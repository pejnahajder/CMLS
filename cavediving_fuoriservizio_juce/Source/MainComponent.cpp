#include "MainComponent.h"

//======================= INITIALIZATION & TEARDOWN =======================================================
MainComponent::MainComponent()
{
    // listen to OSC messages (on port 9001)
    if (! oscReceiver.connect (9001))
        juce::Logger::writeToLog ("Error: Could not connect OSC Receiver to port 9001");
    else
        juce::Logger::writeToLog ("OSC Receiver connected to port 9001");

    oscReceiver.addListener (this);

    // transmit to SC (port 57120)
    if (! oscSender.connect ("127.0.0.1", 57120))
        juce::Logger::writeToLog ("Error: Could not connect OSC Sender to port 57120");

    // --- Float sliders [0, 1] ---
    auto setupFloatSlider = [this] (juce::Slider& s, juce::Label& lbl, const juce::String& name,
                                    std::atomic<float>& target)
    {
        lbl.setText (name, juce::dontSendNotification);
        lbl.setJustificationType (juce::Justification::centredRight);

        s.setRange (0.0, 1.0, 0.0);
        s.setValue (target.load(), juce::dontSendNotification);
        s.setSliderStyle (juce::Slider::LinearHorizontal);
        s.setTextBoxStyle (juce::Slider::TextBoxRight, true /*readOnly*/, 60, 22);
        s.onValueChange = [&] { target = (float) s.getValue(); };

        addAndMakeVisible (s);
        addAndMakeVisible (lbl);
    };

    // --- Int slider (vario) ---
    auto setupIntSlider = [this] (juce::Slider& s, juce::Label& lbl, const juce::String& name,
                                  std::atomic<int>& target, double min, double max)
    {
        lbl.setText (name, juce::dontSendNotification);
        lbl.setJustificationType (juce::Justification::centredRight);

        s.setRange (min, max, 1.0);
        s.setValue ((double) target.load(), juce::dontSendNotification);
        s.setSliderStyle (juce::Slider::LinearHorizontal);
        s.setTextBoxStyle (juce::Slider::TextBoxRight, true, 60, 22);
        s.onValueChange = [&] { target = (int) s.getValue(); };

        addAndMakeVisible (s);
        addAndMakeVisible (lbl);
    };

    setupFloatSlider (sliderFront, lblFront, "front",  inputs.front);
    setupFloatSlider (sliderLeft,  lblLeft,  "left",   inputs.left);
    setupFloatSlider (sliderRight, lblRight, "right",  inputs.right);
    setupFloatSlider (sliderAccel, lblAccel, "accel",  inputs.accel);
    setupIntSlider   (sliderVario, lblVario, "vario",  inputs.vario, -10.0, 10.0);

    // --- Toggles ---
    btnManual.setToggleState (false, juce::dontSendNotification);
    btnManual.onClick = [this] { onManualToggleChanged(); };
    addAndMakeVisible (btnManual);

    btnSendSC.setToggleState (true, juce::dontSendNotification);
    btnSendSC.onClick = [this] { sendToSC = btnSendSC.getToggleState(); };
    addAndMakeVisible (btnSendSC);

    updateSliderEnablement();

    setSize (560, 500);

    // 30 Hz mapping + send + repaint loop
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
    sliderFront.setEnabled (enabled);
    sliderLeft .setEnabled (enabled);
    sliderRight.setEnabled (enabled);
    sliderAccel.setEnabled (enabled);
    sliderVario.setEnabled (enabled);
}

//======================= GRAPHICS SECTION ==========================================
void MainComponent::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colours::darkgrey);

    g.setColour (juce::Colours::white);
    g.setFont (16.0f);
    g.drawText ("M4 - dev sliders + Manual/OSC + Send-to-SC toggle",
                10, 10, getWidth() - 20, 24, juce::Justification::centredLeft);

    g.setFont (14.0f);

    const int colW = getWidth() / 2;
    const int rowH = 22;
    const int top  = 44;

    g.setColour (juce::Colours::lightblue);
    g.drawText ("INPUTS (port 9001)",    10,         top, colW - 20, rowH, juce::Justification::centredLeft);
    g.drawText ("OUTPUTS (port 57120)",  colW + 10,  top, colW - 20, rowH, juce::Justification::centredLeft);

    g.setColour (juce::Colours::white);

    int y = top + rowH + 4;
    auto row = [&] (const juce::String& inText, const juce::String& outText)
    {
        g.drawText (inText,  10,        y, colW - 20, rowH, juce::Justification::centredLeft);
        g.drawText (outText, colW + 10, y, colW - 20, rowH, juce::Justification::centredLeft);
        y += rowH;
    };
    row ("front:  " + juce::String (inputs.front.load(), 3),  "reverb: " + juce::String (outputs.reverb, 3));
    row ("left:   " + juce::String (inputs.left.load(),  3),  "pan:    " + juce::String (outputs.pan,    3));
    row ("right:  " + juce::String (inputs.right.load(), 3),  "bpm:    " + juce::String (outputs.bpm,    3));
    row ("accel:  " + juce::String (inputs.accel.load(), 3),  "pitch:  " + juce::String (outputs.pitch,  3));
    row ("vario:  " + juce::String (inputs.vario.load()),     "alert:  " + juce::String (outputs.alert));
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

    // Sliders with their labels on the left
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
    place (sliderFront, lblFront);
    place (sliderLeft,  lblLeft);
    place (sliderRight, lblRight);
    place (sliderAccel, lblAccel);
    place (sliderVario, lblVario);
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
        s.setValue (v, juce::dontSendNotification); // mirror in slider, do not re-trigger callback
    };

    if      (addr == "/in/sonar/front" && message[0].isFloat32()) applyFloat (inputs.front, sliderFront);
    else if (addr == "/in/sonar/left"  && message[0].isFloat32()) applyFloat (inputs.left,  sliderLeft);
    else if (addr == "/in/sonar/right" && message[0].isFloat32()) applyFloat (inputs.right, sliderRight);
    else if (addr == "/in/accel"       && message[0].isFloat32()) applyFloat (inputs.accel, sliderAccel);
    else if (addr == "/in/vario"       && message[0].isInt32())
    {
        const int v = message[0].getInt32();
        inputs.vario = v;
        sliderVario.setValue ((double) v, juce::dontSendNotification);
    }
    // unknown address or wrong type: drop silently
}

void MainComponent::timerCallback()
{
    applyMappingAndSend();
    repaint();
}

void MainComponent::applyMappingAndSend()
{
    // Identity mapping for M4. Real curves (PAN/BPM from L+R, ALERT edge-triggered,
    // PITCH in Hz, etc.) land in M5.
    outputs.reverb = inputs.front.load();
    outputs.pan    = inputs.left.load();
    outputs.bpm    = inputs.right.load();
    outputs.pitch  = inputs.accel.load();
    outputs.alert  = inputs.vario.load();

    sendOutputs();
}

void MainComponent::sendOutputs()
{
    if (! sendToSC.load())
        return;

    forwardFloat ("/out/reverb", outputs.reverb);
    forwardFloat ("/out/pan",    outputs.pan);
    forwardFloat ("/out/bpm",    outputs.bpm);
    forwardFloat ("/out/pitch",  outputs.pitch);
    forwardInt   ("/out/alert",  outputs.alert);
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
