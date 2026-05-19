// Diver HUD — right half of the window.
// Placeholder layout.
//   - Top-down minimap of the cave channel + stylised diver
//   - BPM pulse circle (beats at bpm_out)
//   - Tilt + frequency display
//   - Alarm light (binary)
//
// Coordinates are local to the panel's bounds (x, y, w, h).

class DiverHUD {
  int x, y, w, h;

  // Layout constants
  final int PAD       = 14;
  final int HEADER_H  = 32;

  // BPM pulse animation state
  float pulsePhase = 0.0;
  int   lastFrameMs = 0;

  DiverHUD(int x, int y, int w, int h) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    lastFrameMs = millis();
  }

  void draw() {
    // header
    fill(C_GREEN);
    textSize(14);
    textAlign(LEFT, TOP);
    text("DIVER HUD  // top-down + status", x + PAD, y + PAD);
    stroke(C_GREEN_DARK);
    line(x + PAD, y + HEADER_H, x + w - PAD, y + HEADER_H);

    // Minimap occupies the upper region
    int mmX = x + PAD;
    int mmY = y + HEADER_H + 12;
    int mmW = w - 2 * PAD;
    int mmH = (int) (h * 0.55);
    drawMinimap(mmX, mmY, mmW, mmH);

    // Lower region: pulse + tilt + freq + alarm
    int loY = mmY + mmH + 16;
    int loH = h - (loY - y) - PAD;
    drawLowerStatus(x + PAD, loY, w - 2 * PAD, loH);
  }

  // ---------------------------------------------------------------------------
  // Minimap: top-down. Channel walls move with `width`; front wall with `depth`;
  // diver position laterally with `pan`. Uses a placeholder diver glyph
  // (circle + small fin); the proper stylised silhouette comes later.
  // ---------------------------------------------------------------------------
  void drawMinimap(int gx, int gy, int gw, int gh) {
    // outer frame
    noFill();
    stroke(C_GREEN_DARK);
    rect(gx, gy, gw, gh);

    fill(C_GREEN_DIM);
    textSize(10);
    textAlign(LEFT, TOP);
    text("MINIMAP  (top-down view)", gx + 4, gy + 4);

    // Cave bounds inside the frame, with a margin
    int innerX = gx + 30;
    int innerY = gy + 28;
    int innerW = gw - 60;
    int innerH = gh - 56;

    // Channel: parallel vertical walls. width=1 means walls wide apart at max,
    // width=0 means walls collapse to the centre.
    float minHalfChan = 30;                              // never collapse to 0
    float maxHalfChan = innerW * 0.5 - 8;
    float halfChan    = lerp(minHalfChan, maxHalfChan, constrain(width_in, 0, 1));

    float channelCx  = innerX + innerW * 0.5;
    float wallLeftX  = channelCx - halfChan;
    float wallRightX = channelCx + halfChan;

    // Front wall (at top of view). depth=0 -> wall close to the diver
    // (low y, since y increases downward). depth=1 -> wall at top of frame.
    float frontWallY = innerY + (1.0 - constrain(depth_in, 0, 1)) * (innerH * 0.6);

    // walls (solid lines) + noise texture along them
    stroke(C_GREEN);
    strokeWeight(2);
    line(wallLeftX,  frontWallY, wallLeftX,  innerY + innerH);
    line(wallRightX, frontWallY, wallRightX, innerY + innerH);
    line(wallLeftX,  frontWallY, wallRightX, frontWallY);

    // noise pattern (placeholder texture, refined later)
    stroke(C_GREEN_DARK);
    strokeWeight(1);
    int dy = 6;
    float t = millis() / 1000.0;
    for (float yy = frontWallY + 4; yy < innerY + innerH; yy += dy) {
      float n = noise(t * 0.3, yy * 0.05);
      float jL = (n - 0.5) * 8;
      float jR = (noise(t * 0.3 + 100, yy * 0.05) - 0.5) * 8;
      point(wallLeftX  + jL, yy);
      point(wallRightX + jR, yy);
    }

    // Diver: centred in the channel, offset laterally by pan_in
    // pan_in negative -> diver towards left wall; positive -> towards right.
    float diverY = innerY + innerH * 0.7;
    float diverX = channelCx + constrain(pan_in, -1, 1) * (halfChan - 16);
    drawDiver(diverX, diverY);
    strokeWeight(1);
  }

  void drawDiver(float dx, float dy) {
    // Placeholder: oval body + small head + fin direction. To be replaced
    // by the proper stylised "penguin-with-tank" silhouette.
    noStroke();
    fill(C_TEXT);
    ellipse(dx, dy, 14, 22);           // body
    fill(C_TEXT, 200);
    ellipse(dx, dy - 12, 8, 8);        // head
    fill(C_GREEN_DIM);
    triangle(dx - 9, dy + 14, dx + 9, dy + 14, dx, dy + 22);   // fins
    fill(C_GREEN);
    ellipse(dx + 2, dy + 2, 4, 8);     // tank highlight
  }

  // ---------------------------------------------------------------------------
  void drawLowerStatus(int gx, int gy, int gw, int gh) {
    // Split lower area in 2 rows
    int rowH = gh / 2 - 4;

    // ---- Row 1: BPM pulse (left) + Alarm (right) ----
    int pulseW = (int) (gw * 0.55);
    int alarmW = gw - pulseW - 8;
    drawBpmPulse (gx,             gy, pulseW, rowH);
    drawAlarmBox (gx + pulseW + 8, gy, alarmW, rowH);

    // ---- Row 2: tilt indicator + frequency display ----
    int tiltW = pulseW;
    int freqW = alarmW;
    drawTiltIndicator(gx,             gy + rowH + 8, tiltW, rowH);
    drawFreqDisplay  (gx + tiltW + 8, gy + rowH + 8, freqW, rowH);
  }

  void drawBpmPulse(int gx, int gy, int gw, int gh) {
    noFill();
    stroke(C_GREEN_DARK);
    rect(gx, gy, gw, gh);
    fill(C_GREEN_DIM);
    textSize(10);
    textAlign(LEFT, TOP);
    text("BPM PULSE", gx + 4, gy + 4);

    // Advance pulse phase: each beat = 1.0
    int now = millis();
    float dt = (now - lastFrameMs) / 1000.0;
    lastFrameMs = now;
    pulsePhase += dt * (bpm_out / 60.0);
    if (pulsePhase >= 1.0) pulsePhase -= 1.0;

    float intensity = 1.0 - pulsePhase;          // bright at beat, fades
    intensity = pow(intensity, 2);

    float cx = gx + gw * 0.5;
    float cy = gy + gh * 0.5 + 4;
    float maxR = min(gw, gh) * 0.32;
    float r = maxR * (0.55 + 0.45 * intensity);

    noStroke();
    fill(lerpColor(C_GREEN_DARK, C_HIGHLIGHT, intensity));
    ellipse(cx, cy, r * 2, r * 2);

    fill(C_TEXT);
    textSize(11);
    textAlign(CENTER, BOTTOM);
    text(nf(bpm_out, 0, 1) + " BPM", cx, gy + gh - 4);
  }

  void drawAlarmBox(int gx, int gy, int gw, int gh) {
    noFill();
    stroke(alarm_out == 1 ? C_ALARM : C_GREEN_DARK);
    strokeWeight(alarm_out == 1 ? 2 : 1);
    rect(gx, gy, gw, gh);
    strokeWeight(1);

    fill(alarm_out == 1 ? C_ALARM : C_GREEN_DIM);
    textSize(10);
    textAlign(LEFT, TOP);
    text("ALARM", gx + 4, gy + 4);

    // big LED
    float cx = gx + gw * 0.5;
    float cy = gy + gh * 0.55;
    float r  = min(gw, gh) * 0.22;
    noStroke();
    fill(alarm_out == 1 ? C_ALARM : C_GREEN_DARK);
    ellipse(cx, cy, r * 2, r * 2);

    fill(C_TEXT);
    textSize(12);
    textAlign(CENTER, BOTTOM);
    text(alarm_out == 1 ? "EMERGENCY" : "ok", cx, gy + gh - 4);
  }

  void drawTiltIndicator(int gx, int gy, int gw, int gh) {
    noFill();
    stroke(C_GREEN_DARK);
    rect(gx, gy, gw, gh);
    fill(C_GREEN_DIM);
    textSize(10);
    textAlign(LEFT, TOP);
    text("TILT (head)", gx + 4, gy + 4);

    // horizontal "horizon" line that pivots around the centre with tilt
    float cx = gx + gw * 0.5;
    float cy = gy + gh * 0.55;
    float halfLen = gw * 0.35;
    float angle = (tilt_in - 0.5) * radians(60);  // -30°..+30°

    pushMatrix();
    translate(cx, cy);
    rotate(angle);
    stroke(C_GREEN);
    strokeWeight(1.5);
    line(-halfLen, 0, halfLen, 0);
    // little ticks
    line(-halfLen,  -4, -halfLen,  4);
    line( halfLen,  -4,  halfLen,  4);
    line(0, -6, 0, 6);
    popMatrix();
    strokeWeight(1);

    fill(C_TEXT);
    textSize(11);
    textAlign(CENTER, BOTTOM);
    text(nf(tilt_in, 0, 3), gx + gw / 2, gy + gh - 4);
  }

  void drawFreqDisplay(int gx, int gy, int gw, int gh) {
    noFill();
    stroke(C_GREEN_DARK);
    rect(gx, gy, gw, gh);
    fill(C_GREEN_DIM);
    textSize(10);
    textAlign(LEFT, TOP);
    text("FREQ (Hz)", gx + 4, gy + 4);

    fill(C_HIGHLIGHT);
    textSize(28);
    textAlign(CENTER, CENTER);
    text(nf(freq_out, 0, 0), gx + gw / 2, gy + gh / 2 + 4);
  }
}
