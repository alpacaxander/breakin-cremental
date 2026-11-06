// Pixel-art asset set on a 2x canvas (640x360 game view; a 60x24 brick is 30x12 px).
// Generates assets/pixel/png/*.png at native size, look.png mockup (shown 2x), assets.html demo.
// Run: node assets/pixel/gen.mjs   (needs ImageMagick `magick`). Colors from docs/palette.md.
import { writeFileSync, mkdirSync, readFileSync } from "node:fs";
import { execSync } from "node:child_process";

const C = {
	base: "000020", trim: "2e2e5c", trimHi: "5454a7", trimLo: "21224e", rivet: "9797d5", chromeHi: "e7e7ff", chromeMid: "c6c6ff", chromeLo: "414183",
	pay: "ffff00", payDim: "887809", payHi: "ffff73",
	brick: "ff4aff", brickRing: "a200a2", brickDeep: "350035", brickHi: "ffcaff", brickDim: "790079", brickDimRing: "550055",
	bump: "15f2b0", bumpRing: "02936b", bumpDeep: "01563f", bumpHi: "b7fbe7",
	sky: "4fc7ff", skyRing: "186fb6", skyDeep: "0e3556", skyHi: "cefaff",
	danger: "ff0000", white: "ffffcf", pureWhite: "ffffff", cream: "ebde81",
};
const rgba = (h, a = 255) => [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16), a];

class Img {
	constructor(w, h) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); }
	px(x, y, c, a = 255) {
		if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
		const i = (y * this.w + x) * 4, s = typeof c === "string" ? rgba(c, a) : c;
		if (s[3] === 255) { this.d.set(s, i); return; }
		const t = s[3] / 255, da = this.d[i + 3] / 255, oa = t + da * (1 - t);
		for (let k = 0; k < 3; k++) this.d[i + k] = oa ? (s[k] * t + this.d[i + k] * da * (1 - t)) / oa : 0;
		this.d[i + 3] = oa * 255;
	}
	get(x, y) { const i = (y * this.w + x) * 4; return [...this.d.slice(i, i + 4)]; }
	clear(x, y) { this.d.fill(0, (y * this.w + x) * 4, (y * this.w + x) * 4 + 4); }
	rect(x, y, w, h, c, a) { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) this.px(i, j, c, a); }
	outline(x, y, w, h, c) { this.rect(x, y, w, 1, c); this.rect(x, y + h - 1, w, 1, c); this.rect(x, y, 1, h, c); this.rect(x + w - 1, y, 1, h, c); }
	hline(x, y, w, c, a) { this.rect(x, y, w, 1, c, a); }
	corners() { for (const [x, y] of [[0, 0], [this.w - 1, 0], [0, this.h - 1], [this.w - 1, this.h - 1]]) this.clear(x, y); }
	ascii(x, y, rows, map) { rows.forEach((r, j) => [...r].forEach((ch, i) => { if (map[ch]) this.px(x + i, y + j, map[ch]); })); }
	blit(s, x, y, scale = 1) { for (let j = 0; j < s.h; j++) for (let i = 0; i < s.w; i++) { const p = s.get(i, j); if (p[3]) for (let sy = 0; sy < scale; sy++) for (let sx = 0; sx < scale; sx++) this.px(x + i * scale + sx, y + j * scale + sy, p); } }
	// Nearest-neighbour rotate about centre. ponytail: this is the "rotated pixel art looks jagged" demo, not a real solution.
	rotated(deg) {
		const r = deg * Math.PI / 180, cos = Math.cos(r), sin = Math.sin(r);
		const W = Math.ceil(Math.abs(this.w * cos) + Math.abs(this.h * sin)), H = Math.ceil(Math.abs(this.w * sin) + Math.abs(this.h * cos));
		const o = new Img(W, H);
		for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
			const dx = x - W / 2 + .5, dy = y - H / 2 + .5;
			const sx = Math.floor(dx * cos + dy * sin + this.w / 2), sy = Math.floor(-dx * sin + dy * cos + this.h / 2);
			if (sx >= 0 && sy >= 0 && sx < this.w && sy < this.h) { const p = this.get(sx, sy); if (p[3]) o.px(x, y, p); }
		}
		return o;
	}
	crop(x, y, w, h) { const o = new Img(w, h); for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) o.px(i, j, this.get(x + i, y + j)); return o; }
	fade(a) { const o = this.crop(0, 0, this.w, this.h); for (let i = 3; i < o.d.length; i += 4) o.d[i] = o.d[i] * a / 255; return o; }
	pam() { return Buffer.concat([Buffer.from(`P7\nWIDTH ${this.w}\nHEIGHT ${this.h}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n`), Buffer.from(this.d)]); }
}

// 3x5 font. '.' off, '#' on.
const FONT = {
	"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"], "2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", "###", "..#", "###"], "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."], "8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "###"], "+": ["...", ".#.", "###", ".#.", "..."], "$": [".#.", "###", "##.", ".##", "###"],
	"x": ["...", "#.#", ".#.", "#.#", "..."], ":": ["...", ".#.", "...", ".#.", "..."], ",": ["...", "...", "...", ".#.", "#.."],
	"C": ["###", "#..", "#..", "#..", "###"], "O": ["###", "#.#", "#.#", "#.#", "###"], "M": ["#.#", "###", "###", "#.#", "#.#"],
	"B": ["##.", "#.#", "##.", "#.#", "##."], " ": ["...", "...", "...", "...", "..."],
};
function text(img, x, y, s, c, scale = 1) {
	for (const ch of s) { const g = FONT[ch]; if (g) g.forEach((r, j) => [...r].forEach((p, i) => { if (p === "#") img.rect(x + i * scale, y + j * scale, scale, scale, c); })); x += 4 * scale; }
}
const textW = (s, scale = 1) => s.length * 4 * scale - scale;

// Lamp brick 30x12: tube outline, ring, dark glass, highlight row.
function lamp(w, h, { tube, ring, deep, hi }, lit = true) {
	const b = new Img(w, h);
	b.rect(0, 0, w, h, deep);
	b.outline(1, 1, w - 2, h - 2, ring);
	b.outline(0, 0, w, h, tube);
	if (lit && hi) b.hline(3, 2, w - 6, hi);
	b.corners();
	return b;
}
const MAG = { tube: C.brick, ring: C.brickRing, deep: C.brickDeep, hi: C.brickHi };
const MAG_DIM = { tube: C.brickDim, ring: C.brickDimRing, deep: C.base, hi: null };
const SKY = { tube: C.sky, ring: C.skyRing, deep: C.skyDeep, hi: C.skyHi };
const SKY_DIM = { tube: "155386", ring: C.skyDeep, deep: C.base, hi: null };

const A = {};
A.brick_plain_lit = lamp(30, 12, MAG);
A.brick_plain_dim = lamp(30, 12, MAG_DIM, false);
A.brick_plain_flash = (() => { const b = lamp(30, 12, { tube: C.pureWhite, ring: C.white, deep: C.white, hi: C.pureWhite }); b.rect(2, 2, 26, 8, C.pureWhite); b.rect(3, 3, 24, 6, C.white); return b; })();

const pips = (b, lit2) => { b.rect(12, 8, 2, 2, C.pay); b.rect(16, 8, 2, 2, lit2 ? C.pay : C.payDim); };
A.brick_multi_full = lamp(30, 12, MAG); pips(A.brick_multi_full, true);
A.brick_multi_cracked = lamp(30, 12, MAG); pips(A.brick_multi_cracked, false);
for (const [x, y] of [[9, 1], [10, 2], [11, 3], [11, 4], [10, 5], [11, 6], [12, 7], [12, 8], [13, 9], [20, 1], [19, 2], [19, 3], [18, 4], [19, 5], [19, 6], [20, 7], [19, 8], [19, 9]]) A.brick_multi_cracked.px(x, y, C.white);

A.brick_icon_multiball = lamp(30, 12, MAG);
for (const [cx, cy] of [[11, 7], [17, 7], [14, 4]]) A.brick_icon_multiball.ascii(cx, cy, [".#.", "###", ".#."], { "#": C.white });
A.brick_icon_x2 = lamp(30, 12, MAG); text(A.brick_icon_x2, 12, 4, "x2", C.pay);

const chevrons = (b, c) => { for (const x of [10, 14, 18]) b.ascii(x, 3, ["#..", ".#.", "..#", ".#.", "#.."], { "#": c }); };
A.brick_cond_speed_idle = lamp(30, 12, SKY_DIM, false); chevrons(A.brick_cond_speed_idle, "186fb6");
A.brick_cond_speed_primed = lamp(30, 12, SKY); chevrons(A.brick_cond_speed_primed, C.white);

A.brick_solid = (() => {
	const b = new Img(30, 12);
	b.rect(0, 0, 30, 12, C.chromeLo);
	b.hline(0, 0, 30, C.rivet); b.hline(0, 1, 30, C.trimHi);
	b.hline(0, 10, 30, C.trimLo); b.hline(0, 11, 30, C.trimLo);
	b.rect(0, 0, 1, 12, C.trim); b.rect(29, 0, 1, 12, C.trim);
	b.px(3, 6, C.chromeMid); b.px(26, 6, C.chromeMid);
	b.corners();
	return b;
})();

A.bumper = (() => {
	const b = new Img(45, 7);
	b.rect(0, 0, 45, 7, C.bumpDeep);
	b.outline(1, 1, 43, 5, C.bumpRing);
	b.outline(0, 0, 45, 7, C.bump);
	b.hline(6, 2, 33, C.bumpHi);
	for (const x of [0, 41]) { b.rect(x, 0, 4, 1, C.chromeHi); b.rect(x, 1, 4, 2, C.chromeMid); b.rect(x, 3, 4, 2, C.rivet); b.rect(x, 5, 4, 2, C.trimHi); }
	b.corners();
	return b;
})();

const ghost = (c, o = 0) => { // o: dash offset, for marching ants
	const b = new Img(30, 12);
	b.rect(1, 1, 28, 10, c, 50);
	for (let x = 0; x < 30; x++) if ((x + o) % 4 < 2) { b.px(x, 0, c); b.px(29 - x, 11, c); }
	for (let y = 0; y < 12; y++) if ((y + o + 2) % 4 < 2) { b.px(0, 11 - y, c); b.px(29, y, c); }
	return b;
};
A.ghost_valid = ghost(C.bump);
A.ghost_invalid = ghost(C.danger);
for (let i = 0; i < 6; i++) { A.ghost_invalid.px(12 + i, 3 + i, C.danger); A.ghost_invalid.px(17 - i, 3 + i, C.danger); }

A.ball = (() => {
	const b = new Img(8, 8);
	b.ascii(0, 0, ["..####..", ".######.", "########", "########", "########", "########", ".######.", "..####.."], { "#": C.payHi });
	b.ascii(0, 0, ["........", "..####..", ".######.", ".######.", ".######.", ".######.", "..####..", "........"], { "#": C.white });
	b.rect(2, 2, 2, 1, C.pureWhite); b.px(2, 3, C.pureWhite);
	return b;
})();
A.paddle = (() => {
	const b = new Img(60, 8);
	[C.chromeHi, C.chromeMid, C.rivet, C.rivet, "7777bb", C.trimHi, C.trimHi, C.chromeLo].forEach((c, y) => b.hline(0, y, 60, c));
	b.hline(6, 4, 48, C.pay);
	b.corners();
	return b;
})();

A.fx_halo = (() => {
	const b = new Img(60, 30);
	for (let y = 0; y < 30; y++) for (let x = 0; x < 60; x++) {
		const d = ((x - 29.5) / 30) ** 2 + ((y - 14.5) / 15) ** 2, dith = (x + y) % 2 === 0;
		if (d < .25) b.px(x, y, C.brick, 110); else if (d < .5 && dith) b.px(x, y, C.brick, 90); else if (d < .8 && dith && x % 2 === 0) b.px(x, y, C.brick, 60);
	}
	return b;
})();
A.fx_spark = (() => { const b = new Img(5, 5); b.ascii(0, 0, ["..#..", "..#..", "#####", "..#..", "..#.."], { "#": C.pay }); b.px(2, 2, C.pureWhite); return b; })();
A.fx_debris = (() => { const b = new Img(4, 3); b.rect(0, 0, 4, 3, C.brick); b.rect(1, 1, 2, 1, C.brickDeep); return b; })();
A.fx_payout_tag = (() => { const b = new Img(17, 8); b.rect(0, 0, 17, 8, C.pay); b.outline(0, 0, 17, 8, C.cream); b.corners(); text(b, 3, 2, "+12", C.base); return b; })();

// ---- Animations: same-size frames, exported as horizontal strips anim_<name>.png. Held frames are repeated. ----
const frame = (w, h, ...layers) => { const f = new Img(w, h); for (const [img, x, y, a] of layers) { const s = a == null ? img : img.fade(a); f.blit(s, x, y); } return f; };
const center = (img, w, h, dx = 0, dy = 0) => [img, ((w - img.w) >> 1) + dx, ((h - img.h) >> 1) + dy];
const MAG_HOT = { tube: C.brickHi, ring: C.brick, deep: C.brickRing, hi: C.pureWhite };
const SKY_HOT = { tube: C.skyHi, ring: C.sky, deep: C.skyRing, hi: C.pureWhite };
const ellipse = (w, h) => { // ball squash/stretch shapes
	const b = new Img(w, h), f = (x, y, r) => ((x + .5 - w / 2) / (w / 2 - r)) ** 2 + ((y + .5 - h / 2) / (h / 2 - r)) ** 2 <= 1;
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { if (f(x, y, 0)) b.px(x, y, C.payHi); if (f(x, y, 1)) b.px(x, y, C.white); }
	b.rect(2, 2, 2, 1, C.pureWhite); b.px(2, 3, C.pureWhite); return b;
};
const sparks = (f, r, c) => { for (const [sx, sy] of [[1, 1], [-1, 1], [1, -1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]]) f.px((f.w >> 1) + sx * r, (f.h >> 1) + sy * r, c); };

const ANIM = {}; // name: { fps, frames }
ANIM.brick_hit = { fps: 12, frames: [A.brick_plain_flash, lamp(30, 12, MAG_HOT), A.brick_plain_lit, A.brick_plain_lit, A.brick_plain_lit, A.brick_plain_lit] };
ANIM.brick_break = { fps: 12, frames: (() => {
	const W = 44, H = 20, lit = A.brick_plain_lit, L = lit.crop(0, 0, 15, 12), R = lit.crop(15, 0, 15, 12), hot = lamp(30, 12, MAG_HOT);
	const f0 = frame(W, H, center(A.brick_plain_flash, W, H));
	const f1 = frame(W, H, center(hot, W, H)); sparks(f1, 8, C.pay);
	const f2 = frame(W, H, [L, 5, 3], [R, 24, 3]); sparks(f2, 7, C.payHi); f2.blit(A.fx_debris, 20, 1); f2.blit(A.fx_debris, 19, 15);
	const f3 = frame(W, H, [L, 2, 1, 150], [R, 27, 5, 150], [A.fx_debris, 10, 17, 200], [A.fx_debris, 32, 0, 200], [A.fx_debris, 21, 16, 200]); sparks(f3, 9, C.payDim);
	const f4 = frame(W, H, [A.fx_debris, 6, 19, 90], [A.fx_debris, 36, 0, 90], [A.fx_debris, 22, 18, 90]);
	return [f0, f1, f2, f3, f4, new Img(W, H), new Img(W, H), new Img(W, H)];
})() };
ANIM.multi_crack = { fps: 12, frames: [A.brick_multi_full, A.brick_multi_full, A.brick_multi_full, A.brick_plain_flash, A.brick_multi_cracked, A.brick_multi_cracked, A.brick_multi_cracked, A.brick_multi_cracked] };
ANIM.cond_prime = { fps: 8, frames: (() => {
	const mid = lamp(30, 12, { tube: C.skyRing, ring: C.skyDeep, deep: C.base, hi: null }, false); chevrons(mid, C.sky);
	const hot = lamp(30, 12, SKY_HOT); chevrons(hot, C.pureWhite);
	const p = A.brick_cond_speed_primed, i = A.brick_cond_speed_idle;
	return [i, i, i, mid, hot, p, p, p, p, p];
})() };
ANIM.bumper_hit = { fps: 12, frames: (() => {
	const b = A.bumper, f = b.crop(0, 0, 45, 7), hot = b.crop(0, 0, 45, 7);
	f.rect(4, 0, 37, 7, C.white); f.rect(5, 1, 35, 5, C.pureWhite);
	hot.rect(4, 0, 37, 1, C.bumpHi); hot.rect(4, 6, 37, 1, C.bumpHi); hot.hline(6, 2, 33, C.pureWhite);
	return [f, hot, b, b, b, b];
})() };
ANIM.ghost_march = { fps: 8, frames: [0, 1, 2, 3].map((o) => ghost(C.bump, o)) };
ANIM.ball_bounce = { fps: 12, frames: (() => {
	const W = 12, H = 12, n = A.ball, sq = ellipse(10, 6), st = ellipse(6, 10);
	return [frame(W, H, [n, 2, 2]), frame(W, H, [n, 2, 4]), frame(W, H, [sq, 1, 6]), frame(W, H, [st, 3, 0]), frame(W, H, [n, 2, 0]), frame(W, H, [n, 2, 0])];
})() };
ANIM.payout_rise = { fps: 12, frames: [[18, 255], [15, 255], [12, 255], [10, 255], [8, 255], [6, 255], [5, 170], [4, 110], [3, 60], [3, 0]].map(([y, a]) => frame(17, 26, [A.fx_payout_tag, 0, y, a])) };
ANIM.spark_burst = { fps: 12, frames: (() => {
	const f0 = frame(16, 16, center(A.fx_spark, 16, 16));
	const f1 = new Img(16, 16); sparks(f1, 3, C.payHi); f1.px(8, 8, C.pureWhite);
	const f2 = new Img(16, 16); sparks(f2, 5, C.pay);
	const f3 = new Img(16, 16); sparks(f3, 7, C.payDim);
	return [f0, f1, f2, f3, new Img(16, 16), new Img(16, 16)];
})() };
const strip = (frames) => { const s = new Img(frames[0].w * frames.length, frames[0].h); frames.forEach((f, i) => s.blit(f, i * f.w, 0)); return s; };

// ---- Mockup 640x360 ----
function board() {
	const m = new Img(640, 360);
	m.rect(0, 0, 640, 360, C.base);
	for (let y = 50; y < 280; y += 10) for (let x = 10; x < 640; x += 10) m.px(x, y, C.trim);
	m.hline(0, 20, 640, C.rivet); m.hline(0, 21, 640, C.trimHi);
	m.rect(0, 20, 2, 340, C.rivet); m.rect(638, 20, 2, 340, C.rivet);
	m.hline(0, 18, 410, C.pay);
	text(m, 8, 4, "$ 1,248", C.pay, 2);
	text(m, 320 - textW("x7 COMBO", 2) / 2, 4, "x7 COMBO", C.pay, 2);
	text(m, 632 - textW("0:04", 2), 4, "0:04", C.danger, 2);
	for (let x = 2; x < 638; x += 6) m.rect(x, 280, 3, 1, C.bump, 120);
	const cols = 15, bw = 32, x0 = (640 - cols * bw) / 2;
	const pick = (r, c) => {
		const k = (r * 7 + c * 3) % 23;
		if (r === 0 && c === 7) return "brick_icon_x2";
		if (k === 4 || k === 15) return "brick_solid";
		if (k === 9) return "brick_multi_full";
		if (k === 13) return "brick_multi_cracked";
		if (k === 20) return "brick_icon_multiball";
		if (k === 6) return "brick_cond_speed_idle";
		if (k === 11) return "brick_plain_dim";
		return "brick_plain_lit";
	};
	for (let r = 0; r < 7; r++) for (let i = 0; i < cols - r * 2; i++) {
		const c = r + i;
		if ((r * 5 + c * 11) % 17 === 0) continue;
		m.blit(A[pick(r, c)], x0 + c * bw, 45 + r * 14);
	}
	const fx = x0 + 5 * bw, fy = 45 + 7 * 14;
	m.blit(A.fx_halo, fx - 15, fy - 9);
	m.blit(A.brick_plain_flash, fx, fy);
	for (const [dx, dy] of [[-6, -5], [34, -4], [10, 15], [26, 13]]) m.blit(A.fx_spark, fx + dx, fy + dy);
	for (const [dx, dy] of [[-9, 3], [33, 1], [15, 16]]) m.blit(A.fx_debris, fx + dx, fy + dy);
	m.blit(A.fx_payout_tag, fx + 4, fy - 12);
	m.blit(A.bumper.rotated(-15), 150, 205);
	m.blit(A.bumper.rotated(15), 440, 215);
	m.blit(A.ghost_valid, 300, 240);
	m.blit(A.ghost_invalid, 350, 260);
	for (let i = 1; i <= 4; i++) m.rect(318 - i * 7, 299 + i * 5, 2, 2, C.pay, 160 - i * 35);
	m.blit(A.ball, 315, 295);
	m.blit(A.paddle, 290, 336);
	return m;
}

mkdirSync("assets/pixel/png", { recursive: true });
mkdirSync("assets/pixel/tmp", { recursive: true });
const toPng = (img, out, scale = 1) => {
	writeFileSync("assets/pixel/tmp/x.pam", img.pam());
	execSync(`magick assets/pixel/tmp/x.pam ${scale > 1 ? `-scale ${scale * 100}%` : ""} ${out}`);
};
for (const [n, img] of Object.entries(A)) toPng(img, `assets/pixel/png/${n}.png`);
for (const [n, a] of Object.entries(ANIM)) toPng(strip(a.frames), `assets/pixel/png/anim_${n}.png`);
toPng(board(), "assets/pixel/look.png", 2);
execSync("rm -r assets/pixel/tmp");

// ---- Demo page ----
const uri = (n) => `data:image/png;base64,${readFileSync(`assets/pixel/png/${n}.png`).toString("base64")}`;
const GROUPS = [
	["Plain brick", ["brick_plain_lit", "brick_plain_dim", "brick_plain_flash"]],
	["Multi-hit", ["brick_multi_full", "brick_multi_cracked"]],
	["Icon bricks", ["brick_icon_multiball", "brick_icon_x2"]],
	["Conditional", ["brick_cond_speed_idle", "brick_cond_speed_primed"]],
	["Solid", ["brick_solid"]],
	["Placeables", ["bumper", "ghost_valid", "ghost_invalid"]],
	["Ball and paddle", ["ball", "paddle"]],
	["Effects", ["fx_halo", "fx_spark", "fx_debris", "fx_payout_tag"]],
];
const cards = GROUPS.map(([title, names]) => `<section><h2>${title}</h2><div class="row">${names.map((n) =>
	`<figure><div class="tile"><img src="${uri(n)}" width="${A[n].w}" height="${A[n].h}" alt="${n}"></div><figcaption>${n}<span>${A[n].w}×${A[n].h}</span></figcaption></figure>`
).join("")}</div></section>`).join("");
const anims = `<section id="anims"><h2>Animations</h2><p class="lede">Looping at the frame rate noted. The strip under each is the exported sprite sheet; held frames are repeated in the strip, in-engine they would be a hold time instead.</p><div class="row">${Object.entries(ANIM).map(([n, a]) => {
	const { w, h } = a.frames[0], k = a.frames.length;
	return `<figure><div class="tile"><div class="anim" style="--fw:${w}px;--fh:${h}px;--n:${k};--fps:${a.fps};background-image:url(${uri("anim_" + n)})"></div></div><div class="tile"><img src="${uri("anim_" + n)}" width="${w * k}" height="${h}" alt="${n} strip"></div><figcaption>anim_${n}<span>${w}×${h} · ${k}f · ${a.fps}fps</span></figcaption></figure>`;
}).join("")}</div></section>`;
const html = `<title>Breakin' Cremental Pixel Sprites</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Silkscreen&family=IBM+Plex+Sans:wght@400;600&display=swap">
<style>
/* Layout: 2x mockup on top, sprite groups in wrapping rows, sticky zoom. Single dark theme: it is the game's screen. */
:root{--bg:#${C.base};--panel:#0a0a33;--trim:#${C.trim};--fg:#${C.white};--muted:#${C.rivet};--accent:#${C.pay};--pink:#${C.brick};--mint:#${C.bump};
--display:"Silkscreen",monospace;--body:"IBM Plex Sans",system-ui,sans-serif;--z:4;color-scheme:dark}
body{background:var(--bg);color:var(--fg);font:15px/1.5 var(--body);padding-block:24px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
h1{font:22px var(--display);color:var(--accent);margin:0 0 4px;text-shadow:0 0 12px #${C.pay}88;text-wrap:balance}
h2{font:12px var(--display);color:var(--pink);margin:0 0 10px}
p.lede{color:var(--muted);margin:0 0 20px;max-width:65ch}
img{image-rendering:pixelated;image-rendering:crisp-edges}
.bar{display:flex;gap:8px;align-items:center;flex-wrap:wrap;position:sticky;top:env(safe-area-inset-top,0px);background:var(--bg);padding-block:8px;margin-bottom:16px;border-bottom:1px solid var(--trim);z-index:5}
.bar span{color:var(--muted);font-size:13px;letter-spacing:.08em;text-transform:uppercase}
.bar button{font:600 13px var(--body);color:var(--fg);background:var(--panel);border:1px solid var(--trim);border-radius:4px;padding:4px 12px;cursor:pointer}
.bar button[aria-pressed=true]{border-color:var(--mint);color:var(--mint);box-shadow:0 0 8px #${C.bump}66}
.bar button:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.board{border:2px solid var(--trim);max-width:100%;height:auto;display:block;margin-bottom:28px;box-shadow:0 0 24px #0008}
section{margin-bottom:28px}
.row{display:flex;flex-wrap:wrap;gap:12px}
figure{margin:0;display:flex;flex-direction:column;gap:6px;min-width:0}
.tile{background:var(--panel);border:1px solid var(--trim);padding:16px;display:grid;place-items:center;min-width:120px;min-height:72px;background-image:radial-gradient(#${C.trim} .8px,transparent .8px);background-size:20px 20px}
.tile img{width:calc(var(--w)*var(--z));height:auto}
figcaption{font-size:12px;color:var(--muted);display:flex;justify-content:space-between;gap:12px;font-variant-numeric:tabular-nums}
.anim{width:calc(var(--fw)*var(--z));height:calc(var(--fh)*var(--z));background-size:calc(var(--fw)*var(--n)*var(--z)) 100%;background-repeat:no-repeat;image-rendering:pixelated;animation:play calc(var(--n)/var(--fps)*1s) steps(var(--n)) infinite}
@keyframes play{to{background-position-x:calc(-1*var(--fw)*var(--n)*var(--z))}}
.paused .anim,.anim:hover{animation-play-state:paused}
@media(prefers-reduced-motion:reduce){.anim{animation-play-state:paused}}
#anims .tile{overflow:auto;max-width:100%}
#anims p{margin-bottom:12px}
</style>
<h1>Breakin' Cremental Pixel Sprites</h1>
<p class="lede">Pachinko lamp look as pixel art on a 2× canvas (640×360). One sprite pixel is two screen pixels in game. Sizes below are native pixels. Glow in-engine comes from a shader; the bumpers in the mockup show what nearest-neighbour rotation does to pixel art.</p>
<img class="board" src="data:image/png;base64,${readFileSync("assets/pixel/look.png").toString("base64")}" width="1280" height="720" alt="Mockup of a full arena at 2x">
<div class="bar"><span>Zoom</span><button data-z="2">2×</button><button data-z="4" aria-pressed="true">4×</button><button data-z="8">8×</button><button id="pause" aria-pressed="false" style="margin-left:auto">Pause</button></div>
${anims}
${cards}
<script>
document.getElementById("pause").onclick=function(){const on=document.body.classList.toggle("paused");this.setAttribute("aria-pressed",on);this.textContent=on?"Play":"Pause"};
document.querySelectorAll(".tile img").forEach(i=>i.style.setProperty("--w",i.getAttribute("width")+"px"));
document.querySelectorAll(".bar button").forEach(b=>b.onclick=()=>{
	document.querySelectorAll(".bar button").forEach(x=>x.setAttribute("aria-pressed",x===b));
	document.documentElement.style.setProperty("--z",b.dataset.z);
});
</script>`;
writeFileSync("assets/pixel/assets.html", html);
console.log(`${Object.keys(A).length} pixel assets + look.png + assets.html`);
