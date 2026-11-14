# Art

How to build real assets that match the mockups. Colours and what they mean are in [palette.md](palette.md). This file covers size, shape, glow, effects, type and UI. Every value is provisional.

Mockups: [BreakIn cremental look](https://claude.ai/artifact/6Kpd6EhDk1VkAwn1KGsMgk), a canvas with a level (Setup and Play, levels 1–3) and the upgrade screen. If this file and the mockups disagree, fix whichever one is wrong so they match again.

The main menu, Settings and the Summary have no mockup. They are described below as they were built.

**The mockups are behind the docs in these places.** Until they are redrawn, the docs are right:

- Neither screen has a back button. The upgrade screen's top bar and the Setup footer each get one (see [UI pieces](#ui-pieces)).
- The ball in Setup rests against the paddle. It should sit a little to the right of it.
- Level 1's bricks are all 1 HP. The columns should be 3 HP, 2 HP and 1 HP.
- Level 3 is drawn at 64 × 16 with the tunnel below centre and 3 HP strong bricks. It should be 72 × 18, zoomed to fit, with 4 HP strong bricks.
- The bumper ghost snaps to a grid cell. The bumper is free-form and doesn't snap.
- Special bricks are a share of the level's bricks, and the web has "Explosive Chance" and "Bumper Count" nodes. Counts now come from the unlock node's ranks (see [upgrades.md](design/upgrades.md#counts-come-from-ranks)).
- The web is grouped by category, with a label over each group and a junction square under the seed. The demo's web mixes the categories around a seed in the centre (see [upgrades.md](design/upgrades.md#the-demos-web)).
- The Booster, the Splitter and the Zap mark are not drawn.
- A tray slot reads "1 OF 2 LEFT", and locked placeables are in the tray. A slot now shows pips, and only unlocked placeables are listed (see [Setup](#setup)).
- The combo is one number, "×12". It is now the combo count with the multiplier beside it (see [HUD numbers](#level-screen)).
- The legend lists every brick type. It now lists only what is on the board.
- The web view has a legend of the node states, zoom buttons and a "drag to pan" hint. The web has none of them: it does not pan or zoom yet.
- A Buy the player can't afford reads "CAN'T AFFORD" in a small font. It reads BUY in the can't-afford look.
- A locked level's button reads "CLEAR LEVEL N TO UNLOCK". It reads "CLEAR LEVEL N FIRST", which fits in the button font.

## Rules

- **Reference frame: 1280 × 720.** Every size here is in whole pixels at that frame. The game scales the frame to the window and keeps the aspect ratio (in Godot: stretch mode `canvas_items`, aspect `keep`).
- **Arena sizes are for a 16-row level.** Things inside the arena shrink or grow with the level's size (see [Arena zoom](#arena-zoom)).
- **Draw shapes, don't paint them.** Bricks, the paddle, the ball, placeables, bars, panels and upgrade nodes are flat rectangles drawn in the engine (`ColorRect`, `Polygon2D` or `draw_rect`). They have no textures, outlines, bevels, gradients or rounded corners. If something does need a texture, make it white and tint it with a palette colour, so every colour is defined only in `palette.md`.
- **Bake no glow.** Halos, shadows and flashes all come from bloom. Lit colours bloom and slate never does: set the bloom threshold above the slate neutrals and push lit colours over it (in Godot: WorldEnvironment glow with HDR 2D on).
- **Squares, never circles, with one exception.** The ball, particles and the coin glyph are squares. The coin glyph and the bumper are squares turned 45°. The Booster is the only circle in the game (`draw_circle`): it has to bounce like a round thing, and its shape sets it apart from the Bumper.
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
| Booster | A circle 32 across | Blue. Free-form |
| Wall segment | 10 × 112 | Blue. Free-form, and it can be rotated |
| Placeable brick (Splitter) | A brick cell, drawn like a brick | Blue, so it can't be mistaken for a brick that pays |
| Zap mark | A 6 × 6 square in the centre of the tagged brick | Blue, with a 2 px base-colour rim so it shows on a brick of any colour, a blue Splitter included. The brick keeps its own colour |
| Placement ghost | Same as the item | Where it fits: fill `00396d`, a 2 px dashed blue border and no glow. For an item that snaps, the cell under it gets a cyan fill at 12% and a 1 px cyan border at 50%. Where it does not fit: fill `891e2b`, a dashed `ff0040` border, and the cell in red instead of cyan. A snapping item whose cell is off the board is drawn at the cursor |
| Footer | x 96–1184, y 644–700 | Play: level number and name, a legend with 6 × 22 swatches of the HP steps and special bricks on this board, bricks left. Setup: a back button (to Upgrades), the placeable tray, a count of this run's special bricks, Start (see [Setup](#setup)). Summary: only the back button |

**HUD numbers:** a 12 px Silkscreen label in secondary text with 2 px letter spacing. Below it a 68 px Jersey 10 number (the combo is 84 px), and below that a 6 px bar. Each bar is lit over the dim shade of its meaning: the timer is 220 px of green over `1e6f50`, and the combo window is 160 px of gold over `8a4836`.

- **Combo.** The big number is the combo count, which changes on every break. The multiplier is a 36 px lit "×3" to its right, shown once it is above 1. With no combo running the count is 0 in `8a4836`. The whole column is hidden until combos are bought.
- **Low timer.** At the low-timer mark the bar turns red. The number stays green: red is never a number.
- **Coins** are the coins of the round on screen, so 0 in Setup. The balance is on the upgrade screen.
- **In Setup** the centre column is SETUP in lit cyan over two hint lines in secondary text: how to place, turn and remove once a placeable is unlocked, otherwise how to start and how to move the paddle. The time label reads "TIME · STOPPED".

### Setup

- **Tray slot:** 56 px tall, panel fill, a 2 px blue border. It shows the item's shape (24 px, lit), its name in 14 px Chakra Petch semibold, and one 8 px pip for each one allowed, lit while it is still to place. With all of them placed the border goes grey and the shape dim. Under the cursor the fill turns `00396d`. Only unlocked placeables have a slot; with none, a hint line says where they are unlocked.
- **This run:** a "THIS RUN" tag over the count of each special brick rolled for this attempt, each with a 6 × 18 swatch.
- **Start:** the primary button with a triangle, at the right end. Space and Enter do the same.
- **Backdrop:** the cell lines of the table above, so a snapping item's cell can be seen.

### Summary

A panel 440 px wide, centred over the arena, which stays as the round left it. It appears half a second after the round ends, so the last hit is seen. From the top:

- a tag with the level's number and name
- how the round ended in 56 px Jersey 10: LEVEL CLEARED in lit cyan, TIME UP or BALL LOST in primary text
- a hint line: the bricks left, "Every brick broken", or the level that was just unlocked
- the tally, one row for each kind of brick broken: a 6 × 18 swatch, the name, the count, and what the row paid as a small gold price. Placed bricks get a row that says "pay nothing". With combos bought, a last row gives the best combo and its multiplier. Rows appear one by one, each with a tally tick
- COINS and the round's total in 68 px gold, counting up
- Retry (secondary) and Upgrades (primary). Retry has the keyboard focus, so Space or Enter retries

The back button sits where Setup has it and does what Upgrades does.

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
- **The sizes that exist.** Jersey 10 has even stems at 19, 37, 56, 75 and 93 px (multiples of 56 ÷ 3), so the sizes above come out as 93 combo, 75 HUD numbers, 56 screen title and 37 for panel titles, buttons and pop-ups. Any Jersey size in this file rounds the same way through `UiTheme.number_size`: 40 and 46 give 37, 48 gives 56. Silkscreen has even stems at 8, 16 and 24 px; 8 can't be read through the CRT, so every Silkscreen label is 16 and the two tag styles differ only in letter spacing.
- Lit numbers (time, combo, coins, prices) bloom like lit shapes. Labels and body text use the text neutrals and don't bloom.

## UI pieces

| Piece | Look |
|---|---|
| Panel | Fill `1a1932`, a 2 px `424c6e` border, square corners, about 20 px of padding |
| Primary button | Cyan fill, base-colour text in 36 px Jersey 10, 56 px tall |
| Secondary button | The second choice beside a primary one (Retry, Settings, Quit): base fill, a 2 px cyan border, primary text, the same size and font. No mockup |
| Button states | Hover is a brighter lit fill on a primary button and a dim cyan fill on a secondary or icon button. Pressed is plain, unlit cyan. Keyboard focus is a 2 px `92a1b9` outline 4 px outside the button. No mockup |
| Disabled button | Fill `2a2f4e`, text `92a1b9` |
| Can't afford | No fill, a 2 px danger outline, primary text. It can still be pressed: it plays the "can't afford" sound and buys nothing |
| Icon button | 44 × 44 with a base fill and a 2 px border: cyan when it can be used, `424c6e` when it can't |
| Back button | An icon button with a left-pointing arrow. Esc does the same. It has no tooltip |
| Top bar | 84 px tall, x 24–1256: the back button, then the screen's title in 56 px Jersey 10. The upgrade screen and Settings share it |
| Focus cursor | On the main menu and Settings, a lit cyan triangle 12 px to the left of the focused control, or of its row. It is the only sign of focus on a slider |
| Toggle | A 44 × 44 square with a 2 px cyan border: base fill when off, lit cyan fill when on. Its label sits to the right in primary text |
| Slider | A 6 px track in `2a2f4e`, lit cyan from the left end to the grabber. The grabber is a 16 × 28 cyan rectangle. The row is 44 px tall, so it meets the hit target |
| Dropdown | The secondary button's look at 44 px tall, in 18 px Chakra Petch semibold, with a chevron. Its list is a panel with 44 px rows and a cyan dot beside the chosen one. No mockup |
| Tooltip | A small panel with 14 px Chakra Petch text |
| Icons | Flat filled shapes or 2.5 px strokes in the text colour. No emoji or font glyphs for arrows |
| Coin glyph | A gold square turned 45°, about a quarter of the number's height |
| Hit target | At least 44 × 44 |

## Upgrade screen

**Layout:** a top bar 84 px tall with a back button (to the main menu) and the title on the left, the tag "BUY A NODE TO UNLOCK ITS NEIGHBOURS" after it, and coins on the right. Below it, the web view at (24, 88), 864 × 608. On the right, the detail panel at (904, 88), 352 × 284, and the level panel at (904, 388), 352 × 308.

**Web view:**
- **Frame:** a 2 px `2a2f4e` border over a dot grid of 3 px dots every 24 px, also in `2a2f4e`.
- **Spacing:** nodes sit on a 170 × 116 px pitch. The demo's web is 5 columns × 5 rows with the seed in the centre. It fills the view, so the web does not pan or zoom yet.
- **Node:** 148 × 60 px (the seed node is 168 × 72), with 8 × 10 px padding. The name is top left. Rank pips (8 px squares, 4 px apart) are bottom left, and the price or MAX is bottom right.
- **Connections:** 3 px lines that run straight across or straight down through node centres. A line is lit in its outer node's category colour once either end is owned; otherwise it's `424c6e`.
- **Categories:** a node's colour is the only thing that shows its category. The web mixes the categories, so there are no group labels.

| Node state | Fill | Border | Text | Pips |
|---|---|---|---|---|
| Maxed | The category colour, unlit | Lit | Base `0e071b` | Base |
| Owned | Dim | Lit, solid | Primary | Lit for each rank owned, `424c6e` for the rest |
| Available | Base | Lit, dashed | Primary | `424c6e` |
| Locked | Base | `424c6e` | Secondary | `424c6e` |

A maxed node's fill is not lit: a lit fill blooms over the 14 px name and washes it out. Its lit border carries the glow.

The selected node keeps its state's look and adds a 2 px cyan outline 4 px outside the node, plus a cyan glow. Prices are gold when you can afford them and secondary text when you can't, never red. A locked node shows its price too, in secondary text, so the player can see what to save for.

**Detail panel:** from the top:
- the category in its colour, with the state on the right
- the name in 46 px Jersey 10
- 16 px rank pips
- the effect text
- the next rank's price in 40 px Jersey 10, beside the Buy button. Buy reads BUY when the node is open: the primary button if the coins cover it, the can't-afford look and a grey price if not. On a locked node it is disabled and reads LOCKED; on a maxed one it reads MAXED and the price is gone

**Level panel:**
- ◄ ► icon buttons around the level number (48 px Jersey 10) and the level's name.
- A 256 × 128 thumbnail of the layout, scaled so the whole grid fits. On a 16-row level that is 4 px per column and 8 px per row, with bricks drawn 3 × 15 in their HP colours. A locked level's thumbnail is at 35% opacity.
- Then Play Level, or a disabled "CLEAR LEVEL N FIRST".
- The status on the right of the panel's tag reads CLEARED, NOT CLEARED YET or LOCKED.
- The panel opens on the highest level unlocked and jumps to a level when it unlocks. Thumbnail bricks are unlit.

## Main menu

No mockup. The menu is an empty arena, drawn flat like the game's and not moving:

- **Walls:** 6 px `2a2f4e` walls 24 px in from the top and the bottom, and a back wall at x 1250.
- **Paddle and ball:** a 12 × 96 paddle at x 40, level with Play, with the ball resting 48 px from its stripe.
- **Bricks:** three columns of lit bricks in front of the back wall: 1, 2 and 3 HP from the front, with three of the front bricks already broken.
- **Title:** "BREAKIN" spelled in lit 18 px square bricks on a 20 px pitch, five rows from y 124, each row in a brick HP colour from 4 HP at the top to 1 HP at the bottom. Under it "CREMENTAL" in 68 px Jersey 10, lit gold.
- **Buttons:** Play (primary), Settings and Exit (secondary) in a column 360 px wide from y 384, 16 px apart. Focus starts on Play. Esc does nothing here.

## Settings

No mockup. The top bar with the title SETTINGS, and a panel 640 px wide centred at y 176 with 24 px of extra padding at the sides for the focus cursor:

- a DISPLAY tag over two toggles, "CRT filter" and "Reduce flashing", each with a hint at the right end of its row
- a VOLUME tag over two sliders, Music and Sound, each with its name on the left and its percentage in 36 px Jersey 10, unlit, on the right. A slider moves in steps of 5%

Every control applies and saves as it changes; there is nothing to confirm. The back button and Esc go to the main menu.

## CRT

The CRT is one full-screen pass over everything, UI included. It's on by default and can be turned off in Settings.

- **Scanlines:** every 3 px, one row darkened by 26%.
- **Vignette:** clear out to 58% of the radius, then darkening by 60% at the corners.
- **Curvature:** real barrel distortion, which moves the corners in by about 12 px. The mockups only fake it with 28 px rounded corners and an inner shadow.

## Checking an asset

1. Screenshot the game at 1280 × 720 and compare it side by side with the mockup artboard.
2. Every unlit colour is a `palette.md` value before the CRT. A lit colour shows as the full-brightness version of its hue, which for some is brighter than its hex (see [architecture.md](architecture.md#rendering)).
3. Only lit things glow, and nothing outshines the ball.
4. Text stays readable with the CRT on and off.
5. Turn on reduce flashing and check that nothing strobes.
