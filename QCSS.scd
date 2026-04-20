// QCSS — Quantum Computing-based Sound Synthesis
// by Akihiro Kubota
//
// Usage:
//   1. Evaluate this file to load the library
//   2. ~q.boot { |q| q.go(220) }
//   3. ~q.h(0).cnot(0,1).sync(440)
//
// Note: Event built-in methods (play, stop, update, set) are renamed
//       to avoid conflicts:
//       go / hush / sync / ctrl / goFor / hushSeq
//
(
~q = ();

// ============================================================
// Bitwise Helpers
// ============================================================
~q.bitAt   = { |self, n, pos| (n >> pos) & 1 };
~q.bitFlip = { |self, n, pos| n bitXor: (1 << pos) };

// ============================================================
// Initialization
// ============================================================
~q.init = { |self, nQubits=6|
	self.nQubits = nQubits;
	self.nStates = (2 ** nQubits).asInteger;
	self.verbose = false;
	self[\snd] = nil;
	self[\routine] = nil;
	self.gateRegistry  = IdentityDictionary.new;
	self.scaleRegistry = IdentityDictionary.new;
	self.resetState;
	self.initGates;
	self.initScales;
	self.setScale(\exponential);
	self;
};

~q.resetState = { |self|
	self.stateVec = Array.fill(self.nStates, { Complex(0, 0) });
	self.stateVec[0] = Complex(1, 0);
	self;
};

// ============================================================
// Gate Registry
// ============================================================
~q.registerGate = { |self, name, func|
	self.gateRegistry[name] = func;
	self;
};

~q.applyGate = { |self ...args|
	var name = args[0];
	var rest = args[1..];
	var gate = self.gateRegistry[name];
	if (gate.isNil) { Error("Unknown gate: " ++ name).throw };
	gate.value(self, *rest);
	if (self.verbose) { self.stateVec.postln };
	self;
};

// ============================================================
// Built-in Quantum Gates
// ============================================================
~q.initGates = { |self|

	// --- Single-qubit gates ---

	// Hadamard: creates superposition
	self.registerGate(\h, { |self, target|
		var sv = self.stateVec;
		var newVec = sv.copy;
		var c = 2.sqrt.reciprocal;
		self.nStates.do { |i|
			if (self.bitAt(i, target) == 0) {
				var j = self.bitFlip(i, target);
				newVec[i] = (sv[i] + sv[j]) * c;
				newVec[j] = (sv[i] - sv[j]) * c;
			}
		};
		self.stateVec = newVec;
	});

	// Pauli-X (NOT)
	self.registerGate(\x, { |self, target|
		var sv = self.stateVec;
		var newVec = Array.fill(self.nStates, { Complex(0, 0) });
		self.nStates.do { |i| newVec[i] = sv[self.bitFlip(i, target)] };
		self.stateVec = newVec;
	});

	// Pauli-Y
	self.registerGate(\y, { |self, target|
		var sv = self.stateVec;
		var newVec = Array.fill(self.nStates, { Complex(0, 0) });
		self.nStates.do { |i|
			var src = self.bitFlip(i, target);
			var phase = if (self.bitAt(i, target) == 0) { Complex(0, 1) } { Complex(0, -1) };
			newVec[i] = sv[src] * phase;
		};
		self.stateVec = newVec;
	});

	// Pauli-Z
	self.registerGate(\z, { |self, target|
		var newVec = self.stateVec.copy;
		self.nStates.do { |i|
			if (self.bitAt(i, target) == 1) { newVec[i] = newVec[i].neg }
		};
		self.stateVec = newVec;
	});

	// S gate (π/2 phase)
	self.registerGate(\s, { |self, target|
		var newVec = self.stateVec.copy;
		self.nStates.do { |i|
			if (self.bitAt(i, target) == 1) { newVec[i] = newVec[i] * Complex(0, 1) }
		};
		self.stateVec = newVec;
	});

	// T gate (π/4 phase)
	self.registerGate(\t, { |self, target|
		var newVec = self.stateVec.copy;
		var phase = Complex(0, pi/4).exp;
		self.nStates.do { |i|
			if (self.bitAt(i, target) == 1) { newVec[i] = newVec[i] * phase }
		};
		self.stateVec = newVec;
	});

	// Rz: arbitrary Z-rotation by angle theta
	self.registerGate(\rz, { |self, target, theta|
		var newVec = self.stateVec.copy;
		var phase = Complex(0, theta).exp;
		self.nStates.do { |i|
			if (self.bitAt(i, target) == 1) { newVec[i] = newVec[i] * phase }
		};
		self.stateVec = newVec;
	});

	// Rx: arbitrary X-rotation by angle theta
	self.registerGate(\rx, { |self, target, theta|
		var sv = self.stateVec;
		var newVec = sv.copy;
		var cosH = (theta / 2).cos;
		var sinH = (theta / 2).sin;
		self.nStates.do { |i|
			if (self.bitAt(i, target) == 0) {
				var j = self.bitFlip(i, target);
				newVec[i] = (sv[i] * cosH) + (sv[j] * Complex(0, sinH.neg));
				newVec[j] = (sv[i] * Complex(0, sinH.neg)) + (sv[j] * cosH);
			}
		};
		self.stateVec = newVec;
	});

	// Ry: arbitrary Y-rotation by angle theta
	self.registerGate(\ry, { |self, target, theta|
		var sv = self.stateVec;
		var newVec = sv.copy;
		var cosH = (theta / 2).cos;
		var sinH = (theta / 2).sin;
		self.nStates.do { |i|
			if (self.bitAt(i, target) == 0) {
				var j = self.bitFlip(i, target);
				newVec[i] = (sv[i] * cosH) + (sv[j] * sinH.neg);
				newVec[j] = (sv[i] * sinH)  + (sv[j] * cosH);
			}
		};
		self.stateVec = newVec;
	});

	// --- Multi-qubit gates ---

	// CNOT (controlled NOT)
	self.registerGate(\cnot, { |self, ctrl, tgt|
		var sv = self.stateVec;
		var newVec = Array.fill(self.nStates, { Complex(0, 0) });
		self.nStates.do { |i|
			var src = if (self.bitAt(i, ctrl) == 1) { self.bitFlip(i, tgt) } { i };
			newVec[i] = sv[src];
		};
		self.stateVec = newVec;
	});

	// CZ (controlled Z)
	self.registerGate(\cz, { |self, ctrl, tgt|
		var newVec = self.stateVec.copy;
		self.nStates.do { |i|
			if ((self.bitAt(i, ctrl) == 1) and: { self.bitAt(i, tgt) == 1 }) {
				newVec[i] = newVec[i].neg;
			}
		};
		self.stateVec = newVec;
	});

	// SWAP
	self.registerGate(\swap, { |self, q0, q1|
		var sv = self.stateVec;
		var newVec = Array.fill(self.nStates, { Complex(0, 0) });
		self.nStates.do { |i|
			var b0 = self.bitAt(i, q0);
			var b1 = self.bitAt(i, q1);
			var j = i;
			if (b0 != b1) {
				j = self.bitFlip(self.bitFlip(i, q0), q1);
			};
			newVec[i] = sv[j];
		};
		self.stateVec = newVec;
	});

	// Toffoli (CCNOT)
	self.registerGate(\toffoli, { |self, c0, c1, tgt|
		var sv = self.stateVec;
		var newVec = Array.fill(self.nStates, { Complex(0, 0) });
		self.nStates.do { |i|
			var src = if ((self.bitAt(i, c0) == 1) and: { self.bitAt(i, c1) == 1 }) {
				self.bitFlip(i, tgt)
			} { i };
			newVec[i] = sv[src];
		};
		self.stateVec = newVec;
	});
};

// ============================================================
// Gate Shorthands (for live coding convenience)
// ============================================================
~q.h       = { |self, t=0|            self.applyGate(\h, t) };
~q.x       = { |self, t=0|            self.applyGate(\x, t) };
~q.y       = { |self, t=0|            self.applyGate(\y, t) };
~q.z       = { |self, t=0|            self.applyGate(\z, t) };
~q.ss      = { |self, t=0|            self.applyGate(\s, t) };  // "ss" to avoid conflict with Server
~q.t       = { |self, t=0|            self.applyGate(\t, t) };
~q.rz      = { |self, t=0, th=0|      self.applyGate(\rz, t, th) };
~q.rx      = { |self, t=0, th=0|      self.applyGate(\rx, t, th) };
~q.ry      = { |self, t=0, th=0|      self.applyGate(\ry, t, th) };
~q.cnot    = { |self, c=0, t=1|       self.applyGate(\cnot, c, t) };
~q.cz      = { |self, c=0, t=1|       self.applyGate(\cz, c, t) };
~q.swap    = { |self, a=0, b=1|       self.applyGate(\swap, a, b) };
~q.toffoli = { |self, c0=0, c1=1, t=2| self.applyGate(\toffoli, c0, c1, t) };

// ============================================================
// Measurement
// ============================================================

// Probability of qubit measuring to |1⟩
~q.prob = { |self, target=0, eps=1e-12|
	var totalP = self.stateVec.collect { |c| c.abs.squared }.sum.max(eps);
	var p1 = 0.0;
	self.nStates.do { |i|
		if (self.bitAt(i, target) == 1) { p1 = p1 + self.stateVec[i].abs.squared }
	};
	(p1 / totalP).clip(0.0, 1.0)
};

// Projective measurement: collapses state and returns outcome (0 or 1)
~q.measure = { |self, target=0, eps=1e-12|
	var p1 = self.prob(target);
	var outcome = if (1.0.rand < p1) { 1 } { 0 };
	var newVec = Array.fill(self.nStates, { Complex(0, 0) });
	var norm;
	self.nStates.do { |i|
		if (self.bitAt(i, target) == outcome) { newVec[i] = self.stateVec[i] }
	};
	norm = newVec.collect { |c| c.abs.squared }.sum.sqrt.max(eps);
	self.stateVec = newVec.collect { |c| c / norm };
	if (self.verbose) { ("Measured qubit[%] = %".format(target, outcome)).postln };
	outcome
};

// ============================================================
// Frequency Scales (pluggable)
// ============================================================
~q.registerScale = { |self, name, func|
	self.scaleRegistry[name] = func;
	self;
};

~q.setScale = { |self, name, nOctaves=4|
	var fn = self.scaleRegistry[name];
	var m = self.nStates;
	var ratios, grayOrder;
	if (fn.isNil) { Error("Unknown scale: " ++ name).throw };
	ratios = fn.(self, nOctaves);
	grayOrder = (0 .. (m - 1)).collect { |i| i bitXor: i.div(2) };
	self.grayOrder = grayOrder;
	self.ratios = ratios;
	self.gratios = (0 .. (m - 1)).collect { |i| ratios[grayOrder.indexOf(i)] };
	self.currentScale = name;
	self;
};

~q.initScales = { |self|
	// Exponential: 2^(n*i/m) — covers n octaves evenly
	self.registerScale(\exponential, { |self, n|
		var m = self.nStates;
		(0 .. (m - 1)).collect { |i| 2.pow(n * i / m) }
	});

	// Golden ratio: quasi-periodic inharmonic spectrum
	self.registerScale(\golden, { |self, n|
		var m = self.nStates;
		var phi = (1 + 5.sqrt) * 0.5;
		var alpha = phi.log / 2.0.log;
		(0 .. (m - 1)).collect { |i| 2.pow(((i * alpha) % 1.0) * n) }
	});

	// Harmonic series: 1, 2, 3, ... m
	self.registerScale(\harmonic, { |self, n|
		var m = self.nStates;
		(1 .. m).collect { |i| i.asFloat }
	});

	// Just intonation: 12-tone ratios repeated across octaves
	self.registerScale(\just, { |self, n|
		var base = [1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8];
		var m = self.nStates;
		(0 .. (m - 1)).collect { |i|
			var oct = i.div(12);
			var deg = i % 12;
			base[deg] * (2 ** oct)
		}
	});

	// Equal temperament: 12-TET repeated across octaves
	self.registerScale(\equal, { |self, n|
		var m = self.nStates;
		(0 .. (m - 1)).collect { |i| 2.pow(i / 12.0) }
	});
};

// ============================================================
// Audio Engine
// ============================================================

~q.normalizeAmps = { |self, amps, mode=\l2, eps=1e-9|
	switch(mode,
		\l1,  { amps / amps.sum.max(eps) },
		\l2,  { amps / amps.collect { |a| a * a }.sum.sqrt.max(eps) },
		\max, { amps / amps.maxItem.max(eps) },
		{ amps }
	)
};

~q.autoAmp = { |self, amps, target=\rms, level=0.2, eps=1e-9|
	switch(target,
		\peak, { level / amps.sum.max(eps) },
		\rms,  { level / amps.collect { |a| a * a }.sum.sqrt.max(eps) },
		{ level }
	)
};

~q.buildSynthDef = { |self, name=\qAdd|
	var n = self.nStates;
	SynthDef(name, {
		|out=0, amp=0.2, gate=1,
		 panRate=0.05, panWidth=0.9, panPhase=0.0,
		 revMix=0.2, revRoom=0.8, revDamp=0.3|
		var amps   = NamedControl.kr(\amps,   Array.fill(n, 0));
		var phases = NamedControl.kr(\phases,  Array.fill(n, 0));
		var freqs  = NamedControl.kr(\freqs,   Array.fill(n, 440));
		var sig, env, panSig, dry, wet;

		panSig = Array.fill(n, { |i|
			var iph = (2pi * i / n) + panPhase;
			(SinOsc.kr(panRate, iph) * panWidth).clip(-1, 1)
		});

		sig = Mix.fill(n, { |i|
			Pan2.ar(SinOsc.ar(freqs[i], phases[i]) * amps[i], panSig[i])
		});

		// Safety: compressor + normalizer
		sig = Compander.ar(sig, sig,
			thresh: 0.5, slopeBelow: 1, slopeAbove: 0.25,
			clampTime: 0.01, relaxTime: 0.2);
		sig = Normalizer.ar(sig, level: 0.98, dur: 0.01);

		// Envelope
		env = EnvGen.kr(Env.asr(1.0, 1.0, 1.5), gate, doneAction: 2);
		dry = sig * amp * env;

		// Reverb (stereo)
		wet = FreeVerb2.ar(dry[0], dry[1], revMix, revRoom, revDamp);

		// Final limiter
		sig = Limiter.ar(wet, level: 0.99, dur: 0.01);
		Out.ar(out, sig);
	}).add;
	self;
};

// Map current state vector to synth parameters
~q.sync = { |self, f0=220|
	var amps = self.stateVec.collect(_.abs);
	var phases = self.stateVec.collect(_.phase);
	var freqs = f0 * self.gratios;
	var ampCtl;
	amps = self.normalizeAmps(amps, \l2);
	ampCtl = self.autoAmp(amps, \rms, 0.5);
	if (self[\snd].notNil) {
		self[\snd].set(\amp, ampCtl);
		self[\snd].setn(\amps, amps);
		self[\snd].setn(\phases, phases);
		self[\snd].setn(\freqs, freqs);
	};
	self;
};

// Set synth parameters directly (pan, reverb, etc.)
~q.ctrl = { |self ...args|
	if (self[\snd].notNil) { self[\snd].set(*args) };
	self;
};

// Start playback
~q.go = { |self, f0=220, amp=0.2|
	self[\snd] = Synth(\qAdd, [\amp, amp]);
	self.sync(f0);
	self;
};

// Stop with optional fade time
~q.hush = { |self, fadeTime|
	if (self[\snd].notNil) {
		if (fadeTime.notNil) {
			var syn = self[\snd];
			SystemClock.sched(fadeTime, { syn.set(\gate, 0); nil });
		} {
			self[\snd].set(\gate, 0);
		};
	};
	self;
};

// Play for a limited duration
~q.goFor = { |self, f0=220, sec=5, amp=0.2|
	self.go(f0, amp);
	self.hush(sec);
	self;
};

// ============================================================
// Circuit: reusable gate sequences
// ============================================================

// Apply a sequence of gates: [[\h, 0], [\cnot, 0, 1], [\t, 1]]
~q.circuit = { |self, steps|
	steps.do { |step| self.applyGate(*step) };
	self;
};

// ============================================================
// Sequencer
// ============================================================

// Run a routine (function receives self)
~q.seq = { |self, fn|
	self.hushSeq;
	self[\routine] = Routine({ fn.(self) }).play;
	self;
};

~q.hushSeq = { |self|
	if (self[\routine].notNil) { self[\routine].stop; self[\routine] = nil };
	self;
};

// ============================================================
// Display
// ============================================================

// Print state vector (only non-zero amplitudes)
~q.printState = { |self, threshold=1e-10|
	self.nStates.do { |i|
		var sv = self.stateVec[i];
		if (sv.abs > threshold) {
			("[%] gray[%] %\t %".format(
				i.asBinaryDigits(self.nQubits).join(""),
				self.grayOrder[i],
				self.gratios[i].asStringPrec(5),
				sv
			)).postln;
		};
	};
	self;
};

// Print state vector ordered by Gray code
~q.printGray = { |self, threshold=1e-10|
	self.nStates.do { |i|
		var go = self.grayOrder[i];
		var sv = self.stateVec[go];
		if (sv.abs > threshold) {
			("gray[%] [%] %\t %".format(
				i,
				go.asBinaryDigits(self.nQubits).join(""),
				self.gratios[go].asStringPrec(5),
				sv
			)).postln;
		};
	};
	self;
};

// ============================================================
// Boot: build SynthDef and start server
// ============================================================
~q.boot = { |self, action|
	self.buildSynthDef;
	s.waitForBoot({
		("QCSS ready: % qubits, % states, scale=%".format(
			self.nQubits, self.nStates, self.currentScale
		)).postln;
		if (action.notNil) { action.(self) };
	});
	self;
};

// ============================================================
// Initialize with defaults
// ============================================================
~q.init(6);

"QCSS loaded. Use ~q.boot { |q| q.go(220) } to start.".postln;
)
