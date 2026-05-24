// Control Panel — left half of the window.
//   - 2 pre-dive dual-range sliders (bpm, freq) + 1 single slider (alarm thr)
//   - 5 live sensor input bars
//   - 5 live cooked output bars
//   - Oscilloscope of the audio signal (synthetic until SC sends real data)
//
// All coordinates are local to the panel's bounds (x, y, w, h).

class ControlPanel {
  int x, y, w, h;

  // Layout constants
  final int PAD       = 14;
  final int HEADER_H  = 32;
  final int ROW_H     = 24;
  final int SECTION_GAP = 12;

  // Config absolute bounds + minimum gap between range thumbs
  final float BPM_BOUND_MIN  = 20,   BPM_BOUND_MAX  = 200;
  final float FREQ_BOUND_MIN = 20,   FREQ_BOUND_MAX = 2000;
  final float ALARM_BOUND_MIN = 0,   ALARM_BOUND_MAX = 10;
  final float BPM_GAP   = 5;
  final float FREQ_GAP  = 20;

  // Config values (Interactive UI state)
  float cfgBpmMin    = 40;
  float cfgBpmMax    = 200;
  float cfgFreqMin   = 80;
  float cfgFreqMax   = 800;
  float cfgAlarmThr  = 3.0;

  // Active config values (Committed on APPLY, used by the engine/bars)
  float activeBpmMin    = 40;
  float activeBpmMax    = 200;
  float activeFreqMin   = 80;
  float activeFreqMax   = 800;
  float activeAlarmThr  = 3.0;

  // --- MOUSE INTERACTION ---
  // 3 config rows: 0 = BPM range, 1 = Freq range, 2 = Alarm thr
  int[] rowY = new int[3];
  int sliderX, sliderW;
  int btnX, btnY, btnW, btnH;
  // Active thumb id: -1 = none, 0/1 = bpm min/max, 2/3 = freq min/max, 4 = alarm
  int activeThumb = -1;
  int lastApplyMs = -10000;

  ControlPanel(int x, int y, int w, int h) {
    this.x = x; this.y = y; this.w = w; this.h = h;
  }

  void draw() {
    // Panel header
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
    drawOscilloscope            (x + PAD, cursorY, w - 2 * PAD, h - (cursorY - y) - PAD);
  }

  // -----------------------------------------------------------------
  int drawConfigSection(int gx, int gy, int gw) {
    fill(C_GREEN_DIM);
    textSize(11);
    textAlign(LEFT, TOP);
    text("PRE-DIVE CONFIG  (APPLY -> JUCE)", gx, gy);
    gy += 16;

    // Save slider coordinates for mouse interaction.
    // Wider right gutter to fit "min..max" text on range rows.
    sliderX = gx + 90;
    sliderW = gw - 90 - 110;

    rowY[0] = gy; gy = drawRangeRow (gx, gy, gw, "bpm",     cfgBpmMin,  cfgBpmMax,  BPM_BOUND_MIN,  BPM_BOUND_MAX,  1);
    rowY[1] = gy; gy = drawRangeRow (gx, gy, gw, "freq Hz", cfgFreqMin, cfgFreqMax, FREQ_BOUND_MIN, FREQ_BOUND_MAX, 0);
    rowY[2] = gy; gy = drawSingleRow(gx, gy, gw, "alarm.thr", cfgAlarmThr, ALARM_BOUND_MIN, ALARM_BOUND_MAX, 1);

    // Save APPLY button coordinates
    btnW = 80; btnH = 22;
    btnX = gx + gw - btnW;
    btnY = gy + 4;

    // Draw APPLY button with hover/click feedback
    boolean isHover = isApplyClicked(mouseX, mouseY);
    boolean isClick = isHover && mousePressed;

    if (isClick) fill(C_HIGHLIGHT);
    else noFill();

    stroke(C_GREEN);
    rect(btnX, btnY, btnW, btnH);

    if (isClick) fill(C_BG);
    else fill(C_GREEN);

    textAlign(CENTER, CENTER);
    textSize(11);
    text("APPLY", btnX + btnW / 2, btnY + btnH / 2);

    // Visual feedback "SENT TO JUCE"
    if (millis() - lastApplyMs < 1500) {
      fill(C_HIGHLIGHT);
      textAlign(RIGHT, CENTER);
      text("SENT TO JUCE! -->", btnX - 10, btnY + btnH / 2);
    }

    return btnY + btnH;
  }

  // Dual-thumb range row. Filled segment between min and max thumbs.
  int drawRangeRow(int gx, int gy, int gw, String label,
                   float vMin, float vMax, float bMin, float bMax, int decimals) {
    fill(C_TEXT);
    textSize(11);
    textAlign(LEFT, CENTER);
    text(label, gx, gy + ROW_H / 2);

    int barX = sliderX;
    int barW = sliderW;
    int barY = gy + 4;
    int barH = ROW_H - 8;

    // Track frame
    noFill();
    stroke(C_GREEN_DARK);
    rect(barX, barY, barW, barH);

    // Filled segment between the two thumbs
    float fMin = constrain((vMin - bMin) / (bMax - bMin), 0, 1);
    float fMax = constrain((vMax - bMin) / (bMax - bMin), 0, 1);
    float xMin = barX + barW * fMin;
    float xMax = barX + barW * fMax;
    noStroke();
    fill(C_GREEN_DIM);
    rect(xMin, barY + 1, xMax - xMin, barH - 2);

    // Two thumbs as bright vertical bars, slightly taller than the track
    stroke(C_HIGHLIGHT);
    strokeWeight(2);
    line(xMin, gy + 2, xMin, gy + ROW_H - 2);
    line(xMax, gy + 2, xMax, gy + ROW_H - 2);
    strokeWeight(1);

    // "min..max" text in the right gutter
    fill(C_TEXT);
    textAlign(RIGHT, CENTER);
    text(nf(vMin, 0, decimals) + ".." + nf(vMax, 0, decimals), gx + gw - 4, gy + ROW_H / 2);

    return gy + ROW_H;
  }

  // Single-thumb row (alarm threshold).
  int drawSingleRow(int gx, int gy, int gw, String label,
                    float value, float bMin, float bMax, int decimals) {
    fill(C_TEXT);
    textSize(11);
    textAlign(LEFT, CENTER);
    text(label, gx, gy + ROW_H / 2);

    int barX = sliderX;
    int barW = sliderW;
    int barY = gy + 4;
    int barH = ROW_H - 8;

    noFill();
    stroke(C_GREEN_DARK);
    rect(barX, barY, barW, barH);

    float f = constrain((value - bMin) / (bMax - bMin), 0, 1);
    float xT = barX + barW * f;
    noStroke();
    fill(C_GREEN_DIM);
    rect(barX + 1, barY + 1, (barW - 2) * f, barH - 2);

    stroke(C_HIGHLIGHT);
    strokeWeight(2);
    line(xT, gy + 2, xT, gy + ROW_H - 2);
    strokeWeight(1);

    fill(C_TEXT);
    textAlign(RIGHT, CENTER);
    text(nf(value, 0, decimals), gx + gw - 4, gy + ROW_H / 2);

    return gy + ROW_H;
  }

  // --- INTERACTION LOGIC ---
  boolean isApplyClicked(int mx, int my) {
    return (mx >= btnX && mx <= btnX + btnW && my >= btnY && my <= btnY + btnH);
  }

  void handleMousePressed(int mx, int my) {
    if (mx < sliderX || mx > sliderX + sliderW) return;

    // BPM range row
    if (my >= rowY[0] && my <= rowY[0] + ROW_H) {
      activeThumb = pickThumb(mx, cfgBpmMin, cfgBpmMax, BPM_BOUND_MIN, BPM_BOUND_MAX, 0, 1);
      updateSliderValue(mx);
      return;
    }
    // Freq range row
    if (my >= rowY[1] && my <= rowY[1] + ROW_H) {
      activeThumb = pickThumb(mx, cfgFreqMin, cfgFreqMax, FREQ_BOUND_MIN, FREQ_BOUND_MAX, 2, 3);
      updateSliderValue(mx);
      return;
    }
    // Alarm single row
    if (my >= rowY[2] && my <= rowY[2] + ROW_H) {
      activeThumb = 4;
      updateSliderValue(mx);
      return;
    }
  }

  void handleMouseDragged(int mx, int my) {
    if (activeThumb != -1) {
      updateSliderValue(mx);
    }
  }

  void handleMouseReleased() {
    activeThumb = -1;
  }

  // Pick the thumb (min or max) whose X is closer to the mouse.
  int pickThumb(int mx, float vMin, float vMax, float bMin, float bMax, int idMin, int idMax) {
    float xMin = sliderX + sliderW * (vMin - bMin) / (bMax - bMin);
    float xMax = sliderX + sliderW * (vMax - bMin) / (bMax - bMin);
    return (abs(mx - xMin) <= abs(mx - xMax)) ? idMin : idMax;
  }

  void updateSliderValue(int mx) {
    float frac = constrain((float)(mx - sliderX) / sliderW, 0.0, 1.0);
    switch(activeThumb) {
      case 0:  // bpm min
        cfgBpmMin = lerp(BPM_BOUND_MIN, BPM_BOUND_MAX, frac);
        if (cfgBpmMin > cfgBpmMax - BPM_GAP) cfgBpmMin = cfgBpmMax - BPM_GAP;
        break;
      case 1:  // bpm max
        cfgBpmMax = lerp(BPM_BOUND_MIN, BPM_BOUND_MAX, frac);
        if (cfgBpmMax < cfgBpmMin + BPM_GAP) cfgBpmMax = cfgBpmMin + BPM_GAP;
        break;
      case 2:  // freq min
        cfgFreqMin = lerp(FREQ_BOUND_MIN, FREQ_BOUND_MAX, frac);
        if (cfgFreqMin > cfgFreqMax - FREQ_GAP) cfgFreqMin = cfgFreqMax - FREQ_GAP;
        break;
      case 3:  // freq max
        cfgFreqMax = lerp(FREQ_BOUND_MIN, FREQ_BOUND_MAX, frac);
        if (cfgFreqMax < cfgFreqMin + FREQ_GAP) cfgFreqMax = cfgFreqMin + FREQ_GAP;
        break;
      case 4:  // alarm thr
        cfgAlarmThr = lerp(ALARM_BOUND_MIN, ALARM_BOUND_MAX, frac);
        break;
    }
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
    text("COOKED PARAMS (to SC  /beep/* + /alarm/gate)", gx, gy);
    gy += 16;
    gy = drawValueBar(gx, gy, gw, "reverb", reverb_out, 0, 1, 3, C_HIGHLIGHT, false);
    gy = drawValueBar(gx, gy, gw, "pan",    pan_out,   -1, 1, 3, C_HIGHLIGHT, true);
    
    // Use active variables to define bar limits
    gy = drawValueBar(gx, gy, gw, "bpm",    bpm_out,   activeBpmMin, activeBpmMax, 1, C_HIGHLIGHT, false);
    gy = drawValueBar(gx, gy, gw, "freq",   freq_out,  activeFreqMin, activeFreqMax, 0, C_HIGHLIGHT, false);
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
      // Center anchor, bar grows left or right
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
    gh -= 16;

    noFill();
    stroke(C_GREEN_DARK);
    rect(gx, gy, gw, gh);

    // Signal rendering
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
  void drawDivider(int gx, int gy) {
    stroke(C_GREEN_DARK);
    line(gx, gy, gx + w - 2 * PAD, gy);
  }
}
