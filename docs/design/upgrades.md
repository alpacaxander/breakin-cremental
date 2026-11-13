# Upgrades

See also: [placeables.md](placeables.md), [physics.md](physics.md), [overview.md](overview.md).

## Rules

- Upgrades form a **web** that grows out from one seed node, **Paddle Speed** (the paddle starts slow). Each node unlocks once a connected node has been bought.
- An upgrade can have **one or more ranks**, each more expensive than the last.
- **Editable in Godot:** the web is laid out in its own scene. Each node sets:
  - its cost and growth
  - its maximum rank
  - its effect
  - which nodes it connects to

## Categories

| Category | What it does | Example ideas (placeholders) |
|---|---|---|
| **Placeables** | Items you unlock and then place in the arena during the Setup phase to help yourself. The three kinds and their rules are in [placeables.md](placeables.md) | Bumper, Wall segment, Ball splitter |
| **Bricks** | When a level starts, some standard bricks are randomly replaced by special bricks that do something when hit or destroyed | Explosive, Coin ×2, Hourglass (+time) |
| **Arena** | Changes the arena's base stats | Paddle size, Paddle speed, Ball speed, Round time +s, Combos |

## Counts come from ranks

Placeables and special bricks share one rule: the node that unlocks the item has ranks, and each rank adds one.

- **Placeables:** rank N lets you place N of that item.
- **Special bricks:** rank N replaces N random standard bricks with that brick type when the level starts. The bricks are picked again on every attempt, including a retry.

A count is the same on every level, so 2 explosive bricks matter far more among level 1's 24 bricks than among level 3's 512.

## Speed

The ball and the paddle both start slow, and upgrades speed them up. The ball's speed is constant during play; only upgrades and placeables change it (see [physics.md](physics.md#ball)).

## Web (example)

This web is a placeholder. The demo's real list of upgrades is an open question.

```
                         [Paddle Size ★★★]──[Combos ★★★]
                                │
   [Bumper ★★★]                 │       ARENA
       │                        │
   PLACEABLES ────────[ PADDLE SPEED ★★★ ]────[Round Time +2s ★★★★★]
       │                        │
   [Wall Segment ★★]            │       BRICKS
                         [Explosive Brick ★★★]──[Blast Size ★★]
                                │
                         [Hourglass Brick ★★]──[Hourglass Time ★★]

   ★ = one rank      ──  = connection; buying a node unlocks its neighbors
```

## Upgrade screen

```
┌─ UPGRADES ────────────────────────────── ● 142 ─┐
│                                                 │
│        (web view, pan/zoom)                     │
│                                                 │
├─────────────────────────────────────────────────┤
│ Explosive Brick    Rank 2/3                     │
│ 2 bricks become Explosive each attempt          │
│ Next rank: 23 ●                 [ BUY ]         │
├─────────────────────────────────────────────────┤
│ Level: [◄ 2 ►]  (3 locked)    [ PLAY LEVEL ▶ ]  │
└─────────────────────────────────────────────────┘
```

## Open questions

- **The initial upgrades.** Which nodes the demo has, and each one's cost, growth, maximum rank and effect per rank. This also decides which placeables, brick mods and special bricks exist.
- **The coin formula.** How the round's tally of bricks and combos turns into coins (see [overview.md](overview.md#coins)).
- **Combo numbers.** The window length, how it shrinks, and the multiplier. The implementation picks starting values and they are tuned later.
