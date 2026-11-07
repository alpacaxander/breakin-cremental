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

	for lvl in Tuning.LEVELS.size():
		var arena := Rect2(Vector2.ZERO, g.arena_size(lvl))
		check(arena.size.x <= Tuning.ARENA.x and arena.size.y <= Tuning.ARENA.y, "level %d arena fits the minimum window" % lvl)
		var walls: Array = Tuning.LEVELS[lvl].get("walls", [])
		for s in 200:
			var bricks: Array = g.generate(lvl, s)
			check(bricks.any(func(b): return Tuning.BRICKS[b.kind].hp > 0), "level %d seed %d has a breakable brick" % [lvl, s])
			for b in bricks:
				var r := Rect2(b.pos - Tuning.BRICK_SIZE / 2, Tuning.BRICK_SIZE)
				check(arena.encloses(r) and r.end.y < arena.size.y - Tuning.PLACE_UP, "level %d brick inside the arena, above placement line" % lvl)
				check(not walls.any(func(w): return w.intersects(r)), "level %d brick clear of the level walls" % lvl)
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

	# The web: every node has a category with lamps, an icon, real links, its own spot, and a path from the seed.
	var seen := {}
	var reach := {Tuning.SEED_UPGRADE: true}
	var frontier := [Tuning.SEED_UPGRADE]
	while frontier:
		for l in Tuning.UPGRADES[frontier.pop_back()].links:
			if not l in reach:
				reach[l] = true
				frontier.append(l)
	for id in Tuning.UPGRADES:
		var u: Dictionary = Tuning.UPGRADES[id]
		check(u.cat in Tuning.CATS, "node %s has a category" % id)
		check(FileAccess.file_exists("res://assets/pixel/png/icon_%s.png" % u.get("icon", id)), "node %s has an icon" % id)
		check(u.links.all(func(l): return l in Tuning.UPGRADES), "node %s links to real nodes" % id)
		check(not u.pos in seen, "node %s has its own spot" % id)
		seen[u.pos] = true
		check(id in reach, "node %s is reachable from the seed" % id)
	for cat in Tuning.CATS:
		for state in ["dim", "lit", "max"]:
			check(FileAccess.file_exists("res://assets/pixel/png/node_%s_%s.png" % [cat, state]), "%s %s lamp exists" % [cat, state])
	# Maxed generation upgrades still fit every level and the unlocks land.
	g.slot = g.SANDBOX_PATH
	g.wipe()
	check(g.sandbox and g.rank("tele") == Tuning.UPGRADES.tele.ranks and g.is_revealed("tele") and not g.can_buy("tele"), "sandbox owns everything")
	for lvl in Tuning.LEVELS.size():
		var arena := Rect2(Vector2.ZERO, g.arena_size(lvl))
		for s in 50:
			var bricks: Array = g.generate(lvl, s)
			check(bricks.size() >= g.generate(lvl, s).size(), "generate is deterministic")
			for b in bricks:
				var r := Rect2(b.pos - Tuning.BRICK_SIZE / 2, Tuning.BRICK_SIZE)
				check(arena.encloses(r) and r.end.y < arena.size.y - Tuning.PLACE_UP, "level %d maxed board inside the arena, above placement line" % lvl)
			# multiball converts first (ICON_KINDS order); later kinds may run out of plain bricks on small boards
			check(bricks.filter(func(b): return b.kind == "multiball").size() >= Tuning.UPGRADES.multiball.ranks + 1, "level %d has every unlocked multiball plus the twin" % lvl)
	var fresh = load("res://src/game.gd").new()
	check(g.generate(0, 1).size() > fresh.generate(0, 1).size(), "fewer holes and an extra row make a bigger board")
	check(g.round_time(0, 10) == fresh.round_time(0, 10) + Tuning.UPGRADES.time.amount * Tuning.UPGRADES.time.ranks, "round length adds its seconds")
	fresh.free()
	check(g.piece_cost("spawner") == Tuning.PLACEABLES.spawner.cost - 1 and g.piece_cost("accel") == 1, "cheaper pieces floor at 1")
	g.slot = g.SAVE_PATH
	g.wipe()
	check(not g.sandbox and g.rank("tele") == 0 and g.currency == 0, "the real slot starts from zero, not the sandbox's state")
	check(g.generate(1, 1).size() > g.generate(0, 1).size(), "level 2 board is bigger")
	check(g.generate(3, 1).filter(func(b): return b.pos.y == Tuning.BOARD_TOP + 28).all(func(b): return int(b.pos.x) % 64 == 0), "honey odd rows sit half a step over (even rows are at 32)")
	check(g.generate(8, 1).all(func(b): return b.pos.x != 480), "double wide leaves the divider column empty")
	check(g.round_time(11, 100) < g.round_time(2, 100), "finale clock is shorter per brick")
	g.note_broken(3, 36, 50)
	g.note_broken(3, 10, 50)
	check(g.broken["3"] == 72, "best broken share keeps the best, as a percent")

	var seed_id: String = Tuning.SEED_UPGRADE
	check(g.is_revealed(seed_id), "seed visible")
	check(not g.is_revealed("tele"), "far node hidden")
	check(not g.can_buy(seed_id), "can't buy broke")
	g.currency = 10000
	g.buy("tele")
	check(g.rank("tele") == 0, "can't buy hidden node")
	g.buy(seed_id)
	check(g.rank(seed_id) == 1 and g.currency == 10000 - Tuning.UPGRADES[seed_id].cost, "buy charges cost")
	check(g.is_revealed("bumper"), "neighbours revealed")
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
			["chain_arc", 64, 4], ["chain_fuse", 30, 16], ["bomb_fuse", 30, 16], ["bolt_fuse", 30, 16], ["bomb_ring", 60, 4], ["bolt_sweep", 60, 4], ["jackpot_rays", 48, 6], ["mystery_cycle", 30, 6], ["halo_pulse", 60, 4],
			["pop_bumper_hit", 24, 6], ["gate_flow", 30, 4], ["accel_chevrons", 30, 4], ["magnet_pull", 44, 4], ["spawner_charge", 30, 8], ["sticky_hold", 30, 6],
			["teleport_in", 16, 4], ["teleport_out", 16, 4], ["spark_burst_mint", 16, 6], ["spark_burst_sky", 16, 6], ["payout_rise", 25, 10], ["shield_floor_pop", 32, 6],
			["ghost_march_45x7", 45, 4], ["ghost_invalid_shake_30x6", 30, 4], ["hover_outline_28x28", 28, 4]]:
		var holder := Node2D.new()
		var s: AnimatedSprite2D = Fx.play(holder, a[0], a[1], 12, Vector2.ZERO)
		check(s.sprite_frames.get_frame_count("default") == a[2], "anim_%s has %d frames" % [a[0], a[2]])
		holder.free()

	# Every cue the scripts play exists as a wav. Names: assets/audio/gen.mjs.
	var call := RegEx.create_from_string("Sfx\\.(?:play|loop)\\(([^\\n]*)")
	var lit := RegEx.create_from_string("\"([a-z]\\w{3,})\"")  # cue-shaped literals only, so "x2" in a condition is skipped
	for f in ["arena", "main", "shop", "ui"]:
		for c in call.search_all(FileAccess.get_file_as_string("res://src/%s.gd" % f)):
			for m in lit.search_all(c.get_string(1)):
				check(FileAccess.file_exists("res://assets/audio/wav/%s.wav" % m.get_string(1)), "cue %s has a wav" % m.get_string(1))

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
