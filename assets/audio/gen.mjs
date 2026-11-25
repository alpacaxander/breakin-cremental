// Procedural sound: square-wave bleeps with a modern punch (docs/audio.md).
// Generates assets/audio/wav/<cue>.wav (44.1 kHz mono 16-bit) and assets/audio/demo.html.
// Run from the repo root: nix develop -c node assets/audio/gen.mjs   (no dependencies). Played by src/autoload/sfx.gd.
// The numbers each file must meet (length, peak, RMS, no clipping, the loop's seam) are checked in tests/cases/audio.gd.
// music.wav loops through edit/loop_mode=2 (Forward) in its .import, which a regen leaves alone.
import { writeFileSync, mkdirSync } from "node:fs";

const SR = 44100;
const TAU = Math.PI * 2;

// Seeded noise so a regen rewrites only the cues whose recipe changed, not every wav. ponytail: mulberry32, fine for white noise.
let rs = 0;
Math.random = () => { rs = (rs + 0x6d2b79f5) | 0; let t = Math.imul(rs ^ (rs >>> 15), 1 | rs); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };

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
// The punch under a big cue: a low sine thump and a noise burst.
const punch = (thump = 110, dur = 0.3, g = 1) => layer([tone({ f: thump, f1: thump / 3, dur, wave: "sin", a: 0.001 }), 0, g], [noise({ dur: dur * 0.6, lp: 6000, lp1: 300 }), 0, 0.5 * g]);

// name: { g: group, d: what plays it, gen, gain? }. The names are the cue constants in src/autoload/sfx.gd.
const CUES = {
	// --- Ball and paddle ---
	paddle_hit: { g: "Ball and paddle", d: "ball bounces off the paddle", gen: () => layer([tone({ f: 440, f1: 294, dur: 0.07 })], [tone({ f: 150, f1: 70, dur: 0.06, wave: "sin" }), 0, 0.7]) },
	wall_bounce: { g: "Ball and paddle", d: "ball bounces off a wall or a Wall Segment", gen: () => tone({ f: 880, f1: 740, dur: 0.04, duty: 0.25 }), gain: 0.8 },
	ball_lost: { g: "Ball and paddle", d: "a ball leaves through the open side (big)", gen: () => layer([tone({ f: 660, f1: 110, dur: 0.45, vib: 0.03, vibf: 18, k: 5 })], [punch(90, 0.35), 0, 1.1]) },
	// --- Bricks ---
	brick_hit: { g: "Bricks", d: "a brick takes a hit and stays", gen: () => tone({ f: 1047, f1: 990, dur: 0.035, duty: 0.25 }), gain: 0.8 },
	brick_break: { g: "Bricks", d: "a brick breaks; the game climbs a pentatonic scale per combo step", gen: () => layer([tone({ f: 659, f1: 523, dur: 0.06 })], [noise({ dur: 0.05, lp: 6000, lp1: 1500 }), 0.005, 0.35]) },
	gold_brick: { g: "Bricks", d: "a gold brick breaks", gen: () => notes([[988, 0.05], [1319, 0.18]], { k: 16 }) },
	hourglass_brick: { g: "Bricks", d: "an hourglass brick breaks, time is added", gen: () => layer([click(1500, 0.02)], [click(1000, 0.02), 0.07], [tone({ f: 784, f1: 1568, dur: 0.12, duty: 0.25 }), 0.14]) },
	// --- Placeables ---
	bumper: { g: "Placeables", d: "ball bounces off a Bumper", gen: () => layer([tone({ f: 330, f1: 250, dur: 0.06, duty: 0.3 })], [noise({ dur: 0.03, lp: 2500 }), 0, 0.4], [tone({ f: 90, dur: 0.05, wave: "sin" }), 0, 0.8]) },
	booster: { g: "Placeables", d: "ball passes a Booster and speeds up", gen: () => layer([tone({ f: 300, f1: 1200, dur: 0.12, duty: 0.25, k: 12 })], [noise({ dur: 0.12, lp: 800, lp1: 6000, hp: 300, a: 0.03 }), 0, 0.3]) },
	splitter: { g: "Placeables", d: "a new ball: a Splitter's or the Multiball volley's; also a Power Brick breaking", gen: () => notes([[990, 0.04], [660, 0.04], [990, 0.06]]) },
	// --- Abilities ---
	catch: { g: "Abilities", d: "the paddle catches a drop: one more charge", gen: () => layer([tone({ f: 660, f1: 1320, dur: 0.05, duty: 0.25, k: 10 })], [tone({ f: 1320, f1: 1760, dur: 0.1, duty: 0.125, k: 24 }), 0.045], [noise({ dur: 0.03, lp: 12000, hp: 4000 }), 0.045, 0.3]) },
	zap: { g: "Abilities", d: "a Zap goes off along its row", gen: () => layer([tone({ f: 2000, f1: 200, dur: 0.14, trem: 0.8, tremf: 90 })], [noise({ dur: 0.1, lp: 9000, hp: 1500 }), 0, 0.5]) },
	explosion: { g: "Abilities", d: "a Blast goes off (big)", gen: () => layer([noise({ dur: 0.5, lp: 3000, lp1: 120 })], [tone({ f: 220, f1: 55, dur: 0.25 }), 0, 0.45], [punch(110, 0.4), 0, 1.3]) },
	// --- Round ---
	round_start: { g: "Round", d: "Start is pressed, the ball launches", gen: () => notes([[392, 0.06], [523, 0.06], [784, 0.16]], { duty: 0.25, k: 14 }) },
	low_timer_tick: { g: "Round", d: "each whole second at or under the low-time mark", gen: () => layer([click(1500, 0.02)], [tone({ f: 300, dur: 0.04, wave: "sin" }), 0, 0.6]) },
	level_cleared: { g: "Round", d: "every brick is broken (big)", gen: () => layer([notes([[523, 0.08], [659, 0.08], [784, 0.08], [1047, 0.32]], { k: 9 })], [notes([[131, 0.24], [196, 0.32]], { wave: "tri", k: 6 }), 0, 0.5], [punch(130, 0.3), 0.24, 0.9]) },
	tally_tick: { g: "Round", d: "the summary counts up", gen: () => click(2000, 0.008), gain: 0.6 },
	// --- UI ---
	click: { g: "UI", d: "any button press (Sfx plays it)", gen: () => notes([[1047, 0.02], [1319, 0.02]]), gain: 0.7 },
	buy: { g: "UI", d: "an upgrade is bought", gen: () => layer([noise({ dur: 0.03, lp: 10000, hp: 3000 }), 0, 0.5], [notes([[1319, 0.05], [1760, 0.05], [2093, 0.16]], { duty: 0.25, k: 14 }), 0.02]) },
	cant_afford: { g: "UI", d: "Buy is pressed without the coins", gen: () => layer([tone({ f: 110, dur: 0.08, k: 20 })], [tone({ f: 110, dur: 0.1, k: 20 }), 0.1]) },
	place_item: { g: "UI", d: "an item is put down in Setup", gen: () => layer([tone({ f: 659, f1: 523, dur: 0.04 })], [noise({ dur: 0.03, lp: 1500 }), 0, 0.4]) },
};

// The placeholder loop: square lead, triangle bass, noise hi-hat. 16 bars of 4/4 at 150 bpm, A minor, Am F C G.
// Every note fades out inside its own slot, so the loop starts and ends on silence and the seam has no click.
const BPM = 150, BARS = 16, E8 = 60 / BPM / 2; // seconds per eighth note
function music() {
	const L = Math.round(BARS * 8 * E8 * SR), out = new Float32Array(L);
	const put = (buf, at, g) => { const o = Math.round(at * SR), m = Math.min(buf.length, L - o), f = Math.round(0.005 * SR); for (let i = 0; i < m; i++) out[o + i] += buf[i] * g * Math.min(1, (m - 1 - i) / f); };
	const hz = n => 440 * Math.pow(2, n / 12); // semitones from A4
	const roots = [-24, -28, -21, -26]; // bass roots A2 F2 C3 G2: Am F C G
	const chords = [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]]; // chord tones from A4
	const shape = [0, 2, 1, 2, 0, 1, 2, 1]; // which chord tone each eighth plays
	for (let bar = 0; bar < BARS; bar++) {
		const c = Math.floor(bar / 2) % 4, t0 = bar * 8 * E8;
		for (let e = 0; e < 8; e++) {
			const t = t0 + e * E8;
			put(tone({ f: hz(roots[c] + (e % 2 ? 12 : 0)), dur: E8 * 0.9, wave: "tri", k: 3 }), t, 0.5);
			put(noise({ dur: 0.04, lp: 12000, hp: 6000, a: 0.001 }), t, e % 2 ? 0.25 : 0.12);
			const rest = bar % 4 === 3 && e >= 6; // breathe at the end of each phrase
			if (!rest && (e % 2 === 0 || bar % 2 === 1)) put(tone({ f: hz(chords[c][shape[(e + bar) % 8]] + (bar >= 8 ? 12 : 0)), dur: E8 * 0.9, duty: 0.25, k: 6 }), t, 0.22);
		}
	}
	return out;
}

function finish(buf, gain = 1, loop = false) {
	let peak = 0;
	for (const s of buf) { if (Number.isNaN(s)) throw new Error("NaN sample"); peak = Math.max(peak, Math.abs(s)); }
	const g = (0.8 * gain) / (peak || 1), fade = loop ? 0 : Math.min(buf.length, Math.round(0.003 * SR));
	for (let i = 0; i < buf.length; i++) buf[i] *= g * (i >= buf.length - fade ? (buf.length - 1 - i) / fade : 1);
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

CUES.music = { g: "Music", d: "the placeholder loop, on the Music bus, quieter than the sounds", gen: music, gain: 0.45, loop: true };

mkdirSync("assets/audio/wav", { recursive: true });
const meta = {};
for (const [name, c] of Object.entries(CUES)) {
	rs = [...name].reduce((h, ch) => Math.imul(h ^ ch.charCodeAt(0), 16777619), 0x811c9dc5); // per-cue seed: a recipe change rewrites only its own wav
	const buf = finish(c.gen(), c.gain, c.loop);
	writeFileSync(`assets/audio/wav/${name}.wav`, wav(buf));
	meta[name] = { g: c.g, d: c.d, ms: Math.round(buf.length / SR * 1000), loop: !!c.loop };
}

// The combo climb as Sfx plays it: one pentatonic step per combo step, up to two octaves.
const climb = [...Array(11).keys()].map(i => Math.pow(2, (12 * Math.floor(i / 5) + [0, 2, 4, 7, 9][i % 5]) / 12));

const html = `<!doctype html><meta charset="utf-8"><title>BreakIn cremental audio</title>
<style>
body{background:#14151c;color:#e6e8ef;font:14px/1.4 ui-monospace,monospace;margin:0;padding:16px 24px;max-width:960px}
h1{font-size:20px}h2{font-size:15px;margin:24px 0 8px;border-bottom:1px solid #3a3d4d}
.row{display:flex;align-items:center;gap:8px;padding:3px 0}
button{background:#2a2c38;color:#e6e8ef;border:1px solid #4a4e62;border-radius:3px;padding:3px 10px;cursor:pointer;font:inherit}
button:hover{background:#4a4e62}button.on{background:#2f7d8c}
.name{width:150px}.desc{flex:1;color:#9a9eb2}.ms{width:60px;text-align:right;color:#6b7086}p{color:#9a9eb2}
</style>
<h1>BreakIn cremental: audio cues</h1>
<p>Generated by <code>assets/audio/gen.mjs</code>, played by <code>src/autoload/sfx.gd</code>. Judge them by ear here. The music button toggles the loop.</p>
<p>Scenes: <button onclick="combo()">combo climb (brick_break)</button> <button onclick="burst()">64 breaks in one frame, capped and staggered</button></p>
<div id="list"></div>
<script>
const M=${JSON.stringify(meta)}, CLIMB=${JSON.stringify(climb)}, VOICES=4, STAGGER=15;
const loops={};
function play(n,rate=1){const a=new Audio('wav/'+n+'.wav');a.preservesPitch=false;a.playbackRate=rate;a.play();return a}
function toggle(n,b){if(loops[n]){loops[n].pause();delete loops[n];b.classList.remove('on')}else{const a=play(n);a.loop=true;loops[n]=a;b.classList.add('on')}}
function combo(){CLIMB.concat([CLIMB[10],CLIMB[10]]).forEach((r,i)=>setTimeout(()=>play('brick_break',r),i*140))}
function burst(){play('zap');for(let i=0;i<VOICES;i++)setTimeout(()=>play('brick_break'),i*STAGGER)}
const list=document.getElementById('list');let g='';
for(const [n,m] of Object.entries(M)){
 if(m.g!==g){g=m.g;const h=document.createElement('h2');h.textContent=g;list.appendChild(h)}
 const r=document.createElement('div');r.className='row';
 r.innerHTML='<button>&#9654;</button><span class="name">'+n+'</span><span class="desc">'+m.d+'</span><span class="ms">'+m.ms+' ms</span>';
 const b=r.querySelector('button');b.onclick=()=>m.loop?toggle(n,b):play(n);
 list.appendChild(r);
}
</script>`;
writeFileSync("assets/audio/demo.html", html);
console.log(`${Object.keys(CUES).length} files -> assets/audio/wav/, demo.html`);
