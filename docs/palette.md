# Palette

Source: Sonic Robo Blast 2 v2.2 palette (256 colors, Lospec). Indices below refer to that file.

Theme: pachinko / slot-machine cabinet. Near-black surface, a few saturated lit accents, each hue owns one meaning.

## Rules

- Base is a dark near-black, never pure black, so glow has something to brighten.
- Accents are full-value, full-saturation neon. Test at 50% alpha over the base: it must still look lit.
- One hue per meaning. Payout, combo, danger, placement each own a color. UI never borrows a brick color.
- Unbreakable and inactive things are dim and desaturated so lit things pop on dense boards.
- Warm white for text, ball, chrome. Never cold white.
- Text over base needs ~7:1 contrast. Red fails; don't use it for numbers.
- There is one currency, shown in payout yellow. Effects (sparks, blasts, beams) stay in it too, so a break never introduces a hue.

## Groups

Every board object belongs to one group, and the group owns one hue in the arena and in the upgrade web alike. A brick's group is `Tuning.hue(kind)`: `mag`, `ora` or `blue`.

| Group | Hue | Idx | Hex | Dim state | In the arena | In the web |
|---|---|---|---|---|---|---|
| Basic bricks | magenta | 180 | `ff4aff` | 185 `790079` | plain, multi, multi3. Glass brightens a step per hit left and drops a step on each hit; hp 1 is the plain glass | Blocks |
| Level specials | orange | 54 | `ff7500` | 58 `9f3800` | what a level places and no upgrade adds: shield, cond, cgate, timed, seq1..3, slowdown, x3, jackpot (`hue = "ora"` on the row). Locked state is the dim lamp, open is lit | no nodes |
| Unlocks | blue | off-palette | `3d6bff` | `1a2f8f` | icon kinds with a web node of the same id, and their halo | Unlocks: the kind's node and every node that modifies it (Bigger Bomb, Longer Timer, Twin) |
| Placeables | mint | 122 | `15f2b0` | 126 `027354` | bumpers, pads, gates, launchers, magnets, portals, spawners, the valid ghost and placement line | Placement, including modifiers (Pop Power, Hotter Launch, Magnet Reach, Fast Spawner) |
| Paddle | sky | 132 | `4fc7ff` | `155386` | the paddle's stripe and its hit flash over chrome | Paddle |
| Round | violet | 164 | `7f16ff` | `5b00c9` | only the shield floor; time and extra balls have no board object | Round |
| Dead | slate | 172 | `5454a7` | | solid, hole, walls: unlit chrome and trim, the ball ignores or bounces | |

Blue is off-palette, picked deeper than sky so the paddle stays apart. Violet was held for a brick colour paying a second currency (`docs/design.md`); that idea now needs a new hue, since the palette has no spare neon ramp (cyan 255 is a single).

## Game assignment

| Role | Idx | Hex | Dim state |
|---|---|---|---|
| Base | 254 | `000020` | |
| Cabinet trim | 174 | `2e2e5c` | |
| Dead / unbreakable | 172 | `5454a7` | |
| Payout / sparks | 73 | `ffff00` | 77 `887809` |
| Gold trim | 64 | `ebdb57` | 68 `9b5b13` |
| Danger / timer low / invalid ghost | 35 | `ff0000` | 43 `7f0000` |
| Ball / text / chrome | 80 | `ffffcf` | 84 `ebde81` |

## Upgrade web

A node's lamp takes its category's hue (`tuning.gd` `CATS`, sprites `node_<cat>_<state>`): the hue of the arena thing it adds or changes, per the Groups table. Links and costs stay payout yellow.

Known gaps: no true gold neon (64–71 is bronze, tops at 0.63 sat). No cyan ramp, only the single 255 `00ffff`.

## Ramps

### Neutrals

| Idx | Ramp | Use |
|---|---|---|
| 0–31 | White → black, 32 steps | Base, trim, text. 26–30 are cabinet near-blacks. |
| 240–251 | Warm tan, 12 steps | Alt dead-brick color if warmth wanted. |
| 252–254 | Singles: blush white, `00003f`, `000020` | Cold cabinet base. |

### Neon (full value and saturation at top, dim tail below)

| Idx | Ramp | Top | Use |
|---|---|---|---|
| 32–47 | Red, 16 | `ff0000` | Danger, timer. |
| 48–63 | Orange, 16 | `ff7500` | Level specials. |
| 72–79 | Yellow, 8 | `ffff00` | Lamps, payout. |
| 112–119 | Pure green, 8 | `00ff00` | Harsh. Short flashes only. |
| 120–127 | Mint, 8 | `15f2b0` | Bumpers, placement. |
| 128–139 | Sky → navy, 12 | `4fc7ff` | Paddle. |
| 144–159 | Lavender → blue, 16 | `0000ff` | Backgrounds. Unlock blue `3d6bff` sits just off this ramp. |
| 160–169 | Violet, 10 | `7f16ff` | Round upgrades and the shield floor. |
| 176–187 | Magenta, 12 | `ff00ff` | Basic bricks. |
| 255 | Cyan single | `00ffff` | No ramp. |

### Gold and warm mids

| Idx | Ramp | Top | Use |
|---|---|---|---|
| 64–71 | Gold → bronze, 8 | `ebdb57` | Metal trim, not neon. |
| 80–87 | Cream yellow, 8 | `ffffcf` | Warm white: text, ball, chrome. |
| 188–191 | Chartreuse, 4 | `c5e800` | Acid accent, sparingly. |

### Muted (not neon, mostly skip)

| Idx | Ramp | Use |
|---|---|---|
| 88–95 | Sage green, 8 | Skip. |
| 96–111 | Leaf green, 16 | Skip. |
| 140–143 | Teal grey, 4 | Dim bumper alt. |
| 170–175 | Slate periwinkle, 6 | Inactive UI, trim. |
| 192–199 | Dusty mauve, 8 | Warm purple base alt (`2b152b`, `402040`). |
| 200–207 | Rose, 8 | Softer pink alt. |
| 208–215 | Salmon, 8 | Skip. |
| 216–239 | Skin / brown, 24 | Skip. |
