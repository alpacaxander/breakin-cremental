# BreakIn cremental

**Logline:** A breakout-style incremental game where you build the board you're about to break. "Sir, We Have an Orc Problem" meets breakout.

*Status: WIP. Every decision below is provisional.*

## Unique selling point

Breakout where the player shapes the board. Between rounds you place special bricks on a generated arena, then play the round to cash in. Placed bricks are tools that make the ball hit more bricks, faster; combos follow from that. Placement cleverness is the engine-building hook (Balatro-style); paddle skill is the floor; generated boards are the variance.

## Core fantasy

Feel like a jackpot engineer: clever brick placement turns a chaotic arena into bigger and bigger payouts. Paddle skill matters early and gets you by; placement and upgrades are what make the screen explode late.

## Core loop

1. Play a timed round. Every brick broken pays currency, whether or not the round is cleared.
2. Spend currency on upgrades (permanent) or placeable bricks.
3. Place bricks on the next generated board to set up combos.
4. Play the next round.

## Key mechanics

- **Base layer:** horizontal paddle bounces a ball around the arena and breaks bricks.
- **Ball drop:** if the ball passes the paddle, the round ends early. You keep currency for bricks broken so far but forfeit the remaining time. Paddle skill matters because dropping costs you the rest of the round.
- **Timer:** fixed per level, scales with board size, extendable via upgrades.
- **Combos:** each brick broken within the combo window extends the combo and ramps a multiplier on currency per brick. The window shrinks as the combo grows, so long combos demand dense hits. If the window lapses, the combo hard-resets. Combos are the central reward; placed bricks make them likelier, not guaranteed.
- **Generated arena:** each level has a semi-custom layout template. Default is an N x M grid of bricks that grows each level; other levels use clusters, triangles, and similar shapes. Which brick types appear depends on the level and what's been unlocked. Brick types:
  - Colored bricks that pay different currencies.
  - Icon bricks with effects on break: spawn balls, speed up balls, multiply payout, etc.
  - Unbreakable bricks.
  - Multi-hit bricks (health > 1).
  - Conditional bricks: only break at a certain ball speed or angle.
- **Placeable bricks:** the arena has a capacity (upgradable). Each brick type has a capacity cost, e.g. Brick A uses 3. Unlocking a brick type in the upgrade web adds one copy to your inventory; unlocking it again adds another, so unlocking Brick A three times lets you place up to three. Before each round you place any inventory bricks you like, as long as the total capacity cost fits. Placement is freeform (not cell-snapped), free, and redone each round. Most brick types cannot overlap other bricks; a few can. Examples: one-way pass-through, unbreakable, magnetic, ball-spawning-over-time.
- **Upgrade web:** starts from one seed node. A node is visible only if a connected node is unlocked. Each node has a cost and 1-5 ranks with increasing cost per rank. Early nodes are cheap and high-impact so a new player gets past the drop-and-retry phase quickly.
- **Paddle upgrades:** size, speed, small sibling paddles, charge multiplier, vertical movement unlock.
- **Currencies:** keep to 2-3 colors total. Each extra currency is a UI tab and a balance axis.

## Progression

- Clearing all breakable bricks within the timer advances to the next level (a level row's `unlock` can ask for something else: level 2 opens on a combo of 10). Cleared levels produce bigger boards with more combo potential.
- New brick colors (= new currencies) only generate after certain levels, which gates the upgrades that cost them.
- A new level is typically too hard on the first try; failed attempts still pay out, so upgrades make the retry easier.
- Replaying earlier levels is allowed, but earlier levels pay less (no new colors, smaller boards), so grinding is possible but slow.
- Level count: twelve, a ramp of scale and combo size (`docs/ideas.md`, Level design). No prestige/reset layer; out of scope for v1.

## Win / lose

Win by clearing the final level. There is no loss state: a round that times out or ends on a ball drop still pays out for bricks broken, and you retry with upgrades.

## Controls

- In round: arrows / WASD or mouse. Paddle moves toward the mouse or in the arrow direction. Once vertical movement is unlocked, mouse control becomes 2D.
- Between rounds: click and drag UI (upgrade web, brick placement).

## Target audience & platform

Steam players who like incremental games, especially bright, flashy, casual ones. Inspirations: Balatro, "Sir, We Have an Orc Problem".

## Art & audio

Casino flash and pop. Every milestone should feel like a bigger jackpot than the last.

## MVP

- 1 paddle, 1 ball, timer, ball drop ends round
- Generated board with 2 brick types (plain, unbreakable)
- 1 currency
- ~5 upgrades in a tiny web
- 1 placeable brick type, small arena capacity
- 2 levels, retry on fail
- Combo multiplier

Deliberately out of MVP: animations, audio, extra currencies, icon/conditional bricks. The MVP exists to test whether placement + combos is fun and whether board generation can be tuned.

## Risks

1. **Tuning generated boards.** "Too hard first try, doable after upgrades" is a balance target that procedural generation makes hard to hit consistently. Biggest risk; the MVP is built to probe it.
2. **Late-game screen density.** The overwhelming-jackpot feel wants hundreds of bricks and effects on screen. Nice to have, not required, and a performance concern.
3. **Art, audio, animation feel.** Simple scope, but nailing the casino feel is the part most likely to fall flat.
4. **Paddle feel.** Breakout lives or dies on ball physics and paddle response. Prototype early. Ball drop ending the round raises the stakes here: if the paddle feels bad, every drop feels unfair.
