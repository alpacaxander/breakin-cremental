# Map 3: Deep Net

Proposal, 2026-11-10. Nothing here is in `tuning.gd` yet. When a row lands, `docs/content.md` wins over this file.

Past the corp layer: rogue code and glitch. This is where the green trait colour belongs (`docs/art-style.md`, Green set). Hazards here mess with the rules the first two maps taught: bricks move, controls flip, things stop being solid. The map's lesson is that the board itself is the enemy.

Vocabulary as `docs/content.md`. Earlier maps' hazards are available; Deep Net reuses `red_bricks`, `enemy_balls`, `debris`, `laser_sweep` and `shield_row`.

## New hazards

| id | numbers | effect | persists past a phase end |
|---|---|---|---|
| `virus` | `count`, `spread` 1 per paddle hit | per count a random live plain becomes kind `virus` (green set). Every paddle hit, each virus brick infects one live plain neighbour. Breaking a virus brick clears its whole connected cluster. A virus brick stores no damage | yes |
| `scramble` | one shot | every live brick swaps position with another live brick; kinds move, slots stay | n/a |
| `mirror` | `hits` 6 | paddle input is inverted for the next 6 paddle hits; a refire resets to 6 | yes |
| `ghost` | `count` | per count a random live non-solid brick becomes a ghost: drawn in the dashed ghost state, balls pass through it, it stores nothing. Returns to its kind at the next phase start | yes, until the next phase starts |

`virus` is a brick kind as well as a hazard, so it follows the three-step "adding a brick kind" path in `CLAUDE.md`: a `BRICKS` row with hue green, a `_damage` arm for the refusal, a `_effect` arm for the cluster clear, strips in `parts/bricks.mjs`.

## Enemies (8)

| id | look | board hook | HP | cd | intents |
|---|---|---|---|---|---|
| `worm` | segmented glyph string | one winding line of plains, a crit at the head | 70 | 5 | `virus` x1, `red_bricks` x2 |
| `glitch` | a sprite that tears on every idle frame | the board is redrawn from the fight class at every phase end | 75 | 5 | `scramble` x1, `enemy_balls` x3 |
| `mirror_daemon` | the player's paddle, red | the fight-class starting board flipped top to bottom | 80 | 6 | `mirror` x1, `debris` x4 |
| `null` | a hole with an outline | ghosts where the crits would be | 70 | 5 | `ghost` x2, `laser_sweep` x1 |
| `packet_storm` | dots streaming down | bricks only on the diagonals | 65 | 4 | `enemy_balls` x5 |
| `rootkit` | a root system of cables | solids in a tree, crits at the leaf tips | 85 | 6 | `virus` x2, `shield_row` |
| `ghost_process` | a faded glob | mostly empty, crits in the centre | 70 | 5 | `ghost` x1, `scramble` x1, `debris` x3 |
| `checksum` | a number that keeps changing | refresh bricks numbered 1-5; hitting one out of order turns it red | 80 | 5 | `red_bricks` x3, `mirror` x1 |

## Elites (4)

| id | signature | board hook | HP | cd | intents |
|---|---|---|---|---|---|
| `hive_mind` | every virus brick on the board absorbs one paddle hit before the cd counts it | a nest of plains, crits deep inside | 180 | 5 | `virus` x3, `red_bricks` x2, `shield_row` |
| `fork_bomb` | at 50% HP it splits into two enemies with half the remaining HP each, sharing one cycle | two identical halves | 200 | 5 | `enemy_balls` x3, `debris` x6, `scramble` |
| `recursion` | every phase end repeats the last hazard fired, one count higher | a spiral of plains, a crit at the centre | 170 | 6 | `mirror` x1, `laser_sweep` x1 |
| `trojan` | looks like a Map 1 regular; at 50% HP it reveals itself, swaps board and cycle, and heals 20 | the glob board, then a Deep Net board | 190 | 6 | `red_bricks` x3; after the reveal `virus` x2, `ghost` x2 |

## Bosses (2)

| id | phases | board hook | HP | cd | intents |
|---|---|---|---|---|---|
| `compiler` | rewrites the board between phases: at 75% HP every plain becomes a crit, at 50% every crit a bomb, at 25% everything red. It dies when the red board is cleared, whatever its HP | a grid of equal cells, no solids | 320 | 4 | `scramble`, `virus` x3, `laser_sweep` x2, `enemy_balls` x6 |
| `admin` | the one enemy that is not a drone: a figure at a terminal. Its HP bar is hidden all fight (`blackout` on the bar), and every phase end it heals the brick that was broken last | the maw board inverted, crits on the outside | 340 | 4 | `ghost` x3, `mirror` x1, `shield_row`, `debris` x10, `virus` x4 |

## Engine notes

- `virus` and `ghost` are brick state changes; `scramble` is a position swap in the brick list. None of the three has a body on the board.
- `mirror` is a sign flip on the paddle input read; the mini paddle relic is already mirrored, so it flips too.
- `fork_bomb` and `trojan` need an enemy swap mid-fight (new sprite, new board, kept HP). `trojan`'s board swap is a second `generate` call with the live bricks cleared.
- `compiler`'s kind rewrites go through the refresh path so bricks keep their slots.

## Events (3)

Same shape as `Tuning.EVENTS`. Deep Net events bend the bag the way the fights bend the board.

| id | title | body | a | b |
|---|---|---|---|---|
| `event_corrupted_save` | CORRUPTED SAVE | A SAVE FILE. THE CHECKSUM IS WRONG. | LOAD IT: every ball's rank moves up or down one, random per ball, clamped 1..3 | DELETE: gold 20 |
| `event_honeypot` | HONEYPOT | A RELIC ON A PEDESTAL. TOO EASY. | TAKE IT: a random relic; the next fight opens with `virus` x2 | LEAVE: nothing |
| `event_mirror_terminal` | MIRROR TERMINAL | YOUR OWN FACE, A FRAME LATE. | LOOK: a copy of a random ball in the bag | SMASH: hp 6, one `ball_junk` leaves the bag if there is one |

`event_corrupted_save` rolls per ball on the node's `rng(site)`. `event_honeypot` uses Corp Tower's `pending_hazard` field.

## Shop: the Darknet

- Prices are hidden until bought: every price label draws as `??` and the gold deducts on purchase. Every item is 10 under list, floor 5.
- One of the three ball cards is a `ball_junk` wearing a random ball's face and name. It reveals on purchase. The card is cheap, which is the tell.
- Remove is free. RANK UP is a new slot here only: rank one ball for 20.
- Relics: rare weighted up.

Hidden prices and the fake card are display rules on the shop screen; the row carries `hide_prices` true and `fake_junk` 1.

## Thematic balls (3)

`map` 3 on the `BALLS` row. All three use the green set on the card so they read as the map's.

| id | name | desc | rarity | dmg | trait key | ranks | behaviour |
|---|---|---|---|---|---|---|---|
| `ball_virus` | VIRUS | INFECTS A NEIGHBOUR PER BREAK | uncommon | 1, 2, 3 | `infect` | 1, 1, 2 | every break turns N live plain neighbours into kind `virus_player`: green, pays double stored damage when broken, never spreads on its own. Shares the `virus` brick face with the hazard; the hostile one spreads, the player's one pays |
| `ball_ghost` | GHOST | PHASES, THEN HITS DOUBLE | rare | 1, 2, 3 | `phase` | 2, 3, 4 | passes through the first N bricks it meets per flight, then turns solid and stores double for each brick it phased. Pierce with a memory |
| `ball_fork` | FORK | COMES BACK ONCE | rare | 1, 2, 3 | `lives` | 1, 1, 2 | on a drop it re-enters from the top at junk size with its stored damage kept, N times per phase. The `recall` relic's path, in-phase |

## Engine notes, run side

- Rank shuffling is a rank write on the bag with the invariant check after.
- The fake junk card needs a card that draws one ball's face over another's row; the shop already draws a face per card.
- `ball_virus` and the hazard `virus` share one face and the cluster-clear arm; the kind string decides whether a paddle hit spreads it.
