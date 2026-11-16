extends PlaceableKind
## The Zap: a brick mod. When its brick breaks, every other brick in that brick row within stats.zap_range
## columns takes stats.zap_damage hits, from the paddle side to the back wall.


func on_host_broken(round: Round, cell: Vector2i, _brick: Brick, _cause: Round.Cause, _dir: Vector2, _ball: Ball) -> void:
	var reach := int(round.stats.zap_range)
	for column in range(maxi(cell.x - reach, 0), mini(cell.x + reach + 1, round.board.cols)):
		if column != cell.x:
			for i in int(round.stats.zap_damage):
				round.hit_brick(Vector2i(column, cell.y), Round.Cause.ZAP, Vector2.LEFT if column < cell.x else Vector2.RIGHT)
