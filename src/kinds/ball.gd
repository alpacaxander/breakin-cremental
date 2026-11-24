extends BrickKind
## The Ball Brick: breaking it puts one more ball in reserve (Round.add_charge), however it broke.


func on_broken(round: Round, _cell: Vector2i, _brick: Brick, _cause: Round.Cause, _dir: Vector2, _ball: Ball) -> void:
	round.add_charge()
