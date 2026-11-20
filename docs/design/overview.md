# Overview

A horizontal Breakout game with roguelite progression. Each level is a short timed run that earns coins. Coins buy permanent upgrades.

See also: [levels.md](levels.md), [physics.md](physics.md), [placeables.md](placeables.md), [upgrades.md](upgrades.md).

## Flow

```
┌──────────────┐        ┌──────────────────────────────────────────┐
│  MAIN MENU   │        │               PLAY SCENE                 │
│              │  Play  │                      latest unlocked     │
│  > Play  ────┼───────►├──────────────────────────────────┐       │
│    Settings  │◄───────┼───┬──────────┐  pick unlocked    │       │
│    Exit      │  back  │   │ UPGRADES ├──────────────┐    │       │
│              │        │   │  (hub)   │◄─────────┐   ▼    ▼       │
└──────────────┘        │   └──────────┘   ┌──────┴──────────────┐ │
                        │                  │ LEVEL               │ │
                        │                  │ setup → play → summ.│ │
                        │                  │   ▲           retry │ │
                        │                  │   └───────────────┘ │ │
                        │                  └─────────────────────┘ │
                        └──────────────────────────────────────────┘
```

- **Main menu:** Play, Settings, Exit. Play opens the Setup of the highest level unlocked (the last level once every level is cleared); going back from there reaches Upgrades.
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
└─────────┘          └──────────────┘  lost / all bricks broken └─────────┘
```

| Phase | What happens |
|---|---|
| **Setup** | The timer is stopped. The level's saved layout is already on the board, and you place, move or remove any unlocked placeables. Brick upgrades have already swapped some bricks for special bricks. The ball waits 8 bricks to the right of the paddle, at the arena's vertical centre, and stays there until Start; the keys move the paddle. Press Start to begin. |
| **Play** | The timer runs: 20 s base, extended by Arena upgrades and hourglass bricks. The round keeps a tally of the bricks broken, by type, and of the combos reached. The run ends when the timer reaches 0, when the last ball is lost with no spare left, or when every brick is broken. |
| **Summary** | Shows the tally (bricks broken by type, hits that broke nothing, combos), the coins it pays, and whether the level was cleared. Two buttons: Retry goes back to Setup on the same level, and Upgrades returns to the hub. After a clear, Next takes Retry's place and opens the next level's Setup; the last level's clear keeps Retry. |

- **Ball loss** ends the run immediately and goes to Summary. With several balls, only losing the last one ends the run.
- **A clear** is a round whose score reaches the level's target (set per level, in [levels.md](levels.md)), however the round ends. It unlocks the next level. The score is the coins' points (see "Coins"): the hits and bricks and the combos. Reaching the target does not end the round. The HUD shows the score against the target.
- **Breaking every level brick** ends the round. It is not a clear by itself unless the score has reached the target. Bricks the player placed don't count. With Overgrowth broken bricks come back after 8 s, but the round does not wait for them: breaking the last one standing still ends it.
- **Special bricks are rolled again on every attempt**, including a retry.

## Coins

- Coins are calculated from the round's tally: the hits on bricks, the number and type of bricks broken, and the combos.
- The tally pays out however the run ends, so a ball drop or a timeout still pays for everything broken so far.
- The HUD shows the running coin total during Play.
- Bricks the player placed pay nothing. The Summary leaves them and the other placeables out: it lists only what paid.
- The formula is not decided yet. Until then, every hit on a level brick scores 1 point (1 coin), whether or not it breaks it, and the hit that breaks a special brick scores its worth instead: a gold brick counts as 20. So a 1 HP brick scores 1 and a 2 HP brick 2. Every such hit grows the combo and restarts its window, as a break does; a hit on a placed brick grows it only when it breaks it, and a hit on a block that never breaks (Growth, Refresh) never does. A combo multiplies every point scored while it runs by the multiplier the combo reached, so a hit that raises the multiplier raises it for the whole combo.
- There are no end-of-round bonuses: the round pays its hits, its bricks and its combos, nothing more.

## Replaying levels

You can replay any level you have unlocked. Later levels hold more bricks, so they happen to pay more coins; there is no other payout curve.
