#pragma once

#include <JuceHeader.h>
#include <atomic>

//==============================================================================
/*
    Cave Diving Controller — JUCE engine.

    Data flow:

      Arduino MKR ──UDP:9000──► Inputs ─┐                                      ┌─► /beep/*, /alarm/gate  ──► SC          :57120
                                         │  Timer @30Hz                        │
      5 dev sliders (Manual mode) ──────►├──────────────► applyMappingAndSend ─┤
                                         │                                     │
      Processing UI ──UDP:9002 /cfg─────► Config                               └─► /viz/in/*, /viz/out/*  ──► Processing  :9003

    Input contract (from Arduino, branch `arduino`):
      /sensor/space/pan        float [-1, +1]   (already cooked = gravity1 - gravity2)
      /sensor/space/width      float [0, 1]     (already cooked = (gravity1 + gravity2) / 2)
      /sensor/space/depth      float [0, 1]     (HCSR04, 0 = wall close, 1 = far)
      /sensor/position/tilt    float [0, 1]     (MMA accel X normalised, neutral ~0.5)
      /sensor/position/speed   float            (joystick, discrete {0, 2.5, 5, 7.5, 10})

    Output contract (to SC's CAVEDIVING.scd, after our mapping):
      /beep/reverb    float [0, 1]      (wet/dry, power-2 curve over width: hugs 1 near safe origin = wide canal)
      /beep/pan       float [-1, +1]    (identity passthrough)
      /beep/bpm       float             (range from Config, default [40, 200]; power-2 curve over (1 - depth) = panic as front wall approaches)
      /beep/pitch     float Hz          (range from Config, default [80, 800]; linear over tilt)
      /alarm/gate     int   {0, 1}      (edge-triggered, threshold from Config, default 3.0)

    Note: SC calls the frequency parameter "pitch", we call it "freq" internally and on the viz wire.
    SC also supports /alarm/type (int 1..3) to pick alarm sound; not driven from JUCE — SC default is 1.

    Viz contract (to Processing UI on 9003, rate-constant every Timer tick):
      /viz/in/pan     /viz/in/width    /viz/in/depth   /viz/in/tilt   /viz/in/speed     (5 floats)
      /viz/out/reverb /viz/out/pan     /viz/out/bpm    /viz/out/freq  /viz/out/alarm    (4 floats + 1 int)

    Config contract (from Processing UI on port 9002, one-shot on APPLY click):
      /cfg/apply   5 floats positional: (bpmMin, bpmMax, freqMin, freqMax, alarmThr).
                   No streaming, no per-field address. Defaults if no APPLY: (40, 200, 80, 800, 3.0).
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
    void sendVizSnapshot();
    void forwardFloat (const char* addr, float v);
    void forwardInt   (const char* addr, int v);
    void sendVizFloat (const char* addr, float v);
    void sendVizInt   (const char* addr, int v);

    void onManualToggleChanged();
    void updateSliderEnablement();

    // Raw input state from Arduino (or from sliders in Manual mode).
    // Atomic for future-proofing; today all accesses happen on the message thread
    // thanks to MessageLoopCallback.
    struct Inputs
    {
        std::atomic<float> pan   { 0.0f };  // [-1, +1], already cooked by Arduino
        std::atomic<float> width { 0.5f };  // [0, 1], already cooked by Arduino
        std::atomic<float> depth { 0.5f };  // [0, 1], HCSR04 frontal
        std::atomic<float> tilt  { 0.5f };  // [0, 1], MMA accel X (neutral 0.5)
        std::atomic<float> speed { 0.0f };  // joystick discrete, {0, 2.5, 5, 7.5, 10}
    };
    Inputs inputs;

    // Cooked output sent to SC. Written by Timer, read by paint(). Both on
    // message thread → no atomic needed.
    struct Outputs
    {
        float reverb = 0.0f;
        float pan    = 0.0f;
        float bpm    = 0.0f;
        float freq   = 0.0f;     // Hz, was "pitch" pre-refactor
        int   alarm  = 0;
    };
    Outputs outputs;

    // Configuration values received from the Processing UI via /cfg/apply.
    // Defaults match the original hardcoded mapping, so the engine works
    // identically until APPLY is clicked at least once.
    struct Config
    {
        std::atomic<float> bpmMin   {  40.0f };
        std::atomic<float> bpmMax   { 200.0f };
        std::atomic<float> freqMin  {  80.0f };
        std::atomic<float> freqMax  { 800.0f };
        std::atomic<float> alarmThr {   3.0f };
    };
    Config config;

    // Last alarm gate value forwarded to SC. Edge-trigger sentinel: -1 forces
    // the very first send so SC starts with a known state.
    int lastAlarmSent = -1;

    std::atomic<bool> manualMode { false };
    std::atomic<bool> sendToSC   { true  };

    juce::Slider sliderPan, sliderWidth, sliderDepth, sliderTilt, sliderSpeed;
    juce::Label  lblPan,    lblWidth,    lblDepth,    lblTilt,    lblSpeed;
    juce::ToggleButton btnManual { "Manual mode" };
    juce::ToggleButton btnSendSC { "Send to SC" };

    juce::OSCReceiver oscReceiver;     // <- Arduino on 9000 (raw sensor streams)
    juce::OSCReceiver oscReceiverCfg;  // <- Processing on 9002 (/cfg/apply)
    juce::OSCSender   oscSender;       // -> SuperCollider on 57120 (cooked params)
    juce::OSCSender   oscSenderViz;    // -> Processing on 9003 (live monitoring)

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainComponent)
};
