extends RefCounted
## The rules lane's case: src/sim/ and src/kinds/, on boards built by hand. It reads no level file, no save and
## no autoload's state, so it passes while the lanes beside it are still stubs.

const TICK := 1.0 / 120.0
## Units. Positions are 32-bit floats, so "the same place" is within this.
const NEAR := 0.01
## A brick the ball cannot break, so a round with one on the board never counts as cleared.
const SOLID := 1000000
const FAR := Vector2i(63, 0)
## The numbers the checks are written against: data/balance.tres as it was when they were written. A copy, so
## that tuning that file moves no check here. _shipped() is the one check that reads the file itself.
const NUMBERS := {
	&"paddle_speed": 360.0, &"paddle_size": 96.0, &"ball_speed": 560.0, &"round_time": 20.0, &"combo_rank": 0.0, &"blast_size": 1.0, &"shockwave": 0.0,
	&"ball_size": 12.0, &"launch_gap": 48.0, &"min_angle_vertical": 20.0, &"min_angle_horizontal": 8.0, &"boost_cap": 3.0, &"shockwave_boost": 2.0,
	&"paddle_thickness": 12.0, &"paddle_inset": 24.0, &"paddle_max_angle": 60.0, &"low_time": 5.0,
	&"combo_window": 1.6, &"combo_window_per_rank": 0.5, &"combo_breaks_per_step": 4, &"combo_window_shrink": 0.9, &"combo_window_min": 0.5,
	&"coins_per_brick": 1.0, &"rotate_step": 15.0,
	&"explosion_damage": 1.0, &"zap_range": 64.0, &"zap_damage": 1.0, &"splitter_splits": 2.0,
}

var t: Node


func run(p_t: Node) -> void:
	t = p_t
	_shipped()
	_kinds()
	_build()
	_speed()
	_paddle()
	_angles()
	_tunnelling()
	_fuzz()
	_wedge()
	_tick_rates()
	_determinism()
	_brick_hits()
	_blasts()
	_zap()
	_shockwave()
	_placeables()
	_growth()
	_refresh()
	_overgrowth()
	_balls()
	_specials()
	_layouts()
	_combo()
	_coins()
	_ends()
	_timing()
	_launch()


## Round.hold and Round.launch: the ball rides on the paddle and nothing else moves, then leaves within
## LAUNCH_ANGLE of level, the same way for the same seed.
func _launch() -> void:
	var stats := _stats()
	var round := Round.new(_board(), null, stats, 1)
	round.hold()
	for i in 10:
		round.step(0.05, INF)
	var ball := round.balls[0]
	t.check(round.held and ball.pos == Vector2(round.paddle.x + stats.ball_size * 0.5, round.paddle.y) and round.paddle.y > 256.0
			and round.time_left == stats.round_time, "a held ball rides on the paddle's face as it moves, and the clock waits")
	var angles := []
	for seed in 200:
		var r := Round.new(_board(), null, stats, seed)
		r.hold()
		r.launch()
		angles.append(rad_to_deg(r.balls[0].dir.angle()))
	t.check(angles.all(func(a: float) -> bool: return absf(a) <= Round.LAUNCH_ANGLE + 0.001 and absf(a) >= stats.min_angle_horizontal - 0.001)
			and angles.min() < -30.0 and angles.max() > 30.0, "the launch goes toward the board within 45 degrees of level either way, minimum angle kept")
	var dirs := []
	for i in 2:
		var r := Round.new(_board(), null, stats, 7)
		r.hold()
		r.launch()
		dirs.append(r.balls[0].dir)
	t.check(dirs[0] == dirs[1], "the same seed launches the same way")


# --- helpers ---------------------------------------------------------------------------------------------------

## NUMBERS as a stats snapshot a check may change, with `stats` set on top: {&"bumper_count": 2}.
func _stats(stats := {}) -> Balance:
	var s := Balance.new()
	for stat: StringName in NUMBERS:
		s.set(stat, NUMBERS[stat])
	for stat: StringName in stats:
		s.put(stat, stats[stat])
	return s


## The same, for a round that ends only when the check wants: the paddle covers the whole open side, so no ball
## is lost and the paddle never moves, and the timer is long.
func _sealed(board: Board, stats := {}) -> Balance:
	var s := _stats(stats)
	s.paddle_size = board.size().y
	s.round_time = 100000.0
	return s


## A board with a standard brick at each cell given, {cell: hp}.
func _board(bricks := {}, rows := 16) -> Board:
	var b := Board.new(rows)
	for cell: Vector2i in bricks:
		b.bricks[cell] = Brick.new(bricks[cell])
	return b


## An item of a kind at a point (FREE) or a brick cell (BRICK, MOD).
func _item(kind: StringName, at: Variant, rot := 0.0) -> Layout.Item:
	var item := Layout.Item.new()
	item.kind = Kinds.of(kind)
	if at is Vector2i:
		item.cell = at
	else:
		item.pos = at
	item.rot = rot
	return item


func _layout(items: Array) -> Layout:
	var layout := Layout.new()
	for item: Layout.Item in items:
		layout.add(item)
	return layout


func _run(round: Round, seconds: float, dt := TICK) -> void:
	for i in roundi(seconds / dt):
		round.step(dt, round.paddle.y)


## A direction's angle from level, in degrees: 0 to 90.
func _angle(dir: Vector2) -> float:
	return rad_to_deg(atan2(absf(dir.y), absf(dir.x)))


## Everything a round emits from now on, as text, in order.
func _events(round: Round) -> Array[String]:
	var log: Array[String] = []
	round.brick_hit.connect(func(cell: Vector2i, hp: int, cause: Round.Cause) -> void: log.append("hit %s %d %d" % [cell, hp, cause]))
	round.brick_broken.connect(func(cell: Vector2i, brick: Brick, cause: Round.Cause, dir: Vector2, coins: int) -> void: log.append("broke %s '%s' %d %s %d" % [cell, brick.kind, cause, var_to_str(dir), coins]))
	round.ball_bounced.connect(func(ball: Ball, hit: Hit) -> void: log.append("bounce %d %d %s %s" % [ball.id, hit.surface, var_to_str(hit.point), var_to_str(ball.dir)]))
	round.ball_added.connect(func(ball: Ball) -> void: log.append("added %d %s" % [ball.id, var_to_str(ball.pos)]))
	round.ball_lost.connect(func(ball: Ball) -> void: log.append("lost %d %s" % [ball.id, var_to_str(ball.pos)]))
	round.exploded.connect(func(pos: Vector2, reach: float, cells: Array[Vector2i]) -> void: log.append("exploded %s %s %d" % [pos, reach, cells.size()]))
	round.combo_changed.connect(func(count: int, multiplier: int) -> void: log.append("combo %d %d" % [count, multiplier]))
	round.time_changed.connect(func(left: float, added: float) -> void: log.append("time %s %s" % [left, added]))
	round.ended.connect(func(reason: Round.End) -> void: log.append("ended %d" % reason))
	return log


## Steps a one-ball round for `seconds` and returns the most any step's path differed from speed x time, in
## units. The path runs through every point the ball bounced at. A step in which the boost changed is skipped.
func _speed_error(round: Round, seconds: float, dt: float) -> float:
	var ball := round.balls[0]
	var path: Array[Vector2] = []
	round.ball_bounced.connect(func(_b: Ball, hit: Hit) -> void: path.append(hit.point))
	round.brick_hit.connect(func(_c: Vector2i, _hp: int, _cause: Round.Cause) -> void: path.append(ball.pos))
	round.brick_broken.connect(func(_c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, _n: int) -> void: path.append(ball.pos))
	var worst := 0.0
	for i in roundi(seconds / dt):
		path.clear()
		var at := ball.pos
		var boost := ball.boost
		round.step(dt, round.paddle.y)
		path.append(ball.pos)
		if ball.boost != boost:
			continue
		var length := 0.0
		for point in path:
			length += at.distance_to(point)
			at = point
		worst = maxf(worst, absf(length - round.speed_of(ball) * dt))
		worst = maxf(worst, absf(ball.dir.length() - 1.0))
	return worst


## A closed pen of four Wall Segments around `centre`, turned by `turn` degrees, with a Booster in the middle.
## The inside is 102 x 102 units.
func _pen(centre: Vector2, turn: float) -> Layout:
	var items := [_item(&"booster", centre)]
	for wall: Array in [[Vector2(5, -56), 90.0], [Vector2(56, 5), 0.0], [Vector2(-5, 56), 90.0], [Vector2(-56, -5), 0.0]]:
		items.append(_item(&"wall_segment", centre + (wall[0] as Vector2).rotated(deg_to_rad(turn)), wall[1] + turn))
	return _layout(items)


# --- the shipped numbers ---------------------------------------------------------------------------------------

## What the rules need of data/balance.tres, whatever it is tuned to.
func _shipped() -> void:
	var s: Balance = load("res://data/balance.tres")
	for stat: StringName in NUMBERS:
		t.check(s.get(stat) != null, "Balance has the number %s" % stat)
	t.check(s.min_angle_horizontal <= s.paddle_max_angle and s.paddle_max_angle <= 90.0 - s.min_angle_vertical, "the paddle's steepest angle is a legal angle")
	t.check(s.boost_cap >= 1.0 and s.shockwave_boost >= 1.0, "a boost never slows a ball")
	t.check(Board.LANE_PX - s.paddle_inset - s.paddle_thickness >= s.ball_size, "on a 16-row board a ball fits between the paddle's face and the grid, so nothing placed can wedge it there")
	t.check(s.launch_gap >= 0.0 and s.paddle_inset >= 0.0 and s.paddle_size > 0.0 and s.ball_speed > 0.0 and s.combo_breaks_per_step >= 1, "the ball starts in front of the paddle and moves")


# --- the kinds -------------------------------------------------------------------------------------------------

func _kinds() -> void:
	var ids := func(kinds: Array) -> Array: return kinds.map(func(k: Kind) -> StringName: return k.id)
	t.check(ids.call(Kinds.placeables()) == [&"bumper", &"booster", &"wall_segment", &"splitter", &"zap", &"growth", &"refresh"], "the placeables are the seven of the kinds table, in tray order")
	t.check(ids.call(Kinds.bricks()) == [&"explosive", &"gold", &"hourglass", &"tough"], "the special bricks are the four of the kinds table, in roll order")
	# id: [placement, shape, size, turn, rotatable, cue]
	var placeables := {
		&"bumper": [PlaceableKind.Placement.FREE, PlaceableKind.Shape.RECT, Vector2(30, 30), 45.0, false, Sfx.BUMPER],
		&"booster": [PlaceableKind.Placement.FREE, PlaceableKind.Shape.CIRCLE, Vector2(32, 32), 0.0, false, Sfx.BOOSTER],
		&"wall_segment": [PlaceableKind.Placement.FREE, PlaceableKind.Shape.RECT, Vector2(10, 112), 0.0, true, Sfx.WALL_BOUNCE],
		&"splitter": [PlaceableKind.Placement.BRICK, PlaceableKind.Shape.RECT, Vector2.ZERO, 0.0, false, &""],  # no cue: Sfx plays SPLITTER from ball_added
		&"zap": [PlaceableKind.Placement.MOD, PlaceableKind.Shape.RECT, Vector2(6, 6), 0.0, false, Sfx.ZAP],
		&"growth": [PlaceableKind.Placement.BRICK, PlaceableKind.Shape.RECT, Vector2.ZERO, 0.0, false, Sfx.BOOSTER],  # the cue of its pulse
		&"refresh": [PlaceableKind.Placement.BRICK, PlaceableKind.Shape.RECT, Vector2.ZERO, 0.0, false, Sfx.PLACE_ITEM],  # the cue of the bricks it brings back
	}
	for id: StringName in placeables:
		var k := Kinds.of(id) as PlaceableKind
		var want: Array = placeables[id]
		t.check(k != null and [k.placement, k.shape, k.size, k.turn, k.rotatable, k.cue] == want and k.colour == &"placeable" and k.hp == 1 and k.title != "",
				"the %s is as the kinds table has it" % id)
	# id: [colour, cue, worth, hp]. The tough brick has no colour: it is drawn in the HP steps.
	var bricks := {&"explosive": [&"explosive", &"", 1, 1], &"gold": [&"coins", Sfx.GOLD_BRICK, 20, 1], &"hourglass": [&"time", Sfx.HOURGLASS_BRICK, 1, 1], &"tough": [&"", &"", 1, 3]}
	for id: StringName in bricks:
		var k := Kinds.of(id) as BrickKind
		t.check(k != null and [k.colour, k.cue, k.worth, k.hp] == bricks[id] and k.title != "", "the %s brick is as the kinds table has it" % id)
	for k in Kinds.all():
		t.check(Palette.MEANINGS.has(k.colour) or k.id == &"tough", "%s's colour is a Palette meaning" % k.id)
	# The three amounts are pinned here and nowhere else: the other checks read them from the kinds.
	t.check(Kinds.of(&"booster").get("boost") == 0.1 and Kinds.of(&"hourglass").get("seconds") == 15.0, "the Booster adds 0.1 and the hourglass 15 s, from their files")


# --- building and the first step -------------------------------------------------------------------------------

func _build() -> void:
	var board := _board({FAR: SOLID})
	var stats := _stats()
	var round := Round.new(board, null, stats, 1)
	var ball := round.balls[0]
	t.check(round.paddle.x == -22.0 and round.paddle.y == 256.0 and round.paddle.length == 96.0 and round.paddle.thickness == 12.0,
			"the paddle starts centred, its face 36 units in from the open side")
	t.check(round.balls.size() == 1 and ball.id == 0 and ball.pos == Vector2(32, 256) and ball.dir == Vector2.LEFT and ball.boost == 1.0 and ball.size == 12.0,
			"one ball rests launch_gap to the right of the paddle's face, level with it, facing it")
	t.check(ball.pos == Round.ball_start(board, stats), "Round.ball_start is where the ball rests")
	t.check(round.time_left == 20.0 and round.coins == 0 and not round.over, "a new round has its full time, no coins and is not over")

	var hits: Array[Hit] = []
	round.ball_bounced.connect(func(_b: Ball, hit: Hit) -> void: hits.append(hit))
	round.step(TICK, round.paddle.y)
	t.check(ball.dir == Vector2.LEFT and is_equal_approx(ball.pos.x, 32.0 - stats.ball_speed * TICK) and ball.pos.y == 256.0,
			"the first step sends the ball straight left at ball_speed")
	_run(round, 0.1)
	t.check(hits.size() == 1 and hits[0].surface == Hit.Surface.PADDLE and hits[0].normal == Vector2.RIGHT and hits[0].point == Vector2(-16, 256),
			"the launched ball lands on the paddle's face")
	t.check(ball.dir.is_equal_approx(Vector2.from_angle(deg_to_rad(stats.min_angle_horizontal))),
			"off the dead centre of the paddle the ball leaves at the minimum angle, not back along its line")


# --- constant speed --------------------------------------------------------------------------------------------

func _speed() -> void:
	var board := _board({FAR: SOLID, Vector2i(40, 2): 3, Vector2i(40, 3): 2, Vector2i(41, 5): 1, Vector2i(52, 6): 4, Vector2i(30, 0): 2})
	var stats := _sealed(board, {&"bumper_count": 1, &"wall_segment_count": 2})
	var layout := _layout([_item(&"bumper", Vector2(300, 150)), _item(&"wall_segment", Vector2(500, 380), 30.0), _item(&"wall_segment", Vector2(200, 420), 90.0)])
	for dt: float in [TICK, 1.0 / 60.0, 1.0 / 37.0]:
		var round := Round.new(board, layout, stats, 1)
		var bounces := {Hit.Surface.WALL: 0, Hit.Surface.PADDLE: 0, Hit.Surface.ITEM: 0}
		round.ball_bounced.connect(func(_b: Ball, hit: Hit) -> void: bounces[hit.surface] += 1)
		var worst := _speed_error(round, 30.0, dt)
		t.check(round.layout.items.size() == 3 and bounces.values().min() > 0 and round.board.bricks.size() < 6, "the speed check's round bounces off walls, the paddle, items and bricks (%s)" % [bounces])
		t.check(worst < NEAR, "a ball covers exactly speed x time in every step, through every bounce (off by %f at %d steps a second)" % [worst, roundi(1.0 / dt)])
		t.check(round.balls[0].boost == 1.0, "nothing but a boost changes a ball's speed")

	# Boosted: a ball penned in with a Booster reaches the cap and holds that speed.
	stats = _sealed(board, {&"booster_count": 1, &"wall_segment_count": 4})
	var round := Round.new(board, _pen(Vector2(351, 261), 0.0), stats, 1)
	round.balls[0].put(Vector2(320, 230), Vector2(0.8, 0.6))
	_run(round, 8.0)
	t.check(round.balls[0].boost == stats.boost_cap, "boosts stack up to the cap and stop there")
	var worst := _speed_error(round, 5.0, TICK)
	t.check(worst < NEAR and is_equal_approx(round.speed_of(round.balls[0]), stats.ball_speed * stats.boost_cap), "a boosted ball holds its boosted speed until the paddle (off by %f)" % worst)


# --- the paddle ------------------------------------------------------------------------------------------------

func _paddle() -> void:
	var board := _board({FAR: SOLID})
	var stats := _stats()
	for where: float in [-1.0, -0.5, 0.0, 0.25, 1.0, 1.1]:
		var out: Array[Vector2] = []
		for coming: float in [20.0, -45.0]:
			var round := Round.new(board, null, stats, 1)
			var ball := round.balls[0]
			var dir := Vector2.LEFT.rotated(deg_to_rad(coming))
			var land := Vector2(round.paddle.x + 6.0, round.paddle.y + where * 48.0)
			ball.put(land - dir * 40.0, dir)
			round.set_boost(ball, 2.0)
			var hits: Array[Hit] = []
			round.ball_bounced.connect(func(_b: Ball, hit: Hit) -> void: hits.append(hit))
			_run(round, 0.05)
			t.check(hits.size() == 1 and hits[0].surface == Hit.Surface.PADDLE and hits[0].normal == Vector2.RIGHT and hits[0].point.distance_to(land) < NEAR,
					"a ball aimed %.2f of the way along the paddle lands there" % where)
			t.check(ball.boost == 1.0, "touching the paddle ends a boost")
			out.append(ball.dir)
		var want := Vector2.RIGHT.rotated(deg_to_rad(clampf(where, -1.0, 1.0) * stats.paddle_max_angle))
		if where == 0.0:
			want = Vector2.from_angle(deg_to_rad(stats.min_angle_horizontal))
		t.check(out[0] == out[1], "the angle off the paddle does not depend on the angle the ball came in at")
		t.check(out[0].is_equal_approx(want), "%.2f of the way along the paddle sends the ball off at %.0f degrees" % [where, rad_to_deg(want.angle())])

	# Past the end of the paddle is a miss.
	var round := Round.new(board, null, stats, 1)
	var ball := round.balls[0]
	ball.put(Vector2(20, round.paddle.y + 48.0 + 6.5), Vector2.LEFT.rotated(deg_to_rad(-10.0)))
	_run(round, 0.3)
	t.check(round.balls.is_empty() and round.over and round.reason == Round.End.BALL_LOST, "a ball that passes the paddle's end is lost")

	# The paddle's end is solid too.
	round = Round.new(board, null, stats, 1)
	ball = round.balls[0]
	var hits: Array[Hit] = []
	round.ball_bounced.connect(func(_b: Ball, hit: Hit) -> void: hits.append(hit))
	ball.put(Vector2(round.paddle.x - 3.0, round.paddle.y - 48.0 - 6.0 - 20.0), Vector2(-cos(deg_to_rad(70.0)), sin(deg_to_rad(70.0))))
	_run(round, 0.1)
	t.check(hits.size() == 1 and hits[0].surface == Hit.Surface.PADDLE and hits[0].normal == Vector2.UP and ball.dir.is_equal_approx(Vector2.RIGHT.rotated(deg_to_rad(-stats.paddle_max_angle))),
			"a ball that comes down on the paddle's top end is sent back up and toward the board")

	# The paddle moving onto a ball beside it bounces the ball once and lets it out.
	round = Round.new(board, null, stats, 1)
	ball = round.balls[0]
	hits.clear()
	round.ball_bounced.connect(func(_b: Ball, hit: Hit) -> void: hits.append(hit))
	ball.put(Vector2(round.paddle.x - 6.0, round.paddle.y - 48.0 - 6.0 - 1.0), Vector2.LEFT.rotated(deg_to_rad(-10.0)))
	for i in 120:
		round.step(TICK, -INF)
	t.check(hits.size() >= 1 and hits[0].surface == Hit.Surface.PADDLE and hits[0].travel == 0.0, "a paddle that moves onto a ball bounces it where it is")
	t.check(hits.filter(func(h: Hit) -> bool: return h.surface == Hit.Surface.PADDLE).size() == 1 and round.balls.size() == 1 and ball.pos.x > 0.0,
			"and the ball leaves the paddle with one bounce, not one a step")

	# The paddle itself: it chases its target at paddle_speed and stays inside the walls.
	round = Round.new(board, null, stats, 1)
	round.step(0.1, INF)
	t.check(is_equal_approx(round.paddle.y, 256.0 + stats.paddle_speed * 0.1), "the paddle moves toward its target at paddle_speed")
	round.step(0.01, round.paddle.y - 1.0)
	t.check(is_equal_approx(round.paddle.y, 256.0 + stats.paddle_speed * 0.1 - 1.0), "the paddle stops on a target it can reach")
	round = Round.new(board, null, stats, 1)
	round.step(10.0, -INF)
	t.check(round.paddle.y == 48.0, "the paddle stops at the top wall")


# --- minimum angles --------------------------------------------------------------------------------------------

func _angles() -> void:
	var bricks := {FAR: SOLID}
	for column in range(36, 44):
		for row in 8:
			bricks[Vector2i(column, row)] = 1 + (column + row) % 3
	var board := _board(bricks)
	board.bricks[Vector2i(38, 2)].kind = &"explosive"
	var stats := _sealed(board, {&"bumper_count": 2, &"booster_count": 1, &"wall_segment_count": 2, &"splitter_count": 1, &"shockwave": 1})
	var layout := _layout([_item(&"bumper", Vector2(200, 120)), _item(&"bumper", Vector2(260, 400)), _item(&"booster", Vector2(450, 250)),
			_item(&"wall_segment", Vector2(120, 300), 15.0), _item(&"wall_segment", Vector2(500, 100), 75.0), _item(&"splitter", Vector2i(30, 5))])
	var round := Round.new(board, layout, stats, 3)
	var low := stats.min_angle_horizontal - 0.01
	var high := 90.0 - stats.min_angle_vertical + 0.01
	var bad: Array[float] = []
	var seen := [0]
	var look := func(ball: Ball) -> void:
		seen[0] += 1
		if _angle(ball.dir) < low or _angle(ball.dir) > high:
			bad.append(_angle(ball.dir))
	round.ball_bounced.connect(func(ball: Ball, _h: Hit) -> void: look.call(ball))
	var balls := round.balls  # not `round` itself: a round that holds a lambda that holds the round is never freed
	round.brick_hit.connect(func(_c: Vector2i, _hp: int, _cause: Round.Cause) -> void: balls.map(look))
	round.brick_broken.connect(func(_c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, _n: int) -> void: balls.map(look))
	_run(round, 60.0)
	t.check(round.layout.items.size() == 6 and seen[0] > 300 and round.balls.size() == 2, "the angle check's round has its items, its second ball and its bounces (%d)" % seen[0])
	t.check(bad.is_empty(), "after every bounce and throw a ball is at least %.0f degrees from level and %.0f from upright (saw %s)" % [stats.min_angle_horizontal, stats.min_angle_vertical, bad.slice(0, 5)])

	# A bounce that needs no nudge is an exact mirror.
	round = Round.new(_board({FAR: SOLID}), null, _sealed(board), 1)
	var ball := round.balls[0]
	ball.put(Vector2(300, 30), Vector2(0.6, -0.8))
	_run(round, 0.1)
	t.check(ball.dir == Vector2(0.6, 0.8), "a wall mirrors a ball's direction exactly")


# --- no tunnelling ---------------------------------------------------------------------------------------------

func _tunnelling() -> void:
	# A solid column of bricks: the ball stays between it and the paddle, inside the walls.
	var bricks := {}
	for row in 8:
		bricks[Vector2i(40, row)] = SOLID
	var board := _board(bricks)
	for speed: float in [560.0, 1680.0, 6000.0]:
		for dt: float in [1.0 / 240.0, 1.0 / 60.0, 1.0 / 20.0, 0.3]:
			var stats := _sealed(board)
			stats.ball_speed = speed
			var round := Round.new(board, null, stats, 1)
			var ball := round.balls[0]
			ball.put(Vector2(100, 200), Vector2(0.8, 0.6))
			var out := 0
			for i in 600:
				round.step(dt, round.paddle.y)
				if ball.pos.x < round.paddle.x + 6.0 - NEAR or ball.pos.x > 40 * 16 - 6.0 + NEAR or ball.pos.y < 6.0 - NEAR or ball.pos.y > 512.0 - 6.0 + NEAR:
					out += 1
			t.check(out == 0 and round.balls.size() == 1, "a ball at %d units a second and %d steps a second stays between the paddle, the walls and a brick" % [speed, roundi(1.0 / dt)])

	# The back wall, with no brick in the way.
	var round := Round.new(_board({FAR: SOLID}), null, _sealed(board), 1)
	round.stats.ball_speed = 6000.0
	round.balls[0].put(Vector2(100, 200), Vector2(0.8, 0.6))
	var past := 0
	for i in 600:
		round.step(1.0 / 30.0, round.paddle.y)
		if round.balls[0].pos.x > 1024.0 - 6.0 + NEAR:
			past += 1
	t.check(past == 0, "a fast ball stays in front of the back wall")

	# Placed items: a ball penned in by four Wall Segments, boosted to the cap by a Booster, never gets out and
	# never gets into the Booster. Square on, and turned.
	for turn: float in [0.0, 30.0, 45.0]:
		for dt: float in [1.0 / 240.0, 1.0 / 60.0, 1.0 / 20.0]:
			var centre := Vector2(351, 261)
			var stats := _sealed(board, {&"booster_count": 1, &"wall_segment_count": 4})
			round = Round.new(_board({FAR: SOLID}), _pen(centre, turn), stats, 1)
			var ball := round.balls[0]
			ball.put(centre + Vector2(-30, -30).rotated(deg_to_rad(turn)), Vector2(0.8, 0.6))
			var out := 0
			var top := 1.0
			for i in 1200:
				round.step(dt, round.paddle.y)
				top = maxf(top, ball.boost)
				var inside := (ball.pos - centre).rotated(deg_to_rad(-turn))
				if absf(inside.x) > 51.0 - 6.0 + NEAR or absf(inside.y) > 51.0 - 6.0 + NEAR or inside.length() < 16.0 + 6.0 - NEAR:
					out += 1
			t.check(round.layout.items.size() == 5, "the pen turned %d degrees fits: walls that touch do not overlap" % turn)
			t.check(out == 0 and top == stats.boost_cap, "a ball at the boost cap and %d steps a second stays inside a pen turned %d degrees and outside its Booster" % [roundi(1.0 / dt), turn])


# --- the same, on boards made at random ------------------------------------------------------------------------

## Rounds on random boards with random items, speeds and step sizes. Every ball's whole path, through each point
## it bounced at, is cut into points 1.5 units apart, and each point is tested for overlap the slow way, with none
## of the sweep's own geometry. Thinner than anything on the board, so nothing is passed through unseen.
func _fuzz() -> void:
	var wrong: Array[String] = []
	var seen := {&"points": 0, &"contacts": 0, &"balls": 0, &"open": 0}
	for trial in 16:
		_fuzz_round(trial, wrong, seen)
	t.check(seen.points > 100000 and seen.contacts > 3000 and seen.balls >= 3 and seen.open >= 3, "the random rounds cover ground (%s)" % seen)
	t.check(wrong.is_empty(), "on random boards a ball's path never overlaps a brick, a wall, the paddle or an item, its speed holds and its angles are legal (%d wrong, first: %s)" % [wrong.size(), wrong.slice(0, 3)])


func _fuzz_round(p_seed: int, wrong: Array[String], seen: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var board := Board.new([16, 18][rng.randi() % 2])
	var density := rng.randf_range(0.03, 0.5)
	for column in range(4, board.cols):
		for row in board.rows / 2:
			if rng.randf() < density:
				board.bricks[Vector2i(column, row)] = Brick.new([1, 1, 2, 3, SOLID][rng.randi() % 5])
	var stats := _stats({&"bumper_count": 4, &"booster_count": 4, &"wall_segment_count": 4, &"splitter_count": 4, &"zap_count": 4, &"explosive_count": rng.randi() % 4,
			&"hourglass_count": rng.randi() % 2, &"shockwave": rng.randi() % 2, &"combo_rank": rng.randi() % 4, &"ball_speed": rng.randf_range(300.0, 1700.0)})
	var sealed := rng.randf() < 0.6
	if sealed:
		stats.paddle_size = board.size().y
	else:
		seen.open += 1
	var layout := Layout.new()
	for i in 60:
		var kind := Kinds.placeables()[rng.randi() % 5]
		var item := _item(kind.id, Vector2(rng.randf(), rng.randf()) * board.size(), rng.randi() % 24 * 15.0 if kind.rotatable else 0.0)
		item.cell = board.cell_at(item.pos)
		if layout.fits(item, board, stats):
			layout.add(item)
	var round := Round.new(board, layout, stats, p_seed)
	var dt: float = [1.0 / 240.0, 1.0 / 120.0, 1.0 / 60.0, 1.0 / 30.0, 0.1][rng.randi() % 5]
	# Not `round` itself in the lambdas: a round that holds a lambda that holds the round is never freed.
	var live := round.board
	var balls := round.balls
	var solids := round.layout.items.filter(func(item: Layout.Item) -> bool: return item.kind.placement == PlaceableKind.Placement.FREE)
	var left := round.paddle.x if sealed else -INF
	var low := stats.min_angle_horizontal - 0.01
	var high := 90.0 - stats.min_angle_vertical + 0.01
	var at := {}  # by ball id: the last point of its path that was tested
	var length := {}  # by ball id: how far it has come this step
	var boost := {}
	var skip := {}  # balls whose boost changed this step, or that were made in it
	var say := func(what: String) -> void: wrong.append("seed %d, %d steps a second: %s" % [p_seed, roundi(1.0 / dt), what])
	# Balls move one at a time and a signal comes at the moment of a contact, so at every signal each ball is at a
	# corner of its path or has not moved since the last one.
	var follow := func() -> void:
		seen.contacts += 1
		for ball: Ball in balls:
			if not at.has(ball.id):
				at[ball.id] = ball.pos
				length[ball.id] = 0.0
				boost[ball.id] = ball.boost
				skip[ball.id] = true
			var from: Vector2 = at[ball.id]
			var cuts := ceili(from.distance_to(ball.pos) / 1.5)
			for i in cuts + 1:
				seen.points += 1
				var what := _overlap(from.lerp(ball.pos, float(i) / maxi(cuts, 1)), ball.size * 0.5, live, solids, left)
				if what:
					say.call(what)
			length[ball.id] += from.distance_to(ball.pos)
			at[ball.id] = ball.pos
			if ball.boost != boost[ball.id]:
				boost[ball.id] = ball.boost
				skip[ball.id] = true
			if (_angle(ball.dir) < low or _angle(ball.dir) > high) and ball.dir != Vector2.LEFT:
				say.call("a ball at %.2f degrees" % _angle(ball.dir))
			if absf(ball.dir.length() - 1.0) > 0.00001:
				say.call("a direction %f long" % ball.dir.length())
	round.ball_bounced.connect(func(_b: Ball, _h: Hit) -> void: follow.call())
	round.brick_hit.connect(func(_c: Vector2i, _hp: int, _cause: Round.Cause) -> void: follow.call())
	round.brick_broken.connect(func(_c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, _n: int) -> void: follow.call())
	round.ball_added.connect(func(_b: Ball) -> void: follow.call())
	round.exploded.connect(func(_p: Vector2, _r: float, _c: Array[Vector2i]) -> void:  # a Shockwave may be about to throw them
		for ball: Ball in balls:
			skip[ball.id] = true)
	follow.call()
	for i in roundi(8.0 / dt):
		if round.over:
			break
		for id: int in length:
			length[id] = 0.0
		skip.clear()
		var target := round.paddle.y
		for ball in balls:
			if ball.dir.x < 0.0:
				target = ball.pos.y + sin(i * 0.3) * 40.0
		round.step(dt, target)
		follow.call()
		seen.balls = maxi(seen.balls, balls.size())
		for ball in balls:
			if not skip.has(ball.id) and absf(length[ball.id] - round.speed_of(ball) * dt) > 0.02:
				say.call("a ball went %f in a step, not %f" % [length[ball.id], round.speed_of(ball) * dt])


## What a ball centred on `point` is inside of by more than a rounding error, or "" for nothing.
func _overlap(point: Vector2, half: float, board: Board, solids: Array, left: float) -> String:
	var slack := 0.02
	var size := board.size()
	if point.y < half - slack or point.y > size.y - half + slack or point.x > size.x - half + slack:
		return "through a wall at %s" % point
	if point.x < left + half - slack:
		return "into the paddle at %s" % point
	var square := Rect2(point, Vector2.ZERO).grow(half - slack)
	var first := board.cell_at(square.position)
	var last := board.cell_at(square.end)
	for column in range(first.x, last.x + 1):
		for row in range(first.y, last.y + 1):
			if board.bricks.has(Vector2i(column, row)):
				return "into the brick %s at %s" % [Vector2i(column, row), point]
	for item: Layout.Item in solids:
		if point.distance_to(item.pos) > 80.0:
			continue
		if item.kind.shape == PlaceableKind.Shape.CIRCLE:
			if point.distance_to(item.pos) < item.kind.size.x * 0.5 + half - slack:  # the sweep's own rule for the round item
				return "into a %s at %s" % [item.kind.id, point]
		elif not Geometry2D.intersect_polygons(Collide.box(square), item.outline()).is_empty():
			return "into a %s at %s" % [item.kind.id, point]
	return ""


# --- a ball in a gap that closes -------------------------------------------------------------------------------

func _wedge() -> void:
	# On a board of 12 rows the paddle's face is less than a ball away from the grid, so an item can close a gap
	# against it. The paddle does not mirror a ball, and here it sends it up into the gap again every time.
	var board := _board({Vector2i(47, 0): SOLID}, 12)
	var round := Round.new(board, _layout([_item(&"wall_segment", Vector2(24, 60), -20.0)]), _sealed(board, {&"wall_segment_count": 1}), 1)
	var ball := round.balls[0]
	var bounces := [0]
	round.ball_bounced.connect(func(_b: Ball, _h: Hit) -> void: bounces[0] += 1)
	ball.put(Vector2(20, 100), Vector2(-0.8, -0.6))
	_run(round, 1.0)
	t.check(round.layout.items.size() == 1 and bounces[0] > 20, "the wedge check's ball goes up into the gap between the paddle and a Wall Segment (%d bounces)" % bounces[0])
	t.check(bounces[0] < 200 and ball.pos.x > 100.0, "a ball wedged where two surfaces close on it is let out, not left bouncing on the spot (%d bounces, now at %s)" % [bounces[0], ball.pos])


# --- the same round at any tick rate ---------------------------------------------------------------------------

func _tick_rates() -> void:
	var bricks := {}
	for column in range(30, 38):
		for row in 8:
			bricks[Vector2i(column, row)] = 1 + (column * 3 + row) % 3
	var board := _board(bricks)
	for cell: Vector2i in [Vector2i(31, 2), Vector2i(36, 6)]:
		board.bricks[cell].kind = &"explosive"
		board.bricks[cell].hp = 1
	var stats := _sealed(board, {&"bumper_count": 1, &"booster_count": 1, &"wall_segment_count": 1, &"zap_count": 1, &"combo_rank": 1, &"shockwave": 1})
	var layout := _layout([_item(&"bumper", Vector2(200, 130)), _item(&"booster", Vector2(700, 300)), _item(&"wall_segment", Vector2(250, 400), 30.0), _item(&"zap", Vector2i(34, 4))])
	var logs := []
	for rate: int in [60, 120, 240]:
		var round := Round.new(board, layout, stats, 9)
		var log := _events(round)
		for i in rate * 600:
			if round.over:
				break
			round.step(1.0 / rate, round.paddle.y)
		t.check(round.over and round.reason == Round.End.CLEARED, "the tick-rate round is cleared at %d steps a second" % rate)
		# Coins and combos depend on the clock, so only what was hit, in what order, is compared.
		logs.append(log.filter(func(line: String) -> bool: return line.begins_with("hit") or line.begins_with("broke")).map(
				func(line: String) -> String: return line.get_slice(")", 0)))
	t.check(logs[0].size() >= 64 and logs[0] == logs[1] and logs[1] == logs[2], "a round stepped at 60, 120 and 240 steps a second hits and breaks the same bricks in the same order")


# --- determinism -----------------------------------------------------------------------------------------------

func _determinism() -> void:
	var bricks := {}
	for column in range(14, 40):
		for row in 8:
			if (column + row) % 4 != 0:
				bricks[Vector2i(column, row)] = 1 + (column + row) % 2
	var board := _board(bricks)
	var stats := _stats({&"bumper_count": 2, &"booster_count": 1, &"wall_segment_count": 2, &"splitter_count": 2, &"zap_count": 2, &"explosive_count": 3,
			&"gold_count": 2, &"hourglass_count": 2, &"combo_rank": 2, &"shockwave": 1, &"paddle_speed": 900.0})
	var layout := _layout([_item(&"bumper", Vector2(70, 90)), _item(&"bumper", Vector2(800, 420)), _item(&"booster", Vector2(110, 300)),
			_item(&"wall_segment", Vector2(90, 440), 60.0), _item(&"wall_segment", Vector2(900, 150), 15.0),
			_item(&"splitter", Vector2i(11, 2)), _item(&"splitter", Vector2i(11, 5)), _item(&"zap", Vector2i(15, 2)), _item(&"zap", Vector2i(20, 6))])
	var play := func(p_seed: int) -> Array[String]:
		var round := Round.new(board, layout, stats, p_seed)
		var log := _events(round)
		log.append("items %d" % round.layout.items.size())
		for i in 6000:
			# The paddle follows the last ball that is coming back, with a wobble so it also misses.
			var target := round.paddle.y + sin(i * 0.05) * 44.0
			for ball in round.balls:
				if ball.dir.x < 0.0:
					target = ball.pos.y + sin(i * 0.05) * 44.0
			round.step(TICK, target)
		log.append("coins %d left %d balls %d" % [round.coins, round.board.bricks.size(), round.balls.size()])
		return log
	var log: Array[String] = play.call(78)
	var seen := {}
	for line in log:
		seen[line.get_slice(" ", 0)] = true
	t.check(log[0] == "items 9" and log.size() > 100 and seen.has_all(["hit", "broke", "bounce", "added", "lost", "exploded", "combo", "time", "ended"]),
			"the determinism round does a bit of everything (%d events: %s)" % [log.size(), seen.keys()])
	t.check(play.call(78) == log, "the same board, layout, stats, seed and paddle input give the same events, to the last digit")
	t.check(play.call(79) != log, "another seed gives another round")


# --- one brick hit ---------------------------------------------------------------------------------------------

func _brick_hits() -> void:
	var cell := Vector2i(20, 3)  # its rectangle is (320, 192) to (336, 256)
	var board := _board({FAR: SOLID, cell: 3})
	var stats := _sealed(board)
	var round := Round.new(board, null, stats, 1)
	var ball := round.balls[0]
	var log := _events(round)
	var gone_when_told := [false]
	var live := round.board
	round.brick_broken.connect(func(c: Vector2i, brick: Brick, _cause: Round.Cause, _d: Vector2, _n: int) -> void:
		gone_when_told[0] = live.brick(c) == null and brick.hp == 0)
	var coming := Vector2.from_angle(deg_to_rad(10.0))
	for hp_left: int in [2, 1, 0]:
		log.clear()
		ball.put(Vector2(264, 215), coming)
		_run(round, 0.2)
		t.check(ball.dir == Vector2(-coming.x, coming.y), "a hit on a brick's side face turns the ball back and leaves its up and down alone")
		if hp_left > 0:
			t.check(log == ["hit (20, 3) %d 0" % hp_left] and round.board.brick(cell).hp == hp_left, "a hit takes 1 HP and says what is left (%d)" % hp_left)
		else:
			t.check(log.size() == 1 and log[0].begins_with("broke (20, 3) '' 0 %s 1" % var_to_str(coming)), "the last hit breaks the brick and passes on the ball's direction of travel")
			t.check(gone_when_told[0] and round.board.brick(cell) == null, "a broken brick is off the board by the time brick_broken is heard")
	t.check(board.brick(cell).hp == 3, "the round plays on its own copy of the board")

	# The top face.
	round = Round.new(board, null, stats, 1)
	ball = round.balls[0]
	coming = Vector2.from_angle(deg_to_rad(60.0))
	ball.put(Vector2(328, 186) - coming * 30.0, coming)
	_run(round, 0.1)
	t.check(ball.dir == Vector2(coming.x, -coming.y) and round.board.brick(cell).hp == 2, "a hit on a brick's top face turns the ball up and leaves its left and right alone")

	# Dead on a corner, and a hair to either side of it: one edge, one hit.
	for off: float in [0.0, 0.004, -0.004]:
		round = Round.new(board, null, stats, 1)
		ball = round.balls[0]
		log = _events(round)
		coming = Vector2(1, 1).normalized()
		ball.put(Vector2(314, 186 + off) - coming * 30.0, coming)
		_run(round, 0.1)
		var turned := int(ball.dir.x == -coming.x) + int(ball.dir.y == -coming.y)
		t.check(turned == 1 and log.size() == 1 and round.board.brick(cell).hp == 2, "a hit on a brick's corner picks one edge and takes one HP (%+.3f off the corner)" % off)
		# A hair low, the ball is level with the brick before it reaches it: the side. A hair high: the top.
		t.check((ball.dir.y < 0.0) == (off < 0.0), "the edge a corner hit picks is the one the ball reaches, and dead on the corner it is the side")

	# Across two bricks at once: one of them takes the hit, the one more of the ball is on.
	var pair := _board({FAR: SOLID, Vector2i(20, 3): 3, Vector2i(20, 4): 3})
	for case: Array in [[258.0, Vector2i(20, 4)], [254.0, Vector2i(20, 3)]]:
		round = Round.new(pair, null, stats, 1)
		ball = round.balls[0]
		log = _events(round)
		coming = Vector2.from_angle(deg_to_rad(10.0))
		ball.put(Vector2(314, case[0]) - coming * 30.0, coming)
		_run(round, 0.1)
		t.check(log == ["hit %s 2 0" % case[1]], "a ball that lands across two bricks hits only the one more of it is on")

	# A seam in a floor of bricks is not an edge: a ball that reaches it exactly still bounces off the top.
	var floor_board := _board({FAR: SOLID, Vector2i(20, 3): 3, Vector2i(21, 3): 3})
	round = Round.new(floor_board, null, stats, 1)
	ball = round.balls[0]
	log = _events(round)
	coming = Vector2(1, 1).normalized()
	ball.put(Vector2(330, 186) - coming * 30.0, coming)
	_run(round, 0.1)
	t.check(ball.dir == Vector2(coming.x, -coming.y) and log == ["hit (20, 3) 2 0"], "the seam between two bricks side by side is never hit as an edge")


# --- explosions ------------------------------------------------------------------------------------------------

func _blasts() -> void:
	var bricks := {}
	for column in 64:
		for row in 8:
			bricks[Vector2i(column, row)] = 5
	var full := _board(bricks)
	var hit_cells := func(round: Round) -> Array:
		return round.board.bricks.keys().filter(func(c: Vector2i) -> bool: return round.board.brick(c).hp == 4)
	# reach in units: [columns hit to each side, brick rows hit above and below]
	var reaches := {64.0: [4, 1], 96.0: [6, 2], 128.0: [8, 2], 63.0: [4, 1], 65.0: [5, 2]}
	for reach: float in reaches:
		var round := Round.new(full, null, _stats(), 1)
		var told := []
		var live := round.board
		round.exploded.connect(func(pos: Vector2, r: float, cells: Array[Vector2i]) -> void:
			told.append([pos, r, cells.duplicate(), cells.all(func(c: Vector2i) -> bool: return live.brick(c).hp == 5)]))
		round.blast(Vector2i(30, 4), reach)
		var want := []
		for column in range(30 - reaches[reach][0], 30 + reaches[reach][0] + 1):
			for row in range(4 - reaches[reach][1], 4 + reaches[reach][1] + 1):
				want.append(Vector2i(column, row))
		var got: Array = hit_cells.call(round)
		got.sort()
		t.check(got == want, "a blast reaching %d units hits %d columns to each side and %d brick rows above and below, each brick once" % [reach, reaches[reach][0], reaches[reach][1]])
		t.check(told.size() == 1 and told[0][0] == Vector2(488, 288) and told[0][1] == reach and told[0][2] == want and told[0][3],
				"exploded gives the brick's centre, the reach in units and the bricks about to be hit, while they are still untouched")

	# The explosive brick turns the blast_size stat, in squares, into units.
	for size: float in [1.0, 1.5]:
		var board := full.copy()
		board.bricks[Vector2i(30, 4)] = Brick.new(1, &"explosive")
		var round := Round.new(board, null, _stats({&"blast_size": size}), 1)
		var log := _events(round)
		round.hit_brick(Vector2i(30, 4), Round.Cause.BALL, Vector2.RIGHT)
		t.check(log.has("exploded (488.0, 288.0) %s %d" % [size * 64.0, 26 if size == 1.0 else 64]), "an explosive brick at Blast Size %.1f reaches %d units" % [size, size * 64.0])

	# Chains. A, B and C are explosive, each inside the blast of the one before; A and B are inside each other's.
	var board := _board({FAR: SOLID, Vector2i(30, 4): 1, Vector2i(33, 4): 1, Vector2i(36, 4): 1, Vector2i(27, 4): 5, Vector2i(32, 4): 5, Vector2i(35, 4): 5, Vector2i(39, 4): 5, Vector2i(41, 4): 5})
	for cell: Vector2i in [Vector2i(30, 4), Vector2i(33, 4), Vector2i(36, 4)]:
		board.bricks[cell].kind = &"explosive"
	var round := Round.new(board, null, _stats(), 1)
	var log := _events(round)
	round.hit_brick(Vector2i(30, 4), Round.Cause.BALL, Vector2.RIGHT)
	t.check(log.filter(func(line: String) -> bool: return line.begins_with("exploded")).size() == 3, "an explosive brick broken by a blast explodes too, and each explodes once")
	t.check(log.filter(func(line: String) -> bool: return line.begins_with("broke") and " 'explosive' 1 " in line).size() == 2, "the chained bricks are broken with the cause BLAST")
	var hp := func(column: int) -> int: return round.board.brick(Vector2i(column, 4)).hp
	t.check([hp.call(27), hp.call(32), hp.call(35), hp.call(39), hp.call(41)] == [4, 2, 3, 4, 5], "a brick takes one hit from each blast it is inside, never two from one")
	var dirs := log.filter(func(line: String) -> bool: return line.begins_with("broke (33, 4)"))
	t.check(dirs.size() == 1 and var_to_str(Vector2.RIGHT) in dirs[0], "a brick broken by a blast is thrown away from the blast's centre")

	# A long fuse: sixty explosive bricks, each setting off the next.
	bricks = {FAR: SOLID}
	for column in 60:
		bricks[Vector2i(column, 2)] = 1
	board = _board(bricks)
	for column in 60:
		board.bricks[Vector2i(column, 2)].kind = &"explosive"
	round = Round.new(board, null, _stats(), 1)
	round.hit_brick(Vector2i(0, 2), Round.Cause.BALL, Vector2.RIGHT)
	t.check(round.board.bricks.size() == 1 and round.tally.broken[&"explosive"] == 60, "a chain of sixty explosive bricks runs to its end and stops")


# --- the Zap ---------------------------------------------------------------------------------------------------

func _zap() -> void:
	var board := _board({FAR: SOLID, Vector2i(10, 4): 3, Vector2i(20, 4): 1, Vector2i(40, 4): 1, Vector2i(50, 4): 2, Vector2i(20, 3): 1, Vector2i(20, 5): 1})
	var stats := _stats({&"zap_count": 2})
	var round := Round.new(board, _layout([_item(&"zap", Vector2i(20, 4))]), stats, 1)
	t.check(round.board.brick(Vector2i(20, 4)).mod == &"zap", "a Zap in the layout tags its brick")
	var log := _events(round)
	round.hit_brick(Vector2i(20, 4), Round.Cause.BALL, Vector2.RIGHT)
	t.check(log == ["broke (20, 4) '' 0 %s 1" % var_to_str(Vector2.RIGHT), "hit (10, 4) 2 2", "broke (40, 4) '' 2 %s 1" % var_to_str(Vector2.RIGHT), "hit (50, 4) 1 2"],
			"when a Zap's brick breaks, every other brick in its brick row takes one hit, from the paddle side to the back wall, and no other row does")

	# Two Zaps and an explosive brick in one row: each acts once and it ends.
	board = _board({FAR: SOLID, Vector2i(10, 4): 1, Vector2i(20, 4): 1, Vector2i(22, 4): 1, Vector2i(40, 4): 4})
	board.bricks[Vector2i(22, 4)].kind = &"explosive"
	round = Round.new(board, _layout([_item(&"zap", Vector2i(10, 4)), _item(&"zap", Vector2i(20, 4))]), stats, 1)
	log = _events(round)
	round.hit_brick(Vector2i(10, 4), Round.Cause.BALL, Vector2.RIGHT)
	t.check(round.board.bricks.size() == 2 and round.board.brick(Vector2i(40, 4)).hp == 2 and log.filter(func(line: String) -> bool: return line.begins_with("exploded")).size() == 1,
			"Zaps and blasts that set each other off each act once")
	t.check(log.filter(func(line: String) -> bool: return line.begins_with("broke (20, 4)")).size() == 1 and var_to_str(Vector2.RIGHT) in log[1], "a brick a Zap breaks is thrown along the row, away from the tagged brick")


# --- Shockwave -------------------------------------------------------------------------------------------------

func _shockwave() -> void:
	var board := _board({FAR: SOLID})
	var centre := Vector2(488, 224)  # of brick cell (30, 3); a reach of 64 makes the blast (416, 128) to (560, 320)
	var stats := _sealed(board, {&"shockwave": 1})
	var round := Round.new(board, null, stats, 1)
	var ball := round.balls[0]
	var outside := round.add_ball(Vector2(570, 200), Vector2(-0.6, 0.8))
	ball.put(Vector2(500, 200), Vector2(-0.6, 0.8))
	round.blast(Vector2i(30, 3), 64.0)
	t.check(ball.dir.is_equal_approx((ball.pos - centre).normalized()) and ball.boost == stats.shockwave_boost, "a Shockwave throws a ball in the blast straight away from its centre, with the boost")
	t.check(outside.dir == Vector2(-0.6, 0.8) and outside.boost == 1.0, "a ball outside the blast is left alone")
	var from := ball.pos
	round.step(TICK, round.paddle.y)
	t.check((ball.pos - from).is_equal_approx(ball.dir * stats.ball_speed * stats.shockwave_boost * TICK), "a thrown ball moves along the throw at the boosted speed")
	round.blast(Vector2i(30, 3), 64.0)
	t.check(ball.boost == stats.boost_cap, "a second Shockwave stops at the boost cap")
	ball.put(centre + Vector2(0, -40), Vector2(0.6, 0.8))
	round.blast(Vector2i(30, 3), 64.0)
	t.check(is_equal_approx(_angle(ball.dir), 90.0 - stats.min_angle_vertical) and ball.dir.y < 0.0, "a throw straight up is nudged to the minimum angle")

	round = Round.new(board, null, _sealed(board), 1)
	ball = round.balls[0]
	ball.put(Vector2(500, 200), Vector2(-0.6, 0.8))
	round.blast(Vector2i(30, 3), 64.0)
	t.check(ball.dir == Vector2(-0.6, 0.8) and ball.boost == 1.0, "without the Shockwave upgrade a blast leaves balls alone")

	# Through a real explosive brick, hit by the ball.
	board = _board({FAR: SOLID, Vector2i(30, 3): 1})
	board.bricks[Vector2i(30, 3)].kind = &"explosive"
	round = Round.new(board, null, stats, 1)
	ball = round.balls[0]
	var coming := Vector2.from_angle(deg_to_rad(30.0))
	ball.put(Vector2(474, 214) - coming * 20.0, coming)
	_run(round, 0.05)
	t.check(ball.boost == stats.shockwave_boost and ball.dir.is_equal_approx((Vector2(474, 214) - centre).normalized()), "a ball that sets off an explosive brick is thrown back from it")


# --- what each placeable does ----------------------------------------------------------------------------------

func _placeables() -> void:
	var board := _board({FAR: SOLID})
	var stats := _sealed(board, {&"bumper_count": 1, &"booster_count": 1, &"wall_segment_count": 1, &"splitter_count": 2, &"zap_count": 1})
	var at := Vector2(400, 256)
	var shoot := func(item: Layout.Item, from: Vector2, dir: Vector2) -> Array:
		var round := Round.new(board, _layout([item]), stats, 1)
		var hits: Array[Hit] = []
		round.ball_bounced.connect(func(_b: Ball, hit: Hit) -> void: hits.append(hit))
		round.balls[0].put(from, dir)
		_run(round, 0.15)
		return [round.balls[0], hits]

	# Bumper: a diamond. A face bounces the ball; the point of the diamond meets the ball's flat side.
	var bumper := _item(&"bumper", at)
	var coming := Vector2.from_angle(deg_to_rad(10.0))
	var shot: Array = shoot.call(bumper, Vector2(340, 240), coming)
	var hit: Hit = shot[1][0]
	var face := Vector2(-1, -1).normalized()
	t.check(shot[1].size() == 1 and hit.surface == Hit.Surface.ITEM and hit.item == bumper and hit.normal.is_equal_approx(face), "a ball bounces off the Bumper's slanted face")
	t.check(shot[0].dir.is_equal_approx(Vector2(-cos(deg_to_rad(70.0)), -sin(deg_to_rad(70.0)))) and shot[0].boost == 1.0,
			"off that face it leaves mirrored, nudged from near upright to the minimum angle on the side the face looks to, at the same speed")
	t.check(absf((hit.point - at).dot(face) - (15.0 + 6.0 * sqrt(2.0))) < NEAR, "the ball's corner is on the Bumper's face when it bounces")
	shot = shoot.call(bumper, Vector2(340, 256) - coming * 5.0, coming)
	hit = shot[1][0]
	t.check(hit.normal == Vector2.LEFT and shot[0].dir == Vector2(-coming.x, coming.y) and absf(hit.point.x - (400.0 - 15.0 * sqrt(2.0) - 6.0)) < NEAR, "the point of the Bumper turns back a ball that meets it flat on")

	# Booster: round. The normal runs from its centre to the ball, and every hit adds a quarter of the base speed.
	var booster := _item(&"booster", at)
	shot = shoot.call(booster, Vector2(340, 240), coming)
	hit = shot[1][0]
	t.check(hit.item == booster and hit.normal.is_equal_approx((hit.point - at).normalized()) and absf(hit.point.distance_to(at) - 22.0) < NEAR, "a ball bounces off the Booster at the point where it touches")
	t.check(shot[0].dir.is_equal_approx(coming.bounce(hit.normal)) and shot[0].boost == 1.0 + booster.kind.get("boost"), "and leaves mirrored there, faster by the Booster's share of its base speed")

	# Wall Segment: straight on, turned a quarter, and at an angle.
	var wall := _item(&"wall_segment", at)
	shot = shoot.call(wall, Vector2(340, 240), coming)
	hit = shot[1][0]
	t.check(hit.item == wall and hit.normal == Vector2.LEFT and hit.point.x == 400.0 - 5.0 - 6.0 and shot[0].dir == Vector2(-coming.x, coming.y) and shot[0].boost == 1.0, "a ball bounces off an upright Wall Segment's face like off a wall")
	wall = _item(&"wall_segment", at, 90.0)
	coming = Vector2.from_angle(deg_to_rad(50.0))
	shot = shoot.call(wall, Vector2(380, 200), coming)
	hit = shot[1][0]
	t.check(hit.normal == Vector2.UP and absf(hit.point.y - (256.0 - 5.0 - 6.0)) < NEAR and shot[0].dir == Vector2(coming.x, -coming.y), "a Wall Segment turned a quarter is a level wall")
	wall = _item(&"wall_segment", at, 30.0)
	coming = Vector2.from_angle(deg_to_rad(10.0))
	shot = shoot.call(wall, Vector2(340, 250), coming)
	hit = shot[1][0]
	face = Vector2.LEFT.rotated(deg_to_rad(30.0))
	t.check(hit.normal.is_equal_approx(face) and shot[0].dir.is_equal_approx(coming.bounce(face)), "a Wall Segment turned 30 degrees bounces the ball off its turned face")

	# Splitter: a placed brick. The ball that breaks it splits in two; a blast or a Zap just breaks it.
	var round := Round.new(board, _layout([_item(&"splitter", Vector2i(25, 3))]), stats, 1)
	var brick := round.board.brick(Vector2i(25, 3))
	t.check(brick != null and brick.placed and brick.kind == &"splitter" and brick.hp == 1 and board.brick(Vector2i(25, 3)) == null, "a Splitter in the layout is a placed 1 HP brick on the round's board")
	var log := _events(round)
	var ball := round.balls[0]
	ball.put(Vector2(394, 220) - coming * 20.0, coming)
	_run(round, 0.05)
	t.check(round.balls.size() == 2 and round.balls[1].id == 1 and log.count("added 1 %s" % var_to_str(Vector2(394, 220))) == 1, "a ball that breaks a Splitter splits in two, there")
	t.check(ball.dir == Vector2(-coming.x, coming.y) and round.balls[1].dir == coming, "off the Splitter's face one bounces back and the other carries on through")
	t.check(round.coins == 0 and round.tally.placed_broken == 1 and round.tally.broken.is_empty(), "a Splitter pays nothing and is counted as a placed brick")
	t.check(round.tally.hits == {&"splitter": 1}, "the tally counts the hit the Splitter took")
	for cause: Round.Cause in [Round.Cause.BLAST, Round.Cause.ZAP]:
		round = Round.new(board, _layout([_item(&"splitter", Vector2i(25, 3))]), stats, 1)
		round.hit_brick(Vector2i(25, 3), cause, Vector2.RIGHT)
		t.check(round.board.brick(Vector2i(25, 3)) == null and round.balls.size() == 1, "a Splitter broken by a blast or a Zap just breaks")
	# A Zap on a Splitter works like on any brick.
	round = Round.new(_board({FAR: SOLID, Vector2i(40, 3): 2}), _layout([_item(&"splitter", Vector2i(25, 3)), _item(&"zap", Vector2i(25, 3))]), stats, 1)
	round.hit_brick(Vector2i(25, 3), Round.Cause.BALL, Vector2.RIGHT)
	t.check(round.board.brick(Vector2i(40, 3)).hp == 1, "a Zap can sit on a Splitter")


## Growth: a placed block that never breaks, and its pulse.
func _growth() -> void:
	var block := Vector2i(25, 3)
	var board := _board({FAR: SOLID, Vector2i(20, 3): 1, Vector2i(24, 4): 1})
	board.bricks[Vector2i(24, 4)].kind = &"explosive"
	var stats := _sealed(board, {&"growth_count": 1, &"zap_count": 1})
	var round := Round.new(board, _layout([_item(&"growth", block), _item(&"zap", Vector2i(20, 3))]), stats, 1)
	var log := _events(round)
	var coming := Vector2.from_angle(deg_to_rad(10.0))
	var ball := round.balls[0]
	ball.put(Vector2(394, 220) - coming * 20.0, coming)
	_run(round, 0.05)
	t.check(ball.dir == Vector2(-coming.x, coming.y) and log.has("hit %s 1 %d" % [block, Round.Cause.BALL]), "a ball bounces off a Growth block as off a brick, and the hit takes no HP")
	round.hit_brick(Vector2i(24, 4), Round.Cause.BALL, Vector2.RIGHT)  # an explosive brick: its blast reaches the block
	round.hit_brick(Vector2i(20, 3), Round.Cause.BALL, Vector2.RIGHT)  # the Zap's brick: its row runs through the block
	t.check(log.has("hit %s 1 %d" % [block, Round.Cause.BLAST]) and log.has("hit %s 1 %d" % [block, Round.Cause.ZAP]) and round.board.brick(block).hp == 1,
			"a blast and a Zap hit a Growth block too, and it keeps its 1 HP")
	t.check(round.tally.hits.get(&"growth") == 3 and round.tally.dents == 0 and round.tally.placed_broken == 0 and round.coins == 2,
			"its three hits count in the tally and pay nothing: the coins are the two level bricks'")
	t.check(not _layout([_item(&"growth", block)]).fits(_item(&"zap", block), board, stats), "a Zap cannot go on a Growth block, where it would never go off")
	round = Round.new(_board({Vector2i(30, 3): 1}), _layout([_item(&"growth", block)]), stats, 1)
	round.hit_brick(Vector2i(30, 3), Round.Cause.BALL, Vector2.RIGHT)
	round.step(TICK, round.paddle.y)
	t.check(round.over and round.reason == Round.End.CLEARED, "a Growth block left standing does not keep a level from being cleared")

	# The pulse: every 5 s, 1 HP to each level brick within a square of the block's edges, up to max_hp. In reach:
	# (21, 3) at the edge of it, (24, 3), and (25, 2) already at 4; (25, 4) is a Splitter. Out: (20, 3), (25, 5).
	board = _board({FAR: SOLID, Vector2i(21, 3): 3, Vector2i(24, 3): 1, Vector2i(25, 2): 4, Vector2i(20, 3): 1, Vector2i(25, 5): 1})
	var layout := _layout([_item(&"growth", block), _item(&"splitter", Vector2i(25, 4))])
	# Returns [[step, cells] for each pulse, the round], played with the ball at a standstill.
	var pulses := func(rate: float, seconds: float) -> Array:
		var s := _sealed(board, {&"growth_count": 1, &"splitter_count": 1, &"growth_reach": 1.0, &"pulse_min": 1.0, &"pulse_rate": rate})
		s.max_hp = 4
		s.ball_speed = 0.0
		var r := Round.new(board, layout, s, 1)
		var seen := []
		var steps := [0]
		r.grew.connect(func(cell: Vector2i, reach: float, cells: Array[Vector2i]) -> void: seen.append([steps[0], cells.duplicate()] if cell == block and reach == 64.0 else null))
		for i in roundi(seconds / TICK):
			steps[0] = i + 1
			r.step(TICK, r.paddle.y)
		return [seen, r]
	var got: Array = pulses.call(0.0, 10.0)
	var hp := func(c: Vector2i) -> int: return (got[1] as Round).board.brick(c).hp
	t.check(got[0] == [[600, [Vector2i(21, 3), Vector2i(24, 3)]], [1200, [Vector2i(24, 3)]]],
			"a Growth block pulses at 5 s and 10 s of play, giving 1 HP to the level bricks in reach under the ceiling (%s)" % [got[0]])
	t.check([hp.call(Vector2i(21, 3)), hp.call(Vector2i(24, 3)), hp.call(Vector2i(25, 2)), hp.call(Vector2i(25, 4)), hp.call(Vector2i(20, 3)), hp.call(Vector2i(25, 5))] == [4, 3, 4, 1, 1, 1],
			"no brick goes over max_hp, a placed brick gains nothing, and nothing out of reach does")
	t.check((got[0] as Array).map(func(p: Array) -> int: return p[0]) == [600, 1200] and (pulses.call(2.0, 6.0)[0] as Array).map(func(p: Array) -> int: return p[0]) == [360, 720],
			"pulse_rate takes seconds off the period: 3 s at a rate of 2")
	t.check((pulses.call(10.0, 3.0)[0] as Array).map(func(p: Array) -> int: return p[0]) == [120, 240, 360], "and the period never goes under pulse_min, 1 s")


func _refresh() -> void:
	# Around the block at (25, 3): (24, 3) a gold brick and (26, 3) a Zap's 2 HP brick, both 256 away (squared,
	# centre to centre), then (25, 2) and the Splitter (25, 4) at 4096, then (20, 3) and (30, 3) at 6400. (25, 1)
	# stands. The Zap's break takes out the rest of row 3.
	var block := Vector2i(25, 3)
	var board := _board({FAR: SOLID, Vector2i(24, 3): 1, Vector2i(26, 3): 2, Vector2i(25, 2): 1, Vector2i(25, 1): 1, Vector2i(20, 3): 1, Vector2i(30, 3): 1})
	board.bricks[Vector2i(24, 3)].kind = &"gold"
	var stats := _sealed(board, {&"refresh_count": 1, &"splitter_count": 1, &"zap_count": 1, &"refresh_size": 3.0, &"pulse_min": 1.0})
	stats.ball_speed = 0.0
	var layout := _layout([_item(&"refresh", block), _item(&"splitter", Vector2i(25, 4)), _item(&"zap", Vector2i(26, 3))])
	var round := Round.new(board, layout, stats, 1)
	t.check(round.broken_near(block, 3).is_empty(), "nothing is broken yet, so there is nothing to bring back")
	for cell: Vector2i in [Vector2i(26, 3), Vector2i(26, 3), Vector2i(25, 2), Vector2i(25, 4)]:
		round.hit_brick(cell, Round.Cause.BLAST, Vector2.RIGHT)
	var nearest: Array[Vector2i] = [Vector2i(24, 3), Vector2i(26, 3), Vector2i(25, 2), Vector2i(20, 3), Vector2i(30, 3)]
	t.check(round.broken_near(block, 3) == nearest.slice(0, 3) and round.broken_near(block, 9) == nearest,
			"the broken level cells nearest the block, a tie to the lower column and then the lower row; never a placed brick's (%s)" % [round.broken_near(block, 9)])
	var ball := round.balls[0]
	ball.put(round.board.cell_rect(Vector2i(24, 3)).get_center() + Vector2(-13, 0), Vector2.LEFT)
	t.check(round.broken_near(block, 3) == [Vector2i(26, 3), Vector2i(25, 2), Vector2i(20, 3)], "a cell a ball overlaps is skipped")
	t.check(round.restore(block, [Vector2i(24, 3), Vector2i(25, 1), Vector2i(25, 4), Vector2i(26, 3)]) == [Vector2i(26, 3)],
			"restore brings back only a broken level cell: not one a ball is over, one still standing or a placed brick's")
	var back := round.board.brick(Vector2i(26, 3))
	t.check(back.hp == 1 and back.kind == &"" and back.mod == &"" and not back.placed, "it comes back a plain 1 HP level brick, its Zap gone")
	ball.put(round.board.cell_rect(Vector2i(24, 3)).get_center() + Vector2(-14, 0), Vector2.LEFT)
	t.check(round.restorable(Vector2i(24, 3)), "a ball that only touches the cell does not keep it")

	# Only a ball's hit, and only when ready: then the cooldown, 4 s less pulse_rate and never under pulse_min.
	var log := _events(round)
	var heard := []
	round.restored.connect(func(cell: Vector2i, cells: Array[Vector2i]) -> void: heard.append([cell, cells.duplicate()]))
	round.hit_brick(block, Round.Cause.BLAST, Vector2.RIGHT)
	round.hit_brick(block, Round.Cause.ZAP, Vector2.RIGHT)
	t.check(heard.is_empty() and round.board.brick(block).hp == 1 and log.size() == 2, "a blast or a Zap hits the block and brings nothing back")
	round.hit_brick(block, Round.Cause.BALL, Vector2.RIGHT)
	t.check(heard == [[block, [Vector2i(24, 3), Vector2i(25, 2), Vector2i(20, 3)]]] and round.board.brick(Vector2i(24, 3)).kind == &"",
			"a ball's hit brings back the nearest three, and the gold brick comes back plain (%s)" % [heard])
	t.check(round.board.brick(block).ready_at == 4.0, "then it waits 4 s")
	# Returns the steps at which a ball's hit, one every step, brought bricks back; each time they break again.
	var refreshes := func(rate: float, seconds: float) -> Array:
		var s := stats.duplicate() as Balance
		s.put(&"pulse_rate", rate)
		var r := Round.new(board, layout, s, 1)
		for cell: Vector2i in [Vector2i(26, 3), Vector2i(26, 3)]:
			r.hit_brick(cell, Round.Cause.BLAST, Vector2.RIGHT)
		var at := []
		for i in roundi(seconds / TICK):
			r.step(TICK, r.paddle.y)
			r.hit_brick(block, Round.Cause.BALL, Vector2.RIGHT)
			for cell in r.level_cells:
				if r.board.brick(cell) and cell.y == 3:
					at.append(i + 1)
					r.hit_brick(cell, Round.Cause.BLAST, Vector2.RIGHT)
		return at.reduce(func(seen: Array, step: int) -> Array: return seen if seen.has(step) else seen + [step], [])
	t.check(refreshes.call(0.0, 10.0) == [1, 481, 961], "every 4 s while it is hit all the time")
	t.check(refreshes.call(2.0, 6.0) == [1, 241, 481], "pulse_rate takes seconds off the cooldown: 2 s at a rate of 2")
	t.check(refreshes.call(10.0, 3.0) == [1, 121, 241], "and it never goes under pulse_min, 1 s")

	# A brick brought back scores and counts toward a clear.
	round = Round.new(_board({Vector2i(20, 3): 1}), _layout([_item(&"refresh", block)]), stats, 1)
	round.hit_brick(Vector2i(20, 3), Round.Cause.BLAST, Vector2.RIGHT)
	var coins := round.coins
	round.hit_brick(block, Round.Cause.BALL, Vector2.RIGHT)
	round.step(TICK, round.paddle.y)
	t.check(not round.over and round.board.brick(Vector2i(20, 3)) != null, "the level is not cleared while a brick brought back stands")
	round.hit_brick(Vector2i(20, 3), Round.Cause.BLAST, Vector2.RIGHT)
	round.step(TICK, round.paddle.y)
	t.check(round.over and round.reason == Round.End.CLEARED and round.coins > coins and round.tally.score == 2, "breaking it scores, and then the board is cleared")

	# A real ball bounces off it and sets it off. (25, 2) stands in this round.
	var played := func() -> Array:
		var s := stats.duplicate() as Balance
		s.ball_speed = 560.0
		var r := Round.new(board, layout, s, 1)
		for cell: Vector2i in [Vector2i(26, 3), Vector2i(26, 3)]:
			r.hit_brick(cell, Round.Cause.BLAST, Vector2.RIGHT)
		var seen := []
		r.restored.connect(func(cell: Vector2i, cells: Array[Vector2i]) -> void: seen.append([cell, cells.duplicate()]))
		var coming := Vector2.from_angle(deg_to_rad(10.0))
		r.balls[0].put(Vector2(394, 220) - coming * 20.0, coming)
		_run(r, 0.05)
		return seen
	var first: Array = played.call()
	t.check(first == [[block, [Vector2i(26, 3), Vector2i(20, 3), Vector2i(30, 3)]]] and played.call() == first,
			"a ball's bounce off the block brings bricks back, the same every time, but not (24, 3), which the ball is in (%s)" % [first])


## Overgrowth: a broken level brick comes back overgrowth_delay s later on the round's clock, plain and 1 HP.
func _overgrowth() -> void:
	var gold := Vector2i(20, 3)
	var zapped := Vector2i(40, 6)
	var placed := Vector2i(10, 10)
	var board := _board({FAR: SOLID, gold: 1, zapped: 1})
	board.bricks[gold].kind = &"gold"
	var stats := _sealed(board, {&"overgrowth": 1.0, &"overgrowth_delay": 8.0, &"splitter_count": 1, &"zap_count": 1})
	stats.ball_speed = 0.0
	var layout := _layout([_item(&"splitter", placed), _item(&"zap", zapped)])
	var round := Round.new(board, layout, stats, 1)
	var heard := []
	round.restored.connect(func(cell: Vector2i, cells: Array[Vector2i]) -> void: heard.append([cell, cells.duplicate()]))
	round.hit_brick(gold, Round.Cause.BLAST, Vector2.RIGHT)
	_run(round, 4.0)
	round.hit_brick(zapped, Round.Cause.BLAST, Vector2.RIGHT)
	round.hit_brick(placed, Round.Cause.BLAST, Vector2.RIGHT)
	_run(round, 4.0 - TICK)
	t.check(heard.is_empty() and round.board.brick(gold) == null, "a broken brick stays broken until the delay is up")
	round.step(TICK, round.paddle.y)
	var back := round.board.brick(gold)
	t.check(heard == [[Round.NOWHERE, [gold]]] and back != null and back.hp == 1 and back.kind == &"" and not back.placed,
			"8 s after it broke, the gold brick comes back plain and 1 HP, from NOWHERE (%s)" % [heard])
	_run(round, 4.0)
	back = round.board.brick(zapped)
	t.check(heard.size() == 2 and heard[1] == [Round.NOWHERE, [zapped]] and back.hp == 1 and back.mod == &"", "the Zap's brick comes back without its Zap")
	_run(round, 20.0)
	t.check(round.board.brick(placed) == null and heard.size() == 2, "a placed brick never comes back")

	# Both break again in one step: they come back again, in one emission, in the order they broke.
	round.hit_brick(zapped, Round.Cause.BLAST, Vector2.RIGHT)
	round.hit_brick(gold, Round.Cause.BLAST, Vector2.RIGHT)
	_run(round, 8.0)
	t.check(heard.size() == 3 and heard[2] == [Round.NOWHERE, [zapped, gold]], "they come back again each time they break, all due in a step at once (%s)" % [heard])

	# A ball over the cell holds it back until the cell is clear.
	var ball := round.balls[0]
	round.hit_brick(gold, Round.Cause.BLAST, Vector2.RIGHT)
	ball.put(round.board.cell_rect(gold).get_center(), Vector2.RIGHT)
	_run(round, 12.0)
	t.check(round.board.brick(gold) == null and heard.size() == 3, "a ball over the cell keeps the brick from coming back")
	ball.put(round.board.cell_rect(Vector2i(50, 12)).get_center(), Vector2.RIGHT)
	round.step(TICK, round.paddle.y)
	t.check(round.board.brick(gold) != null and heard.size() == 4, "and it comes back on the first step the cell is clear")

	# Rank 0 brings nothing back.
	var off := stats.copy()
	off.put(&"overgrowth", 0.0)
	round = Round.new(board, layout, off, 1)
	round.hit_brick(gold, Round.Cause.BLAST, Vector2.RIGHT)
	_run(round, 20.0)
	t.check(round.board.brick(gold) == null, "without Overgrowth a broken brick stays broken")

	# The round does not wait for a brick to grow back: the last one standing still clears it.
	round = Round.new(_board({gold: 1, zapped: 1}), null, stats, 1)
	round.hit_brick(gold, Round.Cause.BLAST, Vector2.RIGHT)
	_run(round, 4.0)
	round.hit_brick(zapped, Round.Cause.BLAST, Vector2.RIGHT)
	round.step(TICK, round.paddle.y)
	t.check(round.over and round.reason == Round.End.CLEARED and round.board.brick(gold) == null, "breaking the last level brick clears the round with a brick still due back")

	# The same seed gives the same round, regrowth and all.
	var bricks := {}
	for column in range(14, 40):
		for row in 8:
			bricks[Vector2i(column, row)] = 1
	var grid := _board(bricks)
	var moving := _sealed(grid, {&"overgrowth": 1.0, &"overgrowth_delay": 8.0})
	var play := func(p_seed: int) -> Array[String]:
		var r := Round.new(grid, null, moving, p_seed)
		var log := _events(r)
		r.restored.connect(func(cell: Vector2i, cells: Array[Vector2i]) -> void: log.append("restored %s %s" % [cell, cells]))
		_run(r, 30.0)
		log.append("coins %d left %d" % [r.coins, r.board.remaining()])
		return log
	var log: Array[String] = play.call(5)
	t.check(log.any(func(line: String) -> bool: return line.begins_with("restored")) and play.call(5) == log,
			"the same seed gives the same round with Overgrowth, to the last brick grown back")


# --- several balls ---------------------------------------------------------------------------------------------

func _balls() -> void:
	var board := _board({FAR: SOLID})
	var round := Round.new(board, null, _stats(), 1)
	var log := _events(round)
	var second := round.add_ball(Vector2(0, 100), Vector2(-0.8, 0.6), 9.0)
	t.check(second.id == 1 and round.balls == [round.balls[0], second] and second.boost == round.stats.boost_cap and second.size == 12.0 and log == ["added 1 %s" % var_to_str(Vector2(0, 100))],
			"add_ball makes the next ball, keeps its boost under the cap and says so once")
	_run(round, 0.3)
	t.check(round.balls.size() == 1 and not round.over and log.count("lost 1 %s" % var_to_str(second.pos)) == 1, "losing a ball that is not the last does not end the round")
	t.check(absf(second.pos.x - (-58.0 - 6.0)) < NEAR, "a ball is lost where the whole of it is past the open side")
	round.balls[0].put(Vector2(0, 400), Vector2(-0.8, 0.6))
	_run(round, 0.3)
	t.check(round.balls.is_empty() and round.over and round.reason == Round.End.BALL_LOST and log[-1] == "ended %d" % Round.End.BALL_LOST and log[-2].begins_with("lost 0"),
			"losing the last ball ends the round, after ball_lost")


# --- special bricks --------------------------------------------------------------------------------------------

func _specials() -> void:
	var bricks := {}
	for column in range(20, 30):
		for row in 4:
			bricks[Vector2i(column, row)] = 4
	var board := _board(bricks)
	var stats := _stats({&"explosive_count": 2, &"gold_count": 1, &"hourglass_count": 3, &"tough_count": 1, &"bumper_count": 1, &"splitter_count": 1, &"zap_count": 1})
	var picks := func(round: Round) -> Dictionary:
		var out := {}
		for cell: Vector2i in round.board.bricks:
			if round.board.brick(cell).kind != &"":
				out[cell] = round.board.brick(cell).kind
		return out
	var round := Round.new(board, null, stats, 5)
	var got: Dictionary = picks.call(round)
	t.check(got.values().count(&"explosive") == 2 and got.values().count(&"gold") == 1 and got.values().count(&"hourglass") == 3 and got.values().count(&"tough") == 1 and got.size() == 7,
			"rank N of a special brick replaces N standard bricks")
	t.check(got.keys().all(func(c: Vector2i) -> bool: return round.board.brick(c).hp == (3 if got[c] == &"tough" else 1)) and round.board.bricks.values().filter(func(b: Brick) -> bool: return b.hp == 4).size() == 33,
			"a special brick has its kind's HP (1, a tough brick 3) whatever it replaced, and the others keep theirs")
	t.check(board.bricks.values().all(func(b: Brick) -> bool: return b.kind == &"" and b.hp == 4), "the level's own board is not changed by the roll")
	t.check(picks.call(Round.new(board, null, stats, 5)) == got, "the same seed picks the same bricks")
	var layout := _layout([_item(&"bumper", Vector2(200, 400)), _item(&"splitter", Vector2i(40, 2)), _item(&"zap", Vector2i(22, 1))])
	var with_layout := Round.new(board, layout, stats, 5)
	var same: Dictionary = picks.call(with_layout)
	same.erase(Vector2i(40, 2))
	t.check(with_layout.layout.items.size() == 3 and same == got, "the same seed picks the same bricks whatever the layout")
	t.check(picks.call(Round.new(board, null, stats, 6)) != got, "another seed picks other bricks")
	# The pick does not depend on the order the level listed its bricks in.
	var shuffled := Board.new()
	var cells := board.bricks.keys()
	cells.reverse()
	for cell: Vector2i in cells:
		shuffled.bricks[cell] = Brick.new(4)
	t.check(picks.call(Round.new(shuffled, null, stats, 5)) == got, "the pick depends on where the bricks are, not on the order they were listed in")

	var small := _board({Vector2i(20, 0): 3, Vector2i(21, 0): 3})
	round = Round.new(small, null, _stats({&"explosive_count": 1, &"gold_count": 5, &"hourglass_count": 5}), 1)
	got = picks.call(round)
	t.check(got.values().count(&"explosive") == 1 and got.values().count(&"gold") == 1 and got.size() == 2, "the roll goes in kind order and stops when no standard brick is left")


# --- the layout ------------------------------------------------------------------------------------------------

func _layouts() -> void:
	var board := _board({Vector2i(30, 3): 1, Vector2i(31, 3): 2})
	var stats := _stats({&"bumper_count": 2, &"booster_count": 1, &"wall_segment_count": 2, &"splitter_count": 2, &"zap_count": 2})
	var empty := Layout.new()

	# Counts.
	t.check(empty.fits(_item(&"bumper", Vector2(200, 200)), board, stats), "a Bumper fits on open board")
	t.check(not empty.fits(_item(&"bumper", Vector2(200, 200)), board, _stats()), "nothing fits while its count is 0")
	var one := _layout([_item(&"booster", Vector2(600, 100))])
	t.check(one.count(&"booster") == 1 and one.count(&"bumper") == 0 and not one.fits(_item(&"booster", Vector2(200, 200)), board, stats), "an item does not fit once its count is used up")

	# Free-form.
	t.check(not empty.fits(_item(&"bumper", Vector2(-20, 200)), board, stats), "a free-form item does not fit in the paddle lane")
	t.check(not empty.fits(_item(&"bumper", Vector2(15, 200)), board, stats) and empty.fits(_item(&"bumper", Vector2(22, 200)), board, stats), "a free-form item must be wholly inside the grid")
	t.check(not empty.fits(_item(&"booster", Vector2(1010, 500)), board, stats) and empty.fits(_item(&"booster", Vector2(1008, 496)), board, stats), "a Booster may touch the walls but not cross them")
	t.check(not empty.fits(_item(&"bumper", Vector2(488, 224)), board, stats), "a free-form item does not fit over a brick")
	t.check(empty.fits(_item(&"wall_segment", Vector2(475, 224)), board, stats) and not empty.fits(_item(&"wall_segment", Vector2(476, 224)), board, stats), "touching a brick is not overlapping it")
	t.check(empty.fits(_item(&"wall_segment", Vector2(462, 152)), board, stats) and empty.fits(_item(&"wall_segment", Vector2(462, 152), 45.0), board, stats)
			and not empty.fits(_item(&"wall_segment", Vector2(462, 152), -45.0), board, stats), "a turned item is tested as it is turned")
	t.check(not empty.fits(_item(&"bumper", Vector2(40, 256)), board, stats) and not empty.fits(_item(&"booster", Vector2(52, 256)), board, stats) and empty.fits(_item(&"booster", Vector2(55, 256)), board, stats),
			"a free-form item does not fit over the ball at rest")
	t.check(not empty.fits(_item(&"bumper", Vector2(22, 256)), board, stats) and not empty.fits(_item(&"wall_segment", Vector2(10, 256)), board, stats) and not empty.fits(_item(&"splitter", Vector2i(0, 4)), board, stats),
			"nothing fits between the ball at rest and the paddle")
	t.check(Round.launch_path(board, stats) == Rect2(-22, 250, 60, 12), "Round.launch_path runs from the paddle's face to the far side of the ball at rest")
	t.check(not one.fits(_item(&"bumper", Vector2(600, 130)), board, stats) and one.fits(_item(&"bumper", Vector2(600, 150)), board, stats), "a free-form item does not fit over another")
	var with_brick := _layout([_item(&"splitter", Vector2i(10, 2))])
	t.check(not with_brick.fits(_item(&"bumper", Vector2(168, 160)), board, stats), "a free-form item does not fit over a placed brick")

	# Placeable bricks.
	t.check(empty.fits(_item(&"splitter", Vector2i(5, 3)), board, stats), "a Splitter fits on an empty brick cell")
	t.check(not empty.fits(_item(&"splitter", Vector2i(64, 3)), board, stats) and not empty.fits(_item(&"splitter", Vector2i(5, 8)), board, stats) and not empty.fits(_item(&"splitter", Vector2i(-1, 0)), board, stats),
			"a placeable brick does not fit outside the board")
	t.check(not empty.fits(_item(&"splitter", Vector2i(30, 3)), board, stats), "a placeable brick does not fit on a brick")
	t.check(not with_brick.fits(_item(&"splitter", Vector2i(10, 2)), board, stats), "a placeable brick does not fit on another")
	t.check(not one.fits(_item(&"splitter", Vector2i(37, 1)), board, stats) and one.fits(_item(&"splitter", Vector2i(39, 1)), board, stats), "a placeable brick does not fit under a free-form item")
	t.check(not empty.fits(_item(&"splitter", Vector2i(1, 3)), board, stats) and not empty.fits(_item(&"splitter", Vector2i(2, 4)), board, stats) and empty.fits(_item(&"splitter", Vector2i(3, 3)), board, stats),
			"a placeable brick does not fit over the ball at rest")

	# Brick mods.
	t.check(empty.fits(_item(&"zap", Vector2i(30, 3)), board, stats) and not empty.fits(_item(&"zap", Vector2i(29, 3)), board, stats), "a Zap fits only on a brick")
	t.check(with_brick.fits(_item(&"zap", Vector2i(10, 2)), board, stats), "a Zap fits on a placed brick")
	t.check(not _layout([_item(&"zap", Vector2i(30, 3))]).fits(_item(&"zap", Vector2i(30, 3)), board, stats), "a brick takes one Zap")

	# The saved form.
	var layout := _layout([_item(&"wall_segment", Vector2(600.3, 256), 45.0), _item(&"bumper", Vector2(200, 120.5)), _item(&"splitter", Vector2i(30, 2)), _item(&"zap", Vector2i(31, 3))])
	var data := layout.to_data()
	t.check(data[2] == {"kind": "splitter", "col": 30, "row": 2} and typeof(data[2].col) == TYPE_INT and typeof(data[2].row) == TYPE_INT, "to_data writes a brick cell as whole numbers")
	t.check(data[0].kind == "wall_segment" and data[0].rot == 45.0 and data[0].y == 256.0 and [typeof(data[0].x), typeof(data[0].y), typeof(data[0].rot)] == [TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT],
			"to_data writes a free-form item's centre and turn as floats")
	var back := Layout.from_data(JSON.parse_string(JSON.stringify(data)))
	t.check(back.items.size() == 4 and back.items[0].kind == Kinds.of(&"wall_segment") and back.items[0].pos == layout.items[0].pos and back.items[0].rot == 45.0 and back.items[2].cell == Vector2i(30, 2),
			"from_data reads what the save file hands back, floats and all")
	t.check(back.to_data() == data and typeof(back.to_data()[2].col) == TYPE_INT, "a layout that has been through the save file writes the same data again")
	t.check(Layout.from_data([{"kind": "splitter", "col": 30.0, "row": 3.0}]).items[0].cell == Vector2i(30, 3), "from_data reads 30.0 as column 30")
	var junk := [{"kind": "no_such_kind", "x": 1.0, "y": 2.0}, {"kind": "gold", "col": 1, "row": 1}, {"kind": "bumper"}, {"kind": "splitter", "col": "a", "row": 1}, "text", 7, null, {},
			{"kind": "bumper", "x": 5.0, "y": 6.0, "rot": 30.0}]
	back = Layout.from_data(junk)
	t.check(back.items.size() == 1 and back.items[0].pos == Vector2(5, 6) and back.items[0].rot == 0.0, "from_data skips what it cannot read, and a turn on an item that does not turn")

	# Loading: what no longer fits is dropped.
	layout = _layout([_item(&"zap", Vector2i(12, 2)), _item(&"bumper", Vector2(200, 100)), _item(&"bumper", Vector2(300, 100)), _item(&"bumper", Vector2(400, 100)), _item(&"splitter", Vector2i(12, 2)),
			_item(&"zap", Vector2i(50, 5)), _item(&"booster", Vector2(488, 224))])
	var fitted := layout.fitted(board, stats)
	t.check(fitted.items == [layout.items[1], layout.items[2], layout.items[4], layout.items[0]], "fitted keeps what fits, drops the rest, and tests a Zap after the brick it is on")
	t.check(layout.items.size() == 7, "fitted leaves the layout it was asked about alone")
	var round := Round.new(board, layout, stats, 1)
	t.check(round.layout.to_data() == fitted.to_data() and round.board.brick(Vector2i(12, 2)).mod == &"zap" and round.board.brick(Vector2i(12, 2)).placed, "a round is built from the fitted layout")

	# Taking out and picking.
	layout = _layout([_item(&"bumper", Vector2(200, 100)), _item(&"booster", Vector2(600, 100)), _item(&"wall_segment", Vector2(400, 300), 90.0), _item(&"splitter", Vector2i(12, 2)), _item(&"zap", Vector2i(12, 2)),
			_item(&"zap", Vector2i(30, 3))])
	t.check(layout.item_at(Vector2(200, 118)) == layout.items[0] and layout.item_at(Vector2(214, 114)) == null, "item_at finds a Bumper inside its diamond only")
	t.check(layout.item_at(Vector2(611, 111)) == layout.items[1] and layout.item_at(Vector2(613, 113)) == null, "item_at finds a Booster inside its circle only")
	t.check(layout.item_at(Vector2(450, 303)) == layout.items[2] and layout.item_at(Vector2(403, 340)) == null, "item_at finds a Wall Segment as it is turned")
	t.check(layout.item_at(Vector2(200, 160)) == layout.items[4] and layout.item_at(Vector2(484, 250)) == layout.items[5] and layout.item_at(Vector2(2, 2)) == null, "item_at finds a Zap anywhere on its brick, before the brick under it")
	layout.remove(layout.items[4])
	t.check(layout.item_at(Vector2(200, 160)) == layout.items[3], "with its Zap gone, item_at finds the placed brick")
	layout.add(_item(&"zap", Vector2i(12, 2)))
	layout.remove(layout.items[3])
	t.check(layout.count(&"splitter") == 0 and layout.count(&"zap") == 1 and layout.items.size() == 4, "taking out a placed brick takes its Zap with it")


# --- combos ----------------------------------------------------------------------------------------------------

func _combo() -> void:
	var bricks := {FAR: SOLID}
	for column in range(20, 60):
		bricks[Vector2i(column, 6)] = 1
	var board := _board(bricks)
	var break_next := func(round: Round, n: int) -> void:
		for i in n:
			var column := 20
			while round.board.brick(Vector2i(column, 6)) == null:
				column += 1
			round.hit_brick(Vector2i(column, 6), Round.Cause.BALL, Vector2.RIGHT)

	var round := Round.new(board, null, _stats(), 1)
	var log := _events(round)
	break_next.call(round, 9)
	t.check(round.combo.count == 0 and round.combo.multiplier == 1 and round.combo.window == 0.0 and not log.any(func(line: String) -> bool: return line.begins_with("combo")),
			"at combo rank 0 there is no combo")
	t.check(round.coins == 9 and round.tally.combos.is_empty() and round.tally.best_combo == 0 and round.tally.best_multiplier == 1, "with combos off every brick pays once")

	var stats := _sealed(board, {&"combo_rank": 1, &"splitter_count": 1})
	stats.ball_speed = 1.0  # the ball stays out of this
	round = Round.new(board, _layout([_item(&"splitter", Vector2i(10, 1))]), stats, 1)
	log = _events(round)
	break_next.call(round, 1)
	t.check(round.combo.count == 1 and round.combo.multiplier == 1 and round.combo.window == stats.combo_window and round.combo.time_left == stats.combo_window and log[0] == "combo 1 1",
			"at combo rank 1 a broken brick starts a combo with the full window, and combo_changed comes before brick_broken")
	break_next.call(round, 3)
	t.check(round.combo.count == 4 and round.combo.multiplier == 1, "the multiplier holds for combo_breaks_per_step breaks")
	log.clear()
	break_next.call(round, 1)
	t.check(round.combo.multiplier == 2 and is_equal_approx(round.combo.window, stats.combo_window * stats.combo_window_shrink) and log[0] == "combo 5 2" and log[1].ends_with(" 6"),
			"the break that raises the multiplier pays the rise on the whole combo (5 + 5 - 4), and the window shrinks")
	break_next.call(round, 4)
	t.check(round.combo.multiplier == 3 and is_equal_approx(round.combo.window, stats.combo_window * stats.combo_window_shrink ** 2) and round.coins == 9 * 3, "multiplier and window follow balance.tres, and the combo pays its 9 bricks x3")
	_run(round, 1.0)
	t.check(is_equal_approx(round.combo.time_left, round.combo.window - 1.0) and round.combo.count == 9, "the window counts down while nothing breaks")
	round.hit_brick(Vector2i(10, 1), Round.Cause.BALL, Vector2.RIGHT)
	t.check(round.combo.count == 10 and round.combo.time_left == round.combo.window and round.coins == 27, "a placed brick extends the combo and restarts its window, and pays nothing")
	log.clear()
	_run(round, 1.5)
	t.check(round.combo.count == 0 and round.combo.multiplier == 1 and round.combo.window == 0.0 and round.combo.time_left == 0.0 and log == ["combo 0 1"], "when the window runs out the combo resets, once")
	t.check(round.tally.best_combo == 10 and round.tally.best_multiplier == 3, "the tally keeps the best combo and multiplier")
	break_next.call(round, 1)
	t.check(round.combo.count == 1 and round.combo.multiplier == 1 and round.coins == 28, "after a reset the next combo starts from 1")
	var first: Tally.Run = round.tally.combos[0] if round.tally.combos else null
	t.check(round.tally.combos.size() == 2 and first.count == 10 and first.multiplier == 3 and first.worth == 9, "the tally lists each combo: its count, multiplier and the worth of its level bricks")
	var combo := Combo.new()
	for i in 200:
		combo.add(stats)
	t.check(combo.multiplier == 50 and combo.window == stats.combo_window_min and combo.time_left == stats.combo_window_min, "the window never shrinks below combo_window_min")

	round = Round.new(board, null, _stats({&"combo_rank": 3}), 1)
	break_next.call(round, 1)
	t.check(is_equal_approx(round.combo.window, round.stats.combo_window + 2.0 * round.stats.combo_window_per_rank), "each combo rank above 1 widens the window")


# --- the tally and coins ---------------------------------------------------------------------------------------

func _coins() -> void:
	var board := _board({FAR: SOLID, Vector2i(10, 0): 1, Vector2i(11, 0): 2, Vector2i(12, 0): 1, Vector2i(20, 0): 1, Vector2i(30, 0): 1, Vector2i(50, 6): 1})
	board.bricks[Vector2i(20, 0)].kind = &"gold"
	board.bricks[Vector2i(30, 0)].kind = &"hourglass"
	board.bricks[Vector2i(50, 6)].kind = &"explosive"
	var stats := _stats({&"splitter_count": 1})
	var worth: int = (Kinds.of(&"gold") as BrickKind).worth  # 20
	var seconds: float = Kinds.of(&"hourglass").get("seconds")  # 15
	var round := Round.new(board, _layout([_item(&"splitter", Vector2i(40, 3))]), stats, 1)
	var paid: Array[int] = []
	round.brick_broken.connect(func(_c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, n: int) -> void: paid.append(n))
	var log := _events(round)
	var after: Array[int] = []
	for cell: Vector2i in [Vector2i(10, 0), Vector2i(11, 0), Vector2i(11, 0), Vector2i(12, 0), Vector2i(20, 0), Vector2i(40, 3), Vector2i(30, 0), Vector2i(50, 6)]:
		round.hit_brick(cell, Round.Cause.BALL, Vector2.RIGHT)
		after.append(round.coins)
	t.check(round.tally.broken == {&"": 3, &"gold": 1, &"hourglass": 1, &"explosive": 1} and round.tally.combos.is_empty() and round.tally.placed_broken == 1 and round.tally.dents == 1,
			"the tally counts bricks broken by kind, placed bricks apart, and the hit that left the 2 HP brick standing")
	t.check(paid == [1, 1, 1, worth, 0, 1, 1] and after.slice(0, 3) == [1, 2, 3] and round.coins == 6 + worth and Coins.total(round.tally, stats) == 6 + worth,
			"a hit that breaks nothing scores 1 at once, a break 1 (a gold brick its worth), and a placed brick nothing: a 2 HP brick scores 2 (%s)" % [after])
	t.check(round.time_left == stats.round_time + seconds and log.has("time %s %s" % [stats.round_time + seconds, seconds]), "an hourglass brick adds its seconds and says so")

	var tally := Tally.new()
	tally.broken = {&"": 3, &"gold": 2, &"gone_kind": 1}
	var run := Tally.Run.new()
	run.multiplier = 3
	run.worth = 4
	tally.combos.append(run)
	stats.coins_per_brick = 0.5
	t.check(Coins.total(tally, stats) == floori(0.5 * (3 + 2 * worth + 1 + 4 * 2)),
			"Coins.total is coins_per_brick times the bricks' worth, a gold brick's counted by its worth, plus each combo's worth times its multiplier - 1, rounded down")
	t.check(Coins.total(Tally.new(), stats) == 0, "an empty tally pays nothing")

	# A combo pays all its bricks at the multiplier it has reached.
	var bricks := {FAR: SOLID}
	for column in range(20, 30):
		bricks[Vector2i(column, 6)] = 1
	board = _board(bricks)
	board.bricks[Vector2i(24, 6)].kind = &"gold"
	round = Round.new(board, null, _stats({&"combo_rank": 1}), 1)
	paid.clear()
	round.brick_broken.connect(func(_c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, n: int) -> void: paid.append(n))
	for column in range(20, 26):
		round.hit_brick(Vector2i(column, 6), Round.Cause.BALL, Vector2.RIGHT)
	t.check(round.tally.broken == {&"": 5, &"gold": 1} and paid == [1, 1, 1, 1, 4 + 2 * worth, 2] and round.coins == 2 * (5 + worth),
			"the gold brick that raises the combo to x2 pays twice its worth and the rise on the four before it, and all six are paid x2")

	# A hit that breaks nothing scores 1 and does not grow the combo, but a running combo pays it at its multiplier.
	board = _board({FAR: SOLID, Vector2i(20, 6): 1, Vector2i(21, 6): 1, Vector2i(22, 6): 1, Vector2i(23, 6): 1, Vector2i(24, 6): 1, Vector2i(30, 6): 3})
	round = Round.new(board, null, _stats({&"combo_rank": 1}), 1)
	round.hit_brick(Vector2i(30, 6), Round.Cause.BALL, Vector2.RIGHT)
	t.check(round.coins == 1 and round.combo.count == 0 and round.tally.combos.is_empty(), "a hit with no combo running scores 1 and starts none")
	for column in range(20, 24):
		round.hit_brick(Vector2i(column, 6), Round.Cause.BALL, Vector2.RIGHT)
	round.hit_brick(Vector2i(30, 6), Round.Cause.BALL, Vector2.RIGHT)
	t.check(round.coins == 6 and round.combo.count == 4, "a hit during a combo scores 1 and leaves the combo's count alone")
	round.hit_brick(Vector2i(24, 6), Round.Cause.BALL, Vector2.RIGHT)
	t.check(round.combo.count == 5 and round.combo.multiplier == 2 and round.tally.dents == 2 and round.tally.combos[0].worth == 6 and round.coins == 1 + 6 * 2,
			"the break that takes the combo to x2 pays its five bricks and the hit inside it x2, the hit before it x1 (%d)" % round.coins)

	# The bonuses: the biggest chain, the longest rally, and how the round ended.
	var bonus := {&"chain_bonus": 2, &"rally_bonus": 1, &"clear_bonus": 0.5, &"time_bonus": 2, &"first_clear_bonus": 2, &"kept_bonus": 3}
	board = _board({FAR: SOLID, Vector2i(20, 6): 1, Vector2i(21, 6): 1, Vector2i(22, 6): 1, Vector2i(40, 6): 1})
	board.bricks[Vector2i(20, 6)].kind = &"explosive"
	round = Round.new(board, null, _stats(bonus), 1)
	round.hit_brick(Vector2i(20, 6), Round.Cause.BALL, Vector2.RIGHT)
	t.check(round.tally.best_chain == 2 and round.tally.best_rally == 3, "the blast's two bricks are a chain of 2, without the explosive; all three are a rally of 3")
	round.tally.touch()
	round.hit_brick(Vector2i(40, 6), Round.Cause.BALL, Vector2.RIGHT)
	t.check(round.tally.best_rally == 3 and round.tally.rally == 1 and round.coins == 4 + 2 * 2 + 3, "a paddle touch starts the rally again; the biggest chain and longest rally pay per brick (%d)" % round.coins)

	round = Round.new(_board({Vector2i(20, 6): 1}), null, _stats(bonus), 1)
	round.first_clear = true
	round.target = 2
	round.hit_brick(Vector2i(20, 6), Round.Cause.BALL, Vector2.RIGHT)
	round.step(0.01, round.paddle.y)  # short of the paddle
	t.check(round.reason == Round.End.CLEARED and round.tally.cleared and round.tally.score == 2 and round.tally.seconds_left == 19
			and round.coins == 1 + 1 + 1 + 2 * 19 + 4 + 3,
			"a first clear (a score of 2, a target of 2) with every brick broken and 19 s left pays half the target, 2 a second, twice the target and the kept ball (%d)" % round.coins)
	t.check(round.tally.paddle_touches == 0 and Coins.bonuses(round.tally, round.stats).size() == 5, "every bonus earned is listed, and only those")
	round = Round.new(_board({Vector2i(20, 6): 1}), null, _stats(bonus), 1)
	round.first_clear = true
	round.target = 3
	round.hit_brick(Vector2i(20, 6), Round.Cause.BALL, Vector2.RIGHT)
	round.step(0.01, round.paddle.y)
	t.check(round.reason == Round.End.CLEARED and not round.tally.cleared and round.coins == 1 + 1 + 2 * 19 + 3,
			"every brick broken short of the target is no clear: no clear bonus, no first clear, but the time and the kept ball (%d)" % round.coins)
	var eff := _sealed(_board({}), {&"efficiency_from": 10, &"efficiency_to": 100, &"efficiency_bonus": 0.1})
	var shares := []
	for count in [9, 55, 300]:
		var made := Tally.new()
		made.broken[&""] = count
		made.paddle_touches = 1
		shares.append(Coins.points(made, eff))
		made.ended = true
		shares.append(Coins.points(made, eff))
	t.check(shares == [9, 9, 55, 57, 300, 330], "bricks per paddle touch add nothing until the round ends, then 0 at 10, 5%% at 55 and 10%% from 100 on (%s)" % [shares])
	var timed := _sealed(_board({FAR: SOLID}), bonus)
	timed.round_time = 0.25
	round = Round.new(_board({FAR: SOLID}), null, timed, 1)
	round.step(0.25, round.paddle.y)
	t.check(round.reason == Round.End.TIME and round.coins == 3, "running out of time with a ball in play pays the kept ball only")


# --- how a round ends ------------------------------------------------------------------------------------------

func _ends() -> void:
	var board := _board({FAR: SOLID})
	var stats := _sealed(board)
	stats.round_time = 0.5
	var round := Round.new(board, null, stats, 1)
	var log := _events(round)
	_run(round, 0.49)
	t.check(not round.over and round.time_left > 0.0, "the timer counts down while the round runs")
	_run(round, 0.02)
	t.check(round.over and round.reason == Round.End.TIME and round.time_left == 0.0 and log.count("ended %d" % Round.End.TIME) == 1, "the round ends when the timer reaches 0")
	var at := round.balls[0].pos
	log.clear()
	_run(round, 1.0)
	t.check(round.balls[0].pos == at and log.is_empty(), "after the end a step does nothing and `ended` is not sent again")

	# Cleared: the last level brick, even with a placed brick still standing.
	board = _board({Vector2i(20, 3): 1})
	stats = _sealed(board, {&"splitter_count": 1})
	round = Round.new(board, _layout([_item(&"splitter", Vector2i(50, 6))]), stats, 1)
	log = _events(round)
	var ball := round.balls[0]
	var coming := Vector2.from_angle(deg_to_rad(10.0))
	ball.put(Vector2(314, 220) - coming * 20.0, coming)
	round.step(0.01, round.paddle.y)
	t.check(not round.over, "a round with a brick left is not over")
	round.step(0.1, round.paddle.y)
	t.check(round.over and round.reason == Round.End.CLEARED and round.board.brick(Vector2i(50, 6)) != null and log[-1] == "ended %d" % Round.End.CLEARED and log[-2].begins_with("broke (20, 3)"),
			"breaking the last level brick clears the round on that step; a placed brick does not count")
	t.check(round.coins == 1, "a round pays for what it broke when it ends")

	# Cleared wins over the last ball lost and over time, and a lost ball over time.
	stats = _stats()
	stats.round_time = 0.05
	round = Round.new(board, null, stats, 1)
	round.balls[0].put(Vector2(-50, 100), Vector2(-0.8, 0.6))
	round.hit_brick(Vector2i(20, 3), Round.Cause.BALL, Vector2.RIGHT)
	round.step(0.1, round.paddle.y)
	t.check(round.reason == Round.End.CLEARED and round.balls.is_empty() and round.time_left == 0.0, "a round that is cleared as its last ball goes and its time runs out is cleared")
	round = Round.new(_board({FAR: SOLID}), null, stats, 1)
	round.balls[0].put(Vector2(-50, 100), Vector2(-0.8, 0.6))
	round.step(0.1, round.paddle.y)
	t.check(round.reason == Round.End.BALL_LOST, "a round whose last ball goes as its time runs out ends on the ball")


# --- how long a round takes ------------------------------------------------------------------------------------

## Level 3 as docs/design/levels.md draws it: 72 x 18, a solid wall with a tunnel, 512 bricks.
func _tunnel_board() -> Board:
	var board := Board.new(18)
	for column in range(4, 68):
		for row in 9:
			if row != 4:
				board.bricks[Vector2i(column, row)] = Brick.new(4 if column == 4 or row == 3 or row == 5 else 1)
	return board


func _timing() -> void:
	var board := _tunnel_board()
	t.check(board.bricks.size() == 512 and board.cols == 72, "the timing board is level 3's: 512 bricks on 72 x 18")
	# Mid-game stats, the paddle following the ball, 120 steps a second for the full 20 seconds.
	var stats := _stats({&"paddle_speed": 720.0, &"ball_speed": 980.0, &"paddle_size": 139.0, &"combo_rank": 3, &"explosive_count": 3, &"gold_count": 3, &"hourglass_count": 2,
			&"blast_size": 2.0, &"shockwave": 1, &"bumper_count": 3, &"booster_count": 2, &"wall_segment_count": 2, &"splitter_count": 2, &"zap_count": 2})
	var layout := _layout([_item(&"bumper", Vector2(30, 100)), _item(&"bumper", Vector2(32, 480)), _item(&"bumper", Vector2(1120, 288)), _item(&"booster", Vector2(1110, 100)), _item(&"booster", Vector2(1110, 470)),
			_item(&"wall_segment", Vector2(6, 200)), _item(&"wall_segment", Vector2(6, 376)), _item(&"splitter", Vector2i(2, 2)), _item(&"splitter", Vector2i(2, 6)), _item(&"zap", Vector2i(4, 1)), _item(&"zap", Vector2i(4, 7))])
	var report := []
	for mode: String in ["paddle following", "paddle sealed", "sealed, with Overgrowth"]:
		var s := stats.copy()
		if mode != "paddle following":
			s.paddle_size = board.size().y  # no ball is lost, so the round runs its whole time with every ball it makes
		var began := Time.get_ticks_usec()
		if mode == "sealed, with Overgrowth":
			s.put(&"overgrowth", 1.0)
			s.overgrowth_delay = 8.0
		var round := Round.new(board, layout, s, 4)
		var counts := [0, 0]  # level bricks broken, and grown back
		round.brick_broken.connect(func(_cell: Vector2i, brick: Brick, _cause: Round.Cause, _dir: Vector2, _coins: int) -> void: counts[0] += 0 if brick.placed else 1)
		round.restored.connect(func(_cell: Vector2i, cells: Array[Vector2i]) -> void: counts[1] += cells.size())
		var steps := 0
		while not round.over:
			var target := round.paddle.y
			for ball in round.balls:
				if ball.dir.x < 0.0:
					target = ball.pos.y
			round.step(TICK, target)
			steps += 1
		report.append("%s: %d ms for %.1f s of play (%d steps), %d bricks broken, %d grown back, %d balls at the end" % [mode,
				(Time.get_ticks_usec() - began) / 1000, steps * TICK, steps, counts[0], counts[1], round.balls.size()])
		t.check(round.layout.items.size() == 11, "the timing round has its eleven items")
	print("   rules: a round on 72 x 18 with 512 bricks. ", ". ".join(report))
