extends PlaceableKind
## The Zap: a brick mod. When its brick breaks, every other brick in that brick row takes one hit, from the
## paddle side to the back wall.


func on_host_broken(round: Round, cell: Vector2i, _brick: Brick, _cause: Round.Cause, _dir: Vector2, _ball: Ball) -> void:
	for column in round.board.cols:
		if column != cell.x:
			round.hit_brick(Vector2i(column, cell.y), Round.Cause.ZAP, Vector2.LEFT if column < cell.x else Vector2.RIGHT)
