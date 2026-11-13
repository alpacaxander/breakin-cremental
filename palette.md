# Palette

Theme: neon cyberpunk. Near-black surface, lit tubes in full-saturation hues, cool steel for everything unlit. Each hue owns one meaning.

Status: proposed 2026-11-10, previewed in `assets/pixel/preview/palette.html` (open it in a browser: sample fight, lamp per hue, role map, every ramp). `assets/pixel/gen.mjs` still draws from the deprecated palette at the bottom of this file; when it moves, this table wins and the old section goes.

Built from the Sonic Robo Blast 2 v2.2 palette (256 colours, Lospec): 86 of its colours kept, 170 dropped, 44 added. Thirteen ramps of ten steps each, lightest tint first, deepest shade last. 130 slots used, 126 free.

## Rules

- Base is a dark near-black, never pure black, so glow has something to brighten.
- Accents are full-value, full-saturation neon. Test at 50% alpha over the base: it must still look lit.
- One hue per meaning. Damage, gold, danger, crit, refresh each own a colour. UI never borrows a brick colour.
- Unlit things are gunmetal: paddle body, walls, solids, shield rows, hull, inactive UI. Dim and desaturated so lit things pop on dense boards.
- Cold white (ice, cyan's top) for text. The ball is cream (yellow's light end) so it reads as a physical object, not text.
- Text over base needs ~7:1 contrast. Red fails; don't use it for numbers. Enemy HP and the player's HP are red bars with ice numbers.
- Damage is yellow and gold is gold. Effects (sparks, blasts, beams) stay yellow, so a break never introduces a hue. Red is the enemy's and appears only on things that hurt the player.
- Backdrops are the base, a faint circuit grid in deep gunmetal, and neon tubes on the hull. Violet's deep end is the only purple a backdrop gets.
- A lamp takes four steps of one ramp: tube (bright), ring (mid), deep, highlight (tint). See `docs/art-style.md`.

## Groups

Every board object belongs to one group, and the group owns one hue in the arena and in the HUD alike. A brick's group is `Tuning.hue(kind)`: `mag`, `ora`, `blue`, `mint` or `red`.

| Group | Ramp | Tube | Ring | Deep | Highlight | Meaning |
|---|---|---|---|---|---|---|
| Basic bricks | magenta | `ff4aff` | `a200a2` | `350035` | `ffcaff` | plain, multi, multi3. Glass brightens a step per hit left and drops a step on each hit; hp 1 is the plain glass |
| Bomb and act specials | orange | `ff7500` | `c44f00` | `791800` | `ffb975` | bomb bricks and the specials an act's boards place (shield, conditional, timed, sequence). Locked is the dim lamp, open is lit |
| Crit | electric blue | `3131ff` | `0000c4` | `000052` | `c6c6ff` | crit bricks (launch the next ball) and their halo. Was the off-palette `3d6bff` |
| Refresh | mint | `15f2b0` | `02936b` | `01563f` | `b7fbe7` | refresh bricks and the wave that relights the board |
| Telegraphs | amber gold, mid | `ffb000` | `c07c00` | `503000` | `ffe08a` | intent countdown pips, hazard warning stripes, timed bricks. Red stays pure danger |
| Paddle and player | cyan | `00ffff` | `00a0b8` | `003a50` | `b0ffff` | the paddle's stripe and its hit flash over gunmetal; starting paddles, holograms, the map path |
| Relics | violet | `7f16ff` | `48009f` | `240051` | `c799ff` | relic and ball-trait icons in the HUD, shop and rewards; the shield floor relic's floor line |
| Traits: poison, junk, virus | green | `00ff00` | `00bf00` | `003f00` | `a0ff60` | infectious and corrupt things, the hack cue |
| Enemy | red | `ff0000` | `9f0000` | `370000` | `ff7f7f` | enemies' lit accent, red and fuse bricks, enemy balls, goo, lasers, debris, both HP bars |
| UI accent | hot pink | `ff1493` | `c00c6a` | `300218` | `ffa0d0` | buttons, selection, the logo, the shop sign. Bricks never use it |
| Dead | gunmetal | `7494a4` | `3e5c6c` | `0c141c` | `e8f4f8` | solid, hole, walls, shield rows: unlit chrome bands, the ball ignores or bounces |

There is one currency (gold); violet goes to relics, pink to the UI.

## Game assignment

| Role | Idx | Hex | Dim state |
|---|---|---|---|
| Base | 89 | `000020` | |
| Backdrop grid | 129 | `0c141c` | traces 128 `14202c` |
| Hull and trim | 126 | `2c4452` | |
| Dead / unbreakable | 123 | `7494a4` | |
| Inactive UI | 125 | `3e5c6c` | |
| Damage / sparks | 44 | `ffff00` | 48 `887809` |
| Gold: run currency, prices | 32 | `ffc84a` | 36 `9b5b13` |
| Enemy / danger / invalid ghost | 12 | `ff0000` | 15 `9f0000` |
| Text | 70 | `e0ffff` | 74 `00e0e8` |
| Ball / chrome highlight | 41 | `ffffcf` | 46 `c9bb0e` |

The map is drawn in hull gunmetal with the node kinds as icons and the path in cyan; reward and shop cards are violet lamps.

## Ramps

Indices are the proposed order (hover a swatch in the preview page to see them). Every ramp is ten steps, tint to deep.

| Idx | Ramp | Use | Steps |
|---|---|---|---|
| 0–9 | Greys | Text shadows, pause dim, debug. Rare on screen. | `ffffff dadada b7b7b7 979797 777777 575757 3f3f3f 272727 171717 070707` |
| 10–19 | Red | Enemies and everything they put on the board. | `ff7f7f ff3f3f ff0000 df0000 bf0000 9f0000 7f0000 5f0000 470000 370000` |
| 20–29 | Orange | Bomb bricks and the act specials. | `ffdbc0 ffb975 ff9736 ff7500 dd5e00 c44f00 9f3800 8a2900 812000 791800` |
| 30–39 | Amber gold | Gold on the light end, telegraphs on the saturated mid. | `fff5a8 ffe08a ffc84a ffb000 e09600 c07c00 9b5b13 784800 503000 2b1a06` |
| 40–49 | Yellow | Cream end: ball, chrome highlights. Pure end: damage, sparks. | `fffff0 ffffcf ffffaf ffff73 ffff00 e3d90f c9bb0e aa9b0b 887809 5a4905` |
| 50–59 | Green | Poison, junk, virus, hack cue, terminal blinks. Leans green, lime tints on top. | `e0ffc0 a0ff60 60ff20 00ff00 00df00 00bf00 009f00 007f00 005f00 003f00` |
| 60–69 | Mint | Refresh. | `e0fff4 b7fbe7 66f7cb 15f2b0 0bd297 03b180 02936b 027354 01563f 00301f` |
| 70–79 | Cyan | The player: paddle stripe and flash, holograms, map path, text (ice, the top step). | `e0ffff b0ffff 80ffff 00ffff 00e0e8 00c0d0 00a0b8 007f98 005c74 003a50` |
| 80–89 | Electric blue | Crit bricks and their halo. The deepest step is the base. | `e7e7ff c6c6ff 8c8cff 5252ff 3131ff 0000ff 0000c4 000095 000052 000020` |
| 90–99 | Violet | Relics and trait icons. Deep end for backdrop glow only. | `d8b7ff c799ff ad6aff 9844ff 7f16ff 6b00ee 5b00c9 48009f 330071 240051` |
| 100–109 | Hot pink | UI accent: buttons, selection, logo, shop sign. | `ffd0e8 ffa0d0 ff70b8 ff40a0 ff1493 e0107f c00c6a 900850 600436 300218` |
| 110–119 | Magenta | Basic bricks. | `ffcaff ffaaff ff8aff ff4aff ff00ff dd00dd a200a2 790079 550055 350035` |
| 120–129 | Gunmetal | Unlit chrome: paddle body, walls, solids, shield rows, hull, inactive UI. | `e8f4f8 c0d4dc 98b4c0 7494a4 567888 3e5c6c 2c4452 1e3040 14202c 0c141c` |
| 130–255 | Free | | |

Dropped from the source: sky, slate, sage, leaf, teal grey, chartreuse, dusty mauve, rose, salmon, skin and brown, warm tan, the blush white and `00003f` singles, and the trimmed steps of greys, red, orange, blue, magenta, gold, yellow, cream and pure green. Cyan covers sky; gunmetal covers slate, teal grey and tan; violet's deep end covers mauve; hot pink replaces rose at full saturation; green's light end covers chartreuse.

---

# Deprecated: cabinet palette

Superseded 2026-11-10 by the neon cyberpunk palette above. Still what `assets/pixel/gen.mjs` draws from until the art moves over; kept so the current PNGs can be read against it.

Source: Sonic Robo Blast 2 v2.2 palette (256 colors, Lospec). Indices below refer to that file.

Theme: pachinko / slot-machine cabinet. Near-black surface, a few saturated lit accents, each hue owns one meaning.

## Rules (deprecated)

- Base is a dark near-black, never pure black, so glow has something to brighten.
- Accents are full-value, full-saturation neon. Test at 50% alpha over the base: it must still look lit.
- One hue per meaning. Damage, gold, danger, crit, refresh each own a color. UI never borrows a brick color.
- Unbreakable and inactive things are dim and desaturated so lit things pop on dense boards.
- Warm white for text, ball, chrome. Never cold white.
- Text over base needs ~7:1 contrast. Red fails; don't use it for numbers. Enemy HP and the player's HP are red bars with warm-white numbers.
- Damage is yellow and gold is gold. Effects (sparks, blasts, beams) stay yellow, so a break never introduces a hue. Red is the enemy's and appears only on things that hurt the player.

## Groups (deprecated)

| Group | Hue | Idx | Hex | Dim state | Meaning |
|---|---|---|---|---|---|
| Basic bricks | magenta | 180 | `ff4aff` | 185 `790079` | plain, multi, multi3. Glass brightens a step per hit left and drops a step on each hit; hp 1 is the plain glass |
| Bomb and act specials | orange | 54 | `ff7500` | 58 `9f3800` | bomb bricks and the specials an act's boards place (shield, conditional, timed, sequence). Locked is the dim lamp, open is lit |
| Crit | blue | off-palette | `3d6bff` | `1a2f8f` | crit bricks (launch the next ball) and their halo |
| Refresh | mint | 122 | `15f2b0` | 126 `027354` | refresh bricks and the wave that relights the board |
| Paddle | sky | 132 | `4fc7ff` | `155386` | the paddle's stripe and its hit flash over chrome; starting paddles |
| Relics | violet | 164 | `7f16ff` | `5b00c9` | relic and ball-trait icons in the HUD, shop and rewards; the shield floor relic's floor line |
| Enemy | red | 35 | `ff0000` | 43 `7f0000` | enemies' lit accent, red and fuse bricks, enemy balls, goo, lasers, debris, intents, both HP bars |
| Dead | slate | 172 | `5454a7` | | solid, hole, walls, shield rows: unlit chrome and trim, the ball ignores or bounces |

Blue is off-palette, picked deeper than sky so the paddle stays apart. There is one currency (gold); violet goes to relics.

## Game assignment (deprecated)

| Role | Idx | Hex | Dim state |
|---|---|---|---|
| Base | 254 | `000020` | |
| Cabinet trim | 174 | `2e2e5c` | |
| Dead / unbreakable | 172 | `5454a7` | |
| Damage / sparks | 73 | `ffff00` | 77 `887809` |
| Gold: run currency, prices, trim | 64 | `ebdb57` | 68 `9b5b13` |
| Enemy / danger / invalid ghost | 35 | `ff0000` | 43 `7f0000` |
| Ball / text / chrome | 80 | `ffffcf` | 84 `ebde81` |

The map is drawn in cabinet trim with the node kinds as icons; reward and shop cards are violet lamps.

Known gaps: no true gold neon (64–71 is bronze, tops at 0.63 sat). No cyan ramp, only the single 255 `00ffff`. The gold lamp uses off-palette `2b1a06` and `fff5a8`.

## Ramps (deprecated, source indices)

### Neutrals

| Idx | Ramp | Use |
|---|---|---|
| 0–31 | White → black, 32 steps | Base, trim, text. 26–30 are cabinet near-blacks. |
| 240–251 | Warm tan, 12 steps | Alt dead-brick color if warmth wanted. |
| 252–254 | Singles: blush white, `00003f`, `000020` | Cold cabinet base. |

### Neon (full value and saturation at top, dim tail below)

| Idx | Ramp | Top | Use |
|---|---|---|---|
| 32–47 | Red, 16 | `ff0000` | Enemies and hazards, danger. |
| 48–63 | Orange, 16 | `ff7500` | Bomb and act specials. |
| 72–79 | Yellow, 8 | `ffff00` | Lamps, damage. |
| 112–119 | Pure green, 8 | `00ff00` | Harsh. Short flashes only. |
| 120–127 | Mint, 8 | `15f2b0` | Refresh. |
| 128–139 | Sky → navy, 12 | `4fc7ff` | Paddle. |
| 144–159 | Lavender → blue, 16 | `0000ff` | Backgrounds. Crit blue `3d6bff` sits just off this ramp. |
| 160–169 | Violet, 10 | `7f16ff` | Relics. |
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
