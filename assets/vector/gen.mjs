// Generates assets/vector/svg/*.svg and assets/vector/png/*.png (4x) plus assets/vector/look.png mockup.
// Run: node assets/vector/gen.mjs   (needs ImageMagick `magick` with librsvg)
// Colors come from docs/palette.md. Sizes are 1x (see src/tuning.gd).
import { writeFileSync, mkdirSync } from "node:fs";
import { execSync } from "node:child_process";

const C = {
	base: "#000020", trim: "#2e2e5c", trimHi: "#5454a7", trimLo: "#21224e", rivet: "#9797d5",
	pay: "#ffff00", payDim: "#887809", gold: "#ebdb57",
	brick: "#ff4aff", brickDim: "#790079", brickDeep: "#350035",
	bump: "#15f2b0", bumpDim: "#027354", bumpDeep: "#01563f",
	danger: "#ff0000", dangerDim: "#7f0000",
	white: "#ffffcf", cream: "#ebde81",
	orange: "#ff7500", violet: "#7f16ff", sky: "#4fc7ff",
};

const DEFS = `<defs>
<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2"/></filter>
<filter id="glowBig" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="5"/></filter>
<linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
<linearGradient id="chrome" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e7e7ff"/><stop offset=".45" stop-color="#9797d5"/><stop offset=".5" stop-color="#5454a7"/><stop offset="1" stop-color="#7777bb"/></linearGradient>
<radialGradient id="halo"><stop offset="0" stop-color="${C.brick}" stop-opacity=".7"/><stop offset="1" stop-color="${C.brick}" stop-opacity="0"/></radialGradient>
</defs>`;

const svg = (w, h, body) =>
	`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${DEFS}${body}</svg>`;

// Lamp brick: neon tube outline + dark glass + gloss. The core look.
function lamp(w, h, hue, deep, { lit = true, inner = "", rx = 4, glowOn = true } = {}) {
	const x = 2, y = 2, bw = w - 4, bh = h - 4;
	const tube = lit ? hue : deep;
	const glow = lit && glowOn ? `<rect x="${x}" y="${y}" width="${bw}" height="${bh}" rx="${rx}" fill="none" stroke="${hue}" stroke-width="3" filter="url(#glow)" opacity=".9"/>` : "";
	return `${glow}
<rect x="${x}" y="${y}" width="${bw}" height="${bh}" rx="${rx}" fill="${C.base}" stroke="${tube}" stroke-width="2"/>
<rect x="${x + 2}" y="${y + 2}" width="${bw - 4}" height="${bh - 4}" rx="${rx - 1}" fill="${hue}" opacity="${lit ? .38 : .08}"/>
${inner}
<rect x="${x + 4}" y="${y + 2}" width="${bw - 8}" height="${Math.max(3, bh * .3)}" rx="2" fill="url(#gloss)" opacity="${lit ? 1 : .35}"/>`;
}

// Icons drawn in brick-local coords, centered at (30,12) for a 60x24 brick.
const ICON = {
	multiball: `<g fill="${C.white}"><circle cx="24" cy="12" r="3.2"/><circle cx="36" cy="12" r="3.2"/><circle cx="30" cy="7" r="3.2"/></g>`,
	x2: `<text x="30" y="17" text-anchor="middle" font-family="Arial Black,Arial" font-weight="900" font-size="13" fill="${C.pay}" stroke="${C.base}" stroke-width=".6">×2</text>`,
	speed: `<g fill="none" stroke="${C.white}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 7l5 5-5 5"/><path d="M27 7l5 5-5 5"/><path d="M34 7l5 5-5 5"/></g>`,
	pips2: `<g><circle cx="26" cy="19" r="1.6" fill="${C.pay}"/><circle cx="34" cy="19" r="1.6" fill="${C.pay}"/></g>`,
	pips1: `<g><circle cx="26" cy="19" r="1.6" fill="${C.pay}"/><circle cx="34" cy="19" r="1.6" fill="${C.payDim}"/></g>`,
	crack: `<path d="M22 4l6 7-3 4 5 7M38 4l-4 6 3 3-4 8" fill="none" stroke="${C.white}" stroke-width="1.4" stroke-linejoin="round" opacity=".8"/>`,
};

const A = {};

// Plain brick states
A.brick_plain_lit = svg(60, 24, lamp(60, 24, C.brick, C.brickDim));
A.brick_plain_dim = svg(60, 24, lamp(60, 24, C.brick, C.brickDim, { lit: false }));
A.brick_plain_flash = svg(60, 24, lamp(60, 24, C.white, C.white) + `<rect x="4" y="4" width="52" height="16" rx="3" fill="${C.white}" opacity=".85"/>`);

// Multi-hit
A.brick_multi_full = svg(60, 24, lamp(60, 24, C.brick, C.brickDim, { inner: ICON.pips2 }));
A.brick_multi_cracked = svg(60, 24, lamp(60, 24, C.brick, C.brickDim, { inner: ICON.pips1 + ICON.crack }));

// Icon bricks (plain hue + icon)
A.brick_icon_multiball = svg(60, 24, lamp(60, 24, C.brick, C.brickDim, { inner: ICON.multiball }));
A.brick_icon_x2 = svg(60, 24, lamp(60, 24, C.brick, C.brickDim, { inner: ICON.x2 }));

// Conditional: speed gate, dim until primed
A.brick_cond_speed_idle = svg(60, 24, lamp(60, 24, C.sky, "#155386", { lit: false, inner: ICON.speed }));
A.brick_cond_speed_primed = svg(60, 24, lamp(60, 24, C.sky, "#155386", { inner: ICON.speed }));

// Solid: chrome bevel, no lamp
A.brick_solid = svg(60, 24, `
<rect x="2" y="2" width="56" height="20" rx="2" fill="#414183" stroke="${C.trimLo}" stroke-width="2"/>
<rect x="3" y="3" width="54" height="2" fill="${C.rivet}"/>
<rect x="3" y="19" width="54" height="2" fill="${C.trimLo}"/>
<g fill="${C.rivet}"><circle cx="7" cy="12" r="1.5"/><circle cx="53" cy="12" r="1.5"/></g>`);

// Bumper (placeable, mint, pill with chrome caps)
A.bumper = svg(90, 14, `
<rect x="2" y="2" width="86" height="10" rx="5" fill="none" stroke="${C.bump}" stroke-width="3" filter="url(#glow)"/>
<rect x="2" y="2" width="86" height="10" rx="5" fill="${C.base}" stroke="${C.bump}" stroke-width="2"/>
<rect x="4" y="4" width="82" height="6" rx="3" fill="${C.bump}" opacity=".3"/>
<rect x="8" y="4" width="74" height="2.5" rx="1" fill="url(#gloss)"/>
<rect x="2" y="2" width="8" height="10" rx="4" fill="url(#chrome)"/><rect x="80" y="2" width="8" height="10" rx="4" fill="url(#chrome)"/>`);

// Placement ghosts
const ghost = (hue) => `<rect x="2" y="2" width="56" height="20" rx="4" fill="${hue}" fill-opacity=".15" stroke="${hue}" stroke-width="2" stroke-dasharray="5 3"/>`;
A.ghost_valid = svg(60, 24, ghost(C.bump));
A.ghost_invalid = svg(60, 24, ghost(C.danger) + `<path d="M24 6l12 12M36 6l-12 12" stroke="${C.danger}" stroke-width="2.5" stroke-linecap="round"/>`);

// Ball, paddle
A.ball = svg(20, 20, `
<circle cx="10" cy="10" r="7" fill="${C.pay}" filter="url(#glow)" opacity=".8"/>
<circle cx="10" cy="10" r="7" fill="${C.white}"/>
<circle cx="7.5" cy="7.5" r="2.5" fill="#fff"/>`);
A.paddle = svg(120, 16, `
<rect x="1" y="1" width="118" height="14" rx="5" fill="url(#chrome)" stroke="${C.trimLo}" stroke-width="1"/>
<rect x="12" y="7" width="96" height="2.5" rx="1" fill="${C.pay}" filter="url(#glow)"/>
<rect x="12" y="7" width="96" height="2.5" rx="1" fill="${C.pay}"/>`);

// Effects
A.fx_halo = svg(120, 60, `<ellipse cx="60" cy="30" rx="58" ry="28" fill="url(#halo)"/>`);
A.fx_spark = svg(16, 16, `<path d="M8 0L9.6 6.4 16 8 9.6 9.6 8 16 6.4 9.6 0 8 6.4 6.4z" fill="${C.pay}"/><circle cx="8" cy="8" r="2" fill="#fff"/>`);
A.fx_debris = svg(12, 8, `<rect x="1" y="1" width="10" height="6" rx="1.5" fill="${C.base}" stroke="${C.brick}" stroke-width="1.5"/>`);
A.fx_payout_tag = svg(44, 18, `
<rect x="1" y="1" width="42" height="16" rx="8" fill="${C.pay}" filter="url(#glow)" opacity=".7"/>
<rect x="1" y="1" width="42" height="16" rx="8" fill="${C.pay}" stroke="${C.gold}" stroke-width="1"/>
<text x="22" y="13.5" text-anchor="middle" font-family="Arial Black,Arial" font-weight="900" font-size="11" fill="${C.base}">+12</text>`);

// ---- Mockup board (1280x720) ----
function board() {
	const place = (name, x, y, rot = 0) => {
		const inner = A[name].replace(/^<svg[^>]*>/, "").replace(/<\/svg>$/, "").replace(DEFS, "");
		return `<g transform="translate(${x} ${y}) rotate(${rot})">${inner}</g>`;
	};
	let out = `<rect width="1280" height="720" fill="${C.base}"/>`;
	// Peg-board dots in placement zone
	for (let y = 100; y < 560; y += 20) for (let x = 20; x < 1280; x += 20) out += `<circle cx="${x}" cy="${y}" r=".8" fill="${C.trim}"/>`;
	// Rails
	out += `<rect x="0" y="40" width="1280" height="4" fill="url(#chrome)"/><rect x="0" y="40" width="4" height="680" fill="url(#chrome)"/><rect x="1276" y="40" width="4" height="680" fill="url(#chrome)"/>`;
	// HUD line: combo bar
	out += `<rect x="0" y="36" width="820" height="4" fill="${C.pay}" filter="url(#glow)"/><rect x="0" y="36" width="820" height="4" fill="${C.pay}"/>`;
	out += `<text x="16" y="28" font-family="Arial Black,Arial" font-weight="900" font-size="20" fill="${C.pay}">$ 1,248</text>`;
	out += `<text x="640" y="30" text-anchor="middle" font-family="Arial Black,Arial" font-weight="900" font-size="24" fill="${C.pay}">×7 COMBO</text>`;
	out += `<text x="1264" y="28" text-anchor="end" font-family="Arial Black,Arial" font-weight="900" font-size="20" fill="${C.danger}">0:04</text>`;
	// Placement line
	out += `<line x1="4" y1="560" x2="1276" y2="560" stroke="${C.bump}" stroke-width="1.5" stroke-dasharray="8 6" opacity=".5"/>`;
	// Brick grid, triangle-ish with variety
	const cols = 15, bw = 64, x0 = (1280 - cols * bw) / 2;
	const pick = (r, c) => {
		const k = (r * 7 + c * 3) % 23;
		if ((r === 0 && c === 7)) return "brick_icon_x2";
		if (k === 4 || k === 15) return "brick_solid";
		if (k === 9) return "brick_multi_full";
		if (k === 13) return "brick_multi_cracked";
		if (k === 20) return "brick_icon_multiball";
		if (k === 6) return "brick_cond_speed_idle";
		if (k === 11) return "brick_plain_dim";
		return "brick_plain_lit";
	};
	for (let r = 0; r < 7; r++) {
		const n = cols - r * 2, start = r;
		for (let i = 0; i < n; i++) {
			const c = start + i;
			if ((r * 5 + c * 11) % 17 === 0) continue; // hole
			out += place(pick(r, c), x0 + c * bw, 90 + r * 28);
		}
	}
	// A just-broken brick: flash + sparks + debris + payout tag
	out += place("brick_plain_flash", x0 + 5 * bw, 90 + 7 * 28);
	for (const [dx, dy, rot] of [[-14, -10, 20], [70, -8, -30], [20, 30, 60], [50, 26, 10]]) out += place("fx_spark", x0 + 5 * bw + dx + 20, 90 + 7 * 28 + dy, rot);
	for (const [dx, dy, rot] of [[-20, 6, 25], [66, 2, -40], [30, 32, 70]]) out += place("fx_debris", x0 + 5 * bw + dx + 20, 90 + 7 * 28 + dy, rot);
	out += place("fx_payout_tag", x0 + 5 * bw + 8, 90 + 7 * 28 - 24);
	// Placed bumpers, one being placed (ghost)
	out += place("bumper", 300, 420, -15);
	out += place("bumper", 880, 440, 15);
	out += place("ghost_valid", 600, 480);
	out += place("ghost_invalid", 700, 520);
	// Ball with trail, paddle
	for (let i = 1; i <= 4; i++) out += `<circle cx="${640 - i * 14}" cy="${600 + i * 10}" r="${7 - i}" fill="${C.pay}" opacity="${.5 - i * .1}"/>`;
	out += place("ball", 630, 590);
	out += place("paddle", 580, 672);
	return svg(1280, 720, out);
}

mkdirSync("assets/vector/svg", { recursive: true });
mkdirSync("assets/vector/png", { recursive: true });

for (const [name, s] of Object.entries(A)) {
	writeFileSync(`assets/vector/svg/${name}.svg`, s);
	execSync(`magick -background none -density 384 assets/vector/svg/${name}.svg assets/vector/png/${name}.png`);
}
const boardSvg = board();
writeFileSync("assets/vector/look.svg", boardSvg);
execSync(`magick -background none -density 96 assets/vector/look.svg assets/vector/look.png`);

// ---- Demo page: assets/vector/assets.html (self-contained, SVGs inlined as data URIs) ----
const uri = (s) => `data:image/svg+xml;utf8,${encodeURIComponent(s)}`;
const dims = (s) => s.match(/width="(\d+)" height="(\d+)"/).slice(1, 3).map(Number);
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
const cards = GROUPS.map(([title, names]) => `<section><h2>${title}</h2><div class="row">${names.map((n) => {
	const [w, h] = dims(A[n]);
	return `<figure><div class="tile"><img src="${uri(A[n])}" width="${w}" height="${h}" alt="${n}"></div><figcaption>${n}<span>${w}×${h}</span></figcaption></figure>`;
}).join("")}</div></section>`).join("");
const html = `<title>BreakIn cremental Sprites</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bungee&family=IBM+Plex+Sans:wght@400;600&display=swap">
<style>
/* Layout: cabinet mockup on top, then sprite groups in wrapping rows, zoom toggle sticky. Single dark theme: it is the game's screen. */
:root{--bg:${C.base};--panel:#0a0a33;--trim:${C.trim};--fg:${C.white};--muted:${C.rivet};--accent:${C.pay};--pink:${C.brick};--mint:${C.bump};
--display:"Bungee",Impact,sans-serif;--body:"IBM Plex Sans",system-ui,sans-serif;color-scheme:dark}
body{background:var(--bg);color:var(--fg);font:15px/1.5 var(--body);padding-block:24px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
h1{font:28px var(--display);color:var(--accent);margin:0 0 4px;text-shadow:0 0 12px ${C.pay}88;text-wrap:balance}
h2{font:14px var(--display);color:var(--pink);margin:0 0 10px;letter-spacing:.04em}
p.lede{color:var(--muted);margin:0 0 20px;max-width:65ch}
.bar{display:flex;gap:8px;align-items:center;flex-wrap:wrap;position:sticky;top:env(safe-area-inset-top,0px);background:var(--bg);padding-block:8px;margin-bottom:16px;border-bottom:1px solid var(--trim);z-index:5}
.bar span{color:var(--muted);font-size:13px;letter-spacing:.08em;text-transform:uppercase}
.bar button{font:600 13px var(--body);color:var(--fg);background:var(--panel);border:1px solid var(--trim);border-radius:4px;padding:4px 12px;cursor:pointer}
.bar button[aria-pressed=true]{border-color:var(--mint);color:var(--mint);box-shadow:0 0 8px ${C.bump}66}
.bar button:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.board{border:2px solid var(--trim);border-radius:6px;max-width:100%;display:block;margin-bottom:28px;box-shadow:0 0 24px #0008}
section{margin-bottom:28px}
.row{display:flex;flex-wrap:wrap;gap:12px}
figure{margin:0;display:flex;flex-direction:column;gap:6px;min-width:0}
.tile{background:var(--panel);border:1px solid var(--trim);border-radius:4px;padding:16px;display:grid;place-items:center;min-width:120px;min-height:72px;background-image:radial-gradient(${C.trim} .8px,transparent .8px);background-size:20px 20px}
.tile img{image-rendering:auto;width:calc(var(--w,60px)*var(--z,2))}
figcaption{font-size:12px;color:var(--muted);display:flex;justify-content:space-between;gap:12px;font-variant-numeric:tabular-nums}
@media (prefers-reduced-motion:no-preference){.tile img{transition:width .15s}}
</style>
<h1>BreakIn cremental Sprites</h1>
<p class="lede">Pachinko lamp look: dark glass, neon tube outline, chrome for anything unlit. Sizes are 1× game units at a 1280×720 view. Glow in-engine comes from a shader, not these files.</p>
<img class="board" src="${uri(boardSvg)}" width="1280" height="720" alt="Mockup of a full arena">
<div class="bar"><span>Zoom</span><button data-z="1">1×</button><button data-z="2" aria-pressed="true">2×</button><button data-z="4">4×</button></div>
${cards}
<script>
document.querySelectorAll(".tile img").forEach(i=>i.style.setProperty("--w",i.getAttribute("width")+"px"));
document.querySelectorAll(".bar button").forEach(b=>b.onclick=()=>{
	document.querySelectorAll(".bar button").forEach(x=>x.setAttribute("aria-pressed",x===b));
	document.documentElement.style.setProperty("--z",b.dataset.z);
});
</script>`;
writeFileSync("assets/vector/assets.html", html);
console.log(`${Object.keys(A).length} assets + assets/vector/look.png + assets/vector/assets.html`);
