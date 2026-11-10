// Corp Tower regulars (docs/content/maps/corp-tower.md, Enemies): sentry_drone, camera_cluster, server_rack, auditor (48 wide), turnstile, intern_swarm, elevator (64 wide), all 48 tall.
// Strips per enemy: <id>_idle x4 @8 (loop), <id>_hit x6 @12, <id>_attack x6 @12 (the hazard spawns on frame 3, the release pose), <id>_die x8 @12 (ends blank).
// Feet on the bottom row, body centred, anchored bottom centre like parts/enemies.mjs; hovering ones (drone, swarm) put a shadow or the lead body on the bottom row.
// Look: kit() from parts/enemies.mjs (dark body, one lit red accent, flash and hot by recolour). Each enemy is one draw(params) fn; a table of params per strip builds the frames.
// mason is Corp Tower's too but exists in parts/enemies.mjs; elites and bosses live in parts/tower_bosses.mjs.
import { kit } from "./enemies.mjs";

const GROUP = "Enemies: Corp Tower";
const W = { sentry_drone: 48, turnstile: 64, camera_cluster: 48, server_rack: 48, intern_swarm: 64, auditor: 48, elevator: 64 };

export function emit({ Img, C, def, blank }) {
	const { E, RED, flash, hot, oval, block, eye, std, fade } = kit(C);
	// Thick limb: rim either side, fill down the middle (lobber's arm).
	const limb = (f, x0, y0, x1, y1) => { for (const [ox, oy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) f.line(x0 + ox, y0 + oy, x1 + ox, y1 + oy, E.rim); f.line(x0, y0, x1, y1, E.fill); };
	// One enemy from its draw fn and a params table: idle x4, hit recoil x2, attack x6, die x3 (then two fades and a blank).
	const enemy = (id, draw, { idle, hit, attack, die }) => {
		const B = draw({}), d = die.map(draw);
		def(GROUP, `${id}_idle`, 8, idle.map(draw));
		def(GROUP, `${id}_hit`, 12, std(B, hit.map(draw)));
		def(GROUP, `${id}_attack`, 12, attack.map(draw));
		def(GROUP, `${id}_die`, 12, [flash(B), hot(B), ...d, fade(d[2], 170), fade(d[2], 90), blank(B.w, 48)]);
	};

	// -- sentry_drone 48: a hovering saucer with a dome and one big red lens; a shadow marks the floor. Fires a laser straight down on attack. --
	enemy("sentry_drone", ({ dy = 0, lens = RED.tube, beam = false, crash = false } = {}) => {
		const f = new Img(48, 48), cy = 28 + dy;
		if (!crash) f.hline(18 + (dy < 0 ? 1 : 0), 47, 12 - (dy < 0 ? 2 : 0), E.rim);
		f.line(24, cy - 13, 24, cy - 10, E.chrome); f.px(24, cy - 14, E.chromeHi);   // antenna
		oval(f, 24, cy - 4, 9, 7);                                                    // dome
		oval(f, 24, cy, 20, 5);                                                       // disc
		for (const x of [7, 40]) f.rect(x, cy, 2, 1, E.chrome);
		if (beam) { f.rect(21, cy + 4, 6, 44, RED.tube); f.rect(23, cy + 4, 2, 44, C.pureWhite); }
		if (lens) { f.rect(20, cy - 6, 8, 4, lens); f.outline(20, cy - 6, 8, 4, lens === RED.tube || lens === RED.hi ? RED.ring : E.rim); if (lens === RED.tube) f.px(21, cy - 5, RED.hi); }
		if (crash) for (const [x, y] of [[20, cy - 9], [21, cy - 8], [26, cy - 7], [27, cy - 8]]) f.px(x, y, E.rim);
		return f;
	}, {
		idle: [{}, { dy: -1 }, { dy: -2 }, { dy: -1 }],
		hit: [{ dy: -4, lens: RED.dim }, { dy: -2 }],
		attack: [{ dy: 1 }, { dy: 2, lens: RED.hi }, { dy: 2, lens: C.pureWhite }, { dy: 2, lens: C.pureWhite, beam: true }, { dy: 1, lens: RED.hi }, {}],
		die: [{ dy: 3, lens: RED.dim }, { dy: 9, lens: RED.dim }, { dy: 14, lens: null, crash: true }],
	});

	// -- turnstile 64: a post on a floor plate with three gate arms on a hub, turning; a red stop light on top. Spins up and locks on attack. --
	enemy("turnstile", ({ ang = 0, light = RED.tube, sink = 0, slam = false } = {}) => {
		const f = new Img(64, 48), hx = 32, hy = 22 + sink;
		block(f, 26, 12 + sink, 12, 34);                                             // post
		for (let k = 0; k < 3; k++) { const t = (ang + 90 + k * 120) * Math.PI / 180, ex = Math.round(hx + 22 * Math.cos(t)), ey = Math.round(hy - 22 * Math.sin(t)); limb(f, hx, hy, ex, ey); f.rect(ex - 1, ey - 1, 3, 3, E.chrome); }
		f.rect(hx - 3, hy - 3, 6, 6, E.chrome); f.px(hx - 2, hy - 2, E.chromeHi);   // hub
		if (light) { f.rect(28, 7 + sink, 8, 6, E.rim); eye(f, 29, 8 + sink, 6, 4, light); }  // stop light, in front of the arms
		block(f, 14, 44, 36, 4);                                                     // floor plate, in front so the post sinks into it
		if (slam) for (const [x, y] of [[8, 46], [10, 43], [54, 43], [56, 46], [12, 41], [52, 41]]) f.px(x, y, E.chromeHi);
		return f;
	}, {
		idle: [{}, { ang: 30 }, { ang: 60 }, { ang: 90 }],
		hit: [{ ang: -25, light: RED.dim, sink: 1 }, { ang: -10 }],
		attack: [{ ang: 20 }, { ang: 70, light: RED.hi }, { ang: 140, light: RED.hi }, { ang: 180, light: C.pureWhite, slam: true }, { ang: 180, light: RED.hi }, { ang: 120 }],
		die: [{ ang: 15, light: RED.dim }, { ang: 35, light: RED.dim, sink: 8 }, { ang: 60, light: null, sink: 18 }],
	});

	// -- camera_cluster 48: three security cameras on stalks from one base box, red lenses that pan together. Flashes white on attack (blackout). --
	const CAMS = [[16, 11, 14], [24, 24, 5], [32, 37, 17]];  // stalk foot x, head x, head y
	enemy("camera_cluster", ({ look = 0, sway = 0, lens = RED.tube, rise = 0, droop = [0, 0, 0], glare = false } = {}) => {
		const f = new Img(48, 48);
		CAMS.forEach(([bx, hx, hy], i) => { const x = hx + sway * (i - 1 || 1) + Math.sign(hx - 24) * droop[i] / 2, y = hy - rise + droop[i]; limb(f, bx, 40, x, y); });
		CAMS.forEach(([, hx, hy], i) => {
			const x = hx + sway * (i - 1 || 1) + Math.sign(hx - 24) * droop[i] / 2, y = hy - rise + droop[i];
			block(f, x - 6, y - 4, 12, 8); f.rect(x - 7, y - 3, 1, 4, E.chrome);    // camera body, hood
			eye(f, x - 2 + look, y - 1, 4, 3, lens);
			if (glare) for (const [ox, oy] of [[-4, -6], [0, -7], [4, -6], [-7, 0], [7, 0]]) f.px(x + ox + look, y + oy, C.pureWhite);
		});
		block(f, 10, 38, 28, 10, true);
		return f;
	}, {
		idle: [{}, { look: 1, sway: 1 }, { look: 2 }, { look: 1, sway: -1 }],
		hit: [{ sway: -3, look: -2, lens: RED.dim }, { sway: -1 }],
		attack: [{ rise: 1 }, { rise: 2, lens: RED.hi }, { rise: 3, lens: RED.hi }, { rise: 3, lens: C.pureWhite, glare: true }, { rise: 1, lens: RED.hi }, {}],
		die: [{ lens: RED.dim, droop: [4, 0, 0] }, { lens: RED.dim, droop: [10, 6, 8] }, { lens: null, droop: [16, 20, 14] }],
	});

	// -- server_rack 48: a tall cabinet of six blinking units, one red status light. Every light goes red on attack (lockdown); it goes dark and sinks on death. --
	enemy("server_rack", ({ blink = 0, mode = "on", dx = 0, dy = 0 } = {}) => {
		const f = new Img(48, 48), x0 = 11 + dx;
		block(f, x0, 1 + dy, 26, 47); f.rect(x0 + 2, 46, 4, 2, E.rim); f.rect(x0 + 20, 46, 4, 2, E.rim);
		for (let u = 0; u < 6; u++) {
			const y = 4 + u * 7 + dy;
			f.outline(x0 + 2, y, 22, 6, E.rim);
			for (let j = 0; j < 3; j++) {
				const red = u === 2 && j === 0, on = (u * 2 + j + blink) % 3 === 0;
				const c = mode === "off" ? E.rim : mode === "red" ? RED.tube : mode === "white" ? C.pureWhite : red ? RED.tube : on ? E.chromeHi : E.chrome;
				f.rect(x0 + 4 + j * 3, y + 2, 2, 2, c);
			}
			for (let v = 0; v < 3; v++) f.hline(x0 + 14, y + 2 + v, 8, v & 1 ? E.fill : E.rim);  // vent
		}
		return f;
	}, {
		idle: [{}, { blink: 1 }, { blink: 2 }, { blink: 1 }],
		hit: [{ dx: 3, mode: "off" }, { dx: -1 }],
		attack: [{ blink: 1 }, { mode: "red" }, { blink: 2 }, { mode: "white", dy: -1 }, { mode: "red" }, {}],
		die: [{ mode: "red", dx: 1 }, { mode: "off", dy: 6 }, { mode: "off", dy: 18 }],
	});

	// -- intern_swarm 64: five small rotor drones in a V, point down, the lead on the floor. They pinch in then fan out and fire on attack. --
	const V = [[32, 43], [22, 33], [42, 33], [12, 23], [52, 23]];
	enemy("intern_swarm", ({ ph = 0, spread = 0, eyes = RED.tube, fire = false, fall = [0, 0, 0, 0, 0] } = {}) => {
		const f = new Img(64, 48);
		V.forEach(([vx, vy], i) => {
			const x = vx + Math.sign(vx - 32) * spread * (i > 2 ? 2 : 1), y = Math.min(vy + ((i + ph) & 1) - (i ? 0 : ph & 1) + fall[i], 44);
			const r = (i + ph) & 1 ? 5 : 3; f.hline(x - r, y - 5, r * 2, E.chrome); f.px(x, y - 4, E.chrome);   // rotor
			oval(f, x, y, 6, 4, false);
			eye(f, x - 1, y - 1, 3, 2, eyes);
			if (fire) { f.rect(x - 1, y + 5, 3, 3, RED.tube); f.px(x - 1, y + 5, RED.hi); }
		});
		return f;
	}, {
		idle: [{}, { ph: 1 }, { ph: 2 }, { ph: 3 }],
		hit: [{ spread: 3, eyes: RED.dim }, { spread: 1, ph: 1 }],
		attack: [{ spread: -1 }, { spread: -2, eyes: RED.hi, ph: 1 }, { spread: -3, eyes: RED.hi }, { spread: 3, eyes: C.pureWhite, fire: true, ph: 1 }, { spread: 2 }, { ph: 1 }],
		die: [{ eyes: RED.dim, fall: [0, 8, 0, 0, 14] }, { eyes: RED.dim, fall: [0, 12, 10, 21, 21] }, { eyes: null, fall: [0, 12, 12, 21, 21], spread: 2 }],
	});

	// -- auditor 48: a clipboard on two thin legs, a chrome clip with a red eye, a red pen in its hand. Strikes a red X on its sheet on attack. --
	enemy("auditor", ({ dy = 0, knee = 0, pen = 0, eyeC = RED.tube, mark = false, tilt = 0 } = {}) => {
		const f = new Img(48, 48), top = 6 + dy;
		for (const [x, s] of [[19, -1], [28, 1]]) { f.line(x, top + 30, x + s * knee, 41, E.rim); f.line(x + s * knee, 41, x, 46, E.rim); f.hline(x - 2 + (s > 0 ? 2 : 0), 47, 3, E.chrome); }
		block(f, 11 + tilt, top, 26, 31);                                       // board
		f.rect(14 + tilt, top + 4, 20, 25, E.hi);                               // sheet
		for (let r = 0; r < 5; r++) f.hline(16 + tilt, top + 8 + r * 4, r === 4 ? 10 : 16, E.rim);
		if (mark) for (let k = 0; k < 7; k++) { f.px(18 + k + tilt, top + 12 + k, RED.tube); f.px(24 - k + tilt, top + 12 + k, RED.tube); }
		block(f, 18 + tilt, top - 4, 12, 6, false, E.chrome); f.hline(20 + tilt, top - 3, 8, E.chromeHi);   // clip
		eye(f, 22 + tilt, top - 2, 4, 2, eyeC);
		const hx = 37 + tilt, hy = top + 16, px = 41 - pen * 3, py = top + 12 - pen * 4;
		limb(f, hx, hy, px, py);
		f.rect(px, py - 7, 2, 7, E.chrome); f.rect(px, py, 2, 2, RED.tube);     // pen, red tip
		return f;
	}, {
		idle: [{}, { pen: 1 }, {}, { dy: 1, knee: 1 }],
		hit: [{ tilt: -2, dy: 1, knee: 2, eyeC: RED.dim }, { tilt: -1 }],
		attack: [{ pen: -1 }, { pen: -2, eyeC: RED.hi }, { pen: -2, dy: -1, eyeC: RED.hi }, { pen: 3, dy: 1, knee: 2, mark: true, eyeC: C.pureWhite }, { pen: 1, mark: true }, { mark: true }],
		die: [{ knee: 3, dy: 2, eyeC: RED.dim }, { knee: 5, dy: 6, tilt: -3, eyeC: RED.dim }, { knee: 6, dy: 12, tilt: -6, eyeC: null }],
	});

	// -- elevator 64: a cab hung on a cable, doors slid open on a dark car with two red eyes inside, a floor light over the door. Doors shut then slam open on attack; the cable snaps and the cab drops out on death. --
	enemy("elevator", ({ open = 1, ind = RED.tube, eyes = RED.tube, dy = 0, snap = false, burst = false } = {}) => {
		const f = new Img(64, 48), y0 = 6 + dy;
		if (!snap) { f.rect(31, 0, 2, y0, E.chrome); f.px(31, 0, E.chromeHi); }
		block(f, 10, y0, 44, 42);
		f.rect(14, y0 + 7, 36, 34, burst ? RED.deep : C.base);                    // car interior
		eye(f, 26, y0 + 18, 3, 2, open > .3 ? eyes : null); eye(f, 35, y0 + 18, 3, 2, open > .3 ? eyes : null);
		const dw = Math.round(14 * (1 - open)) + 4;
		block(f, 14, y0 + 7, dw, 34); block(f, 50 - dw, y0 + 7, dw, 34);         // doors
		f.rect(28, y0 + 2, 8, 3, C.base); f.ascii(30, y0 + 2, [".##.", "####"], { "#": ind });   // floor light, up arrow
		f.hline(12, 46 + dy, 40, E.chrome);                                      // threshold
		if (burst) for (const [x, y] of [[6, 20], [4, 28], [6, 36], [57, 20], [59, 28], [57, 36]]) f.px(x, y + dy, E.chromeHi);
		return f;
	}, {
		idle: [{}, { ind: RED.dim }, {}, { ind: RED.dim, open: .9 }],
		hit: [{ open: .5, eyes: RED.dim, ind: RED.dim }, { open: .8 }],
		attack: [{ open: .6 }, { open: .2, ind: RED.hi }, { open: 0, ind: RED.hi }, { open: 1, ind: C.pureWhite, eyes: C.pureWhite, burst: true }, { open: 1, ind: RED.hi }, {}],
		die: [{ ind: RED.dim, eyes: RED.dim, snap: true }, { snap: true, dy: 8, eyes: RED.dim, ind: null }, { snap: true, dy: 26, eyes: null, ind: null }],
	});
}

// Strip contract (docs/content/maps/corp-tower.md Enemies): name, frame width, frames. Height is always 48.
export const STRIPS = Object.entries(W).flatMap(([id, w]) => [[`${id}_idle`, w, 4], [`${id}_hit`, w, 6], [`${id}_attack`, w, 6], [`${id}_die`, w, 8]]);
