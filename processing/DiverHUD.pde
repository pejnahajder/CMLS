// =============================================================================
// Diver HUD — Right half of the window.
// 
// Layout:
//   - Top-down minimap of the cave channel + stylized diver
//   - BPM pulse circle (beats at bpm_out)
//   - Tilt + Speed faders with dynamic alarm threshold
//   - Reverb display with faux optical blur
//   - Alarm light (binary with glow effect)
//
// All coordinates are local to the panel's bounds (x, y, w, h).
// =============================================================================

class DiverHUD {
  int x, y, w, h;

  // Layout constants
  final int PAD       = 14;
  final int HEADER_H  = 32;

  // BPM pulse animation state
  float pulsePhase = 0.0;
  int   lastFrameMs = 0;

  DiverHUD(int x, int y, int w, int h) {
    this.x = x; 
    this.y = y; 
    this.w = w; 
    this.h = h;
    lastFrameMs = millis();
  }

  void draw() {
    // Header
    fill(C_GREEN);
    textSize(14);
    textAlign(LEFT, TOP);
    text("DIVER HUD // top-down + status", x + PAD, y + PAD);
    stroke(C_GREEN_DARK);
    line(x + PAD, y + HEADER_H, x + w - PAD, y + HEADER_H);

    // Minimap occupies the upper region
    int mmX = x + PAD;
    int mmY = y + HEADER_H + 12;
    int mmW = w - 2 * PAD;
    int mmH = (int) (h * 0.55);
    drawMinimap(mmX, mmY, mmW, mmH);

    // Lower region: pulse + tilt/speed + reverb + alarm
    int loY = mmY + mmH + 16;
    int loH = h - (loY - y) - PAD;
    drawLowerStatus(x + PAD, loY, w - 2 * PAD, loH);
  }

  // ---------------------------------------------------------------------------
  // Minimap: Top-down view. 
  // Channel walls move with `width`; front wall with `depth`;
  // Diver position laterally with `pan`. 
  // Uses a placeholder diver glyph (cursor arrow style).
  // ---------------------------------------------------------------------------
  void drawMinimap(int gx, int gy, int gw, int gh) {
    // Outer frame
    noFill();
    stroke(C_GREEN_DARK);
    rect(gx, gy, gw, gh);

    fill(C_GREEN_DIM);
    textSize(10);
    textAlign(LEFT, TOP);
    text("MINIMAP (top-down view)", gx + 4, gy + 4);

    // Cave bounds inside the frame, with a margin
    int innerX = gx + 30;
    int innerY = gy + 28;
    int innerW = gw - 60;
    int innerH = gh - 56;

    // Channel: Parallel vertical walls. 
    // width=1 means walls wide apart at max.
    // width=0 means walls collapse toward the center.
    float minHalfChan = 30; // Never collapse to 0
    float maxHalfChan = innerW * 0.5 - 8;
    float halfChan    = lerp(minHalfChan, maxHalfChan, constrain(width_in, 0, 1));

    float channelCx  = innerX + innerW * 0.5;
    float wallLeftX  = channelCx - halfChan;
    float wallRightX = channelCx + halfChan;

    // Front wall (at the top of the view). 
    // depth=0 -> wall close to the diver (low y, since y increases downward).
    // depth=1 -> wall at the top of the frame.
    float frontWallY = innerY + (1.0 - constrain(depth_in, 0, 1)) * (innerH * 0.6);

    // Walls (solid lines)
    stroke(C_GREEN);
    strokeWeight(2);
    line(wallLeftX,  frontWallY, wallLeftX,  innerY + innerH);
    line(wallRightX, frontWallY, wallRightX, innerY + innerH);
    line(wallLeftX,  frontWallY, wallRightX, frontWallY);

    // Noise pattern (procedural texture for the walls)
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

    // Diver: Centered in the channel, offset laterally by pan_in.
    // pan_in < 0 -> diver moves towards left wall; > 0 -> towards right.
    float diverY = innerY + innerH * 0.7;
    float diverX = channelCx + constrain(pan_in, -1, 1) * (halfChan - 16);
    drawDiver(diverX, diverY);
    strokeWeight(1);
  }

  void drawDiver(float dx, float dy) {
    noStroke();
    
    // Fill color for the arrowhead
    fill(C_HIGHLIGHT); 

    // Draw an upward-pointing arrowhead (cursor style)
    beginShape();
    vertex(dx, dy - 14);       // Top tip
    vertex(dx + 10, dy + 10);  // Bottom right corner
    vertex(dx, dy + 4);        // Bottom center (indentation)
    vertex(dx - 10, dy + 10);  // Bottom left corner
    endShape(CLOSE);
    
    // Optional: a small glowing dot in the center of the arrow
    fill(C_BG);
    ellipse(dx, dy + 2, 4, 4);
  }

  // ---------------------------------------------------------------------------
  // Status Indicators Rendering
  // ---------------------------------------------------------------------------
  void drawLowerStatus(int gx, int gy, int gw, int gh) {
    // Split lower area into 2 rows
    int rowH = gh / 2 - 4;

    // ---- Row 1: BPM pulse (left) + Alarm (right) ----
    int pulseW = (int) (gw * 0.55);
    int alarmW = gw - pulseW - 8;
    drawBpmPulse(gx, gy, pulseW, rowH);
    drawAlarmBox(gx + pulseW + 8, gy, alarmW, rowH);

    // ---- Row 2: Tilt/Speed indicators + Reverb display ----
    int tiltW = pulseW;
    int revW  = alarmW; 
    drawTiltIndicator(gx, gy + rowH + 8, tiltW, rowH);
    drawReverbDisplay(gx + tiltW + 8, gy + rowH + 8, revW, rowH);
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

    // Bright at the beat, fades smoothly
    float intensity = 1.0 - pulsePhase;          
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

    // Coordinates and radius of the LED
    float cx = gx + gw * 0.5;
    float cy = gy + gh * 0.55;
    float r  = min(gw, gh) * 0.22;
    
    noStroke();

    // --- GLOW EFFECT (LUMINESCENCE) ---
    // Activates only when the alarm is triggered (alarm_out == 1)
    if (alarm_out == 1) {
      // Outer glow (large, highly transparent: 20 out of 255)
      fill(C_ALARM, 20); 
      ellipse(cx, cy, r * 2 + 24, r * 2 + 24);
      
      // Inner glow (medium size, semi-transparent: 50 out of 255)
      fill(C_ALARM, 50); 
      ellipse(cx, cy, r * 2 + 12, r * 2 + 12);
    }
    // ----------------------------------

    // Draw the actual solid LED
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
    text("TILT & SPEED", gx + 4, gy + 4);

    // --- SHARED FADER DIMENSIONS ---
    int trackW = 24;
    int trackH = gh - 50; // Extra room for top/bottom labels
    int trackY = gy + 28;

    // Position tracks at ~33% and ~66% of the box width
    int tiltX  = gx + (int)(gw * 0.33) - trackW / 2;
    int speedX = gx + (int)(gw * 0.66) - trackW / 2;

    // ==========================================
    // 1. TILT FADER (Bipolar: 0.0 to 1.0, center 0.5)
    // ==========================================
    noFill();
    stroke(C_GREEN_DARK);
    rect(tiltX, trackY, trackW, trackH);

    float trackCenterY = trackY + trackH * 0.5;
    float tiltVal = constrain(tilt_in, 0, 1);
    float offset = tiltVal - 0.5; 
    
    float tiltFillH = min(abs(offset) * trackH, trackH / 2.0);
    float tiltFillY = (offset > 0) ? (trackCenterY - tiltFillH) : trackCenterY;

    noStroke();
    fill(C_GREEN);
    if (abs(offset) > 0.001) {
       rect(tiltX + 1, tiltFillY, trackW - 2, tiltFillH);
    }

    // Center visual notch
    stroke(C_GREEN_DIM);
    line(tiltX - 6, trackCenterY, tiltX + trackW + 6, trackCenterY);

    // Tilt labels
    fill(C_GREEN_DIM);
    textSize(9);
    textAlign(CENTER, BOTTOM);
    text("TILT", tiltX + trackW / 2, trackY - 4);
    fill(C_TEXT);
    textSize(11);
    text(nf(tilt_in, 0, 3), tiltX + trackW / 2, gy + gh - 4);

    // ==========================================
    // 2. SPEED FADER (Unipolar: 0.0 to 10.0)
    // ==========================================
    noFill();
    stroke(C_GREEN_DARK);
    rect(speedX, trackY, trackW, trackH);

    // Mapping variables
    float maxSpeed = 10.0;
    
    // NOW USES THE ACTIVE CONFIGURATION VALUE FROM CONTROL PANEL
    float alarmThreshold = control.activeAlarmThr; 
    
    float speedVal = constrain(speed_in, 0, maxSpeed);
    float speedFillH = (speedVal / maxSpeed) * trackH;
    float speedFillY = trackY + trackH - speedFillH; // Fills from bottom to top

    // Color logic: Red if alarm is triggered, otherwise Green
    noStroke();
    fill(alarm_out == 1 ? C_ALARM : C_GREEN);
    if (speedFillH > 0) {
      rect(speedX + 1, speedFillY, trackW - 2, speedFillH);
    }

    // Alarm Threshold Marker
    float thresholdY = trackY + trackH - (alarmThreshold / maxSpeed) * trackH;
    stroke(C_ALARM);
    line(speedX - 8, thresholdY, speedX + trackW + 8, thresholdY);

    // Speed labels
    fill(C_GREEN_DIM);
    textSize(9);
    textAlign(CENTER, BOTTOM);
    text("SPD", speedX + trackW / 2, trackY - 4);
    
    fill(C_TEXT);
    textSize(11);
    // Display in red if alarming
    if (alarm_out == 1) fill(C_ALARM); 
    text(nf(speed_in, 0, 1), speedX + trackW / 2, gy + gh - 4);
  }

  void drawReverbDisplay(int gx, int gy, int gw, int gh) {
    noFill();
    stroke(C_GREEN_DARK);
    rect(gx, gy, gw, gh);
    fill(C_GREEN_DIM);
    textSize(10);
    textAlign(LEFT, TOP);
    text("FRONT REVERB", gx + 4, gy + 4);

    // Center and dimensions of the symbol
    float cx = gx + gw / 2.0;
    float cy = gy + gh / 2.0 + 8; // Slightly lowered to leave room for the title
    float radius = min(gw, gh) * 0.28;

    // --- FAUX BLUR LOGIC ---
    float amt = constrain(reverb_out, 0, 1);
    
    // If reverb is low, draw only 1 layer. If high, draw up to 6 "ghost" layers
    int ghostLayers = (int) map(amt, 0, 1, 0, 6);
    
    // Distance of the ghost layers from the center
    float maxSpread = map(amt, 0, 1, 0, 12.0); 

    // 1. Draw blurred shadows behind (only if there is reverb)
    if (ghostLayers > 0) {
      for (int i = 1; i <= ghostLayers; i++) {
        float spread = (i / (float)ghostLayers) * maxSpread;
        float alpha = map(amt, 0, 1, 100, 15); // Opacity decreases as reverb increases
        
        // Draw 6 copies arranged in a circle to simulate optical blur
        for (float angle = 0; angle < TWO_PI; angle += TWO_PI / 6.0) {
          float ox = cos(angle) * spread;
          float oy = sin(angle) * spread;
          drawWarningSymbol(cx + ox, cy + oy, radius, alpha);
        }
      }
    }

    // 2. Draw the base layer at the center
    // Higher reverb makes the center lose focus and become translucent
    float centerAlpha = map(amt, 0, 1, 255, 60);
    drawWarningSymbol(cx, cy, radius, centerAlpha);

    // Numerical text at the bottom
    fill(C_TEXT);
    textSize(11);
    textAlign(CENTER, BOTTOM);
    text(nf(reverb_out, 0, 2), gx + gw / 2, gy + gh - 4);
  }

  // Helper to draw the warning symbol
  void drawWarningSymbol(float x, float y, float r, float alpha) {
    // Orange/amber color (defined in the main palette)
    stroke(C_WARN, alpha);
    strokeWeight(2.5);
    noFill();
    
    // Equilateral triangle inscribed in a circle of radius 'r'
    beginShape();
    vertex(x, y - r);                                // Top tip
    vertex(x + r * 0.866, y + r * 0.5);              // Bottom-right corner
    vertex(x - r * 0.866, y + r * 0.5);              // Bottom-left corner
    endShape(CLOSE);

    // Exclamation mark (vertical line + dot)
    fill(C_WARN, alpha);
    noStroke();
    float lineTop = y - r * 0.3;
    float lineBot = y + r * 0.15;
    float dotY    = y + r * 0.35;
    
    rect(x - 1.5, lineTop, 3, lineBot - lineTop);    // The bar
    ellipse(x, dotY, 4, 4);                          // The dot
  }
}
