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
| **Play** | The timer runs: 20 s base, extended by Arena upgrades and hourglass bricks. The round keeps a tally of the bricks broken, by type, and of the combos reached. The run ends when the timer reaches 0, when the last ball is lost, or when every brick is broken. |
| **Summary** | Shows the tally (bricks broken by type, hits that broke nothing, combos), the coins it pays, and whether the level was cleared. Two buttons: Retry goes back to Setup on the same level, and Upgrades returns to the hub. After a clear, Next takes Retry's place and opens the next level's Setup; the last level's clear keeps Retry. |

- **Ball loss** ends the run immediately and goes to Summary. With several balls, only losing the last one ends the run.
- **A clear** is a round whose score reaches the level's target (set per level, in [levels.md](levels.md)), however the round ends. It unlocks the next level. The score is the coins' points (see "Coins") before the end bonuses: the hits and bricks, the combos, the biggest chain and the longest rally. Reaching the target does not end the round. The HUD shows the score against the target.
- **Breaking every level brick** ends the round. It is not a clear by itself unless the score has reached the target. Bricks the player placed don't count.
- **Special bricks are rolled again on every attempt**, including a retry.

## Coins

- Coins are calculated from the round's tally: the hits on bricks, the number and type of bricks broken, and the combos.
- The tally pays out however the run ends, so a ball drop or a timeout still pays for everything broken so far.
- The HUD shows the running coin total during Play.
- Bricks the player placed pay nothing. The Summary leaves them out. Instead it counts, for each kind of placeable on the board, how many times the ball hit one: touching a free item, hitting a placed brick, or hitting a brick that carries a mod.
- The formula is not decided yet. Until then, every hit on a level brick scores 1 point (1 coin), whether or not it breaks it, and the hit that breaks a special brick scores its worth instead: a gold brick counts as 20. So a 1 HP brick scores 1 and a 2 HP brick 2. Only a break grows the combo and restarts its window, but a combo multiplies every point scored while it runs, hits that break nothing included, by the multiplier the combo reached, so a break that raises the multiplier raises it for the whole combo. The bonuses below that count bricks (chain, rally, bricks per paddle touch) count breaks only.
- Bonuses are added on top, as first values (the `_bonus` numbers in `data/balance.tres`, in brick points):
  - **Biggest chain:** 2 per level brick in the round's biggest explosion chain, which is everything one blast set off (not counting the explosive brick that started it).
  - **Longest rally:** 1 per level brick in the most broken between two paddle touches. The launch counts as a touch.
  - **Clear bonus:** 10% of the level's target, for a clear.
  - **Time left:** 2 per whole second left on the clock when every level brick is broken.
  - **First clear:** 50% of the level's target, the first time a level is cleared.
  - **Ball kept:** 3 when the round ends with a ball still in play (every brick broken, or a timeout).
  - **Efficiency:** bricks per paddle touch (level bricks broken ÷ paddle touches, the launch included) multiplies the whole score, bonuses included, when the round ends: nothing up to 10 bricks per touch, rising evenly to +10% at 100 and staying there. The Summary shows the ratio on this row.

## Replaying levels

You can replay any level you have unlocked. Later levels hold more bricks, so they happen to pay more coins; there is no other payout curve.
