# Upgrade ideas

Working list for the upgrade web. Four categories; every node in `tuning.gd` `UPGRADES` belongs to one.
Existing nodes are marked **(in)**. Rules the ideas must respect:

- Losing a ball does nothing on its own. The round ends when no ball is left on the stage.
- Paddle hits never touch the combo timer. Only bricks start, extend or pay into a combo.
- Layouts are always saved per level. Not an upgrade.

## Paddle

- **Wider Paddle (in)**: +width per rank.
- **Faster Paddle (in)**: +speed cap.
- **Aim on first shot (in)**: the launch angle follows the mouse instead of firing straight up.
- **Mini paddles**: a small paddle that moves with the main one. Sub-upgrades:
  - count: +1 mini paddle, mirrored left and right, then above.
  - width: mini paddles grow.
  - spacing: how far from the main paddle they sit.
  - placement: choose where each mini paddle lives (ties into Placement).
- **Vertical paddle movement**: the paddle can rise toward the board, a band that widens per rank.
- **Power until first combo**: the ball leaves the paddle fast until the first combo of N. Each rank raises N, so the power lasts longer.
- **Abilities on right click**: an energy bar where 1 energy = 1 second of ability time. Energy refills between rounds, upgrades raise the pool and the refill rate. One ability equipped at a time, more equip slots as an upgrade.
  - *Stick and shoot*: hold to catch the ball on the paddle, release to fire it the way the mouse points.
  - *Grow*: the paddle gets much wider while held.
  - *Slow time*: balls move at half speed while held, the round clock keeps running.
  - *Flipper*: a quick flick that fires every touching ball upward at full speed.
  - *Blast*: a one-shot shockwave from the paddle that breaks the lowest row within reach, costs a chunk of energy.
  - *Magnet paddle*: nearby balls curve toward the paddle while held.
  - *Ghost*: balls pass through placed pieces while held, for clearing a jam.
  - *Recall*: pulls the lowest ball back up to the paddle, costs energy per use rather than per second.

## Round

The cap. In a capped-session upgrade game (Motherload, Digseum, A Game About Digging A Hole) the first and most-bought upgrade widens the cap, so this category sits at or next to the seed node. See the market fit report.

- **Round length (in)**: +seconds per round. Restored from the 2026-11-06 cut; it fits here.
- **Shield floor (in)**: a one-use floor per round that bounces a dropped ball back. Later ranks add uses.
- **Starting ball count (in)**: the round opens with more balls in play.
- **Timer brick** and **Rewind brick** (under Blocks) are the in-round version: fuel cans found mid-dig. Keep them common.

## Placement

### Placeable items

Each item is a `PLACEABLES` row and an `UPGRADES` node of the same id, so +1 owned is the base upgrade for all of them. Special upgrades that only make sense for one item are listed under it.

- **Bumper (in)**: a flat bar the ball bounces off.
  - Paid bumper: each hit pays a little, scaled by the combo.
  - Long bumper: wider bar.
- **Pop bumper (in)**: a round bumper that speeds the ball up, then goes on cooldown. While cooling it acts as a plain bumper.
  - Cooldown: shorter cooldown per hit.
  - Pop power (in): more speed per hit.
  - Pop pay: a hit pays, like a pinball pop.
- **Launcher (in)**: a strip the ball flies through and leaves at fast speed.
  - Hotter launch (in): higher exit speed.
  - Aimed launch: exit follows the strip's rotation exactly, no spread.
- **One-way gate (in)**: ball passes up, bounces down, then goes on cooldown. While cooling it collides with nothing.
  - Cooldown: shorter cooldown per pass.
  - Gate pay: pays each time a ball passes.
  - Combo gate: passing extends the combo timer.
- **Portal (in)**: the ball jumps to the next portal placed.
  - Split portal: the ball exits from every other portal at once, one use per round.
- **Sticky pad (in)**: catches the ball and fires it up.
  - Sticky aim: fires toward the nearest brick.
  - Quick release: shorter hold.
  - Charged release: the longer the hold, the faster the shot.
- **Spawner (in)**: spits out an extra ball every few seconds.
  - Fast spawner (in): shorter interval.
  - Burst: spawns two at once.
  - Warm start: the first ball comes out at round start.
- **Magnet (in)**: bends the ball toward it.
  - Magnet reach (in): larger radius.
  - Magnet pull: stronger pull.
  - Repel: a rotated magnet pushes instead.
- **Splitter (new)**: pass-through piece that forks the ball into two.
  - More splits: forks into three, then four.
  - Cooldown: shorter wait before it can split again.
- **Flipper (new)**: a pinball flipper that flicks on click, placed left or right handed.
  - Flip power: faster flick.
  - Longer flipper: wider reach.
- **Deflector wedge (new)**: a 45 degree wall piece.
- **Ramp (new)**: curves the ball sideways.
  - Ramp speed: the ball keeps more speed through the turn.
- **Toll lamp (new)**: pays each time a ball passes through.
  - Toll rate: pays more per pass.

### Placeable upgrades

Upgrades that apply to placement as a whole or to every piece.

- **Capacity (in)**: +arena capacity.
- **Cheaper pieces (in)**: every piece costs one less capacity, floored at 1.
- **Cheaper kind**: one chosen kind costs less.
- **Lower floor (in)**: pieces may sit closer to the paddle.
- **Tight fit**: smaller gap required between pieces.
- **Free rotate (in)**: finer rotation steps.
- **Piece pay (in)**: every bumper contact pays a flat amount.
- **Piece combo (in)**: a bumper contact extends a running combo window; it never starts one.
- **Shared cooldown**: every cooldown piece cools faster.
- **Overlap**: pieces may overlap bricks, the brick sits behind.
- **Mirror**: place a piece and its mirror image for one capacity extra.

## Blocks

### Unlockable blocks

Each is an unlock node. Rank 1 guarantees one of that block on every board, and each rank after adds one more. These are the icon kinds: bonus effects the player adds to a level. Special upgrades that only make sense for one block are listed under it.

- **Multiball (in)**: spawns an extra ball.
  - Extra split: spawns one more ball.
- **Speedup (in)**: the ball goes faster.
  - Paid speed: pays extra while the ball is fast.
- **Multiplier (in, merges x2 and x3)**: multiplies the total earned by the current combo run.
  - Bigger multiplier: x2, then x3, x4 and on.
  - Stacking: two multipliers in one run multiply instead of replacing.
- **Combo (in)**: pauses the combo window for N seconds. The window does not shrink, but the combo keeps counting and paying.
  - Longer pause: more seconds.
- **Timer (in)**: adds seconds to the round.
  - Longer timer (in): more seconds.
- **Shocker (in, replaces chain)**: a multi-hit brick. Each hit fires chain lightning that damages nearby bricks.
  - More charges: more hits before it breaks.
  - Wider arc: the lightning hits more bricks per hit.
- **Bomb (in)**: breaks everything in a 3x3 and pays for every brick blown up.
  - Bigger bomb (in): wider radius.
- **Bolt (in)**: breaks a line in a random direction: up, down, left, right or diagonal.
  - Twin bolt: fires in two directions.
- **Rewind (new)**: pauses the arena briefly, restores every brick broken so far, and resets the round clock to its start. Balls in flight keep going when play resumes. A ball inside a restored brick must be pushed out or that brick left broken.
- **Mystery (in)**: does its own weird things on break. Ideas: swap every brick with a neighbour, flip the board upside down, turn all balls into one big ball, flip paddle controls for a few seconds, reverse gravity on the balls, turn every plain brick gold for one hit, teleport every ball to a random spot. Shrug.

### Level blocks

Native to level design, never unlocked. A level row places them by chance or by hand to shape the board. Some still have upgrades that soften them, listed under each.

- **Solid (in)**: never breaks, a wall inside the board.
- **Shield (in, replaces multi and multi3)**: a shield of power N takes N hits to strip, then the brick breaks. Levels place shields of different powers.
  - Weak shield: every shield takes one hit less.
- **Cond (in)**: breaks only from a fast ball, pays triple.
  - Slow cond: lower speed threshold.
- **Combo gate (in)**: breaks only at combo N or above, pays triple.
  - Lower gate: opens at a lower combo.
- **Timed (in)**: breaks only while lit.
  - Longer lit: lit for more of its cycle.
- **Sequence (in)**: a 1-2-3 run that breaks in order, the last pays five.
  - Longer sequence: a fourth brick with a bigger payout.
  - Any order: the run pays in any order at a smaller bonus.
- **Jackpot (in)**: one 777 brick per board, pays 20x the level payout.
  - Bigger jackpot: higher multiplier.
- **Slowdown (in)**: the ball goes slower.
  - Wide on slow: paddle grows while a slowdown is active.
- **Magnet brick (new)**: pulls balls toward it until broken.
- **Ghost brick (new)**: the ball passes through it every other second.
- **Gold brick (new)**: pays ten times, but takes five hits.
  - Softer gold: fewer hits.
- **Mirror brick (new)**: bounces the ball back the way it came.
- **Teleport brick (new)**: the ball exits from its twin elsewhere on the board.
- **Regrow brick (new)**: comes back a few seconds after breaking, pays each time.
- **Key and lock (new)**: lock bricks become breakable once the key brick breaks.

### Block upgrades

Upgrades that apply to generation as a whole, to every unlockable block, or to every level block.

- **Payout (in)**: +base payout per brick.
- **Special pay**: every special block pays more.
- **Fewer solids (in)**: lower solid brick rate.
- **Fewer holes (in)**: denser boards.
- **Extra row (in)**: one more board row, capped where the board would reach the placement line.
- **Special spread**: specials are placed apart rather than clumped.
- **Low specials**: specials favour the bottom rows, reached sooner.
- **Reroll**: reroll the board once per round before placement.
- **Twin unlock (in)**: one extra of every unlocked kind.

## Removed

- **Combo Window**: cut on 2026-11-06, fits no category. **More Time** was cut with it and came back as Round length.

## Level design

Levels are a ramp of scale. Each one puts more bricks, more balls and more pieces on screen than the last, and each one asks for a bigger combo than the last to clear in time. The puzzle is never "how do I get in", it is "how do I keep the chain going". All twelve are rows in `tuning.gd` **(in)**; the combo targets are the tuning goal, not something the game enforces. Rules:

- A level row is data only: shape (`grid`, `triangle`, `honey`), size, hole and solid rates, payout, specials, optional `arena` size, `walls`, `skip` columns and `time` scale. A new shape or block is a code change first.
- Every level must fit its arena (`test.gd` checks this), and `arena` never exceeds `Tuning.ARENA`.
- Each level's board, timer and special mix are tuned so that clearing it needs roughly the combo size the previous level taught. Failing still pays, so the retry buys the upgrade that closes the gap.
- Solids are rare and never form walls. They are there to bank the ball into a good run, not to block one.

The ramp, with the combo each level is built around:

- **Open grid (in, level 1, combo 3)**: a small N x M grid, almost no specials. The player learns that two bricks in a row inside the window pay more than two bricks apart.
- **Triangle (in, level 2, combo 5)**: rows narrow going up, so a ball that gets above the bottom row rattles between the slanted edges and breaks several bricks per trip. The shape itself makes the first real combos. Multiball and the first multiplier appear.
- **Full grid (in, level 3, combo 8)**: the full arena and the whole special table. Dense enough that a fast ball chains on its own; the timer is tight enough that one ball cannot clear it. Teaches that the second ball is the engine.
- **Honeycomb (in, level 4, combo 10)**: offset rows with a hole pattern that leaves diagonal corridors. A ball entering a corridor breaks the whole diagonal, so bolt and speedup bricks sit at corridor mouths. First level where a launcher aimed at a corridor is the obvious play.
- **Multiball rain (in, level 5, combo 12)**: a normal grid with a high multiball rate and a lower timer. Three or four balls in play is the expected state, not a bonus. Combo bricks pause the window so the swarm can keep one chain alive.
- **Tall stack (in, level 6, combo 15)**: more rows than any level before. Speedups and bolts are common, so the ball is fast by the time it gets high and the long trip up pays the whole way. Specials are spread evenly for now; "low specials" (Block upgrades) would pack them into the bottom rows.
- **Pinball (in, level 7, combo 20)**: a few solids placed like pinball posts between brick clusters. The ball ricochets cluster to cluster; pop bumpers and magnets between the posts turn every bounce into bricks. The first level where placed pieces should outnumber what the player has, so capacity is the upgrade it sells.
- **Chain field (in, level 8, combo 25)**: shocker and bomb bricks on a tight lattice. One hit sets off a cascade that counts every brick toward the combo. The level that shows the combo counter climbing on its own.
- **Double wide (in, level 9, combo 30)**: a full-width board with the middle column skipped and a solid divider from `walls` in the gap, which the ball flies over. One paddle cannot cover both halves, so the player spawns balls on the far side and lets portals carry the chain across.
- **Storm (in, level 10, combo 40)**: everything that makes action, all at once: high multiball, speedup, bolt and multiplier rates on a dense tall grid. Spawners earn their cost here. The timer is short; the clear comes from one run that never drops.
- **Open sky (in, level 11, combo 50)**: a full-size arena with the board pushed to the top and a large empty middle. Nothing below the bricks but the player's pieces, so the chain between trips is whatever the player built: bumper to launcher to portal to the next cluster. The level that is mostly the player's own machine.
- **Finale (in, level 12, combo 75)**: the biggest board the arena holds, every special kind, the jackpot in the middle, the shortest timer per brick. Clear it in one combo to win. Every ball, piece and multiplier the run has unlocked should be on screen at once.

Variations any row can carry once the blocks exist:

- **Regrowth**: regrow bricks in the bottom rows keep a chain fed between trips up.
- **Gold run**: a few gold bricks in the top row, five hits each, so a swarm of fast balls is the only way to reach them in time.
- **Rewind round**: a rewind brick mid-board puts the whole board back under a running combo. The level that asks for the biggest combo count rather than the biggest clear.
- **Bonus level**: a short round of only icon bricks, no solids, between two hard levels. Pure screen fireworks to show what the next scale looks like.

## Leaning into the loop

Not upgrades. Presentation and scope changes that make the cap, the payout and the retry read the way the comparables do.

- **Time bar**: the HUD timer as a bar whose full length is the upgraded maximum, so each Round length rank visibly lengthens it. The shop node shows before and after.
- **Payout screen**: the result panel headline is the money, counted up with bricks, best combo and multiplier. The reason the round ended ("Ball dropped", "Time's up") is a subline. A lost round is a payout, never a verdict.
- **Best clear percent**: shown per level on level select, so a retry reads as closing a gap.
- **Scope**: two to four hours at $3 to $5. Build Round and one or two placeable kinds first. The abilities bar and most of the Blocks list wait for playtests.
