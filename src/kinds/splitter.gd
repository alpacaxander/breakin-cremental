extends PlaceableKind
## The Splitter: a placed brick. When a ball breaks it, that ball splits in two. A blast or a Zap just breaks it.


## The new ball starts where the first one is, with its direction mirrored up for down. Off the Splitter's side
## the two leave as a V; off its top or bottom one bounces back and the other carries on through the gap.
func on_broken(round: Round, _cell: Vector2i, _brick: Brick, _cause: Round.Cause, ball: Ball) -> void:
	if ball:
		round.add_ball(ball.pos, Vector2(ball.dir.x, -ball.dir.y), ball.boost)
