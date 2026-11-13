# Overview

A horizontal Breakout game with roguelite progression. Each level is a short timed run that earns coins. Coins buy permanent upgrades.

See also: [levels.md](levels.md), [upgrades.md](upgrades.md).

## Flow

```
┌──────────────┐        ┌──────────────────────────────────────────┐
│  MAIN MENU   │        │               PLAY SCENE                 │
│              │  Play  │                                          │
│  > Play  ────┼───────►│   ┌──────────┐  pick unlocked level      │
│    Settings  │        │   │ UPGRADES ├──────────────┐            │
│    Exit      │        │   │  (hub)   │◄─────────┐   ▼            │
└──────────────┘        │   └──────────┘   ┌──────┴──────────────┐ │
                        │                  │ LEVEL               │ │
                        │                  │ setup → play → summ.│ │
                        │                  └─────────────────────┘ │
                        └──────────────────────────────────────────┘
```

- **Main menu:** Play, Settings, Exit.
- **Play scene:** you switch between two modes:
  - **Upgrades:** spend coins in the upgrade web, then choose an unlocked level to play.
  - **Level:** a single run, made up of the three phases below. It always returns to Upgrades.

## Save data

There is one save slot. It holds:

- the coin balance
- the rank of each upgrade
- the highest level unlocked

Nothing about a level in progress is saved.

## Level phases

```
┌─────────┐  start   ┌──────────────┐  timer ends / ball lost /  ┌─────────┐
│  SETUP  ├─────────►│  PLAY (20 s) ├───────────────────────────►│ SUMMARY │──► Upgrades
└─────────┘          └──────────────┘  all bricks cleared        └─────────┘
```

| Phase | What happens |
|---|---|
| **Setup** | The timer is stopped. You place any unlocked placeables in the arena. Brick upgrades have already swapped some bricks for special bricks. Press Start to begin. |
| **Play** | The timer runs: 20 s base, extended by Arena upgrades and hourglass bricks. Each brick destroyed gives +1 coin, multiplied by the combo once combos are unlocked. The run ends when the timer reaches 0, when the ball is lost, or when every brick is cleared. |
| **Summary** | Shows coins earned and bricks destroyed, and whether the level was cleared. Returns to Upgrades. |

- **Ball loss** ends the run immediately and goes to Summary.
- **Clearing every brick** before time runs out unlocks the next level.
- Coins are added the moment a brick breaks, so you keep them however the run ends.

## Replaying levels

You can replay any level you have unlocked. Later levels hold more bricks, so they happen to pay more coins; there is no other payout curve.
