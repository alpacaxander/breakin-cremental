# Upgrades

See also: [placeables.md](placeables.md), [physics.md](physics.md), [overview.md](overview.md).

## Rules

- Upgrades form a **web** that grows out from one seed node, **Paddle Speed** (the paddle starts slow). Each node unlocks once a connected node has been bought. Until then the upgrade screen hides it: the web shows only nodes whose ranks need nothing but coins.
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

A count is the same on every level, so 2 explosive bricks matter far more among level 1's 51 bricks than among level 3's 512.

## Speed

The ball and the paddle both start slow, and upgrades speed them up. The ball's speed is constant during play, except for boosts from the Booster and from Shockwave (see [physics.md](physics.md#ball)).

## The demo's web

Bracket shape shows the category: `( )` Arena, `[ ]` Placeables, `{ }` Bricks.

```
                 [    Zap     ]   [  Booster   ]
                       │                │
                 { Gold Brick }───( Ball Speed )   { Shockwave  }
                                        │                │
(   Combo    )───[  Splitter  ]───(PADDLE SPEED)───{ Explosive  }───{ Blast Size }
      │                                 │                │
[   Bumper   ]   [Wall Segment]───(Paddle Size )   ( Round Time )
                                                         │
                                                   { Hourglass  }
```

- Only the drawn lines are connections. Two nodes that sit side by side with no line between them are not linked.
- The web fits a grid of 5 columns × 5 rows, with the seed in the centre (see [art.md](../art.md#upgrade-screen)).

| Steps from seed | Node | Category | Ranks | Each rank | First cost | Each rank costs | Prices |
|---|---|---|---|---|---|---|---|
| 0 | Paddle Speed | Arena | 2 | +100% paddle speed | 2 | ×20 | 2, 40 |
| 1 | Ball Speed | Arena | 3 | +10% ball speed | 5 | ×3 | 5, 15, 45 |
| 1 | Paddle Size | Arena | 5 | +40% paddle length | 10 | ×8 | 10, 80, 640, 5120, 40960 |
| 1 | Splitter | Placeables | 5 | One more Splitter | 40 | ×5.7 | 40, 228, 1300, 7408, 42224 |
| 1 | Explosive Brick | Bricks | 4 | One more explosive brick | 8 | ×3.5 | 8, 28, 98, 343 |
| 2 | Combo | Arena | 2 | Rank 1 turns combos on. Rank 2 widens the window | 20 | ×25 | 20, 500 |
| 2 | Wall Segment | Placeables | 2 | One more Wall Segment | 30 | ×8 | 30, 240 |
| 2 | Round Time | Arena | 5 | +6 s | 10 | ×7 | 10, 70, 490, 3430, 24010 |
| 2 | Gold Brick | Bricks | 3 | One more gold brick | 25 | ×7 | 25, 175, 1225 |
| 2 | Booster | Placeables | 2 | One more Booster | 100 | ×8 | 100, 800 |
| 2 | Blast Size | Bricks | 2 | Explosions reach one square further | 35 | ×450 | 35, 15750 |
| 2 | Shockwave | Bricks | 1 | Explosions throw balls | 600 | | 600 |
| 3 | Hourglass Brick | Bricks | 2 | One more hourglass brick | 300 | ×60 | 300, 18000 |
| 3 | Bumper | Placeables | 3 | One more Bumper | 10 | ×8 | 10, 80, 640 |
| 3 | Zap | Placeables | 3 | One more Zap | 300 | ×9 | 300, 2700, 24300 |

- **Cost growth** is set per node, and each node has its own value: a price is the first cost times the growth for every rank owned, rounded to a whole coin. The growth is what puts a node's later ranks in a later level's price band. Blast Size costs 450× and Hourglass Brick 60× because their first rank is an early purchase and their second belongs to level 3.
- **Percentages** are of the base value and add up, so Ball Speed rank 3 is 130% of the base speed.
- **The base values** are in `data/balance.tres`: the paddle moves 600 units a second and is 96 long, the ball moves 700 units a second, and a round lasts 20 s. A unit is a screen pixel on a 16-row level. Maxed, that is a paddle at 1800 and 288 long (half of level 3's lane), a ball at 910 and a 50 s round.
- **The costs assume the coin formula** of 1 coin per brick (see [overview.md](overview.md#coins)). A first round on level 1 pays about 20 coins. The seed costs 2 and Ball Speed 5, so the first trip to the hub buys both and the second round is already faster.
- **The prices come in three bands**, one per level, because each level pays about ten times the one before: a round pays 20 to 70 coins on level 1, 200 to 700 on level 2 and 2,500 to 6,500 on level 3. Up to 45 coins: what level 1 pays for, 15 ranks. From 70 to about 1,300: level 2 and the first round of level 3, 19 ranks. From 2,700 to 42,000: level 3, 10 ranks. The balance bot (`tests/run.sh bot campaign`) buys the cheapest rank on offer, so the bands are the order it buys in.
- **What the last ranks are for.** Level 3 is cleared by the ranks at the top of the list: Paddle Size 4 and 5 keep the ball in play against the wall's face, and Splitter 4 and 5, Hourglass Brick 2 and Round Time 5 find the last bricks.
- Shockwave sits one step from the first ring because it has to connect to Explosive Brick. Its price is what keeps it late.
- That is 15 nodes and 44 purchases, 192,434 coins in all.
- **What the balance bot cannot show.** On levels 1 and 2 a Bumper, a Booster or a Wall Segment measures as nothing or as a loss for the bot, wherever it is put, at any size or boost tried: the bot's paddle does not foresee a bounce off an item. On level 3 they count as a set: with every upgrade, the bot's average player clears the level in 44 rounds of 100 with them and 8 without, and each kind alone is worth 7 to 9 of those. Shockwave measures as nothing anywhere. So the numbers of these four are untested guesses until a person places them. Paddle Speed's first rank changes nothing on level 1, where the ball takes more than two seconds to come back; without it level 2 is lost in more than eight rounds of ten.
- **The text in the detail panel** is the "Each rank" wording, then, on a node that unlocks an item or changes one, a sentence on what it does. That sentence names no number that tuning may change, and the whole text has to fit the panel's two lines, about 80 characters.

## What the special bricks do

A special brick has 1 HP, whatever the brick it replaced had. What the placeables do is in [placeables.md](placeables.md#items).

| Brick | When it breaks |
|---|---|
| **Explosive** | Every brick within the blast takes 1 hit. The blast reaches 1 square (4 columns, or 1 brick height) out from the brick's edges in every direction, and each rank of Blast Size adds one more square, so the blast covers 26 brick cells around it, then 84, then 174. An explosive brick broken by a blast explodes too |
| **Gold** | It counts as 20 bricks in the round's tally |
| **Hourglass** | It adds 15 s to the timer |

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

- **The coin formula.** How the round's tally of bricks and combos turns into coins (see [overview.md](overview.md#coins)). The costs above move with it. For now it is the placeholder: 1 coin per brick times the multiplier, a gold brick counting as 20.
- **Combo numbers.** The window length, how it shrinks, and the multiplier. The values now, in `data/balance.tres`: the window is 2.4 s, about as long as the ball's trip to the back of level 1 and home, and Combo's second rank adds 1 s; every 5 breaks add 1 to the multiplier; each step of the multiplier cuts the window to 0.8 of what it was, down to 0.1 s. So a combo of 20 has a 1.2 s window at rank 1, and past about 80 only a blast, a Zap or several balls keep it alive. With every upgrade a round's best combo is about 27 on level 1, 90 on level 2 and 175 on level 3, and the effects are at their biggest from 160 (see [art.md](../art.md#effects)). A cascade on level 3 can pass 300, which pays three times a usual round.
- **The numbers were set with the balance bot and nobody has played them.** `tests/run.sh bot` plays the rules with a paddle that stands in for a person. Its average player finishes the demo in 33 to 65 rounds, 20 to 45 minutes, with 38 to 43 of the 44 ranks: about 40 rounds on the layouts kept in `tests/layouts/found.json`, about 60 with layouts it searches for as it buys items and never rearranges. With every rank it clears level 3 in 3 or 4 rounds of 10, and its good player in 4 to 8. Level 3 is where the bot is the weakest stand-in. The wall's face is 81 units from the paddle, so how a person copes with a ball that is back in a fifth of a second decides the level; where the items are decides it as much, and the bot cannot aim at the last few bricks.
