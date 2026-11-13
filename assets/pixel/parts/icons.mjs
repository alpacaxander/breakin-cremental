// HUD and screen glyphs for the Peglin direction (docs/content.md): relic icons, map node icons, enemy intent
// icons, the HP heart and the NEXT arrow, and the map's reachable-node ring. Sprite px, drawn on the pixel grid.
// gen.mjs exports nothing, so it hands its helpers in. Merge: `import { emit as icons } from "./parts/icons.mjs";`
// then `icons({ Img, C, text, A, def });` after `def` and `FONT["?"]` exist. Needs from gen.mjs:
//   Img   the pixel buffer class (px, rect, outline, ascii, corners)
//   C     the colour table (base, trim*, pay*, white, pureWhite, danger, chrome*)
//   text  3x5 font writer, for "$" and "?"
//   A     the statics table: name -> Img, written as png/<name>.png
//   def   (group, name, fps, frames) registering a strip anim_<name>.png
// Returns { A, ANIM } of what it added, so a runner without gen.mjs can draw them.

const RED = { tube: "ff0000", ring: "a30000", deep: "3a0000", hi: "ff8a8a" };  // docs/art-style.md Red set
const GOLD = "ebdb57";

export const RELICS = ["wide_paddle", "shield_floor", "opener", "toll", "tenth_bomb", "magnet_paddle", "combo", "twin_crit", "recall", "mini_paddle"];
export const INTENTS = ["red_bricks", "enemy_balls", "debris", "laser_sweep", "shield_row", "mouth", "shield_bricks"];
export const NODES = ["fight", "elite", "treasure", "shop", "event"];

// Glyphs are at most 10x10 and sit centred in the 12x12 (1 px clear of the edge). '#' main colour, 'o' second.
const RELIC = {
	wide_paddle: [".#......#.", "##......##", "###....###", "##......##", ".#......#.", "..........", "##########", "##########"],
	shield_floor: ["....#.....", "...###....", "..#.#.#...", "....#.....", "....#.....", "..........", "##..##..##", "##..##..##"],
	opener: ["....##....", "....##....", "...#..#...", "..........", "....##....", "...####...", "..........", "##########", "#.#.#.#.##", "##########"],
	toll: ["....#.....", "..#####...", ".#..#..#..", ".#..#.....", "..####....", "....#..#..", ".#..#..#..", "..#####...", "....#....."],
	tenth_bomb: [".......o..", "......#...", ".....#....", "...####...", "..######..", "..######..", "..######..", "...####..."],
	magnet_paddle: [".##....##.", ".oo....oo.", ".#......#.", ".#......#.", ".#......#.", "..#....#..", "...####...", "....##...."],
	combo: [".......##.", ".......##.", "....##.##.", "....##.##.", ".##.##.##.", ".##.##.##.", ".##.##.##."],
	twin_crit: [".##....##.", ".##....##.", "#..#..#..#", "..........", ".##....##.", "####..####", "..........", "##########", "#.#.#.#.##", "##########"],
	recall: ["....#.....", "...###....", "..#.#.#...", "....#.....", "....#.....", "....#.....", "...###....", "..#####...", "..#####...", "...###...."],
	mini_paddle: ["..........", ".########.", ".########.", "..........", "..........", "...####...", "...####..."],
};
const INTENT = {
	red_bricks: ["..........", "..........", ".########.", ".#oooooo#.", ".#......#.", ".########."],
	enemy_balls: ["..#....#..", ".###..###.", "..#....#..", "..........", "....#.....", "...###....", "....#....."],
	debris: [".##...##..", ".oo...oo..", "..........", "....##....", "....oo....", "..........", "..........", ".########."],
	laser_sweep: ["....#o....", "....#o....", ".#..#o..#.", "##..#o..##", ".#..#o..#.", "....#o....", "....#o....", "....#o...."],
	shield_row: ["..........", "###.##.###", "ooo.oo.ooo", "..........", "..........", "....#.....", "...###....", "..#.#.#...", "....#....."],
	shield_bricks: ["..######..", "..#oooo#..", "..#oooo#..", "...#oo#...", "....##....", "..........", "##########", "#oooooooo#", "##########"],
	mouth: ["##########", "#..#..#..#", ".o..o..o..", "..........", "..........", ".o..o..o..", "#..#..#..#", "##########"],
};
const NODE = {
	fight: [RED.tube, ["#....#", ".#..#.", "..##..", "..##..", ".#..#.", "#....#"]],
	elite: [RED.tube, [".####.", "######", "#o##o#", "######", ".####.", ".#.#.."]],
	treasure: [GOLD, [".######.", "#......#", "########", "###oo###", "#..##..#", "########"]],
};
const BOSS = ["..##....##..", "..#......#..", "..########..", ".##########.", "##..####..##", "##..####..##", "############", "############", ".##########.", "..#.#..#.#..", "..########.."];

const mask = (rows, c, c2) => (b, x, y) => b.ascii(x, y, rows, { "#": c, "o": c2 || c });
const centred = (b, rows, c, c2) => mask(rows, c, c2)(b, (b.w - rows[0].length) >> 1, (b.h - rows.length) >> 1);
// Pixel circles by row width, so the edge is the usual stair pattern and not a distance-test gear.
const WIDTHS = { 10: [4, 8, 8, 10, 10, 10, 10, 8, 8, 4], 12: [6, 8, 10, 10, 12, 12, 12, 12, 10, 10, 8, 6], 14: [6, 8, 10, 12, 12, 14, 14, 14, 14, 12, 12, 10, 8, 6], 16: [6, 10, 12, 12, 14, 14, 16, 16, 16, 16, 14, 14, 12, 12, 10, 6] };
const fill = (b, n, x0, y0, c) => WIDTHS[n].forEach((w, y) => b.rect(x0 + ((n - w) >> 1), y0 + y, w, 1, c));
// Disc: the round cabinet-trim body a map node sits on.
const disc = (Img, C, n) => {
	const b = new Img(n, n);
	fill(b, n, 0, 0, C.trimHi); fill(b, n - 2, 1, 1, C.trimLo);
	b.hline(n >> 2, 1, n >> 1, C.rivet); // light from the top
	return b;
};
const circle = (b, r, c, dash) => { const n = Math.ceil(r * 8), o = b.w / 2 - .5; for (let i = 0; i < n; i++) { if (dash && ((i >> 1) & 1)) continue; const t = i / n * Math.PI * 2; b.px(Math.round(o + r * Math.cos(t)), Math.round(o + r * Math.sin(t)), c); } };

export function emit({ Img, C, text, A, def }) {
	const out = {}, anim = {};
	const put = (n, img) => { out[n] = img; if (A) A[n] = img; };

	// Relics: warm white on transparent; the violet comes from the HUD slot and card behind it.
	for (const id of RELICS) { const b = new Img(12, 12); centred(b, RELIC[id], C.white, id === "tenth_bomb" ? C.pay : C.pureWhite); put(`relic_${id}`, b); }

	// Intents: red glyph on a dark red-ringed plate. Corners cut, 'o' is the red highlight.
	for (const id of INTENTS) {
		const b = new Img(12, 12); b.rect(0, 0, 12, 12, C.base); b.outline(0, 0, 12, 12, RED.ring); b.corners();
		centred(b, INTENT[id], RED.tube, RED.hi); put(`intent_${id}`, b);
	}

	// Map nodes: trim disc, kind glyph. Reachable / visited / unreachable are alpha in-engine.
	for (const id of NODES) {
		const b = disc(Img, C, 12);
		if (NODE[id]) centred(b, NODE[id][1], NODE[id][0], C.pureWhite);
		else text(b, 5, 4, id === "shop" ? "$" : "?", id === "shop" ? GOLD : C.white);
		put(`map_node_${id}`, b);
	}
	put("map_node_boss", (() => { const b = disc(Img, C, 16); centred(b, BOSS, RED.tube); return b; })());

	// HUD glyphs.
	put("ui_hp", (() => { const b = new Img(8, 8); b.ascii(0, 1, [".##..##.", "########", "########", ".######.", "..####..", "...##..."], { "#": RED.tube }); b.px(1, 2, RED.hi); b.px(2, 1, RED.hi); return b; })());
	put("ui_next", (() => { const b = new Img(4, 5); b.ascii(0, 0, ["##..", "###.", "####", "###.", "##.."], { "#": C.white }); return b; })());

	// Map ring around the reachable node: dashed circle, pulses by colour only (docs/art-style.md).
	const frames = [C.pay, C.payHi, C.pureWhite, C.payHi].map((c) => { const f = new Img(16, 16); circle(f, 7, c, 1); return f; });
	anim.map_ring_pulse = { fps: 8, frames };
	if (def) def("Map", "map_ring_pulse", 8, frames);
	return { A: out, ANIM: anim };
}
