// =============================================================================
// SplashScreen — pre-dive splash.
// Shown until START DIVING is clicked, then the main ControlPanel + DiverHUD
// take over. Holds: title, divider, frontal helmet illustration (PImage tinted
// to the palette green), sensor markers overlaid on the helmet, joystick icon
// centred below the helmet, 5 sensor callouts with L-shaped leaders, START
// DIVING button, and a live OSC status line that flips to "connected" when
// JUCE starts sending /viz/* messages.
// =============================================================================

class SplashScreen {
  int w, h;

  // START DIVING button rect (centered horizontally, fixed y).
  final int BTN_W = 280;
  final int BTN_H = 44;
  int btnX, btnY;

  // Vertical anchors for the static layout (in window pixels).
  final int TITLE_Y      = 50;
  final int DIVIDER_Y    = 100;
  final int STATUS_Y     = 640;

  // Helmet illustration (frontal view, loaded from data/helmet.png at setup).
  // Drawn at the centre of the splash, tinted with the palette green.
  final int HELMET_CX = 640;
  final int HELMET_CY = 320;
  final int HELMET_W  = 320;
  final int HELMET_H  = 320;

  // Sensor marker positions in splash pixels. Derived from positions on the
  // 1024x1024 source image with scale 320/1024 = 0.3125 and offset (480, 160).
  // HCSR04 and MMA are on the two symmetric top cylinders flanking the wedge,
  // so the top-row leaders descend at distinct X (giving the "| |" pattern).
  final int M_HCSR04_X = 571, M_HCSR04_Y = 218;  // left top cylinder
  final int M_GR_L_X   = 539, M_GR_L_Y   = 279;  // left side cuff (visor level)
  final int M_GR_R_X   = 743, M_GR_R_Y   = 279;  // right side cuff
  final int M_MMA_X    = 708, M_MMA_Y    = 218;  // right top cylinder
  final int M_JOY_X    = 640, M_JOY_Y    = 470;  // centred below helmet (pressure proxy)

  // Callout box dimensions.
  final int CB_W = 220;
  final int CB_H = 72;

  SplashScreen(int w, int h) {
    this.w = w;
    this.h = h;
    btnX = (w - BTN_W) / 2;
    btnY = 572;
  }

  void draw() {
    drawTitle();
    drawDivider();
    // Order: callouts (incl. leader lines) -> helmet image -> markers -> joystick.
    // The helmet image painted on top hides leader segments that fall on
    // opaque pixels of the artwork; markers are drawn last so they always
    // sit above both leader and helmet.
    drawCallouts();
    drawHelmet();
    drawMarkers();
    drawJoystickIcon();
    drawStartButton();
    drawStatusLine();
  }

  boolean isStartClicked(int mx, int my) {
    return mx >= btnX && mx <= btnX + BTN_W
        && my >= btnY && my <= btnY + BTN_H;
  }

  // --- private renderers -----------------------------------------------------

  void drawTitle() {
    fill(C_GREEN);
    textSize(32);
    textAlign(CENTER, TOP);
    text("CAVE DIVING CONTROLLER", w / 2, TITLE_Y);
  }

  void drawDivider() {
    stroke(C_GREEN_DARK);
    strokeWeight(1);
    line(w / 2 - 350, DIVIDER_Y, w / 2 + 350, DIVIDER_Y);
  }

  void drawStartButton() {
    boolean hover = isStartClicked(mouseX, mouseY);
    boolean held  = hover && mousePressed;

    strokeWeight(2);
    stroke(C_GREEN);
    if (held)       fill(C_HIGHLIGHT);
    else if (hover) fill(C_GREEN_DARK);
    else            noFill();
    rect(btnX, btnY, BTN_W, BTN_H);

    fill(held ? C_BG : C_GREEN);
    textSize(14);
    textAlign(CENTER, CENTER);
    text("START DIVING", btnX + BTN_W / 2, btnY + BTN_H / 2);
    strokeWeight(1);
  }

  // "Vivente": switches between awaiting-JUCE and connected based on whether
  // /viz/* has arrived in the last second. lastVizOscMs is updated by oscEvent.
  void drawStatusLine() {
    boolean connected = (millis() - lastVizOscMs) < 1000;
    textSize(11);
    textAlign(CENTER, CENTER);

    if (connected) {
      fill(C_HIGHLIGHT);
      text("● JUCE bridge connected — data flowing", w / 2, STATUS_Y);
    } else {
      // Slow global alpha pulse (~0.5 Hz) so the whole line breathes, dot included.
      float pulse = 0.5 + 0.5 * sin(millis() * 0.003);
      float a = lerp(80, 200, pulse);
      fill(C_GREEN_DIM, a);
      text("○ OSC listener 9003 — awaiting JUCE...", w / 2, STATUS_Y);
    }
  }

  // --- helmet diagram + sensor callouts -------------------------------------

  void drawCallouts() {
    // Top row: callouts above the helmet image. Their leaders bend (horizontal
    // then vertical DOWN) into the two symmetric top-cylinder markers, giving
    // the "| |" pattern of two side-by-side descents.
    drawCallout(60, 140,
                "HC-SR04 ultrasonic",
                "/sensor/space/depth",
                "→ bpm",
                M_HCSR04_X, M_HCSR04_Y);

    drawCallout(1000, 140,
                "MMA accel. X",
                "/sensor/position/tilt",
                "→ frequency",
                M_MMA_X, M_MMA_Y);

    // Mid row: callouts at the same Y as the side cuff markers, so the leaders
    // collapse to a single horizontal segment (no vertical bend).
    // Both gravity sensors physically contribute to both streams (pan = L-R,
    // width = (L+R)/2); the callout is split into two so each OSC stream gets
    // its own visible mapping.
    drawCallout(60, 243,
                "Gravity ×2 lateral",
                "/sensor/space/width",
                "→ reverb",
                M_GR_L_X, M_GR_L_Y);

    drawCallout(1000, 243,
                "Gravity ×2 lateral",
                "/sensor/space/pan",
                "→ pan",
                M_GR_R_X, M_GR_R_Y);

    // Bottom: leader leaves the centred joystick icon straight DOWN, then bends
    // RIGHT to the bottom-right callout. The joystick stands in for a real
    // barometer measuring ascent rate (pressure variation); demo proxy as we
    // have no pressure sensor in the prototype.
    drawCallout(1000, 490,
                "Joystick (pressure proxy)",
                "/sensor/position/speed",
                "→ alarm gate",
                M_JOY_X, M_JOY_Y);
  }

  // Single callout: box + 3-line text + L-shaped leader to the marker.
  // The leader anchor (box edge) auto-picks the side closer to the marker.
  void drawCallout(int boxX, int boxY,
                   String line1, String line2, String line3,
                   int markerX, int markerY) {
    // Box outline
    noFill();
    stroke(C_GREEN_DIM);
    strokeWeight(1);
    rect(boxX, boxY, CB_W, CB_H);

    // 3 text lines: hardware name (bright), OSC address (dim), mapping (highlight)
    int textX = boxX + 10;
    textAlign(LEFT, TOP);
    fill(C_TEXT);     textSize(12); text(line1, textX, boxY + 10);
    fill(C_GREEN_DIM); textSize(10); text(line2, textX, boxY + 30);
    fill(C_HIGHLIGHT); textSize(10); text(line3, textX, boxY + 48);

    // L-shaped leader: horizontal then vertical, single bend.
    int boxCenterX = boxX + CB_W / 2;
    int anchorX = (markerX > boxCenterX) ? (boxX + CB_W) : boxX;
    int anchorY = boxY + CB_H / 2;
    stroke(C_GREEN_DIM);
    strokeWeight(1);
    line(anchorX, anchorY, markerX, anchorY);
    line(markerX, anchorY, markerX, markerY);
  }

  void drawHelmet() {
    // Frontal helmet illustration. White-on-transparent PNG tinted with the
    // palette green; falls back to nothing if loadImage failed (file missing).
    if (helmetImg == null) return;
    tint(C_GREEN_DIM);
    imageMode(CENTER);
    image(helmetImg, HELMET_CX, HELMET_CY, HELMET_W, HELMET_H);
    noTint();
    imageMode(CORNER);
  }

  void drawMarkers() {
    // 3 dots (HCSR04, GR L, GR R) in the same style.
    noStroke();
    fill(C_GREEN);
    ellipse(M_HCSR04_X, M_HCSR04_Y, 8, 8);
    ellipse(M_GR_L_X,   M_GR_L_Y,   8, 8);
    ellipse(M_GR_R_X,   M_GR_R_Y,   8, 8);

    // MMA as a small diamond — different shape signals a different sensor
    // type (orientation, not distance) without needing a label.
    int dR = 5;
    beginShape();
    vertex(M_MMA_X,      M_MMA_Y - dR);
    vertex(M_MMA_X + dR, M_MMA_Y     );
    vertex(M_MMA_X,      M_MMA_Y + dR);
    vertex(M_MMA_X - dR, M_MMA_Y     );
    endShape(CLOSE);
  }

  void drawJoystickIcon() {
    // Stylized top-down joystick: base ring + filled knob.
    noFill();
    stroke(C_GREEN_DIM);
    strokeWeight(1);
    ellipse(M_JOY_X, M_JOY_Y, 36, 36);
    noStroke();
    fill(C_GREEN);
    ellipse(M_JOY_X, M_JOY_Y, 14, 14);
  }
}
