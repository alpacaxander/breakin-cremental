extends Node2D
## One round: placement (place.gd), then play: paddle, ball physics, brick rules and effects, then the result (hud.gd).

signal done
signal again  # the result's PLAY AGAIN: same level, fresh round

const Tuning = preload("res://src/tuning.gd")
const Box = preload("res://src/brick.gd")
const Fx = preload("res://src/fx.gd")
const Ui = preload("res://src/ui.gd")
const Sfx = preload("res://src/sfx.gd")
const Place = preload("res://src/place.gd")
const Hud = preload("res://src/hud.gd")
const BALL_TEX := preload("res://assets/pixel/png/ball.png")
const TRAIL_TEX := preload("res://assets/pixel/png/anim_ball_trail.png")
const HAZARD_TEX := preload("res://assets/pixel/png/anim_hazard_strip.png")
const SHIELD_TEX := preload("res://assets/pixel/png/anim_shield_floor.png")


class Ball extends CharacterBody2D:
	var vel := Vector2.ZERO
	var speed := 1.0  # multiplier on Tuning.BALL_SPEED
	var hold := 0.0  # seconds left stuck to a sticky pad
	var grace := 0.0  # seconds left ignoring pass-through pieces

	func _init(radius: float) -> void:
		var c := CollisionShape2D.new()
		c.shape = CircleShape2D.new()
		c.shape.radius = radius
		add_child(c)

	func set_speed(s: float) -> void:
		speed = clampf(s, Tuning.SPEED_MIN, Tuning.SPEED_MAX)
		vel = vel.normalized() * Tuning.BALL_SPEED * speed


var level := 0
var launched := false
var over := false

var paddle: Box
var balls: Array[Ball] = []
var target_x := 0.0
var time_left := 0.0
var time_max := 0.0  # the round's starting clock, the HUD bar's full length
var combo := 0
var combo_timer := 0.0
var earned := 0
var breakable := 0
var total := 0  # breakable bricks at the start
var boost_mult := 1.0
var boost_hits := 0
var was_fast := false
var shields := 0  # shield floors left this round (Shield Floor upgrade)
var mode := ""  # plain brick idle: "", "pulse", "chase"

var placed: Array[Box] = []  # the player's pieces, handed over by place.gd at start
var best_combo := 0
var tally := {bricks = 0, combo = 0, specials = 0, boost = 0, jackpot = 0, pieces = 0}  # earned, split by what each factor added
var combos: Array = []  # every combo run of 2+: [length, pay]
var run_pay := 0  # paid during the current combo run
var ui: Ui.Root  # the cabinet: score column left (hud.gd), pieces column right (place.gd)
var place: Place
var hud: Hud
var pause: Control = null
var field: Rect2  # the arena in its own px: origin top-left. _fit scales the node into the cabinet's 4:3 field.


func _ready() -> void:
	field = Rect2(Vector2.ZERO, Game.arena_size(level))
	get_viewport().size_changed.connect(_fit)
	# Walls: left, right, top. Bottom is open, that's the drop. Then the level's own walls, if any.
	box("wall", Vector2(100, field.size.y * 3), Vector2(-50, field.size.y / 2))
	box("wall", Vector2(100, field.size.y * 3), Vector2(field.size.x + 50, field.size.y / 2))
	box("wall", Vector2(field.size.x, 100), Vector2(field.size.x / 2, -50))
	for w in Tuning.LEVELS[level].get("walls", []):
		box("wall", w.size, w.get_center())
	var rows := {}
	for b in Game.generate(level, randi()):
		var brick := box(b.kind, Tuning.BRICK_SIZE, b.pos)
		if brick.hp > 0:
			breakable += 1
		# Spawn-in, one row after another. The brick shows once its spawn strip ends.
		brick.hide()
		var row := int((b.pos.y - Tuning.BOARD_TOP) / (Tuning.BRICK_SIZE.y + Tuning.BRICK_GAP))
		if not row in rows:  # one tick per row as it lands
			rows[row] = true
			Sfx.play("count_tick", 1.0 + 0.06 * row, 0.08 * row)
		var id := brick.get_instance_id()  # not the box itself: a lambda holding a freed object logs an engine error
		create_tween().tween_callback(func():
			if instance_from_id(id):
				Fx.play(self, "mag_spawn", 30, 12, b.pos).animation_finished.connect(func(): if instance_from_id(id): instance_from_id(id).show())
		).set_delay(0.08 * row)
	paddle = box("paddle", Vector2(Game.paddle_width(), Tuning.PADDLE_HEIGHT), Vector2(field.size.x / 2, field.size.y - Tuning.PADDLE_UP))
	target_x = paddle.position.x
	_add_ball(Vector2.ZERO)
	_rest_ball()
	time_left = Game.round_time(level, breakable)
	time_max = time_left
	total = breakable
	shields = Game.rank("shield")

	ui = Ui.chassis("SCORE", "PIECES", true)
	add_child(ui)
	hud = Hud.new(self, ui)
	add_child(hud)
	place = Place.new(self, ui)
	place.started.connect(_on_start)
	add_child(place)
	_fit()


## Scales the arena to the largest that fits the cabinet's 4:3 field between the columns and centres it there on whole
## sprite px. Tuning.ARENA fills the field exactly; other ratios leave bare sheet beside or above the board.
func _fit() -> void:
	var content := Ui.Root.content(get_viewport())  # sprite px
	# ponytail: free scale, so sprite px go uneven above 1x; floor s to 0.5 steps (whole screen px) if the shimmer bothers
	var s := minf(content.size.x * Fx.SCALE / field.size.x, content.size.y * Fx.SCALE / field.size.y)
	scale = Vector2.ONE * s
	position = (content.position + ((content.size - field.size * s / Fx.SCALE) / 2).floor()) * Fx.SCALE


## The line placed pieces must stay above.
func place_y() -> float:
	return field.size.y - Game.place_up()


func box(kind: String, size: Vector2, pos: Vector2) -> Box:
	var b := Box.new()
	b.kind = kind
	b.size = size
	b.position = pos
	b.hp = Tuning.BRICKS[kind].hp if kind in Tuning.BRICKS else -1
	add_child(b)
	return b


func _add_ball(pos: Vector2) -> Ball:
	var b := Ball.new(Tuning.BALL_RADIUS)
	b.position = pos
	balls.append(b)
	add_child(b)
	return b


func _on_start() -> void:
	placed = place.placed
	for p in placed:
		if p.kind == "magnet":
			Sfx.loop(p, "magnet_hum")


# --- Play ---

## Motion comes through _input: the cabinet columns swallow events over them, and the paddle must still follow the mouse there.
func _input(e: InputEvent) -> void:
	if not over and e is InputEventMouseMotion:
		target_x = get_local_mouse_position().x


## Placement input is handled (and consumed) by place.gd first.
func _unhandled_input(e: InputEvent) -> void:
	if over:
		return
	var key: bool = e is InputEventKey and e.pressed and not e.echo
	if key and e.keycode == KEY_ESCAPE:
		_pause(true)  # in placement too: the dialog's MENU then leaves the round without a result
	elif place.placing:
		return
	elif not launched and (e is InputEventMouseButton and e.pressed or key and e.keycode == KEY_SPACE):
		_launch()


# --- Pause ---

func _pause(on: bool) -> void:
	if on != get_tree().paused:
		Sfx.play("ui_pause" if on else "ui_unpause")
	get_tree().paused = on
	if pause:
		pause.queue_free()
		pause = null
	if not on:
		return
	pause = Ui.dialog("PAUSED", [["RESUME", true, _pause.bind(false)], ["SETTINGS", false, _pause_settings], ["SHOP" if place.placing else "MENU", false, _quit]])
	pause.back.connect(_pause.bind(false))
	add_child(pause)


func _pause_settings() -> void:
	Sfx.play("ui_click")
	pause.queue_free()
	pause = Ui.settings(_pause.bind(true))  # Back rebuilds the pause menu
	add_child(pause)


func _quit() -> void:
	_pause(false)
	if place.placing:
		done.emit()
	else:
		_end("Abandoned")


func _launch() -> void:
	launched = true
	Sfx.play("ball_launch")
	var dir := Vector2.UP.rotated(randf_range(-0.3, 0.3))
	if Game.rank("aim"):  # Aim: toward the mouse, no flatter than a paddle-edge bounce
		var a := clampf(balls[0].position.angle_to_point(get_local_mouse_position()) + PI / 2, -deg_to_rad(Tuning.MAX_BOUNCE_DEG), deg_to_rad(Tuning.MAX_BOUNCE_DEG))
		dir = Vector2.UP.rotated(a)
	balls[0].vel = dir * Tuning.BALL_SPEED
	for i in Game.rank("balls"):  # Extra Ball: fanned out beside the first
		_add_ball(balls[0].position).vel = dir.rotated((i + 1) * 0.35 * (1 if i % 2 == 0 else -1)) * Tuning.BALL_SPEED


func _rest_ball() -> void:
	balls[0].position = paddle.position + Vector2(0, -Tuning.PADDLE_HEIGHT / 2 - Tuning.BALL_RADIUS - 1)


func _physics_process(delta: float) -> void:
	if place.placing or over:
		return
	_move_paddle(delta)
	if not launched:
		_rest_ball()
		return
	time_left -= delta
	if time_left < 5 and time_left + delta >= 5:  # ponytail: same 5 s the clock turns red at in _process
		Sfx.play("time_low")
	combo_timer -= delta
	if combo_timer <= 0:
		if combo > 1:
			Sfx.play("combo_drop")
		_end_combo()
	for p in placed:
		if p.kind == "spawner":
			_charge(p, delta)
	for b in _live():
		if b.fuse > 0:
			b.fuse -= delta
			if b.fuse <= 0:
				_break(b)
	for b in balls.duplicate():
		_move_ball(b, delta)
		if over:
			return
		if b.position.y > field.size.y - Tuning.BALL_RADIUS and shields > 0:
			shields -= 1
			b.position.y = field.size.y - Tuning.BALL_RADIUS
			b.vel.y = -absf(b.vel.y)
			Fx.play(self, "shield_floor_pop", 32, 12, Vector2(b.position.x, field.size.y - 12))
			Sfx.play("shield_floor")
		elif b.position.y > field.size.y + Tuning.BALL_RADIUS:
			Fx.play(self, "ball_lost", 12, 12, Vector2(b.position.x, field.size.y - 12))
			Sfx.play("ball_lost")
			balls.erase(b)
			b.queue_free()
	var fast := balls.any(func(b): return b.speed >= Tuning.FAST_SPEED)
	if fast != was_fast:
		was_fast = fast
		var conds := _bricks("cond")
		if fast:
			Sfx.play("fast_whoosh")
			if conds:
				Sfx.play("cond_primed", 1.0, 0.15)
		for b in conds:
			b.face("brick_cond_speed_primed" if fast else "brick_cond_speed_idle")
			if fast:
				b.flash("cond_prime", 30, 8)
	if balls.is_empty():
		_end("Ball dropped")
	elif time_left <= 0:
		_end("Time's up")


func _charge(p: Box, delta: float) -> void:
	p.charge += delta
	var every := maxf(1.0, Game.stat(Tuning.SPAWN_EVERY, "fastspawn"))
	if p.charge < every:
		p.face(["spawner_charge", 30, int(p.charge / every * 4)])
		return
	p.charge = 0
	p.face(["spawner_charge", 30, 0])
	Fx.play(self, "spawner_charge", 30, 12, p.position + Tuning.PLACEABLES.spawner.offset)
	Sfx.play("spawner_charge")
	var b := _add_ball(p.position + Vector2(0, -p.size.y / 2 - Tuning.BALL_RADIUS - 2))
	b.vel = Vector2.UP.rotated(randf_range(-0.6, 0.6)) * Tuning.BALL_SPEED


func _move_paddle(delta: float) -> void:
	var dir := float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	var speed := Game.paddle_speed()
	if dir != 0:
		target_x = paddle.position.x + dir * speed * delta
	var half := paddle.size.x / 2
	# ponytail: paddle teleports, so a fast sideways swipe can clip into the ball. Use AnimatableBody2D if it shows up.
	paddle.position.x = clampf(move_toward(paddle.position.x, target_x, speed * delta), half, field.size.x - half)


func _move_ball(ball: Ball, delta: float) -> void:
	if ball.hold > 0:
		ball.hold -= delta
		if ball.hold <= 0:
			ball.vel = Vector2.UP * Tuning.BALL_SPEED * ball.speed
			ball.grace = Tuning.PASS_GRACE
			Sfx.play("sticky_fire")
		return
	ball.grace -= delta
	for m in placed:
		if m.kind == "magnet" and ball.position.distance_to(m.position) < Game.stat(Tuning.MAGNET_RADIUS, "reach"):
			ball.vel += ball.position.direction_to(m.position) * Tuning.MAGNET_PULL * delta
			ball.set_speed(ball.speed)
	var motion := ball.vel * delta
	for i in 4:  # a fast ball can hit several things in one tick
		var c := ball.move_and_collide(motion)
		if not c:
			break
		var hit = c.get_collider()
		var n := c.get_normal()
		if hit == paddle and n.y < -0.5:
			# Angle comes from where the ball lands on the paddle, not reflection.
			var off := clampf((ball.position.x - paddle.position.x) / (paddle.size.x / 2), -1, 1)
			ball.vel = Vector2.UP.rotated(off * deg_to_rad(Tuning.MAX_BOUNCE_DEG)) * Tuning.BALL_SPEED * ball.speed
			# Child of the paddle so the flash rides along instead of ghosting where the hit happened.
			Fx.play(paddle, "paddle_hit", 60, 12, Vector2.ZERO).scale = paddle.size / Vector2(60, 8)
			Sfx.play("paddle_hit", clampf(ball.speed, 0.85, 1.3))
		else:
			ball.vel = ball.vel.bounce(n)
		if hit is Box:
			_hit(hit, ball)
		motion = ball.vel.normalized() * c.get_remainder().length()
	var min_vy := Tuning.BALL_SPEED * ball.speed * Tuning.MIN_VERTICAL
	if absf(ball.vel.y) < min_vy:
		ball.vel.y = min_vy if ball.vel.y > 0 else -min_vy
		ball.set_speed(ball.speed)
	if ball.grace > 0:
		return
	for p in placed:
		if Tuning.PLACEABLES[p.kind].get("thru", false) and p.rect().has_point(ball.position):
			_pass(p, ball)


## A pass-through piece acts on a ball inside it.
func _pass(p: Box, ball: Ball) -> void:
	match p.kind:
		"accel":
			var exit := Game.stat(Tuning.ACCEL_SPEED, "hotlaunch")
			if ball.speed < exit:
				ball.set_speed(exit)
				Sfx.play("accel_zip")
				Fx.play(self, "spark_burst_mint", 16, 12, ball.position)
		"oneway":
			if ball.vel.y > 0:
				ball.vel.y = -ball.vel.y
				Sfx.play("gate_pass")
				Fx.play(self, "spark_burst_mint", 16, 12, ball.position)
		"sticky":
			ball.hold = Tuning.STICKY_HOLD
			ball.position = p.position + Vector2(0, -p.size.y / 2 - Tuning.BALL_RADIUS)
			Fx.play(self, "sticky_hold", 30, 8, p.position + Vector2(0, -10))
			Sfx.play("sticky_catch")
		"tele":
			var teles := placed.filter(func(b): return b.kind == "tele")
			if teles.size() < 2:
				return
			var out: Box = teles[(teles.find(p) + 1) % teles.size()]
			Fx.play(self, "teleport_in", 16, 12, p.position)
			Fx.play(self, "teleport_out", 16, 12, out.position)
			Sfx.play("teleport_in")
			Sfx.play("teleport_out", 1.0, 0.1)
			ball.position = out.position + ball.vel.normalized() * (out.size.x / 2 + Tuning.BALL_RADIUS)
		_:
			return
	ball.grace = Tuning.PASS_GRACE


func _hit(b: Box, ball: Ball) -> void:
	match b.kind:
		"wall": Sfx.play("ball_bounce")
		"solid":
			Fx.play(self, "solid_bounce", 44, 12, b.position)
			Sfx.play("solid_bounce")
		"bumper", "pop":
			if b.kind == "pop":
				Fx.play(self, "pop_bumper_hit", 24, 12, b.position)
				Sfx.play("pop_bumper_hit")
				ball.set_speed(ball.speed + Game.stat(Tuning.POP_SPEED, "poppower"))
			else:
				Fx.play(self, "bumper_hit", 45, 12, b.position, b.rotation)
				Sfx.play("bumper_hit")
			if combo > 0:  # Piece Combo: a bumper keeps a running combo alive, never starts one
				combo_timer += Game.bonus("piececombo")
			var tip := int(Game.bonus("piecepay"))  # Piece Pay
			if tip:
				tally.pieces += tip
				_pay(b.position, tip)
		_:
			if b.hp > 0:
				_damage(b, ball)


func _damage(b: Box, ball: Ball) -> void:
	if b.is_queued_for_deletion():
		return
	var refused := false
	match b.kind:
		"cond": refused = ball.speed < Tuning.FAST_SPEED
		"cgate": refused = combo < Tuning.GATE_COMBO
		"timed": refused = b.idle_sprite.frame > 3 and b.idle_sprite.frame < 7  # unlit frames of timed_blink
		"seq1", "seq2", "seq3": refused = b.kind != _seq_next()
	if refused:
		b.flash("cond_too_slow", 30)  # the "why didn't it break" signal
		Sfx.play("hit_refused")
		return
	if b.kind.begins_with("seq"):
		Sfx.play("seq_step", [1.0, 1.26, 1.5][int(b.kind[-1]) - 1])
	if b.kind in Tuning.FUSED:
		_trigger(b, true)
		return
	b.hp -= 1
	if b.hp <= 0:
		_break(b)
		return
	match b.kind:
		"multi":
			b.face("brick_multi_cracked")
			b.flash("mag_hit", 30)
			Sfx.play("multi_crack")
		"multi3":
			b.face(["multi3_crack", 30, 4 if b.hp == 2 else 8])
			b.flash("pips_shrink" if b.hp == 2 else "mag_hit", 30)
			Sfx.play("multi_crack", 0.8 + 0.1 * b.hp)  # lower each crack
		"shield":
			b.face("brick_plain_lit")
			b.flash("shield_pop", 44)
			Sfx.play("shield_pop")
		_:
			b.flash("mag_hit", 30)
			Sfx.play("brick_hit")


## The lowest-numbered sequence brick still standing is the one that may break.
func _seq_next() -> String:
	for k in ["seq1", "seq2", "seq3"]:
		if not _bricks(k).is_empty():
			return k
	return ""


## Every box still standing: breakable, not already broken this frame.
func _live() -> Array:
	return get_children().filter(func(o): return o is Box and o.hp > 0 and not o.is_queued_for_deletion())


func _bricks(kind: String) -> Array:
	return _live().filter(func(o): return o.kind == kind)


## The one way anything, ball or blast, sets off a brick. A fused kind arms on the first trigger (the fuse ticks in
## _physics_process) and breaks when it runs out, or on a ball's second hit (direct); a blast on an armed brick does nothing,
## so a cascade ripples at FUSE intervals instead of short-circuiting itself.
func _trigger(b: Box, direct := false) -> void:
	if not b.kind in Tuning.FUSED or (direct and b.fuse > 0):
		_break(b)
	elif b.fuse == 0:
		b.fuse = Tuning.FUSE
		b.flash("%s_fuse" % b.kind, 30, 8)  # ponytail: 16 frames at 8 fps is FUSE seconds; regenerate the strip if FUSE changes
		Sfx.play("fuse_lit")


func _break(b: Box) -> void:
	if over or b.is_queued_for_deletion():
		return
	b.queue_free()
	var sky := b.kind in ["cond", "cgate", "timed", "seq1", "seq2", "seq3"]
	Fx.play(self, "mag_break", 44, 12, b.position)
	Fx.play(self, "spark_burst_sky" if sky else "spark_burst", 16, 12, b.position)
	combo = combo + 1 if combo > 0 else 1
	combo_timer = Game.combo_window(combo)
	Sfx.play("brick_break")
	if combo > 1:
		Sfx.play("combo_tick", Sfx.st(mini(combo - 2, 7)))
	if combo == Tuning.GATE_COMBO or combo % 5 == 0:
		Sfx.play("combo_up")
	elif combo < Tuning.GATE_COMBO and _bricks("cgate"):
		Sfx.play("gate_tick", 0.7 + 0.1 * combo)
	var base := Game.base_pay(level)
	var with_combo := Game.payout(level, combo)
	var with_kind := roundi(with_combo * Tuning.BRICKS[b.kind].pay)
	var pay := roundi(with_kind * boost_mult)
	tally.bricks += base
	tally.combo += with_combo - base
	tally.specials += with_kind - with_combo
	tally.boost += pay - with_kind
	if boost_hits > 0:
		boost_hits -= 1
		if boost_hits == 0:
			boost_mult = 1.0
			Sfx.play("boost_end")
	_pay(b.position, pay)
	best_combo = maxi(best_combo, combo)
	hud.pop_combo()
	breakable -= 1
	_effect(b.kind, b)
	if breakable == 0:
		_end("Cleared!", true)


func _pay(pos: Vector2, pay: int) -> void:
	earned += pay
	run_pay += pay
	Game.currency += pay
	_tag(pos, "+$%d" % pay)


## Icon brick effects. Area effects pay into the same combo.
func _effect(kind: String, b: Box) -> void:
	match kind:
		"multiball":
			Sfx.play("multiball_pop")
			_add_ball(b.position).vel = Vector2.DOWN.rotated(randf_range(-0.5, 0.5)) * Tuning.BALL_SPEED
		"speedup":
			Sfx.play("speedup")
			for ball in balls:
				ball.set_speed(ball.speed * Tuning.SPEEDUP)
		"slowdown":
			Sfx.play("slowdown")
			for ball in balls:
				ball.set_speed(ball.speed * Tuning.SLOWDOWN)
		"x2", "x3":
			Sfx.play("x2_sting" if kind == "x2" else "x3_sting")
			boost_mult = maxf(boost_mult, 2 if kind == "x2" else 3)
			boost_hits = Tuning.BOOST_HITS
			_tag(b.position + Vector2(0, -24), kind)
		"combo":
			Sfx.play("combo_extend")
			combo_timer += Tuning.COMBO_EXTEND
		"timer":
			Sfx.play("timer_extend")
			var extend := Game.stat(Tuning.TIME_EXTEND, "longtimer")
			time_left += extend
			_tag(b.position + Vector2(0, -24), "+%ds" % int(extend))
		"chain":
			Sfx.play("chain_zap")
			for n in _near(b, Tuning.CHAIN_DIST):
				var mid: Vector2 = (b.position + n.position) / 2
				Fx.play(self, "chain_arc", 64, 12, mid, b.position.angle_to_point(n.position))
				_trigger(n)
		"bomb":
			Fx.play(self, "bomb_ring", 60, 12, b.position)
			Sfx.play("bomb_boom")
			for n in _near(b, Game.stat(Tuning.BOMB_RADIUS, "bigbomb")):
				_trigger(n)
		"bolt":
			Sfx.play("bolt_sweep")
			for n in _live().filter(func(o): return o != b and absf(o.position.y - b.position.y) < 2):
				Fx.play(self, "bolt_sweep", 60, 12, n.position)
				_trigger(n)
		"jackpot":
			Fx.play(self, "jackpot_rays", 48, 8, b.position)
			Sfx.play("jackpot")
			var j: int = Tuning.LEVELS[level].payout * Tuning.JACKPOT_MULT
			tally.jackpot += j
			_pay(b.position + Vector2(0, -28), j)
		"mystery":
			Sfx.play("mystery_reel")
			var picks := Tuning.ICON_KINDS.duplicate()
			picks.erase("mystery")
			_effect(picks.pick_random(), b)


func _near(b: Box, dist: float) -> Array:
	return _live().filter(func(o): return o != b and o.position.distance_to(b.position) <= dist)


## A combo run ends: record it for the result panel.
func _end_combo() -> void:
	if combo > 1:
		combos.append([combo, run_pay])
	combo = 0
	run_pay = 0


func _end(msg: String, cleared := false) -> void:
	if over:
		return
	over = true
	_end_combo()
	var unlocked := cleared and Game.unlocked == level and level + 1 < Tuning.LEVELS.size()
	if cleared:
		Game.clear_level(level)
	Game.runs += 1
	Game.best = maxi(Game.best, earned)
	Game.note_broken(level, total - breakable, total)
	Game.save()
	Sfx.play({"Cleared!": "round_clear", "Time's up": "time_up", "Ball dropped": "round_fail"}.get(msg, "ui_back"))
	if earned:
		Sfx.play("coin_cascade", 1.0, 0.5)
	if unlocked or (cleared and level == Tuning.LEVELS.size() - 1):
		Sfx.play("ui_unlock", 1.0, 1.0)
	hud.result(msg, cleared, unlocked)


## Payout tag: the strip fades while the node rises; the text is a label riding on it.
func _tag(pos: Vector2, text: String) -> void:
	var s := Fx.play(self, "payout_rise", 25, 12, pos)
	var l := Label.new()
	l.text = text
	l.size = Vector2(50, 16)
	l.scale = Vector2.ONE / Fx.SCALE
	l.position = -l.size * l.scale / 2
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Tuning.COLORS.bg)
	s.add_child(l)
	create_tween().tween_property(s, "position:y", pos.y - 40, 10.0 / 12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Brick idles that follow the combo: plain bricks pulse then chase, the gate counts down.
func _process(_delta: float) -> void:
	var m := "" if combo == 0 else "chase" if combo_timer < Tuning.CHASE_AT else "pulse"
	if m != mode:
		mode = m
		for b in _bricks("plain"):
			b.idle(null if m == "" else ["mag_pulse" if m == "pulse" else "combo_chase", 30, 8])
	for b in _bricks("cgate"):
		b.face(["combo_gate", 30, [5, 2, 1, 0][clampi(Tuning.GATE_COMBO - combo, 0, 3)]])
	queue_redraw()


func _draw() -> void:
	# Base and dots come from the cabinet (ui, drawn beneath this). Here: the frame and level walls, the placement line,
	# the bottom lamps and the balls. The frame sits just outside the arena, under the rails.
	var w := field.size.x
	var h := field.size.y
	draw_polyline([Vector2(-2, h), Vector2(-2, -2), Vector2(w + 2, -2), Vector2(w + 2, h)], Tuning.COLORS.trim_hi, 4)
	for r in Tuning.LEVELS[level].get("walls", []):
		draw_rect(r, Tuning.COLORS.trim_hi)
	if place.placing:
		draw_dashed_line(Vector2(4, place_y()), Vector2(w - 4, place_y()), Color(Tuning.COLORS.mint, 0.6), 2, 6, false)
	var f := int(Time.get_ticks_msec() / 125) % 4  # 8 fps
	for x in range(0, int(w), 64):
		var cw := minf(64, w - x)  # the last chunk stops at the arena's edge
		draw_texture_rect_region(HAZARD_TEX, Rect2(x, h - 8, cw, 8), Rect2(f * 32, 0, cw / 2, 4))
		if shields > 0:  # the shield floor rides just above the hazard strip
			draw_texture_rect_region(SHIELD_TEX, Rect2(x, h - 16, cw, 8), Rect2(f * 32, 0, cw / 2, 4))
	var r := Tuning.BALL_RADIUS
	for b in balls:
		if b.hold > 0:
			continue  # the sticky_hold strip draws it
		if b.speed >= Tuning.FAST_SPEED and launched:
			draw_set_transform(b.position, b.vel.angle(), Vector2.ONE * Fx.SCALE)
			draw_texture_rect_region(TRAIL_TEX, Rect2(-20, -4, 24, 8), Rect2(int(Time.get_ticks_msec() / 83) % 4 * 24, 0, 24, 8))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect(BALL_TEX, Rect2(b.position - Vector2(r, r), Vector2(r, r) * 2), false)
