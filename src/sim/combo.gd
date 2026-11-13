class_name Combo
extends RefCounted
## The combo of one round. The round owns it and changes it; screens read it.
##
## Combos are off until the Combo upgrade is bought (stats.combo_rank 0): count stays 0 and multiplier stays 1.
## With combos on, every brick broken while a combo is running, or starting one, adds 1 to count and restarts the
## window. Placed bricks count too. When the window runs out the combo resets.
## The numbers and the two formulas are in Balance, under "Combo".

## Bricks broken in the combo that is running. 0 when none is.
var count := 0
## What a brick broken now is worth: coins = its worth * multiplier. Whole, and at least 1.
var multiplier := 1
## Seconds left to break the next brick before the combo resets. 0 when no combo is running.
var time_left := 0.0
## The full length of the window that is counting down, so time_left / window is the HUD bar's fill.
## 0 when no combo is running.
var window := 0.0


## A brick broke: the combo grows by one and its window starts again. The round calls this only while combos
## are on.
func add(stats: Balance) -> void:
	count += 1
	@warning_ignore("integer_division")
	multiplier = 1 + (count - 1) / maxi(stats.combo_breaks_per_step, 1)
	window = maxf(stats.combo_window_min, (stats.combo_window + stats.combo_window_per_rank * (stats.combo_rank - 1.0))
			* pow(stats.combo_window_shrink, multiplier - 1))
	time_left = window


## Counts the window down by `delta` seconds. True if a combo was running and has just run out: it is reset.
func tick(delta: float) -> bool:
	if count == 0:
		return false
	time_left -= delta
	if time_left > 0.0:
		return false
	count = 0
	multiplier = 1
	time_left = 0.0
	window = 0.0
	return true
