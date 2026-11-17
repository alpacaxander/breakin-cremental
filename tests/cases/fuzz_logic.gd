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
	&"explosion_damage": 1.0, &"zap_range": 64.0, &"zap_damage": 1.0, &"splitter_splits": 2.0,
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
		exploded.connect(_told)  # a method, not a lambda: a lambda here holds the Spy, which then never frees itself
		super(b, l, s, sd)

	func _told(pos: Vector2, reach: float, cells: Array[Vector2i]) -> void:
		if not frames.is_empty() and frames.back().type == "blast" and not frames.back().has("told"):
			frames.back().told = [pos, reach, cells.duplicate()]

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
	# Round 2.
	_r2_timer()
	_r2_end_order()
	_r2_chain_pay()
	_r2_shockwave_chain()
	_r2_zap_blast()
	_r2_painted()
	_r2_fits_rest()
	_r2_save_trip()
	# Round 3.
	_r3_combo_window()
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
				if x != rec.cell.x and absi(x - rec.cell.x) <= int(spy.stats.zap_range):
					for d in int(spy.stats.zap_damage):
						want.append(Vector2i(x, rec.cell.y))
			_fail(zaps == want, "a Zap hits every other brick within zap_range in its row, zap_damage times, from the paddle side to the back wall")
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
	# ...but keeps what a Booster gave it.
	round = Round.new(board, null, stats, 1)
	ball = round.balls[0]
	(Kinds.of(&"booster") as PlaceableKind).on_ball_hit(round, ball, null)
	var given := ball.boost
	round.set_boost(ball, 2.0)
	_run(round, 0.2)
	t.check(given > 1.0 and ball.boost == given and ball.dir.x > 0.0, "the paddle leaves a Booster's boost (%s -> %s)" % [given, ball.boost])


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
	t.check(level != null and level.board.bricks.size() == 20, "level 1 reads as 20 bricks")
	if level == null:
		return
	var board := level.board
	var counts := {}
	for ranks: Array in [[1, 0, 0], [3, 3, 2], [0, 2, 1], [10, 10, 10], [20, 0, 1], [0, 21, 0]]:
		var stats := _stats({&"explosive_count": ranks[0], &"gold_count": ranks[1], &"hourglass_count": ranks[2], &"splitter_count": 2, &"zap_count": 2})
		var layout := _layout([_item(&"splitter", Vector2i(34, 2)), _item(&"splitter", Vector2i(50, 5)), _item(&"zap", Vector2i(34, 2)), _item(&"zap", Vector2i(48, 1))])
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
			var left := board.bricks.size()
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
		if ranks.max() > 0 and ranks[0] + ranks[1] + ranks[2] < board.bricks.size():
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
		[empty, _item(&"wall_segment", Vector2(5, 400)), true, "a Wall Segment touching the lane's edge"],
		[empty, _item(&"bumper", rest), false, "a Bumper on the ball at rest"],
		[empty, _item(&"wall_segment", Vector2(5, 300)), false, "a Wall Segment between the ball at rest and the paddle"],
		[empty, _item(&"splitter", Vector2i(0, 3)), false, "a Splitter between the ball at rest and the paddle"],
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
			@warning_ignore("integer_division")
			var was := 1 + maxi(count - 2, 0) / 4
			var window := maxf(0.5, base_window * pow(0.9, mult - 1))
			# every brick in the combo is paid at its multiplier, so this break pays itself and the rise on the rest
			ok = ok and round.combo.count == count and round.combo.multiplier == mult and is_equal_approx(round.combo.window, window) and paid[i] == count * mult - (count - 1) * was and events.back() == [count, mult]
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
	var inputs := _r2_inputs(board, layout, stats)
	var spy := Spy.new(board, layout, stats, sd)
	_fail(spy.layout.to_data() == layout.fitted(board, stats).to_data(), "a round is built from the fitted layout")
	_r2_watch(spy)

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
	var m := {"left": left, "base": 0, "run": 0, "done": 0, "was": 1, "broken": {}, "placed": 0, "coins": 0, "count": 0, "mult": 1, "best": 0, "last": "", "added": 0.0,
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
		if not placed[c]:
			m.base += 1
			if m.count > 0:
				m.run += 1
		var total := floori(stats.coins_per_brick * (m.base + m.done + m.run * (m.mult - 1)))
		_fail(spy.coins == total, "a hit that leaves a level brick standing scores 1, paid again by a running combo, a placed brick's nothing; `coins` has it when brick_hit is heard")
		m.coins = total
		m.last = "hit")
	spy.combo_changed.connect(func(n: int, mult: int) -> void:
		if m.ended:
			m.after += 1
		_fail(stats.combo_rank >= 1.0, "combo_changed is not emitted while combos are off")
		if n == 0:
			_fail(mult == 1 and m.count > 0, "a reset is combo_changed(0, 1), only when a combo was running")
			m.done += m.run * (m.mult - 1)
			m.run = 0
		else:
			@warning_ignore("integer_division")
			var want := 1 + (n - 1) / stats.combo_breaks_per_step
			_fail(n == m.count + 1 and mult == want, "a break adds 1 to the combo; the multiplier is 1 + (count - 1) / 4 (balance.tres)")
			m.best = maxi(m.best, n)
		m.count = n
		m.was = m.mult
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
			var w := 20 if brick.kind == &"gold" else 1
			m.base += w
			if stats.combo_rank >= 1.0:
				m.run += w
		var total := floori(stats.coins_per_brick * (m.base + m.done + m.run * (mult - 1)))
		_fail(coins == total - m.coins and spy.coins == total, "each brick pays 1, a gold brick 20, a placed brick nothing, and a combo pays its bricks again times its multiplier - 1; `coins` is the running total (overview.md)")
		_fail(not placed[c] or coins == 0 or (stats.combo_rank >= 1.0 and m.was < mult), "a placed brick pays nothing (placeables.md), unless it raises the combo's multiplier")
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
		_fail(m.last == "broken" and m.expect == "time" and added == 15.0 and left_now == spy.time_left, "an hourglass brick adds 15 s when it breaks, and only then (upgrades.md)")
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
			want = ball.kept
		elif hit.surface == Hit.Surface.ITEM and hit.item.kind.id == &"booster":
			want = minf(was + 0.1, cap)
			_seen.booster = _seen.get("booster", 0) + 1
		_fail(is_equal_approx(ball.boost, want), "a Booster adds 10% of base speed, up to 3x; the paddle takes away all but a Booster's; nothing else changes it (physics.md)",
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
	_fail(spy.tally.broken == m.broken and spy.tally.placed_broken == m.placed, "the tally counts the bricks broken by kind, and placed bricks apart")
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
	# Round 2: the inputs are not changed by playing, and the order the board lists its bricks in is not an input.
	_fail(_r2_inputs(board, layout, stats) == inputs, "a round changes neither the board, the layout nor the stats it was built from (Round INPUTS: 'The round copies it; the caller's board is not changed')")
	var listed := Board.new(board.rows)
	var keys := board.bricks.keys()
	keys.reverse()
	for c: Vector2i in keys:
		listed.bricks[c] = board.bricks[c].copy()
	var third := Round.new(listed, layout, stats, sd)
	var log3 := []
	third.brick_broken.connect(func(c: Vector2i, _b: Brick, cause: Round.Cause, _d: Vector2, _n: int) -> void: log3.append([c, cause]))
	for target: float in targets:
		third.step(dt, target)
	_fail(log3 == log and third.coins == spy.coins and third.reason == spy.reason, "the same bricks listed in another order give the same round (Round INPUTS)")
	# The lambdas above read `spy` and hang on spy's own signals, so the round holds itself. Let go, or every
	# random round is still there when the test run exits (Godot then reports thousands of leaked objects).
	for sig: Dictionary in spy.get_signal_list():
		for c: Dictionary in spy.get_signal_connection_list(sig.name):
			spy.disconnect(sig.name, c.callable)


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
	# The launch path: the ball at rest and its way straight left to the paddle's face.
	var rest := Round.ball_start(board, stats)
	var half := Vector2.ONE * stats.ball_size * 0.5
	var face := Round.paddle_face(board, stats)
	var ball := Collide.box(Rect2(face, rest.y - half.y, rest.x + half.x - face, half.y * 2.0))
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
		_fail(got == (expect == 1), "Layout.fits takes an item exactly when it is inside the grid, over no brick, item or the launch path, a mod on a free host, and under its count (%s %s)" % [item.kind.id, "fits" if expect == 1 else "does not fit"],
				"%s at %s rot %s cell %s on %d rows; layout %s" % [item.kind.id, item.pos, item.rot, item.cell, board.rows, layout.to_data()])
		if got and rng.randf() < 0.3:
			layout.add(item)


# --- round 2 ---------------------------------------------------------------------------------------------------
# What round 1 left alone: the timer fix at many step rates, which end wins when two come in one step, what a long
# chain pays at each step of the combo, Shockwaves in a chain, a Zap that sets off a blast, special bricks the
# level painted itself, items against the ball at rest on every level size, a layout's trip through the save,
# every ball_bounced payload, and that a round leaves its inputs alone.

## Everything a round is built from, as plain data, to see that playing it changes none of it.
func _r2_inputs(board: Board, layout: Layout, stats: Balance) -> Array:
	var cells := []
	for c: Vector2i in board.bricks:
		var b := board.brick(c)
		cells.append([c, b.hp, b.kind, b.mod, b.placed])
	cells.sort()
	var numbers := {}
	for stat: StringName in NUMBERS:
		numbers[stat] = stats.get(stat)
	return [board.rows, cells, layout.to_data(), numbers, stats.extra.duplicate()]


## Every ball_bounced against Hit's and Round.ball_bounced's words: where the ball is, which way the surface
## faces, and that the ball leaves it.
func _r2_watch(spy: Round) -> void:
	var h := spy.stats.ball_size * 0.5
	var size := spy.board.size()
	spy.ball_bounced.connect(func(ball: Ball, hit: Hit) -> void:
		_fail(ball.pos == hit.point and hit.travel >= 0.0 and absf(hit.normal.length() - 1.0) < 1e-5, "ball_bounced: the ball is at hit.point, hit.travel is not negative, hit.normal is a unit vector (Hit)",
				"off %s at %s, ball at %s, travel %s" % [Hit.Surface.keys()[hit.surface], hit.point, ball.pos, hit.travel])
		if hit.surface == Hit.Surface.WALL:
			var on := (hit.normal == Vector2.DOWN and is_equal_approx(hit.point.y, h)) or (hit.normal == Vector2.UP and is_equal_approx(hit.point.y, size.y - h)) \
					or (hit.normal == Vector2.LEFT and is_equal_approx(hit.point.x, size.x - h))
			_fail(on, "a WALL hit's normal is DOWN, UP or LEFT, for the wall the ball is touching (Hit.Surface.WALL)", "normal %s, point %s" % [hit.normal, hit.point])
			_fail(ball.dir.dot(hit.normal) > 0.0, "after a wall bounce the ball leaves the wall (Round.ball_bounced: ball.dir is the new direction)", "normal %s, dir %s" % [hit.normal, ball.dir])
		elif hit.surface == Hit.Surface.PADDLE:
			_fail(ball.dir.x > 0.0 and _angle(ball.dir) <= spy.stats.paddle_max_angle + 0.01 and ball.boost == ball.kept,
					"off the paddle a ball goes back toward the board, at most paddle_max_angle off level, back to its Booster boost (Round ONE BOUNCE)", "dir %s boost %s" % [ball.dir, ball.boost])
		elif hit.surface == Hit.Surface.ITEM:
			_fail(ball.dir.dot(hit.normal) > 0.0, "after an item bounce the ball leaves the item (Round.ball_bounced)", "%s normal %s, dir %s" % [hit.item.kind.id, hit.normal, ball.dir])
			if hit.item.kind.shape == PlaceableKind.Shape.CIRCLE:
				_fail(hit.normal.is_equal_approx((hit.point - hit.item.pos).normalized()), "a Booster hit's normal points from the Booster's centre to the ball (Hit.normal)",
						"normal %s, from centre %s" % [hit.normal, (hit.point - hit.item.pos).normalized()])
	)


func _r2_count_steps(round: Round, dt: float, at := {}) -> int:
	var n := 0
	while not round.over and n < 200000:
		if at.has(n):
			round.hit_brick(at[n], Round.Cause.BALL, Vector2.RIGHT)
		round.step(dt, round.paddle.y)
		n += 1
	return n


## Round ONE STEP 4, after the fix in d943e98: "A round whose time is a whole number of steps plays exactly that
## many; any other plays to the end of the step its time runs out in."
func _r2_timer() -> void:
	var board := _board({FAR: SOLID, Vector2i(40, 2): 1, Vector2i(44, 6): 1})
	board.bricks[Vector2i(40, 2)].kind = &"hourglass"
	board.bricks[Vector2i(44, 6)].kind = &"hourglass"
	var wrong := []
	var runs := [[20.0, [24, 30, 48, 50, 60, 75, 90, 100, 120, 144, 165, 200, 240, 300]], [23.0, [60, 120, 144, 240]], [26.0, [60, 144]], [29.0, [60, 120, 144, 240]],
			[0.3, [10, 20, 30, 60, 120, 1000]], [0.7, [10, 30, 70, 90, 110, 130, 170]], [20.005, [60, 120]], [0.31, [60, 100]], [1.1, [3, 7, 9, 30]]]
	for run: Array in runs:
		var time: float = run[0]
		for rate: int in run[1]:
			var stats := _sealed(board, {&"ball_speed": 1.0})
			stats.round_time = time
			var round := Round.new(board, null, stats, 1)
			var n := _r2_count_steps(round, 1.0 / rate)
			var exact := time * rate
			var want := roundi(exact) if absf(exact - roundf(exact)) < 1e-6 else ceili(exact)
			if n != want or round.reason != Round.End.TIME or round.time_left != 0.0:
				wrong.append("%s s at %d/s: %d steps, want %d" % [time, rate, n, want])
	# Hourglass bricks add whole seconds, so the round is still a whole number of steps.
	for rate: int in [60, 120, 144, 240]:
		var stats := _sealed(board, {&"ball_speed": 1.0})
		stats.round_time = 20.0
		var round := Round.new(board, null, stats, 1)
		var n := _r2_count_steps(round, 1.0 / rate, {rate * 3: Vector2i(40, 2), rate * 21 + 7: Vector2i(44, 6)})
		if n != rate * 50 or round.reason != Round.End.TIME:
			wrong.append("20 s + two hourglasses at %d/s: %d steps, want %d" % [rate, n, rate * 50])
	t.check(wrong.is_empty(), "a round whose time is a whole number of steps plays exactly that many, any other to the end of the step its time runs out in (Round ONE STEP 4): %s" % [wrong])


## Round ONE STEP 5: "The round ends if every level brick is broken (CLEARED), else if no ball is left
## (BALL_LOST), else if time_left is 0 (TIME)", when two of them come in the same step.
func _r2_end_order() -> void:
	# A ball breaks the last brick on its top face and goes on out of the open side, in one step.
	for time: float in [100.0, 0.5]:
		var round := Round.new(_board({Vector2i(1, 2): 1}), null, _stats({&"round_time": time}), 1)
		round.balls[0].put(Vector2(30, 110), Vector2(-0.6, 0.8))
		var log := []
		round.ended.connect(func(why: Round.End) -> void: log.append(why))
		round.step(0.5, round.paddle.y)
		t.check(round.board.bricks.is_empty() and round.balls.is_empty(), "the end-order round breaks the last brick and loses its ball in one step (%s s)" % time)
		t.check(log == [Round.End.CLEARED] and round.reason == Round.End.CLEARED, "the last brick broken and the last ball lost%s in one step: the round is CLEARED (Round ONE STEP 5): %s" % [" as time runs out" if time == 0.5 else "", log])
	# The last ball lost as time runs out.
	var round := Round.new(_board({FAR: SOLID}), null, _stats({&"round_time": 0.5}), 1)
	round.balls[0].put(Vector2(-62, 100), Vector2(-0.8, 0.6))
	var log := []
	round.ended.connect(func(why: Round.End) -> void: log.append(why))
	round.step(0.5, round.paddle.y)
	t.check(log == [Round.End.BALL_LOST], "the last ball lost as time runs out: the round ends BALL_LOST (Round ONE STEP 5): %s" % [log])
	# An hourglass broken in the step the time runs out in saves the round.
	var board := _board({FAR: SOLID, Vector2i(30, 3): 1})
	board.bricks[Vector2i(30, 3)].kind = &"hourglass"
	var stats := _sealed(board)
	stats.round_time = 1.0 / 60.0
	round = Round.new(board, null, stats, 1)
	round.balls[0].put(Vector2(470, 224), Vector2(0.8, 0.6))
	round.step(1.0 / 60.0, round.paddle.y)
	t.check(not round.over and round.board.bricks.size() == 1 and absf(round.time_left - 15.0) < 1e-9, "an hourglass broken in the last step adds its 15 s before the timer is read (Round ONE STEP 4): time %s, over %s" % [round.time_left, round.over])


## One hit that breaks ten bricks: every brick in the combo is paid at the multiplier it has reached (Round ONE BRICK HIT,
## overview.md "Coins"), so a break that raises it pays the rise on the earlier ones too; gold is worth 20, the placed
## Splitter nothing, though it still counts in the combo.
func _r2_chain_pay() -> void:
	var bricks := {FAR: SOLID, Vector2i(20, 4): 1, Vector2i(20, 3): 1}
	for x in range(17, 25):
		if x != 20:
			bricks[Vector2i(x, 4)] = 1
	var board := _board(bricks)
	board.bricks[Vector2i(20, 4)].kind = &"explosive"
	board.bricks[Vector2i(20, 3)].kind = &"gold"
	for rank: int in [1, 0]:
		var round := Round.new(board, _layout([_item(&"splitter", Vector2i(20, 5))]), _sealed(board, {&"combo_rank": float(rank), &"splitter_count": 1}), 1)
		var paid := []
		round.brick_broken.connect(func(c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, n: int) -> void: paid.append([c, n]))
		round.hit_brick(Vector2i(20, 4), Round.Cause.BALL, Vector2.RIGHT)
		var order := [Vector2i(20, 4), Vector2i(17, 4), Vector2i(18, 4), Vector2i(19, 4), Vector2i(20, 3), Vector2i(20, 5), Vector2i(21, 4), Vector2i(22, 4), Vector2i(23, 4), Vector2i(24, 4)]
		var coins := [1, 1, 1, 1, 44, 0, 2, 2, 29, 3] if rank else [1, 1, 1, 1, 20, 0, 1, 1, 1, 1]
		var want := []
		for i in order.size():
			want.append([order[i], coins[i]])
		t.check(paid == want, "combo rank %d: a blast's ten breaks pay %s, in blast order (overview.md 'Coins'): %s" % [rank, coins, paid])
		var total := 84 if rank else 28
		t.check(round.coins == total and Coins.total(round.tally, round.stats) == total and round.tally.placed_broken == 1 and round.tally.broken == {&"explosive": 1, &"": 7, &"gold": 1},
				"combo rank %d: the chain pays %d and the tally holds 7 standard, 1 explosive, 1 gold and 1 placed brick: %d %s" % [rank, total, round.coins, round.tally.broken])
		if rank:
			t.check(round.combo.count == 10 and round.combo.multiplier == 3 and round.tally.best_combo == 10 and is_equal_approx(round.combo.window, 1.6 * 0.81),
					"the chain leaves a combo of 10 at x3 with a window of 1.296 s: %d x%d %s" % [round.combo.count, round.combo.multiplier, round.combo.window])
		t.check(round.balls.size() == 1, "a Splitter a blast breaks adds no ball (placeables.md)")


## Shockwaves in a chain (Round.blast): each blast throws the balls inside it and multiplies their boost; the
## first blast throws last, so its direction is the one a ball leaves with.
func _r2_shockwave_chain() -> void:
	var board := _board({FAR: SOLID, Vector2i(30, 3): 1, Vector2i(33, 3): 1})
	board.bricks[Vector2i(30, 3)].kind = &"explosive"
	board.bricks[Vector2i(33, 3)].kind = &"explosive"
	var round := Round.new(board, null, _sealed(board, {&"shockwave": 1.0}), 1)
	var only_a := round.balls[0]
	only_a.put(Vector2(430, 200), Vector2(0.6, 0.8))
	var both := round.add_ball(Vector2(520, 300), Vector2(0.6, -0.8))
	var only_b := round.add_ball(Vector2(590, 140), Vector2(-0.6, -0.8))
	var outside := round.add_ball(Vector2(700, 200), Vector2(0.6, 0.8))
	round.hit_brick(Vector2i(30, 3), Round.Cause.BALL, Vector2.RIGHT)
	t.check(only_a.boost == 2.0 and only_a.dir.is_equal_approx(Vector2(-58, -24).normalized()), "a ball in the first blast only is thrown from its centre once: %s x%s" % [only_a.dir, only_a.boost])
	t.check(both.boost == 3.0 and both.dir.is_equal_approx(Vector2(32, 76).normalized()), "a ball in both blasts is boosted twice, to the cap, and leaves along the first blast's throw: %s x%s" % [both.dir, both.boost])
	t.check(only_b.boost == 2.0 and only_b.dir.is_equal_approx(Vector2(54, -84).normalized()), "a ball in the second blast only is thrown from its centre: %s x%s" % [only_b.dir, only_b.boost])
	t.check(outside.boost == 1.0 and outside.dir == Vector2(0.6, 0.8), "a ball outside both blasts is left alone")


## A Zap on an explosive brick whose row holds another explosive: two blasts and one Zap, and each brick takes
## one hit from each of them that reaches it (upgrades.md, placeables.md).
func _r2_zap_blast() -> void:
	var board := _board({FAR: SOLID, Vector2i(20, 4): 1, Vector2i(10, 4): 5, Vector2i(22, 4): 5, Vector2i(23, 3): 5, Vector2i(30, 4): 1, Vector2i(33, 4): 5, Vector2i(40, 4): 5, Vector2i(26, 5): 5})
	board.bricks[Vector2i(20, 4)].kind = &"explosive"
	board.bricks[Vector2i(30, 4)].kind = &"explosive"
	var spy := Spy.new(board, _layout([_item(&"zap", Vector2i(20, 4))]), _stats({&"zap_count": 1.0}), 1)
	var booms := []
	spy.exploded.connect(func(p: Vector2, _r: float, cells: Array[Vector2i]) -> void: booms.append([p, Array(cells)]))
	_repro = "a Zap on an explosive brick (_r2_zap_blast)"
	spy.hit_brick(Vector2i(20, 4), Round.Cause.BALL, Vector2.RIGHT)
	_check_tree(spy)
	var hp := {}
	for c: Vector2i in [Vector2i(10, 4), Vector2i(22, 4), Vector2i(23, 3), Vector2i(26, 5), Vector2i(33, 4), Vector2i(40, 4)]:
		hp[c] = spy.board.brick(c).hp if spy.board.brick(c) else 0
	t.check(hp == {Vector2i(10, 4): 4, Vector2i(22, 4): 3, Vector2i(23, 3): 4, Vector2i(26, 5): 4, Vector2i(33, 4): 3, Vector2i(40, 4): 4}, "a Zap on an explosive brick: one hit from each blast and from the Zap: %s" % [hp])
	t.check(str(booms) == str([[Vector2(328, 288), [Vector2i(22, 4), Vector2i(23, 3)]], [Vector2(488, 288), [Vector2i(26, 5), Vector2i(33, 4)]]]), "the two blasts go off in order with the bricks they are about to hit: %s" % [booms])


## Special bricks the level painted itself are kept, and rank N still replaces N of the standard ones
## (levels.md: "Every brick is a standard brick unless the level says otherwise"; upgrades.md).
func _r2_painted() -> void:
	var bricks := {}
	for y in 6:
		bricks[Vector2i(40, y)] = 2
		bricks[Vector2i(44, y)] = 2
	var board := _board(bricks)
	for y in 3:
		board.bricks[Vector2i(44, y)].kind = &"gold"
		board.bricks[Vector2i(44, y)].hp = 1
	var wrong := []
	for ranks: Array in [[1, 2, 0], [0, 0, 3], [20, 1, 0]]:
		for sd in 10:
			var round := Round.new(board, null, _stats({&"explosive_count": ranks[0], &"gold_count": ranks[1], &"hourglass_count": ranks[2]}), sd)
			var got := {&"": 0, &"explosive": 0, &"gold": 0, &"hourglass": 0}
			for c: Vector2i in round.board.bricks:
				got[round.board.brick(c).kind] += 1
			var left := 9
			var want := {&"": 0, &"explosive": mini(ranks[0], left), &"gold": 3, &"hourglass": 0}
			left -= want[&"explosive"]
			want[&"gold"] += mini(ranks[1], left)
			left -= mini(ranks[1], left)
			want[&"hourglass"] = mini(ranks[2], left)
			left -= want[&"hourglass"]
			want[&""] = left
			var kept := range(3).all(func(y: int) -> bool: return round.board.brick(Vector2i(44, y)).kind == &"gold")
			if got != want or not kept:
				wrong.append("ranks %s seed %d: %s" % [ranks, sd, got])
	t.check(wrong.is_empty(), "bricks the level made special are kept, and rank N replaces N of the standard ones: %s" % [wrong.slice(0, 3)])


## Layout.fits keeps items off the launch path on every level size: the ball at rest and its way straight left to
## the paddle (Round.launch_path). An item may touch the right side of the ball ("Overlap means sharing area:
## touching does not count") but must stay Layout.CLEAR from the path above and below, where a touch that is a
## hair too deep would take the launch's first bounce.
func _r2_fits_rest() -> void:
	var wrong := []
	for rows: int in [14, 16, 18, 20]:
		var board := _board({}, rows)
		var stats := _stats({&"wall_segment_count": 1, &"splitter_count": 1})
		var rest := Round.ball_start(board, stats)
		var empty := Layout.new()
		var right := rest.x + 6.0 + 5.0  # an upright Wall Segment's centre with its left face on the ball's right edge
		for c: Array in [[right, true], [right - 0.1, false]]:
			if empty.fits(_item(&"wall_segment", Vector2(c[0], rest.y)), board, stats) != c[1]:
				wrong.append("%d rows: Wall Segment at x %.2f" % [rows, c[0]])
		var below := rest.y + 6.0 + 5.0  # a flat Wall Segment's centre with its top face on the ball's bottom edge
		for c: Array in [[below + 0.1, true], [below, false]]:
			if empty.fits(_item(&"wall_segment", Vector2(maxf(rest.x, 57.0), c[0]), 90.0), board, stats) != c[1]:
				wrong.append("%d rows: flat Wall Segment at y %.2f" % [rows, c[0]])
		var face := Round.paddle_face(board, stats)
		var ball := Rect2(face, rest.y - 6.0, rest.x + 6.0 - face, 12.0)
		for x in 4:
			for y in range(rows / 4 - 2, rows / 4 + 2):
				var cell := Vector2i(x, y)
				var r := board.cell_rect(cell).intersection(ball)
				var want := not (r.size.x > 0.0 and r.size.y > 0.0)
				if empty.fits(_item(&"splitter", cell), board, stats) != want:
					wrong.append("%d rows: Splitter at %s" % [rows, cell])
	t.check(wrong.is_empty(), "on 14, 16, 18 and 20 rows an item may touch the right side of the ball at rest, but not the launch path from above or below, nor overlap it (Layout.fits): wrong on %s" % [wrong])


## Layout SAVED FORM: "a layout that has been through the save file gives the same to_data() as it did before".
## Free items are put where the mouse puts them, in units, so their numbers are not round.
func _r2_save_trip() -> void:
	var zoom := 16.0 / 18.0
	var layout := _layout([_item(&"bumper", Vector2(437.0, 211.0) / zoom), _item(&"wall_segment", Vector2(300.1, 99.7) / zoom, 15.0 * 7.0),
			_item(&"booster", Vector2(0.1 + 0.2, 0.7) * 1000.0 / 3.0), _item(&"splitter", Vector2i(30, 3)), _item(&"zap", Vector2i(30, 3))])
	var before := layout.to_data()
	var old := Progress.path
	Progress.use(old.get_base_dir().path_join("fuzz_logic_save.json"))
	Progress.set_layout(1, layout)
	Progress.use(Progress.path)
	var after := Progress.layout(1).to_data()
	Progress.use(old)
	var drift := []
	for i in mini(before.size(), after.size()):
		for key: String in ["x", "y", "rot"]:
			if before[i].has(key) and before[i][key] != after[i].get(key):
				drift.append("%s.%s %s -> %s" % [before[i].kind, key, var_to_str(before[i][key]), var_to_str(after[i].get(key))])
	t.check(after == before, "a layout that has been through the save file gives the same to_data() as before (Layout SAVED FORM): %s" % [drift if drift else after])


# --- round 3 ---------------------------------------------------------------------------------------------------

# The combo window, at a tick rate where it is a whole number of steps: 1.6 s at 60/s is 96 steps, so the combo
# is gone after the 96th step, not the 97th. Combo.tick counts time_left down by 1/60 and tests `> 0.0` with no
# slop, so float error leaves a hair over 0 and the combo lives one step longer. The round's timer had the same
# off-by-one-step and is fixed with Round.TIME_SLOP (round.gd ONE STEP 4); the combo window is not.
func _r3_combo_window() -> void:
	var board := _board({FAR: SOLID, Vector2i(30, 3): 1})
	for c: Array in [[1.0, 60, 96], [1.0, 120, 192], [2.0, 120, 252]]:
		var stats := _sealed(board, {&"combo_rank": c[0]})
		stats.ball_speed = 1.0  # the ball stays out of this
		var round := Round.new(board, null, stats, 1)
		round.hit_brick(Vector2i(30, 3), Round.Cause.BALL, Vector2.RIGHT)
		var window := round.combo.window
		var steps := 0
		while round.combo.count > 0 and steps < 10000:
			round.step(1.0 / c[1], round.paddle.y)
			steps += 1
		t.check(steps == c[2], "at Combo rank %d and %d steps a second, a %.1f s combo window resets after %d steps, not %d (combo.gd: time_left is the seconds left to break the next brick; round.gd ONE STEP 3)" % [c[0], c[1], window, c[2], steps])
