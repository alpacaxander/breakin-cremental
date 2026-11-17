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
| **Placeables** | Items you unlock and then place in the arena during the Setup phase to help yourself. The three kinds and their rules are in [placeables.md](placeables.md) | Booster, Booster Speed, Zap, Zap Range, Zap Damage, Splitter, Splitter Splits, Splitter Health, Wall Segment |
| **Bricks** | When a level starts, some standard bricks are randomly replaced by special bricks that do something when broken. Some nodes improve a special brick instead | Explosive Brick, Explosion Size, Explosion Damage, Shockwave, Gold Brick, Tough Brick, Hourglass Brick, Hourglass Time, Hourglass Freeze |
| **Arena** | Changes the arena's base stats | Paddle Speed, Paddle Size, Combo, Combo Window, Rear Paddle |

## Counts come from ranks

Placeables and special bricks share one rule: the node that unlocks the item has ranks, and each rank adds one.

- **Placeables:** rank N lets you place N of that item.
- **Special bricks:** rank N replaces N random standard bricks with that brick type when the level starts. The bricks are picked again on every attempt, including a retry.

A count is the same on every level, so 2 explosive bricks matter far more among level 1's 20 bricks than among level 3's 512.

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
                   [SplitterHealth]   { Tough Brick  }
```

- Only the drawn lines are connections. The scene `src/hub/web.tscn` is the source; this drawing follows it.
- The web is 5 columns × 6 rows, taller than the view at zoom 1: Splitter Health and Tough Brick are reached by panning, or the view scrolls to one when it is selected.

A price is the first price times the growth for every rank owned, rounded to a whole coin. The ranks and prices are first values, set with the balance bot against the three stages of [design.md](../design.md#progression).

| Node | Category | Each rank | Ranks | Growth | Prices |
|---|---|---|---|---|---|
| Paddle Speed | Arena | +100% paddle speed | 2 | ×30 | 5, 150 |
| Paddle Size | Arena | +40% paddle length | 5 | ×3.5 | 50, 175, 613, 2,144, 7,503 |
| Combo | Arena | Turns combos on | 1 |  | 12 |
| Combo Window | Arena | The combo's window is 1 s longer | 2 | ×15 | 40, 600 |
| Rear Paddle | Arena | The back wall's stretch opposite the paddle boosts a ball by 20% of base speed | 2 | ×8 | 300, 2,400 |
| Booster | Placeables | One Booster | 2 | ×20 | 12, 240 |
| Booster Speed | Placeables | A Booster adds 10% of base speed more | 2 | ×6 | 500, 3,000 |
| Zap | Placeables | One Zap | 3 | ×4 | 200, 800, 3,200 |
| Zap Range | Placeables | A Zap reaches 2 more bricks each way (8 by default) | 2 | ×5 | 400, 2,000 |
| Zap Damage | Placeables | A Zap hits each brick once more | 2 | ×5 | 800, 4,000 |
| Splitter | Placeables | One Splitter | 5 | ×3 | 80, 240, 720, 2,160, 6,480 |
| Splitter Splits | Placeables | A Splitter splits a ball into one more (2 by default) | 2 | ×5 | 2,000, 10,000 |
| Splitter Health | Placeables | A Splitter takes one more hit, and splits the ball on each | 2 | ×6 | 500, 3,000 |
| Wall Segment | Placeables | One Wall Segment | 2 | ×10 | 40, 400 |
| Explosive Brick | Bricks | One explosive brick | 4 | ×3.5 | 40, 140, 490, 1,715 |
| Explosion Size | Bricks | Explosions reach one square further | 2 | ×20 | 150, 3,000 |
| Explosion Damage | Bricks | Explosions hit each brick once more | 2 | ×10 | 300, 3,000 |
| Shockwave | Bricks | Explosions throw balls | 1 |  | 600 |
| Gold Brick | Bricks | One gold brick | 3 | ×6 | 30, 180, 1,080 |
| Tough Brick | Bricks | One tough brick | 3 | ×6 | 20, 120, 720 |
| Hourglass Brick | Bricks | One hourglass brick | 2 | ×100 | 25, 2,500 |
| Hourglass Time | Bricks | An hourglass brick adds 5 s more | 2 | ×5 | 1,200, 6,000 |
| Hourglass Freeze | Bricks | Breaking an hourglass brick holds the combo's window for 1 s | 2 | ×5 | 800, 4,000 |

- That is 23 nodes and 55 purchases, 80,874 coins in all. The Bumper is still a kind in the code but no node unlocks it.
- **The prices come in three bands, one per level**, because each level pays several times the one before. A round pays about 15 to 75 coins on level 1, 40 to 500 on level 2, and on level 3 either almost nothing (the ball is lost in the first seconds) or 1,500 to 5,000 and more. Up to 50 coins is what level 1 pays for: 10 ranks, the first of nearly every node next to the seed, so the first trip to the hub shows the core of the game. From 80 to 1,200 is level 2: 27 ranks. From 1,700 to 10,000 is level 3: 18 ranks. The balance bot buys the cheapest rank on offer, so the bands are the order it buys in.
- **The growth puts a node's later ranks in a later band.** Hourglass Brick grows ×100 and Booster ×20 because their first rank belongs to level 1 and their second to level 3 or 2.
- **The first round.** A fresh round on level 1 pays the bot's clumsy player about 14 coins and its good player about 19: the seed (5) either way, and with some skill Combo or a Booster (12) as well.
- **What the bot measured** (`bot campaign`, average player, with the layout search, on the 52 ranks before Tough Brick was added): the first trip buys Paddle Speed and a Booster, the second Combo. Level 1 is cleared on round 4, level 2 on round 13 and level 3 on round 20. In rounds from each level's first, against the goals in brackets: level 1's stage 1 ends on round 3 (2) and its stage 2 on 8 (6); level 2's on 1 (4) and 19 (12); level 3's on 1 (8) and 25 (25). On the kept layouts (`tests/layouts/found.json`, four seed sets) the demo's first finish is on rounds 18 to 27, level 2's stage 2 ends on rounds 9 to 25, and level 3's on 16 to 30, or not within the run.
- **Level 3 is a lottery, and prices cannot fix that.** Its good player clears 10% of tries on arrival, so its stage 1 ends at once, and with every rank its clumsy player still loses the ball in about 7 rounds of 10. Only a paddle long enough to fill the lane (12 ranks of Paddle Size) stops the drops, and then skill no longer matters. The level's layout and target are what need changing: the wall's face is 81 units from the paddle.
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
- **Combo numbers.** The window length, how it shrinks, and the multiplier. The values now, in `data/balance.tres`: the window is 2.4 s, about as long as the ball's trip to the back of level 1 and home, and Combo Window adds 1 s; every 5 breaks add 1 to the multiplier; each step of the multiplier cuts the window to 0.8 of what it was, down to 0.1 s. So a combo of 20 has a 1.2 s window at rank 1, and past about 80 only a blast, a Zap or several balls keep it alive. With every upgrade a round's best combo is about 27 on level 1, 90 on level 2 and 175 on level 3, and the effects are at their biggest from 160 (see [art.md](../art.md#effects)). A cascade on level 3 can pass 300, which pays three times a usual round. These were measured when each brick paid the multiplier it broke at; a combo now pays all its bricks at the multiplier it reached, so combos pay more than this, and the bot has not measured it again.
- **The numbers were set with the balance bot and nobody has played them.** `tests/run.sh bot` plays the rules with a paddle that stands in for a person. Its average player first clears level 3 on round 18 to 27 and has every one of the 52 ranks by round 31 to 57 (see "What the bot measured" above). With every rank it clears level 3 in about 2 rounds of 10 on the kept layouts, and its good player in 4. Level 3 is where the bot is the weakest stand-in. The wall's face is 81 units from the paddle, so how a person copes with a ball that is back in a fifth of a second decides the level; where the items are decides it as much, and the bot cannot aim at the last few bricks.
