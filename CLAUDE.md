# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

BreakIn cremental: a horizontal breakout incremental game in Godot 4.7 (GDScript). Before each timed round you place items on a hand-made level, then play it to earn coins; coins buy nodes in an upgrade web. The pitch, core loop, demo scope, open questions and risks are in `docs/design.md`.

**Current state: design docs only.** The repo was purged on 2026-11-12 (commit `1aa951b`), so there is no `project.godot`, no code and no tests yet. The next code work is the demo described in `docs/design.md`: the full loop on three levels, with effects, audio and the CRT filter.

## Commands

Godot and xvfb-run are not on PATH. They come from the Nix dev shell: run `nix develop`, or prefix commands with `nix develop -c`.

```sh
nix develop -c godot      # open the editor (once project.godot exists)
```

There is no test, lint or build step yet.

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
