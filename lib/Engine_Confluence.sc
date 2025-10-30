// Engine_Confluence
// 16-voice polyphonic granular synthesis engine
// Supports live input, buffers, and generated audio

Engine_Confluence : CroneEngine {

    // Voice state
    var grainSynths;
    var numVoices = 16;

    // Buffers
    var buffers;
    var numBuffers = 8;

    // Audio buses
    var inputBus;
    var fxBus;
    var reverbBus;
    var delayBus;

    // Effects synths
    var reverbSynth;
    var delaySynth;
    var filterSynth;

    // Groups for organization
    var grainGroup;
    var fxGroup;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {

        // Create audio buses
        inputBus = Bus.audio(context.server, 2);
        fxBus = Bus.audio(context.server, 2);
        reverbBus = Bus.audio(context.server, 2);
        delayBus = Bus.audio(context.server, 2);

        // Create groups
        grainGroup = Group.new(context.xg);
        fxGroup = Group.after(grainGroup);

        // Allocate buffers for samples
        buffers = Array.fill(numBuffers, { arg i;
            Buffer.alloc(context.server, context.server.sampleRate * 60, 2); // 60 seconds each
        });

        // Initialize grain synth array
        grainSynths = Array.newClear(numVoices);

        // Add SynthDefs
        this.addSynthDefs;

        // Wait for SynthDefs to load, then create synths
        context.server.sync;

        // Create effect synths
        this.createEffects;

        // Create grain voices (initially silent)
        numVoices.do({ arg i;
            grainSynths[i] = Synth(\confluenceGrain, [
                \out, fxBus,
                \bufnum, 0,
                \gate, 0,
                \amp, 0
            ], grainGroup);
        });

        // Register OSC commands
        this.addCommands;

        // Start audio input routing
        SynthDef(\confluenceInput, {
            arg in=0, out=0, gain=1.0;
            var sig = SoundIn.ar([in, in+1]) * gain;
            Out.ar(out, sig);
        }).add;

        context.server.sync;
    }

    addSynthDefs {

        // Main grain synthesizer
        SynthDef(\confluenceGrain, {
            arg out=0, bufnum=0,
            gate=0, amp=0.5,
            pos=0, posSpread=0,
            rate=1.0, rateMul=1.0,
            grainSize=0.1, grainSizeSpread=0,
            pan=0, panSpread=0,
            envType=0,
            sourceType=0, // 0=buffer, 1=sine, 2=saw, 3=pulse, 4=input
            inputBus=0,
            atk=0.01, rel=0.01;

            var sig, env, grainEnv;
            var finalPos, finalRate, finalSize, finalPan;
            var bufFrames, actualPos;

            // Calculate grain parameters with randomization
            finalPos = pos + LFNoise2.kr(10).range(-1*posSpread, posSpread);
            finalRate = rate * rateMul * LFNoise2.kr(8).range(0.95, 1.05);
            finalSize = grainSize + LFNoise2.kr(5).range(-1*grainSizeSpread, grainSizeSpread);
            finalSize = finalSize.max(0.001); // Prevent zero or negative
            finalPan = pan + LFNoise2.kr(7).range(-1*panSpread, panSpread);
            finalPan = finalPan.clip(-1, 1);

            // Grain envelope selection
            grainEnv = Select.kr(envType, [
                Env.sine(finalSize),
                Env.perc(0.01, finalSize * 0.99, 1, -4),
                Env.linen(finalSize * 0.1, finalSize * 0.8, finalSize * 0.1),
                Env([0, 1, 1, 0], [finalSize * 0.5, 0, finalSize * 0.5])
            ]);

            grainEnv = EnvGen.kr(grainEnv, gate, doneAction: 0);

            // Audio source selection
            sig = Select.ar(sourceType, [
                // Buffer playback
                PlayBuf.ar(2, bufnum, finalRate * BufRateScale.kr(bufnum),
                    gate, finalPos * BufFrames.kr(bufnum), 0),

                // Sine wave
                SinOsc.ar(finalRate * 440) ! 2,

                // Saw wave
                Saw.ar(finalRate * 440) ! 2,

                // Pulse wave
                Pulse.ar(finalRate * 440, 0.5) ! 2,

                // Live input
                In.ar(inputBus, 2)
            ]);

            // Apply grain envelope and amp
            sig = sig * grainEnv * amp;

            // Pan
            sig = Balance2.ar(sig[0], sig[1], finalPan);

            // Output envelope for voice (sustained)
            env = EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction: 0);
            sig = sig * env;

            Out.ar(out, sig);
        }).add;

        // Reverb effect
        SynthDef(\confluenceReverb, {
            arg in=0, out=0, mix=0.3, room=0.7, damp=0.5;
            var sig, verb;
            sig = In.ar(in, 2);
            verb = FreeVerb2.ar(sig[0], sig[1], mix, room, damp);
            Out.ar(out, verb);
        }).add;

        // Delay effect
        SynthDef(\confluenceDelay, {
            arg in=0, out=0, time=0.375, feedback=0.5, mix=0.3;
            var sig, delay;
            sig = In.ar(in, 2);
            delay = sig + CombL.ar(sig, 2.0, time, feedback * 3) * mix;
            Out.ar(out, delay);
        }).add;

        // Multimode filter
        SynthDef(\confluenceFilter, {
            arg in=0, out=0, freq=5000, res=0.5, filterType=0, mix=1.0;
            var sig, filtered;
            sig = In.ar(in, 2);

            filtered = Select.ar(filterType, [
                // Lowpass
                RLPF.ar(sig, freq, 1-res+0.05),
                // Highpass
                RHPF.ar(sig, freq, 1-res+0.05),
                // Bandpass
                BPF.ar(sig, freq, 1-res+0.05)
            ]);

            sig = XFade2.ar(sig, filtered, mix * 2 - 1);
            Out.ar(out, sig);
        }).add;

        // Final output mixer
        SynthDef(\confluenceMixer, {
            arg in=0, out=0, amp=0.7;
            var sig;
            sig = In.ar(in, 2);
            sig = Limiter.ar(sig, 0.99) * amp;
            Out.ar(out, sig);
        }).add;
    }

    createEffects {
        // Create effects chain
        filterSynth = Synth(\confluenceFilter, [
            \in, fxBus,
            \out, delayBus
        ], fxGroup);

        delaySynth = Synth(\confluenceDelay, [
            \in, delayBus,
            \out, reverbBus
        ], fxGroup);

        reverbSynth = Synth(\confluenceReverb, [
            \in, reverbBus,
            \out, context.out_b
        ], fxGroup);
    }

    addCommands {

        // Trigger grain
        this.addCommand(\triggerGrain, "iffffff", { arg msg;
            var voice = msg[1].asInteger;
            var pos = msg[2];
            var rate = msg[3];
            var size = msg[4];
            var pan = msg[5];
            var amp = msg[6];
            var sourceType = msg[7].asInteger;

            if (voice < numVoices, {
                grainSynths[voice].set(
                    \gate, 1,
                    \pos, pos,
                    \rate, rate,
                    \grainSize, size,
                    \pan, pan,
                    \amp, amp,
                    \sourceType, sourceType
                );

                // Auto-release after grain duration
                SystemClock.sched(size, {
                    grainSynths[voice].set(\gate, 0);
                });
            });
        });

        // Set voice parameter
        this.addCommand(\setVoiceParam, "isf", { arg msg;
            var voice = msg[1].asInteger;
            var param = msg[2].asSymbol;
            var value = msg[3];

            if (voice < numVoices, {
                grainSynths[voice].set(param, value);
            });
        });

        // Set global parameter (all voices)
        this.addCommand(\setGlobalParam, "sf", { arg msg;
            var param = msg[1].asSymbol;
            var value = msg[2];

            numVoices.do({ arg i;
                grainSynths[i].set(param, value);
            });
        });

        // Buffer management
        this.addCommand(\loadBuffer, "is", { arg msg;
            var bufIndex = msg[1].asInteger;
            var path = msg[2].asString;

            if (bufIndex < numBuffers, {
                Buffer.read(context.server, path, action: { arg buf;
                    buffers[bufIndex] = buf;
                    ("Loaded buffer " ++ bufIndex).postln;
                });
            });
        });

        this.addCommand(\recordToBuffer, "iff", { arg msg;
            var bufIndex = msg[1].asInteger;
            var duration = msg[2];
            var inputGain = msg[3];

            if (bufIndex < numBuffers, {
                // Record from audio input to buffer
                {
                    var sig = SoundIn.ar([0, 1]) * inputGain;
                    RecordBuf.ar(sig, buffers[bufIndex], loop: 0, doneAction: 2);
                }.play(context.server);

                ("Recording to buffer " ++ bufIndex ++ " for " ++ duration ++ "s").postln;
            });
        });

        this.addCommand(\clearBuffer, "i", { arg msg;
            var bufIndex = msg[1].asInteger;
            if (bufIndex < numBuffers, {
                buffers[bufIndex].zero;
            });
        });

        this.addCommand(\setBufferForVoice, "ii", { arg msg;
            var voice = msg[1].asInteger;
            var bufIndex = msg[2].asInteger;

            if ((voice < numVoices) && (bufIndex < numBuffers), {
                grainSynths[voice].set(\bufnum, buffers[bufIndex].bufnum);
            });
        });

        // Effects controls
        this.addCommand(\setReverb, "fff", { arg msg;
            reverbSynth.set(\mix, msg[1], \room, msg[2], \damp, msg[3]);
        });

        this.addCommand(\setDelay, "fff", { arg msg;
            delaySynth.set(\time, msg[1], \feedback, msg[2], \mix, msg[3]);
        });

        this.addCommand(\setFilter, "ffif", { arg msg;
            filterSynth.set(\freq, msg[1], \res, msg[2],
                \filterType, msg[3].asInteger, \mix, msg[4]);
        });
    }

    free {
        grainSynths.do({ arg synth; synth.free; });
        reverbSynth.free;
        delaySynth.free;
        filterSynth.free;
        buffers.do({ arg buf; buf.free; });
        inputBus.free;
        fxBus.free;
        reverbBus.free;
        delayBus.free;
        grainGroup.free;
        fxGroup.free;
    }
}
