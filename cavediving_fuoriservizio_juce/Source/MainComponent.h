#pragma once

#include <JuceHeader.h>

//==============================================================================
/*
    This component lives inside our window, and this is where you should put all
    your controls and content.
*/
class MainComponent  : public juce::Component,
                       public juce::OSCReceiver::Listener<juce::OSCReceiver::MessageLoopCallback>
{
public:
    //==============================================================================
    MainComponent();
    ~MainComponent() override;

    //==============================================================================
    void paint (juce::Graphics&) override;
    void resized() override;

    //==============================================================================
    // OSC callback dispatched on the JUCE message (UI) thread.
    void oscMessageReceived (const juce::OSCMessage& message) override;

private:
    // Latest values seen, for diagnostic display + downstream forwarding.
    // M2: identity passthrough. Real mappings (PAN/BPM derived from L+R, ALERT
    // edge-triggered, PITCH in Hz, etc.) land in M5.
    struct Values
    {
        float front  = 0.0f;
        float left   = 0.0f;
        float right  = 0.0f;
        float accel  = 0.0f;
        int   vario  = 0;

        float reverb = 0.0f;
        float pan    = 0.0f;
        float bpm    = 0.0f;
        float pitch  = 0.0f;
        int   alert  = 0;
    };
    Values values;

    void forwardFloat (const char* addr, float v);
    void forwardInt   (const char* addr, int v);

    juce::OSCReceiver oscReceiver;
    juce::OSCSender   oscSender;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainComponent)
};
