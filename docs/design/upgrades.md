# Upgrades

See also: [placeables.md](placeables.md), [physics.md](physics.md), [overview.md](overview.md).

## Rules

- Upgrades form a **web** that grows out from one seed node, **Paddle Speed** (the paddle starts slow). Each node unlocks once a connected node has been bought.
- An upgrade can have **one or more ranks**, each more expensive than the last.
- **Categories are mixed across the web.** A category says what kind of thing a node is, not where it sits. Every path out from the seed should pass through different categories, so the player picks up a mix as they go.
- **A node that needs another node branches off it.** Blast Size and Shockwave only do something once there are explosive bricks, so both connect directly to Explosive Brick.
- **Editable in Godot:** the web is laid out in its own scene, which sets where each node sits and which nodes it connects to. Each upgrade is its own resource file (see [architecture.md](../architecture.md#stats)), which sets:
  - its cost and growth
  - its maximum rank
  - its effect

## Categories

| Category | What it does | Nodes in the demo |
|---|---|---|
| **Placeables** | Items you unlock and then place in the arena during the Setup phase to help yourself. The three kinds and their rules are in [placeables.md](placeables.md) | Bumper, Booster, Wall Segment, Splitter, Zap |
| **Bricks** | When a level starts, some standard bricks are randomly replaced by special bricks that do something when broken. Some nodes improve a special brick instead | Explosive Brick, Blast Size, Shockwave, Gold Brick, Hourglass Brick |
| **Arena** | Changes the arena's base stats | Paddle Speed, Paddle Size, Ball Speed, Round Time, Combo |

## Counts come from ranks

Placeables and special bricks share one rule: the node that unlocks the item has ranks, and each rank adds one.

- **Placeables:** rank N lets you place N of that item.
- **Special bricks:** rank N replaces N random standard bricks with that brick type when the level starts. The bricks are picked again on every attempt, including a retry.

A count is the same on every level, so 2 explosive bricks matter far more among level 1's 24 bricks than among level 3's 512.

## Speed

The ball and the paddle both start slow, and upgrades speed them up. The ball's speed is constant during play, except for boosts from the Booster and from Shockwave (see [physics.md](physics.md#ball)).

## The demo's web

Bracket shape shows the category: `( )` Arena, `[ ]` Placeables, `{ }` Bricks.

```
                 [    Zap     ]   [  Booster   ]
                       │                │
                 { Gold Brick }───( Ball Speed )   { Shockwave  }
                                        │                │
(   Combo    )───[   Bumper   ]───(PADDLE SPEED)───{ Explosive  }───{ Blast Size }
      │                                 │                │
[  Splitter  ]   [Wall Segment]───(Paddle Size )   ( Round Time )
                                                         │
                                                   { Hourglass  }
```

- Only the drawn lines are connections. Two nodes that sit side by side with no line between them are not linked.
- The web fits a grid of 5 columns × 5 rows, with the seed in the centre (see [art.md](../art.md#upgrade-screen)).

| Steps from seed | Node | Category | Ranks | Each rank | First cost | Each rank costs | Prices |
|---|---|---|---|---|---|---|---|
| 0 | Paddle Speed | Arena | 2 | +100% paddle speed | 5 | ×10 | 5, 50 |
| 1 | Ball Speed | Arena | 3 | +10% ball speed | 6 | ×2.5 | 6, 15, 38 |
| 1 | Paddle Size | Arena | 3 | +20% paddle length | 10 | ×4 | 10, 40, 160 |
| 1 | Bumper | Placeables | 3 | One more Bumper | 10 | ×10 | 10, 100, 1000 |
| 1 | Explosive Brick | Bricks | 4 | One more explosive brick | 8 | ×2.5 | 8, 20, 50, 125 |
| 2 | Combo | Arena | 3 | Rank 1 turns combos on. Ranks 2 and 3 widen the window | 20 | ×10 | 20, 200, 2000 |
| 2 | Wall Segment | Placeables | 2 | One more Wall Segment | 400 | ×4 | 400, 1600 |
| 2 | Round Time | Arena | 6 | +5 s | 10 | ×2.5 | 10, 25, 63, 156, 391, 977 |
| 2 | Gold Brick | Bricks | 3 | One more gold brick | 25 | ×4 | 25, 100, 400 |
| 2 | Booster | Placeables | 2 | One more Booster | 400 | ×4 | 400, 1600 |
| 2 | Blast Size | Bricks | 2 | Explosions reach one square further | 35 | ×100 | 35, 3500 |
| 2 | Shockwave | Bricks | 1 | Explosions throw balls | 300 | | 300 |
| 3 | Hourglass Brick | Bricks | 2 | One more hourglass brick | 200 | ×4 | 200, 800 |
| 3 | Splitter | Placeables | 5 | One more Splitter | 60 | ×4 | 60, 240, 960, 3840, 15360 |
| 3 | Zap | Placeables | 3 | One more Zap | 200 | ×4 | 200, 800, 3200 |

- **Cost growth** is set per node, and there are four values. The three stats that are more of the same (Ball Speed, Explosive Brick, Round Time) cost 2.5× the rank before. Most nodes cost 4×. The three whose first rank is an early unlock and whose later ranks are late purchases (Paddle Speed, Bumper, Combo) cost 10×. Blast Size costs 100×: its first rank is what clears level 1, and its second, a blast three squares wide, belongs to level 3. Prices are rounded to a whole coin.
- **Percentages** are of the base value and add up, so Ball Speed rank 3 is 130% of the base speed.
- **The base values** are in `data/balance.tres`: the paddle moves 600 units a second and is 96 long, the ball moves 700 units a second, and a round lasts 20 s. A unit is a screen pixel on a 16-row level. Maxed, that is a paddle at 1800 and 154 long, a ball at 910 and a 50 s round.
- **The costs assume the coin formula** of 1 coin per brick (see [overview.md](overview.md#coins)). A first round on level 1 pays about 8 coins, and the seed costs 5.
- **The prices come in three bands**, one per level. Up to about 60 coins: what level 1 pays for, about 16 ranks. From 100 to about 1000: level 2. Above that: level 3. The balance bot (`tests/run.sh bot campaign`) buys the cheapest rank on offer, so the bands are the order it buys in.
- Shockwave sits one step from the first ring because it has to connect to Explosive Brick. Its price is what keeps it late.
- That is 15 nodes and 44 purchases.
- **The text in the detail panel** is the "Each rank" wording, then, on a node that unlocks an item or changes one, a sentence on what it does. That sentence names no number that tuning may change, and the whole text has to fit the panel's two lines, about 80 characters.

## What the special bricks do

A special brick has 1 HP, whatever the brick it replaced had. What the placeables do is in [placeables.md](placeables.md#items).

| Brick | When it breaks |
|---|---|
| **Explosive** | Every brick within the blast takes 1 hit. The blast reaches 1 square (4 columns, or 1 brick height) out from the brick's edges in every direction, and each rank of Blast Size adds one more square, so the blast covers 26 brick cells around it, then 84, then 174. An explosive brick broken by a blast explodes too |
| **Gold** | It counts as 20 bricks in the round's tally |
| **Hourglass** | It adds 10 s to the timer |

**Shockwave** changes the explosion: every ball inside the blast is thrown straight away from the blast's centre, with its speed raised by a quarter as a boost (see [physics.md](physics.md#ball)).

## Upgrade screen

```
┌─ UPGRADES ────────────────────────────── ● 142 ─┐
│                                                 │
│        (web view, pan/zoom)                     │
│                                                 │
├─────────────────────────────────────────────────┤
│ Explosive Brick    Rank 2/3                     │
│ 2 bricks become Explosive each attempt          │
│ Next rank: 65 ●                 [ BUY ]         │
├─────────────────────────────────────────────────┤
│ Level: [◄ 2 ►]  (3 locked)    [ PLAY LEVEL ▶ ]  │
└─────────────────────────────────────────────────┘
```

## Open questions

- **The coin formula.** How the round's tally of bricks and combos turns into coins (see [overview.md](overview.md#coins)). The costs above move with it. For now it is the placeholder: 1 coin per brick times the multiplier, a gold brick counting as 20.
- **Combo numbers.** The window length, how it shrinks, and the multiplier. The values now, in `data/balance.tres`: the window is 1.6 s, and each Combo rank above the first adds 0.5 s; every 5 breaks add 1 to the multiplier; each step of the multiplier cuts the window to 0.8 of what it was, down to 0.1 s. So a combo of 20 has a 0.8 s window at rank 1, and past about 70 only a blast or several balls keep it alive. With every upgrade a round's best combo is about 25 on level 1, 85 on level 2 and 100 to 140 on level 3, and the effects are at their biggest from 120 (see [art.md](../art.md#effects)).
- **The numbers were set with the balance bot and nobody has played them.** `tests/run.sh bot` plays the rules with a paddle that stands in for a person. It says level 3 is still too hard: an average player almost never clears it, even with everything bought.
