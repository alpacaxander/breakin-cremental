extends RefCounted
## The level screen in each state that matters: Setup on a fresh save and with everything unlocked and placed,
## a drag that fits and one that does not, an item held over the tray, Play early, mid-combo, with tough bricks
## hit, with bricks grown by a Growth block, with bricks a Refresh block brought back (it cooling, beside one
## ready), with bricks Overgrowth brought back, on the zoomed level 3, and paused, and the Summary for each of the three
## ends and with several combos. Compare them with docs/art.md ("Level screen") and the level mockup.
##
## The mouse is pushed straight into Main's View, so a position here is a position in the 1280 x 720 frame
## whether the CRT curves the picture or not.

## Something of every placeable on level 1, in the saved form (Layout.to_data), clear of its bricks.
const PLACED := [
	{"kind": "bumper", "x": 300.0, "y": 120.0, "rot": 0.0},
	{"kind": "bumper", "x": 420.0, "y": 400.0, "rot": 0.0},
	{"kind": "booster", "x": 610.0, "y": 180.0, "rot": 0.0},
	{"kind": "wall_segment", "x": 720.0, "y": 300.0, "rot": 0.0},
	{"kind": "wall_segment", "x": 200.0, "y": 380.0, "rot": 60.0},
	{"kind": "splitter", "col": 30, "row": 2},
	{"kind": "splitter", "col": 40, "row": 5},
	{"kind": "zap", "col": 62, "row": 1},
	{"kind": "zap", "col": 40, "row": 5},
	{"kind": "growth", "col": 47, "row": 3},
	{"kind": "refresh", "col": 50, "row": 3},
	{"kind": "refresh", "col": 20, "row": 6},
]


func shots() -> Array[Dictionary]:
	return [
		{"name": "setup_fresh", "setup": _open.bind(1, [])},
		{"name": "setup_fresh_crt_off", "crt": false, "setup": _open.bind(1, [])},
		{"name": "setup_placed", "save": "maxed", "setup": _open.bind(1, PLACED)},
		{"name": "setup_placed_crt_off", "save": "maxed", "crt": false, "setup": _open.bind(1, PLACED)},
		{"name": "setup_mid_2", "save": "mid", "crt": false, "setup": _open.bind(2, [])},
		{"name": "setup_maxed_3", "save": "maxed", "setup": _open.bind(3, [])},
		{"name": "drag_fits", "save": "maxed", "crt": false, "setup": _drag.bind(Vector2(520, 300), &"wall_segment")},
		{"name": "drag_refused", "save": "maxed", "crt": false, "setup": _drag.bind(Vector2(1138, 300), &"wall_segment")},
		{"name": "drag_brick", "save": "maxed", "crt": false, "setup": _drag.bind(Vector2(700, 420), &"splitter")},
		{"name": "drag_zap", "save": "maxed", "crt": false, "setup": _drag.bind(Vector2(1138, 420), &"zap")},
		{"name": "hold_tray", "save": "maxed", "crt": false, "setup": _hold.bind(&"booster", Vector2(30, -8))},
		{"name": "hold_tray_splitter", "save": "maxed", "crt": false, "setup": _hold.bind(&"splitter", Vector2.ZERO)},
		{"name": "play_fresh", "setup": _play.bind(1, [], 45, 0)},
		{"name": "play_fresh_crt_off", "crt": false, "setup": _play.bind(1, [], 45, 0)},
		{"name": "play_mid_2", "save": "mid", "setup": _play.bind(2, [], 150, 9)},
		{"name": "play_mid_2_crt_off", "save": "mid", "crt": false, "setup": _play.bind(2, [], 150, 9)},
		{"name": "play_maxed_1", "save": "maxed", "crt": false, "setup": _play.bind(1, PLACED, 200, 0)},
		{"name": "play_maxed_3", "save": "maxed", "setup": _play.bind(3, [], 240, 0)},
		{"name": "play_paused", "save": "mid", "setup": _paused},
		{"name": "play_low_time", "save": "mid", "crt": false, "setup": _low_time},
		{"name": "play_guide", "save": "maxed", "setup": _guide},
		{"name": "play_tough", "save": "maxed", "crt": false, "setup": _tough},
		{"name": "play_growth", "save": "maxed", "setup": _growth, "settle": 12},
		{"name": "play_refresh", "save": "maxed", "setup": _refresh, "settle": 12},
		{"name": "play_refresh_crt_off", "save": "maxed", "crt": false, "setup": _refresh, "settle": 12, "frames": 2, "every": 40},
		{"name": "play_overgrowth", "save": "maxed", "crt": false, "setup": _overgrowth, "settle": 60},
		{"name": "play_strip", "save": "mid", "crt": false, "setup": _play.bind(2, [], 60, 0), "settle": 0, "frames": 4, "every": 2},
		{"name": "summary_cleared", "save": "maxed", "setup": _end.bind(Round.End.CLEARED), "settle": 110},
		{"name": "summary_cleared_crt_off", "save": "maxed", "crt": false, "setup": _end.bind(Round.End.CLEARED), "settle": 110},
		{"name": "summary_time", "save": "mid", "crt": false, "setup": _end.bind(Round.End.TIME), "settle": 110},
		{"name": "summary_ball_lost", "crt": false, "setup": _end.bind(Round.End.BALL_LOST), "settle": 110},
		{"name": "summary_combos", "save": "maxed", "crt": false, "setup": _combos, "settle": 140},
		{"name": "summary_counting", "save": "maxed", "crt": false, "setup": _end.bind(Round.End.CLEARED), "settle": 38, "frames": 4, "every": 8},
	]


func _open(_main: Main, number: int, placed: Array) -> Control:
	Progress.layouts[number] = placed
	return Main.show_level(number)


## Level 1 with everything placed, and the tray slot of kind `slot` dragged to `to`.
func _drag(main: Main, to: Vector2, slot: StringName) -> void:
	var level := _open(main, 1, PLACED.slice(0, 1))
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var from := _slot(level, slot).get_global_rect().get_center()
	_mouse(main, from, true)
	for i in 4:
		_mouse(main, from.lerp(to, (i + 1) / 4.0))
	if slot == &"wall_segment":
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = to
		wheel.global_position = to
		for i in 2:
			main.view.push_input(wheel, true)


## Level 1 with the tray slot of kind `slot` just pressed and held, the cursor `by` from its centre: over the tray.
func _hold(main: Main, slot: StringName, by: Vector2) -> void:
	var level := _open(main, 1, [])
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var from := _slot(level, slot).get_global_rect().get_center()
	_mouse(main, from, true)
	_mouse(main, from + by)


## The tray slot of kind `id`. By kind, not by index: which slots the tray has follows the upgrade web.
func _slot(level: Control, id: StringName) -> LevelSetupUi.Slot:
	for slot: LevelSetupUi.Slot in level.get_node("SetupUi").get("_slots"):
		if slot.kind.id == id:
			return slot
	return null


## Starts level `number` and lets a paddle that follows the ball play it for `frames` physics ticks. Then, to
## show a combo, breaks `breaks` bricks at once.
func _play(main: Main, number: int, placed: Array, frames: int, breaks: int) -> Control:
	var level := _open(main, number, placed)
	level.call("start", 7)
	var round: Round = level.get("round")
	for i in frames:
		if round.over:
			break
		var ball := round.balls[0]
		for other in round.balls:
			if other.dir.x < 0.0 and (ball.dir.x >= 0.0 or other.pos.x < ball.pos.x):
				ball = other
		_mouse(main, LevelArena.ORIGIN + ball.pos * round.board.zoom())
		await main.get_tree().physics_frame
	var cells := round.board.bricks.keys()
	for i in mini(breaks, cells.size()):
		round.hit_brick(cells[i], Round.Cause.BLAST, Vector2.RIGHT)
	return level


## Level 1 in Play with its three tough bricks hit 0, 1 and 2 times: they show the 3, 2 and 1 HP steps.
func _tough(main: Main) -> void:
	var level := await _play(main, 1, [], 0, 0)
	var round: Round = level.get("round")
	var tough := round.board.bricks.keys().filter(func(c: Vector2i) -> bool: return round.board.brick(c).kind == &"tough")
	for i in tough.size():
		for j in i:
			round.hit_brick(tough[i], Round.Cause.BLAST, Vector2.RIGHT)


## Level 1 in Play with everything placed, after the Growth block has pulsed twice: the bricks beside it have
## grown, and the second pulse's effect is still on screen.
func _growth(main: Main) -> void:
	var level := await _play(main, 1, PLACED, 0, 0)
	var round: Round = level.get("round")
	for i in 2:
		round.grow(Vector2i(47, 3), round.stats.growth_reach * Board.BRICK.y)


## Level 1 in Play with everything placed, after a ball hit the Refresh block beside the bricks: the five level
## bricks nearest it were gone and are back (a maxed one brings seven), its effect is on screen, and it is dim
## (cooling) while the other Refresh block, out in the open, is lit (ready). The flat one adds a frame after the
## effect is gone.
func _refresh(main: Main) -> void:
	var level := await _play(main, 1, PLACED, 0, 0)
	var round: Round = level.get("round")
	var block := Vector2i(50, 3)
	for cell in [Vector2i(49, 3), Vector2i(49, 2), Vector2i(49, 4), Vector2i(48, 3), Vector2i(49, 1)]:
		round.board.bricks.erase(cell)  # gone without a blast, so nothing but the Refresh effect is on screen
	round.hit_brick(block, Round.Cause.BALL, Vector2.RIGHT, round.balls[0])


## Level 3 in Play with Overgrowth (the maxed save owns it): a block above the tunnel was broken 8 s of play ago
## and has grown back, all 1 HP (its 2 HP row too), and the same block below the tunnel, broken since, is a gap.
func _overgrowth(main: Main) -> void:
	var level := await _play(main, 3, [], 30, 0)
	var round: Round = level.get("round")
	var smash := func(rows: Array) -> void:
		for column in range(40, 48):
			for row: int in rows:
				while round.board.brick(Vector2i(column, row)):
					round.hit_brick(Vector2i(column, row), Round.Cause.BLAST, Vector2.RIGHT)
	smash.call([1, 2, 3])
	round.clock += round.stats.overgrowth_delay  # 8 s of play skipped
	round.launch()  # a held round waits, regrowth too
	round.step(1.0 / 120.0, round.paddle.y)  # the step that brings the top block back
	round.hold()  # the ball back on the paddle, so the shot does not depend on where it goes
	smash.call([5, 6, 7])


func _low_time(main: Main) -> void:
	var level := await _play(main, 2, [], 60, 5)
	(level.get("round") as Round).time_left = 3.4


## Level 2 in Play, paused: the pause panel over the arena, Resume selected.
func _paused(main: Main) -> void:
	var level := await _play(main, 2, [], 150, 9)
	level.call("pause", true)


## Plays level 1 for a moment and ends the round the given way.
func _end(main: Main, how: Round.End) -> void:
	var level := await _play(main, 1, PLACED if how == Round.End.CLEARED else [], 30, 0)
	var round: Round = level.get("round")
	match how:
		Round.End.CLEARED:
			for cell: Vector2i in round.board.bricks.keys():
				for i in round.board.brick(cell).hp if round.board.brick(cell) else 0:
					round.hit_brick(cell, Round.Cause.BLAST, Vector2.RIGHT)
		Round.End.TIME:
			var cells := round.board.bricks.keys()
			for i in 7:
				for j in 3:
					round.hit_brick(cells[i], Round.Cause.BLAST, Vector2.RIGHT)
			round.time_left = 0.0
		Round.End.BALL_LOST:
			round.balls[0].put(Vector2(-20, 40), Vector2.LEFT)


## Level 2 run out of time after seven combos, so the Summary lists the biggest as combo rows and folds the rest
## into "more combos".
func _combos(main: Main) -> void:
	var level := await _play(main, 2, [], 30, 0)
	var round: Round = level.get("round")
	var cells := round.board.bricks.keys()
	var next := 0
	for size in [6, 11, 7, 9, 6, 8, 12]:
		for i in size:
			while round.board.brick(cells[next]):
				round.hit_brick(cells[next], Round.Cause.BLAST, Vector2.RIGHT)
			next += 1
		round.combo.tick(100.0)  # the window runs out
	round.time_left = 0.0


func _mouse(main: Main, at: Vector2, press := false) -> void:
	var event: InputEventMouse = InputEventMouseButton.new() if press else InputEventMouseMotion.new()
	if press:
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
	event.position = at
	event.global_position = at
	main.view.push_input(event, true)


## Level 1 in Play with everything placed and the ball still on the paddle: the Guide's line (the maxed save owns
## Guide Bounces too) from the ball, aimed steeply up, off the walls and the items.
func _guide(main: Main) -> void:
	var level := await _play(main, 1, PLACED, 0, 0)
	var round: Round = level.get("round")
	round.sway = 1.2
