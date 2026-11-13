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

| Steps from seed | Node | Category | Ranks | Each rank | First cost |
|---|---|---|---|---|---|
| 0 | Paddle Speed | Arena | 5 | +20% paddle speed | 5 |
| 1 | Ball Speed | Arena | 5 | +15% ball speed | 10 |
| 1 | Paddle Size | Arena | 3 | +15% paddle length | 10 |
| 1 | Bumper | Placeables | 3 | One more Bumper | 15 |
| 1 | Explosive Brick | Bricks | 3 | One more explosive brick | 20 |
| 2 | Combo | Arena | 3 | Rank 1 turns combos on. Ranks 2 and 3 widen the window | 30 |
| 2 | Wall Segment | Placeables | 2 | One more Wall Segment | 30 |
| 2 | Round Time | Arena | 3 | +3 s | 30 |
| 2 | Gold Brick | Bricks | 3 | One more gold brick | 40 |
| 2 | Booster | Placeables | 2 | One more Booster | 40 |
| 2 | Blast Size | Bricks | 2 | Explosions reach half a square further | 50 |
| 2 | Shockwave | Bricks | 1 | Explosions throw balls | 80 |
| 3 | Hourglass Brick | Bricks | 2 | One more hourglass brick | 60 |
| 3 | Splitter | Placeables | 2 | One more Splitter | 70 |
| 3 | Zap | Placeables | 2 | One more Zap | 80 |

- **Cost growth:** each rank costs 1.8× the one before, rounded to a whole coin.
- **Percentages** are of the base value and add up, so Ball Speed rank 5 is 175% of the base speed.
- **The costs assume the placeholder coin formula** of 1 coin per brick (see [overview.md](overview.md#coins)). A first run on level 1 should pay roughly 5 to 15 coins.
- Shockwave sits one step from the first ring because it has to connect to Explosive Brick. Its price is what keeps it late.
- That is 15 nodes and 41 purchases.

## What the special bricks do

A special brick has 1 HP, whatever the brick it replaced had. What the placeables do is in [placeables.md](placeables.md#items).

| Brick | When it breaks |
|---|---|
| **Explosive** | Every brick within the blast takes 1 hit. The blast reaches 1 square (4 columns, or 1 brick height) out from the brick's edges in every direction, and each rank of Blast Size adds half a square. An explosive brick broken by a blast explodes too |
| **Gold** | It counts as 5 bricks in the round's tally |
| **Hourglass** | It adds 2 s to the timer |

**Shockwave** changes the explosion: every ball inside the blast is thrown straight away from the blast's centre, with its speed doubled as a boost (see [physics.md](physics.md#ball)).

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

- **The coin formula.** How the round's tally of bricks and combos turns into coins (see [overview.md](overview.md#coins)). The costs above move with it.
- **Combo numbers.** The window length, how it shrinks, and the multiplier. The implementation picks starting values and they are tuned later.
