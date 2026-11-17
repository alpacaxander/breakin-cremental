extends PlaceableKind
## Growth: a placed block that never breaks (unbreakable). Every `pulse` seconds of play, less stats.pulse_rate
## and never under stats.pulse_min, it gives each level brick within stats.growth_reach squares of its edges 1 HP,
## up to stats.max_hp (Round.grow). The first pulse is one period after the round's first step of play.

## Seconds between pulses, before stats.pulse_rate.
@export var pulse := 0.0


## A pulse for every multiple of the period that round.clock passed in this step. Less than Round.TIME_SLOP short
## of one counts as on it, as the timer does.
func on_step(round: Round, cell: Vector2i, _brick: Brick, delta: float) -> void:
	var period := maxf(pulse - round.stats.pulse_rate, round.stats.pulse_min)
	var due := floori((round.clock + Round.TIME_SLOP) / period) - floori((round.clock - delta + Round.TIME_SLOP) / period)
	for i in due:
		round.grow(cell, round.stats.growth_reach * Board.BRICK.y)
