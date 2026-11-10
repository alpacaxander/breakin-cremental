# Map 1: Back Alley Arcade

Proposal, 2026-11-10; landed in `tuning.gd` the same day, so `docs/content.md` now wins over this file. Deviations on landing: the map joined the existing pools (mason, event_vendor and event_spring stay); the token's trait key is `pays` (`every` is the blaster's) and the magnet ball's is `magnet` (`pull` is the hazard); `bootleg_cabinet`'s board is a drawn cabinet, not a mirrored generator board; the ticket printer advances by sliding its whole layout; `attract_mode`'s needle copy flies plain (nothing to pierce on the enemy side); the reward roll does not prefer map balls, only the shop's first slot does.

Street-level scrap tech: bootleg cabinets, coin-op pests, things that got into the wiring. Hazards are physical. Stuff falls, stuff bounces, nothing is subtle. This is the first map, so every enemy teaches one hazard and the board shapes are readable at a glance.

Vocabulary as `docs/content.md`: a fight is one enemy on one board, a phase is one launch until every ball drops, the clock is seconds with a ball in flight (`cd` in seconds). Intents cycle in order; `hazard xN` is one intent firing N of that hazard.

## New hazards

Existing: `red_bricks`, `enemy_balls`, `debris`, `laser_sweep`, `shield_row`, and the boss intent `mouth`. This map adds three.

| id | numbers | effect | persists past a phase end |
|---|---|---|---|
| `jam` | `hits` 6 | the paddle draws at half width for the next 6 paddle hits; a refire resets to 6 | yes |
| `pull` | `secs` 1.0, `force` 0.5x gravity | every player ball in flight drifts upward for 1.0 s, so stored damage risks going back into the bricks instead of the paddle | no, in flight |
| `coin_junk` | `count` | a junk ball goes on top of the bag per count (bag invariant as events: a junk ball is a stone orb, 0 damage, no trait) | yes, it is in the bag |

## Enemies (8)

| id | look | board hook | HP | cd | intents |
|---|---|---|---|---|---|
| `glob` | goo blob, red core | crit behind a ring of reds (exists) | 30 | 12 s | `red_bricks` x3, `debris` x4 |
| `lobber` | squat turret | fortress with a gate (exists) | 40 | 10 s | `enemy_balls` x1, `enemy_balls` x3 |
| `rat_king` | pile of cable rats, one red eye | nest of plains, crits in the four corners | 35 | 12 s | `coin_junk` x1, `debris` x3 |
| `coin_slug` | slug with a coin-slot mouth | one gold brick in the middle, plains around it | 40 | 10 s | `coin_junk` x2, `red_bricks` x2 |
| `fuse_box` | wall box with sparking fuses | bombs chained in one line across the board | 45 | 12 s | `red_bricks` x2, `debris` x6 |
| `claw_rig` | crane claw hanging over the board | two solid pillars, a wide centre lane of crits | 50 | 10 s | `pull` x1, `enemy_balls` x2 |
| `ticket_printer` | printer spooling paper | rows that advance toward the paddle (design.md "advancing bricks") | 45 | 12 s | `jam` x1, `red_bricks` x4 |
| `bootleg_cabinet` | a cabinet with a cracked screen | a mirrored copy of the fight-class starting board | 55 | 10 s | `enemy_balls` x3, `debris` x4 |

## Elites (4)

| id | signature | board hook | HP | cd | intents |
|---|---|---|---|---|---|
| `warden` | riposte: a paddle hit landing 10+ takes 2 s off the countdown (exists) | honeycomb pillars, crits in the middle lane | 120 | 10 s | `laser_sweep` x1, `enemy_balls` x3, `shield_row` |
| `repo_man` | every ball that drops steals 1 gold | vault with a shield row already raised at fight start | 110 | 10 s | `shield_row`, `coin_junk` x2, `debris` x6 |
| `arcade_bouncer` | the first hazard fired in a phase fires twice | solid pillars that narrow toward the top | 130 | 10 s | `jam` x2, `enemy_balls` x4 |
| `jackpot_reel` | three gold bricks that pay only if all three break in one phase | three vertical reels of plains, a gold brick in each | 115 | 12 s | `pull` x1, `red_bricks` x3, `debris` x8 |

## Bosses (2)

| id | phases | board hook | HP | cd | intents |
|---|---|---|---|---|---|
| `maw` | below 50% HP: cd 6 s, the mouth holds 6 hits (exists) | jaws with solid teeth, crits in the throat | 240 | 8 s | `debris` x8, `mouth`, `laser_sweep` x2 |
| `attract_mode` | a cabinet playing itself. Below 50% HP its `enemy_balls` copy the player's bag in order: each spat ball carries the trait of the next ball in the bag (heavy is bigger and slower, split splits, piercing passes the shield floor) | a big screen frame; the bricks form a high-score table, crits as the top score | 220 | 8 s | `jam` x1, `enemy_balls` x5, `pull` x1 |

## Engine notes

- `jam` is a stat on the paddle build; the mini paddle relic is not jammed.
- `pull` needs one arena-wide gravity scalar read in `_move_ball`. It is the only hazard without a body.
- `coin_junk` reuses the junk ball path events already take; it needs no new sprite, only the `intent_coin_junk` icon.
- `attract_mode`'s trait copy reads the bag; it is the one place an enemy reads player state.

## Events (3)

Same shape as `Tuning.EVENTS`: one panel, choices a / b, the row holds the numbers. Each event touches a hazard of this map so the player meets it outside a fight first. Text is the panel's, in the 3x5 face, so it stays short and upper case.

| id | title | body | a | b |
|---|---|---|---|---|
| `event_coin_return` | COIN RETURN | A DEAD CABINET. THE COIN BOX RATTLES. | PRY IT OPEN: gold 25, one `ball_junk` into the bag | WALK ON: nothing |
| `event_mod_shop` | THE MOD SHOP | A KID WITH A SOLDERING IRON LOOKS UP. | MOD A BALL: rank up one ball, hp 6 | SELL ONE: remove one ball, gold 15 |
| `event_fried_cabinet` | FRIED CABINET | SMOKE. THE SCREEN STILL FLICKERS. | PULL THE PLUG: heal 10, gold -10 | PLAY IT: a random relic, hp 8 |

`event_mod_shop` is `event_forge` rethemed and replaces it. `event_fried_cabinet` is the first event that can hand out a relic outside treasure and shop.

## Shop: the Pawn Shop

One shop screen for every map; this map's `SHOP` row changes what is stocked and one price rule.

- Stocks common and uncommon balls only, never rare. Relics: two slots, common weighted 5.
- Prices: ball 15, remove 12, heal 20 for 20 HP. Relics at list.
- One extra slot: BUY BACK. Returns the last ball removed in this run at half the ball price. Empty if nothing was removed. This is the one new button.
- Map 1 thematic balls take one of the three ball slots whenever the roll allows.

## Thematic balls (3)

Added to `Tuning.BALLS` with a `map` key of 1, so the reward and shop rolls on this map prefer them. Names in the one-word card style; desc under 36 glyphs.

| id | name | desc | rarity | dmg | trait key | ranks | behaviour |
|---|---|---|---|---|---|---|---|
| `ball_token` | TOKEN | PAYS OUT EVERY NTH BREAK | common | 1, 2, 3 | `every` | 8, 6, 4 | every nth break in a fight pays 1 gold. The `toll` relic's counter, per ball |
| `ball_rubber` | RUBBER | BOUNCES OFF THE FLOOR | uncommon | 1, 2, 3 | `floor` | 1, 2, 3 | floor bounces per phase for this ball only. The `shield_floor` relic's path, keyed to the ball |
| `ball_magnet` | MAGNET | DRAWN TO THE PADDLE | uncommon | 2, 3, 4 | `pull` | 0.5, 1.0, 1.5 | multiplies `MAGNET_PULL` for this ball; stacks with the `magnet_paddle` relic |

All three reuse an existing relic's code path, so none needs a new arm in `_break` or `_paddle_hit`.

## Engine notes, run side

- Events already carry every number they need; `event_fried_cabinet`'s relic roll is the shop's relic roll with the price skipped.
- BUY BACK needs the run state to remember the last removed ball id. One field.
- A `map` key on a `BALLS` row, blank on the universal ones, is the filter the reward and shop rolls read.
