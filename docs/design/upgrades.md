# Upgrades

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
| **Placeables** | Items you unlock and then place in the arena during the Setup phase to help yourself | Bumper, Wall segment, Ball splitter |
| **Bricks** | When a level starts, some standard bricks are randomly replaced by special bricks that do something when hit or destroyed | Explosive, Coin ×2, Hourglass (+time) |
| **Arena** | Changes the arena's base stats | Paddle size, Paddle speed, Round time +s, Combos |

## Web (example)

```
                         [Paddle Size ★★★]──[Combos ★★★]
                                │
   [Bumper]──[Bumper Count ★★]  │       ARENA
       │                        │
   PLACEABLES ────────[ PADDLE SPEED ★★★ ]────[Round Time +2s ★★★★★]
       │                        │
   [Wall Segment]               │       BRICKS
                         [Explosive Brick]──[Explosive Chance ★★★]
                                │
                         [Hourglass Brick]──[Hourglass Time ★★]

   ★ = one rank      ──  = connection; buying a node unlocks its neighbors
```

## Upgrade screen

```
┌─ UPGRADES ────────────────────────────── ● 142 ─┐
│                                                 │
│        (web view, pan/zoom)                     │
│                                                 │
├─────────────────────────────────────────────────┤
│ Explosive Chance   Rank 2/3                     │
│ +5% of bricks become Explosive                  │
│ Next rank: 23 ●                 [ BUY ]         │
├─────────────────────────────────────────────────┤
│ Level: [◄ 2 ►]  (3 locked)    [ PLAY LEVEL ▶ ]  │
└─────────────────────────────────────────────────┘
```

## Open questions

- How many of each placeable can you place: a fixed count per type, or a number that its upgrade raises?
