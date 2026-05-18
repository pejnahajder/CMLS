#include "MainComponent.h"
#include <algorithm>   // std::clamp

//======================= INITIALIZATION & TEARDOWN =======================================================
MainComponent::MainComponent()
{
    // Listen for OSC from the Arduino MKR (in AP mode, sends to 192.168.4.2:9000).
    // Bound to 0.0.0.0 so it also accepts localhost from the fake tools.
    if (! oscReceiver.connect (9000))
        juce::Logger::writeToLog ("Error: Could not connect OSC Receiver to port 9000");
    else
        juce::Logger::writeToLog ("OSC Receiver connected to port 9000");

    oscReceiver.addListener (this);

    // Transmit to SC (sclang, default port 57120).
    if (! oscSender.connect ("127.0.0.1", 57120))
        juce::Logger::writeToLog ("Error: Could not connect OSC Sender to port 57120");

    // --- Sliders (5 floats, with three different ranges) ---
    auto setupSlider = [this] (juce::Slider& s, juce::Label& lbl, const juce::String& name,
                               std::atomic<float>& target,
                               double rangeMin, double rangeMax, double step)
    {
        lbl.setText (name, juce::dontSendNotification);
        lbl.setJustificationType (juce::Justification::centredRight);

        s.setRange (rangeMin, rangeMax, step);
        s.setValue ((double) target.load(), juce::dontSendNotification);
        s.setSliderStyle (juce::Slider::LinearHorizontal);
        s.setTextBoxStyle (juce::Slider::TextBoxRight, true /*readOnly*/, 60, 22);
        s.onValueChange = [&] { target = (float) s.getValue(); };

        addAndMakeVisible (s);
        addAndMakeVisible (lbl);
    };

    setupSlider (sliderPan,   lblPan,   "pan",   inputs.pan,   -1.0, 1.0, 0.0);
    setupSlider (sliderWidth, lblWidth, "width", inputs.width,  0.0, 1.0, 0.0);
    setupSlider (sliderDepth, lblDepth, "depth", inputs.depth,  0.0, 1.0, 0.0);
    setupSlider (sliderTilt,  lblTilt,  "tilt",  inputs.tilt,   0.0, 1.0, 0.0);
    setupSlider (sliderSpeed, lblSpeed, "speed", inputs.speed,  0.0, 10.0, 0.5);

    // --- Toggles ---
    btnManual.setToggleState (false, juce::dontSendNotification);
    btnManual.onClick = [this] { onManualToggleChanged(); };
    addAndMakeVisible (btnManual);

    btnSendSC.setToggleState (true, juce::dontSendNotification);
    btnSendSC.onClick = [this] { sendToSC = btnSendSC.getToggleState(); };
    addAndMakeVisible (btnSendSC);

    updateSliderEnablement();

    setSize (560, 500);

    // 30 Hz mapping + send + repaint loop.
    startTimerHz (30);
}

MainComponent::~MainComponent()
{
    stopTimer();
    oscReceiver.removeListener (this);
    oscReceiver.disconnect();
    oscSender.disconnect();
}

void MainComponent::onManualToggleChanged()
{
    manualMode = btnManual.getToggleState();
    updateSliderEnablement();
}

void MainComponent::updateSliderEnablement()
{
    const bool enabled = manualMode.load();
    sliderPan  .setEnabled (enabled);
    sliderWidth.setEnabled (enabled);
    sliderDepth.setEnabled (enabled);
    sliderTilt .setEnabled (enabled);
    sliderSpeed.setEnabled (enabled);
}

//======================= GRAPHICS SECTION ==========================================
void MainComponent::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colours::darkgrey);

    g.setColour (juce::Colours::white);
    g.setFont (16.0f);
    g.drawText ("Cave Diving Controller - OSC in 9000 / out 57120",
                10, 10, getWidth() - 20, 24, juce::Justification::centredLeft);

    g.setFont (14.0f);

    const int colW = getWidth() / 2;
    const int rowH = 22;
    const int top  = 44;

    g.setColour (juce::Colours::lightblue);
    g.drawText ("INPUTS (from Arduino, /sensor/...)",    10,         top, colW - 20, rowH, juce::Justification::centredLeft);
    g.drawText ("OUTPUTS (to SC, /synth/... + /alarm/gate)",  colW + 10,  top, colW - 20, rowH, juce::Justification::centredLeft);

    g.setColour (juce::Colours::white);

    int y = top + rowH + 4;
    auto row = [&] (const juce::String& inText, const juce::String& outText)
    {
        g.drawText (inText,  10,        y, colW - 20, rowH, juce::Justification::centredLeft);
        g.drawText (outText, colW + 10, y, colW - 20, rowH, juce::Justification::centredLeft);
        y += rowH;
    };
    row ("pan:    " + juce::String (inputs.pan.load(),   3),  "reverb: " + juce::String (outputs.reverb, 3));
    row ("width:  " + juce::String (inputs.width.load(), 3),  "pan:    " + juce::String (outputs.pan,    3));
    row ("depth:  " + juce::String (inputs.depth.load(), 3),  "bpm:    " + juce::String (outputs.bpm,    2));
    row ("tilt:   " + juce::String (inputs.tilt.load(),  3),  "freq:   " + juce::String (outputs.freq,   2));
    row ("speed:  " + juce::String (inputs.speed.load(), 2),  "alarm:  " + juce::String (outputs.alarm));
}

void MainComponent::resized()
{
    const int margin = 10;
    const int rowH   = 22;

    // The diagnostic table is paint-drawn — leave space for it.
    int y = 44 + rowH + 4 + rowH * 5 + 12;

    // Toggle buttons row
    btnManual.setBounds (margin,        y, 130, 26);
    btnSendSC.setBounds (margin + 140,  y, 130, 26);
    y += 26 + 10;

    // Sliders with their labels on the left.
    const int labelW   = 60;
    const int sliderH  = 28;
    const int sliderX  = margin + labelW + 4;
    const int sliderW  = getWidth() - margin - sliderX;

    auto place = [&] (juce::Slider& s, juce::Label& lbl)
    {
        lbl.setBounds (margin, y, labelW, sliderH);
        s.setBounds   (sliderX, y, sliderW, sliderH);
        y += sliderH + 4;
    };
    place (sliderPan,   lblPan);
    place (sliderWidth, lblWidth);
    place (sliderDepth, lblDepth);
    place (sliderTilt,  lblTilt);
    place (sliderSpeed, lblSpeed);
}

//======================== OSC DATA HANDLING & PROCESSING ======================================================
// Called when an OSC message arrives (dispatched on the message/UI thread).
// In OSC mode: update atomic input + mirror in the slider (read-only display).
// In Manual mode: ignore network input.
void MainComponent::oscMessageReceived (const juce::OSCMessage& message)
{
    if (manualMode.load())
        return;

    if (message.size() != 1)
        return;

    const auto addr = message.getAddressPattern();

    auto applyFloat = [&] (std::atomic<float>& target, juce::Slider& s)
    {
        const float v = message[0].getFloat32();
        target = v;
        s.setValue ((double) v, juce::dontSendNotification); // mirror, do not re-trigger onValueChange
    };

    if      (addr == "/sensor/space/pan"      && message[0].isFloat32()) applyFloat (inputs.pan,   sliderPan);
    else if (addr == "/sensor/space/width"    && message[0].isFloat32()) applyFloat (inputs.width, sliderWidth);
    else if (addr == "/sensor/space/depth"    && message[0].isFloat32()) applyFloat (inputs.depth, sliderDepth);
    else if (addr == "/sensor/position/tilt"  && message[0].isFloat32()) applyFloat (inputs.tilt,  sliderTilt);
    else if (addr == "/sensor/position/speed" && message[0].isFloat32()) applyFloat (inputs.speed, sliderSpeed);
    // unknown address or wrong type: drop silently
}

void MainComponent::timerCallback()
{
    applyMappingAndSend();
    repaint();
}

void MainComponent::applyMappingAndSend()
{
    // Take a consistent snapshot of the atomic inputs.
    const float panIn   = inputs.pan  .load();
    const float widthIn = inputs.width.load();
    const float depthIn = inputs.depth.load();
    const float tiltIn  = inputs.tilt .load();
    const float speedIn = inputs.speed.load();

    // ASSUMPTION (confirmed reading Arduino's clampAndNormalizeDistance):
    // 0 = wall close, 1 = max distance. So depth=0 -> dry reverb (claustrophobia
    // feel), depth=1 -> wet (open space). Sign convention coherent across all.

    // REVERB <- depth, linear in [0, 1].
    outputs.reverb = std::clamp (depthIn, 0.0f, 1.0f);

    // PAN: identity passthrough. Arduino has already computed
    // gravity1 - gravity2 in [-1, +1], so we just clamp defensively.
    outputs.pan = std::clamp (panIn, -1.0f, 1.0f);

    // BPM: accelerates as the channel narrows. Arduino has already computed
    // width = (gravity1 + gravity2) / 2 in [0, 1] -- 0 = both walls close.
    outputs.bpm = std::clamp (40.0f + (1.0f - widthIn) * 160.0f, 40.0f, 200.0f);

    // FREQ: lerp(80, 800, tilt) in Hz. ASSUMPTION: tilt neutral ~0.5 (head
    // horizontal), to be verified at first board test (M9).
    const float tiltClamped = std::clamp (tiltIn, 0.0f, 1.0f);
    outputs.freq = 80.0f + tiltClamped * (800.0f - 80.0f);

    // ALARM: gate triggered when joystick speed exceeds threshold.
    // ASSUMPTION: threshold 3.0f catches 3 of 4 joystick directions (skips
    // "light right" = 2.5). Edge-triggered in sendOutputs().
    constexpr float ALARM_THRESHOLD = 3.0f;
    outputs.alarm = (speedIn > ALARM_THRESHOLD) ? 1 : 0;

    sendOutputs();
}

void MainComponent::sendOutputs()
{
    if (! sendToSC.load())
        return;

    // Continuous control parameters: forwarded every Timer tick (~25 Hz on Windows).
    forwardFloat ("/synth/reverb", outputs.reverb);
    forwardFloat ("/synth/pan",    outputs.pan);
    forwardFloat ("/synth/bpm",    outputs.bpm);
    forwardFloat ("/synth/freq",   outputs.freq);

    // ALARM gate: event semantics, forward only on transitions. The -1 sentinel
    // forces the first send so SC starts with a known state.
    if (outputs.alarm != lastAlarmSent)
    {
        forwardInt ("/alarm/gate", outputs.alarm);
        lastAlarmSent = outputs.alarm;
    }
}

void MainComponent::forwardFloat (const char* addr, float v)
{
    juce::OSCMessage msg (addr);
    msg.addFloat32 (v);
    oscSender.send (msg);
}

void MainComponent::forwardInt (const char* addr, int v)
{
    juce::OSCMessage msg (addr);
    msg.addInt32 (v);
    oscSender.send (msg);
}
