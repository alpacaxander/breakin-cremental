extends Node
## Runs fights headless and pokes every mechanic once, then walks the run's screens through main.gd:
## godot --headless tests/smoke.tscn. Any script error prints. (A scene, not -s, so the Game autoload exists.) The real
## run.json (and settings.json, for the meta-unlock checks) is saved first and restored at the end.

const Tuning = preload("res://src/tuning.gd")


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)  # headless starts 64x64; at that size the arena is a 100 px thumbnail and physics misses collisions
	var kept := FileAccess.get_file_as_string(Game.RUN_PATH) if Game.has_run() else ""
	# A run through the autoload: new, walk a node (autosaves), reload it.
	Game.new_run(7)
	var kind: String = Game.enter_node(0)
	assert(kind == "fight" and Game.has_run() and Game.run.map.enemies[0][0] != "", "entering the first node rolled its enemy and saved")
	var saved := Game.run.duplicate(true)
	Game.run = {}
	assert(Game.load_run() and Game.run == saved and Game.run.pending == "fight", "run.json reloads the same run, its node pending")
	var Ui = load("res://src/ui.gd")  # needs the Game autoload, so it is checked here and not in test.gd
	assert(Ui.money(0) == "0" and Ui.money(999) == "999" and Ui.money(1248) == "1,248" and Ui.money(1234567) == "1,234,567", "cash gets thousands separators")
	var a = load("res://src/arena.gd").new()
	add_child(a)
	await get_tree().process_frame
	assert(a.breakable > 0 and a.balls.size() == 1 and a.rest == a.balls[0] and a.phase == 1, "the board built with a resting ball")
	assert(a.phase_golds == a._bricks("gold").size(), "the jackpot counts the golds standing at the phase start")
	assert(a.organs.size() == 1 and a.organs[0].hp == Tuning.ENEMIES.glob.hp and a.organs[0].cd_left == Tuning.ENEMIES.glob.cd and a.bag.size() == Game.run.bag.size() - 1, "the bridged glob organ is up and the bag holds the rest")
	a._launch_rest()
	await get_tree().physics_frame
	assert(a.rest == null and a.balls[0].vel.y < 0, "the ball launched upward")
	# Pause menu, main.gd's, shared by the run screen and a round: Esc opens it over the round, settings and back, resume, Esc closes, MENU leaves.
	var main = load("res://src/main.gd").new()
	add_child(main)
	main.group = true
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert(get_tree().paused and main.pause != null and not a.can_process(), "Esc pauses the round under a menu")
	assert(main.pause.sheet.size * main.pause.sheet.scale == get_viewport().get_visible_rect().size, "pause overlay covers the whole canvas")
	main._pause_settings()
	assert(await _click(main.pause, "BACK") and main.pause and _button(main.pause, "RESUME"), "settings BACK clicks back to the pause menu")
	assert(await _click(main.pause, "RESUME") and not get_tree().paused and main.pause == null, "RESUME clicks through")
	main._pause(true)
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert(not get_tree().paused and main.pause == null, "Esc resumes")
	main._pause(true)
	assert(await _click(main.pause, "MENU") and not get_tree().paused and main.pause == null and not main.group, "MENU abandons straight to the menu")
	main.queue_free()
	await get_tree().process_frame

	# Store and fire: a break stores the ball's dmg, an organ cell lands it, the paddle never does; the clock fires the intent.
	var ball = a.balls[0]
	var before: int = a.breakable
	a._damage(a._bricks("plain").front(), ball)
	assert(a.breakable == before - 1 and ball.stored == ball.dmg and ball.tag.text == str(ball.dmg) and ball.tag_s.visible, "a break stores the ball's dmg on the ball")
	# Red: a ball's own break costs HP; a blast removes it for free. (The glob's board always starts with reds.)
	var hp_run: int = Game.run.hp
	a._damage(a._bricks("red").front(), ball)
	assert(Game.run.hp == hp_run - Tuning.BRICKS.red.hurt and ball.stored == ball.dmg, "a ball breaking a red brick costs HP and stores nothing")
	a._trigger(a._bricks("red").front(), ball)
	assert(Game.run.hp == hp_run - Tuning.BRICKS.red.hurt, "a blast removing a red brick costs nothing")
	# Bombs: the first hit arms, the second blasts; each brick in radius takes one hit for the ball, an organ none. The bomb
	# sits by the organ, with two plain neighbours turned bombs out of each other's reach: one armed (chains), one not (arms).
	_pull_refresh(a)  # a blast reaching the refresh brick would regrow the board
	var BR := Tuning.BOMB_RADIUS
	var o_cell = a.organs[0].cells[0]
	var spot = a._bricks("plain").filter(func(p): return p.position.distance_to(o_cell.position) <= BR and a._near(p, BR).filter(func(o): return o.kind == "plain").size() >= 3).front()
	var near: Array = a._near(spot, BR).filter(func(o): return o.kind == "plain")
	var pair: Array = []
	for x in near:
		for y in near:
			if pair.is_empty() and x.position.distance_to(y.position) > BR:
				pair = [x, y]
	var b1 = _bomb_at(a, spot)
	var b2 = _bomb_at(a, pair[0])
	var b3 = _bomb_at(a, pair[1])
	a._damage(b2, ball)
	a._damage(b1, ball)
	assert(b1.hp == 1 and b1 in a._live() and b2.hp == 1 and b2 in a._live() and ball.stored == ball.dmg, "a bomb's first hit arms it and leaves it live")
	var hp_o: int = a.organs[0].hp
	a._damage(b1, ball)
	assert(b1.is_queued_for_deletion() and b2.is_queued_for_deletion() and b3.hp == 1 and b3 in a._live() and ball.stored > ball.dmg, "the second hit blasts for the ball: the armed bomb in range chains, the unarmed one arms")
	assert(a.organs[0].hp == hp_o and a.organs[0].cells.all(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion()), "a blast never touches an organ")
	var stored: int = ball.stored
	var o0 = a.organs[0]
	var hp_e: int = o0.hp
	var cd_e: float = o0.cd_left
	a._paddle_hit(ball)
	assert(o0.hp == hp_e and ball.stored == stored, "paddle contact keeps the charge")
	var in_discard: int = a.discard.size()
	a._organ_hit(o0, ball, o0.cells[0])
	assert(o0.hp == hp_e - stored and ball.stored == 0 and ball.tag.text == "" and not ball.tag_s.visible and a.phase_dmg == stored and o0.cd_left == cd_e, "an organ cell cashes the stored damage in and leaves the clock alone")
	assert(not ball in a.balls and ball.is_queued_for_deletion() and a.discard.size() == in_discard + 1, "the organ consumed the ball to the discard pile")
	ball = a._add_ball({id = "ball_basic", rank = 1}, Vector2(30, 600))
	a._launch(ball)
	a._organ_hit(o0, ball, o0.cells[0])
	assert(o0.hp == hp_e - stored and not ball in a.balls, "a 0-charge touch is refused, and still consumed")
	ball = a._add_ball({id = "ball_basic", rank = 1}, Vector2(30, 600))
	a._launch(ball)
	assert(cd_e < Tuning.ENEMIES.glob.cd, "the organ clock ran while the ball flew")
	a._count_down(o0.cd_left)
	assert(o0.intent == 1 and o0.cd_left == Tuning.ENEMIES.glob.cd, "the countdown fired the intent and showed the next")
	var reds: int = a._bricks("red").size()  # the glob's first intent paints red bricks on the attack's spawn frame; checked after the beat below
	# A crit (relic opener's) launches the bag's next ball; drops end the phase after the beat, then the next ball rests.
	var in_bag: int = a.bag.size()
	var in_play: int = a.balls.size()
	in_discard = a.discard.size()
	var drops: int = Game.run.stats.drops
	a._crit(a._bricks("plain").front(), ball)
	assert(a.balls.size() == in_play + 1 and a.bag.size() == in_bag - 1 and a.balls.back().vel.y < 0, "a crit launched the bag's next ball")
	for b in a.balls.duplicate():
		b.position.y = a.field.size.y + 100
	for i in 3:  # physics_frame fires before the step, so the drop lands a frame later
		await get_tree().physics_frame
	assert(a.balls.is_empty() and a.discard.size() == in_discard + in_play + 1 and a.beat > 0 and Game.run.stats.drops == drops + in_play + 1, "dropped balls go to the discard pile and start the beat")
	await get_tree().create_timer(Tuning.RUN.enemy_turn + 0.2).timeout
	assert(a.phase == 2 and a.rest != null and a.balls.size() == 1, "the next phase rested a ball")
	assert(a._bricks("red").size() == reds + Tuning.ENEMIES.glob.intents[0][1], "the intent painted its red bricks onto standing plain ones, and the phase end kept them")
	var head: String = a.rest.id
	a._discard()
	assert(a.discarded and a.discard.size() == in_discard + in_play + 2 and a.discard.back().id == head and a.rest != null, "discard swaps the resting ball for the next")
	# Refresh: broken standard slots regrow plain with no source, standing bricks stay put, and the keep tops its refresh
	# brick back up somewhere other than the slot that fired; a bare board with a ball live regrows one brick.
	before = a.breakable
	a._trigger(a._bricks("plain").front())
	a._refresh()
	assert(a.breakable > before and a._empty_slots().is_empty() and a.pending == 0, "a refresh regrew every broken slot")
	var keeper := func() -> Array: return a._live().filter(func(b): return b.keep >= 0)
	assert(keeper.call().size() == a.keeps.size() and keeper.call().all(func(b): return b.kind == "refresh" and b.source == "design" and b.keep == 0), "the default keep stands one refresh brick of its own, from design")
	var other = a._bricks("plain").front()
	a._convert(other, "refresh", "design")  # a refresh no keep counts: it must not move
	var other_at: int = a.slots.find(other)
	var fresh = keeper.call().front()
	var at: int = a.slots.find(fresh)
	var gone = a._bricks("plain").front()
	var gone_at: int = a.slots.find(gone)
	a._trigger(gone)
	a._trigger(fresh)
	var regrown = a.slots[gone_at]
	assert(a._empty_slots() == [at] and not fresh in a._live(), "a refresh regrew the board but its own slot")
	assert(regrown != gone and regrown.kind == "plain" and regrown.source == "" and regrown.keep == -1, "a broken slot regrew plain, no source")
	assert(other in a._live() and a.slots.find(other) == other_at and other.kind == "refresh", "the other refresh brick did not move")
	assert(keeper.call().size() == a.keeps.size() and keeper.call().all(func(b): return b.kind == "refresh" and a.slots.find(b) != at), "the keep's refresh stands again, elsewhere")
	assert(a.breakable == a._live().size(), "the conversions kept the breakable count")
	# Pending: no plain target, so the keep places nothing and owes; the next refresh's regrowth gives it one.
	_pull_refresh(a)
	for b in a._bricks("plain"):
		a._convert(b, "red", "design")
	a._keep()
	assert(a.pending == a.keeps.size() and a._bricks("refresh").is_empty() and a.breakable == a._live().size(), "no plain target: the keep placed nothing and owes")
	a._trigger(a._bricks("red").front())  # a blast's removal: no HP cost
	a._refresh()
	assert(a.pending == 0 and keeper.call().size() == a.keeps.size() and a._bricks("refresh").size() == a.keeps.size(), "the regrown plain brick took the pending refresh")
	a._refresh()
	a._launch_rest()
	a.balls[0].position.x = 30  # off the board, so the live ball meets no brick while the test looks
	a.bag = []  # so the crits broken below launch nothing
	a.organs[0].hp = 999  # so the poison or any stray hit below cannot win the fight first
	_pull_refresh(a)
	while not a._live().is_empty():  # an unarmed bomb takes two
		a._trigger(a._live()[0])
	assert(a.breakable == 0 and a.refresh_in > 0 and a.in_play() == 1, "a bare board with a ball live waits to regrow a brick")
	await get_tree().create_timer(Tuning.RUN.refresh_after + 0.1).timeout
	assert(a._bricks("refresh").size() == 1 and a.breakable == 1 and a._bricks("refresh")[0].keep == 0, "one brick regrew and the keep turned it refresh")
	# HP loss short of 0 keeps the fight going; the win organ at 0 wins it, then done(true) after the end beat.
	hp_run = Game.run.hp
	a.hurt(1)
	assert(Game.run.hp == hp_run - 1 and not a.over, "hurt costs HP without ending the fight")
	var hit := [false, false, false]
	a.won.connect(func(): hit[0] = true)
	a.done.connect(func(w): hit[1] = w)
	a._land(a.organs[0], a.organs[0].hp)
	assert(a.over and hit[0] and not hit[1] and Game.run.stats.fights == 1, "the win organ at 0 HP wins the fight")
	await get_tree().create_timer(Tuning.RUN.end_beat + 0.5).timeout  # done, and the delayed cues, else they leak at quit
	assert(hit[1], "done(true) fired after the end beat")
	var fx: int = a.get_children().filter(func(c): return c is AnimatedSprite2D).size()
	print("smoke ok: over=%s breakable=%d phase=%d fx=%d" % [a.over, a.breakable, a.phase, fx])
	a.queue_free()
	# A second fight: the ball traits on a fresh board (the rest ball stays on the paddle), then lost on HP.
	a = load("res://src/arena.gd").new()
	add_child(a)
	a.lost.connect(func(): hit[2] = true)
	await get_tree().process_frame
	var P := Tuning.BALLS
	# Needle: launched below the lowest plain brick in a column with no solid, it passes through on the same heading.
	var solids: Array = a._bricks("solid")
	var lane: Array = a._bricks("plain").filter(func(p): return solids.all(func(s): return absf(s.position.x - p.position.x) > Tuning.BRICK_SIZE.x / 2))
	lane.sort_custom(func(x, y): return x.position.y > y.position.y)
	var needle = a._add_ball({id = "ball_pierce", rank = 1}, lane.front().position + Vector2(0, 40))
	a._launch(needle)
	assert(needle.pierce_left == P.ball_pierce.pierce[0] and needle.radius == Tuning.BALL_RADIUS * P.ball_pierce.size and needle.speed == P.ball_pierce.speed, "a launched needle is armed, small and fast")
	for i in 12:
		await get_tree().physics_frame
	assert(needle.pierce_left < P.ball_pierce.pierce[0] and needle.vel.y < 0 and needle.stored > 0, "the needle broke a brick and passed through on its heading")
	a.balls.erase(needle)
	needle.free()
	# ...but bounces off an unarmed bomb, arming it, with its pierce kept.
	var nb = _bomb_at(a, lane.filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion()).front())
	needle = a._add_ball({id = "ball_pierce", rank = 1}, nb.position + Vector2(0, 40))
	a._launch(needle)
	for i in 12:
		await get_tree().physics_frame
	assert(needle.pierce_left == P.ball_pierce.pierce[0] and needle.vel.y > 0 and nb.hp == 1, "a needle bounces off an unarmed bomb and arms it")
	a.balls.erase(needle)
	needle.free()
	# Splitter: the first break per flight forks it; halves store their own damage, never split again and never rejoin the bag.
	var sp = a._add_ball({id = "ball_split", rank = 3}, Vector2(480, 500))
	a._launch(sp)
	var n0: int = a.balls.size()
	a._damage(a._bricks("plain").front(), sp)
	var half = a.balls.back()
	assert(a.balls.size() == n0 + P.ball_split.split[2] - 1 and not sp.can_split and half.copy and half.vel.y < 0 and half.stored == 0 and half.dmg == sp.dmg, "a splitter's first break forked it; halves are fresh full copies")
	a._damage(a._bricks("plain").front(), sp)
	assert(a.balls.size() == n0 + P.ball_split.split[2] - 1, "a splitter does not fork again before a paddle hit")
	half.position.y = a.field.size.y + 100
	for i in 3:
		await get_tree().physics_frame
	assert(not is_instance_valid(half) and a.discard.is_empty(), "a dropped half is freed and never joins the discard pile")
	# Gum: the first paddle contact keeps the charge and sticks; fired, it flies up; no catches left, it bounces.
	var gum = a._add_ball({id = "ball_sticky", rank = 1}, Vector2(480, 600))
	a._launch(gum)
	gum.store(4)
	var hp0: int = a.organs[0].hp
	a._paddle_hit(gum)
	assert(gum.hold > 0 and gum.vel == Vector2.ZERO and gum.catches_left == 0 and gum.stored == 4 and a.organs[0].hp == hp0, "gum's first paddle contact keeps its charge and sticks")
	a._sticky_fire(gum)
	assert(gum.hold == 0 and gum.vel.y < 0 and is_equal_approx(gum.vel.length(), Tuning.BALL_SPEED * gum.speed), "fired gum flies up at its speed")
	a._paddle_hit(gum)
	assert(gum.hold == 0, "gum with no catches left bounces")
	# Spore: breaks store stacks, an organ cell lands them, the phase-end tick deals them and halves them.
	var spore = a._add_ball({id = "ball_poison", rank = 2}, Vector2(480, 600))
	a._launch(spore)
	a._damage(a._bricks("plain").front(), spore)
	assert(spore.poison == P.ball_poison.poison[1] and spore.stored == 0, "a spore stores stacks and no damage at rank 2")
	a._organ_hit(a.organs[0], spore, a.organs[0].cells[0])
	assert(a.organs[0].poison == P.ball_poison.poison[1] and spore.poison == 0, "an organ cell lands the stacks on its organ")
	hp0 = a.organs[0].hp
	a._phase_end()
	assert(a.organs[0].hp == hp0 - P.ball_poison.poison[1] and a.organs[0].poison == P.ball_poison.poison[1] / 2, "the phase-end tick deals the stacks and halves them")
	# Stone: stores nothing, its crits launch nothing.
	var stone = a._add_ball({id = "ball_junk", rank = 1}, Vector2(480, 600))
	a._launch(stone)
	var in_bag2: int = a.bag.size()
	a._damage(a._bricks("plain").front(), stone)
	a._crit(a._bricks("plain").front(), stone)
	assert(stone.stored == 0 and a.bag.size() == in_bag2, "a stone stores nothing and its crits launch nothing")
	# Blaster: every nth break this fight blasts the brick's neighbours for the ball.
	var blaster = a._add_ball({id = "ball_bomb", rank = 3}, Vector2(480, 600))
	a._launch(blaster)
	_pull_refresh(a)  # a blast reaching a refresh brick would regrow the board
	before = a.breakable
	for i in P.ball_bomb.every[2]:  # each at a plain with a live neighbour, so the nth break's blast has something to break
		a._damage(a._bricks("plain").filter(func(p): return not a._near(p, Tuning.BOMB_RADIUS).is_empty()).front(), blaster)
	assert(blaster.entry.breaks >= P.ball_bomb.every[2] and a.breakable < before - P.ball_bomb.every[2], "the blaster's nth break blasted its neighbours")
	var bp = a._bricks("plain").filter(func(p): return a._near(p, Tuning.BOMB_RADIUS).any(func(o): return o.kind == "plain")).front()
	var bb = _bomb_at(a, a._near(bp, Tuning.BOMB_RADIUS).filter(func(o): return o.kind == "plain").front())
	for o in a._near(bp, Tuning.BOMB_RADIUS):  # the bomb alone in reach, so no break of this blast fires another
		if o != bb:
			a.breakable -= 1
			o.queue_free()
	blaster.entry.breaks = P.ball_bomb.every[2] - 1
	a._damage(bp, blaster)
	assert(bb.hp == 1 and bb in a._live(), "the blaster's blast arms an unarmed bomb in range, never detonates it")
	a.hurt(Game.run.hp)
	assert(a.over and hit[2] and Game.run.hp == 0 and Game.run.stats.killer == "glob", "HP at 0 loses the fight")
	await get_tree().create_timer(Tuning.RUN.end_beat + 0.5).timeout
	a.queue_free()
	await get_tree().process_frame

	# A third fight: every hazard by hand. Enemy balls fan at the paddle after the wind-up; one on the paddle costs its hp.
	Game.run.hp = Game.run.hp_max
	var H := Tuning.HAZARDS
	a = load("res://src/arena.gd").new()
	add_child(a)
	await get_tree().process_frame
	var org = a.organs[0]
	org.dead = true
	a._hazard(org, "enemy_balls", 3)
	assert(a.hazards.is_empty(), "an organ that died during its wind-up fires nothing")
	org.dead = false
	a._hazard(org, "enemy_balls", 3)
	assert(a.hazards.size() == 1 and a.hazards[0].vel == Vector2.ZERO and a.hazards[0].position == org.position, "the wind-up ring is up on the organ")
	await get_tree().create_timer(H.enemy_balls.windup + H.enemy_balls.gap * 2 + 0.1).timeout
	assert(a.hazards.size() == 3 and a.hazards.all(func(h): return h.kind == "enemy_balls" and h.vel.y > 0), "three enemy balls fly down after the wind-up and the ring is gone")
	hp0 = Game.run.hp
	a.hazards[0].position = a.paddle.position
	for i in 2:
		await get_tree().physics_frame
	assert(Game.run.hp == hp0 - H.enemy_balls.hp and a.hazards.size() == 2, "an enemy ball on the paddle costs its hp and is gone")
	# A phase end clears what is in flight, pending volleys included; a fresh debris volley falls from the organ and lands on the floor.
	a._hazard(org, "debris", 2)
	a._phase_end()
	await get_tree().create_timer(H.debris.shake + H.debris.gap + 0.1).timeout
	assert(a.hazards.is_empty() and a.volley.is_empty(), "a phase end clears flight hazards and their pending volley")
	a._hazard(org, "debris", 2)
	await get_tree().create_timer(H.debris.shake + H.debris.gap + 0.1).timeout
	assert(a.hazards.size() == 2 and a.hazards.all(func(h): return h.kind == "debris" and h.vel.y == H.debris.speed and h.src == org.id and h.position.y > org.position.y) and is_equal_approx(absf(a.hazards[0].position.x - a.hazards[1].position.x), H.debris.apart), "two debris chunks fall from the organ, apart")
	for h in a.hazards:
		h.position.y = a.field.size.y
	for i in 2:
		await get_tree().physics_frame
	assert(a.hazards.is_empty(), "debris at the floor is gone")
	# Laser: two lanes, the paddle's column and its mirror; the beam charges the paddle under it once and empties a ball in the lane.
	a.paddle.position.x = a._lane_x(2)
	a.target_x = a.paddle.position.x
	a._hazard(org, "laser_sweep", 2)
	var lanes: Array = a.hazards.filter(func(h): return h.kind == "laser_sweep")
	assert(lanes.size() == 2 and lanes[0].position.x == a._lane_x(2) and lanes[1].position.x == a._lane_x(Tuning.BOARDS.fight.cols - 3) and lanes[0].state == "warn", "two laser lanes warn on the paddle's column and its mirror")
	var zap = a._add_ball({id = "ball_basic", rank = 1}, Vector2(a._lane_x(2), 500))
	a._launch(zap)
	zap.store(5)
	hp0 = Game.run.hp
	for h in lanes:
		h.t = 0.0
	for i in 2:
		await get_tree().physics_frame
	assert(lanes[0].state == "beam" and Game.run.hp == hp0 - H.laser_sweep.hp and zap.stored == 0, "the beam charged the paddle once and emptied the ball under it")
	a.balls.erase(zap)  # before it reaches a brick (a red would cost HP) or falls back onto the paddle (a hit would count down)
	zap.free()
	await get_tree().create_timer(H.laser_sweep.beam + 0.1).timeout
	assert(Game.run.hp == hp0 - H.laser_sweep.hp and a.hazards.filter(func(h): return h.kind == "laser_sweep").is_empty(), "the beam paid once and the lanes are gone")
	# Shield row: a solid per column at SHIELD_Y, crumbling when the paddle hits run out; a refire resets the count.
	a._hazard(org, "shield_row", 1)
	assert(a.shield.size() == Tuning.BOARDS.fight.cols and a.shield_left == H.shield_row.hits and a.shield.all(func(b): return b.kind == "solid" and b.position.y == Tuning.SHIELD_Y), "the shield row raised a solid per column")
	a.shield_left = 1
	a._hazard(org, "shield_row", 1)
	assert(a.shield_left == H.shield_row.hits and a.shield.size() == Tuning.BOARDS.fight.cols, "a refire resets the hits without a second row")
	a.shield_left = 1
	a._paddle_hit(a.rest)  # the resting ball never moves on its own, so no stray paddle hit sneaks in
	assert(a.shield.is_empty() and a.shield_left == 0, "the last paddle hit crumbled the shield row")
	# Riposte: a shot at or over the mark takes RIPOSTE_CUT seconds off the countdown.
	org.row.riposte = 10
	org.hp = 999
	org.cd_left = Tuning.RIPOSTE_CUT * 2
	var shot = a._add_ball({id = "ball_basic", rank = 1}, Vector2(30, 600))
	shot.store(10)
	a._organ_hit(org, shot, org.cells[0])
	assert(is_equal_approx(org.cd_left, Tuning.RIPOSTE_CUT) and not shot in a.balls, "a riposte shot cuts the countdown")
	# Layers (docs/encounter-mechanics.md "Layers"): a shield takes its hp in hits and the brick stores nothing, then the
	# next hit reaches the brick; a blast strips a shield instead of breaking; a needle skips it.
	var LY := Tuning.LAYERS
	org.cd_left = 100.0  # so no ward cut below lets the organ act
	var tap = a._add_ball({id = "ball_basic", rank = 1}, Vector2(30, 600))
	var bare := func() -> Array: return a._bricks("plain").filter(func(b): return b.layer.is_empty() and b.source == "")
	var sb = bare.call()[0]
	sb.add_layer("shield", LY.shield.hp, "design")
	for i in LY.shield.hp:
		a._hit(sb, tap)
	assert(sb in a._live() and sb.layer.is_empty() and tap.stored == 0, "a shield took its hits and the brick stored nothing")
	a._hit(sb, tap)
	assert(not sb in a._live() and tap.stored > 0, "the next hit broke the bare brick")
	tap.store(-tap.stored)
	sb = bare.call()[0]
	sb.add_layer("shield", 1, "design")
	a._trigger(sb)
	assert(sb in a._live() and sb.layer.is_empty(), "a blast stripped the shield and left the brick")
	sb = bare.call()[0]
	sb.add_layer("shield", LY.shield.hp, "design")
	var pin = a._add_ball({id = "ball_pierce", rank = 1}, Vector2(30, 600))
	a._hit(sb, pin)
	assert(not sb in a._live(), "a needle broke a shielded brick in one hit")
	a.balls.erase(pin)
	pin.free()
	sb = bare.call()[0]
	sb.add_layer("shield", LY.shield.hp, "design")
	assert(not sb.add_layer("ward", 1, "x") and sb.add_layer("shield", 1, "design") and sb.layer.hp == LY.shield.hp + 1, "one layer per brick: another kind is refused, the same kind adds hp")
	assert(not sb.add_layer("shield", 1, "enemy:x") and sb.layer.source == "design", "the same kind from another source is refused, so a death drops only its own")
	# A keep converts a shielded plain and the shield stays, unless its target is "no layer".
	_pull_refresh(a)
	for b in a._bricks("plain"):
		b.add_layer("shield", 1, "design")
	var keeps0: Array = a.keeps
	a.keeps = [{when = "keep", to = "refresh", count = 1, target = "no layer", source = "design"}]
	a._keep()
	assert(a.pending == 1 and a._bricks("refresh").is_empty(), "a no-layer keep passed over the shielded plains and owes")
	a.keeps = keeps0
	a._keep()
	assert(not a._bricks("refresh").is_empty() and a._bricks("refresh").all(func(b): return b.layer.get("kind") == "shield"), "the converted refresh kept its shield")
	_pull_refresh(a)
	for b in a._live():
		b.drop_layer()
	# Gilded is passive: the hit goes through and the break pays.
	sb = bare.call()[0]
	sb.add_layer("gilded", 1, "design")
	var gold_g: int = Game.run.gold
	a._trigger(sb)
	assert(not sb in a._live() and Game.run.gold == gold_g + LY.gilded.gold, "a gilded brick paid its gold on break")
	# A ward on an organ cell refuses the cash-in: the ball stays live and charged, the organ's clock hurries.
	var cell = org.cells[0]
	cell.add_layer("ward", LY.ward.hp, "enemy:" + org.id)
	tap.store(5)
	var org_hp: int = org.hp
	a._hit(cell, tap)
	a._hit(cell, tap)  # the same touch again in this physics frame: the one-hit guard holds for the ward too
	assert(org.hp == org_hp and tap in a.balls and tap.stored == 5 and is_equal_approx(org.cd_left, 100.0 - LY.ward.cut) and cell.layer.hp == LY.ward.hp - 1, "a ward refused the cash-in and hurried its organ")
	cell.drop_layer()
	a.balls.erase(tap)
	tap.free()
	# shield_bricks: the nearest live bricks and the organ's own cells gain a shield from that organ.
	var src: String = "enemy:" + org.id
	var nearest: Array = a._live()
	nearest.sort_custom(func(x, y): return x.position.distance_to(org.position) < y.position.distance_to(org.position))
	a._hazard(org, "shield_bricks", 3)
	assert(nearest.slice(0, 3).all(func(b): return b.layer.get("source") == src) and a._live().filter(func(b): return b.layer.get("source") == src).size() == 3, "shield_bricks shielded the three nearest bricks")
	assert(org.cells.all(func(c): return c.layer.get("kind") == "shield" and c.layer.source == src), "shield_bricks shielded the organ's cells")
	var red = bare.call()[0]
	a._paint(red.get_instance_id(), 0, org.id)
	assert(red.kind == "red" and red.source == src, "the organ painted a red")
	# Jackpot: breaking every gold standing at the phase start pays it, though the start picture held more.
	a.enc.jackpot = 9
	var golds: Array = bare.call().slice(0, 2)
	for g in golds:
		a._convert(g, "gold")
	a.phase_golds = golds.size()
	a.phase_gold = 0
	var gold_j: int = Game.run.gold
	for g in golds:
		a._trigger(g)
	assert(Game.run.gold == gold_j + 9, "the phase that broke every standing gold paid the jackpot")
	a.enc.erase("jackpot")
	org.cells[0].add_layer("gilded", 1, "design", true)
	var gold_d: int = Game.run.gold
	# The win breaks the board outward and clears the hazards.
	a._hazard(org, "laser_sweep", 1)
	a._land(org, org.hp)
	assert(a.over and a.hazards.is_empty(), "the win cleared the hazards")
	assert(Game.run.gold == gold_d + LY.gilded.gold, "a gilded coat on an organ cell paid as the organ died")
	var late = bare.call()[0]  # picked after the death: its keeps may have taken a plain
	a._paint(late.get_instance_id(), 0, org.id)
	assert(late.kind == "plain" and late.source == "", "a paint landing after its organ died does nothing")
	assert(red.kind != "red" and red.source != src and a.get_children().all(func(b): return not "layer" in b or b.is_queued_for_deletion() or b.layer.get("source") != src), "the organ's death reverted its red (the keeps may take it) and dropped its layers")
	await get_tree().create_timer(Tuning.RUN.win_break + 0.2).timeout
	assert(a._live().is_empty(), "the win broke every brick outward")
	a.queue_free()
	await get_tree().process_frame

	# A fourth fight holding every relic (docs/content.md "Relics"): the stat ones show at the build, the hooks fire by hand.
	Game.run.hp = Game.run.hp_max
	Game.run.relics = Tuning.RELICS.keys()
	var R := Tuning.RELICS
	a = load("res://src/arena.gd").new()
	add_child(a)
	await get_tree().process_frame
	assert(a.paddle.size.x == R.wide_paddle.width and a.mini and a.mini.size == R.mini_paddle.size and a.saves_left == R.shield_floor.saves, "wide paddle, mini paddle and shield floor are up at fight start")
	assert(a.layout.filter(func(s): return s.kind == "bomb").size() > Tuning.BOARDS.fight.bomb[1], "tenth bomb turned plain bricks into bombs past the generator's max")
	assert(a._bricks("bomb").filter(func(b): return b.source == "relic:tenth_bomb").size() == a.layout.filter(func(s): return s.source == "relic:tenth_bomb").size() and a._bricks("bomb").any(func(b): return b.source == "relic:tenth_bomb"), "tenth bomb's bombs carry its source")
	var tenth: Array = a.layout.filter(func(s): return s.slot == "standard" and s.source in ["", "relic:tenth_bomb"])  # the plain start picture, row-major
	assert(tenth.size() >= 10 and range(tenth.size()).all(func(i): return (tenth[i].source == "relic:tenth_bomb") == ((i + 1) % 10 == 0)), "tenth bomb's effect row converted every 10th standard plain")
	a.paddle.position.x = 300
	a._move_paddle(0)
	assert(a.mini.position.x == a.field.size.x - a.paddle.position.x, "the mini paddle mirrors the main one")
	var chunk = a._hazard_node("debris", a.mini.position, "debris_fall")
	chunk.vel = Vector2.DOWN
	hp0 = Game.run.hp
	for i in 2:
		await get_tree().physics_frame
	assert(Game.run.hp == hp0 - H.debris.hp and a.hazards.is_empty(), "a hazard on the mini paddle costs its hp")
	a._launch_rest()
	var saved_ball = a.balls[0]
	saved_ball.position = Vector2(480, a.field.size.y + 100)
	saved_ball.vel = Vector2.DOWN * Tuning.BALL_SPEED
	for i in 2:
		await get_tree().physics_frame
	assert(is_instance_valid(saved_ball) and saved_ball in a.balls and saved_ball.vel.y < 0 and a.saves_left == 0, "the shield floor bounced the phase's first drop straight up")
	# Opener: the phase's first break is a crit, and twin crit makes it two launches. Combo: a second break inside the window multiplies the store.
	in_bag = a.bag.size()
	a._damage(a._bricks("plain").front(), saved_ball)
	assert(a.balls.size() == 3 and a.bag.size() == in_bag - R.twin_crit.launches and a.combo == 1 and saved_ball.stored == saved_ball.dmg, "the opener's crit launched two bag balls; the first break stores at x1")
	a._damage(a._bricks("plain").front(), saved_ball)
	assert(a.combo == 2 and a.combo_mult() == 1 + Tuning.COMBO_MULT_PER_HIT and saved_ball.stored == saved_ball.dmg + roundi(saved_ball.dmg * a.combo_mult()), "the second break inside the window stores at the combo multiplier")
	# Toll: a coin every `per` breaks this fight.
	var gold0: int = Game.run.gold
	while a.breaks < R.toll.per:
		a._damage(a._bricks("plain").front(), saved_ball)
	assert(Game.run.gold == gold0 + R.toll.gold and a.combo_mult() <= R.combo.cap, "the tenth break paid the toll; the combo stays capped")
	# Recall: the phase's first non-junk drop goes back on top of the bag at phase end instead of the discard pile.
	var entry: Dictionary = saved_ball.entry
	a._drop(saved_ball)
	assert(a.discard.back() == entry and a.dropped == [entry], "the drop went to the discard pile and was noted")
	a._phase_end()
	assert(a.bag.front() == entry and not entry in a.discard, "recall put the dropped ball back on top of the bag")
	for b in a.balls.duplicate():
		a.balls.erase(b)
		b.free()
	await get_tree().create_timer(Tuning.COMBO_WINDOW_START + 0.1).timeout
	assert(a.combo == 0, "the combo lapses after its window")
	a.queue_free()
	await get_tree().process_frame
	Game.run.relics = []

	# The boss: its mouth opens on the intent and eats a ball at the wall under it; below half HP it enrages; after its
	# paddle hits it closes and spits the eaten ball back as an enemy ball.
	a = load("res://src/arena.gd").new()
	a.encounter_id = "maw"
	add_child(a)
	await get_tree().process_frame
	assert(a.cls == "boss" and a.organs[0].hp == Tuning.ENEMIES.maw.hp and a.balls.size() == 1, "the maw fights on the boss board")
	a._hazard(a.organs[0], "mouth", 1)
	assert(a.mouth_left == Tuning.ENEMIES.maw.mouth and a.eaten == 0, "the mouth opened")
	var bite = a._add_ball({id = "ball_basic", rank = 1}, Vector2(Tuning.MOUTH.rect.get_center().x, Tuning.TOP_WALL + 20))
	a._launch(bite)
	var spent0: int = a.discard.size()
	for i in 8:
		await get_tree().physics_frame
	assert(a.eaten == 1 and not is_instance_valid(bite) and a.discard.size() == spent0 + 1, "a ball at the wall under the mouth is eaten into the discard pile")
	a._land(a.organs[0], a.organs[0].hp_max / 2 + 1)
	assert(a.organs[0].row.cd == Tuning.ENEMIES.maw.enraged.cd and a.organs[0].row.mouth == Tuning.ENEMIES.maw.enraged.mouth, "below half HP the maw enrages")
	for i in Tuning.ENEMIES.maw.mouth:
		a._paddle_hit(a.rest)
	await get_tree().create_timer(0.1).timeout
	assert(a.mouth_left == 0 and a.hazards.filter(func(h): return h.kind == "enemy_balls").size() == 1, "the mouth closed after its hits and spat the eaten ball back")
	await get_tree().create_timer(1.0).timeout  # the attack's volley and the delayed cues (the boss board's ten spawn ticks run to 0.8 s), else they leak at quit
	a.queue_free()
	await get_tree().process_frame

	# Map 1 (docs/content/maps/back-alley-arcade.md): jam halves the paddle for its hits, pull lifts the balls, coin_junk
	# tops the bag with stones; below half HP the attract mode's enemy balls copy the run bag.
	a = load("res://src/arena.gd").new()
	a.encounter_id = "attract_mode"
	add_child(a)
	await get_tree().process_frame
	a.organs[0].cd_left = 999  # no intent fires mid-check
	var w0: float = a.paddle.size.x
	a._hazard(a.organs[0], "jam", 1)
	assert(a.jam_left == H.jam.hits and is_equal_approx(a.paddle.size.x, w0 * H.jam.width), "jam halves the paddle")
	for i in H.jam.hits:
		a._paddle_hit(a.rest)
	assert(a.jam_left == 0 and is_equal_approx(a.paddle.size.x, w0), "the paddle grows back after its hits")
	a._hazard(a.organs[0], "pull", 1)
	assert(a.pull_t == H.pull.secs, "pull lifts for its seconds")
	var queue0: int = a.bag.size()
	var run_bag0: int = Game.run.bag.size()
	a._hazard(a.organs[0], "coin_junk", 2)
	assert(a.bag.size() == queue0 + 2 and a.bag[0].id == H.coin_junk.junk and Game.run.bag.size() == run_bag0 + 2, "coin junk puts stones on top of the bag and in the run")
	a._land(a.organs[0], a.organs[0].hp_max / 2 + 1)
	assert(a.organs[0].row.cd == Tuning.ENEMIES.attract_mode.enraged.cd and a.organs[0].row.mimic, "below half HP the attract mode enrages")
	Game.run.bag = [{id = "ball_split", rank = 1}]
	var spat0: int = a.hazards.size()
	a._enemy_ball(a.organs[0], 0)
	assert(a.hazards.size() == spat0 + Tuning.BALLS.ball_split.split[0], "a mimicked splitter spits its fan")
	await get_tree().create_timer(1.2).timeout  # the cues and the pull strips, else they leak at quit
	a.queue_free()
	await get_tree().process_frame

	# The knight (docs/encounter-mechanics.md): three organs on their own clocks; a cell cashes in once a frame, refuses a
	# 0-charge touch; the sword dying leaves the fight on; a hazard's organ is the killer; the body dying wins.
	Game.run.hp = Game.run.hp_max
	a = load("res://src/arena.gd").new()
	a.encounter_id = "knight"
	add_child(a)
	var knight_won := [false]
	a.done.connect(func(w): knight_won[0] = w)
	await get_tree().process_frame
	var K: Dictionary = Tuning.ENCOUNTERS.knight
	var body = a.organs[0]
	var sword = a.organs[1]
	assert(a.organs.size() == 3 and a.organs.all(func(o): return o.cd_left == K.cd_start[a.organs.find(o)] and not o.cells.is_empty()), "the knight's three organs are up on their first countdowns")
	var k1 = a._add_ball({id = "ball_basic", rank = 1}, Vector2(480, 600))
	var k2 = a._add_ball({id = "ball_basic", rank = 1}, Vector2(480, 600))
	a._organ_hit(body, k1, body.cells[0])
	assert(body.hp == body.hp_max, "a 0-charge touch is refused")
	k1 = a._add_ball({id = "ball_basic", rank = 1}, Vector2(480, 600))
	k1.store(5)
	a._organ_hit(body, k1, body.cells[0])
	a._organ_hit(body, k1, body.cells[1])
	assert(body.hp == body.hp_max - 5, "two cells of one organ in a frame cash in once")
	k2.store(3)
	a._organ_hit(sword, k2, sword.cells[0])
	assert(sword.hp == sword.hp_max - 3 and body.hp == body.hp_max - 5, "each organ takes its own hits")
	a._land(sword, sword.hp)
	await get_tree().process_frame
	assert(sword.dead and not a.over and sword.cells.all(func(c): return not is_instance_valid(c)), "the sword dies, its cells go, the fight goes on")
	var cd_s: float = sword.cd_left
	a._count_down(1.0)
	assert(sword.cd_left == cd_s, "a dead organ's clock stops")
	var lump = a._hazard_node("debris", a.paddle.position, "debris_fall", "knight_shield")
	lump.vel = Vector2.DOWN
	Game.run.hp = H.debris.hp
	Game.run.stats.killer = ""
	for i in 2:
		await get_tree().physics_frame
	assert(a.over and Game.run.stats.killer == "knight_shield", "the hazard's organ is the killer")
	Game.run.hp = Game.run.hp_max
	await get_tree().create_timer(Tuning.RUN.end_beat + 0.5).timeout
	a.queue_free()
	await get_tree().process_frame
	a = load("res://src/arena.gd").new()
	a.encounter_id = "knight"
	add_child(a)
	a.done.connect(func(w): knight_won[0] = w)
	await get_tree().process_frame
	a._land(a.organs[0], a.organs[0].hp)
	assert(a.over and not a.organs[1].dead, "the body at 0 wins with the other organs standing")
	await get_tree().create_timer(Tuning.RUN.end_beat + 0.5).timeout
	assert(knight_won[0], "the knight fight ends done(true)")
	a.queue_free()
	await get_tree().process_frame

	# The run's screens through main.gd (docs/content.md "Screens"): CONTINUE resumes the pending fight; a won fight shows
	# the reward over the arena and SKIP returns to the map; the shop heals once and removes a ball; an event choice shows
	# its result and CONTINUE returns to the map; the end screen deletes the save and MENU leaves.
	Game.new_run(7)
	Game.enter_node(0)  # pending fight, saved
	Game.run = {}
	main = load("res://src/main.gd").new()
	add_child(main)
	await get_tree().process_frame
	assert(_button(main, "CONTINUE") and await _click(main, "CONTINUE") and main.get_child(0).get_script() == load("res://src/arena.gd") and main.get_child(0).encounter_id == Game.run.map.enemies[0][0], "CONTINUE resumes the pending fight against its enemy")
	await get_tree().process_frame
	# The fight end to end through main.gd: a launch, a shot that kills, the arena's own done signal brings the reward.
	var gold1: int = Game.run.gold
	var fight = main.get_child(0)
	fight._launch_rest()
	fight.balls[0].store(fight.organs[0].hp)
	fight._organ_hit(fight.organs[0], fight.balls[0], fight.organs[0].cells[0])
	assert(fight.over and fight.organs[0].hp <= 0, "one organ hit landing its HP wins the fight")
	await fight.done
	await get_tree().process_frame
	assert(Game.run.gold >= gold1 + Tuning.GOLD.fight[0] and main.get_child_count() == 2 and await _click(main, "SKIP"), "a won fight pays gold and shows the reward, SKIP leaves it")
	await get_tree().process_frame
	assert(Game.run.pending == "" and Game.has_run() and _button(main, "SKIP") == null, "the map saved with the node resolved")
	var m: Dictionary = Game.run.map
	# The catalog: the starting bag and the enemy just fought are marked seen; then back to the map.
	assert("ball_basic" in Game.settings.meta.seen and m.enemies[m.layer][m.node] in Game.settings.meta.seen, "the starting bag and the first enemy are in the catalog")
	main._show_catalog()
	await get_tree().process_frame
	assert(_button(main, "BACK") != null, "the catalog opens with a BACK button")
	main._show_catalog(true)  # the encounters page: every band, summed organ HP and every organ's intents
	await get_tree().process_frame
	assert(_button(main, "BALLS") != null, "the encounters page opens")
	main._show_map()
	main._pick_node(Tuning.MAP[0].edges[0][0])
	await get_tree().process_frame
	assert(m.layer == 1 and Game.run.pending == m.layers[1][m.node], "a map click enters the next layer's node")
	# The shop, forced: stock rolled once, HEAL once, REMOVE picks a bag row, LEAVE.
	Game.run.hp = 10
	Game.run.gold = 100
	main._show_shop()
	await get_tree().process_frame
	var stock: Dictionary = Game.run.shop.duplicate(true)
	assert(stock.balls.size() == 3 and stock.relics.size() == 2 and await _click(main, "HEAL") and Game.run.hp == 10 + Tuning.SHOP.heal_hp and Game.run.gold == 100 - Tuning.SHOP.heal and Game.run.shop.healed, "HEAL pays and heals once")
	await get_tree().process_frame
	assert(_button(main, "HEAL").disabled and Game.run.shop.balls == stock.balls, "HEAL is spent and the stock is the same after the rebuild")
	var bag0: int = Game.run.bag.size()
	assert(await _click(main, "REMOVE"), "REMOVE enters pick mode")
	await get_tree().process_frame
	main._remove_pick(0)
	await get_tree().process_frame
	assert(Game.run.bag.size() == bag0 - 1 and Game.run.gold == 100 - Tuning.SHOP.heal - Tuning.SHOP.remove, "picking a bag row removes the ball and pays")
	main._buy("balls", 0, Tuning.SHOP.ball)
	await get_tree().process_frame
	assert(Game.run.bag.size() == bag0 and Game.run.bag.back().id == stock.balls[0] and Game.run.shop.balls.size() == 2, "buying a ball card adds it to the bag and takes the card")
	assert(await _click(main, "LEAVE") and not Game.run.has("shop"), "LEAVE drops the stock and returns to the map")
	await get_tree().process_frame
	# An event, forced onto the node stood on.
	m.events[m.layer][m.node] = "event_spring"
	main._show_event()
	await get_tree().process_frame
	hp0 = Game.run.hp
	assert(await _click(main, "BATHE") and Game.run.hp == hp0 + Tuning.EVENTS.event_spring.heal and Game.run.pending == "", "the spring's bath heals and the choice is saved")
	await get_tree().process_frame
	assert(await _click(main, "CONTINUE") and _button(main, "LEGEND") == null and _button(main, "CONTINUE") == null, "CONTINUE returns to the map")
	await get_tree().process_frame
	# Meta-unlocks on fresh meta (the real settings.json is kept and written back): the elite's death sets its flag before
	# its reward; a lost run counts, sets finished_run and lists every id it opened on the end screen.
	var kept_settings := FileAccess.get_file_as_string(Game.SETTINGS_PATH) if FileAccess.file_exists(Game.SETTINGS_PATH) else ""
	var meta0: Dictionary = Game.settings.meta.duplicate(true)
	Game.settings.meta = {flags = [], runs = 0, wins = 0}
	m.layer = 2
	m.node = 0
	m.enemies[2][0] = "warden"
	main._fight_done(true)
	await get_tree().process_frame
	assert(Game.unlocked("ball_poison") and Game.unlocked("mini_paddle") and Game.run.unlocked == Tuning.UNLOCKS.killed_elite and _button(main, "SKIP"), "the elite's death unlocks spore and mini paddle before its reward")
	# The end: the save goes, MENU leaves with PLAY but no CONTINUE.
	Game.run.stats.killer = "warden"
	main._fight_done(false)
	await get_tree().process_frame
	var line: Array = main.find_children("*", "Label", true, false).filter(func(l): return l.text.begins_with("UNLOCKED:"))
	assert(Game.settings.meta.runs == 1 and Game.settings.meta.wins == 0 and Game.unlocked("ball_bomb") and line.size() == 1 and "BLASTER" in line[0].text and "SPORE" in line[0].text, "a lost run counts, unlocks the blaster and lists this run's unlocks")
	assert(not Game.has_run() and _button(main, "NEW RUN") and await _click(main, "MENU") and _button(main, "PLAY") and _button(main, "CONTINUE") == null, "the end screen deletes the save; the menu offers no CONTINUE")
	await get_tree().process_frame
	assert(main.find_children("*", "Label", true, false).any(func(l): return l.text == "RUNS 1  WINS 0"), "the menu shows the run count")
	# The encounter editor: paint, move, copy and paste, the setup page, a save round trip, a test play stopped by Esc.
	assert(await _click(main, "EDITOR"), "the menu opens the editor")
	await get_tree().process_frame
	var ed = main.get_child(0)
	ed.tool = "x"
	ed.place(Vector2i(0, 0))
	ed.place(Vector2i(1, 0))  # overlaps the first: refused
	ed.tool = "1"
	ed.place(Vector2i(4, 1))
	assert(ed.cells == {Vector2i(0, 0): "x", Vector2i(4, 1): "1"}, "pieces snap to their cell and never overlap")
	ed.sel = {Vector2i(0, 0): true}
	ed.move(Vector2i(1, 2))
	ed.move(Vector2i(100, 0))  # off the board: refused
	assert(ed.cells.has(Vector2i(1, 2)) and ed.rows()[2].begins_with(".xx"), "a selection moves by whole cells, half a brick included")
	ed.copy()
	ed.paste(Vector2i(5, 2))
	assert(ed.cells.size() == 3, "a copy pastes beside the original")
	ed.tool = "+s"
	ed.coat(Vector2i(2, 2))  # the plain's right cell
	ed.tool = "+w"
	ed.coat(Vector2i(4, 1))
	ed.tool = "+g"
	ed.coat(Vector2i(5, 2))
	ed.erase(Vector2i(6, 2))  # a layer tool's right button strips the coat only
	assert(ed.cells == {Vector2i(1, 2): "xs", Vector2i(4, 1): "1w", Vector2i(5, 2): "x"} and ed.row().board.layers[2].begins_with(".ss....") and ed.row().board.layers[1].begins_with("....ww.."),
		"a layer tool coats the piece under it, its right button strips the coat, and board.layers carries the coats")
	ed.set_keep(1)
	assert(not ed.enc.has("effects") and ed.keep() == 1, "the default refresh keep saves no effects")
	ed.set_keep(2)
	assert(ed.enc.effects == [{when = "keep", to = "refresh", count = 2}] and ed.keep() == 2, "a refresh keep count off the default saves as the encounter's effects")
	ed.page = "setup"
	ed._build()
	ed.page = "board"
	ed.file = "_smoke"
	ed._save()
	var saved_rows: Array = ed.rows()
	ed._new()
	ed._load("res://encounters/_smoke.json")
	DirAccess.remove_absolute("res://encounters/_smoke.json")
	assert(ed.rows() == saved_rows and ed.cells[Vector2i(1, 2)] == "xs" and ed.cells[Vector2i(4, 1)] == "1w" and ed.keep() == 2 and ed.enc.organs.size() == 1, "an encounter file loads back as saved, coats and keep count included")
	ed._play()
	await get_tree().process_frame
	assert(ed.arena and ed.arena.organs.size() == 1 and ed.arena.organs[0].cells.size() == 1 and ed.arena.breakable == 2, "PLAY runs the encounter in the arena")
	var shielded: Array = ed.arena.slots.filter(func(b): return b.layer.get("kind") == "shield")
	assert(shielded.size() == 1 and shielded[0].layer.source == "design" and shielded[0].layer.hp == Tuning.LAYERS.shield.hp and ed.arena.organs[0].cells[0].layer.get("kind") == "ward",
		"PLAY stands the painted coats as design layers, on the organ cell too")
	assert(ed.arena.keeps.map(func(e): return [e.to, e.count, e.source]) == [["refresh", 2, "design"]] and ed.arena.slots.all(func(b): return b.kind == "refresh" and b.source == "design"),
		"PLAY keeps the edited refresh count: both plains turn refresh")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert(ed.arena == null and _button(main, "PLAY"), "Esc stops the test fight and returns to the editor")
	assert(await _click(main, "MENU") and _button(main, "EDITOR"), "MENU leaves the editor")
	Game.settings.meta = meta0
	if kept_settings:
		FileAccess.open(Game.SETTINGS_PATH, FileAccess.WRITE).store_string(kept_settings)
	else:
		DirAccess.remove_absolute(Game.SETTINGS_PATH)
	main.queue_free()
	await get_tree().create_timer(1.0).timeout  # the screens' delayed cues (coin, the board's spawn ticks), else they leak at quit
	if kept:
		FileAccess.open(Game.RUN_PATH, FileAccess.WRITE).store_string(kept)
	else:
		Game.delete_run()
	load("res://src/sfx.gd").quit()  # not get_tree().quit(): a cue still mixing at exit logs a leak


## Swaps the live brick p for a fresh, unarmed bomb in its layout slot.
func _bomb_at(a: Node2D, p) -> Node:
	var i: int = a.slots.find(p)
	a.breakable -= 1
	p.queue_free()
	a._spawn(i, "bomb")
	return a.slots[i]


## Pulls the refresh bricks without their effect: a broken refresh regrows the layout, itself included, which no board-emptying step can allow.
func _pull_refresh(a: Node2D) -> void:
	for b in a._bricks("refresh"):
		a.breakable -= 1
		b.queue_free()


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
