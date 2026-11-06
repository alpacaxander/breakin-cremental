extends Node2D
## One round: placement mode, then play mode, then a result panel.

signal done

const Tuning = preload("res://src/tuning.gd")
const Box = preload("res://src/brick.gd")
const Fx = preload("res://src/fx.gd")
const Ui = preload("res://src/ui.gd")
const Sfx = preload("res://src/sfx.gd")
const BALL_TEX := preload("res://assets/pixel/png/ball.png")
const TRAIL_TEX := preload("res://assets/pixel/png/anim_ball_trail.png")
const HAZARD_TEX := preload("res://assets/pixel/png/anim_hazard_strip.png")


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
var placing := true
var launched := false
var over := false

var paddle: Box
var balls: Array[Ball] = []
var target_x := 0.0
var time_left := 0.0
var combo := 0
var combo_timer := 0.0
var earned := 0
var breakable := 0
var boost_mult := 1.0
var boost_hits := 0
var was_fast := false
var mode := ""  # plain brick idle: "", "pulse", "chase"

var placed: Array[Box] = []
var holding: Box = null
var hovered: Box = null

var best_combo := 0
var ui: Ui.Root  # the cabinet: score column left, pieces column right
var tray := Control.new()  # right column contents, rebuilt by _refresh_tray
var cash_l: Label
var extra_l: Label
var boost_l: Label
var combo_l: Label
var bar: ColorRect
var mult_l: Label
var time_l: Label
var best_l: Label
var pause: Control = null
var view := Tuning.VIEW
var field := Tuning.FIELD


func _ready() -> void:
	# Walls: left, right, top. Bottom is open, that's the drop.
	_box("wall", Vector2(100, view.y * 3), Vector2(field.position.x - 50, view.y / 2))
	_box("wall", Vector2(100, view.y * 3), Vector2(field.end.x + 50, view.y / 2))
	_box("wall", Vector2(view.x, 100), Vector2(view.x / 2, -50))
	var rows := {}
	for b in Game.generate(level, randi()):
		var box := _box(b.kind, Tuning.BRICK_SIZE, b.pos)
		if box.hp > 0:
			breakable += 1
		# Spawn-in, one row after another. The brick shows once its spawn strip ends.
		box.hide()
		var row := int((b.pos.y - Tuning.BOARD_TOP) / (Tuning.BRICK_SIZE.y + Tuning.BRICK_GAP))
		if not row in rows:  # one tick per row as it lands
			rows[row] = true
			Sfx.play("count_tick", 1.0 + 0.06 * row, 0.08 * row)
		var id := box.get_instance_id()  # not the box itself: a lambda holding a freed object logs an engine error
		create_tween().tween_callback(func():
			if instance_from_id(id):
				Fx.play(self, "mag_spawn", 30, 12, b.pos).animation_finished.connect(func(): if instance_from_id(id): instance_from_id(id).show())
		).set_delay(0.08 * row)
	paddle = _box("paddle", Vector2(Game.paddle_width(), Tuning.PADDLE_HEIGHT), Vector2(view.x / 2, Tuning.PADDLE_Y))
	target_x = paddle.position.x
	_add_ball(Vector2.ZERO)
	_rest_ball()
	time_left = Game.round_time(breakable)

	# The cabinet. Positions are sprite px inside the score column (see ui.gd).
	ui = Ui.chassis("SCORE", "PIECES", true)
	add_child(ui)
	var C := Tuning.COLORS
	cash_l = Ui.cash(ui, 0, Game.currency)
	extra_l = Ui.label(ui, "", 6, 44, C.cream)
	boost_l = Ui.label(ui, "", 6, 52, C.cream)
	Ui.label(ui, "COMBO", 6, 60, C.rivet)
	combo_l = Ui.label(ui, "-", 6, 68, C.rivet, 4)
	combo_l.pivot_offset = Vector2(0, 10)
	Ui.rect(ui, 6, 92, 68, 3, C.trim_lo)
	bar = Ui.rect(ui, 6, 92, 0, 3, C.pay)
	mult_l = Ui.label(ui, "", 6, 98, C.rivet)
	Ui.label(ui, "TIME", 6, 108, C.rivet)
	time_l = Ui.label(ui, "", 6, 116, C.cream, 3)
	best_l = Ui.label(ui, "", 6, 138, C.rivet)
	Ui.label(ui, "LEVEL %d" % (level + 1), 6, 146, C.rivet)
	tray.position.x = Ui.RX
	ui.add_child(tray)
	_refresh_tray()


func _box(kind: String, size: Vector2, pos: Vector2) -> Box:
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


# --- Placement ---

func _count(kind: String) -> int:
	return placed.filter(func(b): return b.kind == kind).size()


func _used() -> int:
	var n := 0
	for b in placed:
		n += Tuning.PLACEABLES[b.kind].cost
	return n


func _can_take(kind: String) -> bool:
	return holding == null and _count(kind) < Game.owned(kind) and _used() + Tuning.PLACEABLES[kind].cost <= Game.capacity()


## Rebuilds the pieces column: a slot per owned piece with its count left, capacity pips, hints and the start button.
func _refresh_tray() -> void:
	for c in tray.get_children():
		c.queue_free()
	var C := Tuning.COLORS
	var kinds: Array = Tuning.PLACEABLES.keys().filter(func(k): return Game.owned(k) > 0)
	for i in kinds.size():
		var kind: String = kinds[i]
		var left := Game.owned(kind) - _count(kind)
		var slot := TextureButton.new()
		slot.texture_normal = Ui.tex("ui_slot")
		slot.texture_hover = Ui.tex("ui_slot_hover")
		slot.texture_disabled = slot.texture_normal
		slot.position = Vector2(22, 22 + i * 20)
		slot.focus_mode = Control.FOCUS_NONE
		slot.disabled = not _can_take(kind)
		slot.pressed.connect(_take.bind(kind))
		tray.add_child(slot)
		var t := Box.tex_of(Box.FACE[kind])
		Ui.icon(slot, t, 18 - t.get_width() / 2, 9 - t.get_height() / 2).modulate.a = 1.0 if left and placing else 0.3
		if left:
			Ui.icon(slot, "ui_badge", 30, -3)
			Ui.label(slot, str(left), 33, -2, C.bg)
	var y := 26 + kinds.size() * 20
	Ui.label(tray, "CAP", 6, y, C.rivet)
	Ui.label(tray, "%d/%d" % [_used(), Game.capacity()], 24, y, C.white)
	Ui.pips(tray, 6, y + 8, Game.capacity(), _used())
	if not placing:
		Ui.label(tray, "LOCKED", 6, y + 24, C.rivet)
		return
	var hints := ["LMB PICK/DROP", "R ROTATE", "RMB REMOVE", "ESC PAUSE"]
	for i in hints.size():
		Ui.label(tray, hints[i], 6, y + 24 + i * 8, C.rivet)
	Ui.button(tray, "START", 6, 300, 66, 24, _start, true, 2, "")
	Ui.label(tray, "SPACE", 0, 328, C.rivet, 1, 78, HORIZONTAL_ALIGNMENT_CENTER)


func _take(kind: String) -> void:
	if not _can_take(kind):
		return
	Sfx.play("ui_pickup")
	_hover(null)
	holding = _box(kind, Tuning.PLACEABLES[kind].size, get_global_mouse_position())
	placed.append(holding)
	_drag()
	_refresh_tray()


func _valid(b: Box) -> bool:
	var zone := Rect2(field.position, Vector2(field.size.x, Tuning.PLACE_MAX_Y))
	if not zone.encloses(b.rect()):
		return false
	for o in get_children():
		if o is Box and o != b and o.kind != "wall" and o.rect().grow(Tuning.PLACE_MARGIN).intersects(b.rect()):
			return false
	return true


func _drag() -> void:
	holding.position = get_global_mouse_position()
	var s := holding.size / Fx.SCALE
	holding.overlay([("ghost_march_%dx%d" if _valid(holding) else "ghost_invalid_shake_%dx%d") % [s.x, s.y], int(s.x), 8])


func _hover(b: Box) -> void:
	if b == hovered:
		return
	if hovered:
		hovered.overlay(null)
	hovered = b
	if b:
		var s := b.size / Fx.SCALE + Vector2(4, 4)
		b.overlay(["hover_outline_%dx%d" % [s.x, s.y], int(s.x), 8])


func _placed_at(p: Vector2) -> Box:
	for b in placed:
		if b.rect().has_point(p):
			return b
	return null


func _place_click(button: int) -> void:
	var m := get_global_mouse_position()
	if button == MOUSE_BUTTON_LEFT:
		if holding and _valid(holding):
			Sfx.play("ui_drop")
			holding.overlay(null)
			holding = null
			_hover(_placed_at(m))
		elif not holding:
			_hover(null)
			holding = _placed_at(m)
			if holding:
				Sfx.play("ui_pickup")
				_drag()
		else:
			Sfx.play("ui_invalid")
	elif button == MOUSE_BUTTON_RIGHT:
		var b := holding if holding else _placed_at(m)
		if b:
			Sfx.play("ui_back")
			_hover(null)
			placed.erase(b)
			b.queue_free()
			holding = null
	_refresh_tray()


func _start() -> void:
	if not placing:
		return
	if holding and not _valid(holding):
		placed.erase(holding)
		holding.queue_free()
	elif holding:
		holding.overlay(null)
	_hover(null)
	holding = null
	placing = false
	Sfx.play("ui_start")
	for p in placed:
		if p.kind == "magnet":
			Sfx.loop(p, "magnet_hum")
	_refresh_tray()


# --- Play ---

## Motion comes through _input: the cabinet columns swallow events over them, and the paddle must still follow the mouse there.
func _input(e: InputEvent) -> void:
	if over or not e is InputEventMouseMotion:
		return
	target_x = get_global_mouse_position().x
	if holding:
		_drag()
	elif placing:
		_hover(_placed_at(get_global_mouse_position()))


func _unhandled_input(e: InputEvent) -> void:
	if over:
		return
	if e is InputEventMouseButton and e.pressed:
		if placing:
			_place_click(e.button_index)
		elif not launched:
			_launch()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_SPACE:
			if placing:
				_start()
			elif not launched:
				_launch()
		elif e.keycode == KEY_R and holding:
			Sfx.play("ui_rotate")
			holding.rotation += deg_to_rad(Tuning.ROTATE_DEG)
			_drag()
		elif e.keycode == KEY_ESCAPE:
			_pause(true)


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
	pause = Ui.dialog("PAUSED", [["RESUME", true, _pause.bind(false)], ["SETTINGS", false, _pause_settings], ["MENU", false, _quit]])
	pause.back.connect(_pause.bind(false))
	add_child(pause)


func _pause_settings() -> void:
	Sfx.play("ui_click")
	pause.queue_free()
	pause = Ui.settings(_pause.bind(true))  # Back rebuilds the pause menu
	add_child(pause)


func _quit() -> void:
	_pause(false)
	if placing:
		done.emit()
	else:
		_end("Abandoned")


func _launch() -> void:
	launched = true
	Sfx.play("ball_launch")
	balls[0].vel = Vector2.UP.rotated(randf_range(-0.3, 0.3)) * Tuning.BALL_SPEED


func _rest_ball() -> void:
	balls[0].position = paddle.position + Vector2(0, -Tuning.PADDLE_HEIGHT / 2 - Tuning.BALL_RADIUS - 1)


func _physics_process(delta: float) -> void:
	if placing or over:
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
		combo = 0
	for p in placed:
		if p.kind == "spawner":
			_charge(p, delta)
	for b in balls.duplicate():
		_move_ball(b, delta)
		if over:
			return
		if b.position.y > view.y + Tuning.BALL_RADIUS:
			Fx.play(self, "ball_lost", 12, 12, Vector2(b.position.x, view.y - 12))
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
	if p.charge < Tuning.SPAWN_EVERY:
		p.face(["spawner_charge", 30, int(p.charge / Tuning.SPAWN_EVERY * 4)])
		return
	p.charge = 0
	p.face(["spawner_charge", 30, 0])
	Fx.play(self, "spawner_charge", 30, 12, p.position + Box.FACE_OFFSET.spawner)
	Sfx.play("spawner_charge")
	var b := _add_ball(p.position + Vector2(0, -p.size.y / 2 - Tuning.BALL_RADIUS - 2))
	b.vel = Vector2.UP.rotated(randf_range(-0.6, 0.6)) * Tuning.BALL_SPEED


func _move_paddle(delta: float) -> void:
	var dir := float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	if dir != 0:
		target_x = paddle.position.x + dir * Tuning.PADDLE_SPEED * delta
	var half := paddle.size.x / 2
	# ponytail: paddle teleports, so a fast sideways swipe can clip into the ball. Use AnimatableBody2D if it shows up.
	paddle.position.x = clampf(move_toward(paddle.position.x, target_x, Tuning.PADDLE_SPEED * delta), field.position.x + half, field.end.x - half)


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
		if m.kind == "magnet" and ball.position.distance_to(m.position) < Tuning.MAGNET_RADIUS:
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
			if ball.speed < Tuning.ACCEL_SPEED:
				ball.set_speed(Tuning.ACCEL_SPEED)
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
		"bumper":
			Fx.play(self, "bumper_hit", 45, 12, b.position, b.rotation)
			Sfx.play("bumper_hit")
		"pop":
			Fx.play(self, "pop_bumper_hit", 24, 12, b.position)
			Sfx.play("pop_bumper_hit")
			ball.set_speed(ball.speed + Tuning.POP_SPEED)
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


func _bricks(kind: String) -> Array:
	return get_children().filter(func(o): return o is Box and o.kind == kind and not o.is_queued_for_deletion())


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
	var pay := roundi(Game.payout(level, combo) * Tuning.BRICKS[b.kind].pay * boost_mult)
	if boost_hits > 0:
		boost_hits -= 1
		if boost_hits == 0:
			boost_mult = 1.0
			Sfx.play("boost_end")
	_pay(b.position, pay)
	best_combo = maxi(best_combo, combo)
	create_tween().tween_property(combo_l, "scale", Vector2.ONE, 0.25).from(Vector2.ONE * 1.5)
	breakable -= 1
	_effect(b.kind, b)
	if breakable == 0:
		_end("Cleared!", true)


func _pay(pos: Vector2, pay: int) -> void:
	earned += pay
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
			time_left += Tuning.TIME_EXTEND
			_tag(b.position + Vector2(0, -24), "+%ds" % int(Tuning.TIME_EXTEND))
		"chain":
			Sfx.play("chain_zap")
			for n in _near(b, Tuning.CHAIN_DIST):
				var mid: Vector2 = (b.position + n.position) / 2
				Fx.play(self, "chain_arc", 64, 12, mid, b.position.angle_to_point(n.position))
				_break(n)
		"bomb":
			Fx.play(self, "bomb_ring", 60, 12, b.position)
			Sfx.play("bomb_boom")
			for n in _near(b, Tuning.BOMB_RADIUS):
				_break(n)
		"bolt":
			Sfx.play("bolt_sweep")
			for n in get_children():
				if n is Box and n.hp > 0 and n != b and absf(n.position.y - b.position.y) < 2:
					Fx.play(self, "bolt_sweep", 60, 12, n.position)
					_break(n)
		"jackpot":
			Fx.play(self, "jackpot_rays", 48, 8, b.position)
			Sfx.play("jackpot")
			_pay(b.position + Vector2(0, -28), Tuning.LEVELS[level].payout * Tuning.JACKPOT_MULT)
		"mystery":
			Sfx.play("mystery_reel")
			var picks := Tuning.ICON_KINDS.duplicate()
			picks.erase("mystery")
			_effect(picks.pick_random(), b)


func _near(b: Box, dist: float) -> Array:
	return get_children().filter(func(o): return o is Box and o != b and o.hp > 0 and not o.is_queued_for_deletion() and o.position.distance_to(b.position) <= dist)


func _end(msg: String, cleared := false) -> void:
	if over:
		return
	over = true
	var unlocked := cleared and Game.unlocked == level and level + 1 < Tuning.LEVELS.size()
	if cleared:
		Game.clear_level(level)
	Game.runs += 1
	Game.best = maxi(Game.best, earned)
	Game.save()
	Sfx.play({"Cleared!": "round_clear", "Time's up": "time_up", "Ball dropped": "round_fail"}.get(msg, "ui_back"))
	if earned:
		Sfx.play("coin_cascade", 1.0, 0.5)
	if unlocked or (cleared and level == Tuning.LEVELS.size() - 1):
		Sfx.play("ui_unlock", 1.0, 1.0)
	var r := Ui.overlay(0.6)
	Ui.bulbs(r, 4)
	Ui.panel(r, 200, 118, 240, 112)
	Ui.centre(r, msg, 128, Tuning.COLORS.cream)
	Ui.centre(r, "+$%s" % Ui.money(earned), 140, Tuning.COLORS.pay, 4)
	Ui.centre(r, "x%d BEST COMBO" % best_combo, 166, Tuning.COLORS.white)
	if cleared and level == Tuning.LEVELS.size() - 1:
		Ui.centre(r, "YOU WIN!", 176, Tuning.COLORS.mint)
	elif unlocked:
		Ui.centre(r, "LEVEL %d UNLOCKED" % (level + 2), 176, Tuning.COLORS.mint)
	Ui.button(r, "CONTINUE", 272, 194, 96, 20, done.emit, true)
	add_child(r)


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


func _process(_delta: float) -> void:
	cash_l.text = Ui.money(Game.currency)
	extra_l.text = "+%d" % earned if earned else ""
	boost_l.text = "x%d FOR %d" % [boost_mult, boost_hits] if boost_hits > 0 else ""
	combo_l.text = "x%d" % combo if combo else "-"
	combo_l.add_theme_color_override("font_color", Tuning.COLORS.pay if combo else Tuning.COLORS.rivet)
	bar.size.x = 68 * clampf(combo_timer / Game.combo_window(combo), 0, 1) if combo else 0.0
	mult_l.text = "x%.2f PAY" % Game.combo_mult(combo) if combo > 1 else ""
	var t := maxf(time_left, 0)
	time_l.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	time_l.add_theme_color_override("font_color", Tuning.COLORS.danger if launched and t < 5 else Tuning.COLORS.cream)
	best_l.text = "BEST x%d" % best_combo if best_combo > 1 else ""
	var m := "" if combo == 0 else "chase" if combo_timer < Tuning.CHASE_AT else "pulse"
	if m != mode:
		mode = m
		for b in _bricks("plain"):
			b.idle(null if m == "" else ["mag_pulse" if m == "pulse" else "combo_chase", 30, 8])
	for b in _bricks("cgate"):
		b.face(["combo_gate", 30, [5, 2, 1, 0][clampi(Tuning.GATE_COMBO - combo, 0, 3)]])
	queue_redraw()


func _draw() -> void:
	# Base and dots come from the cabinet (ui, drawn beneath this). Here: the placement line, the bottom lamps and the balls.
	if placing:
		draw_dashed_line(Vector2(field.position.x + 4, Tuning.PLACE_MAX_Y), Vector2(field.end.x - 4, Tuning.PLACE_MAX_Y), Color(Tuning.COLORS.mint, 0.6), 2, 6, false)
	var f := int(Time.get_ticks_msec() / 125) % 4  # 8 fps
	for x in range(int(field.position.x), int(field.end.x), 64):
		draw_texture_rect_region(HAZARD_TEX, Rect2(x, view.y - 8, 64, 8), Rect2(f * 32, 0, 32, 4))
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
