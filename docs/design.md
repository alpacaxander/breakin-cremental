# BreakIn cremental

**Logline:** A breakout-style incremental game where you set up the board you're about to break. "Sir, We Have an Orc Problem" meets breakout.

*Status: WIP. Every decision below is provisional. Details are in `docs/design/`: `overview.md` (flow, phases, coins, save), `levels.md` (grid, arena size, layouts), `physics.md` (ball and paddle), `placeables.md` (placement kinds and rules) and `upgrades.md` (web, categories). Sound is in `docs/audio.md` and the code structure is in `docs/architecture.md`.*

## Unique selling point

Breakout where the player prepares the board. Before each 20 second round you place items such as bumpers and wall segments on a hand-made level, and brick upgrades add special bricks to it. Then you play the round to cash in. Placement and upgrades make the ball hit more bricks, faster; once unlocked, combos turn that into bigger payouts. Clever placement is the engine-building hook (Balatro-style); paddle skill is the floor.

## Core fantasy

Feel like a high-score engineer: clever setup turns a stubborn wall of bricks into a chain reaction of breaks and an ever-climbing coin counter. Paddle skill gets you by early; placement and upgrades are what make the screen explode late.

## Core loop

1. **Upgrades:** spend coins in the upgrade web, then pick an unlocked level.
2. **Setup:** place unlocked items on the board while the timer is stopped. The level remembers its layout.
3. **Play:** a timed round. Bricks broken and combos are tallied, whether or not the level is cleared.
4. **Summary:** shows the tally, the coins it pays, and whether the level was cleared. Retry the level (step 2), or after a clear go on to the next one, or go back to Upgrades (step 1).

## Key mechanics

- **Arena:** horizontal. The paddle sits on the left edge and moves up and down; the back wall is on the right; the paddle side is open. The board is a grid whose size is set per level: a level picks its row count, there are always 4 columns per row, and the view zooms to fit. The base size is 64 × 16.
- **Bricks:** a brick is 1 column × 2 rows and has HP, the number of hits needed to break it (default 1). Its colour shows the hits it has left and changes with every hit.
- **Levels:** made by hand, one Godot scene each, edited in the editor. There is no procedural generation.
- **Ball:** it moves at a constant speed and only changes direction when it bounces. The angle off the paddle depends on where the ball hits it, as in classic Breakout. Ball and paddle both start slow, and upgrades speed them up. A Shockwave explosion or the Rear Paddle boosts one ball until it next touches the paddle; a Booster's boost lasts the round.
- **Ball drop:** if the last ball gets past the paddle, the round ends immediately. You are still paid for the bricks broken so far but lose the remaining time.
- **Timer:** 20 s base, extended by Arena upgrades and hourglass bricks.
- **Coins:** the only currency. They are calculated from the round's tally of hits, bricks broken (by type) and combos. The formula is an open question; until it is decided every hit on a brick pays 1 coin, broken or not, multiplied by the combo.
- **Combos:** off at the start, then unlocked and upgraded through Arena upgrades. Each brick broken within the combo window extends the combo and raises its multiplier, which multiplies the coins of every brick broken in that combo. The window shrinks as the combo grows, so long combos need dense hits. If the window runs out, the combo resets. Higher ranks widen the window.
- **Placeables:** items placed during Setup. There are three kinds: free-form items that go anywhere clear of bricks and the paddle lane (some can be rotated), placeable bricks that snap to the grid, and brick mods that go on an existing brick. Fencing the ball into the board is allowed.
- **Upgrade web:** grows out from one seed node, paddle speed. Buying a node unlocks its neighbours. A node has one or more ranks, each more expensive than the last. The demo has 28 nodes in three categories, which are mixed across the web so every path out picks up some of each:
  - **Placeables:** unlock the items above (Booster, Wall Segment, Splitter, Zap, Growth, a block that never breaks and adds HP to the bricks near it, and Refresh, a block that never breaks and brings back the broken bricks nearest it when a ball hits it), and nodes that improve them. Each rank lets you place one more.
  - **Bricks:** at level start, some standard bricks are randomly replaced by special bricks that do something when broken: explosive, gold (worth 20 bricks), hourglass (+time) and tough (3 HP). Each rank replaces one more brick, and the bricks are picked again on every attempt. Blast Size and Shockwave improve the explosion.
  - **Arena:** base stats: paddle size, paddle speed, ball speed, round time and combos.

## Progression

- Each level has a target score. A round that reaches it clears the level and unlocks the next one. The round still plays out to the timer, the last ball or the last brick.
- A new level is usually too hard on the first try. Failed attempts still pay out, so upgrades make the retry easier.
- **Every level goes through three stages**, counted in rounds from the first time the player reaches it, with the upgrades they had then:
  1. **Almost unbeatable.** The first rounds pay but don't clear. Failing still buys upgrades.
  2. **Beatable with skill.** A few upgrades in, good aim or good placement clears it; an average player doesn't yet.
  3. **Easy.** With the upgrades that are reasonable for this level, clearing it takes little skill.
- **Each stage is longer on each later level.** The goals, in rounds from the level's first round:

  | Level | Stage 1 ends | Stage 2 ends |
  |---|---|---|
  | 1 | 2 | 6 |
  | 2 | 4 | 12 |
  | 3 | 8 | 25 |

  The whole demo comes to about 40 to 60 rounds. Level 1 is the tutorial, and its stage 1 is a round or two.
- **Rules that come with the stages:**
  - **The first round** pays a cheap first upgrade (the seed node, Paddle Speed) even when it is played badly, and with some skill it also pays for a more useful one.
  - **The first few purchases show the core of the game.** Placement and aim make combos, and combos make the round exciting. So they include Combo and an item that visibly sends the ball into bricks.
  - **The stages overlap.** A level's stage 3 comes at about the same time as the next level's stage 1, and a failed round on the new level pays more than a round on the old one. Otherwise farming the old level beats trying the new one.
  - **"Skill" means aim or placement.** Placement is the game's hook, so good placement alone should be enough to reach a clear in stage 2.
- **How it is measured:** the balance bot's campaign (`tests/run.sh bot campaign`) prints a stages table. Stage 1 ends on the first round its good player clears 10% of tries; stage 2 ends on the first round its clumsy player clears half. It also prints what a round pays on the new level and on the old one when the new level is reached. The goals above are `STAGE_GOALS` in `tests/balance.gd`; change them in both places. The bot's skills differ in their reaction time and aim, and its good player knows the level: it aims at the cells the level marks for it (see [levels.md](design/levels.md#rules)). The bot is a stand-in, and playing the game by hand settles it.
- Any unlocked level can be replayed. There is no deliberate payout curve, but later levels hold more bricks, so they happen to pay more.
- There is one save slot. It holds the coin balance, the upgrade ranks, the highest level unlocked and each level's placed layout.
- There is no prestige or reset layer; that is out of scope for the demo.

## Win / lose

Win by clearing the final level. There is no loss state: a round that times out or ends on a ball drop still pays for the bricks broken, and you retry with upgrades.

## Controls

- In a round: W/S or the up/down arrows move the paddle. With the mouse, the paddle chases the cursor's vertical position at paddle speed.
- Between rounds: the mouse. Click to buy upgrades and drag to place items. The scroll wheel, or Q and E, rotates a rotatable item. Esc, or the back button, goes one step back (see `docs/design/overview.md`).

## Target audience & platform

Steam players who like incremental games, especially bright, flashy, casual ones. Inspirations: Balatro, "Sir, We Have an Orc Problem".

## Art & audio

A modern take on arcade and Atari: everything on screen is as simple as a 2600 game, and the modern part is how it moves and lights up. Sizes, effects, type and UI rules for building real assets are in `docs/art.md`.

- **Shapes:** bricks, paddle and ball are flat, solid rectangles with no textures, outlines or bevels. A plain brick's colour shows its HP; a special brick's colour shows its kind.
- **Palette:** a subset of Endesga 64, with about 11 lit colours on a dark background and one hue per meaning. The ball is always the brightest, clearest object on screen, and effects never use its colour. The colours and their meanings are in `docs/palette.md`.
- **Type:** big, blocky numbers for the timer, coins and combo.
- **Glow:** bloom on the flat colours, so simple shapes still read as bright lights.
- **Effects:** particles on every break, light screen shake, a brief freeze on big hits, ball trails and pop-ups. Effects scale with the combo: the board is quiet early and turns into a light show when a big combo lands.
- **Motion:** smooth 60 fps and eased animation, even though the art looks low-res.
- **CRT:** scanlines and screen curvature as a filter over the whole game. It's on by default and can be turned off in Settings.
- **Audio:** square-wave bleeps whose pitch climbs with each hit in a combo, given modern punch, over one simple placeholder music loop. Every sound is synthesised by a script (see `docs/audio.md`).
- **Accessibility:** a "reduce flashing" toggle in Settings.

## Demo

The demo is the first build. It is the whole loop with its look and sound, on three levels:

- Levels 1–3 from `docs/design/levels.md`.
- Setup → play → summary, with Retry and Upgrades on the summary.
- The ball and paddle from `docs/design/physics.md`.
- The upgrade web, with all three categories: placeables, special bricks and arena stats, including paddle speed and combos. The 28 nodes are listed in `docs/design/upgrades.md`.
- The three kinds of placeables, with layouts saved per level.
- Coins only.
- Art, effects and the CRT filter as described above and in `docs/art.md`. Sound effects and placeholder music from `docs/audio.md`.
- Main menu, Settings (CRT, reduce flashing, music and sound volume) and one save slot.

Out of the demo: more levels, a prestige layer.

The demo exists to test whether placement + combos is fun and whether hand-made levels hit the difficulty target. It is judged by playing it. Where the docs don't give a number, the implementation makes its best guess and keeps the value easy to tune.

## Open questions

The demo gives the first two a first value, set with the balance bot and not yet by a person. Playing the demo is what settles them:

1. **The coin formula.** How the tally of bricks and combos turns into coins. The upgrade costs move with it. First value: the placeholder, 1 coin per hit on a brick, each combo's points times the multiplier that combo reached, with a gold brick counting as 20, plus bonuses for the biggest chain, the longest rally and how the round ended, two of them a share of the level's target score, and an efficiency multiplier (`docs/design/overview.md`, "Coins"). The targets are in `docs/design/levels.md`. The formula is `Coins.total` in `src/sim/coins.gd`; its numbers are `coins_per_brick` and the `_bonus` numbers in `data/balance.tres`, and each special brick's `worth` in `data/kinds/`. The bonuses are set by hand and the bot has not measured them.
2. **Combo numbers.** The window, how it shrinks and how the multiplier steps. First values: the `combo_` numbers in `data/balance.tres`, and the ranks and prices of the Combo node in `data/upgrades/combo.tres`. What they come to is in `docs/design/upgrades.md`, "Open questions".
3. **A ceiling on arena size.** Still open. Very big levels shrink the ball and bricks to a few pixels (see `docs/art.md`, "Arena zoom"). The demo's largest level is 18 rows; the floor is 14 (see `docs/design/levels.md`).
4. **Screens with no mockup.** Answered by building them: the Summary, the main menu and Settings are described in `docs/art.md` as built. Nobody has judged their look yet.

## Risks

1. **Difficulty tuning.** Every hand-made level needs to be too hard on the first try but doable after upgrades. This is the biggest risk, and the demo is built to test it.
2. **Paddle feel.** Breakout lives or dies on ball physics and paddle response, so prototype it early. Because a drop ends the round, a bad-feeling paddle makes every drop feel unfair.
3. **Effects feel.** Flat rectangles keep the art cheap, so the polish has to come from effects, sound and the CRT filter. Making them punchy without hiding the ball is the part most likely to fall flat.
