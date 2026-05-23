#include "MainComponent.h"
#include <algorithm>   // std::clamp
#include <cmath>       // std::isfinite

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

    // Listen for /cfg/apply from the Processing UI on port 9002.
    if (! oscReceiverCfg.connect (9002))
        juce::Logger::writeToLog ("Error: Could not connect Config OSC Receiver to port 9002");
    else
        juce::Logger::writeToLog ("Config OSC Receiver connected to port 9002");

    oscReceiverCfg.addListener (this);

    // Transmit to SC (sclang, default port 57120).
    if (! oscSender.connect ("127.0.0.1", 57120))
        juce::Logger::writeToLog ("Error: Could not connect OSC Sender to port 57120");

    // Transmit to the Processing UI on 9003 (live monitoring of inputs + outputs).
    if (! oscSenderViz.connect ("127.0.0.1", 9003))
        juce::Logger::writeToLog ("Error: Could not connect viz OSC Sender to port 9003");

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
    oscReceiverCfg.removeListener (this);
    oscReceiverCfg.disconnect();
    oscSender.disconnect();
    oscSenderViz.disconnect();
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
    g.drawText ("Cave Diving Controller - OSC in 9000+9002 / out 57120+9003",
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
// Called on the message/UI thread for any OSC message arriving on either receiver.
// Address-based dispatch:
//   /cfg/apply        -> Config (Processing on 9002), unconditional.
//   /sensor/...       -> Inputs + slider mirror (Arduino on 9000), ignored in Manual mode.
void MainComponent::oscMessageReceived (const juce::OSCMessage& message)
{
    const auto addr = message.getAddressPattern();

    // Configuration from Processing — bundled 5-float message. Applied unconditionally
    // (not gated by Manual mode: the config drives the mapping regardless of input source).
    if (addr == "/cfg/apply")
    {
        if (message.size() != 5)
            return;
        for (int i = 0; i < 5; ++i)
            if (! message[i].isFloat32())
                return;

        const float v0 = message[0].getFloat32();
        const float v1 = message[1].getFloat32();
        const float v2 = message[2].getFloat32();
        const float v3 = message[3].getFloat32();
        const float v4 = message[4].getFloat32();

        if (! std::isfinite (v0) || ! std::isfinite (v1) || ! std::isfinite (v2)
         || ! std::isfinite (v3) || ! std::isfinite (v4))
            return;

        config.bpmMin   = v0;
        config.bpmMax   = v1;
        config.freqMin  = v2;
        config.freqMax  = v3;
        config.alarmThr = v4;

        juce::Logger::writeToLog ("/cfg/apply: bpm=[" + juce::String (v0, 1) + ", " + juce::String (v1, 1)
                                 + "] freq=[" + juce::String (v2, 0) + ", " + juce::String (v3, 0)
                                 + "] alarmThr=" + juce::String (v4, 2));
        return;
    }

    // Sensor streams from Arduino — Manual mode silences the network in favour of sliders.
    if (manualMode.load())
        return;

    if (message.size() != 1)
        return;

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
    sendVizSnapshot();
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

    // BPM: accelerates as the channel narrows. Range from Config (default [40, 200]).
    // No defensive clamp on the result: lerp with frac in [0, 1] already stays inside
    // [min(lo,hi), max(lo,hi)], so user-inverted ranges (bpmMin > bpmMax) reverse the
    // mapping but never produce out-of-bounds output.
    const float widthClamped = std::clamp (widthIn, 0.0f, 1.0f);
    const float bpmLo = config.bpmMin.load();
    const float bpmHi = config.bpmMax.load();
    outputs.bpm = bpmLo + (1.0f - widthClamped) * (bpmHi - bpmLo);

    // FREQ: lerp(freqMin, freqMax, tilt) in Hz. Range from Config (default [80, 800]).
    // ASSUMPTION: tilt neutral ~0.5 (head horizontal), to be verified at first board test.
    const float tiltClamped = std::clamp (tiltIn, 0.0f, 1.0f);
    const float freqLo = config.freqMin.load();
    const float freqHi = config.freqMax.load();
    outputs.freq = freqLo + tiltClamped * (freqHi - freqLo);

    // ALARM: gate triggered when joystick speed exceeds threshold (from Config, default 3.0).
    // Conceptually the source is a barometer-delta (rapid ascent → embolism risk); the joystick
    // is the demo proxy. Edge-triggered downstream in sendOutputs().
    outputs.alarm = (speedIn > config.alarmThr.load()) ? 1 : 0;

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

void MainComponent::sendVizSnapshot()
{
    // Live monitoring stream to the Processing UI. Not gated by sendToSC: the
    // UI should keep moving even when the synth output is silenced.
    sendVizFloat ("/viz/in/pan",    inputs.pan  .load());
    sendVizFloat ("/viz/in/width",  inputs.width.load());
    sendVizFloat ("/viz/in/depth",  inputs.depth.load());
    sendVizFloat ("/viz/in/tilt",   inputs.tilt .load());
    sendVizFloat ("/viz/in/speed",  inputs.speed.load());

    sendVizFloat ("/viz/out/reverb", outputs.reverb);
    sendVizFloat ("/viz/out/pan",    outputs.pan);
    sendVizFloat ("/viz/out/bpm",    outputs.bpm);
    sendVizFloat ("/viz/out/freq",   outputs.freq);
    sendVizInt   ("/viz/out/alarm",  outputs.alarm);
}

void MainComponent::sendVizFloat (const char* addr, float v)
{
    juce::OSCMessage msg (addr);
    msg.addFloat32 (v);
    oscSenderViz.send (msg);
}

void MainComponent::sendVizInt (const char* addr, int v)
{
    juce::OSCMessage msg (addr);
    msg.addInt32 (v);
    oscSenderViz.send (msg);
}
