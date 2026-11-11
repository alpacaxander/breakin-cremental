// Encounter organs (docs/content/encounters.md): one neutral grey-white cell face and its hit and die strips, tinted per organ
// at runtime by ORGANS.tint (self_modulate). emit(h) takes gen.mjs's helpers, the same object emitBricks gets.
// ponytail: one tinted placeholder for every organ; per-organ face, hit and die keys on ORGANS replace the tint later.
import { hueStrips } from "./bricks.mjs";

const GREY = { tube: "d8d8d8", ring: "a0a0a0", deep: "585858", hi: "ffffff", dimTube: "707070", dimRing: "404040" };

export function emit(h) {
	h.A.organ_cell = h.lit(GREY);
	// hueStrips' <set>_hit and <set>_break shapes, renamed organ_hit and organ_die; its spawn strip is dropped (organs never regrow).
	const def = (_g, n, fps, frames) => n.endsWith("_spawn") || h.def("Organs", n.replace("_break", "_die"), fps, frames);
	hueStrips({ ...h, def }, GREY, "organ", false);
}
