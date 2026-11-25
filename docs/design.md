# BreakIn cremental

**Logline:** A breakout-style incremental game where you set up the board you're about to break. "Sir, We Have an Orc Problem" meets breakout.

*Status: WIP. Every decision below is provisional. Details are in `docs/design/`: `overview.md` (flow, phases, coins, save), `levels.md` (grid, arena size, layouts), `physics.md` (ball and paddle), `placeables.md` (placement kinds and rules) and `upgrades.md` (web, categories). Sound is in `docs/audio.md` and the code structure is in `docs/architecture.md`.*

## Unique selling point

Breakout where the player prepares the board. Before each 20 second round you place items such as boosters and wall segments on a hand-made level, and brick upgrades add special bricks to it. Power Bricks among them drop charges for the paddle to catch and fire as balls that zap or blast. Then you play the round to cash in. Placement and upgrades make the ball hit more bricks, faster; once unlocked, combos turn that into bigger payouts. Clever placement is the engine-building hook (Balatro-style); paddle skill is the floor.

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
- **Ball:** it moves at a constant speed and only changes direction when it bounces. The angle off the paddle depends on where the ball hits it, as in classic Breakout. Ball and paddle both start slow, and upgrades speed them up. A Shockwave blast or the Rear Paddle boosts one ball until it next touches the paddle; a Booster's boost lasts the round. Multiball follows the round's first launch with more balls down the same line.
- **Losing the ball:** if the last ball gets past the paddle, no charge is held, no drop is still falling and the opening volley has no ball still to come, the round ends immediately (charges: [physics.md](design/physics.md#ball)). You are still paid for the bricks broken so far but lose the remaining time.
- **Charges and abilities:** a Power Brick that breaks makes a drop that moves toward the paddle side. The paddle catches it as a charge, a ball in reserve, which a click or Space fires as a new ball carrying the selected ability, Zap or Blast. On its first hit on a level brick the ability goes off there, and then it plays on as an ordinary ball. A held charge keeps the round alive when the last ball in play is lost.
- **Timer:** 20 s base, extended by Arena upgrades and hourglass bricks.
- **Coins:** the only currency. They are calculated from the round's tally of hits, bricks broken (by type) and combos. The formula is an open question; until it is decided every hit on a brick pays 1 coin, broken or not, multiplied by the combo.
- **Combos:** off at the start, then unlocked and upgraded through Arena upgrades. Each hit on a level brick within the combo window, whether it breaks the brick or not, extends the combo and raises its multiplier, which multiplies the coins of every hit in that combo. The window shrinks as the combo grows, so long combos need dense hits. If the window runs out, the combo resets. Higher ranks widen the window.
- **Placeables:** items placed during Setup. There are three kinds: free-form items that go anywhere clear of bricks and the paddle lane (some can be rotated), placeable bricks that snap to the grid, and areas laid over the bricks. Fencing the ball into the board is allowed.
- **Upgrade web:** grows out from one seed node, paddle speed. Buying a node unlocks its neighbours. An upgrade has one or more ranks, each more expensive than the last, and each rank is a node of its own, a copy of the upgrade. The demo has 31 upgrades on 70 nodes in four categories, which are mixed across the web so every path out picks up some of each:
  - **Placeables:** unlock the items above (Booster, Wall Segment, Splitter and Growth, an area laid over the bricks that adds HP to them at the start of a round; Refresh, a block that brings back broken bricks, is in the code but no node unlocks it), and nodes that improve them. Each rank lets you place one more.
  - **Bricks:** at level start, some standard bricks are randomly replaced by special bricks that do something when broken: gold (worth 20 bricks), hourglass (+time) and tough (3 HP). Each rank replaces one more brick, and the bricks are picked again on every attempt.
  - **Abilities:** the Power Brick, a special brick rolled the same way that drops a charge when it breaks, and the two abilities a charge can fire: Zap, which hits the rest of the brick's row, and Blast, an explosion around the brick. Zap Range, Zap Damage, Blast Size, Blast Damage and Shockwave improve them.
  - **Arena:** base stats: paddle size, paddle speed, ball speed, round time and combos, Multiball, and Overgrowth, which makes every level brick that breaks come back a few seconds later as a plain 1 HP brick.

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
  | 2 | 4 | 10 |
  | 3 | 6 | 16 |

  The whole demo comes to about 30 rounds, about 35 minutes for a first-time player once setup, the Summary and the upgrade screen are counted (a round takes about a minute and a quarter in all, 15 to 20 s of it play). Level 1 is the tutorial, and its stage 1 is a round or two.
- **Rules that come with the stages:**
  - **The first round** pays a cheap first upgrade (the seed node, Paddle Speed) even when it is played badly, and with some skill it also pays for a more useful one.
  - **The first few purchases show the core of the game.** Placement and aim make combos, and combos make the round exciting. So they include Combo and an item that visibly sends the ball into bricks.
  - **The stages overlap.** A level's stage 3 comes at about the same time as the next level's stage 1, and a failed round on the new level pays more than a round on the old one. Otherwise farming the old level beats trying the new one.
  - **"Skill" means aim or placement.** Placement is the game's hook, so good placement alone should be enough to reach a clear in stage 2.
- **How it is measured:** the balance bot's campaign (`tests/run.sh bot campaign`) prints a stages table. Stage 1 ends on the first round its good player clears 10% of tries; stage 2 ends on the first round its clumsy player clears half. It also prints what a round pays on the new level and on the old one when the new level is reached. The goals above are `STAGE_GOALS` in `tests/balance.gd`; change them in both places. The bot's skills differ in their reaction time and aim, and its good player knows the level: it aims at the cells the level marks for it (see [levels.md](design/levels.md#rules)). The bot is a stand-in, and playing the game by hand settles it.
- **Where it stands:** retuned with the bot after the ability system, on the targets 28, 384 and 2048. The bot now catches drops and fires charges: by default it holds a charge until no other ball is in play or the round has 3 s left, and fires it with the first ability unlocked (Zap). The campaigns were run once per skill on the layout search, so each figure below is one run and moves by a round or two between runs. In the average player's campaign level 1's stages end on its 3rd and 5th rounds (goals 2 and 6), level 2's on its 2nd and 10th (4 and 10) and level 3's on its 4th and 21st (6 and 16). The average player clears the levels on rounds 3, 9 and 19, the good one on 3, 14 and 18 and the clumsy one on 15, 30 and 37, against the goal of about 30. Level 2's stage 1 ends early for every skill (its 1st to 3rd round): a good player clears it now and then on arrival, and a higher target would push its stage 2 further past 10. Level 3 is still a lottery: its rounds pay from tens of coins to thousands, so its stage 1 ends on its 1st to 4th round for every skill (goal 6) and its stage 2 on its 13th to 21st (goal 16), and a higher target would delay both. On arrival a round on level 3 pays less than one on level 2 (153 against 196 for the average player), against the rule above. What would change that has not been measured (see [upgrades.md](design/upgrades.md#the-demos-web), "What the bot measured").
- Any unlocked level can be replayed. There is no deliberate payout curve, but later levels hold more bricks, so they happen to pay more.
- There is one save slot. It holds the coin balance, the upgrade ranks and the web nodes bought, the highest level unlocked and each level's placed layout.
- There is no prestige or reset layer; that is out of scope for the demo.

## Win / lose

Win by clearing the final level. There is no loss state: a round that times out or ends on a lost ball still pays for the bricks broken, and you retry with upgrades.

## Controls

- In a round: W/S or the up/down arrows move the paddle. With the mouse, the paddle chases the cursor's vertical position at paddle speed. A left click or Space launches the ball waiting on the paddle, the first ball or a charge. The scroll wheel, or Q and E, cycles the ability a charge fires with.
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
- The upgrade web, with all four categories: placeables, special bricks, abilities and arena stats, including paddle speed and combos. The 31 upgrades and the 70-node web are in `docs/design/upgrades.md`.
- The three kinds of placeables, with layouts saved per level.
- Power Bricks, drops and charges, and the two abilities, Zap and Blast.
- Coins only.
- Art, effects and the CRT filter as described above and in `docs/art.md`. Sound effects and placeholder music from `docs/audio.md`.
- Main menu, Settings (CRT, reduce flashing, music and sound volume) and one save slot.

Out of the demo: more levels, a prestige layer.

The demo exists to test whether placement + combos is fun and whether hand-made levels hit the difficulty target. It is judged by playing it. Where the docs don't give a number, the implementation makes its best guess and keeps the value easy to tune.

## Open questions

The demo gives the first two a first value, set with the balance bot and not yet by a person. Playing the demo is what settles them:

1. **The coin formula.** How the tally of bricks and combos turns into coins. The upgrade costs move with it. First value: the placeholder, 1 coin per hit on a brick, each combo's points times the multiplier that combo reached, with a gold brick counting as 20, and no end-of-round bonuses (`docs/design/overview.md`, "Coins"). The targets are in `docs/design/levels.md`. The formula is `Coins.total` in `src/sim/coins.gd`; its numbers are `coins_per_brick` and the combo numbers in `data/balance.tres`, and each special brick's `worth` in `data/kinds/`.
2. **Combo numbers.** The window, how it shrinks and how the multiplier steps. First values: the `combo_` numbers in `data/balance.tres`, and the ranks and prices of the Combo node in `data/upgrades/combo.tres`. What they come to is in `docs/design/upgrades.md`, "Open questions".
3. **A ceiling on arena size.** Still open. Very big levels shrink the ball and bricks to a few pixels (see `docs/art.md`, "Arena zoom"). The demo's largest level is 18 rows; the floor is 14 (see `docs/design/levels.md`).
4. **Screens with no mockup.** Answered by building them: the Summary, the main menu and Settings are described in `docs/art.md` as built. Nobody has judged their look yet.

## Risks

1. **Difficulty tuning.** Every hand-made level needs to be too hard on the first try but doable after upgrades. This is the biggest risk, and the demo is built to test it.
2. **Paddle feel.** Breakout lives or dies on ball physics and paddle response, so prototype it early. Because losing the last ball ends the round, a bad-feeling paddle makes every lost ball feel unfair.
3. **Effects feel.** Flat rectangles keep the art cheap, so the polish has to come from effects, sound and the CRT filter. Making them punchy without hiding the ball is the part most likely to fall flat.
