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
	flipX() { const o = new Img(this.w, this.h); for (let j = 0; j < this.h; j++) for (let i = 0; i < this.w; i++) o.px(this.w - 1 - i, j, this.get(i, j)); return o; }
	line(x0, y0, x1, y1, c) { const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0), 1); for (let i = 0; i <= n; i++) this.px(Math.round(x0 + (x1 - x0) * i / n), Math.round(y0 + (y1 - y0) * i / n), c); }
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

const ghost = (c, o = 0, w = 30, h = 12) => { // o: dash offset, for marching ants
	const b = new Img(w, h);
	b.rect(1, 1, w - 2, h - 2, c, 50);
	for (let x = 0; x < w; x++) if ((x + o) % 4 < 2) { b.px(x, 0, c); b.px(w - 1 - x, h - 1, c); }
	for (let y = 0; y < h; y++) if ((y + o + 2) % 4 < 2) { b.px(0, h - 1 - y, c); b.px(w - 1, y, c); }
	return b;
};
const cross = (f, w, h, c) => { const k = Math.min(6, h - 2, w - 2), x0 = (w - k) >> 1, y0 = (h - k) >> 1; for (let i = 0; i < k; i++) { f.px(x0 + i, y0 + i, c); f.px(x0 + k - 1 - i, y0 + i, c); } };
A.ghost_valid = ghost(C.bump);
A.ghost_invalid = ghost(C.danger);
cross(A.ghost_invalid, 30, 12, C.danger);

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
// Full list and intent: docs/animations.md. Each group below matches a section there.
const frame = (w, h, ...layers) => { const f = new Img(w, h); for (const [img, x, y, a] of layers) f.blit(a == null ? img : img.fade(a), x, y); return f; };
const center = (img, w, h, dx = 0, dy = 0) => [img, ((w - img.w) >> 1) + dx, ((h - img.h) >> 1) + dy];
const hold = (f, n) => Array(n).fill(f);
const blank = (w, h) => new Img(w, h);

// Hue sets. tube/ring/deep/hi for lit; dimTube/dimRing for dim. All from docs/palette.md ramps.
const SETS = {
	mag: { tube: C.brick, ring: C.brickRing, deep: C.brickDeep, hi: C.brickHi, dimTube: C.brickDim, dimRing: C.brickDimRing },
	ora: { tube: "ff7500", ring: "c44f00", deep: "791800", hi: "ffb975", dimTube: "9f3800", dimRing: "812000" },
	vio: { tube: "7f16ff", ring: "48009f", deep: "240051", hi: "c799ff", dimTube: "5b00c9", dimRing: "330071" },
	mint: { tube: C.bump, ring: C.bumpRing, deep: C.bumpDeep, hi: C.bumpHi, dimTube: "027354", dimRing: C.bumpDeep },
	sky: { tube: C.sky, ring: C.skyRing, deep: C.skyDeep, hi: C.skyHi, dimTube: "155386", dimRing: C.skyDeep },
};
const lit = (s, w = 30, h = 12) => lamp(w, h, s);
const dim = (s, w = 30, h = 12) => lamp(w, h, { tube: s.dimTube, ring: s.dimRing, deep: C.base, hi: null }, false);
const hot = (s, w = 30, h = 12) => lamp(w, h, { tube: s.hi, ring: s.tube, deep: s.ring, hi: C.pureWhite });
const mid = (s, w = 30, h = 12) => lamp(w, h, { tube: s.ring, ring: s.deep, deep: C.base, hi: null }, false);
const flash = (w = 30, h = 12) => { const b = lamp(w, h, { tube: C.pureWhite, ring: C.white, deep: C.white, hi: C.pureWhite }); b.rect(2, 2, w - 4, h - 4, C.pureWhite); b.rect(3, 3, w - 6, h - 6, C.white); return b; };
const FLASH = flash();

const ellipse = (w, h, edge = C.payHi, body = C.white) => { // ball shapes
	const b = new Img(w, h), f = (x, y, r) => ((x + .5 - w / 2) / (w / 2 - r)) ** 2 + ((y + .5 - h / 2) / (h / 2 - r)) ** 2 <= 1;
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { if (f(x, y, 0)) b.px(x, y, edge); if (f(x, y, 1)) b.px(x, y, body); }
	if (w > 4) { b.rect(2, 2, 2, 1, C.pureWhite); b.px(2, 3, C.pureWhite); }
	return b;
};
const sparks = (f, r, c) => { for (const [sx, sy] of [[1, 1], [-1, 1], [1, -1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]]) f.px((f.w >> 1) + sx * r, (f.h >> 1) + sy * r, c); };
const ring = (f, cx, cy, r, c, thick = 1, dash = 0) => { // circle outline by angle steps; dash: skip every other step group
	const n = Math.ceil(r * 8);
	for (let i = 0; i < n; i++) { if (dash && ((i >> 1) & 1)) continue; const t = i / n * Math.PI * 2; for (let k = 0; k < thick; k++) f.px(Math.round(cx + (r - k) * Math.cos(t)), Math.round(cy + (r - k) * Math.sin(t)), c); }
};
const oval = (f, cx, cy, rx, ry, c, dash = 0) => { const n = Math.ceil((rx + ry) * 4); for (let i = 0; i < n; i++) { if (dash && ((i >> 1) & 1)) continue; const t = i / n * Math.PI * 2; f.px(Math.round(cx + rx * Math.cos(t)), Math.round(cy + ry * Math.sin(t)), c); } };
const withIcon = (b, icon, c) => { const o = b.crop(0, 0, b.w, b.h); icon(o, c); return o; };
const glyph = (rows, c2 = null) => (b, c) => { const w = rows[0].length, h = rows.length; b.ascii(15 - (w >> 1), 3 + ((7 - h) >> 1), rows, { "#": c, "o": c2 || c }); };
const label = (s) => (b, c) => text(b, 15 - (textW(s) >> 1), 4, s, c);
FONT["?"] = ["###", "..#", ".##", "...", ".#."];

const ICONS = {
	multiball: (b, c) => { for (const [cx, cy] of [[11, 7], [17, 7], [14, 4]]) b.ascii(cx, cy, [".#.", "###", ".#."], { "#": c }); },
	speedup: (b, c) => chevrons(b, c),
	slowdown: (b, c) => { for (const x of [10, 14, 18]) b.ascii(x, 3, ["..#", ".#.", "#..", ".#.", "..#"], { "#": c }); },
	x2: label("x2"), x3: label("x3"), combo: label("C+"), jackpot: label("777"), mystery: label("?"),
	timer: glyph(["#####", ".#.#.", "..#..", ".#.#.", "#####"]),
	chain: glyph(["###.###", "#.###.#", "###.###"]),
	bomb: glyph(["...o.", "..#..", ".###.", "#####", "#####", ".###."], C.pay),
	bolt: glyph(["..##.", "..#..", ".####", "...#.", "..#.."]),
	wild: (b) => { [SETS.mag, SETS.ora, SETS.vio].forEach((s, i) => { b.rect(10 + i * 4, 5, 3, 3, s.tube); b.px(10 + i * 4, 5, s.hi); }); },
	magnet: glyph(["o...o", "#...#", "#...#", "#...#", ".###."], C.pureWhite),
	split: glyph(["#...#", ".#.#.", "..#..", "..#..", "..#.."]),
	pierce: glyph(["...#...", "#..##..", "#######", "#..##..", "...#..."]),
	wedge: glyph(["#....", "##...", "###..", "####.", "#####"]),
	gate: glyph(["..#..", ".###.", "#.#.#", "..#..", "..#.."]),
};

const ANIM = {}, AGROUPS = [];
const def = (group, name, fps, frames) => { ANIM[name] = { fps, frames }; (AGROUPS.find((g) => g[0] === group) || AGROUPS[AGROUPS.push([group, []]) - 1])[1].push(name); };

// -- Brick states per currency set --
for (const id of ["mag", "ora", "vio"]) {
	const s = SETS[id], L = lit(s), H = hot(s), D = dim(s);
	def("Brick states", `${id}_hit`, 12, [FLASH, H, ...hold(L, 4)]);
	def("Brick states", `${id}_break`, 12, (() => {
		const W = 44, Hh = 20, Lh = L.crop(0, 0, 15, 12), Rh = L.crop(15, 0, 15, 12), chip = (() => { const b = new Img(4, 3); b.rect(0, 0, 4, 3, s.tube); b.rect(1, 1, 2, 1, s.deep); return b; })();
		const f0 = frame(W, Hh, center(FLASH, W, Hh));
		const f1 = frame(W, Hh, center(H, W, Hh)); sparks(f1, 8, C.pay);
		const f2 = frame(W, Hh, [Lh, 5, 3], [Rh, 24, 3], [chip, 20, 1], [chip, 19, 15]); sparks(f2, 7, C.payHi);
		const f3 = frame(W, Hh, [Lh, 2, 1, 150], [Rh, 27, 5, 150], [chip, 10, 17, 200], [chip, 32, 0, 200], [chip, 21, 16, 200]); sparks(f3, 9, C.payDim);
		const f4 = frame(W, Hh, [chip, 6, 19, 90], [chip, 36, 0, 90], [chip, 22, 18, 90]);
		return [f0, f1, f2, f3, f4, ...hold(blank(W, Hh), 3)];
	})());
	def("Brick states", `${id}_spawn`, 12, (() => {
		const o = new Img(30, 12); o.outline(0, 0, 30, 12, s.dimTube); o.corners();
		const o2 = o.crop(0, 0, 30, 12); o2.outline(1, 1, 28, 10, s.dimRing);
		return [o, o2, D, FLASH, H, L];
	})());
	def("Brick states", `${id}_pulse`, 8, [L, lamp(30, 12, { ...s, hi: C.pureWhite }), L, lamp(30, 12, { ...s, hi: null })]);
}

// -- Multi-hit and armor --
const M = SETS.mag, ML = lit(M), MH = hot(M);
const crack = (b, pts) => { for (const [x, y] of pts) b.px(x, y, C.white); return b; };
const CRACK_L = [[9, 1], [10, 2], [11, 3], [11, 4], [10, 5], [11, 6], [12, 7], [12, 8], [13, 9]], CRACK_R = [[20, 1], [19, 2], [19, 3], [18, 4], [19, 5], [19, 6], [20, 7], [19, 8], [19, 9]];
const pips3 = (b, n, blink = null) => { [10, 14, 18].forEach((x, i) => b.rect(x, 8, 2, 2, i === blink ? C.pureWhite : i < n ? C.pay : C.payDim)); return b; };
def("Multi-hit and armor", "multi_crack", 12, [...hold(A.brick_multi_full, 3), FLASH, ...hold(A.brick_multi_cracked, 4)]);
def("Multi-hit and armor", "multi3_crack", 12, (() => {
	const f = pips3(ML.crop(0, 0, 30, 12), 3), c1 = crack(pips3(ML.crop(0, 0, 30, 12), 2), CRACK_L), c2 = crack(crack(pips3(ML.crop(0, 0, 30, 12), 1), CRACK_L), CRACK_R);
	return [...hold(f, 3), FLASH, ...hold(c1, 3), FLASH, ...hold(c2, 4)];
})());
def("Multi-hit and armor", "pips_shrink", 12, [pips3(ML.crop(0, 0, 30, 12), 3), pips3(ML.crop(0, 0, 30, 12), 3, 2), pips3(ML.crop(0, 0, 30, 12), 3), pips3(ML.crop(0, 0, 30, 12), 3, 2), ...hold(pips3(ML.crop(0, 0, 30, 12), 2), 2)]);
def("Multi-hit and armor", "armor_pop", 12, (() => {
	const W = 44, Hh = 20, P = A.brick_solid, PF = (() => { const b = P.crop(0, 0, 30, 12); b.rect(1, 0, 28, 2, C.pureWhite); return b; })();
	const f2 = frame(W, Hh, center(ML, W, Hh), center(P, W, Hh, 0, -2)); sparks(f2, 8, C.pay);
	return [frame(W, Hh, center(P, W, Hh)), frame(W, Hh, center(PF, W, Hh)), f2, frame(W, Hh, center(ML, W, Hh), [P, 11, -1, 200]), frame(W, Hh, center(MH, W, Hh), [P, 17, -5, 100]), ...hold(frame(W, Hh, center(ML, W, Hh)), 3)];
})());

// -- Solid --
const dust = [["..##..", ".####."], ["#..##..#", "..#..#.."], [".#......#.", "#...##...#", "....##...."], ["#........#", "..........", "....#....."]].map((rows, i) => { const b = new Img(12, 8); b.ascii(1, 6 - i * 2, rows, { "#": [C.chromeMid, C.rivet, C.trimHi, C.trimHi][i] }); return i > 1 ? b.fade(160) : b; });
def("Solid", "dust_puff", 12, dust);
def("Solid", "solid_bounce", 12, (() => {
	const W = 44, Hh = 20, S = A.brick_solid, SF = S.crop(0, 0, 30, 12); SF.rect(1, 0, 28, 2, C.pureWhite);
	return [frame(W, Hh, center(SF, W, Hh)), frame(W, Hh, center(S, W, Hh), [dust[0], 16, 1]), frame(W, Hh, center(S, W, Hh), [dust[1], 16, 0]), frame(W, Hh, center(S, W, Hh), [dust[2], 16, -1]), frame(W, Hh, center(S, W, Hh), [dust[3], 16, -2]), frame(W, Hh, center(S, W, Hh))];
})());

// -- Icon bricks --
for (const id of ["multiball", "speedup", "slowdown", "x2", "x3", "combo", "timer", "chain", "bomb", "bolt", "wild", "jackpot", "mystery", "magnet", "split", "pierce"])
	def("Icon bricks", `icon_${id}_pulse`, 8, [C.pay, C.white, C.pureWhite, C.white].map((c) => withIcon(ML, ICONS[id], c)));
def("Icon bricks", "wild_cycle", 8, [SETS.mag, SETS.mag, SETS.ora, SETS.ora, SETS.vio, SETS.vio].map((s) => withIcon(lit(s), ICONS.wild, null)));
def("Icon bricks", "mystery_cycle", 8, ["mystery", "multiball", "mystery", "bolt", "mystery", "x2"].map((k) => withIcon(ML, ICONS[k], C.white)));
def("Icon bricks", "chain_arc", 12, [0, 1, 2, 3].map((f) => {
	const b = new Img(64, 12), ys = [6, 3, 8, 4, 9, 2, 7, 3, 9, 5, 8, 2, 7, 4, 9, 3, 6].map((y, i) => f === 3 ? 6 : (y + (f * (i + 1)) % 3 - 1 + 12) % 12);
	for (let i = 0; i < 16; i++) b.line(i * 4, ys[i], i * 4 + 4, ys[i + 1], C.brick);
	ys.forEach((y, i) => b.px(i * 4, y, C.pureWhite));
	return f === 3 ? b.fade(110) : b;
}));
def("Icon bricks", "bomb_ring", 12, [[6, 3, C.pureWhite], [12, 2, C.payHi], [20, 1, C.pay], [28, 1, C.payDim]].map(([r, t, c]) => { const b = new Img(60, 60); ring(b, 30, 30, r, c, t); return b; }));
def("Icon bricks", "bolt_sweep", 12, [0, 1, 2, 3].map((f) => { const b = new Img(60, 12); b.rect(0, 5, 60, 2, C.pay); for (let x = 0; x < 60; x++) if (((x - f * 15) % 60 + 60) % 60 < 15) { b.rect(x, 4, 1, 4, C.payHi); b.rect(x, 5, 1, 2, C.pureWhite); } return b; }));
def("Icon bricks", "jackpot_rays", 8, [8, 12, 16, 20, 16, 12].map((len, f) => {
	const b = new Img(48, 48);
	for (let i = 0; i < 8; i++) { const t = i * Math.PI / 4 + (f & 1 ? Math.PI / 8 : 0), l = i & 1 ? len * .6 : len; b.line(24, 24, Math.round(24 + l * Math.cos(t)), Math.round(24 + l * Math.sin(t)), i & 1 ? C.payDim : C.pay); }
	b.rect(23, 23, 2, 2, C.pureWhite); return b;
}));
def("Icon bricks", "magnet_field", 8, [21, 17, 13, 9].map((rx) => { const b = new Img(44, 20); oval(b, 22, 10, rx, Math.round(rx * .45), C.brick, 1); return b; }));
def("Icon bricks", "pierce_trail", 12, [0, 1, 2, 3].map((f) => frame(24, 8, [A.ball, 1 - (f & 1), 0, 40], [A.ball, 6, 0, 90 + f * 10], [A.ball, 11 - (f & 1), 0, 150], [A.ball, 16, 0])));

// -- Conditional bricks --
const S = SETS.sky, SL = lit(S), SD = dim(S), SM = mid(S), SH = hot(S);
const prime = (icon) => [...hold(withIcon(SD, icon, S.ring), 3), withIcon(SM, icon, S.tube), withIcon(SH, icon, C.pureWhite), ...hold(withIcon(SL, icon, C.white), 5)];
def("Conditional bricks", "cond_prime", 8, prime(ICONS.speedup));
def("Conditional bricks", "angle_prime", 8, prime(ICONS.wedge));
def("Conditional bricks", "cond_too_slow", 12, [[-1, 1], [1, 1], [0, 0], [-1, 1], [1, 1], [0, 0]].map(([dx, X]) => {
	const f = frame(30, 12, [withIcon(SD, ICONS.speedup, S.ring), dx, 0]);
	if (X) for (let i = 0; i < 6; i++) { f.px(12 + i, 3 + i, C.danger); f.px(17 - i, 3 + i, C.danger); }
	return f;
}));
def("Conditional bricks", "combo_gate", 8, [withIcon(SD, label("3"), S.tube), withIcon(SD, label("2"), S.tube), withIcon(SD, label("1"), S.tube), FLASH, withIcon(SH, label("1"), C.pureWhite), withIcon(SL, label("1"), C.white)]);
for (const n of [1, 2, 3]) def("Conditional bricks", `sequence_step${n}`, 12, (() => {
	const done = withIcon(SD, glyph(["....#", "...#.", "#.#..", ".#..."]), C.bump);
	return [...hold(withIcon(SL, label(String(n)), C.white), 2), FLASH, ...hold(done, 3)];
})());
def("Conditional bricks", "timed_blink", 8, [...hold(SL, 3), SM, ...hold(SD, 3), SM]);
def("Conditional bricks", "shield_pop", 12, (() => {
	const W = 44, Hh = 20, base = () => frame(W, Hh, center(ML, W, Hh));
	const sh = (c, gaps = [], off = 0, a = 255) => { const f = base(), s = new Img(W, Hh); s.outline(5 - off, 2 - off, 34 + off * 2, 16 + off * 2, c); s.corners(); for (const [x, y] of gaps) s.clear(x, y); f.blit(a < 255 ? s.fade(a) : s, 0, 0); return f; };
	const gaps = [[12, 2], [13, 2], [30, 17], [31, 17], [5, 8], [38, 11]];
	const pieces = (off, a) => { const f = base(); const s = new Img(W, Hh); s.outline(5 - off, 2 - off, 34 + off * 2, 16 + off * 2, C.sky); for (let i = 0; i < W; i++) for (let j = 0; j < Hh; j++) if ((i + j) % 5 < 2) s.clear(i, j); f.blit(s.fade(a), 0, 0); return f; };
	return [sh(C.sky), sh(C.sky, gaps), sh(C.pureWhite, gaps), pieces(2, 200), pieces(4, 100), base()];
})());

// -- Placeables --
const B = A.bumper;
def("Placeables", "bumper_hit", 12, (() => {
	const f = B.crop(0, 0, 45, 7), h = B.crop(0, 0, 45, 7);
	f.rect(4, 0, 37, 7, C.white); f.rect(5, 1, 35, 5, C.pureWhite);
	h.rect(4, 0, 37, 1, C.bumpHi); h.rect(4, 6, 37, 1, C.bumpHi); h.hline(6, 2, 33, C.pureWhite);
	return [f, h, ...hold(B, 4)];
})());
def("Placeables", "pop_bumper_hit", 12, (() => {
	const pop = (t, r, d, hi) => { const b = new Img(24, 24); for (let y = 0; y < 24; y++) for (let x = 0; x < 24; x++) { const q = (x - 11.5) ** 2 + (y - 11.5) ** 2; if (q <= 49) b.px(x, y, d); } ring(b, 11.5, 11.5, 6, r); ring(b, 11.5, 11.5, 7, t); if (hi) b.rect(9, 7, 5, 1, hi); return b; };
	const n = pop(C.bump, C.bumpRing, C.bumpDeep, C.bumpHi), fl = pop(C.pureWhite, C.white, C.white, C.pureWhite), ho = pop(C.bumpHi, C.bump, C.bumpRing, C.pureWhite);
	const r1 = n.crop(0, 0, 24, 24); ring(r1, 11.5, 11.5, 9, C.pay); const r2 = n.crop(0, 0, 24, 24); ring(r2, 11.5, 11.5, 11, C.payDim, 1, 1);
	return [fl, ho, r1, r2, n, n];
})());
const glassScroll = (draw, n = 4) => Array.from({ length: n }, (_, f) => { const g = new Img(26, 7); draw(g, f); const b = lit(SETS.mint).crop(0, 0, 30, 12); b.blit(g, 2, 3); return b; });
def("Placeables", "gate_flow", 8, glassScroll((g, f) => { for (let k = -1; k < 3; k++) g.ascii(10, k * 4 + 3 - f, ["..#..", ".###.", "#.#.#"], { "#": C.white }); }));
def("Placeables", "accel_chevrons", 8, glassScroll((g, f) => { for (let k = -1; k < 8; k++) g.ascii(k * 4 + f, 1, ["#..", ".#.", "..#", ".#.", "#.."], { "#": C.white }); }));
def("Placeables", "magnet_pull", 8, [21, 17, 13, 9].map((rx) => { const b = new Img(44, 20); oval(b, 22, 10, rx, Math.round(rx * .45), C.bump, 1); return b; }));
def("Placeables", "spawner_charge", 12, (() => {
	const W = 30, Hh = 20, cell = (fill) => { const b = lit(SETS.mint, 30, 12); b.rect(2, 10 - fill, 26, fill, C.bumpHi); if (fill) b.hline(2, 10 - fill, 26, C.pureWhite); return b; };
	const at = (b, ...rest) => frame(W, Hh, [b, 0, 8], ...rest);
	return [at(cell(0)), at(cell(2)), at(cell(4)), at(cell(7)), frame(W, Hh, [flash(30, 12), 0, 8]), at(hot(SETS.mint), [A.ball, 11, 2]), at(cell(0), [A.ball, 11, 0]), at(cell(0))];
})());
def("Placeables", "sticky_hold", 8, (() => {
	const pad = (h) => lamp(30, h, SETS.mint), P6 = pad(6), P5 = pad(5);
	return [frame(30, 16, [A.ball, 11, 2], [P6, 0, 10]), frame(30, 16, [A.ball, 11, 3], [P5, 0, 11]), frame(30, 16, [A.ball, 10, 3], [P5, 0, 11]), frame(30, 16, [A.ball, 12, 3], [P5, 0, 11]), frame(30, 16, [A.ball, 11, 2], [P6, 0, 10]), frame(30, 16, [A.ball, 11, 2], [P6, 0, 10])];
})());
const portal = (ballSize, flashRing) => { const b = new Img(16, 16); ring(b, 7.5, 7.5, 7, flashRing ? C.pureWhite : SETS.vio.tube); if (ballSize) b.blit(ellipse(ballSize, ballSize), 8 - ballSize / 2, 8 - ballSize / 2); return b; };
def("Placeables", "teleport_in", 12, [portal(8), portal(6), portal(4), portal(2, true)]);
A.place_sticky = lamp(30, 6, SETS.mint);
A.place_magnet = withIcon(lit(SETS.mint), ICONS.magnet, C.white);
A.place_tele = portal(0);
def("Placeables", "teleport_out", 12, [portal(2, true), portal(4), portal(6), portal(8)]);

// -- Placement and selection --
// One ghost pair and hover outline per placeable footprint (native px): brick, bumper, pop bumper, teleporter, sticky pad.
const FOOTPRINTS = [[30, 12], [45, 7], [24, 24], [16, 16], [30, 6]];
for (const [w, h] of FOOTPRINTS) {
	def("Placement and selection", `ghost_march_${w}x${h}`, 8, [0, 1, 2, 3].map((o) => ghost(C.bump, o, w, h)));
	def("Placement and selection", `ghost_invalid_shake_${w}x${h}`, 12, [-1, 1, -1, 1].map((dx, i) => { const f = frame(w, h, [ghost(C.danger, 0, w, h), dx, 0]); if (!(i & 1)) cross(f, w, h, C.danger); return f; }));
	def("Placement and selection", `hover_outline_${w + 4}x${h + 4}`, 8, [0, 1, 2, 3].map((o) => {
		const W = w + 4, H = h + 4, f = new Img(W, H);
		for (let x = 0; x < W; x++) if ((x + o) % 4 < 2) { f.px(x, 0, C.white); f.px(W - 1 - x, H - 1, C.white); }
		for (let y = 0; y < H; y++) if ((y + o + 2) % 4 < 2) { f.px(0, H - 1 - y, C.white); f.px(W - 1, y, C.white); }
		return f;
	}));
}

// -- Effects --
const burst = (s) => { const f0 = frame(16, 16, center(A.fx_spark, 16, 16)); const r = (rr, c, dot) => { const b = new Img(16, 16); sparks(b, rr, c); if (dot) b.px(8, 8, C.pureWhite); return b; }; return [f0, r(3, s.hi, 1), r(5, s.tube, 0), r(7, s.ring, 0), blank(16, 16), blank(16, 16)]; };
def("Effects", "spark_burst", 12, burst({ hi: C.payHi, tube: C.pay, ring: C.payDim }));
def("Effects", "spark_burst_mint", 12, burst(SETS.mint));
def("Effects", "spark_burst_sky", 12, burst(SETS.sky));
// Blank tag, static in frame: the node rises by tween in-engine so a number label can ride on it.
const tagBlank = (() => { const b = new Img(25, 8); b.rect(0, 0, 25, 8, C.pay); b.outline(0, 0, 25, 8, C.cream); b.corners(); return b; })();
def("Effects", "payout_rise", 12, [255, 255, 255, 255, 255, 255, 170, 110, 60, 0].map((a) => tagBlank.fade(a)));
def("Effects", "combo_chase", 8, (() => {
	const path = []; for (let x = 1; x < 29; x++) path.push([x, 0]); for (let y = 1; y < 11; y++) path.push([29, y]); for (let x = 28; x > 0; x--) path.push([x, 11]); for (let y = 10; y > 0; y--) path.push([0, y]);
	return [0, 1, 2, 3, 4, 5, 6, 7].map((f) => { const b = ML.crop(0, 0, 30, 12), p = Math.floor(f * path.length / 8); [[0, C.pureWhite], [1, C.brickHi], [2, C.brickHi], [3, C.brickHi]].forEach(([k, c]) => { const [x, y] = path[(p - k + path.length) % path.length]; b.px(x, y, c); }); return b; });
})());
def("Effects", "halo_pulse", 8, [255, 200, 150, 200].map((a) => A.fx_halo.fade(a)));
def("Effects", "hazard_strip", 8, [0, 1, 2, 3].map((f) => { const b = new Img(32, 4); b.hline(0, 0, 32, C.trimLo); b.hline(0, 3, 32, C.trimLo); for (let i = 0; i < 8; i++) { const k = (i + f) % 4; b.rect(i * 4 + 1, 1, 2, 2, k === 0 ? C.pay : k === 1 ? C.cream : C.payDim); } return b; }));

// -- Ball and paddle --
def("Ball and paddle", "ball_bounce", 12, (() => { const n = A.ball, sq = ellipse(10, 6), st = ellipse(6, 10); return [frame(12, 12, [n, 2, 2]), frame(12, 12, [n, 2, 4]), frame(12, 12, [sq, 1, 6]), frame(12, 12, [st, 3, 0]), frame(12, 12, [n, 2, 0]), frame(12, 12, [n, 2, 0])]; })());
def("Ball and paddle", "ball_trail", 12, [0, 1, 2, 3].map((f) => frame(24, 8, [A.ball, 4 - (f & 1), 0, 60], [A.ball, 10 - (f >> 1), 0, 120], [A.ball, 16, 0])));
def("Ball and paddle", "ball_lost", 12, [frame(12, 12, [A.ball, 2, 2]), frame(12, 12, [ellipse(8, 8, C.danger, C.white), 2, 2]), frame(12, 12, [ellipse(6, 6, C.danger, "7f0000"), 3, 3]), frame(12, 12, [ellipse(4, 4, C.danger, "7f0000"), 4, 4]), frame(12, 12, [ellipse(2, 2, C.danger, C.danger), 5, 5]), blank(12, 12)]);
def("Ball and paddle", "paddle_hit", 12, [C.pureWhite, C.white, C.payHi, C.pay].map((c) => { const b = A.paddle.crop(0, 0, 60, 8); b.hline(6, 4, 48, c); return b; }));

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

// ---- UI: one cabinet chassis (score column, field, pieces column) that every screen lives inside. ----
// Columns at 1x: score 0-77, rail 78-79, field 80-559, rail 560-561, pieces 562-639. Text: 3x5 font, HUD at 2x.
Object.assign(FONT, {
	A: [".#.", "#.#", "###", "#.#", "#.#"], D: ["##.", "#.#", "#.#", "#.#", "##."], E: ["###", "#..", "###", "#..", "###"], F: ["###", "#..", "###", "#..", "#.."],
	G: ["###", "#..", "#.#", "#.#", "###"], H: ["#.#", "#.#", "###", "#.#", "#.#"], I: ["###", ".#.", ".#.", ".#.", "###"], J: ["..#", "..#", "..#", "#.#", "###"],
	K: ["#.#", "#.#", "##.", "#.#", "#.#"], L: ["#..", "#..", "#..", "#..", "###"], N: ["##.", "#.#", "#.#", "#.#", "#.#"], P: ["###", "#.#", "###", "#..", "#.."],
	Q: ["###", "#.#", "#.#", "###", "..#"], R: ["###", "#.#", "##.", "#.#", "#.#"], S: ["###", "#..", "###", "..#", "###"], T: ["###", ".#.", ".#.", ".#.", ".#."],
	U: ["#.#", "#.#", "#.#", "#.#", "###"], V: ["#.#", "#.#", "#.#", "#.#", ".#."], W: ["#.#", "#.#", "###", "###", "#.#"], Y: ["#.#", "#.#", ".#.", ".#.", ".#."],
	Z: ["###", "..#", ".#.", "#..", "###"], "-": ["...", "...", "###", "...", "..."], ".": ["...", "...", "...", "...", ".#."], "/": ["..#", "..#", ".#.", "#..", "#.."],
	"!": [".#.", ".#.", ".#.", "...", ".#."], "'": [".#.", ".#.", "...", "...", "..."], X: ["#.#", "#.#", ".#.", "#.#", "#.#"],
});
const FONT_ORDER = " !$'+,-./0123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZx?";
A.font_3x5 = (() => { const b = new Img(FONT_ORDER.length * 4, 6); [...FONT_ORDER].forEach((ch, i) => text(b, i * 4, 0, ch, C.pureWhite)); return b; })();
// BMFont descriptor so Godot imports the atlas as a FontFile (size 5, line 6, advance 4). Lowercase maps onto the capitals; "x" keeps its own small glyph.
const fnt = (() => {
	const chars = [];
	[...FONT_ORDER].forEach((ch, i) => { for (const c of ch === "x" ? ["x"] : /[A-Z]/.test(ch) ? [ch, ch.toLowerCase()] : [ch]) chars.push(`char id=${c.charCodeAt(0)} x=${i * 4} y=0 width=4 height=6 xoffset=0 yoffset=0 xadvance=4 page=0 chnl=15`); });
	return [`info face="font_3x5" size=5 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0`,
		`common lineHeight=6 base=5 scaleW=${FONT_ORDER.length * 4} scaleH=6 pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4`,
		`page id=0 file="font_3x5.png"`, `chars count=${chars.length}`, ...chars, ""].join("\n");
})();

SETS.pay = { tube: C.pay, ring: C.payDim, deep: C.base, hi: C.payHi, dimTube: C.payDim, dimRing: "443a05" };
// Nine-patch stretch: m px corners stay, edges and glass repeat. Lamp buttons use m=3 (tube, ring, highlight inset).
const nine = (s, w, h, m = 3) => { const o = new Img(w, h), f = (v, n, sn) => v < m ? v : v >= n - m ? sn - (n - v) : m + (v - m) % (sn - 2 * m); for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) o.px(x, y, s.get(f(x, w, s.w), f(y, h, s.h))); return o; };

A.ui_button_mint = lit(SETS.mint, 24, 16);
A.ui_button_mint_hot = hot(SETS.mint, 24, 16);
A.ui_button_mint_dim = dim(SETS.mint, 24, 16);
const chromeBtn = (hover) => { const b = new Img(24, 16); b.rect(0, 0, 24, 16, hover ? C.trimHi : C.trim); b.hline(0, 0, 24, hover ? C.pureWhite : C.chromeHi); b.hline(0, 1, 24, C.chromeMid); b.rect(0, 0, 1, 16, C.chromeMid); b.rect(23, 0, 1, 16, C.chromeLo); b.hline(0, 14, 24, C.chromeLo); b.hline(0, 15, 24, C.trimLo); b.corners(); return b; };
A.ui_button_chrome = chromeBtn(false);
A.ui_button_chrome_hot = chromeBtn(true);
A.ui_panel = (() => { const b = new Img(24, 24); b.rect(0, 0, 24, 24, C.trimLo); b.outline(0, 0, 24, 24, C.rivet); b.outline(1, 1, 22, 22, C.trim); b.hline(3, 2, 18, C.trimHi); b.corners(); return b; })();
A.ui_rail = (() => { const b = new Img(2, 8); b.rect(0, 0, 1, 8, C.rivet); b.rect(1, 0, 1, 8, C.trimHi); return b; })();

// Web node: yellow lamp, icon in rows 3-7, rank pips on row 9. UI never borrows a brick hue.
const nglyph = (rows) => (b, c) => b.ascii(15 - (rows[0].length >> 1), 3 + ((5 - rows.length) >> 1), rows, { "#": c });
const UICONS = {
	paddle: nglyph(["#.....#", "##...##", "#######", "##...##", "#.....#"]), time: nglyph(["#####", ".#.#.", "..#..", ".#.#.", "#####"]), combo: (b, c) => text(b, 12, 3, "C+", c),
	bumper: nglyph(["##...##", "#######", "##...##"]), capacity: nglyph(["##.##.##", "##.##.##", "........", "##.##.##", "##.##.##"]), pop: nglyph([".###.", "#...#", "#...#", "#...#", ".###."]),
	accel: (b, c) => chevrons(b, c), oneway: nglyph(["..#..", ".###.", "#.#.#", "..#..", "#####"]), tele: nglyph([".###.", "#...#", "#.#.#", "#...#", ".###."]),
	sticky: nglyph(["..#..", "..#..", ".....", "#####", "#####"]), spawner: nglyph([".#...", "###..", ".#.#.", "..###", "...#."]), magnet: nglyph(["#...#", "#...#", "#...#", "##.##", ".###."]),
};
const node = (state, icon, rank, ranks) => {
	const b = state === "lit" ? lit(SETS.pay) : state === "hot" ? hot(SETS.pay) : dim(SETS.pay);
	if (icon) icon(b, state === "dim" ? C.payDim : state === "hot" ? C.pureWhite : C.white);
	for (let i = 0; i < ranks; i++) b.rect(15 - ((ranks * 3 - 1) >> 1) + i * 3, 8, 2, 2, i < rank ? (state === "dim" ? C.payDim : C.payHi) : state === "dim" ? "443a05" : C.payDim);
	return b;
};
// Shipped nodes are blank lamps: the game overlays icon_<id> and draws rank pips itself.
A.node_lit = node("lit"); A.node_dim = node("dim"); A.node_max = node("hot");
for (const id in UICONS) A[`icon_${id}`] = (() => { const b = new Img(30, 12); UICONS[id](b, C.white); return b.crop(9, 3, 12, 5); })();

const pip = (s, on) => { const b = new Img(4, 4); if (on) { b.rect(0, 0, 4, 4, s.tube); b.rect(1, 1, 2, 2, s.hi); } else { b.rect(0, 0, 4, 4, s.deep); b.outline(0, 0, 4, 4, s.dimTube); } b.corners(); return b; };
A.ui_pip_on = pip(SETS.mint, true); A.ui_pip_off = pip(SETS.mint, false); A.ui_pip_pay = pip(SETS.pay, true);
A.coin = (() => { const b = ellipse(8, 8, C.payDim, C.pay); text(b, 3, 2, "$", C.base); return b; })();
A.ui_badge = (() => { const b = new Img(9, 7); b.rect(0, 0, 9, 7, C.pay); b.outline(0, 0, 9, 7, C.cream); b.corners(); return b; })();
const hoverOutline = (W, H, o = 0) => { const f = new Img(W, H); for (let x = 0; x < W; x++) if ((x + o) % 4 < 2) { f.px(x, 0, C.white); f.px(W - 1 - x, H - 1, C.white); } for (let y = 0; y < H; y++) if ((y + o + 2) % 4 < 2) { f.px(0, H - 1 - y, C.white); f.px(W - 1, y, C.white); } return f; };
A.ui_slot = (() => { const b = new Img(36, 18); b.rect(0, 0, 36, 18, C.base); b.outline(0, 0, 36, 18, C.trim); b.hline(1, 1, 34, C.trimLo); b.rect(1, 1, 1, 16, C.trimLo); b.corners(); return b; })();
A.ui_slot_hover = (() => { const b = A.ui_slot.crop(0, 0, 36, 18); b.blit(hoverOutline(36, 18), 0, 0); return b; })();
A.ui_cursor = (() => { const b = new Img(8, 8); b.ascii(0, 0, ["#.......", "##......", "#o#.....", "#oo#....", "#ooo#...", "#o##....", "##.#....", "....#..."], { "#": C.chromeLo, "o": C.chromeMid }); b.px(0, 0, C.pay); b.px(1, 1, C.payHi); return b; })();
A.ui_toggle_on = (() => { const b = lit(SETS.mint, 16, 8); b.rect(10, 1, 5, 6, C.chromeMid); b.hline(10, 1, 5, C.chromeHi); b.hline(10, 6, 5, C.rivet); return b; })();
A.ui_toggle_off = (() => { const b = dim(SETS.mint, 16, 8); b.rect(1, 1, 5, 6, C.rivet); b.hline(1, 1, 5, C.chromeMid); b.hline(1, 6, 5, C.trimHi); return b; })();
A.ui_slider_track = (() => { const b = new Img(1, 4); [C.bumpRing, C.bump, C.bump, C.bumpRing].forEach((c, y) => b.px(0, y, c)); return b; })();
A.ui_slider_knob = (() => { const b = new Img(6, 8); [C.chromeHi, C.chromeMid, C.rivet, C.rivet, "7777bb", C.trimHi, C.chromeLo, C.trimLo].forEach((c, y) => b.hline(0, y, 6, c)); b.corners(); return b; })();

// Lamp lettering: rasterize the font at scale k, then paint tube / ring / glass by distance to the stroke edge. Needs k >= 5 for any glass.
const lampText = (s, k, set, hollow = false) => {
	const w = textW(s, k) + 2, h = 5 * k + 2, m = new Img(w, h); text(m, 1, 1, s, C.pureWhite, k);
	const on = (x, y) => x >= 0 && y >= 0 && x < w && y < h && m.get(x, y)[3] > 0;
	const o = new Img(w, h);
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
		if (!on(x, y)) continue;
		const e1 = !(on(x - 1, y) && on(x + 1, y) && on(x, y - 1) && on(x, y + 1));
		const e2 = !(on(x - 2, y) && on(x + 2, y) && on(x, y - 2) && on(x, y + 2));
		const c = e1 ? set.tube : e2 ? set.ring : hollow ? null : !on(x, y - 3) ? set.hi : set.deep;
		if (c) o.px(x, y, c);
	}
	return o;
};
A.title_logo = lampText("BREAKIN", 5, SETS.mag);

// ---- Logo variants: same lamp lettering, different name treatments. ----
const chromeText = (s, k) => {
	const w = textW(s, k) + 2, h = 5 * k + 2, m = new Img(w, h); text(m, 1, 1, s, C.pureWhite, k);
	const on = (x, y) => x >= 0 && y >= 0 && x < w && y < h && m.get(x, y)[3] > 0, band = [C.chromeHi, C.chromeMid, C.rivet, "7777bb", C.trimHi];
	const o = new Img(w, h);
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (on(x, y)) o.px(x, y, on(x - 1, y) && on(x + 1, y) && on(x, y - 1) && on(x, y + 1) ? band[Math.min(4, ((y - 1) / k) | 0)] : C.chromeLo);
	return o;
};
const word = (s, c, k = 1) => { const o = new Img(textW(s, k), 5 * k); text(o, 0, 0, s, c, k); return o; };
const stack = (parts, gap = 3) => { const w = Math.max(...parts.map((p) => p.w)), o = new Img(w, parts.reduce((a, p) => a + p.h + gap, -gap)); let y = 0; for (const p of parts) { o.blit(p, (w - p.w) >> 1, y); y += p.h + gap; } return o; };
const row = (parts, gap = 6) => { const h = Math.max(...parts.map((p) => p.h)), o = new Img(parts.reduce((a, p) => a + p.w + gap, -gap), h); let x = 0; for (const p of parts) { o.blit(p, x, (h - p.h) >> 1); x += p.w + gap; } return o; };
const LOGOS = {
	lamp: stack([A.title_logo, word("CREMENTAL", C.pay, 2)]),
	twotone: stack([row([lampText("BREAK", 5, SETS.mag), lampText("IN", 5, SETS.pay)]), word("CREMENTAL", C.cream, 2)]),
	tower: stack([lampText("BREAK", 5, SETS.mag), lampText("IN", 5, SETS.pay), lampText("CREMENTAL", 5, SETS.mint)], 2),
	neon: lampText("BREAKINCREMENTAL", 4, SETS.mint, true),
	sign: (() => { const o = nine(A.ui_panel, 160, 66); for (let x = 0; x < 160; x += 32) { o.blit(ANIM.hazard_strip.frames[(x >> 5) & 3], x, 0); o.blit(ANIM.hazard_strip.frames[(x >> 5) & 3], x, 58); } const t = stack([chromeText("BREAKIN", 5), word("CREMENTAL", C.pay, 2)]); o.blit(t, (160 - t.w) >> 1, 11); return o; })(),
	breakin: stack([lampText("BREAKIN'", 5, SETS.mag), word("CREMENTAL", C.pay, 2)]),
	hyphen: stack([lampText("BREAK-IN", 5, SETS.sky), word("CREMENTAL", C.pay, 2)]),
	oneline: lampText("BREAK IN CREMENTAL", 5, SETS.pay),
};
// Split: BREAKIN on one line with BREAK in treatment a, IN and CREMENTAL in treatment b. a/b = (text, k) => Img.
const split = (a, b) => stack([row([a("BREAK", 6), b("IN", 6)], 4), b("CREMENTAL", 5)], 4);
const lampOf = (set) => (s, k) => lampText(s, k, set), neonOf = (set) => (s, k) => lampText(s, k, set, true);
Object.assign(LOGOS, {
	split_lamp_neon: split(lampOf(SETS.mag), neonOf(SETS.mint)),
	split_neon_lamp: split(neonOf(SETS.mag), lampOf(SETS.mint)),
	split_pay_neon: split(lampOf(SETS.pay), neonOf(SETS.mag)),
	split_mint_pay: split(neonOf(SETS.mint), lampOf(SETS.pay)),
	split_mag_pay: split(lampOf(SETS.mag), neonOf(SETS.pay)),
	split_pay_mint: split(neonOf(SETS.pay), lampOf(SETS.mint)),
});
A.title_logo = LOGOS.split_mag_pay; // the chosen one; the game loads this file. The rest only appear as cards on ui.html.

// ---- UI mock screens, 640x360. Three columns: score 0-79, field 80-559, pieces 562-639, rails between. ----
const btn = (m, x, y, w, h, kind, s, k = 2, c = C.white) => { m.blit(nine(A[kind], w, h), x, y); text(m, x + ((w - textW(s, k)) >> 1), y + ((h - 5 * k) >> 1), s, c, k); };
const RX = 562; // right column origin; left is 0. Text inset 6, so 68px of text per column.
const chassis = () => {
	const m = new Img(640, 360); m.rect(0, 0, 640, 360, C.base);
	for (let y = 10; y < 360; y += 10) for (let x = 90; x < 560; x += 10) m.px(x, y, C.trim);
	const rr = A.ui_rail.flipX(); for (let y = 0; y < 360; y += 8) { m.blit(A.ui_rail, 78, y); m.blit(rr, 560, y); }
	return m;
};
const col = (m, x, title) => { m.blit(nine(A.ui_panel, 78, 360), x, 0); if (title) { text(m, x + 39 - (textW(title) >> 1), 6, title, C.rivet); m.hline(x + 3, 14, 72, C.rivet); } };
const cash = (m, x, s) => { m.blit(A.coin, x + 6, 22); text(m, x + 16, 23, "CASH", C.rivet); text(m, x + 6, 32, s, C.pay, 2); };
const hud = (m, { money, extra, combo, bar, time, danger, best }) => {
	col(m, 0, "SCORE"); cash(m, 0, money); if (extra) text(m, 6, 44, extra, C.cream);
	text(m, 6, 60, "COMBO", C.rivet); text(m, 6, 68, combo, combo === "-" ? C.rivet : C.pay, 4);
	m.rect(6, 92, 68, 3, C.trimLo); if (bar) m.rect(6, 92, Math.round(68 * bar), 3, C.pay);
	text(m, 6, 104, "TIME", C.rivet); text(m, 6, 112, time, danger ? C.danger : C.cream, 3);
	if (best) text(m, 6, 134, `BEST ${best}`, C.rivet);
};
const PIECES = () => [[A.bumper, 2], [ANIM.pop_bumper_hit.frames[4], 1], [A.place_sticky, 1], [A.place_magnet, 0], [A.place_tele, 2]];
const tray = (m, { sel, cap, locked }) => {
	col(m, RX, "PIECES");
	PIECES().forEach(([p, n], i) => { const x = RX + 22, y = 22 + i * 22; m.blit(sel === i ? A.ui_slot_hover : A.ui_slot, x, y); m.blit(n && !locked ? p : p.fade(70), x + 18 - (p.w >> 1), y + 9 - (p.h >> 1)); if (n) { m.blit(A.ui_badge, x + 30, y - 3); text(m, x + 33, y - 2, String(n), C.base); } });
	text(m, RX + 6, 136, "CAP", C.rivet); text(m, RX + 24, 136, `${cap}/8`, C.white); for (let i = 0; i < 8; i++) m.blit(i < cap ? A.ui_pip_on : A.ui_pip_off, RX + 6 + i * 6, 144);
	if (locked) { text(m, RX + 6, 160, "LOCKED", C.rivet); return; }
	["LMB PICK/DROP", "R ROTATE", "RMB REMOVE", "ESC PAUSE"].forEach((s, i) => text(m, RX + 6, 160 + i * 8, s, C.rivet));
	btn(m, RX + 6, 300, 66, 24, "ui_button_mint", "START"); text(m, RX + 39 - (textW("SPACE") >> 1), 328, "SPACE", C.rivet);
};
const centreText = (m, y, s, c, k = 2) => text(m, 320 - (textW(s, k) >> 1), y, s, c, k);
const bulbs = (m, y) => { for (let x = 80; x < 560; x += 32) m.blit(ANIM.hazard_strip.frames[(x >> 5) & 3], x, y); };
const dashLine = (m, x0, y0, x1, y1, c) => { const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0), 1); for (let i = 0; i <= n; i++) if (i % 5 < 3) m.px(Math.round(x0 + (x1 - x0) * i / n), Math.round(y0 + (y1 - y0) * i / n), c); };
const pickBrick = (r, c) => {
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
const fieldBricks = (m, y0, rows = 7) => { const cols = 14, bw = 32, x0 = 320 - (cols * bw) / 2; for (let r = 0; r < rows; r++) for (let i = 0; i < cols - r * 2; i++) { const c = r + i; if ((r * 5 + c * 11) % 17 === 0) continue; m.blit(A[pickBrick(r, c)], x0 + c * bw, y0 + r * 14); } return x0; };
const breakFx = (m, fx, fy) => {
	m.blit(A.fx_halo, fx - 15, fy - 9); m.blit(A.brick_plain_flash, fx, fy);
	for (const [dx, dy] of [[-6, -5], [34, -4], [10, 15], [26, 13]]) m.blit(A.fx_spark, fx + dx, fy + dy);
	for (const [dx, dy] of [[-9, 3], [33, 1], [15, 16]]) m.blit(A.fx_debris, fx + dx, fy + dy);
	m.blit(A.fx_payout_tag, fx + 4, fy - 12);
};
const placed = (m) => { m.blit(A.bumper.rotated(-15), 140, 200); m.blit(A.bumper.rotated(15), 430, 212); m.blit(A.place_magnet, 305, 176); };
const MOCK = {};
MOCK.menu = (() => {
	const m = chassis(); col(m, 0); col(m, RX);
	bulbs(m, 4);
	m.blit(A.title_logo, 320 - (A.title_logo.w >> 1), 50);
	m.blit(nine(A.ui_panel, 160, 82), 240, 140);
	[["PLAY", "ui_button_mint_hot"], ["SETTINGS", "ui_button_chrome"], ["QUIT", "ui_button_chrome"]].forEach(([s, k], i) => btn(m, 260, 150 + i * 24, 120, 18, k, s)); m.blit(A.ui_cursor, 330, 160);
	centreText(m, 232, "BEST $486   RUNS 14   LEVEL 3", C.rivet, 1);
	centreText(m, 300, "BUILD THE BOARD. BREAK THE BOARD.", C.rivet, 1);
	for (let i = 0; i < 6; i++) m.blit(i % 3 ? A.brick_plain_dim : A.brick_plain_lit, 230 + i * 32, 330);
	return m;
})();
MOCK.shop = (() => {
	const m = chassis(); col(m, 0, "STATS"); cash(m, 0, "1,248");
	const R = { paddle: [3, 3], time: [2, 3], bumper: [1, 3], combo: [1, 3], capacity: [1, 5], pop: [0, 3], accel: [0, 3], sticky: [0, 2], magnet: [0, 2] };
	text(m, 6, 52, "OWNED", C.rivet); Object.entries(R).filter(([, [r]]) => r).forEach(([id, [r, n]], i) => { text(m, 6, 60 + i * 8, ({ capacity: "CAP" })[id] ?? id.toUpperCase(), C.white); text(m, 56, 60 + i * 8, `${r}/${n}`, r >= n ? C.pay : C.cream); });
	btn(m, 6, 316, 66, 14, "ui_button_chrome", "RESET", 1); btn(m, 6, 334, 66, 14, "ui_button_chrome", "MENU", 1);
	centreText(m, 6, "UPGRADE WEB", C.rivet, 1);
	const P = { paddle: [320, 420], time: [210, 300], combo: [210, 170], bumper: [430, 300], capacity: [430, 170], pop: [530, 300], accel: [530, 170], sticky: [430, 440], magnet: [320, 170] };
	const at = (id) => [Math.round(96 + (P[id][0] - 210) * 1.4), Math.round(40 + (P[id][1] - 170) * 280 / 270)];
	const L = [["paddle", "time"], ["paddle", "bumper"], ["time", "combo"], ["bumper", "capacity"], ["bumper", "pop"], ["bumper", "sticky"], ["capacity", "accel"], ["capacity", "magnet"]];
	for (const [a, b] of L) { const [x0, y0] = at(a), [x1, y1] = at(b); dashLine(m, x0, y0, x1, y1, R[a][0] && R[b][0] ? C.pay : C.payDim); }
	for (const id in P) { const [x, y] = at(id), [r, n] = R[id]; m.blit(node(r >= n ? "hot" : r ? "lit" : "dim", UICONS[id], r, n), x - 15, y - 6); }
	const [hx, hy] = at("capacity"); m.blit(hoverOutline(34, 16), hx - 17, hy - 8); m.blit(A.ui_cursor, hx + 8, hy + 3);
	col(m, RX, "UPGRADE");
	m.blit(node("lit", UICONS.capacity, 1, 5), RX + 24, 20);
	text(m, RX + 6, 36, "CAPACITY", C.white, 2); text(m, RX + 6, 50, "+2 CAPACITY", C.rivet); text(m, RX + 6, 58, "PER RANK", C.rivet);
	text(m, RX + 6, 70, "RANK", C.rivet); for (let i = 0; i < 5; i++) m.blit(i < 1 ? A.ui_pip_pay : A.ui_pip_off, RX + 28 + i * 6, 70);
	m.blit(A.coin, RX + 6, 84); text(m, RX + 18, 82, "30", C.pay, 2);
	btn(m, RX + 6, 98, 66, 18, "ui_button_mint", "BUY"); btn(m, RX + 6, 120, 66, 14, "ui_button_chrome", "BUY MAX", 1);
	m.hline(RX + 3, 142, 72, C.rivet); text(m, RX + 6, 148, "LEVEL", C.rivet);
	[["1", "ui_button_chrome"], ["2", "ui_button_chrome"], ["3", "ui_button_chrome_hot"]].forEach(([s, k], i) => btn(m, RX + 6 + (i % 2) * 35, 158 + (i >> 1) * 22, 31, 18, k, s));
	m.blit(nine(A.ui_button_chrome, 31, 18), RX + 41, 180); text(m, RX + 53, 185, "4", C.trimHi, 2);
	["LEVEL 3", "16 x 7 GRID", "60 SECONDS"].forEach((s, i) => text(m, RX + 6, 206 + i * 8, s, i ? C.rivet : C.white));
	btn(m, RX + 6, 300, 66, 24, "ui_button_mint", "PLAY"); text(m, RX + 39 - (textW("SPACE") >> 1), 328, "SPACE", C.rivet);
	return m;
})();
MOCK.place = (() => {
	const m = chassis(); hud(m, { money: "1,248", combo: "-", time: "0:32", best: "x12" }); tray(m, { sel: 0, cap: 5 });
	centreText(m, 6, "PLACE PIECES", C.rivet, 1);
	fieldBricks(m, 16, 5); placed(m);
	m.blit(A.ghost_valid, 300, 240); m.blit(A.ui_cursor, 316, 246);
	for (let x = 82; x < 558; x += 6) m.rect(x, 280, 3, 1, C.bump, 160);
	return m;
})();
MOCK.play = (() => {
	const m = chassis(); hud(m, { money: "1,248", extra: "+86", combo: "x7", bar: 0.6, time: "0:04", danger: true, best: "x12" }); tray(m, { cap: 5, locked: true });
	const x0 = fieldBricks(m, 16); breakFx(m, x0 + 5 * 32, 16 + 7 * 14); placed(m);
	for (let i = 1; i <= 4; i++) m.rect(318 - i * 7, 299 + i * 5, 2, 2, C.pay, 160 - i * 35);
	m.blit(A.ball, 315, 295); m.blit(A.paddle, 290, 336);
	bulbs(m, 352);
	return m;
})();
MOCK.result = (() => {
	const m = MOCK.play.crop(0, 0, 640, 360); m.rect(0, 0, 640, 360, C.base, 150); bulbs(m, 4);
	m.blit(nine(A.ui_panel, 240, 112), 200, 118);
	centreText(m, 128, "ROUND CLEARED", C.cream, 1); centreText(m, 140, "+486", C.pay, 4); centreText(m, 166, "x12 BEST COMBO", C.white, 1); centreText(m, 176, "LEVEL 4 UNLOCKED", C.bump, 1);
	btn(m, 272, 194, 96, 20, "ui_button_mint", "CONTINUE");
	for (const [x, y] of [[196, 114], [438, 116], [198, 230], [440, 228]]) m.blit(A.fx_spark, x, y);
	return m;
})();
MOCK.pause = (() => {
	const m = MOCK.play.crop(0, 0, 640, 360); m.rect(0, 0, 640, 360, C.base, 180);
	m.blit(nine(A.ui_panel, 160, 110), 240, 110); centreText(m, 120, "PAUSED", C.pay);
	[["RESUME", "ui_button_mint"], ["SETTINGS", "ui_button_chrome"], ["MENU", "ui_button_chrome"]].forEach(([s, k], i) => btn(m, 260, 140 + i * 24, 120, 18, k, s));
	return m;
})();
MOCK.settings = (() => {
	const m = chassis(); col(m, 0); col(m, RX); centreText(m, 60, "SETTINGS", C.pay);
	text(m, 220, 104, "FULLSCREEN", C.white); m.blit(A.ui_toggle_on, 380, 102);
	text(m, 220, 128, "VOLUME", C.white); for (let x = 300; x < 396; x++) m.blit(A.ui_slider_track, x, 128); m.blit(A.ui_slider_knob, 364, 126);
	btn(m, 260, 160, 120, 18, "ui_button_chrome", "BACK");
	return m;
})();

mkdirSync("assets/pixel/png", { recursive: true });
mkdirSync("assets/pixel/tmp", { recursive: true });
mkdirSync("assets/pixel/preview", { recursive: true });
const toPng = (img, out, scale = 1) => {
	writeFileSync("assets/pixel/tmp/x.pam", img.pam());
	execSync(`magick assets/pixel/tmp/x.pam ${scale > 1 ? `-scale ${scale * 100}%` : ""} -define png:color-type=6 ${out}`);
};
for (const [n, img] of Object.entries(A)) toPng(img, `assets/pixel/png/${n}.png`);
writeFileSync("assets/pixel/png/font_3x5.fnt", fnt);
for (const [n, a] of Object.entries(ANIM)) toPng(strip(a.frames), `assets/pixel/png/anim_${n}.png`);
toPng(board(), "assets/pixel/preview/look.png", 2);
for (const [n, img] of Object.entries(MOCK)) toPng(img, `assets/pixel/preview/ui_${n}.png`, 2);
const logoCard = (l) => { const m = new Img(l.w + 32, l.h + 24); m.rect(0, 0, m.w, m.h, C.base); for (let y = 6; y < m.h; y += 10) for (let x = 6; x < m.w; x += 10) m.px(x, y, C.trim); m.blit(l, 16, 12); return m; };
for (const [n, l] of Object.entries(LOGOS)) toPng(logoCard(l), `assets/pixel/preview/logo_${n}.png`, 3);
execSync("rm -r assets/pixel/tmp");

// ---- Demo page ----
const uri = (n) => `data:image/png;base64,${readFileSync(`assets/pixel/png/${n}.png`).toString("base64")}`;
const GROUPS = [
	["Plain brick", ["brick_plain_lit", "brick_plain_dim", "brick_plain_flash"]],
	["Multi-hit", ["brick_multi_full", "brick_multi_cracked"]],
	["Icon bricks", ["brick_icon_multiball", "brick_icon_x2"]],
	["Conditional", ["brick_cond_speed_idle", "brick_cond_speed_primed"]],
	["Solid", ["brick_solid"]],
	["Placeables", ["bumper", "place_sticky", "place_magnet", "place_tele", "ghost_valid", "ghost_invalid"]],
	["Ball and paddle", ["ball", "paddle"]],
	["Effects", ["fx_halo", "fx_spark", "fx_debris", "fx_payout_tag"]],
];
const cardsFor = (groups) => groups.map(([title, names]) => `<section><h2>${title}</h2><div class="row">${names.map((n) =>
	`<figure><div class="tile"><img src="${uri(n)}" width="${A[n].w}" height="${A[n].h}" alt="${n}"></div><figcaption>${n}<span>${A[n].w}×${A[n].h}</span></figcaption></figure>`
).join("")}</div></section>`).join("");
const cards = cardsFor(GROUPS);
const animCard = (n) => {
	const a = ANIM[n], { w, h } = a.frames[0], k = a.frames.length;
	return `<figure><div class="tile"><div class="anim" style="--fw:${w}px;--fh:${h}px;--n:${k};--fps:${a.fps};background-image:url(${uri("anim_" + n)})"></div></div><div class="tile"><img src="${uri("anim_" + n)}" width="${w * k}" height="${h}" alt="${n} strip"></div><figcaption>anim_${n}<span>${w}×${h} · ${k}f · ${a.fps}fps</span></figcaption></figure>`;
};
const anims = `<section id="anims"><h2>Animations</h2><p class="lede">${Object.keys(ANIM).length} animations looping at the frame rate noted. The strip under each is the exported sprite sheet; held frames are repeated in the strip, in-engine they would be a hold time instead. Grouped as in docs/animations.md.</p>${AGROUPS.map(([t, names]) => `<h3>${t}</h3><div class="row">${names.map(animCard).join("")}</div>`).join("")}</section>`;
const HEAD = `<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Silkscreen&family=IBM+Plex+Sans:wght@400;600&display=swap">
<style>
/* Layout: 2x mockup on top, sprite groups in wrapping rows, sticky zoom. Single dark theme: it is the game's screen. */
:root{--bg:#${C.base};--panel:#0a0a33;--trim:#${C.trim};--fg:#${C.white};--muted:#${C.rivet};--accent:#${C.pay};--pink:#${C.brick};--mint:#${C.bump};
--display:"Silkscreen",monospace;--body:"IBM Plex Sans",system-ui,sans-serif;--z:4;color-scheme:dark}
body{background:var(--bg);color:var(--fg);font:15px/1.5 var(--body);padding-block:24px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
h1{font:22px var(--display);color:var(--accent);margin:0 0 4px;text-shadow:0 0 12px #${C.pay}88;text-wrap:balance}
h2{font:12px var(--display);color:var(--pink);margin:0 0 10px}
h3{font:600 13px var(--body);color:var(--muted);margin:18px 0 8px;text-transform:uppercase;letter-spacing:.08em}
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
.screen{margin-bottom:36px}
.screen h2{font-size:14px;color:var(--accent)}
.screen p{color:var(--muted);margin:0 0 12px;max-width:65ch}
.screen p b{color:var(--fg);font-weight:600}
.screen img.board{margin-bottom:0}
.zones{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px;margin:0 0 28px}
.zones div{background:var(--panel);border:1px solid var(--trim);padding:12px 14px}
.zones b{display:block;font:12px var(--display);color:var(--mint);margin-bottom:4px}
.zones span{color:var(--muted);font-size:13px}
nav{display:flex;gap:6px 14px;flex-wrap:wrap;margin-bottom:24px}
.logo{max-width:100%}.logo img{border:1px solid var(--trim);max-width:100%;height:auto}.logo figcaption{display:block;max-width:40ch;line-height:1.4}.logo b{display:block;color:var(--mint);font:12px var(--display);margin-bottom:2px}
nav a{color:var(--mint);font-size:13px;text-transform:uppercase;letter-spacing:.08em;text-decoration:none;border-bottom:1px solid transparent}
nav a:hover,nav a:focus-visible{border-color:var(--mint);outline:none}
</style>`;
const html = `<title>BreakIn cremental Pixel Sprites</title>
${HEAD}
<h1>BreakIn cremental Pixel Sprites</h1>
<p class="lede">Pachinko lamp look as pixel art on a 2× canvas (640×360). One sprite pixel is two screen pixels in game. Sizes below are native pixels. Glow in-engine comes from a shader; the bumpers in the mockup show what nearest-neighbour rotation does to pixel art.</p>
<img class="board" src="data:image/png;base64,${readFileSync("assets/pixel/preview/look.png").toString("base64")}" width="1280" height="720" alt="Mockup of a full arena at 2x">
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

// ---- UI preview page: the cabinet layout as mock screens, then the UI sprites that build it. ----
const SCREENS = [
	["menu", "Main menu", "The cabinet is the chassis of every screen: a riveted <b>score column</b> on the left, the peg-board field in the middle, a <b>pieces column</b> on the right, rails between. The menu shows it idle: records on the left, the <b>lamp lettering</b> logo in the field, the button column on the right where every screen's actions live. The hovered button is the <b>hot</b> state; the cursor is a chrome arrow with a lit tip."],
	["shop", "Shop: upgrade web", "The web fills the field. Nodes are <b>yellow lamps</b> with an icon in the glass and rank pips along the bottom row: dim when revealed, lit when owned, hot when maxed. Links light up between two owned nodes. The left column lists cash and owned ranks, with Reset and Menu at the bottom. Hovering a node writes its name, effect, rank and cost into the <b>right column</b>, with Buy under it. Level select and Play sit in the same column, so the player always looks to the same place to act."],
	["place", "Round: placement", "Left column is the <b>HUD</b>: cash, combo, timer idle, best combo. The board sits at the top of the field, the placement line is the dashed mint row at 280. The right column is the <b>tray</b>: real piece sprites in slots with a count badge, the selected slot outlined, capacity as pips, controls, Start as one big mint button with its key under it."],
	["play", "Round: play", "The tray locks and dims, the paddle owns the field's bottom. The HUD counts: this round's earnings under cash, combo big in payout yellow with its bar under it, timer going danger-red near zero. Nothing in the field but the game."],
	["result", "Round: result", "The arena dims under a panel built from the same nine-patch as the columns. The payout is the headline at 4x, then the best combo and what unlocked. Bulbs chase along the top of the field while the readout shows."],
	["pause", "Pause", "Esc dims the arena and drops the menu column into a small panel. Nothing else changes, so resuming is instant."],
	["settings", "Settings", "A toggle and a slider in the same lamp language: a mint lamp switch with a chrome knob, a mint tube track with a chrome knob."],
];
const UI_GROUPS = [
	["Font", ["font_3x5"]],
	["Buttons (24x16 nine-patch, 3px margins)", ["ui_button_mint", "ui_button_mint_hot", "ui_button_mint_dim", "ui_button_chrome", "ui_button_chrome_hot"]],
	["Chassis", ["ui_rail", "ui_panel"]],
	["Web", ["node_dim", "node_lit", "node_max", ...Object.keys(UICONS).map((k) => `icon_${k}`)]],
	["Tray and HUD", ["ui_slot", "ui_slot_hover", "ui_badge", "ui_pip_on", "ui_pip_off", "ui_pip_pay", "coin", "ui_cursor"]],
	["Settings", ["ui_toggle_on", "ui_toggle_off", "ui_slider_track", "ui_slider_knob"]],
	["Menu", ["title_logo"]],
];
const LOGO_NOTES = [
	["lamp", "Lamp", "The first draft. BREAKIN as a magenta lamp tube, CREMENTAL in payout yellow under it."],
	["twotone", "Two-tone", "BREAK magenta, IN payout yellow: the pun split by colour. CREMENTAL in cream so the yellow stays the accent."],
	["tower", "Tower", "Three stacked lamps, one hue each, like a pachinko parlour sign. Tallest, fits the field as a splash."],
	["neon", "Neon", "One word, BREAKINCREMENTAL, as a hollow mint tube. Reads as neon rather than lamp; the smallest at 4x."],
	["sign", "Marquee sign", "Chrome lettering on a riveted panel between two bulb strips. The same parts as the columns, so it can be the cabinet header or a loading card."],
	["breakin", "Breakin' Cremental", "Name variant: the apostrophe makes the verb explicit, breakin' bricks."],
	["hyphen", "Break-In Cremental", "Name variant: hyphenated and sky blue, reads as a heist."],
	["oneline", "Marquee line", "BREAK IN CREMENTAL as one payout-yellow lamp line: a header strip rather than a stacked mark."],
	["split_lamp_neon", "Split: magenta lamp, mint neon", "BREAK as a solid magenta lamp; IN and CREMENTAL as a mint neon tube."],
	["split_neon_lamp", "Split: magenta neon, mint lamp", "The inverse: BREAK as a hollow magenta tube; IN and CREMENTAL as solid mint lamps."],
	["split_pay_neon", "Split: yellow lamp, magenta neon", "BREAK as a yellow lamp; IN and CREMENTAL as magenta neon."],
	["split_mint_pay", "Split: mint neon, yellow lamp", "BREAK as a mint tube; IN and CREMENTAL as solid yellow lamps."],
	["split_mag_pay", "Split: magenta lamp, yellow neon (chosen)", "BREAK as a magenta lamp; IN and CREMENTAL as yellow neon. This is title_logo, shown on the menu mock above."],
	["split_pay_mint", "Split: yellow neon, mint lamp", "BREAK as a yellow tube; IN and CREMENTAL as solid mint lamps."],
];
const logos = LOGO_NOTES.map(([n, t, d]) => `<figure class="logo"><img src="data:image/png;base64,${readFileSync(`assets/pixel/preview/logo_${n}.png`).toString("base64")}" width="${(LOGOS[n].w + 32) * 3}" height="${(LOGOS[n].h + 24) * 3}" alt="${t} logo"><figcaption><b>${t}</b>${d}</figcaption></figure>`).join("");
const screens = SCREENS.map(([n, t, d]) => `<section class="screen" id="${n}"><h2>${t}</h2><p>${d}</p><img class="board" src="data:image/png;base64,${readFileSync(`assets/pixel/preview/ui_${n}.png`).toString("base64")}" width="1280" height="720" alt="${t} mock screen"></section>`).join("");
const uiHtml = `<title>BreakIn cremental UI Preview</title>
${HEAD}
<h1>BreakIn cremental UI Preview</h1>
<p class="lede">Proposed layout: one pachinko cabinet that every screen lives inside, split into three columns. Mock screens are rendered from the real sprite generator at 640×360, shown at 2× like the game. Text is the 3×5 font, HUD size is 2×.</p>
<nav>${SCREENS.map(([n, t]) => `<a href="#${n}">${t}</a>`).join("")}<a href="#logos">Logos</a><a href="#sprites">Sprites</a></nav>
<div class="zones"><div><b>Score · 0–160</b><span>Cash, round earnings, combo with its bar, timer, best combo. Stats and Reset/Menu in the shop.</span></div><div><b>Field · 160–1120</b><span>The board in a round, the upgrade web in the shop. 960 wide: a 16-column level at 60px bricks fits exactly.</span></div><div><b>Pieces · 1120–1280</b><span>Tray, capacity and Start in placement; node detail, Buy, level select and Play in the shop; locked during play.</span></div></div>
${screens}
<section id="logos"><h2 style="font-size:14px;color:var(--accent)">Logo and name variants</h2><p class="lede">Treatments of the same lamp lettering at 3×. The first five keep the name, the next three try other spellings, the last six set BREAKIN on one line with BREAK in one treatment and IN in another, then CREMENTAL under it in IN's treatment.</p><div class="row">${logos}</div></section>
<section id="sprites"><h2 style="font-size:14px;color:var(--accent)">UI sprites</h2><p class="lede">Everything the screens above are built from, at native size. Buttons and the panel are nine-patches: 3px corners stay fixed, edges and glass repeat.</p>
<div class="bar"><span>Zoom</span><button data-z="2">2×</button><button data-z="4" aria-pressed="true">4×</button><button data-z="8">8×</button></div>
${cardsFor(UI_GROUPS)}</section>
<script>
document.querySelectorAll(".tile img").forEach(i=>i.style.setProperty("--w",i.getAttribute("width")+"px"));
document.querySelectorAll(".bar button").forEach(b=>b.onclick=()=>{
	document.querySelectorAll(".bar button").forEach(x=>x.setAttribute("aria-pressed",x===b));
	document.documentElement.style.setProperty("--z",b.dataset.z);
});
</script>`;
writeFileSync("assets/pixel/preview/ui.html", uiHtml);
console.log(`${Object.keys(A).length} pixel assets + look.png + assets.html + ${Object.keys(MOCK).length} ui mocks + ${Object.keys(LOGOS).length} logos + ui.html`);
