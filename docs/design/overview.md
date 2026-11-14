# Overview

A horizontal Breakout game with roguelite progression. Each level is a short timed run that earns coins. Coins buy permanent upgrades.

See also: [levels.md](levels.md), [physics.md](physics.md), [placeables.md](placeables.md), [upgrades.md](upgrades.md).

## Flow

```
┌──────────────┐        ┌──────────────────────────────────────────┐
│  MAIN MENU   │        │               PLAY SCENE                 │
│              │  Play  │                                          │
│  > Play  ────┼───────►│   ┌──────────┐  pick unlocked level      │
│    Settings  │◄───────┼───┤ UPGRADES ├──────────────┐            │
│    Exit      │  back  │   │  (hub)   │◄─────────┐   ▼            │
└──────────────┘        │   └──────────┘   ┌──────┴──────────────┐ │
                        │                  │ LEVEL               │ │
                        │                  │ setup → play → summ.│ │
                        │                  │   ▲           retry │ │
                        │                  │   └───────────────┘ │ │
                        │                  └─────────────────────┘ │
                        └──────────────────────────────────────────┘
```

- **Main menu:** Play, Settings, Exit.
- **Settings:** the CRT filter toggle, the "reduce flashing" toggle, and volume sliders for music and sound.
- **Play scene:** you switch between two modes:
  - **Upgrades:** spend coins in the upgrade web, then choose an unlocked level to play.
  - **Level:** a single run, made up of the three phases below. From the Summary you either retry the level or return to Upgrades.
- **Going back:** a back button, or Esc, goes one step back: from Settings to the main menu, from Upgrades to the main menu, and from a level's Setup or Summary to Upgrades. During Play there is no way out; the round is short. Nothing is lost by leaving, because purchases and layouts are saved as they happen.

## Save data

There is one save slot. It holds:

- the coin balance
- the rank of each upgrade
- the highest level unlocked. Clearing the last level counts one past it, which is how the save knows the game is won
- each level's placed layout (see [placeables.md](placeables.md#rules))

Nothing else about a level in progress is saved. Settings are stored separately from the save slot.

## Level phases

```
     ┌───────────────────────── Retry ──────────────────────────┐
     ▼                                                          │
┌─────────┐  start   ┌──────────────┐  timer ends / last ball   ┌┴────────┐
│  SETUP  ├─────────►│  PLAY (20 s) ├──────────────────────────►│ SUMMARY │──► Upgrades
└─────────┘          └──────────────┘  lost / all bricks cleared└─────────┘
```

| Phase | What happens |
|---|---|
| **Setup** | The timer is stopped. The level's saved layout is already on the board, and you place, move or remove any unlocked placeables. Brick upgrades have already swapped some bricks for special bricks. The ball waits a little to the right of the paddle. Press Start to begin. |
| **Play** | The timer runs: 20 s base, extended by Arena upgrades and hourglass bricks. The round keeps a tally of the bricks broken, by type, and of the combos reached. The run ends when the timer reaches 0, when the last ball is lost, or when every brick is cleared. |
| **Summary** | Shows the tally (bricks broken by type, combos), the coins it pays, and whether the level was cleared. Two buttons: Retry goes back to Setup on the same level, and Upgrades returns to the hub. |

- **Ball loss** ends the run immediately and goes to Summary. With several balls, only losing the last one ends the run.
- **Clearing every brick** before time runs out unlocks the next level. Bricks the player placed don't count.
- **Special bricks are rolled again on every attempt**, including a retry.

## Coins

- Coins are calculated from the round's tally: the number and type of bricks broken, and the combos.
- The tally pays out however the run ends, so a ball drop or a timeout still pays for everything broken so far.
- The HUD shows the running coin total during Play.
- Bricks the player placed pay nothing.
- The formula is not decided yet. Until then, each brick pays 1 coin, multiplied by the combo multiplier at the moment it broke. A gold brick counts as 20 bricks.

## Replaying levels

You can replay any level you have unlocked. Later levels hold more bricks, so they happen to pay more coins; there is no other payout curve.
