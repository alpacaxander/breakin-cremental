extends RefCounted
## An attack on the ball and the sweep (src/sim/round.gd, src/sim/collide.gd): whole rounds on random boards with
## random legal layouts, random upgrade ranks, random seeds and random paddle input, every step checked against
## the rules with geometry of its own. Run with: tests/run.sh test fuzz_physics
## FUZZ_ROUNDS=<n> FUZZ_FROM=<seed> hunts with n rounds from that seed instead of the fixed few the suite runs.

const SLACK := 0.02  ## Units a ball may be inside something: rounding, not a hit
const LOW_SLACK := 0.01  ## Degrees of rounding allowed on a minimum angle

var t: Node
var _stats_base: Balance


func run(p_t: Node) -> void:
	t = p_t
	_stats_base = Progress.snapshot()
	var n := int(OS.get_environment("FUZZ_ROUNDS")) if OS.has_environment("FUZZ_ROUNDS") else 0
	var from := int(OS.get_environment("FUZZ_FROM")) if OS.has_environment("FUZZ_FROM") else 1
	if n > 0:
		_hunt(from, n)
		return
	_timer_steps()
	_timer_rates()
	_hunt(1, 18)


# --- findings, cut to the smallest board -----------------------------------------------------------------------

## A round of `seconds` at `rate` steps a second, with one ball heading right at a brick and a paddle that stays
## put and as tall as the arena, so the ball is never lost. Returns [steps played, bricks broken, end reason].
func _timed(seconds: float, rate: int, ball_x: float, hp: int) -> Array:
	var stats := _stats_base.copy()
	stats.round_time = seconds
	stats.paddle_size = 512.0
	var board := Board.new(16)
	board.bricks[Vector2i(40, 0)] = Brick.new(hp)
	var round := Round.new(board, null, stats, 1)
	round.balls[0].put(Vector2(ball_x, 32.0), Vector2.RIGHT)
	var got := [0, 0, -1]  # steps, broken, end
	round.brick_broken.connect(func(_c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, _n: int) -> void: got[1] += 1)
	round.ended.connect(func(reason: Round.End) -> void: got[2] = reason)
	while not round.over and got[0] < rate * (seconds + 1.0):
		round.step(1.0 / rate, round.paddle.y)
		got[0] += 1
	_drop(round)
	return got


## Round step 4: "time_left counts down. It stops at 0." and overview.md "The timer runs: 20 s base". time_left
## was lowered by `delta` each step and compared with 0.0, so float residue left a hair above 0 after the last
## whole step and the round played one step more than its time: 1 s was 121 steps at 120/s, 20 s was 2401.
## Round.TIME_SLOP fixed it. The lengths are the Round Time ranks (20, 23, 26, 29) and two short ones.
func _timer_steps() -> void:
	for c in [[1.0, 120], [20.0, 120], [20.0, 240], [2.0, 60], [23.0, 60], [26.0, 60], [29.0, 60], [20.0, 144]]:
		var got: Array = _timed(c[0], c[1], 0.0, 1000000)
		t.check(got[0] == roundi(c[0] * c[1]), "timer: a %s s round at %d steps a second plays %d steps, not %d" % [c[0], c[1], got[0], roundi(c[0] * c[1])])


## Round TICK RATE: "a round with one ball and a paddle that stays put breaks the same bricks in the same order at
## 60, 120 and 240 steps a second". The ball reaches the brick 1.004 s in; a 1 s round played exactly 1 s at 60/s
## but one extra step (1.0083 s) at 120/s, so the brick broke, and the level cleared, only at 120.
func _timer_rates() -> void:
	var x := 40 * 16.0 - _stats_base.ball_size * 0.5 - _stats_base.ball_speed * 1.004
	var at60 := _timed(1.0, 60, x, 1)
	var at120 := _timed(1.0, 120, x, 1)
	t.check(at60[1] == at120[1] and at60[2] == at120[2], "tick rate: one ball, still paddle, 1 s round: %d broken (end %d) at 60/s but %d broken (end %d) at 120/s" % [at60[1], at60[2], at120[1], at120[2]])


# --- the hunt --------------------------------------------------------------------------------------------------

func _hunt(from: int, n: int) -> void:
	var wrong := {}  # category -> [examples]
	var seen := {&"steps": 0, &"contacts": 0, &"balls": 0, &"rounds": 0}
	for s in range(from, from + n):
		_attack(s, wrong, seen)
		if s % 3 == 0:
			_rates(s, wrong)
	for what: String in wrong:
		var list: Array = wrong[what]
		t.check(false, "%s: %d times, first %s" % [what, list.size(), list.slice(0, 3)])
	print("   fuzz_physics: ", seen)


func _say(wrong: Dictionary, what: String, detail: String) -> void:
	if not wrong.has(what):
		wrong[what] = []
	if wrong[what].size() < 20:
		wrong[what].append(detail)


## Random upgrade ranks, any of them up to the top rank, through Progress.snapshot.
func _random_stats(rng: RandomNumberGenerator) -> Balance:
	for u: Upgrade in Progress.upgrades():
		Progress.ranks[u.id] = u.max_rank if rng.randf() < 0.4 else rng.randi_range(0, u.max_rank)
	var s := Progress.snapshot()
	Progress.ranks.clear()
	return s


func _random_board(rng: RandomNumberGenerator) -> Board:
	if rng.randf() < 0.3:
		return Levels.read(rng.randi_range(1, Levels.count())).board
	var board := Board.new([14, 16, 18, 20, 24][rng.randi() % 5])
	var density := rng.randf_range(0.02, 0.6)
	var start := rng.randi_range(4, 8)  # a brick under the ball at rest is a broken level, not a rule
	for column in range(start, board.cols):
		for row in board.rows / 2:
			if rng.randf() < density:
				board.bricks[Vector2i(column, row)] = Brick.new([1, 1, 2, 3, 4, 1000][rng.randi() % 6])
	return board


## Random items at their counts. Positions are often snapped to whole or half units and to brick edges, so items
## touch bricks and each other exactly.
func _random_layout(rng: RandomNumberGenerator, board: Board, stats: Balance) -> Layout:
	var layout := Layout.new()
	for i in 200:
		var kind: PlaceableKind = Kinds.placeables()[rng.randi() % Kinds.placeables().size()]
		var item := Layout.Item.new()
		item.kind = kind
		var p := Vector2(rng.randf(), rng.randf()) * board.size()
		match rng.randi() % 3:
			1:
				p = p.snapped(Vector2(0.5, 0.5))
			2:  # against a brick edge
				var c := board.cell_at(p)
				var half: float = kind.size.x * 0.5 if rng.randf() < 0.5 else kind.size.y * 0.5
				p = Vector2(c) * Board.BRICK + [Vector2(-half, rng.randf() * 64), Vector2(16 + half, rng.randf() * 64), Vector2(rng.randf() * 16, -half), Vector2(rng.randf() * 16, 64 + half)][rng.randi() % 4]
		item.pos = p
		item.cell = board.cell_at(p)
		if kind.rotatable:
			item.rot = rng.randf_range(0.0, 360.0) if rng.randf() < 0.5 else rng.randi() % 24 * 15.0
		if layout.fits(item, board, stats):
			layout.add(item)
	return layout


## Items slid until they touch a brick, a wall or each other, so the board is full of corners and narrow gaps.
## Returns [layout, contacts]: the points where each item touched what stopped it.
func _snug_layout(rng: RandomNumberGenerator, board: Board, stats: Balance) -> Array:
	var layout := Layout.new()
	var contacts: Array[Vector2] = []
	for i in 60:
		var kind: PlaceableKind = Kinds.placeables()[rng.randi() % Kinds.placeables().size()]
		var item := Layout.Item.new()
		item.kind = kind
		if kind.placement != PlaceableKind.Placement.FREE:
			item.cell = Vector2i(rng.randi_range(0, board.cols - 1), rng.randi_range(0, board.rows / 2 - 1))
			if layout.fits(item, board, stats):
				layout.add(item)
			continue
		if kind.rotatable:
			item.rot = rng.randf_range(0.0, 360.0) if rng.randf() < 0.5 else rng.randi() % 24 * 15.0
		var ok := false
		for attempt in 30:
			item.pos = Vector2(rng.randf(), rng.randf()) * board.size()
			if layout.fits(item, board, stats):
				ok = true
				break
		if not ok:
			continue
		var start := item.pos
		var d: Vector2 = Vector2.from_angle(rng.randf_range(0, TAU)) if rng.randf() < 0.5 else [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN][rng.randi() % 4]
		var lo := 0.0
		var hi := 2.0
		while hi < 1500.0:
			item.pos = start + d * hi
			if not layout.fits(item, board, stats):
				break
			lo = hi
			hi *= 2.0
		if hi >= 1500.0:
			item.pos = start + d * lo
		else:
			for k in 30:
				var mid := (lo + hi) * 0.5
				item.pos = start + d * mid
				if layout.fits(item, board, stats):
					lo = mid
				else:
					hi = mid
			item.pos = start + d * lo
		if not layout.fits(item, board, stats):
			continue
		layout.add(item)
		var tip := item.pos
		for p in item.outline():
			if (p - item.pos).dot(d) > (tip - item.pos).dot(d):
				tip = p
		contacts.append(tip)
	return [layout, contacts]


## What a ball centred on `point` is inside of, by more than SLACK, or "" for nothing.
func _inside(point: Vector2, half: float, round: Round, paddle: bool) -> String:
	var board := round.board
	var size := board.size()
	if point.y < half - SLACK or point.y > size.y - half + SLACK or point.x > size.x - half + SLACK:
		return "wall"
	var square := Rect2(point, Vector2.ZERO).grow(half - SLACK)
	if paddle and square.intersects(round.paddle.rect()):
		return "paddle"
	var first := board.cell_at(square.position)
	var last := board.cell_at(square.end)
	for column in range(first.x, last.x + 1):
		for row in range(first.y, last.y + 1):
			if board.bricks.has(Vector2i(column, row)):
				return "brick %s" % Vector2i(column, row)
	for item: Layout.Item in round.layout.items:
		if item.kind.placement != PlaceableKind.Placement.FREE or point.distance_to(item.pos) > 90.0:
			continue
		if item.kind.shape == PlaceableKind.Shape.CIRCLE:
			if point.distance_to(item.pos) < item.kind.size.x * 0.5 + half - SLACK:
				return "booster"
		elif not Geometry2D.intersect_polygons(Collide.box(square), item.outline()).is_empty():
			return String(item.kind.id)
	return ""


func _angle(dir: Vector2) -> float:
	return rad_to_deg(atan2(absf(dir.y), absf(dir.x)))


func _bad_number(v: Variant) -> bool:
	if v is Vector2:
		return not (is_finite(v.x) and is_finite(v.y))
	return not is_finite(v)


## Everything a round emits, as text, in order.
func _events(round: Round) -> Array[String]:
	var log: Array[String] = []
	round.brick_hit.connect(func(cell: Vector2i, hp: int, cause: Round.Cause) -> void: log.append("hit %s %d %d" % [cell, hp, cause]))
	round.brick_broken.connect(func(cell: Vector2i, brick: Brick, cause: Round.Cause, dir: Vector2, coins: int) -> void: log.append("broke %s '%s' %d %s %d" % [cell, brick.kind, cause, var_to_str(dir), coins]))
	round.ball_bounced.connect(func(ball: Ball, hit: Hit) -> void: log.append("bounce %d %d %s %s" % [ball.id, hit.surface, var_to_str(hit.point), var_to_str(ball.dir)]))
	round.ball_added.connect(func(ball: Ball) -> void: log.append("added %d %s" % [ball.id, var_to_str(ball.pos)]))
	round.ball_lost.connect(func(ball: Ball) -> void: log.append("lost %d %s" % [ball.id, var_to_str(ball.pos)]))
	round.exploded.connect(func(pos: Vector2, reach: float, cells: Array[Vector2i]) -> void: log.append("exploded %s %s %d" % [pos, reach, cells.size()]))
	round.ended.connect(func(reason: Round.End) -> void: log.append("ended %d" % reason))
	return log


## Paddle input: one of several styles, changing now and then.
func _target(rng: RandomNumberGenerator, round: Round, step: int, style: int) -> float:
	match style:
		0:  # follow the ball coming back, with a wobble so it also misses and hits the ends
			var target := round.paddle.y + sin(step * 0.07) * 60.0
			for ball in round.balls:
				if ball.dir.x < 0.0:
					target = ball.pos.y + sin(step * 0.11) * round.paddle.length * 0.6
			return target
		1:  # keys, flipping
			return [-INF, INF, round.paddle.y][(step / 7 + rng.randi() % 2) % 3]
		2:  # the mouse jumping about
			return rng.randf() * round.board.size().y
		_:  # chase the nearest ball's y exactly: the paddle's end meets balls as it moves
			var target := round.paddle.y
			var best := INF
			for ball in round.balls:
				if absf(ball.pos.x - round.paddle.x) < best:
					best = absf(ball.pos.x - round.paddle.x)
					target = ball.pos.y + round.paddle.length * 0.5 * (1.0 if step % 2 else -1.0)
			return target


## One whole random round, checked after every step and at every contact.
## `cfg` may set any of: board, stats, layout, dt, pos and dir (the first ball's start), style (paddle input), name.
func _attack(p_seed: int, wrong: Dictionary, seen: Dictionary, cfg := {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var board: Board = cfg.board if cfg.has("board") else _random_board(rng)
	var stats: Balance = cfg.stats if cfg.has("stats") else _random_stats(rng)
	if not cfg.has("stats") and rng.randf() < 0.5:
		stats.paddle_size = board.size().y  # sealed
	var targets: Array[Vector2] = []
	var layout: Layout
	if cfg.has("layout"):
		layout = cfg.layout
	elif rng.randf() < 0.5:
		var snug := _snug_layout(rng, board, stats)
		layout = snug[0]
		targets = snug[1]
	else:
		layout = _random_layout(rng, board, stats)
	for corner_i in 30:  # brick corners too
		targets.append(Vector2(rng.randi_range(0, board.cols), rng.randi_range(0, board.rows / 2)) * Board.BRICK)
	var dt: float = cfg.dt if cfg.has("dt") else [1.0 / 240.0, 1.0 / 120.0, 1.0 / 60.0, 1.0 / 30.0, 1.0 / 144.0, 0.1][rng.randi() % 6]
	var round := Round.new(board, layout, stats, p_seed)
	seen.rounds += 1
	var tag := "%s seed %d, %d rows, %d/s" % [cfg.get("name", ""), p_seed, board.rows, roundi(1.0 / dt)]
	var balls := round.balls
	var h := stats.ball_size * 0.5
	var cap := maxf(stats.boost_cap, 1.0)
	# Per ball id: the last tested point, the path length this step, the boost last seen, and whether this step's
	# length is not comparable (boost changed, ball made).
	var at := {}
	var length := {}
	var boost := {}
	var skip := {}
	var still := {}  # contacts in a row with no movement, per ball: a wedge exit may leave at any angle
	var contacts := [0]
	var inside_paddle := {}  # balls the paddle moved onto at the start of this step: they are let out, not hit
	var me := self
	var follow := func(why: String) -> void:
		contacts[0] += 1
		for ball: Ball in balls:
			if not at.has(ball.id):
				at[ball.id] = ball.pos
				length[ball.id] = 0.0
				boost[ball.id] = ball.boost
				skip[ball.id] = true
				still[ball.id] = 0
			var a: Vector2 = at[ball.id]
			var cuts := ceili(a.distance_to(ball.pos) / 1.0)
			for i in cuts + 1:
				var p := a.lerp(ball.pos, float(i) / maxi(cuts, 1))
				var what: String = me._inside(p, h, round, not inside_paddle.has(ball.id))
				if what:
					me._say(wrong, "a ball's path goes into a " + what.get_slice(" ", 0), "%s: ball %d at %s (%s)" % [tag, ball.id, p, what])
					break
			still[ball.id] = still[ball.id] + 1 if a.distance_to(ball.pos) < 0.02 else 0
			length[ball.id] += a.distance_to(ball.pos)
			at[ball.id] = ball.pos
			if ball.boost != boost[ball.id]:
				boost[ball.id] = ball.boost
				skip[ball.id] = true
			if me._bad_number(ball.pos) or me._bad_number(ball.dir) or me._bad_number(ball.boost):
				me._say(wrong, "a ball has a NaN or infinite value", "%s: ball %d %s %s %s" % [tag, ball.id, ball.pos, ball.dir, ball.boost])
			if absf(ball.dir.length() - 1.0) > 1e-5:
				me._say(wrong, "a ball's dir is not a unit vector", "%s: %f" % [tag, ball.dir.length()])
			if ball.boost < 1.0 or ball.boost > cap:
				me._say(wrong, "a ball's boost leaves 1 to the cap", "%s: %f" % [tag, ball.boost])
			var ang: float = me._angle(ball.dir)
			if (ang < stats.min_angle_horizontal - LOW_SLACK or ang > 90.0 - stats.min_angle_vertical + LOW_SLACK) and ball.dir != Vector2.LEFT and still[ball.id] < Round.WEDGED - 1:
				me._say(wrong, "a ball leaves a contact at an illegal angle", "%s: ball %d at %.3f degrees, at %s, after %s" % [tag, ball.id, ang, ball.pos, why])
	round.ball_bounced.connect(func(ball: Ball, hit: Hit) -> void:
		var prev: float = boost.get(ball.id, ball.boost)
		var thrown := skip.has(ball.id)
		follow.call("bounce %d" % hit.surface)
		if hit.surface == Hit.Surface.PADDLE and ball.boost != 1.0:
			me._say(wrong, "the paddle does not reset the boost", "%s: %f" % [tag, ball.boost])
		if hit.surface == Hit.Surface.ITEM and hit.item.kind.id == &"booster":
			var want := minf(prev + hit.item.kind.get("boost"), cap)
			if not thrown and not is_equal_approx(ball.boost, want):
				me._say(wrong, "a Booster does not add its share", "%s: %f, not %f" % [tag, ball.boost, want])
		pass)
	round.brick_hit.connect(func(_c: Vector2i, _hp: int, _cause: Round.Cause) -> void: follow.call("brick hit"))
	round.brick_broken.connect(func(_c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, _n: int) -> void: follow.call("brick broken"))
	round.ball_added.connect(func(_b: Ball) -> void: follow.call("added"))
	round.ball_lost.connect(func(ball: Ball) -> void:
		if absf(ball.pos.x - (-board.lane() - h)) > 0.05:
			me._say(wrong, "a ball is lost somewhere other than wholly past the open side", "%s: %s" % [tag, ball.pos])
		at.erase(ball.id))
	round.exploded.connect(func(_p: Vector2, _r: float, _c: Array[Vector2i]) -> void:
		for ball: Ball in balls:
			skip[ball.id] = true)
	# Sometimes the ball starts somewhere else, aimed exactly at a corner of a brick or of the grid.
	if cfg.has("pos"):
		round.balls[0].put(cfg.pos, cfg.dir)
	elif rng.randf() < 0.5:
		for attempt in 50:
			var p := Vector2(rng.randf_range(h, board.size().x - h), rng.randf_range(h, board.size().y - h)).snapped(Vector2.ONE)
			if _inside(p, h + 0.5, round, true):
				continue
			var corner: Vector2 = targets[rng.randi() % targets.size()]
			var aim := corner - p
			if rng.randf() < 0.5:
				aim -= Vector2(signf(aim.x), signf(aim.y)) * h  # the ball's own corner meets it
			if aim.length() < 1.0:
				continue
			var d := aim.normalized()
			if _angle(d) < stats.min_angle_horizontal or _angle(d) > 90.0 - stats.min_angle_vertical:
				continue
			round.balls[0].put(p, d)
			break
	follow.call("start")
	var style: int = cfg.get("style", rng.randi() % 4)
	var start_pos := round.balls[0].pos
	var start_dir := round.balls[0].dir
	var lasted := 0.0
	var limit := stats.round_time + 2.0 * stats.count(&"hourglass") * 2.0 + 5.0
	var history := {}  # ball id -> positions over the last second
	var step := 0
	while not round.over:
		if lasted > limit + 1.0:
			_say(wrong, "a round does not end", tag)
			break
		if rng.randf() < 0.01 and not cfg.has("style"):
			style = rng.randi() % 4
		for id: int in length:
			length[id] = 0.0
		skip.clear()
		contacts[0] = 0
		var target := _target(rng, round, step, style)
		# Which balls will the paddle be on after it moves: replay its move here.
		var half := minf(round.paddle.length, board.size().y) * 0.5
		var py := clampf(move_toward(round.paddle.y, target, stats.paddle_speed * dt), half, board.size().y - half)
		var pr := Rect2(round.paddle.x - round.paddle.thickness, py - round.paddle.length * 0.5, round.paddle.thickness, round.paddle.length)
		inside_paddle.clear()
		for ball in balls:
			if Rect2(ball.pos, Vector2.ZERO).grow(h - SLACK).intersects(pr):
				inside_paddle[ball.id] = true
		round.step(dt, target)
		step += 1
		lasted += dt
		follow.call("step")
		seen.steps += 1
		seen.contacts += contacts[0]
		seen.balls = maxi(seen.balls, balls.size())
		if _bad_number(round.paddle.y) or _bad_number(round.time_left):
			_say(wrong, "the paddle or the timer is NaN", tag)
		for ball in balls:
			if not skip.has(ball.id) and absf(length[ball.id] - round.speed_of(ball) * dt) > 0.02 and still.get(ball.id, 0) < Round.WEDGED - 1:
				_say(wrong, "a ball does not cover speed x time in a step", "%s: ball %d went %f, not %f (%d contacts, boost %f)" % [tag, ball.id, length[ball.id], round.speed_of(ball) * dt, contacts[0], ball.boost])
			if not is_equal_approx(round.speed_of(ball), stats.ball_speed * ball.boost):
				_say(wrong, "speed_of is not ball_speed x boost", tag)
			if ball.pos.x < -board.lane() - h - SLACK:
				_say(wrong, "a ball is past the open side and not lost", "%s: %s" % [tag, ball.pos])
			# Stuck: still in a box 2 units across after a second.
			var hist: Array = history.get(ball.id, [])
			hist.append(ball.pos)
			if hist.size() > ceili(1.0 / dt):
				hist.pop_front()
				var box := Rect2(hist[0], Vector2.ZERO)
				for p: Vector2 in hist:
					box = box.expand(p)
				if box.size.x < 2.0 and box.size.y < 2.0:
					_say(wrong, "a ball is stuck in one place", "%s: ball %d at %s" % [tag, ball.id, ball.pos])
					hist.clear()
			history[ball.id] = hist
		if contacts[0] > 200:
			_say(wrong, "a step needs over 200 contacts", "%s: %d at step %d" % [tag, contacts[0], step])
	_drop(round)
	# The same round again gives the same events.
	if p_seed % 4 == 0:
		var logs := []
		for again in 2:
			var r2 := Round.new(board, layout, stats, p_seed)
			r2.balls[0].put(start_pos, start_dir)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = p_seed * 7
			var log := _events(r2)
			var i := 0
			while not r2.over and i < 20000:
				r2.step(dt, _target(rng2, r2, i, p_seed % 4))
				i += 1
			logs.append(log)
			_drop(r2)
		if logs[0] != logs[1]:
			_say(wrong, "the same round twice gives other events", tag)


## Tick rates: one ball (no Splitter), a paddle that stays put. The same bricks must be hit and broken in the same
## order at 60, 120 and 240 steps a second.
func _rates(p_seed: int, wrong: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed + 1000
	var board := _random_board(rng)
	var stats := _random_stats(rng)
	stats.put(&"splitter_count", 0)
	if rng.randf() < 0.6:
		stats.paddle_size = board.size().y
	var layout := _random_layout(rng, board, stats)
	var start := Vector2.ZERO
	var dir := Vector2.ZERO
	if rng.randf() < 0.7:
		var probe := Round.new(board, layout, stats, p_seed)
		for attempt in 50:
			var p := Vector2(rng.randf_range(10, board.size().x - 10), rng.randf_range(10, board.size().y - 10))
			if _inside(p, 6.5, probe, true):
				continue
			start = p
			dir = Vector2.from_angle(rng.randf_range(0, TAU))
			if _angle(dir) < stats.min_angle_horizontal or _angle(dir) > 90.0 - stats.min_angle_vertical:
				dir = Vector2(0.8, 0.6) * dir.sign()
				if dir.x == 0 or dir.y == 0:
					dir = Vector2(0.8, 0.6)
			break
	var logs := []
	for rate: int in [60, 120, 240]:
		var round := Round.new(board, layout, stats, p_seed)
		if dir != Vector2.ZERO:
			round.balls[0].put(start, dir)
		var log := _events(round)
		var i := 0
		while not round.over and i < rate * 60:
			round.step(1.0 / rate, round.paddle.y)
			i += 1
		_drop(round)
		logs.append(log.filter(func(line: String) -> bool: return line.begins_with("hit") or line.begins_with("broke")).map(
				func(line: String) -> String: return line.get_slice(")", 0)))
	for k in [1, 2]:
		if logs[0] != logs[k]:
			var n := 0
			while n < mini(logs[0].size(), logs[k].size()) and logs[0][n] == logs[k][n]:
				n += 1
			_say(wrong, "a round hits other bricks at another tick rate", "seed %d (rates), %d rows: 60/s and %d/s part after %d of %d/%d events: %s vs %s" % [p_seed, board.rows, [60, 120, 240][k], n, logs[0].size(), logs[k].size(),
					logs[0][n] if n < logs[0].size() else "-", logs[k][n] if n < logs[k].size() else "-"])


## Cuts every connection, so a round held by a lambda it holds is freed.
func _drop(round: Round) -> void:
	for sig in round.get_signal_list():
		for c in round.get_signal_connection_list(sig.name):
			round.disconnect(sig.name, c.callable)
