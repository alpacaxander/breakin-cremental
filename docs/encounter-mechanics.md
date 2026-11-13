# Encounter mechanics: slots, bricks, layers, effects

Status: decided 2026-11-12. Build steps 1-6 are in (slot / kind / source on every generated cell and Box, `keep` with pending in `arena.gd` `_keep`, `Tuning.KEEP_DEFAULT` or an encounter's `effects`; revert on enemy death in `_organ_die`; `Tuning.LAYERS` shield, ward and gilded through `_through`, placed by `start` rows and hazard `shield_bricks`; effect rows from the encounter, relics and bag balls through `Game.fight_effects`, "How effects enter an encounter" below; design placements from the board itself: drawn bricks and `board.layers` coats, painted in the editor). This file holds the rules every brick-placement effect follows, so interactions stay predictable.

## The three levels

| level | what it is | changed by | survives a board refresh |
|---|---|---|---|
| **slot type** | what the board design put at a position: `standard` for most of the board, terrain (`solid`, `organ`, later `gap`) for the rest | the board design only | always |
| **brick type** | what stands in the slot now: standard, bomb, refresh, gold, red... | effects | only while standing; a destroyed brick on a standard slot regrows as a standard brick |
| **layer** | something on top of the brick that takes hits first (a shield) | effects | only while its brick stands; regrown bricks have no layer |

A standard slot is a targeting handle: effects can be written against the slot type, the brick type, the layer, or any mix.

## Effects

Every effect is one row:

| field | meaning | examples |
|---|---|---|
| `target` | what it may touch | standard brick on a standard slot; any red brick; slot ids; a row; bricks from `source: enemy:x`; no layer |
| `when` | when it fires | `start`, `keep`, per phase, on hit count, on break of type X, on enemy intent, on enemy death, on a threshold |
| `count` | how many | N, a % of the matches, all |
| `select` | which of the matches | random, positional (row, column, edges), relational (next to X, nearest the ball, nearest an organ) |
| `to` | what it does | set brick type, remove brick, add brick, revert to standard, add layer, remove layer |
| `source` | who owns what it makes | `design`, `relic:x`, `ball:y`, `enemy:organ` |
| duration (optional) | how long the change lasts | until broken (default), until the phase ends, wandering |

Every brick and layer an effect makes carries the effect's `source`.

### Rules

1. **Targets belong to the effect.** Each effect states its own `target`; there is no global "only standard bricks" rule.
2. **Stacking sums.** Two "1 refresh on board" effects keep 2 refresh bricks, each counted under its own source.
3. **Collisions are avoided by how targets are written**, not by a priority list. The default target for anything that replaces is "standard brick on a standard slot", so a bomb placed by design or a refresh placed by a ball can't be taken by a `keep` effect.
4. **Replacing, not creating.** `start` and `keep` convert existing bricks. Only an explicit "add brick" effect creates one, into an empty standard slot.
5. **Effects target the whole board.** `start` and `keep` always use their own target against everything standing, never just the slots that just regrew.

### `start` and `keep`

- **`start`**: runs once, at initial generation. A brick the designer pre-places (a bomb at a given position) is a `start` effect from `source: design` targeting slot ids; the editor paints that, no separate field.
- **`keep`**: maintains `count` live bricks of its own source. It owes `count` minus its live bricks. Whenever it owes any (at generation, after a refresh, when one of its bricks breaks), it converts matching bricks until it owes nothing or runs out of matches.
- **Pending:** a placement a `keep` can't make waits. It is placed the next time a matching brick exists (from a refresh, a spawn, a revert). It is never forced and never creates a brick.
- A brick placed by any other effect (a ball that makes every 5th hit a refresh) is not counted by a `keep` and never regrows.
- Default board: `keep` 1 refresh, target standard brick on a standard slot. Crit was cut in `0749e96`; a default "keep 1 crit" brings it back.

### Lifecycle

**Initial generation**
1. Every standard slot gets a standard brick.
2. All `start` effects run, in this order: design, then relics, then balls.
3. All `keep` effects run.

**Board refresh**
1. Every destroyed standard slot regrows a standard brick.
2. All `keep` effects run (pending placements fill first). `start` effects don't run.

A standing `keep` brick stays where it is through a refresh. The broken refresh's own replacement lands somewhere else, since its slot is the one the ball is in.

### How effects enter an encounter

Decided 2026-11-12 (option a): a ball's `start` / `keep` effects count from the **bag** for the whole fight, like a relic; its in-flight traits (split, pierce, poison...) stay as they are.

- **Where rows live.** Same row shape everywhere (`when`, `count` or `every`, `target`, `select`, `to`, optional `hp`):
  - the encounter row's `effects`, source `design` (`Tuning.KEEP_DEFAULT` when it has none);
  - a `RELICS` row's optional `effects`, source `relic:<id>`;
  - a `BALLS` row's optional `effects`, source `ball:<bag uid>`; a `count` / `every` / `hp` may be per rank like a trait (`count = [1, 2, 3]`);
  - enemy hazards, source `enemy:<organ id>` (they place at their intent, not through this list).
- **Order.** `Game.fight_effects(enc, run)` (pure, headless-tested) returns the fight's rows: design, then relics in `run.relics` order, then balls in bag order, each a copy tagged with its source and its rank's numbers. The arena runs the `start` rows in that order (brick kinds on the layout before the spawn, `_start`; layers after it, `_apply`), then hands the `keep` rows to `_keep`.
- **Stacking sums.** Each `keep` row (each source instance: two copies of a ball are two rows) counts only its own bricks.
- **Bag uids.** Every bag entry carries a stable `uid` (`run.uid` is the next), assigned when a ball enters the bag (`Game.add_ball`: start bag, rewards, shop, events, coin_junk) and given on load to a `run.json` saved before uids (`Game.tag_bag`). Only the ball source tag reads it.
- **Placement relics are rows.** `tenth_bomb` is `{when = "start", every = 10, to = "bomb", target = "standard"}` with no hook: every 10th plain of no source on a standard slot, row-major, at least one (the last when fewer than 10 stand; a ponytail in `_start`). `RELIC_HOOKS` stays for the non-placement relics.
- No ball has effect rows yet (content is a separate call); `test.gd` drives the ball path with a hand-made table through `fight_effects`'s rows arguments.

## Layers

A layer has `kind`, `hp` (hits left), `source`, `blocks` (default true), and optional `on_hit` / `on_pop` effects (same effect rows, usually targeting "this brick" or its neighbours).

### Hit resolution

1. A ball or area effect hits a brick.
2. If the brick has a blocking layer: `on_hit` fires, the layer loses 1 hp; at 0, `on_pop` fires and the layer is removed. The ball bounces. The brick does nothing: no damage stored, no brick effect.
3. Otherwise the brick is hit as it is today. A passive layer (`blocks: false`) fires its `on_hit` and lets the hit through.

### Rules

- **The popping hit is spent on the layer.** A 1-hp shield costs one extra hit.
- **Area effects hit the layer, not the brick.** A bomb blast strips neighbouring shields. **Pierce** is a trait (ball or effect) that skips the layer.
- **The brick type can change under a layer; the layer stays.** A shielded standard brick converted to a bomb is a shielded bomb.
- **One layer per brick.** Adding the same kind adds its hp; "add layer" effects default to target "no layer", so different kinds don't collide.
- **`keep` may convert a layered brick** unless its target says "no layer".
- **Organ cells are slots**, so they can carry a layer (an enemy ward).
- **Enemy death removes everything it made.** On an organ's death, its bricks revert to standard and its layers are removed (`source: enemy:that organ`).
- In code, the layer check goes in front of `_damage`; `_trigger` routes area hits through the same path.

### Built (`Tuning.LAYERS`)

A layer is an overlay sprite on its Box (`Box.layer` {kind, hp, source}); `on_hit` is the row's number below, there are no `on_pop` rows yet. Placed by `start` effect rows (`to` "layer:<kind>", `count` random live bricks, optional `hp`, tagged with the row's source, target "any" to replace another kind), by the board design (`board.layers`, a `Tuning.LAYER_KEYS` glyph per cell, source `design`, added in `arena.gd` `_ready` ahead of the layer start rows) and by hazard `shield_bricks`; `keep` rows convert bricks only and do not take a layer `to`.

| kind | hp | blocks | on_hit / on break | face | pop strip | cues |
|---|---|---|---|---|---|---|
| `shield` | 2 | yes | none | `layer_shield` 30x12 chrome rim | `armor_pop` 44x20 x8 @12 | blocked hit `solid_bounce` (strip 44x20 x6 @12), pop `armor_pop` |
| `ward` | 2 | yes | each hit (the popping one too) takes `cut` 1.0 s off its source organ's countdown; on an organ cell it refuses the cash-in, the ball bounces, still live and charged | `layer_ward` 30x12 red dashed rim | `shield_pop` 44x20 x6 @12 | blocked hit `solid_bounce`, pop `shield_pop` |
| `gilded` | 1 | no | passive: the hit goes through; the brick's break pays `gold` 2 | `layer_gilded` 30x12 gold corners | none | `coin` (through `_pay`, strip `toll_pay`) |

## Catalog (candidates, not committed)

**Effects:** per-phase bonus bricks that revert at phase end; every-Nth-hit conversion (the hit brick or a random match); on break of X, convert neighbours (source tag stops loops); enemy intent corrupts N bricks; last standard brick standing becomes M; ratio counts (10% of matches) that scale with board size; wandering bricks that move each phase; missing bricks at start (thinner board, regrow on refresh); cleanse (red brick to standard at `start`, or a ball that reverts what it hits).

**Blocking layers:** shield (N hits); thorns (each hit costs the player 1 HP); ward (enemy: each hit heals its organ or brings its countdown forward); mirror (steep or fast bounce); slime (slows the ball, slimes a neighbour on pop); ice (holds the ball briefly); shell (gold on pop); charge (player: the popping ball gets +damage until it lands); timed shield (drops at phase end).

**Passive layers:** gilded (+gold on break); poisoned (poisons the organ when this brick's damage is cashed in).

## Build order

1. Slot type / brick type split, `source` on every brick.
2. `start` and `keep` with pending placements, replacing `place_refresh` / `_refresh` (built: `keep`; a `start` row sets a brick kind (`_start`, on the layout before the spawn) or places a layer (`to` "layer:<kind>", `_apply`); the drawn design bricks are the board itself, step 3).
2b. How effects enter an encounter: design, relic and ball rows through `Game.fight_effects`, bag uids, tenth_bomb as an effect row (built).
3. Design placements as `start` effects in the editor (built: a painted non-plain brick stands with source `design` through `Game.generate`, a painted coat is `board.layers`; the editor's KEEP stepper sets the refresh keep count, saved as the row's `effects` only when it differs from `KEEP_DEFAULT`).
4. Revert on enemy death (built: `arena.gd` `_organ_die` reverts its bricks through `_convert`, drops its layers, then runs `_keep`).
5. One layer per brick: shield and ward; then pierce (built: `Box.add_layer` / `drop_layer`, `arena.gd` `_through`; pierce is the ball row's `pierce` trait on a direct hit).
6. Passive layers when gilded or poisoned is wanted (built: gilded; poisoned is not).

## Not verified

Moved here on 2026-11-12 from `docs/content.md`, `docs/design.md` and `docs/content/encounters.md`, word for word. Not checked against the code or against the decisions above; where they disagree, the decisions above win for what gets built, and the code wins for what plays today. Verify a section before relying on it, then lift it out of this label.

### Cross-pool decisions (from content.md "Decisions that cut across pools")

| topic | decision | lost proposals |
|---|---|---|
| Enemy attack timing | **Seconds** (paddle hits until 2026-11-10; one paddle hit was taken as 2 s at `BALL_SPEED` 350, so every `cd` doubled). Every organ has `cd` in seconds; it runs down while any player ball is in flight (not while one rests on the paddle); at 0 the current intent fires on the spot, mid-phase, and the next intent (cyclic) shows with `cd` reset. Nothing fires between phases; the between-phase beat is 0.8 s of the enemy idling. | screens.md "YOUR TURN / ENEMY TURN" bands and `turn_you`/`turn_enemy` cues; design.md core loop step 3 is reworded to "enemies act mid-phase on a countdown of seconds". |
| Hazard ids | `red_bricks`, `enemy_balls`, `debris`, `laser_sweep`, `shield_row` (five). | `floor_goo` (no enemy intends it), `fuse` brick, `mouth` is a boss intent, not a hazard id. |
| Hazard damage | One number per hazard row (HAZARDS table), not per enemy. Elite and boss hit harder through `count`. | enemies.md `atk` column. |
| Red brick HP cost | 3 (bricks pool owns the row). | hazards.md 4. |
| Shield row | A full row of `solid` bricks at `SHIELD_Y`, gone after `shield_hits` paddle hits. | enemies.md hp-3 reward-less bricks. |
| Fight layout | Enemy band 0..112, top wall body at y 112, shield row centre 140, `BOARD_TOP` 168 (boss 200), `BOARD_FLOOR` 240, rows <= 11 (boss <= 10). | bricks.md 156, screens.md 140, enemies.md 120. |
| Empty board | One mechanism, the refresh: mid-phase, 1.0 s after the last breakable goes with a ball still live, one `refresh` spawns at a random original slot; at phase start with fewer than `regen_below` 10 breakables left the board refreshes for free. | run.md re-generation with a new seed. |
| Poison tick | At phase end (the 0.8 s beat): each organ takes its own `stacks`, then `stacks = floor(stacks / 2)`. | balls.md "start of the enemy turn". |

### Key mechanics (from design.md)

- **Bricks are pegs.** Each encounter authors its board. Basic bricks charge the ball with its per-brick damage. Refresh bricks respawn every broken brick: more fuel to charge on. Bomb bricks arm on the first hit and detonate on the second, hitting their neighbours and adding the charge to the ball that set them off; a blast never touches an organ. Unbreakable bricks shape the bounces. Red bricks cost the player HP when a ball breaks them.
- **Phase end.** A phase has no timer. It ends when every ball in play has dropped past the paddle, with no HP cost: like a wasted shot in Peglin, the penalty is the damage you did not deal. The natural limiter is the player's own success: an empty board stops the damage until a refresh brick appears. If play shows phases that never end, the fallback is a speed ramp on balls that stay alive too long.
- **Damage.** In Peglin damage is stored as the orb hits pegs and fired when the orb leaves the board. Here each ball stores damage as it breaks bricks and fires it when it hits an organ. The organ hit is the shot: a ball shows its stored total as it flies, lands it on the organ it touches, and starts again from zero. A ball with nothing stored just bounces off. A ball that drops past the paddle loses whatever it was carrying. The paddle deals no damage; its job is keeping charged balls alive and aiming them.
- **Enemy damage.** Peglin's enemies act once per shot. Here they act on the board: hazards that hurt you when they touch the paddle or cross the paddle line. See Enemy attacks below. A countdown of seconds in flight times them.
- **Encounters and organs.** A fight is an authored encounter: it lays out the board, places the organs, scripts what happens when (an organ splits, the board swaps) and names its end condition (default: every organ dead). An organ is one enemy: one HP bar, its own countdown and attacks, any size and shape, buried in the board as the encounter likes. A thematic foe can be several organs (a knight is a body, a sword and a shield), so multiple enemies need no extra rule. The enemy band above the top wall is decoration that pictures what the organs are doing.

### Enemy attacks

Enemies hurt you through things on the board, not through a number that lands at the end of a turn. One rule ties them together: anything hostile that touches the paddle or crosses the paddle line costs HP. The paddle lane is then shared by balls you want to catch and hazards you want to miss, which is the fight's core tension. Each organ shows an intent and a countdown; it counts down while a player ball is in flight, and at zero the hazard fires mid-phase, from the organ. Built (`Tuning.HAZARDS`): red bricks, enemy balls, debris, laser sweep, shield rows, plus the boss's mouth. The rest of the pool is ideas.

Hazard pool, roughly by build cost:

- **Red bricks.** Breaking one deals damage to you. The ball does not care, so steering it around them is the skill. Variant: a fuse brick counts down and blows up on its own unless you break it first, so one kind must be hit and the other avoided.
- **Enemy balls.** The enemy lobs balls down the board. They look like yours but carry the enemy's damage: catching one on the paddle takes the hit, letting it drop is free. Variants: homing, spread of three, slow heavy ones that must be dodged early.
- **Advancing bricks.** Rows march toward the paddle, Space Invaders style. A row reaching the paddle line deals damage per brick and vanishes. Breaking bricks slows the front; refresh bricks add rows at the top.
- **Drifting invaders.** Arkanoid-style critters wander the board, deflect balls unpredictably and sink toward the paddle. A ball kills them for bonus damage; one touching the paddle costs HP.
- **Laser sweep.** A telegraphed beam across a lane or column fires after a beat. A paddle or ball in the beam takes it; a ball hit by the beam is pushed or loses its stored damage.
- **Debris.** The enemy slams the board and shakes loose bricks that fall straight down. Dodge them; they are not worth catching.
- **Floor goo.** A hazard zone grows along the paddle line from one side, shrinking the safe lane. The paddle standing in goo takes damage per second. Breaking bricks of a certain kind, or a timer, clears it.
- **Cursed ball.** The enemy swaps the next ball in your bag for one that stores damage against you instead of the enemy. Catch it once and it hurts; the counter is to let it drop, which costs you a turn of the bag.
- **Parasite bricks.** A brick turns hostile and spreads to a neighbour every few seconds. Hostile bricks heal the enemy when broken, or hurt you. Break the source fast or the board turns against you.
- **Shield rows.** The enemy raises a layer of unbreakable or high-HP bricks in front of itself. Damage still lands, but the ball spends more time behind the shield and less near the paddle.
- **Thieves.** Small enemies run onto the board and grab a ball mid-flight or steal gold, then leave by the top. Hitting one with a ball drops the loot.
- **Paddle debuffs delivered as objects.** Ice slicks the paddle lane (slide), a weight shrinks it, a mirror reverses controls for a few seconds. Each is a thing to dodge, not a status applied from nowhere.
- **Boss as the board.** The boss is the top wall. It slams down a row at a time, opens a mouth that eats balls, or tilts the arena so gravity bends every ball.

### Fight pipeline (`arena.gd`)

| step | rule | strips | cues |
|---|---|---|---|
| `fight_start` | build the encounter's drawn board (`?` rolls from `BOARDS[class]`; digit cells become organ cells), each organ's countdown starts at its `cd_start` (else `cd`), the band portrait drops in, shuffle the bag, discard pile empty | `<enemy>_idle` loop | `round_go 1.0`; `fast_whoosh 0.6` then `bumper_hit 0.5` at delay 0.3 |
| `phase_start` | bag empty: shuffle the discard pile into it. `< regen_below` breakables: free refresh. Rest `bag[0]` on the paddle; click/space launches straight up with the paddle-offset angle | | `ball_launch st(rank-1)` (junk `0.6`) |
| `discard` | once per phase while a ball rests: D / right-click / DISCARD button; head ball to the discard pile, next rests | | `ui_drop 1.0` |
| `store` | a ball breaking a brick adds `ball.dmg * brick.dmg` to `ball.stored` (relic `combo` scales) | `stored_tag` 25x8 x4 @8 rides 6 sprite px above the ball, number as a `pay` label, hidden at 0 | |
| `fire` | a ball touching any cell of an organ (`_organ_hit`): `organ.hp -= stored`, `stored = 0`, poison moves onto the organ, and the organ consumes the ball (to the discard pile like a quiet drop: no `ball_lost`, no `steal`), so the phase moves on once it was the last ball; two cells of one organ in one frame are one hit; 0 stored and 0 poison is refused (and still consumed). A paddle hit lands nothing: the ball keeps its charge. Riposte (warden): 10+ landed takes `RIPOSTE_CUT` 2 s off that organ's countdown | `damage_fire` 60x8 x6 @12 on the cell; `organ_hit` on every cell of the organ, tinted; band `<band>_hit` | `damage_land`: 1-9 `1.0`, 10-29 `st(2)`, 30-99 `st(4)`, 100+ `st(7)`; `bumper_hit 0.6*st(off)`; refused `hit_refused 1.0`; paddle contact: `paddle_hit` speed ladder (heavy `0.7`) |
| `drop` | past the paddle line: stored lost, ball to the discard pile; relics `shield_floor`, `recall` intercept | `ball_lost` 12x12 x6 @12 (exists) | `ball_lost 1.0` if it carried damage, else `0.7` at gain 0.5 |
| `countdown` | each live organ's `cd` seconds tick down while a ball is in flight, shown rounded up; at 0 the intent fires, next intent shows, `cd` resets | intent icon pulses alpha 0.6..1 at 2 Hz in the last second | `timed_off 1.0` as it crosses 1 s; `hit_refused 0.5*st(off)` as it fires |
| `crit` | relic `opener` (there is no crit brick): launch `bag.pop_front()` from the paddle straight up; empty bag: nothing | `crit_launch` | `multiball_pop st(2*min(n,4))`, n = balls already in play; empty `hit_refused 0.8` |
| `empty_board` | no breakable left, a ball live: after 1.0 s one `refresh` spawns at a random original slot | `mint_spawn` | |
| `phase_end` | `balls_in_play == 0`: `on_phase_end` hooks, poison tick, in-flight hazards (`enemy_balls`, `debris`) removed, placed ones (red bricks, shield row, laser telegraph) stay; 0.8 s beat; `phase_start` | | `combo_drop 0.8`; poison `pips_shrink 0.8` |
| `organ_die` | `organ.hp <= 0`: its cells break and go, its clock stops, hazards already out keep going | `organ_die` 44x20 x8 @12 per cell, tinted | `enemy_die st(off)` |
| `win` | every organ in the encounter's `win` (default all) dead: balls freeze, hazards freed, band `<band>_die`, board bricks and live organ cells break outward with `<hue>_break` / `organ_die`, 0.6 s, gold, reward | `<band>_die` | `enemy_die 1.0` (maw `0.6`, then `run_won` at delay 1.2) |
| `lose` | `hp <= 0`: balls freeze, red field flash, 0.6 s, run over | field `ColorRect` alpha 0.25 for 0.1 s (also on every HP loss) | `hp_lose 0.7`, then `run_over` |

Fight columns (sprite px): left = HP bar + number, gold, relic icons 12x12 at pitch 13, then "PHASE %d", "DAMAGE" with this phase's total at k3 `pay`, "IN PLAY %d", "NEXT: <name>" / "BAG EMPTY", "RED BRICKS %d" when > 0, "COMBO x%.2f" while relic `combo` runs (`combo_chase` 30x12 x8 @8 beside it). Right = the bag queue in order, face at x6, name <= 9 glyphs at x18, `ui_pip_pay`/`ui_pip_off` x3 for rank, pitch 12, `ui_next` 4x5 static on the head row, "SPENT %d", DISCARD button 66x24 at y 300, hint "D DISCARD". Each organ draws an HP bar along the top edge of its cells' bounding rect, its HP and countdown labels and its intent 12x12 on itself; the band is the portrait only. Top wall line 480x2 at y 56.

### Bricks (`Tuning.BRICKS`, `Tuning.BOARDS`)

`hue` is an explicit field; `Tuning.hue(kind)` returns it. `ICON_KINDS = ["refresh", "bomb"]` means only "draws `<id>_pulse` instead of a static face" (`bomb` keeps `icon_bomb_pulse`). `pay` is renamed `dmg`. A blast hits each brick in reach once through `_trigger` (= `_damage(b, ball, false)`): a multi-hit brick loses one, an unarmed bomb arms, an armed bomb detonates; a brick it breaks never hurts and never refuses; refresh and gold fire from any break.

| id | hp | dmg | hue | effect | strips | cues |
|---|---|---|---|---|---|---|
| `plain` | 1 | 1 | mag | basic | face `brick_plain_lit` (exists); `mag_hit` 30x12 x6 @12, `mag_break` 44x20 x8 @12, `mag_spawn` 30x12 x6 @12 (exist) | `brick_hit 1.0`, `brick_break 1.0` |
| `refresh` | 1 | 1 | mint | on break: a board refresh (Lifecycle above) | `refresh_pulse` 30x12 x4 @8 idle, `refresh_wave` 60x12 x6 @12 tileable swept top to bottom; `mint_hit` 30x12 x6 @12, `mint_break` 44x20 x8 @12, `mint_spawn` 30x12 x6 @12; static `brick_refresh` | `regrow 1.0` once |
| `solid` | -1 | 0 | chrome | unbreakable | face `brick_solid`, `solid_bounce` 44x20 x6 @12 (exist) | `solid_bounce 1.0` |
| `bomb` | 2 | 0 | ora | the first hit arms it (`armed`: face and idle `bomb_fuse`, `ora_hit` flash, `cond_primed 1.0`); the second breaks it: `_blast` hits every brick with its centre within `BOMB_RADIUS` 72 once (armed bombs chain in the same frame, unarmed ones arm); the charge of every brick it breaks goes to the detonating ball. No direct damage; organs are never touched. A needle bounces off an unarmed bomb | `icon_bomb_pulse` 30x12 x4 @8 (exists, body recoloured orange), `halo_pulse_ora` 60x30 x4 @8, `bomb_ring` 60x60 x4 @12; `ora_hit`, `ora_break`, `ora_spawn` (exist) | `bomb_boom 1.0` |
| `red` | 1 | 0 | red | a ball breaking it costs the player `hurt` = 3 HP at the moment of the break; a blast just removes it | static `brick_red` 30x12; `red_hit` 30x12 x6 @12, `red_break` 44x20 x8 @12 (debris falls), `red_spawn` 30x12 x6 @12 | `brick_break 0.7`, `hp_lose` (ladder) at delay 0.05 |
| `gold` | 1 | 1 | gold | on break pays `gold` 5; under an enemy with `jackpot` it pays nothing by itself and the phase that breaks every gold brick of the layout pays `jackpot` once | static `brick_gold` 30x12 (exists); `gold_hit`, `gold_break`, `gold_spawn` (exist); `toll_pay` on the pay | `gold_hit 1.0`, pay `coin 1.0`, jackpot `jackpot 1.0` |

#### Generator (`Game.generate(cls, seed, board)`)

Every encounter draws its own board: `board.rows` in `tuning.gd` `ENCOUNTERS` or `ENEMIES` (bridged, see Encounters and organs), one glyph per brick from `BOARD_KEYS`: `.` empty, `x` plain, `?` rolled, `#` solid, `b` bomb, `R` red, `r` refresh, `g` gold; a digit `1`-`9` is a cell of the encounter's organ n (`organs[n - 1]`), never rolled or converted, kind `organ` with `organ = n - 1`. Each row centres on the arena, so a row one shorter than its neighbours sits half a step over (honeycomb). Drawn kinds stand as drawn; each `?` rolls `solid`, `bomb`, `red` at the class's per-brick chance under its hard `max`, in that order; then the `keep` refresh runs (`start` and `keep` above).

Arena is always `Tuning.ARENA`. `BOARD_TOP = 168`, `BOARD_FLOOR = 240`, step 64x28, max rows 11 (boss 10, it sits 32 lower). `test.gd` asserts every brick fits, the widest row is exactly the class's `cols` (the lane grid for `laser_sweep` and `shield_row`), and every non-solid glyph is reachable from outside the layout past the drawn solids.

| class | cols | solid | bomb | red | refresh (`KEEP_DEFAULT`, all classes) |
|---|---|---|---|---|---|
| `fight` | 11 | 0.03 max 2 | 0.03 max 2 | 0.04 max 3, rows 0-3 only | 1 |
| `elite` | 13 | 0.05 max 4 | 0.04 max 3 | 0.06 max 6 | 1 |
| `boss` | 15 | 0.06 max 6 | 0.05 max 4 | 0.08 max 10 | 1 |

Placement rules for `?` rolls (a failing roll stays `plain`): `solid` never touching `solid`, never at a row's ends or in the bottom row; `red` never touching `red`. Conversions (the default `keep`, `arena.gd` `_keep`): `refresh` takes a `plain` of no source in the top half below `no_refresh_rows`, never two in one column, else any such `plain`.

The crit brick was cut on 2026-11-11 (an organ now consumes the ball that touches it, so the phase moves to the next ball instead of multiballing); every drawn `c` became `x`. The `crit` launch lives on only through the `opener` and `twin_crit` relics.

| enemy | layout | idea |
|---|---|---|
| `glob` | 7-row blob, a plain core ringed by 4 drawn reds | the goo core costs HP to reach |
| `lobber` | battlements, a wall, solid side towers, a 3-wide gate in the bottom row | a fortress you enter by the gate or by breaking in |
| `mason` | a solid ring around a vault of plains, a 3-plain door at the bottom | break in; the shield row seals the top |
| `warden` | two solid pillars full height (zigzag on the honeycomb), plains in the middle chamber | three lanes, and the laser sweeps lanes |
| `maw` | jaws of plain, two rows of solid teeth with one-brick gaps, plains floating in the throat | shoot between the teeth |
| `rat_king` | 6-row nest of plains, plains to the corners | the corners are where the ball goes last |
| `coin_slug` | 7-row blob with one drawn gold brick in the middle | dig for the coin |
| `fuse_box` | plain walls top and bottom, a diagonal fuse of 5 drawn bombs (each 69.8 px from the next, inside `BOMB_RADIUS`) | light one end and the fuse arms down the line: each blast arms the next bomb, so one more hit apiece sets it off, the bricks it breaks credited to that ball (bombs deal no direct damage) |
| `claw_rig` | two drawn solid pillars, plains in the open lane between them | the prize lane |
| `ticket_printer` | 5 rows, plain lines between rows of rolled bricks; `advance` 1: the whole layout slides a row toward the paddle each phase while the lowest row stays above `BOARD_FLOOR` (5 phases) | the paper feeds out |
| `bootleg_cabinet` | a drawn solid case around a cracked screen (2 drawn reds beside a plain), a plain shelf, an open row and a coin door | break the case or go in by the door |
| `repo_man` | a solid vault of plains with a 3-wide door at the bottom; `shield_start`: the shield row stands at fight start | the vault opens from below; the shield row seals the top first |
| `arcade_bouncer` | two drawn solid rope lines narrowing toward the top (a V), plains across the bottom | the lane tightens toward the top |
| `jackpot_reel` | three 3-wide reels of plains with a drawn gold brick in each, a plain line below | all three golds in one phase pays the jackpot |
| `attract_mode` | a solid screen frame, open at the bottom; inside, a high-score table of plains with plains as the top score, `BOARD_TOP` +32, no `refresh` in rows 0-1 | play the table from the bottom up |

#### Every existing `tuning.gd` kind and constant

| table | id | verdict | note |
|---|---|---|---|
| BRICKS | `plain`, `solid` | keep | as above; `pay` -> `dmg` |
| BRICKS | `hole` | cut | gaps are `density` |
| BRICKS | `multi`, `multi3`, `shield`, `cond`, `cgate`, `timed`, `seq1..3` | cut | `shield` rows are `solid`; strips stay generated |
| ICON | `bomb` | keep, retimed | arms then detonates; `bomb_fuse` is the armed face and idle, `fuse_lit` cue unused |
| ICON | `speedup`, `slowdown`, `x2`, `x3`, `combo`, `timer`, `chain`, `bolt`, `jackpot`, `mystery` | cut | `combo` returns as a relic id (no collision once the brick is gone); `jackpot` -> relic `toll` |
| PLACEABLES | all eight | cut | relic candidates; faces stay; `magnet` numbers move to relic `magnet_paddle` |
| PIECES | `paddle`, `wall` | keep | `paddle_mini` face for relic `mini_paddle` |
| const | `LEVELS` | replace | `BOARDS` above |
| const | `ROUND_TIME_BASE`, `TIME_BAR_PX`, `COMBO_WINDOW_SHRINK`, `COMBO_WINDOW_MIN`, `SPEEDUP`, `SLOWDOWN`, `BOOST_HITS`, `COMBO_EXTEND`, `TIME_EXTEND`, `CHAIN_DIST`, `FUSED`, `FUSE`, `JACKPOT_MULT`, `GATE_COMBO`, `CHASE_AT`, `PLACE_UP`, `PLACE_MARGIN`, `ROTATE_DEG`, `CAPACITY_BASE`, `POP_SPEED`, `ACCEL_SPEED`, `PASS_GRACE`, `SPAWN_EVERY`, `COST_MULT`, `SEED_UPGRADE`, `UPGRADES`, `CATS` | cut | `PLACE_UP` becomes `BOARD_FLOOR` 240 |
| const | `COMBO_WINDOW_START` 1.0, `COMBO_MULT_PER_HIT` 0.25 | keep | relic `combo` |
| const | `STICKY_HOLD` | keep, 1.5 | |
| const | `MAGNET_RADIUS` 160, `MAGNET_PULL` 700 | keep | relic `magnet_paddle` |
| const | `BOMB_RADIUS`, `SPEED_MIN`, `SPEED_MAX`, `FAST_SPEED`, `BALL_*`, `PADDLE_*`, `MAX_BOUNCE_DEG`, `MIN_VERTICAL`, `BRICK_SIZE`, `BRICK_GAP`, `ARENA`, `COLORS` | keep | `BOARD_TOP` -> 168 |
| new | `RUN`, `MAP`, `EVENTS`, `REWARDS`, `SHOP`, `BALLS`, `BAG_START`, `RARITY`, `BOARDS`, `ENEMIES`, `HAZARDS`, `RELICS`, `UNLOCKS`, `TOP_WALL` 112, `SHIELD_Y` 140, `BOARD_FLOOR` 240 | add | |

### Encounters and organs (`Tuning.ENCOUNTERS`, `Tuning.ORGANS`)

One encounter per fight. An **organ** is one enemy living in the board: one HP bar, its own `cd`, intent cycle and poison, drawn with a digit glyph; its cells are `Box`es of `PIECES.organ` (face `organ_cell`, `hp = -1`, so never in `_live`, `_near`, refresh or the win check), tinted by the organ's `tint`. The band above the top wall is the encounter's portrait (`band` strips at width `w`); no rule reads it. `Tuning.organ(id)` reads `ORGANS`, else an `ENEMIES` row; `Tuning.encounters()` is `ENCOUNTERS` then `ENEMIES` ids (pairwise disjoint). `stats.killer` is the hazard's organ id; `meta.seen` and the catalog key by encounter.

| organ | HP | cd | intents | off | tint |
|---|---|---|---|---|---|
| `knight_body` | 60 | 14 s | `debris` x4 | -3 | `e0a040` |
| `knight_sword` | 25 | 8 s | `laser_sweep` x1, `enemy_balls` x2 | 0 | `c0d0ff` |
| `knight_shield` | 30 | 12 s | `shield_row` (ponytail: stands in for the deferred `grow`) | -5 | `80c0a0` |

| encounter | role | tier | organs | cd_start | win | band | board |
|---|---|---|---|---|---|---|---|
| `knight` | regular | 1 | 1 body, 2 sword, 3 shield | 14 / 4 / 9 s | `knight_body` | `warden` 64 (borrowed) | 11 cols, 6 rows: the shield (3) a 2x3 block on the left, the body (1) a cross in the middle, the sword (2) a 1x4 column on the right, lanes of `?` between |

Bridge (`Tuning.encounter(id)` for an `ENEMIES` id): one organ (the row itself), `win` = it, band = its own strips, its board with `111` stamped at the centre of the top row (over plain, rolled, empty or solid cells only, so no vault is sealed and no drawn kind is lost); `steal`, `jackpot`, `advance`, `shield_start` carry over as encounter fields. `riposte`, `twice`, `mimic`, `enraged`, `mouth` are organ fields.

#### Enemies (`Tuning.ENEMIES`, bridged)

Each row is a one-organ encounter through the bridge. `tier` = earliest layer. Intents cycle in order; each entry is `hazard x count` (bare = x1). `board` is the drawn layout (Generator above).

| id | role | tier | HP | cd | board | intents | strips (W x 48 sprite px) | cues (`off` st) |
|---|---|---|---|---|---|---|---|---|
| `glob` | regular | 1 | 30 | 12 s | goo blob, a core behind reds | `red_bricks` x3, `debris` x4 | `glob_idle` 48 x4 @8, `glob_hit` 48 x6 @12, `glob_attack` 48 x6 @12, `glob_die` 48 x8 @12 | 0 |
| `lobber` | regular | 1 | 40 | 10 s | fortress with a gate | `enemy_balls` x1, `enemy_balls` x3 | `lobber_idle/_hit/_attack/_die` 48, same counts | -2 |
| `mason` | regular | 3 | 55 | 12 s | solid-ringed vault | `shield_row`, `debris` x6 | `mason_*` 64 | -4 |
| `warden` | elite | 4 | 120 | 10 s | two solid pillars, a middle lane; **riposte**: an organ hit landing 10+ takes 2 s off the countdown | `laser_sweep` x1, `enemy_balls` x3, `shield_row` | `warden_*` 64 | -5 |
| `maw` | boss | 5 | 240 | 8 s | jaws with solid teeth, plains in the throat, `BOARD_TOP` +32, no `refresh` in rows 0-1; below 50% HP `cd` 6 s and the mouth holds 6 hits | `debris` x8, `mouth`, `laser_sweep` x2 | `maw_*` 160; `maw_mouth_open` 48x16 x6 @12 (hold last), `maw_mouth_close` 48x16 x6 @12 | -7 |
| `rat_king` | regular | 1 | 35 | 12 s | nest | `coin_junk` x1, `debris` x3 | `rat_king_*` 64 | +3 |
| `coin_slug` | regular | 1 | 40 | 10 s | one gold brick mid blob | `coin_junk` x2, `red_bricks` x2 | `coin_slug_*` 48 | -1 |
| `fuse_box` | regular | 2 | 45 | 12 s | a diagonal fuse of bombs | `red_bricks` x2, `debris` x6 | `fuse_box_*` 48 | +1 |
| `claw_rig` | regular | 2 | 50 | 10 s | two pillars, a lane between | `pull` x1, `enemy_balls` x2 | `claw_rig_*` 64 | -3 |
| `ticket_printer` | regular | 2 | 45 | 12 s | rows that feed toward the paddle; **advance** 1 row per phase | `jam` x1, `red_bricks` x4 | `ticket_printer_*` 48 | +2 |
| `bootleg_cabinet` | regular | 3 | 55 | 10 s | a solid case, a cracked screen | `enemy_balls` x3, `debris` x4 | `bootleg_cabinet_*` 48 | -2 |
| `repo_man` | elite | 4 | 110 | 10 s | a vault, the shield row up at fight start; **steal** 1: every ball that drops costs 1 gold (not below 0) | `shield_row`, `coin_junk` x2, `debris` x6 | `repo_man_*` 64 | -6 |
| `arcade_bouncer` | elite | 4 | 130 | 10 s | solid rope lines narrowing upward; **twice** 0.3: a phase's first intent fires again 0.3 s later | `jam` x2, `enemy_balls` x4 | `arcade_bouncer_*` 64 | -5 |
| `jackpot_reel` | elite | 4 | 115 | 12 s | three reels with a gold brick each; **jackpot** 30: its gold bricks pay only when all three break in one phase | `pull` x1, `red_bricks` x3, `debris` x8 | `jackpot_reel_*` 64 | -3 |
| `attract_mode` | boss | 5 | 220 | 8 s | a screen frame, a high-score table, `BOARD_TOP` +32, no `refresh` in rows 0-1; below 50% HP **mimic**: each `enemy_balls` ball copies the run bag's next ball in order (its size and speed; a splitter's fan of `split` copies; a needle has nothing to pass and flies plain) | `jam` x1, `enemy_balls` x5, `pull` x1 | `attract_mode_*` 160 | -8 |

Enrage is one rule: a row's `enraged` fields (`cd`, `mouth`, `mimic`) merge into the enemy once its HP is at or below `enraged.at` of its max (`_land`).

Shared: the enemy sprite sits behind balls and bricks, bottom centre at sprite (240,54), in the bare band above the top wall body (y 112). The hazard spawns on frame 3 of `<id>_attack`; `<id>_hit` on every landed shot; `<id>_die` on the win, then outward board break. Statics `enemy_<id>` are frame 0 of `<id>_idle` (no separate sprite). Cue per moment: hit `bumper_hit 0.6*st(off)`, attack `hit_refused 0.5*st(off)`, die `enemy_die` (`1.0`, maw `0.6`), enter `fast_whoosh 0.6` + `bumper_hit 0.5` d0.3.

Boss intent `mouth` (not a hazard): opens a 48x16 sprite zone at the top centre (game x 432..528, y 0..32) for 4 paddle hits (6 below 50% HP); any player ball entering it is removed like a drop (stored lost, to the discard pile); on close every eaten ball is spat back as one `enemy_balls` ball aimed at the paddle, 0.4 s apart. Icon `intent_mouth`. Cues: open `fast_whoosh 0.5`, a ball eaten `teleport_in 0.6`, close `blast 0.5`.

### Hazards (`Tuning.HAZARDS`)

Hazards are arena children on their own collision layer: they pass through bricks and player balls, bounce off side walls where stated, never off the floor, despawn silently past the paddle line (dropping them is free). Any hazard touching a paddle (`mini_paddle` too) costs its `hp` and plays `paddle_hurt` 60x8 x4 @12 (red twin of `paddle_hit`) + `hp_lose`. In-flight hazards are freed at phase end and fight end. Icons `intent_<id>` 12x12 red-on-dark statics.

| id | numbers | effect | strips | cues |
|---|---|---|---|---|
| `red_bricks` | `count` per intent; targets: live `plain` in the 3 live rows nearest the paddle, random, never adjacent to another `red` if avoidable | each target becomes kind `red` (3 HP on a ball break); a refresh respawns the slot as its original kind | `red_bricks_paint` 30x12 x6 @12 per target, staggered 0.05 s | `cond_primed 0.6` per target, one semitone lower each |
| `enemy_balls` | `count`; speed 192.5 (0.55x), radius 8, spread +-15 deg evenly (1 ball = straight at the paddle's x), 0.15 s apart, `hp` 5 | spawn at the firing organ's centre after a 0.8 s wind-up; straight flight, side walls bounce; ends on paddle contact or past the line | `enemy_balls_warn` 8x8 x4 @8 loop at the spawn point, `enemy_balls_fly` 8x8 x4 @8 loop (animations.md's `enemy_ball`, renamed) | `ball_launch 0.5` per ball, wall `ball_bounce 0.6` |
| `debris` | `count`; chunks 16x16, 240 px/s, 80 apart centred on the organ (clamped to the field), 0.2 s stagger, `hp` 3 | board shakes 4 px for 0.3 s, then chunks fall from the firing organ's bottom edge; ends on paddle or floor | `debris_fall` 8x8 x4 @8 loop, `dust_puff` 12x8 x4 @12 (exists) at the floor | `blast 0.6` on the shake, floor `solid_bounce 1.3` at gain 0.5 |
| `laser_sweep` | lanes = `count` (1, or 2 = paddle column + its mirror); warn 1.0 s, beam 0.4 s, `hp` 6 once per beam | picks the 64-wide board column under the paddle centre at fire time; paddle centre inside during the beam pays; a ball inside has `stored` set to 0 once per beam; bricks untouched; telegraph persists across a phase end | `laser_sweep_warn` 30x6 x4 @8 tiled from the top wall to the floor, `laser_sweep_fire` 30x6 x6 @12 tiled | warn `ui_reveal 0.5`, beam `bolt_sweep 0.8`, ball zapped `combo_drop 1.2` |
| `shield_row` | `shield_hits` 8 paddle hits; a refire resets to 8 | a full row of `solid` at centre y `SHIELD_Y` 140 (one per board column), balls bounce off it; crumbles when the hits run out or the fight ends; never part of the refresh layout | raise and crumble: `dust_puff` per brick; face `brick_solid` | raise `armor_pop 0.7`, crumble `solid_bounce 0.8` |
| `shield_bricks` | `count` per intent, `hp` 0, `layer` "shield" (an organ row's `layer` wins, e.g. "ward"); no enemy intends it yet | the `count` live bricks nearest the firing organ, then its own cells, gain the layer with source `enemy:<organ id>` (same kind adds hp; another kind is passed over); the organ's death removes them | per brick none on raise; `armor_pop` / `shield_pop` on pop; icon `intent_shield_bricks` | raise `armor_pop 0.7` |

| `jam` | `hits` 6, `width` 0.5; a refire resets the count | the paddle (not relic `mini_paddle`'s) draws and collides at half its built width for the next 6 paddle hits on it, then springs back; survives a phase end | `jam_clamp` 60x8 x6 @12 over the built width, ending on the half paddle; face `paddle_jam` 30x8 (stretched like `paddle`) | `paddle_jam 1.0` on fire and refire, `grow 1.0` when it wears off |
| `pull` | `secs` 1.0 per count, `force` 490 px/s^2 (half gravity); no body, so `flight` only means a pull still pending dies with the phase | every player ball in flight gets `force` upward in `_move_ball` for `secs`; speed is kept, the heading bends up, so stored damage risks going back into the bricks | `pull_drift` 12x16 x4 @8 once over each ball in flight | `pull_lift 1.0` |
| `coin_junk` | `count`, `junk` = `ball_junk` | per count a stone goes on top of the fight's bag and into the run's bag for good (autosaved with the next screen) | none; the bag column shows it | `coin 0.7` then `teleport_out 0.5` at delay 0.1 per stone, +2 st each further one |

Persistence: `red_bricks`, `shield_row`, `jam` and a pending laser telegraph survive a phase end; `enemy_balls`, `debris` and `pull` do not; `coin_junk` is in the bag.

### What has not landed (from docs/content/encounters.md)

Proposal, 2026-11-10. The first slice landed the same day (its rows are the sections above): the knight encounter, organ cash-in with reset, the paddle no longer landing damage, armed bombs, placeholder organ art, and a bridge that plays every `ENEMIES` row as a one-organ encounter. What follows is still proposal.

#### Rules still to build

| topic | rule |
|---|---|
| Encounter script | An encounter can react to events: an organ below an HP mark, an organ dead, a phase number. Reactions: spawn organs, swap the board, change an organ's fields. Deep Net's `fork_bomb` split and `trojan` reveal are scripts, not enemy signatures. |
| `grow` | An organ effect: n plains grow around the organ. The knight's shield fires `shield_row` as a stand-in until it exists. |
| The maw's mouth | A mouth organ: it swallows balls that touch it and spits them back as enemy balls (the old band zone goes). Today the bridged maw keeps the band zone. |
| `ball_magnet` | Flips: a charged ball is drawn to the nearest organ. `magnet_paddle` (relic) keeps pulling to the paddle, as survival. |
| Band mirrors organs | The band portrait shows what the organs do (the sword raised when the sword organ winds up, the shield cracked when it is hurt). Today it plays `hit` on any landed shot, `attack` on any intent and `die` on the win. |

Deferred: refresh regrowing the bricks that bury organs could stall a fight. If play shows it, exclude organ-adjacent cells from refresh.

#### Converting enemies

Every `ENEMIES` row plays through the bridge (`Tuning.encounter`), which stamps a 3-cell organ at the board centre. Each should instead become an authored encounter that draws its organ into the board's thematic centre (the glob's goo core, the coin slug's gut, the mason's vault). Elites and bosses are the first to split into several organs. The map proposals convert the same way: `fork_bomb` and `trojan` become encounter scripts. When the last row converts, the bridge and `ENEMIES` go.

#### Art

- Each organ needs its own look: a face for its cells plus one overlay sprite sized to its footprint (the sword, the shield), and `<organ>_hit` / `<organ>_die` strips, keyed by per-organ `face`, `hit` and `die` fields on `ORGANS` that replace today's `tint` over the grey-white `organ_cell`.
- The knight needs its own band portrait; it borrows the warden's.

#### Playtest questions

If aiming at organs feels like luck, the levers are organ size, open lanes in the authored board, and `sticky` / `ball_magnet` in the starting pools. The knight is tier 1 (proposed 2) so the playtest meets it from the first node; move it once the question is answered.
