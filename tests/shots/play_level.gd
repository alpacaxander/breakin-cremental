extends RefCounted
## A first player's look at the level screen on all three levels: real play strips with a paddle that follows
## the ball by the mouse, dragging items on the crowded level 3, each end's Summary, the unlock, and the hub
## after the last level is cleared. Some setups also print a measurement (look for "play_level:" lines).

const FOLLOW := "follow"


func shots() -> Array[Dictionary]:
	return [
		{"name": "l1_fresh_play", "crt": false, "setup": _play.bind(1, 7), "settle": 0, "frames": 6, "every": 20},
		{"name": "l1_fresh_lost", "crt": false, "setup": _lose.bind(1), "settle": 150},
		{"name": "l2_mid_play", "save": "mid", "setup": _play.bind(2, 7), "settle": 0, "frames": 4, "every": 30},
		{"name": "l3_maxed_white", "save": "maxed", "crt": false, "setup": _white, "settle": 1},
		{"name": "l3_maxed_play", "save": "maxed", "crt": false, "setup": _play.bind(3, 7), "settle": 0, "frames": 10, "every": 12},
		{"name": "l3_maxed_play_crt", "save": "maxed", "setup": _play.bind(3, 3), "settle": 0, "frames": 4, "every": 15},
		{"name": "l3_drag_tunnel", "save": "maxed", "crt": false, "setup": _drag.bind(3, 0, Vector2(600, 367))},
		{"name": "l3_drag_refused", "save": "maxed", "crt": false, "setup": _drag.bind(3, 2, Vector2(600, 200))},
		{"name": "l1_cleared_unlock", "save": "maxed", "crt": false, "setup": _clear.bind(1, 1), "settle": 130},
		{"name": "l3_cleared_final", "save": "maxed", "crt": false, "setup": _clear.bind(3, 3), "settle": 130},
		{"name": "hub_after_final_clear", "save": "maxed", "crt": false, "setup": _hub_after_final},
	]


func _open(number: int) -> Control:
	Progress.layouts.erase(number)
	return Main.show_level(number)


## Starts level `number` with `seed` and leaves a paddle following the nearest incoming ball by the mouse, every
## physics tick, until the round ends or the shot moves on. When the last ball is lost it prints why.
func _play(main: Main, number: int, seed: int) -> void:
	var level := _open(number)
	level.call("start", seed)
	(level.get("round") as Round).launch()
	_follow(main, level, number)


func _follow(main: Main, level: Control, number: int) -> void:
	var round: Round = level.get("round")
	var last := ""
	while is_instance_valid(level) and level.get("round") == round and not round.over:
		var ball := round.balls[0]
		for other in round.balls:
			if other.dir.x < 0.0 and (ball.dir.x >= 0.0 or other.pos.x < ball.pos.x):
				ball = other
		_mouse(main, LevelArena.ORIGIN + ball.pos * round.board.zoom())
		last = "ball %s dir %s speed %.0f, paddle y %.1f, %.2f s in" % [ball.pos.round(), ball.dir, round.speed_of(ball), round.paddle.y, round.stats.round_time - round.time_left]
		await main.get_tree().physics_frame
	if is_instance_valid(level) and round.reason == Round.End.BALL_LOST:
		print("play_level: level %d, the follower lost the last ball: %s" % [number, last])


## Level `number`, followed for two seconds, then the mouse goes to the top and stays there.
func _lose(main: Main, number: int) -> void:
	var level := _open(number)
	level.call("start", 5)
	(level.get("round") as Round).launch()
	var round: Round = level.get("round")
	for i in 240:
		if round.over:
			return
		_mouse(main, LevelArena.ORIGIN + round.balls[0].pos * round.board.zoom())
		await main.get_tree().physics_frame
	_mouse(main, Vector2(640, 112))


## Level 3 in Setup, maxed: measures the brightest pixel of the ball and of one of the board's toughest plain
## bricks, as the player sees them.
func _white(main: Main) -> void:
	var level := _open(3)
	for i in 3:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := main.get_viewport().get_texture().get_image()
	var round: Round = level.get("round")
	var zoom := round.board.zoom()
	var ball_at := LevelArena.ORIGIN + round.balls[0].pos * zoom
	var ball := _brightest(image, Rect2(ball_at - Vector2(4, 4), Vector2(8, 8)))
	var brick: Color
	var top := 0
	for cell: Vector2i in round.board.bricks:
		if round.board.brick(cell).kind == &"":
			top = maxi(top, round.board.brick(cell).hp)
	for cell: Vector2i in round.board.bricks:
		if round.board.brick(cell).hp == top and round.board.brick(cell).kind == &"":
			var r := round.board.cell_rect(cell)
			brick = _brightest(image, Rect2(LevelArena.ORIGIN + r.position * zoom, r.size * zoom).grow(-2))
			break
	print("play_level: level 3 Setup, ball brightest %s (%.3f), %d HP brick brightest %s (%.3f)" % [ball.to_html(false), ball.get_luminance(), top, brick.to_html(false), brick.get_luminance()])


func _brightest(image: Image, area: Rect2) -> Color:
	var best: Color
	for x in range(int(area.position.x), int(area.end.x)):
		for y in range(int(area.position.y), int(area.end.y)):
			var c := image.get_pixel(x, y)
			if c.get_luminance() > best.get_luminance():
				best = c
	return best


## Level `number` in Setup with tray slot `slot` held over `to`, not let go.
func _drag(main: Main, number: int, slot: int, to: Vector2) -> void:
	var level := _open(number)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var from: Vector2 = (level.get_node("SetupUi").get("_slots")[slot] as Control).get_global_rect().get_center()
	_mouse(main, from)
	_mouse(main, from, MOUSE_BUTTON_LEFT, true)
	for i in 4:
		_mouse(main, from.lerp(to, (i + 1) / 4.0))


## Level `number` with only levels up to `unlocked` open, played for a moment, then every brick broken. Level 1
## has a Bumper and a Booster placed, so its Summary shows the Placeables rows.
func _clear(main: Main, number: int, unlocked: int) -> Control:
	Progress.unlocked = unlocked
	Progress.layouts.erase(number)
	if number == 1:
		var layout := Layout.new()
		for k: Array in [[&"bumper", Vector2(300, 150)], [&"booster", Vector2(300, 380)]]:
			var item := Layout.Item.new()
			item.kind = Kinds.of(k[0])
			item.pos = k[1]
			layout.add(item)
		Progress.set_layout(1, layout)
	var level := Main.show_level(number)
	level.call("start", 7)
	(level.get("round") as Round).launch()
	for i in 20:
		await main.get_tree().physics_frame
	var round: Round = level.get("round")
	for cell: Vector2i in round.board.bricks.keys():
		while not round.over and round.board.brick(cell):
			round.hit_brick(cell, Round.Cause.BLAST, Vector2.RIGHT)
	return level


## Every level open, level 3 cleared, then Upgrades: what the hub says about level 3.
func _hub_after_final(main: Main) -> void:
	var level := await _clear(main, 3, 3)
	for i in 60:  # the round ends on its next step, which the freeze of the last explosion holds back a moment
		if (level.get("round") as Round).over:
			break
		await main.get_tree().physics_frame
	var upgrades := level.get_node("Summary").find_child("Upgrades", true, false) as Button
	upgrades.pressed.emit()
	await main.get_tree().process_frame
	var panel := (main.screen.get_child(0) as Play).get_node("Hub/Levels")
	panel.call("pick", 3)
	print("play_level: after clearing level 3, unlocked %d, the hub's level 3 status reads %s" % [Progress.unlocked, (panel.get_node("%Status") as Label).text])


func _mouse(main: Main, at: Vector2, button := MOUSE_BUTTON_NONE, pressed := false) -> void:
	var event: InputEventMouse
	if button == MOUSE_BUTTON_NONE:
		event = InputEventMouseMotion.new()
	else:
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = pressed
		event = click
	event.position = at
	event.global_position = at
	main.view.push_input(event, true)
