# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

BreakIn cremental: a breakout-style incremental game in Godot 4.7 (GDScript). Between timed rounds the player buys upgrades and places pieces on a generated board, then plays the round to cash in. Design, status and open risks: `docs/design.md`.

## Commands

Godot is not on PATH; it comes from the Nix dev shell (`nix develop`, or prefix commands with `nix develop -c`).

```sh
godot                                  # open the editor on this project
godot --headless -s tests/test.gd      # rules self-check (game.gd, brick.gd, fx.gd, tuning.gd); prints "ok" or FAIL lines, exits 1 on failure
godot --headless tests/smoke.tscn      # one scripted round through arena.gd; any script error prints. A scene, not -s, so the Game autoload exists
xvfb-run -s "-screen 0 3840x2160x24" godot --display-driver x11 --rendering-driver opengl3 tests/shots.tscn  # every screen at eight window sizes to user://shots/, to eyeball the layout
node assets/pixel/gen.mjs              # regenerate every sprite and animation strip in assets/pixel/png/ (needs ImageMagick `magick`)
node assets/audio/gen.mjs              # regenerate every sound cue in assets/audio/wav/ and the review page assets/audio/demo.html
```

There is no test framework and no lint step. `tests/test.gd` is a plain `SceneTree` script using a `check(ok, msg)` helper; add a line there when a rule changes. The smoke test saves the real `user://save.json` and restores it afterward.

## Architecture

Eleven scripts in `src/`, no scenes except `main.tscn`. Everything is built in code.

- **`tuning.gd`** is the single home for every number and table: level layouts (`LEVELS`), brick kinds (`BRICKS`, `ICON_KINDS`), placeable pieces (`PLACEABLES`), the paddle and wall (`PIECES`), and the upgrade web (`UPGRADES`). A kind's row holds its numbers and its look (`face`, optional `idle` strip and `offset`); `spec(kind)` finds the row whichever table holds it. Changing balance means editing this file only. Keys are shared across tables: a placeable's id doubles as its upgrade id (owned count = `start` + rank), an `ICON_KINDS` id in `UPGRADES` is an unlock that `generate` guarantees per board, and `ICON_KINDS` must all be `BRICKS` keys. Every upgrade row has a `cat` from `CATS` (its node colour) and most are a `Game.stat(Tuning.X, id)` at one call site. `test.gd` enforces these cross-references.
- **`game.gd`** (autoload `Game`) holds run state (currency, unlocked level, upgrade ranks), save/settings files, the save slot (`slot` is the real `save.json` or the dev `sandbox.json`, which starts with every rank maxed and every level open; `load_save` wipes to the slot's defaults first, so the two never mix; entered from the menu, left on return to it), and the pure rules: combo window and multiplier, upgrade reveal/cost/buy, derived stats, and `generate(level, seed)` for boards. It has no scene dependencies, which is why `test.gd` can instantiate it headless.
- **`main.gd`** swaps one child at a time between the main menu, `shop.gd` (upgrade web and level select) and `arena.gd` (a round). Signals `play(level)` / `menu` / `done` drive the swaps. The shop's web lives in the root's clipped `field`: drag on empty field pans it, the wheel zooms through `ZOOMS` about the cursor, and the whole screen is rebuilt on every change with pan and zoom kept.
- **`arena.gd`** is one round: it builds the board, walls and paddle, then runs play mode (ball physics, paddle, combo timer, brick effects, pass-through pieces, spawner) and ends it. Everything is in arena-local px with the origin at the arena's top-left; `field` is the level's rect (`Game.arena_size`, at most `Tuning.ARENA`) and `_fit` scales the node to the largest that fits the cabinet's 4:3 field between the columns and centres it there, so a non-4:3 level shows bare sheet beside or above the board (the cabinet `Ui.Root`s are `top_level`, so they keep their own 2x). Mouse reads go through `get_local_mouse_position`. A level row may carry an `arena` size and extra `walls`. Balls are an inner `CharacterBody2D` class. Brick-kind behaviour lives here in `_hit`, `_damage`, `_effect` and `_pass`, keyed by `kind` string. Two child nodes take the rest and read the arena's fields directly (untyped `arena` var, so neither preloads the other):
  - **`place.gd`** is placement mode: the pieces tray, pick/drag/rotate/drop, validity and capacity checks. Pieces it creates are arena children (`arena.box`). It consumes its input events so the arena does not also launch, and emits `started`, at which point the arena copies its `placed` list.
  - **`hud.gd`** is the score column, refreshed every frame from the arena, plus the result panel.
- **`brick.gd`** (`Box`) is every physical piece: board bricks, placeables, paddle, walls. It builds the collider and look from the kind's `tuning.gd` row; icon kinds derive their face from `icon_<kind>_pulse`. Pass-through placeables set `collision_layer = 0` and the arena checks overlap itself.
- **`fx.gd`** plays horizontal animation strips from `assets/pixel/png/anim_<name>.png` as `AnimatedSprite2D` at 2x, slicing by a caller-supplied frame width. One `SpriteFrames` is cached per strip, so a strip must always be played at the same fps.
- **`sfx.gd`** plays one cue from `assets/audio/wav/<name>.wav`: `play(name, pitch, delay)` one-shots under the scene root (they survive scene swaps and pauses), `loop(parent, name)` as a child that stops with its owner. Pitch ladders reuse one sample (`st(n)` = n semitones). `Ui.button` plays `ui_click` unless given another cue or `""`; `test.gd` checks every cue name the scripts play has a wav.
- **`ui.gd`** is the cabinet: every screen is a 640x360 sprite-space layout scaled 2x (`Ui.Root`), centred in a canvas that grows with the window. `main.gd` `_scale` sets the window's `content_scale_factor` to the factor at which 1280x720 just fits (Godot's own stretch is off: it letterboxes), so there are no bars and the cabinet grows with the window. Left to right every screen is padding, column, 4:3 field (480x360 sprite px), column, padding. Below 1280x720 (tiling window managers ignore a minimum size) the columns keep their 2x and `Ui.Root.content` shrinks the field to the largest 4:3 left between them: the root's `sheet`, `left` and `right` are `top_level` at a fixed 2x, the root itself scales with the content, and `fit()` lays them out on every resize. The arena's `_fit` uses the same `Ui.Root.content` rect. Static helpers (`chassis`, `label`, `button`, `icon`, `pips`, `cash`, `dialog`, `settings`) place things in sprite px; `theme.tres` supplies the 3x5 bitmap font and the nine-patch button, toggle and slider styles. The arena's HUD, tray, pause and result panels are built from these too.

### Adding a brick kind

A kind is a string that several tables and `match` blocks agree on. Touch, in order:

1. `tuning.gd`: a row in `BRICKS` (and a `special` weight in a level, or `ICON_KINDS` for a break effect) or in `PLACEABLES` (plus an `UPGRADES` node with the same id).
2. `arena.gd`: the arm it needs. `_hit` for a bounce reaction, `_damage` for a refusal or multi-hit face, `_effect` for an on-break effect, `_pass` for a pass-through placeable. Per-tick behaviour (magnet, spawner) is a `kind` check in `_physics_process` or `_move_ball`; the `sky` spark list in `_break` names the conditional kinds.
3. Art and sound: `assets/pixel/gen.mjs`, `docs/animations.md`, `assets/audio/gen.mjs`, and the strip list in `test.gd`.

## Art pipeline

Sprites are pixel art on a 640x360 canvas shown at 2x (nearest filtering, set in `project.godot`). Game-space sizes in `tuning.gd` are 2x the sprite sizes (a 60x24 brick is a 30x12 sprite). All PNGs are generated by `assets/pixel/gen.mjs` and committed; do not hand-edit them. The UI font is `assets/pixel/png/font_3x5.fnt` (BMFont descriptor, also generated) over `font_3x5.png`; Godot imports it as a `FontFile` and the UI asks for sizes 5, 10, 15 and 20. Mock screens, logo cards and `look.png` land in `assets/pixel/preview/` (`.gdignore`, so Godot never imports them); `preview/ui.html` shows them. The strip name, frame width and frame count every call site uses must match `docs/animations.md`, and `test.gd` checks that each strip the arena plays slices into the documented frame count. `docs/art-style.md` and `docs/palette.md` describe the lamp look and colours; when the docs and `gen.mjs` disagree, the code wins and the doc gets fixed.

Sound cues are sfxr-style synthesis from `assets/audio/gen.mjs` (plain Node, no dependencies), committed as 44.1k mono WAVs; tune the recipe in its `CUES` table, never the wav. The four loop cues carry `edit/loop_mode=1` in their `.import` sidecars; a new loop needs that flag too.

`assets/vector/` is an earlier SVG attempt, excluded from Godot import by `.gdignore` and not used by the game.

## Conventions

- Ponytail style: the smallest working change, and deliberate shortcuts are marked with a `# ponytail:` comment naming the ceiling and the upgrade path. Keep that habit.
- Each script opens with a `##` doc comment saying what it owns; keep those accurate when responsibilities move.
- Capture freed-able nodes in lambdas by instance id (see the spawn tween in `arena.gd`), not by reference.
- Quit through `Sfx.quit()`, never `get_tree().quit()` directly: a cue still mixing at exit logs a leaked playback. The window close button already routes there (`main.gd`).
