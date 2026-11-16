extends PlaceableKind
## The Splitter: a placed brick. Every time a ball hits it, that ball splits into stats.splitter_splits balls
## (itself included). It has kind hp + stats.splitter_health HP. A blast or a Zap just hits it.

## Degrees between the balls a split fans out.
const SPREAD := 20.0


## The ball that hit it has already bounced off it. If the Splitter broke, the first new ball starts where the
## ball is and carries on the way it came in (`dir`), through the gap the Splitter leaves: one goes back, one goes
## on. If it still stands, the new balls fan out from the bounced ball instead, so none goes back into it. Each
## further ball is SPREAD further round, alternating sides.
func on_hit(round: Round, _cell: Vector2i, brick: Brick, _cause: Round.Cause, dir: Vector2, ball: Ball) -> void:
	if ball == null:
		return
	var stands := brick.hp > 0
	for i in int(round.stats.splitter_splits) - 1:
		var k := i + int(stands)
		@warning_ignore("integer_division")
		var turn := SPREAD * ((k + 1) / 2) * (1 if k % 2 else -1)
		round.add_ball(ball.pos, (ball.dir if stands else dir).rotated(deg_to_rad(turn)), ball.boost).kept = ball.kept


func on_broken(round: Round, cell: Vector2i, brick: Brick, cause: Round.Cause, dir: Vector2, ball: Ball) -> void:
	on_hit(round, cell, brick, cause, dir, ball)
