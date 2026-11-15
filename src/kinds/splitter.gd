extends PlaceableKind
## The Splitter: a placed brick. When a ball breaks it, that ball splits in two. A blast or a Zap just breaks it.


## The ball that broke it has already bounced off it; the new ball starts where it is and carries on the way it
## came in (`dir`), through the gap the Splitter leaves. So one goes back and one goes on, off any edge.
func on_broken(round: Round, _cell: Vector2i, _brick: Brick, _cause: Round.Cause, dir: Vector2, ball: Ball) -> void:
	if ball:
		round.add_ball(ball.pos, dir, ball.boost)
