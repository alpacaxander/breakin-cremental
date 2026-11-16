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
| **Bricks** | When a level starts, some standard bricks are randomly replaced by special bricks that do something when broken. Some nodes improve a special brick instead | Explosive Brick, Explosion Size, Explosion Damage, Shockwave, Gold Brick, Hourglass Brick, Hourglass Time, Hourglass Freeze |
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
                           │
                   [SplitterHealth]
```

- Only the drawn lines are connections. The scene `src/hub/web.tscn` is the source; this drawing follows it.
- The web is 5 columns × 6 rows, taller than the view at zoom 1: Splitter Health is reached by panning, or the view scrolls to it when it is selected.

Every node has one rank for now. Prices not listed are 10.

| Node | Category | Effect | Cost |
|---|---|---|---|
| Paddle Speed | Arena | +100% paddle speed | 5 |
| Paddle Size | Arena | +40% paddle length | 80 |
| Combo | Arena | Turns combos on | 30 |
| Combo Window | Arena | The combo's window is 1 s longer | 10 |
| Rear Paddle | Arena | The back wall's stretch opposite the paddle boosts a ball by 20% of base speed | 10 |
| Booster | Placeables | One Booster | 10 |
| Booster Speed | Placeables | A Booster adds 10% of base speed more | 530 |
| Zap | Placeables | One Zap | 270 |
| Zap Range | Placeables | A Zap reaches 2 more bricks each way (8 by default) | 10 |
| Zap Damage | Placeables | A Zap hits each brick once more | 10 |
| Splitter | Placeables | One Splitter | 110 |
| Splitter Splits | Placeables | A Splitter splits a ball into one more (2 by default) | 5000 |
| Splitter Health | Placeables | A Splitter takes one more hit, and splits the ball on each | 10 |
| Wall Segment | Placeables | One Wall Segment | 10 |
| Explosive Brick | Bricks | One explosive brick | 10 |
| Explosion Size | Bricks | Explosions reach one square further | 10 |
| Explosion Damage | Bricks | Explosions hit each brick once more | 10 |
| Shockwave | Bricks | Explosions throw balls | 10 |
| Gold Brick | Bricks | One gold brick | 10 |
| Hourglass Brick | Bricks | One hourglass brick | 20 |
| Hourglass Time | Bricks | An hourglass brick adds 5 s more | 1200 |
| Hourglass Freeze | Bricks | Breaking an hourglass brick holds the combo's window for 1 s | 10 |

- That is 22 nodes and 22 purchases, 7,382 coins in all.
- **The prices are first values, set by hand.** The balance bot has not played this web; its numbers in this file and in CLAUDE.md are from the old 15-node web. The Bumper is still a kind in the code but no node unlocks it.
- **Cost growth** is still set per node (a price is the first cost times the growth for every rank owned), for when nodes get more ranks.
- **The base values** are in `data/balance.tres`: the paddle moves 600 units a second and is 96 long, the ball moves 500 units a second, and a round lasts 20 s. A unit is a screen pixel on a 16-row level.

- **The text in the detail panel** is the "Each rank" wording, then, on a node that unlocks an item or changes one, a sentence on what it does. That sentence names no number that tuning may change, and the whole text has to fit the panel's two lines, about 80 characters.

## What the special bricks do

A special brick has 1 HP, whatever the brick it replaced had. What the placeables do is in [placeables.md](placeables.md#items).

| Brick | When it breaks |
|---|---|
| **Explosive** | Every brick within the blast takes 1 hit, and 1 more per rank of Explosion Damage. The blast reaches 1 square (4 columns, or 1 brick height) out from the brick's edges in every direction, and each rank of Explosion Size adds one more square, so the blast covers 26 brick cells around it, then 84, then 174. An explosive brick broken by a blast explodes too |
| **Gold** | It counts as 20 bricks in the round's tally |
| **Hourglass** | It adds 15 s to the timer, plus Hourglass Time. With Hourglass Freeze it holds a running combo's window |

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

- **The coin formula.** How the round's tally of bricks and combos turns into coins (see [overview.md](overview.md#coins)). The costs above move with it. For now it is the placeholder: 1 coin per brick, each combo's bricks times the multiplier that combo reached, a gold brick counting as 20.
- **Combo numbers.** The window length, how it shrinks, and the multiplier. The values now, in `data/balance.tres`: the window is 2.4 s, about as long as the ball's trip to the back of level 1 and home, and Combo Window adds 1 s; every 5 breaks add 1 to the multiplier; each step of the multiplier cuts the window to 0.8 of what it was, down to 0.1 s. So a combo of 20 has a 1.2 s window at rank 1, and past about 80 only a blast, a Zap or several balls keep it alive. With every upgrade a round's best combo is about 27 on level 1, 90 on level 2 and 175 on level 3, and the effects are at their biggest from 160 (see [art.md](../art.md#effects)). A cascade on level 3 can pass 300, which pays three times a usual round. These were measured when each brick paid the multiplier it broke at; a combo now pays all its bricks at the multiplier it reached, so combos pay more than this, and the bot has not measured it again.
- **The numbers were set with the balance bot and nobody has played them.** `tests/run.sh bot` plays the rules with a paddle that stands in for a person. Its average player finishes the demo in 33 to 65 rounds, 20 to 45 minutes, with 38 to 43 of the 44 ranks: about 40 rounds on the layouts kept in `tests/layouts/found.json`, about 60 with layouts it searches for as it buys items and never rearranges. With every rank it clears level 3 in 3 or 4 rounds of 10, and its good player in 4 to 8. Level 3 is where the bot is the weakest stand-in. The wall's face is 81 units from the paddle, so how a person copes with a ball that is back in a fifth of a second decides the level; where the items are decides it as much, and the bot cannot aim at the last few bricks.
