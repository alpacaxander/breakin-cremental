// Thematic ball faces for the three map proposals (docs/content/maps/*.md, Thematic balls): same contract as parts/balls.mjs,
// one still strip per ball at fps 1, frame rank-1 is the face, all 8x8. Rank is the edge: own ring at rank 1, then pay, then payHi.
// Silhouette + body: token a brass coin with a hole, rubber a squashed orange ball with a cream band, magnet a red horseshoe with
// chrome tips (Map 1); laser a blue ball with a white beam through it, badge a violet shield with a white star, drone a sky dome
// under rotor blades (Map 2); virus a green diamond with knobs, ghost a pale-green sheet with eyes, fork a green ball shedding a
// small copy (Map 3, green set).
// In-flight strips, rank-agnostic overlays the arena plays on the ball: ball_drone_hover 8x4 x4 @12 (thrust under the ball while
// it hovers), ball_ghost_phase 12x12 x4 @8 (dashed shell while it phases), laser_column 8x120 x4 @12 (beam down the ball's
// column, scaled to the board height by the caller). Fork re-entry reuses spark_burst_mint; nothing new.

export const STRIPS = [
	["ball_token_rank", 8, 3], ["ball_rubber_rank", 8, 3], ["ball_magnet_rank", 8, 3],
	["ball_laser_rank", 8, 3], ["ball_badge_rank", 8, 3], ["ball_drone_rank", 8, 3],
	["ball_virus_rank", 8, 3], ["ball_ghost_rank", 8, 3], ["ball_fork_rank", 8, 3],
	["ball_drone_hover", 8, 4], ["ball_ghost_phase", 12, 4], ["laser_column", 8, 4],
];

// Faces as ascii: e = the rank edge, other letters per ball's map.
const ART = {
	token: ["..eeee..", ".eGGGGe.", "eGhrrGGe", "eGr..rGe", "eGr..rGe", "eGGrrGde", ".eGGGde.", "..eeee.."],
	rubber: ["........", "..eeee..", ".eOhOOe.", "eOOOOOOe", "eWWWWWWe", "eOOOOOde", ".eOOOde.", "..eeee.."],
	magnet: ["eee..eee", "eTT..TTe", "eTT..TTe", "eRR..RRe", "eRh..RRe", "eRRRRRde", ".eRRRde.", "..eeee.."],
	laser: ["...ww...", "..eWWe..", ".eBWWBe.", "eBhWWBBe", "eBBWWBde", ".eBWWde.", "..eWWe..", "...ww..."],
	badge: ["eeeeeeee", "eVhVVVVe", "eVVWWVVe", "eWWWWWWe", "eVWWWWVe", ".eWVVWe.", "..eVde..", "...ee..."],
	drone: ["RR....RR", ".e....e.", ".eeeeee.", "eShSSSSe", "eSSkkSSe", "eSSSSSde", ".eSSSde.", "..eeee.."],
	virus: ["...kk...", "..eGGe..", ".eGhGGe.", "kGGdGGGk", "kGGGdGGk", ".eGGGde.", "..eGGe..", "...kk..."],
	ghost: ["..eeee..", ".eGGGGe.", "eGhGGGGe", "eGkGGkGe", "eGkGGkGe", "eGGGGGGe", "eGeGGeGe", "e.e..e.e"],
	fork: [".....ee.", "....eSSe", "..eeeSSe", ".eFFFee.", "eFhFFFe.", "eFFFFFe.", "eFFFFde.", ".eeeee.."],
};

export function emit({ C, SETS, Img, def, ring }) {
	const { ora, gold, sky, vio, blue, red, green } = SETS;
	// [body map, rank-1 edge]
	const LOOK = {
		token: [{ G: gold.tube, h: gold.hi, r: gold.ring, d: gold.dimTube }, gold.ring],
		rubber: [{ O: ora.tube, h: ora.hi, W: C.cream, d: ora.ring }, ora.ring],
		magnet: [{ R: red.tube, h: red.hi, T: C.chromeHi, d: red.ring }, red.ring],
		laser: [{ B: blue.tube, h: blue.hi, W: C.pureWhite, w: blue.hi, d: blue.ring }, blue.ring],
		badge: [{ V: vio.tube, h: vio.hi, W: C.white, d: vio.ring }, vio.ring],
		drone: [{ S: sky.tube, h: sky.hi, k: C.danger, R: C.chromeHi, d: sky.ring }, sky.ring],
		virus: [{ G: green.tube, h: green.hi, d: green.deep, k: green.hi }, green.ring],
		ghost: [{ G: green.hi, h: C.pureWhite, k: green.deep }, green.ring],
		fork: [{ F: green.tube, h: green.hi, S: green.hi, d: green.ring }, green.ring],
	};
	const draw = (w, h, rows, map) => { const b = new Img(w, h); b.ascii(0, 0, rows, map); return b; };
	for (const [id, [map, own]] of Object.entries(LOOK)) def("Balls: maps", `ball_${id}_rank`, 1, [own, C.pay, C.payHi].map((e) => draw(8, 8, ART[id], { ...map, e })));
	// drone thrust: two jets flickering long/short under the ball
	const J = { a: sky.hi, b: sky.tube, c: sky.ring };
	def("Balls: maps", "ball_drone_hover", 12, [
		[".a....a.", ".b....b.", ".c....c.", "........"], [".a....a.", ".b....b.", "........", "........"],
		[".a....a.", ".a....a.", ".b....b.", ".c....c."], [".a....a.", ".b....b.", ".c....c.", "........"],
	].map((r) => draw(8, 4, r, J)));
	// ghost shell: a dashed ring that breathes in and out around the ball
	def("Balls: maps", "ball_ghost_phase", 8, [[4, green.hi], [5, green.tube], [5, green.ring], [4, green.tube]].map(([r, c]) => { const f = new Img(12, 12); ring(f, 5.5, 5.5, r, c, 1, 1); return f; }));
	// laser beam: flash wide, white core, thin, gone
	def("Balls: maps", "laser_column", 12, [[8, C.pureWhite, blue.hi], [6, C.pureWhite, blue.tube], [4, blue.hi, blue.ring], [2, blue.ring, null]].map(([w, core, glow]) => {
		const f = new Img(8, 120), x = (8 - w) >> 1;
		f.rect(x, 0, w, 120, glow ?? core);
		if (glow) f.rect(x + 1, 0, w - 2, 120, core);
		return f;
	}));
}
