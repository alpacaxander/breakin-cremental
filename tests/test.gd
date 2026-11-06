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
			check(bricks.any(func(b): return Tuning.BRICKS[b.kind].hp > 0), "level %d seed %d has a breakable brick" % [lvl, s])
			for b in bricks:
				check(view.has_point(b.pos) and b.pos.y < Tuning.PLACE_MAX_Y, "level %d brick on screen, above placement line" % lvl)
			if Tuning.LEVELS[lvl].get("jackpot", false):
				check(bricks.filter(func(b): return b.kind == "jackpot").size() == 1, "level %d has one jackpot" % lvl)
			if Tuning.LEVELS[lvl].get("seq", false):
				var seq := bricks.filter(func(b): return b.kind.begins_with("seq"))
				check(seq.size() == 3 and seq[0].kind == "seq1" and seq[1].pos == seq[0].pos + Vector2(64, 0) and seq[2].pos == seq[0].pos + Vector2(128, 0), "level %d has a 1-2-3 run" % lvl)
	for k in Tuning.LEVELS[Tuning.LEVELS.size() - 1].special:
		check(k in Tuning.BRICKS, "special kind %s is a brick kind" % k)
	for k in Tuning.ICON_KINDS:
		check(k in Tuning.BRICKS, "icon kind %s is a brick kind" % k)
	for k in Tuning.PLACEABLES:
		check(k in Tuning.UPGRADES, "placeable %s has an upgrade node" % k)
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
	check(g.owned("bumper") == 1 and g.owned("pop") == 0, "start with one bumper, nothing else")
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
	for a in [["mag_break", 44, 8], ["spark_burst", 16, 6], ["bumper_hit", 45, 6], ["solid_bounce", 44, 6], ["paddle_hit", 60, 4], ["ball_lost", 12, 6],
			["mag_spawn", 30, 6], ["mag_hit", 30, 6], ["mag_pulse", 30, 4], ["combo_chase", 30, 8], ["multi3_crack", 30, 12], ["pips_shrink", 30, 6], ["shield_pop", 44, 6],
			["cond_prime", 30, 10], ["cond_too_slow", 30, 6], ["combo_gate", 30, 6], ["sequence_step3", 30, 6], ["timed_blink", 30, 8],
			["chain_arc", 64, 4], ["bomb_ring", 60, 4], ["bolt_sweep", 60, 4], ["jackpot_rays", 48, 6], ["mystery_cycle", 30, 6], ["halo_pulse", 60, 4],
			["pop_bumper_hit", 24, 6], ["gate_flow", 30, 4], ["accel_chevrons", 30, 4], ["magnet_pull", 44, 4], ["spawner_charge", 30, 8], ["sticky_hold", 30, 6],
			["teleport_in", 16, 4], ["teleport_out", 16, 4], ["spark_burst_mint", 16, 6], ["spark_burst_sky", 16, 6], ["payout_rise", 25, 10],
			["ghost_march_45x7", 45, 4], ["ghost_invalid_shake_30x6", 30, 4], ["hover_outline_28x28", 28, 4]]:
		var holder := Node2D.new()
		var s: AnimatedSprite2D = Fx.play(holder, a[0], a[1], 12, Vector2.ZERO)
		check(s.sprite_frames.get_frame_count("default") == a[2], "anim_%s has %d frames" % [a[0], a[2]])
		holder.free()

	# Every brick kind and placeable builds with a face.
	for k in Tuning.BRICKS.keys() + Tuning.PLACEABLES.keys():
		var box = load("res://src/brick.gd").new()
		box.kind = k
		box.size = Tuning.PLACEABLES[k].size if k in Tuning.PLACEABLES else Tuning.BRICK_SIZE
		box._ready()
		check(box.tex != null, "%s has a face" % k)
		box.free()

	g.free()
	print("FAILED %d" % failed if failed else "ok")
	quit(1 if failed else 0)
