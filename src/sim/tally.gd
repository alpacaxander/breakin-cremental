class_name Tally
extends RefCounted
## What a round has broken so far. Coins are calculated from this (Coins.total), never handed out per brick,
## and the summary screen shows it.
##
## Keys are brick kind ids: &"" is a standard brick, &"gold" a gold brick, and so on. A brick the player placed
## is never added to `broken` or `points`: it pays nothing.

## Bricks broken, by kind id.
var broken: Dictionary[StringName, int] = {}
## By kind id, the sum of the combo multiplier each of those bricks broke at. With combos off this equals
## `broken`. Three standard bricks broken at x1, x1 and x2 give points[&""] = 4.
var points: Dictionary[StringName, int] = {}
## Placed bricks broken. They are counted here only.
var placed_broken := 0
## The highest combo count the round reached.
var best_combo := 0
## The highest multiplier the round reached. 1 if combos are off.
var best_multiplier := 1


## Counts a brick that has just broken. `combo` is the round's combo, already grown by this break.
func add(brick: Brick, combo: Combo) -> void:
	best_combo = maxi(best_combo, combo.count)
	best_multiplier = maxi(best_multiplier, combo.multiplier)
	if brick.placed:
		placed_broken += 1
		return
	broken[brick.kind] = broken.get(brick.kind, 0) + 1
	points[brick.kind] = points.get(brick.kind, 0) + combo.multiplier
