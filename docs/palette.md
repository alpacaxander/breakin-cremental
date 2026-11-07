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
- There is one currency, shown in payout yellow. Violet is held back for the coloured bricks in `docs/design.md` that would pay a second one.

## Game assignment

| Role | Idx | Hex | Dim state |
|---|---|---|---|
| Base | 254 | `000020` | |
| Cabinet trim | 174 | `2e2e5c` | |
| Dead / unbreakable | 172 | `5454a7` | |
| Payout | 73 | `ffff00` | 77 `887809` |
| Gold trim | 64 | `ebdb57` | 68 `9b5b13` |
| Plain brick | 180 | `ff4aff` | 185 `790079` |
| Bumper / placement | 122 | `15f2b0` | 126 `027354` |
| Danger / timer low | 35 | `ff0000` | 43 `7f0000` |
| Ball / text / chrome | 80 | `ffffcf` | 84 `ebde81` |

Reserved: violet 164 `7f16ff`, for a future brick colour.

Sky means paddle. The conditional-brick strips (`docs/animations.md`) borrow it, but no conditional kind is in `tuning.gd` yet; when one lands it needs its own hue or the Paddle nodes move, since the palette has no spare ramp (cyan 255 is a single).

## Upgrade web

A node's lamp takes its category's hue (`tuning.gd` `CATS`, sprites `node_<cat>_<state>`). Placement and Blocks reuse the hue of the thing they buy; Paddle takes sky, already the paddle-extras hue in `gen.mjs`; Round takes orange. Unlocks (the brick kinds in `ICON_KINDS`) take blue, which the icon bricks share in the arena: a blue thing is an unlock. It is off-palette, picked deeper than sky so the paddle stays apart. Links and costs stay payout yellow.

| Category | Idx | Hex | Dim state |
|---|---|---|---|
| Paddle | 132 | `4fc7ff` | `155386` |
| Round | 54 | `ff7500` | `9f3800` |
| Placement | 122 | `15f2b0` | 126 `027354` |
| Blocks | 180 | `ff4aff` | 185 `790079` |
| Unlocks | off-palette | `3d6bff` | `1a2f8f` |

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
| 48–63 | Orange, 16 | `ff7500` | Round upgrades. |
| 72–79 | Yellow, 8 | `ffff00` | Lamps, payout. |
| 112–119 | Pure green, 8 | `00ff00` | Harsh. Short flashes only. |
| 120–127 | Mint, 8 | `15f2b0` | Bumpers, placement. |
| 128–139 | Sky → navy, 12 | `4fc7ff` | Paddle. |
| 144–159 | Lavender → blue, 16 | `0000ff` | Backgrounds. Unlock blue `3d6bff` sits just off this ramp. |
| 160–169 | Violet, 10 | `7f16ff` | Reserved for a future brick colour. |
| 176–187 | Magenta, 12 | `ff00ff` | Plain bricks. |
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
