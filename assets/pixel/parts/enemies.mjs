// Regular enemies and the elite (docs/content.md, Enemies table): glob, lobber, mason (48/48/64 wide) and warden (64, elite), all 48 tall.
// Strips per enemy: <id>_idle x4 @8 (loop), <id>_hit x6 @12, <id>_attack x6 @12 (the hazard spawns on frame 3, the release pose), <id>_die x8 @12 (ends blank).
// Feet on the bottom row, body centred, so the arena anchors bottom centre at field sprite (240,54). Static enemy_<id> is frame 0 of <id>_idle, no separate sprite.
// Look (docs/art-style.md): a dark creature, the boss's body colours (trimLo fill, chromeLo rim), one lit accent in red. Flash and hot frames follow the lamp rule by recolour.
// gen.mjs exports nothing, so emit(h) takes its helpers: h = { Img, C, def, hold, blank } (all from gen.mjs's top half).
// Wire-up, one line after `def` exists: emitEnemies({ Img, C, def, hold, blank });

const RED = { tube: "ff0000", ring: "a30000", deep: "3a0000", hi: "ff8a8a", dim: "7f0000" };  // docs/art-style.md Red set, palette 32-47
const GROUP = "Enemies";

// Shared enemy look, exported for the map parts (parts/arcade*.mjs, tower*.mjs, deepnet*.mjs).
export function kit(C) {
	const E = { fill: C.trimLo, rim: C.chromeLo, hi: C.trim, chrome: C.trimHi, chromeHi: C.rivet };
	const hex = (p) => p.map((v) => v.toString(16).padStart(2, "0")).join("").slice(0, 6);
	// Recolour by table; unmapped colours stay. `all` maps every opaque pixel not in the table.
	const remap = (img, map, all = null) => { const o = img.crop(0, 0, img.w, img.h); for (let i = 0; i < o.d.length; i += 4) { if (!o.d[i + 3]) continue; const k = hex([...o.d.slice(i, i + 3)]), c = map[k] ?? all; if (c) o.d.set(rgb(c), i); } return o; };
	const rgb = (h) => [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
	const flash = (img) => remap(img, { [E.rim]: C.pureWhite, [E.chrome]: C.pureWhite, [E.chromeHi]: C.pureWhite }, C.white);
	const hot = (img) => remap(img, { [E.fill]: RED.ring, [E.rim]: RED.dim, [E.hi]: RED.hi, [E.chrome]: RED.hi, [E.chromeHi]: C.pureWhite, [RED.tube]: C.pureWhite, [RED.hi]: C.pureWhite, [RED.dim]: RED.tube, [RED.deep]: RED.ring });
	// Filled oval: 1px rim, fill inside; a 1-row highlight 2 below the top where the fill is.
	const oval = (f, cx, cy, rx, ry, hi = true) => {
		const inside = (x, y, k) => ((x + .5 - cx) / (rx - k)) ** 2 + ((y + .5 - cy) / (ry - k)) ** 2 <= 1;
		for (let y = cy - ry; y < cy + ry; y++) for (let x = cx - rx; x < cx + rx; x++) if (inside(x, y, 0)) f.px(x, y, inside(x, y, 1) ? E.fill : E.rim);
		if (hi) for (let x = cx - rx; x < cx + rx; x++) if (inside(x, cy - ry + 2, 1) && inside(x, cy - ry + 1, 1)) f.px(x, cy - ry + 2, E.hi);
	};
	// Block with a rim and a lit top edge; `seams` draws mortar lines so it reads as masonry.
	const block = (f, x, y, w, h, seams = false, rim = E.rim) => {
		f.rect(x, y, w, h, E.fill); f.outline(x, y, w, h, rim); f.hline(x + 1, y + 1, w - 2, E.hi);
		if (seams) for (let r = 1; r * 5 < h - 1; r++) { f.hline(x + 1, y + r * 5, w - 2, rim); for (let s = (r & 1) ? 5 : 10; s < w - 2; s += 10) f.rect(x + s, y + (r - 1) * 5 + 1, 1, 4, rim); }
	};
	const eye = (f, x, y, w, h, c) => { if (!c) return; f.rect(x, y, w, h, c); if (c === RED.tube) { f.px(x, y, RED.hi); f.rect(x + w - 2, y + 1, 1, h - 2, RED.deep); } };
	const std = (base, recoil) => [flash(base), hot(base), ...recoil, base, base];  // hit: flash, hot, two recoil poses, settle
	const fade = (f, a) => f.fade(a);
	return { E, RED, remap, flash, hot, oval, block, eye, std, fade };
}

export function emit({ Img, C, def, hold, blank }) {
	const { E, remap, flash, hot, oval, block, eye, std, fade } = kit(C);

	// -- glob 48x48: a slime. Breathes by trading width for height; spits a red chunk on attack; melts on death. --
	const glob = ({ rx = 16, ry = 12, eyeC = RED.tube, drip = 0, spit = false } = {}) => {
		const f = new Img(48, 48), cy = 47 - ry;
		oval(f, 24, cy, rx, ry);
		for (const [x, h] of [[15, 3 + drip], [30, 2 + (1 - drip)]]) { f.rect(x, cy - ry - h + 1, 3, h + 2, E.fill); f.rect(x, cy - ry - h, 3, 1, E.rim); f.rect(x - 1, cy - ry - h + 1, 1, h, E.rim); f.rect(x + 3, cy - ry - h + 1, 1, h, E.rim); }
		eye(f, 26, cy - 3, 7, 4, eyeC);
		if (spit) { f.rect(21, cy - ry - 10, 6, 4, RED.tube); f.outline(21, cy - ry - 10, 6, 4, RED.ring); }
		return f;
	};
	const G0 = glob();
	def(GROUP, "glob_idle", 8, [G0, glob({ rx: 15, ry: 13, drip: 1 }), G0, glob({ rx: 17, ry: 11, drip: 1 })]);
	def(GROUP, "glob_hit", 12, std(G0, [glob({ rx: 19, ry: 9, eyeC: RED.dim }), glob({ rx: 18, ry: 10 })]));
	def(GROUP, "glob_attack", 12, [glob({ rx: 18, ry: 10 }), glob({ rx: 19, ry: 9 }), glob({ rx: 14, ry: 15 }), glob({ rx: 14, ry: 15, spit: true }), glob({ rx: 15, ry: 13 }), G0]);
	def(GROUP, "glob_die", 12, [flash(G0), hot(G0), glob({ rx: 18, ry: 9 }), glob({ rx: 20, ry: 6, eyeC: RED.dim }), glob({ rx: 22, ry: 4, eyeC: null }), fade(glob({ rx: 23, ry: 2, eyeC: null }), 170), fade(glob({ rx: 23, ry: 2, eyeC: null }), 90), blank(48, 48)]);

	// -- lobber 48x48: a pot on the ground with a scoop arm. The arm angle (degrees, 0 = right, 90 = up) is the pose; a red ball rides the cup while loading. --
	const lobber = ({ ang = 60, rx = 12, ry = 10, dx = 0, dy = 0, eyeC = RED.tube, ball = null, flung = false } = {}) => {
		const f = new Img(48, 48), cx = 20 + dx, cy = 47 - ry + dy;
		const px = cx + 9, py = cy - ry + 3, t = ang * Math.PI / 180, ex = Math.round(px + 13 * Math.cos(t)), ey = Math.round(py - 13 * Math.sin(t));
		for (const [ox, oy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) f.line(px + ox, py + oy, ex + ox, ey + oy, E.rim);
		f.line(px, py, ex, ey, E.fill);
		oval(f, cx, cy, rx, ry);
		f.ascii(ex - 3, ey - 2, ["#.....#", "#.....#", ".#####."], { "#": E.chrome });  // the cup
		if (ball) { const bx = flung ? ex + 5 : ex, by = flung ? ey - 4 : ey - 2; f.rect(bx - 2, by - 2, 4, 4, ball); f.px(bx - 2, by - 2, ball === RED.tube ? RED.hi : ball); f.outline(bx - 2, by - 2, 4, 4, ball === RED.tube ? RED.ring : ball); f.corners(); }
		eye(f, cx - 5, cy - 2, 9, 2, eyeC);
		return f;
	};
	const L0 = lobber();
	def(GROUP, "lobber_idle", 8, [L0, lobber({ ang: 64 }), lobber({ ang: 68 }), lobber({ ang: 64 })]);
	def(GROUP, "lobber_hit", 12, std(L0, [lobber({ ang: 84, rx: 13, ry: 9, dx: -2, eyeC: RED.dim }), lobber({ ang: 72, dx: -1 })]));
	def(GROUP, "lobber_attack", 12, [lobber({ ang: 110 }), lobber({ ang: 135, ball: RED.dim }), lobber({ ang: 150, ball: RED.tube, rx: 13, ry: 9 }), lobber({ ang: 15, ball: RED.tube, flung: true, rx: 11, ry: 11 }), lobber({ ang: 30 }), lobber({ ang: 48 })]);
	def(GROUP, "lobber_die", 12, [flash(L0), hot(L0), lobber({ ang: 20 }), lobber({ ang: -10, dy: 1 }), lobber({ ang: -30, dy: 2, eyeC: RED.dim }), fade(lobber({ ang: -40, dy: 3, eyeC: null }), 170), fade(lobber({ ang: -40, dy: 3, eyeC: null }), 90), blank(48, 48)]);

	// -- mason 64x48: a masonry golem with a red core. Arms rise and slam for the attack; it crumbles into rubble on death. --
	const mason = ({ headDx = 0, headDy = 0, armDy = 0, torsoDy = 0, core = RED.tube, eyeC = RED.dim, dust = false, rubble = false } = {}) => {
		const f = new Img(64, 48);
		if (rubble) { block(f, 6, 40, 14, 8, true); block(f, 22, 36, 20, 12, true); block(f, 44, 42, 14, 6); block(f, 30, 30, 10, 6); f.rect(29, 41, 6, 4, core); return f; }
		block(f, 20, 40, 10, 8); block(f, 34, 40, 10, 8);                                   // legs
		block(f, 6, 18 + armDy, 10, 22, true); block(f, 48, 18 + armDy, 10, 22, true);       // arms
		block(f, 5, 38 + armDy, 12, 8); block(f, 47, 38 + armDy, 12, 8);                     // fists
		block(f, 18, 20 + torsoDy, 28, 20, true);                                           // torso
		f.rect(29, 26 + torsoDy, 6, 6, core); f.outline(29, 26 + torsoDy, 6, 6, core === RED.tube ? RED.ring : core); if (core === RED.tube || core === RED.hi) f.px(30, 27 + torsoDy, RED.hi);
		block(f, 26 + headDx, 10 + headDy, 12, 10);                                         // head
		eye(f, 28 + headDx, 14 + headDy, 2, 2, eyeC); eye(f, 34 + headDx, 14 + headDy, 2, 2, eyeC);
		if (dust) for (const [x, y] of [[2, 46], [4, 44], [16, 45], [46, 45], [58, 44], [61, 46]]) f.px(x, y, E.chrome);
		return f;
	};
	const M0 = mason();
	def(GROUP, "mason_idle", 8, [M0, mason({ core: RED.hi }), mason({ armDy: 1 }), mason({ core: RED.ring, armDy: 1 })]);
	def(GROUP, "mason_hit", 12, std(M0, [mason({ headDx: 2, headDy: -1, torsoDy: 1, armDy: -2, core: RED.hi }), mason({ headDx: 1, armDy: -1 })]));
	def(GROUP, "mason_attack", 12, [mason({ armDy: -4 }), mason({ armDy: -8, core: RED.hi }), mason({ armDy: -10, headDy: -1, core: RED.hi }), mason({ armDy: 2, torsoDy: 2, headDy: 2, dust: true, core: C.pureWhite }), mason({ armDy: 1, torsoDy: 1, headDy: 1, dust: true }), M0]);
	def(GROUP, "mason_die", 12, [flash(M0), hot(M0), mason({ headDx: 1, core: RED.hi }), mason({ headDy: 4, armDy: 6, torsoDy: 2 }), mason({ headDy: 14, headDx: -8, armDy: 16, torsoDy: 8, core: RED.dim, eyeC: null }), mason({ rubble: true, core: RED.dim }), fade(mason({ rubble: true, core: RED.deep }), 150), blank(64, 48)]);

	// -- warden 64x48, the elite: an armoured knight, chrome-rimmed, shield left and lance right. The visor slit scans; the lance tip charges and flares. --
	const warden = ({ scan = 0, dx = 0, dy = 0, shieldDx = 0, shieldDy = 0, lanceDy = 0, charge = 0, visor = RED.tube, tip = RED.tube } = {}) => {
		const f = new Img(64, 48), rim = E.chrome;
		block(f, 22 + dx, 43 + dy, 8, 5, false, rim); block(f, 34 + dx, 43 + dy, 8, 5, false, rim);   // feet
		block(f, 21 + dx, 30 + dy, 22, 13, false, rim); for (const x of [26, 31, 36]) f.rect(x + dx, 32 + dy, 1, 10, rim);  // skirt plates
		block(f, 15 + dx, 16 + dy, 10, 6, false, rim); block(f, 39 + dx, 16 + dy, 14, 6, false, rim);  // arms, out to the shield and the lance
		block(f, 23 + dx, 12 + dy, 18, 18, false, rim); f.rect(31 + dx, 14 + dy, 2, 14, E.rim);         // torso, seam
		block(f, 25 + dx, 2 + dy, 14, 10, false, rim); f.rect(31 + dx, 0 + dy, 2, 3, E.chromeHi);       // helmet, crest
		if (visor) { f.rect(27 + dx, 6 + dy, 10, 2, visor); if (visor === RED.tube) f.rect(27 + dx + scan * 2, 6 + dy, 2, 2, RED.hi); }
		block(f, 6 + shieldDx + dx, 14 + shieldDy + dy, 12, 22, false, rim); f.rect(10 + shieldDx + dx, 23 + shieldDy + dy, 4, 4, visor ? RED.dim : RED.deep);  // shield, emblem
		const lx = 51 + dx, ly = 8 + lanceDy + dy;
		f.rect(lx, ly, 3, 36, rim); f.rect(lx + 1, ly, 1, 36, E.chromeHi);                              // lance shaft
		f.ascii(lx - 1, ly - 4, [".#.", "###", "###", "###"], { "#": tip });                             // tip
		if (charge > 0 && charge < 4) for (const [ox, oy] of [[0, -charge], [0, charge], [-charge, 0], [charge, 0]]) f.px(lx + 1 + ox, ly - 2 + oy, charge === 3 ? RED.hi : RED.tube);
		if (charge === 4) { for (let k = -5; k <= 5; k++) { f.px(lx + 1 + k, ly - 2, k & 1 ? RED.tube : C.pureWhite); f.px(lx + 1, ly - 2 + k, k & 1 ? RED.tube : C.pureWhite); } for (const k of [-3, 3]) { f.px(lx + 1 + k, ly - 2 + k, RED.hi); f.px(lx + 1 + k, ly - 2 - k, RED.hi); } }
		return f;
	};
	const W0 = warden();
	def(GROUP, "warden_idle", 8, [W0, warden({ scan: 1 }), warden({ scan: 2 }), warden({ scan: 1 })]);
	def(GROUP, "warden_hit", 12, std(W0, [warden({ dx: 2, shieldDx: -2, shieldDy: -2, visor: RED.dim }), warden({ dx: 1, shieldDx: -1, shieldDy: -1 })]));
	def(GROUP, "warden_attack", 12, [warden({ charge: 1 }), warden({ charge: 2 }), warden({ charge: 3, tip: RED.hi }), warden({ charge: 4, tip: C.pureWhite, lanceDy: -4, scan: 2 }), warden({ charge: 1, lanceDy: -2, tip: RED.hi }), W0]);
	def(GROUP, "warden_die", 12, [flash(W0), hot(W0), warden({ visor: RED.dim, tip: RED.dim, lanceDy: 4 }), warden({ dy: 3, lanceDy: 12, visor: RED.dim, tip: RED.dim, shieldDy: 4 }), warden({ dy: 7, lanceDy: 22, visor: null, tip: RED.deep, shieldDy: 10 }), fade(warden({ dy: 9, lanceDy: 30, visor: null, tip: RED.deep, shieldDy: 14 }), 170), fade(warden({ dy: 9, lanceDy: 30, visor: null, tip: RED.deep, shieldDy: 14 }), 90), blank(64, 48)]);
}

// Strip contract (docs/content.md Enemies): name, frame width, frames. Height is always 48.
export const STRIPS = ["glob", "lobber", "mason", "warden"].flatMap((id) => { const w = id === "glob" || id === "lobber" ? 48 : 64; return [[`${id}_idle`, w, 4], [`${id}_hit`, w, 6], [`${id}_attack`, w, 6], [`${id}_die`, w, 8]]; });
