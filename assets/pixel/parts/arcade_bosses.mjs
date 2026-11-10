// Back Alley Arcade's elites and boss (docs/content/maps/back-alley-arcade.md): repo_man, arcade_bouncer, jackpot_reel (64x48, elites,
// chrome-rimmed like warden) and attract_mode (160x48, the boss). All 48 tall, feet on the bottom row, anchored bottom centre.
// Strips per enemy: <id>_idle x4 @8 (loop), <id>_hit x6 @12, <id>_attack x6 @12 (the hazard spawns on frame 3, the release pose), <id>_die x8 @12 (ends blank).
// Look: parts/enemies.mjs kit (dark body, one lit red accent, flash/hot by recolour). attract_mode's half-HP trait copy is a ball change, so no extra strip.
import { kit } from "./enemies.mjs";

const GROUP = "Elites and bosses: Back Alley Arcade";

// ponytail: gen.mjs fills FONT's letters after the parts run, so `text` only has C, M, O by then; the other letters the marquee needs live here.
const LETTERS = { A: [".#.", "#.#", "###", "#.#", "#.#"], D: ["##.", "#.#", "#.#", "#.#", "##."], E: ["###", "#..", "###", "#..", "###"], I: ["###", ".#.", ".#.", ".#.", "###"],
	N: ["##.", "#.#", "#.#", "#.#", "#.#"], R: ["###", "#.#", "##.", "#.#", "#.#"], S: ["###", "#..", "###", "..#", "###"], T: ["###", ".#.", ".#.", ".#.", ".#."] };

export function emit({ Img, C, def, frame, blank, text }) {
	const { E, RED, flash, hot, oval, block, eye, std } = kit(C);
	const say = (f, x, y, s, c) => [...s].forEach((ch, i) => LETTERS[ch] ? f.ascii(x + i * 4, y, LETTERS[ch], { "#": c }) : text(f, x + i * 4, y, ch, c));
	const at = (img, dx, dy, a) => frame(img.w, img.h, [img, dx, dy, a]);  // shift a pose, optionally faded
	// die: flash, hot, a dimmed pose, then it sinks and fades out.
	const die = (B, D) => [flash(B), hot(B), D, at(D, 0, 3), at(D, 0, 7), at(D, 0, 10, 170), at(D, 0, 13, 90), blank(B.w, 48)];
	const R = E.chrome;  // elite rim

	// -- repo_man 64x48: a hatted heavy in a long coat, a loot sack on his shoulder and a tow hook swinging on a chain. Red eyes under the brim. --
	const repo = ({ ang = 0, dy = 0, eyes = RED.tube, sack = 0, hookC = E.chromeHi } = {}) => {
		const f = new Img(64, 48);
		block(f, 22, 43, 8, 5, false, R); block(f, 34, 43, 8, 5, false, R);                 // boots
		oval(f, 15, 15 + sack + dy, 10, 10); f.rect(20, 6 + sack + dy, 3, 3, R);             // sack, tied neck
		block(f, 19, 18 + dy, 26, 26, false, R); f.rect(31, 20 + dy, 2, 23, R);              // coat, seam
		block(f, 17, 16 + dy, 8, 8, false, R);                                               // arm up to the sack
		block(f, 26, 9 + dy, 12, 9, false, R);                                               // head
		block(f, 27, 1 + dy, 10, 7, false, R); f.rect(21, 7 + dy, 22, 2, R);                 // hat crown, brim
		eye(f, 28, 11 + dy, 3, 2, eyes); eye(f, 33, 11 + dy, 3, 2, eyes);
		const t = ang * Math.PI / 180, hx = 46, hy = 28 + dy, ex = Math.round(hx + 14 * Math.sin(t)), ey = Math.round(hy + 14 * Math.cos(t));
		block(f, 43, 18 + dy, 6, 12, false, R);                                              // hook arm
		for (let i = 0; i <= 7; i++) f.px(Math.round(hx + (ex - hx) * i / 7), Math.round(hy + (ey - hy) * i / 7), i & 1 ? E.chrome : E.chromeHi);  // chain
		f.ascii(ex - 2, ey - 1, [".#..", ".#..", "##.#", ".##."], { "#": hookC });           // the hook
		return f;
	};
	const P0 = repo();
	def(GROUP, "repo_man_idle", 8, [P0, repo({ ang: 10, sack: 1 }), repo({ ang: 14 }), repo({ ang: 6, sack: 1 })]);
	def(GROUP, "repo_man_hit", 12, std(P0, [at(repo({ ang: -20, sack: -2, eyes: RED.dim }), 2, 0), at(repo({ ang: -10, sack: -1 }), 1, 0)]));
	def(GROUP, "repo_man_attack", 12, [repo({ ang: -30 }), repo({ ang: 60, dy: -1 }), repo({ ang: 130, dy: -1, hookC: RED.hi }), repo({ ang: 175, dy: -2, hookC: RED.tube, eyes: RED.hi }), repo({ ang: 90 }), repo({ ang: 20 })]);
	def(GROUP, "repo_man_die", 12, die(P0, repo({ ang: -40, sack: 4, eyes: RED.dim, hookC: E.chrome })));

	// -- arcade_bouncer 64x48: a slab of a doorman, shoulders twice his head, red shades. Arms folded at rest; raises and slams both fists to attack. --
	const bouncer = ({ arms = "fold", dy = 0, shades = RED.tube, glint = 0, spark = false } = {}) => {
		const f = new Img(64, 48);
		block(f, 21, 38, 9, 10, false, R); block(f, 34, 38, 9, 10, false, R);              // legs
		block(f, 17, 24 + dy, 30, 15, false, R);                                            // waist
		block(f, 8, 13 + dy, 48, 12, false, R);                                             // shoulders
		block(f, 28, 10 + dy, 8, 4, false, R); block(f, 26, 1 + dy, 12, 11, false, R);      // neck, head
		if (shades) { f.rect(27, 5 + dy, 10, 2, shades); if (shades === RED.tube) f.rect(28 + glint * 3, 5 + dy, 2, 1, RED.hi); }
		if (arms === "fold") { block(f, 12, 22 + dy, 40, 7, false, R); f.rect(31, 23 + dy, 2, 5, R); }
		if (arms === "up") { block(f, 4, 0 + dy, 9, 14, false, R); block(f, 51, 0 + dy, 9, 14, false, R); block(f, 3, 0 + dy, 11, 6, false, R); block(f, 50, 0 + dy, 11, 6, false, R); }
		if (arms === "slam") { block(f, 4, 22, 9, 16, false, R); block(f, 51, 22, 9, 16, false, R); block(f, 2, 37, 13, 8, false, R); block(f, 49, 37, 13, 8, false, R); }
		if (spark) for (const cx of [8, 55]) for (const [x, y] of [[-4, 0], [4, 0], [-3, -3], [3, -3], [0, -5]]) f.px(cx + x, 37 + y, x ? RED.hi : C.pureWhite);
		return f;
	};
	const B0 = bouncer();
	def(GROUP, "arcade_bouncer_idle", 8, [B0, bouncer({ dy: 1, glint: 1 }), bouncer({ glint: 2 }), bouncer({ dy: 1, glint: 1 })]);
	def(GROUP, "arcade_bouncer_hit", 12, std(B0, [at(bouncer({ dy: 1, shades: RED.dim }), 2, 0), at(B0, 1, 0)]));
	def(GROUP, "arcade_bouncer_attack", 12, [bouncer({ dy: 1 }), bouncer({ arms: "up" }), bouncer({ arms: "up", dy: -1, shades: RED.hi }), bouncer({ arms: "slam", dy: 2, spark: true, shades: RED.hi }), bouncer({ arms: "slam", dy: 1 }), B0]);
	def(GROUP, "arcade_bouncer_die", 12, die(B0, bouncer({ arms: "slam", dy: 2, shades: RED.dim })));

	// -- jackpot_reel 64x48: a one-armed bandit. Domed top with chase lights, three reels in a window, the lever on the right. Red sevens. --
	const SYM = [["###", "..#", ".#.", ".#."], ["###", "...", "###", "..."], [".#.", "###", ".#.", "..."]];  // seven, bar, star; 4 rows on a 6-row pitch
	const reel = (o, lit) => { const s = new Img(7, 24); for (let k = 0; k < 4; k++) s.ascii(2, k * 6 + 1, SYM[k % 3], { "#": k % 3 ? E.chrome : lit }); return s.crop(0, o, 7, 11); };
	const jackpot = ({ reels = [0, 6, 12], lever = 0, lights = 0, dx = 0, seven = RED.tube } = {}) => {
		const f = new Img(64, 48);
		block(f, 10 + dx, 42, 40, 6, false, R);                                              // plinth
		oval(f, 30 + dx, 12, 18, 9); block(f, 12 + dx, 12, 36, 31, false, R); f.rect(13 + dx, 12, 34, 1, E.fill);  // dome, cabinet
		for (let i = 0; i < 7; i++) f.px(17 + dx + i * 4, i === 0 || i === 6 ? 9 : 5 - (i === 3) + (i === 1 || i === 5) * 1, (i + lights) % 2 ? E.chromeHi : RED.dim);  // chase lights round the dome
		f.rect(15 + dx, 17, 30, 13, C.base); f.outline(14 + dx, 16, 32, 15, R);             // reel window
		reels.forEach((o, i) => { f.blit(reel(o, seven), 15 + dx + i * 10, 18); if (i) f.rect(14 + dx + i * 10, 17, 1, 13, E.rim); });
		f.rect(16 + dx, 34, 28, 2, E.rim); f.rect(26 + dx, 38, 8, 2, E.rim);                 // payout slot, coin tray
		const ly = [10, 18, 28][lever];                                                       // lever knob y
		block(f, 48 + dx, 26, 5, 6, false, R); f.rect(54 + dx, Math.min(ly, 28), 2, Math.abs(28 - ly) + 1, E.chrome);
		f.rect(52 + dx, ly - 3, 6, 5, RED.tube); f.outline(52 + dx, ly - 3, 6, 5, RED.ring); f.px(53 + dx, ly - 2, RED.hi);  // knob
		return f;
	};
	const J0 = jackpot();
	def(GROUP, "jackpot_reel_idle", 8, [J0, jackpot({ lights: 1 }), J0, jackpot({ lights: 1 })]);
	def(GROUP, "jackpot_reel_hit", 12, std(J0, [jackpot({ reels: [2, 8, 14], dx: 2, seven: RED.dim }), jackpot({ reels: [1, 7, 13], dx: 1 })]));
	def(GROUP, "jackpot_reel_attack", 12, [jackpot({ lever: 1 }), jackpot({ lever: 2, reels: [4, 9, 2] }), jackpot({ lever: 2, reels: [9, 3, 7], lights: 1 }), jackpot({ lever: 1, reels: [0, 0, 0], seven: RED.hi, lights: 1 }), jackpot({ reels: [0, 0, 0], lights: 0 }), J0]);
	def(GROUP, "jackpot_reel_die", 12, die(J0, jackpot({ reels: [3, 10, 5], lever: 2, seven: RED.dim })));

	// -- attract_mode 160x48, the boss: a wide two-player cabinet playing breakout to itself. Marquee, screen, a joystick each side.
	// The screen is the face: a demo game (bricks, paddle, red ball) with INSERT COIN blinking; on death the CRT collapses to a line, then a dot. --
	const DEMO = [[44, 26], [62, 20], [80, 14], [98, 20]];  // ball positions per idle frame
	const attract = ({ t = 0, scr = "demo", dy = 0, stick = 0, mark = RED.ring } = {}) => {
		const f = new Img(160, 48);
		block(f, 14, 42, 132, 6);                                                            // base
		block(f, 4, 34 + dy, 152, 8);                                                        // control deck
		for (const [x, s] of [[24, -stick], [134, stick]]) { f.line(x, 33 + dy, x + s, 28 + dy, E.chrome); f.rect(x + s - 1, 26 + dy, 3, 3, RED.tube); f.px(x + s - 1, 26 + dy, RED.hi); for (const b of [8, 13]) f.rect(x + (x < 80 ? b : -b - 2), 36 + dy, 3, 2, E.chrome); }  // sticks, buttons
		block(f, 26, 8 + dy, 108, 27);                                                       // cabinet
		for (let y = 13; y < 32; y += 3) { f.hline(28, y + dy, 4, E.rim); f.hline(128, y + dy, 4, E.rim); }  // speaker grilles
		block(f, 36, 0 + dy, 88, 9); say(f, 56, 2 + dy, "ATTRACT MODE", mark);              // marquee
		const sx = 34, sy = 11 + dy, sw = 92, sh = 21;
		f.rect(sx, sy, sw, sh, C.base); f.outline(sx - 1, sy - 1, sw + 2, sh + 2, E.chrome);
		const scrn = { demo: () => {
			for (let x = sx + 3; x < sx + sw - 4; x += 6) f.rect(x, sy + 2, 5, 2, (x >> 1) % 3 && t !== (x % 4) ? RED.dim : RED.ring);  // bricks
			const [bx, by] = DEMO[t]; f.rect(bx + sx - 34, by + sy - 11, 2, 2, RED.hi);
			f.rect(Math.min(sx + sw - 13, bx + sx - 38), sy + sh - 2, 10, 1, E.chromeHi);    // paddle follows the ball
			if (t < 2) say(f, sx + 24, sy + 9, "INSERT COIN", RED.tube);
		}, flash: () => f.rect(sx, sy, sw, sh, RED.ring), burst: () => { f.rect(sx, sy, sw, sh, RED.hi); f.rect(sx + 4, sy + 3, sw - 8, sh - 6, C.pureWhite); },
		noise: () => { for (let i = 0; i < 140; i++) f.px(sx + (i * 37) % sw, sy + (i * 17) % sh, i % 3 ? RED.dim : E.chrome); },
		line: () => f.hline(sx + 6, sy + 10, sw - 12, C.pureWhite), dot: () => f.rect(sx + 45, sy + 10, 2, 1, C.pureWhite), off: () => {} };
		scrn[scr]();
		if (scr === "burst") for (const [x, y] of [[sx - 8, sy - 2], [sx + sw + 4, sy - 2], [sx + 10, sy + sh + 3], [sx + sw - 14, sy + sh + 3], [sx + sw / 2 - 2, sy + sh + 4]]) { f.rect(x, y, 4, 4, RED.tube); f.px(x, y, RED.hi); f.outline(x, y, 4, 4, RED.ring); f.px(x, y, RED.hi); }  // balls spat out
		return f;
	};
	const A0 = attract();
	def(GROUP, "attract_mode_idle", 8, [A0, attract({ t: 1, stick: 2 }), attract({ t: 2 }), attract({ t: 3, stick: -2 })]);
	def(GROUP, "attract_mode_hit", 12, std(A0, [at(attract({ scr: "noise", dy: 1 }), 2, 0), at(attract({ t: 1 }), -1, 0)]));
	def(GROUP, "attract_mode_attack", 12, [attract({ scr: "noise", stick: 3 }), attract({ scr: "flash", stick: -3, mark: RED.tube }), attract({ scr: "flash", dy: -1, mark: RED.hi }), attract({ scr: "burst", dy: -1, mark: RED.hi }), attract({ scr: "noise" }), A0]);
	const off = attract({ scr: "off", mark: RED.deep });
	def(GROUP, "attract_mode_die", 12, [flash(A0), hot(A0), attract({ scr: "line", mark: RED.dim }), attract({ scr: "dot", mark: RED.deep }), at(off, 0, 3), at(off, 0, 7, 200), at(off, 0, 11, 110), blank(160, 48)]);
}

// Strip contract: name, frame width, frames. Height is always 48.
export const STRIPS = [["repo_man", 64], ["arcade_bouncer", 64], ["jackpot_reel", 64], ["attract_mode", 160]].flatMap(([id, w]) => [[`${id}_idle`, w, 4], [`${id}_hit`, w, 6], [`${id}_attack`, w, 6], [`${id}_die`, w, 8]]);
