extends RefCounted
## The level screen, driven through the real scene under the real Main: the seam with the effects, placing in
## Setup, the paddle in Play, the three ends, the Summary, Retry and the ways back.
##
## Every upgrade is owned, so all five placeables are in the tray and special bricks are rolled. The CRT is off,
## so a mouse position pushed here is the position the screen gets.

const ORIGIN := Vector2(154, 110)
const SETUP := 0
const PLAY := 1
const SUMMARY := 2
## Tray slots, in Kinds.placeables() order.
const BOOSTER := 0
const WALL := 1
const SPLITTER := 2
const ZAP := 3

var t: Node
var main: Main
var level: Control
var heard: Array[StringName] = []
var paid := [0]


func run(p_t: Node) -> void:
	t = p_t
	Settings.crt = false
	for u in Progress.upgrades():
		Progress.ranks[u.id] = 1  # one rank of each: the checks count one of every item and special brick
	# A longer paddle has no room for the moves _paddle makes.
	Progress.ranks[&"paddle_size"] = 0
	main = (load("res://src/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	var on_played := func(cue: StringName, _player: AudioStreamPlayer) -> void: heard.append(cue)
	var on_paid := func(_coins: int) -> void: paid[0] += 1
	Sfx.played.connect(on_played)
	Progress.coins_changed.connect(on_paid)
	await _seam()
	await _placing()
	await _leaving()
	await _paddle()
	await _ends()
	Sfx.played.disconnect(on_played)
	Progress.coins_changed.disconnect(on_paid)
	Input.action_release(&"paddle_up")
	Input.action_release(&"paddle_down")
	main.free()


## What play.gd and fx.gd say the level's root and its tree are.
func _seam() -> void:
	await _open(3)
	var round: Round = level.round
	var arena: Node2D = level.get_node("Arena")
	t.check(level.level == 3 and round != null and level.fx is Fx and level.has_method("start"), "the root has level, round, fx and start")
	t.check(level.phase == SETUP and not round.over and round.time_left == round.stats.round_time, "a level opens in Setup, on a round that has not begun")
	t.check(arena.position == ORIGIN and arena.scale.is_equal_approx(Vector2.ONE * 16.0 / 18.0), "Arena is at (154, 110), scaled by the level's zoom")
	t.check(arena.get_child(-1) == level.fx and level.fx.z_index == 0 and arena.z_index == 0, "Fx is the last child of Arena, and both are at z 0")
	for child: Node2D in arena.get_children():
		if child.name == &"Ghost":
			t.check(child.z_index > (level.get_node("SetupUi") as Control).z_index, "the ghost draws over SetupUi, so a held item shows over the tray")
		else:
			t.check(child == level.fx or child.z_index in [0, 10, 20], "%s is at z 0, 10 or 20" % child.name)
	t.check(arena.get_child_count() < 10 and round.board.bricks.size() == 512, "512 bricks are drawn by one node, not by 512")
	for part: String in ["Hud", "SetupUi", "Summary"]:
		t.check((level.get_node(part) as Control).z_index == 100, "%s is at z 100" % part)
	t.check(_specials(round).size() == 5, "Setup shows this attempt's special bricks")
	# Called by hand, here and for the freeze below: the real effects set shake and frozen themselves every frame.
	level.fx.shake = Vector2(3, -2)
	arena._process(0.0)
	t.check(arena.position == ORIGIN + Vector2(3, -2), "Arena follows the effects' shake")
	level.fx.shake = Vector2.ZERO
	# Level 3 has 1 and 2 HP bricks, and the tough brick rolled on it has 3: it shows as its HP step, not by name.
	level.start(7)
	var legend: Array = _texts(level.get_node("Hud")._legend).filter(func(s: String) -> bool: return s.ends_with("HP"))
	t.check(legend == ["1 HP", "2 HP", "3 HP"] and not _texts(level.get_node("Hud")._legend).has("TOUGH"),
			"Play's legend lists every HP step up to the board's toughest brick, a tough brick's too, and no TOUGH entry (%s)" % [legend])
	# No level has a brick over 2 HP, so the top step is checked on a brick made tougher than the palette goes.
	(round.board.bricks.values().filter(func(b: Brick) -> bool: return b.kind == &"")[0] as Brick).hp = 6
	level.get_node("Hud").show_round(round, Levels.read(3), false, true)
	legend = _texts(level.get_node("Hud")._legend).filter(func(s: String) -> bool: return s.ends_with("HP"))
	t.check(legend == ["1 HP", "2 HP", "3 HP", "4+ HP"], "the legend stops at the palette's top step, 4+ HP (%s)" % [legend])

	# The hint names turning only when something in the tray turns: of the placeables the Booster and the Wall Segment do.
	var ranks := Progress.ranks.duplicate()
	for only: Array in [[&"splitter", false], [&"booster", true]]:
		Progress.ranks.clear()
		Progress.ranks[only[0]] = 1
		await _open(1)
		var hint: String = level.get_node("Hud")._hint.text.replace("\n", " / ")
		t.check(hint.containsn("right-click removes one") and hint.contains("turns") == only[1],
				"with only a %s, Setup's hint %s turning (%s)" % [only[0], "names" if only[1] else "leaves out", hint])
	Progress.ranks = ranks


## Setup: drag to place, move and remove; refusals; rotation; snapping; each change saved.
func _placing() -> void:
	await _open(1)
	var at := Vector2(300, 100)
	var arena: LevelArena = level.get_node("Arena")
	_mouse(_slot(BOOSTER), MOUSE_BUTTON_LEFT, true)
	t.check(arena._ghost != null and arena._ghost_fits, "a press on a tray slot shows the item at once, in the look of one that fits")
	_mouse(_slot(BOOSTER), MOUSE_BUTTON_LEFT, false)
	t.check(arena._ghost == null and _items().is_empty(), "let go over the tray, it goes back")
	heard.clear()
	await _drag(_slot(BOOSTER), _screen(at))
	var items := _items()
	t.check(items.size() == 1 and items[0].kind.id == &"booster" and items[0].pos.is_equal_approx(at), "a drag from the tray places the item where it is dropped")
	t.check(Progress.layout(1).count(&"booster") == 1 and _saved().layouts["1"].size() == 1, "placing saves the level's layout")
	await t.tree().create_timer(0.15).timeout
	t.check(heard.has(Sfx.PLACE_ITEM), "putting an item down plays PLACE_ITEM")
	for spot: Vector2 in [Vector2(-30, 100), Vector2(870, 100), Vector2(30, 224), Vector2(300, 100)]:
		await _drag(_slot(BOOSTER), _screen(spot))
		t.check(_items().size() == 1, "a booster at %s is refused: the lane, a brick, the launch path, another item" % spot)
	await _drag(_screen(at), _screen(Vector2(400, 200)))
	t.check(_items().size() == 1 and _items()[0].pos.is_equal_approx(Vector2(400, 200)), "a placed item can be dragged somewhere else")
	await _drag(_screen(Vector2(400, 200)), _screen(Vector2(870, 100)))
	t.check(_items().size() == 1 and _items()[0].pos.is_equal_approx(Vector2(400, 200)), "moved onto a brick, it goes back where it was")
	await _drag(_screen(Vector2(400, 200)), Vector2(640, 50))
	t.check(_items().is_empty() and Progress.layout(1).items.is_empty(), "dragged out of the arena, it is removed")
	await _drag(_slot(BOOSTER), _screen(at))
	_mouse(_screen(at), MOUSE_BUTTON_RIGHT, true)
	t.check(_items().is_empty(), "a right click removes the item under it")
	await _drag(_slot(BOOSTER), _screen(at))

	# Rotation: the wheel while dragging, then Q and E over the placed item.
	var wall := Vector2(400, 380)
	_mouse(_slot(WALL), MOUSE_BUTTON_LEFT, true)
	_mouse(_screen(wall))
	_mouse(_screen(wall), MOUSE_BUTTON_WHEEL_DOWN, true)
	_mouse(_screen(wall), MOUSE_BUTTON_LEFT, false)
	await t.tree().process_frame
	var step: float = level.round.stats.rotate_step
	t.check(_rot(&"wall_segment") == step, "the wheel turns the item being dragged by one step")
	_key(KEY_E)
	_key(KEY_E)
	t.check(_rot(&"wall_segment") == step * 3.0, "E turns the item under the cursor clockwise")
	_key(KEY_Q)
	t.check(_rot(&"wall_segment") == step * 2.0 and is_equal_approx(_saved().layouts["1"][1].rot, step * 2.0), "Q turns it back, and the turn is saved")
	_mouse(_screen(at))
	_key(KEY_E)
	t.check(_rot(&"booster") == step, "a Booster turns as well")

	# A placeable brick snaps to its cell; a brick mod goes on a brick and nowhere else.
	await _drag(_slot(SPLITTER), _screen(Vector2(333, 140)))
	var brick: Brick = level.round.board.brick(Vector2i(20, 2))
	t.check(brick != null and brick.placed and brick.kind == &"splitter", "a Splitter snaps to the brick cell under the cursor")
	await _drag(_slot(ZAP), _screen(Vector2(600, 300)))
	t.check(_items().size() == 3, "a Zap on an empty cell is refused")
	await _drag(_slot(ZAP), _screen(Vector2(870, 224)))
	t.check(level.round.board.brick(Vector2i(54, 3)).mod == &"zap" and _items().size() == 4, "a Zap goes on an existing brick")
	t.check(level.get_node("SetupUi")._slots[BOOSTER].left == 0 and level.get_node("SetupUi")._slots[ZAP].left == 0, "the tray counts what is left to place")


## Esc goes back to the hub and no further, and the layout is there on the way back in.
func _leaving() -> void:
	var was: Control = level
	_key(KEY_ESCAPE)
	await t.tree().process_frame
	var play := main.screen.get_child(0) as Play
	t.check(play != null and play._hub.visible and not is_instance_valid(was), "Esc in Setup goes to the hub, and one Esc goes no further")
	Progress.use(Progress.path)  # from the file, as a new session would
	await _open(1)
	t.check(_items().size() == 4 and _rot(&"wall_segment") == level.round.stats.rotate_step * 2.0, "the layout is on the board when the level is opened again")
	var back: Button = level.get_node("SetupUi").find_child("Back", true, false)
	back.pressed.emit()
	await t.tree().process_frame
	t.check(play._hub.visible and not is_instance_valid(level), "the back button goes to the hub too")
	await _open(1)


## Start, and the paddle under the keys and the mouse.
func _paddle() -> void:
	var shown := _specials(level.round)
	var setup_round: Round = level.round
	var start: Button = level.get_node("SetupUi").find_child("Start", true, false)
	t.check(start.is_in_group(Sfx.QUIET), "Start plays no click: the round start is its sound")
	var rest := setup_round.balls[0].pos
	Input.action_press(&"paddle_down")
	await _steps(12)
	Input.action_release(&"paddle_down")
	var setup_y := setup_round.paddle.y
	rest = setup_round.balls[0].pos
	t.check(setup_y > setup_round.board.size().y * 0.5 and rest == Vector2(setup_round.paddle.x + setup_round.stats.ball_size * 0.5, setup_y) and level.round == setup_round,
			"in Setup a key moves the paddle and the ball rides on its face")
	level.start()
	var round: Round = level.round
	t.check(round.paddle.y == setup_y and round.balls[0].pos == rest and round.held, "Start keeps the paddle where Setup left it, with the ball held on it")
	t.check(level.phase == PLAY and round != setup_round and _specials(round) == shown, "start() goes to Play on a new round with the special bricks Setup showed")
	t.check(round.layout.items.size() == 4 and round.ball_bounced.is_connected(Sfx._on_ball_bounced) and round.ended.get_connections().size() >= 2,
			"start() is complete when it returns: the round has the layout, and the sound and the screen are listening")
	t.check(not level.get_node("SetupUi").visible, "Setup's tray is gone in Play")
	level.start(3)
	t.check(level.round == round, "start() does nothing outside Setup")
	var speed := round.stats.paddle_speed
	var y := round.paddle.y

	await _steps(12)
	t.check(round.paddle.y == y, "the paddle waits where it is until the player moves")
	Input.action_press(&"paddle_up")
	await _steps(12)
	t.check(absf((y - round.paddle.y) - speed * 0.1) < speed * 0.02, "a held key moves the paddle at paddle speed, from the first step")
	Input.action_release(&"paddle_up")
	y = round.paddle.y
	await _steps(6)
	t.check(round.paddle.y == y, "the paddle stops when the key is let go")

	_mouse(_screen(Vector2(0, 350)))
	await _steps(6)
	t.check(round.paddle.y - y > speed * 0.03 and round.paddle.y - y < speed * 0.06, "the paddle chases the mouse's height at paddle speed, from the first step")
	await _steps(120)
	t.check(is_equal_approx(round.paddle.y, 350.0), "it stops on the mouse's height, without overshooting")
	await _steps(6)
	t.check(is_equal_approx(round.paddle.y, 350.0), "and stays there")

	Input.action_press(&"paddle_up")
	await _steps(12)
	Input.action_release(&"paddle_up")
	y = round.paddle.y
	t.check(y < 350.0 - speed * 0.08, "a key takes the paddle from the mouse at once")
	_mouse(_screen(Vector2(0, 350)) + Vector2(0, 2))
	await _steps(12)
	t.check(round.paddle.y == y, "after a key, a mouse that only trembles does not pull the paddle back")
	_mouse(_screen(Vector2(0, 300)))
	await _steps(4)
	t.check(round.paddle.y != y, "a mouse that moves takes the paddle back")

	# The pointer leaves the window low down: Main clears hover with a motion far outside the frame.
	_mouse(_screen(Vector2(0, 430)))
	await _steps(240)
	y = round.paddle.y
	main._notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	await _steps(120)
	t.check(y > 350.0 and round.paddle.y == y, "the pointer leaving the window leaves the paddle where it was (%.0f, then %.0f)" % [y, round.paddle.y])
	# Only that motion is ignored. A real pointer outside the frame is in a wide screen's bars, or at the left
	# edge, which the CRT's curve puts a few pixels outside: the paddle's own edge.
	_mouse(Vector2(-40, _screen(Vector2(0, 200)).y))
	await _steps(240)
	t.check(is_equal_approx(round.paddle.y, 200.0), "a pointer left of the frame still steers the paddle (%.0f)" % round.paddle.y)

	_key(KEY_ESCAPE)
	await _steps(2)
	t.check(is_instance_valid(level) and level.phase == PLAY and not (main.screen.get_child(0) as Play)._hub.visible, "Esc does nothing during Play")
	round.launch()
	var left := round.time_left
	level.fx.frozen = true
	level._physics_process(1.0 / 120.0)
	t.check(round.time_left == left, "the round does not step while the effects hold a freeze")
	level.fx.frozen = false
	level._physics_process(1.0 / 120.0)
	t.check(round.time_left < left, "and steps again after it")


## The three ends: each reaches the Summary and pays once. Retry, and the clear that unlocks level 2.
func _ends() -> void:
	# The last ball lost, with something broken first: it is still paid.
	var round: Round = level.round
	var coins := Progress.coins
	paid[0] = 0
	for row in 7:  # column 54 is 1 HP; one that is still a standard brick
		if round.board.brick(Vector2i(54, row)).kind == &"":
			round.hit_brick(Vector2i(54, row), Round.Cause.BALL, Vector2.RIGHT)
			break
	round.spares = 0  # Spare Ball is owned: with one in reserve the ball lost would not be the last
	if round.waiting:  # with no spare_delay, one is already on the paddle: it came unannounced, so it goes the same way
		round.balls.erase(round.waiting)
		round.waiting = null
	round.balls[0].put(Vector2(-20.0, 20.0 if round.paddle.y > 224.0 else 428.0), Vector2.LEFT)
	await _until_summary()
	t.check(level.phase == SUMMARY and round.reason == Round.End.BALL_LOST, "losing the last ball ends the round in the Summary")
	await _steps(12)
	t.check(round.coins > 0 and Progress.coins == coins + round.coins and paid[0] == 1 and _saved().coins == Progress.coins, "the round is paid once, and saved")
	t.check(Progress.unlocked == 1, "a round that is not cleared unlocks nothing")
	heard.clear()
	await t.tree().create_timer(2.5).timeout
	var summary: Control = level.get_node("Summary")
	t.check(summary.visible and _texts(summary).has("BALL LOST"), "the Summary says how the round ended")
	t.check(_texts(summary).has("Bricks") and _texts(summary).has(str(round.coins)), "it lists the bricks broken and the coins paid")
	t.check(heard.has(Sfx.TALLY_TICK), "the tally ticks as it counts")

	# Retry: Setup again, a new round, the special bricks rolled again, the layout still there.
	var before := _specials(round)
	(summary.find_child("Retry", true, false) as Button).pressed.emit()
	await t.tree().process_frame
	t.check(level.phase == SETUP and level.round != round and not level.round.over and level.round.time_left == round.stats.round_time, "Retry goes back to Setup with a new round")
	t.check(_specials(level.round) != before and _specials(level.round).size() == before.size(), "Retry rolls the special bricks again")
	t.check(_items().size() == 4 and not summary.visible and level.get_node("SetupUi").visible, "the layout is still on the board after Retry")

	# The timer running out. Start is pressed this time.
	(level.get_node("SetupUi").find_child("Start", true, false) as Button).pressed.emit()
	round = level.round
	round.launch()
	t.check(level.phase == PLAY, "the Start button starts the round")
	coins = Progress.coins
	paid[0] = 0
	round.time_left = 0.03
	await _until_summary()
	await _steps(12)
	t.check(round.reason == Round.End.TIME and paid[0] == 1 and Progress.coins == coins + round.coins, "the timer running out ends the round in the Summary, paid once")
	_key(KEY_SPACE)
	t.check(level.phase == SUMMARY, "Space starts nothing outside Setup")
	(level.get_node("Summary").find_child("Retry", true, false) as Button).pressed.emit()
	_key(KEY_SPACE)
	t.check(level.phase == PLAY, "Space starts the round in Setup")

	# Every brick broken.
	round = level.round
	coins = Progress.coins
	paid[0] = 0
	for cell: Vector2i in round.board.bricks.keys():
		while round.board.brick(cell):
			round.hit_brick(cell, Round.Cause.BLAST, Vector2.RIGHT)
	await _until_summary()
	await _steps(12)
	t.check(round.reason == Round.End.CLEARED and paid[0] == 1 and Progress.coins == coins + round.coins, "clearing the level ends the round in the Summary, paid once")
	t.check(Progress.unlocked == 2 and _saved().unlocked == 2, "clearing level 1 unlocks level 2")
	await t.tree().create_timer(0.7).timeout
	t.check(_texts(level.get_node("Summary")).has("LEVEL CLEARED") and _texts(level.get_node("Summary")).has("Level 2 unlocked"), "the Summary says the level was cleared and what it unlocked")
	var next := level.get_node("Summary").find_child("Next", true, false) as Button
	t.check(next != null and next.has_focus() and level.get_node("Summary").find_child("Retry", true, false) == null, "a clear offers Next, focused, in Retry's place")
	var was: Control = level
	_key(KEY_ESCAPE)
	await t.tree().process_frame
	var play := main.screen.get_child(0) as Play
	t.check(play != null and play._hub.visible and not is_instance_valid(was), "Esc in the Summary goes to the hub, and no further")
	t.check(is_equal_approx(main.env.glow_intensity, Main.GLOW), "leaving puts the bloom back to rest")

	# Next: clear level 1 again, and Next opens level 2 in Setup.
	await _open(1)
	_key(KEY_SPACE)
	round = level.round
	for cell: Vector2i in round.board.bricks.keys():
		while round.board.brick(cell):
			round.hit_brick(cell, Round.Cause.BLAST, Vector2.RIGHT)
	await _until_summary()
	await t.tree().create_timer(0.7).timeout
	was = level
	(level.get_node("Summary").find_child("Next", true, false) as Button).pressed.emit()
	await t.tree().process_frame
	level = play._level
	t.check(level != null and level.level == 2 and level.phase == SETUP and not is_instance_valid(was), "Next opens level 2 in Setup and frees level 1")
	t.check(is_equal_approx(main.env.glow_intensity, Main.GLOW), "Next puts the bloom back to rest")


func _open(number: int) -> void:
	level = Main.show_level(number)
	await t.tree().process_frame
	await t.tree().process_frame  # the footer is laid out


## Physics ticks with the ball held out of the way, so nothing ends the round meanwhile.
func _steps(n: int) -> void:
	for i in n:
		if level.phase == PLAY and not level.round.balls.is_empty():
			level.round.balls[0].put(Vector2(500, 30), Vector2.RIGHT)
		await t.tree().physics_frame


func _until_summary() -> void:
	for i in 120:  # a second: the effects may freeze the round for a moment on the last hit
		if level.phase == SUMMARY:
			return
		await t.tree().physics_frame


func _screen(units: Vector2) -> Vector2:
	return ORIGIN + units * level.round.board.zoom()


func _slot(index: int) -> Vector2:
	return (level.get_node("SetupUi")._slots[index] as Control).get_global_rect().get_center()


func _items() -> Array[Layout.Item]:
	return level.round.layout.items


func _rot(kind: StringName) -> float:
	for item in _items():
		if item.kind.id == kind:
			return item.rot
	return NAN


## The special bricks of a round: brick cell -> kind id.
func _specials(round: Round) -> Dictionary:
	var out := {}
	for cell: Vector2i in round.board.bricks:
		var brick := round.board.bricks[cell]
		if brick.kind and not brick.placed:
			out[cell] = brick.kind
	return out


func _texts(under: Node) -> Array:
	return under.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _saved() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Progress.path))


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(from, MOUSE_BUTTON_LEFT, true)
	_mouse(from.lerp(to, 0.5))
	_mouse(to)
	_mouse(to, MOUSE_BUTTON_LEFT, false)
	await t.tree().process_frame


func _mouse(at: Vector2, button := MOUSE_BUTTON_NONE, pressed := false) -> void:
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
	t.get_viewport().push_input(event, true)


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	t.get_viewport().push_input(event, true)
