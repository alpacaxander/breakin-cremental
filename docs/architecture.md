# Architecture

How the code is organised. This is meant to last through development, not only the demo. Names of files, signals and functions below are the starting point; change one when it turns out wrong, and update this file.

## Goal

The game grows in four ways: more levels, more upgrades, more placeables and more brick kinds. Adding one of these should mean adding a file, not editing a central script.

The purged build is the warning. Its `arena.gd` was 1,536 lines that held rules, drawing and effects together.

## Three layers

| Layer | Where | What it is |
|---|---|---|
| **Rules** | `src/sim/`, `src/kinds/` | Plain GDScript objects. No nodes, no drawing, no sound, no autoloads |
| **Screens** | `src/level/`, `src/hub/`, `src/menu/`, `src/ui/` | Nodes that draw the state of the rules and send them input |
| **Data** | `data/`, `levels/` | Godot resources and scenes, edited in the editor. Numbers live here, not in code |

Dependencies point one way: screens know the rules, and the rules know nothing about screens. Effects and sound listen to signals from the rules. The rules never call them and never wait for them.

Because the rules have no nodes, a round runs headless. Tests check the physics without a window, and a bot can play a level to check its difficulty (see [Tests](#tests)).

## The round

`Round` (`src/sim/round.gd`) is one attempt at a level. It owns the board grid, the balls, the paddle, the placed items, the combo, the timer and the tally.

- **Inputs.** A round is built from four things: the level's bricks, the saved layout, a snapshot of the stats, and a random seed. It reads nothing else, so the same four inputs and the same paddle input always give the same round.
- **Tick.** The level screen calls `round.step(delta)` from `_physics_process`, so the rules run on Godot's fixed tick. Collision is swept (see [physics.md](design/physics.md)), so the result doesn't depend on the tick rate.
- **Paddle input.** The level screen passes in a target position each tick. The round moves the paddle toward it at paddle speed.
- **Freeze on big hits.** The level screen owns the clock. To freeze, it skips `step` for a few frames. The rules don't know about it.
- **Random.** The round has its own seeded `RandomNumberGenerator`. It picks the special bricks with it.

### Signals

There is no global event bus. A round's events are signals on the `Round` object, and whoever holds the round connects to them:

| Signal | When |
|---|---|
| `brick_hit(cell, hp_left)` | A brick took a hit and is still there |
| `brick_broken(cell, kind, cause)` | A brick broke. The cause is a ball, a blast or a Zap |
| `ball_bounced(ball, surface)` | A ball bounced off a wall, the paddle or a placed item |
| `ball_added(ball)` / `ball_lost(ball)` | A Splitter made a ball, or a ball left through the open side |
| `exploded(position, radius)` | An explosive brick went off |
| `combo_changed(count, multiplier)` | The combo grew or reset |
| `time_changed(seconds_left)` | An hourglass brick added time |
| `ended(reason)` | The timer ran out, the last ball was lost, or the level was cleared |

Screens read continuous state, such as ball positions and the time left, straight from the round each frame.

## How content plugs in

| To add | You add | Why nothing else changes |
|---|---|---|
| A level | One scene in `levels/`: a painted `TileMapLayer`, plus its row count and name | The level screen reads the tiles into the board grid when it loads. The scene is only how a level is written down; it is not shown in the game |
| An upgrade | One `.tres` in `data/upgrades/`, and one node in the web scene | Game code asks for a stat value, never for a rank (see [Stats](#stats)) |
| A placeable or a brick kind | One script in `src/kinds/` and one `.tres` in `data/kinds/` | The round calls the kind's hooks. It has no branches per kind |

### Kinds

A kind is a `Resource`. The base scripts are `BrickKind` and `PlaceableKind`; each kind extends one of them, and its `.tres` holds its numbers (size, HP, colour meaning, amounts).

| Hook | Called when | Example |
|---|---|---|
| `on_ball_hit(round, ball, hit)` | A ball touches a placed item | The Booster adds a boost |
| `on_broken(round, cell, cause)` | The brick breaks | The explosive brick hits the bricks around it; the Splitter adds a ball |
| `on_host_broken(round, cell, cause)` | A brick with this mod on it breaks | Zap hits the rest of the row |

A hook changes the round through the round's own functions, such as `round.hit_brick(cell, cause)`, so chains work without special cases: an explosion that breaks an explosive brick calls that brick's hook too.

### Stats

Every upgrade changes one named stat. Game code only reads stats.

- **An upgrade** (`data/upgrades/*.tres`) holds its name, category, first cost, cost growth, maximum rank, the stat it changes and the amount per rank.
- **The base value** of each stat is in `data/balance.tres`.
- **`Progress.stat(name)`** returns the base value plus the amount for every rank owned. A percent amount is a share of the base value.
- **The level screen** takes a snapshot of all stats when a round starts and passes it to the round.

The demo's stats, one per node: `paddle_speed`, `paddle_size`, `ball_speed`, `round_time`, `combo_rank`, `blast_size`, `shockwave`, and a count for each kind (`bumper_count`, `booster_count`, `wall_segment_count`, `splitter_count`, `zap_count`, `explosive_count`, `gold_count`, `hourglass_count`).

The web scene (`src/hub/web.tscn`) holds only layout: where each node sits, which `.tres` it shows, and which nodes it connects to.

### Other numbers

- `data/balance.tres` also holds the numbers that are not stats: launch angle, minimum angles, the combo window, boost amounts and the boost cap.
- The coin formula is one function in `src/sim/coins.gd`. It turns a tally into coins.
- Colours are constants in `src/ui/palette.gd`, copied from [palette.md](palette.md). No other file contains a colour value.

## Scene tree

```
Main                     never unloaded
├─ Screen                holds MainMenu or Play
│   └─ Play
│       ├─ Hub           upgrade web, detail panel, level panel
│       └─ Level         setup → play → summary; freed when you leave
│           ├─ Arena     scaled by the level's zoom
│           │   ├─ BoardView     draws every brick in one _draw
│           │   ├─ PaddleView, BallViews, ItemViews
│           │   └─ Fx            particles, shockwaves, trails, pop-ups
│           ├─ Hud
│           ├─ SetupUi           tray, placement, Start
│           └─ Summary
├─ WorldEnvironment      bloom
└─ Crt                   one full-screen pass
```

- `Main` swaps the child of `Screen`. It doesn't use `change_scene_to_file`, so bloom, the CRT and the music are set up once.
- `Level` holds the phase as an enum (setup, play, summary) and a `match`. There is no state machine library.
- Bricks are not nodes. `BoardView` draws them from the board grid.

**Not verified yet:** whether the CRT pass can read the screen after bloom in Godot 4.7 with HDR 2D on. If it can't, the game renders into a `SubViewport` and the CRT shader runs on that. Either way the CRT stays one node under `Main`.

## Autoloads

| Autoload | Holds | Signals |
|---|---|---|
| `Progress` | The save slot: coins, upgrade ranks, highest level unlocked, each level's layout. Also `stat(name)`, `buy(upgrade)` and `save()` | `coins_changed`, `rank_changed(upgrade)` |
| `Settings` | CRT, reduce flashing, music volume, sound volume | `changed` |
| `Sfx` | `play(cue, pitch)` and the music loop (see [audio.md](audio.md)) | |

- The save is `user://save.json` with a `version` field, so a later build can read an older save. Settings are `user://settings.cfg`.
- `Progress` saves after every purchase, after every round and when a layout changes.
- Nothing in `src/sim/` or `src/kinds/` touches an autoload.

## File layout

```
project.godot
src/
  main.tscn  main.gd
  autoload/   progress.gd  settings.gd  sfx.gd
  sim/        round.gd  board.gd  ball.gd  paddle.gd  collide.gd
              combo.gd  tally.gd  coins.gd  layout.gd
  kinds/      brick_kind.gd  placeable_kind.gd  and one script per kind
  level/      level.tscn  board_view.gd  hud.tscn  setup_ui.tscn  summary.tscn  fx/
  hub/        hub.tscn  web.tscn  upgrade_node.tscn  detail_panel.tscn  level_panel.tscn
  menu/       main_menu.tscn  settings.tscn
  ui/         theme.tres  palette.gd
data/
  balance.tres
  upgrades/   one .tres per upgrade
  kinds/      one .tres per kind
levels/       level_1.tscn  level_2.tscn  level_3.tscn
assets/
  audio/      gen.mjs  demo.html  wav/
  fonts/      each font with its licence
  shaders/    crt.gdshader
tests/        test.gd  balance.gd  shots.gd
```

## Tests

| File | What it does |
|---|---|
| `tests/test.gd` | A headless self-check of the rules, made of plain asserts with no test framework. It covers the physics rules (constant speed, minimum angles, no tunnelling), the brick and hit counts of each level against [levels.md](design/levels.md), upgrade costs, the coin formula and a save round trip |
| `tests/balance.gd` | A bot plays each level headless at a given set of upgrade ranks and reports bricks broken, coins and whether it cleared. It is the tool for the difficulty risk in [design.md](design.md#risks) |
| `tests/shots.gd` | Renders each screen at 1280 × 720 under `xvfb-run` for the check in [art.md](art.md#checking-an-asset) |

## Left out on purpose

- An entity-component system
- A state machine library
- One node per brick
- A global event bus
- A general modifier system. The stat lookup is enough until an upgrade needs something it can't express.

## Build order

The folders are also how the work divides.

1. **Contracts first, by one author:** `project.godot`, the `Round` signals and public functions, the `Progress` API, the stat names, `balance.tres` and `palette.gd`.
2. **Then in parallel, each staying in its own folder:**
   - rules and `tests/test.gd` (`src/sim/`, `src/kinds/`)
   - the level screen (`src/level/`, without `fx/`)
   - the hub (`src/hub/`, `data/upgrades/`)
   - effects, bloom and the CRT (`src/level/fx/`, `assets/shaders/`)
   - audio (`assets/audio/`, `sfx.gd`)
   - menu, Settings and the save (`src/menu/`, `progress.gd`, `settings.gd`)
   - the three levels (`levels/`)
3. **Last:** `tests/balance.gd` and `tests/shots.gd`, then tuning.
