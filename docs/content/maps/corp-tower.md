# Map 2: Corp Tower

Proposal, 2026-11-10. Nothing here is in `tuning.gd` yet. When a row lands, `docs/content.md` wins over this file.

Security hardware: ICE, drones, sentries, procedure. Every hazard is telegraphed and precise. Lasers, shields and walls instead of falling junk. The map's lesson is positioning: where the paddle stands decides what it eats.

Vocabulary as `docs/content.md`. The Map 1 hazards (`jam`, `pull`, `coin_junk`) are available here but no Corp Tower enemy intends them.

## New hazards

| id | numbers | effect | persists past a phase end |
|---|---|---|---|
| `wall_col` | `count` columns, `hits` 8 | a solid column from the top wall down to `SHIELD_Y` in a random board column that holds no crit; balls bounce off it; crumbles after 8 paddle hits or at fight end | yes |
| `blackout` | one phase | stored damage numbers on balls and the ball glow are hidden until the next phase; damage still fires | yes, until the next phase starts |
| `lockdown` | one phase | every live brick in the row nearest the paddle goes dim and refuses hits (bounces, no damage stored) until the next phase | yes, until the next phase starts |

## Enemies (8)

| id | look | board hook | HP | cd | intents |
|---|---|---|---|---|---|
| `mason` | brick-laying bot | solid-ringed vault of crits (exists) | 55 | 6 | `shield_row`, `debris` x6 |
| `sentry_drone` | hovering disc, one red lens | crits in one straight vertical lane | 60 | 5 | `laser_sweep` x1, `enemy_balls` x2 |
| `turnstile` | gate arms | three gates of solids across the middle, refresh bricks behind them | 65 | 6 | `wall_col` x1, `red_bricks` x3 |
| `camera_cluster` | eyes on stalks | a wide spread of crits with no cover | 55 | 5 | `blackout` x1, `enemy_balls` x3 |
| `server_rack` | tower of blinking lights | tall columns, dense in the centre, empty edges | 70 | 6 | `lockdown` x1, `debris` x5 |
| `intern_swarm` | small drones in a V | many refresh bricks, few plains | 50 | 4 | `enemy_balls` x4, `red_bricks` x2 |
| `auditor` | a clipboard on legs | two gold bricks ringed by solids | 65 | 6 | `blackout` x1, `shield_row` |
| `elevator` | a cab with its doors open | the board scrolls up one row at every phase end; the vacated bottom row is empty | 70 | 5 | `wall_col` x2, `laser_sweep` x1 |

## Elites (4)

| id | signature | board hook | HP | cd | intents |
|---|---|---|---|---|---|
| `ice_wall` | the shield row regrows at every phase end | two shield rows at fight start, crits above the upper one | 150 | 5 | `shield_row`, `laser_sweep` x2, `wall_col` x1 |
| `head_of_security` | laser lanes are two board columns wide | pillars, crits at both edges | 160 | 5 | `laser_sweep` x2, `enemy_balls` x3, `lockdown` |
| `legal` | every ball that drops costs 1 HP that fight | a board of refresh bricks, three crits | 140 | 6 | `blackout` x1, `red_bricks` x4, `shield_row` |
| `twin_sentries` | two intent cycles with their own cd, left and right | symmetric halves, a solid spine down the middle | 2 x 80 | 5 / 5 | left: `laser_sweep` x1; right: `enemy_balls` x2 |

## Bosses (2)

| id | phases | board hook | HP | cd | intents |
|---|---|---|---|---|---|
| `mainframe` | three cores, each its own HP bar and its own third of the board; the fight ends when all three fall. A dead core locks its third down (`lockdown`, permanent) | three vaults side by side, a crit in each | 3 x 100 | 4 | `wall_col` x2, `laser_sweep` x2, `shield_row`, `debris` x6 |
| `ceo` | a shield row that only a crit-launched ball passes; below 50% HP the shield drops for good and cd halves | a throne of solids, crits in a crown above it | 280 | 4, then 2 | `shield_row`, `blackout`, `enemy_balls` x6, `laser_sweep` x3 |

## Engine notes

- `wall_col` is a vertical `shield_row`: same crumble rule, same face, placed by column instead of row.
- `blackout` and `lockdown` are presentation and refusal rules, no bodies. `lockdown` reuses the dim state and the refusal arm of `_damage`.
- `twin_sentries` and `mainframe` need more than one intent cycle per fight. The cheap fake is one cycle whose entries alternate sides; the real version is a list of cycles in the `ENEMIES` row.
- `ceo`'s shield needs a "launched by a crit" flag on the ball; `_crit` is the one launch site that can set it.

## Events (3)

Same shape as `Tuning.EVENTS`. Corp Tower events are the first that change the next fight, which needs one `pending_hazard` field on the run state that the arena reads at fight start.

| id | title | body | a | b |
|---|---|---|---|---|
| `event_badge_check` | BADGE CHECK | A TURNSTILE. A LIGHT BLINKS RED. | PAY THE TOLL: gold -30 | JUMP IT: the next fight opens with `lockdown`; gold 0 if under 30 |
| `event_vending` | VENDING MACHINE | IT HUMS. SOMETHING IS STUCK IN THE COIL. | BUY: heal 20, gold -15 | SHAKE IT: 50% heal 20 free, 50% the next fight opens with `jam` at 10 hits |
| `event_server_closet` | SERVER CLOSET | RACKS OF DRIVES. ONE IS UNLOCKED. | COPY A FILE: a random Map 2 thematic ball | WIPE IT: remove any ball, free |

`event_vending`'s coin flip is the first random outcome in an event; it rolls on the node's `rng(site)` so CONTINUE replays it the same.

## Shop: the Company Store

- Prices rise by 5 on every purchase in the same visit, every item. Leaving resets.
- Heal is free once per visit, then 20.
- One of the three ball slots always holds a Map 2 thematic ball. Relics at list, uncommon weighted up.
- Remove 12, ball 15 base.

The rising price is one counter on the shop screen; the row carries `price_step` 5.

## Thematic balls (3)

`map` 2 on the `BALLS` row.

| id | name | desc | rarity | dmg | trait key | ranks | behaviour |
|---|---|---|---|---|---|---|---|
| `ball_laser` | LASER | FIRES DOWN ITS COLUMN TOO | uncommon | 1, 2, 3 | `lanes` | 1, 1, 2 | on paddle contact the stored damage also hits every live brick in the ball's board column (two columns at rank 3). New arm in `_paddle_hit` |
| `ball_badge` | BADGE | PASSES SHIELDS AND WALLS | uncommon | 1, 2, 3 | `pass` | 1, 2, 3 | passes through `shield_row` and `wall_col` bricks N times per phase. The `ceo` crit-pass flag, keyed to the ball |
| `ball_drone` | DRONE | HOVERS, THEN DROPS | rare | 2, 3, 5 | `hover` | 1, 2, 3 | ignores gravity for N seconds after launch, bouncing bricks on a flat path, then falls. One timer in `_move_ball` |

## Engine notes, run side

- `pending_hazard` on the run state: a hazard id and count the arena fires at fight start, then clears. Badge Check, Vending and Deep Net's Honeypot share it.
- `ball_badge` and the `ceo` shield use the same pass flag, so whichever lands first builds it for the other.
