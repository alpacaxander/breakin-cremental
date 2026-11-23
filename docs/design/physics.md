# Ball and paddle

How the ball and paddle behave during Play. Every value is provisional. Where no number is given, the implementation picks a starting value and keeps it easy to tune.

See also: [overview.md](overview.md), [levels.md](levels.md), [placeables.md](placeables.md).

## Ball

- **Constant speed.** The ball never speeds up or slows down on its own. A bounce off the paddle, a brick, a wall or a placeable changes its direction only. Its speed changes only through boosts.
- **Slow at first.** The base speed is low. No upgrade raises it; boosts do, for a while.
- **Boosts.** Three things make one ball faster during play: a Booster adds 20% of the ball's base speed (100 units/s) each time the ball passes through it (plus Booster Speed), a Shockwave explosion raises the ball's current speed by a quarter, and the Rear Paddle adds 20% of base speed. Boosts stack up to 2× the base speed (1000 units/s), which a paddle with Paddle Speed still outruns. When the ball next touches the paddle it drops back to base speed plus whatever Boosters gave it: a Booster's boost lasts the whole round, the others are lost at the paddle. So a ball fenced into the board stays fast.
- **Start position.** Setup opens with the paddle vertically centred and the ball resting on its face. The keys move the paddle during Setup (the mouse is busy placing items), and the ball rides along. After Start the ball stays on the paddle, which the mouse or the keys now move, and the clock and the combo wait. While it waits its aim sways from 45° above level to 45° below and back, once every 3 s (`launch_sway`), slowing at each end like a pendulum, and starting each round at a random point of the swing; a click or Space launches it along the aim of that moment, never flatter than the minimum angle. With the Guide upgrade the sway reaches the steepest legal angle (70°) instead of 45°, passes through level instead of skipping the minimum angle, and a line shows the way (see [upgrades.md](upgrades.md#the-demos-web)).
- **Paddle bounce.** The angle the ball leaves at depends only on where it hits along the paddle, as in classic Breakout: the centre sends it straight back toward the board, and the ends send it up or down at 45°. No steeper: on level 3, where the wall is close, a ball sent off at 60° comes back further along the lane than the paddle can follow. The angle it came in at doesn't matter. The minimum angle applies here too, so the exact centre sends the ball back at the minimum angle below level, not dead level.
- **Placeable bounces.** The ball bounces off the flat faces of a Bumper or a Wall Segment. A Booster is a gate: the ball passes through it untouched in direction and speeds up as its centre crosses the gate's middle line. A Shockwave throws the ball straight away from the centre of the blast.
- **Minimum angles.** After any bounce or throw the direction is nudged so it is never within a small angle of vertical (the ball would bounce between the top and bottom walls and never come back) or of horizontal (it would go back and forth along one line). The launch follows them too, except with the Guide, whose line shows a flat launch before it is made.
- **Collision.** Movement is swept, so a fast ball can't pass through a brick or the paddle. A hit on a brick resolves against exactly one of its edges. There are no corner bounces: a hit on a corner picks one edge.
- **Damage.** Each hit takes 1 HP off the brick.
- **Several balls.** If an item or upgrade adds balls, each one follows the same rules. The round ends when the last ball is lost and no spare is left.
- **Spare balls.** A round can hold balls in reserve: one per rank of Spare Ball (`spare_balls`) at the start, and one more for each Ball Brick broken. Right after a launch (`spare_delay`, 0 s for now), the next spare goes onto the paddle's face, where it rides and sways like the first ball while the others play on and the clock runs; a click or Space launches it. It touches nothing while it waits. When the last ball in play is lost, the next spare comes at once, so the round goes on; a player may keep a spare on the paddle as insurance rather than launch it. Only a ball in play is thrown by a Shockwave. The spares in reserve are drawn as ball squares stacked up the strip behind the paddle (see [art.md](../art.md)).

## Paddle

- The paddle sits on the left edge, moves only up and down, and stays inside the arena.
- **Slow at first.** Paddle Speed upgrades raise its speed.
- **Keys** (W/S or the up/down arrows) move it at paddle speed.
- **Mouse:** the paddle chases the cursor's vertical position at paddle speed. It doesn't jump to the cursor, so Paddle Speed matters with either control.

## Arena edges

- The top wall, bottom wall and back wall bounce the ball.
- The paddle side is open. A ball that gets past the paddle and leaves the arena is lost.
