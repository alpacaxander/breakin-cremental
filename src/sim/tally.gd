class_name Tally
extends RefCounted
## What a round has broken so far. Coins are calculated from this (Coins.total), never handed out per brick,
## and the summary screen shows it.
##
## Keys are brick kind ids: &"" is a standard brick, &"gold" a gold brick, and so on. A brick the player placed
## is never added to `broken` or `points`: it pays nothing.
##
## STUB: the rules lane adds the function the round fills it with.

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
