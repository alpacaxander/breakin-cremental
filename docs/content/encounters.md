# Encounters and organs: what has not landed

Proposal, 2026-11-10. The first slice landed the same day and its rows moved to `docs/content.md` (Encounters and organs, Fight pipeline, Bricks, Hazards), which wins over this file: the knight encounter, organ cash-in with reset, the paddle no longer landing damage, armed bombs, placeholder organ art, and a bridge that plays every `ENEMIES` row as a one-organ encounter. What follows is still proposal.

## Rules still to build

| topic | rule |
|---|---|
| Encounter script | An encounter can react to events: an organ below an HP mark, an organ dead, a phase number. Reactions: spawn organs, swap the board, change an organ's fields. Deep Net's `fork_bomb` split and `trojan` reveal are scripts, not enemy signatures. |
| `grow` | An organ effect: n plains grow around the organ. The knight's shield fires `shield_row` as a stand-in until it exists. |
| The maw's mouth | A mouth organ: it swallows balls that touch it and spits them back as enemy balls (the old band zone goes). Today the bridged maw keeps the band zone. |
| `ball_magnet` | Flips: a charged ball is drawn to the nearest organ. `magnet_paddle` (relic) keeps pulling to the paddle, as survival. |
| Band mirrors organs | The band portrait shows what the organs do (the sword raised when the sword organ winds up, the shield cracked when it is hurt). Today it plays `hit` on any landed shot, `attack` on any intent and `die` on the win. |

Deferred: refresh regrowing the bricks that bury organs could stall a fight. If play shows it, exclude organ-adjacent cells from refresh.

## Converting enemies

Every `ENEMIES` row plays through the bridge (`Tuning.encounter`), which stamps a 3-cell organ at the board centre. Each should instead become an authored encounter that draws its organ into the board's thematic centre (the glob's goo core, the coin slug's gut, the mason's vault). Elites and bosses are the first to split into several organs. The map proposals convert the same way: `fork_bomb` and `trojan` become encounter scripts. When the last row converts, the bridge and `ENEMIES` go.

## Art

- Each organ needs its own look: a face for its cells plus one overlay sprite sized to its footprint (the sword, the shield), and `<organ>_hit` / `<organ>_die` strips, keyed by per-organ `face`, `hit` and `die` fields on `ORGANS` that replace today's `tint` over the grey-white `organ_cell`.
- The knight needs its own band portrait; it borrows the warden's.

## Playtest questions

If aiming at organs feels like luck, the levers are organ size, open lanes in the authored board, and `sticky` / `ball_magnet` in the starting pools. The knight is tier 1 (proposed 2) so the playtest meets it from the first node; move it once the question is answered.
