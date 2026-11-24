extends PlaceableKind
## The Splitter: a placed brick. Every time a ball hits it, that ball splits in two: it bounces back off it as
## usual, and a new ball goes on the way it came in, out of the Splitter's far side. It has kind hp +
## stats.splitter_health HP. A blast or a Zap just hits it. With Splitter Respawn (stats.splitter_respawn >= 1) a
## broken Splitter comes back `respawn` s later, less `respawn_per_rank` s for each rank above 1 (Round.rebuild).

## Seconds a broken Splitter takes to come back at Splitter Respawn rank 1.
@export var respawn := 0.0
## Seconds each Splitter Respawn rank above 1 takes off `respawn`.
@export var respawn_per_rank := 0.0


## The ball that hit it has already bounced off it. If the Splitter broke, the new ball starts where the ball is
## and goes through the gap it leaves. If it still stands, the new ball starts on the far side, as if it had
## passed through, unless that is in a brick, in a solid placed item or past a wall: then it leaves on the near side, mirrored to the
## bounced ball along the face, so the two still go opposite ways.
func on_hit(round: Round, cell: Vector2i, brick: Brick, _cause: Round.Cause, dir: Vector2, ball: Ball) -> void:
	if ball == null:
		return
	var pos := ball.pos
	var way := dir
	if brick.hp > 0:
		var side := signf(ball.dir.x) != signf(dir.x)  # the bounce flipped x: it hit a left or right face
		var axis := Vector2(1, 0) if side else Vector2(0, 1)
		var centre := round.board.cell_rect(cell).get_center()
		pos = ball.pos - 2.0 * axis * (ball.pos - centre).dot(axis)
		var box := Rect2(pos - Vector2.ONE * ball.size * 0.5, Vector2.ONE * ball.size).grow(-Collide.SKIN)
		var blocked := not Rect2(Vector2.ZERO, round.board.size()).encloses(box) or not round.board.bricks_in(box).is_empty()
		for item in round.layout.items:
			if not blocked and item.kind.placement == PlaceableKind.Placement.FREE and not item.kind.gate:
				blocked = Collide.overlap(Collide.box(box), item.outline())
		if blocked:
			pos = ball.pos
			way = ball.dir * (axis * 2.0 - Vector2.ONE)  # the bounced way, flipped along the face
	round.add_ball(pos, way, ball.boost).kept = ball.kept


func on_broken(round: Round, cell: Vector2i, brick: Brick, cause: Round.Cause, dir: Vector2, ball: Ball) -> void:
	on_hit(round, cell, brick, cause, dir, ball)
	var rank := round.stats.splitter_respawn
	if rank >= 1.0:
		round.rebuild(cell, maxf(respawn - respawn_per_rank * (rank - 1.0), 0.0))
