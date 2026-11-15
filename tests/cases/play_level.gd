extends RefCounted
## A first player's pass over the level screen, on all three levels, through the real Main and real input
## events: placing every kind of item where it may and may not go, moving, removing and turning them, the count
## limit, a Zap on and off a brick, leaving and coming back; then Play with the keys and the mouse, the HUD
## against the round, nothing to click or escape; then each of the three ends against the round's tally,
## Retry, Upgrades and the unlock. The pictures are in tests/shots/play_level.gd.
##
## The CRT is off, so a position pushed here is the position the screen gets. Keys a held paddle key needs go
## through Input.parse_input_event, which is how a real key press reaches both Input and the window.

const SETUP := 0
const PLAY := 1
const SUMMARY := 2
## Tray slots, in Kinds.placeables() order.
const BUMPER := 0
const BOOSTER := 1
const WALL := 2
const SPLITTER := 3
const ZAP := 4

var t: Node
var main: Main
var level: Control
var _last := ""


func run(p_t: Node) -> void:
	t = p_t
	Settings.crt = false
	main = (load("res://src/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	await t.tree().process_frame
	await _fresh()
	_max()
	await _placing()
	await _clear_1()
	await _level_3()
	Engine.time_scale = 1.0
	for key: Key in [KEY_S, KEY_W]:
		_hold(key, false)
	main.free()


func _max() -> void:
	Progress.unlocked = 1
	for u in Progress.upgrades():
		Progress.ranks[u.id] = u.max_rank
	Progress.save()


## A fresh save on level 1: Setup, the keys, nothing to click or escape in Play, the HUD, a ball lost, Retry.
func _fresh() -> void:
	await _open(1)
	var hud: LevelHud = level.get_node("Hud")
	var round: Round = level.round
	hud._process(0.0)
	t.check(hud._time.text == "20.0" and hud._time_tag.text == "TIME" and hud._coins.amount == 0 and hud._setup_title.visible,
			"fresh Setup: TIME 20.0, SETUP, 0 coins")
	t.check(round.balls[0].pos.x - (round.paddle.x) > 40.0, "the ball rests to the right of the paddle")

	_key(KEY_SPACE)
	t.check(level.phase == PLAY, "Space starts the round")
	round = level.round
	var speed := round.stats.paddle_speed
	var y := round.paddle.y
	_hold(KEY_S, true)
	await _steps(2)  # the tree's physics_frame signal comes before the level's _physics_process in a tick
	t.check(round.paddle.y > y, "a held S moves the paddle on the very next step")
	y = round.paddle.y
	await _steps(10)
	t.check(is_equal_approx(round.paddle.y - y, speed * 10.0 / 120.0), "and steadily: paddle speed every step (moved %.2f, wanted %.2f)" % [round.paddle.y - y, speed * 10.0 / 120.0])
	await _steps(120)
	var bottom := round.board.size().y - round.paddle.length * 0.5
	t.check(is_equal_approx(round.paddle.y, bottom), "held down, it stops at the bottom wall")
	_hold(KEY_S, false)
	await t.tree().process_frame
	var view: Node2D = level.get_node("Arena/PaddleView")
	t.check(is_equal_approx(view.position.y + round.paddle.length, bottom + round.paddle.length * 0.5), "the paddle is drawn where the round has it")
	_hold(KEY_W, true)
	await _steps(1)
	y = round.paddle.y
	_hold(KEY_W, false)
	await _steps(4)
	t.check(round.paddle.y == y, "let go, it stops at once")

	# Nothing on screen answers during Play.
	var start := level.get_node("SetupUi").find_child("Start", true, false) as Control
	var back := level.get_node("SetupUi").find_child("Back", true, false) as Control
	for at: Vector2 in [start.get_global_rect().get_center(), back.get_global_rect().get_center(), Vector2(640, 360)]:
		for b: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP]:
			_mouse(at, b, true)
			_mouse(at, b, false)
	for key: Key in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_TAB, KEY_Q, KEY_E]:
		_key(key)
	await _steps(2)
	t.check(is_instance_valid(level) and level.phase == PLAY and level.round == round and _play().get_child(-1) == level,
			"clicks, the wheel, Esc, Enter, Space, Tab, Q and E change nothing during Play")

	# The HUD against the round while a mouse plays.
	Engine.time_scale = 4.0
	var bad := []
	for i in 40:
		await _follow(6)
		if level.phase != PLAY:
			break
		level.fx.frozen = true
		await t.tree().process_frame
		var shown := "%.1f|%d|%s" % [round.time_left, round.coins, hud._left.text]
		var broken := 0
		for n: int in round.tally.broken.values():
			broken += n
		var want := "%.1f|%d|%d / %d" % [round.time_left, round.coins, round.board.remaining(), 51]
		if hud._time.text + "|" + str(hud._coins.amount) + "|" + hud._left.text != want:
			bad.append("%s != %s" % [hud._time.text + "|" + str(hud._coins.amount) + "|" + hud._left.text, want])
		level.fx.frozen = false
		if shown == "":
			break
	t.check(bad.is_empty(), "the HUD's time, coins and bricks left match the round every frame looked at %s" % [bad.slice(0, 3)])

	# Let the ball go.
	_mouse(Vector2(640, 110))
	await _until_summary(2400)
	Engine.time_scale = 1.0
	t.check(level.phase == SUMMARY and round.reason == Round.End.BALL_LOST, "a ball the paddle misses ends the round: BALL LOST")
	await _summary_shown()
	_check_summary("BALL LOST")
	t.check(Progress.coins == round.coins, "the round is paid")

	_key(KEY_ENTER)
	await t.tree().process_frame
	t.check(level.phase == SETUP and level.get_node("SetupUi").visible, "Enter on the focused Retry goes back to Setup")


## A maxed save on level 1: every placeable, legal and not, the count, moving, removing, turning, the Zap.
func _placing() -> void:
	Main.show_hub()
	await _open(1)
	var setup: LevelSetupUi = level.get_node("SetupUi")
	t.check(setup._slots.size() == 5, "a maxed save has five slots in the tray")
	var ok_spots := {
		BUMPER: [Vector2(300, 100), Vector2(300, 420), Vector2(450, 100)],
		BOOSTER: [Vector2(400, 200), Vector2(400, 330)],
		WALL: [Vector2(600, 200), Vector2(600, 330)],
		SPLITTER: [Vector2(700, 100), Vector2(720, 400), Vector2(760, 200), Vector2(740, 300), Vector2(800, 480)],
		ZAP: [Vector2(984, 100), Vector2(984, 480), Vector2(1000, 300)],
	}
	## Refused wherever the layout stands: off the grid, in the paddle lane, on the launch path, on a brick.
	var refused := {
		BUMPER: [Vector2(-30, 100), Vector2(30, 256), Vector2(984, 300), Vector2(1020, 10)],
		BOOSTER: [Vector2(1000, 32), Vector2(40, 250)],
		WALL: [Vector2(600, 10), Vector2(984, 300)],
		SPLITTER: [Vector2(984, 100), Vector2(24, 280), Vector2(1100, 100)],
		ZAP: [Vector2(600, 300), Vector2(-20, 300)],
	}
	## Refused once the first ok spot is taken: on top of it.
	var on_first := {BUMPER: Vector2(310, 110), BOOSTER: Vector2(410, 210), WALL: Vector2(604, 210), SPLITTER: Vector2(700, 100), ZAP: Vector2(984, 100)}
	for slot: int in ok_spots:
		var title := setup._slots[slot].kind.title
		for spot: Vector2 in refused[slot]:
			var before := _items().size()
			await _drag(_slot(slot), _screen(spot))
			t.check(_items().size() == before, "%s at %s is refused" % [title, spot])
		for spot: Vector2 in ok_spots[slot]:
			var before := _items().size()
			await _drag(_slot(slot), _screen(spot))
			t.check(_items().size() == before + 1, "%s at %s is placed" % [title, spot])
			if spot == ok_spots[slot][0]:
				await _drag(_slot(slot), _screen(on_first[slot]))
				t.check(_items().size() == before + 1, "%s on top of the one just placed is refused" % title)
		t.check(setup._slots[slot].left == 0, "%s: none left in the tray" % title)
		var before := _items().size()
		await _drag(_slot(slot), _screen(Vector2(200, 480)))
		t.check(_items().size() == before and level.get_node("Arena")._ghost == null, "%s: one more than the count cannot be taken from the tray" % title)

	# A Zap on a Splitter, then off a brick: a refused drop puts it back, a drop outside the arena removes it.
	var zap := _item_on(Vector2i(61, 1), &"zap")
	await _drag(_screen(Vector2(984, 100)), _screen(Vector2(728, 400)))
	t.check(_item_on(Vector2i(45, 6), &"zap") != null and _item_on(Vector2i(61, 1), &"zap") == null, "a Zap moves onto a Splitter")
	await _drag(_screen(Vector2(728, 400)), _screen(Vector2(470, 250)))
	t.check(_item_on(Vector2i(45, 6), &"zap") != null and level.round.board.brick(Vector2i(45, 6)).mod == &"zap", "a Zap dropped on nothing goes back to its brick")
	await _drag(_screen(Vector2(728, 400)), Vector2(640, 40))
	t.check(_item_on(Vector2i(45, 6), &"zap") == null and setup._slots[ZAP].left == 1, "a Zap dragged out of the arena comes off and back to the tray")
	await _drag(_slot(ZAP), _screen(Vector2(984, 100)))
	t.check(zap != null and _item_on(Vector2i(61, 1), &"zap") != null, "and it goes on a brick again")

	# Turning: the wheel and Q / E, and a turn that would hit something is not made.
	var wall := _item_at_pos(Vector2(600, 200))
	var step: float = level.round.stats.rotate_step
	_mouse(_screen(Vector2(600, 200)), MOUSE_BUTTON_WHEEL_DOWN, true)
	_mouse(_screen(Vector2(600, 200)), MOUSE_BUTTON_WHEEL_DOWN, false)
	t.check(wall != null and wall.rot == step, "the wheel turns a placed Wall Segment")
	_key(KEY_E)
	_key(KEY_Q)
	_key(KEY_Q)
	t.check(wall.rot == 0.0, "E and Q turn it each way")
	var low := _item_at_pos(Vector2(600, 330))
	for i in 6:
		_mouse(_screen(Vector2(600, 330)))
		_key(KEY_E)
	t.check(low != null and _fits_now(low), "turning never leaves an item where it does not fit")
	low.rot = 0.0
	level._on_edited(true)

	# Move one, remove one.
	await _drag(_screen(Vector2(450, 100)), _screen(Vector2(450, 470)))
	t.check(_item_at_pos(Vector2(450, 470)) != null and _item_at_pos(Vector2(450, 100)) == null, "a placed Bumper can be dragged elsewhere")
	_mouse(_screen(Vector2(450, 470)), MOUSE_BUTTON_RIGHT, true)
	_mouse(_screen(Vector2(450, 470)), MOUSE_BUTTON_RIGHT, false)
	t.check(_item_at_pos(Vector2(450, 470)) == null and setup._slots[BUMPER].left == 1, "a right click takes it off, back to the tray")

	# Leave and come back.
	var kept := JSON.stringify(level.round.layout.to_data())
	_key(KEY_ESCAPE)
	await t.tree().process_frame
	await _open(1)
	t.check(JSON.stringify(level.round.layout.to_data()) == kept, "leaving and coming back keeps the layout exactly")
	await _open(2)
	t.check(level.round.layout.items.is_empty(), "level 2 has a layout of its own")
	await _open(1)


## Level 1 maxed, everything placed: a real start, some real play, then every brick broken. The Summary, the
## unlock, Upgrades.
func _clear_1() -> void:
	var specials := _specials(level.round)
	(level.get_node("SetupUi").find_child("Start", true, false) as Button).pressed.emit()
	var round: Round = level.round
	t.check(level.phase == PLAY and round.layout.items.size() == 14 and _specials(round) == specials, "Start plays the board Setup showed")
	await _follow(30)
	for cell: Vector2i in round.board.bricks.keys():
		while not round.over and round.board.brick(cell):
			round.hit_brick(cell, Round.Cause.BLAST, Vector2.RIGHT)
	await _until_summary(240)
	t.check(round.reason == Round.End.CLEARED, "every brick broken: LEVEL CLEARED (%s)" % round.reason)
	await _summary_shown()
	_check_summary("LEVEL CLEARED")
	t.check(_texts(level.get_node("Summary")).has("Level 2 unlocked") and Progress.unlocked == 2, "the Summary says level 2 is unlocked")
	await _click(level.get_node("Summary").find_child("Upgrades", true, false))
	var panel: Control = _play().get_node("Hub/Levels")
	t.check(panel.level == 2 and (panel.get_node("%Status") as Label).text == "NOT CLEARED YET", "Upgrades: the hub offers level 2")


## Level 3, zoomed: the frame and the HUD where level 1 has them, placing in round units, a TIME end, a clear.
func _level_3() -> void:
	await _open(1)
	var rects := _ui_rects()
	Progress.unlocked = 3
	await _open(3)
	var now := _ui_rects()
	var moved := []
	for i in mini(rects.size(), now.size()):
		if rects[i] != now[i]:
			moved.append("%s -> %s" % [rects[i], now[i]])
	t.check(rects.size() == now.size() and moved.is_empty(), "level 3's HUD and footer sit exactly where level 1's do %s" % [moved])
	await _drag(_slot(BUMPER), Vector2(600, 367))
	var items := _items()
	t.check(items.size() == 1 and items[0].pos.is_equal_approx((Vector2(600, 367) - LevelArena.ORIGIN) * 18.0 / 16.0),
			"a drop on level 3 lands under the cursor (%s)" % [items.map(func(i: Layout.Item) -> Vector2: return i.pos)])
	# Whether a maxed level 3 can be cleared at all is a question for tuning (step 6, data/ only), not a check
	# here: it cannot yet, and tests/cases/contracts.gd prints how far a maxed round gets on every run. The
	# bot (tests/run.sh bot) is the tool for it.
	_key(KEY_SPACE)
	var round: Round = level.round
	round.time_left = 0.5
	await _follow(120)
	t.check(round.reason == Round.End.TIME, "the clock running out ends the round: TIME UP")
	await _summary_shown()
	_check_summary("TIME UP")
	await _click(level.get_node("Summary").find_child("Retry", true, false))
	_key(KEY_SPACE)
	round = level.round
	for cell: Vector2i in round.board.bricks.keys():
		while not round.over and round.board.brick(cell):
			round.hit_brick(cell, Round.Cause.BLAST, Vector2.RIGHT)
	await _until_summary(240)
	await _summary_shown()
	_check_summary("LEVEL CLEARED")
	t.check(_texts(level.get_node("Summary")).has("Every brick broken"), "clearing the last level says every brick broken")
	_key(KEY_ESCAPE)
	await t.tree().process_frame
	var panel: Control = _play().get_node("Hub/Levels")
	panel.pick(3)  # this case opened level 3 by Main.show_level, so the kept hub is still on level 2
	t.check((panel.get_node("%Status") as Label).text == "CLEARED",
			"after clearing level 3, the last level, the hub says so (it says %s)" % (panel.get_node("%Status") as Label).text)
	Main.show_menu()
	Main.show_hub()
	await t.tree().process_frame
	panel = _play().get_node("Hub/Levels")
	t.check(panel.level == 3 and (panel.get_node("%Status") as Label).text == "CLEARED" and not (panel.get_node("%Play") as Button).disabled,
			"a new hub on a won save opens on the last level, cleared and playable (level %d)" % panel.level)


## The Summary on screen against the round: the title, the hint, one row per kind with its count and coins, the
## total.
func _check_summary(title: String) -> void:
	var round: Round = level.round
	var summary: Control = level.get_node("Summary")
	var texts := _texts(summary)
	t.check(texts.has(title), "the Summary is titled %s (%s)" % [title, texts.slice(0, 3)])
	var left := round.board.remaining()
	if round.reason != Round.End.CLEARED:
		t.check(texts.has("%d brick%s left" % [left, "" if left == 1 else "s"]), "it says how many bricks are left (%d)" % left)
	var grid := summary.find_children("*", "GridContainer", true, false)[0] as GridContainer
	var rows := {}
	for i in range(0, grid.get_child_count(), 4):
		var name_text := (grid.get_child(i + 1) as Label).text
		var last := grid.get_child(i + 3)
		rows[name_text] = [int((grid.get_child(i + 2) as Label).text), (last as UiPrice).amount if last is UiPrice else (last as Label).text]
	var sum := 0
	for id: StringName in round.tally.broken:
		var kind := Kinds.of(id)
		var row: Array = rows.get(kind.title if kind else "Bricks", [])
		t.check(row.size() == 2 and row[0] == round.tally.broken[id], "a %s row counts %d" % [kind.title if kind else "Bricks", round.tally.broken[id]])
		if row.size() == 2 and row[1] is int:
			sum += row[1]
	if round.tally.placed_broken:
		t.check(rows.get("Placed bricks", [0])[0] == round.tally.placed_broken, "a Placed bricks row counts them")
	var total := summary.find_children("*", "UiPrice", true, false).filter(func(p: UiPrice) -> bool: return p.style == &"HudNumber")
	t.check(total.size() == 1 and total[0].amount == round.coins and sum == round.coins, "the rows add up to the total, which is the round's coins (%d, %d, %d)" % [sum, total[0].amount if total else -1, round.coins])
	var first := "Next" if round.reason == Round.End.CLEARED and level.level < Progress.level_count else "Retry"
	var focused := summary.find_child(first, true, false) as Button
	var upgrades := summary.find_child("Upgrades", true, false) as Button
	t.check(focused.has_focus() and focused.theme_type_variation == &"" and upgrades.theme_type_variation == &"SecondaryButton",
			"%s has the focus, and it is the filled one" % first)
	upgrades.mouse_entered.emit()
	t.check(upgrades.has_focus() and upgrades.theme_type_variation == &"" and focused.theme_type_variation == &"SecondaryButton",
			"the mouse moves the Summary's selection, as on the main menu")
	focused.grab_focus()


func _ui_rects() -> Array:
	var out := []
	for path: String in ["Hud", "SetupUi"]:
		for c: Control in level.get_node(path).find_children("*", "Control", true, false):
			if c.is_visible_in_tree() and not c is LevelSetupUi.Slot and c.get_parent() is not LevelSetupUi.Slot and not c.get_parent().get_parent() is LevelSetupUi.Slot:
				if c.name in ["Back", "Start"] or c.get_parent() == level.get_node("Hud"):
					out.append(c.get_global_rect())
	return out


func _open(number: int) -> void:
	level = Main.show_level(number)
	await t.tree().process_frame
	await t.tree().process_frame


func _play() -> Play:
	return main.screen.get_child(0) as Play


## Physics ticks, with the mouse level with the nearest ball that comes this way.
func _follow(n: int) -> void:
	for i in n:
		if level.phase != PLAY:
			break
		var round: Round = level.round
		if not round.balls.is_empty():
			var ball := round.balls[0]
			for other in round.balls:
				if other.dir.x < 0.0 and (ball.dir.x >= 0.0 or other.pos.x < ball.pos.x):
					ball = other
			_mouse(_screen(Vector2(0, ball.pos.y)))
			_last = "ball %s dir %s, paddle y %.1f, %.2f s in" % [ball.pos.round(), ball.dir, round.paddle.y, round.stats.round_time - round.time_left]
		await t.tree().physics_frame
	if level.phase != PLAY and level.round.reason == Round.End.BALL_LOST:
		print("play_level: a paddle kept level with the ball lost it on level %d: %s" % [level.round.board.rows, _last])


func _steps(n: int) -> void:
	for i in n:
		if level.phase == PLAY and not level.round.balls.is_empty():
			level.round.balls[0].put(Vector2(500, 30), Vector2.RIGHT)
		await t.tree().physics_frame


func _until_summary(frames: int) -> void:
	for i in frames:
		if level.phase == SUMMARY:
			return
		await t.tree().physics_frame


## The Summary's panel is up and its rows are counted. Ten times the speed, so the wait is 0.2 s.
func _summary_shown() -> void:
	Engine.time_scale = 10.0
	await t.tree().create_timer(LevelSummary.DELAY + 1.5).timeout
	Engine.time_scale = 1.0


func _screen(units: Vector2) -> Vector2:
	return LevelArena.ORIGIN + units * level.round.board.zoom()


func _slot(index: int) -> Vector2:
	return (level.get_node("SetupUi")._slots[index] as Control).get_global_rect().get_center()


func _items() -> Array[Layout.Item]:
	return level.round.layout.items


func _item_on(cell: Vector2i, kind: StringName) -> Layout.Item:
	for item in _items():
		if item.kind.id == kind and item.cell == cell:
			return item
	return null


func _item_at_pos(pos: Vector2) -> Layout.Item:
	for item in _items():
		if item.kind.placement == PlaceableKind.Placement.FREE and item.pos.is_equal_approx(pos):
			return item
	return null


func _fits_now(item: Layout.Item) -> bool:
	var layout: Layout = level._layout
	layout.remove(item)
	var ok := layout.fits(item, level._data.board, level._stats)
	layout.add(item)
	return ok


func _specials(round: Round) -> Dictionary:
	var out := {}
	for cell: Vector2i in round.board.bricks:
		if round.board.bricks[cell].kind and not round.board.bricks[cell].placed:
			out[cell] = round.board.bricks[cell].kind
	return out


func _texts(under: Node) -> Array:
	return under.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	_mouse(at)
	for pressed: bool in [true, false]:
		_mouse(at, MOUSE_BUTTON_LEFT, pressed)
		await t.tree().process_frame


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(from)
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


## Presses and releases `key`, into the window.
func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		t.get_viewport().push_input(event, true)


## Holds or lets go of `key` as the OS would report it: through Input, so Input.get_axis sees it too.
func _hold(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
