# Ball and paddle

How the ball and paddle behave during Play. Every value is provisional. Where no number is given, the implementation picks a starting value and keeps it easy to tune.

See also: [overview.md](overview.md), [levels.md](levels.md), [placeables.md](placeables.md).

## Ball

- **Constant speed.** The ball never speeds up or slows down on its own. A bounce off the paddle, a brick, a wall or a placeable changes its direction only. Its speed changes only through an upgrade or a placeable whose effect says so.
- **Slow at first.** The base speed is low, and upgrades raise it.
- **Start position.** During Setup the paddle is vertically centred and the ball sits a little to the right of it, also vertically centred. On Start the ball travels straight left into the paddle, so the player's first touch sets the first angle.
- **Paddle bounce.** The angle the ball leaves at depends only on where it hits along the paddle, as in classic Breakout: the centre sends it straight back toward the board, and the ends send it steeply up or down. The angle it came in at doesn't matter.
- **Minimum angles.** After any bounce the direction is nudged so it is never within a small angle of vertical (the ball would bounce between the top and bottom walls and never come back) or of horizontal (it would go back and forth along one line). The launch is exempt, because it is exactly horizontal.
- **Collision.** Movement is swept, so a fast ball can't pass through a brick or the paddle. A hit on a brick resolves against exactly one of its edges. There are no corner bounces: a hit on a corner picks one edge.
- **Damage.** Each hit takes 1 HP off the brick.
- **Several balls.** If an item or upgrade adds balls, each one follows the same rules. The round ends when the last ball is lost.

## Paddle

- The paddle sits on the left edge, moves only up and down, and stays inside the arena.
- **Slow at first.** Paddle Speed upgrades raise its speed.
- **Keys** (W/S or the up/down arrows) move it at paddle speed.
- **Mouse:** the paddle chases the cursor's vertical position at paddle speed. It doesn't jump to the cursor, so Paddle Speed matters with either control.

## Arena edges

- The top wall, bottom wall and back wall bounce the ball.
- The paddle side is open. A ball that gets past the paddle and leaves the arena is lost.
