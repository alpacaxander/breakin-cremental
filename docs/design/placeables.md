# Placeables

Items the player places on the board during Setup. They are unlocked in the Placeables category of the [upgrade web](upgrades.md). Every value is provisional.

See also: [overview.md](overview.md#level-phases), [levels.md](levels.md), [physics.md](physics.md).

## Kinds

| Kind | Where it can go | Items in the demo |
|---|---|---|
| **Free-form** | Anywhere in the arena where it doesn't overlap a brick, another placed item or the paddle lane, and is clear of the ball where it rests and of its way to the paddle. It doesn't snap to the grid. Some free-form items can be rotated | Bumper, Booster (rotatable), Wall Segment (rotatable) |
| **Placeable brick** | Snaps to the brick grid, on empty brick cells only, and not on the ball where it rests or its way to the paddle | Splitter, Refresh |
| **Area** | Snaps to any brick cell, with a brick on it or not, but not to another area's cell. It covers a rectangle around that cell and is not solid: the ball and every other item ignore it, and other items can go on or over it | Growth |

The paddle lane is the strip between the open side and the first grid column (see [art.md](../art.md#level-screen)).

## Items

Each item is unlocked by the node of the same name in the [upgrade web](upgrades.md#the-demos-web), except the Bumper and Refresh, which no node unlocks: they are still in the code but can't be placed in the game.

| Item | Kind | What it does |
|---|---|---|
| **Bumper** | Free-form | A diamond. The ball bounces off its faces. It doesn't change the ball's speed |
| **Booster** | Free-form, rotatable | A gate. The ball passes through it either way, never bounces, and comes out faster by 20% of its base speed (100 units/s). The extra speed is a boost (see [physics.md](physics.md#ball)) |
| **Wall Segment** | Free-form, rotatable | A straight wall the ball bounces off |
| **Splitter** | Placeable brick | A 1 HP brick. When a ball hits it, that ball splits in two: one bounces back off it as usual and the other goes on the way the ball came in, out of its far side (through the gap, if it broke). If it still stands (Splitter Health) and the far side holds a brick or is past a wall, the new ball leaves the near side instead, mirrored to the bounced one along the face. With Splitter Respawn a broken Splitter comes back, with its full HP, 6 s of play later, 2 s sooner for each rank after the first, once no ball is over its cell. If a blast or a Zap breaks it, it just breaks (and still comes back). A charged ball that hits it keeps its charge for the next level brick |
| **Growth** | Area | Covers its cell and 1 square out from the cell's edges (the area of a base blast); each rank of Growth Reach adds one more square. It pulses once at the start of a round, 0.5 s of play in, and once more 0.5 s after that for each rank of Growth Pulses (at most 3 pulses, done 1.5 s in). Each pulse gives 1 HP to each level brick in the area, up to 4 HP. It never grows a placed brick, and nothing hits it |
| **Refresh** | Placeable brick | A block that never breaks: a ball bounces off it as off a brick, and no hit takes its HP. When a ball hits it, the 3 broken level bricks nearest it come back as plain 1 HP bricks; each rank of Refresh Size brings 2 more. Then it waits 4 s, drawn dim. A brick that came back scores and counts toward the target and the clear like any level brick. Nearest is by distance between the cells' centres, ties to the lower column, then the lower row. A cell a ball is in is skipped and special bricks come back plain. A hit that finds nothing to bring back leaves it ready. A blast or a Zap does not set it off |

Zap was a brick mod, a fourth kind that went on a brick already on the board. It is now an ability a charge fires (see [upgrades.md](upgrades.md#what-the-abilities-do)), and the brick-mod kind is gone. A saved layout that still holds one skips it on load, as it skips any entry whose kind is no longer a placeable.

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
  - Refresh never breaks: its hits pay nothing and don't extend the combo (a Growth area is never hit)
- **Ball speed.** Only the Booster changes a ball's speed, and it is the one placeable the ball goes through, Growth aside, which it does not touch at all. Every other placeable just bounces the ball (see [physics.md](physics.md#ball)).

## Controls

- Drag an item from the tray onto the board to place it.
- Rotate a rotatable item with the scroll wheel or with Q and E while dragging it.
