// Ball faces for the Peglin direction (docs/content.md, Balls table): one still strip per ball, frame rank-1 is the face.
// gen.mjs exports nothing, so the merge point is `emit(h)` with h = { C, SETS, A, Img, def } from gen.mjs:
//   C (palette), SETS (hue sets), A (A.ball is the basic rank-3 face), Img (the image class), def(group, name, fps, frames).
// Each ball reads by silhouette and body colour alone (boulder a lumpy brown rock, splitter two halves on a crack, needle a
// diagonal shard, gum a pink drip, blaster a black bomb with a lit fuse, spore a spiky green puffball). Rank is the edge:
// the ball's own ring at rank 1, then pay, then payHi (basic keeps cream / pay / payHi, so its rank 3 is `ball` exactly).
// Junk is a dead slate ball with no glint.

export const STRIPS = [
	["ball_basic_rank", 8, 3], ["ball_heavy_rank", 12, 3], ["ball_split_rank", 8, 3], ["ball_pierce_rank", 6, 3],
	["ball_sticky_rank", 8, 3], ["ball_bomb_rank", 8, 3], ["ball_poison_rank", 8, 3], ["ball_junk_rank", 8, 1],
];

// Faces as ascii: e = the rank edge, other letters per ball's map. Every row is the frame width.
const ART = {
	heavy: [
		"...eeeee....",
		"..eRhhRRee..",
		".eRhhRRRRRe.",
		"eRhRRRRRdRRe",
		"eRRRRRRdRRRe",
		"eRRRRRdRRRRe",
		"eRdRRRRRRRde",
		"eRRdRRRRRdRe",
		".eRRRddRRRRe",
		".eRRRRRRRRe.",
		"..eeRRRRee..",
		"....eeee....",
	],
	split: [
		"..edee..",
		".eWWdSe.",
		"eWhdSSse",
		"eWWWdSSe",
		"eWWdSSSe",
		"eWWWdSSe",
		".eWdSSe.",
		"..eede..",
	],
	pierce: [
		"...eeh",
		"..eHHe",
		".eHHe.",
		"eSHe..",
		"eSe...",
		"ee....",
	],
	sticky: [
		"..eeee..",
		".ePhPPe.",
		"ePhPPPPe",
		"ePPPPPPe",
		"ePPPPPPe",
		".ePPPPe.",
		"..eePe..",
		"....d...",
	],
	bomb: [
		".....oY.",
		".....F..",
		"..eeFe..",
		".eKKKKe.",
		"eKhKKKKe",
		"eKKKKKKe",
		".eKKKKe.",
		"..eeee..",
	],
	poison: [
		"e..ee..e",
		".eGGGGe.",
		"eGhGGdGe",
		"eGGdGGGe",
		"eGGGGdGe",
		"eGdGGGGe",
		".eGGGGe.",
		"e..ee..e",
	],
};

export function emit({ C, SETS, A, Img, def }) {
	const { ora, gold, sky, mag, mint } = SETS;
	const hex = (p) => p.slice(0, 3).map((v) => v.toString(16).padStart(2, "0")).join("");
	const swap = (img, from, to) => { const o = img.crop(0, 0, img.w, img.h); for (let y = 0; y < o.h; y++) for (let x = 0; x < o.w; x++) { const p = o.get(x, y); if (p[3] && hex(p) === from) o.px(x, y, to); } return o; };
	const draw = (rows, map, edge) => { const b = new Img(rows[0].length, rows.length); b.ascii(0, 0, rows, { ...map, e: edge }); return b; };
	// [body map, rank-1 edge]
	const LOOK = {
		heavy: [{ R: gold.ring, h: gold.tube, d: gold.dimRing }, ora.ring],
		split: [{ W: C.white, h: C.pureWhite, S: sky.tube, s: sky.hi, d: sky.deep }, sky.ring],
		pierce: [{ H: C.chromeHi, S: sky.tube, h: C.pureWhite }, sky.ring],
		sticky: [{ P: mag.hi, h: C.pureWhite, d: mag.tube }, mag.tube],
		bomb: [{ K: C.trimLo, h: C.rivet, F: C.cream, o: ora.tube, Y: C.pay }, C.trimHi],
		poison: [{ G: mint.tube, h: mint.hi, d: mint.deep }, mint.ring],
	};
	def("Ball faces", "ball_basic_rank", 1, [C.cream, C.pay, C.payHi].map((edge, i) => i === 2 ? A.ball : swap(A.ball, C.payHi, edge)));
	for (const [id, [map, own]] of Object.entries(LOOK)) def("Ball faces", `ball_${id}_rank`, 1, [own, C.pay, C.payHi].map((edge) => draw(ART[id], map, edge)));
	const junk = new Img(8, 8);
	junk.ascii(0, 0, ["..eeee..", ".eBBBBe.", "eBBBBBBe", "eBBBBBBe", "eBBBBBBe", "eBBBBBBe", ".eBBBBe.", "..eeee.."], { e: C.trimHi, B: C.rivet });
	def("Ball faces", "ball_junk_rank", 1, [junk]);
}
