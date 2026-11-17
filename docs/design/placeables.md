# Placeables

Items the player places on the board during Setup. They are unlocked in the Placeables category of the [upgrade web](upgrades.md). Every value is provisional.

See also: [overview.md](overview.md#level-phases), [levels.md](levels.md), [physics.md](physics.md).

## Kinds

| Kind | Where it can go | Items in the demo |
|---|---|---|
| **Free-form** | Anywhere in the arena where it doesn't overlap a brick, another placed item or the paddle lane, and is clear of the ball where it rests and of its way to the paddle. It doesn't snap to the grid. Some free-form items can be rotated | Bumper, Booster, Wall Segment (rotatable) |
| **Placeable brick** | Snaps to the brick grid, on empty brick cells only, and not on the ball where it rests or its way to the paddle | Splitter, Growth, Refresh |
| **Brick mod** | Only on a brick that is already on the board. It gives that one brick an effect | Zap |

The paddle lane is the strip between the open side and the first grid column (see [art.md](../art.md#level-screen)).

## Items

Each item is unlocked by the node of the same name in the [upgrade web](upgrades.md#the-demos-web).

| Item | Kind | What it does |
|---|---|---|
| **Bumper** | Free-form | A diamond. The ball bounces off its faces. It doesn't change the ball's speed |
| **Booster** | Free-form | A circle. The ball bounces off it at the point where it touches, and leaves faster by 20% of its base speed (100 units/s). The extra speed is a boost (see [physics.md](physics.md#ball)) |
| **Wall Segment** | Free-form, rotatable | A straight wall the ball bounces off |
| **Splitter** | Placeable brick | A 1 HP brick. When a ball breaks it, that ball splits in two: one bounces back off it as usual and the other carries on the way the ball came in, through the gap. Each rank of Splitter Splits adds one more ball, fanned 20° from the last and kept to the minimum angles. If a blast or a Zap breaks it, it just breaks |
| **Growth** | Placeable brick | A block that never breaks: a ball bounces off it as off a brick, and no hit takes its HP. Every 5 s of play (1 s less per rank of Pulse Rate, never under 1 s) it gives 1 HP to each level brick within 1 square of its edges (the area of a base blast), up to 4 HP. Each rank of Growth Reach adds one more square. It never grows a placed brick |
| **Refresh** | Placeable brick | A block that never breaks, like Growth. When a ball hits it, the 3 broken level bricks nearest it come back as plain 1 HP bricks; each rank of Refresh Size brings 2 more. Then it waits 4 s, less 1 s per rank of Pulse Rate and never under 1 s, drawn dim. A brick that came back scores and counts toward the target and the clear like any level brick. Nearest is by distance between the cells' centres, ties to the lower column, then the lower row. A cell a ball is in is skipped, special bricks come back plain and Zaps do not come back. A hit that finds nothing to bring back leaves it ready. A blast or a Zap does not set it off |
| **Zap** | Brick mod | When the tagged brick breaks, every other brick in its row, from the paddle side to the back wall, takes 1 hit. That is the rest of the row: 2 bricks on level 1 (none in its top and bottom rows), 15 on level 2 and 63 on level 3 |

A Zap can go on any brick, including a special brick or a Splitter, but not on a Growth or Refresh block, which never breaks to set it off. If the brick it was saved on is gone when the level loads, the Zap is dropped like any other item that no longer fits.

## Rules

- **Counts.** A placeable's unlock node has ranks, and each rank lets you place one more of that item: rank 1 gives 1, rank 2 gives 2, and so on. This is the same rule special bricks use.
- **Saved layout.** Each level keeps its own layout. It is part of the save, and it is already on the board when Setup opens, so a retry doesn't need the items placed again.
- **Loading a layout.** Any saved item that no longer fits is dropped, for example because the level was edited or the item's count went down.
- **Sealing the open side is allowed.** Nothing stops the player from fencing the ball into the board with free-form items so it can't drop.
- **A strip in front of the paddle is kept clear.** Nothing can be placed from the paddle's face to 8 bricks (128 units) right of it, level with the paddle's start. A level has no bricks there either. The strip is left over from the old straight-left launch; the ball now launches off the paddle (see [physics.md](physics.md#ball)).
- **Placed bricks:**
  - pay no coins
  - don't count toward clearing the level
  - extend the combo when broken; a hit that leaves one standing does not (a hit on a level brick does, broken or not)
  - Growth and Refresh never break: their hits pay nothing and don't extend the combo
- **Ball speed.** Only the Booster changes a ball's speed. Every other placeable just bounces the ball (see [physics.md](physics.md#ball)).

## Controls

- Drag an item from the tray onto the board to place it.
- Rotate a rotatable item with the scroll wheel or with Q and E while dragging it.
