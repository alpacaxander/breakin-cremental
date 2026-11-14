# Levels

## Rules

- The arena is horizontal, with the **paddle on the left edge** moving up and down. The back wall is on the right. Ball and paddle behaviour is in [physics.md](physics.md).
- The layout is a grid of cells. Each cell is twice as tall as it is wide.
- Each brick is **1 column wide × 2 rows tall**.
- A **square** is a block of 4 columns × 2 rows, which is 4 bricks side by side. Because cells are twice as tall as wide, a square really is square on screen.
- Bricks have **HP**, the number of hits needed to destroy them. The default is 1. A brick's colour shows the hits it has left and changes each time it is hit (see [palette.md](../palette.md#brick-hp)). The three levels here use 1 and 2 HP. 3 and 4 are further colour steps, 4 the top one, a deep violet, and no level uses them yet.
- Every brick is a standard brick unless the level says otherwise.
- **Editable in Godot:** each level is its own scene, `levels/level_<n>.tscn`, and you paint its bricks in the editor. The scene's root is a TileMapLayer with a `title` and a `rows` field. One tile is one brick, and the tile set has a tile for each HP, with the number on it. The grid's edge is outlined, because the columns follow from the rows. To add a level, duplicate a scene under the next number.
- Clearing every brick unlocks the next level. Phases and end conditions are described in [overview.md](overview.md#level-phases).

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
| 1 | Three Columns | 16 | 64 × 16 | 100% |
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

## Level 1: three columns near the back

64 × 16. Columns 0–51 are empty. In the last 12 columns (52–63), the pattern is empty, bricks, empty, bricks, empty, bricks, followed by 6 empty columns. Bricks are in columns 53, 55 and 57, for 24 bricks in total.

Every brick is 1 HP. That is 24 hits to clear.

Tougher bricks do not fit a first round: it holds about one hit for every trip the ball makes to the back, 7 or 8 in all, so behind a 3 HP front column a new player breaks nothing. The level is still cleared only with upgrades, because the last few bricks take longer to find than the first.

```
   +----------------------------------------------------------------+
   |.....................................................█.█.█......|
   |.....................................................█.█.█......|
   |.....................................................█.█.█......|
   |.....................................................█.█.█......|
   |.....................................................█.█.█......|
   |.....................................................█.█.█......|
|  |.....................................................█.█.█......|
|  |.....................................................█.█.█......|
|  |.....................................................█.█.█......|
|  |.....................................................█.█.█......|
   |.....................................................█.█.█......|
   |.....................................................█.█.█......|
   |.....................................................█.█.█......|
   |.....................................................█.█.█......|
   |.....................................................█.█.█......|
   |.....................................................█.█.█......|
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
- The tunnel mouth is left open.
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
