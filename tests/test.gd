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

	# Every board fits the arena between the top wall band and the floor line, and the generator keeps its counts and
	# placement rules (docs/content.md "Generator"). Touching = within one column step, the generator's own definition.
	var arena := Rect2(Vector2.ZERO, Tuning.ARENA)
	var step := Tuning.BRICK_SIZE + Vector2.ONE * Tuning.BRICK_GAP
	var fits := func(b: Dictionary) -> bool:
		var r := Rect2(b.pos - Tuning.BRICK_SIZE / 2, Tuning.BRICK_SIZE)
		return arena.encloses(r) and r.end.y <= arena.size.y - Tuning.BOARD_FLOOR
	for id in Tuning.encounters():
		var e: Dictionary = Tuning.encounter(id)
		var cls: String = "fight" if e.role == "regular" else e.role
		var B: Dictionary = Tuning.BOARDS[cls]
		var rows: Array = e.board.rows
		var digits := "123456789".substr(0, e.organs.size())
		check(rows.all(func(l): return l.length() <= B.cols) and rows.any(func(l): return l.length() == B.cols), "%s's layout is %d columns at its widest (the lane grid)" % [id, B.cols])
		check(rows.all(func(l): return Array(l.split("")).all(func(ch): return ch in Tuning.BOARD_KEYS or ch in digits)), "%s's layout uses only BOARD_KEYS glyphs and its organs' digits" % id)
		for d in digits:
			check(d in "".join(rows), "%s's organ %s has cells on the board" % [id, d])
		if id in Tuning.ENEMIES:  # the bridge stamps its organ over plain or rolled cells only, never a drawn glyph
			var src: Array = Tuning.ENEMIES[id].board.rows
			for r in rows.size():
				for c in rows[r].length():
					check(rows[r][c] == src[r][c] or src[r][c] in "x?.#", "%s's bridged organ covers no drawn %s at row %d col %d" % [id, src[r][c], r, c])
		# Every brick is reachable past the drawn solids: flood the open cells from outside the layout, 4-way.
		# ponytail: a 4-way grid walk ignores the half-step offset of short rows; fine while honey pillars run straight.
		var solid := func(r: int, c: int) -> bool: return r >= 0 and r < rows.size() and c >= 0 and c < rows[r].length() and rows[r][c] in "#123456789"
		var seen := {Vector2i(-1, -1): true}
		var todo := [Vector2i(-1, -1)]
		while todo:
			var p: Vector2i = todo.pop_back()
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var q: Vector2i = p + d
				if q.x >= -1 and q.x <= rows.size() and q.y >= -1 and q.y <= B.cols and not q in seen and not solid.call(q.x, q.y):
					seen[q] = true
					todo.append(q)
		for r in rows.size():
			for c in rows[r].length():
				if not rows[r][c] in ".#123456789":
					check(Vector2i(r, c) in seen, "%s's brick at row %d col %d is reachable past the solids" % [id, r, c])
		var drawn := func(kind: String) -> int: return "".join(rows).count({crit = "c", refresh = "r"}[kind])
		for s in 200:
			var bricks: Array = g.generate(cls, s, e.board)
			check(bricks == g.generate(cls, s, e.board), "generate is deterministic")
			check(bricks.any(func(b): return b.kind != "organ" and Tuning.BRICKS[b.kind].hp > 0), "%s's board has a breakable brick" % id)
			var n := func(kind: String) -> int: return bricks.filter(func(b): return b.kind == kind).size()
			for k in ["crit", "refresh"]:
				check(n.call(k) == maxi(B[k], drawn.call(k)), "%s seed %d has %d %ss" % [id, s, maxi(B[k], drawn.call(k)), k])
			var rolled: Array = bricks.filter(func(b): return rows[b.row][b.col] == "?")
			for k in ["solid", "bomb", "red"]:
				check(rolled.filter(func(b): return b.kind == k).size() <= B[k][1], "%s seed %d keeps rolled %s at or under its max" % [id, s, k])
			for b in bricks:
				check(fits.call(b), "%s brick inside the arena, above the floor line" % id)
				check(b.kind in Tuning.BRICKS or (b.kind == "organ" and b.organ < e.organs.size()), "%s brick kind %s exists" % [id, b.kind])
			for b in rolled:
				var touching: Array = bricks.filter(func(o): return o != b and o.pos.distance_to(b.pos) <= step.x + 1)
				if b.kind == "solid":
					check(b.col > 0 and b.col < rows[b.row].length() - 1 and b.row < rows.size() - 1 and touching.all(func(o): return o.kind != "solid"), "%s rolled solid is off the ends and touches no solid" % id)
				if b.kind == "red":
					check(b.row < B.get("red_rows", rows.size()) and touching.all(func(o): return o.kind != "red"), "%s rolled red is in its rows and touches no red" % id)
	for k in Tuning.ICON_KINDS:
		check(k in Tuning.BRICKS and Tuning.BRICKS[k].has("idle"), "icon kind %s is a brick kind with a pulse strip" % k)
	for k in Tuning.BRICKS:
		check(Tuning.hue(k) in ["mag", "ora", "blue", "mint", "red", "gold"], "brick %s has a colour group with strips" % k)
		check(Tuning.BRICKS[k].has("dmg"), "brick %s has a dmg" % k)
	check(Tuning.BRICKS.bomb.hp == 2 and "armed" in Tuning.BRICKS.bomb and not "blast" in Tuning.BRICKS.bomb and Tuning.BRICKS.red.hurt > 0, "the bomb arms then blasts, and the red brick hurts")
	check(Tuning.ladder(Tuning.DAMAGE_LAND, 0) == 0 and Tuning.ladder(Tuning.DAMAGE_LAND, 29) == 2 and Tuning.ladder(Tuning.DAMAGE_LAND, 100) == 7, "cue ladders pick the last row reached")
	for k in ["enemy_turn", "regen_below", "refresh_after", "end_beat", "win_break", "ramp_on", "ramp_after", "ramp_per_s", "ramp_max"]:
		check(k in Tuning.RUN, "RUN has %s" % k)

	# Run tables cross-reference by id (docs/content.md).
	for id in Tuning.BAG_START:
		check(id in Tuning.BALLS, "bag start ball %s exists" % id)
	for id in Tuning.BALLS:
		var row: Dictionary = Tuning.BALLS[id]
		check(row.rarity in Tuning.RARITY or row.rarity == "none", "ball %s has a rarity" % id)
		check(row.dmg.size() == Tuning.MAX_RANK, "ball %s has a dmg per rank" % id)
		check(row.size > 0 and row.speed > 0 and row.name.length() <= 9, "ball %s has a size, a speed and a name of 9 glyphs or fewer" % id)
		for k in ["split", "pierce", "catches", "every", "poison", "pays", "floor"]:
			check(not row.has(k) or (row[k].size() == Tuning.MAX_RANK and row[k].all(func(v): return v is int and v >= 0)), "ball %s trait %s has a whole value per rank" % [id, k])
		check(not row.has("split") or row.split.min() >= 2, "ball %s splits into at least two" % id)
		check(not row.has("every") or row.every.min() >= 1, "ball %s blasts every nth break, n >= 1" % id)
		check(not row.has("pays") or (row.pays.min() >= 1 and row.get("gold", 0) >= 1), "ball %s pays gold every nth break, n >= 1" % id)
		check(not row.has("magnet") or (row.magnet.size() == Tuning.MAX_RANK and row.magnet.all(func(v): return v is float and v > 0)), "ball %s multiplies the magnet pull per rank" % id)
		check(not row.has("map") or row.map == Tuning.SHOP.map, "ball %s belongs to a map the shop knows" % id)
		check(load("res://src/fx.gd")._frames("%s_rank" % id, int(8 * row.size)).get_frame_count("default") == (1 if id == "ball_junk" else Tuning.MAX_RANK), "ball %s has a face per rank" % id)
		check(not row.has("locked") or row.locked in Tuning.UNLOCKS, "ball %s locks behind an UNLOCKS flag" % id)
	for id in Tuning.RELICS:
		var row: Dictionary = Tuning.RELICS[id]
		check(row.rarity in Tuning.RELIC_RARITY, "relic %s has a rarity" % id)
		check(row.hook in Tuning.RELIC_HOOKS and (not row.has("reset") or row.reset in Tuning.RELIC_HOOKS), "relic %s hooks a known site" % id)
		check(not row.has("locked") or row.locked in Tuning.UNLOCKS, "relic %s locks behind an UNLOCKS flag" % id)
		check(FileAccess.file_exists("res://assets/pixel/png/relic_%s.png" % id), "relic %s has an icon" % id)
		for k in ["saves", "per", "gold", "every", "cap", "launches", "balls"]:  # the counts arena.gd _relics reads
			check(not row.has(k) or row[k] >= 1, "relic %s %s is at least 1" % [id, k])
	check(Tuning.RELICS.wide_paddle.width > Tuning.PADDLE_WIDTH and Tuning.RELICS.twin_crit.launches >= 2 and Tuning.RELICS.combo.cap > 1, "wide paddle widens, twin crit doubles, combo climbs")
	check(Tuning.spec("paddle_mini").has("face") and Tuning.RELICS.mini_paddle.size.x > 0, "the mini paddle has a face and a size")
	check(Tuning.RELIC_RARITY.values().map(func(r): return r.weight).reduce(func(a, b): return a + b) > 0 and Tuning.RELIC_RARITY.values().all(func(r): return r.weight >= 1 and r.price >= 1), "relic offer weights sum to something and every rarity has a price")
	for flag in Tuning.UNLOCKS:
		for id in Tuning.UNLOCKS[flag]:
			check(id in Tuning.BALLS or id in Tuning.RELICS, "unlock %s is a ball or relic" % id)
	var Fx = load("res://src/fx.gd")
	check(Tuning.ENCOUNTERS.keys().all(func(k): return not k in Tuning.ORGANS and not k in Tuning.ENEMIES) and Tuning.ORGANS.keys().all(func(k): return not k in Tuning.ENEMIES), "ENCOUNTERS, ORGANS and ENEMIES ids are disjoint")
	check("111" in "".join(Tuning.encounter("glob").board.rows), "the bridge stamps a 3-cell organ on a legacy enemy's board")
	check(FileAccess.file_exists("res://assets/pixel/png/%s.png" % Tuning.spec("organ").face), "the organ cell has a face")
	for id in Tuning.ORGANS.keys() + Tuning.ENEMIES.keys():  # every organ arena.gd runs: authored, and each enemy through the bridge
		var e: Dictionary = Tuning.organ(id)
		check(e.intents.size() >= 1 and e.hp > 0 and e.cd >= 1, "organ %s has hp, a countdown and an intent" % id)
		for it in e.intents:
			check((it[0] in Tuning.HAZARDS or it[0] == "mouth") and it[1] >= 1, "organ %s intent %s is a hazard x count" % [id, it[0]])
			check(it[0] != "mouth" or e.has("mouth"), "organ %s intends a mouth it has" % id)
		check(not e.has("enraged") or (e.enraged.at > 0 and e.enraged.at < 1 and e.enraged.cd >= 1 and (not e.enraged.has("mouth") or e.has("mouth"))), "organ %s enrages below a fraction of its HP" % id)
		check(not e.has("riposte") or e.riposte >= 1, "organ %s ripostes shots of some size" % id)
		check(not e.has("twice") or e.twice > 0, "organ %s twice is positive" % id)
	for id in Tuning.encounters():
		var e: Dictionary = Tuning.encounter(id)
		check(e.role in ["regular", "elite", "boss"] and e.tier >= 1, "encounter %s has a role and a tier" % id)
		check(e.organs.size() >= 1 and e.organs.all(func(o): return not Tuning.organ(o).is_empty()), "encounter %s's organs exist" % id)
		check(e.get("win", e.organs).all(func(o): return o in e.organs), "encounter %s wins on its own organs" % id)
		check(not e.has("cd_start") or e.cd_start.size() == e.organs.size(), "encounter %s has a first countdown per organ" % id)
		for strip in Tuning.ENEMY_STRIPS:  # the four strips arena.gd _band_play slices at the row's width (docs/animations.md)
			check(strip in Tuning.ENEMY_FPS and Fx._frames("%s_%s" % [e.band, strip], e.w).get_frame_count("default") == Tuning.ENEMY_STRIPS[strip], "encounter %s has a %d-frame %s strip %d wide with an fps" % [id, Tuning.ENEMY_STRIPS[strip], strip, e.w])
		for k in ["steal", "jackpot", "advance"]:  # the signature numbers arena.gd reads
			check(not e.has(k) or e[k] > 0, "encounter %s %s is positive" % [id, k])
		check(not e.has("jackpot") or "".join(e.board.rows).count("g") >= 2, "encounter %s's jackpot has gold bricks to break in one phase" % id)
		check(not e.has("advance") or e.board.rows.size() + e.advance <= 11, "encounter %s's board has room to advance" % id)
	for id in Tuning.HAZARDS:
		var h: Dictionary = Tuning.HAZARDS[id]
		check(h.hp >= 0 and FileAccess.file_exists("res://assets/pixel/png/intent_%s.png" % id), "hazard %s has an hp cost and an intent icon" % id)
	check(FileAccess.file_exists("res://assets/pixel/png/intent_mouth.png"), "the mouth has an intent icon")
	check(Tuning.HAZARDS.enemy_balls.flight and Tuning.HAZARDS.debris.flight and not Tuning.HAZARDS.laser_sweep.get("flight", false), "enemy balls and debris are flight hazards a phase end clears; a laser lane persists")
	check(Tuning.HAZARDS.shield_row.hits >= 1 and Tuning.SHIELD_Y > Tuning.TOP_WALL and Tuning.SHIELD_Y < Tuning.BOARD_TOP, "the shield row sits between the top wall and the board")
	var H := Tuning.HAZARDS
	check(H.jam.hits >= 1 and H.jam.width > 0 and H.jam.width < 1 and H.pull.secs > 0 and H.pull.force > 0 and H.pull.flight and H.coin_junk.junk in Tuning.BALLS, "jam narrows the paddle for some hits, pull lifts for some seconds and dies with the phase, coin_junk adds a ball")
	check(FileAccess.file_exists("res://assets/pixel/png/paddle_jam.png") and FileAccess.file_exists("res://assets/pixel/png/brick_gold.png"), "the jammed paddle and the gold brick have faces")
	check(Tuning.SHOP.buy_back == Tuning.SHOP.ball / 2 and Tuning.SHOP.rarities.all(func(r): return r in Tuning.RARITY) and Tuning.SHOP.relic_weights.keys().all(func(r): return r in Tuning.RELIC_RARITY), "the pawn shop buys back at half price and stocks known rarities")
	check(Tuning.MOUTH.rect.position.y == 0 and Tuning.MOUTH.rect.end.y <= Tuning.TOP_WALL, "the mouth zone is in the band")
	check(Tuning.EVENTS.event_vendor.junk in Tuning.BALLS, "the vendor's junk is a ball")
	for id in Tuning.EVENTS:
		check(["title", "body", "a", "b"].all(func(k): return Tuning.EVENTS[id].get(k, "") != "" and not "(" in Tuning.EVENTS[id][k]), "event %s has a title, a body and two choices, in glyphs the 3x5 font has" % id)
	for id in Tuning.BALLS:
		check(Tuning.BALLS[id].get("desc", "").length() in range(1, 37), "ball %s has a card line of 1-36 glyphs" % id)
	for id in Tuning.RELICS:
		check(Tuning.RELICS[id].get("desc", "").length() in range(1, 37), "relic %s has a card line of 1-36 glyphs" % id)
	check(Tuning.MAP_LEGEND.keys().all(func(k): return k in Tuning.MAP_KINDS and FileAccess.file_exists("res://assets/pixel/png/map_node_%s.png" % k)), "every legend kind is a map kind with a node sprite")
	check("fight" in Tuning.GOLD and "elite" in Tuning.GOLD and Tuning.RUN.hp_floor >= 1, "win gold per rewarded node kind; an event's cost leaves some HP")
	for i in Tuning.MAP.size():
		var L: Dictionary = Tuning.MAP[i]
		check(L.edges.size() == L.slots.size() if i + 1 < Tuning.MAP.size() else L.edges.is_empty(), "map layer %d has edges per slot" % i)
		for s in L.slots:
			for k in ([s] if s is String else s.keys()):
				check(k in Tuning.MAP_KINDS, "map layer %d slot kind %s is known" % [i, k])
		for e in L.edges:
			for s in e:
				check(s < Tuning.MAP[i + 1].slots.size(), "map layer %d edge points into the next layer" % i)
	for k in Tuning.REWARDS:
		check(k in ["ball", "rank", "relic", "gold"], "reward kind %s is one game.gd deals" % k)

	# Map shape, node walk, rolls, HP and gold, the bag invariant, the save round-trip. The real run.json is kept.
	var kept := FileAccess.get_file_as_string(g.RUN_PATH) if g.has_run() else ""
	for s in 50:
		g.new_run(s)
		var m: Dictionary = g.run.map
		check(m.layers.size() == 5 and m.layers.map(func(l): return l.size()) == [2, 3, 2, 1, 1], "map is 5 layers of 2/3/2/1/1")
		check("fight" in m.layers[1] and m.layers[2][0] == "elite" and m.layers[3] == ["shop"] and m.layers[4] == ["boss"], "map has a layer-2 fight, elite, shop, boss")
		check(g.gen_map(s) == g.gen_map(s), "gen_map is deterministic")
		check(g.reachable(0) and g.reachable(1) and not g.reachable(2), "both first nodes are reachable")
	g.new_run(3)
	var prev := ""
	var walk := []
	for layer in 5:
		var slot: int = range(Tuning.MAP[layer].slots.size()).filter(g.reachable).front()
		walk.append(g.enter_node(slot))
		check(g.run.pending == walk.back(), "entering a node leaves it pending until the map returns")
		var e: String = g.run.map.enemies[layer][slot]
		if walk.back() in ["fight", "elite", "boss"]:
			check(e in Tuning.encounters() and e != prev, "node %d encounter %s exists and differs from the last fight's" % [layer, e])
			check(Tuning.encounter(e).role == ("regular" if walk.back() == "fight" else walk.back()), "node %d encounter has the node's role" % layer)
			check(walk.back() != "fight" or Tuning.encounter(e).tier <= layer + 1, "fight encounter tier fits the layer")
			prev = e
		elif walk.back() == "event":
			check(g.run.map.events[layer][slot] in Tuning.EVENTS, "event node rolled an event")
	check(walk.size() == 5 and walk[2] == "elite" and walk[4] == "boss" and g.run.map.path.size() == 5, "walked every layer")
	check(not g.reachable(0), "nothing is reachable past the boss")
	var knight := false
	for s in 200:  # the first two layers of each map, where tier-1 fights roll
		g.new_run(s)
		for layer in 2:
			var slot: int = range(Tuning.MAP[layer].slots.size()).filter(g.reachable).front()
			g.enter_node(slot)
			knight = knight or g.run.map.enemies[layer][slot] == "knight"
	check(knight, "the knight is rolled onto some map")
	g.delete_run()
	g.new_run(11)
	for s in 50:
		var cards: Array = g.roll_reward(g.rng(s))
		var kinds := cards.map(func(c): return c.kind)
		check(cards.size() == 3 and kinds.size() == 3 and kinds[0] != kinds[1] and kinds[1] != kinds[2] and kinds[0] != kinds[2], "reward offers 3 distinct kinds")
		for c in cards:
			check(c.kind != "ball" or (c.id in Tuning.BALLS and c.id != "ball_junk"), "ball card is a real non-junk ball")
			check(c.kind != "relic" or (c.id in Tuning.RELICS and not c.id in g.run.relics and g.unlocked(c.id)), "relic card is unowned and unlocked")
		var shop: Dictionary = g.roll_shop(g.rng(100 + s))
		check(shop.balls.size() == 3 and shop.balls[0] != shop.balls[1] and shop.balls[1] != shop.balls[2] and shop.balls[0] != shop.balls[2], "shop stocks 3 distinct balls")
		check(shop.balls.all(func(id): return Tuning.BALLS[id].rarity in Tuning.SHOP.rarities) and Tuning.BALLS[shop.balls[0]].get("map", 0) == Tuning.SHOP.map, "the pawn shop stocks common and uncommon balls, a map ball first")
		check(shop.relics.size() == 2 and shop.relics[0] != shop.relics[1], "shop stocks 2 distinct relics")
	check(not g.unlocked("ball_bomb") and g.unlocked("ball_basic"), "locked rows need their flag")
	# Meta-unlocks (docs/content.md "Meta-unlocks"): the elite's flag, then a won run's; each new flag lists its ids once,
	# and the pools open up. g's settings are the defaults, so the real settings.json is kept and written back.
	var kept_settings := FileAccess.get_file_as_string(g.SETTINGS_PATH) if FileAccess.file_exists(g.SETTINGS_PATH) else ""
	g.unlock("killed_elite")
	g.unlock("killed_elite")
	check(g.run.unlocked == Tuning.UNLOCKS.killed_elite and g.unlocked("ball_poison") and g.unlocked("mini_paddle") and not g.unlocked("twin_crit"), "the elite's flag unlocks its ids, listed once")
	g.end_run(true)
	check(g.settings.meta.runs == 1 and g.settings.meta.wins == 1 and g.unlocked("ball_bomb") and g.unlocked("twin_crit") and g.run.unlocked.size() == 4, "a won run counts and sets finished_run and won_boss")
	check(range(50).any(func(s): return g.roll_ball(g.rng(s)) == "ball_bomb") and range(50).any(func(s): return "twin_crit" in g.roll_shop(g.rng(s)).relics), "unlocked ids reach the reward and shop rolls")
	g.end_run(false)
	check(g.settings.meta.runs == 2 and g.settings.meta.wins == 1 and g.run.unlocked.size() == 4, "a lost run counts and unlocks nothing twice")
	g.settings.meta = {flags = [], runs = 0, wins = 0}
	if kept_settings:
		FileAccess.open(g.SETTINGS_PATH, FileAccess.WRITE).store_string(kept_settings)
	else:
		DirAccess.remove_absolute(g.SETTINGS_PATH)
	g.take_reward({kind = "relic", id = "toll"})
	check(g.has("toll") and g.roll_shop(g.rng(0)).relics.find("toll") < 0, "owned relics leave the pool")
	g.take_reward({kind = "rank", at = 0})
	g.take_reward({kind = "gold", gold = 30})
	check(g.run.bag[0].rank == 2 and g.run.gold == 30 and g.run.stats.gold_earned == 30, "rank and gold cards apply")
	check(g.spend(31) == false and g.spend(30) and g.run.gold == 0, "spend refuses when short")
	g.hurt(20)
	g.heal(99)
	check(g.run.hp == g.run.hp_max and g.hurt(50), "heal caps at max; hurt to 0 ends the run")
	g.run.bag = [{id = "ball_basic", rank = 1}, {id = "ball_junk", rank = 1}]
	check(not g.remove_ball(0) and g.remove_ball(1) and not g.remove_ball(0) and g.run.bag.size() == 1, "removal never leaves the bag without a non-junk ball")
	g.save_run()
	var saved: Dictionary = g.run.duplicate(true)
	g.run = {}
	check(g.load_run() and g.run == saved and g.run.bag[0].rank is int, "run save round-trips with ints")
	g.run.version = 1
	g.save_run()
	check(not g.load_run() and not g.has_run(), "a save of an older version is dropped, and CONTINUE with it")
	# Events (docs/content.md "Gold, rewards, shop, events"), rolled at the node stood on.
	g.new_run(21)
	g.enter_node(0)
	var E := Tuning.EVENTS
	var relics: Array = g.roll_relics(g.rng(0), 3)
	check(relics.size() == 3 and relics[0] != relics[1] and relics[1] != relics[2] and relics[0] != relics[2], "treasure offers 3 distinct relics")
	g.run.hp = 3
	g.run.gold = 0
	check(g.event_choice("event_spring", "b") != "" and g.run.hp == Tuning.RUN.hp_floor and g.run.gold == E.event_spring.gold, "the spring's dive pays gold and floors HP")
	g.event_choice("event_spring", "a")
	check(g.run.hp == Tuning.RUN.hp_floor + E.event_spring.heal, "the spring's bath heals")
	g.run.bag = [{id = "ball_basic", rank = Tuning.MAX_RANK}, {id = "ball_junk", rank = 1}]
	g.run.hp = 3
	g.event_choice("event_mod_shop", "a")
	check(g.run.hp == 3 and g.run.bag[0].rank == Tuning.MAX_RANK and g.run.bag[1].rank == 1, "the mod shop with nothing to mod costs nothing")
	g.run.bag[0].rank = 1
	g.event_choice("event_mod_shop", "a")
	check(g.run.bag[0].rank == 2 and g.run.hp == Tuning.RUN.hp_floor, "the mod shop ranks a non-junk ball and floors HP")
	g.run.gold = 0
	g.event_choice("event_mod_shop", "b")
	check(g.run.gold == E.event_mod_shop.gold and g.run.bag.size() == 1 and g.run.bag[0].id == "ball_basic" and g.run.removed == "ball_junk", "the mod shop sells the stone first and remembers it for BUY BACK")
	g.event_choice("event_mod_shop", "b")
	check(g.run.gold == E.event_mod_shop.gold and g.run.bag.size() == 1, "the mod shop never buys the last ball")
	g.run.gold = 0
	g.event_choice("event_coin_return", "a")
	check(g.run.gold == E.event_coin_return.gold and g.run.bag.size() == 2 and g.run.bag.back().id == E.event_coin_return.junk, "the coin return pays gold and a stone")
	g.event_choice("event_coin_return", "b")
	check(g.run.gold == E.event_coin_return.gold and g.run.bag.size() == 2, "walking on changes nothing")
	g.run.gold = E.event_fried_cabinet.gold - 1
	check(not g.event_can("event_fried_cabinet", "a") and g.event_can("event_fried_cabinet", "b"), "the plug needs its gold")
	g.run.gold = E.event_fried_cabinet.gold
	g.run.hp = 3
	g.event_choice("event_fried_cabinet", "a")
	check(g.run.gold == 0 and g.run.hp == 3 + E.event_fried_cabinet.heal, "pulling the plug heals for gold")
	var n_rel0: int = g.run.relics.size()
	g.run.hp = 20
	g.event_choice("event_fried_cabinet", "b")
	check(g.run.relics.size() == n_rel0 + 1 and g.run.hp == 20 - E.event_fried_cabinet.hp, "playing it hands out a relic for HP")
	g.run.gold = 0
	check(not g.event_can("event_vendor", "a") and g.event_can("event_vendor", "b") and g.event_can("event_mod_shop", "a"), "the vendor's buy needs its price; every other choice is open")
	g.run.gold = E.event_vendor.price
	var relic: String = g.event_relic()
	check(relic in Tuning.RELICS and Tuning.RELICS[relic].rarity != "rare" and relic == g.event_relic() and g.event_can("event_vendor", "a"), "the vendor offers one common or uncommon relic")
	g.event_choice("event_vendor", "a")
	check(g.has(relic) and g.run.gold == 0, "buying the vendor's relic takes the gold")
	var n_bag: int = g.run.bag.size()
	var n_rel: int = g.run.relics.size()
	g.event_choice("event_vendor", "b")
	check((g.run.bag.size() == n_bag + 1 and g.run.bag.back().id == E.event_vendor.junk) != (g.run.relics.size() == n_rel + 1), "haggling yields a stone or a free relic, not both")
	g.run.relics = Tuning.RELICS.keys()
	check(g.event_relic() == "" and not g.event_can("event_vendor", "a") and not g.event_can("event_fried_cabinet", "b") and g.roll_relics(g.rng(0), 3).is_empty(), "with every relic owned the vendor, the fried cabinet and the treasure have nothing")
	if kept:
		FileAccess.open(g.RUN_PATH, FileAccess.WRITE).store_string(kept)
	else:
		g.delete_run()
	check(g.node_index(0, 0) == 1 and g.node_index(1, 0) == 3 and g.node_index(4, 0) == 9, "node indices count in reading order")

	var b = load("res://src/brick.gd").new()
	b.size = Vector2(90, 14)
	b.position = Vector2(100, 100)
	b.rotation = deg_to_rad(90)
	check(b.rect().is_equal_approx(Rect2(93, 55, 14, 90)), "rotated brick rect is its bounding box")
	b.free()

	# Every strip the run plays exists and slices into whole frames: docs/content.md "Code steps" 9's new and reused lists
	# (ball faces and enemy strips are checked above), plus the spark and the pause dialog's hazard strip. docs/animations.md.
	for a in [["ball_split_pop", 16, 6], ["ball_poison_land", 12, 4], ["stored_tag", 25, 4], ["damage_fire", 60, 6], ["paddle_hurt", 60, 4],
			["crit_pulse", 30, 4], ["crit_launch", 30, 6], ["refresh_pulse", 30, 4], ["refresh_wave", 60, 6], ["mint_hit", 30, 6], ["mint_break", 44, 8], ["mint_spawn", 30, 6],
			["red_hit", 30, 6], ["red_break", 44, 8], ["red_spawn", 30, 6], ["red_bricks_paint", 30, 6], ["enemy_balls_warn", 8, 4], ["enemy_balls_fly", 8, 4],
			["debris_fall", 8, 4], ["laser_sweep_warn", 30, 4], ["laser_sweep_fire", 30, 6], ["maw_mouth_open", 48, 6], ["maw_mouth_close", 48, 6],
			["recall_rise", 12, 6], ["relic_get", 36, 6], ["map_ring_pulse", 16, 4],
			["ball_bounce", 12, 6], ["ball_lost", 12, 6], ["sticky_hold", 30, 6], ["bomb_ring", 60, 4], ["paddle_hit", 60, 4],
			["mag_hit", 30, 6], ["blue_hit", 30, 6], ["ora_hit", 30, 6], ["mag_break", 44, 8], ["blue_break", 44, 8], ["ora_break", 44, 8],
			["mag_spawn", 30, 6], ["blue_spawn", 30, 6], ["ora_spawn", 30, 6], ["icon_bomb_pulse", 30, 4], ["halo_pulse", 60, 4], ["halo_pulse_ora", 60, 4], ["bomb_fuse", 30, 16], ["organ_hit", 30, 6], ["organ_die", 44, 8],
			["solid_bounce", 44, 6], ["dust_puff", 12, 4], ["shield_floor", 32, 4], ["shield_floor_pop", 32, 6], ["magnet_pull", 44, 4], ["combo_chase", 30, 8], ["toll_pay", 30, 6],
			["spark_burst", 16, 6], ["hazard_strip", 32, 4],
			["gold_hit", 30, 6], ["gold_break", 44, 8], ["gold_spawn", 30, 6], ["jam_clamp", 60, 6], ["pull_drift", 12, 4]]:  # map 1
		var holder := Node2D.new()
		var s: AnimatedSprite2D = Fx.play(holder, a[0], a[1], 12, Vector2.ZERO)
		check(s.sprite_frames.get_frame_count("default") == a[2], "anim_%s has %d frames" % [a[0], a[2]])
		holder.free()

	for n in ["card_frame", "card_frame_hot", "card_frame_dim"]:
		check(ResourceLoader.exists("res://assets/pixel/png/%s.png" % n), "Ui.card's static %s exists" % n)

	# Every cue the scripts play exists as a wav. Names: assets/audio/gen.mjs.
	var call := RegEx.create_from_string("(?:Sfx\\.(?:play|loop)(?:\\.bind)?\\(|_CUES := )([^\\n]*)")  # calls, binds and cue tables
	var lit := RegEx.create_from_string("\"([a-z]\\w{3,})\"")  # cue-shaped literals only, so "x2" in a condition is skipped
	for f in ["arena", "hud", "main", "ui"]:
		for c in call.search_all(FileAccess.get_file_as_string("res://src/%s.gd" % f)):
			for m in lit.search_all(c.get_string(1)):
				check(FileAccess.file_exists("res://assets/audio/wav/%s.wav" % m.get_string(1)), "cue %s has a wav" % m.get_string(1))

	# Every brick kind builds with a face.
	for k in Tuning.BRICKS:
		var box = load("res://src/brick.gd").new()
		box.kind = k
		box.size = Tuning.BRICK_SIZE
		box._ready()
		check(box.tex != null, "%s has a face" % k)
		box.free()

	g.free()
	print("FAILED %d" % failed if failed else "ok")
	quit(1 if failed else 0)
