# Ball and paddle

How the ball and paddle behave during Play. Every value is provisional. Where no number is given, the implementation picks a starting value and keeps it easy to tune.

See also: [overview.md](overview.md), [levels.md](levels.md), [placeables.md](placeables.md).

## Ball

- **Constant speed.** The ball never speeds up or slows down on its own. A bounce off the paddle, a brick, a wall or a placeable changes its direction only. Its speed changes only through the Ball Speed upgrade and through boosts.
- **Slow at first.** The base speed is low, and the Ball Speed upgrade raises it.
- **Boosts.** Two things make one ball faster during play: a Booster adds 25% of the ball's base speed each time the ball hits it, and a Shockwave explosion doubles the ball's current speed. Boosts stack up to 3× the base speed. A boosted ball keeps its speed until it next touches the paddle, where it drops back to base speed. So a fast ball is a risk on its way back, and a ball fenced into the board stays fast.
- **Start position.** During Setup the paddle is vertically centred and the ball sits a little to the right of it, also vertically centred. On Start the ball travels straight left into the paddle, so the player's first touch sets the first angle.
- **Paddle bounce.** The angle the ball leaves at depends only on where it hits along the paddle, as in classic Breakout: the centre sends it straight back toward the board, and the ends send it steeply up or down. The angle it came in at doesn't matter. The minimum angle applies here too, so the exact centre sends the ball back at the minimum angle below level, not dead level. The first launch always lands on the centre unless the paddle has moved.
- **Placeable bounces.** The ball bounces off the flat faces of a Bumper or a Wall Segment. Off a Booster, which is round, it bounces off the point where it touches. A Shockwave throws the ball straight away from the centre of the blast.
- **Minimum angles.** After any bounce or throw the direction is nudged so it is never within a small angle of vertical (the ball would bounce between the top and bottom walls and never come back) or of horizontal (it would go back and forth along one line). The launch is exempt, because it is exactly horizontal.
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
