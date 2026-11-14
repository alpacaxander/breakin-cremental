# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

BreakIn cremental: a horizontal breakout incremental game in Godot 4.7 (GDScript). Before each timed round you place items on a hand-made level, then play it to earn coins; coins buy nodes in an upgrade web. The pitch, core loop, demo scope, open questions and risks are in `docs/design.md`.

**Current state: playable, with effects, tuned by the bot and not yet by hand.** The repo was purged on 2026-11-12 (commit `1aa951b`) and the demo described in `docs/design.md` is being rebuilt from the docs, in the steps of `docs/architecture.md` ("Build order"). All six steps are done: the last was tuning the numbers with the balance bot. What exists: the project skeleton, the render chain with bloom and the CRT (`src/main.*`), navigation and the palette; the rules (`src/sim/`: a `Round` that runs headless, with swept collision) and the eight kinds (`src/kinds/`, `data/kinds/`); the save, the settings and the fifteen upgrades (`src/autoload/progress.gd`, `src/autoload/settings.gd`, `data/upgrades/`); the three levels and their reader (`levels/`, `src/content/levels.gd`); the synthesised cues, the placeholder music and `Sfx` (`assets/audio/`, `src/autoload/sfx.gd`); the theme and shared widgets (`src/ui/`); and every screen: the main menu and Settings (`src/menu/`), the upgrade screen (`src/hub/`) and the level screen with Setup, Play and the Summary (`src/level/`). The game can be played from the menu through a level and back, and `tests/cases/loop.gd` walks that whole loop with input events. There is a balance bot (`tests/balance.gd`). The effects (`src/level/fx/fx.gd`) decorate a round: squares, shockwaves, light pools, the trail, pop-ups, shake, freezes, and bloom that climbs with the combo. The numbers under `data/`, the brick HP of levels 1 and 3 and the effects' `COMBO_TOP` are tuned by the bot and not yet by hand: a first round on level 1 pays about 8 coins, and the bot's average player clears level 1 around round 16, level 2 around round 27 and level 3, the end of the demo, between rounds 33 and 65, 20 to 45 minutes in, depending on where the items are (the good player between rounds 35 and 59, the clumsy one between 49 and 82). The bot is the weakest stand-in on level 3 and for the Bumper, Booster, Wall Segment and Shockwave, which measure as nothing for it (`docs/design/upgrades.md`). The effects' strengths and timings are first values that have been checked in still frames and never felt in motion. Nobody has played it by hand or listened to the audio.

## Commands

Godot, xvfb-run and Node are not on PATH. They come from the Nix dev shell. `tests/run.sh` enters it by itself; for anything else run `nix develop`, or prefix the command with `nix develop -c`.

```sh
tests/run.sh import           # import assets: once in a new checkout, and after adding files
tests/run.sh test             # headless self-check: "ok" or FAIL lines, exit 1 on a failure
tests/run.sh test rules       # only tests/cases/rules.gd
tests/run.sh boot             # the main scene, headless, for 5 seconds; fails on any error
tests/run.sh shots            # screenshots of the real game, bloom and CRT included, to tests/out/shots/
tests/run.sh shots hub fx     # only those shot lists
tests/run.sh bot              # the balance bot's report: every level fresh and maxed, then a campaign (minutes)
tests/run.sh bot check        # the bot's own self-check, 2 seconds
tests/run.sh bot batch level=1 ranks=fresh skill=all seeds=20 layout=empty   # one table; keys are in tests/balance.gd
tests/run.sh bot campaign skill=average rounds=400
nix develop -c godot          # open the editor
```

- `tests/run.sh` moves `user://` to `tests/out/user`, so worktrees running at once share nothing and no run touches the player's save. `tests/run.sh <godot args>` passes anything else to Godot.
- Tests are plain checks with no framework: one case file per lane in `tests/cases/` and one shot list per lane in `tests/shots/`, plus the few that belong to no lane (the fuzz and play-test cases; see "Tests" in `docs/architecture.md`). `tests/test.gd` and `tests/shots.gd` describe the format. A Godot error during a case fails it.
- Tests and shots run as scenes, because a `godot -s` script cannot see the autoloads. Screenshots need the virtual display; `--headless` renders nothing.
- There is no lint or build step.

## Docs

Every value in the docs is provisional. Where the docs give no number, pick a sensible starting value and keep it easy to tune.

- `docs/design.md`: the summary. Pitch, loop, mechanics, controls, the demo's scope and the open questions (coin formula, combo numbers, arena size ceiling, screens with no mockup).
- `docs/design/overview.md`: screen flow (menu → play scene switching between Upgrades and Level), level phases (setup → 20 s play → summary, with Retry) and end conditions, how coins are paid, save contents.
- `docs/design/levels.md`: grid rules, per-level arena size and zoom, and the three demo layouts.
- `docs/design/physics.md`: ball and paddle behaviour (constant speed, paddle bounce angle, minimum angles, launch, collision).
- `docs/design/placeables.md`: the three kinds of placeables, their counts and saved layouts.
- `docs/design/upgrades.md`: the upgrade web, its three categories (Placeables, Bricks, Arena) and the upgrade screen. It lists the demo's 15 nodes with ranks, effects and first costs, and what each special brick does.
- `docs/art.md`: every size, position, effect, font and UI rule, in pixels at a 1280 × 720 frame. It links the mockup artifact; if they disagree, fix whichever is wrong so they match. It lists where the mockups are currently behind the docs.
- `docs/palette.md`: the only place colours are defined, each hue tied to one meaning.
- `docs/audio.md`: how sound is synthesised by a script (reused from the purged build), the cue list, playback rules and the placeholder music loop.
- `docs/architecture.md`: how the code is organised. Rules (`src/sim/`, no nodes) are kept apart from screens and data; it gives the scene tree, autoloads, the round's signals, the file layout, the tests and the build order. Follow it when writing code.

## Design constraints that shape the code

These are spread across several docs:

- **Arena:** the paddle is on the left edge and moves up and down; the back wall is on the right and the paddle side is open. Losing the last ball ends the round, but the bricks broken so far are still paid.
- **Grid:** each level sets its row count, and columns = rows × 4. The base is 64 × 16 with 16 × 32 px cells; other sizes zoom everything inside the arena by 16 ÷ rows, while the arena frame and the UI stay fixed. A brick is 1 column × 2 rows (a 16 × 64 cell, drawn at 14 × 62) with HP (default 1) shown by its colour.
- **Ball:** constant speed. Bounces change its direction only; speed changes only through the Ball Speed upgrade and through boosts (Booster, Shockwave), which last until the ball next touches the paddle. Collision is swept, and a brick hit resolves against one edge. The paddle chases the mouse at paddle speed.
- **Placeables:** free-form items go anywhere clear of bricks and the paddle lane (some rotate), placeable bricks snap to the grid, and brick mods go on an existing brick. Each rank of an unlock node allows one more; special bricks follow the same rule and are picked again every attempt.
- **Coins:** calculated from the round's tally of bricks broken (by type) and combos, not handed out per brick. Placed bricks pay nothing and don't count toward a clear.
- **Hand-made content:** each level is its own scene, painted in the editor (for example a TileMapLayer) with per-brick HP. The upgrade web is a scene that holds layout and connections; each upgrade's cost, growth, max rank and effect are in its own resource file. There is no procedural generation.
- **Structure:** rules, screens and data are separate layers (see `docs/architecture.md`). Adding a level, an upgrade, a placeable or a brick kind should mean adding a file.
- **Save:** one slot holding the coin balance, each upgrade's rank, the highest level unlocked and each level's placed layout. Nothing else about a level in progress is saved. Settings are stored separately.
- **Rendering:** stretch mode `canvas_items`, aspect `keep`, at 1280 × 720. Shapes are flat and drawn in the engine (`ColorRect`, `Polygon2D`, `draw_rect`), with no textures. Use squares, never circles; the Booster placeable is the one exception. Glow comes only from WorldEnvironment bloom with HDR 2D on: the threshold sits above the slate neutrals and lit colours are pushed over it. White is reserved for the ball and its trail.

## History

The purged implementation at `1aa951b^` was a different design (a "Peglin, but breakout" roguelike run), with `src/`, a headless `tests/test.gd` self-check and generated art and audio. Use `git show 1aa951b^:<path>` to reuse a piece, such as ball and paddle physics, but don't restore it wholesale.

## Conventions

- Ponytail style: make the smallest change that works, and mark deliberate shortcuts with a `# ponytail:` comment that names the ceiling and the upgrade path.
