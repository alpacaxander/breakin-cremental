extends RefCounted
## Round 1 attack on the rules (src/sim/, src/kinds/): everything that counts and chains. The oracle is the docs
## (docs/design/*.md) and the contract headers, never the code. Hand-built boards and the shipped levels.
##
## Fixed seeds, so it gives the same result every run. To hunt with more random rounds:
##     FUZZ_N=500 FUZZ_SEED=7 tests/run.sh test fuzz_logic
## A random failure is reported once per rule, with the seed of the first round that broke it.

const TICK := 1.0 / 120.0
const SOLID := 1000000
const FAR := Vector2i(63, 0)
## data/balance.tres as it was when this was written, so tuning moves no check here.
const NUMBERS := {
	&"paddle_speed": 360.0, &"paddle_size": 96.0, &"ball_speed": 560.0, &"round_time": 20.0, &"combo_rank": 0.0, &"blast_size": 1.0, &"shockwave": 0.0,
	&"ball_size": 12.0, &"launch_gap": 48.0, &"min_angle_vertical": 20.0, &"min_angle_horizontal": 8.0, &"boost_cap": 3.0, &"shockwave_boost": 2.0,
	&"paddle_thickness": 12.0, &"paddle_inset": 24.0, &"paddle_max_angle": 60.0, &"low_time": 5.0,
	&"combo_window": 1.6, &"combo_window_per_rank": 0.5, &"combo_breaks_per_step": 4, &"combo_window_shrink": 0.9, &"combo_window_min": 0.5,
	&"coins_per_brick": 1.0, &"rotate_step": 15.0,
}
const PLACEABLES: Array[StringName] = [&"bumper", &"booster", &"wall_segment", &"splitter", &"zap"]
const SPECIALS: Array[StringName] = [&"explosive", &"gold", &"hourglass"]

var t: Node
## Random failures: rule -> the first repro that broke it.
var _broken := {}
var _repro := ""
## How often the random rounds reached each thing they check, so they cannot go quiet unnoticed.
var _seen := {}


## A Round that records every hit_brick and blast call as a tree, so each blast and each Zap can be checked
## against the exact hits it made. It changes nothing: every call goes straight to Round's own.
class Spy:
	extends Round
	var frames: Array[Dictionary] = []  # the calls running now, outermost first
	var roots: Array[Dictionary] = []  # calls made from outside any other call
	var boosts := {}  # ball id -> its boost when last seen, kept by blasts and by the case's ball_bounced

	func _init(b: Board, l: Layout, s: Balance, sd: int) -> void:
		exploded.connect(func(pos: Vector2, reach: float, cells: Array[Vector2i]) -> void:
			if not frames.is_empty() and frames.back().type == "blast" and not frames.back().has("told"):
				frames.back().told = [pos, reach, cells.duplicate()])
		super(b, l, s, sd)

	func _push(rec: Dictionary) -> void:
		if frames.is_empty():
			roots.append(rec)
		else:
			frames.back().children.append(rec)
		frames.append(rec)

	func hit_brick(cell: Vector2i, cause: Round.Cause, dir: Vector2, ball: Ball = null) -> void:
		var b := board.brick(cell)
		_push({"type": "hit", "cell": cell, "cause": cause, "dir": dir, "ball": ball, "pre": b.copy() if b else null, "children": []})
		super(cell, cause, dir, ball)
		frames.pop_back()
		if not frames.is_empty() and frames.back().type == "blast":
			frames.back().before = _balls()  # what the blast's Shockwave starts from

	func _balls() -> Array:
		return balls.map(func(b: Ball) -> Array: return [b, b.pos, b.dir, b.boost])

	func blast(cell: Vector2i, reach: float) -> void:
		var area := board.cell_rect(cell).grow(reach)
		var want: Array[Vector2i] = []
		for c: Vector2i in board.bricks:
			var r := board.cell_rect(c).intersection(area)
			if r.size.x > 0.0 and r.size.y > 0.0:
				want.append(c)
		want.sort()  # by column, then by row
		var rec := {"type": "blast", "cell": cell, "reach": reach, "area": area, "want": want, "before": _balls(), "children": []}
		_push(rec)
		super(cell, reach)
		frames.pop_back()
		rec.after = _balls()
		for b in balls:
			boosts[b.id] = b.boost


func run(p_t: Node) -> void:
	t = p_t
	_blast_reach()
	_chains()
	_shockwave()
	_zap()
	_specials()
	_fits()
	_combo()
	_ends()
	var n := int(OS.get_environment("FUZZ_N")) if OS.get_environment("FUZZ_N") else 24
	var base := int(OS.get_environment("FUZZ_SEED")) if OS.get_environment("FUZZ_SEED") else 1
	for i in n:
		_fuzz_round(base * 100003 + i)
	for i in n * 8:
		_fuzz_fits(base * 7919 + i)
	for i in n / 2:
		_fuzz_tick_rate(base * 3001 + i)
	for rule: String in _broken:
		t.check(false, "%s  [first seen: %s]" % [rule, _broken[rule]])
	var reached := ["blast", "zap", "split", "hourglass", "booster", "shockwave", "CLEARED", "BALL_LOST", "TIME", "tick"].filter(func(k: String) -> bool: return _seen.get(k, 0) > 0)
	t.check(reached.size() == 10,"the random rounds reach blasts, Zaps, splits, hourglasses, Boosters, Shockwaves and all three ends: %s" % [_seen])


# --- helpers ---------------------------------------------------------------------------------------------------

func _stats(stats := {}) -> Balance:
	var s := Balance.new()
	for stat: StringName in NUMBERS:
		s.set(stat, NUMBERS[stat])
	for stat: StringName in stats:
		s.put(stat, stats[stat])
	return s


func _sealed(board: Board, stats := {}) -> Balance:
	var s := _stats(stats)
	s.paddle_size = board.size().y
	s.round_time = 100000.0
	return s


func _board(bricks := {}, rows := 16) -> Board:
	var b := Board.new(rows)
	for cell: Vector2i in bricks:
		b.bricks[cell] = Brick.new(bricks[cell])
	return b


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


## A random-run rule that broke. Reported once, at the end, with the first repro.
func _fail(ok: bool, rule: String, detail := "") -> void:
	if not ok and not _broken.has(rule):
		_broken[rule] = _repro + ("; " + detail if detail else "")


func _angle(dir: Vector2) -> float:
	return rad_to_deg(atan2(absf(dir.y), absf(dir.x)))


## The docs' minimum angles for a throw (physics.md): legal directions are kept; others are turned to the nearest
## legal angle on the same side. Returns true if `got` is what a throw along `away` should give.
func _thrown_ok(away: Vector2, got: Vector2, stats: Balance) -> bool:
	var a := _angle(away)
	var lo := stats.min_angle_horizontal
	var hi := 90.0 - stats.min_angle_vertical
	if a > lo + 0.01 and a < hi - 0.01:
		return got.is_equal_approx(away.normalized())
	var g := _angle(got)
	if g < lo - 0.01 or g > hi + 0.01 or absf(g - clampf(a, lo, hi)) > 0.01:
		return false
	return (away.x == 0.0 or signf(got.x) == signf(away.x)) and (away.y == 0.0 or signf(got.y) == signf(away.y))


# --- explosions: reach at every rank, on every side, at the board's edges ---------------------------------------

func _blast_reach() -> void:
	for rows: int in [14, 16, 18]:
		var bricks := {}
		for column in rows * 4:
			for row in rows / 2:
				bricks[Vector2i(column, row)] = SOLID
		var round := Round.new(_board(bricks, rows), null, _stats(), 1)
		for size: float in [1.0, 1.5, 2.0]:
			var reach := size * 64.0
			# docs/design/upgrades.md: "1 square (4 columns, or 1 brick height) out from the brick's edges", each
			# Blast Size rank half a square more; Round.blast: brick rows are added whole once the blast enters them.
			var cols_out := int(reach / 16.0)
			var rows_out := ceili(reach / 64.0)
			var wrong := 0
			var cells_seen := 0
			for column in rows * 4:
				for row in rows / 2:
					var hits: Array[Vector2i] = []
					var on_hit := func(c: Vector2i, _hp: int, cause: Round.Cause) -> void:
						if cause == Round.Cause.BLAST:
							hits.append(c)
					round.brick_hit.connect(on_hit)
					round.blast(Vector2i(column, row), reach)
					round.brick_hit.disconnect(on_hit)
					var want: Array[Vector2i] = []
					for x in range(column - cols_out, column + cols_out + 1):
						for y in range(row - rows_out, row + rows_out + 1):
							if x >= 0 and x < rows * 4 and y >= 0 and y < rows / 2:
								want.append(Vector2i(x, y))
					cells_seen += 1
					if hits != want:
						wrong += 1
			t.check(wrong == 0, "on %d rows at Blast Size %.1f every blast hits %d columns and %d brick rows to each side, clipped at the board's edges, each brick once (%d of %d cells wrong)" % [rows, size, cols_out, rows_out, wrong, cells_seen])


# --- chains: long fuses, rings, multi-HP bricks ----------------------------------------------------------------

func _chains() -> void:
	# A ring: 3 x 3 explosive bricks around a 20 HP brick, every one inside every other's blast.
	var bricks := {FAR: SOLID}
	for x in range(30, 33):
		for y in range(3, 6):
			bricks[Vector2i(x, y)] = 1
	var board := _board(bricks)
	for c: Vector2i in bricks:
		if c != FAR:
			board.bricks[c].kind = &"explosive"
	board.bricks[Vector2i(31, 4)] = Brick.new(20)
	var spy := Spy.new(board, null, _stats(), 1)
	var booms := [0]
	spy.exploded.connect(func(_p: Vector2, _r: float, _c: Array[Vector2i]) -> void: booms[0] += 1)
	_repro = "a ring of explosive bricks (_chains)"
	spy.hit_brick(Vector2i(30, 3), Round.Cause.BALL, Vector2.RIGHT)
	_check_tree(spy)
	t.check(booms[0] == 8 and spy.board.brick(Vector2i(31, 4)).hp == 20 - 8,
			"a ring of 8 explosive bricks round a 20 HP brick: each explodes once, and the brick in the middle takes one hit per blast (%d blasts, hp %s)" % [booms[0], spy.board.brick(Vector2i(31, 4)).hp if spy.board.brick(Vector2i(31, 4)) else "gone"])

	# A blast that comes back on itself through the edge of the board: explosives along column 0 and the top row.
	bricks = {FAR: SOLID}
	for y in 8:
		bricks[Vector2i(0, y)] = 1
	for x in 40:
		bricks[Vector2i(x, 0)] = 1
	board = _board(bricks)
	for c: Vector2i in bricks:
		if c != FAR:
			board.bricks[c].kind = &"explosive"
	spy = Spy.new(board, null, _stats({&"blast_size": 2.0}), 1)
	_repro = "an L of explosive bricks (_chains)"
	spy.hit_brick(Vector2i(0, 7), Round.Cause.BALL, Vector2.RIGHT)
	_check_tree(spy)
	t.check(spy.board.bricks.size() == 1 and spy.tally.broken.get(&"explosive", 0) == 47 and spy.coins == 47, "an L of 47 explosive bricks along two edges all go off, once each, and pay once each")


## Checks a Spy's call tree against the docs: what each break sets off, what each blast hits, what each Zap hits.
func _check_tree(spy: Spy) -> void:
	var stack := spy.roots.duplicate()
	while not stack.is_empty():
		var rec: Dictionary = stack.pop_back()
		stack.append_array(rec.children)
		if rec.type == "blast":
			var hit_cells: Array[Vector2i] = []
			var ok := true
			for child: Dictionary in rec.children:
				ok = ok and child.type == "hit" and child.cause == Round.Cause.BLAST
				hit_cells.append(child.cell)
			_fail(ok and hit_cells == rec.want, "a blast hits every brick whose cell overlaps the blast's rectangle, once each, by column then row, and nothing else (Round.blast)")
			var told: Array = rec.get("told", [])
			_fail(told.size() == 3 and told[0] == spy.board.cell_rect(rec.cell).get_center() and told[1] == rec.reach and told[2] == rec.want,
					"exploded carries the brick's centre, the reach and every brick cell about to be hit (Round.exploded)")
			var area: Rect2 = rec.area
			var centre := area.get_center()
			for k in mini(rec.before.size(), rec.after.size()):
				var was: Array = rec.before[k]
				var now: Array = rec.after[k]
				var pos: Vector2 = was[1]
				if was[0] != now[0] or not area.grow(0.01).has_point(pos):
					continue
				var inside := area.grow(-0.01).has_point(pos)
				if not inside:
					continue  # on the blast's edge: the docs do not say
				var s := spy.stats
				if s.shockwave < 1.0:
					_fail(now[2] == was[2] and now[3] == was[3], "without Shockwave a blast leaves the balls alone")
					continue
				_seen.shockwave = _seen.get("shockwave", 0) + 1
				var boost := minf(was[3] * s.shockwave_boost, s.boost_cap)
				_fail(is_equal_approx(now[3], boost), "a Shockwave boosts each ball inside the blast, up to the cap (upgrades.md, physics.md)",
						"ball at %s, boost %s -> %s" % [pos, was[3], now[3]])
				if pos != centre:
					_fail(_thrown_ok(pos - centre, now[2], s), "a Shockwave throws each ball inside the blast straight away from its centre, then the minimum angles (upgrades.md)",
							"ball at %s, centre %s, dir %s -> %s" % [pos, centre, was[2], now[2]])
			continue
		var pre: Brick = rec.pre
		var kids: Array = rec.children
		if pre == null or pre.hp > 1:
			_fail(kids.is_empty(), "a hit that breaks nothing sets nothing off")
			continue
		var i := 0
		if pre.kind == &"explosive":
			var ok: bool = kids.size() > 0 and kids[0].type == "blast" and kids[0].cell == rec.cell and kids[0].reach == spy.stats.blast_size * 64.0
			_fail(ok, "an explosive brick that breaks explodes once, from its own cell, reaching blast_size squares (upgrades.md: 'An explosive brick broken by a blast explodes too')")
			i = 1
		var zaps: Array[Vector2i] = []
		for k in range(i, kids.size()):
			if kids[k].type == "hit" and kids[k].cause == Round.Cause.ZAP:
				zaps.append(kids[k].cell)
			else:
				_fail(false, "a break sets off only its own kind's effect and its mod's (Round.hit_brick)")
		if pre.mod == &"zap":
			var want: Array[Vector2i] = []
			for x in spy.board.cols:
				if x != rec.cell.x:
					want.append(Vector2i(x, rec.cell.y))
			_fail(zaps == want, "a Zap hits every other brick in its row, from the paddle side to the back wall (placeables.md)")
		else:
			_fail(zaps.is_empty(), "only a brick with a Zap on it zaps its row")


# --- Shockwave -------------------------------------------------------------------------------------------------

func _shockwave() -> void:
	var board := _board({FAR: SOLID})
	var stats := _sealed(board, {&"shockwave": 1})
	var centre := Vector2(488, 224)  # cell (30, 3); at reach 64 the blast is (416, 128) to (560, 320)
	var wrong := []
	var dirs := [Vector2(-0.6, 0.8), Vector2(0.6, -0.8), Vector2(0.8, 0.6)]
	for off: Vector2 in [Vector2(10, 0), Vector2(-10, 0), Vector2(0, 10), Vector2(0, -10), Vector2(30, 30), Vector2(-30, 30), Vector2(-60, -90), Vector2(71, 95),
			Vector2(-71, -95), Vector2(5, 1), Vector2(1, 50)]:
		for d: Vector2 in dirs:
			var round := Round.new(board, null, stats, 1)
			var ball := round.balls[0]
			ball.put(centre + off, d.normalized())
			round.blast(Vector2i(30, 3), 64.0)
			if not (_thrown_ok(off, ball.dir, stats) and ball.boost == 2.0):
				wrong.append("%s -> %s x%.2f" % [off, ball.dir, ball.boost])
	t.check(wrong.is_empty(), "a Shockwave throws every ball inside the blast straight away from its centre, then the minimum angles, with its speed doubled (upgrades.md, physics.md): %s" % [wrong])

	# The exact centre: no direction is away, but it is inside the blast, so it is boosted.
	var round := Round.new(board, null, stats, 1)
	var ball := round.balls[0]
	ball.put(centre, Vector2(0.6, 0.8))
	round.blast(Vector2i(30, 3), 64.0)
	t.check(ball.boost == 2.0 and absf(ball.dir.length() - 1.0) < 1e-5 and _angle(ball.dir) >= 8.0 - 0.01 and _angle(ball.dir) <= 70.01, "a ball at the blast's exact centre is boosted and keeps a legal direction")

	# Boost stacks and caps: 1.5 after a Booster, then x2 = 3, then capped.
	round = Round.new(board, null, stats, 1)
	ball = round.balls[0]
	ball.put(centre + Vector2(20, 20), Vector2(0.6, 0.8))
	round.set_boost(ball, 1.25)
	round.blast(Vector2i(30, 3), 64.0)
	t.check(ball.boost == 2.5, "a Shockwave doubles the ball's current speed, boost included (physics.md): 1.25 -> %s" % ball.boost)
	round.blast(Vector2i(30, 3), 64.0)
	t.check(ball.boost == 3.0, "boosts stack up to 3x the base speed (physics.md)")

	# A ball that touches the paddle loses its boost.
	round = Round.new(board, null, stats, 1)
	ball = round.balls[0]
	round.set_boost(ball, 2.0)
	_run(round, 0.2)
	t.check(ball.boost == 1.0 and ball.dir.x > 0.0, "a boosted ball drops back to base speed when it touches the paddle (physics.md)")


# --- the Zap ---------------------------------------------------------------------------------------------------

func _zap() -> void:
	# On a host of every kind, in a row with an explosive and a 3 HP brick.
	for host_kind: StringName in [&"", &"explosive", &"gold", &"hourglass", &"splitter"]:
		var board := _board({FAR: SOLID, Vector2i(5, 2): 3, Vector2i(9, 2): 1, Vector2i(12, 2): 1, Vector2i(40, 2): 2, Vector2i(63, 2): 1, Vector2i(20, 1): 1, Vector2i(20, 3): 1})
		board.bricks[Vector2i(12, 2)].kind = &"explosive"
		var items := [_item(&"zap", Vector2i(20, 2))]
		if host_kind == &"splitter":
			items.push_front(_item(&"splitter", Vector2i(20, 2)))
		else:
			board.bricks[Vector2i(20, 2)] = Brick.new(1, host_kind)
		var spy := Spy.new(board, _layout(items), _stats({&"zap_count": 1, &"splitter_count": 1}), 1)
		t.check(spy.board.brick(Vector2i(20, 2)).mod == &"zap", "a Zap goes on a '%s' brick" % host_kind)
		_repro = "a Zap on a '%s' brick (_zap)" % host_kind
		spy.hit_brick(Vector2i(20, 2), Round.Cause.BALL, Vector2.RIGHT)
		_check_tree(spy)
		t.check(spy.board.brick(Vector2i(5, 2)).hp == 2 and spy.board.brick(Vector2i(40, 2)).hp == 1 and spy.board.brick(Vector2i(63, 2)) == null and spy.board.brick(Vector2i(9, 2)) == null,
				"a Zap on a '%s' brick: every other brick in the row takes 1 hit (placeables.md)" % host_kind)

	# Two Zaps in one row: the second host breaks to the first's Zap and zaps the row again.
	var bricks := {FAR: SOLID, Vector2i(10, 4): 1, Vector2i(30, 4): 1}
	for x: int in [0, 5, 20, 50, 63]:
		bricks[Vector2i(x, 4)] = 3
	var spy := Spy.new(_board(bricks), _layout([_item(&"zap", Vector2i(10, 4)), _item(&"zap", Vector2i(30, 4))]), _stats({&"zap_count": 2}), 1)
	_repro = "two Zaps in one row (_zap)"
	spy.hit_brick(Vector2i(10, 4), Round.Cause.BALL, Vector2.RIGHT)
	_check_tree(spy)
	t.check([0, 5, 20, 50, 63].all(func(x: int) -> bool: return spy.board.brick(Vector2i(x, 4)).hp == 1), "two Zaps in one row: every other brick takes one hit from each")


# --- special bricks --------------------------------------------------------------------------------------------

func _specials() -> void:
	var level := Levels.read(1)
	t.check(level != null and level.board.bricks.size() == 24, "level 1 reads as 24 bricks")
	if level == null:
		return
	var board := level.board
	var counts := {}
	for ranks: Array in [[1, 0, 0], [3, 3, 2], [0, 2, 1], [10, 10, 10], [24, 0, 1], [0, 25, 0]]:
		var stats := _stats({&"explosive_count": ranks[0], &"gold_count": ranks[1], &"hourglass_count": ranks[2], &"splitter_count": 2, &"zap_count": 2})
		var layout := _layout([_item(&"splitter", Vector2i(54, 2)), _item(&"splitter", Vector2i(56, 5)), _item(&"zap", Vector2i(54, 2)), _item(&"zap", Vector2i(53, 1))])
		var seen := {}
		for sd in 40:
			var round := Round.new(board, layout if sd % 2 else null, stats, sd)
			counts = {&"explosive": 0, &"gold": 0, &"hourglass": 0}
			var bad := false
			for c: Vector2i in round.board.bricks:
				var b := round.board.brick(c)
				if b.placed:
					bad = bad or b.kind != &"splitter"
				elif b.kind != &"":
					counts[b.kind] += 1
					bad = bad or b.hp != 1 or board.brick(c) == null or board.brick(c).kind != &""
			var left := 24
			var want := {}
			for k in 3:
				want[SPECIALS[k]] = mini(ranks[k], left)
				left -= want[SPECIALS[k]]
			t.check(not bad and counts == want, "ranks %s replace exactly min(rank, standard bricks left) of each kind, in kind order, each 1 HP, never a placed brick (seed %d): got %s" % [ranks, sd, counts])
			var picks := []
			for c: Vector2i in round.board.bricks:
				if round.board.brick(c).kind != &"" and not round.board.brick(c).placed:
					picks.append([c, round.board.brick(c).kind])
			picks.sort()
			seen[str(picks)] = true
			var again := Round.new(board, null if sd % 2 else layout, stats, sd)
			var picks2 := []
			for c: Vector2i in again.board.bricks:
				if again.board.brick(c).kind != &"" and not again.board.brick(c).placed:
					picks2.append([c, again.board.brick(c).kind])
			picks2.sort()
			t.check(picks == picks2, "the same seed gives the same special bricks, with or without a layout (Round, Building 2)")
		if ranks.max() > 0 and ranks[0] + ranks[1] + ranks[2] < 24:
			t.check(seen.size() > 15,"different seeds give different special bricks (ranks %s: %d different rolls in 40 seeds)" % [ranks, seen.size()])


# --- Layout.fits ------------------------------------------------------------------------------------------------

func _fits() -> void:
	var board := _board({Vector2i(30, 3): 1, Vector2i(31, 3): 2, Vector2i(0, 0): 1, Vector2i(63, 7): 1})
	var stats := _stats({&"bumper_count": 3, &"booster_count": 2, &"wall_segment_count": 2, &"splitter_count": 2, &"zap_count": 2})
	var empty := Layout.new()
	var rest := Round.ball_start(board, stats)
	var cases := [
		# [layout, item, should fit, why]
		[empty, _item(&"bumper", Vector2(300, 100)), true, "a Bumper in open grid"],
		[empty, _item(&"bumper", Vector2(488, 224)), false, "a Bumper on a brick"],
		[empty, _item(&"bumper", Vector2(8, 32)), false, "a Bumper on a brick at the grid's corner"],
		[empty, _item(&"bumper", Vector2(-30, 256)), false, "a Bumper in the paddle lane"],
		[empty, _item(&"wall_segment", Vector2(4, 300)), false, "a Wall Segment reaching into the paddle lane"],
		[empty, _item(&"wall_segment", Vector2(5, 300)), true, "a Wall Segment touching the lane's edge"],
		[empty, _item(&"bumper", rest), false, "a Bumper on the ball at rest"],
		[empty, _item(&"booster", rest + Vector2(18, 0)), false, "a Booster over the ball at rest"],
		[empty, _item(&"booster", Vector2(1100, 300)), false, "a Booster off the board"],
		[empty, _item(&"booster", Vector2(500, -10)), false, "a Booster over the top wall"],
		[empty, _item(&"booster", Vector2(500, 515)), false, "a Booster over the bottom wall"],
		[empty, _item(&"wall_segment", Vector2(1020, 300)), false, "a Wall Segment through the back wall"],
		[empty, _item(&"wall_segment", Vector2(500, 40)), false, "a Wall Segment through the top wall"],
		[empty, _item(&"wall_segment", Vector2(500, 40), 90.0), true, "a Wall Segment turned flat near the top wall"],
		[_layout([_item(&"bumper", Vector2(300, 100))]), _item(&"bumper", Vector2(300, 100)), false, "two Bumpers on one spot"],
		[_layout([_item(&"booster", Vector2(300, 100))]), _item(&"bumper", Vector2(300, 100)), false, "a Bumper on a Booster"],
		[_layout([_item(&"wall_segment", Vector2(300, 100))]), _item(&"wall_segment", Vector2(300, 100), 90.0), false, "two Wall Segments crossed"],
		[_layout([_item(&"bumper", Vector2(300, 100)), _item(&"bumper", Vector2(400, 100)), _item(&"bumper", Vector2(500, 100))]), _item(&"bumper", Vector2(700, 100)), false, "a fourth Bumper over a count of 3"],
		[empty, _item(&"splitter", Vector2i(10, 2)), true, "a Splitter on an empty cell"],
		[empty, _item(&"splitter", Vector2i(30, 3)), false, "a Splitter on a brick"],
		[empty, _item(&"splitter", Vector2i(64, 0)), false, "a Splitter off the back of the board"],
		[empty, _item(&"splitter", Vector2i(10, 8)), false, "a Splitter off the bottom of the board"],
		[empty, _item(&"splitter", Vector2i(-1, 3)), false, "a Splitter in the paddle lane"],
		[empty, _item(&"splitter", Vector2i(2, 4)), false, "a Splitter on the ball at rest"],
		[_layout([_item(&"splitter", Vector2i(10, 2))]), _item(&"splitter", Vector2i(10, 2)), false, "two Splitters on one cell"],
		[_layout([_item(&"splitter", Vector2i(10, 2))]), _item(&"bumper", Vector2(168, 160)), false, "a Bumper on a Splitter"],
		[_layout([_item(&"bumper", Vector2(168, 160))]), _item(&"splitter", Vector2i(10, 2)), false, "a Splitter under a Bumper"],
		[_layout([_item(&"splitter", Vector2i(10, 2)), _item(&"splitter", Vector2i(11, 2))]), _item(&"splitter", Vector2i(12, 2)), false, "a third Splitter over a count of 2"],
		[empty, _item(&"zap", Vector2i(30, 3)), true, "a Zap on a brick"],
		[empty, _item(&"zap", Vector2i(29, 3)), false, "a Zap with no brick"],
		[empty, _item(&"zap", Vector2i(64, 3)), false, "a Zap off the board"],
		[_layout([_item(&"zap", Vector2i(30, 3))]), _item(&"zap", Vector2i(30, 3)), false, "two Zaps on one brick"],
		[_layout([_item(&"splitter", Vector2i(10, 2))]), _item(&"zap", Vector2i(10, 2)), true, "a Zap on a Splitter"],
		[_layout([_item(&"zap", Vector2i(30, 3)), _item(&"zap", Vector2i(31, 3))]), _item(&"zap", Vector2i(0, 0)), false, "a third Zap over a count of 2"],
	]
	var wrong := []
	for c: Array in cases:
		if (c[0] as Layout).fits(c[1], board, stats) != c[2]:
			wrong.append(c[3])
	t.check(wrong.is_empty(), "Layout.fits refuses every illegal item and takes every legal one (Layout.fits, placeables.md): wrong on %s" % [wrong])
	# Loading a saved layout (placeables.md: "Any saved item that no longer fits is dropped"; Layout.fitted).
	var saved := _layout([_item(&"zap", Vector2i(10, 2)), _item(&"splitter", Vector2i(10, 2)), _item(&"zap", Vector2i(29, 3)), _item(&"bumper", Vector2(300, 100)),
			_item(&"bumper", Vector2(400, 100)), _item(&"bumper", Vector2(500, 100)), _item(&"zap", Vector2i(30, 3))])
	var kept := saved.fitted(board, _stats({&"bumper_count": 2, &"splitter_count": 1, &"zap_count": 3}))
	t.check(kept.to_data() == _layout([saved.items[1], saved.items[3], saved.items[4], saved.items[0], saved.items[6]]).to_data(),
			"loading keeps the first items of each kind up to its count, and a Zap saved before its Splitter, and drops a Zap with no brick")
	kept = saved.fitted(board, _stats({&"bumper_count": 3, &"zap_count": 3}))
	t.check(kept.count(&"zap") == 1 and kept.count(&"splitter") == 0 and kept.count(&"bumper") == 3, "a Zap on a Splitter that is dropped is dropped with it")
	# A count of 0 takes nothing.
	t.check(PLACEABLES.all(func(k: StringName) -> bool: return not empty.fits(_item(k, Vector2(300, 100) if k != &"zap" and k != &"splitter" else Vector2i(30, 3) if k == &"zap" else Vector2i(10, 2)), board, _stats())),
			"nothing fits at a count of 0")


# --- combos ----------------------------------------------------------------------------------------------------

func _combo() -> void:
	var bricks := {FAR: SOLID}
	for column in range(0, 60):
		bricks[Vector2i(column, 6)] = 1
	var board := _board(bricks)
	for rank: float in [0.0, 1.0, 2.0, 3.0]:
		var stats := _sealed(board, {&"combo_rank": rank})
		stats.ball_speed = 1.0  # the ball stays out of this
		var round := Round.new(board, null, stats, 1)
		var events := []
		round.combo_changed.connect(func(n: int, m: int) -> void: events.append([n, m]))
		var paid := []
		round.brick_broken.connect(func(_c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, n: int) -> void: paid.append(n))
		var ok := true
		var base_window := 1.6 + 0.5 * (rank - 1.0)
		for i in 30:
			round.hit_brick(Vector2i(i, 6), Round.Cause.BALL, Vector2.RIGHT)
			if rank == 0.0:
				continue
			var count := i + 1
			@warning_ignore("integer_division")
			var mult := 1 + (count - 1) / 4
			var window := maxf(0.5, base_window * pow(0.9, mult - 1))
			ok = ok and round.combo.count == count and round.combo.multiplier == mult and is_equal_approx(round.combo.window, window) and paid[i] == mult and events.back() == [count, mult]
		if rank == 0.0:
			t.check(events.is_empty() and round.coins == 30 and round.combo.count == 0 and round.tally.best_multiplier == 1, "at Combo rank 0 combos are off: no combo, every brick pays 1")
			continue
		t.check(ok, "at Combo rank %d the multiplier steps every 4 breaks and the window is %.1f s shrinking by 0.9 per step (balance.tres)" % [rank, base_window])
		# The window: the combo lives until exactly `window` seconds pass with no break.
		var window := round.combo.window
		events.clear()
		var steps := 0
		while round.combo.count > 0 and steps < 10000:
			round.step(0.001, round.paddle.y)
			steps += 1
		t.check(events == [[0, 1]] and absi(steps - roundi(window / 0.001)) <= 1, "at Combo rank %d the combo resets once, %.3f s after the last break (took %d ms)" % [rank, window, steps])


# --- how a round ends ------------------------------------------------------------------------------------------

func _ends() -> void:
	# Each way, emitted once, and nothing after it.
	var ways := {}
	# TIME
	var board := _board({FAR: SOLID})
	var stats := _sealed(board)
	stats.round_time = 0.3
	ways[Round.End.TIME] = Round.new(board, null, stats, 1)
	# BALL_LOST
	stats = _stats()
	ways[Round.End.BALL_LOST] = Round.new(board, null, stats, 1)
	ways[Round.End.BALL_LOST].balls[0].put(Vector2(-40, 100), Vector2(-0.8, 0.6))
	# CLEARED: by a blast, with an hourglass and a placed brick left standing.
	var b2 := _board({Vector2i(20, 3): 1, Vector2i(21, 3): 1, Vector2i(22, 3): 1})
	b2.bricks[Vector2i(20, 3)].kind = &"explosive"
	b2.bricks[Vector2i(22, 3)].kind = &"hourglass"
	ways[Round.End.CLEARED] = Round.new(b2, _layout([_item(&"splitter", Vector2i(50, 3))]), _sealed(b2, {&"splitter_count": 1}), 1)
	ways[Round.End.CLEARED].hit_brick(Vector2i(20, 3), Round.Cause.BALL, Vector2.RIGHT)
	for why: Round.End in ways:
		var round: Round = ways[why]
		var log := []
		for sig: Signal in [round.brick_hit, round.brick_broken, round.ball_bounced, round.ball_added, round.ball_lost, round.exploded, round.combo_changed, round.time_changed, round.ended]:
			sig.connect(func(a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null) -> void: log.append([sig.get_name(), a]))
		for i in 200:
			round.step(1.0 / 60.0, round.paddle.y)
		var ends := log.filter(func(e: Array) -> bool: return e[0] == "ended")
		t.check(ends.size() == 1 and ends[0][1] == why and round.reason == why and log.back()[0] == "ended", "the round ends once, by %s, and `ended` is the last thing it says" % Round.End.keys()[why])
	# Round ONE STEP 5: "A board with no level bricks is cleared on its first step", placed bricks or not.
	var bare := _board()
	var round := Round.new(bare, _layout([_item(&"splitter", Vector2i(30, 3))]), _stats({&"splitter_count": 1}), 1)
	round.step(1.0 / 60.0, round.paddle.y)
	t.check(round.over and round.reason == Round.End.CLEARED and round.coins == 0, "a board with no level bricks is cleared on its first step, with a placed brick on it")
	t.check(ways[Round.End.CLEARED].coins == 3 and ways[Round.End.CLEARED].board.brick(Vector2i(50, 3)) != null, "the last level brick broken by a blast clears the round, with a placed brick still up")


# --- random rounds ---------------------------------------------------------------------------------------------

func _random_board(rng: RandomNumberGenerator) -> Board:
	var level := rng.randi_range(0, 5)
	if level >= 1 and level <= 3:
		return Levels.read(level).board
	var rows: int = [14, 16, 18, 20][rng.randi_range(0, 3)]
	var board := Board.new(rows)
	var density := rng.randf_range(0.05, 0.7)
	var x0 := rng.randi_range(0, board.cols - 1)
	var x1 := rng.randi_range(x0, board.cols - 1)
	for x in range(x0, x1 + 1):
		for y in rows / 2:
			if rng.randf() < density:
				board.bricks[Vector2i(x, y)] = Brick.new(rng.randi_range(1, 4))
	return board


func _random_item(rng: RandomNumberGenerator, board: Board, layout: Layout) -> Layout.Item:
	var kind: StringName = PLACEABLES[rng.randi_range(0, PLACEABLES.size() - 1)]
	var item := Layout.Item.new()
	item.kind = Kinds.of(kind)
	match item.kind.placement:
		PlaceableKind.Placement.FREE:
			var size := board.size()
			var pick := rng.randi_range(0, 3)
			if pick == 0 and not board.bricks.is_empty():  # next to a brick
				var c: Vector2i = board.bricks.keys()[rng.randi_range(0, board.bricks.size() - 1)]
				item.pos = board.cell_rect(c).get_center() + Vector2(rng.randf_range(-40, 40), rng.randf_range(-60, 60))
			elif pick == 1:  # near an edge of the grid
				item.pos = Vector2(rng.randf_range(-10, 40) if rng.randf() < 0.5 else size.x - rng.randf_range(-10, 40), rng.randf_range(-10, size.y + 10))
			elif pick == 2 and not layout.items.is_empty():  # near another item
				var other := layout.items[rng.randi_range(0, layout.items.size() - 1)]
				item.pos = (other.pos if other.kind.placement == PlaceableKind.Placement.FREE else board.cell_rect(other.cell).get_center()) + Vector2(rng.randf_range(-50, 50), rng.randf_range(-70, 70))
			else:
				item.pos = Vector2(rng.randf_range(-20, size.x + 20), rng.randf_range(-20, size.y + 20))
			if item.kind.rotatable:
				item.rot = [0.0, 15.0, 45.0, 90.0, rng.randf_range(-180, 180)][rng.randi_range(0, 4)]
		PlaceableKind.Placement.BRICK, PlaceableKind.Placement.MOD:
			if rng.randf() < 0.5 and not board.bricks.is_empty():
				var c: Vector2i = board.bricks.keys()[rng.randi_range(0, board.bricks.size() - 1)]
				item.cell = c + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			else:
				item.cell = Vector2i(rng.randi_range(-1, board.cols), rng.randi_range(-1, board.rows / 2))
	return item


func _random_stats(rng: RandomNumberGenerator) -> Balance:
	var s := _stats({&"combo_rank": rng.randi_range(0, 3), &"blast_size": [1.0, 1.5, 2.0][rng.randi_range(0, 2)], &"shockwave": rng.randi_range(0, 1),
			&"explosive_count": rng.randi_range(0, 30), &"gold_count": rng.randi_range(0, 3), &"hourglass_count": rng.randi_range(0, 3)})
	for k in PLACEABLES:
		s.put(Balance.count_stat(k), rng.randi_range(0, 3))
	s.ball_speed = 560.0 * rng.randf_range(1.0, 1.75)
	s.paddle_speed = 360.0 * rng.randf_range(1.0, 2.0)
	s.paddle_size = 96.0 * rng.randf_range(1.0, 1.45)
	return s


func _fuzz_round(sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var board := _random_board(rng)
	var stats := _random_stats(rng)
	var layout := Layout.new()
	for i in 40:
		var item := _random_item(rng, board, layout)
		if layout.fits(item, board, stats):
			layout.add(item)
	var dt: float = [1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0][rng.randi_range(0, 2)]
	_repro = "random round %d" % sd
	var spy := Spy.new(board, layout, stats, sd)
	_fail(spy.layout.to_data() == layout.fitted(board, stats).to_data(), "a round is built from the fitted layout")

	# What the round should hold, kept from its signals.
	var hp := {}
	var placed := {}
	var left := 0
	for c: Vector2i in spy.board.bricks:
		hp[c] = spy.board.brick(c).hp
		placed[c] = spy.board.brick(c).placed
		if not placed[c]:
			left += 1
	var rolled := {}
	for c: Vector2i in spy.board.bricks:
		var k := spy.board.brick(c).kind
		if not placed[c] and k != &"":
			rolled[k] = rolled.get(k, 0) + 1
	var pool := board.bricks.size()
	for k: StringName in SPECIALS:
		var want := mini(stats.count(k), pool)
		pool -= want
		_fail(rolled.get(k, 0) == want, "rank N of a special brick replaces N standard bricks, or as many as are left (upgrades.md)")
	var m := {"left": left, "points": {}, "broken": {}, "placed": 0, "coins": 0, "count": 0, "mult": 1, "best": 0, "last": "", "added": 0.0,
			"splits": 0, "balls": {0: true}, "next": 1, "ended": 0, "after": 0, "expect": "", "new": []}
	var cap := stats.boost_cap
	var lane := spy.board.lane()

	spy.brick_hit.connect(func(c: Vector2i, hp_left: int, cause: Round.Cause) -> void:
		if m.ended:
			m.after += 1
		var rec: Dictionary = spy.frames.back()
		_fail(hp.has(c) and hp[c] - 1 == hp_left and hp_left > 0 and spy.board.brick(c).hp == hp_left, "a hit takes exactly 1 HP and brick_hit says what is left")
		_fail(rec.cell == c and rec.cause == cause, "brick_hit carries the cell and cause of the hit")
		hp[c] = hp_left
		m.last = "hit")
	spy.combo_changed.connect(func(n: int, mult: int) -> void:
		if m.ended:
			m.after += 1
		_fail(stats.combo_rank >= 1.0, "combo_changed is not emitted while combos are off")
		if n == 0:
			_fail(mult == 1 and m.count > 0, "a reset is combo_changed(0, 1), only when a combo was running")
		else:
			@warning_ignore("integer_division")
			var want := 1 + (n - 1) / stats.combo_breaks_per_step
			_fail(n == m.count + 1 and mult == want, "a break adds 1 to the combo; the multiplier is 1 + (count - 1) / 4 (balance.tres)")
			m.best = maxi(m.best, n)
		m.count = n
		m.mult = mult
		m.last = "combo" if n > 0 else "reset")
	spy.brick_broken.connect(func(c: Vector2i, brick: Brick, cause: Round.Cause, dir: Vector2, coins: int) -> void:
		if m.ended:
			m.after += 1
		var rec: Dictionary = spy.frames.back()
		var pre: Brick = rec.pre
		_fail(hp.get(c, 0) == 1 and brick.hp == 0 and spy.board.brick(c) == null, "a brick breaks on its last HP and is off the board when brick_broken is heard")
		_fail(pre != null and brick.kind == pre.kind and brick.mod == pre.mod and brick.placed == pre.placed and brick.placed == placed.get(c, false), "brick_broken's brick has the kind, mod and placed flag it had")
		_fail(rec.cell == c and rec.cause == cause, "brick_broken carries the cell and cause of the hit")
		_fail(stats.combo_rank < 1.0 or m.last == "combo", "with combos on, combo_changed comes just before brick_broken")
		hp.erase(c)
		var mult: int = m.mult if stats.combo_rank >= 1.0 else 1
		if stats.combo_rank >= 1.0:
			var window := maxf(stats.combo_window_min, (stats.combo_window + stats.combo_window_per_rank * (stats.combo_rank - 1.0)) * pow(stats.combo_window_shrink, mult - 1))
			_fail(is_equal_approx(spy.combo.window, window) and spy.combo.time_left == spy.combo.window, "each break restarts the window at its length for the multiplier and rank")
		if placed[c]:
			m.placed += 1
		else:
			m.left -= 1
			m.broken[brick.kind] = m.broken.get(brick.kind, 0) + 1
			m.points[brick.kind] = m.points.get(brick.kind, 0) + mult
		var sum := 0
		for k: StringName in m.points:
			sum += m.points[k] * (5 if k == &"gold" else 1)
		var total := floori(stats.coins_per_brick * sum)
		_fail(coins == total - m.coins and spy.coins == total, "each brick pays 1 x its multiplier, a gold brick 5, a placed brick nothing; `coins` is the running total (overview.md)")
		_fail(not placed[c] or coins == 0, "a placed brick pays nothing (placeables.md)")
		m.coins = total
		_fail(absf(dir.length() - 1.0) < 1e-4, "brick_broken's dir is a unit vector")
		match cause:
			Round.Cause.BALL:
				_fail(dir == rec.dir, "a brick a ball breaks is thrown along the ball's direction of travel")
				var ball: Ball = rec.ball
				_fail(ball != null and ball.rect().grow(0.05).intersects(spy.board.cell_rect(c)) and not ball.rect().grow(-0.05).intersects(spy.board.cell_rect(c)),
						"when a ball breaks a brick the ball is on the brick's face")
				if ball:
					var b := ball.rect()
					var r := spy.board.cell_rect(c)
					var faces := []
					if absf(b.end.x - r.position.x) < 0.05: faces.append(Vector2.LEFT)
					if absf(b.position.x - r.end.x) < 0.05: faces.append(Vector2.RIGHT)
					if absf(b.end.y - r.position.y) < 0.05: faces.append(Vector2.UP)
					if absf(b.position.y - r.end.y) < 0.05: faces.append(Vector2.DOWN)
					_fail(faces.any(func(n: Vector2) -> bool: return rec.dir.dot(n) < 0.0 and ball.dir.dot(n) > 0.0),
							"when a ball breaks a brick it has already bounced: its new dir leaves the face it hit (Round.brick_broken)",
							"ball at %s dir %s -> %s, brick %s" % [ball.pos, rec.dir, ball.dir, c])
			Round.Cause.BLAST:
				var parent: Dictionary = spy.frames[-2]
				var away: Vector2 = spy.board.cell_rect(c).get_center() - (parent.area as Rect2).get_center()
				_fail(parent.type == "blast" and dir.is_equal_approx(away.normalized()), "a brick a blast breaks is thrown away from the blast's centre")
			Round.Cause.ZAP:
				_seen.zap = _seen.get("zap", 0) + 1
				var parent: Dictionary = spy.frames[-2]
				_fail(parent.type == "hit" and dir == (Vector2.LEFT if c.x < parent.cell.x else Vector2.RIGHT), "a brick a Zap breaks is thrown along the row away from the tagged brick")
		var kind := brick.kind
		m.expect = "exploded" if kind == &"explosive" else "time" if kind == &"hourglass" else "added" if kind == &"splitter" and cause == Round.Cause.BALL else ""
		m.last = "broken")
	spy.exploded.connect(func(_p: Vector2, _r: float, cells: Array[Vector2i]) -> void:
		if m.ended:
			m.after += 1
		_fail(cells.all(func(c: Vector2i) -> bool: return spy.board.brick(c) != null), "every brick in exploded's cells is still on the board")
		_fail(m.last != "broken" or m.expect == "exploded", "only an explosive brick's break sets off a blast")
		_seen.blast = _seen.get("blast", 0) + 1
		m.last = "exploded")
	spy.time_changed.connect(func(left_now: float, added: float) -> void:
		if m.ended:
			m.after += 1
		_fail(m.last == "broken" and m.expect == "time" and added == 2.0 and left_now == spy.time_left, "an hourglass brick adds 2 s when it breaks, and only then (upgrades.md)")
		m.added += added
		_seen.hourglass = _seen.get("hourglass", 0) + 1
		m.last = "time")
	spy.ball_added.connect(func(ball: Ball) -> void:
		if m.ended:
			m.after += 1
		_fail(m.last == "broken" and m.expect == "added", "a ball is added only when a ball breaks a Splitter (placeables.md)")
		_fail(ball.id == m.next and spy.balls.has(ball) and ball.boost >= 1.0 and ball.boost <= cap, "ball_added gives the next ball, already in `balls`")
		m.balls[ball.id] = true
		m.next += 1
		m.splits += 1
		spy.boosts[ball.id] = ball.boost
		m.new.append([ball, ball.pos])
		_seen.split = _seen.get("split", 0) + 1
		m.last = "added")
	spy.ball_lost.connect(func(ball: Ball) -> void:
		if m.ended:
			m.after += 1
		_fail(m.balls.has(ball.id) and not spy.balls.has(ball) and ball.pos.x <= -lane - ball.size * 0.5 + 0.01, "ball_lost gives a ball that is out of `balls`, wholly past the open side")
		m.balls.erase(ball.id)
		m.last = "lost")
	spy.ball_bounced.connect(func(ball: Ball, hit: Hit) -> void:
		if m.ended:
			m.after += 1
		_fail(hit.surface != Hit.Surface.BRICK and spy.balls.has(ball), "ball_bounced is never for a brick")
		var was: float = spy.boosts.get(ball.id, 1.0)
		var want := was
		if hit.surface == Hit.Surface.PADDLE:
			want = 1.0
		elif hit.surface == Hit.Surface.ITEM and hit.item.kind.id == &"booster":
			want = minf(was + 0.25, cap)
			_seen.booster = _seen.get("booster", 0) + 1
		_fail(is_equal_approx(ball.boost, want), "a Booster adds 25% of base speed, up to 3x; the paddle takes the boost away; nothing else changes it (physics.md)",
				"ball %d off %s: boost %s -> %s" % [ball.id, Hit.Surface.keys()[hit.surface], was, ball.boost])
		spy.boosts[ball.id] = ball.boost
		m.last = "bounced")
	spy.ended.connect(func(why: Round.End) -> void:
		m.ended += 1
		_seen[Round.End.keys()[why]] = _seen.get(Round.End.keys()[why], 0) + 1
		m.last = "ended")

	var log := []
	spy.brick_broken.connect(func(c: Vector2i, _b: Brick, cause: Round.Cause, _d: Vector2, _n: int) -> void: log.append([c, cause]))
	var targets := []
	var time := spy.time_left
	var steps := 0
	while not spy.over and steps < 40.0 / dt:
		var target := spy.paddle.y if rng.randf() < 0.9 else rng.randf_range(-100, 700)
		var best := INF
		for ball in spy.balls:
			if ball.dir.x < 0.0 and ball.pos.x < best:
				best = ball.pos.x
				target = ball.pos.y + rng.randf_range(-40, 40)
		m.added = 0.0
		m.new = []
		targets.append(target)
		var was_y := spy.paddle.y
		spy.step(dt, target)
		steps += 1
		var half := minf(spy.paddle.length, spy.board.size().y) * 0.5
		var paddle_y := clampf(move_toward(was_y, target, stats.paddle_speed * dt), half, spy.board.size().y - half)
		_fail(is_equal_approx(spy.paddle.y, paddle_y), "the paddle moves toward its target at paddle speed (Round.step 1)")
		for pair: Array in m.new:
			_fail(pair[0].pos == pair[1], "a ball made during a step starts moving on the next one (Round.step 2)")
		time = maxf(time + m.added - dt, 0.0)
		_fail(absf(spy.time_left - time) < 1e-6, "the timer counts down and hourglass bricks add to it")
		for ball in spy.balls:
			_fail(ball.boost >= 1.0 and ball.boost <= cap and absf(ball.dir.length() - 1.0) < 1e-4, "every ball's boost is between 1 and the cap and its dir is a unit vector")
		_fail(spy.balls.size() == m.balls.size(), "`balls` holds every ball added and not lost")
		if spy.over:
			var why := Round.End.CLEARED if m.left == 0 else Round.End.BALL_LOST if spy.balls.is_empty() else Round.End.TIME
			_fail(m.ended == 1 and m.last == "ended" and spy.reason == why and (why != Round.End.TIME or spy.time_left == 0.0), "the round ends once, cleared before ball lost before time, and `ended` is the last signal")
		else:
			_fail(m.left > 0 and not spy.balls.is_empty() and spy.time_left > 0.0, "the round goes on while level bricks, balls and time are left")
		_fail(spy.board.remaining() == m.left, "the level bricks left are the ones not yet broken")
	_check_tree(spy)
	# Nothing after the end.
	var at := spy.balls.map(func(b: Ball) -> Vector2: return b.pos)
	for i in 20:
		spy.step(dt, spy.paddle.y + 100)
	_fail(m.after == 0 and m.ended <= 1 and spy.balls.map(func(b: Ball) -> Vector2: return b.pos) == at, "after the end nothing moves and nothing is emitted")
	# The tally against our count.
	_fail(spy.tally.broken == m.broken and spy.tally.points == m.points and spy.tally.placed_broken == m.placed, "the tally counts the bricks broken by kind, and placed bricks apart")
	_fail(spy.tally.best_combo == m.best, "the tally keeps the best combo")
	_fail(spy.coins == Coins.total(spy.tally, stats) and spy.coins == m.coins, "`coins` is what the tally pays")
	# Round INPUTS: "the same four inputs and the same paddle targets always give the same round".
	var again := Round.new(board, layout, stats, sd)
	var log2 := []
	again.brick_broken.connect(func(c: Vector2i, _b: Brick, cause: Round.Cause, _d: Vector2, _n: int) -> void: log2.append([c, cause]))
	for target: float in targets:
		again.step(dt, target)
	_fail(log2 == log and again.coins == spy.coins and again.reason == spy.reason and again.over == spy.over and again.time_left == spy.time_left,
			"the same board, layout, stats, seed and paddle targets give the same round (Round INPUTS)")


## Round TICK RATE: "a round with one ball and a paddle that stays put breaks the same bricks in the same order at
## 60, 120 and 240 steps a second". No Splitter, and a paddle as tall as the board so the one ball never leaves.
func _fuzz_tick_rate(sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	_repro = "tick rate %d" % sd
	var board := _random_board(rng)
	var stats := _random_stats(rng)
	stats.put(&"splitter_count", 0)
	stats.paddle_size = board.size().y
	stats.round_time = 100000.0
	var layout := Layout.new()
	for i in 30:
		var item := _random_item(rng, board, layout)
		if layout.fits(item, board, stats):
			layout.add(item)
	var runs := []
	for dt: float in [1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0]:
		var round := Round.new(board, layout, stats, sd)
		var log := []
		round.brick_broken.connect(func(c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, _n: int) -> void: log.append(c))
		for i in roundi(6.0 / dt):
			round.step(dt, round.paddle.y)
		runs.append(log)
	# A break in the last moments may fall either side of the end, so compare what all three have.
	var n: int = mini(runs[0].size(), mini(runs[1].size(), runs[2].size()))
	var same: bool = runs[0].slice(0, n) == runs[1].slice(0, n) and runs[1].slice(0, n) == runs[2].slice(0, n)
	var where := 0
	while where < n and runs[0][where] == runs[1][where] and runs[1][where] == runs[2][where]:
		where += 1
	_fail(same and absi(runs[0].size() - runs[2].size()) <= 2, "one ball and a paddle that stays put break the same bricks in the same order at 60, 120 and 240 steps a second (Round TICK RATE)",
			"%d rows, %d bricks; breaks %d/%d/%d, first difference at break %d" % [board.rows, board.bricks.size(), runs[0].size(), runs[1].size(), runs[2].size(), where])
	_seen.tick = _seen.get("tick", 0) + n


# --- random layouts against Layout.fits ------------------------------------------------------------------------

## The area two convex polygons share, 0 if none.
func _shared(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var area := 0.0
	for poly: PackedVector2Array in Geometry2D.intersect_polygons(a, b):
		var s := 0.0
		for i in poly.size():
			s += poly[i].cross(poly[(i + 1) % poly.size()])
		area += absf(s) * 0.5
	return area


## 1 if they clearly overlap, 0 if they are clearly apart, -1 if it is too close to tell.
func _overlaps(a: PackedVector2Array, b: PackedVector2Array) -> int:
	# Geometry2D clips on a fixed-point grid, so slivers under about a unit wide come out as nothing: those are
	# left to the hand-built cases in _fits().
	if _shared(a, b) > 2.0:
		return 1
	var grown := Geometry2D.offset_polygon(a, 0.5)
	for g: PackedVector2Array in grown:
		if _shared(g, b) > 0.0:
			return -1
	return 0


func _fuzz_fits(sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	_repro = "random layout %d" % sd
	var board := _random_board(rng)
	var stats := _random_stats(rng)
	var layout := Layout.new()
	for i in 12:
		var item := _random_item(rng, board, layout)
		if layout.fits(item, board, stats):
			layout.add(item)
	var rest := Round.ball_start(board, stats)
	var half := Vector2.ONE * stats.ball_size * 0.5
	var ball := Collide.box(Rect2(rest - half, half * 2.0))
	for i in 20:
		var item := _random_item(rng, board, layout)
		var expect := 1  # 1 fits, 0 does not, -1 too close to tell
		if layout.count(item.kind.id) >= stats.count(item.kind.id):
			expect = 0
		elif item.kind.placement == PlaceableKind.Placement.MOD:
			var host := board.brick(item.cell) != null or layout.items.any(func(o: Layout.Item) -> bool: return o.kind.placement == PlaceableKind.Placement.BRICK and o.cell == item.cell)
			var taken := layout.items.any(func(o: Layout.Item) -> bool: return o.kind.placement == PlaceableKind.Placement.MOD and o.cell == item.cell)
			expect = 1 if host and not taken else 0
		else:
			var shape: PackedVector2Array
			if item.kind.placement == PlaceableKind.Placement.BRICK:
				if not board.has_cell(item.cell) or board.brick(item.cell) != null or layout.items.any(func(o: Layout.Item) -> bool: return o.kind.placement == PlaceableKind.Placement.BRICK and o.cell == item.cell):
					expect = 0
				shape = Collide.box(board.cell_rect(item.cell))
			else:
				shape = item.outline()
				var grid := board.grid()
				for p in shape:
					if not grid.grow(-0.05).has_point(p):
						expect = 0 if not grid.grow(0.05).has_point(p) else mini(expect, -1) if expect != 0 else 0
				for c: Vector2i in board.bricks:
					var o := _overlaps(shape, Collide.box(board.cell_rect(c)))
					expect = 0 if o == 1 or expect == 0 else (-1 if o == -1 else expect)
			var others: Array[PackedVector2Array] = [ball]
			for o: Layout.Item in layout.items:
				if o.kind.placement == PlaceableKind.Placement.FREE:
					others.append(o.outline())
				elif o.kind.placement == PlaceableKind.Placement.BRICK:
					others.append(Collide.box(board.cell_rect(o.cell)))
			for other in others:
				var o := _overlaps(shape, other)
				expect = 0 if o == 1 or expect == 0 else (-1 if o == -1 else expect)
		if expect == -1:
			continue
		var got := layout.fits(item, board, stats)
		_fail(got == (expect == 1), "Layout.fits takes an item exactly when it is inside the grid, over no brick, item or the ball at rest, a mod on a free host, and under its count (%s %s)" % [item.kind.id, "fits" if expect == 1 else "does not fit"],
				"%s at %s rot %s cell %s on %d rows; layout %s" % [item.kind.id, item.pos, item.rot, item.cell, board.rows, layout.to_data()])
		if got and rng.randf() < 0.3:
			layout.add(item)
