// Control Panel — left half of the window.
// Placeholder layout, synthetic values driving the visuals.
//   - 5 pre-dive config sliders (display-only here for now)
//   - 5 live sensor input bars
//   - 5 live cooked output bars
//   - Oscilloscope of the audio signal (synthetic until SC sends real data)
//   - Spectrum bars (idem)
//
// All coordinates are local to the panel's bounds (x, y, w, h).

class ControlPanel {
  int x, y, w, h;

  // Layout constants
  final int PAD       = 14;
  final int HEADER_H  = 32;
  final int ROW_H     = 24;
  final int SECTION_GAP = 12;

  // Placeholder config values (interactive once APPLY is wired)
  float cfgBpmMin    = 40;
  float cfgBpmMax    = 200;
  float cfgFreqMin   = 80;
  float cfgFreqMax   = 800;
  float cfgAlarmThr  = 3.0;

  ControlPanel(int x, int y, int w, int h) {
    this.x = x; this.y = y; this.w = w; this.h = h;
  }

  void draw() {
    // panel header
    fill(C_GREEN);
    textSize(14);
    textAlign(LEFT, TOP);
    text("CONTROL  // pre-dive config + live monitoring", x + PAD, y + PAD);
    drawDivider(x + PAD, y + HEADER_H);

    int cursorY = y + HEADER_H + 6;

    cursorY = drawConfigSection (x + PAD, cursorY, w - 2 * PAD);
    cursorY += SECTION_GAP;
    cursorY = drawInputBars     (x + PAD, cursorY, w - 2 * PAD);
    cursorY += SECTION_GAP;
    cursorY = drawOutputBars    (x + PAD, cursorY, w - 2 * PAD);
    cursorY += SECTION_GAP;
    cursorY = drawOscilloscope  (x + PAD, cursorY, w - 2 * PAD, 100);
    cursorY += SECTION_GAP;
    cursorY = drawSpectrum      (x + PAD, cursorY, w - 2 * PAD, h - (cursorY - y) - PAD);
  }

  // -----------------------------------------------------------------
  int drawConfigSection(int gx, int gy, int gw) {
    fill(C_GREEN_DIM);
    textSize(11);
    textAlign(LEFT, TOP);
    text("PRE-DIVE CONFIG  (APPLY -> JUCE)", gx, gy);
    gy += 16;

    gy = drawConfigRow(gx, gy, gw, "bpm.min",     cfgBpmMin,    20, 200);
    gy = drawConfigRow(gx, gy, gw, "bpm.max",     cfgBpmMax,    20, 200);
    gy = drawConfigRow(gx, gy, gw, "freq.min Hz", cfgFreqMin,   20, 2000);
    gy = drawConfigRow(gx, gy, gw, "freq.max Hz", cfgFreqMax,   20, 2000);
    gy = drawConfigRow(gx, gy, gw, "alarm.thr",   cfgAlarmThr,  0, 10);

    // APPLY button placeholder
    int btnW = 80, btnH = 22;
    noFill();
    stroke(C_GREEN);
    rect(gx + gw - btnW, gy, btnW, btnH);
    fill(C_GREEN);
    textAlign(CENTER, CENTER);
    textSize(11);
    text("APPLY", gx + gw - btnW / 2, gy + btnH / 2);
    return gy + btnH;
  }

  int drawConfigRow(int gx, int gy, int gw, String label, float value, float vmin, float vmax) {
    // label
    fill(C_TEXT);
    textSize(11);
    textAlign(LEFT, CENTER);
    text(label, gx, gy + ROW_H / 2);

    // bar
    int barX = gx + 90;
    int barW = gw - 90 - 70;
    noFill();
    stroke(C_GREEN_DARK);
    rect(barX, gy + 4, barW, ROW_H - 8);
    float fillFrac = constrain((value - vmin) / (vmax - vmin), 0, 1);
    noStroke();
    fill(C_GREEN_DIM);
    rect(barX + 1, gy + 5, (barW - 2) * fillFrac, ROW_H - 10);

    // value text
    fill(C_TEXT);
    textAlign(RIGHT, CENTER);
    text(nf(value, 0, 1), gx + gw - 4, gy + ROW_H / 2);

    return gy + ROW_H;
  }

  // -----------------------------------------------------------------
  int drawInputBars(int gx, int gy, int gw) {
    fill(C_GREEN_DIM);
    textSize(11);
    textAlign(LEFT, TOP);
    text("LIVE SENSORS (from JUCE  /viz/in/*)", gx, gy);
    gy += 16;
    gy = drawValueBar(gx, gy, gw, "pan",   pan_in,   -1, 1, 3, C_GREEN, true);
    gy = drawValueBar(gx, gy, gw, "width", width_in,  0, 1, 3, C_GREEN, false);
    gy = drawValueBar(gx, gy, gw, "depth", depth_in,  0, 1, 3, C_GREEN, false);
    gy = drawValueBar(gx, gy, gw, "tilt",  tilt_in,   0, 1, 3, C_GREEN, false);
    gy = drawValueBar(gx, gy, gw, "speed", speed_in,  0, 10, 1, C_GREEN, false);
    return gy;
  }

  // -----------------------------------------------------------------
  int drawOutputBars(int gx, int gy, int gw) {
    fill(C_GREEN_DIM);
    textSize(11);
    textAlign(LEFT, TOP);
    text("COOKED PARAMS (to SC  /synth/* + /alarm/gate)", gx, gy);
    gy += 16;
    gy = drawValueBar(gx, gy, gw, "reverb", reverb_out, 0, 1, 3, C_HIGHLIGHT, false);
    gy = drawValueBar(gx, gy, gw, "pan",    pan_out,   -1, 1, 3, C_HIGHLIGHT, true);
    gy = drawValueBar(gx, gy, gw, "bpm",    bpm_out,   40, 200, 1, C_HIGHLIGHT, false);
    gy = drawValueBar(gx, gy, gw, "freq",   freq_out,  80, 800, 0, C_HIGHLIGHT, false);
    gy = drawAlarmRow(gx, gy, gw, "alarm",  alarm_out);
    return gy;
  }

  int drawValueBar(int gx, int gy, int gw, String label, float value, float vmin, float vmax,
                   int decimals, color barColor, boolean bipolar) {
    fill(C_TEXT);
    textSize(11);
    textAlign(LEFT, CENTER);
    text(label, gx, gy + ROW_H / 2);

    int barX = gx + 80;
    int barW = gw - 80 - 80;
    noFill();
    stroke(C_GREEN_DARK);
    rect(barX, gy + 4, barW, ROW_H - 8);
    noStroke();
    fill(barColor, 220);
    if (bipolar) {
      // center anchor, bar grows left or right
      float frac = constrain((value - vmin) / (vmax - vmin), 0, 1);  // 0..1
      float center = barX + barW * 0.5;
      float xLeft, xRight;
      if (frac >= 0.5) { xLeft = center; xRight = barX + barW * frac; }
      else             { xLeft = barX + barW * frac; xRight = center; }
      rect(xLeft, gy + 5, xRight - xLeft, ROW_H - 10);
      stroke(C_GREEN_DIM);
      line(center, gy + 4, center, gy + ROW_H - 4);
    } else {
      float frac = constrain((value - vmin) / (vmax - vmin), 0, 1);
      rect(barX + 1, gy + 5, (barW - 2) * frac, ROW_H - 10);
    }

    fill(C_TEXT);
    textAlign(RIGHT, CENTER);
    text(nf(value, 0, decimals), gx + gw - 4, gy + ROW_H / 2);

    return gy + ROW_H;
  }

  int drawAlarmRow(int gx, int gy, int gw, String label, int gate) {
    fill(C_TEXT);
    textSize(11);
    textAlign(LEFT, CENTER);
    text(label, gx, gy + ROW_H / 2);

    noStroke();
    fill(gate == 1 ? C_ALARM : C_GREEN_DARK);
    int dotD = 14;
    ellipse(gx + 80 + dotD / 2, gy + ROW_H / 2, dotD, dotD);

    fill(C_TEXT);
    textAlign(RIGHT, CENTER);
    text(gate, gx + gw - 4, gy + ROW_H / 2);
    return gy + ROW_H;
  }

  // -----------------------------------------------------------------
  int drawOscilloscope(int gx, int gy, int gw, int gh) {
    fill(C_GREEN_DIM);
    textSize(11);
    textAlign(LEFT, TOP);
    text("OSCILLOSCOPE  (synthetic until SC /scope/amp arrives)", gx, gy);
    gy += 16;

    noFill();
    stroke(C_GREEN_DARK);
    rect(gx, gy, gw, gh);

    // signal
    stroke(C_GREEN);
    strokeWeight(1.5);
    noFill();
    beginShape();
    for (int i = 0; i < SCOPE_LEN; i++) {
      float px = gx + (float) i / (SCOPE_LEN - 1) * gw;
      float py = gy + gh / 2.0 - scope[i] * (gh * 0.4);
      vertex(px, py);
    }
    endShape();
    strokeWeight(1);

    return gy + gh;
  }

  // -----------------------------------------------------------------
  int drawSpectrum(int gx, int gy, int gw, int gh) {
    fill(C_GREEN_DIM);
    textSize(11);
    textAlign(LEFT, TOP);
    text("SPECTRUM  (synthetic until SC /scope/fft arrives)", gx, gy);
    gy += 16;
    gh -= 16;

    noFill();
    stroke(C_GREEN_DARK);
    rect(gx, gy, gw, gh);

    int bins = SPECTRUM_LEN;
    float binW = gw / (float) bins;
    noStroke();
    for (int i = 0; i < bins; i++) {
      float val = constrain(spectrum[i], 0, 1);
      float barH = val * (gh - 4);
      fill(lerpColor(C_GREEN_DARK, C_HIGHLIGHT, val));
      rect(gx + i * binW + 1, gy + gh - barH - 2, binW - 2, barH);
    }
    return gy + gh;
  }

  // -----------------------------------------------------------------
  void drawDivider(int gx, int gy) {
    stroke(C_GREEN_DARK);
    line(gx, gy, gx + w - 2 * PAD, gy);
  }
}
