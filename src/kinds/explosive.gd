extends BrickKind
## The explosive brick: when it breaks, every brick in the blast takes one hit. One it breaks that is explosive
## too goes off in turn.


## The blast_size stat is in squares; Round.blast takes units.
func on_broken(round: Round, cell: Vector2i, _brick: Brick, _cause: Round.Cause, _dir: Vector2, _ball: Ball) -> void:
	round.blast(cell, round.stats.blast_size * Board.BRICK.y)
