extends Node2D
## One round: placement mode, then play mode, then a result panel.

signal done

const Tuning = preload("res://src/tuning.gd")
const Box = preload("res://src/brick.gd")

var level := 0
var placing := true
var launched := false
var over := false

var paddle: Box
var ball := CharacterBody2D.new()
var vel := Vector2.ZERO
var target_x := 0.0
var time_left := 0.0
var combo := 0
var combo_timer := 0.0
var earned := 0
var breakable := 0

var placed: Array[Box] = []
var holding: Box = null

var hud := Label.new()
var tray := HBoxContainer.new()
var place_btn := Button.new()
var view := Tuning.VIEW


func _ready() -> void:
	# Walls: left, right, top. Bottom is open, that's the drop.
	_box("wall", Vector2(100, view.y * 3), Vector2(-50, view.y / 2))
	_box("wall", Vector2(100, view.y * 3), Vector2(view.x + 50, view.y / 2))
	_box("wall", Vector2(view.x, 100), Vector2(view.x / 2, Tuning.HUD_HEIGHT - 50))
	for b in Game.generate(level, randi()):
		_box(b.kind, Tuning.BRICK_SIZE, b.pos)
		if b.kind == "plain":
			breakable += 1
	paddle = _box("paddle", Vector2(Game.paddle_width(), Tuning.PADDLE_HEIGHT), Vector2(view.x / 2, Tuning.PADDLE_Y))
	target_x = paddle.position.x

	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = Tuning.BALL_RADIUS
	ball.add_child(shape)
	add_child(ball)
	_rest_ball()
	time_left = Game.round_time(breakable)

	hud.position = Vector2(12, 10)
	add_child(hud)
	tray.position = Vector2(12, Tuning.PLACE_MAX_Y + 16)
	tray.add_theme_constant_override("separation", 16)
	var start := Button.new()
	start.text = "Start round (Space)"
	start.pressed.connect(_start)
	var hint := Label.new()
	hint.text = "Click to pick up / drop.  R rotates.  Right-click removes."
	for b in [place_btn, start]:
		b.focus_mode = Control.FOCUS_NONE  # else Space re-presses the last clicked button
	place_btn.pressed.connect(_take_bumper)
	tray.add_child(place_btn)
	tray.add_child(start)
	tray.add_child(hint)
	add_child(tray)
	_refresh_tray()


func _box(kind: String, size: Vector2, pos: Vector2) -> Box:
	var b := Box.new()
	b.kind = kind
	b.size = size
	b.position = pos
	b.hp = 1 if kind == "plain" else -1
	add_child(b)
	return b


# --- Placement ---

func _used() -> int:
	return placed.size() * Tuning.BUMPER_COST


func _can_take() -> bool:
	return holding == null and placed.size() < Game.bumpers() and _used() + Tuning.BUMPER_COST <= Game.capacity()


func _refresh_tray() -> void:
	place_btn.text = "Place bumper (%d/%d)   Capacity %d/%d" % [placed.size(), Game.bumpers(), _used(), Game.capacity()]
	place_btn.disabled = not _can_take()


func _take_bumper() -> void:
	if not _can_take():
		return
	holding = _box("bumper", Tuning.BUMPER_SIZE, get_global_mouse_position())
	placed.append(holding)
	_drag()
	_refresh_tray()


func _valid(b: Box) -> bool:
	var zone := Rect2(0, Tuning.HUD_HEIGHT, view.x, Tuning.PLACE_MAX_Y - Tuning.HUD_HEIGHT)
	if not zone.encloses(b.rect()):
		return false
	for o in get_children():
		if o is Box and o != b and o.kind != "wall" and o.rect().grow(Tuning.PLACE_MARGIN).intersects(b.rect()):
			return false
	return true


func _drag() -> void:
	holding.position = get_global_mouse_position()
	holding.modulate = Color.WHITE if _valid(holding) else Color(1, 0.3, 0.3, 0.7)


func _placed_at(p: Vector2) -> Box:
	for b in placed:
		if b.rect().has_point(p):
			return b
	return null


func _place_click(button: int) -> void:
	var m := get_global_mouse_position()
	if button == MOUSE_BUTTON_LEFT:
		if holding and _valid(holding):
			holding = null
		elif not holding:
			holding = _placed_at(m)
	elif button == MOUSE_BUTTON_RIGHT:
		var b := holding if holding else _placed_at(m)
		if b:
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
	holding = null
	placing = false
	tray.queue_free()


# --- Play ---

func _unhandled_input(e: InputEvent) -> void:
	if over:
		return
	if e is InputEventMouseMotion:
		target_x = get_global_mouse_position().x
		if holding:
			_drag()
	elif e is InputEventMouseButton and e.pressed:
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
			holding.resize(Vector2(holding.size.y, holding.size.x))
			_drag()


func _launch() -> void:
	launched = true
	vel = Vector2.UP.rotated(randf_range(-0.3, 0.3)) * Tuning.BALL_SPEED


func _rest_ball() -> void:
	ball.position = paddle.position + Vector2(0, -Tuning.PADDLE_HEIGHT / 2 - Tuning.BALL_RADIUS - 1)


func _physics_process(delta: float) -> void:
	if placing or over:
		return
	_move_paddle(delta)
	if not launched:
		_rest_ball()
		return
	time_left -= delta
	combo_timer -= delta
	if combo_timer <= 0:
		combo = 0
	_move_ball(delta)
	if over:
		return
	if ball.position.y > view.y + Tuning.BALL_RADIUS:
		_end("Ball dropped")
	elif time_left <= 0:
		_end("Time's up")


func _move_paddle(delta: float) -> void:
	var dir := float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	if dir != 0:
		target_x = paddle.position.x + dir * Tuning.PADDLE_SPEED * delta
	var half := paddle.size.x / 2
	# ponytail: paddle teleports, so a fast sideways swipe can clip into the ball. Use AnimatableBody2D if it shows up.
	paddle.position.x = clampf(move_toward(paddle.position.x, target_x, Tuning.PADDLE_SPEED * delta), half, view.x - half)


func _move_ball(delta: float) -> void:
	var motion := vel * delta
	for i in 4:  # a fast ball can hit several things in one tick
		var c := ball.move_and_collide(motion)
		if not c:
			break
		var hit = c.get_collider()
		var n := c.get_normal()
		if hit == paddle and n.y < -0.5:
			# Angle comes from where the ball lands on the paddle, not reflection.
			var off := clampf((ball.position.x - paddle.position.x) / (paddle.size.x / 2), -1, 1)
			vel = Vector2.UP.rotated(off * deg_to_rad(Tuning.MAX_BOUNCE_DEG)) * Tuning.BALL_SPEED
		else:
			vel = vel.bounce(n)
		if hit is Box and hit.kind == "plain":
			_break(hit)
		motion = vel.normalized() * c.get_remainder().length()
	var min_vy := Tuning.BALL_SPEED * Tuning.MIN_VERTICAL
	if absf(vel.y) < min_vy:
		vel.y = min_vy if vel.y > 0 else -min_vy
		vel = vel.normalized() * Tuning.BALL_SPEED


func _break(b: Box) -> void:
	if b.is_queued_for_deletion():
		return
	b.hp -= 1
	if b.hp > 0:
		return
	b.queue_free()
	combo = combo + 1 if combo > 0 else 1
	combo_timer = Game.combo_window(combo)
	var pay := Game.payout(level, combo)
	earned += pay
	Game.currency += pay
	breakable -= 1
	if breakable == 0:
		_end("Cleared!", true)


func _end(msg: String, cleared := false) -> void:
	over = true
	if cleared:
		Game.clear_level(level)
	Game.save()
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = "%s\nEarned $%d" % [msg, earned]
	if cleared and level == Tuning.LEVELS.size() - 1:
		label.text += "\nYOU WIN!"
	var btn := Button.new()
	btn.text = "Continue"
	btn.pressed.connect(done.emit)
	box.add_child(label)
	box.add_child(btn)
	panel.add_child(box)
	panel.position = view / 2 - Vector2(80, 50)
	add_child(panel)


func _process(_delta: float) -> void:
	hud.text = "Level %d    Time %.1f    $%d (+%d)    Combo %d  x%.2f" % [
		level + 1, maxf(time_left, 0), Game.currency, earned, combo, Game.combo_mult(combo)]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Tuning.COLORS.bg)
	if placing:
		draw_line(Vector2(0, Tuning.PLACE_MAX_Y), Vector2(view.x, Tuning.PLACE_MAX_Y), Tuning.COLORS.line, 2)
	if combo > 0:
		var frac := clampf(combo_timer / Game.combo_window(combo), 0, 1)
		draw_rect(Rect2(0, Tuning.HUD_HEIGHT - 4, view.x * frac, 4), Tuning.COLORS.combo)
	draw_circle(ball.position, Tuning.BALL_RADIUS, Tuning.COLORS.ball)
