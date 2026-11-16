class_name Tally
extends RefCounted
## What a round has broken so far. Coins are calculated from this (Coins.total), never handed out per brick,
## and the summary screen shows it.
##
## Keys are brick kind ids: &"" is a standard brick, &"gold" a gold brick, and so on. A brick the player placed
## is never added to `broken` or to a combo's worth: it pays nothing.

## One combo: every brick broken in it is paid again at its multiplier (Coins.total).
class Run:
	var count := 0  ## Bricks broken in it, placed ones too
	var multiplier := 1  ## The multiplier it reached
	var worth := 0  ## The worth of its level bricks (Coins.worth); placed bricks add 0

## Bricks broken, by kind id.
var broken: Dictionary[StringName, int] = {}
## The round's combos in order; the last is the running one while the round's combo.count > 0. Empty while
## combos are off.
var combos: Array[Run] = []
## Placed bricks broken. They are counted here only.
var placed_broken := 0
## Hits each kind of placeable took, by its id: a ball off a free item, any hit on a placed brick or on a brick
## that carries a mod. Pays nothing; the Summary shows it.
var hits: Dictionary[StringName, int] = {}
## The highest combo count the round reached.
var best_combo := 0
## The highest multiplier the round reached. 1 if combos are off.
var best_multiplier := 1


## Counts one hit on a placeable of kind `id`.
func hit(id: StringName) -> void:
	hits[id] = hits.get(id, 0) + 1


## Counts a brick that has just broken. `combo` is the round's combo, already grown by this break (count 0 while
## combos are off).
func add(brick: Brick, combo: Combo) -> void:
	best_combo = maxi(best_combo, combo.count)
	best_multiplier = maxi(best_multiplier, combo.multiplier)
	if combo.count > 0:
		if combos.is_empty() or combo.count <= combos.back().count:  # a new combo (or one set up by hand)
			combos.append(Run.new())
		var run: Run = combos.back()
		run.count = combo.count
		run.multiplier = combo.multiplier
		if not brick.placed:
			run.worth += Coins.worth(brick.kind)
	if brick.placed:
		placed_broken += 1
		return
	broken[brick.kind] = broken.get(brick.kind, 0) + 1
