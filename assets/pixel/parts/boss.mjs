// The boss (`maw`): a 160x48 dark creature with one red accent, its mouth, and the mouth gimmick art.
// Contract: docs/content.md (Enemies table, "Boss intent `mouth`", Asset inventory). Look: docs/art-style.md (enemies are the one non-lamp sprite).
// gen.mjs exports nothing, so `emit(h)` takes its helpers: h = { Img, C, def, A, frame, hold, blank } (all from gen.mjs top half).
// Call from gen.mjs after `def` exists: `emitBoss({ Img, C, def, A, frame, hold, blank })`.
// Strips: maw_idle 160x48 x4 @8, maw_hit 160x48 x6 @12 (hazard spawn frame convention: attack frame 3), maw_attack 160x48 x6 @12,
// maw_die 160x48 x8 @12, maw_mouth_open 48x16 x6 @12 (hold last), maw_mouth_close 48x16 x6 @12. Static: intent_mouth 12x12.
// Anchor: bottom centre at field sprite (240,54); the mouth zone overlay sits at field (216,0), i.e. body-local (56,-6).

// Red set from docs/art-style.md (palette 32-47); not in gen.mjs SETS yet, so it lives here.
const RED = { tube: "ff0000", ring: "a30000", deep: "3a0000", hi: "ff8a8a", dim: "7f0000" };
const W = 160, H = 48;
const SPIKES = [[10, 3], [30, 4], [46, 3], [112, 3], [128, 4], [150, 3]];  // [x, height] jags on the silhouette
const EYES = [[22, 2], [38, 2], [52, 3], [106, 3], [120, 2], [136, 2]];     // [x, size], y rides the dome

export function emit(h) {
	const { Img, C, def, A, frame, hold, blank } = h;
	// Top edge of the body at column x: a dome (6 at the centre, 24 at the edges) with spikes, moved by `lift` (negative = up).
	const top = (x, lift) => { let y = 6 + Math.round(18 * ((x - 79.5) / 80) ** 2) + lift; for (const [sx, sh] of SPIKES) y -= Math.max(0, sh - Math.abs(x - sx)); return Math.max(0, y); };
	// body({ lift, fill, rim, eye, eyeHi, mouth, teeth, blink }): the whole creature, filled down to the bottom row so it always sits on the wall.
	const body = ({ lift = 0, fill = C.trimLo, rim = C.chromeLo, eye = RED.tube, eyeHi = RED.hi, mouth = 2, teeth = RED.ring, blink = false } = {}) => {
		const b = new Img(W, H);
		for (let x = 0; x < W; x++) { const y = top(x, lift); b.rect(x, y, 1, H - y, fill); if (y < H) b.px(x, y, rim); }
		for (let x = 1; x < W - 1; x++) { const y = top(x, lift); if (top(x - 1, lift) > y && top(x + 1, lift) > y) b.px(x, y + 1, C.trim); }  // spike tips catch the light
		const my = 8 + lift;  // mouth slit, centred under where the open-mouth overlay lands
		if (mouth > 0) {
			b.rect(62, my, 36, mouth, RED.deep);
			if (mouth > 2) { b.outline(61, my - 1, 38, mouth + 2, RED.tube); b.corners(); }
			for (let x = 64; x < 98; x += 4) { b.px(x, my, teeth); if (mouth > 3) b.px(x + 2, my + mouth - 1, teeth); }
		}
		for (const [ex, s] of EYES) {
			const ey = top(ex, lift) + 5;
			if (blink) b.rect(ex, ey + (s >> 1), s, 1, RED.dim);
			else { b.rect(ex, ey, s, s, eye); b.px(ex, ey, eyeHi); }
		}
		return b;
	};
	const rest = body();
	const FLASH = body({ fill: C.white, rim: C.pureWhite, eye: C.pureWhite, eyeHi: C.pureWhite, teeth: C.pureWhite });
	const HOT = body({ fill: RED.ring, rim: RED.tube, eye: C.pureWhite, eyeHi: C.pureWhite, teeth: RED.hi });
	const shift = (img, dx) => frame(W, H, [img, dx, 0]);

	def("Enemies", "maw_idle", 8, [rest, body({ lift: -1 }), rest, body({ blink: true })]);
	def("Enemies", "maw_hit", 12, [FLASH, HOT, shift(body({ lift: 1 }), 2), shift(rest, -1), rest, rest]);
	def("Enemies", "maw_attack", 12, [
		body({ lift: 1 }), body({ lift: -2, mouth: 4 }), body({ lift: -3, mouth: 6, teeth: RED.hi }),
		(() => { const f = body({ lift: -3, mouth: 6, teeth: RED.hi, eye: RED.hi, eyeHi: C.pureWhite }); for (const [x, y] of [[54, 2], [106, 2], [50, 8], [110, 8], [80, -1]]) f.rect(x, y + 1, 1, 1, RED.hi); return f; })(),  // spawn frame: the hazard leaves here
		body({ lift: -1, mouth: 3 }), rest,
	]);
	def("Enemies", "maw_die", 12, [
		FLASH, HOT, body({ lift: 4, eye: RED.dim, eyeHi: RED.ring }), body({ lift: 10, blink: true }).fade(220),
		body({ lift: 20, blink: true, mouth: 0 }).fade(170), body({ lift: 32, blink: true, mouth: 0 }).fade(110), body({ lift: 42, blink: true, mouth: 0 }).fade(60), blank(W, H),
	]);

	// Mouth zone overlay 48x16: a dark gullet rimmed in red with a tooth row top and bottom.
	const gape = (ry, rim = RED.tube, hiTeeth = true) => {
		const f = new Img(48, 16), cx = 23.5, cy = 11.5, rx = Math.min(23, 15 + ry * 1.5);
		const inside = (x, y, dx, dy) => ((x + .5 - cx - .5) / (rx - dx)) ** 2 + ((y + .5 - cy - .5) / (ry - dy)) ** 2 <= 1;
		for (let y = 0; y < 16; y++) for (let x = 0; x < 48; x++) { if (ry > 0 && inside(x, y, 0, 0)) f.px(x, y, rim); if (ry > 1 && inside(x, y, 1, 1)) f.px(x, y, RED.deep); if (ry > 4 && inside(x, y, 3, 4)) f.px(x, y, "000020"); }
		if (ry === 0) f.hline(6, 11, 36, rim);
		if (ry > 2 && hiTeeth) for (let x = 8; x < 40; x += 4) { f.px(x, Math.round(cy - ry + 1), RED.hi); f.px(x + 2, Math.round(cy + ry - 1), RED.hi); }
		return f;
	};
	const open = gape(7);
	def("Enemies", "maw_mouth_open", 12, [gape(0), gape(2), gape(4), gape(6), open, open]);
	def("Enemies", "maw_mouth_close", 12, [gape(7, C.pureWhite), gape(5), gape(3), gape(1), gape(0, RED.ring, false), blank(48, 16)]);
	// intent_mouth lives in parts/icons.mjs with the other five intents.
}
