# BreakIn cremental

**Logline:** A breakout-style incremental game where you set up the board you're about to break. "Sir, We Have an Orc Problem" meets breakout.

*Status: WIP. Every decision below is provisional. Details are in `docs/design/`: `overview.md` (flow, phases, save), `levels.md` (grid, layouts) and `upgrades.md` (web, categories).*

## Unique selling point

Breakout where the player prepares the board. Before each 20 second round you place items such as bumpers and wall segments on a hand-made level, and brick upgrades add special bricks to it. Then you play the round to cash in. Placement and upgrades make the ball hit more bricks, faster; once unlocked, combos turn that into bigger payouts. Clever placement is the engine-building hook (Balatro-style); paddle skill is the floor.

## Core fantasy

Feel like a high-score engineer: clever setup turns a stubborn wall of bricks into a chain reaction of breaks and an ever-climbing coin counter. Paddle skill gets you by early; placement and upgrades are what make the screen explode late.

## Core loop

1. **Upgrades:** spend coins in the upgrade web, then pick an unlocked level.
2. **Setup:** place unlocked items on the board while the timer is stopped.
3. **Play:** a timed round. Every brick broken pays coins, whether or not the level is cleared.
4. **Summary:** shows coins earned, bricks broken, and whether the level was cleared. Back to step 1.

## Key mechanics

- **Arena:** horizontal. The paddle sits on the left edge and moves up and down; the back wall is on the right. The board is a 64 × 16 grid. A brick is 1 column × 2 rows and has HP, the number of hits needed to break it (default 1).
- **Levels:** made by hand, one Godot scene each, edited in the editor. There is no procedural generation.
- **Ball drop:** if the ball gets past the paddle, the round ends immediately. You keep the coins for bricks broken so far but lose the remaining time.
- **Timer:** 20 s base, extended by Arena upgrades and hourglass bricks.
- **Coins:** the only currency. Each brick broken pays 1 coin, multiplied by the combo once combos are unlocked.
- **Combos:** off at the start, then unlocked and upgraded through Arena upgrades. Each brick broken within the combo window extends the combo and raises a multiplier on coins per brick. The window shrinks as the combo grows, so long combos need dense hits. If the window runs out, the combo resets. Higher ranks widen the window.
- **Upgrade web:** grows out from one seed node, paddle speed (the paddle starts slow). Buying a node unlocks its neighbours. A node has one or more ranks, each more expensive than the last. There are three categories:
  - **Placeables:** items you place during setup, for example a bumper, a wall segment or a ball splitter.
  - **Bricks:** at level start, some standard bricks are randomly replaced by special bricks that do something when hit or destroyed, for example explosive, coin ×2 or hourglass (+time).
  - **Arena:** base stats, for example paddle size, paddle speed, round time and combos.

## Progression

- Clearing every brick before time runs out unlocks the next level.
- A new level is usually too hard on the first try. Failed attempts still pay out, so upgrades make the retry easier.
- Any unlocked level can be replayed. There is no deliberate payout curve, but later levels hold more bricks, so they happen to pay more.
- There is one save slot. It holds the coin balance, the upgrade ranks and the highest level unlocked.
- There is no prestige or reset layer; that is out of scope for v1.

## Win / lose

Win by clearing the final level. There is no loss state: a round that times out or ends on a ball drop still pays for the bricks broken, and you retry with upgrades.

## Controls

- In a round: W/S, the up/down arrows, or the mouse's vertical position move the paddle.
- Between rounds: the mouse. Click to buy upgrades and drag to place items.

## Target audience & platform

Steam players who like incremental games, especially bright, flashy, casual ones. Inspirations: Balatro, "Sir, We Have an Orc Problem".

## Art & audio

A modern take on arcade and Atari: everything on screen is as simple as a 2600 game, and the modern part is how it moves and lights up.

- **Shapes:** bricks, paddle and ball are flat, solid rectangles with no textures, outlines or bevels. A plain brick's colour shows its HP; a special brick's colour shows its kind.
- **Palette:** a subset of Endesga 64, with about 11 lit colours on a dark background and one hue per meaning. The ball is always the brightest, clearest object on screen, and effects never use its colour. The colours and their meanings are in `docs/palette.md`.
- **Type:** big, blocky numbers for the timer, coins and combo.
- **Glow:** bloom on the flat colours, so simple shapes still read as bright lights.
- **Effects:** particles on every break, light screen shake, a brief freeze on big hits, ball trails and pop-ups. Effects scale with the combo: the board is quiet early and turns into a light show when a big combo lands.
- **Motion:** smooth 60 fps and eased animation, even though the art looks low-res.
- **CRT:** scanlines and screen curvature as a filter over the whole game. It's on by default and can be turned off in Settings.
- **Audio:** square-wave bleeps whose pitch climbs with each hit in a combo, given modern punch.
- **Accessibility:** a "reduce flashing" toggle in Settings.

## MVP

- 1 paddle and 1 ball, a 20 s timer, and a ball drop ends the round.
- Levels 1–3 from `docs/design/levels.md`, with plain and high HP bricks.
- Coins only.
- About 5 upgrades in a tiny web, including paddle speed and combos.
- 1 placeable.
- Setup → play → summary, with a retry after a failed attempt.

Deliberately out of the MVP: effects, audio, the CRT filter and special bricks. The MVP exists to test whether placement + combos is fun and whether hand-made levels hit the difficulty target.

## Risks

1. **Difficulty tuning.** Every hand-made level needs to be too hard on the first try but doable after upgrades. This is the biggest risk, and the MVP is built to test it.
2. **Paddle feel.** Breakout lives or dies on ball physics and paddle response, so prototype it early. Because a drop ends the round, a bad-feeling paddle makes every drop feel unfair.
3. **Effects feel.** Flat rectangles keep the art cheap, so the polish has to come from effects, sound and the CRT filter. Making them punchy without hiding the ball is the part most likely to fall flat.
