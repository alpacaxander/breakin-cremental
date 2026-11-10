// Peglin-direction brick kinds (docs/content.md, Bricks): crit (blue), refresh (mint), red (enemy). Faces and strips.
// gen.mjs exports nothing, so emit(h) takes its helpers: Img, C, SETS, lit, dim, hot, FLASH, frame, center, hold, blank,
// sparks, withIcon, glyph, ellipse, ICONS, A (statics map, read for A.ball, written for the faces) and def (anim registrar).
// Wire-up in gen.mjs, one line after the hue-set loop and A.ball exist: emitBricks({ Img, C, SETS, lit, dim, hot, FLASH, frame, center, hold, blank, sparks, withIcon, glyph, ellipse, ICONS, A, def });
// bomb's orange recolour is not here: add "bomb" to SPECIAL_ICONS in gen.mjs so icon_bomb_pulse takes the orange body.

// Red hue set from docs/art-style.md (palette ramp 32-47). Exported so gen.mjs can put it in SETS as `red`.
export const RED = { tube: "ff0000", ring: "a30000", deep: "3a0000", hi: "ff8a8a", dimTube: "7f0000", dimRing: "3a0000" };

const GROUP = "Peglin bricks";
const PULSE = (h, body, icon) => [h.C.pay, h.C.white, h.C.pureWhite, h.C.white].map((c) => h.withIcon(body, icon, c));

// <id>_hit, <id>_break, <id>_spawn for one hue set; the same shapes as gen.mjs's hue loop. fall: halves and chips drop instead of flying out.
function hueStrips(h, s, id, fall) {
	const { Img, C, lit, dim, hot, FLASH, frame, center, hold, blank, sparks, def } = h;
	const L = lit(s), H = hot(s), D = dim(s);
	def(GROUP, `${id}_hit`, 12, [FLASH, H, ...hold(L, 4)]);
	def(GROUP, `${id}_break`, 12, (() => {
		const W = 44, Hh = 20, Lh = L.crop(0, 0, 15, 12), Rh = L.crop(15, 0, 15, 12), chip = (() => { const b = new Img(4, 3); b.rect(0, 0, 4, 3, s.tube); b.rect(1, 1, 2, 1, s.deep); return b; })();
		const f0 = frame(W, Hh, center(FLASH, W, Hh));
		const f1 = frame(W, Hh, center(H, W, Hh)); sparks(f1, 8, C.pay);
		const f2 = fall ? frame(W, Hh, [Lh, 6, 6], [Rh, 23, 7], [chip, 14, 13], [chip, 27, 12]) : frame(W, Hh, [Lh, 5, 3], [Rh, 24, 3], [chip, 20, 1], [chip, 19, 15]); sparks(f2, 7, C.payHi);
		const f3 = fall ? frame(W, Hh, [Lh, 5, 10, 150], [Rh, 24, 11, 150], [chip, 12, 17, 200], [chip, 30, 16, 200], [chip, 21, 18, 200]) : frame(W, Hh, [Lh, 2, 1, 150], [Rh, 27, 5, 150], [chip, 10, 17, 200], [chip, 32, 0, 200], [chip, 21, 16, 200]); sparks(f3, 9, C.payDim);
		const f4 = fall ? frame(W, Hh, [Lh, 4, 15, 70], [Rh, 25, 16, 70], [chip, 10, 19, 90], [chip, 33, 19, 90]) : frame(W, Hh, [chip, 6, 19, 90], [chip, 36, 0, 90], [chip, 22, 18, 90]);
		return [f0, f1, f2, f3, f4, ...hold(blank(W, Hh), 3)];
	})());
	def(GROUP, `${id}_spawn`, 12, (() => {
		const o = new Img(30, 12); o.outline(0, 0, 30, 12, s.dimTube); o.corners();
		const o2 = o.crop(0, 0, 30, 12); o2.outline(1, 1, 28, 10, s.dimRing);
		return [o, o2, D, FLASH, H, L];
	})());
}

export function emitBricks(h) {
	const { Img, C, SETS, lit, hot, FLASH, frame, withIcon, glyph, ellipse, ICONS, A, def } = h;
	const red = SETS.red || RED;

	// crit: the multiball face repurposed (its three balls now mean "launch the next bag ball"). Blue body.
	const BL = lit(SETS.blue), critIcon = ICONS.multiball;
	A.brick_crit = withIcon(BL, critIcon, C.white);
	def(GROUP, "crit_pulse", 8, PULSE(h, BL, critIcon));
	// Break: flash, hot, then a ball swells in the glass and drops out of the bottom edge toward the paddle while the face fades.
	def(GROUP, "crit_launch", 12, [FLASH, withIcon(hot(SETS.blue), critIcon, C.pureWhite),
		frame(30, 12, [BL, 0, 0], [ellipse(4, 4), 13, 4]), frame(30, 12, [BL, 0, 0, 200], [ellipse(6, 6), 12, 3]),
		frame(30, 12, [BL, 0, 0, 120], [A.ball, 11, 3]), frame(30, 12, [BL, 0, 0, 50], [A.ball, 11, 5])]);

	// refresh: mint body, circular-arrow icon. The wave is a 60-wide band that sweeps 12 rows top to bottom, tiled across the board.
	const NL = lit(SETS.mint), refreshIcon = glyph([".###..#", "#....##", "#...###", "#......", ".####.."]);
	A.brick_refresh = withIcon(NL, refreshIcon, C.white);
	def(GROUP, "refresh_pulse", 8, PULSE(h, NL, refreshIcon));
	def(GROUP, "refresh_wave", 12, [0, 1, 2, 3, 4, 5].map((f) => {
		const b = new Img(60, 12), yc = f * 2 + 1, m = SETS.mint;
		for (let x = 0; x < 60; x++) {
			b.px(x, yc, C.pureWhite); b.px(x, yc - 1, m.hi); b.px(x, yc + 1, m.tube);
			b.px(x, yc - 2, m.tube); if ((x + yc) % 2 === 0) b.px(x, yc - 3, m.tube); if (x % 4 === (yc >> 1) % 4) b.px(x, yc - 4, m.ring); if (x % 4 === 2) b.px(x, yc - 5, m.ring);
		}
		return b;
	}));
	hueStrips(h, SETS.mint, "mint", false);

	// red: a plain lamp in the enemy's hue (red_bricks paints a plain brick, so the shape stays). Its break hurts the player: the debris falls.
	A.brick_red = lit(red);
	hueStrips(h, red, "red", true);
}
