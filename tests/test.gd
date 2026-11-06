extends SceneTree
## Rules self-check: godot --headless -s tests/test.gd

const Tuning = preload("res://src/tuning.gd")

var failed := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		printerr("FAIL: ", msg)


func _init() -> void:
	var g = load("res://src/game.gd").new()

	check(g.combo_mult(1) == 1.0, "first hit has no multiplier")
	check(g.combo_mult(5) > g.combo_mult(2), "multiplier ramps")
	check(g.combo_window(1) == Tuning.COMBO_WINDOW_START, "window starts at START")
	check(g.combo_window(1000) == Tuning.COMBO_WINDOW_MIN, "window floors at MIN")

	var view := Rect2(Vector2.ZERO, Tuning.VIEW)
	for lvl in Tuning.LEVELS.size():
		for s in 200:
			var bricks: Array = g.generate(lvl, s)
			check(bricks.any(func(b): return b.kind == "plain"), "level %d seed %d has a breakable brick" % [lvl, s])
			for b in bricks:
				check(view.has_point(b.pos) and b.pos.y < Tuning.PLACE_MAX_Y, "level %d brick on screen, above placement line" % lvl)
	check(g.generate(1, 1).size() > g.generate(0, 1).size(), "level 2 board is bigger")

	var seed_id: String = Tuning.SEED_UPGRADE
	check(g.is_revealed(seed_id), "seed visible")
	check(not g.is_revealed("combo"), "far node hidden")
	check(not g.can_buy(seed_id), "can't buy broke")
	g.currency = 10000
	g.buy("combo")
	check(g.rank("combo") == 0, "can't buy hidden node")
	g.buy(seed_id)
	check(g.rank(seed_id) == 1 and g.currency == 10000 - Tuning.UPGRADES[seed_id].cost, "buy charges cost")
	check(g.is_revealed("time") and g.is_revealed("bumper"), "neighbours revealed")
	check(g.cost(seed_id) > Tuning.UPGRADES[seed_id].cost, "cost rises per rank")
	for i in 10:
		g.buy(seed_id)
	check(g.rank(seed_id) == Tuning.UPGRADES[seed_id].ranks, "rank caps")

	g.clear_level(0)
	check(g.unlocked == 1 and not g.won, "clearing level 1 unlocks level 2")
	g.clear_level(Tuning.LEVELS.size() - 1)
	check(g.won and g.unlocked == Tuning.LEVELS.size() - 1, "clearing last level wins")

	var b = load("res://src/brick.gd").new()
	b.size = Vector2(90, 14)
	b.position = Vector2(100, 100)
	b.rotation = deg_to_rad(90)
	check(b.rect().is_equal_approx(Rect2(93, 55, 14, 90)), "rotated brick rect is its bounding box")
	b.free()

	# Every strip the arena plays exists and slices into whole frames. Names, widths, fps: docs/animations.md.
	var Fx = load("res://src/fx.gd")
	for a in [["mag_break", 44, 8], ["spark_burst", 16, 6], ["bumper_hit", 45, 6], ["solid_bounce", 44, 6], ["paddle_hit", 60, 4], ["ball_lost", 12, 6]]:
		var holder := Node2D.new()
		var s: AnimatedSprite2D = Fx.play(holder, a[0], a[1], 12, Vector2.ZERO)
		check(s.sprite_frames.get_frame_count("default") == a[2], "anim_%s has %d frames" % [a[0], a[2]])
		holder.free()

	g.free()
	print("FAILED %d" % failed if failed else "ok")
	quit(1 if failed else 0)
