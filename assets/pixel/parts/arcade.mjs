// Back Alley Arcade regular enemies (docs/content/maps/back-alley-arcade.md, Enemies): rat_king 64, coin_slug 48, fuse_box 48, claw_rig 64,
// ticket_printer 48, bootleg_cabinet 48 wide, all 48 tall. glob and lobber are parts/enemies.mjs; the elites and attract_mode are parts/arcade_bosses.mjs.
// Strips per enemy (same contract as parts/enemies.mjs): <id>_idle x4 @8 (loop), <id>_hit x6 @12, <id>_attack x6 @12 (the hazard spawns on frame 3,
// the release pose), <id>_die x8 @12 (ends blank). Feet on the bottom row, body centred, anchored bottom centre. Static enemy_<id> is idle frame 0.
// Look: kit() from parts/enemies.mjs, a dark creature in the boss body colours with one lit red accent; hit and die open on its flash and hot recolours.
// Each enemy is a pose function plus a table of poses per strip; `strips` turns the table into the four defs.
import { kit } from "./enemies.mjs";

const GROUP = "Enemies: Back Alley Arcade";
const W = { rat_king: 64, coin_slug: 48, fuse_box: 48, claw_rig: 64, ticket_printer: 48, bootleg_cabinet: 48 };

export function emit({ Img, C, def, blank }) {
	const { E, RED, flash, hot, oval, block, eye, fade } = kit(C);
	// idle: 4 poses; hit: 2 recoil poses (flash, hot, recoil x2, rest x2); attack: 6 poses; die: 3 collapse poses, then the last one faded twice.
	const strips = (id, P, { idle, hit, attack, die }) => {
		const B = P({}), w = W[id];
		def(GROUP, `${id}_idle`, 8, idle.map(P));
		def(GROUP, `${id}_hit`, 12, [flash(B), hot(B), ...hit.map(P), B, B]);
		def(GROUP, `${id}_attack`, 12, attack.map(P));
		const d = die.map(P);
		def(GROUP, `${id}_die`, 12, [flash(B), hot(B), ...d, fade(d[2], 170), fade(d[2], 90), blank(w, 48)]);
	};
	const spark = (f, x, y, r, c = RED.hi) => { for (let k = 1; k <= r; k++) for (const [ox, oy] of [[k, 0], [-k, 0], [0, k], [0, -k]]) f.px(x + ox, y + oy, k === r ? c : C.pureWhite); };

	// -- rat_king 64x48: a heap of cable rats, tails knotted into plugs on the ground; the top rat is the king with the red eye. --
	// Each rat: [x, y, facing]; `s` pushes them out from the heap centre (die scatter), `rear` lifts the king, `wig` sways the tails.
	const RATS = [[14, 42, -1], [32, 43, 1], [50, 42, 1], [22, 35, -1], [42, 35, 1]];
	const rat = (f, x, y, d, big, eyeC) => {
		oval(f, x, y, big ? 9 : 7, big ? 6 : 5);
		const sx = x + d * (big ? 9 : 7);                                                  // snout, ear
		f.rect(d > 0 ? sx - 1 : sx - 2, y - 1, 3, 3, E.fill); f.px(d > 0 ? sx + 2 : sx - 3, y, E.rim); f.px(d > 0 ? sx + 1 : sx - 2, y + 1, E.rim);
		f.ascii(x + d * 2 - 1, y - (big ? 8 : 7), ["#.#", "###"], { "#": E.chrome });
		if (big) eye(f, x + d * 5 - 1, y - 2, 3, 3, eyeC); else f.px(x + d * 4, y - 1, E.chromeHi);
	};
	const ratKing = ({ s = 0, rear = 0, wig = 0, eyeC = RED.tube, squash = 0, spit = 0 } = {}) => {
		const f = new Img(64, 48);
		for (const [ex, k] of [[2, -1], [61, 1], [8, -1], [56, 1]]) {                       // tails out to plugs on the floor
			const mx = 32 + (ex - 32) / 2, my = 41 + k * wig;
			f.line(32, 40, mx, my, E.rim); f.line(mx, my, ex, 46, E.rim); f.rect(ex - 1, 45, 3, 3, E.chrome); f.px(ex, 44, E.chromeHi);
		}
		for (const [x, y, d] of RATS) rat(f, Math.round(x + (x - 32) * s), y + squash + Math.round(s * 4), d, false);
		rat(f, Math.round(32 + 6 * s), 26 - rear + squash * 2 + Math.round(s * 14), 1, true, eyeC);
		f.ascii(28 + Math.round(6 * s), 16 - rear + squash * 2 + Math.round(s * 14), ["#.#.#", "#####"], { "#": eyeC ? RED.dim : RED.deep });  // tin crown
		if (spit) { const y = 22 - spit * 4; f.rect(44, y, 4, 4, RED.tube); f.outline(44, y, 4, 4, RED.ring); f.px(44, y, RED.hi); }
		return f;
	};
	strips("rat_king", ratKing, {
		idle: [{}, { wig: 1 }, { rear: 1 }, { wig: -1 }],
		hit: [{ squash: 2, eyeC: RED.dim, wig: 1 }, { squash: 1 }],
		attack: [{ squash: 1 }, { squash: 2 }, { rear: 4 }, { rear: 5, spit: 1, eyeC: C.pureWhite }, { rear: 2, spit: 2 }, {}],
		die: [{ s: 0.3, squash: 1 }, { s: 0.7, squash: 2, eyeC: RED.dim }, { s: 1.1, squash: 3, eyeC: null }],
	});

	// -- coin_slug 48x48: a low slug, raised head on the right with a glowing coin-slot mouth and two eyestalks. --
	const coinSlug = ({ stretch = 0, rear = 0, slot = RED.tube, coin = 0, stalk = 0, melt = 0 } = {}) => {
		const f = new Img(48, 48), hy = 36 - rear + melt;
		oval(f, 20 - stretch, 42 + Math.floor(melt / 2), 17 + stretch, 6 - Math.floor(melt / 3));                      // foot
		for (const [x, k] of [[33, 0], [38, 1]]) { const ty = hy - 13 + stalk * (k ? 1 : -1) + melt; f.line(x, hy - 6, x + k * 2 - 1, ty, E.rim); f.rect(x + k * 2 - 2, ty - 2, 3, 3, E.chrome); f.px(x + k * 2 - 1, ty - 1, C.base); }
		if (melt < 8) oval(f, 36, hy, 8, 10 - melt);                                                                   // head
		if (melt < 8) { f.rect(41, hy - 5, 4, 10, E.rim); f.rect(42, hy - 4, 2, 8, slot); if (slot === RED.tube) f.px(42, hy - 4, RED.hi); }  // the coin slot
		if (coin) { const cx = 46 - coin, cy = hy - 6 - coin * 4; f.rect(cx - 1, cy - 2, 3, 5, C.pay); f.px(cx - 1, cy - 2, C.payHi); f.rect(cx + 1, cy - 2, 1, 5, C.payDim); }
		return f;
	};
	strips("coin_slug", coinSlug, {
		idle: [{}, { stretch: 1, stalk: 1 }, { stretch: 2 }, { stretch: 1, stalk: -1 }],
		hit: [{ stretch: -2, rear: -2, slot: RED.dim, stalk: 2 }, { stretch: -1, rear: -1 }],
		attack: [{ stretch: -1 }, { rear: 3, slot: RED.hi }, { rear: 6, slot: RED.hi }, { rear: 6, slot: C.pureWhite, coin: 1 }, { rear: 3, coin: 2 }, {}],
		die: [{ slot: RED.dim, rear: -2 }, { melt: 4, slot: RED.deep }, { melt: 7, slot: RED.deep }],
	});

	// -- fuse_box 48x48: a wall box on conduit legs, three red fuses in its door, sparking; the door bangs open to fire. --
	const fuseBox = ({ dy = 0, open = 0, fuse = RED.tube, zap = 0, tilt = 0, burst = 0 } = {}) => {
		const f = new Img(48, 48), y = 12 + dy;
		block(f, 13, 40, 4, 8); block(f, 31, 40, 4, 8);                                   // conduit legs
		f.line(9, y + 4, 2, y - 6 + tilt, E.rim); f.line(39, y + 4, 46, y - 6 - tilt, E.rim);  // cables out of the top corners
		block(f, 8, y, 32, 28 + (dy < 0 ? -dy : 0));                                      // box
		for (const x of [10, 37]) for (const yy of [y + 2, y + 25]) f.px(x, yy, E.chromeHi);  // rivets
		const dw = 24 - open * 6;                                                          // door narrows as it swings out
		f.outline(12, y + 4, dw, 20, E.chrome);
		if (open) f.rect(12 + dw, y + 4, 24 - dw, 20, C.base);
		for (const [i, x] of [16, 22, 28].entries()) if (x + 3 <= 12 + dw || open) {
			f.rect(x, y + 8, 4, 10, E.rim); f.rect(x + 1, y + 7, 2, 1, E.chrome); f.rect(x + 1, y + 18, 2, 1, E.chrome);
			f.rect(x + 1, y + 9, 2, 8, fuse); if (fuse === RED.tube) f.px(x + 1, y + 9 + ((zap + i) % 3) * 2, RED.hi);
		}
		f.ascii(21, y + 20, ["##.", ".##", "##."], { "#": E.hi });                         // bolt mark
		if (zap) spark(f, zap & 1 ? 2 : 46, (zap & 1 ? y - 6 + tilt : y - 6 - tilt), 2);
		if (burst) for (const [x, yy] of [[18, y - 4], [30, y - 6], [24, y - 10]]) spark(f, x, yy, burst);
		return f;
	};
	strips("fuse_box", fuseBox, {
		idle: [{}, { zap: 1 }, {}, { zap: 2, fuse: RED.hi }],
		hit: [{ dy: 2, fuse: RED.dim, tilt: 2 }, { dy: 1, tilt: 1 }],
		attack: [{ fuse: RED.hi, zap: 1 }, { fuse: RED.hi, zap: 2, dy: -1 }, { open: 1, fuse: C.pureWhite, dy: -2 }, { open: 2, fuse: C.pureWhite, burst: 3, dy: -2 }, { open: 1, burst: 1 }, {}],
		die: [{ open: 2, burst: 2, fuse: RED.dim }, { open: 2, dy: 4, fuse: RED.deep, tilt: 3 }, { open: 2, dy: 8, fuse: RED.deep, tilt: 5 }],
	});

	// -- claw_rig 64x48: a crane gantry, red lamp on the carriage, a three-prong claw on a cable. It drops, grabs, and yanks up. --
	const clawRig = ({ cy = 30, sway = 0, grip = 0, lamp = RED.tube, sag = 0 } = {}) => {
		const f = new Img(64, 48), top = 4 + sag;
		block(f, 4, top, 6, 44 - sag); block(f, 54, top, 6, 44 - sag);                     // legs
		block(f, 1, 44, 12, 4); block(f, 51, 44, 12, 4);                                   // feet
		block(f, 2, top - 2, 60, 6); for (let x = 12; x < 52; x += 6) f.line(x, top + 3, x + 3, top + 1, E.rim);  // crossbar
		block(f, 25 + sway, top - 4, 14, 8); eye(f, 30 + sway, top - 2, 4, 3, lamp);       // carriage + lamp
		const cx = 32 + sway * 2;
		f.line(32 + sway, top + 4, cx, cy, E.chrome); f.line(33 + sway, top + 4, cx + 1, cy, E.rim);  // cable
		block(f, cx - 4, cy, 10, 5);                                                       // hub
		const g = [6, 3, 0][grip];                                                         // prong spread: open, half, shut
		for (const k of [-1, 1]) { const bx = cx + 1 + k * 4, ex = cx + 1 + k * (2 + g); f.line(bx, cy + 4, ex + k * 2, cy + 9, E.chrome); f.line(ex + k * 2, cy + 9, ex, cy + 13, E.chrome); f.line(bx + k, cy + 4, ex + k * 3, cy + 9, E.rim); }
		f.line(cx + 1, cy + 5, cx + 1, cy + 12, E.chrome);
		return f;
	};
	strips("claw_rig", clawRig, {
		idle: [{}, { sway: 1 }, { cy: 29 }, { sway: -1 }],
		hit: [{ sway: 3, lamp: RED.dim, grip: 1 }, { sway: 1 }],
		attack: [{ cy: 26, lamp: RED.hi }, { cy: 30, grip: 0 }, { cy: 33, grip: 1 }, { cy: 14, grip: 2, lamp: C.pureWhite }, { cy: 20, grip: 2 }, {}],
		die: [{ sag: 2, lamp: RED.dim, grip: 1 }, { sag: 6, cy: 34, lamp: RED.deep, sway: 2 }, { sag: 12, cy: 34, lamp: null, sway: 3, grip: 2 }],
	});

	// -- ticket_printer 48x48: a squat printer with a toothed slot mouth and a red display eye; a ticket tongue hangs from the mouth and piles in folds. --
	const ticketPrinter = ({ feed = 0, dy = 0, eyeC = RED.tube, shoot = 0, gape = 0 } = {}) => {
		const f = new Img(48, 48), y = 20 + dy, P = E.chromeHi;
		block(f, 5, 44, 6, 4); block(f, 29, 44, 6, 4);                                     // feet
		block(f, 2, y, 36, 26 - dy);                                                       // body
		f.rect(5, y + 5, 30, 3 + gape, C.base); for (let x = 6; x < 35; x += 3) f.px(x, y + 5, E.chrome);  // the slot mouth, teeth
		eye(f, 6, y + 12, 8, 3, eyeC);                                                     // display
		for (const x of [6, 10]) f.rect(x, y + 18, 2, 2, E.chrome);                        // buttons
		const ribbon = (y0, y1) => { f.rect(24, y0, 7, y1 - y0, P); for (let j = y1 - 4 + feed; j >= y0; j -= 4) f.hline(25, j, 5, E.chrome); };  // perforations scroll with feed
		for (const [i, x] of [[0, 30], [1, 33], [2, 29]]) { f.rect(x, 39 + i * 3, 15, 3, P); f.hline(x, 39 + i * 3, 15, E.chrome); f.px(x + (i & 1 ? 14 : 0), 40 + i * 3, E.rim); }  // folds on the floor
		if (shoot) ribbon(y + 6 - shoot, y + 6); else ribbon(y + 6 + gape, 45);
		return f;
	};
	strips("ticket_printer", ticketPrinter, {
		idle: [{}, { feed: 1 }, { feed: 2 }, { feed: 3 }],
		hit: [{ dy: 2, eyeC: RED.dim, gape: 1 }, { dy: 1 }],
		attack: [{ gape: 1, eyeC: RED.hi }, { gape: 2, feed: 2, dy: -1 }, { gape: 3, shoot: 10, eyeC: C.pureWhite, dy: -2 }, { gape: 3, shoot: 20, eyeC: C.pureWhite, dy: -2 }, { gape: 1, shoot: 6 }, {}],
		die: [{ gape: 3, eyeC: RED.dim }, { dy: 6, gape: 2, eyeC: RED.deep }, { dy: 12, gape: 1, eyeC: null }],
	});

	// -- bootleg_cabinet 48x48: an upright arcade cabinet, marquee on top, a cracked screen glowing red, a joystick deck. It spits a ball from the screen. --
	const bootleg = ({ scan = 0, scr = RED.ring, spit = 0, lean = 0, dy = 0, crack = 1 } = {}) => {
		const f = new Img(48, 48), x = 10 + lean, y = 2 + dy;
		block(f, x, y, 28, 6); f.hline(x + 3, y + 3, 22, scr === RED.ring ? RED.dim : scr);  // marquee
		block(f, x + 1, y + 6, 26, 40 - dy);                                               // cabinet
		f.rect(x + 4, y + 9, 20, 14, RED.deep); f.outline(x + 4, y + 9, 20, 14, E.rim);    // screen bezel
		f.rect(x + 5, y + 10, 18, 12, scr); f.hline(x + 5, y + 10 + scan, 18, scr === RED.ring ? RED.tube : C.pureWhite);
		if (crack) for (const [a, b] of [[[x + 9, y + 10], [x + 13, y + 16]], [[x + 13, y + 16], [x + 11, y + 22]], [[x + 13, y + 16], [x + 20, y + 13]]]) f.line(...a, ...b, C.base);
		block(f, x - 2, y + 26, 32, 6);                                                    // control deck
		f.rect(x + 5, y + 24, 1, 2, E.chrome); f.rect(x + 4, y + 23, 3, 2, RED.tube);       // joystick
		for (const bx of [x + 16, x + 20, x + 24]) f.px(bx, y + 28, E.chromeHi);
		f.rect(x + 11, y + 37, 6, 2, E.rim);                                               // coin door
		if (spit) { const by = y + 14 - spit * 6; f.rect(x + 12, by, 5, 5, RED.tube); f.outline(x + 12, by, 5, 5, RED.ring); f.px(x + 13, by + 1, RED.hi); f.corners(); }
		return f;
	};
	strips("bootleg_cabinet", bootleg, {
		idle: [{}, { scan: 4 }, { scan: 8 }, { scan: 11, scr: RED.dim }],
		hit: [{ lean: 2, scr: C.white, scan: 6 }, { lean: 1 }],
		attack: [{ scr: RED.tube, scan: 2 }, { scr: RED.tube, scan: 9 }, { scr: RED.hi, scan: 5, lean: -1 }, { scr: C.pureWhite, spit: 1, lean: 1 }, { spit: 2 }, {}],
		die: [{ scr: RED.dim, lean: 1 }, { scr: RED.deep, lean: 3, dy: 4, scan: 11 }, { scr: C.base, lean: 5, dy: 10, crack: 0, scan: 11 }],
	});
}

// Strip contract (docs/encounter-mechanics.md Enemies): name, frame width, frames. Height is always 48.
export const STRIPS = Object.entries(W).flatMap(([id, w]) => [[`${id}_idle`, w, 4], [`${id}_hit`, w, 6], [`${id}_attack`, w, 6], [`${id}_die`, w, 8]]);
