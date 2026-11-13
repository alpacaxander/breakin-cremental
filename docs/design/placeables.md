# Placeables

Items the player places on the board during Setup. They are unlocked in the Placeables category of the [upgrade web](upgrades.md). Every value is provisional.

See also: [overview.md](overview.md#level-phases), [levels.md](levels.md), [physics.md](physics.md).

## Kinds

| Kind | Where it can go | Examples (placeholders) |
|---|---|---|
| **Free-form** | Anywhere in the arena where it doesn't overlap a brick, another placed item or the paddle lane. It doesn't snap to the grid. Some free-form items can be rotated | Bumper, Wall segment (rotatable) |
| **Placeable brick** | Snaps to the brick grid, on empty brick cells only | To be decided |
| **Brick mod** | Only on a brick that is already on the board. It gives that one brick an effect | To be decided |

The paddle lane is the strip between the open side and the first grid column (see [art.md](../art.md#level-screen)).

## Rules

- **Counts.** A placeable's unlock node has ranks, and each rank lets you place one more of that item: rank 1 gives 1, rank 2 gives 2, and so on. This is the same rule special bricks use.
- **Saved layout.** Each level keeps its own layout. It is part of the save, and it is already on the board when Setup opens, so a retry doesn't need the items placed again.
- **Loading a layout.** Any saved item that no longer fits is dropped, for example because the level was edited or the item's count went down.
- **Sealing the open side is allowed.** Nothing stops the player from fencing the ball into the board with free-form items so it can't drop.
- **Placed bricks:**
  - pay no coins
  - don't count toward clearing the level
  - do extend the combo when broken
- **Ball speed.** A placeable can change a ball's speed if its effect says so. Otherwise it only bounces the ball (see [physics.md](physics.md#ball)).

## Controls

- Drag an item from the tray onto the board to place it.
- Rotate a rotatable item with the scroll wheel or with Q and E while dragging it.

## Open questions

- The list of placeables in the demo and what each one does. This is decided together with the initial upgrades (see [upgrades.md](upgrades.md#open-questions)).
- How a brick mod is shown on its brick.
