class_name Tally
extends RefCounted
## What a round has hit and broken so far. Coins are calculated from this (Coins.total), never handed out per
## brick, and the summary screen shows it.
##
## Keys are brick kind ids: &"" is a standard brick, &"gold" a gold brick, and so on. A brick the player placed
## is never added to `broken`, `dents` or a combo's worth: it pays nothing.
##
## Every hit on a level brick scores 1 point, and the hit that breaks it scores its worth instead (Coins.worth: 1,
## gold 20). So a brick with n HP and worth w scores (n - 1) + w in all: the n - 1 in `dents`, the w in `broken`.

## One combo: every point scored while it ran is paid again at its multiplier (Coins.total).
class Run:
	var count := 0  ## Bricks hit or broken in it, placed ones broken too
	var multiplier := 1  ## The multiplier it reached
	var worth := 0  ## Points scored while it ran: its level bricks' worth (Coins.worth) and its dents. Placed bricks add 0

## Bricks broken, by kind id.
var broken: Dictionary[StringName, int] = {}
## The round's combos in order; the last is the running one while the round's combo.count > 0. Empty while
## combos are off.
var combos: Array[Run] = []
## Hits that left a level brick standing: 1 point each.
var dents := 0
## Placed bricks broken. They are counted here only.
var placed_broken := 0
## The highest combo count the round reached.
var best_combo := 0
## How the round ended, set once when it does (Round._end).
var target := 0  ## The score the level needs (Round.target)
var score := 0  ## The score (Coins.points)
var cleared := false  ## `score` reached `target`


## Counts a hit that left a level brick standing: 1 point. `combo` is the round's combo, already grown by this hit
## as by a break (count 0 while combos are off).
func dent(combo: Combo) -> void:
	dents += 1
	_record(combo, 1)


## Counts a brick that has just broken. `combo` is the round's combo, already grown by this break (count 0 while
## combos are off).
func add(brick: Brick, combo: Combo) -> void:
	_record(combo, 0 if brick.placed else Coins.worth(brick.kind))
	if brick.placed:
		placed_broken += 1
		return
	broken[brick.kind] = broken.get(brick.kind, 0) + 1


# Keeps the best combo, and brings the running combo's Run up to `combo`, which a hit scoring
# `points` has just grown.
func _record(combo: Combo, points: int) -> void:
	best_combo = maxi(best_combo, combo.count)
	if combo.count == 0:
		return
	if combos.is_empty() or combo.count <= combos.back().count:  # a new combo (or one set up by hand)
		combos.append(Run.new())
	var run: Run = combos.back()
	run.count = combo.count
	run.multiplier = combo.multiplier
	run.worth += points
