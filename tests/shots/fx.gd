extends RefCounted
## The effects (src/level/fx/fx.gd), each as a strip that shows it start, peak and fade: at no combo, at x12 and
## at the top of the curve, on level 1 and on the zoomed level 3, with the CRT on, and the explosion once more
## with reduce flashing on. Compare them with docs/art.md ("Effects") and the level mockup.
##
## A strip is 8 pictures 4 frames apart unless it says otherwise: 0.47 s, which is an explosion from its first
## frame to its last. Each effect is set off by hand on the real level screen, on a round that is being played,
## so the ball and its trail are in the picture too.

const STRIP := {"settle": 0, "frames": 8, "every": 4}
## Something of every placeable on level 1, clear of its bricks (the same layout as tests/shots/level.gd).
const PLACED := [
	{"kind": "bumper", "x": 300.0, "y": 120.0, "rot": 0.0},
	{"kind": "booster", "x": 610.0, "y": 180.0, "rot": 0.0},
	{"kind": "wall_segment", "x": 720.0, "y": 300.0, "rot": 0.0},
	{"kind": "wall_segment", "x": 200.0, "y": 380.0, "rot": 60.0},
	{"kind": "splitter", "col": 40, "row": 5},
]


func shots() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		# A brick broken by a ball, three times over, and two bricks hit that held.
		{"name": "break_x0", "crt": false, "setup": _breaks.bind(1, 0)},
		{"name": "break_x12", "save": "maxed", "crt": false, "setup": _breaks.bind(1, 12)},
		{"name": "break_top", "save": "maxed", "crt": false, "setup": _breaks.bind(1, Fx.COMBO_TOP)},
		{"name": "break_top_crt", "save": "maxed", "setup": _breaks.bind(1, Fx.COMBO_TOP)},
		# The same on level 3's full wall, where the combo has to show too.
		{"name": "l3_break_x0", "save": "maxed", "setup": _breaks.bind(3, 0)},
		{"name": "l3_break_top", "save": "maxed", "setup": _breaks.bind(3, Fx.COMBO_TOP)},
		# The explosion, at the base blast size every time so the combo is the only difference.
		{"name": "blast_x0", "crt": false, "setup": _blast.bind(1, 0)},
		{"name": "blast_x12", "save": "maxed", "crt": false, "setup": _blast.bind(1, 12)},
		{"name": "blast_top", "save": "maxed", "crt": false, "setup": _blast.bind(1, Fx.COMBO_TOP)},
		{"name": "blast_x12_calm", "save": "maxed", "crt": false, "calm": true, "setup": _blast.bind(1, 12)},
		{"name": "blast_x12_crt", "save": "maxed", "setup": _blast.bind(1, 12)},
		# The special bricks as the round sets them off: gold, hourglass, and an explosive at the bought blast size.
		{"name": "specials", "save": "maxed", "crt": false, "setup": _specials.bind(1)},
		{"name": "explosive_top", "save": "maxed", "crt": false, "setup": _explosive.bind(1, Fx.COMBO_TOP)},
		# The placeables, the paddle, a boosted ball, a ball lost, the last brick.
		{"name": "items", "save": "maxed", "crt": false, "setup": _items},
		{"name": "boost", "save": "maxed", "crt": false, "setup": _boost, "settle": 0, "frames": 3, "every": 4},
		{"name": "gate", "save": "maxed", "crt": false, "setup": _gate, "settle": 0, "frames": 8, "every": 2},
		{"name": "paddle_lost", "crt": false, "setup": _paddle_lost},
		{"name": "paddle_lost_calm", "crt": false, "calm": true, "setup": _paddle_lost},
		{"name": "cleared", "save": "maxed", "setup": _cleared, "settle": 0, "frames": 8, "every": 6},
		{"name": "time_up", "setup": _time_up},
		# Level 3: smaller, and bursts. A Zap along a 2 HP row and along a 1 HP row, an explosive, and the worst
		# burst there is: every brick at 1 HP, a Zap on a row and the three explosives next to it.
		{"name": "l3_break_x12", "save": "maxed", "crt": false, "setup": _breaks.bind(3, 12)},
		{"name": "l3_zap_hits", "save": "maxed", "crt": false, "setup": _zap.bind(3)},
		{"name": "l3_zap_breaks_crt", "save": "maxed", "setup": _zap.bind(1)},
		{"name": "l3_explosive_x12", "save": "maxed", "crt": false, "setup": _explosive.bind(3, 12)},
		{"name": "l3_worst", "save": "maxed", "crt": false, "setup": _worst},
		{"name": "l3_worst_crt", "save": "maxed", "setup": _worst},
		# Real play, a paddle following the ball.
		{"name": "play_l1", "setup": _play.bind(1, 180), "settle": 0, "frames": 6, "every": 6},
		{"name": "play_l2_mid", "save": "mid", "setup": _play.bind(2, 150), "settle": 0, "frames": 8, "every": 8},
		{"name": "play_l3_maxed", "save": "maxed", "setup": _play.bind(3, 200), "settle": 0, "frames": 8, "every": 8},
	]
	for shot in list:
		shot.merge(STRIP)
	return list


## Level `number` in Play with seed 7, the combo standing at `combo` and the bloom settled there.
func _start(main: Main, number: int, combo := 0, placed := []) -> Round:
	Progress.layouts[number] = placed
	var level := Main.show_level(number)
	level.call("start", 7)
	var round: Round = level.get("round")
	if combo > 0:
		_combo(round, combo - 1)
	for i in 20:
		await main.get_tree().process_frame
	return round


## Puts the combo at `count`, with a window that outlasts the strip.
func _combo(round: Round, count: int) -> void:
	round.combo.count = count
	@warning_ignore("integer_division")
	round.combo.multiplier = 1 + maxi(count - 1, 0) / round.stats.combo_breaks_per_step
	round.combo.window = 60.0
	round.combo.time_left = 60.0
	round.combo_changed.emit(count, round.combo.multiplier)


## The standard bricks of the board with `hp`, top to bottom from the paddle side.
func _plain(round: Round, hp: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in round.board.bricks:
		var brick := round.board.brick(cell)
		if brick.kind == &"" and brick.mod == &"" and brick.hp == hp:
			out.append(cell)
	out.sort()
	return out


func _of_kind(round: Round, kind: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in round.board.bricks:
		if round.board.brick(cell).kind == kind:
			out.append(cell)
	out.sort()
	return out


## Three 1 HP bricks broken as a ball would, each from another side, and a brick or two hit that held.
func _breaks(main: Main, number: int, combo: int) -> void:
	var round := await _start(main, number, combo)
	var soft := _plain(round, 1)
	var dirs: Array[Vector2] = [Vector2(1, 0.4).normalized(), Vector2(1, -0.6).normalized(), Vector2(-1, 0.5).normalized()]
	for i in 3:
		round.hit_brick(soft[i * (soft.size() - 1) / 2], Round.Cause.BALL, dirs[i])  # the first, the middle one, the last
	for hp: int in [2, 3, 4]:
		var hard := _plain(round, hp)
		if not hard.is_empty():
			round.hit_brick(hard[hard.size() / 3], Round.Cause.BALL, Vector2.RIGHT)


func _blast(main: Main, number: int, combo: int) -> void:
	var round := await _start(main, number, combo)
	round.blast(Vector2i(48, 3), Board.BRICK.y)


func _explosive(main: Main, number: int, combo: int) -> void:
	var round := await _start(main, number, combo)
	round.hit_brick(_of_kind(round, &"explosive")[0], Round.Cause.BALL, Vector2.RIGHT)


func _specials(main: Main, number: int) -> void:
	var round := await _start(main, number, 6)
	round.hit_brick(_of_kind(round, &"gold")[0], Round.Cause.BALL, Vector2.RIGHT)
	round.hit_brick(_of_kind(round, &"hourglass")[0], Round.Cause.BALL, Vector2(1, 1).normalized())


## A ball sent at each placed item from close by, and one that breaks the Splitter.
func _items(main: Main) -> void:
	var round := await _start(main, 1, 0, PLACED)
	var from: Array[Vector2] = [Vector2(240, 120), Vector2(550, 180), Vector2(660, 290), Vector2(150, 360), Vector2(590, 350)]
	var to: Array[Vector2] = [Vector2(300, 120), Vector2(610, 180), Vector2(720, 300), Vector2(200, 380), Vector2(648, 352)]
	for i in from.size():
		var ball := round.balls[0] if i == 0 else round.add_ball(from[i], Vector2.RIGHT)
		ball.put(from[i], from[i].direction_to(to[i]))
	for i in 6:
		await main.get_tree().physics_frame


## Two balls side by side, the lower one at three times the speed.
func _boost(main: Main) -> void:
	var round := await _start(main, 1)
	round.balls[0].put(Vector2(60, 150), Vector2(1, 0.15).normalized())
	round.set_boost(round.add_ball(Vector2(60, 300), Vector2(1, 0.15).normalized()), 3.0)
	for i in 10:
		await main.get_tree().physics_frame


## The timer runs out with two balls in play.
func _time_up(main: Main) -> void:
	var round := await _start(main, 1)
	round.add_ball(Vector2(500, 380), Vector2(1, 0.5).normalized())
	round.time_left = 0.0
	await main.get_tree().physics_frame


## The launch into the paddle, and a second ball that goes out past it.
func _paddle_lost(main: Main) -> void:
	Progress.layouts.erase(1)
	var level := Main.show_level(1)
	level.call("start", 7)
	var round: Round = level.get("round")
	round.add_ball(Vector2(110, 60), Vector2(-1, 0.25).normalized())
	await main.get_tree().process_frame


## Level 1 down to its last brick, and that brick.
func _cleared(main: Main) -> void:
	var round := await _start(main, 1, 20)
	var cells := round.board.bricks.keys()
	cells.sort()
	for cell: Vector2i in cells:  # plain bricks, so no blast takes the last one early
		round.board.brick(cell).kind = &""
	for i in cells.size():
		if i == cells.size() - 1:
			for j in 60:
				await main.get_tree().process_frame
		while round.board.brick(cells[i]) and not round.over:
			round.hit_brick(cells[i], Round.Cause.BALL, Vector2.RIGHT)


## A Zap set off on brick row `row` of level 3: row 3 is 2 HP (63 hits that hold), row 1 is 1 HP (63 breaks).
func _zap(main: Main, row: int) -> void:
	var round := await _start(main, 3, 12)
	var cell := Vector2i(30, row)
	var brick := round.board.brick(cell)
	brick.mod = &"zap"
	brick.kind = &""
	brick.hp = 1
	round.hit_brick(cell, Round.Cause.BALL, Vector2.RIGHT)


## The worst burst: every brick of level 3 at 1 HP, a Zap on a row, and the round's explosives moved into it.
func _worst(main: Main) -> void:
	var round := await _start(main, 3, Fx.COMBO_TOP)
	worst(round)


## Also what tests/cases/fx.gd measures.
static func worst(round: Round) -> void:
	for cell: Vector2i in round.board.bricks:
		var brick := round.board.brick(cell)
		brick.hp = 1
		brick.kind = &""
	for column: int in [14, 34, 54]:
		round.board.brick(Vector2i(column, 2)).kind = &"explosive"
	round.board.brick(Vector2i(6, 2)).mod = &"zap"
	round.board.brick(Vector2i(30, 6)).mod = &"zap"
	round.stats.zap_range = maxf(round.stats.zap_range, round.board.cols)  # a whole-row Zap: past any rank, for the worst case
	round.hit_brick(Vector2i(6, 2), Round.Cause.BALL, Vector2.RIGHT)
	round.hit_brick(Vector2i(30, 6), Round.Cause.BALL, Vector2.RIGHT)


## Starts level `number` and lets a paddle that follows the nearest incoming ball play it for `ticks` physics
## ticks before the strip starts, and on through it.
func _play(main: Main, number: int, ticks: int) -> void:
	Progress.layouts.erase(number)
	var level := Main.show_level(number)
	level.call("start", 7)
	var round: Round = level.get("round")
	_follow(main, level, round)
	for i in ticks:
		await main.get_tree().physics_frame


func _follow(main: Main, level: Control, round: Round) -> void:
	while is_instance_valid(level) and level.get("round") == round and not round.over:
		var ball := round.balls[0]
		for other in round.balls:
			if other.dir.x < 0.0 and (ball.dir.x >= 0.0 or other.pos.x < ball.pos.x):
				ball = other
		var event := InputEventMouseMotion.new()
		event.position = LevelArena.ORIGIN + ball.pos * round.board.zoom()
		event.global_position = event.position
		main.view.push_input(event, true)
		await main.get_tree().physics_frame


## A ball launched, then sent through the Booster's gate on a slant, just short of it.
func _gate(main: Main) -> void:
	var round := await _start(main, 1, 0, PLACED)
	round.launch()
	round.balls[0].put(Vector2(570, 165), Vector2(1, 0.3).normalized())
