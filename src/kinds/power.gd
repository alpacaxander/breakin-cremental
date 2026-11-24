extends BrickKind
## The Power Brick: breaking it leaves a drop that moves to the paddle (Round.drop); caught, it is a charge.


func on_broken(round: Round, cell: Vector2i, _brick: Brick, _cause: Round.Cause, _dir: Vector2, _ball: Ball) -> void:
	round.drop(cell)
