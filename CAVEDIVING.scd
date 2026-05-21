(
s.options.numOutputBusChannels = 2; // Forza l'uscita Stereo di sistema

s.waitForBoot({
    SynthDef(\oscBeep, {
        arg out = 0, freq = 880, bpm = 120, pan = 0, reverb = 0.2, amp = 0.2;
        var beatRate, gate, env, sig, wet, panned;
        
        beatRate = bpm / 60;
        gate = LFPulse.kr(beatRate, width: 0.5);
        env = Lag.kr(gate, 0.01);
        sig = SinOsc.ar(freq) * env * amp;
        
        wet = FreeVerb.ar(sig, mix: reverb, room: 0.7, damp: 0.5);
        panned = Pan2.ar(wet, pan);
        
        Out.ar(out, panned);
    }).add;

    SynthDef(\alarmSynth, {
        arg out = 0, gate = 0, amp = 0.4;
        var env, sig;
        env = EnvGen.kr(Env.asr(0.1, 1, 0.2), gate);
        sig = Saw.ar([300, 314]) * LFPulse.kr(20).range(0.2, 1.0);
        Out.ar(out, sig * env * amp);
    }).add;

    s.sync;

    ~beep = Synth(\oscBeep);
    ~alarm = Synth(\alarmSynth);

    // I ricevitori OSC con i limitatori di sicurezza (.clip)
    OSCdef(\beepPan, { |msg| ~beep.set(\pan, msg[1].asFloat.clip(-1.0, 1.0)); }, "/beep/pan");
    OSCdef(\beepBpm, { |msg| ~beep.set(\bpm, msg[1].asFloat.clip(30.0, 600.0)); }, "/beep/bpm");
    OSCdef(\beepReverb, { |msg| ~beep.set(\reverb, msg[1].asFloat.clip(0.0, 1.0)); }, "/beep/reverb");
    OSCdef(\beepPitch, { |msg| ~beep.set(\freq, msg[1].asFloat.clip(20.0, 20000.0)); }, "/beep/pitch");
    OSCdef(\alarmGate, { |msg| ~alarm.set(\gate, msg[1].asInteger); }, "/alarm/gate");

    "\n*** MOTORE AUDIO PRONTO - IN ASCOLTO OSC SULLA PORTA 57120 ***".postln;
});
)