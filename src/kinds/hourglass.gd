extends BrickKind
## The hourglass brick: it adds time to the round's timer when it breaks, and holds a running combo's window.

## Seconds added, before stats.hourglass_time.
@export var seconds := 0.0


func on_broken(round: Round, _cell: Vector2i, _brick: Brick, _cause: Round.Cause, _dir: Vector2, _ball: Ball) -> void:
	round.add_time(seconds + round.stats.hourglass_time)
	if round.combo.count > 0:
		round.combo.held = maxf(round.combo.held, round.stats.hourglass_freeze)
