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

    setSize (400, 300);
}

MainComponent::~MainComponent()
{
    // close OSC connections
    oscReceiver.removeListener (this);
    oscReceiver.disconnect();
    oscSender.disconnect();
}

//======================= GRAPHICS SECTION ==========================================
void MainComponent::paint (juce::Graphics& g)
{
    // dark gray background
    g.fillAll (juce::Colours::darkgrey);

    // white text in the center
    g.setColour (juce::Colours::white);
    g.setFont (20.0f);
    g.drawText ("Sensors Controller (OSC) active, listening on port 9001", getLocalBounds(),
                juce::Justification::centred, true);
}

void MainComponent::resized()
{
    // coordinates for component layout
}

//======================== OSC DATA HANDLING & PROCESSING ======================================================
// this function is called automatically when an OSC message is received
void MainComponent::oscMessageReceived (const juce::OSCMessage& message)
{ 
    // HYPOTHESIS FOR NOW. receiving from "/sensor/1"
    if (message.getAddressPattern() == "/sensor/1")
    {
        // ensure we are getting a float value
        if (message.size() == 1 && message[0].isFloat32())
        {
            float sensorValue = message[0].getFloat32();
            
            // signals mapping 
            //...
            
            float mappedValue = 0.0f; // placeholder to avoid compilation errors
            
            // send the value to SuperCollider
            juce::OSCMessage messageForSC ("/synth/param");
            messageForSC.addFloat32 (mappedValue);
            oscSender.send (messageForSC);
        }
    }
}