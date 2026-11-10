// Deep Net elites and bosses (docs/content/maps/deep-net.md): hive_mind, fork_bomb, recursion, trojan (64 wide, elites, chrome-rimmed like warden),
// compiler and admin (160 wide, bosses). All 48 tall, feet on the bottom row, anchored bottom centre like parts/enemies.mjs.
// Strips per enemy: <id>_idle x4 @8 (loop), <id>_hit x6 @12, <id>_attack x6 @12 (hazard spawns on frame 3, the release pose), <id>_die x8 @12 (ends blank).
// Form changes get their own strips: fork_bomb_split 64 x8 @12 (the bomb tears down its seam, ends blank) then two fork_bomb_half_* enemies (48 wide);
// trojan_* is the glob disguise, trojan_reveal 64 x8 @12 (the shell splits, ends on the horse) then trojan_true_*; compiler_rewrite 160 x8 @12 (the head
// sweeps the board at each 25% step). Look: kit() from parts/enemies.mjs, one lit red accent; the Green set (docs/art-style.md) marks virus and code.

import { kit } from "./enemies.mjs";

const G = "Elites and bosses: Deep Net";
const GREEN = { tube: "00ff00", ring: "00bf00", deep: "003f00", hi: "a0ff60" };  // docs/art-style.md Green set
const DIRS = [[1, 1], [-1, 1], [1, -1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]];

export function emit({ Img, C, def, frame, blank }) {
	const { E, RED, flash, hot, oval, block, eye, std, fade } = kit(C);
	const burst = (f, x, y, r, c) => { for (const [sx, sy] of DIRS) f.px(x + sx * r, y + sy * r, c); };
	// Elite rim: every clear pixel touching the body turns chrome, so the silhouette reads as warden's kin.
	const edge = (f) => { const o = f.crop(0, 0, f.w, f.h), on = (x, y) => x >= 0 && y >= 0 && x < f.w && y < f.h && f.get(x, y)[3]; for (let y = 0; y < f.h; y++) for (let x = 0; x < f.w; x++) if (!on(x, y) && (on(x - 1, y) || on(x + 1, y) || on(x, y - 1) || on(x, y + 1))) o.px(x, y, E.chrome); return o; };
	// One enemy's four strips from a pose function; a pose with `a` is faded. die lists the 5 frames between flash/hot and the blank.
	const four = (id, w, pose, idle, hit, atk, die) => {
		const B = pose({}), P = (o) => o.a ? fade(pose(o), o.a) : pose(o);
		def(G, `${id}_idle`, 8, idle.map(P));
		def(G, `${id}_hit`, 12, std(B, hit.map(P)));
		def(G, `${id}_attack`, 12, atk.map(P));
		def(G, `${id}_die`, 12, [flash(B), hot(B), ...die.map(P), blank(w, 48)]);
	};

	// -- hive_mind 64x48: a honeycomb mound of ten cells, each with a green virus nucleus that pulses in turn; the crown cell holds the red eye. --
	const HEX = [[32, 8, 0], [26, 19, 1], [38, 19, 1], [20, 30, 2], [32, 30, 2], [44, 30, 2], [14, 41, 3], [26, 41, 3], [38, 41, 3], [50, 41, 3]];  // cx, cy, row
	const hive = ({ pulse = 0, dx = 0, sag = 0, nuc = null, eyeC = RED.tube, spores = false }) => {
		const f = new Img(64, 48);
		HEX.forEach(([hx, hy, row], i) => {
			const cx = hx + dx, cy = Math.min(41, hy + Math.round(sag * (3 - row) / 3));
			for (let dy = -5; dy <= 5; dy++) { const ins = Math.max(0, Math.abs(dy) - 2), x0 = cx - 6 + ins, x1 = cx + 6 - ins; for (let x = x0; x <= x1; x++) f.px(x, cy + dy, x === x0 || x === x1 || Math.abs(dy) === 5 ? E.rim : E.fill); }
			f.hline(cx - 3, cy - 4, 7, E.hi);
			if (i === 0) { eye(f, cx - 2, cy - 1, 5, 3, eyeC); return; }
			const c = nuc ?? (i % 3 === pulse % 3 ? GREEN.tube : GREEN.deep);
			f.rect(cx - 1, cy - 1, 3, 3, c); if (c === GREEN.tube) f.px(cx, cy, GREEN.hi);
		});
		if (spores) for (const [r, c] of [[5, GREEN.tube], [8, RED.tube], [11, GREEN.hi]]) burst(f, 32 + dx, 6, r, c);
		return edge(f);
	};
	four("hive_mind", 64, hive,
		[{ pulse: 0 }, { pulse: 1, sag: -1 }, { pulse: 2 }, { pulse: 0, sag: 1 }],
		[{ dx: 2, sag: 2, nuc: GREEN.deep, eyeC: RED.dim }, { dx: 1, sag: 1 }],
		[{ sag: 1, nuc: GREEN.ring }, { sag: -1, nuc: GREEN.tube }, { sag: -2, nuc: GREEN.hi, eyeC: RED.hi }, { sag: -2, nuc: GREEN.hi, eyeC: C.pureWhite, spores: true }, { sag: 0, pulse: 1 }, {}],
		[{ sag: 4, nuc: GREEN.ring }, { sag: 10, nuc: GREEN.deep, eyeC: RED.dim }, { sag: 20, nuc: GREEN.deep, eyeC: RED.deep }, { sag: 30, nuc: GREEN.deep, eyeC: null, a: 170 }, { sag: 33, nuc: GREEN.deep, eyeC: null, a: 80 }]);

	// -- fork_bomb 64x48 (and fork_bomb_half 48x48): a round bomb with a burning red fuse and a riveted seam down the middle, one eye each side. --
	const bomb = ({ w = 64, r = 18, dx = 0, sq = 0, fuse = 0, spark = 0, crack = false, eyeC = RED.tube, boom = false }) => {
		const f = new Img(w, 48), cx = (w >> 1) + dx, rx = r + sq, ry = r - sq, cy = 46 - ry, top = cy - ry;
		const len = Math.max(0, 7 - fuse * 2), tx = cx + 2 + len, ty = top - 3 - len;
		for (const o of [0, 1]) f.line(cx + o, top - 3, tx + o, ty, E.chrome);                               // fuse cord
		block(f, cx - 4, top - 4, 9, 5);                                                                      // cap
		oval(f, cx, cy, rx, ry);
		for (let y = top + 3; y < cy + ry - 2; y++) f.px(cx, y, crack ? (y & 1 ? RED.tube : RED.hi) : E.rim);  // seam
		if (!crack) for (let y = top + 6; y < cy + ry - 4; y += 5) { f.px(cx - 1, y, E.chrome); f.px(cx + 1, y, E.chrome); }
		const s = Math.max(2, r >> 2); eye(f, cx - 3 - s * 2, cy - 2, s + 2, 2, eyeC); eye(f, cx + 3 + s - 2, cy - 2, s + 2, 2, eyeC);
		f.rect(tx - 1, ty - 1, 3, 3, RED.tube); f.px(tx, ty, spark & 1 ? C.pureWhite : RED.hi);             // the spark, the lit accent
		if (spark) burst(f, tx, ty, 2 + (spark & 1), spark & 1 ? RED.hi : RED.tube);
		if (boom) for (const [k, c] of [[4, C.pureWhite], [7, RED.tube], [10, RED.hi]]) burst(f, tx, ty, k, c);
		return edge(f);
	};
	const bombSet = (id, w, r) => four(id, w, (o) => bomb({ w, r, ...o }),
		[{ spark: 0 }, { spark: 1 }, { spark: 2 }, { spark: 1, sq: 1 }],
		[{ dx: 2, sq: -2, eyeC: RED.dim }, { dx: 1, sq: -1 }],
		[{ fuse: 1, spark: 1 }, { fuse: 2, spark: 3, sq: 1 }, { fuse: 3, spark: 3, sq: 2 }, { fuse: 3, sq: -2, boom: true }, { fuse: 1, sq: -1 }, {}],
		[{ sq: 2, crack: true }, { sq: 3, crack: true, eyeC: RED.dim }, { sq: 5, crack: true, eyeC: null }, { sq: 7, crack: true, eyeC: null, a: 160 }, { sq: 9, crack: true, eyeC: null, a: 70 }]);
	bombSet("fork_bomb", 64, 18);
	bombSet("fork_bomb_half", 48, 13);
	const torn = bomb({ crack: true }), apart = (k, a) => frame(64, 48, [torn.crop(0, 0, 32, 48), -k, 0, a], [torn.crop(32, 0, 32, 48), 32 + k, 0, a]);
	def(G, "fork_bomb_split", 12, [bomb({ crack: true, spark: 1 }), bomb({ crack: true, sq: 2, spark: 3 }), apart(2), apart(5), apart(9, 210), apart(14, 150), apart(20, 80), blank(64, 48)]);

	// -- recursion 64x48: a diamond on its point holding diamonds inside diamonds; the rings zoom inward forever round a red core. --
	const rec = ({ ph = 0, s = 22, dx = 0, core = RED.tube, out = false, flare = false }) => {
		const f = new Img(64, 48), cx = 32 + dx, cy = 24, gap = Math.max(2, s >> 2), t = Math.round(((out ? 4 - ph : ph) * gap / 4)) % gap;
		for (let y = cy - s; y <= cy + s; y++) for (let x = cx - s; x <= cx + s; x++) {
			const d = Math.abs(x - cx) + Math.abs(y - cy);
			if (d > s) continue;
			f.px(x, y, d === s ? E.rim : d <= 2 ? core : (s - 2 - d - t) % gap === 0 && d > 3 ? E.chrome : E.fill);
		}
		if (core === RED.tube) f.px(cx, cy - 1, RED.hi);
		f.line(cx - s + 2, cy - 1, cx - 1, cy - s + 2, E.hi);  // lit upper-left facet
		if (flare) for (const [x, y] of [[cx, cy - s - 1], [cx - s - 1, cy], [cx + s + 1, cy]]) burst(f, x, y, 2, RED.tube);
		return edge(f);
	};
	four("recursion", 64, rec,
		[0, 1, 2, 3].map((ph) => ({ ph })),
		[{ dx: 2, ph: 2, core: RED.dim }, { dx: 1, ph: 1 }],
		[{ out: true, ph: 1 }, { out: true, ph: 2, core: RED.hi }, { out: true, ph: 3, core: RED.hi }, { out: true, ph: 0, core: C.pureWhite, flare: true }, { ph: 1 }, {}],
		[{ s: 18, core: RED.hi }, { s: 13, ph: 2 }, { s: 9, core: RED.dim }, { s: 5, core: RED.dim, a: 170 }, { s: 2, core: RED.deep, a: 90 }]);

	// -- trojan 64x48, disguised: a Map 1 glob a size up, no chrome rim. The tell: a green seam glitches down its middle on one idle frame. --
	const mask = ({ rx = 20, ry = 13, drip = 0, dx = 0, eyeC = RED.tube, seam = 0, spit = false }) => {
		const f = new Img(64, 48), cx = 32 + dx, cy = 47 - ry;
		oval(f, cx, cy, rx, ry);
		for (const [x, h] of [[cx - 11, 3 + drip], [cx + 7, 2 + (1 - drip)]]) { f.rect(x, cy - ry - h + 1, 3, h + 2, E.fill); f.rect(x, cy - ry - h, 3, 1, E.rim); f.rect(x - 1, cy - ry - h + 1, 1, h, E.rim); f.rect(x + 3, cy - ry - h + 1, 1, h, E.rim); }
		eye(f, cx + 2, cy - 3, 8, 4, eyeC);
		for (let y = cy - ry + 1; y < 47 && seam; y += 3 - Math.min(seam, 2)) f.px(cx - 2 + ((y >> 1) & 1), y, seam > 2 ? GREEN.hi : GREEN.tube);
		if (spit) { f.rect(cx - 3, cy - ry - 10, 6, 4, RED.tube); f.outline(cx - 3, cy - ry - 10, 6, 4, RED.ring); }
		return f;
	};
	four("trojan", 64, mask,
		[{}, { rx: 19, ry: 14, drip: 1 }, { seam: 1 }, { rx: 21, ry: 12, drip: 1 }],
		[{ rx: 23, ry: 10, eyeC: RED.dim }, { rx: 22, ry: 11 }],
		[{ rx: 22, ry: 11 }, { rx: 23, ry: 10 }, { rx: 18, ry: 16 }, { rx: 18, ry: 16, spit: true }, { rx: 19, ry: 14 }, {}],
		[{ rx: 22, ry: 10 }, { rx: 24, ry: 7, eyeC: RED.dim }, { rx: 26, ry: 4, eyeC: null }, { rx: 27, ry: 2, eyeC: null, a: 170 }, { rx: 27, ry: 2, eyeC: null, a: 90 }]);

	// -- trojan_true 64x48, revealed: a wooden horse on a wheeled platform, chrome-rimmed, red eye, a green hatch of code open in its flank. --
	const horse = ({ dx = 0, dy = 0, head = 0, code = 0, eyeC = RED.tube, hatch = GREEN.deep, spew = false }) => {
		const f = new Img(64, 48), X = (x) => x + dx, Y = (y) => y + dy;
		block(f, X(6), 37, 52, 5);                                                                        // platform
		for (const x of [14, 32, 50]) { oval(f, X(x), 44, 3, 3, false); f.px(X(x), 43, E.chrome); }         // wheels
		for (const x of [14, 22, 38, 44]) block(f, X(x), Y(30), 5, 8 - dy);                                // legs
		f.line(X(10), Y(21), X(5), Y(31), E.rim); f.line(X(11), Y(21), X(6), Y(31), E.rim);                // tail
		block(f, X(10), Y(18), 38, 14, true);                                                              // barrel, planked
		block(f, X(38), Y(7 + head), 10, 16);                                                              // neck
		block(f, X(42), Y(4 + head), 19, 9);                                                               // head, snout right
		f.ascii(X(43), Y(head), ["#..", "##.", "###", "###"], { "#": E.rim });                             // ear
		for (let y = 8 + head; y < 22; y += 2) f.px(X(37), Y(y), E.chrome);                                // mane
		eye(f, X(52), Y(7 + head), 3, 2, eyeC);
		f.rect(X(19), Y(21), 13, 9, hatch); f.outline(X(18), Y(20), 15, 11, GREEN.ring);                   // the hatch, open
		if (hatch === GREEN.deep) for (let r = 0; r < 4; r++) for (let k = 0; k < 11; k += 2) if ((k * 3 + r * 5 + code) % 7 < 3) f.px(X(20 + k), Y(22 + r * 2), GREEN.tube);
		if (spew) for (const [x, y, c] of [[14, 17, GREEN.tube], [10, 13, GREEN.hi], [20, 14, RED.tube], [6, 9, GREEN.tube], [16, 8, RED.hi], [24, 11, GREEN.hi], [3, 15, RED.tube]]) f.rect(X(x), Y(y), 2, 2, c);
		return edge(f);
	};
	four("trojan_true", 64, horse,
		[{}, { code: 1 }, { code: 2, head: 1 }, { code: 3, head: 1 }],
		[{ dx: 2, head: -1, eyeC: RED.dim }, { dx: 1 }],
		[{ head: -1 }, { head: -2, code: 2, hatch: GREEN.deep }, { head: -3, hatch: GREEN.ring, eyeC: RED.hi }, { head: -3, hatch: GREEN.hi, eyeC: C.pureWhite, spew: true }, { head: -1, code: 1 }, {}],
		[{ dy: 1, head: 2, eyeC: RED.dim }, { dy: 2, head: 4, hatch: GREEN.ring }, { dy: 4, head: 7, eyeC: null, hatch: C.base }, { dy: 6, head: 9, eyeC: null, hatch: C.base, a: 160 }, { dy: 7, head: 10, eyeC: null, hatch: C.base, a: 70 }]);
	// trojan_reveal: the glob's green seam spreads, the shell halves slide off and fade, the horse is left standing (then trojan_true_idle takes over).
	const shell = mask({ seam: 3 }), H0 = horse({ hatch: GREEN.hi }), peel = (k, a) => frame(64, 48, [H0, 0, 0, Math.min(255, 300 - a)], [shell.crop(0, 0, 32, 48), -k, k >> 1, a], [shell.crop(32, 0, 32, 48), 32 + k, k >> 1, a]);
	def(G, "trojan_reveal", 12, [mask({ seam: 1 }), mask({ seam: 2, rx: 21, ry: 12 }), shell, peel(3, 255), peel(7, 200), peel(12, 130), peel(18, 60), horse({})]);

	// -- compiler 160x48, boss: a gantry printer. Two planked pillars carry a beam; a carriage with a red lens rides it over an 8x3 grid of equal cells
	// that turn green as it compiles. --
	const comp = ({ hx = 73, drop = 0, on = [], lift = 0, lens = RED.tube, flare = false }) => {
		const f = new Img(160, 48), Y = (y) => y + lift;
		block(f, 4, Y(4), 14, 44, true); block(f, 142, Y(4), 14, 44, true);                                 // pillars
		block(f, 16, Y(4), 128, 6); for (let x = 20; x < 140; x += 6) f.px(x, Y(7), E.rim);                // beam
		block(f, 24, Y(18), 112, 30);                                                                      // the body
		for (let i = 0; i < 24; i++) { const x = 28 + (i & 7) * 13, y = Y(22 + (i >> 3) * 8), g = on.includes(i); f.rect(x, y, 12, 6, g ? GREEN.deep : E.hi); f.outline(x, y, 12, 6, g ? GREEN.ring : E.rim); if (g) f.hline(x + 2, y + 1, 8, GREEN.tube); }
		block(f, hx, Y(9), 14, 9 + drop, false, E.chrome);                                                 // carriage
		f.ascii(hx + 3, Y(18 + drop), ["########", ".######.", "..####.."], { "#": E.chrome });            // nozzle
		eye(f, hx + 4, Y(12 + drop), 6, 3, lens); f.rect(hx + 6, Y(20 + drop), 2, 1, lens);
		if (flare) for (const [k, c] of [[3, C.pureWhite], [6, RED.tube], [9, RED.hi]]) burst(f, hx + 7, Y(22 + drop), k, c);
		return f;
	};
	const ALL = [...Array(24).keys()];
	four("compiler", 160, comp,
		[[73, [3]], [75, [12]], [77, [21]], [75, [14]]].map(([hx, on]) => ({ hx, on })),
		[{ lift: 2, hx: 77, lens: RED.dim }, { lift: 1, hx: 75 }],
		[{ drop: 1 }, { drop: -2, lens: RED.hi }, { drop: -3, lens: RED.hi }, { drop: 2, lens: C.pureWhite, flare: true }, { drop: 1 }, {}],
		[{ lift: 3, lens: RED.dim, on: ALL }, { lift: 8, lens: RED.dim, on: [1, 6, 9, 20] }, { lift: 16, lens: RED.deep, a: 200 }, { lift: 26, lens: RED.deep, a: 130 }, { lift: 36, lens: RED.deep, a: 60 }]);
	// compiler_rewrite: the carriage sweeps the beam left to right and every column behind it compiles green.
	def(G, "compiler_rewrite", 12, [...Array(8).keys()].map((i) => comp({ hx: 24 + i * 14, drop: i & 1, on: ALL.filter((c) => (c & 7) < i) })).map((f, i) => i === 7 ? comp({ hx: 122, on: ALL }) : f));

	// -- admin 160x48, boss: not a drone. A hooded figure at a long desk between two green terminals, red eyes in the hood, typing. --
	const LINES = [22, 14, 28, 9, 18, 25, 12, 30, 16];
	const admin = ({ type = 0, scroll = 0, head = 0, hx = 0, arm = 0, scr = GREEN.deep, eyeC = RED.tube, slump = 0, sparks = false }) => {
		const f = new Img(160, 48);
		oval(f, 80 + hx, 37 + slump, 22, 12);                                                              // shoulders
		if (arm) { block(f, 96 + hx, 30 - arm, 6, arm + 6); block(f, 94 + hx, 26 - arm, 10, 6, false, E.chrome); }  // the raised arm, fist
		oval(f, 80 + hx, 16 + head + slump, 10, 11);                                                       // hood
		oval(f, 80 + hx, 19 + head + slump, 6, 6, false); f.rect(75 + hx, 17 + head + slump, 11, 7, C.base); // the dark face
		eye(f, 76 + hx, 19 + head + slump, 3, 2, eyeC); eye(f, 82 + hx, 19 + head + slump, 3, 2, eyeC);
		for (const mx of [12, 110]) {                                                                      // terminals
			block(f, mx + 16, 28, 6, 7); block(f, mx, 4, 38, 25, false, E.chrome);
			f.rect(mx + 3, 7, 32, 19, scr);
			if (scr === GREEN.deep) LINES.forEach((_, i) => f.hline(mx + 4, 8 + i * 2, LINES[(i + scroll + (mx & 3)) % LINES.length], i === 8 ? GREEN.tube : GREEN.ring));
			if (scr === GREEN.deep && type & 1) f.rect(mx + 30, 24, 3, 1, GREEN.hi);                       // cursor
		}
		block(f, 4, 34, 152, 5); block(f, 10, 39, 140, 9, true);                                           // desk
		block(f, 64, 31, 32, 4, false, E.chrome); for (let x = 66; x < 94; x += 3) f.px(x, 32, E.chromeHi); // keyboard
		const up = arm ? [0, 9] : [type & 1, 1 - (type & 1)]; [68, 87].forEach((x, i) => up[i] < 9 && block(f, x + hx, 29 - up[i] + slump, 5, 4)); // hands
		if (sparks) for (const [x, y, c] of [[31, 1, GREEN.hi], [129, 1, GREEN.hi], [99, 14, RED.tube], [80, 1, RED.hi], [60, 6, GREEN.tube], [104, 5, RED.tube], [50, 2, RED.hi]]) f.rect(x, y, 2, 2, c);
		return f;
	};
	four("admin", 160, admin,
		[0, 1, 2, 3].map((k) => ({ type: k, scroll: k })),
		[{ hx: 2, head: -1, eyeC: RED.dim, scr: GREEN.ring }, { hx: 1 }],
		[{ arm: 4, scroll: 1 }, { arm: 10, scroll: 2, eyeC: RED.hi }, { arm: 14, scroll: 3, eyeC: RED.hi, scr: GREEN.ring }, { scr: GREEN.hi, eyeC: C.pureWhite, sparks: true, head: 1 }, { scroll: 5 }, {}],
		[{ scr: GREEN.ring, head: 2 }, { scr: C.base, head: 4, slump: 2, eyeC: RED.dim }, { scr: C.base, head: 7, slump: 4, eyeC: null, a: 200 }, { scr: C.base, head: 9, slump: 5, eyeC: null, a: 130 }, { scr: C.base, head: 10, slump: 6, eyeC: null, a: 60 }]);
}

// Strip contract (docs/animations.md): name, frame width, frames. Height is always 48.
const IDS = [["hive_mind", 64], ["fork_bomb", 64], ["fork_bomb_half", 48], ["recursion", 64], ["trojan", 64], ["trojan_true", 64], ["compiler", 160], ["admin", 160]];
export const STRIPS = [...IDS.flatMap(([id, w]) => [[`${id}_idle`, w, 4], [`${id}_hit`, w, 6], [`${id}_attack`, w, 6], [`${id}_die`, w, 8]]), ["fork_bomb_split", 64, 8], ["trojan_reveal", 64, 8], ["compiler_rewrite", 160, 8]];
