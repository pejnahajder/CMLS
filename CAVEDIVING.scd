
(
s.options.numOutputBusChannels = 2; // Stereo output
s.options.numInputBusChannels = 0;  // No input needed
s.reboot;
s.meter;
)

(
s.waitForBoot({

    // ------------------------------------------------------------
    // SynthDef: oscBeep
    // A pulsing sine-wave beep controlled by OSC.
    // ------------------------------------------------------------
    SynthDef(\oscBeep, {
        arg out = 0,      // audio output bus, usually 0 = main stereo out
            freq = 880,   // sine-wave frequency in Hz
            bpm = 120,    // pulse speed, expressed as beats per minute
            pan = 0,      // stereo position: -1 left, 0 center, 1 right
            reverb = 0.2, // reverb mix amount: 0 dry, 1 wet
            amp = 0.2,    // output volume
		    controlGate = 1;	  // 0 = off, 1 = on

        var beatRate, gate, env, sig, wet, panned;


        // Convert BPM into pulses per second.
		beatRate = Lag.kr(bpm, 0.1) / 60;

        // Create a square-wave control signal.
        gate = LFPulse.kr(beatRate, width: 0.2);

        // Smooth the gate slightly to avoid clicks
        // when the beep turns on and off.
        env = Lag.kr(gate, 0.02);

        // Generate the sine-wave beep,
        // then shape it with the envelope and amplitude.
        sig = SinOsc.ar(freq) * env * amp * Lag.kr(controlGate.clip(0, 1), 0.05);

        // Add reverb to the signal.
        wet = FreeVerb.ar(sig, mix: reverb, room: 0.7, damp: 0.5);

        // Convert the mono signal into stereo and apply panning.
        panned = Pan2.ar(wet, pan);

        // Send the final stereo signal to the output bus.
        Out.ar(out, panned);
    }).add;


    // ------------------------------------------------------------
    // SynthDef: alarmSynth
    // A harsher alarm sound controlled by a gate value over OSC.
    // ------------------------------------------------------------
	SynthDef(\alarmSynth, {
		arg out = 0,			// audio output bus
            gate = 0,			// 0 = off, 1 = on
			amp = 0.1,			// alarm volume
		    alarmType = 1;		// alarm type

		var env, alarm1, alarm2, alarm3, sig;

		env = EnvGen.kr(Env.asr(0.1, 1, 0.2), gate);

		// Alarm 1: original rough saw alarm
		alarm1 = Saw.ar([300, 314]) * LFPulse.kr(20).range(0.2, 1.0);

		// Alarm 2: high-low siren
		alarm2 = VarSaw.ar(
			LFPulse.kr(3).range(500, 1200),
			width: 0.35
		) ! 2;

		// Alarm 3: fast pulsing harsh alarm
		alarm3 = Pulse.ar([700, 705], 0.4) * LFPulse.kr(12).range(0.0, 1.0);

		// Select alarm by index:
		// 1 = alarm1
		// 2 = alarm2
		// 3 = alarm3
		sig = Select.ar(
			(alarmType.clip(1, 3) - 1),
			[alarm1, alarm2, alarm3]
		);

		Out.ar(out, sig * env * amp);
	}).add;

    // Wait until both SynthDefs have actually been sent to the server
    // before trying to create Synth instances from them.
    s.sync;


    // Create one running instance of each SynthDef.
    ~beep = Synth(\oscBeep);
    ~alarm = Synth(\alarmSynth);


    // ------------------------------------------------------------
    // OSC receivers
    // Each OSCdef listens for one address and updates one Synth parameter.
    // The .clip calls act as safety limits, preventing extreme values.
    // ------------------------------------------------------------

    // OSC address: /beep/pan
    // Expected value range: -1.0 to 1.0
    OSCdef(\beepPan, { |msg|
        ~beep.set(\pan, msg[1].asFloat.clip(-1.0, 1.0));
    }, "/beep/pan");

    // OSC address: /beep/bpm
    // Expected value range: 30 to 600 BPM
    OSCdef(\beepBpm, { |msg|
        ~beep.set(\bpm, msg[1].asFloat.clip(30.0, 600.0));
    }, "/beep/bpm");

    // OSC address: /beep/reverb
    // Expected value range: 0.0 to 1.0
    OSCdef(\beepReverb, { |msg|
        ~beep.set(\reverb, msg[1].asFloat.clip(0.0, 1.0));
    }, "/beep/reverb");

    // OSC address: /beep/pitch
	// Expected value range: 20 Hz to 20000 Hz'
	// Supposed value range: 200 Hz to 1200 Hz
    OSCdef(\beepPitch, { |msg|
        ~beep.set(\freq, msg[1].asFloat.clip(20.0, 20000));
    }, "/beep/pitch");

    // OSC address: /alarm/gate
    // Expected values:
    // 0 = alarm off
    // 1 = alarm on
    OSCdef(\alarmGate, { |msg|
        ~alarm.set(\gate, msg[1].asInteger.clip(0, 1));
    }, "/alarm/gate");

	// OSC address: /alarm/type
	// Expected values:
    // 1 = alarm 1
    // 2 = alarm 2
	// 3 = alarm 3
	OSCdef(\alarmType, { |msg|
		~alarm.set(\alarmType, msg[1].asInteger.clip(1, 3));
	}, "/alarm/type");

	// OSC address: /beep/gate
	// 1 = beeping on
	// 2 = beeping off
	OSCdef(\beepGate, { |msg|
		~beep.set(\controlGate, msg[1].asInteger.clip(0, 1));
	}, "/beep/gate");


    // Print confirmation in the SuperCollider post window.
    "\n*** AUDIO ENGINE READY - LISTENING FOR OSC ON PORT 57120 ***".postln;
});
)

(
// ------------------------------------------------------------
// STOP / CLEANUP BLOCK
// Frees Synths and removes OSC receivers.
// ------------------------------------------------------------

if(~beep.notNil) {
	~beep.free;
	~beep = nil;
};

if(~alarm.notNil) {
	~alarm.set(\gate, 0);
	~alarm.free;
	~alarm = nil;
};

OSCdef(\beepPan).free;
OSCdef(\beepBpm).free;
OSCdef(\beepReverb).free;
OSCdef(\beepPitch).free;
OSCdef(\alarmGate).free;
OSCdef(\beepGate).free;

"Audio stopped. Synths freed. OSC receivers removed.".postln;
)


// ------------------------------------------------------------
// OSC TEST FUNCTIONS
// ------------------------------------------------------------
(
~oscTestAddr = NetAddr("127.0.0.1", NetAddr.langPort);

// Pan test: -1 = left, 0 = center, 1 = right
~testPan = { |val = 0|
	~oscTestAddr.sendMsg("/beep/pan", val);
};

// BPM test:value between 60 - 600 BPM range
~testBpm = { |val = 0.5|
	~oscTestAddr.sendMsg("/beep/bpm", val);
};

// Reverb test: send normalized value 0.0 - 1.0
~testReverb = { |val = 0.5|
	~oscTestAddr.sendMsg("/beep/reverb", val);
};

// Pitch test: value in Hz
~testPitch = { |val = 880|
	~oscTestAddr.sendMsg("/beep/pitch", val);
};

// Alarm test: 0 = off, 1 = on
~testAlarm = { |val = 1|
	~oscTestAddr.sendMsg("/alarm/gate", val.clip(0, 1).asInteger);
};

// Alarm type test
~testAlarmType = { |val = 1|
	~oscTestAddr.sendMsg("/alarm/type", val.clip(1, 3).asInteger);
};

// Beeping on/off test: 0 = off, 1 = on
~testBeepGate = { |val = 1|
	~oscTestAddr.sendMsg("/beep/gate", val.clip(0, 1).asInteger);
};
)
~testBeepGate.(1);  // beepGate on/off

~testPan.(-1);      // hard left
~testPan.(1);       // hard right
~testBpm.(120);     // fast beep
~testReverb.(0.2);  // max reverb
~testPitch.(400);   // lower pitch
~testPitch.(1600);  // higher pitch
~testAlarm.(1);     // alarm on
~testAlarm.(0);     // alarm off

~testAlarmType.(1); // original saw alarm
~testAlarmType.(2); // siren alarm
~testAlarmType.(3); // pulsing harsh alarm

