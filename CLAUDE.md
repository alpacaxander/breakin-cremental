# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

BreakIn cremental: a horizontal breakout incremental game in Godot 4.7 (GDScript). Before each timed round you place items on a hand-made level, then play it to earn coins; coins buy nodes in an upgrade web. The pitch, core loop, MVP scope and risks are in `docs/design.md`.

**Current state: design docs only.** The repo was purged on 2026-11-12 (commit `1aa951b`), so there is no `project.godot`, no code and no tests yet. The next code work is the MVP described in `docs/design.md`.

## Commands

Godot and xvfb-run are not on PATH. They come from the Nix dev shell: run `nix develop`, or prefix commands with `nix develop -c`.

```sh
nix develop -c godot      # open the editor (once project.godot exists)
```

There is no test, lint or build step yet.

## Docs

Every value in the docs is provisional.

- `docs/design.md`: the summary. Pitch, loop, mechanics, controls, MVP and what it leaves out (effects, audio, CRT, special bricks).
- `docs/design/overview.md`: screen flow (menu → play scene switching between Upgrades and Level), level phases (setup → 20 s play → summary) and end conditions, save contents.
- `docs/design/levels.md`: grid rules and the three MVP layouts.
- `docs/design/upgrades.md`: the upgrade web, its three categories (Placeables, Bricks, Arena) and the upgrade screen.
- `docs/art.md`: every size, position, effect, font and UI rule, in pixels at a 1280 × 720 frame. It links the mockup artifact; if they disagree, fix whichever is wrong so they match.
- `docs/palette.md`: the only place colours are defined, each hue tied to one meaning.

## Design constraints that shape the code

These are spread across several docs:

- **Arena:** the paddle is on the left edge and moves up and down; the back wall is on the right and the paddle side is open. A ball drop ends the round, but coins already earned are kept.
- **Grid:** 64 columns × 16 rows, each cell 16 × 32 px. A brick is 1 column × 2 rows (a 16 × 64 cell, drawn at 14 × 62) with HP (default 1). Placeables snap to the same grid.
- **Hand-made content as scenes:** each level is its own scene, painted in the editor (for example a TileMapLayer) with per-brick HP. The upgrade web is also a scene; each node sets its cost and growth, max rank, effect and connections. There is no procedural generation.
- **Save:** one slot holding the coin balance, each upgrade's rank and the highest level unlocked. Nothing about a level in progress is saved.
- **Rendering:** stretch mode `canvas_items`, aspect `keep`, at 1280 × 720. Shapes are flat and drawn in the engine (`ColorRect`, `Polygon2D`, `draw_rect`), with no textures. Use squares, never circles. Glow comes only from WorldEnvironment bloom with HDR 2D on: the threshold sits above the slate neutrals and lit colours are pushed over it. White is reserved for the ball and its trail.

## History

The purged implementation at `1aa951b^` was a different design (a "Peglin, but breakout" roguelike run), with `src/`, a headless `tests/test.gd` self-check and generated art and audio. Use `git show 1aa951b^:<path>` to reuse a piece, such as ball and paddle physics, but don't restore it wholesale.

## Conventions

- Ponytail style: make the smallest change that works, and mark deliberate shortcuts with a `# ponytail:` comment that names the ceiling and the upgrade path.
