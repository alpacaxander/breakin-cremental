// Deep Net regulars (docs/content/maps/deep-net.md, Enemies): worm, mirror_daemon, rootkit 64 wide; glitch, null, packet_storm, ghost_process, checksum 48 wide; all 48 tall.
// Strips per enemy, as parts/enemies.mjs: <id>_idle x4 @8 (loop), <id>_hit x6 @12, <id>_attack x6 @12 (hazard spawns on frame 3, the release pose), <id>_die x8 @12 (ends blank).
// Feet on the bottom row, body centred, anchored bottom centre. Look from kit() in parts/enemies.mjs: dark body, one lit red accent;
// the virus carriers (worm, rootkit) spit and pulse in the Green set (docs/art-style.md), the colour the map's virus brick uses.
// h = { Img, C, def, blank, text } from gen.mjs's MAPH.
import { kit } from "./enemies.mjs";

const GROUP = "Enemies: Deep Net";
const GRN = { tube: "00ff00", ring: "00bf00", deep: "003f00", hi: "a0ff60" };  // docs/art-style.md Green set
const W64 = ["worm", "mirror_daemon", "rootkit"];
const IDS = ["worm", "glitch", "mirror_daemon", "null", "packet_storm", "rootkit", "ghost_process", "checksum"];

export function emit({ Img, C, def, blank, text }) {
	const { E, RED, flash, hot, oval, block, eye, std } = kit(C);
	// One enemy's four strips: idle 4, hit = std(base, 2 recoil), attack 6, die = flash, hot, 3 poses, the last pose fading out, blank.
	const four = (id, idle, recoil, attack, die) => {
		const w = idle[0].w, B = idle[0];
		def(GROUP, `${id}_idle`, 8, idle);
		def(GROUP, `${id}_hit`, 12, std(B, recoil));
		def(GROUP, `${id}_attack`, 12, attack);
		def(GROUP, `${id}_die`, 12, [flash(B), hot(B), ...die, die[2].fade(170), die[2].fade(90), blank(w, 48)]);
	};
	// Dashed ellipse outline; `o` marches the dashes.
	const dashOval = (f, cx, cy, rx, ry, c, o = 0) => { const n = Math.ceil((rx + ry) * 4); for (let i = 0; i < n; i++) if (((i + o) >> 1) & 1) { const t = i / n * Math.PI * 2; f.px(Math.round(cx + rx * Math.cos(t)), Math.round(cy + ry * Math.sin(t)), c); } };
	const blob = (f, x, y) => { f.rect(x, y, 6, 6, GRN.tube); f.outline(x, y, 6, 6, GRN.ring); f.rect(x + 1, y + 1, 2, 1, GRN.hi); f.px(x + 1, y + 2, GRN.hi); };

	// -- worm 64x48: a string of glyph segments (1s and 0s) on a sine, the head on the right with a red eye. Rears and spits a green virus chunk. --
	const worm = ({ ph = 0, amp = 2, rear = 0, gap = 8, drop = 0, eyeC = RED.tube, spit = 0, glyph = E.chrome } = {}) => {
		const f = new Img(64, 48);
		for (let i = 0; i < 6; i++) {   // tail on the floor, the string climbing toward the head; `drop` lays it back down
			const x = 1 + i * gap, y = Math.min(39, 39 - Math.round(i * 2.5) - Math.round(amp * Math.sin(ph + i * 1.1)) - (i === 5 ? rear >> 1 : 0) + Math.round(drop * i / 2));
			block(f, x, y, 8, 9); text(f, x + 3, y + 2, i & 1 ? "0" : "1", glyph);
		}
		const hx = 1 + 6 * gap, hy = Math.min(34, 16 - rear + drop * 3);   // head
		block(f, hx, hy, 14, 14); f.rect(hx + 1, hy + 10, 12, 1, E.rim); eye(f, hx + 6, hy + 4, 5, 3, eyeC);
		f.rect(hx + 3, hy + 11, 2, 2, E.chrome); f.rect(hx + 9, hy + 11, 2, 2, E.chrome);   // fangs
		if (spit) blob(f, hx + 4 + spit * 2, hy - 8 - spit * 2);
		return f;
	};
	four("worm",
		[0, 1, 2, 3].map((k) => worm({ ph: k * Math.PI / 2 })),
		[worm({ amp: 1, rear: -2, eyeC: RED.dim, gap: 7 }), worm({ amp: 2, gap: 7 })],
		[worm({ rear: 3 }), worm({ rear: 6, amp: 1 }), worm({ rear: 9, amp: 0 }), worm({ rear: -2, spit: 2 }), worm({ rear: 1, ph: 1 }), worm()],
		[worm({ amp: 1, rear: -3, eyeC: RED.dim }), worm({ amp: 0, drop: 3, glyph: E.hi, eyeC: RED.dim }), worm({ amp: 0, drop: 6, glyph: E.rim, eyeC: null })]);

	// -- glitch 48x48: a boxy face whose rows tear sideways a little differently every frame; the attack scrambles it into chunks. --
	const glitchBody = ({ eyeC = RED.tube, mouth = RED.dim } = {}) => {
		const f = new Img(48, 48);
		block(f, 9, 8, 30, 32); block(f, 13, 40, 6, 8); block(f, 29, 40, 6, 8);
		eye(f, 14, 16, 6, 4, eyeC); eye(f, 28, 16, 6, 4, eyeC);
		f.ascii(14, 28, ["#.#.#.#.#.#.#.#.#.#", ".#.#.#.#.#.#.#.#.#."], { "#": mouth });
		return f;
	};
	// Shift row bands sideways: bands = [[y0, y1, dx], ...]; a red tear line marks each torn band's top edge.
	const tear = (src, bands, line = RED.tube) => {
		const f = src.crop(0, 0, 48, 48);
		for (const [y0, y1, dx] of bands) { for (let y = y0; y < y1; y++) for (let x = 0; x < 48; x++) f.clear(x, y); for (let y = y0; y < y1; y++) for (let x = 0; x < 48; x++) { const p = src.get(x, y); if (p[3]) f.px(x + dx, y, p); } if (line) for (let x = 0; x < 48; x++) if (f.get(x, y0)[3]) f.px(x, y0, line); }
		return f;
	};
	const GB = glitchBody();
	four("glitch",
		[tear(GB, [[12, 15, 3]]), tear(GB, [[22, 26, -4], [34, 36, 2]]), tear(GB, [[8, 11, -2], [29, 31, 4]]), tear(GB, [[17, 20, 5]], null)],
		[tear(glitchBody({ eyeC: RED.dim }), [[8, 20, 4], [20, 32, -4]]), tear(GB, [[14, 18, 2]])],
		[tear(GB, [[10, 14, 3], [26, 30, -3]]), tear(GB, [[8, 16, -5], [16, 24, 5], [32, 38, -3]]), tear(glitchBody({ eyeC: RED.hi }), [[8, 14, 8], [14, 22, -8], [22, 30, 6], [30, 40, -6]]), tear(glitchBody({ eyeC: C.pureWhite, mouth: RED.tube }), [[8, 20, -10], [20, 30, 10], [30, 40, -4]], C.pureWhite), tear(GB, [[18, 24, 3]]), GB],
		[tear(glitchBody({ eyeC: RED.dim }), [[8, 18, 6], [18, 28, -6], [28, 40, 4]]), tear(glitchBody({ eyeC: null }), [[8, 14, -12], [14, 20, 12], [20, 26, -9], [26, 34, 9], [34, 48, -4]], RED.dim), tear(glitchBody({ eyeC: null, mouth: E.rim }), [[0, 12, 16], [12, 24, -16], [24, 36, 14], [36, 48, -14]], null)]);

	// -- mirror_daemon 64x48: the player's paddle in red, horned, floating over a mirror line with its faded reflection below. Its reflection flares to full on the attack, the controls flipping. --
	const mirror = ({ dy = 0, eyeC = RED.hi, stripe = RED.tube, refl = 110, line = E.chrome, crack = 0, tilt = 0 } = {}) => {
		const top = new Img(64, 38), py = 26 + dy;
		const paddle = (x0, w, t) => {   // t: tilt, the far end drops t px
			for (let i = 0; i < w; i++) { const x = x0 + i, y = py + Math.round(t * i / w); top.rect(x, y, 1, 9, E.rim); if (i > 0 && i < w - 1) { top.rect(x, y + 1, 1, 7, E.fill); top.px(x, y + 1, E.hi); top.rect(x, y + 4, 1, 2, stripe); } }
			top.clear(x0, py); top.clear(x0 + w - 1, py + t);
		};
		if (crack) { paddle(4, 27, crack); paddle(33, 27, crack); } else paddle(4, 56, tilt);
		for (const hx of [10, 49]) top.ascii(hx, py - 6, ["#....", "##...", ".##..", ".###.", "..###", "..###"].map((r) => hx > 30 ? [...r].reverse().join("") : r), { "#": E.rim });  // horns
		if (eyeC && !crack) { top.rect(24, py + 4, 3, 2, eyeC); top.rect(37, py + 4, 3, 2, eyeC); }
		const f = new Img(64, 48), low = new Img(64, 10);
		for (let y = 0; y < 10; y++) for (let x = 0; x < 64; x++) { const p = top.get(x, 37 - y); if (p[3]) low.px(x, y, p); }
		f.blit(top, 0, 0); f.blit(low.fade(refl), 0, 38);   // the flip: the reflection comes up to full
		for (let x = 2; x < 62; x++) if (!crack || (x % 9) > crack) f.px(x, 37, line);
		return f;
	};
	four("mirror_daemon",
		[mirror(), mirror({ dy: -1 }), mirror({ dy: -2 }), mirror({ dy: -1 })],
		[mirror({ dy: 1, tilt: 3, eyeC: RED.dim }), mirror({ tilt: 1 })],
		[mirror({ dy: -2, refl: 140 }), mirror({ dy: -3, refl: 180, stripe: RED.hi }), mirror({ dy: -3, refl: 220, stripe: RED.hi, line: C.pureWhite }), mirror({ dy: 1, refl: 255, stripe: C.pureWhite, line: C.pureWhite }), mirror({ refl: 170 }), mirror()],
		[mirror({ crack: 1, eyeC: RED.dim }), mirror({ crack: 3, dy: 2, stripe: RED.dim }), mirror({ crack: 5, dy: 3, stripe: RED.deep, refl: 50 })]);

	// -- null 48x48: a tall hole, a void of the backdrop colour in a dark rim with a marching dashed outline and one red pinpoint. --
	const nul = ({ o = 0, rx = 15, ry = 20, eyeC = RED.tube, eyeR = 1, flare = 0 } = {}) => {
		const f = new Img(48, 48), cy = 47 - ry;
		oval(f, 24, cy, rx, ry, false);
		const vx = rx - 3, vy = ry - 3;
		for (let y = cy - vy; y < cy + vy; y++) for (let x = 24 - vx; x < 24 + vx; x++) if (((x + .5 - 24) / vx) ** 2 + ((y + .5 - cy) / vy) ** 2 <= 1) f.px(x, y, C.base);
		dashOval(f, 24, cy, rx + 1, ry + 1, E.chrome, o);
		if (eyeC) f.rect(24 - eyeR, cy - eyeR, eyeR * 2, eyeR * 2, eyeC);
		if (flare) for (let k = 2; k <= flare; k++) for (const [sx, sy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) f.px(24 + sx * k - (sx < 0 ? 1 : 0), cy + sy * k - (sy < 0 ? 1 : 0), k === flare ? RED.hi : RED.tube);
		return f;
	};
	four("null",
		[nul(), nul({ o: 1, eyeC: RED.dim }), nul({ o: 2 }), nul({ o: 3, eyeC: RED.hi })],
		[nul({ rx: 18, ry: 17, eyeC: RED.dim }), nul({ rx: 16, ry: 19 })],
		[nul({ rx: 16, ry: 21, eyeR: 2, o: 1 }), nul({ rx: 17, ry: 22, eyeR: 2, o: 2, eyeC: RED.hi }), nul({ rx: 18, ry: 23, eyeR: 3, o: 3, eyeC: RED.hi, flare: 5 }), nul({ rx: 18, ry: 23, eyeR: 3, eyeC: C.pureWhite, flare: 9 }), nul({ rx: 16, ry: 21, eyeR: 2 }), nul()],
		[nul({ rx: 11, ry: 15, eyeC: RED.dim }), nul({ rx: 7, ry: 9, eyeC: RED.dim, o: 1 }), nul({ rx: 4, ry: 5, eyeC: null, o: 2 })]);

	// -- packet_storm 48x48: a router head with LED eyes and an antenna, raining columns of packet dots to the floor. --
	const storm = ({ step = 0, gap = 8, dot = E.chrome, led = RED.tube, dy = 0, fall = 0, spread = 0 } = {}) => {
		const f = new Img(48, 48);
		[9, 15, 21, 27, 33, 39].forEach((x, c) => {
			for (let y = 15 + ((step + c * 3) % gap); y < 48; y += gap) { const yy = y + fall * (1 + (c & 1)), xx = x + Math.round(spread * (x - 24) / 15 * (y - 15) / 32); if (yy < 48) f.rect(xx - 1, yy, 2, 2, c === 2 ? RED.dim : dot); }
		});
		block(f, 10, 4 + dy, 28, 10); f.rect(23, 0 + dy, 2, 4, E.rim); f.px(23, 0 + dy, led ?? E.rim);
		for (const x of [15, 20, 27, 32]) if (led) f.rect(x, 8 + dy, 2, 2, x === 20 || x === 27 ? led : RED.dim);
		return f;
	};
	four("packet_storm",
		[0, 2, 4, 6].map((s) => storm({ step: s })),
		[storm({ step: 1, dy: -2, led: RED.dim, spread: -3 }), storm({ step: 3, dy: -1 })],
		[storm({ step: 0, gap: 6, led: RED.hi }), storm({ step: 3, gap: 5, dot: RED.dim, led: RED.hi }), storm({ step: 1, gap: 4, dot: RED.tube, led: C.pureWhite, dy: -1 }), storm({ step: 3, gap: 4, dot: RED.hi, led: C.pureWhite, spread: 8, dy: -2 }), storm({ step: 2, gap: 6, spread: 3 }), storm()],
		[storm({ led: RED.dim, fall: 2 }), storm({ led: null, fall: 6, dy: 4, dot: E.hi }), storm({ led: null, fall: 12, dy: 8, dot: E.rim })]);

	// -- rootkit 64x48: a cable core with a red eye, roots of cable branching down and out to the floor; a green pulse runs the roots. --
	const ROOTS = [[[32, 16], [32, 24], [20, 32], [10, 40], [4, 47]], [[20, 32], [18, 47]], [[32, 24], [44, 32], [54, 40], [60, 47]], [[44, 32], [46, 47]], [[32, 24], [30, 36], [32, 47]]];
	const rootkit = ({ pulse = 0, lift = 0, sag = 0, eyeC = RED.tube, tips = null, cut = 0 } = {}) => {
		const f = new Img(64, 48), at = (pts, t) => { const n = pts.length - 1, i = Math.min(n - 1, Math.floor(t * n)), u = t * n - i; return [Math.round(pts[i][0] + (pts[i + 1][0] - pts[i][0]) * u), Math.round(pts[i][1] + (pts[i + 1][1] - pts[i][1]) * u)]; };
		const pts = ROOTS.map((r) => r.map(([x, y], i) => [x, y + (i === 0 ? -lift : i < 2 ? -Math.round(lift / 2) : 0) + (y < 47 ? sag : 0)]));
		for (const pass of [0, 1]) for (const p of pts) for (let i = 0; i + 1 < p.length; i++) {
			if (cut && i === 0 && p === pts[0]) continue;
			const [a, b] = [p[i], p[i + 1]];
			if (pass) f.line(a[0], a[1], b[0], b[1], E.hi); else for (const [ox, oy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) f.line(a[0] + ox, a[1] + oy, b[0] + ox, b[1] + oy, E.rim);
		}
		const cy = 10 - lift + sag + cut;
		oval(f, 32, cy, 9, 8); for (const x of [26, 32, 37]) f.rect(x, cy - 9, 1, 2, E.rim);  // core, cable stubs
		eye(f, 30, cy - 2, 5, 3, eyeC);
		if (pulse != null) for (const p of pts) { const [x, y] = at(p, pulse); f.rect(x - 1, y - 1, 2, 2, GRN.tube); }
		if (tips) for (const p of pts) { const [x, y] = p[p.length - 1]; f.rect(x - 1, 46, 3, 2, tips); }
		return f;
	};
	four("rootkit",
		[0, .25, .5, .75].map((t) => rootkit({ pulse: t })),
		[rootkit({ pulse: null, lift: -2, eyeC: RED.dim }), rootkit({ pulse: null, lift: -1 })],
		[rootkit({ pulse: .2, lift: 2 }), rootkit({ pulse: .5, lift: 4, eyeC: RED.hi }), rootkit({ pulse: .8, lift: 5, eyeC: RED.hi, tips: GRN.ring }), rootkit({ pulse: null, lift: 3, eyeC: C.pureWhite, tips: GRN.hi }), rootkit({ pulse: null, lift: 1, tips: GRN.deep }), rootkit({ pulse: 0 })],
		[rootkit({ pulse: null, sag: 2, eyeC: RED.dim }), rootkit({ pulse: null, sag: 4, cut: 6, eyeC: RED.dim }), rootkit({ pulse: null, sag: 4, cut: 14, eyeC: null })]);

	// -- ghost_process 48x48: a glob gone faint, see-through body under a marching dashed outline (the ghost brick's dash), dim red eye. Phases out and back to attack. --
	const ghost = ({ o = 0, a = 110, rx = 16, ry = 12, dy = 0, eyeC = RED.tube, dash = E.chrome } = {}) => {
		const b = new Img(48, 48), cy = 47 - ry + dy;
		oval(b, 24, cy, rx, ry);
		for (const x of [15, 30]) { b.rect(x - 1, cy - ry - 3, 5, 5, E.rim); b.rect(x, cy - ry - 2, 3, 4, E.fill); }
		const f = b.fade(a);
		if (dash) dashOval(f, 24, cy, rx, ry, dash, o);
		if (eyeC) eye(f, 26, cy - 3, 7, 4, eyeC);
		return f;
	};
	four("ghost_process",
		[ghost(), ghost({ o: 1, a: 90 }), ghost({ o: 2, a: 70, eyeC: RED.dim }), ghost({ o: 3, a: 90 })],
		[ghost({ rx: 19, ry: 9, eyeC: RED.dim, a: 160 }), ghost({ rx: 17, ry: 11, o: 1 })],
		[ghost({ a: 60, o: 1 }), ghost({ a: 25, o: 2, eyeC: RED.dim, dash: E.rim }), ghost({ a: 0, o: 3, eyeC: RED.dim, dash: null, rx: 14, ry: 15 }), ghost({ a: 255, rx: 18, ry: 14, eyeC: RED.hi }), ghost({ a: 160, o: 1 }), ghost()],
		[ghost({ a: 80, rx: 18, ry: 10, eyeC: RED.dim, o: 1 }), ghost({ a: 50, rx: 20, ry: 7, eyeC: RED.deep, o: 2 }), ghost({ a: 25, rx: 22, ry: 4, eyeC: null, dash: E.rim, o: 3 })]);

	// -- checksum 48x48: a display box on two stubby legs, showing a red two-digit number that never holds; the attack runs it to 00. --
	const check = ({ n = "37", c = RED.tube, dx = 0, dy = 0, legs = 0, panel = true } = {}) => {
		const f = new Img(48, 48);
		block(f, 14, 40 + legs, 6, 8 - legs); block(f, 28, 40 + legs, 6, 8 - legs);
		if (!panel) return f;
		block(f, 5 + dx, 10 + dy + legs, 38, 30); f.rect(9 + dx, 15 + dy + legs, 30, 16, C.base);   // body, screen
		text(f, 17 + dx, 18 + dy + legs, n, c, 2);
		f.rect(21 + dx, 3 + dy + legs, 6, 7, E.rim); f.rect(22 + dx, 4 + dy + legs, 4, 6, E.fill);       // neck tab
		for (const x of [11, 15]) f.rect(x + dx, 34 + dy + legs, 2, 2, x === 11 ? RED.dim : E.hi);       // status LEDs
		return f;
	};
	four("checksum",
		["37", "81", "04", "52"].map((n) => check({ n })),
		[check({ n: "88", c: RED.dim, dx: 2, dy: -1 }), check({ n: "19", dx: 1 })],
		[check({ n: "99", c: RED.hi }), check({ n: "50", c: RED.hi, dy: -1 }), check({ n: "10", c: RED.hi, dy: -2 }), check({ n: "00", c: C.pureWhite, dy: -3 }), check({ n: "00", dy: -1 }), check({ n: "37" })],
		[check({ n: "00", c: RED.dim }), check({ n: "0", c: RED.deep, legs: 4 }), check({ n: "", legs: 6 })]);
}

// Strip contract (docs/animations.md Enemies): name, frame width, frames. Height is always 48.
export const STRIPS = IDS.flatMap((id) => { const w = W64.includes(id) ? 64 : 48; return [[`${id}_idle`, w, 4], [`${id}_hit`, w, 6], [`${id}_attack`, w, 6], [`${id}_die`, w, 8]]; });
