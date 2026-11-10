// Mock screens for the Peglin direction (docs/content.md "Screens"): map, fight, reward, shop, run over.
// Reference images for the code agents, drawn at 640x360 sprite px and saved 2x to assets/pixel/preview/ui_<name>.png.
// gen.mjs exports nothing, so the caller hands its helpers in: emit({ Img, C, SETS, A, ANIM, text, textW, nine, lit, dim, hot, ellipse, ring, chassis, col, btn, centreText, toPng }).
// Call it after toPng is defined. Sprites that other pools own (cards, node icons, relics, intents, enemies, faces) are
// drawn here as placeholders so the mocks read; they are never written as game assets.
// ponytail: the shop mock overwrites the old ui_shop.png (upgrade web), which the redirect cuts. Rename the key if both must stay.

const RX = 562, FX = 80; // right column origin, field origin (field is FX..FX+480)
const RED = { tube: "ff0000", ring: "a30000", deep: "3a0000", hi: "ff8a8a", dimTube: "7f0000", dimRing: "3a0000" };
const BAG = [["NEEDLE", "pierce", 1], ["PEBBLE", "basic", 1], ["PEBBLE", "basic", 2], ["BOULDER", "heavy", 1], ["PEBBLE", "basic", 1], ["PEBBLE", "basic", 3]];
const RELICS = ["wide_paddle", "toll", "shield_floor"];
const NODE_SETS = { fight: "mag", elite: "red", treasure: "vio", shop: "gold", event: "trim", boss: "red" };

export function mocks(h) {
	const { Img, C, SETS, A, ANIM, text, textW, nine, lit, dim, hot, ellipse, ring, chassis, col, btn, centreText } = h;
	const S = { ...SETS, red: RED, trim: { tube: C.rivet, ring: C.trim, deep: C.trimLo, hi: C.chromeMid, dimTube: C.trim, dimRing: C.trimLo } };
	const bar = (m, x, y, w, hh, frac) => { m.rect(x, y, w, hh, C.trimLo); m.rect(x, y, Math.round(w * frac), hh, C.danger); };

	// -- placeholders for other pools' sprites --
	const FACE = { basic: A.ball, heavy: ellipse(12, 12), pierce: ellipse(6, 6), junk: ellipse(8, 8, C.trimHi, C.rivet) };
	const card = (face, state = "lit", scale = 2) => { const b = ({ lit, hot, dim })[state](S.vio, 36, 48); b.blit(face, 18 - face.w * scale / 2, 20 - face.h * scale / 2, scale); return b; };
	const glyph12 = (set, rows, c = C.white, n = 12) => { const b = lit(set, n, n); b.ascii((n - rows[0].length) >> 1, 3 + ((n - 5 - rows.length) >> 1), rows, { "#": c }); return b; };
	const NODE = {
		fight: glyph12(S.mag, ["######", "#....#", "######"]), elite: glyph12(S.red, ["#.##.#", "######", "#.##.#"]),
		treasure: glyph12(S.vio, [".####.", "######", "#.##.#", "######"], S.gold.tube), shop: glyph12(S.gold, [".#.", "###", "##.", ".##", "###"]),
		event: glyph12(S.trim, ["###", "..#", ".##", "...", ".#."]), boss: glyph12(S.red, [".#####.", "#######", "#.###.#", "#######", ".#.#.#.", ".#####."], C.white, 16),
	};
	const relic = (rows) => { const b = new Img(12, 12); b.ascii((12 - rows[0].length) >> 1, (12 - rows.length) >> 1, rows, { "#": C.white }); return b; };
	const RELIC = { wide_paddle: relic(["#......#", "########", "#......#"]), toll: relic([".#.", "###", "##.", ".##", "###"]), shield_floor: relic([".#####.", "#.....#", ".......", "##.##.##"]) };
	const intent = (rows) => { const b = new Img(12, 12); b.rect(0, 0, 12, 12, C.base); b.outline(0, 0, 12, 12, RED.dimTube); b.corners(); b.ascii((12 - rows[0].length) >> 1, (12 - rows.length) >> 1, rows, { "#": C.danger }); return b; };
	const INTENT = { debris: intent(["##..##", "##..##", "......", "..##..", "..##.."]), red_bricks: intent(["######", "#....#", "######"]), enemy_balls: intent([".##...", ".##.##", "....##", "##....", "##..##"]) };
	const glob = (() => { // dark blob, red eyes: the one non-lamp style (docs/art-style.md)
		const b = new Img(48, 48), f = (x, y, r) => ((x + .5 - 24) / (20 - r)) ** 2 + ((y + .5 - 31) / (16 - r)) ** 2 <= 1;
		for (let y = 0; y < 48; y++) for (let x = 0; x < 48; x++) { if (f(x, y, 0)) b.px(x, y, C.trim); if (f(x, y, 1.5)) b.px(x, y, C.trimLo); }
		for (const [x, y, hh] of [[10, 10, 6], [22, 6, 10], [34, 12, 4]]) { b.rect(x, y, 4, hh, C.trimLo); b.outline(x, y, 4, hh, C.trim); }
		for (const x of [14, 28]) { b.rect(x, 26, 5, 3, C.danger); b.px(x + 1, 26, RED.hi); }
		b.hline(18, 36, 12, RED.ring); for (const x of [20, 24, 28]) b.px(x, 37, C.danger);
		return b;
	})();
	const uiHp = (() => { const b = new Img(8, 8); b.ascii(0, 0, [".##..##.", "########", "########", "########", ".######.", "..####..", "...##...", "........"], { "#": C.danger }); b.px(2, 1, RED.hi); return b; })();
	const uiNext = (() => { const b = new Img(4, 5); b.ascii(0, 0, ["#...", "##..", "###.", "##..", "#..."], { "#": C.white }); return b; })();
	const tag = (n) => { const b = new Img(25, 8); b.rect(0, 0, 25, 8, C.pay); b.outline(0, 0, 25, 8, C.cream); b.corners(); text(b, 12 - (textW(n) >> 1), 2, n, C.base); return b; };
	const ringPulse = () => { const b = new Img(16, 16); ring(b, 7.5, 7.5, 7, C.white, 1, 1); return b; };

	// -- run columns: left YOU, right BAG --
	const you = (m, { hp, gold, lines = [] }) => {
		col(m, 0, "YOU");
		m.blit(uiHp, 6, 22); text(m, 16, 23, `HP ${hp}/50`, C.cream); bar(m, 6, 32, 68, 3, hp / 50);
		m.blit(A.coin, 6, 40); text(m, 16, 41, "GOLD", C.rivet); text(m, 6, 50, String(gold), C.pay, 2);
		RELICS.forEach((id, i) => m.blit(RELIC[id], 6 + i * 13, 64));
		let y = 84; for (const [s, c, k = 1] of lines) { text(m, 6, y, s, c, k); y += 5 * k + 3; }
		return y;
	};
	const bag = (m, balls, { head = false, spent, leave } = {}) => {
		col(m, RX, `BAG ${balls.length}`);
		balls.forEach(([name, id, rank], i) => {
			const y = 22 + i * 12, f = FACE[id]; m.blit(f, RX + 6 + 4 - (f.w >> 1), y + 4 - (f.h >> 1));
			text(m, RX + 18, y + 1, name, C.white); for (let p = 0; p < 3; p++) m.blit(p < rank ? A.ui_pip_pay : A.ui_pip_off, RX + 56 + p * 5, y + 2);
			if (head && !i) m.blit(uiNext, RX + 1, y + 1);
		});
		if (spent != null) text(m, RX + 6, 24 + balls.length * 12, `SPENT ${spent}`, C.rivet);
		if (head) { btn(m, RX + 6, 300, 66, 24, "ui_button_chrome", "DISCARD"); text(m, RX + 39 - (textW("D DISCARD") >> 1), 328, "D DISCARD", C.rivet); }
		if (leave) btn(m, RX + 6, 300, 66, 24, "ui_button_mint", "LEAVE");
	};
	const priced = (m, cx, y, n, c = C.pay) => { const w = textW(String(n)) + 10; m.blit(A.coin, cx - (w >> 1), y); text(m, cx - (w >> 1) + 10, y + 1, String(n), c); };

	const M = {};
	M.map = (() => {
		const m = chassis();
		const y = you(m, { hp: 38, gold: 47 }); text(m, 6, 120, "LEGEND", C.rivet);
		Object.keys(NODE).forEach((k, i) => { const n = NODE[k]; m.blit(n, 6 + 6 - (n.w >> 1), 130 + i * 12 + 6 - (n.h >> 1)); text(m, 22, 134 + i * 12, k.toUpperCase(), C.white); });
		bag(m, BAG);
		centreText(m, 6, "MAP", C.rivet, 1); centreText(m, 14, "NODE 2/5", C.cream, 1);
		const layers = [["fight", "fight"], ["event", "fight", "treasure"], ["elite", "fight"], ["shop"], ["boss"]];
		const at = (l, s) => [FX + 60 + 90 * l, [[180], [120, 240], [90, 180, 270]][layers[l].length - 1][s]];
		const edges = [[0, 0, 1, 0], [0, 0, 1, 1], [0, 1, 1, 1], [0, 1, 1, 2], [1, 0, 2, 0], [1, 0, 2, 1], [1, 1, 2, 0], [1, 1, 2, 1], [1, 2, 2, 0], [1, 2, 2, 1], [2, 0, 3, 0], [2, 1, 3, 0], [3, 0, 4, 0]];
		for (const [l0, s0, l1, s1] of edges) { const [x0, y0] = at(l0, s0), [x1, y1] = at(l1, s1); m.line(x0, y0, x1, y1, l0 === 0 && s0 === 0 && s1 === 1 ? C.pay : C.trimHi); }
		const state = (l, s) => (l === 0 && s === 0) ? "visited" : (l === 1 && s === 1) ? "here" : l === 2 ? "reach" : "far";
		layers.forEach((ks, l) => ks.forEach((k, s) => {
			const [x, y] = at(l, s), n = NODE[k], st = state(l, s);
			if (st === "reach") m.blit(ringPulse(), x - 8, y - 8);
			m.blit(st === "visited" ? n.fade(128) : st === "far" ? n.fade(90) : n, x - (n.w >> 1), y - (n.h >> 1));
			if (st === "here") m.blit(A.ball, x - 4, y - 16);
		}));
		const [hx, hy] = at(2, 1); m.blit(A.ui_cursor, hx + 5, hy + 4);
		return m;
	})();
	M.fight = (() => {
		const m = chassis();
		you(m, { hp: 38, gold: 47, lines: [["PHASE 3", C.white], ["DAMAGE", C.rivet], ["27", C.pay, 3], ["IN PLAY 1", C.cream], ["NEXT: NEEDLE", C.cream], ["RED BRICKS 2", C.cream]] });
		bag(m, BAG.slice(0, 4), { head: true, spent: 2 });
		// ponytail: content.md puts the intent at field x 330, under a 19 px "22/30" starting at 324; drawn 16 px right so the mock shows no overlap
		bar(m, FX + 160, 2, 160, 4, 22 / 30); text(m, FX + 324, 2, "22/30", C.cream); m.blit(INTENT.debris, FX + 346, 2); text(m, FX + 362, 0, "3", C.pay, 2);
		text(m, FX + 160, 8, "GLOB", C.rivet);
		m.blit(glob, FX + 240 - 24, 54 - 48);
		m.hline(FX, 56, 480, C.rivet); m.hline(FX, 57, 480, C.trimHi);
		const bomb = lit(S.ora); bomb.ascii(13, 3, ["..#", ".#.", "###", "###", ".#."], { "#": C.pay });
		const crit = lit(S.blue); crit.ascii(12, 4, [".#...#", "#.#.#.", ".#.#..", "...#.."], { "#": C.white });
		const refresh = lit(S.mint); refresh.ascii(12, 3, ["..#..", "#.#.#", ".###.", "..#..", "..#.."], { "#": C.white });
		const red = lit(S.red);
		const faces = { p: A.brick_plain_lit, s: A.brick_solid, b: bomb, c: crit, f: refresh, r: red };
		const board = ["ppcprpp.ppp", "p.ppsppprpc", "fppp.pppppp", "pp.rpbppspp", "ppppp..pccp", ".pppp...pp."];
		board.forEach((row, r) => [...row].forEach((k, c) => { if (faces[k]) m.blit(faces[k], FX + 64 + c * 32 + 1, 84 + r * 14 + 1); }));
		for (let i = 1; i <= 4; i++) m.rect(318 - i * 6, 232 + i * 7, 2, 2, C.pay, 160 - i * 35);
		m.blit(A.ball, 315, 228); m.blit(tag("12"), 310, 214);
		for (const [x, y] of [[440, 120], [444, 128]]) { m.rect(x, y, 8, 8, RED.ring); m.outline(x, y, 8, 8, C.danger); }
		m.blit(A.paddle, 290, 336);
		return m;
	})();
	M.reward = (() => {
		const m = M.fight.crop(0, 0, 640, 360); m.rect(0, 0, 640, 360, C.base, 150);
		m.blit(nine(A.ui_panel, 320, 180), 160, 70);
		centreText(m, 78, "VICTORY", C.pay); centreText(m, 94, "PICK ONE", C.rivet, 1);
		m.blit(A.coin, 420, 76); text(m, 430, 77, "+15 GOLD", C.pay);
		const cards = [[card(FACE.heavy), "BOULDER", ["BALL", "DMG 3"]], [card(FACE.basic, "hot"), "PEBBLE", ["RANK UP", "DMG 1 TO 2"]], [card(RELIC.toll), "TOLL", ["RELIC", "1 GOLD PER", "10 BRICKS"]]];
		cards.forEach(([c, name, desc], i) => {
			const cx = 240 + i * 80; m.blit(c, cx - 18, 108);
			text(m, cx - (textW(name) >> 1), 160, name, C.white); desc.forEach((s, j) => text(m, cx - (textW(s) >> 1), 170 + j * 8, s, C.rivet));
		});
		m.blit(A.ui_badge, 332, 106); text(m, 333, 107, "UP", C.base); m.blit(A.ui_cursor, 328, 136);
		btn(m, 272, 224, 96, 20, "ui_button_chrome", "SKIP");
		return m;
	})();
	M.shop = (() => {
		const m = chassis(); you(m, { hp: 38, gold: 47 }); bag(m, BAG, { leave: true });
		centreText(m, 6, "SHOP", C.rivet, 1); centreText(m, 16, "PEDDLER", C.pay);
		[[90, FACE.basic, "PEBBLE", "lit"], [170, FACE.heavy, "BOULDER", "hot"], [250, FACE.pierce, "NEEDLE", "lit"]].forEach(([x, f, name, st]) => { m.blit(card(f, st), FX + x - 18, 40); text(m, FX + x - (textW(name) >> 1), 92, name, C.white); priced(m, FX + x, 100, 15); });
		[[370, RELIC.wide_paddle, "WIDE PADDLE", 40], [450, RELIC.shield_floor, "SHIELD FLOOR", 60]].forEach(([x, f, name, p]) => { m.blit(card(f), FX + x - 18, 40); text(m, FX + x - (textW(name) >> 1), 92, name, C.white); priced(m, FX + x, 100, p, p > 47 ? C.payDim : C.pay); });
		m.blit(A.ui_cursor, FX + 176, 64);
		m.hline(FX + 6, 150, 468, C.rivet);
		text(m, FX + 10, 165, "REMOVE A BALL", C.white); priced(m, FX + 300, 164, 12); btn(m, FX + 344, 160, 96, 18, "ui_button_chrome", "REMOVE", 1);
		text(m, FX + 10, 189, "HEAL +20 HP", C.white); priced(m, FX + 300, 188, 20); btn(m, FX + 344, 184, 96, 18, "ui_button_chrome", "HEAL", 1);
		centreText(m, 210, "BOULDER: DMG 3, BIG AND SLOW", C.rivet, 1);
		return m;
	})();
	M.run_over = (() => {
		const m = chassis();
		centreText(m, 40, "RUN OVER", C.white, 4); m.rect(320 - (textW("RUN OVER", 4) >> 1), 62, textW("RUN OVER", 4), 1, C.danger);
		centreText(m, 70, "SLAIN BY GLOB AT NODE 3/5", C.cream, 1);
		text(m, 180, 92, "STATS", C.rivet);
		[["FIGHTS WON", "2"], ["DAMAGE DEALT", "96"], ["BRICKS BROKEN", "141"], ["BIGGEST SHOT", "23"], ["BALLS DROPPED", "9"], ["GOLD EARNED", "47"], ["TIME", "4:12"]].forEach(([k, v], i) => { text(m, 180, 102 + i * 10, k, C.rivet); text(m, 300 - textW(v), 102 + i * 10, v, C.cream); });
		text(m, 340, 92, "BAG", C.rivet); BAG.forEach(([name, id], i) => { const f = FACE[id]; m.blit(f, 344 - (f.w >> 1), 110 + i * 12 + 4 - (f.h >> 1)); text(m, 352, 111 + i * 12, name, C.white); });
		text(m, 440, 92, "RELICS", C.rivet); RELICS.forEach((id, i) => { m.blit(RELIC[id], 440, 102 + i * 14); text(m, 456, 105 + i * 14, id.replace("_", " ").toUpperCase(), C.white); });
		centreText(m, 180, "UNLOCKED: BLASTER", C.bump, 1);
		btn(m, 214, 220, 96, 20, "ui_button_mint", "NEW RUN"); btn(m, 330, 220, 96, 20, "ui_button_chrome", "MENU");
		return m;
	})();
	return M;
}

export function emit(h, dir = "assets/pixel/preview") {
	const M = mocks(h);
	for (const [n, img] of Object.entries(M)) h.toPng(img, `${dir}/ui_${n}.png`, 2);
	return M;
}
