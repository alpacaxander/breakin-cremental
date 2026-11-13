class_name Fx
extends Node2D
## Everything that decorates a round and changes nothing in it: particles, shockwaves, light pools, the ball
## trail, coin pop-ups, screen shake, freezes, flashes, and the bloom that climbs with the combo
## (docs/art.md, "Effects"). It is built only from a round's signals and the state it reads from the round.
##
## STUB: the Feel step writes this folder. As shipped here it shows nothing, never freezes and never shakes.
##
## THE SEAM WITH THE LEVEL SCREEN. The level screen owns everything outside src/level/fx/ and does five things:
##   1. It has one Fx node, a Node2D with this script, as the last child of its Arena node. Arena sits at
##      (154, 110) with scale Board.zoom(), so Fx and its children draw in round units (see Board). Text is
##      the exception: a pop-up is placed in units but scaled back by 1 / zoom, so it keeps its pixel size.
##   2. It calls watch(round) once, when Play starts, with the round it is about to step, and clear() when that
##      round is thrown away (Retry, leaving the level).
##   3. On a physics tick where `frozen` is true it does not call Round.step.
##   4. Every frame it sets Arena's position to Vector2(154, 110) + shake.
##   5. It keeps what it draws inside Arena at these z_index values, so Fx can put its own children between
##      them: the backdrop grid at 0, bricks, placed items and the paddle at 10, balls at 20. Fx uses, for
##      example, 5 for light pools (under the bricks), 15 for particles and shockwaves, 19 for the trail and 30
##      for pop-ups.
## Fx also calls Main.set_bloom as the combo climbs and reads Settings.reduce_flashing. It never changes the
## round, the HUD or anything else the level screen draws.

## True while the game should stand still (the brief freeze on a big hit). Fx counts the freeze down itself.
var frozen := false
## How far to move the Arena this frame, in screen pixels (screen shake). Zero when nothing shakes.
var shake := Vector2.ZERO


## Starts decorating `round`: connects to its signals and reads its balls, board and combo from then on.
func watch(_round: Round) -> void:
	pass


## Forgets the round and removes every effect on screen. Also puts `frozen`, `shake` and the bloom back to rest.
func clear() -> void:
	frozen = false
	shake = Vector2.ZERO
	Main.set_bloom(0.0)
