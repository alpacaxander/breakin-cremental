# Upgrades

See also: [placeables.md](placeables.md), [physics.md](physics.md), [overview.md](overview.md).

## Rules

- Upgrades form a **web** that grows out from one seed node, **Paddle Speed** (the paddle starts slow). Each node unlocks once a connected node has been bought. Until then the upgrade screen hides it: the web shows only nodes whose ranks need nothing but coins.
- An upgrade can have **one or more ranks**, each more expensive than the last.
- **Categories are mixed across the web.** A category says what kind of thing a node is, not where it sits. Every path out from the seed should pass through different categories, so the player picks up a mix as they go.
- **A node that needs another node branches off it.** Explosion Size and Shockwave only do something once there are explosive bricks, so both connect directly to Explosive Brick.
- **Editable in Godot:** the web is laid out in its own scene, which sets where each node sits and which nodes it connects to. Each upgrade is its own resource file (see [architecture.md](../architecture.md#stats)), which sets:
  - its cost and growth
  - its maximum rank
  - its effect

## Categories

| Category | What it does | Nodes in the demo |
|---|---|---|
| **Placeables** | Items you unlock and then place in the arena during the Setup phase to help yourself. The three kinds and their rules are in [placeables.md](placeables.md) | Booster, Booster Speed, Zap, Zap Range, Zap Damage, Splitter, Splitter Splits, Splitter Health, Wall Segment, Growth, Growth Reach, Refresh, Refresh Size, Pulse Rate |
| **Bricks** | When a level starts, some standard bricks are randomly replaced by special bricks that do something when broken. Some nodes improve a special brick instead | Explosive Brick, Explosion Size, Explosion Damage, Shockwave, Gold Brick, Tough Brick, Hourglass Brick, Hourglass Time, Hourglass Freeze |
| **Arena** | Changes the arena's base stats and rules | Paddle Speed, Paddle Size, Combo, Combo Window, Rear Paddle, Overgrowth |

## Counts come from ranks

Placeables and special bricks share one rule: the node that unlocks the item has ranks, and each rank adds one.

- **Placeables:** rank N lets you place N of that item.
- **Special bricks:** rank N replaces N random standard bricks with that brick type when the level starts. The bricks are picked again on every attempt, including a retry.

A count is the same on every level, so 2 explosive bricks matter far more among level 1's 28 bricks than among level 3's 512.

## Speed

The ball and the paddle both start slow, and upgrades speed them up. The ball's speed is constant during play, except for boosts from the Booster and from Shockwave (see [physics.md](physics.md#ball)).

## The demo's web

Bracket shape shows the category: `( )` Arena, `[ ]` Placeables, `{ }` Bricks. Rows run top to bottom, as on screen.

```
{ Expl. Damage }   ( Rear Paddle  )───[     Zap      ]───[  Zap Range   ]───[  Zap Damage  ]
        │                                    │
{  Expl. Size  }   [Booster Speed ]───[   Booster    ]
        │                                    │
{  Explosive   }───( Paddle Size  )───(PADDLE SPEED  )───{  Hourglass   }───{Hourglass Time}
        │                                    │                                     │
{  Shockwave   }   [   Splitter   ]───(    Combo     )───( Combo Window )   {Hourglass Frz.}
                           │                 │
                   [SplitterSplits]   {  Gold Brick  }───[ Wall Segment ]
                           │                 │
                   [SplitterHealth]   { Tough Brick  }───[    Growth    ]───[ Growth Reach ]
                                             │                  │
                   [ Refresh Size ]───[   Refresh    ]───[  Pulse Rate  ]───(  Overgrowth  )
```

- Only the drawn lines are connections. The scene `src/hub/web.tscn` is the source; this drawing follows it.
- The web is 5 columns × 7 rows, taller than the view at zoom 1: the bottom two rows (Splitter Health, Tough Brick, Growth, Growth Reach; Refresh Size, Refresh, Pulse Rate, Overgrowth) are reached by panning, or the view scrolls to a node when it is selected.

A price is the first price times the growth for every rank owned, rounded to a whole coin. The ranks and prices are first values, set with the balance bot against the three stages of [design.md](../design.md#progression).

| Node | Category | Each rank | Ranks | Growth | Prices |
|---|---|---|---|---|---|
| Paddle Speed | Arena | +100% paddle speed | 2 | ×30 | 5, 150 |
| Paddle Size | Arena | +40% paddle length | 5 | ×3.5 | 50, 175, 613, 2,144, 7,503 |
| Combo | Arena | Turns combos on | 1 |  | 12 |
| Combo Window | Arena | The combo's window is 1 s longer | 2 | ×15 | 40, 600 |
| Rear Paddle | Arena | The back wall's stretch opposite the paddle boosts a ball by 20% of base speed | 2 | ×8 | 300, 2,400 |
| Overgrowth | Arena | Every level brick that breaks comes back 8 s of play later, a plain 1 HP brick (see below) | 1 |  | 8,000 |
| Booster | Placeables | One Booster | 2 | ×20 | 12, 240 |
| Booster Speed | Placeables | A Booster adds 20% of base speed more | 2 | ×6 | 500, 3,000 |
| Zap | Placeables | One Zap | 3 | ×4 | 200, 800, 3,200 |
| Zap Range | Placeables | A Zap reaches 2 more bricks each way (8 by default) | 2 | ×5 | 400, 2,000 |
| Zap Damage | Placeables | A Zap hits each brick once more | 2 | ×5 | 800, 4,000 |
| Splitter | Placeables | One Splitter | 5 | ×3 | 80, 240, 720, 2,160, 6,480 |
| Splitter Splits | Placeables | A Splitter splits a ball into one more (2 by default) | 2 | ×5 | 2,000, 10,000 |
| Splitter Health | Placeables | A Splitter takes one more hit, and splits the ball on each | 2 | ×6 | 500, 3,000 |
| Wall Segment | Placeables | One Wall Segment | 2 | ×10 | 40, 400 |
| Growth | Placeables | One Growth block | 3 | ×4.5 | 100, 450, 2,025 |
| Growth Reach | Placeables | Growth reaches one square further | 2 | ×10 | 300, 3,000 |
| Refresh | Placeables | One Refresh block | 3 | ×4.5 | 150, 675, 3,038 |
| Refresh Size | Placeables | Refresh brings back 2 more bricks | 2 | ×10 | 400, 4,000 |
| Pulse Rate | Placeables | Growth and Refresh are 1 s faster | 2 | ×6 | 1,000, 6,000 |
| Explosive Brick | Bricks | One explosive brick | 4 | ×3.5 | 40, 140, 490, 1,715 |
| Explosion Size | Bricks | Explosions reach one square further | 2 | ×20 | 150, 3,000 |
| Explosion Damage | Bricks | Explosions hit each brick once more | 2 | ×10 | 300, 3,000 |
| Shockwave | Bricks | Explosions throw balls | 1 |  | 600 |
| Gold Brick | Bricks | One gold brick | 3 | ×6 | 30, 180, 1,080 |
| Tough Brick | Bricks | One tough brick | 3 | ×6 | 20, 120, 720 |
| Hourglass Brick | Bricks | One hourglass brick | 2 | ×100 | 25, 2,500 |
| Hourglass Time | Bricks | An hourglass brick adds 5 s more | 2 | ×5 | 1,200, 6,000 |
| Hourglass Freeze | Bricks | Breaking an hourglass brick holds the combo's window for 1 s | 2 | ×5 | 800, 4,000 |

- That is 29 nodes and 68 purchases, 110,012 coins in all. The Bumper is still a kind in the code but no node unlocks it.
- **Overgrowth** makes the arena grow back. A level brick that breaks, by a ball, a blast or a Zap, comes back 8 s of play later (`overgrowth_delay`, on the round's clock, so an hourglass does not move it) as a plain 1 HP level brick: a special brick comes back plain and a Zap on it is gone. It comes back again each time it breaks. A brick the player placed never comes back. If a ball is over the cell when it is due, it comes back on the first step the cell is clear. A brick that came back scores and counts toward the target and the clear like any level brick, but the round does not wait for one: breaking the last level brick standing still ends it. It has no effect or sound of its own (see [art.md](../art.md#effects) and [audio.md](../audio.md)). It means levels 1 and 2 are seldom wiped any more: with every rank the contract round on level 2 runs to time, 356 bricks broken and 5,149 coins, where it used to break all 128 for about 2,000. A clear comes from the target, so this costs nothing but the sight of an empty board. Of the bot's campaigns only the good player's reaches it, after its last clear (see "What the bot measured").
- **The prices come in three bands, one per level**, because each level pays several times the one before. A round pays about 10 to 80 coins on level 1, 5 to 1,700 on level 2 (most under 150, a clear 500 to 1,700), and on level 3 either almost nothing (the ball is lost in the first seconds) or a few hundred on arrival and 2,500 to 7,000 later, with a clear paying 14,000 to 33,000 (80,000 with every rank). Up to 50 coins is what level 1 pays for: 10 ranks, the first of nearly every node next to the seed, so the first trip to the hub shows the core of the game. From 80 to 1,200 is level 2: 34 ranks. From 1,700 to 10,000 is level 3: 24 ranks. The balance bot buys the cheapest rank on offer, so the bands are the order it buys in.
- **The growth puts a node's later ranks in a later band.** Hourglass Brick grows ×100 and Booster ×20 because their first rank belongs to level 1 and their second to level 3 or 2.
- **The first round.** A fresh round on level 1 pays the bot's clumsy player about 14 coins and its good player about 19: the seed (5) either way, and with some skill Combo or a Booster (12) as well.
- **What the bot measured** (`bot campaign`, with the layout search, on all 68 ranks and the targets 28, 320 and 8192), since a Booster adds 20% of base speed (Booster Speed 20% a rank, boosts capped at 2×) and level 2's squares are twice as big: the first trip buys Paddle Speed and a Booster, the second Combo. The average player clears level 1 on round 4, level 2 on 10 and level 3 on 14 (the good player on 4, 10 and 17, the clumsy one on 3, 7 and 22). In rounds from each level's first, against the goals in brackets, the average player's level 1 stages end on 2 (2) and 5 (6), level 2's on 2 (4) and 7 (10), level 3's on 2 (6) and 8 (16); across the three skills level 2's stage 2 ends on its round 7 to 14 and level 3's on 8 to 19. Every player clears level 2 within 4 to 6 rounds of reaching it, so level 2 is now too easy, and level 3's stage 1 ends on its second round for the average and good players, so it is too soon. A round on arrival pays about 1,770 on level 3 against about 570 on level 2 (1,129 against 391 for the clumsy one). The clumsy player's campaign reaches Overgrowth; the average one ends with 3,440 coins and two ranks unbought. The two changes were measured together, so which did what is not known. Before them (Booster 10%, cap 1.5×, level 2 an 8×8 checkerboard), since a hit that leaves a level brick standing grows the combo as a break does, the average player cleared level 1 on round 4, level 2 on round 12 and level 3 on round 29 (the good player on 4, 16 and 17, the clumsy one on 3, 17 and 26). In rounds from each level's first, against the goals in brackets: level 1's stage 1 ends on round 3 (2) and its stage 2 on 5 (6); level 2's on 8 (4) and 10 (10); level 3's on 14 (6) and 17 (16). The three skills' runs put level 1's stages on 3 and 4 to 5, level 2's on 5 to 10 and 10 to 15, and level 3's stage 1 on its round 1 to 14 and stage 2 on 7 to 17: the good player clears level 3 on its first round there, with 14,351 coins. Only the good player's campaign reaches Overgrowth, five rounds after level 3's clear; the others end on the clear with 400 to 1,600 coins left. The campaigns play 346 (clumsy), 442 (average) and 508 (good, five rounds past its clear) seconds in all. Before the change the average player cleared on rounds 4, 13 and 30 (the good one on 4, 10 and 24, the clumsy one on 3, 20 and 40), and level 2's stage 1 ended on its round 3.
- **Level 3 is a lottery, and neither prices nor its target can fix that.** Most rounds lose the ball in the first seconds, at every rank, and a round that keeps it scores many times more, so its two stages end close together whatever the target: the target only says how many ranks that takes (see [levels.md](levels.md#rules)). Since a hit grows the combo, a round that keeps its ball pays even more: the average player's stage 2 ends on the round after Splitter Splits is bought, three rounds after stage 1, and the good player clears on arrival. So the demo took 17 to 29 rounds against the goal of about 30 in [design.md](../design.md#progression), and since the Booster and level 2 changes it takes 14 to 22. The level's layout is what needs changing: the wall's face is 81 units from the paddle.
- **Sealing the paddle side does not pay.** Two Wall Segments across the open side, with the Growth and Refresh blocks in the column behind them, trap the ball, but it then wears down only the bricks it reaches. When that layout is first affordable (the campaign's ranks on level 3's clear) a round pays the bot's average player 144 coins on level 1, 285 on level 2 and 26 on level 3, against 430, 1,179 and 3,173 with the layout search. With every rank it pays about 380, 350 to 800 and 700 to 1,300, against about 3,900 on level 1 and 5,000 and 43,000 for the contract's maxed rounds on levels 2 and 3.
- **The base values** are in `data/balance.tres`: the paddle moves 600 units a second and is 96 long, the ball moves 500 units a second, and a round lasts 20 s. A unit is a screen pixel on a 16-row level.

- **The text in the detail panel** is the "Each rank" wording, then, on a node that unlocks an item or changes one, a sentence on what it does. That sentence names no number that tuning may change, and the whole text has to fit the panel's two lines, about 80 characters.

## What the special bricks do

A special brick has 1 HP, a tough brick 3, whatever the brick it replaced had. What the placeables do is in [placeables.md](placeables.md#items).

| Brick | When it breaks |
|---|---|
| **Explosive** | Every brick within the blast takes 1 hit, and 1 more per rank of Explosion Damage. The blast reaches 1 square (4 columns, or 1 brick height) out from the brick's edges in every direction, and each rank of Explosion Size adds one more square, so the blast covers 26 brick cells around it, then 84, then 174. An explosive brick broken by a blast explodes too |
| **Gold** | It counts as 20 bricks in the round's tally |
| **Hourglass** | It adds 15 s to the timer, plus Hourglass Time. With Hourglass Freeze it holds a running combo's window |
| **Tough** | Nothing more. It takes 3 hits, and each scores a point (see [overview.md](overview.md#coins)). It looks like any 3 HP brick, its colour stepping down the HP colours as it is hit |

**Shockwave** changes the explosion: every ball inside the blast is thrown straight away from the blast's centre, with its speed raised by a quarter as a boost (see [physics.md](physics.md#ball)).

## Upgrade screen

```
┌─ UPGRADES ────────────────────────────── ● 142 ─┐
│                                                 │
│        (web view, pan/zoom)                     │
│                                                 │
├─────────────────────────────────────────────────┤
│ Explosive Brick    Rank 2                       │
│ One more explosive brick each round             │
│ Next rank: 98 ●                 [ BUY ]         │
├─────────────────────────────────────────────────┤
│ Level: [◄ 2 ►]  (3 locked)    [ PLAY LEVEL ▶ ]  │
└─────────────────────────────────────────────────┘
```

## Open questions

- **The coin formula.** How the round's tally of bricks and combos turns into coins (see [overview.md](overview.md#coins)). The costs above move with it. For now it is the placeholder: 1 coin per hit on a brick, broken or not, each combo's points times the multiplier that combo reached, a gold brick counting as 20. The prices above were set when only a break scored.
- **Combo numbers.** The window length, how it shrinks, and the multiplier. The values now, in `data/balance.tres`: the window is 2.4 s, about as long as the ball's trip to the back of level 1 and home, and Combo Window adds 1 s; every 5 hits on level bricks (a break is one) add 1 to the multiplier; each step of the multiplier cuts the window to 0.8 of what it was, down to 0.1 s. So a combo of 20 has a 1.2 s window at rank 1, and past about 80 only a blast, a Zap or several balls keep it alive. With every upgrade (`bot batch ranks=max skill=all seeds=20` on `tests/layouts/found.json`) a round's best combo is about 28 on level 1, 75 to 90 on level 2 and 100 to 250 on level 3, where the best rounds reach 640; the effects are at their biggest from 160 (see [art.md](../art.md#effects)), so level 3's big rounds sit far past the top. Before a hit grew the combo the same batch gave about 24, 70 to 90 and 80 to 215, with 580 at most: most hits on a maxed board break their brick, so the change shows most where bricks have HP to spare, early on and on level 3.
- **The numbers were set with the balance bot and nobody has played them.** `tests/run.sh bot` plays the rules with a paddle that stands in for a person. Its players first clear level 3 on round 17 to 29, and none of them has bought every rank by then (see "What the bot measured" above). Level 3 is where the bot is the weakest stand-in. The wall's face is 81 units from the paddle, so how a person copes with a ball that is back in a fifth of a second decides the level; where the items are decides it as much, and the bot cannot aim at the last few bricks.
