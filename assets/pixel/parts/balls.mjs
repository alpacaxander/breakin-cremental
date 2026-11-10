// Ball faces for the Peglin direction (docs/content.md, Balls table): one still strip per ball, frame rank-1 is the face.
// gen.mjs exports nothing, so the merge point is `emit(h)` with h = { C, SETS, A, ellipse, def } from gen.mjs:
//   C (palette), SETS (hue sets, uses vio.tube), A (A.ball is the basic rank-3 face), ellipse(w, h, edge, body), def(group, name, fps, frames).
// Every face is the warm-white ball; rank only changes the edge swatch (cream, pay, payHi, so rank 3 of basic is `ball` exactly)
// and a trait is one violet mark (relics and ball traits are violet in the HUD). Junk is a dead slate ball with no glint.

export const STRIPS = [
	["ball_basic_rank", 8, 3], ["ball_heavy_rank", 12, 3], ["ball_split_rank", 8, 3], ["ball_pierce_rank", 6, 3],
	["ball_sticky_rank", 8, 3], ["ball_bomb_rank", 8, 3], ["ball_poison_rank", 8, 3], ["ball_junk_rank", 8, 1],
];

export function emit({ C, SETS, A, ellipse, def }) {
	const V = SETS.vio.tube, RANK = [C.cream, C.pay, C.payHi];
	const hex = (p) => p.slice(0, 3).map((v) => v.toString(16).padStart(2, "0")).join("");
	const swap = (img, from, to) => { const o = img.crop(0, 0, img.w, img.h); for (let y = 0; y < o.h; y++) for (let x = 0; x < o.w; x++) { const p = o.get(x, y); if (p[3] && hex(p) === from) o.px(x, y, to); } return o; };
	// face(size, mark, thick): ellipse at the rank's edge colour; thick = 2 makes a heavy shell.
	const shell = (size, edge, thick) => { // ellipse() insets the body 1; a heavy ball's shell is `thick` instead
		const b = ellipse(size, size, edge, edge), inner = ellipse(size - 2 * thick, size - 2 * thick, C.white, C.white);
		b.blit(inner, thick, thick); b.rect(thick + 1, thick + 1, 2, 1, C.pureWhite); b.px(thick + 1, thick + 2, C.pureWhite); return b;
	};
	const face = (size, mark = () => {}, thick = 1) => RANK.map((edge) => { const b = thick > 1 ? shell(size, edge, thick) : ellipse(size, size, edge, C.white); mark(b, V); return b; });
	const dots = (pts) => (b, c) => { for (const [x, y] of pts) b.px(x, y, c); };

	const faces = {
		basic: RANK.map((edge, i) => i === 2 ? A.ball : swap(A.ball, C.payHi, edge)),
		heavy: face(12, () => {}, 2),
		split: face(8, dots([[4, 1], [4, 2], [4, 3], [4, 4], [4, 5], [4, 6]])),            // one seam down the middle: two halves waiting
		pierce: face(6, dots([[3, 3]])),                                                // needle: small, one violet core
		sticky: face(8, dots([[2, 6], [3, 7], [4, 7], [5, 6], [5, 5]])),                 // gum: a violet drip hanging off the bottom
		bomb: face(8, (b, c) => { b.px(5, 0, c); b.px(5, 1, c); b.px(6, 0, C.pay); }),  // fuse on top with a yellow spark
		poison: face(8, dots([[4, 3], [2, 5], [5, 5]])),                                 // spore: three violet specks
	};
	for (const [id, frames] of Object.entries(faces)) def("Ball faces", `ball_${id}_rank`, 1, frames);
	def("Ball faces", "ball_junk_rank", 1, [swap(ellipse(8, 8, C.trimHi, C.rivet), C.pureWhite, C.rivet)]);
}
