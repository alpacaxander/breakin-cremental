# Architecture

How the code is organised. This is meant to last through development, not only the demo. The names of files, signals and functions below are the contract the code is built against; the doc comments in the files themselves give the details. Change a name when it turns out wrong, and update this file.

## Goal

The game grows in four ways: more levels, more upgrades, more placeables and more brick kinds. Adding one of these should mean adding a file, not editing a central script.

The purged build is the warning. Its `arena.gd` was 1,536 lines that held rules, drawing and effects together.

## Three layers

| Layer | Where | What it is |
|---|---|---|
| **Rules** | `src/sim/`, `src/kinds/` | Plain GDScript objects. No nodes, no drawing, no sound, no autoloads |
| **Screens** | `src/level/`, `src/hub/`, `src/menu/`, `src/ui/`, `src/main.gd`, `src/play.gd` | Nodes that draw the state of the rules and send them input |
| **Data** | `data/`, `levels/` | Godot resources and scenes, edited in the editor. Numbers live here, not in code |

`src/content/` sits between data and the rest: it finds the level and upgrade files and reads them. `src/autoload/` holds the three autoloads.

Dependencies point one way: screens know the rules, and the rules know nothing about screens. Effects and sound listen to signals from the rules. The rules never call them and never wait for them.

Because the rules have no nodes, a round runs headless. Tests check the physics without a window, and a bot can play a level to check its difficulty (see [Tests](#tests)).

`tests/cases/layers.gd` holds two of these rules: nothing under `src/sim/` or `src/kinds/` extends Node or names an autoload or a screen class, and no file but `src/ui/palette.gd` contains a colour literal.

## The round

`Round` (`src/sim/round.gd`) is one attempt at a level. It owns the board grid, the balls, the paddle, the placed items, the combo, the timer and the tally. Its doc comment gives the order of everything that happens when a round is built, in one step and on one brick hit.

- **Inputs.** `Round.new(board, layout, stats, seed)`. A round is built from four things: the level's bricks (a `Board`), the saved `Layout`, a snapshot of the stats (a `Balance`), and a random seed. It reads nothing else, so the same four inputs and the same paddle input always give the same round.
- **Tick.** The level screen calls `round.step(delta, paddle_target)` from `_physics_process`, so the rules run on Godot's fixed tick, 120 a second. Collision is swept (see [physics.md](design/physics.md)), so the result doesn't depend on the tick rate.
- **Paddle input.** `paddle_target` is where the paddle's centre should go, in round units. The round moves the paddle toward it at paddle speed. A held key passes `-INF` or `INF`.
- **Freeze on big hits.** The level screen owns the clock. To freeze, it skips `step`. The effects ask for a freeze through `Fx.frozen` (see [Scene tree](#scene-tree)). The rules don't know about it.
- **Random.** The round has its own seeded `RandomNumberGenerator`. It picks the special bricks with it, before the layout is applied, so the same seed gives the same special bricks whatever the layout. Setup shows a round, and Start builds it again with the same seed and the final layout.

### Units and cells

`Board` (`src/sim/board.gd`) defines the space every rule and every view uses.

- **Round units.** One unit is one screen pixel on a 16-row level. The sizes in [art.md](art.md#level-screen) are the sizes in units at every level size. Speeds are units per second.
- **Origin.** `(0, 0)` is the top left corner of the grid; x grows toward the back wall and y grows downward. The paddle lane is at negative x: the open side is the line `x = -board.lane()`.
- **To the screen.** The level screen's `Arena` node sits at `(154, 110)` with scale `board.zoom()` (16 ÷ rows) and its children draw in units, so `screen = (154, 110) + units × zoom`. The lane is 58 screen pixels at every level size, which is `58 ÷ zoom` units.
- **Brick cells.** A brick always starts on an even grid row, so bricks are addressed by brick cell: `Vector2i(column, brick row)`, a 16 × 64 unit rectangle. Brick row `r` covers grid rows `2r` and `2r + 1`. Every `cell` in a signal, a hook or a saved layout is a brick cell.
- **A row**, for a Zap, is every brick cell with the same brick row.
- **A blast** reaches `blast_size × 64` units out from the edges of the brick that exploded, and hits every brick whose cell overlaps that rectangle. At the base size that is 4 columns to each side and 1 brick row above and below.

### Signals

There is no global event bus. A round's events are signals on the `Round` object, and whoever holds the round connects to them:

| Signal | When |
|---|---|
| `brick_hit(cell, hp_left, cause)` | A brick took a hit and is still there |
| `brick_broken(cell, brick, cause, dir, coins)` | A brick broke. `brick` is the brick as it was (its kind, mod and `placed`), `dir` is the direction for the debris, `coins` is what this break paid |
| `ball_bounced(ball, hit)` | A ball bounced off a wall, the paddle or a placed item. `hit` (`src/sim/hit.gd`) says which, where, and the surface normal |
| `ball_added(ball)` / `ball_lost(ball)` | A Splitter made a ball, or a ball left through the open side |
| `exploded(pos, reach, cells)` | An explosive brick went off. `cells` are the bricks it is about to hit, still on the board |
| `combo_changed(count, multiplier)` | The combo grew or reset |
| `time_changed(seconds_left, added)` | An hourglass brick added time |
| `ended(reason)` | The timer ran out, the last ball was lost, or the level was cleared |

The cause of a hit is `Round.Cause.BALL`, `BLAST` or `ZAP`. Screens read continuous state, such as ball positions, the combo's window and the time left, straight from the round each frame.

## How content plugs in

| To add | You add | Why nothing else changes |
|---|---|---|
| A level | The next scene in `levels/`, `level_<n>.tscn` | `Levels.read(n)` (`src/content/levels.gd`) turns the scene into a `LevelData`: number, title and a `Board`. The level screen, the hub's thumbnail, the tests and the bot all go through it. The scene is only how a level is written down; it is not shown in the game |
| An upgrade | One `.tres` in `data/upgrades/`, and one node in the web scene | The file name is the upgrade's id. Game code asks for a stat value, never for a rank (see [Stats](#stats)) |
| A placeable or a brick kind | One script in `src/kinds/` and one `.tres` in `data/kinds/` | The file name is the kind's id, and `Kinds` (`src/kinds/kinds.gd`) finds it. The round calls the kind's hooks and has no branches per kind; the views draw it from its fields; `Sfx` plays its cue |

### Kinds

A kind is a `Resource`. `Kind` is the base, with the id, the title, the colour meaning, the cue and the hooks. `BrickKind` and `PlaceableKind` extend it; each kind extends one of them, and its `.tres` holds its numbers.

| Hook | Called when | Example |
|---|---|---|
| `on_ball_hit(round, ball, hit)` | A ball has bounced off a placed item | The Booster adds a boost |
| `on_broken(round, cell, brick, cause, ball)` | The brick broke | The explosive brick calls `round.blast`; the Splitter adds a ball |
| `on_host_broken(round, cell, brick, cause, ball)` | A brick with this mod on it broke | Zap hits the rest of the row |

A hook changes the round through the round's own functions (`hit_brick`, `blast`, `add_ball`, `set_boost`, `add_time`), so chains work without special cases: an explosion that breaks an explosive brick calls that brick's hook too.

The demo's kinds. The id is the file name in `data/kinds/`, and `<id>_count` is the stat that counts it:

| Id | Base | Shape and size (units) | Colour | Cue | Its own numbers |
|---|---|---|---|---|---|
| `bumper` | PlaceableKind, FREE | RECT 30 × 30, turn 45 | `placeable` | `bumper` | |
| `booster` | PlaceableKind, FREE | CIRCLE, 32 across | `placeable` | `booster` | Adds 0.25 to the ball's boost |
| `wall_segment` | PlaceableKind, FREE, rotatable | RECT 10 × 112 | `placeable` | `wall_bounce` | |
| `splitter` | PlaceableKind, BRICK | A brick cell, 1 HP | `placeable` | `splitter` | |
| `zap` | PlaceableKind, MOD | A 6 × 6 mark | `placeable` | `zap` | |
| `explosive` | BrickKind | 1 HP | `explosive` | none (`exploded` has its own) | Reach comes from the `blast_size` stat |
| `gold` | BrickKind | 1 HP, worth 5 | `coins` | `gold_brick` | |
| `hourglass` | BrickKind | 1 HP | `time` | `hourglass_brick` | Adds 2 s |

`order` runs 1 to 5 down the placeables and 1 to 3 down the bricks; it is the tray order and the order special bricks are rolled in.

### Stats

Every upgrade changes one named stat. Game code only reads stats.

- **An upgrade** (`data/upgrades/*.tres`, script `src/content/upgrade.gd`) holds its title, category, effect text, first cost, cost growth, maximum rank, the stat it changes, the amount per rank, and whether the amount is a percent. `upgrade.cost(owned)` is the price of the next rank.
- **The base value** of each stat is in `data/balance.tres` (script `src/sim/balance.gd`, class `Balance`), as a typed property.
- **`Progress.stat(name)`** returns the base value plus the amount for every rank owned. A percent amount is a share of the base value.
- **`Progress.snapshot()`** returns a `Balance`: a copy of `balance.tres` with every stat replaced by `stat()`. The level screen takes one when a round starts and passes it to the round, so rules code reads `stats.ball_speed` and gets the upgraded value.
- **Counts** have no property. The stat `<kind id>_count` lives in `Balance.extra`, is 0 when missing, and is read with `stats.count(kind_id)`. So a new kind needs no change to `Balance`.

The demo's upgrades. The id is the file name in `data/upgrades/`:

| Id | Stat | Amount per rank |
|---|---|---|
| `paddle_speed` | `paddle_speed` | 20% |
| `ball_speed` | `ball_speed` | 15% |
| `paddle_size` | `paddle_size` | 15% |
| `round_time` | `round_time` | 3 |
| `combo` | `combo_rank` | 1 |
| `blast_size` | `blast_size` | 0.5 |
| `shockwave` | `shockwave` | 1 |
| `bumper`, `booster`, `wall_segment`, `splitter`, `zap` | `<id>_count` | 1 |
| `explosive_brick`, `gold_brick`, `hourglass_brick` | `explosive_count`, `gold_count`, `hourglass_count` | 1 |

The web scene (`src/hub/web.tscn`) holds only layout: where each node sits, which `.tres` it shows, and which nodes it connects to. Whether a node can be reached yet is the hub's question; `Progress.buy` checks only the price and the maximum rank.

### Other numbers

- `data/balance.tres` also holds the numbers that are not stats: ball and paddle sizes, the launch gap, the minimum angles, the paddle's steepest angle, the boost cap, the combo numbers, the low-timer mark, coins per brick and the rotation step. The defaults in `balance.gd` are 0, so a number can only come from the file. A kind's own amounts are in its `.tres`.
- The coin formula is one function, `Coins.total(tally, stats)` in `src/sim/coins.gd`. It turns a tally into coins.
- Colours are constants in `src/ui/palette.gd`, copied from [palette.md](palette.md). No other file contains a colour value, scenes and resources included: a script assigns the colour.

## Scene tree

```
Main                         never unloaded (src/main.tscn)
├─ View                      SubViewport, HDR 2D. The whole game draws in here at 1280 × 720
│   ├─ Backdrop              the base colour
│   ├─ Screen                holds MainMenu, Settings or Play; carries the theme
│   │   └─ Play              src/play.tscn
│   │       ├─ Hub           upgrade web, detail panel, level panel; kept while a level is open
│   │       └─ Level         setup → play → summary; freed when you leave
│   │           ├─ Arena     at (154, 110), scaled by the level's zoom
│   │           │   ├─ BoardView     draws every brick in one _draw
│   │           │   ├─ PaddleView, BallViews, ItemViews
│   │           │   └─ Fx            particles, shockwaves, trails, pop-ups (src/level/fx/fx.gd)
│   │           ├─ Hud
│   │           ├─ SetupUi           tray, placement, Start
│   │           └─ Summary
│   └─ WorldEnvironment      bloom
└─ Crt                       shows View through the CRT shader
```

- **Navigation.** Screens call `Main.show_menu()`, `Main.show_settings()`, `Main.show_hub()`, `Main.show_level(n)` and `Main.quit()`. `Main` swaps the child of `Screen` and `Play` switches between the hub and a level. Nothing uses `change_scene_to_file`, so bloom, the CRT and the music are set up once. `Main.show_level(n)` returns the level scene's root.
- **Back.** Every screen but the main menu has a back icon button and handles `ui_cancel` (Esc) itself: Settings and the hub go to the main menu, and a level in Setup or in the Summary goes to the hub. During Play there is no way out. A handler marks the event handled (`get_viewport().set_input_as_handled()`) before it navigates, or the screen it wakes gets the same Esc.
- **Entry scenes.** Each screen lane owns one or two scenes at fixed paths: `src/menu/main_menu.tscn`, `src/menu/settings.tscn`, `src/hub/hub.tscn` and `src/level/level.tscn`. Each root is a full-rect `Control`.
- **The level's root** has four members, written out in `src/play.gd`: `level: int`, which `Play` sets before the scene enters the tree; `round`, the round on screen; `fx`, its `Fx` node; and `start(seed := -1)`, which does what the Start button does, with a fixed seed if one is given. Tests, shots and the effects drive the real level screen through them.
- `Level` holds the phase as an enum (setup, play, summary) and a `match`. There is no state machine library.
- Bricks are not nodes. `BoardView` draws them from the board grid.
- **The seam between the level screen and the effects** is written at the top of `src/level/fx/fx.gd`: where the `Fx` node sits, `watch(round)` and `clear()`, the `frozen` flag, the `shake` offset, and the z order. `z_index` sorts across the whole canvas layer, so the numbers are shared: what the level screen draws in `Arena` is at 0, 10 and 20, `Fx` uses 1 to 99, and `Hud`, `SetupUi` and `Summary` are at 100.

### Input

The input map has four actions. Everything else is the mouse and Godot's built-in `ui_*` actions.

| Action | Keys |
|---|---|
| `paddle_up` | W, Up |
| `paddle_down` | S, Down |
| `rotate_ccw` | Q, wheel up |
| `rotate_cw` | E, wheel down |

A wheel notch is pressed and released within one frame, so read the rotate actions from the event (`event.is_action_pressed`), not by polling. One press turns the item by `rotate_step` degrees. The paddle chases the mouse's y inside `Arena`, which is already in round units.

## Rendering

A render spike settled this in Godot 4.7.2 before any screen was built.

- **Renderer:** Forward+. The Compatibility renderer gave wrong colours with this chain.
- **The chain.** The game draws into `View`, a `SubViewport` with HDR 2D on and a `WorldEnvironment` whose glow is the bloom. `Crt`, a `TextureRect` under `Main`, shows `View`'s picture through `assets/shaders/crt.gdshader`. HDR 2D is on for `View` only, never in the project settings, so a screenshot of the window is exactly what is on screen.
- **The Crt pass always runs.** `View`'s picture is linear and holds values over 1. The shader brings them back into range without changing their hue and converts to sRGB; with the CRT setting off it does only that. The setting switches the shader's `enabled` flag. Never hide `Crt` or remove its material.
- **Lit colours.** A lit thing is drawn in `Palette.lit(colour)`, which multiplies the colour in linear light so it lands over the bloom threshold. Anything not passed through it keeps its palette value and does not glow: every neutral reads back pixel-exact. `Palette` names the boosts: 4 for shapes and big numbers, 12 for the ball, 8 for small lit text, 2 for a lit fill under dark text.
- **What a lit colour looks like.** On screen it is the full-brightness version of its hue. Cyan, gold, orange, red and white come out exact. The others come out brighter than their hex: 1 HP `ca52c9` shows as `ff6afe`, blue as `00b1ff`, green as `aaff6a`. So [art.md](art.md#checking-an-asset)'s colour check holds for unlit colours only.
- **Bloom strength.** `glow_intensity` is 0.06 at rest. Effects raise it with the combo through `Main.set_bloom(0..1)`, up to 0.18; from about 0.2 the 2 px gaps between bricks fill in. Reduce flashing lowers the top to 0.09.
- **Resolution.** `Main` resizes `View` to the window's real pixels and keeps 1280 × 720 coordinates inside, so text is sharp at any window size, and it shifts the glow levels so halos keep their size.
- **Input.** `View` gets no input by itself. `Main` pushes every event into it, with mouse positions moved the way the shader curves the picture, so a click lands on what is drawn under it. Code inside `View` reads the mouse as usual.
- **Stay on canvas layer 0.** Anything on a `CanvasLayer` above 0 inside `View` is drawn after bloom and does not glow. Pop-ups and tooltips are embedded in `View`, so they get the CRT too.
- **Limits.** Thin lit shapes need more boost than thick ones. A lit hue drawn without `lit()` still glows faintly as a large shape if its largest channel is near `ff`. Halo size is close across window sizes, not equal.
- **Screenshots can be trusted** for colour, bloom and the CRT: the same frame on a real GPU and under `xvfb-run` differed by at most 6 in 255. They say nothing about frame rate, the letterbox bars, or how the pixel fonts land at window sizes that are not a whole multiple of 720.

## Autoloads

| Autoload | Holds | Signals |
|---|---|---|
| `Progress` | The save slot: coins, upgrade ranks, highest level unlocked, each level's layout. Also `upgrades()`, `rank`, `cost`, `can_buy`, `buy`, `stat(name)`, `snapshot()`, `is_unlocked`, `finish_round`, `layout`, `set_layout` and `save()`. `level_count` is the number of levels, which a test may set | `coins_changed(coins)`, `rank_changed(upgrade)`, `level_unlocked(level)` |
| `Settings` | CRT, reduce flashing, music volume, sound volume. It also sets the two bus volumes | `changed` |
| `Sfx` | A constant for every cue, `play(cue, pitch)`, `start_music()`, and `connect_round(round)`, which wires a round's signals to their cues so no scene holds audio glue (see [audio.md](audio.md)). It also plays the click of every button itself, by listening for buttons entering the tree, except those in the group `Sfx.QUIET`; the header of `sfx.gd` says which screen plays each other UI cue | |

- The save is `user://save.json` with a `version` field, so a later build can read an older save. Its shape is written at the top of `src/autoload/progress.gd`. Settings are `user://settings.cfg`.
- `user://` is `~/.local/share/breakin-cremental/` on Linux (a custom user dir), so the purged build's files under `godot/app_userdata/` are never read.
- `Progress` saves after every purchase, after every round and when a layout changes.
- `Progress.use(path)` and `Settings.use(path)` switch to another file. Tests and the screenshot harness call them, so they never touch the player's files.
- Audio buses (`default_bus_layout.tres`): `Music` and `Sfx` feed `Master`, which has a limiter.
- Nothing in `src/sim/` or `src/kinds/` touches an autoload.

## File layout

```
project.godot  default_bus_layout.tres
src/
  main.tscn  main.gd      the render chain and navigation
  play.tscn  play.gd      the Hub and Level switch
  autoload/   progress.gd  settings.gd  sfx.gd
  sim/        round.gd  board.gd  brick.gd  ball.gd  paddle.gd  hit.gd  collide.gd
              combo.gd  tally.gd  coins.gd  layout.gd  balance.gd
  kinds/      kind.gd  brick_kind.gd  placeable_kind.gd  kinds.gd  and one script per kind
  content/    levels.gd  level_data.gd  upgrade.gd
  level/      level.tscn  board_view.gd  hud.tscn  setup_ui.tscn  summary.tscn
              fx/fx.gd
  hub/        hub.tscn  web.tscn  upgrade_node.tscn  detail_panel.tscn  level_panel.tscn
  menu/       main_menu.tscn  settings.tscn
  ui/         palette.gd  theme.gd  shared widgets
data/
  balance.tres
  upgrades/   one .tres per upgrade
  kinds/      one .tres per kind
levels/       level_1.tscn  level_2.tscn  level_3.tscn
assets/
  audio/      gen.mjs  demo.html  wav/
  fonts/      each font with its licence
  shaders/    crt.gdshader
tests/
  run.sh                  every command below
  test.gd  test.tscn      the headless runner
  cases/                  one case file per lane
  shots.gd  shots.tscn    the screenshot harness
  shots/                  one shot list per lane
  balance.gd              the bot
  out/                    what tests write; ignored by git and by Godot
```

The theme is built in code (`UiTheme.build()` in `src/ui/theme.gd`), because a theme saved with colours in it would be a second place that defines them. `build()` always returns the same `Theme`, and `Main` puts it on `Screen`. A theme only passes down through `Control` nodes, so text under a `Node2D` (the effects' pop-ups) takes its font from `UiTheme.numbers()` and its size from `UiTheme.number_size(px)`. The top of `theme.gd` lists the type variations and shared widgets by name.

Godot's generated `.import` and `.uid` files are committed. `.godot/` is not. Folders that are still empty (`data/kinds/`, `data/upgrades/`, `levels/`, `assets/audio/`) appear with their first file.

## Tests

Everything runs through `tests/run.sh`, which moves `user://` inside the checkout (`tests/out/user`), so worktrees running at the same time share nothing. Tests and shots are scenes, not `godot -s` scripts, because a `-s` script cannot see the autoloads.

| Command | What it does |
|---|---|
| `tests/run.sh import` | Imports assets. Needed once in a new checkout and after adding files |
| `tests/run.sh test [case…]` | The headless self-check: plain checks with no test framework. It runs every file in `tests/cases/`, prints `ok` or `FAIL` lines and exits 1 on a failure. A Godot error while a case runs fails the case |
| `tests/run.sh boot` | Runs the main scene headless for 5 seconds and fails on any error |
| `tests/run.sh shots [list…]` | Boots the real `Main` under `xvfb-run` and saves PNGs to `tests/out/shots/<list>/`, bloom and CRT included. Each file in `tests/shots/` is a list of shots; a shot can start from a fresh, mid-game or maxed save and can capture a strip of frames |
| `tests/run.sh bot [args…]` | `tests/balance.tscn`: a bot plays each level headless at a given set of upgrade ranks and reports bricks broken, coins and whether it cleared. It is the tool for the difficulty risk in [design.md](design.md#risks) |

A lane adds its own `tests/cases/<lane>.gd` and `tests/shots/<lane>.gd` and never edits another's. All the cases run in one process, so the runner gives each a fresh save, the default settings and only the kinds that have files (`Kinds.reset()`), whatever the case before it did. The cases cover the physics rules (constant speed, minimum angles, no tunnelling), the brick and hit counts of each level against [levels.md](design/levels.md), upgrade costs, the coin formula, a save round trip, and the layer rules. The shots are for the check in [art.md](art.md#checking-an-asset).

## Left out on purpose

- An entity-component system
- A state machine library
- One node per brick
- A global event bus
- A general modifier system. The stat lookup is enough until an upgrade needs something it can't express.

## Build order

The folders are also how the work divides. A lane writes only in its own folders, plus its own case file and shot list under `tests/`.

1. **Contracts, by one author.** A render spike first. Then the project skeleton and every interface: `project.godot`, the bus layout, `src/main.*`, `src/play.*`, `palette.gd`, `balance.tres`, the resource scripts, the test runner and the screenshot harness, a stub with the full API for every file in the rules, the autoloads, `levels.gd`, `theme.gd` and `fx.gd`, and a placeholder at each screen's entry scene. A file whose header says STUB is filled in by the lane that owns its folder. The other contract files are finished: a lane may add to one inside its own folders, but what it already names stays as it is, and a lane never edits a file outside its folders.
2. **Foundations, in parallel:**

   | Lane | Owns | Case and shots |
   |---|---|---|
   | Rules | `src/sim/`, `src/kinds/`, `data/kinds/` | `rules` |
   | State | `src/autoload/progress.gd`, `src/autoload/settings.gd`, `data/upgrades/` | `state` |
   | Levels | `levels/`, `src/content/levels.gd` | `levels` |
   | Audio | `assets/audio/`, `src/autoload/sfx.gd` | `audio` |
   | UI kit | `src/ui/` except `palette.gd`, and the import settings of `assets/fonts/` | `ui` |

3. **Screens, in parallel, on the finished rules:**

   | Lane | Owns | Case and shots |
   |---|---|---|
   | Level screen | `src/level/` except `fx/` | `level` |
   | Hub | `src/hub/` | `hub` |
   | Menu and Settings | `src/menu/` | `menu` |
   | Balance bot | `tests/balance.gd`, `tests/balance.tscn` | |

4. **Feel:** the effects, in `src/level/fx/` (`fx`).
5. **An audit** against the docs, with fixes.
6. **Tuning**, which changes only files under `data/`.

The screens wait for the rules so a screen lane can render a real board and check its own work.

Three rules keep parallel lanes from colliding:

- **A lane's case passes in its own worktree,** where the files of the lanes beside it are still stubs, and it still passes after the merge. Where a contract leans on another lane's stub, its header says how to test without it (`Progress.level_count`, the raw `Progress.layouts`, emitting a stub round's signals by hand).
- **Class names are global.** A script gets a `class_name` only when another file has to name the type. The screen lanes can't see each other, so theirs start with `Level`, `Hub` or `Menu`. No class is named after an autoload.
- **Shared files have no owner.** `project.godot`, `data/balance.tres`, `src/main.*`, `src/play.*`, `src/ui/palette.gd`, the resource scripts in `src/content/` other than `levels.gd`, the test runner and the docs are changed only between steps. A lane that needs a change there says so in its report.
