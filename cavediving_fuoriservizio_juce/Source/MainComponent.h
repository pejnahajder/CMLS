#pragma once

#include <JuceHeader.h>
#include <atomic>

//==============================================================================
/*
    This component lives inside our window, and this is where you should put all
    your controls and content.

    M4 architecture:
      OSC in  ───┐
                 ├─►  std::atomic Inputs  ──►  Timer @30Hz  ──►  Outputs  ──►  OSC to SC
      Slider ────┘                                            └────────►  repaint()

    Both OSC handler and slider callbacks write to atomic inputs. The Timer reads
    them at 30 Hz, applies the mapping (identity for M4, real formulas in M5),
    and sends to SC. This decouples input rate from output rate and gives a
    single canonical place for the mapping logic.
*/
class MainComponent  : public juce::Component,
                       public juce::OSCReceiver::Listener<juce::OSCReceiver::MessageLoopCallback>,
                       private juce::Timer
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
    //==============================================================================
    // 30 Hz mapping + send loop.
    void timerCallback() override;

    void applyMappingAndSend();
    void sendOutputs();
    void forwardFloat (const char* addr, float v);
    void forwardInt   (const char* addr, int v);

    void onManualToggleChanged();
    void updateSliderEnablement();

    // Raw input state. Written by OSC handler (in OSC mode) or by slider callbacks
    // (in Manual mode); read by the Timer. Atomic for future-proofing — today all
    // accesses happen on the message thread thanks to MessageLoopCallback.
    struct Inputs
    {
        std::atomic<float> front { 0.5f };
        std::atomic<float> left  { 0.5f };
        std::atomic<float> right { 0.5f };
        std::atomic<float> accel { 0.5f };
        std::atomic<int>   vario { 0 };
    };
    Inputs inputs;

    // Computed output state. Written only by the Timer, read by paint(). Both run
    // on the message thread, no atomic needed.
    struct Outputs
    {
        float reverb = 0.0f;
        float pan    = 0.0f;
        float bpm    = 0.0f;
        float pitch  = 0.0f;
        int   alert  = 0;
    };
    Outputs outputs;

    std::atomic<bool> manualMode { false };
    std::atomic<bool> sendToSC   { true  };

    juce::Slider sliderFront, sliderLeft, sliderRight, sliderAccel, sliderVario;
    juce::Label  lblFront,    lblLeft,    lblRight,    lblAccel,    lblVario;
    juce::ToggleButton btnManual { "Manual mode" };
    juce::ToggleButton btnSendSC { "Send to SC" };

    juce::OSCReceiver oscReceiver;
    juce::OSCSender   oscSender;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainComponent)
};
