// Corp Tower elites and bosses (docs/content/maps/corp-tower.md): ice_wall, head_of_security, legal, twin_sentries (64x48 elites, chrome rim like warden),
// mainframe and ceo (160x48 bosses). All 48 tall, feet on the bottom row, anchored bottom centre like parts/enemies.mjs.
// Strips per enemy: <id>_idle x4 @8 (loop), <id>_hit x6 @12, <id>_attack x6 @12 (the hazard spawns on frame 3, the release pose), <id>_die x8 @12 (ends blank).
// Extras for the two-part fights: twin_sentries_attack_r 64x48 x6 @12 (the right turret's own cycle; the plain attack is the left one),
// mainframe_core_die 24x24 x6 @12 (overlay on one core at body-local (20,10), (68,10) or (116,10); holds its last frame, the dead locked core),
// ceo_shield_drop 160x48 x8 @12 (the 50% beat: the desk-front shield bar shatters; the plain ceo strips never draw it, so play this once and go back to them).
// Look: kit() from parts/enemies.mjs, a dark body with one lit red accent. emit(h) takes { Img, C, def, frame, blank } from gen.mjs's MAPH.
import { kit } from "./enemies.mjs";

const GROUP = "Elites and bosses: Corp Tower";

export function emit({ Img, C, def, frame, blank }) {
	const { E, RED, flash, hot, oval, block, eye, std, fade } = kit(C);
	// Fill any shape given as inside(x, y): rim where a 4-neighbour is outside, a lit row 2 under every top edge.
	const solid = (f, inside, rim = E.chrome) => {
		for (let y = 0; y < f.h; y++) for (let x = 0; x < f.w; x++) if (inside(x, y)) {
			const edge = !inside(x - 1, y) || !inside(x + 1, y) || !inside(x, y - 1) || !inside(x, y + 1);
			f.px(x, y, edge ? rim : !inside(x, y - 2) ? E.hi : E.fill);
		}
	};
	const shake = (img, dx, dy = 0) => frame(img.w, img.h, [img, dx, dy]);
	const die = (pose, w) => [flash(pose(0)), hot(pose(0)), pose(1), pose(2), pose(3), fade(pose(4), 170), fade(pose(4), 90), blank(w, 48)];  // pose(k): 0 whole .. 4 wrecked

	// -- ice_wall: three crystal slabs with pointed tops, one red scan slit across all three. Attack: the slit charges and fires; die: the slabs slide apart and sink. --
	const SLABS = [[6, 18, 10], [23, 18, 2], [41, 18, 7]];  // [x, w, top y]
	const ice = ({ scan = 0, slit = RED.tube, open = 0, spread = 0, sink = [0, 0, 0], frost = true } = {}) => {
		const f = new Img(64, 48);
		SLABS.forEach(([x0, w, t], i) => {
			const x = x0 + (i - 1) * spread, top = t + sink[i], cx = x + w / 2 - .5;
			solid(f, (px, py) => px >= x && px < x + w && py < 48 && py >= top + Math.max(0, Math.round(w / 2 - Math.abs(px - cx) - 1)));
			f.line(x + 3, top + w / 2 + 4, x + w - 4, top + w / 2 + 10, E.rim);  // facet
			if (frost) f.px(x + 3, top + w / 2 + 2, E.chromeHi);
		});
		if (slit) {
			f.rect(8 - spread, 22 - open, 48 + spread * 2, 2 + open * 2, RED.deep); f.hline(8 - spread, 22, 48 + spread * 2, slit); f.hline(8 - spread, 23, 48 + spread * 2, slit);
			if (slit === RED.tube) f.rect(10 + scan * 14, 22, 4, 2, RED.hi);
		}
		return f;
	};
	const I0 = ice();
	def(GROUP, "ice_wall_idle", 8, [I0, ice({ scan: 1 }), ice({ scan: 2 }), ice({ scan: 1 })]);
	def(GROUP, "ice_wall_hit", 12, std(I0, [ice({ spread: 2, slit: RED.dim }), ice({ spread: 1 })]));
	def(GROUP, "ice_wall_attack", 12, [ice({ open: 1 }), ice({ open: 2, slit: RED.hi }), ice({ open: 3, slit: RED.hi, spread: 1 }),
		(() => { const f = ice({ open: 3, slit: C.pureWhite, spread: 1 }); for (let x = 6; x < 58; x += 4) f.rect(x, 26, 2, 4 + (x % 8 ? 2 : 0), RED.hi); return f; })(), ice({ open: 1, slit: RED.hi }), I0]);
	def(GROUP, "ice_wall_die", 12, die((k) => ice({ spread: k, slit: k ? (k > 2 ? null : RED.dim) : RED.tube, sink: [k * 3, k * 6, k * 4].map((v) => k > 3 ? v + 10 : v), frost: k < 2 }), 64));

	// -- head_of_security: a broad guard, peaked cap, red visor shades, arms folded; the right arm swings a flashlight up to fire. --
	const guard = ({ dx = 0, dy = 0, visor = RED.tube, scan = 0, arm = 0, beam = 0, slump = 0 } = {}) => {
		const f = new Img(64, 48), X = 32 + dx, Y = dy + slump;
		block(f, X - 11, 40 + dy, 9, 8, false, E.chrome); block(f, X + 2, 40 + dy, 9, 8, false, E.chrome);                       // boots
		solid(f, (x, y) => y >= 17 + Y && y < 41 + dy && Math.abs(x + .5 - X) <= 22 - Math.max(0, y - 17 - Y) * .45);              // shoulders taper to the waist
		f.px(X - 16, 21 + Y, E.chromeHi); f.rect(X + 9, 20 + Y, 4, 3, E.chrome);                                                   // epaulette, badge
		if (arm === 0) { block(f, X - 18, 26 + Y, 36, 6, false, E.chrome); f.rect(X - 4, 27 + Y, 1, 4, E.rim); }                   // folded arms
		else {
			block(f, X - 18, 26 + Y, 18, 6, false, E.chrome);
			const t = (arm === 1 ? 20 : arm === 2 ? 45 : 60) * Math.PI / 180, ex = Math.round(X + 14 + 14 * Math.cos(t)), ey = Math.round(24 + Y - 14 * Math.sin(t));
			for (const o of [-1, 0, 1]) f.line(X + 14 + o, 24 + Y, ex + o, ey, o ? E.chrome : E.fill);
			f.rect(ex - 2, ey - 3, 5, 4, E.chrome); f.rect(ex - 1, ey - 3, 3, 1, beam ? C.pureWhite : RED.tube);                  // flashlight
			if (beam) for (let k = 1; k <= 6; k++) { f.px(ex + k, ey - 3 - k, k < 3 ? C.pureWhite : RED.hi); f.px(ex - k, ey - 3 - k, k < 3 ? C.pureWhite : RED.hi); f.px(ex, ey - 3 - k, RED.tube); }
		}
		block(f, X - 7, 6 + Y, 14, 12, false, E.chrome);                                                                            // head
		solid(f, (x, y) => y >= Y && y < 7 + Y && Math.abs(x + .5 - X) <= 10 - Math.max(0, y - 2 - Y));                             // cap crown, flared like a police cap
		f.rect(X - 8, 6 + Y, 16, 2, E.rim); f.hline(X - 7, 6 + Y, 14, E.chrome); f.rect(X - 1, 2 + Y, 2, 2, E.chromeHi);           // peak, cap badge
		if (visor) { f.rect(X - 6, 10 + Y, 12, 3, visor); f.rect(X - 1, 12 + Y, 2, 1, RED.deep); if (visor === RED.tube) f.rect(X - 5 + scan * 4, 10 + Y, 2, 1, RED.hi); }
		return f;
	};
	const S0 = guard();
	def(GROUP, "head_of_security_idle", 8, [S0, guard({ scan: 1 }), guard({ scan: 2 }), guard({ scan: 1 })]);
	def(GROUP, "head_of_security_hit", 12, std(S0, [guard({ dx: 2, dy: 1, visor: RED.dim }), guard({ dx: 1 })]));
	def(GROUP, "head_of_security_attack", 12, [guard({ arm: 1 }), guard({ arm: 2, scan: 2 }), guard({ arm: 3, visor: RED.hi }), guard({ arm: 3, beam: 1, visor: RED.hi }), guard({ arm: 2 }), S0]);
	def(GROUP, "head_of_security_die", 12, die((k) => guard({ slump: [0, 2, 5, 9, 12][k], visor: k ? (k > 2 ? null : RED.dim) : RED.tube }), 64));

	// -- legal: a walking briefcase with a red wax-seal lock for an eye and a gavel arm; the gavel comes down for the attack. --
	const legal = ({ ang = 70, dy = 0, seal = RED.tube, papers = 0, bang = false, lid = 0 } = {}) => {
		const f = new Img(64, 48), Y = dy;
		block(f, 14, 42 + Y, 4, 6, false, E.chrome); block(f, 32, 42 + Y, 4, 6, false, E.chrome);                                    // stubby legs
		f.outline(19, 12 + Y - lid, 12, 7, E.chrome); f.outline(20, 13 + Y - lid, 10, 5, E.rim);                                     // handle
		for (const [x, h] of [[12, 3 + papers], [24, 5 - papers], [34, 2 + papers]]) { f.rect(x, 18 + Y - lid - h, 6, h + 1, C.white); f.hline(x + 1, 19 + Y - lid - h, 4, E.chrome); }  // papers
		block(f, 6, 18 + Y, 38, 25, false, E.chrome); f.hline(7, 24 + Y, 36, E.chrome);                                // case, lid seam
		for (const x of [10, 38]) f.rect(x, 23 + Y, 2, 3, E.chromeHi);                                                                 // latches
		if (seal) { oval(f, 25, 32 + Y, 5, 5, false); f.rect(22, 30 + Y, 6, 5, seal); if (seal === RED.tube) { f.px(22, 30 + Y, RED.hi); f.px(25, 32 + Y, RED.deep); } }
		const px = 44, py = 26 + Y, t = ang * Math.PI / 180, ex = Math.round(px + 12 * Math.cos(t)), ey = Math.round(py - 12 * Math.sin(t));
		for (const o of [-1, 1]) f.line(px + o, py, ex + o, ey, E.chrome); f.line(px, py, ex, ey, E.fill);
		const hx = ex + 2 * Math.cos(t), hy = ey - 2 * Math.sin(t), along = (x, y) => (x + .5 - hx) * Math.sin(t) + (y + .5 - hy) * Math.cos(t), across = (x, y) => (x + .5 - hx) * Math.cos(t) - (y + .5 - hy) * Math.sin(t);
		solid(f, (x, y) => Math.abs(along(x, y)) <= 7 && Math.abs(across(x, y)) <= 3);                                             // gavel head, square to the handle
		for (let y = 0; y < 48; y++) for (let x = 0; x < 64; x++) if (Math.abs(Math.abs(along(x, y)) - 4) < .5 && Math.abs(across(x, y)) < 2) f.px(x, y, RED.ring);  // red bands
		if (bang) for (const [x, y] of [[54, 44], [62, 45], [57, 40], [60, 42], [52, 41]]) f.px(x, y, x & 1 ? C.pureWhite : RED.hi);
		return f;
	};
	const G0 = legal();
	def(GROUP, "legal_idle", 8, [G0, legal({ papers: 1 }), legal({ ang: 74, papers: 1 }), legal({ ang: 74 })]);
	def(GROUP, "legal_hit", 12, std(G0, [legal({ ang: 100, dy: 1, seal: RED.dim, papers: 2 }), legal({ ang: 85, papers: 1 })]));
	def(GROUP, "legal_attack", 12, [legal({ ang: 95 }), legal({ ang: 120, seal: RED.hi }), legal({ ang: 135, seal: RED.hi, lid: 1 }), legal({ ang: -40, seal: C.pureWhite, bang: true, dy: 1 }), legal({ ang: -20, papers: 2 }), G0]);
	def(GROUP, "legal_die", 12, die((k) => legal({ ang: 70 - k * 30, dy: k * 2, lid: k * 2, papers: k, seal: k ? (k > 2 ? null : RED.dim) : RED.tube }), 64));

	// -- twin_sentries: two dome turrets on one base, a solid spine between them (the board's spine). Left fires in _attack, right in _attack_r (mirror). --
	const sentries = ({ L = {}, R = {}, sink = 0 } = {}) => {
		const f = new Img(64, 48);
		block(f, 29, 12 + sink, 6, 32, false, E.chrome); f.rect(31, 12 + sink, 2, 1, E.chromeHi);                                    // spine
		block(f, 3, 40, 58, 8, false, E.chrome);                                                                                       // base
		for (const [side, s] of [[-1, L], [1, R]]) {
			const { lift = 0, lens = RED.tube, fire = 0, drop = sink } = s, cx = 32 + side * 17, cy = 26 - lift + drop;
			f.rect(cx - 2, cy + 6, 4, 40 - cy - 6, E.rim); f.rect(cx - 1, cy + 6, 2, 40 - cy - 6, E.fill);                              // neck
			solid(f, (x, y) => y < cy + 7 && ((x + .5 - cx) / 10) ** 2 + ((y + .5 - cy - 6) / 10) ** 2 <= 1);                          // dome
			const lx = cx + side * 3;
			f.rect(lx - 2, cy - 1, 5, 4, RED.deep); if (lens) { f.rect(lx - 1, cy, 3, 2, lens); if (lens === RED.tube) f.px(lx - 1, cy, RED.hi); }
			f.rect(lx - 1, cy - 9, 4, 6, E.chrome); f.rect(lx, cy - 9, 2, 5, E.fill);                                                     // barrel
			if (fire) for (let k = 1; k <= fire * 2; k++) { f.px(lx, cy - 9 - k, k < 3 ? C.pureWhite : RED.tube); f.px(lx + 1, cy - 9 - k, RED.hi); if (k < 3) { f.px(lx - k, cy - 9 - k, RED.hi); f.px(lx + 1 + k, cy - 9 - k, RED.hi); } }
		}
		return f;
	};
	const T0 = sentries(), Lfire = [{ lift: 1 }, { lift: 2, lens: RED.hi }, { lift: 3, lens: RED.hi }, { lift: 3, lens: C.pureWhite, fire: 3 }, { lift: 1, fire: 1 }, {}].map((L) => sentries({ L }));
	def(GROUP, "twin_sentries_idle", 8, [T0, sentries({ L: { lift: 1 } }), sentries({ L: { lift: 1 }, R: { lift: 1 } }), sentries({ R: { lift: 1 } })]);
	def(GROUP, "twin_sentries_hit", 12, std(T0, [shake(sentries({ L: { lens: RED.dim }, R: { lens: RED.dim } }), 2), shake(T0, -1)]));
	def(GROUP, "twin_sentries_attack", 12, Lfire);
	def(GROUP, "twin_sentries_attack_r", 12, Lfire.map((f) => f.flipX()));
	def(GROUP, "twin_sentries_die", 12, die((k) => sentries({ sink: k * 3, L: { lens: k ? (k > 2 ? null : RED.dim) : RED.tube, drop: k * 4 }, R: { lens: k > 1 ? null : k ? RED.dim : RED.tube, drop: k * 5 } }), 64));

	// -- mainframe 160x48: a three-tower server cabinet, one red core window per tower, blinking light rows between. --
	const CORES = [32, 80, 128];
	const mainframe = ({ lift = 0, cores = [RED.tube, RED.tube, RED.tube], blink = 0, vent = false } = {}) => {
		const f = new Img(160, 48), top = (x) => (x >= 56 && x < 104 ? 0 : 6) + lift;
		CORES.forEach((cx) => block(f, cx - (cx === 80 ? 24 : 22), top(cx), cx === 80 ? 48 : 44, 48 - top(cx), false, E.chrome));
		for (const cx of CORES) for (let x = cx - 18; x < cx + 18; x += 4) f.rect(x, top(cx) + 3, 2, 2, E.rim);                    // vents
		CORES.forEach((cx, i) => {
			const c = cores[i], cy = 22 + lift;
			oval(f, cx, cy, 10, 10, false); f.outline(cx - 1, cy - 11, 2, 2, E.chromeHi);
			if (c) { oval(f, cx, cy, 6, 6, false); for (let y = -5; y < 5; y++) for (let x = -5; x < 5; x++) if ((x + .5) ** 2 + (y + .5) ** 2 <= 22) f.px(cx + x, cy + y, (x + .5) ** 2 + (y + .5) ** 2 <= 6 ? (c === RED.tube ? RED.hi : c) : c); }
			for (let k = 0; k < 6; k++) f.px(cx - 12 + k * 5, 38 + lift, (k + blink + i) % 3 ? E.rim : RED.tube);                      // light row
		});
		if (vent) for (const [x, y] of [[60, -2], [80, -4], [100, -2], [40, 4], [120, 4]]) f.px(x, y + lift + 4, RED.hi);
		return f;
	};
	const F0 = mainframe(), dimmed = (c) => [c, c, c];
	def(GROUP, "mainframe_idle", 8, [F0, mainframe({ blink: 1 }), mainframe({ blink: 2 }), mainframe({ blink: 1, cores: dimmed(RED.ring) })]);
	def(GROUP, "mainframe_hit", 12, std(F0, [shake(mainframe({ cores: dimmed(RED.dim) }), 2), shake(F0, -1)]));
	def(GROUP, "mainframe_attack", 12, [mainframe({ cores: [RED.hi, RED.tube, RED.tube] }), mainframe({ cores: [RED.hi, RED.hi, RED.tube], lift: -1 }), mainframe({ cores: dimmed(RED.hi), lift: -1 }),
		mainframe({ cores: dimmed(C.pureWhite), lift: -2, vent: true }), mainframe({ cores: dimmed(RED.hi) }), F0]);
	def(GROUP, "mainframe_die", 12, die((k) => mainframe({ lift: [0, 3, 8, 18, 30][k], cores: dimmed([RED.tube, RED.dim, RED.deep, null, null][k]) }), 160));
	// Core overlay 24x24: the core flares, cracks and goes dark behind a red lock bar (permanent lockdown on its third).
	const core = (c, crack = 0, lock = false) => {
		const f = new Img(24, 24); oval(f, 12, 12, 10, 10, false);
		if (c) for (let y = -5; y < 5; y++) for (let x = -5; x < 5; x++) if ((x + .5) ** 2 + (y + .5) ** 2 <= 22) f.px(12 + x, 12 + y, c);
		if (crack) f.line(7, 6, 7 + crack * 3, 6 + crack * 4, C.pureWhite);
		if (lock) { f.rect(3, 11, 18, 3, RED.ring); f.hline(3, 12, 18, RED.tube); f.rect(10, 9, 4, 7, E.chrome); f.rect(11, 11, 2, 2, RED.hi); }
		return f;
	};
	def(GROUP, "mainframe_core_die", 12, [core(C.pureWhite), core(RED.hi, 1), core(RED.tube, 2), core(RED.dim, 3), core(RED.deep, 3, true), core(null, 0, true)]);

	// -- ceo 160x48: a suited figure on a high-backed throne behind a long desk; red tie and eyes are the accent. The desk shield bar only exists in ceo_shield_drop. --
	const ceo = ({ lift = 0, eyes = RED.tube, tie = RED.tube, hand = 0, fire = false, shield = 0, sink = 0 } = {}) => {
		const f = new Img(160, 48), Y = lift + sink;
		const back = (x) => 6 + Y - Math.max(0, ...[46, 60, 100, 114].map((fx) => 6 - Math.abs(x - fx) * 2));
		solid(f, (x, y) => y >= back(x) && y < 34 && Math.abs(x + .5 - 80) <= 36);                                                 // throne back, four finials
		f.outline(50, 10 + Y, 60, 24, E.rim); f.rect(51, 11 + Y, 58, 22, "000020");                                                // dark inner panel
		solid(f, (x, y) => y >= 22 + Y && y < 34 && Math.abs(x + .5 - 80) <= 24 - Math.max(0, 4 - (y - 22 - Y)) * 2);             // shoulders
		f.ascii(76, 22 + Y, ["##.....##", ".##...##.", "..##.##..", "...#.#..."], { "#": C.white });  // collar
		f.rect(79, 25 + Y, 2, 2, tie); f.rect(78, 27 + Y, 4, 6, tie); f.px(78, 32 + Y, "000020"); if (tie === RED.tube) f.px(79, 27 + Y, RED.hi);  // tie
		block(f, 72, 7 + Y, 16, 15, false, E.chrome); f.rect(72, 5 + Y, 16, 4, E.chrome); f.rect(73, 6 + Y, 9, 2, E.chromeHi);       // head, slicked hair
		if (eyes) { f.rect(74, 13 + Y, 4, 2, eyes); f.rect(82, 13 + Y, 4, 2, eyes); } f.hline(76, 18 + Y, 8, E.rim);                 // eyes, thin mouth
		block(f, 20, 32, 120, 16, false, E.chrome); f.hline(21, 35, 118, E.rim); for (const x of [36, 120]) f.rect(x, 38, 4, 2, E.chromeHi);  // desk, drawers
		if (hand) {                                                                                                                     // right hand rises and points
			const hy = 30 - hand * 6 + Y; f.rect(98, hy, 4, 32 - hy, E.rim); f.rect(99, hy, 2, 32 - hy, E.fill); f.rect(97, hy - 3, 6, 4, C.white);
			if (fire) for (const [x, y] of [[100, -6], [96, -5], [104, -5], [100, -9], [93, -8], [107, -8]]) f.px(x, hy + y, y < -7 ? RED.hi : C.pureWhite);
		}
		if (shield) for (let x = 22; x < 138; x++) { const gap = shield > 1 && (x * 7 + shield * 13) % (12 - shield) < shield; if (!gap) { f.px(x, 30 + (shield > 2 ? (x % 5) - 2 : 0), shield > 2 ? RED.hi : RED.tube); f.px(x, 31, RED.ring); } }
		return f;
	};
	const C0 = ceo();
	def(GROUP, "ceo_idle", 8, [C0, ceo({ lift: -1 }), C0, ceo({ eyes: RED.dim })]);
	def(GROUP, "ceo_hit", 12, std(C0, [shake(ceo({ lift: 1, eyes: RED.dim }), 2), shake(C0, -1)]));
	def(GROUP, "ceo_attack", 12, [ceo({ hand: 1 }), ceo({ hand: 2, eyes: RED.hi }), ceo({ hand: 3, eyes: RED.hi, lift: -1 }), ceo({ hand: 3, fire: true, eyes: C.pureWhite, tie: RED.hi, lift: -1 }), ceo({ hand: 2 }), C0]);
	def(GROUP, "ceo_die", 12, die((k) => ceo({ sink: [0, 3, 8, 14, 22][k], eyes: k ? (k > 2 ? null : RED.dim) : RED.tube, tie: k > 2 ? RED.dim : RED.tube }), 160));
	def(GROUP, "ceo_shield_drop", 12, [ceo({ shield: 1 }), ceo({ shield: 1, eyes: RED.hi }), ceo({ shield: 2, hand: 1, eyes: RED.hi }), ceo({ shield: 3, hand: 2, eyes: C.pureWhite, tie: RED.hi }), ceo({ shield: 4, hand: 2, eyes: RED.hi }), ceo({ shield: 6, hand: 1 }), ceo({ eyes: RED.hi }), C0]);
}

// Strip contract (docs/content/maps/corp-tower.md): name, frame width, frames. Height is 48, except the core overlay.
export const STRIPS = [
	...["ice_wall", "head_of_security", "legal", "twin_sentries", "mainframe", "ceo"].flatMap((id) => { const w = id === "mainframe" || id === "ceo" ? 160 : 64; return [[`${id}_idle`, w, 4], [`${id}_hit`, w, 6], [`${id}_attack`, w, 6], [`${id}_die`, w, 8]]; }),
	["twin_sentries_attack_r", 64, 6], ["mainframe_core_die", 24, 6], ["ceo_shield_drop", 160, 8],
];
