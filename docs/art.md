# Art

How to build real assets that match the mockups. Colours and what they mean are in [palette.md](palette.md). This file covers size, shape, glow, effects, type and UI. Every value is provisional.

Mockups: [BreakIn cremental look](https://claude.ai/artifact/6Kpd6EhDk1VkAwn1KGsMgk), a canvas with a level (Setup and Play, levels 1–3) and the upgrade screen. If this file and the mockups disagree, fix whichever one is wrong so they match again.

**The mockups are behind the docs in five places.** Until they are redrawn, the docs are right:

- The ball in Setup rests against the paddle. It should sit a little to the right of it.
- Level 1's bricks are all 1 HP. The columns should be 3 HP, 2 HP and 1 HP.
- Level 3 is drawn at 64 × 16 with the tunnel below centre and 3 HP strong bricks. It should be 72 × 18, zoomed to fit, with 4 HP strong bricks.
- The bumper ghost snaps to a grid cell. The bumper is free-form and doesn't snap.
- Special bricks are a share of the level's bricks, and the web has "Explosive Chance" and "Bumper Count" nodes. Counts now come from the unlock node's ranks (see [upgrades.md](design/upgrades.md#counts-come-from-ranks)).

## Rules

- **Reference frame: 1280 × 720.** Every size here is in whole pixels at that frame. The game scales the frame to the window and keeps the aspect ratio (in Godot: stretch mode `canvas_items`, aspect `keep`).
- **Arena sizes are for a 16-row level.** Things inside the arena shrink or grow with the level's size (see [Arena zoom](#arena-zoom)).
- **Draw shapes, don't paint them.** Bricks, the paddle, the ball, placeables, bars, panels and upgrade nodes are flat rectangles drawn in the engine (`ColorRect`, `Polygon2D` or `draw_rect`). They have no textures, outlines, bevels, gradients or rounded corners. If something does need a texture, make it white and tint it with a palette colour, so every colour is defined only in `palette.md`.
- **Bake no glow.** Halos, shadows and flashes all come from bloom. Lit colours bloom and slate never does: set the bloom threshold above the slate neutrals and push lit colours over it (in Godot: WorldEnvironment glow with HDR 2D on).
- **Squares, never circles.** The ball, particles and the coin glyph are squares. The coin glyph and the bumper are squares turned 45°.
- **Snap to the grid.** Bricks sit on the level's grid from [levels.md](design/levels.md). Placeable bricks and brick mods snap to it too. Free-form placeables, such as the bumper and the wall segment, don't snap (see [placeables.md](design/placeables.md)).
- **Bloom target.** The mockups fake bloom with CSS shadows: a tight halo of about 6 px and a soft one of about 15 px around bricks, with a stronger one around the ball. Tune bloom to that at ×1 and let the combo push it higher.

## Level screen

| Element | Size and place | Look |
|---|---|---|
| HUD | x 96–1184, y 10–96 | Three columns: time on the left, combo (Play) or SETUP (Setup) in the centre, coins on the right |
| Arena | 1088 × 524 at (96, 104) | Walls 6 px thick in `2a2f4e` on the top, bottom and back. The paddle side is open |
| Grid | 1024 × 512, starting 58 px in from the arena's left edge | Cell 16 × 32 on a 16-row level. The 58 px in front of it is the paddle lane |
| Backdrop grid | The whole grid | Play: 2 px lines every 64 px (one square) in `1a1932`. Setup: those lines turn `2a2f4e`, with 1 px `1a1932` lines on every cell |
| Brick | A 16 × 64 cell, drawn at 14 × 62 | 1 px gap on every side, so 2 px between bricks. The colour comes from HP or kind |
| Paddle | 12 × 96, 24 px in from the arena's left edge | Body `657392`, with a 4 px cyan stripe on the side facing the board |
| Ball | 12 × 12 | White. In Setup it sits about 48 px to the right of the paddle's stripe, vertically centred like the paddle |
| Bumper | 30 × 30, turned 45° | Blue. Free-form |
| Wall segment | 10 × 112 | Blue. Free-form, and it can be rotated |
| Placeable brick | A brick cell, drawn like a brick | Blue, so it can't be mistaken for a brick that pays |
| Placement ghost | Same as the item | Fill `00396d`, a 2 px dashed blue border and no glow. For an item that snaps, the cell under it gets a cyan fill at 12% and a 1 px cyan border at 50% |
| Footer | x 96–1184, y 640–704 | Play: level number and name, a brick legend with 6 × 22 swatches, bricks left. Setup: the placeable tray, a count of this run's special bricks, Start |

**HUD numbers:** a 12 px Silkscreen label in secondary text with 2 px letter spacing. Below it a 68 px Jersey 10 number (the combo is 84 px), and below that a 6 px bar. Each bar is lit over the dim shade of its meaning: the timer is 220 px of green over `1e6f50`, and the combo window is 160 px of gold over `8a4836`.

## Arena zoom

Levels have different grid sizes (see [levels.md](design/levels.md#arena-size)). The sizes in the table above are for a 16-row level.

- **Fixed on screen:** the arena frame and its 6 px walls, the 1024 × 512 grid area, the 58 px paddle lane, the HUD and the footer. They are the same at every level size.
- **Zoomed:** everything inside the walls is drawn at zoom = 16 ÷ rows. That covers bricks and their gaps, the backdrop grid, the paddle and its distance from the edge, the ball and its trail, placeables, ghosts, particles and shockwaves. On an 18-row level a cell is about 14.2 × 28.4 px.
- **Not zoomed:** text. Coin pop-ups keep their size so the pixel fonts stay sharp.
- **Whole pixels only hold at 16 rows.** At other sizes the zoomed shapes land on fractional pixels, and that is accepted.
- **Small sizes.** As the row count grows, the 1 px gaps between bricks and the bloom halos fade out first. A ceiling on level size is an open question in [design.md](design.md#open-questions).

## Effects

Effects take the colour of whatever made them. Sizes below are at their peak. Ease effects in and fade them out. Effects scale with the combo: more particles, bigger shockwaves and stronger bloom as it climbs. The mockup shows ×12.

| Effect | Look |
|---|---|
| Brick break | 8 squares of 3–5 px in the brick's colour, thrown out ahead of the ball |
| Explosion | Two square shockwaves: 96 px with a 3 px `ff5000` border, and 160 px with a 2 px `c64524` border at 40%. Under them, an orange light pool 360 px wide: 24% at the centre, fading to nothing at 68% of the radius. 24 squares of 3–6 px spread 24–120 px out, fading with distance; two thirds are orange and a third take the colour of the bricks it broke |
| Coin pop-up | 36 px gold Jersey 10 that rises and fades. Older pop-ups shrink to 30 px at 60%, then 26 px at 35% |
| Ball trail | 7 squares behind the ball, 13 px apart, shrinking from 11 to 5 px and fading from 44% to 8%. It's white because it's part of the ball |
| Reduce flashing | Drops the light pool and screen flashes and caps bloom. Shockwaves and particles stay |

## Type

| Font | Use | Sizes (px) |
|---|---|---|
| Jersey 10 | Numbers, titles, big buttons, pop-ups | 84 combo, 68 HUD numbers, 56 screen title, 46 panel title, 36 buttons and pop-ups |
| Silkscreen | Labels, tags, prices on nodes. All caps | 11–16, letter spacing 1–2 |
| Chakra Petch | Names and body text | 14–18 semibold for names, 16 on a 22 line for descriptions |

- All three come from Google Fonts under the SIL Open Font License. Commit each font file together with its licence.
- Jersey 10 and Silkscreen are pixel fonts. Turn antialiasing off for them and round each size above to the nearest one where every stem renders at the same width.
- Lit numbers (time, combo, coins, prices) bloom like lit shapes. Labels and body text use the text neutrals and don't bloom.

## UI pieces

| Piece | Look |
|---|---|
| Panel | Fill `1a1932`, a 2 px `424c6e` border, square corners, about 20 px of padding |
| Primary button | Cyan fill, base-colour text in 36 px Jersey 10, 56 px tall |
| Disabled button | Fill `2a2f4e`, text `92a1b9` |
| Can't afford | No fill, a 2 px danger outline, primary text |
| Icon button | 44 × 44 with a base fill and a 2 px border: cyan when it can be used, `424c6e` when it can't |
| Icons | Flat filled shapes or 2.5 px strokes in the text colour. No emoji or font glyphs for arrows |
| Coin glyph | A gold square turned 45°, about a quarter of the number's height |
| Hit target | At least 44 × 44 |

## Upgrade screen

**Layout:** a top bar 84 px tall with the title on the left and coins on the right. Below it, the web view at (24, 88), 864 × 608. On the right, the detail panel at (904, 88), 352 × 284, and the level panel at (904, 388), 352 × 308.

**Web view:**
- **Frame:** a 2 px `2a2f4e` border over a dot grid of 3 px dots every 24 px, also in `2a2f4e`.
- **Spacing:** nodes sit on a 170 × 116 px pitch.
- **Node:** 148 × 60 px (the seed node is 168 × 72), with 8 × 10 px padding. The name is top left. Rank pips (8 px squares, 4 px apart) are bottom left, and the price or MAX is bottom right.
- **Connections:** 3 px lines that run straight across or straight down through node centres. A line is lit in its outer node's category colour once either end is owned; otherwise it's `424c6e`. Lines from the seed meet at a 12 px junction square.
- **Category labels:** Silkscreen in the category's lit colour.

| Node state | Fill | Border | Text | Pips |
|---|---|---|---|---|
| Maxed | Lit | Lit | Base `0e071b` | Base |
| Owned | Dim | Lit, solid | Primary | Lit for each rank owned, `424c6e` for the rest |
| Available | Base | Lit, dashed | Primary | `424c6e` |
| Locked | Base | `424c6e` | Secondary | `424c6e` |

The selected node keeps its state's look and adds a 2 px cyan outline 4 px outside the node, plus a cyan glow. Prices are gold when you can afford them and secondary text when you can't, never red.

**Detail panel:** from the top:
- the category in its colour, with the state on the right
- the name in 46 px Jersey 10
- 16 px rank pips
- the effect text
- the next rank's price in 40 px Jersey 10, beside the Buy button

**Level panel:**
- ◄ ► icon buttons around the level number (48 px Jersey 10) and the level's name.
- A 256 × 128 thumbnail of the layout, scaled so the whole grid fits. On a 16-row level that is 4 px per column and 8 px per row, with bricks drawn 3 × 15 in their HP colours. A locked level's thumbnail is at 35% opacity.
- Then Play Level, or a disabled "Clear level N to unlock".

## CRT

The CRT is one full-screen pass over everything, UI included. It's on by default and can be turned off in Settings.

- **Scanlines:** every 3 px, one row darkened by 26%.
- **Vignette:** clear out to 58% of the radius, then darkening to 60% at the corners.
- **Curvature:** real barrel distortion. The mockups only fake it with 28 px rounded corners and an inner shadow.

## Checking an asset

1. Screenshot the game at 1280 × 720 and compare it side by side with the mockup artboard.
2. Every colour is a `palette.md` value before the CRT.
3. Only lit things glow, and nothing outshines the ball.
4. Text stays readable with the CRT on and off.
5. Turn on reduce flashing and check that nothing strobes.
