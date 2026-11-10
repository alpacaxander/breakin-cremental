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
	assert(a.enemy.hp == Tuning.ENEMIES.glob.hp and a.enemy.cd_left == Tuning.ENEMIES.glob.cd and a.bag.size() == Game.run.bag.size() - 1, "the enemy is up and the bag holds the rest")
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

	# Store and fire: a break stores the ball's dmg, paddle contact lands it on the enemy and counts the intent down.
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
	# Hits the enemy, then the blast's neighbours are credited to the ball: aimed at a plain with a plain neighbour, so there is one to credit.
	_pull_refresh(a)  # a blast reaching the refresh brick would regrow the board
	a._effect("bomb", a._bricks("plain").filter(func(p): return a._near(p, Tuning.BOMB_RADIUS).any(func(o): return o.kind == "plain")).front(), ball)
	assert(a.breakable < before - 3 and ball.stored > ball.dmg and a.enemy.hp <= Tuning.ENEMIES.glob.hp - Tuning.BRICKS.bomb.blast, "the bomb hit the enemy and broke its neighbours for the ball")
	var stored: int = ball.stored
	var hp_e: int = a.enemy.hp
	a._paddle_hit(ball)
	assert(a.enemy.hp == hp_e - stored and ball.stored == 0 and ball.tag.text == "" and not ball.tag_s.visible and a.phase_dmg == stored + Tuning.ENEMIES.glob.hp - hp_e and a.enemy.cd_left == Tuning.ENEMIES.glob.cd - 1, "paddle contact fires the stored damage and counts down")
	for i in Tuning.ENEMIES.glob.cd - 1:
		a._paddle_hit(ball)
	assert(a.enemy.intent == 1 and a.enemy.cd_left == Tuning.ENEMIES.glob.cd, "the countdown fired the intent and showed the next")
	var reds: int = a._bricks("red").size()  # the glob's first intent paints red bricks on the attack's spawn frame; checked after the beat below
	# Crit launches the bag's next ball; drops end the phase after the beat, then the next ball rests.
	var in_bag: int = a.bag.size()
	var in_play: int = a.balls.size()  # the bomb blast above may have broken a crit and launched one already
	a._effect("crit", a._bricks("plain").front(), ball)
	assert(a.balls.size() == in_play + 1 and a.bag.size() == in_bag - 1 and a.balls.back().vel.y < 0, "a crit launched the bag's next ball")
	for b in a.balls.duplicate():
		b.position.y = a.field.size.y + 100
	for i in 3:  # physics_frame fires before the step, so the drop lands a frame later
		await get_tree().physics_frame
	assert(a.balls.is_empty() and a.discard.size() == in_play + 1 and a.beat > 0 and Game.run.stats.drops == in_play + 1, "dropped balls go to the discard pile and start the beat")
	await get_tree().create_timer(Tuning.RUN.enemy_turn + 0.2).timeout
	assert(a.phase == 2 and a.rest != null and a.balls.size() == 1, "the next phase rested a ball")
	assert(a._bricks("red").size() == reds + Tuning.ENEMIES.glob.intents[0][1], "the intent painted its red bricks onto standing plain ones, and the phase end kept them")
	var head: String = a.rest.id
	a._discard()
	assert(a.discarded and a.discard.size() == in_play + 2 and a.discard.back().id == head and a.rest != null, "discard swaps the resting ball for the next")
	# Refresh: broken layout slots regrow; a bare board with a ball live grows a refresh brick.
	before = a.breakable
	a._trigger(a._bricks("plain").front())
	a._refresh()
	assert(a.breakable > before and a._empty_slots().is_empty(), "a refresh regrew every broken slot")
	var fresh = a._bricks("refresh").front()
	a._trigger(fresh)
	assert(a._empty_slots().size() == 1 and fresh.is_queued_for_deletion(), "a refresh brick never regrows itself")
	a._refresh()
	a._launch_rest()
	a.balls[0].position.x = 30  # off the board, so the live ball meets no brick while the test looks
	a.bag = []  # so the crits broken below launch nothing
	a.enemy.hp = 999  # so the bombs' direct damage below cannot win the fight first
	_pull_refresh(a)
	for b in a._live():
		a._trigger(b)
	assert(a.breakable == 0 and a.refresh_in > 0 and a.in_play() == 1, "a bare board with a ball live waits for a refresh brick")
	await get_tree().create_timer(Tuning.RUN.refresh_after + 0.1).timeout
	assert(a._bricks("refresh").size() == 1 and a.breakable == 1, "the refresh brick grew")
	# HP loss short of 0 keeps the fight going; the enemy at 0 wins it, then done(true) after the end beat.
	hp_run = Game.run.hp
	a.hurt(1)
	assert(Game.run.hp == hp_run - 1 and not a.over, "hurt costs HP without ending the fight")
	var hit := [false, false, false]
	a.won.connect(func(): hit[0] = true)
	a.done.connect(func(w): hit[1] = w)
	a._land(a.enemy.hp)
	assert(a.over and hit[0] and not hit[1] and Game.run.stats.fights == 1, "the enemy at 0 HP wins the fight")
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
	for i in 6:
		await get_tree().physics_frame
	assert(needle.pierce_left < P.ball_pierce.pierce[0] and needle.vel.y < 0 and needle.stored > 0, "the needle broke a brick and passed through on its heading")
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
	# Gum: the first paddle contact lands the damage and sticks; fired, it flies up; no catches left, it bounces.
	var gum = a._add_ball({id = "ball_sticky", rank = 1}, Vector2(480, 600))
	a._launch(gum)
	gum.store(4)
	var hp0: int = a.enemy.hp
	a._paddle_hit(gum)
	assert(gum.hold > 0 and gum.vel == Vector2.ZERO and gum.catches_left == 0 and gum.stored == 0 and a.enemy.hp == hp0 - 4, "gum's first paddle contact fires its damage and sticks")
	a._sticky_fire(gum)
	assert(gum.hold == 0 and gum.vel.y < 0 and is_equal_approx(gum.vel.length(), Tuning.BALL_SPEED * gum.speed), "fired gum flies up at its speed")
	a._paddle_hit(gum)
	assert(gum.hold == 0, "gum with no catches left bounces")
	# Spore: breaks store stacks, paddle contact lands them, the phase-end tick deals them and halves them.
	var spore = a._add_ball({id = "ball_poison", rank = 2}, Vector2(480, 600))
	a._launch(spore)
	a._damage(a._bricks("plain").front(), spore)
	assert(spore.poison == P.ball_poison.poison[1] and spore.stored == 0, "a spore stores stacks and no damage at rank 2")
	a._paddle_hit(spore)
	assert(a.enemy.poison == P.ball_poison.poison[1] and spore.poison == 0, "paddle contact lands the stacks on the enemy")
	hp0 = a.enemy.hp
	a._phase_end()
	assert(a.enemy.hp == hp0 - P.ball_poison.poison[1] and a.enemy.poison == P.ball_poison.poison[1] / 2, "the phase-end tick deals the stacks and halves them")
	# Stone: stores nothing, its crits launch nothing.
	var stone = a._add_ball({id = "ball_junk", rank = 1}, Vector2(480, 600))
	a._launch(stone)
	var in_bag2: int = a.bag.size()
	a._damage(a._bricks("plain").front(), stone)
	a._effect("crit", a._bricks("plain").front(), stone)
	assert(stone.stored == 0 and a.bag.size() == in_bag2, "a stone stores nothing and its crits launch nothing")
	# Blaster: every nth break this fight blasts the brick's neighbours for the ball.
	var blaster = a._add_ball({id = "ball_bomb", rank = 3}, Vector2(480, 600))
	a._launch(blaster)
	_pull_refresh(a)  # a blast reaching a refresh brick would regrow the board
	before = a.breakable
	for i in P.ball_bomb.every[2]:  # each at a plain with a live neighbour, so the nth break's blast has something to break
		a._damage(a._bricks("plain").filter(func(p): return not a._near(p, Tuning.BOMB_RADIUS).is_empty()).front(), blaster)
	assert(blaster.entry.breaks >= P.ball_bomb.every[2] and a.breakable < before - P.ball_bomb.every[2], "the blaster's nth break blasted its neighbours")
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
	a._hazard("enemy_balls", 3)
	assert(a.hazards.size() == 1 and a.hazards[0].vel == Vector2.ZERO, "the wind-up ring is up")
	await get_tree().create_timer(H.enemy_balls.windup + H.enemy_balls.gap * 2 + 0.1).timeout
	assert(a.hazards.size() == 3 and a.hazards.all(func(h): return h.kind == "enemy_balls" and h.vel.y > 0), "three enemy balls fly down after the wind-up and the ring is gone")
	hp0 = Game.run.hp
	a.hazards[0].position = a.paddle.position
	for i in 2:
		await get_tree().physics_frame
	assert(Game.run.hp == hp0 - H.enemy_balls.hp and a.hazards.size() == 2, "an enemy ball on the paddle costs its hp and is gone")
	# A phase end clears what is in flight, pending volleys included; a fresh debris volley falls from the top wall and lands on the floor.
	a._hazard("debris", 2)
	a._phase_end()
	await get_tree().create_timer(H.debris.shake + H.debris.gap + 0.1).timeout
	assert(a.hazards.is_empty() and a.volley.is_empty(), "a phase end clears flight hazards and their pending volley")
	a._hazard("debris", 2)
	await get_tree().create_timer(H.debris.shake + H.debris.gap + 0.1).timeout
	assert(a.hazards.size() == 2 and a.hazards.all(func(h): return h.kind == "debris" and h.vel.y == H.debris.speed) and absf(a.hazards[0].position.x - a.hazards[1].position.x) >= H.debris.apart, "two debris chunks fall, spaced apart")
	for h in a.hazards:
		h.position.y = a.field.size.y
	for i in 2:
		await get_tree().physics_frame
	assert(a.hazards.is_empty(), "debris at the floor is gone")
	# Laser: two lanes, the paddle's column and its mirror; the beam charges the paddle under it once and empties a ball in the lane.
	a.paddle.position.x = a._lane_x(2)
	a.target_x = a.paddle.position.x
	a._hazard("laser_sweep", 2)
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
	a._hazard("shield_row", 1)
	assert(a.shield.size() == Tuning.BOARDS.fight.cols and a.shield_left == H.shield_row.hits and a.shield.all(func(b): return b.kind == "solid" and b.position.y == Tuning.SHIELD_Y), "the shield row raised a solid per column")
	a.shield_left = 1
	a._hazard("shield_row", 1)
	assert(a.shield_left == H.shield_row.hits and a.shield.size() == Tuning.BOARDS.fight.cols, "a refire resets the hits without a second row")
	a.shield_left = 1
	a._paddle_hit(a.rest)  # the resting ball never moves on its own, so no stray paddle hit sneaks in
	assert(a.shield.is_empty() and a.shield_left == 0, "the last paddle hit crumbled the shield row")
	# Riposte: a shot at or over the mark drops the countdown by two.
	a.enemy.riposte = 10
	a.rest.store(10)
	var cd0: int = a.enemy.cd_left
	a._paddle_hit(a.rest)
	assert(a.enemy.cd_left == cd0 - 2 and a.rest.stored == 0, "a riposte shot drops the countdown by two")
	# The win breaks the board outward and clears the hazards.
	a._hazard("laser_sweep", 1)
	a._land(a.enemy.hp)
	assert(a.over and a.hazards.is_empty(), "the win cleared the hazards")
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
	a.enemy_id = "maw"
	add_child(a)
	await get_tree().process_frame
	assert(a.cls == "boss" and a.enemy.hp == Tuning.ENEMIES.maw.hp and a.balls.size() == 1, "the maw fights on the boss board")
	a._hazard("mouth", 1)
	assert(a.mouth_left == Tuning.ENEMIES.maw.mouth and a.eaten == 0, "the mouth opened")
	var bite = a._add_ball({id = "ball_basic", rank = 1}, Vector2(Tuning.MOUTH.rect.get_center().x, Tuning.TOP_WALL + 20))
	a._launch(bite)
	var spent0: int = a.discard.size()
	for i in 4:
		await get_tree().physics_frame
	assert(a.eaten == 1 and not is_instance_valid(bite) and a.discard.size() == spent0 + 1, "a ball at the wall under the mouth is eaten into the discard pile")
	a._land(a.enemy.hp_max / 2 + 1)
	assert(a.enemy.cd == Tuning.ENEMIES.maw.enraged.cd and a.enemy.mouth == Tuning.ENEMIES.maw.enraged.mouth, "below half HP the maw enrages")
	for i in Tuning.ENEMIES.maw.mouth:
		a._paddle_hit(a.rest)
	await get_tree().create_timer(0.1).timeout
	assert(a.mouth_left == 0 and a.hazards.filter(func(h): return h.kind == "enemy_balls").size() == 1 and a.enemy.cd_left == Tuning.ENEMIES.maw.enraged.cd, "the mouth closed after its hits, spat the eaten ball back and the countdown reset to the enraged pace")
	await get_tree().create_timer(1.0).timeout  # the attack's volley and the delayed cues (the boss board's ten spawn ticks run to 0.8 s), else they leak at quit
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
	assert(_button(main, "CONTINUE") and await _click(main, "CONTINUE") and main.get_child(0).get_script() == load("res://src/arena.gd") and main.get_child(0).enemy_id == Game.run.map.enemies[0][0], "CONTINUE resumes the pending fight against its enemy")
	await get_tree().process_frame
	# The fight end to end through main.gd: a launch, a shot that kills, the arena's own done signal brings the reward.
	var gold1: int = Game.run.gold
	var fight = main.get_child(0)
	fight._launch_rest()
	fight.balls[0].store(fight.enemy.hp)
	fight._paddle_hit(fight.balls[0])
	assert(fight.over and fight.enemy.hp <= 0, "one paddle hit landing the enemy's HP wins the fight")
	await fight.done
	await get_tree().process_frame
	assert(Game.run.gold >= gold1 + Tuning.GOLD.fight[0] and main.get_child_count() == 2 and await _click(main, "SKIP"), "a won fight pays gold and shows the reward, SKIP leaves it")
	await get_tree().process_frame
	assert(Game.run.pending == "" and Game.has_run() and _button(main, "SKIP") == null, "the map saved with the node resolved")
	var m: Dictionary = Game.run.map
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
