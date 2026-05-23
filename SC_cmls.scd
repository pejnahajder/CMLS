(
s.waitForBoot({
    SynthDef(\navPing, {
		arg out=0, freq=440, bpm=120, pan=0, reverb=0.35, amp=0.3;
		var beatRate, gate, env;
		var sig, dry, wet, verb;

		beatRate = (bpm / 60).clip(0.1, 20);
		gate = LFPulse.kr(beatRate, width: 0.5);
		env = EnvGen.kr(
			Env.perc(0.005, 0.12),
			gate
		);

		sig = SinOsc.ar(freq.clip(20, 20000)) * env * amp;

		// Clear dry signal
		dry = Pan2.ar(sig, pan.clip(-1, 1));

		// Reverb send, not full replacement
		verb = FreeVerb2.ar(
			dry[0],
			dry[1],
			mix: 0.35,
			room: 0.65,
			damp: 0.7
		);

		// Clean the reverb tail
		verb = HPF.ar(verb, 250);
		verb = LPF.ar(verb, 4500);

		// Blend dry + wet manually
		wet = dry + (verb * reverb.clip(0, 1) * 0.7);

		Out.ar(out, Limiter.ar(wet, 0.9));
	}).add;

    SynthDef(\alarmSynth, {
        arg out=0, gate=0, amp=0.4;
        var env, sig;

        env = EnvGen.kr(Env.asr(0.1, 1, 0.2), gate);
        sig = Saw.ar([300, 314]) * LFPulse.kr(20).range(0.2, 1.0);

        Out.ar(out, sig * env * amp);
    }).add;

    s.sync;

    ~ping = Synth(\navPing, [
        \freq, 440,
        \bpm, 120,
        \pan, 0,
        \reverb, 0.5
    ]);

    ~alarm = Synth(\alarmSynth, [
        \gate, 0
    ]);

    OSCdef(\juceReverb, { |msg|
        var v = msg[1].asFloat.clip(0, 1);
        ~ping.set(\reverb, v);
    }, "/synth/reverb");

    OSCdef(\jucePan, { |msg|
        var v = msg[1].asFloat.clip(-1, 1);
        ~ping.set(\pan, v);
    }, "/synth/pan");

    OSCdef(\juceBpm, { |msg|
        var v = msg[1].asFloat.clip(40, 200);
        ~ping.set(\bpm, v);
    }, "/synth/bpm");

    OSCdef(\juceFreq, { |msg|
        var v = msg[1].asFloat.clip(80, 800);
        ~ping.set(\freq, v);
    }, "/synth/freq");

    OSCdef(\juceAlarm, { |msg|
        var v = msg[1].asInteger.clip(0, 1);
        ~alarm.set(\gate, v);
    }, "/alarm/gate");

    "JUCE OSC receiver ready".postln;
});
)