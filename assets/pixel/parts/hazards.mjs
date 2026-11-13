// Hazard art for the Peglin direction (docs/encounter-mechanics.md, Hazards table): every hazard's telegraph and strike,
// the intent icons, and the paddle's red hurt flash. Red set per docs/art-style.md ("proposed; not in SETS yet").
// gen.mjs exports nothing, so this takes its helpers as one object:
//   emit({ Img, C, A, def, frame, lamp, hot, ellipse, ring })
//     Img      pixel buffer class            C      colour table (base, danger, pureWhite, ...)
//     A        statics map, written into     def    (group, name, fps, frames) registers a strip
//     frame    (w, h, ...[img, x, y, a])     lamp   (w, h, set, lit) the lamp brick
//     hot      (set, w, h) hot lamp state    ellipse (w, h, edge, body) ball shape
//     ring     (img, cx, cy, r, c, thick, dash) circle outline
// Call it after the bricks part so the paint strip can end on A.brick_red; A.brick_plain_lit and A.paddle must exist.
// Returns the static names it added, for the demo page's GROUPS.

export const RED = { tube: "ff0000", ring: "a30000", deep: "3a0000", hi: "ff8a8a", dimTube: "7f0000", dimRing: "3a0000" };

export function emit(h) {
	const { Img, C, A, def, frame, lamp, hot, ellipse, ring } = h;
	const RL = A.brick_red || lamp(30, 12, RED);  // ponytail: falls back to a bare red lamp when the bricks part has not run

	// -- red_bricks: a plain brick is painted red, left to right, then settles as a red brick --
	const wipe = (k) => { const f = frame(30, 12, [A.brick_plain_lit, 0, 0], [RL.crop(0, 0, k, 12), 0, 0]); f.rect(k, 0, 1, 12, RED.hi); f.corners(); return f; };
	def("Hazards", "red_bricks_paint", 12, [A.brick_plain_lit, wipe(10), wipe(20), hot(RED), RL, RL]);

	// -- enemy_balls: a ring tightens at the spawn point, then a dark-cored red ball pulses in flight --
	const eball = ([edge, gleam]) => { const b = ellipse(8, 8, edge, RED.deep); b.rect(2, 2, 2, 1, gleam); b.px(2, 3, gleam); return b; };
	const warn = (c, dash, core) => { const b = new Img(8, 8); ring(b, 3.5, 3.5, 3.5, c, 1, dash); if (core) b.rect(3, 3, 2, 2, core); return b; };
	def("Hazards", "enemy_balls_warn", 8, [warn(RED.dimTube, 1), warn(RED.ring, 0), warn(RED.tube, 0, RED.ring), warn(RED.hi, 0, RED.tube)]);
	def("Hazards", "enemy_balls_fly", 8, [[RED.tube, RED.hi], [RED.hi, C.pureWhite], [RED.tube, RED.hi], [RED.ring, RED.tube]].map(eball));

	// -- debris: one jagged chunk tumbling through four quarter turns, re-lit from the top each frame --
	const chunk = new Img(8, 8);
	chunk.ascii(0, 0, ["..####..", ".#####..", "#######.", "########", ".#######", ".######.", "..####..", "...##..."], { "#": RED.ring });
	const turn = (b) => { const o = new Img(8, 8); for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) o.px(x, y, b.get(y, 7 - x)); return o; };  // exact quarter turn; Img.rotated rounds 8x8 to 9x9
	const relight = (b) => { for (let x = 0; x < 8; x++) { const ys = []; for (let y = 0; y < 8; y++) if (b.get(x, y)[3]) ys.push(y); if (ys.length) { b.px(x, ys[0], RED.tube); b.px(x, ys[ys.length - 1], RED.deep); } } b.px(2, 2, RED.hi); return b; };
	const turns = [chunk]; for (let i = 1; i < 4; i++) turns.push(turn(turns[i - 1]));
	def("Hazards", "debris_fall", 8, turns.map((t) => relight(t.crop(0, 0, 8, 8))));

	// -- laser_sweep: a 30-wide lane, tiled down the board. Vertical bands only, so every frame tiles top to bottom --
	const lane = (edge, dot, f) => { const b = new Img(30, 6); b.rect(1, 0, 28, 6, RED.tube, 40); b.rect(0, 0, 1, 6, edge); b.rect(29, 0, 1, 6, edge); for (let y = 0; y < 6; y++) if ((y + f) & 1) b.rect(14, y, 2, 1, dot); return b; };
	def("Hazards", "laser_sweep_warn", 8, [[RED.ring, RED.dimTube], [RED.tube, RED.ring], [RED.hi, RED.tube], [RED.tube, RED.ring]].map(([e, d], f) => lane(e, d, f)));
	const bands = (list) => { const b = new Img(30, 6); for (const [w, c] of list) b.rect((30 - w) >> 1, 0, w, 6, c); return b; };
	def("Hazards", "laser_sweep_fire", 12, [
		[[30, C.pureWhite]], [[30, RED.hi], [20, C.pureWhite]], [[30, RED.tube], [20, RED.hi], [10, C.pureWhite]],
		[[30, RED.ring], [20, RED.tube], [10, RED.hi], [4, C.pureWhite]], [[16, RED.ring], [8, RED.tube], [2, RED.hi]], [[6, RED.ring], [2, RED.tube]],
	].map(bands));

	// -- paddle_hurt: red twin of paddle_hit, the stripe flashes then burns red --
	def("Hazards", "paddle_hurt", 12, [C.pureWhite, RED.tube, RED.hi, RED.tube].map((c) => { const b = A.paddle.crop(0, 0, 60, 8); b.hline(6, 4, 48, c); return b; }));
	// intent_* icons live in parts/icons.mjs (one style for all six); shield_row's face is brick_solid, which exists.
}
