extends RefCounted
## The level screen in each state that matters: Setup on a fresh save and with everything unlocked and placed,
## a drag that fits and one that does not, an item held over the tray, Play early, mid-combo and on the zoomed level 3, and the Summary for
## each of the three ends. Compare them with docs/art.md ("Level screen") and the level mockup.
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
]


func shots() -> Array[Dictionary]:
	return [
		{"name": "setup_fresh", "setup": _open.bind(1, [])},
		{"name": "setup_fresh_crt_off", "crt": false, "setup": _open.bind(1, [])},
		{"name": "setup_placed", "save": "maxed", "setup": _open.bind(1, PLACED)},
		{"name": "setup_placed_crt_off", "save": "maxed", "crt": false, "setup": _open.bind(1, PLACED)},
		{"name": "setup_mid_2", "save": "mid", "crt": false, "setup": _open.bind(2, [])},
		{"name": "setup_maxed_3", "save": "maxed", "setup": _open.bind(3, [])},
		{"name": "drag_fits", "save": "maxed", "crt": false, "setup": _drag.bind(Vector2(520, 300), 2)},
		{"name": "drag_refused", "save": "maxed", "crt": false, "setup": _drag.bind(Vector2(1138, 300), 2)},
		{"name": "drag_brick", "save": "maxed", "crt": false, "setup": _drag.bind(Vector2(700, 420), 3)},
		{"name": "drag_zap", "save": "maxed", "crt": false, "setup": _drag.bind(Vector2(1138, 420), 4)},
		{"name": "hold_tray", "save": "maxed", "crt": false, "setup": _hold.bind(0, Vector2(30, -8))},
		{"name": "hold_tray_splitter", "save": "maxed", "crt": false, "setup": _hold.bind(3, Vector2.ZERO)},
		{"name": "play_fresh", "setup": _play.bind(1, [], 45, 0)},
		{"name": "play_fresh_crt_off", "crt": false, "setup": _play.bind(1, [], 45, 0)},
		{"name": "play_mid_2", "save": "mid", "setup": _play.bind(2, [], 150, 9)},
		{"name": "play_mid_2_crt_off", "save": "mid", "crt": false, "setup": _play.bind(2, [], 150, 9)},
		{"name": "play_maxed_1", "save": "maxed", "crt": false, "setup": _play.bind(1, PLACED, 200, 0)},
		{"name": "play_maxed_3", "save": "maxed", "setup": _play.bind(3, [], 240, 0)},
		{"name": "play_low_time", "save": "mid", "crt": false, "setup": _low_time},
		{"name": "play_strip", "save": "mid", "crt": false, "setup": _play.bind(2, [], 60, 0), "settle": 0, "frames": 4, "every": 2},
		{"name": "summary_cleared", "save": "maxed", "setup": _end.bind(Round.End.CLEARED), "settle": 110},
		{"name": "summary_cleared_crt_off", "save": "maxed", "crt": false, "setup": _end.bind(Round.End.CLEARED), "settle": 110},
		{"name": "summary_time", "save": "mid", "crt": false, "setup": _end.bind(Round.End.TIME), "settle": 110},
		{"name": "summary_ball_lost", "crt": false, "setup": _end.bind(Round.End.BALL_LOST), "settle": 110},
		{"name": "summary_counting", "save": "maxed", "crt": false, "setup": _end.bind(Round.End.CLEARED), "settle": 38, "frames": 4, "every": 8},
	]


func _open(_main: Main, number: int, placed: Array) -> Control:
	Progress.layouts[number] = placed
	return Main.show_level(number)


## Level 1 with everything placed, and tray slot `slot` dragged to `to`.
func _drag(main: Main, to: Vector2, slot: int) -> void:
	var level := _open(main, 1, PLACED.slice(0, 1))
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var from: Vector2 = (level.get_node("SetupUi").get("_slots")[slot] as Control).get_global_rect().get_center()
	_mouse(main, from, true)
	for i in 4:
		_mouse(main, from.lerp(to, (i + 1) / 4.0))
	if slot == 2:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = to
		wheel.global_position = to
		for i in 2:
			main.view.push_input(wheel, true)


## Level 1 with tray slot `slot` just pressed and held, the cursor `by` from the slot's centre: over the tray.
func _hold(main: Main, slot: int, by: Vector2) -> void:
	var level := _open(main, 1, [])
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var from: Vector2 = (level.get_node("SetupUi").get("_slots")[slot] as Control).get_global_rect().get_center()
	_mouse(main, from, true)
	_mouse(main, from + by)


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


func _low_time(main: Main) -> void:
	var level := await _play(main, 2, [], 60, 5)
	(level.get("round") as Round).time_left = 3.4


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


func _mouse(main: Main, at: Vector2, press := false) -> void:
	var event: InputEventMouse = InputEventMouseButton.new() if press else InputEventMouseMotion.new()
	if press:
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
	event.position = at
	event.global_position = at
	main.view.push_input(event, true)
