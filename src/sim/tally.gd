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
	var count := 0  ## Bricks broken in it, placed ones too
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
## Hits each kind of placeable took, by its id: a ball off a free item, any hit on a placed brick or on a brick
## that carries a mod. Pays nothing; the Summary shows it.
var hits: Dictionary[StringName, int] = {}
## The highest combo count the round reached.
var best_combo := 0
## The highest multiplier the round reached. 1 if combos are off.
var best_multiplier := 1
## Level bricks broken by the explosion chain going off now, and the most one chain broke. A chain is everything
## one blast set off, the blasts and Zaps it led to included; the explosive brick that started it is not in it.
var chain := 0
var best_chain := 0
## Level bricks broken since a ball last touched the paddle, and the most between two touches.
var rally := 0
var best_rally := 0
## Times a ball touched the paddle, the launch included.
var paddle_touches := 0
## How the round ended, set once when it does (Round._end). Coins.bonuses pays for these.
var ended := false
var target := 0  ## The score the level needs (Round.target)
var score := 0  ## The score (Coins.points) before the end bonuses
var cleared := false  ## `score` reached `target`
var kept := false  ## A ball was still in play
var seconds_left := 0  ## Whole seconds on the timer, if every level brick was broken
var first_clear := false  ## A clear, and the level's first


## Counts one hit on a placeable of kind `id`.
func hit(id: StringName) -> void:
	hits[id] = hits.get(id, 0) + 1


## Counts a hit that left a level brick standing: 1 point, added to the running combo's worth too while `combo`
## (the round's) has one running. Only a break grows the combo.
func dent(combo: Combo) -> void:
	dents += 1
	if combo.count > 0 and combos:
		combos.back().worth += 1


## Counts a ball touching the paddle: the rally starts again.
func touch() -> void:
	paddle_touches += 1
	rally = 0


## Counts a brick that has just broken. `combo` is the round's combo, already grown by this break (count 0 while
## combos are off). `in_chain` is true while an explosion chain is going off.
func add(brick: Brick, combo: Combo, in_chain := false) -> void:
	if not brick.placed:
		rally += 1
		best_rally = maxi(best_rally, rally)
		if in_chain:
			chain += 1
			best_chain = maxi(best_chain, chain)
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
