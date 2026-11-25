extends RefCounted
## Round 1 attack on the rules (src/sim/, src/kinds/): everything that counts, every charge and what it sets off.
## The oracle is the docs (docs/design/*.md) and the contract headers, never the code. Hand-built boards and the
## shipped levels.
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
	&"coins_per_brick": 1.0, &"rotate_step": 15.0, &"launch_sway": 2.0,
	&"multiball_gap": 0.15, &"drop_speed": 250.0, &"drop_size": 16.0,
	&"explosion_damage": 1.0, &"zap_range": 8.0, &"zap_damage": 1.0, &"splitter_respawn": 0.0,
}
const PLACEABLES: Array[StringName] = [&"bumper", &"booster", &"wall_segment", &"splitter"]
## Kinds.bricks() order, which is the order they are rolled in, and the HP each has (upgrades.md: "A special brick has
## 1 HP, a tough brick 3").
const SPECIALS: Array[StringName] = [&"power", &"gold", &"hourglass", &"tough"]
const SPECIAL_HP := {&"power": 1, &"gold": 1, &"hourglass": 1, &"tough": 3}

var t: Node
## Random failures: rule -> the first repro that broke it.
var _broken := {}
var _repro := ""
## How often the random rounds reached each thing they check, so they cannot go quiet unnoticed.
var _seen := {}


## A Round that records every hit_brick, blast and zap call as a tree, so each blast and each Zap can be checked
## against the exact hits it made, and each against the charged hit that set it off. It changes nothing: every
## call goes straight to Round's own.
class Spy:
	extends Round
	var frames: Array[Dictionary] = []  # the calls running now, outermost first
	var roots: Array[Dictionary] = []  # calls made from outside any other call, in the order they were made
	var boosts := {}  # ball id -> its boost when last seen, kept by blasts and by the case's ball_bounced

	func _init(b: Board, l: Layout, s: Balance, sd: int) -> void:
		exploded.connect(_told)  # methods, not lambdas: a lambda here holds the Spy, which then never frees itself
		zapped.connect(_told_zap)
		super(b, l, s, sd)

	func _told(pos: Vector2, reach: float, cells: Array[Vector2i]) -> void:
		if not frames.is_empty() and frames.back().type == "blast" and not frames.back().has("told"):
			frames.back().told = [pos, reach, cells.duplicate()]

	func _told_zap(cell: Vector2i, cells: Array[Vector2i]) -> void:
		if not frames.is_empty() and frames.back().type == "zap" and not frames.back().has("told"):
			frames.back().told = [cell, cells.duplicate()]

	## Every ball's charge now, so a fire can be checked against the charge it spent.
	func _charges() -> Dictionary:
		var out := {}
		for b in balls:
			out[b] = b.charge
		return out

	func _push(rec: Dictionary) -> void:
		if frames.is_empty():
			roots.append(rec)
		else:
			frames.back().children.append(rec)
		frames.append(rec)

	func hit_brick(cell: Vector2i, cause: Round.Cause, dir: Vector2, ball: Ball = null) -> void:
		var b := board.brick(cell)
		var rec := {"type": "hit", "cell": cell, "cause": cause, "dir": dir, "ball": ball, "pre": b.copy() if b else null, "children": [],
				"charge": ball.charge if ball else &""}
		_push(rec)
		super(cell, cause, dir, ball)
		frames.pop_back()
		if not frames.is_empty() and frames.back().type == "blast":
			frames.back().before = _balls()  # what the blast's Shockwave starts from

	func _balls() -> Array:
		return balls.map(func(b: Ball) -> Array: return [b, b.pos, b.dir, b.boost, b == waiting])

	func blast(cell: Vector2i, reach: float) -> void:
		var area := board.cell_rect(cell).grow(reach)
		var want: Array[Vector2i] = []
		for c: Vector2i in board.bricks:
			var r := board.cell_rect(c).intersection(area)
			if r.size.x > 0.0 and r.size.y > 0.0:
				want.append(c)
		want.sort()  # by column, then by row
		var rec := {"type": "blast", "cell": cell, "reach": reach, "area": area, "want": want, "before": _balls(), "children": [], "charges": _charges()}
		_push(rec)
		super(cell, reach)
		frames.pop_back()
		rec.after = _balls()
		for b in balls:
			boosts[b.id] = b.boost

	func zap(cell: Vector2i) -> void:
		# upgrades.md: "Every other brick in that brick row within 8 columns of the cell, on both sides", 8 being
		# zap_range; listed from the paddle side (Round.zapped).
		var want: Array[Vector2i] = []
		for x in range(cell.x - int(stats.zap_range), cell.x + int(stats.zap_range) + 1):
			if x != cell.x and board.brick(Vector2i(x, cell.y)):
				want.append(Vector2i(x, cell.y))
		var rec := {"type": "zap", "cell": cell, "want": want, "children": [], "charges": _charges()}
		_push(rec)
		super(cell)
		frames.pop_back()


func run(p_t: Node) -> void:
	t = p_t
	_blast_reach()
	_no_chains()
	_shockwave()
	_zap()
	_charged()
	_drops()
	_specials()
	_fits()
	_combo()
	_ends()
	# Round 2.
	_r2_timer()
	_r2_end_order()
	_r2_chain_pay()
	_r2_shockwave_charge()
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
	var want := ["blast", "zap", "split", "hourglass", "booster", "shockwave", "CLEARED", "BALL_LOST", "TIME", "tick", "dropped", "caught", "charge", "plain",
			"kept", "volley", "power by BALL", "power by BLAST", "power by ZAP", "kept alive"]
	var reached := want.filter(func(k: String) -> bool: return _seen.get(k, 0) > 0)
	t.check(reached.size() == want.size(), "the random rounds reach blasts, Zaps, splits, hourglasses, Boosters, Shockwaves, drops, charges, volleys, a lost ball that a charge, a drop or the volley keeps going, and all three ends: missing %s" % [want.filter(func(k: String) -> bool: return not reached.has(k))])


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
		for size: float in [1.0, 2.0, 3.0]:
			var reach := size * 64.0
			# docs/design/upgrades.md: "1 square (4 columns, or 1 brick height) out from the cell's edges in every
			# direction, and each rank of Blast Size adds one more square, so it covers 26 brick cells around the
			# cell, then 84, then 174. The brick that was hit is in it too, if it still stands."
			var cols_out := int(reach / 16.0)
			var rows_out := ceili(reach / 64.0)
			var around: int = {1.0: 26, 2.0: 84, 3.0: 174}[size]
			var wrong := 0
			var counted := 0
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
					if want.size() == (cols_out * 2 + 1) * (rows_out * 2 + 1):  # not clipped by an edge
						counted += 1
						if hits.size() != around + 1:
							wrong += 1
			t.check(wrong == 0 and counted > 0, "on %d rows at Blast Size %.0f every blast hits %d columns and %d brick rows to each side (%d cells around its own), clipped at the board's edges, each brick once, its own brick too (%d of %d cells wrong)" % [rows, size, cols_out, rows_out, around, wrong, cells_seen])


# --- no chains: what a blast or a Zap breaks sets nothing off ----------------------------------------------------

## upgrades.md: "Nothing chains: a brick a blast breaks sets off no blast of its own." A blast and a Zap over every
## kind of brick, with a charged ball inside the blast: each goes off once and hits each brick it reaches once, a
## Power Brick it breaks only drops, and the charged ball keeps its charge.
func _no_chains() -> void:
	var bricks := {FAR: SOLID}
	for x in range(26, 35):
		for y in range(2, 6):
			bricks[Vector2i(x, y)] = 1
	var board := _board(bricks)
	var kinds: Array[StringName] = [&"power", &"gold", &"hourglass", &""]
	for c: Vector2i in bricks:
		board.bricks[c].kind = kinds[(c.x + c.y) % kinds.size()]  # every kind in every row and column; FAR stays plain
	for fire: StringName in [&"blast", &"zap"]:
		var spy := Spy.new(board, null, _stats({&"blast_size": 2.0, &"zap_count": 1, &"blast_count": 1}), 1)
		var charged := spy.balls[0]
		charged.put(Vector2(580, 350), Vector2(0.6, 0.8))  # inside the blast, on no brick
		charged.charge = &"blast"
		var told := [0, 0, 0]
		spy.exploded.connect(func(_p: Vector2, _r: float, _c: Array[Vector2i]) -> void: told[0] += 1)
		spy.zapped.connect(func(_c: Vector2i, _cs: Array[Vector2i]) -> void: told[1] += 1)
		spy.dropped.connect(func(_d: Drop) -> void: told[2] += 1)
		_repro = "a %s over every kind of brick (_no_chains)" % fire
		spy.hit_brick(Vector2i(30, 3), Round.Cause.BALL, Vector2.RIGHT)
		(Kinds.of(fire) as AbilityKind).fire(spy, Vector2i(30, 3), Vector2.RIGHT, null)
		_check_tree(spy)
		var powers: int = spy.tally.broken.get(&"power", 0)
		t.check(told == [1 if fire == &"blast" else 0, 1 if fire == &"zap" else 0, powers] and powers > 1 and charged.charge == &"blast",
				"a %s over Power, gold and hourglass bricks goes off once and sets nothing else off: each Power Brick it breaks drops once, and a charged ball in it keeps its charge (%s)" % [fire, told])


## Checks a Spy's call tree against the docs: what each blast and each Zap hits, and that nothing a hit sets off
## hits a brick again (upgrades.md: "Nothing chains").
func _check_tree(spy: Spy) -> void:
	var stack := spy.roots.duplicate()
	while not stack.is_empty():
		var rec: Dictionary = stack.pop_back()
		stack.append_array(rec.children)
		match rec.type:
			"blast":
				_check_blast(spy, rec)
			"zap":
				_check_zap(spy, rec)
			_:
				_fail(rec.children.is_empty(), "a hit sets off nothing that hits a brick: no blast, no Zap, no chain (upgrades.md: 'Nothing chains')")


func _check_blast(spy: Spy, rec: Dictionary) -> void:
	_seen.blast = _seen.get("blast", 0) + 1
	var hit_cells: Array[Vector2i] = []
	var ok := true
	for child: Dictionary in rec.children:
		ok = ok and child.type == "hit" and child.cause == Round.Cause.BLAST
		hit_cells.append(child.cell)
	var want: Array[Vector2i] = []
	for c: Vector2i in rec.want:
		for i in int(spy.stats.explosion_damage):
			want.append(c)
	_fail(ok and hit_cells == want, "a blast hits every brick whose cell overlaps the blast's rectangle, the hit brick too if it stands, explosion_damage times each, by column then row, and nothing else (upgrades.md, Round.blast)")
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
		if was[4]:
			_fail(now[1] == was[1] and now[2] == was[2] and now[3] == was[3], "a ball waiting on the paddle is not thrown (upgrades.md, Shockwave)")
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


func _check_zap(spy: Spy, rec: Dictionary) -> void:
	_seen.zap = _seen.get("zap", 0) + 1
	var hit_cells: Array[Vector2i] = []
	var ok := true
	for child: Dictionary in rec.children:
		ok = ok and child.type == "hit" and child.cause == Round.Cause.ZAP
		hit_cells.append(child.cell)
	var want: Array[Vector2i] = []
	for c: Vector2i in rec.want:
		for i in int(spy.stats.zap_damage):
			want.append(c)
	_fail(ok and hit_cells == want, "a Zap hits every other brick in its brick row within zap_range columns on both sides, zap_damage times each, from the paddle side, and nothing else (upgrades.md)",
			"zap at %s: %s, want %s" % [rec.cell, hit_cells, want])
	var told: Array = rec.get("told", [])
	_fail(told.size() == 2 and told[0] == rec.cell and told[1] == rec.want, "zapped carries the hit brick's cell and every brick about to be hit (Round.zapped)")


## Checks every charge against the docs (upgrades.md, "Charges and abilities"): a charged ball's first hit on a level
## brick lands, then the charge is spent and its ability goes off at that brick's cell, once; a hit on a placed brick
## does not spend it; a blast or a Zap goes off in no other way, and a spent ball plays on as an ordinary one.
func _check_fires(spy: Spy) -> void:
	var roots := spy.roots
	var carries := {}  # ball -> the charge its next hit must carry
	for i in roots.size():
		var rec: Dictionary = roots[i]
		if rec.type != "hit":
			var prev: Dictionary = roots[i - 1] if i > 0 else {}
			_fail(not prev.is_empty() and prev.type == "hit" and prev.cause == Round.Cause.BALL and String(prev.charge) == rec.type and prev.pre != null
					and not prev.pre.placed and prev.cell == rec.cell, "a blast or a Zap goes off only at the cell of a level brick a ball charged with it has just hit")
			continue
		if rec.cause != Round.Cause.BALL or rec.pre == null:
			continue
		if carries.has(rec.ball):
			_fail(rec.charge == carries[rec.ball], "a hit on a placed brick keeps a ball's charge, a hit on a level brick spends it, and a spent ball plays on as an ordinary one (upgrades.md)",
					"%s on %s, carrying %s, should carry %s" % [rec.ball, rec.cell, rec.charge, carries[rec.ball]])
		var fires: bool = rec.charge != &"" and not rec.pre.placed
		carries[rec.ball] = &"" if fires else rec.charge
		if rec.charge != &"":
			_seen.charge = _seen.get("charge", 0) + 1
		if rec.charge != &"" and rec.pre.placed:
			_seen.kept = _seen.get("kept", 0) + 1
		if not fires:
			continue
		var next: Dictionary = roots[i + 1] if i + 1 < roots.size() else {}
		_fail(not next.is_empty() and next.type == String(rec.charge) and next.cell == rec.cell,
				"a charged ball's first hit on a level brick sets off its ability at that brick's cell, after the hit lands (upgrades.md)", "%s at %s" % [rec.charge, rec.cell])
		if not next.is_empty() and next.type != "hit":
			_fail(next.charges.get(rec.ball, &"?") == &"", "the charge is spent as its ability goes off (Round ABILITIES)")


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

	# A ball waiting on the paddle is not thrown (upgrades.md), even inside the blast.
	board = _board({FAR: SOLID, Vector2i(0, 3): 1})
	round = Round.new(board, null, _sealed(board, {&"shockwave": 1}), 1)
	round.hold()
	round.move_paddle(1.0, 224.0)
	ball = round.waiting
	var was := [ball.pos, ball.dir, ball.boost]
	var inside := board.cell_rect(Vector2i(0, 3)).grow(64.0).has_point(ball.pos)
	round.blast(Vector2i(0, 3), 64.0)
	t.check(inside and [ball.pos, ball.dir, ball.boost] == was, "a ball waiting on the paddle inside a blast is neither thrown nor boosted (upgrades.md, Shockwave)")


# --- the Zap ---------------------------------------------------------------------------------------------------

## upgrades.md: "Every other brick in that brick row within 8 columns of the cell, on both sides, takes 1 hit. Each
## rank of Zap Range reaches 2 columns further each way, and each rank of Zap Damage adds 1 hit to every brick."
func _zap() -> void:
	for ranks: Array in [[0, 0], [1, 0], [2, 1], [0, 2]]:
		var reach: int = 8 + 2 * ranks[0]
		var hits: int = 1 + ranks[1]
		for at: int in [2, 20, 61]:
			var bricks := {FAR: SOLID, Vector2i(at, 3): 5, Vector2i(at, 4): 5, Vector2i(at, 5): 5}
			for x in 64:
				if x % 3 != 1:
					bricks[Vector2i(x, 4)] = 5
			var spy := Spy.new(_board(bricks), null, _stats({&"zap_range": float(reach), &"zap_damage": float(hits)}), 1)
			_repro = "a Zap at column %d, range %d, damage %d (_zap)" % [at, reach, hits]
			spy.hit_brick(Vector2i(at, 4), Round.Cause.BALL, Vector2.RIGHT)
			(Kinds.of(&"zap") as AbilityKind).fire(spy, Vector2i(at, 4), Vector2.RIGHT, null)
			_check_tree(spy)
			var wrong := []
			for c: Vector2i in bricks:
				var want: int = bricks[c] - (1 if c == Vector2i(at, 4) else 0) - (hits if c.y == 4 and c.x != at and absi(c.x - at) <= reach else 0)
				if spy.board.brick(c).hp != want:
					wrong.append(c)
			t.check(wrong.is_empty(), "a Zap at column %d with a reach of %d columns and %d hits: every other brick in its row within reach takes %d hits, the hit brick and the rows above and below none: wrong at %s" % [at, reach, hits, hits, wrong])


# --- charges, fired as play fires them ---------------------------------------------------------------------------

## Fires a charge the way play does: caught (add_charge), onto the paddle on the next step, launched; then puts
## it just left of `cell`, on its way into the brick's left face. Returns the ball.
func _fire_at(round: Round, cell: Vector2i) -> Ball:
	round.add_charge()
	round.step(TICK, round.paddle.y)
	var ball := round.waiting
	round.launch()
	_aim(ball, round.board, cell)
	return ball


func _aim(ball: Ball, board: Board, cell: Vector2i) -> void:
	var r := board.cell_rect(cell)
	ball.put(Vector2(r.position.x - 20.0, r.get_center().y), Vector2(0.8, 0.6))


## A round whose first ball is out of the way: no brick, no paddle, nothing lost, for a long while.
func _quiet(board: Board, layout: Layout, stats := {}) -> Spy:
	var spy := Spy.new(board, layout, _sealed(board, stats), 1)
	spy.balls[0].put(Vector2(900, 450), Vector2(0.6, 0.8))
	return spy


## upgrades.md, "Charges and abilities" and "What the abilities do": a charge fires as a ball carrying the selected
## ability; its first hit on a level brick lands, then the ability goes off once at that brick's cell; a hit on a
## placed brick (a Splitter) does not spend it; with no ability unlocked a charge fires a plain ball.
func _charged() -> void:
	# A Zap charge on a 2 HP brick: the hit lands, then the Zap; a second hit by the same ball sets off nothing.
	var bricks := {FAR: SOLID, Vector2i(30, 3): 2, Vector2i(25, 3): 1, Vector2i(38, 3): 1, Vector2i(39, 3): 1}
	var spy := _quiet(_board(bricks), null, {&"zap_count": 1})
	var log := []
	spy.brick_hit.connect(func(c: Vector2i, _hp: int, cause: Round.Cause) -> void: log.append(["hit", c, cause]))
	spy.zapped.connect(func(c: Vector2i, _cs: Array[Vector2i]) -> void: log.append(["zapped", c]))
	spy.exploded.connect(func(p: Vector2, _r: float, _cs: Array[Vector2i]) -> void: log.append(["exploded", p]))
	var ball := _fire_at(spy, Vector2i(30, 3))
	t.check(ball.charge == &"zap" and spy.ability == &"zap", "a charge leaves the paddle carrying the selected ability")
	_run(spy, 0.05)
	var b := spy.board
	t.check(log.slice(0, 2) == [["hit", Vector2i(30, 3), Round.Cause.BALL], ["zapped", Vector2i(30, 3)]] and ball.charge == &""
			and b.brick(Vector2i(30, 3)).hp == 1 and b.brick(Vector2i(25, 3)) == null and b.brick(Vector2i(38, 3)) == null and b.brick(Vector2i(39, 3)) != null,
			"a Zap charge's first hit on a level brick lands, then the Zap goes off at it, 8 columns each way, and the charge is spent: %s" % [log])
	_aim(ball, b, Vector2i(30, 3))
	_run(spy, 0.05)
	t.check(b.brick(Vector2i(30, 3)) == null and log.count(["zapped", Vector2i(30, 3)]) == 1 and b.brick(Vector2i(39, 3)) != null, "a spent ball's next hit sets off nothing")
	_repro = "a Zap charge (_charged)"
	_check_tree(spy)
	_check_fires(spy)

	# A Splitter does not spend a charge; the level brick after it does. The Zap then breaks a Splitter in its row,
	# which adds no ball (upgrades.md: "A Splitter broken by a blast or a Zap just breaks").
	bricks = {FAR: SOLID, Vector2i(30, 5): 1, Vector2i(26, 5): 1}
	var layout := _layout([_item(&"splitter", Vector2i(30, 3)), _item(&"splitter", Vector2i(34, 5))])
	spy = _quiet(_board(bricks), layout, {&"zap_count": 1, &"splitter_count": 2})
	var zaps := [0]
	spy.zapped.connect(func(_c: Vector2i, _cs: Array[Vector2i]) -> void: zaps[0] += 1)
	ball = _fire_at(spy, Vector2i(30, 3))
	_run(spy, 0.05)
	var split := spy.balls.size()
	t.check(spy.board.brick(Vector2i(30, 3)) == null and split == 3 and ball.charge == &"zap" and zaps[0] == 0,
			"a charged ball that breaks a Splitter splits and keeps its charge (upgrades.md)")
	_aim(ball, spy.board, Vector2i(30, 5))
	_run(spy, 0.05)
	t.check(zaps[0] == 1 and ball.charge == &"" and spy.board.brick(Vector2i(26, 5)) == null and spy.board.brick(Vector2i(34, 5)) == null and spy.balls.size() == split,
			"its next hit, on a level brick, sets the Zap off, and a Splitter the Zap breaks adds no ball")
	_repro = "a Zap charge past a Splitter (_charged)"
	_check_tree(spy)
	_check_fires(spy)

	# A Blast charge: the hit brick is in the blast if it still stands.
	for hp: int in [1, 2]:
		bricks = {FAR: SOLID, Vector2i(30, 3): hp, Vector2i(28, 3): 1, Vector2i(30, 4): 1, Vector2i(35, 3): 1}
		spy = _quiet(_board(bricks), null, {&"blast_count": 1})
		var cells := []
		spy.exploded.connect(func(_p: Vector2, _r: float, cs: Array[Vector2i]) -> void: cells.append(Array(cs)))
		ball = _fire_at(spy, Vector2i(30, 3))
		_run(spy, 0.05)
		var want := [Vector2i(28, 3), Vector2i(30, 3), Vector2i(30, 4)] if hp == 2 else [Vector2i(28, 3), Vector2i(30, 4)]
		t.check(cells == [want] and ball.charge == &"" and spy.board.brick(Vector2i(30, 3)) == null and spy.board.brick(Vector2i(35, 3)) != null,
				"a Blast charge on a %d HP brick: the ball's hit lands, then the blast, %s: %s" % [hp, "the brick still in it" if hp == 2 else "the broken brick no longer in it", cells])
		_repro = "a Blast charge on a %d HP brick (_charged)" % hp
		_check_tree(spy)
		_check_fires(spy)

	# The selection: Zap first, cycled through the unlocked ones; with none unlocked a charge is a plain ball.
	var board := _board({FAR: SOLID, Vector2i(30, 3): 1, Vector2i(26, 3): 1})
	var picks := []
	for counts: Array in [[0, 0], [1, 0], [0, 1], [1, 1]]:
		var round := Round.new(board, null, _stats({&"zap_count": counts[0], &"blast_count": counts[1]}), 1)
		var seq := [round.ability]
		for steps: int in [1, 1, -1]:
			round.cycle(steps)
			seq.append(round.ability)
		picks.append(seq)
	t.check(picks == [[&"", &"", &"", &""], [&"zap", &"zap", &"zap", &"zap"], [&"blast", &"blast", &"blast", &"blast"], [&"zap", &"blast", &"zap", &"blast"]],
			"the selection is the first unlocked ability, Zap first, and cycling goes round the unlocked ones (upgrades.md): %s" % [picks])
	spy = _quiet(board, null)
	var fired := [0]
	spy.exploded.connect(func(_p: Vector2, _r: float, _cs: Array[Vector2i]) -> void: fired[0] += 1)
	spy.zapped.connect(func(_c: Vector2i, _cs: Array[Vector2i]) -> void: fired[0] += 1)
	ball = _fire_at(spy, Vector2i(30, 3))
	_run(spy, 0.05)
	t.check(ball.charge == &"" and spy.board.brick(Vector2i(30, 3)) == null and spy.board.brick(Vector2i(26, 3)) != null and fired[0] == 0,
			"with no ability unlocked a charge fires a plain ball (upgrades.md)")
	# The opening ball is no charge.
	var held := Round.new(board, null, _stats({&"zap_count": 1, &"blast_count": 1}), 1)
	held.hold()
	var first := held.waiting
	held.launch()
	t.check(first.charge == &"", "the round's first ball carries no ability")


# --- drops -----------------------------------------------------------------------------------------------------

## upgrades.md: "A Power Brick makes a drop when it breaks, however it broke (a ball, a blast or a Zap)", one each, at
## its cell; Overgrowth brings it back plain, "so a Power Brick drops only once".
func _drops() -> void:
	var powers: Array[Vector2i] = [Vector2i(31, 3), Vector2i(33, 3), Vector2i(40, 6), Vector2i(40, 3)]
	var board := _board({FAR: SOLID, Vector2i(30, 3): 2})
	for c in powers:
		board.bricks[c] = Brick.new(1, &"power")
	var stats := _sealed(board, {&"overgrowth": 1.0, &"overgrowth_delay": 0.5, &"ball_speed": 1.0})
	var round := Round.new(board, null, stats, 1)
	var made := []
	round.dropped.connect(func(d: Drop) -> void: made.append([d.id, d.pos]))
	round.hit_brick(Vector2i(31, 3), Round.Cause.BALL, Vector2.RIGHT)  # by a ball
	round.blast(Vector2i(30, 3), 64.0)  # (33, 3) by a blast; (30, 3) down to 1 HP
	round.zap(Vector2i(34, 6))  # (40, 6) by a Zap
	round.zap(Vector2i(36, 3))  # (30, 3), plain, then (40, 3)
	var want := []
	for i in powers.size():
		want.append([i, board.cell_rect(powers[i]).get_center()])
	t.check(made == want, "every Power Brick broken by a ball, a blast or a Zap makes one drop, at its cell's centre, in the order they broke: %s" % [made])
	_run(round, 1.0)
	var bricks := round.board
	var back := powers.all(func(c: Vector2i) -> bool: return bricks.brick(c) != null and bricks.brick(c).kind == &"" and bricks.brick(c).hp == 1)
	for c in powers:
		round.hit_brick(c, Round.Cause.BALL, Vector2.RIGHT)
	t.check(back and made.size() == powers.size(), "a Power Brick Overgrowth brings back is a plain 1 HP brick and drops nothing when it breaks again (upgrades.md)")


# --- special bricks --------------------------------------------------------------------------------------------

func _specials() -> void:
	var level := Levels.read(1)
	t.check(level != null and level.board.bricks.size() == 28, "level 1 reads as 28 bricks")
	if level == null:
		return
	var board := level.board
	var counts := {}
	for ranks: Array in [[1, 0, 0, 0], [3, 3, 2, 1], [0, 2, 1, 3], [10, 10, 10, 10], [20, 0, 1, 0], [0, 21, 0, 9]]:
		var ranked := {&"splitter_count": 2}
		for k in SPECIALS.size():
			ranked[StringName(String(SPECIALS[k]) + "_count")] = ranks[k]
		var stats := _stats(ranked)
		var layout := _layout([_item(&"splitter", Vector2i(34, 2)), _item(&"splitter", Vector2i(50, 5))])
		var seen := {}
		for sd in 40:
			var round := Round.new(board, layout if sd % 2 else null, stats, sd)
			counts = {}
			for k in SPECIALS:
				counts[k] = 0
			var bad := false
			for c: Vector2i in round.board.bricks:
				var b := round.board.brick(c)
				if b.placed:
					bad = bad or b.kind != &"splitter"
				elif b.kind != &"":
					counts[b.kind] += 1
					bad = bad or b.hp != SPECIAL_HP[b.kind] or board.brick(c) == null or board.brick(c).kind != &""
			var left := board.bricks.size()
			var want := {}
			for k in SPECIALS.size():
				want[SPECIALS[k]] = mini(ranks[k], left)
				left -= want[SPECIALS[k]]
			t.check(not bad and counts == want, "ranks %s replace exactly min(rank, standard bricks left) of each kind, in kind order, each with its kind's HP, never a placed brick (seed %d): got %s" % [ranks, sd, counts])
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
		if ranks.max() > 0 and ranks.reduce(func(a: int, b: int) -> int: return a + b) < board.bricks.size():
			t.check(seen.size() > 15,"different seeds give different special bricks (ranks %s: %d different rolls in 40 seeds)" % [ranks, seen.size()])


# --- Layout.fits ------------------------------------------------------------------------------------------------

func _fits() -> void:
	var board := _board({Vector2i(30, 3): 1, Vector2i(31, 3): 2, Vector2i(0, 0): 1, Vector2i(63, 7): 1})
	var stats := _stats({&"bumper_count": 3, &"booster_count": 2, &"wall_segment_count": 2, &"splitter_count": 2})
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
		[empty, _item(&"booster", rest + Vector2(13, 0)), false, "a Booster over the ball at rest"],
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
	]
	var wrong := []
	for c: Array in cases:
		if (c[0] as Layout).fits(c[1], board, stats) != c[2]:
			wrong.append(c[3])
	t.check(wrong.is_empty(), "Layout.fits refuses every illegal item and takes every legal one (Layout.fits, placeables.md): wrong on %s" % [wrong])
	# Loading a saved layout (placeables.md: "Any saved item that no longer fits is dropped"; Layout.fitted).
	var saved := _layout([_item(&"splitter", Vector2i(30, 3)), _item(&"splitter", Vector2i(10, 2)), _item(&"bumper", Vector2(300, 100)),
			_item(&"bumper", Vector2(400, 100)), _item(&"bumper", Vector2(500, 100)), _item(&"splitter", Vector2i(11, 2))])
	var kept := saved.fitted(board, _stats({&"bumper_count": 2, &"splitter_count": 1}))
	t.check(kept.to_data() == _layout([saved.items[1], saved.items[2], saved.items[3]]).to_data(),
			"loading keeps, in order, the first items of each kind that fit, up to its count, and drops one on a brick")
	# A count of 0 takes nothing.
	t.check(PLACEABLES.all(func(k: StringName) -> bool: return not empty.fits(_item(k, Vector2i(10, 2) if k == &"splitter" else Vector2(300, 100)), board, _stats())),
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
			t.check(events.is_empty() and round.coins == 30 and round.combo.count == 0, "at Combo rank 0 combos are off: no combo, every brick pays 1")
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
	b2.bricks[Vector2i(22, 3)].kind = &"hourglass"
	ways[Round.End.CLEARED] = Round.new(b2, _layout([_item(&"splitter", Vector2i(50, 3))]), _sealed(b2, {&"splitter_count": 1}), 1)
	ways[Round.End.CLEARED].hit_brick(Vector2i(20, 3), Round.Cause.BALL, Vector2.RIGHT)
	(Kinds.of(&"blast") as AbilityKind).fire(ways[Round.End.CLEARED], Vector2i(20, 3), Vector2.RIGHT, null)
	for why: Round.End in ways:
		var round: Round = ways[why]
		var log := []
		for sig: Signal in [round.brick_hit, round.brick_broken, round.ball_bounced, round.ball_added, round.ball_lost, round.exploded, round.zapped, round.dropped,
				round.caught, round.combo_changed, round.time_changed, round.ended]:
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
		PlaceableKind.Placement.BRICK:
			if rng.randf() < 0.5 and not board.bricks.is_empty():
				var c: Vector2i = board.bricks.keys()[rng.randi_range(0, board.bricks.size() - 1)]
				item.cell = c + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			else:
				item.cell = Vector2i(rng.randi_range(-1, board.cols), rng.randi_range(-1, board.rows / 2))
	return item


func _random_stats(rng: RandomNumberGenerator) -> Balance:
	var s := _stats({&"combo_rank": rng.randi_range(0, 3), &"blast_size": [1.0, 2.0, 3.0][rng.randi_range(0, 2)], &"shockwave": rng.randi_range(0, 1),
			&"power_count": rng.randi_range(0, 30), &"gold_count": rng.randi_range(0, 3), &"hourglass_count": rng.randi_range(0, 3), &"tough_count": rng.randi_range(0, 3),
			&"zap_count": rng.randi_range(0, 1), &"blast_count": rng.randi_range(0, 1), &"multiball": rng.randi_range(0, 2), &"multiball_gap": [0.05, 0.15, 0.4][rng.randi_range(0, 2)],
			&"zap_range": [8.0, 10.0, 12.0][rng.randi_range(0, 2)], &"zap_damage": rng.randi_range(1, 2), &"explosion_damage": rng.randi_range(1, 2)})
	for k in PLACEABLES:
		s.put(Balance.count_stat(k), rng.randi_range(0, 3))
	s.ball_speed = 560.0 * rng.randf_range(1.0, 1.75)
	s.paddle_speed = 360.0 * rng.randf_range(1.0, 2.0)
	s.paddle_size = 96.0 * rng.randf_range(1.0, 1.45)
	return s


## One step's input: [paddle target, add a charge, cycle the selection by, launch].
func _act(round: Round, act: Array, dt: float) -> void:
	if act[1]:
		round.add_charge()
	if act[2]:
		round.cycle(act[2])
	if act[3]:
		round.launch()
	round.step(dt, act[0])


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
	var hold := rng.randf() < 0.5  # as the level screen does; else the ball at rest of the rules tests
	var catcher := rng.randf() < 0.5  # a paddle that goes for drops
	_repro = "random round %d" % sd
	var inputs := _r2_inputs(board, layout, stats)
	var spy := Spy.new(board, layout, stats, sd)
	_fail(spy.layout.to_data() == layout.fitted(board, stats).to_data(), "a round is built from the fitted layout")
	if hold:
		spy.hold()
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
	var ids: Array = spy.abilities().map(func(k: AbilityKind) -> StringName: return k.id)
	_fail(ids == [&"zap", &"blast"].filter(func(id: StringName) -> bool: return stats.count(id) >= 1) and spy.ability == (ids[0] if ids else &""),
			"the unlocked abilities are those with a rank, Zap first, and the first is selected (upgrades.md)")
	var m := {"left": left, "base": 0, "run": 0, "done": 0, "was": 1, "broken": {}, "placed": 0, "coins": 0, "count": 0, "mult": 1, "best": 0, "last": "", "added": 0.0,
			"splits": 0, "balls": {0: true}, "next": 1, "ended": 0, "after": 0, "expect": "", "new": [], "cell": Vector2i.ZERO, "drops": 0, "charges": 0,
			"volley": 0, "from": Vector2.ZERO, "way": Vector2.ZERO, "launched": 0.0, "came": 0}
	var cap := stats.boost_cap
	var lane := spy.board.lane()

	spy.brick_hit.connect(func(c: Vector2i, hp_left: int, cause: Round.Cause) -> void:
		if m.ended:
			m.after += 1
		var rec: Dictionary = spy.frames.back()
		_fail(hp.has(c) and hp[c] - 1 == hp_left and hp_left > 0 and spy.board.brick(c).hp == hp_left, "a hit takes exactly 1 HP and brick_hit says what is left")
		_fail(rec.cell == c and rec.cause == cause, "brick_hit carries the cell and cause of the hit")
		_fail(rec.ball == null or rec.ball != spy.waiting, "a ball waiting on the paddle touches nothing (Round CHARGES)")
		hp[c] = hp_left
		_fail((m.last == "combo") == (stats.combo_rank >= 1.0 and not placed[c]),
				"with combos on, a hit that leaves a level brick standing comes just after combo_changed; a placed brick's or a block's grows nothing")
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
			_fail(n == m.count + 1 and mult == want, "a hit on a level brick or a break adds 1 to the combo; the multiplier is 1 + (count - 1) / 4 (balance.tres)")
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
		_fail(pre != null and brick.kind == pre.kind and brick.placed == pre.placed and brick.placed == placed.get(c, false), "brick_broken's brick has the kind and placed flag it had")
		_fail(rec.cell == c and rec.cause == cause, "brick_broken carries the cell and cause of the hit")
		_fail(rec.ball == null or rec.ball != spy.waiting, "a ball waiting on the paddle touches nothing (Round CHARGES)")
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
				_fail(parent.type == "blast" and dir.is_equal_approx(away.normalized() if away else Vector2.RIGHT), "a brick a blast breaks is thrown away from the blast's centre")
			Round.Cause.ZAP:
				var parent: Dictionary = spy.frames[-2]
				_fail(parent.type == "zap" and dir == (Vector2.LEFT if c.x < parent.cell.x else Vector2.RIGHT), "a brick a Zap breaks is thrown along the row away from the brick the charged ball hit")
		var kind := brick.kind
		if kind == &"power":
			_seen["power by " + Round.Cause.keys()[cause]] = 1
		m.expect = "dropped" if kind == &"power" else "time" if kind == &"hourglass" else "added" if kind == &"splitter" and cause == Round.Cause.BALL else ""
		m.cell = c
		m.last = "broken")
	spy.exploded.connect(func(_p: Vector2, _r: float, cells: Array[Vector2i]) -> void:
		if m.ended:
			m.after += 1
		_fail(cells.all(func(c: Vector2i) -> bool: return spy.board.brick(c) != null), "every brick in exploded's cells is still on the board")
		m.last = "exploded")
	spy.zapped.connect(func(_c: Vector2i, cells: Array[Vector2i]) -> void:
		if m.ended:
			m.after += 1
		_fail(cells.all(func(c: Vector2i) -> bool: return spy.board.brick(c) != null), "every brick in zapped's cells is still on the board")
		m.last = "zapped")
	spy.dropped.connect(func(d: Drop) -> void:
		if m.ended:
			m.after += 1
		_fail(m.last == "broken" and m.expect == "dropped", "a drop is made only when a Power Brick breaks, right after it (upgrades.md)")
		_fail(d.id == m.drops and spy.drops.back() == d and d.pos == spy.board.cell_rect(m.cell).get_center() and d.size == stats.drop_size,
				"dropped gives the next drop, already in `drops`, at the Power Brick's centre (Round.drop)")
		m.drops += 1
		m.expect = ""
		_seen.dropped = _seen.get("dropped", 0) + 1
		m.last = "dropped")
	spy.caught.connect(func(d: Drop) -> void:
		if m.ended:
			m.after += 1
		m.charges += 1
		_fail(not spy.drops.has(d) and spy.charges == m.charges and d.rect().intersects(spy.paddle.rect(spy.board.size().y)),
				"a drop the paddle touches is caught: out of `drops`, and the paddle has one more charge (upgrades.md)")
		_seen.caught = _seen.get("caught", 0) + 1
		m.last = "caught")
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
		if m.volley > 0 and ball.pos == m.from and ball.dir == m.way:
			# The opening volley (physics.md): the k-th ball multiball_gap * k s after the launch, from the launch point.
			m.volley -= 1
			m.came += 1
			var gone: float = spy.clock + dt - m.launched
			_fail(ball.boost == 1.0 and gone > m.came * stats.multiball_gap - 1e-5 and gone - dt < m.came * stats.multiball_gap + 1e-5,
					"Multiball: the opening volley's balls leave the launch point the launch's way, multiball_gap s apart (upgrades.md)", "ball %d of the volley at %.4f s" % [m.came, gone])
			_seen.volley = _seen.get("volley", 0) + 1
		else:
			_fail(m.last == "broken" and m.expect == "added", "a ball is added only when a ball breaks a Splitter (placeables.md) or by the opening volley")
			m.splits += 1
			m.expect = ""
			_seen.split = _seen.get("split", 0) + 1
		_fail(ball.id == m.next and spy.balls.has(ball) and ball.boost >= 1.0 and ball.boost <= cap, "ball_added gives the next ball, already in `balls`")
		m.balls[ball.id] = true
		m.next += 1
		spy.boosts[ball.id] = ball.boost
		m.new.append([ball, ball.pos])
		m.last = "added")
	spy.ball_lost.connect(func(ball: Ball) -> void:
		if m.ended:
			m.after += 1
		_fail(m.balls.has(ball.id) and not spy.balls.has(ball) and ball.pos.x <= -lane - ball.size * 0.5 + 0.01, "ball_lost gives a ball that is out of `balls`, wholly past the open side")
		m.balls.erase(ball.id)
		if spy.balls.all(func(b: Ball) -> bool: return b == spy.waiting) and (spy.waiting or spy.charges > 0 or not spy.drops.is_empty() or m.volley > 0):
			_seen["kept alive"] = _seen.get("kept alive", 0) + 1
		m.last = "lost")
	spy.ball_bounced.connect(func(ball: Ball, hit: Hit) -> void:
		if m.ended:
			m.after += 1
		_fail(hit.surface != Hit.Surface.BRICK and spy.balls.has(ball) and ball != spy.waiting, "ball_bounced is never for a brick, nor for a ball waiting on the paddle")
		var was: float = spy.boosts.get(ball.id, 1.0)
		var want := was
		if hit.surface == Hit.Surface.PADDLE:
			want = ball.kept
		elif hit.surface == Hit.Surface.ITEM and hit.item.kind.id == &"booster":
			want = minf(was + float(Kinds.of(&"booster").get("boost")), cap)
			_seen.booster = _seen.get("booster", 0) + 1
		_fail(is_equal_approx(ball.boost, want), "a Booster adds its file's boost, up to 3x; the paddle takes away all but a Booster's; nothing else changes it (physics.md)",
				"ball %d off %s: boost %s -> %s" % [ball.id, Hit.Surface.keys()[hit.surface], was, ball.boost])
		spy.boosts[ball.id] = ball.boost
		m.last = "bounced")
	spy.ended.connect(func(why: Round.End) -> void:
		m.ended += 1
		_seen[Round.End.keys()[why]] = _seen.get(Round.End.keys()[why], 0) + 1
		m.last = "ended")

	var log := []
	spy.brick_broken.connect(func(c: Vector2i, _b: Brick, cause: Round.Cause, _d: Vector2, _n: int) -> void: log.append([c, cause]))
	var acts := []
	var time := spy.time_left
	var steps := 0
	while not spy.over and steps < 120.0 / dt:  # long: hourglasses add time, and a good paddle loses no ball
		var target := spy.paddle.y if rng.randf() < 0.9 else rng.randf_range(-100, 700)
		var best := INF
		for ball in spy.balls:
			if ball != spy.waiting and ball.dir.x < 0.0 and ball.pos.x < best:
				best = ball.pos.x
				target = ball.pos.y + rng.randf_range(-40, 40)
		if catcher and not spy.drops.is_empty():
			target = spy.drops[0].pos.y
		var act := [target, rng.randf() < 0.002, [0, 0, 0, 0, 1, -1][rng.randi_range(0, 5)] if rng.randf() < 0.01 else 0, spy.waiting != null and rng.randf() < (0.1 if spy.held else 0.03)]
		acts.append(act)
		m.added = 0.0
		m.new = []
		var was_y := spy.paddle.y
		var was_held := spy.held
		var ability := spy.ability
		var fired := spy.waiting
		var from := fired.pos if fired else Vector2.ZERO
		var way := spy.launch_dir()
		var clock := spy.clock
		if act[1]:
			m.charges += 1
		_act(spy, act, dt)
		steps += 1
		if act[2]:
			_fail(spy.ability == (ids[posmod(ids.find(ability) + act[2], ids.size())] if ids else &""), "the wheel cycles the selection through the unlocked abilities (upgrades.md)")
		if act[3] and fired:
			_fail(fired.charge == (&"" if was_held else spy.ability) and fired != spy.waiting,
					"a charge leaves the paddle carrying the selected ability, the round's first ball none (upgrades.md)", "%s, ability %s" % [fired.charge, spy.ability])
			if was_held:
				m.volley = int(stats.multiball)
				m.from = from
				m.way = way
				m.launched = clock
			elif spy.ability == &"":
				_seen.plain = _seen.get("plain", 0) + 1
		# A charge put on the paddle this step: the next ball, with no ball_added.
		var w := spy.waiting
		if w and not m.balls.has(w.id):
			_fail(w.id == m.next and w.charge == &"" and m.charges > 0, "with no ball waiting, a charge held goes onto the paddle as the next ball (Round CHARGES)")
			m.balls[w.id] = true
			m.next += 1
			m.charges -= 1
		_fail(spy.charges == m.charges and (spy.held or spy.waiting or spy.charges == 0), "the charges held are those caught and not yet put on the paddle, and one goes on as soon as no ball waits (Round CHARGES)",
				"charges %d, want %d, waiting %s" % [spy.charges, m.charges, spy.waiting])
		var paddle_y := clampf(move_toward(was_y, target, stats.paddle_speed * dt), 0.0, spy.board.size().y)
		_fail(is_equal_approx(spy.paddle.y, paddle_y), "the paddle moves toward its target at paddle speed (Round.step 1)")
		for pair: Array in m.new:
			_fail(pair[0].pos == pair[1], "a ball made during a step starts moving on the next one (Round.step 2)")
		if not spy.held:
			time = maxf(time + m.added - dt, 0.0)
		_fail(absf(spy.time_left - time) < 1e-6, "the timer counts down, not while the first ball is held, and hourglass bricks add to it")
		for ball in spy.balls:
			_fail(ball.boost >= 1.0 and ball.boost <= cap and absf(ball.dir.length() - 1.0) < 1e-4, "every ball's boost is between 1 and the cap and its dir is a unit vector")
		_fail(spy.balls.size() == m.balls.size(), "`balls` holds every ball added and not lost")
		var playing: bool = not spy.balls.is_empty() or not spy.drops.is_empty() or m.volley > 0
		if spy.over:
			var why := Round.End.CLEARED if m.left == 0 else Round.End.TIME if playing else Round.End.BALL_LOST
			_fail(m.ended == 1 and m.last == "ended" and spy.reason == why and (why != Round.End.TIME or spy.time_left == 0.0),
					"the round ends once, cleared before ball lost before time, and `ended` is the last signal; a ball waiting, a drop falling or a volley ball to come is not a lost ball (upgrades.md)")
		else:
			_fail(m.left > 0 and playing and spy.time_left > 0.0, "the round goes on while level bricks, time and a ball in play, on the paddle, falling as a drop or still to come are left")
		_fail(spy.board.remaining() == m.left, "the level bricks left are the ones not yet broken")
	_check_tree(spy)
	_check_fires(spy)
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
	if hold:
		again.hold()
	var log2 := []
	again.brick_broken.connect(func(c: Vector2i, _b: Brick, cause: Round.Cause, _d: Vector2, _n: int) -> void: log2.append([c, cause]))
	for act: Array in acts:
		_act(again, act, dt)
	_fail(log2 == log and again.coins == spy.coins and again.reason == spy.reason and again.over == spy.over and again.time_left == spy.time_left and again.charges == spy.charges,
			"the same board, layout, stats, seed and inputs give the same round (Round INPUTS)")
	# Round 2: the inputs are not changed by playing, and the order the board lists its bricks in is not an input.
	_fail(_r2_inputs(board, layout, stats) == inputs, "a round changes neither the board, the layout nor the stats it was built from (Round INPUTS: 'The round copies it; the caller's board is not changed')")
	var listed := Board.new(board.rows)
	var keys := board.bricks.keys()
	keys.reverse()
	for c: Vector2i in keys:
		listed.bricks[c] = board.bricks[c].copy()
	var third := Round.new(listed, layout, stats, sd)
	if hold:
		third.hold()
	var log3 := []
	third.brick_broken.connect(func(c: Vector2i, _b: Brick, cause: Round.Cause, _d: Vector2, _n: int) -> void: log3.append([c, cause]))
	for act: Array in acts:
		_act(third, act, dt)
	_fail(log3 == log and third.coins == spy.coins and third.reason == spy.reason, "the same bricks listed in another order give the same round (Round INPUTS)")
	# The lambdas above read `spy` and hang on spy's own signals, so the round holds itself. Let go, or every
	# random round is still there when the test run exits (Godot then reports thousands of leaked objects).
	for sig: Dictionary in spy.get_signal_list():
		for c: Dictionary in spy.get_signal_connection_list(sig.name):
			spy.disconnect(sig.name, c.callable)


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
		_fail(got == (expect == 1), "Layout.fits takes an item exactly when it is inside the grid, over no brick, item or the launch path, and under its count (%s %s)" % [item.kind.id, "fits" if expect == 1 else "does not fit"],
				"%s at %s rot %s cell %s on %d rows; layout %s" % [item.kind.id, item.pos, item.rot, item.cell, board.rows, layout.to_data()])
		if got and rng.randf() < 0.3:
			layout.add(item)


# --- round 2 ---------------------------------------------------------------------------------------------------
# What round 1 left alone: the timer fix at many step rates, which end wins when two come in one step, what a
# hit and a blast pay at each step of the combo, a Blast charge with Shockwave, special bricks the
# level painted itself, items against the ball at rest on every level size, a layout's trip through the save,
# every ball_bounced payload, and that a round leaves its inputs alone.

## Everything a round is built from, as plain data, to see that playing it changes none of it.
func _r2_inputs(board: Board, layout: Layout, stats: Balance) -> Array:
	var cells := []
	for c: Vector2i in board.bricks:
		var b := board.brick(c)
		cells.append([c, b.hp, b.kind, b.placed])
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
		elif hit.surface == Hit.Surface.ITEM and hit.item.kind.gate:
			_fail(hit.normal.is_equal_approx(-ball.dir), "a gate's normal points back along the ball's way, which it does not change (Hit.normal)", "normal %s, dir %s" % [hit.normal, ball.dir])
		elif hit.surface == Hit.Surface.ITEM:
			_fail(ball.dir.dot(hit.normal) > 0.0, "after an item bounce the ball leaves the item (Round.ball_bounced)", "%s normal %s, dir %s" % [hit.item.kind.id, hit.normal, ball.dir])
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


## A hit that breaks a brick, then a Blast charge at its cell that breaks nine more: every brick in the combo is paid
## at the multiplier it has reached (Round ONE BRICK HIT, overview.md "Coins"), so a break that raises it pays the
## rise on the earlier ones too; gold is worth 20, the placed Splitter nothing, though it still counts in the combo.
func _r2_chain_pay() -> void:
	var bricks := {FAR: SOLID, Vector2i(20, 4): 1, Vector2i(20, 3): 1}
	for x in range(17, 25):
		if x != 20:
			bricks[Vector2i(x, 4)] = 1
	var board := _board(bricks)
	board.bricks[Vector2i(20, 3)].kind = &"gold"
	for rank: int in [1, 0]:
		var round := Round.new(board, _layout([_item(&"splitter", Vector2i(20, 5))]), _sealed(board, {&"combo_rank": float(rank), &"splitter_count": 1, &"blast_count": 1}), 1)
		var paid := []
		round.brick_broken.connect(func(c: Vector2i, _b: Brick, _cause: Round.Cause, _d: Vector2, n: int) -> void: paid.append([c, n]))
		round.hit_brick(Vector2i(20, 4), Round.Cause.BALL, Vector2.RIGHT)
		(Kinds.of(&"blast") as AbilityKind).fire(round, Vector2i(20, 4), Vector2.RIGHT, null)
		var order := [Vector2i(20, 4), Vector2i(17, 4), Vector2i(18, 4), Vector2i(19, 4), Vector2i(20, 3), Vector2i(20, 5), Vector2i(21, 4), Vector2i(22, 4), Vector2i(23, 4), Vector2i(24, 4)]
		var coins := [1, 1, 1, 1, 44, 0, 2, 2, 29, 3] if rank else [1, 1, 1, 1, 20, 0, 1, 1, 1, 1]
		var want := []
		for i in order.size():
			want.append([order[i], coins[i]])
		t.check(paid == want, "combo rank %d: a hit and a blast's nine breaks pay %s, in blast order (overview.md 'Coins'): %s" % [rank, coins, paid])
		var total := 84 if rank else 28
		t.check(round.coins == total and Coins.total(round.tally, round.stats) == total and round.tally.placed_broken == 1 and round.tally.broken == {&"": 8, &"gold": 1},
				"combo rank %d: the hit and the blast pay %d and the tally holds 8 standard, 1 gold and 1 placed brick: %d %s" % [rank, total, round.coins, round.tally.broken])
		if rank:
			t.check(round.combo.count == 10 and round.combo.multiplier == 3 and round.tally.best_combo == 10 and is_equal_approx(round.combo.window, 1.6 * 0.81),
					"the hit and the blast leave a combo of 10 at x3 with a window of 1.296 s: %d x%d %s" % [round.combo.count, round.combo.multiplier, round.combo.window])
		t.check(round.balls.size() == 1, "a Splitter a blast breaks adds no ball (placeables.md)")


## A Blast charge with Shockwave, fired as play fires it (upgrades.md): the ball's hit lands, then the blast throws
## every ball inside it straight away from its centre, the charged ball too, and boosts them; one outside is left alone.
func _r2_shockwave_charge() -> void:
	var board := _board({FAR: SOLID, Vector2i(30, 3): 2})
	var spy := _quiet(board, null, {&"blast_count": 1, &"shockwave": 1.0})
	var outside := spy.balls[0]  # at (900, 450)
	var inside := spy.add_ball(Vector2(528, 260), Vector2(0.6, 0.8))  # the blast is x 416-560, y 128-320
	var thrown: int = _seen.get("shockwave", 0)
	_repro = "a Blast charge with Shockwave (_r2_shockwave_charge)"
	var ball := _fire_at(spy, Vector2i(30, 3))
	_run(spy, 0.05)
	_check_tree(spy)
	_check_fires(spy)
	var boost := minf(spy.stats.shockwave_boost, spy.stats.boost_cap)
	t.check(spy.board.brick(Vector2i(30, 3)) == null and ball.charge == &"" and ball.boost == boost and inside.boost == boost and outside.boost == 1.0
			and outside.dir == Vector2(0.6, 0.8) and _seen.get("shockwave", 0) - thrown == 2,
			"a Blast charge with Shockwave throws and boosts the charged ball and the ball inside the blast, and leaves the one outside alone: %s %s %s" % [ball.boost, inside.boost, outside.boost])


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
	for ranks: Array in [[1, 2, 0, 0], [0, 0, 3, 1], [20, 1, 0, 0], [2, 2, 2, 2]]:
		for sd in 10:
			var stats := {}
			for i in SPECIALS.size():
				stats[Balance.count_stat(SPECIALS[i])] = ranks[i]
			var round := Round.new(board, null, _stats(stats), sd)
			var got := {&"": 0}
			for k in SPECIALS:
				got[k] = 0
			for c: Vector2i in round.board.bricks:
				got[round.board.brick(c).kind] += 1
			var left := 9
			var want := got.duplicate()
			for i in SPECIALS.size():
				var n := mini(ranks[i], left)
				want[SPECIALS[i]] = n + (3 if SPECIALS[i] == &"gold" else 0)
				left -= n
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
			_item(&"booster", Vector2(0.1 + 0.2, 0.7) * 1000.0 / 3.0), _item(&"splitter", Vector2i(30, 3))])
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
