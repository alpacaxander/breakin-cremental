extends AbilityKind
## Zap: every other brick in the brick row within stats.zap_range columns of the hit takes stats.zap_damage hits
## (Round.zap).


func fire(round: Round, cell: Vector2i, _dir: Vector2, _ball: Ball) -> void:
	round.zap(cell)
