// =============================================================================
// SplashScreen — pre-dive splash.
// Shown until START DIVING is clicked, then the main ControlPanel + DiverHUD
// take over. This skeleton holds title, divider, button and a live OSC status
// line; the helmet diagram and sensor callouts are added on top later.
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
  final int STATUS_Y     = 690;

  SplashScreen(int w, int h) {
    this.w = w;
    this.h = h;
    btnX = (w - BTN_W) / 2;
    btnY = 622;
  }

  void draw() {
    drawTitle();
    drawDivider();
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
}
