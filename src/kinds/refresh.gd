extends PlaceableKind
## Refresh: a placed block that never breaks (unbreakable). A ball's hit while it is ready brings back the
## stats.refresh_size broken level bricks nearest it as plain 1 HP bricks (Round.broken_near, Round.restore).
## Then it waits `cooldown` seconds of play, less stats.pulse_rate and never under stats.pulse_min (Brick.ready_at),
## drawn dim. A hit that brings nothing back (nothing broken yet) leaves it ready.

## Seconds it waits after bringing bricks back, before stats.pulse_rate.
@export var cooldown := 0.0


func on_hit(round: Round, cell: Vector2i, brick: Brick, cause: Round.Cause, _dir: Vector2, _ball: Ball) -> void:
	if cause != Round.Cause.BALL or round.clock + Round.TIME_SLOP < brick.ready_at:
		return
	if not round.restore(cell, round.broken_near(cell, int(round.stats.refresh_size))).is_empty():
		brick.ready_at = round.clock + maxf(cooldown - round.stats.pulse_rate, round.stats.pulse_min)
