extends Node
## Runs one round headless and pokes every mechanic once: godot --headless tests/smoke.tscn. Any script error prints.
## (A scene, not -s, so the Game autoload exists.)

const Tuning = preload("res://src/tuning.gd")


func _ready() -> void:
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
		a._take(k)
		assert(a.holding != null and a.holding.kind == k, "took %s" % k)
		a.holding.position = Vector2(x, Tuning.PLACE_MAX_Y - 60)
		x += 120
		a.holding.overlay(null)
		a.holding = null
	a._hover(a.placed[0])
	a._start()
	assert(a.placed.size() == Tuning.PLACEABLES.size(), "all placed")
	a._launch()
	await get_tree().physics_frame
	# Pause menu: open, swap to settings and back, resume.
	a._pause(true)
	assert(get_tree().paused and a.pause != null, "paused with a menu")
	assert(a.pause.size * a.pause.scale == Tuning.VIEW, "pause overlay covers the arena at 2x, so its box centers")
	a._pause_settings()
	a._pause(true)
	a._pause(false)
	assert(not get_tree().paused and a.pause == null, "resumed")

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
	var fx: int = a.get_children().filter(func(c): return c is AnimatedSprite2D).size()
	print("smoke ok: over=%s earned=%d balls=%d placed=%d fx=%d" % [a.over, a.earned, a.balls.size(), a.placed.size(), fx])
	if saved:
		FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE).store_string(saved)
	else:
		DirAccess.remove_absolute(Game.SAVE_PATH)
	Game.load_save()
	get_tree().quit()
