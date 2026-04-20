// QCSS Live Coding Examples
// First evaluate QCSS.scd, then try these examples.
//
// API quick reference (renamed to avoid Event method conflicts):
//   ~q.go(f0, amp)    — start synth
//   ~q.hush(fadeTime)  — stop synth (optional fade)
//   ~q.sync(f0)        — map state vector to synth
//   ~q.ctrl(args...)   — set synth parameters
//   ~q.goFor(f0, sec)  — play for duration
//   ~q.hushSeq         — stop running sequence

// ============================================================
// 1. Basic: Boot and play
// ============================================================
~q.boot { |q| q.go(220) };

// ============================================================
// 2. Gate operations with method chaining
// ============================================================
(
~q.h(0).cnot(0, 1).t(1).cnot(1, 2).x(2);
~q.sync(440);
~q.printGray;
)

// ============================================================
// 3. Scalable aesthetic circuit
// ============================================================
(
~q.resetState;
5.do { |i|
	~q.h(i).t(i).cnot(i, i + 1);
};
~q.h(5).t(5);
~q.sync(170);
~q.printGray;
)

// ============================================================
// 4. Full gate chain with circuit notation
// ============================================================
(
~q.resetState;
~q.circuit([
	[\h, 0],
	[\cnot, 0, 1],
	[\t, 1],
	[\cnot, 1, 2],
	[\x, 2],
	[\cnot, 2, 3],
	[\t, 3],
	[\cnot, 3, 4],
	[\x, 4],
	[\cnot, 4, 5],
	[\h, 5],
]);
~q.sync(70);
~q.printGray;
)

// ============================================================
// 5. Measurement and feedforward
// ============================================================
(
var bit;  // var declarations must come first in SC blocks
~q.resetState;
~q.h(0).cnot(0, 1).cnot(1, 2);
~q.sync(200);

// Measure and branch
bit = ~q.measure(0);
("Outcome: " ++ bit).postln;
if (bit == 0) {
	~q.h(4).t(4).x(4);
} {
	~q.h(5).t(5).x(5);
};
~q.sync(200);
~q.printState;
)

// ============================================================
// 6. Frequency sweep sequence
// ============================================================
(
~q.resetState;
~q.h(0).cnot(0, 1).t(3).cnot(1, 2).cnot(2, 3).cnot(3, 4).cnot(4, 5).h(5);

~q.seq { |q|
	30.do { |i|
		q.sync(41 * (i + 1));
		0.5.wait;
	};
};
)

// Stop sequence
~q.hushSeq;

// ============================================================
// 7. Gate modulation
// ============================================================
(
~q.seq { |q|
	var n = q.nQubits;
	128.do { |i|
		q.h(i % n).t(i % n).x(i % n);
		q.sync(11 * (i + 1));
		0.1.wait;
	};
};
)

// ============================================================
// 8. Scale switching
// ============================================================

// Golden ratio (inharmonic, bell-like)
~q.setScale(\golden); ~q.sync(220);

// Harmonic series (bright, buzzy)
~q.setScale(\harmonic); ~q.sync(110);

// Just intonation
~q.setScale(\just); ~q.sync(261);

// Equal temperament
~q.setScale(\equal); ~q.sync(261);

// Back to default
~q.setScale(\exponential); ~q.sync(220);

// Change octave range
~q.setScale(\exponential, 2);  // 2 octaves (tighter)
~q.setScale(\exponential, 8);  // 8 octaves (wider)

// ============================================================
// 9. New gates: Y, Z, Rx, Ry
// ============================================================
(
~q.resetState;
~q.h(0);
~q.y(1);                 // Pauli-Y
~q.rz(2, pi/3);          // Z-rotation by pi/3
~q.rx(3, pi/4);          // X-rotation by pi/4
~q.ry(4, pi/6);          // Y-rotation by pi/6
~q.cz(0, 1);             // Controlled-Z
~q.swap(2, 3);            // SWAP
~q.toffoli(0, 1, 5);     // Toffoli (CCNOT)
~q.sync(220);
~q.printGray;
)

// ============================================================
// 10. Synth parameter control
// ============================================================

// Pan modulation
~q.ctrl(\panRate, 1.0, \panWidth, 0.9, \panPhase, 0);

// Reverb
~q.ctrl(\revMix, 0.35, \revRoom, 0.9, \revDamp, 0.4);

// Volume
~q.ctrl(\amp, 0.3);

// ============================================================
// 11. Register a custom gate
// ============================================================
(
// Controlled-S gate
~q.registerGate(\cs, { |self, ctrl, tgt|
	var newVec = self.stateVec.copy;
	self.nStates.do { |i|
		if ((self.bitAt(i, ctrl) == 1) and: { self.bitAt(i, tgt) == 1 }) {
			newVec[i] = newVec[i] * Complex(0, 1);
		}
	};
	self.stateVec = newVec;
});
// Use it
~q.resetState;
~q.h(0).applyGate(\cs, 0, 1).sync(220);
)

// ============================================================
// 12. Register a custom scale
// ============================================================
(
// Pythagorean tuning
~q.registerScale(\pythagorean, { |self, n|
	var m = self.nStates;
	(0 .. (m - 1)).collect { |i| (3/2).pow(i % 12) / (2.pow((i % 12 * 7.0 / 12).floor)) * (2 ** i.div(12)) }
});
~q.setScale(\pythagorean);
~q.sync(220);
)

// ============================================================
// 13. Stop
// ============================================================
~q.hush;             // Immediate stop
~q.hush(3);          // Fade out over 3 seconds
~q.goFor(440, 8, 0.25);  // Play at 440Hz for 8 seconds

// ============================================================
// 14. Multiple qubit configurations
// ============================================================

// Reinitialize with different qubit count
~q.init(4);  // 4 qubits = 16 states
~q.boot { |q| q.h(0).cnot(0,1).cnot(1,2).cnot(2,3).go(220) };

~q.init(8);  // 8 qubits = 256 states (heavy!)
~q.boot { |q| q.h(0).go(110) };
