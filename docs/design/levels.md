# Levels

## Rules

- The arena is horizontal, with the **paddle on the left edge** moving up and down. The back wall is on the right. Ball and paddle behaviour is in [physics.md](physics.md).
- The layout is a grid of cells. Each cell is twice as tall as it is wide.
- Each brick is **1 column wide × 2 rows tall**.
- A **square** is a block of 4 columns × 2 rows, which is 4 bricks side by side. Because cells are twice as tall as wide, a square really is square on screen.
- Bricks have **HP**, the number of hits needed to destroy them. The default is 1. A brick's colour shows the hits it has left and changes each time it is hit (see [palette.md](../palette.md#brick-hp)). The three levels here use 1 and 2 HP. 3 and 4 are further colour steps, 4 the top one, a deep violet, and no level uses them yet.
- Every brick is a standard brick unless the level says otherwise.
- **Editable in Godot:** each level is its own scene, `levels/level_<n>.tscn`, and you paint its bricks in the editor. The scene's root is a TileMapLayer with a `title` and a `rows` field. One tile is one brick, and the tile set has a tile for each HP, with the number on it. The grid's edge is outlined, because the columns follow from the rows. To add a level, duplicate a scene under the next number.
- **Aim marks:** a level can mark cells a skilled player aims the ball at, such as a gap that lets the ball behind a wall. Paint them with the tile set's fifth tile, the hollow one with a cross (`hp` 0, shown cyan in the editor), on empty cells. They are not bricks, and the game never shows them: only the balance bot reads them (`LevelData.aims`), and its better players aim at them instead of the middle of the bricks (`focus` in `tests/balance.gd`).
- A round whose score reaches the level's target clears it and unlocks the next level. Phases and end conditions are described in [overview.md](overview.md#level-phases).
- Each level scene sets its `target`. First values, twice the brick count and not yet measured: level 1 is 40, level 2 is 256 and level 3 is 1024.

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
| 1 | Two Columns | 16 | 64 × 16 | 100% |
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

64 × 16. Two columns of bricks: columns 48–49 (three quarters of the way, 2 wide) and 62 (1 wide), which leaves a single empty column behind it at the back wall. The first column has a gap of one brick at the top (rows 0–1) and one at the bottom (rows 14–15); the back column is the full height. That is 12 + 8 = 20 bricks.

Every brick is 1 HP. That is 20 hits to clear.

The gaps let the ball round the first column to the back, where the last few bricks take the longest to find.

The four cells of the two gaps (columns 48–49 of rows 0–1 and 14–15) are aim marks: a good player sends the ball through a gap to reach the back column.

```
   +----------------------------------------------------------------+
   |..............................................................█.|
   |..............................................................█.|
   |................................................██............█.|
   |................................................██............█.|
   |................................................██............█.|
   |................................................██............█.|
|  |................................................██............█.|
|  |................................................██............█.|
|  |................................................██............█.|
|  |................................................██............█.|
   |................................................██............█.|
   |................................................██............█.|
   |................................................██............█.|
   |................................................██............█.|
   |..............................................................█.|
   |..............................................................█.|
   +----------------------------------------------------------------+
```

## Level 2: 8×8 checkerboard of squares

- 64 × 16. Every brick is 1 HP.
- An 8×8 checkerboard of squares, alternating filled and empty. It covers columns 24–55 and the full height.
- Behind it are 2 square-widths of empty space (columns 56–63).
- In front of it, columns 0–23 are empty.
- 32 filled squares × 4 bricks = 128 bricks.

```
   +----------------------------------------------------------------+
   |........................████....████....████....████............|
   |........................████....████....████....████............|
   |............................████....████....████....████........|
   |............................████....████....████....████........|
   |........................████....████....████....████............|
   |........................████....████....████....████............|
|  |............................████....████....████....████........|
|  |............................████....████....████....████........|
|  |........................████....████....████....████............|
|  |........................████....████....████....████............|
   |............................████....████....████....████........|
   |............................████....████....████....████........|
   |........................████....████....████....████............|
   |........................████....████....████....████............|
   |............................████....████....████....████........|
   |............................████....████....████....████........|
   +----------------------------------------------------------------+
```

## Level 3: solid wall with a tunnel

- 72 × 18, one brick taller than the base size, so the tunnel sits exactly in the middle.
- Columns 0–3 (paddle side) and 68–71 (back wall) are empty.
- Columns 4–67 are solid bricks.
- A tunnel 1 brick tall (rows 8–9, the fifth of nine brick rows) runs straight through the wall.
- Column 4, the face of the wall toward the paddle, is 2 HP.
- The brick rows on both sides of the tunnel (rows 6–7 and 10–11) are 2 HP.
- Every other brick is 1 HP.
- The tunnel mouth is left open. Its first cell (column 4, rows 8–9) is an aim mark: a good player gets the ball into the tunnel, where it bounces between the 2 HP rows and wears them down. The ball's shallowest angle, 8°, takes it to a tunnel wall within about 370 units, so a ball never flies the tunnel clean.
- 512 bricks, 134 of them 2 HP. That is 646 hits to clear. A round with every upgrade breaks most of the board in its first 10 s, with blasts and Zaps, and spends the rest on what they leave: the tough bricks along the tunnel, one ball at a time. So their HP sets how long the level takes: at 3 HP the balance bot's average player clears it in 3 rounds of 10 with everything bought, and only a longer round raises that (4 of 10 at 82 s); at 2 HP it is 4 of 10 in 55 s.
- The wall's face is 81 units from the paddle's, so a ball that misses the tunnel mouth is back in a fifth of a second. What makes that playable is in the numbers, not the layout: the paddle's steepest angle is 45°, and Paddle Size grows the paddle to half the lane.

```
   +------------------------------------------------------------------------+
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓....|
|  |....▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓....|
|  |........................................................................|
|  |........................................................................|
|  |....▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓....|
   |....▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓....|
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓███████████████████████████████████████████████████████████████....|
   |....▓███████████████████████████████████████████████████████████████....|
   +------------------------------------------------------------------------+
```
