// Fight effects and card statics for the Peglin direction (docs/content.md "Code steps" 9; rows in docs/animations.md):
// ball_split_pop, ball_poison_land, damage_fire, stored_tag, recall_rise, relic_get, and card_frame/_hot/_dim.
// gen.mjs exports nothing, so this takes its helpers as one object: emit({ Img, C, SETS, A, def, frame, center, blank, lit, dim, hot, ring }).
// Call it after A.ball and A.paddle exist.

export function emit({ Img, C, SETS, A, def, frame, center, blank, lit, dim, hot, ring }) {
	const V = SETS.vio;

	// -- ball_split_pop: a white seam flashes, then two halves drift apart and fade --
	const pair = (d, a) => frame(16, 16, [A.ball, 4 - d, 4, a], [A.ball, 4 + d, 4, a]);
	const seam = frame(16, 16, center(A.ball, 16, 16)); seam.rect(7, 3, 2, 10, C.pureWhite);
	def("Fight", "ball_split_pop", 12, [frame(16, 16, center(A.ball, 16, 16)), seam, pair(2, 255), pair(4, 200), pair(6, 120), blank(16, 16)]);

	// -- ball_poison_land: a violet ring of spores bursts outward from the landing point --
	const spore = (r, c, dash) => { const b = new Img(12, 12); ring(b, 5.5, 5.5, r, c, 1, dash); return b; };
	def("Fight", "ball_poison_land", 12, [spore(1.5, V.hi, 0), spore(3, V.tube, 0), spore(4.5, V.ring, 1), spore(5.5, V.deep, 1)]);

	// -- damage_fire: the paddle stripe burns payout yellow and settles back --
	def("Fight", "damage_fire", 12, [C.pureWhite, C.payHi, C.pay, C.payHi, C.pay, C.payDim].map((c, i) => {
		const b = A.paddle.crop(0, 0, 60, 8); b.hline(6, 4, 48, c); if (i < 2) b.hline(6, 3, 48, c); return b;
	}));

	// -- stored_tag: a dark tag with a breathing yellow rim; the stored number is a pay label on it in-engine --
	def("Fight", "stored_tag", 8, [C.payDim, C.pay, C.payHi, C.pay].map((c) => { const b = new Img(25, 8); b.rect(0, 0, 25, 8, C.base); b.outline(0, 0, 25, 8, c); b.corners(); return b; }));

	// -- recall_rise: the ball shoots up out of the floor on a sky streak --
	const rise = (y, a) => { const f = frame(12, 12, [A.ball, 2, y, a]); for (let j = y + 8; j < 12; j++) f.px(5, j, j - y < 10 ? C.skyHi : C.sky); for (let j = y + 8; j < 12; j++) f.px(6, j, C.sky); return f; };
	def("Fight", "recall_rise", 12, [rise(4, 255), rise(3, 255), rise(2, 255), rise(1, 200), rise(0, 120), blank(12, 12)]);

	// -- card frames and relic_get: the back narrows to an edge, then the lit face opens out --
	A.card_frame = lit(V, 36, 48); A.card_frame_hot = hot(V, 36, 48); A.card_frame_dim = dim(V, 36, 48);
	const squeeze = (lamp, w) => { const b = lamp(V, w, 48); return frame(36, 48, center(b, 36, 48)); };
	def("Fight", "relic_get", 12, [A.card_frame_dim, squeeze(dim, 20), squeeze(hot, 6), squeeze(hot, 20), A.card_frame_hot, A.card_frame]);
}
