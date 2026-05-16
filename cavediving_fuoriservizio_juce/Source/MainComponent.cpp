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

    setSize (520, 360);
}

MainComponent::~MainComponent()
{
    oscReceiver.removeListener (this);
    oscReceiver.disconnect();
    oscSender.disconnect();
}

//======================= GRAPHICS SECTION ==========================================
void MainComponent::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colours::darkgrey);

    g.setColour (juce::Colours::white);
    g.setFont (16.0f);
    g.drawText ("M2 - identity forward (in 9001 -> out 57120)",
                10, 10, getWidth() - 20, 24, juce::Justification::centredLeft);

    g.setFont (14.0f);

    const int colW = getWidth() / 2;
    const int rowH = 24;
    const int top  = 50;

    g.setColour (juce::Colours::lightblue);
    g.drawText ("INPUTS (port 9001)",    10,         top, colW - 20, rowH, juce::Justification::centredLeft);
    g.drawText ("OUTPUTS (port 57120)",  colW + 10,  top, colW - 20, rowH, juce::Justification::centredLeft);

    g.setColour (juce::Colours::white);

    int y = top + rowH + 10;
    g.drawText (juce::String ("front:  ") + juce::String (values.front,  3),  10,        y, colW - 20, rowH, juce::Justification::centredLeft);
    g.drawText (juce::String ("reverb: ") + juce::String (values.reverb, 3),  colW + 10, y, colW - 20, rowH, juce::Justification::centredLeft);
    y += rowH;
    g.drawText (juce::String ("left:   ") + juce::String (values.left,   3),  10,        y, colW - 20, rowH, juce::Justification::centredLeft);
    g.drawText (juce::String ("pan:    ") + juce::String (values.pan,    3),  colW + 10, y, colW - 20, rowH, juce::Justification::centredLeft);
    y += rowH;
    g.drawText (juce::String ("right:  ") + juce::String (values.right,  3),  10,        y, colW - 20, rowH, juce::Justification::centredLeft);
    g.drawText (juce::String ("bpm:    ") + juce::String (values.bpm,    3),  colW + 10, y, colW - 20, rowH, juce::Justification::centredLeft);
    y += rowH;
    g.drawText (juce::String ("accel:  ") + juce::String (values.accel,  3),  10,        y, colW - 20, rowH, juce::Justification::centredLeft);
    g.drawText (juce::String ("pitch:  ") + juce::String (values.pitch,  3),  colW + 10, y, colW - 20, rowH, juce::Justification::centredLeft);
    y += rowH;
    g.drawText (juce::String ("vario:  ") + juce::String (values.vario),      10,        y, colW - 20, rowH, juce::Justification::centredLeft);
    g.drawText (juce::String ("alert:  ") + juce::String (values.alert),      colW + 10, y, colW - 20, rowH, juce::Justification::centredLeft);
}

void MainComponent::resized()
{
    // coordinates for component layout
}

//======================== OSC DATA HANDLING & PROCESSING ======================================================
// Called automatically when an OSC message arrives (dispatched on the message/UI thread).
void MainComponent::oscMessageReceived (const juce::OSCMessage& message)
{
    if (message.size() != 1)
        return;

    const auto addr = message.getAddressPattern();

    if (addr == "/in/sonar/front" && message[0].isFloat32())
    {
        values.front  = message[0].getFloat32();
        values.reverb = values.front;                  // M2 identity; M5 will replace with real curve
        forwardFloat ("/out/reverb", values.reverb);
    }
    else if (addr == "/in/sonar/left" && message[0].isFloat32())
    {
        values.left = message[0].getFloat32();
        values.pan  = values.left;                     // M2 identity; M5: pan = L - R
        forwardFloat ("/out/pan", values.pan);
    }
    else if (addr == "/in/sonar/right" && message[0].isFloat32())
    {
        values.right = message[0].getFloat32();
        values.bpm   = values.right;                   // M2 identity; M5: bpm = f(min(L, R))
        forwardFloat ("/out/bpm", values.bpm);
    }
    else if (addr == "/in/accel" && message[0].isFloat32())
    {
        values.accel = message[0].getFloat32();
        values.pitch = values.accel;                   // M2 identity; M5: pitch in Hz
        forwardFloat ("/out/pitch", values.pitch);
    }
    else if (addr == "/in/vario" && message[0].isInt32())
    {
        values.vario = message[0].getInt32();
        values.alert = values.vario;                   // M2 identity; M5: alert = (vario > threshold) ? 1 : 0, edge-triggered
        forwardInt ("/out/alert", values.alert);
    }
    else
    {
        return; // unknown address or wrong type — don't repaint
    }

    repaint();
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
