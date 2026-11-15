extends BrickKind
## The hourglass brick: it adds time to the round's timer when it breaks.

## Seconds added.
@export var seconds := 0.0


func on_broken(round: Round, _cell: Vector2i, _brick: Brick, _cause: Round.Cause, _dir: Vector2, _ball: Ball) -> void:
	round.add_time(seconds)
