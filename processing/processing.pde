// =============================================================================
// Cave Diving Controller — Processing UI
// Branch: processing (Fuori Servizio, CMLS 2025-2026)
//
// Layout: 1280 x 720, split vertical 50/50.
//   left  -> ControlPanel  (config sliders + sensor/param bars + scope + spectrum)
//   right -> DiverHUD      (top-down minimap + diver + BPM pulse + alarm)
//
// OSC:
//   listen  9003  <- JUCE sends /viz/in/* and /viz/out/* (~25-30 Hz)
//                 <- SC   sends /scope/amp and /scope/fft (~60 Hz, optional)
//   send to 9002  -> JUCE  /cfg/* (one-shot on APPLY)
//
// Synthetic underlying signals keep the UI visually alive when no OSC is
// received. Real OSC overrides synthetics when it arrives.
// =============================================================================

import oscP5.*;
import netP5.*;

// -----------------------------------------------------------------------------
// Palette ("deep ocean + industrial HUD" with phosphor green) — §13 of SoT
// -----------------------------------------------------------------------------
final color C_BG          = #0A0F0A;
final color C_GREEN       = #00FF66;
final color C_GREEN_DIM   = #00B345;
final color C_GREEN_DARK  = #1F5538;
final color C_HIGHLIGHT   = #5DFFA4;
final color C_TEXT        = #E0FFD0;
final color C_ALARM       = #FF3030;
final color C_WARN        = #FFB000;

// -----------------------------------------------------------------------------
// Shared state, written by oscEvent (network thread) or by synthetic update
// (draw thread), read by panel draw methods. Single-writer per variable in
// practice; numeric reads on float/int are atomic on the JVM so visual artefacts
// are limited to a single-frame flicker at worst. Will be hardened later if
// needed.
// -----------------------------------------------------------------------------

// 5 sensor inputs (mirror of JUCE's Inputs struct):
float pan_in   = 0.0;   // [-1, +1]
float width_in = 0.5;   // [0, 1]
float depth_in = 0.5;   // [0, 1]
float tilt_in  = 0.5;   // [0, 1]
float speed_in = 0.0;   // joystick discrete in real Arduino, sweep here

// 5 cooked outputs (mirror of JUCE's Outputs struct after mapping):
float reverb_out = 0.0; // [0, 1]
float pan_out    = 0.0; // [-1, +1]
float bpm_out    = 60;  // [40, 200]
float freq_out   = 200; // [80, 800] Hz
int   alarm_out  = 0;   // {0, 1}

// Scope: ring buffer of last N audio samples (synthetic or from /scope/amp)
final int SCOPE_LEN = 256;
float[] scope = new float[SCOPE_LEN];

// Spectrum: 32 frequency bins (synthetic or from /scope/fft)
final int SPECTRUM_LEN = 32;
float[] spectrum = new float[SPECTRUM_LEN];

// Last time we saw a /scope/* OSC message (millis). If older than 2s, we fall
// back to synthetic.
int lastScopeOscMs = -10_000;

// Same for /viz/* (input + cooked output values from JUCE). If older than 1s,
// the synthetic underlying sweep takes over so the UI never sits still.
int lastVizOscMs   = -10_000;

// -----------------------------------------------------------------------------
// OSC + panel objects
// -----------------------------------------------------------------------------
OscP5 oscP5;
NetAddress juceConfigAddr;     // for sending /cfg/* on APPLY

ControlPanel control;
DiverHUD     hud;

// -----------------------------------------------------------------------------
void setup() {
  size(1280, 720);
  frameRate(60);
  background(C_BG);

  oscP5 = new OscP5(this, 9003);
  juceConfigAddr = new NetAddress("127.0.0.1", 9002);

  // Two panels, 50/50 split vertical
  control = new ControlPanel(0,   0, width / 2, height);
  hud     = new DiverHUD   (width / 2, 0, width / 2, height);

  println("Cave Diving Controller — Processing UI");
  println("  listening for OSC on port 9003");
  println("  will send /cfg/* to 127.0.0.1:9002");
}

void draw() {
  // Drive synthetic underlying state so the UI feels alive even without OSC.
  updateSynthetic();

  background(C_BG);
  control.draw();
  hud.draw();

  // Vertical separator between panels (subtle, just dim green hairline)
  stroke(C_GREEN_DARK);
  strokeWeight(1);
  line(width / 2, 0, width / 2, height);
}

// -----------------------------------------------------------------------------
// Synthetic underlying signals — overridden by real OSC when it arrives.
// Until JUCE sends /viz/* and SC sends /scope/*, this is how the UI moves.
// -----------------------------------------------------------------------------
void updateSynthetic() {
  float t = millis() / 1000.0;

  // Only drive the synthetic sweep if no recent /viz/* has been received.
  // When JUCE is alive on the wire, oscEvent() already set the up-to-date
  // values; running the synthetic here would overwrite them every frame.
  if (millis() - lastVizOscMs > 1000) {
    pan_in   = sin(TWO_PI * t / 5.0);
    width_in = 0.5 + 0.5 * sin(TWO_PI * t / 7.0);
    depth_in = 0.5 + 0.5 * sin(TWO_PI * t / 3.0);
    tilt_in  = 0.5 + 0.5 * sin(TWO_PI * t / 11.0);
    speed_in = 5.0 + 5.0 * sin(TWO_PI * t / 13.0);

    // Synthetic outputs mirror JUCE's applyMappingAndSend so the demo looks
    // realistic without a JUCE engine running.
    reverb_out = constrain(depth_in, 0, 1);
    pan_out    = constrain(pan_in, -1, +1);
    bpm_out    = constrain(40 + (1 - width_in) * 160, 40, 200);
    freq_out   = 80 + constrain(tilt_in, 0, 1) * (800 - 80);
    alarm_out  = (speed_in > 3.0) ? 1 : 0;
  }

  // Scope: if no recent /scope/amp, synthesise sin(2pi * freq * t).
  if (millis() - lastScopeOscMs > 2000) {
    for (int i = 0; i < SCOPE_LEN; i++) {
      float sampleTime = t - (SCOPE_LEN - 1 - i) * 0.0002;  // ~50ms window
      scope[i] = sin(TWO_PI * freq_out * sampleTime) * 0.8;
    }
    // Spectrum: dim base + peak at freq's bin.
    int peakBin = (int) map(freq_out, 80, 800, 0, SPECTRUM_LEN - 1);
    peakBin = constrain(peakBin, 0, SPECTRUM_LEN - 1);
    for (int i = 0; i < SPECTRUM_LEN; i++) {
      spectrum[i] = 0.08 + 0.04 * sin(t * 3 + i * 0.5);  // shimmer
    }
    spectrum[peakBin] = 0.85;
    // soft bandwidth around the peak
    if (peakBin > 0)               spectrum[peakBin - 1] = max(spectrum[peakBin - 1], 0.45);
    if (peakBin < SPECTRUM_LEN - 1) spectrum[peakBin + 1] = max(spectrum[peakBin + 1], 0.45);
  }
}

// -----------------------------------------------------------------------------
// OSC routing. Called on the OscP5 receiver thread.
// -----------------------------------------------------------------------------
void oscEvent(OscMessage msg) {
  String addr = msg.addrPattern();

  boolean isViz = addr.startsWith("/viz/");
  if (isViz) lastVizOscMs = millis();

  if      (addr.equals("/viz/in/pan"))     pan_in   = msg.get(0).floatValue();
  else if (addr.equals("/viz/in/width"))   width_in = msg.get(0).floatValue();
  else if (addr.equals("/viz/in/depth"))   depth_in = msg.get(0).floatValue();
  else if (addr.equals("/viz/in/tilt"))    tilt_in  = msg.get(0).floatValue();
  else if (addr.equals("/viz/in/speed"))   speed_in = msg.get(0).floatValue();

  else if (addr.equals("/viz/out/reverb")) reverb_out = msg.get(0).floatValue();
  else if (addr.equals("/viz/out/pan"))    pan_out    = msg.get(0).floatValue();
  else if (addr.equals("/viz/out/bpm"))    bpm_out    = msg.get(0).floatValue();
  else if (addr.equals("/viz/out/freq"))   freq_out   = msg.get(0).floatValue();
  else if (addr.equals("/viz/out/alarm"))  alarm_out  = msg.get(0).intValue();

  // Real scope/spectrum from SC (optional)
  else if (addr.equals("/scope/amp")) {
    // expects N float args = ring of samples (or single peak amplitude)
    int n = min(msg.typetag().length(), SCOPE_LEN);
    for (int i = 0; i < n; i++) scope[i] = msg.get(i).floatValue();
    lastScopeOscMs = millis();
  }
  else if (addr.equals("/scope/fft")) {
    int n = min(msg.typetag().length(), SPECTRUM_LEN);
    for (int i = 0; i < n; i++) spectrum[i] = msg.get(i).floatValue();
    lastScopeOscMs = millis();
  }
}
