// =============================================================================
// Cave Diving Controller — Processing UI
// Branch: processing (Fuori Servizio, CMLS 2025-2026)
//
// Layout: 1280 x 720, split vertical 50/50.
//   Left  -> ControlPanel  (config sliders + sensor/param bars + scope)
//   Right -> DiverHUD      (top-down minimap + diver + BPM pulse + alarm)
//
// OSC:
//   Listen  9003  <- JUCE sends /viz/in/* and /viz/out/* (~25-30 Hz)
//                 <- SC   sends /scope/amp (~60 Hz, optional)
//   Send to 9002  -> JUCE  /cfg/apply (one-shot on APPLY)
//
// Synthetic underlying signals keep the UI visually alive when no OSC is
// received. Real OSC overrides synthetics when it arrives.
// =============================================================================

import oscP5.*;
import netP5.*;

// -----------------------------------------------------------------------------
// Palette ("Deep ocean + industrial HUD" with phosphor green) — §13 of SoT
// -----------------------------------------------------------------------------
final color C_BG          = #0A0F0A;
final color C_GREEN       = #00FF66;
final color C_GREEN_DIM   = #00B345;
final color C_GREEN_DARK  = #1F5538;
final color C_HIGHLIGHT   = #5DFFA4;
final color C_TEXT        = #E0FFD0;
final color C_ALARM       = #FF3030;
final color C_WARN        = #FFB000;

PFont hudFont;     // Custom UI font
PImage helmetImg;  // Pre-dive splash helmet illustration (data/helmet.png)

// -----------------------------------------------------------------------------
// Shared State
// Written by oscEvent (network thread) or by synthetic update (draw thread), 
// read by panel draw methods. Single-writer per variable in practice; numeric 
// reads on float/int are atomic on the JVM, limiting visual artifacts to a 
// single-frame flicker at worst.
// -----------------------------------------------------------------------------

// 5 Sensor inputs (mirroring JUCE's Inputs struct):
float pan_in   = 0.0;   // [-1, +1]
float width_in = 0.5;   // [0, 1]
float depth_in = 0.5;   // [0, 1]
float tilt_in  = 0.5;   // [0, 1]
float speed_in = 0.0;   // Joystick discrete in real Arduino, sweep here

// 5 Cooked outputs (mirroring JUCE's Outputs struct after mapping):
float reverb_out = 0.0; // [0, 1]
float pan_out    = 0.0; // [-1, +1]
float bpm_out    = 60;  // [40, 200]
float freq_out   = 200; // [80, 800] Hz
int   alarm_out  = 0;   // {0, 1}

// Scope: Ring buffer of the last N audio samples (synthetic or from /scope/amp)
final int SCOPE_LEN = 256;
float[] scope = new float[SCOPE_LEN];

// Last time we saw a /scope/amp OSC message (millis).
// If older than 2s, we fall back to a synthetic sine.
int lastScopeOscMs = -10_000;

// Last time we saw a /viz/* OSC message (input + cooked output values from JUCE). 
// If older than 1s, the synthetic underlying sweep takes over so the UI stays alive.
int lastVizOscMs   = -10_000;

// -----------------------------------------------------------------------------
// OSC + Panel Objects
// -----------------------------------------------------------------------------
OscP5 oscP5;
NetAddress juceConfigAddr;     // Target for sending /cfg/apply on APPLY

ControlPanel control;
DiverHUD     hud;
SplashScreen splash;

// Splash state: stays on the pre-dive screen until START DIVING is clicked.
boolean dived = false;

// -----------------------------------------------------------------------------
// Setup & Draw Loop
// -----------------------------------------------------------------------------
void setup() {
  size(1280, 720);
  frameRate(60);
  background(C_BG);
  
  hudFont = createFont("Monospaced", 14);
  textFont(hudFont);
  helmetImg = loadImage("helmet.png");

  oscP5 = new OscP5(this, 9003);
  juceConfigAddr = new NetAddress("127.0.0.1", 9002);

  // Two panels, 50/50 vertical split (post-splash)
  control = new ControlPanel(0,   0, width / 2, height);
  hud     = new DiverHUD    (width / 2, 0, width / 2, height);

  // Full-window pre-dive splash
  splash  = new SplashScreen(width, height);

  println("Cave Diving Controller — Processing UI");
  println("  Listening for OSC on port 9003");
  println("  Will send /cfg/apply to 127.0.0.1:9002");
}

void draw() {
  background(C_BG);

  if (!dived) {
    // Pre-dive splash. OSC listener stays active in the background so the
    // status line can detect JUCE connection live.
    splash.draw();
    return;
  }

  // Drive synthetic underlying state so the UI feels alive even without OSC
  updateSynthetic();

  control.draw();
  hud.draw();

  // Vertical separator between panels (subtle dim green hairline)
  stroke(C_GREEN_DARK);
  strokeWeight(1);
  line(width / 2, 0, width / 2, height);
}

// -----------------------------------------------------------------------------
// Synthetic Simulation Engine
// Overridden by real OSC when it arrives. Until JUCE sends /viz/* and
// SC sends /scope/amp, this keeps the UI elements moving dynamically.
// -----------------------------------------------------------------------------
void updateSynthetic() {
  float t = millis() / 1000.0;

  // Only drive the synthetic sweep if no recent /viz/* has been received.
  if (millis() - lastVizOscMs > 1000) {
    pan_in   = sin(TWO_PI * t / 5.0);
    width_in = 0.5 + 0.5 * sin(TWO_PI * t / 7.0);
    depth_in = 0.5 + 0.5 * sin(TWO_PI * t / 3.0);
    tilt_in  = 0.5 + 0.5 * sin(TWO_PI * t / 11.0);
    speed_in = 5.0 + 5.0 * sin(TWO_PI * t / 13.0);

    // Synthetic outputs mirror JUCE's applyMappingAndSend.
    // Reverb driven by width (wide canal -> wet), BPM driven by depth (close wall -> fast).
    // Curve kept linear here; JUCE uses power-2 — small mismatch only during the synthetic fallback.
    reverb_out = constrain(width_in, 0, 1);
    pan_out    = constrain(pan_in, -1, +1);

    float targetBpm = control.activeBpmMin + (1.0 - depth_in) * (control.activeBpmMax - control.activeBpmMin);
    bpm_out    = constrain(targetBpm, control.activeBpmMin, control.activeBpmMax);
    
    float targetFreq = control.activeFreqMin + tilt_in * (control.activeFreqMax - control.activeFreqMin);
    freq_out   = constrain(targetFreq, control.activeFreqMin, control.activeFreqMax);
    
    alarm_out  = (speed_in > control.activeAlarmThr) ? 1 : 0;
  }

  // Scope: If no recent /scope/amp is received, synthesize sin(2pi * freq * t).
  if (millis() - lastScopeOscMs > 2000) {
    for (int i = 0; i < SCOPE_LEN; i++) {
      float sampleTime = t - (SCOPE_LEN - 1 - i) * 0.0002;  // ~50ms window
      scope[i] = sin(TWO_PI * freq_out * sampleTime) * 0.8;
    }
  }
}

// -----------------------------------------------------------------------------
// OSC Routing (Called on the OscP5 receiver thread)
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

  // Real scope from SuperCollider (optional)
  else if (addr.equals("/scope/amp")) {
    int n = min(msg.typetag().length(), SCOPE_LEN);
    for (int i = 0; i < n; i++) scope[i] = msg.get(i).floatValue();
    lastScopeOscMs = millis();
  }
}

// -----------------------------------------------------------------------------
// Mouse Interaction Routing
// -----------------------------------------------------------------------------
void mousePressed() {
  if (!dived) {
    if (splash.isStartClicked(mouseX, mouseY)) dived = true;
    return;
  }
  if (control.isApplyClicked(mouseX, mouseY)) {
    sendConfigToJuce();
  } else {
    control.handleMousePressed(mouseX, mouseY);
  }
}

void mouseDragged() {
  if (!dived) return;
  control.handleMouseDragged(mouseX, mouseY);
}

void mouseReleased() {
  if (!dived) return;
  control.handleMouseReleased();
}

// -----------------------------------------------------------------------------
// Send Configuration to JUCE via OSC
// -----------------------------------------------------------------------------
void sendConfigToJuce() {
  // 1. Update "active" values with current UI slider values
  control.activeBpmMin   = control.cfgBpmMin;
  control.activeBpmMax   = control.cfgBpmMax;
  control.activeFreqMin  = control.cfgFreqMin;
  control.activeFreqMax  = control.cfgFreqMax;
  control.activeAlarmThr = control.cfgAlarmThr;

  // 2. Send everything via OSC as a single packaged message
  OscMessage msg = new OscMessage("/cfg/apply");
  msg.add(control.activeBpmMin);
  msg.add(control.activeBpmMax);
  msg.add(control.activeFreqMin);
  msg.add(control.activeFreqMax);
  msg.add(control.activeAlarmThr);
  
  oscP5.send(msg, juceConfigAddr);
  control.lastApplyMs = millis(); // Trigger visual UI feedback on the button
  
  println("APPLY CLICKED: Configuration sent to JUCE at " + juceConfigAddr);
  println(" -> BPM Range: " + control.activeBpmMin + " to " + control.activeBpmMax);
  println(" -> Freq Range: " + control.activeFreqMin + " to " + control.activeFreqMax);
  println(" -> Alarm Thr: " + control.activeAlarmThr);
}
