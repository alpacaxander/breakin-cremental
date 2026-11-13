# Placeables

Items the player places on the board during Setup. They are unlocked in the Placeables category of the [upgrade web](upgrades.md). Every value is provisional.

See also: [overview.md](overview.md#level-phases), [levels.md](levels.md), [physics.md](physics.md).

## Kinds

| Kind | Where it can go | Items in the demo |
|---|---|---|
| **Free-form** | Anywhere in the arena where it doesn't overlap a brick, another placed item or the paddle lane. It doesn't snap to the grid. Some free-form items can be rotated | Bumper, Booster, Wall Segment (rotatable) |
| **Placeable brick** | Snaps to the brick grid, on empty brick cells only | Splitter |
| **Brick mod** | Only on a brick that is already on the board. It gives that one brick an effect | Zap |

The paddle lane is the strip between the open side and the first grid column (see [art.md](../art.md#level-screen)).

## Items

Each item is unlocked by the node of the same name in the [upgrade web](upgrades.md#the-demos-web).

| Item | Kind | What it does |
|---|---|---|
| **Bumper** | Free-form | A diamond. The ball bounces off its faces. It doesn't change the ball's speed |
| **Booster** | Free-form | A circle. The ball bounces off it at the point where it touches, and leaves faster by 25% of its base speed. The extra speed is a boost (see [physics.md](physics.md#ball)) |
| **Wall Segment** | Free-form, rotatable | A straight wall the ball bounces off |
| **Splitter** | Placeable brick | A 1 HP brick. When a ball breaks it, that ball splits in two. If a blast or a Zap breaks it, it just breaks |
| **Zap** | Brick mod | When the tagged brick breaks, every other brick in its row, from the paddle side to the back wall, takes 1 hit. That is 3 bricks on level 1, up to 16 on level 2 and 64 on level 3 |

A Zap can go on any brick, including a special brick or a Splitter. If the brick it was saved on is gone when the level loads, the Zap is dropped like any other item that no longer fits.

## Rules

- **Counts.** A placeable's unlock node has ranks, and each rank lets you place one more of that item: rank 1 gives 1, rank 2 gives 2, and so on. This is the same rule special bricks use.
- **Saved layout.** Each level keeps its own layout. It is part of the save, and it is already on the board when Setup opens, so a retry doesn't need the items placed again.
- **Loading a layout.** Any saved item that no longer fits is dropped, for example because the level was edited or the item's count went down.
- **Sealing the open side is allowed.** Nothing stops the player from fencing the ball into the board with free-form items so it can't drop.
- **Placed bricks:**
  - pay no coins
  - don't count toward clearing the level
  - do extend the combo when broken
- **Ball speed.** Only the Booster changes a ball's speed. Every other placeable just bounces the ball (see [physics.md](physics.md#ball)).

## Controls

- Drag an item from the tray onto the board to place it.
- Rotate a rotatable item with the scroll wheel or with Q and E while dragging it.
