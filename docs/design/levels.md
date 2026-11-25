# Levels

## Rules

- The arena is horizontal, with the **paddle on the left edge** moving up and down. The back wall is on the right. Ball and paddle behaviour is in [physics.md](physics.md).
- The layout is a grid of cells. Each cell is twice as tall as it is wide.
- Each brick is **1 column wide × 2 rows tall**.
- A **square** is a block of 4 columns × 2 rows, which is 4 bricks side by side. Because cells are twice as tall as wide, a square really is square on screen.
- Bricks have **HP**, the number of hits needed to destroy them. The default is 1. A brick's colour shows the hits it has left and changes each time it is hit (see [palette.md](../palette.md#brick-hp)). The three levels here use 1 and 2 HP. 3 and 4 are further colour steps, 4 the top one, a deep violet, and no level uses them yet.
- Every brick is a standard brick unless the level says otherwise.
- **Editable in Godot:** each level is its own scene, `levels/level_<n>.tscn`, and you paint its bricks in the editor. The scene's root is a TileMapLayer with a `title` and a `rows` field. One tile is one brick, and the tile set has a tile for each HP, with the number on it. The grid's edge is outlined, because the columns follow from the rows. To add a level, duplicate a scene under the next number.
- **Painted special bricks:** a level can paint a special brick. The tile set's orange alternative of the 1 HP tile is a Power Brick (the tile's `kind` is `power`). A painted one is there every round, at any rank, on top of the ones the round rolls. Only the test level uses this; the three demo levels paint standard bricks.
- **The test level:** `levels/level_0.tscn`, "Abilities Test", is for trying the ability system and is not part of the demo. It is not counted, the upgrade screen never shows it, and clearing it unlocks nothing; a round on it still pays coins. The Admin panel (` in a debug build) opens it with "Play the test level", and "Max abilities" beside it buys every rank in the Abilities category. It is 64 × 16 with a column of 8 Power Bricks at column 30, so the first hits make drops even with no upgrade, and behind it a block of 24 columns × 8 rows (columns 36–59) in bands of 1, 1, 2, 2, 3, 3, 1 and 1 HP with 4 more Power Bricks inside: long rows for Zap's range and damage, a dense block for Blast, and Power Bricks an ability can break. 200 bricks, 341 hits, target 300.
- **Aim marks:** a level can mark cells a skilled player aims the ball at, such as a gap that lets the ball behind a wall. Paint them with the tile set's fifth tile, the hollow one with a cross (`hp` 0, shown cyan in the editor), on empty cells. They are not bricks, and the game never shows them: only the balance bot reads them (`LevelData.aims`), and its better players aim at them instead of the middle of the bricks (`focus` in `tests/balance.gd`).
- A round whose score reaches the level's target clears it and unlocks the next level. Phases and end conditions are described in [overview.md](overview.md#level-phases).
- Each level scene sets its `target`, set with the balance bot's campaign against the stages (see [design.md](../design.md#progression)) and not yet by hand: level 1 is 28, level 2 is 384 and level 3 is 2048. The retune after the ability system raised level 2's from 320 and lowered level 3's from 8192, which the average player's campaign had taken 43 rounds to reach. On level 3 the target moves both stages together, because its rounds pay from tens of coins to thousands: at 2048 the three skills' stage 1 ends on the level's 1st to 4th round and stage 2 on its 13th to 21st, against goals of 6 and 16 (see [upgrades.md](upgrades.md#the-demos-web), "What the bot measured"). Before the ability system, and on the 64-column wall, the same was true from 6144 up: stage 2 ended a few rounds after stage 1.

## Arena size

Levels come in different sizes. The arena keeps the same shape and the same place on screen, and the view zooms to fit the level.

- **A level sets its row count.** The count is even, so 2-row bricks fill it.
- **Columns = rows × 4.** That keeps the grid's shape constant, and it always comes out to a whole number of columns.
- **The base size is 16 rows**, which gives 64 × 16. At that size a full column holds 8 bricks.
- **Zoom = 16 ÷ rows.** Everything inside the arena zooms together: bricks, ball, paddle, placeables and effects. The HUD and the rest of the UI don't zoom. The pixel rules are in [art.md](../art.md#arena-zoom).
- **The smallest level is 14 rows.** The paddle lane keeps its width on screen while the paddle and ball keep theirs in cells, so on a smaller level the ball no longer fits between the paddle and the grid. The number follows from the ball and paddle sizes in `data/balance.tres`.
- **Bigger levels are harder to defend.** The paddle and ball keep their size in cells, so on a bigger level the paddle covers less of the open side and the ball takes longer to cross the board. Paddle size and ball speed upgrades are the answer to that.

| Level | Name | Rows | Grid | Zoom |
|---|---|---|---|---|
| 1 | Two Columns | 14 | 56 × 14 | 114% |
| 2 | Checkerboard | 16 | 64 × 16 | 100% |
| 3 | The Tunnel | 18 | 72 × 18 | 89% |

```
 paddle                 brick grid (rows × 4 columns wide)             back wall
   │  ┌────────────────────────────────────────────────────────────────┐ │
   ▼  │                                                                │ ▼
  ║   │                                                                │
  ║ o │                                                                │
      └────────────────────────────────────────────────────────────────┘
   HUD:  ⏱ 20.0   ● 0
```

## Layouts

Legend: `█` = 1 HP brick, `▓` = 2 HP brick, `.` = empty, `|` = paddle.

## Level 1: two columns

56 × 14, the smallest a level can be. Two full-height columns of bricks, each 2 wide: columns 42–43 (three quarters of the way) and 54–55, against the back wall. That is 14 + 14 = 28 bricks.

Every brick is 1 HP. That is 28 hits to clear.

The first column walls off the back one: the ball reaches the back column only through a hole it has broken.

```
   +--------------------------------------------------------+
   |..........................................██..........██|
   |..........................................██..........██|
   |..........................................██..........██|
   |..........................................██..........██|
   |..........................................██..........██|
|  |..........................................██..........██|
|  |..........................................██..........██|
|  |..........................................██..........██|
|  |..........................................██..........██|
   |..........................................██..........██|
   |..........................................██..........██|
   |..........................................██..........██|
   |..........................................██..........██|
   |..........................................██..........██|
   +--------------------------------------------------------+
```

## Level 2: 4×4 checkerboard of big squares

- 64 × 16. Every brick is 1 HP.
- A 4×4 checkerboard of big squares, alternating filled and empty. A big square is 2 × 2 squares: 8 columns × 4 rows, 16 bricks. It covers columns 24–55 and the full height.
- Behind it are 2 square-widths of empty space (columns 56–63).
- In front of it, columns 0–23 are empty.
- 8 filled big squares × 16 bricks = 128 bricks.

```
   +----------------------------------------------------------------+
   |........................████████........████████................|
   |........................████████........████████................|
   |........................████████........████████................|
   |........................████████........████████................|
   |................................████████........████████........|
   |................................████████........████████........|
|  |................................████████........████████........|
|  |................................████████........████████........|
|  |........................████████........████████................|
|  |........................████████........████████................|
   |........................████████........████████................|
   |........................████████........████████................|
   |................................████████........████████........|
   |................................████████........████████........|
   |................................████████........████████........|
   |................................████████........████████........|
   +----------------------------------------------------------------+
```

## Level 3: solid wall with a tunnel

- 72 × 18, one brick taller than the base size, so the tunnel sits exactly in the middle. In squares (4 columns × 2 rows, a 64 × 64 square on screen like level 2's) that is 18 × 9.
- Columns 0–31 (8 squares on the paddle side) and 64–71 (2 squares at the back wall) are empty.
- Columns 32–63 (8 squares) are solid bricks.
- A tunnel 1 brick tall (rows 8–9, the fifth of nine brick rows) runs straight through the wall.
- Column 32, the face of the wall toward the paddle, is 2 HP.
- The brick rows on both sides of the tunnel (rows 6–7 and 10–11) are 2 HP.
- Every other brick is 1 HP.
- The tunnel mouth is left open. Its first cell (column 32, rows 8–9) is an aim mark: a good player gets the ball into the tunnel, where it bounces between the 2 HP rows and wears them down. The ball's shallowest angle, 8°, takes it to a tunnel wall within about 370 units, so a ball never flies the tunnel clean.
- 256 bricks, 70 of them 2 HP. That is 326 hits to clear, and 326 points before combos and special bricks, since every hit scores 1 (see [overview.md](overview.md#coins)). The wall was 64 columns (512 bricks, 646 hits) until the front 7 squares and the back square were emptied. The rest of this bullet was measured on that wall, before the ability system, and has not been rerun; the campaigns in [upgrades.md](upgrades.md) were rerun on the new one. On it, a round with every upgrade broke most of the board in its first 10 s, with blasts and Zaps, and spent the rest on what they left: the 2 HP bricks along the tunnel (not the Tough Brick special, which is 3 HP), one ball at a time. So their HP set how long the level took: at 3 HP the balance bot's average player cleared it in 3 rounds of 10 with everything bought, and only a longer round raised that (4 of 10 at 82 s); at 2 HP it was 4 of 10 in 55 s.
- The wall's face is 529 units from the paddle's (it was 81), so a ball that misses the tunnel mouth takes about 2 s there and back at the base speed instead of a fraction of one. The paddle's steepest angle is 45°, and Paddle Size grows the paddle to half the lane.

```
   +------------------------------------------------------------------------+
   |................................▓███████████████████████████████........|
   |................................▓███████████████████████████████........|
   |................................▓███████████████████████████████........|
   |................................▓███████████████████████████████........|
   |................................▓███████████████████████████████........|
   |................................▓███████████████████████████████........|
   |................................▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓........|
|  |................................▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓........|
|  |........................................................................|
|  |........................................................................|
|  |................................▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓........|
   |................................▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓........|
   |................................▓███████████████████████████████........|
   |................................▓███████████████████████████████........|
   |................................▓███████████████████████████████........|
   |................................▓███████████████████████████████........|
   |................................▓███████████████████████████████........|
   |................................▓███████████████████████████████........|
   +------------------------------------------------------------------------+
```
