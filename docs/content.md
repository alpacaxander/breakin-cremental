# Content contract (demo: one act, "Peglin but breakout")

The single source for asset and code agents. It resolves the eight pool specs; where this file and a pool spec differ, this file wins. Numbers are game px (arena-local, 960x720) unless a column says sprite px (half). Strips are `assets/pixel/png/anim_<name>.png`; a strip column reads `name WxH xN @fps` with W,H in sprite px. Cues are `assets/audio/wav/<name>.wav`; a cue column reads `name rate` (`st(n)` = n semitones). Statics are plain sprites (`<name>.png`), one frame. "exists" means the asset is already generated; everything else is new.

Maps: map 1, Back Alley Arcade (`docs/content/maps/back-alley-arcade.md`), landed on 2026-11-10; its rows below win over the proposal. Still proposals, not in `tuning.gd`: `docs/content/maps/corp-tower.md`, `docs/content/maps/deep-net.md`. The run is still one five-layer map; map 1's enemies, hazards, events, shop and balls joined the existing pools rather than replacing them.

Encounter mechanics (slots, bricks, layers, effects, the fight pipeline, boards, encounters, organs, enemies, hazards): `docs/encounter-mechanics.md`. Its "Not verified" part holds what used to be here.

Vocabulary: a **fight** is one encounter (one or more organs) on one board. A **phase** is one launch from the bag until every ball in play has dropped (design.md's "turn"). A **paddle hit** is a player ball touching a paddle. The fight's clock is seconds with a ball in flight.

## Decisions that cut across pools

| topic | decision | lost proposals |
|---|---|---|
| Player HP | 50. | design.md's implied 100. |
| Prices and income | run.md owns: ball 15, relic 40/60/80, remove 12, heal 20 for +20 HP, fight gold 12+rand 0..6, elite 30+rand 0..6, gold card 30. | balls.md 25/40/60, relics.md 60/100/150, screens.md remove 25+10 and heal +15. |
| Map | run.md: 9 nodes, 5 layers, forced shop in layer 4, elite in layer 3 slot 0, nodes at x = 60 + 90*(layer-1). Legend lives in the left column. | screens.md 8-node topology and field legend. |
| Ball ids | `ball_<name>`; faces are frame `rank-1` of `<id>_rank`. | run.md save shape with bare `basic`; screens.md static `ball_<id>`. |
| Enemy strips | enemies.md names `<id>_idle/_hit/_attack/_die`, sizes 48/48/64/64/160 wide, 48 tall. Anchor bottom centre at sprite (240,54). The strips are the encounter's band portrait only; each organ draws its own HP bar on the board. | screens.md `enemy_<id>_hurt`, boss 64x48, enemies.md under-feet bar. |
| Intent icons | `intent_<hazard_id>` plus `intent_mouth`, 12x12 statics; pulse in-engine in the countdown's last second. | `ui_intent_*`, `<id>_intent`, `intent_shield`, `intent_heal`. |
| Cards | One `card_frame` (+`_hot`, `_dim`) 36x48 with a separate face. | `card_ball`, `card_relic`, `card_gold`, `card_rank`. |
| Relic icons | `relic_<id>` 12x12 statics. | relics.md 10x10. |
| Sound | sound.md owns: **five new wavs** (`damage_land`, `hp_lose`, `enemy_die`, `run_over`, `run_won`); every other moment plays an existing cue at a rate. Player events at or above 1.0, enemy events at or below 0.8. Enemy cue offsets `off`: glob 0, lobber -2, mason -4, warden -5, maw -7 semitones. | every other pool's new cue name (`dmg_fire`, `hp_hit`, `paddle_hurt`, `red_paint`, `laser_*`, `debris_slam`, `goo_hum`, `relic_get`, `shield_floor_pop`, `poison_tick`, `junk_thud`, `ball_rank_up`, `map_pick`, `map_hop`, `gold_gain`, `reward_pick`, `shop_buy`, `event_pick`, `intent_tick`, `<enemy>_attack`, `maw_mouth_*`). Cues `recall` and `coin` already exist and are reused. |
| Discard | Once per phase while a ball rests on the paddle: D, right-click or the DISCARD button moves it to the discard pile and rests the next. | balls.md "to the back of the queue"; screens.md "removed for the fight". |

## Run state (`Tuning.RUN`, `game.gd`)

| id | numbers | effect | strips | cues |
|---|---|---|---|---|
| `hp`, `hp_max` | 50 / 50 | 0 ends the run; heals cap at max | HP bar in-engine 68x3 sprite px, left column | `hp_lose` on any loss: 1-2 `1.0`, 3-5 `0.85`, 6+ `0.7`; `time_low 0.5` once per phase start while hp <= 12 |
| `gold` | 0 | one integer currency | `coin` 8x8 (exists) | `coin 1.0` on any gain; `count_tick 1.0` while the number rolls |
| `bag` | start `ball_basic` x4, `ball_heavy`, `ball_pierce`, all rank 1 | list of `{id, rank}`; launch order; shuffled at fight start | faces per ball | |
| `relics` | `[]` | ids, no duplicates | `relic_<id>` 12x12 | |
| `removed` | `""` | the id of the last ball removed this run (the shop's REMOVE, the mod shop's SELL ONE), for the shop's BUY BACK; cleared when bought back | | |
| `seed` | `randi()` at run start | one `RandomNumberGenerator` seeded `seed + node index` per roll site, so a reload replays map, shop and rewards | | |
| `stats` | `fights`, `elites`, `damage`, `bricks`, `best_fire`, `drops`, `gold_earned`, `seconds`, `killer` | end-screen lines | | |
| `enemy_turn` | 0.8 s | between-phase beat | | `combo_drop 0.8` at phase end |
| `regen_below` | 10 | breakables left at phase start that trigger a free refresh | `refresh_wave` | `regrow 1.0` |
| `ramp_on`, `ramp_after`, `ramp_per_s`, `ramp_max` | false, 20 s, 0.02, 1.6 | speed ramp on long-lived balls (design.md fallback, off by default); a sticky catch or re-bagging resets it | two afterimages at >= `FAST_SPEED` | |

Save: `user://run.json` `{version, seed, uid, hp, hp_max, gold, bag[{id, rank, uid}], relics, removed, map{layers, enemies, events, path, layer, node}, stats}`; written on map entry, after a reward pick, an event choice and each shop purchase; never mid-fight (a fight restarts on load: `# ponytail: one re-rolled fight per quit`). Deleted when an end screen opens or NEW RUN is pressed. Present file = CONTINUE on the menu. `tests/smoke.tscn` saves and restores it. The dev `sandbox.json` slot is cut.

### Map (`Tuning.MAP`)

| layer | width | slot kinds | edges (slot -> next slots) |
|---|---|---|---|
| 1 | 2 | `fight`, `fight` | 0 -> {0,1}, 1 -> {1,2} |
| 2 | 3 | each: `fight` 50 / `event` 30 / `treasure` 20; if none rolled `fight`, slot 1 is `fight` | every slot -> {0,1} |
| 3 | 2 | slot 0 `elite`; slot 1: `fight` 60 / `event` 40 | both -> {0} |
| 4 | 1 | `shop` | -> {0} |
| 5 | 1 | `boss` | none |

`fight` picks an encounter (`pick_encounter`, from `Tuning.encounters()`) of tier <= layer, equal weight, never the previous fight's; `map.enemies` holds encounter ids. `RUN_VERSION` 2: an older `run.json` is dropped. Events draw without replacement. Nodes at field x = 60 + 90*(layer-1), y spread evenly (2: 120/240; 3: 90/180/270; 1: 180). Node sprites `map_node_fight/elite/treasure/shop/event` 12x12 and `map_node_boss` 16x16 statics; reachable 1.0 with `map_ring_pulse` 16x16 x4 @8 around it, visited 0.5, unreachable alpha 0.35; edges 1 px `trim_hi` in-engine, the walked edge `pay`. The `ball` sprite (exists) marks the player, hops by tween 0.3 s. Header "NODE %d/5". Cues: node click `ui_start 1.0`, unreachable `ui_invalid 1.0`, map open `ui_unpause 1.0`, hover `ui_hover 1.0`, next layer lights `ui_reveal 0.8`.

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
| `shop_ball` | 3 distinct unlocked balls of `SHOP.rarities` (common, uncommon; never rare), 15 each; the first slot is a `map` = `SHOP.map` ball when one fits | adds to the bottom of the bag | cards at y 40, centres x 90/170/250 | `ui_buy 1.0`; refused `ui_cant_afford 1.0` |
| `shop_relic` | 2 distinct unowned relics, 40 / 60 / 80 by rarity, drawn by `SHOP.relic_weights` 5 / 2 / 1 (the reward roll keeps 3 / 2 / 1) | adds the relic | cards at centres x 370/450 | `ui_buy 1.0` |
| `shop_remove` | 12, repeatable | REMOVE enters pick mode on the bag column (`ui_slot_hover`, exists); deletes one copy, junk included; refused (`ui_invalid`) when it would leave no non-junk ball; the id goes to `run.removed` | | `teleport_in 0.8` |
| `shop_heal` | 20 gold, +20 HP, once per visit | disabled at full HP | | `grow 1.0`, `coin 0.8` at delay 0.1 |
| `shop_buy_back` | `buy_back` 7 (half the ball price) | BUY BACK returns `run.removed` to the bottom of the bag at rank 1 and clears it; dimmed with nothing removed ("BUY BACK NOTHING") | row y 208 under HEAL | `ui_buy 1.0`; refused `ui_cant_afford 1.0` |
| shop screen | PAWN SHOP | `lamp_hum` loop while open; LEAVE in the right column | | `ui_unpause 1.0` on enter, `ui_back` on leave |
| `event_coin_return` | A: `gold += 25` and a `ball_junk` joins the bag; B: nothing | COIN RETURN / A DEAD CABINET. THE COIN BOX RATTLES. / PRY IT OPEN / WALK ON | | open `mystery_reel 1.0`, choice `ui_click 1.0`, good `ui_unlock 1.0`, bad `ui_cant_afford 0.8`; junk added `teleport_out 0.5` |
| `event_mod_shop` | A: random owned ball rank < 3 gains a rank, `hp -= 6` (floor 1); B: sells one ball for `gold += 15`: a `ball_junk` if the bag holds one, else a random ball; refused (text only) when the bag invariant would break; the id goes to `run.removed`. Replaces `event_forge` | THE MOD SHOP / A KID WITH A SOLDERING IRON LOOKS UP. / MOD A BALL / SELL ONE | | as above |
| `event_fried_cabinet` | A (10 gold): `hp += 10`, dimmed if unaffordable; B: the node's relic (as the vendor's: random unowned common/uncommon, dimmed if none), `hp -= 8` (floor 1) | FRIED CABINET / SMOKE. THE SCREEN STILL FLICKERS. / PULL THE PLUG / PLAY IT | | as above |
| `event_vendor` | A (20 gold): random unowned common/uncommon relic, dimmed if unaffordable or none; B: 50% the relic free, 50% a `ball_junk` joins the bag | A GHOST VENDOR / IT HOLDS OUT A RELIC AND SAYS NOTHING. / BUY IT (20) / HAGGLE | | junk added `teleport_out 0.5` |
| `event_spring` | A: `hp += 15`; B: `gold += 25`, `hp -= 5` (floor 1) | A HOT SPRING / STEAM. SOMETHING SHINES UNDER THE WATER. / BATHE / DIVE FOR COINS | | |

Event frame: panel (120,60) 400x230 sprite px, title k2 `pay`, body k1 wrapped 368, two choice buttons 368x18; after a choice the body swaps to the result line and one CONTINUE button (`ui_reveal 1.0`) applies it and autosaves.

## Fight pipeline

Moved to `docs/encounter-mechanics.md` "Not verified" on 2026-11-12.

## Balls (`Tuning.BALLS`)

Common: `dmg` is per brick broken, `size` and `speed` multiply `BALL_RADIUS` 8 and `BALL_SPEED` 480, three ranks raise the numbers only. Trait numbers are `[r1, r2, r3]`. Rarity roll: common 60 / uncommon 30 / rare 10, then uniform within the tier among unlocked members (empty tier rerolls). `BAG_START = [ball_basic x3, ball_pierce]`.

| id | name | rarity | dmg | size | speed | effect | strips | cues |
|---|---|---|---|---|---|---|---|---|
| `ball_basic` | PEBBLE | common | 1/2/3 | 1.0 | 1.0 | none | `ball_basic_rank` 8x8 x3 still (frame 2 == `ball`) | |
| `ball_heavy` | BOULDER | common | 3/5/7 | 1.5 | 0.8 | none beyond the numbers | `ball_heavy_rank` 12x12 x3 | paddle catch `paddle_hit 0.7` |
| `ball_split` | SPLITTER | common | 1/2/3 | 1.0 | 1.0 | first break after each launch or paddle hit: becomes `split` = 2/2/3 balls fanned +-20 deg; halves are full copies that cannot split again until the next paddle hit, each stores its own damage | `ball_split_rank` 8x8 x3; `ball_split_pop` 16x16 x6 @12 | `split_pop 1.0` |
| `ball_pierce` | NEEDLE | uncommon | 1/2/3 | 0.75 | 1.2 | after each launch or paddle hit passes through and breaks the next `pierce` = 3/5/8 bricks; `solid`, walls and paddles always bounce it | `ball_pierce_rank` 6x6 x3, turned to its heading; three fading afterimages of its face while piercing | `pierce_swish 1.0` per brick |
| `ball_sticky` | GUM | uncommon | 2/3/4 | 1.0 | 1.0 | the first `catches` = 1/2/3 paddle contacts per phase catch it: damage fires, the ball sits `STICKY_HOLD` 1.5 s or until click/space, relaunches toward the mouse clamped to `MAX_BOUNCE_DEG` | `ball_sticky_rank` 8x8 x3; `sticky_hold` 30x16 x6 @8 (exists, holds its last frame) | `sticky_catch 1.0`, `sticky_fire 1.0` |
| `ball_bomb` | BLASTER | uncommon | 1/2/3 | 1.0 | 1.0 | every `every` = 5/4/3rd brick it breaks (per fight) also fires a `BOMB_RADIUS` blast at that brick through `_trigger`; blast-broken bricks are credited to this ball, no direct damage | `ball_bomb_rank` 8x8 x3; `bomb_ring` 60x60 x4 @12 (exists) | `bomb_boom 1.0` |
| `ball_poison` | SPORE | rare | 0/0/1 | 1.0 | 1.0 | each brick also stores `poison` = 1/2/3 stacks; stacks land with the damage; tick at phase end (above) | `ball_poison_rank` 8x8 x3; `ball_poison_land` 12x12 x4 @12 on the paddle | tick `pips_shrink 0.8` |
| `ball_junk` | STONE | none | 0 | 1.0 | 0.9 | breaks bricks, stores nothing, its `opener` crit does not launch; no ranks, never a card, removable at the shop, added by `event_vendor`, `event_coin_return` and the `coin_junk` hazard | `ball_junk_rank` 8x8 x1 | launch `ball_launch 0.6`, its breaks `brick_break 0.6` |
| `ball_token` | TOKEN | common, `map` 1 | 1/2/3 | 1.0 | 1.0 | every `pays` = 8/6/4th brick it breaks (per fight, counted on the bag entry like the blaster's) pays `gold` 1 (relic `toll`'s path, `_pay`) | `ball_token_rank` 8x8 x3; `toll_pay` on the brick | `coin 1.0` |
| `ball_rubber` | RUBBER | uncommon, `map` 1 | 1/2/3 | 1.0 | 1.0 | the first `floor` = 1/2/3 drops per phase bounce it straight up off the floor (relic `shield_floor`'s `_save`, the ball's own count first) | `ball_rubber_rank` 8x8 x3; `shield_floor_pop` | `shield_pop 1.0` |
| `ball_magnet` | MAGNET | uncommon, `map` 1 | 2/3/4 | 1.0 | 1.0 | pulled toward the paddle within `MAGNET_RADIUS` at `magnet` = 0.5/1.0/1.5 x `MAGNET_PULL`, added to relic `magnet_paddle`'s 1.0 | `ball_magnet_rank` 8x8 x3 | |

Locked: `ball_bomb` until `finished_run`, `ball_poison` until `killed_elite`. Invariant: the bag always holds at least one non-junk ball (removal refuses). Every ball reuses `ball_bounce` 12x12 x6 @12 (exists) and draws two fading afterimages of its own face at >= `FAST_SPEED`; `ball_bounce 1.0` on walls.

## Bricks

Moved to `docs/encounter-mechanics.md` "Not verified" on 2026-11-12.

## Encounters and organs

Moved to `docs/encounter-mechanics.md` "Not verified" on 2026-11-12.

## Hazards

Moved to `docs/encounter-mechanics.md` "Not verified" on 2026-11-12.

## Relics (`Tuning.RELICS`)

One passive rule each, `Game.has(id)` at the named hook; no duplicates. Hooks: `stat`, `on_fight_start`, `on_break(ball, brick)`, `on_phase_end` (four; no relic needs a launch or paddle-hit hook yet). Offer weight / shop price: common 3 / 40, uncommon 2 / 60, rare 1 / 80. Any visible proc plays `toll_ding 1.0`; pickup plays `relic_get` 36x48 x6 @12 on the card and `cond_primed 1.0`. Icons `relic_<id>` 12x12 white-on-transparent statics.

| id | rarity | hook | numbers | effect | strips | cues |
|---|---|---|---|---|---|---|
| `wide_paddle` | common | stat | `PADDLE_WIDTH` 120 -> 160 | wider paddle | `paddle` stretched (exists) | |
| `shield_floor` | common | on_fight_start, reset on_phase_end | 1 save per phase, bounce vy = `BALL_SPEED` | the first player ball to cross the paddle line each phase bounces straight up from the floor, then the floor pops; hazards ignore it | `shield_floor` 32x4 x4 @8 loop, `shield_floor_pop` 32x8 x6 @12 (exist) | `shield_pop 1.0` |
| `opener` | common | on_break (first break of the phase) | 1 extra launch | the first brick broken each phase also acts as a crit | `crit_launch` | `multiball_pop` ladder |
| `toll` | common | on_break | 1 gold per 10 breaks, counter per fight | gold drops | `toll_pay` 30x12 x6 @12 (exists) on the brick | `coin 1.0` |
| `tenth_bomb` | uncommon | effect row `start` (source `relic:tenth_bomb`, docs/encounter-mechanics.md "How effects enter an encounter") | every 10th `plain` on a standard slot in row-major order, min 1 | becomes `bomb` | bomb strips | |
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
| shop | PAWN SHOP header; ball cards tops y 40 at x 90/170/250 with price under each; relic cards at x 370/450; rule at y 150; REMOVE row y 160, HEAL row y 184, BUY BACK row y 208 (chrome 96x18 buttons at x 344); status line y 234; LEAVE in the right column | per Shop | `card_frame*`, `ui_slot_hover` | per Shop |
| event | per Events | | none | per Events |
| run over / run won | full chassis, no columns: title k4 at y 40 (white + red rule for RUN OVER, `pay` for RUN WON); line 2 "SLAIN BY <ENEMY> AT NODE n/5" or "THE <BOSS> IS DOWN" (ids with `_` as spaces); STATS at x 180 from y 102 pitch 10: FIGHTS WON, DAMAGE DEALT, BRICKS BROKEN, BIGGEST SHOT, BALLS DROPPED, GOLD EARNED, TIME m:ss; BAG faces at x 340 pitch 12 and RELICS icons pitch 14; "UNLOCKED: <NAME>" mint at y 180 when a flag was set this run; NEW RUN mint 96x20 at (214,220), MENU chrome at (330,220) | deletes `run.json` on open; numbers tick over 0.8 s | | `run_over 1.0` / `run_won 1.0` on open; `result_roll` while ticking; `ui_unlock 1.2` at delay 1.0 for the unlock line; NEW RUN `ui_start`, MENU `ui_back` |
| catalog | from the menu, no columns, two pages: "CATALOG: BALLS n/11" k2 over a 4-wide grid (face at 2x, name, card line, "DMG 1/2/3"); "CATALOG: ENEMIES n/15" over rows of `<id>_idle` frame 0 (wrapped at the field's width, pitch 84) with name, TIER n / ELITE / BOSS, HP and intent icons; an id not in `meta.seen` is a `trim` silhouette named "???" (a ball still `locked` adds LOCKED); BACK and the other page's button at y 330 | | | BACK `ui_back` |
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

Reused strips: `ball_bounce` 12x12 6, `ball_lost` 12x12 6, `sticky_hold` 30x16 6, `bomb_ring` 60x60 4, `paddle_hit` 60x8 4, `mag_hit`/`blue_hit`/`ora_hit` 30x12 6, `mag_break`/`blue_break`/`ora_break` 44x20 8, `mag_spawn`/`blue_spawn`/`ora_spawn` 30x12 6, `icon_bomb_pulse` 30x12 4 (recoloured), `halo_pulse`, `halo_pulse_ora` 60x30 4, `solid_bounce` 44x20 6, `dust_puff` 12x8 4, `shield_floor` 32x4 4, `shield_floor_pop` 32x8 6, `magnet_pull` 44x20 4, `combo_chase` 30x12 8, `toll_pay` 30x12 6.

Reused statics: `ball`, `coin`, `paddle`, `paddle_mini`, `brick_plain_lit`, `brick_solid`, `title_logo`, `ui_badge`, `ui_slot_hover`, `ui_pip_pay`, `ui_pip_off` (all exist).

New statics: `brick_crit`, `brick_refresh`, `brick_red` 30x12; `intent_red_bricks`, `intent_enemy_balls`, `intent_debris`, `intent_laser_sweep`, `intent_shield_row`, `intent_mouth` 12x12; `relic_<id>` x10 12x12; `ui_hp` 8x8; `ui_next` 4x5; `card_frame`, `card_frame_hot`, `card_frame_dim` 36x48; `map_node_fight`, `map_node_elite`, `map_node_treasure`, `map_node_shop`, `map_node_event` 12x12; `map_node_boss` 16x16.

New cues (5): `damage_land`, `hp_lose`, `enemy_die`, `run_over`, `run_won` (recipes in sound.md). Existing cues the demo plays: `round_go`, `ball_launch`, `ball_bounce`, `paddle_hit`, `ball_lost`, `brick_hit`, `brick_break`, `multiball_pop`, `hit_refused`, `regrow`, `bomb_boom`, `solid_bounce`, `split_pop`, `pierce_swish`, `sticky_catch`, `sticky_fire`, `pips_shrink`, `bumper_hit`, `count_tick`, `combo_drop`, `timed_off`, `fast_whoosh`, `cond_primed`, `blast`, `ui_reveal`, `bolt_sweep`, `armor_pop`, `teleport_in`, `teleport_out`, `shield_pop`, `toll_ding`, `recall`, `coin`, `coin_cascade`, `round_clear`, `mystery_reel`, `lock_open`, `lamp_hum`, `grow`, `time_low`, `result_roll`, `ui_click`, `ui_back`, `ui_start`, `ui_hover`, `ui_pickup`, `ui_drop`, `ui_buy`, `ui_cant_afford`, `ui_unlock`, `ui_invalid`, `ui_pause`, `ui_unpause`. `gen.mjs` housekeeping: `regrow`, `lock_open`, `grow`, `blast`, `toll_ding` leave the Ideas group. Old cues the demo stops playing keep their wavs.

Map 1 (Back Alley Arcade): strips `<id>_idle/_hit/_attack/_die` for `rat_king`, `claw_rig`, `repo_man`, `arcade_bouncer`, `jackpot_reel` 64x48, `coin_slug`, `fuse_box`, `ticket_printer`, `bootleg_cabinet` 48x48, `attract_mode` 160x48 (4/6/6/8); `ball_token_rank`, `ball_rubber_rank`, `ball_magnet_rank` 8x8 3 still; `jam_clamp` 60x8 6 @12; `pull_drift` 12x16 4 @8; reused `gold_hit`/`gold_break`/`gold_spawn`, `toll_pay`, `shield_floor_pop`. Statics `intent_jam`, `intent_pull`, `intent_coin_junk` 12x12, `paddle_jam` 30x8, reused `brick_gold`. New cues `paddle_jam`, `pull_lift`; reused `gold_hit`, `jackpot`, `grow`, `coin`, `teleport_out`, `split_pop`, `count_tick`, `shield_pop`. Art: `assets/pixel/parts/arcade.mjs`, `arcade_bosses.mjs`, `map_hazards.mjs`, `map_balls.mjs`; cues `assets/audio/parts/maps.mjs`.

Encounters first slice: `organ_cell` 30x12 static, `organ_hit` 30x12 6 @12, `organ_die` 44x20 8 @12 (`parts/organs.mjs`, grey-white, tinted per organ at runtime); reused `bomb_fuse` 30x12 16 @8 as the armed bomb. No new cues.

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
