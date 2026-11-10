// The map proposals' ten new hazards (docs/content/maps/*.md, New hazards): an intent icon each, the in-fight tells they
// cannot borrow, and the virus brick kind (green set, docs/art-style.md; SETS has no green yet, so it is defined here).
// emit(h) takes gen.mjs's helpers as one object (h = MAPH there). Sprite px.
//   Statics: intent_<id> 12x12 for all ten (icons.mjs INTENTS grammar), paddle_jam 30x8 (the half-width paddle),
//            brick_virus and brick_virus_player 30x12.
//   Strips:  see STRIPS. Reused, no new art: coin_junk (ball_junk_rank), blackout (hiding the tag and glow is the tell),
//            lockdown (the dim face plus _damage's refusal; brick_plain_dim, or dim(<hue>) faces), ghost's return (<hue>_spawn).

export const GREEN = { tube: "00ff00", ring: "00bf00", deep: "003f00", hi: "a0ff60", dimTube: "007f00", dimRing: "003f00" };
const RED = { tube: "ff0000", ring: "a30000", deep: "3a0000", hi: "ff8a8a" };
const GHOST_HUES = ["mag", "ora", "blue", "mint", "red", "green"];  // every non-solid kind's hue (Tuning.hue)

export const STRIPS = [
	["jam_clamp", 60, 6], ["pull_drift", 12, 4], ["mirror_paddle", 60, 4], ["scramble_swap", 30, 6],
	["wall_col_raise", 30, 6], ["wall_col_crumble", 30, 6], ...GHOST_HUES.map((s) => [`${s}_ghost`, 30, 4]),
	["virus_pulse", 30, 4], ["virus_player_pulse", 30, 4], ["virus_infect", 30, 8], ["virus_player_infect", 30, 8], ["virus_clear", 30, 8],
	["green_hit", 30, 6], ["green_break", 44, 8], ["green_spawn", 30, 6],
];
// frame height per strip, for whoever slices: 60x8 paddles, 12x16 pull, 44x20 break, 30x12 the rest

// Glyphs at most 10x10, centred on the 12x12 plate. '#' red tube, 'o' red highlight.
const INTENT = {
	jam: ["#........#", "##......##", "###....###", "##......##", "#........#", "..........", "...oooo...", "...####..."],
	pull: ["....#.....", "...###....", "..#.#.#...", "....#.....", "....#.....", "..........", "...oo.....", "..oooo....", "..oooo....", "...oo....."],
	coin_junk: ["...####...", "..#oooo#..", "..#o##o#..", "..#oooo#..", "...####...", "....##....", "..######..", "...####...", "....##...."],
	wall_col: ["....##....", "....oo....", "....##....", "....oo....", "....##....", "#...oo....", ".#..##....", "#...oo....", "....##....", "....oo...."],
	blackout: ["#.........", ".#.####...", "..#....#..", ".#.#oo..#.", "#..o#o...#", ".#..o.#.#.", "..####.#..", ".......#..", "........#."],
	lockdown: ["...####...", "..#....#..", "..#....#..", ".########.", ".###oo###.", ".###oo###.", ".########."],
	virus: ["....#....", ".#.###.#.", "..#####..", ".##ooo##.", "####o####", ".##ooo##.", "..#####..", ".#.###.#.", "....#...."],
	scramble: ["......#...", "#########.", "......#...", "..........", "...o......", ".ooooooooo", "...o......"],
	mirror: ["....oo....", "#...oo...#", ".#..oo..#.", "..#.oo.#..", ".#..oo..#.", "#...oo...#", "....oo....", "..........", ".########."],
	ghost: ["..######..", ".#......#.", "#..o..o..#", "#........#", "#........#", "#........#", "#.##..##.#", "##..##..##"],
};
// Virus particle on the brick face: hostile is green with a red core, the player's is pay yellow with a white core.
const VIRUS = ["#.#.#", ".###.", "##o##", ".###.", "#.#.#"];
// 4x4 Bayer order, for dissolves that read the same from every side (a neighbour can be infected from any direction).
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
const on = (x, y, t) => BAYER[(y & 3) * 4 + (x & 3)] < t;

export function emit(h) {
	const { Img, C, SETS, A, def, frame, center, hold, blank, lit, dim, hot, FLASH, sparks, withIcon, glyph } = h;
	const G = SETS.green || GREEN, hues = { ...SETS, green: G };
	const GROUP = "Hazards: maps", VG = "Bricks: virus";

	for (const [id, rows] of Object.entries(INTENT)) {
		const b = new Img(12, 12); b.rect(0, 0, 12, 12, C.base); b.outline(0, 0, 12, 12, RED.ring); b.corners();
		b.ascii((12 - rows[0].length) >> 1, (12 - rows.length) >> 1, rows, { "#": RED.tube, "o": RED.hi });
		A[`intent_${id}`] = b;
	}

	// -- jam: two red clamps squeeze the paddle to half width. Ends and corners kept: the left half and right half meet. --
	const squeeze = (w, clamp) => {
		const b = frame(w, 8, [A.paddle.crop(0, 0, w >> 1, 8), 0, 0], [A.paddle.crop(60 - (w - (w >> 1)), 0, w - (w >> 1), 8), w >> 1, 0]);
		if (clamp) for (const x of [0, w - 3]) { b.rect(x, 0, 3, 8, clamp); b.rect(x + 1, 1, 1, 6, RED.ring); }
		b.corners(); return b;
	};
	A.paddle_jam = squeeze(30, RED.tube);
	def(GROUP, "jam_clamp", 12, [[60, null], [60, C.pureWhite], [48, RED.hi], [38, RED.tube], [30, RED.tube], [30, RED.tube]].map(([w, c]) => frame(60, 8, center(squeeze(w, c), 60, 8))));

	// -- pull: red chevrons rise off a ball, drawn over it (ball centre at frame (6,12)); one chevron per 4 rows, loops --
	def(GROUP, "pull_drift", 8, [0, 1, 2, 3].map((f) => {
		const b = new Img(12, 16);
		for (let y0 = 8 - f; y0 > -3; y0 -= 4) b.ascii(3, y0, ["..#..", ".#.#.", "#...#"], { "#": y0 > 4 ? RED.tube : y0 > 0 ? RED.ring : RED.deep });
		return b;
	}));

	// -- mirror: the paddle's stripe turns red and its arrows point the wrong way (inward, swapped), blinking --
	def(GROUP, "mirror_paddle", 8, [RED.tube, RED.hi, RED.tube, RED.ring].map((c) => {
		const b = A.paddle.crop(0, 0, 60, 8); b.hline(6, 4, 48, RED.ring);
		b.ascii(11, 2, ["##..", ".##.", "..##", ".##.", "##.."], { "#": c }); b.ascii(45, 2, ["..##", ".##.", "##..", ".##.", "..##"], { "#": c });
		return b;
	}));

	// -- scramble: overlay on both slots while the tween swaps them: flash, scanlines, a red/sky split outline closing in --
	const split = (d, a) => { const b = new Img(30, 12); b.outline(Math.max(0, -d), 0, 30 - Math.abs(d), 12, RED.tube); b.outline(Math.max(0, d), 0, 30 - Math.abs(d), 12, C.sky); return b.fade(a); };
	const scan = (() => { const b = new Img(30, 12); for (let y = 0; y < 12; y += 2) b.hline(0, y, 30, C.pureWhite, 160); return b; })();
	def(GROUP, "scramble_swap", 12, [FLASH, scan, split(3, 255), split(2, 220), split(1, 150), blank(30, 12)]);

	// -- wall_col: one solid per segment. Raise drops it in from the top edge; crumble cracks it and lets the halves fall --
	const S = A.brick_solid, SF = (() => { const b = S.crop(0, 0, 30, 12); b.rect(1, 0, 28, 2, C.pureWhite); return b; })();
	def(GROUP, "wall_col_raise", 12, [3, 6, 9, 12].map((k) => frame(30, 12, [S, 0, k - 12])).concat([SF, S]));
	const cracked = (() => { const b = S.crop(0, 0, 30, 12); for (const [x, y] of [[14, 0], [15, 1], [15, 2], [14, 3], [15, 4], [16, 5], [15, 6], [15, 7], [14, 8], [15, 9], [15, 10], [14, 11]]) b.px(x, y, C.base); return b; })();
	const halves = (dy, a) => frame(30, 12, [cracked.crop(0, 0, 15, 12), -dy >> 1, dy, a], [cracked.crop(15, 0, 15, 12), 15 + (dy >> 1), dy, a]);
	def(GROUP, "wall_col_crumble", 12, [SF, cracked, halves(2, 255), halves(5, 180), halves(8, 90), blank(30, 12)]);

	// -- ghost: the dashed ghost state per hue (docs/art-style.md: dashed 2 on 2 off in set tube, fill at alpha 50), dashes march --
	for (const id of GHOST_HUES) def(GROUP, `${id}_ghost`, 8, [0, 1, 2, 3].map((o) => {
		const c = hues[id].tube, b = new Img(30, 12); b.rect(1, 1, 28, 10, c, 50);
		for (let x = 0; x < 30; x++) if ((x + o) % 4 < 2) { b.px(x, 0, c); b.px(29 - x, 11, c); }
		for (let y = 0; y < 12; y++) if ((y + o + 2) % 4 < 2) { b.px(0, 11 - y, c); b.px(29, y, c); }
		return b;
	}));

	// -- virus brick: hostile and player faces, idle pulses, infect (dither from plain), cluster clear (dither out of a flash) --
	const GL = lit(G), PL = h.lamp(30, 12, { ...G, hi: C.pay });  // the player's keeps the green glass, lit row in pay
	const hostile = glyph(VIRUS, RED.tube), friendly = glyph(VIRUS, C.pureWhite);
	A.brick_virus = withIcon(GL, hostile, G.hi);
	A.brick_virus_player = withIcon(PL, friendly, C.pay);
	def(VG, "virus_pulse", 8, [G.hi, C.white, C.pureWhite, C.white].map((c) => withIcon(GL, hostile, c)));
	def(VG, "virus_player_pulse", 8, [C.pay, C.payHi, C.pureWhite, C.payHi].map((c) => withIcon(PL, friendly, c)));
	const dither = (from, to, t) => { const b = from.crop(0, 0, 30, 12); for (let y = 0; y < 12; y++) for (let x = 0; x < 30; x++) if (on(x, y, t)) { b.clear(x, y); const p = to.get(x, y); if (p[3]) b.px(x, y, p); } return b; };
	const infect = (face, icon) => [A.brick_plain_lit, ...[3, 6, 9, 12, 15].map((t) => dither(A.brick_plain_lit, face, t)), withIcon(hot(G), icon, C.pureWhite), face];
	def(VG, "virus_infect", 12, infect(A.brick_virus, hostile));
	def(VG, "virus_player_infect", 12, infect(A.brick_virus_player, friendly));
	const out = (t) => { const b = new Img(30, 12); for (let y = 0; y < 12; y++) for (let x = 0; x < 30; x++) if (!on(x, y, t) && GL.get(x, y)[3]) b.px(x, y, (x + y) & 1 ? G.hi : G.tube); return b; };
	def(VG, "virus_clear", 12, [A.brick_virus, withIcon(hot(G), hostile, C.pureWhite), FLASH, out(4), out(8), out(12), out(15), blank(30, 12)]);

	// green_hit / _break / _spawn: the per-hue shapes. ponytail: a copy of bricks.mjs hueStrips (not exported); export it there if a third hue needs it.
	const H = hot(G);
	def(VG, "green_hit", 12, [FLASH, H, ...hold(GL, 4)]);
	def(VG, "green_break", 12, (() => {
		const W = 44, Hh = 20, Lh = GL.crop(0, 0, 15, 12), Rh = GL.crop(15, 0, 15, 12), chip = new Img(4, 3); chip.rect(0, 0, 4, 3, G.tube); chip.rect(1, 1, 2, 1, G.deep);
		const f1 = frame(W, Hh, center(H, W, Hh)); sparks(f1, 8, C.pay);
		const f2 = frame(W, Hh, [Lh, 5, 3], [Rh, 24, 3], [chip, 20, 1], [chip, 19, 15]); sparks(f2, 7, C.payHi);
		const f3 = frame(W, Hh, [Lh, 2, 1, 150], [Rh, 27, 5, 150], [chip, 10, 17, 200], [chip, 32, 0, 200], [chip, 21, 16, 200]); sparks(f3, 9, C.payDim);
		return [frame(W, Hh, center(FLASH, W, Hh)), f1, f2, f3, frame(W, Hh, [chip, 6, 19, 90], [chip, 36, 0, 90], [chip, 22, 18, 90]), ...hold(blank(W, Hh), 3)];
	})());
	def(VG, "green_spawn", 12, (() => { const o = new Img(30, 12); o.outline(0, 0, 30, 12, G.dimTube); o.corners(); const o2 = o.crop(0, 0, 30, 12); o2.outline(1, 1, 28, 10, G.dimRing); return [o, o2, dim(G), FLASH, H, GL]; })());
}
