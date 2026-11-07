extends Node
## Runs one round headless and pokes every mechanic once: godot --headless tests/smoke.tscn. Any script error prints.
## (A scene, not -s, so the Game autoload exists.)

const Tuning = preload("res://src/tuning.gd")


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)  # headless starts 64x64; at that size the arena is a 100 px thumbnail and physics misses collisions
	# The round saves at the end; put the real save back afterwards.
	var saved := FileAccess.get_file_as_string(Game.SAVE_PATH) if FileAccess.file_exists(Game.SAVE_PATH) else ""
	# Own one of everything and enough capacity to place it all.
	for k in Tuning.PLACEABLES:
		Game.ranks[k] = 1
	Game.ranks["capacity"] = 10  # ranks are not capped here; all pieces together cost more than max capacity
	var Ui = load("res://src/ui.gd")  # needs the Game autoload, so it is checked here and not in test.gd
	assert(Ui.money(0) == "0" and Ui.money(999) == "999" and Ui.money(1248) == "1,248" and Ui.money(1234567) == "1,234,567", "cash gets thousands separators")
	var a = load("res://src/arena.gd").new()
	a.level = Tuning.LEVELS.size() - 1
	add_child(a)
	await get_tree().process_frame
	# Place one of each in a row under the board, then hover and drop like the mouse would.
	var x := 60.0
	for k in Tuning.PLACEABLES:
		a.place._take(k)
		assert(a.place.holding != null and a.place.holding.kind == k, "took %s" % k)
		a.place.holding.position = Vector2(x, a.place_y() - 60)
		x += 120
		a.place.holding.overlay(null)
		a.place.holding = null
	a.place._hover(a.place.placed[0])
	a.place._start()
	assert(a.placed.size() == Tuning.PLACEABLES.size() and not a.place.placing, "all placed and handed to the arena")
	a._launch()
	await get_tree().physics_frame
	# Pause menu: open, swap to settings and back, resume.
	a._pause(true)
	assert(get_tree().paused and a.pause != null, "paused with a menu")
	assert(a.pause.sheet.size * a.pause.sheet.scale == get_viewport().get_visible_rect().size, "pause overlay covers the whole canvas")
	a._pause_settings()
	assert(await _click(a.pause, "BACK") and a.pause and _button(a.pause, "RESUME"), "settings BACK clicks back to the pause menu")
	assert(await _click(a.pause, "RESUME") and not get_tree().paused and a.pause == null, "RESUME clicks through")
	a._pause(true)
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert(not get_tree().paused and a.pause == null, "Esc resumes")

	# Icon effects and area breaks, each on a real brick.
	var ball = a.balls[0]
	for k in Tuning.ICON_KINDS:
		var b = a._bricks("plain").front()
		a._effect(k, b)
	assert(a.balls.size() > 1, "multiball added a ball")
	# Refusals: a slow ball on a cond brick, low combo on a gate, out-of-order sequence.
	a.combo = 0
	ball.speed = 1.0
	for k in ["cond", "cgate", "seq3", "timed"]:
		for b in a._bricks(k):
			a._damage(b, ball)
	assert(not a._bricks("cond").is_empty() and not a._bricks("cgate").is_empty(), "refused bricks still stand")
	# Multi-hit faces and shield.
	for k in ["multi", "multi3", "shield"]:
		for b in a._bricks(k):
			a._damage(b, ball)
			assert(b.hp == Tuning.BRICKS[k].hp - 1, "%s took one hit" % k)
	# Pass-through pieces act on the ball.
	for p in a.placed:
		if Tuning.PLACEABLES[p.kind].get("thru", false):
			ball.grace = 0
			ball.hold = 0
			a._pass(p, ball)
			if p.kind == "sticky":
				assert(ball.hold > 0, "sticky pad holds the ball")
		else:
			a._hit(p, ball)
	ball.hold = 0
	for i in 800:  # keep the spawner charging past SPAWN_EVERY
		await get_tree().physics_frame
		if a.over:
			break
	a._end("Time's up")  # builds the result panel
	await get_tree().create_timer(1.1).timeout  # let its delayed cues fire, else they leak at quit
	var total := 0
	for v in a.tally.values():
		total += v
	assert(total == a.earned, "tally lines sum to earned")
	assert(a.combos.all(func(c): return c[0] > 1), "combo runs are 2+")
	var hit := [false, false]
	a.again.connect(func(): hit[0] = true)
	a.done.connect(func(): hit[1] = true)
	var res: Node = a.hud.get_child(a.hud.get_child_count() - 1)
	assert(await _click(res, "PLAY AGAIN") and hit[0], "result PLAY AGAIN clicks through")
	assert(await _click(res, "UPGRADES") and hit[1], "result UPGRADES clicks through")
	hit[1] = false
	_key(KEY_ESCAPE)
	assert(hit[1], "Esc on the result goes to upgrades")
	var fx: int = a.get_children().filter(func(c): return c is AnimatedSprite2D).size()
	print("smoke ok: over=%s earned=%d balls=%d placed=%d fx=%d" % [a.over, a.earned, a.balls.size(), a.placed.size(), fx])

	# Sandbox: the shop builds with every node lit, a round starts with every upgrade on, and leaving forgets it all.
	Game.enter_sandbox()
	var shop = load("res://src/shop.gd").new()
	add_child(shop)
	await get_tree().process_frame
	assert(Tuning.UPGRADES.keys().all(Game.is_revealed) and Game.rank("twin") == 1, "sandbox reveals and maxes the web")
	shop.queue_free()
	var sb = load("res://src/arena.gd").new()
	add_child(sb)
	await get_tree().process_frame
	assert(sb.shields == Tuning.UPGRADES.shield.ranks and sb.place_y() == sb.field.size.y - (Tuning.PLACE_UP + Tuning.UPGRADES.floor.amount * Tuning.UPGRADES.floor.ranks), "sandbox round has shield floors and a lower floor")
	sb.place._start()
	sb._launch()
	assert(sb.balls.size() == 1 + Tuning.UPGRADES.balls.ranks, "extra balls launch")
	sb.balls[0].position.y = sb.field.size.y + 1  # drop one onto the shield floor
	await get_tree().physics_frame  # fires before the step runs, so wait out a whole one
	await get_tree().physics_frame
	assert(sb.shields == Tuning.UPGRADES.shield.ranks - 1 and sb.balls.size() == 1 + Tuning.UPGRADES.balls.ranks, "shield floor catches a dropped ball")
	sb._end("Abandoned")
	await get_tree().create_timer(1.1).timeout
	sb.queue_free()
	Game.leave_sandbox()
	assert(not Game.sandbox and Game.rank("twin") == 0, "leaving the sandbox forgets it")
	if saved:
		FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE).store_string(saved)
	else:
		DirAccess.remove_absolute(Game.SAVE_PATH)
	Game.load_save()
	load("res://src/sfx.gd").quit()  # not get_tree().quit(): a cue still mixing at exit logs a leak


func _button(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


## A real mouse press and release at the button's centre, through the viewport's GUI picking. True when it was found.
func _click(root: Node, text: String) -> bool:
	var b := _button(root, text)
	if not b:
		return false
	var at := get_viewport().get_final_transform() * b.get_global_rect().get_center()
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		get_viewport().push_input(e)
		await get_tree().process_frame
	return true


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	get_viewport().push_input(e)
