// Procedural sound effects, sfxr-style, to match the pachinko lamp pixel art.
// Generates assets/audio/wav/*.wav (44.1k mono 16-bit) and assets/audio/demo.html.
// Run: node assets/audio/gen.mjs   (no dependencies). Played by src/sfx.gd.
import { writeFileSync, mkdirSync } from "node:fs";

const SR = 44100;
const TAU = Math.PI * 2;

// One synth voice: pitch glides f -> f1 (exponential), amplitude = linear attack `a` then exp decay.
// k = decay rate per second (default lands near silence at dur); k = 0 sustains (for loops).
function tone({ f, f1 = f, dur = 0.1, wave = "sq", duty = 0.5, a = 0.002, k = null, vib = 0, vibf = 30, lp = 0, trem = 0, tremf = 20 }) {
	const n = Math.round(dur * SR), out = new Float32Array(n), decay = k ?? 6 / dur;
	let ph = 0, y = 0;
	for (let i = 0; i < n; i++) {
		const t = i / SR, u = t / dur;
		ph = (ph + f * Math.pow(f1 / f, u) * (1 + vib * Math.sin(TAU * vibf * t)) / SR) % 1;
		let s = wave === "sq" ? (ph < duty ? 1 : -1) : wave === "saw" ? 2 * ph - 1 : wave === "tri" ? 4 * Math.abs(ph - 0.5) - 1 : Math.sin(TAU * ph);
		s *= (a ? Math.min(1, t / a) : 1) * Math.exp(-decay * t) * (1 - trem * (0.5 + 0.5 * Math.sin(TAU * tremf * t)));
		if (lp) { const c = 1 - Math.exp(-TAU * lp / SR); y += c * (s - y); s = y; }
		out[i] = s;
	}
	return out;
}

// White noise through a one-pole lowpass that glides lp -> lp1, and an optional one-pole highpass.
function noise({ dur = 0.1, k = null, lp = 8000, lp1 = lp, hp = 0, a = 0 }) {
	const n = Math.round(dur * SR), out = new Float32Array(n), decay = k ?? 6 / dur;
	let y = 0, hy = 0, hx = 0;
	for (let i = 0; i < n; i++) {
		const t = i / SR, u = t / dur, x = Math.random() * 2 - 1;
		const c = 1 - Math.exp(-TAU * lp * Math.pow(lp1 / lp, u) / SR);
		y += c * (x - y);
		let s = y;
		if (hp) { const r = Math.exp(-TAU * hp / SR); hy = r * (hy + s - hx); hx = s; s = hy; }
		out[i] = s * (a ? Math.min(1, t / a) : 1) * Math.exp(-decay * t);
	}
	return out;
}

// Layer [buffer, startSeconds, gain] parts into one buffer.
function layer(...parts) {
	const n = Math.max(...parts.map(([b, at = 0]) => Math.round(at * SR) + b.length)), out = new Float32Array(n);
	for (const [b, at = 0, g = 1] of parts) { const o = Math.round(at * SR); for (let i = 0; i < b.length; i++) out[o + i] += b[i] * g; }
	return out;
}

// Melody: notes = [[hz, dur], ...] played back to back, each with the same voice options.
const notes = (list, opts = {}, gap = 0) => {
	let t = 0; const parts = [];
	for (const [f, d] of list) { parts.push([tone({ f, dur: d + (opts.ring ?? 0), ...opts }), t]); t += d + gap; }
	return layer(...parts);
};
// Bell: a sine with its octave and a slightly inharmonic partial, long decay.
const bell = (f, dur = 0.3, g = 1) => layer([tone({ f, dur, wave: "sin", k: 9 / dur }), 0, g], [tone({ f: f * 2, dur, wave: "sin", k: 12 / dur }), 0, 0.4 * g], [tone({ f: f * 2.76, dur: dur * 0.5, wave: "sin", k: 20 / dur }), 0, 0.15 * g]);
const click = (f = 1000, dur = 0.012) => tone({ f, dur, wave: "sq", a: 0 });
const E = 1.05946; // one semitone
const st = n => Math.pow(E, n);

// name: { group, desc, gen, gain?, loop?, ladder? }. ladder = playback rates the demo exposes (runtime pitch_scale).
const CUES = {
	// --- Ball and paddle ---
	ball_bounce: { g: "Ball and paddle", d: "wall bounce", gen: () => tone({ f: 880, f1: 660, dur: 0.05 }) },
	paddle_hit: { g: "Ball and paddle", d: "paddle contact; pitch by offset from centre", gen: () => layer([tone({ f: 523, f1: 392, dur: 0.08, wave: "tri" })], [noise({ dur: 0.03, lp: 3000 }), 0, 0.3]), ladder: [0.85, 1, 1.15, 1.3] },
	ball_launch: { g: "Ball and paddle", d: "launch from paddle", gen: () => tone({ f: 400, f1: 1200, dur: 0.12, wave: "sin" }) },
	ball_lost: { g: "Ball and paddle", d: "ball drops off the bottom", gen: () => tone({ f: 600, f1: 150, dur: 0.4, vib: 0.03, vibf: 18 }) },
	multiball_pop: { g: "Ball and paddle", d: "extra ball spawns", gen: () => notes([[660, 0.04], [990, 0.06]]) },
	fast_whoosh: { g: "Ball and paddle", d: "ball crosses the fast tier", gen: () => noise({ dur: 0.25, lp: 800, lp1: 6000, hp: 300, a: 0.08 }) },
	pierce_swish: { g: "Ball and paddle", d: "pierce pass-through", gen: () => noise({ dur: 0.12, lp: 5000, lp1: 1500, hp: 1200, a: 0.01 }) },

	// --- Bricks ---
	brick_hit: { g: "Bricks", d: "plain hit; ladder = mag / ora / vio sets", gen: () => tone({ f: 1047, f1: 900, dur: 0.05 }), ladder: [1, 1.12, 1.25] },
	brick_break: { g: "Bricks", d: "brick breaks, sparks", gen: () => layer([tone({ f: 1319, f1: 880, dur: 0.07 })], [noise({ dur: 0.1, lp: 6000, lp1: 1500 }), 0.01, 0.5]) },
	multi_crack: { g: "Bricks", d: "multi-hit brick cracks; ladder = hp left", gen: () => layer([tone({ f: 700, f1: 600, dur: 0.06, wave: "sq", duty: 0.3 })], [noise({ dur: 0.08, lp: 4000, lp1: 800 }), 0, 0.6]), ladder: [1, 0.9, 0.8] },
	pips_shrink: { g: "Bricks", d: "a pip blinks out", gen: () => notes([[880, 0.02], [660, 0.03]], {}, 0.02) },
	armor_pop: { g: "Bricks", d: "chrome plate rings and falls off", gen: () => layer([tone({ f: 1200, dur: 0.25, wave: "sin", k: 14 })], [tone({ f: 1731, dur: 0.25, wave: "sin", k: 18 }), 0, 0.6], [noise({ dur: 0.05, lp: 9000, hp: 2000 }), 0, 0.5], [tone({ f: 300, f1: 200, dur: 0.06, wave: "sq" }), 0.02, 0.4]) },
	shield_pop: { g: "Bricks", d: "sky shield shatters", gen: () => layer([bell(2093, 0.15)], [bell(2637, 0.12), 0.01, 0.6], [noise({ dur: 0.08, lp: 12000, hp: 3000 }), 0, 0.5]) },
	solid_bounce: { g: "Bricks", d: "dull thud on an unbreakable", gen: () => layer([tone({ f: 150, f1: 60, dur: 0.08, wave: "sin" })], [noise({ dur: 0.04, lp: 600 }), 0, 0.5]) },
	hit_refused: { g: "Bricks", d: "cond / gate / timed / sequence says no", gen: () => tone({ f: 220, dur: 0.12, duty: 0.5, trem: 1, tremf: 25, k: 10 }) },
	cond_primed: { g: "Bricks", d: "conditional brick primes", gen: () => layer([notes([[523, 0.03], [659, 0.03], [784, 0.03]], {}, 0)], [bell(784, 0.3, 0.8), 0.09]) },
	gate_tick: { g: "Bricks", d: "combo gate counts down; ladder = 3,2,1", gen: () => click(1200, 0.02), ladder: [0.8, 0.9, 1] },
	seq_step: { g: "Bricks", d: "sequence brick in order; ladder = step 1,2,3", gen: () => bell(1047, 0.2), ladder: [1, 1.26, 1.5] },
	timed_on: { g: "Bricks", d: "timed brick lights", gen: () => click(1000, 0.01) },
	timed_off: { g: "Bricks", d: "timed brick unlights", gen: () => click(500, 0.01) },
	wild_hum: { g: "Bricks", d: "wild brick hue cycle (loop)", gen: () => tone({ f: 330, dur: 1, wave: "tri", a: 0, k: 0, vib: 0.02, vibf: 1 }), gain: 0.25, loop: true },

	// --- Icon effects ---
	speedup: { g: "Icon effects", d: "all balls speed up", gen: () => tone({ f: 400, f1: 1600, dur: 0.2, k: 8 }) },
	slowdown: { g: "Icon effects", d: "all balls slow down", gen: () => tone({ f: 1600, f1: 400, dur: 0.25, k: 8 }) },
	x2_sting: { g: "Icon effects", d: "x2 boost", gen: () => notes([[784, 0.06], [1047, 0.12]]) },
	x3_sting: { g: "Icon effects", d: "x3 boost", gen: () => notes([[784, 0.06], [1047, 0.06], [1319, 0.14]]) },
	combo_extend: { g: "Icon effects", d: "combo window extended", gen: () => layer([bell(1319, 0.25)], [noise({ dur: 0.15, lp: 10000, hp: 5000 }), 0, 0.15]) },
	timer_extend: { g: "Icon effects", d: "round time added, tick tock", gen: () => layer([click(1500, 0.015)], [click(1000, 0.015), 0.08], [bell(1568, 0.2, 0.6), 0.16]) },
	chain_zap: { g: "Icon effects", d: "chain arc to a neighbour", gen: () => layer([tone({ f: 2000, f1: 200, dur: 0.12, trem: 0.8, tremf: 90 })], [noise({ dur: 0.1, lp: 9000, hp: 1500 }), 0, 0.5]) },
	fuse_lit: { g: "Icon effects", d: "bomb or bolt armed, fuse sizzle", gen: () => layer([noise({ dur: 0.3, lp: 9000, hp: 2500 })], [click(1800, 0.02), 0, 0.8]) },
	bomb_boom: { g: "Icon effects", d: "bomb ring", gen: () => layer([noise({ dur: 0.4, lp: 2000, lp1: 100 })], [tone({ f: 120, f1: 40, dur: 0.35, wave: "sin" }), 0, 1.2]) },
	bolt_sweep: { g: "Icon effects", d: "row beam", gen: () => tone({ f: 2400, f1: 300, dur: 0.15, wave: "saw", lp: 4000 }) },
	jackpot: { g: "Icon effects", d: "jackpot fanfare", gen: () => layer([notes([[523, 0.07], [659, 0.07], [784, 0.07], [1047, 0.07], [1319, 0.07], [1568, 0.07], [2093, 0.3]], { k: 12 })], [bell(2093, 0.6, 0.7), 0.42], [bell(3136, 0.5, 0.3), 0.5], [noise({ dur: 0.5, lp: 12000, hp: 6000 }), 0.42, 0.1]) },
	mystery_reel: { g: "Icon effects", d: "slot reel spins then lands", gen: () => layer(...[0, 0.05, 0.11, 0.18, 0.27, 0.38].map(t => [click(900, 0.015), t, 0.8]), [bell(1568, 0.25), 0.46]) },
	magnet_hum: { g: "Icon effects", d: "magnet field / pull (loop)", gen: () => layer([tone({ f: 55, dur: 1, wave: "saw", a: 0, k: 0, lp: 200 })], [tone({ f: 110, dur: 1, wave: "sin", a: 0, k: 0, trem: 0.5, tremf: 2 }), 0, 0.5]), gain: 0.3, loop: true },
	split_pop: { g: "Icon effects", d: "ball splits", gen: () => notes([[990, 0.04], [660, 0.04], [990, 0.06]]) },

	// --- Placeables ---
	bumper_hit: { g: "Placeables", d: "pinball bumper thunk", gen: () => layer([tone({ f: 330, f1: 250, dur: 0.06, duty: 0.3 })], [noise({ dur: 0.04, lp: 2500 }), 0, 0.6], [tone({ f: 90, dur: 0.05, wave: "sin" }), 0, 0.8]) },
	pop_bumper_hit: { g: "Placeables", d: "round pop bumper, speeds the ball", gen: () => layer([tone({ f: 523, f1: 700, dur: 0.07, duty: 0.3 })], [bell(1047, 0.12, 0.5), 0.02]) },
	gate_pass: { g: "Placeables", d: "one-way gate lets the ball through", gen: () => tone({ f: 1500, f1: 1800, dur: 0.025 }) },
	accel_zip: { g: "Placeables", d: "accelerator strip launches", gen: () => tone({ f: 300, f1: 2400, dur: 0.1, wave: "saw", lp: 5000 }) },
	sticky_catch: { g: "Placeables", d: "sticky pad catches the ball", gen: () => layer([tone({ f: 300, f1: 150, dur: 0.06, wave: "tri" })], [noise({ dur: 0.05, lp: 1200 }), 0, 0.4]) },
	sticky_fire: { g: "Placeables", d: "sticky pad fires it up", gen: () => tone({ f: 200, f1: 800, dur: 0.08, wave: "tri" }) },
	teleport_in: { g: "Placeables", d: "ball shrinks into a portal", gen: () => tone({ f: 1200, f1: 300, dur: 0.15, wave: "sin", vib: 0.05, vibf: 40 }) },
	teleport_out: { g: "Placeables", d: "ball grows out of the next portal", gen: () => tone({ f: 300, f1: 1200, dur: 0.15, wave: "sin", vib: 0.05, vibf: 40 }) },
	spawner_charge: { g: "Placeables", d: "lamp fills, then a ball pops out", gen: () => layer([tone({ f: 200, f1: 800, dur: 0.6, wave: "tri", k: 1, a: 0.05 })], [notes([[660, 0.04], [990, 0.06]]), 0.6]) },

	// --- Combo and economy ---
	combo_tick: { g: "Combo and economy", d: "combo step; ladder climbs a semitone per hit", gen: () => tone({ f: 1047, dur: 0.035, duty: 0.25 }), ladder: [1, st(1), st(2), st(3), st(4), st(5), st(6), st(7)] },
	combo_up: { g: "Combo and economy", d: "multiplier milestone", gen: () => notes([[1047, 0.04], [1319, 0.1]]) },
	combo_drop: { g: "Combo and economy", d: "combo window ran out", gen: () => tone({ f: 880, f1: 440, dur: 0.15, wave: "tri" }), gain: 0.6 },
	coin: { g: "Combo and economy", d: "payout ding", gen: () => layer([bell(1760, 0.3)], [bell(2217, 0.35), 0.04]) },
	coin_cascade: { g: "Combo and economy", d: "big payout, rising dings", gen: () => layer(...[0, 1, 2, 3, 4, 5].map(i => [bell(1319 * st(i * 2), 0.3, 0.8), i * 0.05])) },
	count_tick: { g: "Combo and economy", d: "HUD number count-up", gen: () => click(2000, 0.008), gain: 0.6 },
	boost_end: { g: "Combo and economy", d: "x2/x3 boost expires", gen: () => tone({ f: 660, f1: 523, dur: 0.06, wave: "tri" }), gain: 0.7 },

	// --- Placement and UI ---
	ui_pickup: { g: "Placement and UI", d: "pick a piece from the tray", gen: () => tone({ f: 523, f1: 659, dur: 0.04, wave: "tri" }) },
	ui_drop: { g: "Placement and UI", d: "place a piece", gen: () => layer([tone({ f: 659, f1: 523, dur: 0.04, wave: "tri" })], [noise({ dur: 0.03, lp: 1500 }), 0, 0.4]) },
	ui_invalid: { g: "Placement and UI", d: "can't place here", gen: () => tone({ f: 150, dur: 0.12, trem: 1, tremf: 30, k: 8 }) },
	ui_rotate: { g: "Placement and UI", d: "R rotates", gen: () => click(900, 0.015) },
	ui_hover: { g: "Placement and UI", d: "hover a button or piece", gen: () => click(1200, 0.01), gain: 0.4 },
	ui_click: { g: "Placement and UI", d: "button press", gen: () => notes([[1047, 0.02], [1319, 0.02]]) },
	ui_back: { g: "Placement and UI", d: "back / Esc", gen: () => tone({ f: 659, f1: 523, dur: 0.05 }) },
	ui_pause: { g: "Placement and UI", d: "pause opens", gen: () => tone({ f: 523, f1: 392, dur: 0.08, wave: "tri" }) },
	ui_unpause: { g: "Placement and UI", d: "pause closes", gen: () => tone({ f: 392, f1: 523, dur: 0.08, wave: "tri" }) },
	ui_buy: { g: "Placement and UI", d: "buy an upgrade, ka-ching", gen: () => layer([noise({ dur: 0.03, lp: 10000, hp: 3000 }), 0, 0.6], [bell(2093, 0.4), 0.02], [bell(3136, 0.35, 0.6), 0.1]) },
	ui_cant_afford: { g: "Placement and UI", d: "not enough currency", gen: () => layer([tone({ f: 110, dur: 0.08, k: 20 })], [tone({ f: 110, dur: 0.1, k: 20 }), 0.1]) },
	ui_reveal: { g: "Placement and UI", d: "upgrade node revealed", gen: () => layer([tone({ f: 800, f1: 2400, dur: 0.3, wave: "sin", trem: 0.6, tremf: 30, k: 5 })], [noise({ dur: 0.3, lp: 12000, hp: 6000 }), 0, 0.12]) },
	ui_unlock: { g: "Placement and UI", d: "level unlocked", gen: () => notes([[523, 0.06], [659, 0.06], [784, 0.06], [1047, 0.2]]) },
	ui_slider: { g: "Placement and UI", d: "settings slider notch", gen: () => click(800, 0.01), gain: 0.5 },
	ui_start: { g: "Placement and UI", d: "start / play", gen: () => notes([[392, 0.05], [523, 0.05], [784, 0.15]]) },

	// --- Round flow ---
	round_count: { g: "Round flow", d: "countdown beep (x3)", gen: () => tone({ f: 880, dur: 0.1, k: 20 }) },
	round_go: { g: "Round flow", d: "go!", gen: () => tone({ f: 1760, dur: 0.2, k: 10 }) },
	time_low: { g: "Round flow", d: "last seconds tick", gen: () => layer([click(1500, 0.02)], [tone({ f: 300, dur: 0.04, wave: "sin" }), 0, 0.6]) },
	time_up: { g: "Round flow", d: "time's up buzzer", gen: () => tone({ f: 196, dur: 0.5, trem: 0.7, tremf: 12, k: 4 }) },
	round_clear: { g: "Round flow", d: "cleared! jingle", gen: () => layer([notes([[523, 0.1], [659, 0.1], [784, 0.1], [1047, 0.2], [784, 0.1], [1047, 0.4]], { k: 10 })], [notes([[262, 0.3], [330, 0.3], [392, 0.5]], { wave: "tri", k: 6 }), 0, 0.5], [bell(2093, 0.6, 0.5), 0.6]) },
	round_fail: { g: "Round flow", d: "ball dropped, sad descend", gen: () => notes([[392, 0.15], [370, 0.15], [349, 0.15], [330, 0.4]], { k: 8 }, 0.02) },
	result_roll: { g: "Round flow", d: "earned total rolls up (loop)", gen: () => layer(...[...Array(16).keys()].map(i => [click(1800, 0.006), i / 16, 0.7])), gain: 0.6, loop: true },

	// --- Ideas (docs/ideas.md): cues for proposed kinds, nothing plays them yet. Splitter reuses split_pop, wedge solid_bounce, gold break coin_cascade. ---
	flipper_flick: { g: "Ideas", d: "pinball flipper snaps up", gen: () => layer([tone({ f: 180, f1: 520, dur: 0.05, duty: 0.3 })], [noise({ dur: 0.03, lp: 3000 }), 0.01, 0.5], [click(2500, 0.008), 0.04, 0.6]) },
	ramp_whoosh: { g: "Ideas", d: "ramp bends the ball sideways", gen: () => layer([noise({ dur: 0.18, lp: 1500, lp1: 5000, hp: 400, a: 0.03 })], [tone({ f: 500, f1: 900, dur: 0.15, wave: "sin" }), 0, 0.5]) },
	toll_ding: { g: "Ideas", d: "toll lamp pays a pass", gen: () => layer([click(1500, 0.01)], [bell(2637, 0.12), 0.01]) },
	rewind: { g: "Ideas", d: "rewind brick: tape squeal back to the start", gen: () => layer([tone({ f: 1400, f1: 300, dur: 0.45, wave: "saw", lp: 3000, vib: 0.08, vibf: 14, k: 5 })], ...[0, 0.08, 0.15, 0.21, 0.26, 0.3].map(t => [click(700, 0.01), t, 0.5])) },
	ghost_phase: { g: "Ideas", d: "ghost brick fades in or out", gen: () => layer([noise({ dur: 0.2, lp: 300, lp1: 3000, a: 0.05 })], [tone({ f: 440, f1: 880, dur: 0.2, wave: "sin", a: 0.05 }), 0, 0.4]) },
	gold_hit: { g: "Ideas", d: "gold brick takes a hit; ladder = hits left 5..1", gen: () => layer([bell(1568, 0.2)], [bell(2093, 0.15), 0.01, 0.5], [click(3000, 0.006), 0, 0.6]), ladder: [1, st(2), st(4), st(5), st(7)] },
	mirror_ping: { g: "Ideas", d: "mirror brick sends the ball straight back", gen: () => layer([tone({ f: 3200, f1: 2600, dur: 0.05, wave: "sin" })], [bell(2637, 0.1, 0.6), 0.02]) },
	regrow: { g: "Ideas", d: "regrow brick comes back", gen: () => tone({ f: 300, f1: 900, dur: 0.3, wave: "tri", k: 6, vib: 0.03, vibf: 8 }) },
	key_pick: { g: "Ideas", d: "key brick breaks, locks turn", gen: () => notes([[1047, 0.04], [1319, 0.04], [1568, 0.1]], { k: 12 }) },
	lock_open: { g: "Ideas", d: "lock brick opens", gen: () => layer([click(400, 0.015)], [click(600, 0.015), 0.06], [bell(1319, 0.2), 0.1]) },
	shield_floor: { g: "Ideas", d: "shield floor catches a dropped ball", gen: () => layer([tone({ f: 300, f1: 700, dur: 0.1, wave: "sin" })], [bell(1047, 0.2, 0.6), 0.03]) },
	ability_on: { g: "Ideas", d: "right-click ability starts", gen: () => tone({ f: 400, f1: 800, dur: 0.06, duty: 0.25 }) },
	ability_off: { g: "Ideas", d: "ability released", gen: () => tone({ f: 800, f1: 400, dur: 0.06, duty: 0.25 }) },
	energy_empty: { g: "Ideas", d: "ability wanted, no energy", gen: () => tone({ f: 110, dur: 0.1, trem: 1, tremf: 30, k: 10 }) },
	slow_time: { g: "Ideas", d: "slow time held (loop)", gen: () => layer([tone({ f: 82, dur: 1, wave: "tri", a: 0, k: 0, trem: 0.4, tremf: 1 })], [tone({ f: 123, dur: 1, wave: "sin", a: 0, k: 0 }), 0, 0.4]), gain: 0.3, loop: true },
	blast: { g: "Ideas", d: "paddle shockwave breaks the lowest row", gen: () => layer([noise({ dur: 0.25, lp: 4000, lp1: 200 })], [tone({ f: 200, f1: 60, dur: 0.2, wave: "sin" }), 0, 1]) },
	grow: { g: "Ideas", d: "paddle grows", gen: () => tone({ f: 200, f1: 500, dur: 0.15, wave: "tri" }) },
	recall: { g: "Ideas", d: "lowest ball yanked back to the paddle", gen: () => tone({ f: 1000, f1: 400, dur: 0.2, wave: "sin", vib: 0.05, vibf: 30 }) },

	// --- Ambient ---
	lamp_hum: { g: "Ambient", d: "electrical lamp hum (loop)", gen: () => layer([tone({ f: 120, dur: 1, wave: "sin", a: 0, k: 0 })], [tone({ f: 240, dur: 1, wave: "sin", a: 0, k: 0 }), 0, 0.3], [noise({ dur: 1, lp: 3000, hp: 2000, k: 0 }), 0, 0.04]), gain: 0.15, loop: true },
	tube_flicker: { g: "Ambient", d: "a tube crackles", gen: () => layer(...[0, 0.03, 0.09, 0.1, 0.17].map(t => [noise({ dur: 0.02, lp: 8000, hp: 2500 }), t, 0.5 + Math.random() * 0.5])), gain: 0.5 },
};

function finish(buf, gain = 1, loop = false) {
	let peak = 0;
	for (const s of buf) { if (Number.isNaN(s)) throw new Error("NaN sample"); peak = Math.max(peak, Math.abs(s)); }
	const g = (0.8 * gain) / (peak || 1), fade = loop ? 0 : Math.min(buf.length, Math.round(0.003 * SR));
	for (let i = 0; i < buf.length; i++) buf[i] *= g * (i >= buf.length - fade ? (buf.length - i) / fade : 1);
	return buf;
}

function wav(buf) {
	const b = Buffer.alloc(44 + buf.length * 2);
	b.write("RIFF", 0); b.writeUInt32LE(36 + buf.length * 2, 4); b.write("WAVE", 8);
	b.write("fmt ", 12); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22);
	b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 2, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34);
	b.write("data", 36); b.writeUInt32LE(buf.length * 2, 40);
	for (let i = 0; i < buf.length; i++) b.writeInt16LE(Math.round(Math.max(-1, Math.min(1, buf[i])) * 32767), 44 + i * 2);
	return b;
}

mkdirSync("assets/audio/wav", { recursive: true });
const meta = {};
for (const [name, c] of Object.entries(CUES)) {
	const buf = finish(c.gen(), c.gain, c.loop);
	writeFileSync(`assets/audio/wav/${name}.wav`, wav(buf));
	meta[name] = { g: c.g, d: c.d, ms: Math.round(buf.length / SR * 1000), loop: !!c.loop, ladder: c.ladder ?? null };
}

const html = `<!doctype html><meta charset="utf-8"><title>BreakIn cremental audio</title>
<style>
body{background:#000020;color:#ffffcf;font:14px/1.4 ui-monospace,monospace;margin:0;padding:16px 24px;max-width:960px}
h1{color:#ff4aff;font-size:20px}h2{color:#15f2b0;font-size:15px;margin:24px 0 8px;border-bottom:1px solid #2e2e5c}
.row{display:flex;align-items:center;gap:8px;padding:3px 0}.row:hover{background:#0a0a30}
button{background:#2e2e5c;color:#ffffcf;border:1px solid #5454a7;border-radius:3px;padding:3px 10px;cursor:pointer;font:inherit}
button:hover{background:#5454a7}button.play{min-width:36px;color:#ffff00}button.on{background:#a200a2}
.name{width:150px;color:#ffcaff}.desc{flex:1;color:#9797d5}.ms{width:50px;text-align:right;color:#5454a7}
.lad button{padding:2px 6px;font-size:12px}.scene{margin-right:8px}p{color:#9797d5}
</style>
<h1>BreakIn cremental &mdash; audio cues</h1>
<p>Generated by <code>assets/audio/gen.mjs</code>. Played by src/sfx.gd. Ladder buttons play the same file at a different rate, as the game would with <code>pitch_scale</code>. Loops toggle.</p>
<p>Scenes: <button class="scene" onclick="scene('combo')">combo run</button><button class="scene" onclick="scene('jackpot')">jackpot moment</button><button class="scene" onclick="scene('buy')">buy upgrade</button><button class="scene" onclick="scene('fail')">round lost</button><button class="scene" onclick="scene('clear')">round cleared</button></p>
<div id="list"></div>
<script>
const M=${JSON.stringify(meta)};
const loops={};
function play(n,rate=1){const a=new Audio('wav/'+n+'.wav');a.preservesPitch=false;a.playbackRate=rate;a.play();return a}
function toggle(n,btn){if(loops[n]){loops[n].pause();delete loops[n];btn.classList.remove('on')}else{const a=play(n);a.loop=true;loops[n]=a;btn.classList.add('on')}}
const after=(ms,f)=>setTimeout(f,ms);
const SCENES={
 combo:()=>{for(let i=0;i<8;i++)after(i*160,()=>{play('brick_break');after(30,()=>play('combo_tick',Math.pow(1.05946,i)));if(i==3||i==7)after(60,()=>play('combo_up'))});after(8*160+400,()=>play('combo_drop'))},
 jackpot:()=>{play('brick_break');after(40,()=>play('jackpot'));after(500,()=>play('coin_cascade'));for(let i=0;i<20;i++)after(900+i*40,()=>play('count_tick'))},
 buy:()=>{play('ui_click');after(80,()=>play('ui_buy'));after(600,()=>play('ui_reveal'))},
 fail:()=>{play('ball_bounce');after(300,()=>play('paddle_hit'));after(900,()=>play('ball_lost'));after(1300,()=>play('round_fail'))},
 clear:()=>{play('brick_break');after(150,()=>play('brick_break'));after(300,()=>play('brick_break'));after(360,()=>play('round_clear'));for(let i=0;i<15;i++)after(1400+i*50,()=>play('count_tick'))},
};
const scene=k=>SCENES[k]();
const list=document.getElementById('list');let g='';
for(const [n,m] of Object.entries(M)){
 if(m.g!==g){g=m.g;const h=document.createElement('h2');h.textContent=g;list.appendChild(h)}
 const r=document.createElement('div');r.className='row';
 r.innerHTML='<button class="play">&#9654;</button><span class="name">'+n+'</span><span class="desc">'+m.d+'</span><span class="ms">'+m.ms+'ms</span><span class="lad"></span>';
 const b=r.querySelector('.play');b.onclick=()=>m.loop?toggle(n,b):play(n);
 const lad=r.querySelector('.lad');
 if(m.ladder)m.ladder.forEach((rt,i)=>{const x=document.createElement('button');x.textContent=(i+1);x.title='rate '+rt.toFixed(2);x.onclick=()=>play(n,rt);lad.appendChild(x)});
 list.appendChild(r);
}
</script>`;
writeFileSync("assets/audio/demo.html", html);
console.log(`${Object.keys(CUES).length} cues -> assets/audio/wav/, demo.html`);
