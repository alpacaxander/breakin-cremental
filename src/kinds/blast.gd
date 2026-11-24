extends AbilityKind
## Blast: an explosion at the hit brick (Round.blast). The blast_size stat is in squares; Round.blast takes units.


func fire(round: Round, cell: Vector2i, _dir: Vector2, _ball: Ball) -> void:
	round.blast(cell, round.stats.blast_size * Board.BRICK.y)
