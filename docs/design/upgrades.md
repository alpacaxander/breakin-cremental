# Upgrades

See also: [placeables.md](placeables.md), [physics.md](physics.md), [overview.md](overview.md).

## Rules

- Upgrades form a **web** that grows out from one seed node, **Paddle Speed** (the paddle starts slow). Each node unlocks once a connected node has been bought. Until then the upgrade screen hides it: the web shows only nodes whose ranks need nothing but coins.
- An upgrade can have **one or more ranks**, each more expensive than the last.
- **Categories are mixed across the web.** A category says what kind of thing a node is, not where it sits. Every path out from the seed should pass through different categories, so the player picks up a mix as they go.
- **A node that needs another node branches off it.** Zap and Blast only do something once there are charges to fire, so both connect directly to Power Brick, and Blast Size, Blast Damage and Shockwave only once there are blasts, so they hang off Blast.
- **Editable in Godot:** the web is laid out in its own scene, which sets where each node sits and which nodes it connects to. Each upgrade is its own resource file (see [architecture.md](../architecture.md#stats)), which sets:
  - its cost and growth
  - its maximum rank
  - its effect

## Categories

| Category | What it does | Nodes in the demo |
|---|---|---|
| **Placeables** | Items you unlock and then place in the arena during the Setup phase to help yourself. The three kinds and their rules are in [placeables.md](placeables.md) | Booster, Booster Speed, Splitter, Splitter Respawn, Splitter Health, Wall Segment, Growth, Growth Reach, Growth Pulses |
| **Bricks** | When a level starts, some standard bricks are randomly replaced by special bricks that do something when broken. Some nodes improve a special brick instead | Gold Brick, Tough Brick, Hourglass Brick, Hourglass Time, Hourglass Freeze |
| **Abilities** | The Power Brick, a special brick whose drop the paddle catches as a charge, and the abilities a charge fires a ball with, with the nodes that improve them (see "Charges and abilities" below). The Power Brick follows the special-brick rules | Power Brick, Zap, Zap Range, Zap Damage, Blast, Blast Size, Blast Damage, Shockwave |
| **Arena** | Changes the arena's base stats and rules | Paddle Speed, Paddle Size, Combo, Combo Window, Rear Paddle, Overgrowth, Guide, Guide Bounces, Multiball |

## Counts come from ranks

Placeables and special bricks share one rule: the node that unlocks the item has ranks, and each rank adds one.

- **Placeables:** rank N lets you place N of that item.
- **Special bricks:** rank N replaces N random standard bricks with that brick type when the level starts. The bricks are picked again on every attempt, including a retry. The Power Brick is one, though its node is in Abilities.

A count is the same on every level, so 2 Power Bricks matter far more among level 1's 28 bricks than among level 3's 256.

## Speed

The ball and the paddle both start slow, and upgrades speed them up. The ball's speed is constant during play, except for boosts from the Booster and from Shockwave (see [physics.md](physics.md#ball)).

## The demo's web

Bracket shape shows the category: `( )` Arena, `[ ]` Placeables, `{ }` Bricks, `< >` Abilities. Rows run top to bottom, as on screen.

```
<  Zap Range   >──<  Zap Damage  >   ( Rear Paddle  )
        │                                    │
<     Zap      >   [Booster Speed ]───[   Booster    ]───(    Guide     )───(Guide Bounces )
        │                                    │
< Power Brick  >───( Paddle Size  )───(PADDLE SPEED  )───{  Hourglass   }───{Hourglass Time}
        │                                    │                                     │
<    Blast     >   [   Splitter   ]───(    Combo     )───( Combo Window )   {Hourglass Frz.}
        │                  │                 │
<  Blast Size  >   [Splitter Resp.]   {  Gold Brick  }───[ Wall Segment ]───(  Multiball   )
        │                  │                 │
< Blast Damage >   [SplitterHealth]   { Tough Brick  }───[    Growth    ]───[ Growth Reach ]
        │                                                       │
<  Shockwave   >                                         [Growth Pulses ]───(  Overgrowth  )
```

- Only the drawn lines are connections. The scene `src/hub/web.tscn` is the source; this drawing follows it.
- The Abilities fill the first column: Power Brick hangs off Paddle Size, where Explosive Brick did, Zap and Blast hang off it, and each ability's improvements run in a line away from it. Rear Paddle sits over the Booster, which it links to, and Multiball takes Spare Ball's place off the Wall Segment.
- The web is 5 columns × 7 rows, taller than the view at zoom 1: the bottom two rows (Blast Damage, Splitter Health, Tough Brick, Growth, Growth Reach; Shockwave, Growth Pulses, Overgrowth) are reached by panning, or the view scrolls to a node when it is selected.

A price is the first price times the growth for every rank owned, rounded to a whole coin. The ranks and prices are first values, set with the balance bot against the three stages of [design.md](../design.md#progression). The ability system's nodes first took the prices of the nodes they replaced; the retune after it made Combo, the Booster, Paddle Size, Power Brick, Zap and Blast cheaper, so that Combo and a Booster come on the second round and abilities on level 1 or early on level 2, and left the rest alone.

**The measurements on this page are of two times.** "What the bot measured", the payouts in the bands bullet, the first round and the combo sizes under "Open questions" were taken after the ability system, with the bot catching drops and firing charges. The bullets on Spare Ball, Overgrowth's contract round and sealing the paddle side were taken before it and say so.

| Node | Category | Each rank | Ranks | Growth | Prices |
|---|---|---|---|---|---|
| Paddle Speed | Arena | +100% paddle speed | 2 | ×30 | 5, 150 |
| Paddle Size | Arena | +40% paddle length | 5 | ×4 | 20, 80, 320, 1,280, 5,120 |
| Combo | Arena | Turns combos on | 1 |  | 4 |
| Combo Window | Arena | The combo's window is 1 s longer | 2 | ×15 | 40, 600 |
| Rear Paddle | Arena | The back wall's stretch opposite the paddle boosts a ball by 20% of base speed | 2 | ×8 | 300, 2,400 |
| Overgrowth | Arena | Every level brick that breaks comes back 8 s of play later, a plain 1 HP brick (see below) | 1 |  | 8,000 |
| Guide | Arena | +250 units of guide line, and the launch sways to the steepest legal angle (see below) | 4 | ×4 | 30, 120, 480, 1,920 |
| Guide Bounces | Arena | The guide line bounces | 1 |  | 250 |
| Multiball | Arena | One more ball in the opening volley, right behind the first (see below) | 3 | ×5 | 300, 1,500, 7,500 |
| Booster | Placeables | One Booster | 2 | ×20 | 5, 100 |
| Booster Speed | Placeables | A Booster adds 20% of base speed more | 2 | ×6 | 500, 3,000 |
| Splitter | Placeables | One Splitter | 5 | ×3 | 80, 240, 720, 2,160, 6,480 |
| Splitter Respawn | Placeables | A broken Splitter comes back 6 s of play later; each rank after the first takes 2 s off | 3 | ×2.5 | 2,000, 5,000, 12,500 |
| Splitter Health | Placeables | A Splitter takes one more hit, and splits the ball on each | 2 | ×6 | 500, 3,000 |
| Wall Segment | Placeables | One Wall Segment | 2 | ×10 | 40, 400 |
| Growth | Placeables | One Growth area | 2 | ×4.5 | 100, 450 |
| Growth Reach | Placeables | Growth areas reach one square further | 2 | ×10 | 300, 3,000 |
| Growth Pulses | Placeables | Growth pulses once more | 2 | ×6 | 1,000, 6,000 |
| Gold Brick | Bricks | One gold brick | 3 | ×6 | 30, 180, 1,080 |
| Tough Brick | Bricks | One tough brick | 3 | ×6 | 20, 120, 720 |
| Hourglass Brick | Bricks | One hourglass brick | 2 | ×100 | 25, 2,500 |
| Hourglass Time | Bricks | An hourglass brick adds 5 s more | 2 | ×5 | 1,200, 6,000 |
| Hourglass Freeze | Bricks | Breaking an hourglass brick holds the combo's window for 1 s | 2 | ×5 | 800, 4,000 |
| Power Brick | Abilities | One Power Brick, whose drop the paddle catches as a charge (see below) | 4 | ×4 | 25, 100, 400, 1,600 |
| Zap | Abilities | Unlocks Zap: a charged ball hits the rest of its brick's row | 1 |  | 60 |
| Zap Range | Abilities | A Zap reaches 2 more bricks each way (8 by default) | 2 | ×5 | 400, 2,000 |
| Zap Damage | Abilities | A Zap hits each brick once more | 2 | ×5 | 800, 4,000 |
| Blast | Abilities | Unlocks Blast: a charged ball sets off a blast at the brick it hits | 1 |  | 60 |
| Blast Size | Abilities | Blasts reach one square further | 2 | ×20 | 150, 3,000 |
| Blast Damage | Abilities | Blasts hit each brick once more | 2 | ×10 | 300, 3,000 |
| Shockwave | Abilities | Blasts throw balls | 1 |  | 600 |

- That is 31 nodes and 70 purchases, 111,164 coins in all (115,474 before the retune after the ability system, and 73 purchases and 128,324 coins before the ability system). The Bumper and Refresh are still kinds in the code, with their stats (`refresh_count`, `refresh_size`), but no node unlocks them. Refresh and Refresh Size were taken out of the web (3 ranks from 150 ×4.5, and 2 from 400 ×10). Blast Damage's id is still `explosion_damage`.
- **Charges and abilities.** A Power Brick makes a **drop** when it breaks, however it broke (a ball, a blast or a Zap). The drop moves straight toward the paddle side at 250 units/s (`drop_speed`), through bricks, placed items and balls: nothing stops it. If it touches the solid part of the paddle it is caught and the paddle gains a **charge**; if it passes the open side it is gone. A charge is a ball in reserve (see [physics.md](physics.md#ball)): it goes onto the paddle's face at once when no ball waits there, and a click or Space fires it as a new ball carrying the selected ability. On that ball's first hit on a level brick the brick takes the hit as usual, then the charge is spent and the ability goes off at the brick's cell (see [What the abilities do](#what-the-abilities-do)); after that it plays on as an ordinary ball. A hit on a placed brick, such as a Splitter, does not spend it. Zap and Blast are each unlocked by their node; with neither, a charge fires a plain ball. During Play the wheel, or Q and E, cycles the selection through the unlocked abilities, Zap first. The level screen keeps the selection from one round to the next while it is open, and the save does not. A round starts with no charges and keeps every one it catches, so it can hold at most one per rank of Power Brick. **A held charge keeps the round alive:** when the last ball in play is lost the charge on the paddle is next, and the round also waits for a drop still falling. Power Brick's first rank is in level 1's band, and Zap and Blast are in level 2's.
- **Multiball** replaces Spare Ball. The round's first launch is followed by one more ball for each rank, 0.15 s apart (`multiball_gap`), each from the point the first one left and the same way, so they go down one line and each can go through the gap the one before made. It hangs off the Wall Segment, as Spare Ball did, and its first rank is in level 2's band.
- **Before the ability system** Spare Ball put a ball in reserve for every round, one per rank, and a Ball Brick (off Splitter Respawn, in level 3's band, 2 ranks from 1,800 ×4) added one when it broke. A spare went onto the paddle right after the last launch (`spare_delay`, 0 s), to be launched with a click while the others played, or kept there until the last ball in play was lost. The bot kept a spare on the paddle until no other ball was left (`spares=hold`), or launched it at once (`spares=launch`). Measured on `tests/layouts/found.json` (not the layout search, so not comparable with the campaigns below), against the same campaigns without the two nodes: with every rank, level 3 lost its last ball in 10 to 35% of rounds instead of 85 to 90%, and a round paid 90,000 to 140,000 instead of 14,000 to 38,000; level 2 hardly moved, or cleared every round with `spares=launch`. In the campaigns the first Spare Ball was bought on level 3 (rounds 27 to 55) and the clears moved little: level 3 on round 72, 42 and 40 (clumsy, average, good) against 71, 48 and 40. So it ended level 3's lottery once owned, which is what the level needed, and made a maxed level 3 a farm. Held charges and Multiball take its place as the safety net: in the retune's campaigns 1 round of 46 on level 3 ended on a lost ball (see "What the bot measured").
- **Guide** shows, while a ball waits on the paddle, a dashed cyan line along the way it would go if launched now (see [physics.md](physics.md#ball) for the sway). Each rank makes the line 250 units longer (`guide` in the stats), counted along the whole way. Without **Guide Bounces** the line stops at the first thing the ball would touch; with it, it bounces off walls, bricks and placed items as the ball would, until its length runs out or it reaches the paddle or the open side, where the way depends on the player. It does not foresee blasts, Shockwaves, Splitters or bricks brought back. Owning a rank of Guide also widens the launch's sway from 45° to the steepest legal angle (70°) and lets it pass through level instead of skipping the minimum angle, since the player can now see where a steep or flat launch goes. It hangs off the Booster, which the second trip buys, so it is on offer from the third; Guide Bounces belongs to level 2's band. The bot does not use it: it launches at once.
- **Overgrowth** makes the arena grow back. A level brick that breaks, by a ball, a blast or a Zap, comes back 8 s of play later (`overgrowth_delay`, on the round's clock, so an hourglass does not move it) as a plain 1 HP level brick: a special brick comes back plain, so a Power Brick drops only once. It comes back again each time it breaks. A brick the player placed never comes back. If a ball is over the cell when it is due, it comes back on the first step the cell is clear. A brick that came back scores and counts toward the target and the clear like any level brick, but the round does not wait for one: breaking the last level brick standing still ends it. It has no effect or sound of its own (see [art.md](../art.md#effects) and [audio.md](../audio.md)). It means levels 1 and 2 are seldom wiped any more: before the ability system, with every rank, the contract round on level 2 ran to time, 356 bricks broken and 5,149 coins, where it used to break all 128 for about 2,000. A clear comes from the target, so this costs nothing but the sight of an empty board. None of the bot's campaigns reaches it (see "What the bot measured").
- **The prices come in three bands, one per level**, because each level pays several times the one before. In the retune's campaigns a round pays 1 to about 120 coins on level 1 (a clear 33 to 116), 0 to about 1,100 on level 2 (most under 300, a clear 400 to 1,100) and 40 to about 7,000 on level 3 (a clear 2,300 to 6,800); with every rank a round on level 3 pays 20,000 to 36,000 on average. Up to 40 coins is what level 1 pays for: 11 ranks: the seed, the first rank of every node next to it and of six more, Power Brick and the Guide among them, so the first trips to the hub show the core of the game. From 60 to 1,200 is level 2: 35 ranks, Zap and Blast the first of them. From 1,280 to 12,500 is level 3: 24 ranks. The balance bot buys the cheapest rank on offer, so the bands are the order it buys in. The demo ends before the last band is bought: the campaigns clear level 3 with 37 to 40 ranks bought and 6,800 to 8,800 coins spent.
- **The growth puts a node's later ranks in a later band.** Hourglass Brick grows ×100 and Booster ×20 because their first rank belongs to level 1 and their second to level 3 or 2.
- **The first round.** A fresh round on level 1 with no items (`bot batch level=1 ranks=fresh layout=empty seeds=20`) pays the bot's average and good players about 10 coins, at least 5 every time and 9 or more in 35 to 40% of rounds: the seed (5) always, and Combo (4) as well in those. Its clumsy player gets about 4, and the seed in 55% of rounds. The campaigns' first rounds paid 3, 6 and 8 (clumsy, average, good).
- **What the bot measured** after the ability system: `bot campaign` once per skill, with the layout search, on the prices above and the targets 28, 384 and 2048. Each stage is probed with 10 seeds and each campaign is one run, so a figure moves by a round or two between runs. For the average and good players the first trip buys Paddle Speed and the second Combo and a Booster. The average player buys Power Brick on round 3 (on level 1), Blast and Zap on rounds 6 and 7 (level 2's 3rd and 4th) and Multiball on 12; the good player on rounds 4, 9, 10 and 17, the clumsy one on 13, 18, 18 and 34. The average player clears level 1 on round 3, level 2 on 9 and level 3 on 19 (the good player on 3, 14 and 18, the clumsy one on 15, 30 and 37). In rounds from each level's first, against the goals in brackets, the average player's level 1 stages end on 3 (2) and 5 (6), level 2's on 2 (4) and 10 (10), level 3's on 4 (6) and 21 (16). Across the three skills level 1's end on 3 to 4 and 4 to 13, level 2's on 1 to 3 and 10 to 22, and level 3's on 1 to 4 and 13 to 21. A round on arrival pays the average player 137 on level 2 against 57 on level 1, and 153 on level 3 against 196 on level 2 (the good player 234 against 312, the clumsy one 153 against 447), so a new level 3 pays less than the old level 2. No campaign reaches Overgrowth. They play 305 (clumsy), 379 (average) and 280 (good) seconds. With every rank (`bot batch ranks=max skill=all seeds=20` on `tests/layouts/found.json`) every round clears level 1, in about 11 s; level 2 is cleared in 95 to 100% of rounds, which last 38 to 48 s on average, and level 3 in 80 to 100%, lasting 33 to 45 s; they pay about 830, 6,700 to 7,900 and 26,000 to 36,000. One round of the clumsy player's 20 on level 3 loses its last ball, and none of the others. With Hourglass Time the longest rounds on levels 2 and 3 run 70 s; level 1's board is gone within 16 s. Before this retune, on the old prices and the targets 28, 320 and 8192, the same campaigns cleared on rounds 16, 24 and 60 (clumsy), 5, 11 and 54 (average) and 9, 13 and 35 (good): the average player took 43 rounds on level 3, whose stages ended on its 35th and 40th, and bought its first Power Brick on round 8.
- **Zap against Blast.** Measured with `charges=launch`, which fires each caught drop at once with the ability named by `ability=`. With every rank (as above, 20 seeds a skill) a round pays about the same with either on level 1 (795 to 863), 7,585 to 9,122 with Zap against 7,421 to 7,991 with Blast on level 2, and 29,575 to 31,420 against 20,307 to 25,660 on level 3. With the first rank of each, on level 2 with the ranks an earlier average campaign owned on its 12th round (30 seeds a skill), Zap paid 128 to 315 and Blast 105 to 299. Neither makes the other pointless; with every rank Zap pays more on level 3. With the default `charges=hold` the bot fires few of the charges it catches (3 to 17 in 20 rounds on levels 2 and 3), so the ability changes its payout little.
- **Level 3 is still a lottery.** Its rounds spread widely: the average player's 20 rounds there paid 41 to 6,819 coins, and its five clears 2,281 to 6,819. Its stage 1 ends too soon (on its 1st to 4th round, against 6) and its stage 2 on its 13th to 21st (against 16); a higher target would delay both, and stage 2 is already late for the average player. The ball is seldom lost early any more: in the three campaigns 1 round of 46 on level 3 ended on a lost ball, where before the ability system most did, when the wall's face was 81 units from the paddle (it is now 529, see [levels.md](levels.md#level-3-solid-wall-with-a-tunnel)). What makes the spread now has not been measured.
- **Sealing the paddle side does not pay.** This was measured before the ability system and has not been rerun. Two Wall Segments across the open side, with the Growth and Refresh blocks in the column behind them (measured when Growth was a block that pulsed every 5 s), trap the ball, but it then wears down only the bricks it reaches. When that layout is first affordable (the campaign's ranks on level 3's clear) a round pays the bot's average player 144 coins on level 1, 285 on level 2 and 26 on level 3, against 430, 1,179 and 3,173 with the layout search. With every rank it pays about 380, 350 to 800 and 700 to 1,300, against about 3,900 on level 1 and 5,000 and 43,000 for the contract's maxed rounds on levels 2 and 3.
- **The base values** are in `data/balance.tres`: the paddle moves 600 units a second and is 96 long, the ball moves 500 units a second, and a round lasts 20 s. A unit is a screen pixel on a 16-row level.

- **The text in the detail panel** is the "Each rank" wording, then, on a node that unlocks an item or changes one, a sentence on what it does. That sentence names no number that tuning may change, and the whole text has to fit the panel's two lines, about 80 characters.

## What the special bricks do

A special brick has 1 HP, a tough brick 3, whatever the brick it replaced had. What the placeables do is in [placeables.md](placeables.md#items).

| Brick | When it breaks |
|---|---|
| **Gold** | It counts as 20 bricks in the round's tally |
| **Hourglass** | It adds 15 s to the timer, plus Hourglass Time. With Hourglass Freeze it holds a running combo's window |
| **Tough** | Nothing more. It takes 3 hits, and each scores a point (see [overview.md](overview.md#coins)). It looks like any 3 HP brick, its colour stepping down the HP colours as it is hit |
| **Power** | It makes a drop at its cell, however it broke (a ball, a blast or a Zap), for the paddle to catch as a charge (see "Charges and abilities" above). It is drawn in the Abilities colour and scores 1, like a plain brick |

## What the abilities do

An ability goes off once, at the cell of the first level brick a charged ball hits, after that brick has taken the ball's hit.

| Ability | What it does |
|---|---|
| **Zap** | Every other brick in that brick row within 8 columns of the cell, on both sides, takes 1 hit. Each rank of Zap Range reaches 2 columns further each way, and each rank of Zap Damage adds 1 hit to every brick |
| **Blast** | Every brick within the blast takes 1 hit, and 1 more per rank of Blast Damage. The blast reaches 1 square (4 columns, or 1 brick height) out from the cell's edges in every direction, and each rank of Blast Size adds one more square, so it covers 26 brick cells around the cell, then 84, then 174. The brick that was hit is in it too, if it still stands. Nothing chains: a brick a blast breaks sets off no blast of its own |

**Shockwave** changes the blast: every ball inside it is thrown straight away from its centre, with its speed raised by a quarter as a boost (see [physics.md](physics.md#ball)). A ball still waiting on the paddle is not thrown.

## Upgrade screen

```
┌─ UPGRADES ────────────────────────────── ● 142 ─┐
│                                                 │
│        (web view, pan/zoom)                     │
│                                                 │
├─────────────────────────────────────────────────┤
│ Power Brick        Rank 2                       │
│ One more Power Brick each round                 │
│ Next rank: 400 ●                [ BUY ]         │
├─────────────────────────────────────────────────┤
│ Level: [◄ 2 ►]  (3 locked)    [ PLAY LEVEL ▶ ]  │
└─────────────────────────────────────────────────┘
```

## Open questions

- **The coin formula.** How the round's tally of bricks and combos turns into coins (see [overview.md](overview.md#coins)). The costs above move with it. For now it is the placeholder: 1 coin per hit on a brick, broken or not, each combo's points times the multiplier that combo reached, a gold brick counting as 20. Most of the prices above were set when only a break scored; the six the retune changed were set with hits scoring.
- **Combo numbers.** The window length, how it shrinks, and the multiplier. The values now, in `data/balance.tres`: the window is 2.4 s, about as long as the ball's trip to the back of level 1 and home, and Combo Window adds 1 s; every 5 hits on level bricks (a break is one) add 1 to the multiplier; each step of the multiplier cuts the window to 0.8 of what it was, down to 0.1 s. So a combo of 20 has a 1.2 s window at rank 1, and past about 80 only a blast, a Zap or several balls keep it alive. With every upgrade (`bot batch ranks=max skill=all seeds=20` on `tests/layouts/found.json`) a round's best combo is about 43 on level 1, 88 to 97 on level 2 and 190 to 225 on level 3, where the best rounds reach 344; the effects are at their biggest from 160 (see [art.md](../art.md#effects)), so most maxed rounds on level 3 sit past the top. Before the ability system the same batch gave about 28, 75 to 90 and 100 to 250, with 640 at most, on the 64-column wall.
- **The numbers were set with the balance bot and nobody has played them.** `tests/run.sh bot` plays the rules with a paddle that stands in for a person. Its players first clear level 3 on round 18 to 37, with 37 to 40 of the 70 ranks bought (see "What the bot measured" above). Level 3 is where the bot is the weakest stand-in: where the items are decides it as much as aim, and the bot cannot aim at the last few bricks.
- **Charges snowball.** A charge fires a new ball that stays in play once its ability is spent, so a round that breaks many Power Bricks ends with many balls, on top of Multiball's. That is accepted for now; nothing has measured how far it goes.
