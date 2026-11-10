# Content contract (demo: one act, "Peglin but breakout")

The single source for asset and code agents. It resolves the eight pool specs; where this file and a pool spec differ, this file wins. Numbers are game px (arena-local, 960x720) unless a column says sprite px (half). Strips are `assets/pixel/png/anim_<name>.png`; a strip column reads `name WxH xN @fps` with W,H in sprite px. Cues are `assets/audio/wav/<name>.wav`; a cue column reads `name rate` (`st(n)` = n semitones). Statics are plain sprites (`<name>.png`), one frame. "exists" means the asset is already generated; everything else is new.

Vocabulary: a **fight** is one enemy on one board. A **phase** is one launch from the bag until every ball in play has dropped (design.md's "turn"). A **paddle hit** is a player ball touching a paddle; it is the one clock in a fight.

## Decisions that cut across pools

| topic | decision | lost proposals |
|---|---|---|
| Enemy attack timing | **Paddle hits** (enemies.md and hazards.md agreed; run.md adopted it). Every enemy has `cd`; each paddle hit by a player ball drops it by 1; at 0 the current intent fires on the spot, mid-phase, and the next intent (cyclic) shows with `cd` reset. Hostile objects touching the paddle do not count. Nothing fires between phases; the between-phase beat is 0.8 s of the enemy idling. | screens.md "YOUR TURN / ENEMY TURN" bands and `turn_you`/`turn_enemy` cues; design.md core loop step 3 is reworded to "enemies act mid-phase on a paddle-hit countdown". |
| Hazard ids | `red_bricks`, `enemy_balls`, `debris`, `laser_sweep`, `shield_row` (five). | `floor_goo` (no enemy intends it), `fuse` brick, `mouth` is a boss intent, not a hazard id. |
| Hazard damage | One number per hazard row (HAZARDS table), not per enemy. Elite and boss hit harder through `count`. | enemies.md `atk` column. |
| Red brick HP cost | 3 (bricks pool owns the row). | hazards.md 4. |
| Shield row | A full row of `solid` bricks at `SHIELD_Y`, gone after `shield_hits` paddle hits. | enemies.md hp-3 reward-less bricks. |
| Fight layout | Enemy band 0..112, top wall body at y 112, shield row centre 140, `BOARD_TOP` 168 (boss 200), `BOARD_FLOOR` 240, rows <= 11 (boss <= 10). | bricks.md 156, screens.md 140, enemies.md 120. |
| Player HP | 50. | design.md's implied 100. |
| Prices and income | run.md owns: ball 15, relic 40/60/80, remove 12, heal 20 for +20 HP, fight gold 12+rand 0..6, elite 30+rand 0..6, gold card 30. | balls.md 25/40/60, relics.md 60/100/150, screens.md remove 25+10 and heal +15. |
| Map | run.md: 9 nodes, 5 layers, forced shop in layer 4, elite in layer 3 slot 0, nodes at x = 60 + 90*(layer-1). Legend lives in the left column. | screens.md 8-node topology and field legend. |
| Ball ids | `ball_<name>`; faces are frame `rank-1` of `<id>_rank`. | run.md save shape with bare `basic`; screens.md static `ball_<id>`. |
| Enemy strips | enemies.md names `<id>_idle/_hit/_attack/_die`, sizes 48/48/64/64/160 wide, 48 tall. Anchor bottom centre at sprite (240,54). HP bar at the top of the field (screens.md). | screens.md `enemy_<id>_hurt`, boss 64x48, enemies.md under-feet bar. |
| Intent icons | `intent_<hazard_id>` plus `intent_mouth`, 12x12 statics; pulse in-engine when the countdown is 1. | `ui_intent_*`, `<id>_intent`, `intent_shield`, `intent_heal`. |
| Cards | One `card_frame` (+`_hot`, `_dim`) 36x48 with a separate face. | `card_ball`, `card_relic`, `card_gold`, `card_rank`. |
| Relic icons | `relic_<id>` 12x12 statics. | relics.md 10x10. |
| Sound | sound.md owns: **five new wavs** (`damage_land`, `hp_lose`, `enemy_die`, `run_over`, `run_won`); every other moment plays an existing cue at a rate. Player events at or above 1.0, enemy events at or below 0.8. Enemy cue offsets `off`: glob 0, lobber -2, mason -4, warden -5, maw -7 semitones. | every other pool's new cue name (`dmg_fire`, `hp_hit`, `paddle_hurt`, `red_paint`, `laser_*`, `debris_slam`, `goo_hum`, `relic_get`, `shield_floor_pop`, `poison_tick`, `junk_thud`, `ball_rank_up`, `map_pick`, `map_hop`, `gold_gain`, `reward_pick`, `shop_buy`, `event_pick`, `intent_tick`, `<enemy>_attack`, `maw_mouth_*`). Cues `recall` and `coin` already exist and are reused. |
| Discard | Once per phase while a ball rests on the paddle: D, right-click or the DISCARD button moves it to the discard pile and rests the next. | balls.md "to the back of the queue"; screens.md "removed for the fight". |
| Empty board | One mechanism, the refresh: mid-phase, 1.0 s after the last breakable goes with a ball still live, one `refresh` spawns at a random original slot; at phase start with fewer than `regen_below` 10 breakables left the board refreshes for free. | run.md re-generation with a new seed. |
| Poison tick | At phase end (the 0.8 s beat): enemy takes `stacks`, then `stacks = floor(stacks / 2)`. | balls.md "start of the enemy turn". |

## Run state (`Tuning.RUN`, `game.gd`)

| id | numbers | effect | strips | cues |
|---|---|---|---|---|
| `hp`, `hp_max` | 50 / 50 | 0 ends the run; heals cap at max | HP bar in-engine 68x3 sprite px, left column | `hp_lose` on any loss: 1-2 `1.0`, 3-5 `0.85`, 6+ `0.7`; `time_low 0.5` once per phase start while hp <= 12 |
| `gold` | 0 | one integer currency | `coin` 8x8 (exists) | `coin 1.0` on any gain; `count_tick 1.0` while the number rolls |
| `bag` | start `ball_basic` x4, `ball_heavy`, `ball_pierce`, all rank 1 | list of `{id, rank}`; launch order; shuffled at fight start | faces per ball | |
| `relics` | `[]` | ids, no duplicates | `relic_<id>` 12x12 | |
| `seed` | `randi()` at run start | one `RandomNumberGenerator` seeded `seed + node index` per roll site, so a reload replays map, shop and rewards | | |
| `stats` | `fights`, `elites`, `damage`, `bricks`, `best_fire`, `drops`, `gold_earned`, `seconds`, `killer` | end-screen lines | | |
| `enemy_turn` | 0.8 s | between-phase beat | | `combo_drop 0.8` at phase end |
| `regen_below` | 10 | breakables left at phase start that trigger a free refresh | `refresh_wave` | `regrow 1.0` |
| `ramp_on`, `ramp_after`, `ramp_per_s`, `ramp_max` | false, 20 s, 0.02, 1.6 | speed ramp on long-lived balls (design.md fallback, off by default); a sticky catch or re-bagging resets it | `ball_trail` at >= `FAST_SPEED` | |

Save: `user://run.json` `{version, seed, hp, hp_max, gold, bag, relics, map{layers, enemies, events, path, layer, node}, stats}`; written on map entry, after a reward pick, an event choice and each shop purchase; never mid-fight (a fight restarts on load: `# ponytail: one re-rolled fight per quit`). Deleted when an end screen opens or NEW RUN is pressed. Present file = CONTINUE on the menu. `tests/smoke.tscn` saves and restores it. The dev `sandbox.json` slot is cut.

### Map (`Tuning.MAP`)

| layer | width | slot kinds | edges (slot -> next slots) |
|---|---|---|---|
| 1 | 2 | `fight`, `fight` | 0 -> {0,1}, 1 -> {1,2} |
| 2 | 3 | each: `fight` 50 / `event` 30 / `treasure` 20; if none rolled `fight`, slot 1 is `fight` | every slot -> {0,1} |
| 3 | 2 | slot 0 `elite`; slot 1: `fight` 60 / `event` 40 | both -> {0} |
| 4 | 1 | `shop` | -> {0} |
| 5 | 1 | `boss` | none |

`fight` picks an enemy of tier <= layer, equal weight, never the previous fight's enemy. Events draw without replacement. Nodes at field x = 60 + 90*(layer-1), y spread evenly (2: 120/240; 3: 90/180/270; 1: 180). Node sprites `map_node_fight/elite/treasure/shop/event` 12x12 and `map_node_boss` 16x16 statics; reachable 1.0 with `map_ring_pulse` 16x16 x4 @8 around it, visited 0.5, unreachable alpha 0.35; edges 1 px `trim_hi` in-engine, the walked edge `pay`. The `ball` sprite (exists) marks the player, hops by tween 0.3 s. Header "NODE %d/5". Cues: node click `ui_start 1.0`, unreachable `ui_invalid 1.0`, map open `ui_unpause 1.0`, hover `ui_hover 1.0`, next layer lights `ui_reveal 0.8`.

### Gold, rewards, shop, events

| id | numbers | effect | strips | cues |
|---|---|---|---|---|
| `gold_fight` | 12 + rand 0..6 | on a regular win, shown "+N GOLD" on the reward panel | | `coin 1.0` |
| `gold_elite` | 30 + rand 0..6 | elite win | | `coin 1.0` |
| `reward_ball` | weight 40 | random unlocked non-junk ball at rank 1 (duplicates allowed) | `card_frame` + face | `ui_buy 1.0` |
| `reward_rank` | weight 25 | random owned ball with rank < 3 at its next rank; none eligible = reroll the kind | card + `ui_badge` (exists) "UP" | `ui_unlock 1.0` |
| `reward_relic` | weight 15 | random unowned unlocked relic, rarity weight 3/2/1; none left = reroll | card + `relic_<id>`, `relic_get` 36x48 x6 @12 | `cond_primed 1.0` |
| `reward_gold` | weight 20, +30 | gold card | card + `coin` x2 | `coin_cascade 1.0` |
| reward screen | 3 cards of distinct kinds, SKIP (`ui_click`) | after a regular or elite win; elite then shows 3 relic cards with no skip | panel open: `card_frame_hot` on hover | `round_clear 1.0` on win, `mystery_reel 1.3` as cards show |
| `treasure` | 3 relic cards, no skip, no gold | | same | `lock_open 1.0` on open |
| `shop_ball` | 3 distinct unlocked balls, 15 each | adds to the bottom of the bag | cards at y 40, centres x 90/170/250 | `ui_buy 1.0`; refused `ui_cant_afford 1.0` |
| `shop_relic` | 2 distinct unowned relics, 40 / 60 / 80 by rarity | adds the relic | cards at centres x 370/450 | `ui_buy 1.0` |
| `shop_remove` | 12, repeatable | REMOVE enters pick mode on the bag column (`ui_slot_hover`, exists); deletes one copy, junk included; refused (`ui_invalid`) when it would leave no non-junk ball | | `teleport_in 0.8` |
| `shop_heal` | 20 gold, +20 HP, once per visit | disabled at full HP | | `grow 1.0`, `coin 0.8` at delay 0.1 |
| shop screen | | `lamp_hum` loop while open; LEAVE in the right column | | `ui_unpause 1.0` on enter, `ui_back` on leave |
| `event_forge` | A: random owned ball rank < 3 gains a rank, `hp -= 6` (floor 1); B: `gold += 20` | A COLD FORGE / THE COALS STILL GLOW. A HAMMER WAITS. / HAMMER A BALL / TAKE THE SCRAP | | open `mystery_reel 1.0`, choice `ui_click 1.0`, good `ui_unlock 1.0`, bad `ui_cant_afford 0.8` |
| `event_vendor` | A (20 gold): random unowned common/uncommon relic, dimmed if unaffordable or none; B: 50% the relic free, 50% a `ball_junk` joins the bag | A GHOST VENDOR / IT HOLDS OUT A RELIC AND SAYS NOTHING. / BUY IT (20) / HAGGLE | | junk added `teleport_out 0.5` |
| `event_spring` | A: `hp += 15`; B: `gold += 25`, `hp -= 5` (floor 1) | A HOT SPRING / STEAM. SOMETHING SHINES UNDER THE WATER. / BATHE / DIVE FOR COINS | | |

Event frame: panel (120,60) 400x230 sprite px, title k2 `pay`, body k1 wrapped 368, two choice buttons 368x18; after a choice the body swaps to the result line and one CONTINUE button (`ui_reveal 1.0`) applies it and autosaves.

## Fight pipeline (`arena.gd`)

| step | rule | strips | cues |
|---|---|---|---|
| `fight_start` | build the enemy's drawn board (`?` rolls from `BOARDS[class]`), enemy drops into the band, shuffle the bag, discard pile empty | `<enemy>_idle` loop | `round_go 1.0`; `fast_whoosh 0.6` then `bumper_hit 0.5` at delay 0.3 |
| `phase_start` | bag empty: shuffle the discard pile into it. `< regen_below` breakables: free refresh. Rest `bag[0]` on the paddle; click/space launches straight up with the paddle-offset angle | | `ball_launch st(rank-1)` (junk `0.6`) |
| `discard` | once per phase while a ball rests: D / right-click / DISCARD button; head ball to the discard pile, next rests | | `ui_drop 1.0` |
| `store` | a ball breaking a brick adds `ball.dmg * brick.dmg` to `ball.stored` (relic `combo` scales) | `stored_tag` 25x8 x4 @8 rides 6 sprite px above the ball, number as a `pay` label, hidden at 0 | |
| `fire` | paddle contact: `enemy.hp -= stored`, `stored = 0`; 0 stored is a plain catch. Every contact is one paddle hit for the countdown. Warden: 10+ landed drops it by 2 | `damage_fire` 60x8 x6 @12 on the paddle; `<enemy>_hit`; number flies to the HP bar over 0.25 s then the bar shrinks | `damage_land`: 1-9 `1.0`, 10-29 `st(2)`, 30-99 `st(4)`, 100+ `st(7)`; `bumper_hit 0.6*st(off)`; `count_tick 1.0` per tick; 0 stored: `paddle_hit` speed ladder (heavy `0.7`) |
| `drop` | past the paddle line: stored lost, ball to the discard pile; relics `shield_floor`, `recall` intercept | `ball_lost` 12x12 x6 @12 (exists) | `ball_lost 1.0` if it carried damage, else `0.7` at gain 0.5 |
| `countdown` | per paddle hit `cd -= 1`; at 0 the intent fires, next intent shows, `cd` resets | intent icon pulses alpha 0.6..1 at 2 Hz when `cd == 1` | `timed_off 1.0` when it reaches 1; `hit_refused 0.5*st(off)` as it fires |
| `crit` | `crit` breaks: launch `bag.pop_front()` from the paddle straight up; empty bag: nothing | `crit_launch` | `multiball_pop st(2*min(n,4))`, n = balls already in play; empty `hit_refused 0.8` |
| `empty_board` | no breakable left, a ball live: after 1.0 s one `refresh` spawns at a random original slot | `mint_spawn` | |
| `phase_end` | `balls_in_play == 0`: `on_phase_end` hooks, poison tick, in-flight hazards (`enemy_balls`, `debris`) removed, placed ones (red bricks, shield row, laser telegraph) stay; 0.8 s beat; `phase_start` | | `combo_drop 0.8`; poison `pips_shrink 0.8` |
| `win` | `enemy.hp <= 0`: balls freeze, hazards freed, `<enemy>_die`, board bricks break outward from the enemy with `<hue>_break`, 0.6 s, gold, reward | `<enemy>_die` | `enemy_die 1.0` (maw `0.6`, then `run_won` at delay 1.2) |
| `lose` | `hp <= 0`: balls freeze, red field flash, 0.6 s, run over | field `ColorRect` alpha 0.25 for 0.1 s (also on every HP loss) | `hp_lose 0.7`, then `run_over` |

Fight columns (sprite px): left = HP bar + number, gold, relic icons 12x12 at pitch 13, then "PHASE %d", "DAMAGE" with this phase's total at k3 `pay`, "IN PLAY %d", "NEXT: <name>" / "BAG EMPTY", "RED BRICKS %d" when > 0, "COMBO x%.2f" while relic `combo` runs (`combo_chase` 30x12 x8 @8 beside it). Right = the bag queue in order, face at x6, name <= 9 glyphs at x18, `ui_pip_pay`/`ui_pip_off` x3 for rank, pitch 12, `ui_next` 4x5 static on the head row, "SPENT %d", DISCARD button 66x24 at y 300, hint "D DISCARD". Enemy HP bar 160x4 at field (160,2), number k1 at (324,2), intent 12x12 at (330,2), countdown k2 at (346,0), top wall line 480x2 at y 56.

## Balls (`Tuning.BALLS`)

Common: `dmg` is per brick broken, `size` and `speed` multiply `BALL_RADIUS` 8 and `BALL_SPEED` 480, three ranks raise the numbers only. Trait numbers are `[r1, r2, r3]`. Rarity roll: common 60 / uncommon 30 / rare 10, then uniform within the tier among unlocked members (empty tier rerolls). `BAG_START = [ball_basic x4, ball_heavy, ball_pierce]`.

| id | name | rarity | dmg | size | speed | effect | strips | cues |
|---|---|---|---|---|---|---|---|---|
| `ball_basic` | PEBBLE | common | 1/2/3 | 1.0 | 1.0 | none | `ball_basic_rank` 8x8 x3 still (frame 2 == `ball`) | |
| `ball_heavy` | BOULDER | common | 3/5/7 | 1.5 | 0.8 | none beyond the numbers | `ball_heavy_rank` 12x12 x3 | paddle catch `paddle_hit 0.7` |
| `ball_split` | SPLITTER | common | 1/2/3 | 1.0 | 1.0 | first break after each launch or paddle hit: becomes `split` = 2/2/3 balls fanned +-20 deg; halves are full copies that cannot split again until the next paddle hit, each stores its own damage | `ball_split_rank` 8x8 x3; `ball_split_pop` 16x16 x6 @12 | `split_pop 1.0` |
| `ball_pierce` | NEEDLE | uncommon | 1/2/3 | 0.75 | 1.2 | after each launch or paddle hit passes through and breaks the next `pierce` = 3/5/8 bricks; `solid`, walls and paddles always bounce it | `ball_pierce_rank` 6x6 x3; `pierce_trail` 24x8 x4 @12 (exists) while piercing | `pierce_swish 1.0` per brick |
| `ball_sticky` | GUM | uncommon | 2/3/4 | 1.0 | 1.0 | the first `catches` = 1/2/3 paddle contacts per phase catch it: damage fires, the ball sits `STICKY_HOLD` 1.5 s or until click/space, relaunches toward the mouse clamped to `MAX_BOUNCE_DEG` | `ball_sticky_rank` 8x8 x3; `sticky_hold` 30x16 x6 @8 (exists, holds its last frame) | `sticky_catch 1.0`, `sticky_fire 1.0` |
| `ball_bomb` | BLASTER | uncommon | 1/2/3 | 1.0 | 1.0 | every `every` = 5/4/3rd brick it breaks (per fight) also fires a `BOMB_RADIUS` blast at that brick through `_trigger`; blast-broken bricks are credited to this ball, no direct damage | `ball_bomb_rank` 8x8 x3; `bomb_ring` 60x60 x4 @12 (exists) | `bomb_boom 1.0` |
| `ball_poison` | SPORE | rare | 0/0/1 | 1.0 | 1.0 | each brick also stores `poison` = 1/2/3 stacks; stacks land with the damage; tick at phase end (above) | `ball_poison_rank` 8x8 x3; `ball_poison_land` 12x12 x4 @12 on the paddle | tick `pips_shrink 0.8` |
| `ball_junk` | STONE | none | 0 | 1.0 | 0.9 | breaks bricks, stores nothing, a crit it breaks does not launch; no ranks, never a card, removable at the shop, added by `event_vendor` | `ball_junk_rank` 8x8 x1 | launch `ball_launch 0.6`, its breaks `brick_break 0.6` |

Locked: `ball_bomb` until `finished_run`, `ball_poison` until `killed_elite`. Invariant: the bag always holds at least one non-junk ball (removal refuses). Every ball reuses `ball_bounce` 12x12 x6 @12 and `ball_trail` 24x8 x4 @12 at >= `FAST_SPEED` (exist); `ball_bounce 1.0` on walls.

## Bricks (`Tuning.BRICKS`, `Tuning.BOARDS`)

`hue` is an explicit field; `Tuning.hue(kind)` returns it. `ICON_KINDS = ["crit", "refresh", "bomb"]` means only "draws `<id>_pulse` instead of a static face" (`bomb` keeps `icon_bomb_pulse`). `pay` is renamed `dmg`. A brick removed by a blast never hurts and never refuses; crit and refresh fire from any break through `_trigger`.

| id | hp | dmg | hue | effect | strips | cues |
|---|---|---|---|---|---|---|
| `plain` | 1 | 1 | mag | basic | face `brick_plain_lit` (exists); `mag_hit` 30x12 x6 @12, `mag_break` 44x20 x8 @12, `mag_spawn` 30x12 x6 @12 (exist) | `brick_hit 1.0`, `brick_break 1.0` |
| `crit` | 1 | 1 | blue | on break: launch the next bag ball from the paddle (see `crit` above) | `crit_pulse` 30x12 x4 @8 idle, `halo_pulse` 60x30 x4 @8 (exists), `crit_launch` 30x12 x6 @12 on break; `blue_hit`, `blue_break`, `blue_spawn` (exist); static `brick_crit` 30x12 for cards | `multiball_pop` (ladder above) |
| `refresh` | 1 | 1 | mint | on break: every missing brick of the generated layout respawns as its original kind (enemy-added bricks, its own slot and slots a ball is in excluded); clears nothing else | `refresh_pulse` 30x12 x4 @8 idle, `refresh_wave` 60x12 x6 @12 tileable swept top to bottom; `mint_hit` 30x12 x6 @12, `mint_break` 44x20 x8 @12, `mint_spawn` 30x12 x6 @12; static `brick_refresh` | `regrow 1.0` once |
| `solid` | -1 | 0 | chrome | unbreakable | face `brick_solid`, `solid_bounce` 44x20 x6 @12 (exist) | `solid_bounce 1.0` |
| `bomb` | 1 | 0 | ora | on break, at once: `blast` = 8 direct damage to the enemy, then break every brick with its centre within `BOMB_RADIUS` 72 through `_trigger` (chained bombs each blast); neighbours' `dmg` goes to the breaking ball | `icon_bomb_pulse` 30x12 x4 @8 (exists, body recoloured orange), `halo_pulse_ora` 60x30 x4 @8, `bomb_ring` 60x60 x4 @12; `ora_hit`, `ora_break`, `ora_spawn` (exist) | `bomb_boom 1.0` |
| `red` | 1 | 0 | red | a ball breaking it costs the player `hurt` = 3 HP at the moment of the break; a blast just removes it | static `brick_red` 30x12; `red_hit` 30x12 x6 @12, `red_break` 44x20 x8 @12 (debris falls), `red_spawn` 30x12 x6 @12 | `brick_break 0.7`, `hp_lose` (ladder) at delay 0.05 |

### Generator (`Game.generate(cls, seed, board)`)

Every enemy draws its own board: `board.rows` in `tuning.gd` `ENEMIES`, one glyph per brick from `BOARD_KEYS`: `.` empty, `x` plain, `?` rolled, `#` solid, `b` bomb, `R` red, `c` crit, `r` refresh. Each row centres on the arena, so a row one shorter than its neighbours sits half a step over (honeycomb). Drawn kinds stand as drawn; each `?` rolls `solid`, `bomb`, `red` at the class's per-brick chance under its hard `max`, in that order; then plain bricks convert until the board holds at least `crit` and `refresh` of each (drawn ones count).

Arena is always `Tuning.ARENA`. `BOARD_TOP = 168`, `BOARD_FLOOR = 240`, step 64x28, max rows 11 (boss 10, it sits 32 lower). `test.gd` asserts every brick fits, the widest row is exactly the class's `cols` (the lane grid for `laser_sweep` and `shield_row`), and every non-solid glyph is reachable from outside the layout past the drawn solids.

| class | cols | solid | bomb | red | crit | refresh |
|---|---|---|---|---|---|---|
| `fight` | 11 | 0.03 max 2 | 0.03 max 2 | 0.04 max 3, rows 0-3 only | 3 | 1 |
| `elite` | 13 | 0.05 max 4 | 0.04 max 3 | 0.06 max 6 | 4 | 2 |
| `boss` | 15 | 0.06 max 6 | 0.05 max 4 | 0.08 max 10 | 5 | 2 |

Placement rules for `?` rolls (a failing roll stays `plain`): `solid` never touching `solid`, never at a row's ends or in the bottom row; `red` never touching `red`. Conversions: `crit` takes a `plain` with no `solid` or `crit` touching, in the column with the fewest crits; `refresh` a `plain` in the top half, not touching a `crit`, never two in one column; if a conversion runs out of eligible bricks the rules drop and the count stays.

| enemy | layout | idea |
|---|---|---|
| `glob` | 7-row blob, a drawn crit ringed by 4 drawn reds | the goo core: the crit costs HP to reach |
| `lobber` | battlements, a wall, solid side towers, a 3-wide gate in the bottom row | a fortress you enter by the gate or by breaking in |
| `mason` | a solid ring around a vault of 3 drawn crits, a 3-plain door at the bottom | break in; the shield row seals the top |
| `warden` | two solid pillars full height (zigzag on the honeycomb), 4 drawn crits in the middle chamber | three lanes, and the laser sweeps lanes |
| `maw` | jaws of plain, two rows of solid teeth with one-brick gaps, 3 drawn crits floating in the throat | shoot between the teeth |

### Every existing `tuning.gd` kind and constant

| table | id | verdict | note |
|---|---|---|---|
| BRICKS | `plain`, `solid` | keep | as above; `pay` -> `dmg` |
| BRICKS | `hole` | cut | gaps are `density` |
| BRICKS | `multi`, `multi3`, `shield`, `cond`, `cgate`, `timed`, `seq1..3` | cut | `shield` rows are `solid`; strips stay generated |
| ICON | `multiball` | repurpose -> `crit` | its pulse strip is the template, `multiball_pop` reused |
| ICON | `bomb` | keep, retimed | immediate; `bomb_fuse` strip and `fuse_lit` cue unused |
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

## Enemies (`Tuning.ENEMIES`)

One enemy per fight. `tier` = earliest layer. Intents cycle in order; each entry is `hazard x count` (bare = x1). `board` is the drawn layout (Generator above).

| id | role | tier | HP | cd | board | intents | strips (W x 48 sprite px) | cues (`off` st) |
|---|---|---|---|---|---|---|---|---|
| `glob` | regular | 1 | 30 | 6 | goo blob, crit behind reds | `red_bricks` x3, `debris` x4 | `glob_idle` 48 x4 @8, `glob_hit` 48 x6 @12, `glob_attack` 48 x6 @12, `glob_die` 48 x8 @12 | 0 |
| `lobber` | regular | 1 | 40 | 5 | fortress with a gate | `enemy_balls` x1, `enemy_balls` x3 | `lobber_idle/_hit/_attack/_die` 48, same counts | -2 |
| `mason` | regular | 3 | 55 | 6 | solid-ringed vault of crits | `shield_row`, `debris` x6 | `mason_*` 64 | -4 |
| `warden` | elite | 4 | 120 | 5 | two solid pillars, crits in the middle lane; **riposte**: a paddle hit landing 10+ drops `cd` by 2 | `laser_sweep` x1, `enemy_balls` x3, `shield_row` | `warden_*` 64 | -5 |
| `maw` | boss | 5 | 240 | 4 | jaws with solid teeth, crits in the throat, `BOARD_TOP` +32, no `refresh` in rows 0-1; below 50% HP `cd` 3 and the mouth holds 6 hits | `debris` x8, `mouth`, `laser_sweep` x2 | `maw_*` 160; `maw_mouth_open` 48x16 x6 @12 (hold last), `maw_mouth_close` 48x16 x6 @12 | -7 |

Shared: the enemy sprite sits behind balls and bricks, bottom centre at sprite (240,54), in the bare band above the top wall body (y 112). The hazard spawns on frame 3 of `<id>_attack`; `<id>_hit` on every landed shot; `<id>_die` then outward board break. Statics `enemy_<id>` are frame 0 of `<id>_idle` (no separate sprite). Cue per moment: hit `bumper_hit 0.6*st(off)`, attack `hit_refused 0.5*st(off)`, die `enemy_die` (`1.0`, maw `0.6`), enter `fast_whoosh 0.6` + `bumper_hit 0.5` d0.3.

Boss intent `mouth` (not a hazard): opens a 48x16 sprite zone at the top centre (game x 432..528, y 0..32) for 4 paddle hits (6 below 50% HP); any player ball entering it is removed like a drop (stored lost, to the discard pile); on close every eaten ball is spat back as one `enemy_balls` ball aimed at the paddle, 0.4 s apart. Icon `intent_mouth`. Cues: open `fast_whoosh 0.5`, a ball eaten `teleport_in 0.6`, close `blast 0.5`.

## Hazards (`Tuning.HAZARDS`)

Hazards are arena children on their own collision layer: they pass through bricks and player balls, bounce off side walls where stated, never off the floor, despawn silently past the paddle line (dropping them is free). Any hazard touching a paddle (`mini_paddle` too) costs its `hp` and plays `paddle_hurt` 60x8 x4 @12 (red twin of `paddle_hit`) + `hp_lose`. In-flight hazards are freed at phase end and fight end. Icons `intent_<id>` 12x12 red-on-dark statics.

| id | numbers | effect | strips | cues |
|---|---|---|---|---|
| `red_bricks` | `count` per intent; targets: live `plain` in the 3 live rows nearest the paddle, random, never adjacent to another `red` if avoidable | each target becomes kind `red` (3 HP on a ball break); a refresh respawns the slot as its original kind | `red_bricks_paint` 30x12 x6 @12 per target, staggered 0.05 s | `cond_primed 0.6` per target, one semitone lower each |
| `enemy_balls` | `count`; speed 336 (0.7x), radius 8, spread +-15 deg evenly (1 ball = straight at the paddle's x), 0.15 s apart, `hp` 5 | spawn at the enemy centre (game 480, 60) after a 0.5 s wind-up; straight flight, side walls bounce; ends on paddle contact or past the line | `enemy_balls_warn` 8x8 x4 @8 loop at the spawn point, `enemy_balls_fly` 8x8 x4 @8 loop (animations.md's `enemy_ball`, renamed) | `ball_launch 0.5` per ball, wall `ball_bounce 0.6` |
| `debris` | `count`; chunks 16x16, 300 px/s, >= 80 apart, 0.2 s stagger, `hp` 3 | board shakes 4 px for 0.3 s, then chunks fall from y 112 at random x; ends on paddle or floor | `debris_fall` 8x8 x4 @8 loop, `dust_puff` 12x8 x4 @12 (exists) at the floor | `blast 0.6` on the shake, floor `solid_bounce 1.3` at gain 0.5 |
| `laser_sweep` | lanes = `count` (1, or 2 = paddle column + its mirror); warn 1.0 s, beam 0.4 s, `hp` 6 once per beam | picks the 64-wide board column under the paddle centre at fire time; paddle centre inside during the beam pays; a ball inside has `stored` set to 0 once per beam; bricks untouched; telegraph persists across a phase end | `laser_sweep_warn` 30x6 x4 @8 tiled from the top wall to the floor, `laser_sweep_fire` 30x6 x6 @12 tiled | warn `ui_reveal 0.5`, beam `bolt_sweep 0.8`, ball zapped `combo_drop 1.2` |
| `shield_row` | `shield_hits` 8 paddle hits; a refire resets to 8 | a full row of `solid` at centre y `SHIELD_Y` 140 (one per board column), balls bounce off it; crumbles when the hits run out or the fight ends; never part of the refresh layout | raise and crumble: `dust_puff` per brick; face `brick_solid` | raise `armor_pop 0.7`, crumble `solid_bounce 0.8` |

Persistence: `red_bricks` and `shield_row` and a pending laser telegraph survive a phase end; `enemy_balls` and `debris` do not.

## Relics (`Tuning.RELICS`)

One passive rule each, `Game.has(id)` at the named hook; no duplicates. Hooks: `stat`, `on_fight_start`, `on_break(ball, brick)`, `on_phase_end` (four; no relic needs a launch or paddle-hit hook yet). Offer weight / shop price: common 3 / 40, uncommon 2 / 60, rare 1 / 80. Any visible proc plays `toll_ding 1.0`; pickup plays `relic_get` 36x48 x6 @12 on the card and `cond_primed 1.0`. Icons `relic_<id>` 12x12 white-on-transparent statics.

| id | rarity | hook | numbers | effect | strips | cues |
|---|---|---|---|---|---|---|
| `wide_paddle` | common | stat | `PADDLE_WIDTH` 120 -> 160 | wider paddle | `paddle` stretched (exists) | |
| `shield_floor` | common | on_fight_start, reset on_phase_end | 1 save per phase, bounce vy = `BALL_SPEED` | the first player ball to cross the paddle line each phase bounces straight up from the floor, then the floor pops; hazards ignore it | `shield_floor` 32x4 x4 @8 loop, `shield_floor_pop` 32x8 x6 @12 (exist) | `shield_pop 1.0` |
| `opener` | common | on_break (first break of the phase) | 1 extra launch | the first brick broken each phase also acts as a crit | `crit_launch` | `multiball_pop` ladder |
| `toll` | common | on_break | 1 gold per 10 breaks, counter per fight | gold drops | `toll_pay` 30x12 x6 @12 (exists) on the brick | `coin 1.0` |
| `tenth_bomb` | uncommon | on_fight_start | every 10th `plain` in row-major order, min 1 | becomes `bomb` | bomb strips | |
| `magnet_paddle` | uncommon | stat (`_move_ball`) | `MAGNET_RADIUS` 160, `MAGNET_PULL` 700 | balls within 160 above the paddle centre accelerate toward it | `magnet_pull` 44x20 x4 @8 (exists) under the paddle | |
| `combo` | uncommon | on_break | window `COMBO_WINDOW_START` 1.0 s, +`COMBO_MULT_PER_HIT` 0.25 per step, cap x3 | breaks within 1.0 s of the last raise a counter; stored damage per break is `ball.dmg * mult`; resets after 1.0 s idle or at phase end | `combo_chase` on the HUD line | `brick_break st(min(combo, 12))` |
| `twin_crit` | rare, locked `won_boss` | on_break (crit) | 2 launches per crit | a crit launches two bag balls; empty bag still stops | `crit_launch` | |
| `recall` | rare | on_phase_end | 1 ball per phase | the first non-junk ball that dropped this phase goes to the top of the bag instead of the discard pile | `recall_rise` 12x12 x6 @12 from the bottom edge | `recall 1.0` (exists) |
| `mini_paddle` | rare, locked `killed_elite` | on_fight_start, stat | 48x12, x mirrored (`field.x - paddle.x`) | a second paddle that lands damage and takes hazard hits like the main one | face `paddle_mini` 24x6 (exists) | |

## Screens (`main.gd`, `ui.gd`)

Every between-fight screen is a `Ui.chassis` with the run columns (left: you, right: bag) from screens.md; the fight is the arena with the same columns. Titles: MAP, FIGHT, ELITE, BOSS, SHOP, EVENT, TREASURE, REWARD; right title "BAG %d". `main.gd` swaps one child: menu, map, fight (arena), shop, event, end screen; reward and treasure are overlays on the fight / map.

| screen | numbers (sprite px) | effect | strips / statics | cues |
|---|---|---|---|---|
| menu | CONTINUE above PLAY when `run.json` exists, then CATALOG, SETTINGS, QUIT; SANDBOX gone; PLAY with a save asks `Ui.dialog("ABANDON RUN?")`; footer "BREAK THE BOARD. BEAT THE BOSS." | | `title_logo` (exists) | `ui_start 1.0` |
| map | nodes and edges per the Map section; legend in the left column from y 120 (icon + name, pitch 12) | click a lit node, autosave on entry and after every node | `map_node_*`, `map_ring_pulse`, `ball` | per Map |
| fight | per the Fight pipeline; HP icon `ui_hp` 8x8 beside the player bar | | `ui_hp`, `ui_next` statics | |
| reward | panel (160,70) 320x180: VICTORY k2 `pay`, PICK ONE, three `card_frame` at centres x 240/320/400 tops y 108, name k1 at y 160, desc rivet y 170..188 wrapped 72, SKIP 96x20 at (272,224); "+N GOLD" top right | pick -> autosave -> map | `card_frame`, `card_frame_hot`, `card_frame_dim` 36x48; faces `<id>_rank` frame at 2x, `relic_<id>` at 2x, `coin` at 2x; `ui_badge` for rank-up | per Rewards; hover `ui_hover`, pick `ui_pickup 1.0` then the kind's cue |
| treasure | the reward panel titled TREASURE, three relic cards, no SKIP | | same | `lock_open 1.0` |
| shop | PEDDLER header; ball cards tops y 40 at x 90/170/250 with price under each; relic cards at x 370/450; rule at y 150; REMOVE row y 160, HEAL row y 184 (chrome 96x18 buttons at x 344); status line y 210; LEAVE in the right column | per Shop | `card_frame*`, `ui_slot_hover` | per Shop |
| event | per Events | | none | per Events |
| run over / run won | full chassis, no columns: title k4 at y 40 (white + red rule for RUN OVER, `pay` for RUN WON); line 2 "SLAIN BY <ENEMY> AT NODE n/5" or "THE MAW IS DOWN"; STATS at x 180 from y 102 pitch 10: FIGHTS WON, DAMAGE DEALT, BRICKS BROKEN, BIGGEST SHOT, BALLS DROPPED, GOLD EARNED, TIME m:ss; BAG faces at x 340 pitch 12 and RELICS icons pitch 14; "UNLOCKED: <NAME>" mint at y 180 when a flag was set this run; NEW RUN mint 96x20 at (214,220), MENU chrome at (330,220) | deletes `run.json` on open; numbers tick over 0.8 s | | `run_over 1.0` / `run_won 1.0` on open; `result_roll` while ticking; `ui_unlock 1.2` at delay 1.0 for the unlock line; NEW RUN `ui_start`, MENU `ui_back` |
| catalog | from the menu, no columns: "CATALOG" k2; "BALLS n/8" over a 4x2 grid (face at 2x, name, card line, "DMG 1/2/3"); "ENEMIES n/5" over one row of `<id>_idle` frame 0 with name, TIER n / ELITE / BOSS, HP and intent icons; an id not in `meta.seen` is a `trim` silhouette named "???" (a ball still `locked` adds LOCKED); BACK | | | BACK `ui_back` |
| pause | unchanged: RESUME / SETTINGS / MENU; MENU in a fight abandons it, the map autosave stands | | | `ui_pause`, `ui_unpause` |

Drawn in-engine, no sprite: both HP bars, top wall line, map edges, damage pops, the red field flash, the shop rule, stat tables. Cut: `ui_hp_bar`, `hp_lose` strip, `card_ball`/`card_relic`/`card_gold`/`card_rank`, `map_here`, `ui_intent` generic set, turn bands, event art.

## Meta-unlocks (`Tuning.UNLOCKS`, `settings.json` under `meta`)

| id | set when | unlocks | screen |
|---|---|---|---|
| `finished_run` | any run ends | `ball_bomb` | "UNLOCKED: BLASTER" |
| `killed_elite` | the elite dies | `ball_poison`, `mini_paddle` | "UNLOCKED: SPORE" / "UNLOCKED: MINI PADDLE" |
| `won_boss` | the boss dies | `twin_crit` | "UNLOCKED: TWIN CRIT" |

A ball or relic row carries `locked = "<flag>"`; `Game.unlocked(id)` is `not row.has("locked") or row.locked in meta.flags`. Reward cards, shop stock and `event_vendor` draw only from unlocked ids. `meta` also counts `runs` and `wins` for one menu stat line, and lists `seen`: every ball id that entered a bag (`Game.add_ball`, the starting bag) and every enemy id whose node was entered, for the catalog. Nothing numeric carries over.

## Asset inventory

New strips (name, frame W x H sprite px, frames, fps): `ball_basic_rank` 8x8 3 still, `ball_heavy_rank` 12x12 3, `ball_split_rank` 8x8 3, `ball_pierce_rank` 6x6 3, `ball_sticky_rank` 8x8 3, `ball_bomb_rank` 8x8 3, `ball_poison_rank` 8x8 3, `ball_junk_rank` 8x8 1, `ball_split_pop` 16x16 6 @12, `ball_poison_land` 12x12 4 @12, `stored_tag` 25x8 4 @8, `damage_fire` 60x8 6 @12, `paddle_hurt` 60x8 4 @12, `crit_pulse` 30x12 4 @8, `crit_launch` 30x12 6 @12, `refresh_pulse` 30x12 4 @8, `refresh_wave` 60x12 6 @12, `mint_hit` 30x12 6 @12, `mint_break` 44x20 8 @12, `mint_spawn` 30x12 6 @12, `red_hit` 30x12 6 @12, `red_break` 44x20 8 @12, `red_spawn` 30x12 6 @12, `red_bricks_paint` 30x12 6 @12, `enemy_balls_warn` 8x8 4 @8, `enemy_balls_fly` 8x8 4 @8, `debris_fall` 8x8 4 @8, `laser_sweep_warn` 30x6 4 @8, `laser_sweep_fire` 30x6 6 @12, `glob_idle` 48x48 4 @8, `glob_hit` 48x48 6 @12, `glob_attack` 48x48 6 @12, `glob_die` 48x48 8 @12, `lobber_idle/_hit/_attack/_die` 48x48 4/6/6/8, `mason_idle/_hit/_attack/_die` 64x48 4/6/6/8, `warden_idle/_hit/_attack/_die` 64x48 4/6/6/8, `maw_idle/_hit/_attack/_die` 160x48 4/6/6/8, `maw_mouth_open` 48x16 6 @12, `maw_mouth_close` 48x16 6 @12, `recall_rise` 12x12 6 @12, `relic_get` 36x48 6 @12, `map_ring_pulse` 16x16 4 @8.

Reused strips: `ball_bounce` 12x12 6, `ball_trail` 24x8 4, `pierce_trail` 24x8 4, `ball_lost` 12x12 6, `sticky_hold` 30x16 6, `bomb_ring` 60x60 4, `paddle_hit` 60x8 4, `mag_hit`/`blue_hit`/`ora_hit` 30x12 6, `mag_break`/`blue_break`/`ora_break` 44x20 8, `mag_spawn`/`blue_spawn`/`ora_spawn` 30x12 6, `icon_bomb_pulse` 30x12 4 (recoloured), `halo_pulse`, `halo_pulse_ora` 60x30 4, `solid_bounce` 44x20 6, `dust_puff` 12x8 4, `shield_floor` 32x4 4, `shield_floor_pop` 32x8 6, `magnet_pull` 44x20 4, `combo_chase` 30x12 8, `toll_pay` 30x12 6.

Reused statics: `ball`, `coin`, `paddle`, `paddle_mini`, `brick_plain_lit`, `brick_solid`, `title_logo`, `ui_badge`, `ui_slot_hover`, `ui_pip_pay`, `ui_pip_off` (all exist).

New statics: `brick_crit`, `brick_refresh`, `brick_red` 30x12; `intent_red_bricks`, `intent_enemy_balls`, `intent_debris`, `intent_laser_sweep`, `intent_shield_row`, `intent_mouth` 12x12; `relic_<id>` x10 12x12; `ui_hp` 8x8; `ui_next` 4x5; `card_frame`, `card_frame_hot`, `card_frame_dim` 36x48; `map_node_fight`, `map_node_elite`, `map_node_treasure`, `map_node_shop`, `map_node_event` 12x12; `map_node_boss` 16x16.

New cues (5): `damage_land`, `hp_lose`, `enemy_die`, `run_over`, `run_won` (recipes in sound.md). Existing cues the demo plays: `round_go`, `ball_launch`, `ball_bounce`, `paddle_hit`, `ball_lost`, `brick_hit`, `brick_break`, `multiball_pop`, `hit_refused`, `regrow`, `bomb_boom`, `solid_bounce`, `split_pop`, `pierce_swish`, `sticky_catch`, `sticky_fire`, `pips_shrink`, `bumper_hit`, `count_tick`, `combo_drop`, `timed_off`, `fast_whoosh`, `cond_primed`, `blast`, `ui_reveal`, `bolt_sweep`, `armor_pop`, `teleport_in`, `teleport_out`, `shield_pop`, `toll_ding`, `recall`, `coin`, `coin_cascade`, `round_clear`, `mystery_reel`, `lock_open`, `lamp_hum`, `grow`, `time_low`, `result_roll`, `ui_click`, `ui_back`, `ui_start`, `ui_hover`, `ui_pickup`, `ui_drop`, `ui_buy`, `ui_cant_afford`, `ui_unlock`, `ui_invalid`, `ui_pause`, `ui_unpause`. `gen.mjs` housekeeping: `regrow`, `lock_open`, `grow`, `blast`, `toll_ding` leave the Ideas group. Old cues the demo stops playing keep their wavs.

## Code steps (history: all ten landed)

Each step leaves `godot --headless -s tests/test.gd` and `tests/smoke.tscn` passing; `docs/animations.md` and `docs/sprite-spec.md` are updated in step 9.

1. **Cut old loop.** Delete `shop.gd`, `place.gd`; strip `arena.gd` of the round timer, combo, placement copy, pass-through pieces, spawner and payout; strip `hud.gd` to a column stub; `main.gd` swaps menu <-> arena only; `game.gd` loses currency, ranks, `UPGRADES` reveal/cost/buy, level unlock and the sandbox slot; `tuning.gd` applies the cut column of the verdict table (`LEVELS` stays one row until step 5). `test.gd` drops the upgrade and placement checks. No art or wav deleted.
2. **Run state in `game.gd`.** `RUN`, `MAP`, `EVENTS`, `REWARDS`, `SHOP`, `UNLOCKS` tables; fields hp/gold/bag/relics/seed/stats/map; `new_run`, `save_run`/`load_run` (`run.json`), `meta` in `settings.json`; pure rolls `gen_map(seed)`, `roll_reward`, `roll_shop`, `pick_enemy`, `unlocked(id)`, `has(id)`, `add_gold`, `hurt(n)`, `heal(n)`; `test.gd` checks map shape, reward kinds distinct, removal invariant, save round-trip.
3. **Arena phase loop and damage pipeline.** `TOP_WALL` 112 body, `BOARD_TOP` 168, `BOARD_FLOOR` 240; enemy band placeholder with HP bar, number, intent slot, countdown; bag queue and discard pile; `phase_start`/`discard`/`store`/`fire`/`drop`/`phase_end`/`win`/`lose`; paddle-hit countdown driving a stub intent; `stored_tag` label, `damage_fire` placeholder; `regen_below` and empty-board refresh; fight columns; `hud.gd` becomes the two run columns. Smoke test runs one fight against a stub enemy headless.
4. **Ball types.** `BALLS`, `BAG_START`, `RARITY`; Ball class gets `id`, `rank`, `stored`, `poison`, trait counters; traits heavy/split/pierce/sticky/bomb/poison/junk; `STICKY_HOLD` 1.5; rank-up and locked rows; `test.gd` checks every `BALLS` row has a `<id>_rank` strip name and three `dmg` values.
5. **Bricks.** `BRICKS` rows with `hue`, `ICON_KINDS` = crit/refresh/bomb, `BOARDS` replace `LEVELS`, `generate(cls, seed)` with the placement rules and per-fight `top`; `_effect` arms for `crit`, `refresh`, `bomb` (immediate, blast 8, credit to the ball), `red` (hurt 3 on ball breaks only); `Tuning.hue` reads the field; `test.gd` asserts board fit, exact crit/refresh counts, hue set.
6. **Enemies and hazards.** `ENEMIES`, `HAZARDS`; enemy node in the band with idle/hit/attack/die, intent cycle, `cd`, riposte, maw mouth; hazard layer with the five hazards, paddle contact HP cost, phase-end cleanup, `shield_row` solids, laser lane snap; `pick_enemy` tiers; `test.gd` checks every intent names a `HAZARDS` id or `mouth`, every enemy has >= 1 intent, every hazard has an `intent_<id>` name.
7. **Relics.** `RELICS` with rarity, price, locked; hooks at the four sites; `wide_paddle`, `shield_floor`, `opener`, `toll`, `tenth_bomb`, `magnet_paddle`, `combo`, `twin_crit`, `recall`, `mini_paddle`; `test.gd` checks ids unique, every hook name known, offer weights sum.
8. **Screens.** Map, reward overlay, treasure, shop, event, run over / run won, menu CONTINUE and ABANDON RUN dialog, pause MENU keeping the map autosave; `Ui` gains `card`, `hp_bar`, `tooltip` helpers; `tests/shots.tscn` adds every new screen.
9. **Wire strips and cues.** `assets/pixel/gen.mjs` generates every new strip and static above; `assets/audio/gen.mjs` adds the five cues and moves the housekeeping group; every call site plays the names and rates in this file; `docs/animations.md` and `docs/sprite-spec.md` rows match; `test.gd`'s strip list and cue check cover every name here.
10. **Meta-unlocks.** `UNLOCKS` flags set at run end, elite death, boss death; `unlocked()` filters rewards, shop and vendor; "UNLOCKED:" line and `meta.runs`/`wins` on the menu; `test.gd` checks every `locked` value is an `UNLOCKS` id.
