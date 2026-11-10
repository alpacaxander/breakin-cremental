extends Node2D
## One fight: the enemy in the band above the top wall, the bag of balls launched phase by phase at the board, and the
## damage pipeline. A ball stores dmg per brick it breaks, fires it at the enemy on paddle contact and loses it on a drop;
## crit bricks launch the bag's next ball, bombs hit the enemy and blast their neighbours for the ball, a red brick a ball
## breaks costs the player HP (a blast removes it for free); a phase ends when every ball has dropped, no HP cost. Seconds
## of flight count down the enemy's intent (_count_down); at 0 its attack strip plays and the hazard spawns on frame 3
## (_act, _hazard): red bricks painted onto the board, enemy balls and debris that cost HP on paddle touch (Hazard nodes moved by hand, cleared
## at phase end), a laser lane snapped to the board column under the paddle (drawn in _draw), a shield row of solids that
## crumbles after so many paddle hits, the boss's mouth that eats balls and spits them back, and map 1's three: jam (the
## paddle at half width for so many hits, _paddle_fit), pull (an upward force on every ball in flight for a second,
## _move_ball) and coin_junk (stones on top of the bag). The enemy signatures (Tuning.ENEMIES) live at their sites: the
## riposte in _paddle_hit, enrage in _land (the row's enraged fields merge in; mimic makes _enemy_ball copy the bag's
## balls), steal in _drop, twice in _act, the jackpot in _effect, shield_start in _ready, advance in _phase_start. Ball
## traits (Tuning.BALLS) live here too: pierce in the collision loop, split, the blaster's and the token's counts in
## _break, the sticky catch in _paddle_hit, poison stacks landing with the damage and ticking at phase end, the rubber
## ball's floor bounces in _save, the magnet ball in _move_ball, the junk ball's silent crits. Relics (Tuning.RELICS)
## fire through _relics, one match by id at the on_fight_start, on_break and on_phase_end sites; stat relics are Game.has
## reads where their number applies (paddle width, the magnet in _move_ball, twin_crit in _crit, the mini paddle in _pads). won / lost fire as the fight ends and
## done(win) after the end beat, for main.gd's reward overlay or end screen; hud.gd draws the run columns.
## docs/content.md "Fight pipeline", "Balls", "Enemies", "Hazards" and "Relics" are the contract.

signal won
signal lost
signal done(win: bool)  # RUN.end_beat after won / lost

const Tuning = preload("res://src/tuning.gd")
const Box = preload("res://src/brick.gd")
const Fx = preload("res://src/fx.gd")
const Ui = preload("res://src/ui.gd")
const Sfx = preload("res://src/sfx.gd")
const Hud = preload("res://src/hud.gd")
const HAZARD_TEX := preload("res://assets/pixel/png/anim_hazard_strip.png")
const SHIELD_TEX := preload("res://assets/pixel/png/anim_shield_floor.png")  # the floor line while relic shield_floor has a save armed
const LASER_WARN_TEX := preload("res://assets/pixel/png/anim_laser_sweep_warn.png")
const LASER_FIRE_TEX := preload("res://assets/pixel/png/anim_laser_sweep_fire.png")


class Ball extends CharacterBody2D:
	var vel := Vector2.ZERO
	var speed := 1.0  # multiplier on Tuning.BALL_SPEED
	var base := 1.0  # the kind's speed multiplier, what the ramp starts from
	var radius := Tuning.BALL_RADIUS
	var id := "ball_basic"
	var rank := 1
	var row: Dictionary  # the Tuning.BALLS row
	var entry: Dictionary  # the bag dict this ball came from; it returns to the discard pile on a drop. Carries the blaster's break count
	var copy := false  # a split half: never returns to the bag
	var dmg := 1  # per brick broken
	var stored := 0  # damage carried to the paddle
	var poison := 0  # stacks carried to the paddle, landing with the damage
	var pierce_left := 0  # bricks it still passes through since the last launch or paddle hit
	var can_split := false  # forks on its next break (armed by a launch or paddle hit)
	var catches_left := 0  # sticky paddle catches left this phase
	var floor_left := 0  # rubber: floor bounces left this phase (a Ball lives one phase)
	var hold := 0.0  # seconds a sticky catch keeps it on the paddle; 0 in flight
	var hold_dx := 0.0  # where on the paddle it stuck
	var age := 0.0  # seconds in flight, for the speed ramp
	var tex: Texture2D  # frame rank-1 of <id>_rank
	var tag: Label  # the stored number riding above the ball, on the stored_tag strip (tag_s), both hidden at 0
	var tag_s: AnimatedSprite2D

	func _init(ball: Dictionary) -> void:
		entry = ball
		id = ball.id
		rank = ball.rank
		row = Tuning.BALLS[id]
		dmg = row.dmg[rank - 1]
		base = row.speed
		speed = base
		radius = Tuning.BALL_RADIUS * row.size
		catches_left = at_rank("catches")
		floor_left = at_rank("floor")
		tex = Fx.frame("%s_rank" % id, int(8 * row.size), rank - 1)
		var c := CollisionShape2D.new()
		c.shape = CircleShape2D.new()
		c.shape.radius = radius
		add_child(c)
		tag_s = Fx.play(self, "stored_tag", 25, 8, Vector2(0, -radius - 16), 0, true)
		tag_s.hide()
		tag = Ui.label(self, "", -20, -radius - 22, Tuning.COLORS.pay, 2, 40, HORIZONTAL_ALIGNMENT_CENTER)
		tag.z_index = 2  # over the strip's z 1

	## The row's trait value at this rank, 0 when the ball lacks the trait.
	func at_rank(key: String) -> int:
		return row[key][rank - 1] if key in row else 0

	## A launch or paddle hit re-arms the per-flight traits.
	func arm() -> void:
		pierce_left = at_rank("pierce")
		can_split = row.has("split")

	func set_speed(s: float) -> void:
		speed = clampf(s, Tuning.SPEED_MIN, Tuning.SPEED_MAX)
		vel = vel.normalized() * Tuning.BALL_SPEED * speed

	func store(n: int) -> void:
		stored += n
		tag.text = str(stored) if stored else ""
		tag_s.visible = stored > 0


## A hostile object in the air or a laser lane. No physics body: the arena moves it, bounces it off the side walls and
## tests the paddle's rect itself (_tick_hazards), so it passes through bricks and balls for free. Its look is a child strip.
class Hazard extends Node2D:
	var kind: String
	var row: Dictionary  # the Tuning.HAZARDS row
	var vel := Vector2.ZERO
	var r := 8.0  # half size, for the walls and the paddle
	var state := "warn"  # laser: warn, then beam
	var t := 0.0  # laser: seconds left of the state
	var paid := false  # laser: the paddle already paid this beam
	var zapped: Array = []  # laser: ball instance ids this beam already emptied

	func _init(k: String) -> void:
		kind = k
		row = Tuning.HAZARDS[k]


var enemy_id := "glob"  # set by main.gd from the map node before the arena enters the tree
var enemy := {}  # the ENEMIES row plus hp_max, cd_left and intent (index into intents)
var cls := "fight"  # the BOARDS class, for the lane count
var foe: AnimatedSprite2D  # the enemy's idle loop; hidden while `acting` plays a hit, attack or die strip over it
var acting: AnimatedSprite2D
var intent_s: Sprite2D  # the current intent's icon
var hazards: Array = []  # live Hazard nodes
var volley: Array = []  # tweens spawning flight hazards; a phase end kills them (nothing fires between phases)
var shield: Array = []  # the shield row's solids
var shield_left := 0  # paddle hits until the shield row crumbles
var mouth_left := 0  # paddle hits the boss's mouth stays open; 0 = closed
var eaten := 0  # balls the mouth swallowed, spat back when it closes
var mouth_s: AnimatedSprite2D
var shake := 0.0  # seconds left of the debris shake
var home := Vector2.ZERO  # _fit's position, what the shake jitters around
var bag: Array = []  # {id, rank} in launch order, shuffled at fight start
var discard: Array = []  # dropped and discarded balls; reshuffled into the bag when it runs out
var phase := 0
var phase_dmg := 0
var discarded := false  # one discard per phase
var over := false
var rest: Ball = null  # the ball waiting on the paddle
var beat := 0.0  # seconds left of the between-phase pause; 0 while a phase runs
var refresh_in := 0.0  # seconds until an emptied board grows a refresh brick; 0 when none is pending
var flash := 0.0  # seconds left of the red field flash
var layout: Array = []  # Game.generate's slots; slots[i] is the brick standing there (freed once broken)
var slots: Array = []
var breaks := 0  # bricks broken this fight (relic toll)
var phase_breaks := 0  # and this phase (relic opener)
var combo := 0  # relic combo: breaks inside the window; 0 when idle
var combo_t := 0.0  # seconds of window left
var saves_left := 0  # relic shield_floor: floor bounces left this phase
var dropped: Array = []  # non-junk bag entries dropped this phase, in order (relic recall)
var mini: Box = null  # relic mini_paddle's second paddle, mirroring the main one
var jam_left := 0  # hazard jam: paddle hits the paddle stays at half width; persists past a phase
var pull_t := 0.0  # hazard pull: seconds left of the upward force on every ball in flight
var phase_acts := 0  # intents fired this phase (the bouncer's first fires twice)
var phase_gold := 0  # gold bricks broken this phase (the jackpot)
var mimic_i := 0  # the bag index the next mimicked enemy ball copies
var paddle_w := Tuning.PADDLE_WIDTH  # the paddle's built width, what a jam halves

var paddle: Box
var balls: Array[Ball] = []
var target_x := 0.0
var breakable := 0
var ui: Ui.Root  # the cabinet: columns by hud.gd
var hud: Hud
var field: Rect2  # the arena in its own px: origin top-left. _fit scales the node into the cabinet's 4:3 field.
var hp_l: Label
var cd_l: Label


func _ready() -> void:
	field = Rect2(Vector2.ZERO, Tuning.ARENA)
	get_viewport().size_changed.connect(_fit)
	# Walls: left, right, and the top wall whose underside is TOP_WALL, with the enemy band above it. Bottom is open, that's the drop.
	box("wall", Vector2(100, field.size.y * 3), Vector2(-50, field.size.y / 2))
	box("wall", Vector2(100, field.size.y * 3), Vector2(field.size.x + 50, field.size.y / 2))
	box("wall", Vector2(field.size.x, 100), Vector2(field.size.x / 2, Tuning.TOP_WALL - 50))
	enemy = Tuning.ENEMIES[enemy_id].duplicate()
	enemy.hp_max = enemy.hp
	enemy.cd_left = enemy.cd
	enemy.intent = 0
	enemy.poison = 0  # stacks ticking at phase end
	cls = "fight" if enemy.role == "regular" else enemy.role
	layout = Game.generate(cls, randi(), enemy.board)
	slots.resize(layout.size())
	_relics("on_fight_start")  # before the spawn: tenth_bomb rewrites layout kinds
	var rows := {}
	for i in layout.size():
		var row: int = layout[i].row
		if not row in rows:  # one tick per row as it lands
			rows[row] = true
			Sfx.play("count_tick", 1.0 + 0.06 * row, 0.08 * row)
		_spawn(i, layout[i].kind, 0.08 * row)
	paddle_w = Tuning.RELICS.wide_paddle.width if Game.has("wide_paddle") else Tuning.PADDLE_WIDTH
	paddle = box("paddle", Vector2(paddle_w, Tuning.PADDLE_HEIGHT), Vector2(field.size.x / 2, field.size.y - Tuning.PADDLE_UP))
	target_x = paddle.position.x
	if Game.has("magnet_paddle"):
		Fx.play(paddle, "magnet_pull", 44, 8, Vector2(0, Tuning.PADDLE_HEIGHT), 0, true).show_behind_parent = true
	if enemy.get("shield_start", false):
		_shield_row()

	foe = Fx.play(self, "%s_idle" % enemy_id, enemy.w, Tuning.ENEMY_FPS.idle, Tuning.ENEMY_FOOT - Vector2(0, 24 * Fx.SCALE), 0, true)
	foe.z_index = 0
	foe.show_behind_parent = true  # behind the balls the arena draws
	hp_l = Ui.label(self, "", 648, 2, Tuning.COLORS.white, 2)
	intent_s = Sprite2D.new()
	intent_s.centered = false
	intent_s.position = Vector2(660, 4)
	intent_s.scale = Vector2.ONE * Fx.SCALE
	add_child(intent_s)
	_show_intent()
	cd_l = Ui.label(self, "", 692, 0, Tuning.COLORS.white, 2)
	bag = Game.run.bag.duplicate(true)
	bag.shuffle()

	ui = Ui.chassis("YOU", "BAG", true)
	add_child(ui)
	hud = Hud.new(self, ui)
	add_child(hud)
	_fit()
	Sfx.play("round_go")
	_phase_start()


## Scales the arena to the largest that fits the cabinet's 4:3 field between the columns and centres it there on whole
## sprite px. Tuning.ARENA fills the field exactly.
func _fit() -> void:
	var content := Ui.Root.content(get_viewport())  # sprite px
	# ponytail: free scale, so sprite px go uneven above 1x; floor s to 0.5 steps (whole screen px) if the shimmer bothers
	var s := minf(content.size.x * Fx.SCALE / field.size.x, content.size.y * Fx.SCALE / field.size.y)
	scale = Vector2.ONE * s
	home = (content.position + ((content.size - field.size * s / Fx.SCALE) / 2).floor()) * Fx.SCALE
	position = home


func box(kind: String, size: Vector2, pos: Vector2) -> Box:
	var b := Box.new()
	b.kind = kind
	b.size = size
	b.position = pos
	b.hp = Tuning.BRICKS[kind].hp if kind in Tuning.BRICKS else -1
	add_child(b)
	return b


## A brick of `kind` in layout slot i, hidden until its spawn strip ends after `delay`.
func _spawn(i: int, kind: String, delay := 0.0) -> void:
	var pos: Vector2 = layout[i].pos
	var brick := box(kind, Tuning.BRICK_SIZE, pos)
	slots[i] = brick
	if brick.hp > 0:
		breakable += 1
	brick.hide()
	var id := brick.get_instance_id()  # not the box itself: a lambda holding a freed object logs an engine error
	create_tween().tween_callback(func():
		if instance_from_id(id):
			Fx.play(self, "%s_spawn" % Tuning.hue(kind), 30, 12, pos).animation_finished.connect(func(): if instance_from_id(id): instance_from_id(id).show())
	).set_delay(delay)


## Every empty layout slot regrows its original brick, except the slot of the refresh brick that fired it: regrown under
## the ball that just broke it, a wedged ball breaks it again forever.
func _refresh(from: Box = null) -> void:
	Sfx.play("regrow")
	for i in _empty_slots():
		if from == null or slots[i] != from:
			_spawn(i, layout[i].kind)


## Layout slots with no live brick and no ball inside, so nothing regrows around a ball.
func _empty_slots() -> Array:
	return range(layout.size()).filter(func(i): return (not is_instance_valid(slots[i]) or slots[i].is_queued_for_deletion()) \
			and not balls.any(func(b): return Rect2(layout[i].pos - Tuning.BRICK_SIZE / 2, Tuning.BRICK_SIZE).grow(b.radius).has_point(b.position)))


func _add_ball(ball: Dictionary, pos: Vector2) -> Ball:
	var b := Ball.new(ball)
	b.position = pos
	balls.append(b)
	add_child(b)
	return b


# --- Phases ---

## Rests the bag's next ball on the paddle; a thin board regrows first, and an advancing board (ticket_printer) slides
## its layout and live bricks a row toward the paddle while the lowest still fits above the floor line.
func _phase_start() -> void:
	phase += 1
	phase_dmg = 0
	phase_breaks = 0
	phase_acts = 0
	phase_gold = 0
	combo = 0
	dropped = []
	discarded = false
	refresh_in = 0
	var dy: float = enemy.get("advance", 0) * (Tuning.BRICK_SIZE.y + Tuning.BRICK_GAP)
	if dy and phase > 1 and layout.map(func(s): return s.pos.y).max() + dy + Tuning.BRICK_SIZE.y / 2 <= field.size.y - Tuning.BOARD_FLOOR:
		for s in layout:
			s.pos.y += dy
		for b in slots:
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				b.position.y += dy
		Sfx.play("count_tick", 0.7)
	if breakable < Tuning.RUN.regen_below:
		_refresh()
	_rest_next()


## Rests the bag's head on the paddle, refilling the bag from the discard pile when it is empty.
func _rest_next() -> void:
	if bag.is_empty():
		bag = discard
		discard = []
		bag.shuffle()
	rest = _add_ball(bag.pop_front(), Vector2.ZERO)
	_rest_ball()


func _rest_ball() -> void:
	rest.position = paddle.position + Vector2(0, -Tuning.PADDLE_HEIGHT / 2 - rest.radius - 1)


func _launch_rest() -> void:
	_launch(rest)
	rest = null


func _launch(b: Ball) -> void:
	b.age = 0
	b.arm()
	b.vel = Vector2.UP.rotated(deg_to_rad(randf_range(-Tuning.LAUNCH_SPREAD_DEG, Tuning.LAUNCH_SPREAD_DEG))) * Tuning.BALL_SPEED * b.speed
	var pitch: float = b.row.get("pitch", Sfx.st(b.rank - 1))
	Sfx.play("ball_launch", pitch)


## Once per phase while a ball rests: it goes to the discard pile and the next rests.
func _discard() -> void:
	discarded = true
	Sfx.play("ui_drop")
	discard.append(rest.entry)
	balls.erase(rest)
	rest.queue_free()
	rest = null
	_rest_next()


## Every ball has dropped: relic hooks, in-flight hazards and their pending volleys go, then the poison tick, then the
## between-phase beat, then the next phase. Placed hazards (red bricks, the shield row, a laser lane) stay.
func _phase_end() -> void:
	Sfx.play("combo_drop", 0.8)
	beat = Tuning.RUN.enemy_turn
	pull_t = 0
	_relics("on_phase_end")
	_clear_hazards(true)
	if enemy.poison > 0:
		Sfx.play("pips_shrink", 0.8)
		_land(enemy.poison)
		enemy.poison /= 2


# --- Play ---

## Motion comes through _input: the cabinet columns swallow events over them, and the paddle must still follow the mouse there.
func _input(e: InputEvent) -> void:
	if not over and e is InputEventMouseMotion:
		target_x = get_local_mouse_position().x


## Esc falls through to main.gd, which pauses.
func _unhandled_input(e: InputEvent) -> void:
	if over:
		return
	var click: bool = e is InputEventMouseButton and e.pressed
	var key: bool = e is InputEventKey and e.pressed and not e.echo
	var go: bool = click and e.button_index == MOUSE_BUTTON_LEFT or key and e.keycode == KEY_SPACE
	if rest:
		if click and e.button_index == MOUSE_BUTTON_RIGHT or key and e.keycode == KEY_D:
			if not discarded:
				_discard()
		elif go:
			_launch_rest()
	elif go:
		for b in balls:
			if b.hold > 0:
				_sticky_fire(b)


func _physics_process(delta: float) -> void:
	if over:
		return
	_move_paddle(delta)
	flash = maxf(0, flash - delta)
	shake = maxf(0, shake - delta)
	pull_t = maxf(0, pull_t - delta)
	combo_t -= delta
	if combo_t <= 0:
		combo = 0
	_tick_hazards(delta)
	if balls.size() > (1 if rest else 0):  # a ball in flight (or held by gum): the enemy's clock runs; never between phases
		_count_down(delta)
	if over:
		return
	if refresh_in > 0:
		refresh_in -= delta
		if refresh_in <= 0:
			var empty := _empty_slots()
			_spawn(empty[randi() % empty.size()], "refresh")
	for b in balls.duplicate():
		if b == rest:
			_rest_ball()
			continue
		if b.hold > 0:  # stuck to the paddle: rides it until the hold runs out or a click fires it
			b.hold -= delta
			b.position = paddle.position + Vector2(b.hold_dx, -Tuning.PADDLE_HEIGHT / 2 - b.radius - 1)
			if b.hold <= 0:
				_sticky_fire(b)
			continue
		_move_ball(b, delta)
		if over:
			return
		if b.position.y > field.size.y + b.radius:
			if saves_left > 0 or b.floor_left > 0:
				_save(b)
			else:
				_drop(b)
		elif mouth_left > 0 and b.position.y <= Tuning.TOP_WALL + b.radius + 2 and b.position.x >= Tuning.MOUTH.rect.position.x and b.position.x < Tuning.MOUTH.rect.end.x:
			# ponytail: the zone sits above the top wall body, so a ball touching the wall under the mouth's span is what
			# it eats; a gap in the wall (two top wall bodies) would let balls fly into the zone itself
			eaten += 1
			Sfx.play("teleport_in", 0.6)
			_drop(b, true)
	if balls.is_empty():
		if beat <= 0:
			_phase_end()
		else:
			beat -= delta
			if beat <= 0:
				_phase_start()


## Past the paddle line (or eaten by the mouth, quietly): the stored damage is lost and the ball goes to the discard pile;
## the repo man takes `steal` gold for it.
func _drop(b: Ball, quiet := false) -> void:
	if not quiet:
		Fx.play(self, "ball_lost", 12, 12, Vector2(b.position.x, field.size.y - 12))
		Sfx.play("ball_lost", 1.0 if b.stored else 0.7)
		if enemy.get("steal", 0) and Game.run.gold > 0:
			Game.run.gold = maxi(0, Game.run.gold - enemy.steal)
			Sfx.play("coin", 0.6)
	Game.run.stats.drops += 1
	if not b.copy:
		discard.append(b.entry)
		if b.id != "ball_junk":
			dropped.append(b.entry)
	balls.erase(b)
	b.queue_free()


## relic shield_floor, or the rubber ball's own bounce first: the ball bounces straight up off the floor instead of
## dropping, and the floor pops.
func _save(b: Ball) -> void:
	if b.floor_left > 0:
		b.floor_left -= 1
	else:
		saves_left -= 1
	b.position.y = field.size.y - b.radius
	b.vel = Vector2.UP * Tuning.BALL_SPEED * b.speed
	Fx.play(self, "shield_floor_pop", 32, 12, Vector2(b.position.x, field.size.y - 8))
	Sfx.play("shield_pop")


func _move_paddle(delta: float) -> void:
	var dir := float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	var speed := Tuning.PADDLE_SPEED
	if dir != 0:
		target_x = paddle.position.x + dir * speed * delta
	var half := paddle.size.x / 2
	# ponytail: paddle teleports, so a fast sideways swipe can clip into the ball. Use AnimatableBody2D if it shows up.
	paddle.position.x = clampf(move_toward(paddle.position.x, target_x, speed * delta), half, field.size.x - half)
	if mini:
		mini.position.x = field.size.x - paddle.position.x


## The paddles a ball fires on and a hazard pays on: the main one, and relic mini_paddle's.
func _pads() -> Array:
	return [paddle, mini] if mini else [paddle]


func _move_ball(ball: Ball, delta: float) -> void:
	ball.age += delta
	if Tuning.RUN.ramp_on:  # design.md's fallback for phases that never end
		ball.set_speed(minf(ball.base + Tuning.RUN.ramp_per_s * maxf(0, ball.age - Tuning.RUN.ramp_after), Tuning.RUN.ramp_max))
	var magnet: float = float(Game.has("magnet_paddle")) + (ball.row.magnet[ball.rank - 1] if ball.row.has("magnet") else 0.0)  # the relic and the magnet ball stack
	if magnet > 0 and ball.position.y < paddle.position.y and ball.position.distance_to(paddle.position) < Tuning.MAGNET_RADIUS:
		ball.vel += (paddle.position - ball.position).normalized() * Tuning.MAGNET_PULL * magnet * delta
		ball.set_speed(ball.speed)  # steers, never speeds up
	if pull_t > 0:  # hazard pull: the heading bends upward
		ball.vel.y -= Tuning.HAZARDS.pull.force * delta
		ball.set_speed(ball.speed)
	var motion := ball.vel * delta
	for i in 4:  # a fast ball can hit several things in one tick
		var c := ball.move_and_collide(motion)
		if not c:
			break
		var hit = c.get_collider()
		var n := c.get_normal()
		if hit is Box and hit.hp > 0 and ball.pierce_left > 0:
			# Needle: through the brick on the same heading. The brick is excepted so the next sweep passes it.
			# ponytail: the exception assumes the brick breaks (every breakable is hp 1); a multi-hit brick would stay ghosted to this ball
			ball.pierce_left -= 1
			ball.add_collision_exception_with(hit)
			Sfx.play("pierce_swish")
			_hit(hit, ball)
			if over:
				return
			motion = ball.vel.normalized() * c.get_remainder().length()
			continue
		if hit in _pads() and n.y < -0.5:
			# Angle comes from where the ball lands on the paddle, not reflection.
			var off := clampf((ball.position.x - hit.position.x) / (hit.size.x / 2), -1, 1)
			ball.vel = Vector2.UP.rotated(off * deg_to_rad(Tuning.MAX_BOUNCE_DEG)) * Tuning.BALL_SPEED * ball.speed
			_paddle_hit(ball, hit)
			if over or ball.hold > 0:
				return
		else:
			ball.vel = ball.vel.bounce(n)
		if hit is Box:
			_hit(hit, ball)
		motion = ball.vel.normalized() * c.get_remainder().length()
	var min_vy := Tuning.BALL_SPEED * ball.speed * Tuning.MIN_VERTICAL
	if absf(ball.vel.y) < min_vy:
		ball.vel.y = min_vy if ball.vel.y > 0 else -min_vy
		ball.set_speed(ball.speed)


## Paddle contact (pad: the main paddle or relic mini_paddle's): the ball's stored damage and poison land on the enemy,
## a big one ripostes, the ball's per-flight traits re-arm, and gum with a catch left sticks.
func _paddle_hit(ball: Ball, pad: Box = null) -> void:
	if not pad:
		pad = paddle
	# Child of the paddle so the flash rides along instead of ghosting where the hit happened.
	Fx.play(pad, "damage_fire" if ball.stored > 0 else "paddle_hit", 60, 12, Vector2.ZERO).scale = pad.size / Vector2(60, 8)
	if ball.poison > 0:
		Fx.play(self, "ball_poison_land", 12, 12, ball.position)
	enemy.poison += ball.poison
	ball.poison = 0
	var landed := ball.stored
	if landed > 0:
		_land(landed)
		ball.store(-landed)
	else:
		var pitch: float = ball.row.get("catch", clampf(ball.speed, 0.85, 1.3))
		Sfx.play("paddle_hit", pitch)
	if over:
		return
	ball.arm()
	if ball.catches_left > 0:
		ball.catches_left -= 1
		ball.hold = Tuning.STICKY_HOLD
		ball.hold_dx = ball.position.x - paddle.position.x  # ponytail: gum caught on the mini paddle rides the main one
		ball.vel = Vector2.ZERO
		ball.age = 0  # a catch resets the speed ramp
		Fx.play(paddle, "sticky_hold", 30, 8, Vector2(ball.hold_dx, -Tuning.PADDLE_HEIGHT))
		Sfx.play("sticky_catch")
	if shield:
		shield_left -= 1
		if shield_left <= 0:
			_shield_crumble()
	if jam_left > 0 and pad == paddle:
		jam_left -= 1
		if jam_left == 0:
			_paddle_fit()
	if mouth_left > 0:
		mouth_left -= 1
		if mouth_left == 0:
			_mouth_close()
	if enemy.has("riposte") and landed >= enemy.riposte:  # the warden's riposte: a big shot hurries it
		_count_down(Tuning.RIPOSTE_CUT)


## The enemy's clock: s seconds off the countdown, the warning cue as it crosses 1 s, the intent at 0.
func _count_down(s: float) -> void:
	var was: float = enemy.cd_left
	enemy.cd_left -= s
	if enemy.cd_left <= 0:
		_act()
	elif was > 1 and enemy.cd_left <= 1:
		Sfx.play("timed_off")


## A stuck ball leaves the paddle toward the mouse, within the paddle's bounce angle.
func _sticky_fire(b: Ball) -> void:
	b.hold = 0
	var max_a := deg_to_rad(Tuning.MAX_BOUNCE_DEG)
	var a := clampf(Vector2.UP.angle_to(get_local_mouse_position() - b.position), -max_a, max_a)
	b.vel = Vector2.UP.rotated(a) * Tuning.BALL_SPEED * b.speed
	Sfx.play("sticky_fire")


## n damage lands on the enemy; a boss below its enrage mark takes its enraged fields (the maw's faster countdown and
## longer mouth, attract_mode's mimic).
func _land(n: int) -> void:
	enemy.hp = maxi(0, enemy.hp - n)
	phase_dmg += n
	Game.run.stats.damage += n
	Game.run.stats.best_fire = maxi(Game.run.stats.best_fire, n)
	Sfx.play("damage_land", Sfx.st(Tuning.ladder(Tuning.DAMAGE_LAND, n)))
	Sfx.play("bumper_hit", 0.6 * Sfx.st(enemy.off))
	if enemy.hp <= 0:
		_end(true)
		return
	_enemy_play("hit")
	if enemy.has("enraged") and enemy.hp <= enemy.hp_max * enemy.enraged.at:
		enemy.merge(enemy.enraged, true)


## The enemy's hit, attack or die strip over its hidden idle; the idle returns when it ends (die holds). One at a time.
func _enemy_play(name: String) -> AnimatedSprite2D:
	if is_instance_valid(acting):
		acting.queue_free()
	foe.hide()
	acting = Fx.play(self, "%s_%s" % [enemy_id, name], enemy.w, Tuning.ENEMY_FPS[name], foe.position, 0, false, name == "die")
	acting.z_index = 0
	acting.show_behind_parent = true
	if name != "die":
		acting.animation_finished.connect(foe.show)
	return acting


## The countdown ran out: the attack strip plays and the intent fires on its spawn frame (twice, `twice` seconds apart,
## for the bouncer's first intent of a phase), the next intent shows and the countdown resets. A flight hazard's spawn is
## part of the volley, so a phase end in that window cancels it.
func _act() -> void:
	var it: Array = enemy.intents[enemy.intent]
	Sfx.play("hit_refused", 0.5 * Sfx.st(enemy.off))
	_enemy_play("attack")
	var spawn := Tuning.ENEMY_SPAWN_FRAME / float(Tuning.ENEMY_FPS.attack)
	var flight: bool = Tuning.HAZARDS.get(it[0], {}).get("flight", false)
	_later(spawn, _hazard.bind(it[0], it[1]), flight)
	if enemy.has("twice") and phase_acts == 0:
		_later(spawn + enemy.twice, _hazard.bind(it[0], it[1]), flight)
	phase_acts += 1
	enemy.intent = (enemy.intent + 1) % enemy.intents.size()
	enemy.cd_left = enemy.cd
	_show_intent()


func _show_intent() -> void:
	intent_s.texture = Ui.tex("intent_%s" % enemy.intents[enemy.intent][0])


## fn after delay seconds, on a tween that dies with the arena. flight: part of the volley a phase end cancels.
func _later(delay: float, fn: Callable, flight := false) -> void:
	var tw := create_tween()
	tw.tween_callback(fn).set_delay(delay)
	if flight:
		volley.append(tw)


# --- Hazards (docs/content.md "Hazards") ---

## The intent's effect on the board.
func _hazard(id: String, count: int) -> void:
	if over:
		return
	match id:
		"red_bricks": _red_bricks(count)
		"enemy_balls": _enemy_balls(count)
		"debris": _debris(count)
		"laser_sweep": _laser(count)
		"shield_row": _shield_row()
		"mouth": _mouth_open()
		"jam": _jam()
		"pull": _pull(count)
		"coin_junk": _coin_junk(count)


## A Hazard node at pos, with a looping 8x8 strip when given.
func _hazard_node(kind: String, pos: Vector2, strip := "") -> Hazard:
	var h := Hazard.new(kind)
	h.position = pos
	if strip:
		Fx.play(h, strip, 8, 8, Vector2.ZERO, 0, true)
	hazards.append(h)
	add_child(h)
	return h


func _free_hazard(h: Hazard) -> void:
	hazards.erase(h)
	h.queue_free()


## Kills the pending volley and frees the flight hazards, or every hazard (the fight ending).
func _clear_hazards(flight_only: bool) -> void:
	for tw in volley:
		tw.kill()
	volley = []
	for h in hazards.duplicate():
		if not flight_only or h.row.get("flight", false):
			_free_hazard(h)


## A hazard touched the paddle: the paddle flashes red and its hp is paid.
func _hazard_touch(h: Hazard) -> void:
	Fx.play(paddle, "paddle_hurt", 60, 12, Vector2.ZERO).scale = paddle.size / Vector2(60, 8)
	hurt(h.row.hp)


## Moves every hazard: enemy balls bounce off the side walls and vanish past the line, debris lands on the floor with a
## puff, any of them touching the paddle pays. Lasers tick their own clock.
func _tick_hazards(delta: float) -> void:
	for h in hazards.duplicate():
		if h.kind == "laser_sweep":
			_tick_laser(h, delta)
		else:
			h.position += h.vel * delta
			if h.kind == "enemy_balls" and (h.position.x < h.r or h.position.x > field.size.x - h.r):
				h.position.x = clampf(h.position.x, h.r, field.size.x - h.r)
				h.vel.x = -h.vel.x
				Sfx.play("ball_bounce", 0.6)
			if h.vel != Vector2.ZERO and _pads().any(func(p): return p.rect().grow(h.r).has_point(h.position)):
				_hazard_touch(h)
				_free_hazard(h)
			elif h.kind == "debris" and h.position.y > field.size.y - h.r:
				Fx.play(self, "dust_puff", 12, 12, Vector2(h.position.x, field.size.y - 8))
				Sfx.play("solid_bounce", 1.3)
				_free_hazard(h)
			elif h.position.y > field.size.y + h.r:
				_free_hazard(h)
		if over:
			return


## red_bricks: count live plain bricks in the rows nearest the paddle turn red, staggered, away from other reds if it can.
func _red_bricks(count: int) -> void:
	var H: Dictionary = Tuning.HAZARDS.red_bricks
	var plain := _bricks("plain")
	var ys := {}
	for b in plain:
		ys[b.position.y] = true
	var rows: Array = ys.keys()
	rows.sort()
	rows = rows.slice(maxi(0, rows.size() - H.rows))  # the largest y: nearest the paddle
	var pool := plain.filter(func(b): return b.position.y in rows)
	var reds := _bricks("red")
	var apart := Tuning.BRICK_SIZE.x + Tuning.BRICK_GAP + 1
	for i in count:
		if pool.is_empty():
			break
		var clear := pool.filter(func(b): return reds.all(func(r): return r.position.distance_to(b.position) > apart))
		var pick: Box = (clear if clear else pool).pick_random()
		pool.erase(pick)
		reds.append(pick)
		_later(i * H.stagger, _paint.bind(pick.get_instance_id(), i))


## A brick becomes a red in place, so its layout slot still regrows the original kind.
func _paint(id: int, i: int) -> void:
	var b = instance_from_id(id)
	if not b or b.is_queued_for_deletion():
		return
	b.kind = "red"
	b.face(Tuning.BRICKS.red.face)
	Fx.play(self, "red_bricks_paint", 30, 12, b.position)
	Sfx.play("cond_primed", 0.6 * Sfx.st(-i))


## enemy_balls: a warning ring at the enemy's centre through the wind-up, then count balls fanned at the paddle.
func _enemy_balls(count: int) -> void:
	var H: Dictionary = Tuning.HAZARDS.enemy_balls
	var warn := _hazard_node("enemy_balls", H.origin, "enemy_balls_warn")  # a flight hazard itself, so a phase end clears it
	var wid := warn.get_instance_id()
	var unwarn := func():
		var w = instance_from_id(wid)
		if w:
			_free_hazard(w)
	_later(H.windup, unwarn, true)
	for i in count:
		var off := 0.0 if count == 1 else lerpf(-H.spread_deg, H.spread_deg, i / float(count - 1))
		_later(H.windup + i * H.gap, _enemy_ball.bind(deg_to_rad(off)), true)


## One enemy ball from the enemy's centre toward the paddle, off radians from straight at it. A mimicking boss copies
## the run bag's next ball onto it: its size and speed, and a splitter's fan of copies.
## ponytail: pierce has nothing to pass on the enemy side (no shield floor for hazards), so a needle copies as a plain ball
func _enemy_ball(off: float) -> void:
	var H: Dictionary = Tuning.HAZARDS.enemy_balls
	var row := {}
	var n := 1
	if enemy.get("mimic", false) and Game.run.bag:
		var e: Dictionary = Game.run.bag[mimic_i % Game.run.bag.size()]
		mimic_i += 1
		row = Tuning.BALLS[e.id]
		if row.has("split"):
			n = row.split[e.rank - 1]
			Sfx.play("split_pop", 1.0, 0.05)
	for i in n:
		var h := _hazard_node("enemy_balls", H.origin, "enemy_balls_fly")
		h.r = H.radius * row.get("size", 1.0)
		h.scale = Vector2.ONE * row.get("size", 1.0)
		var fan := 0.0 if n == 1 else deg_to_rad(lerpf(-Tuning.SPLIT_DEG, Tuning.SPLIT_DEG, i / float(n - 1)))
		h.vel = (paddle.position - H.origin).normalized().rotated(off + fan) * Tuning.BALL_SPEED * H.speed * row.get("speed", 1.0)
	Sfx.play("ball_launch", 0.5)


## debris: the board shakes, then count chunks fall from the top wall at random x, spread apart, staggered.
func _debris(count: int) -> void:
	var H: Dictionary = Tuning.HAZARDS.debris
	shake = H.shake
	Sfx.play("blast", 0.6)
	var xs := []
	for i in count:
		var x := randf_range(H.size, field.size.x - H.size)
		for tries in 20:  # ponytail: rejection sampling; a count the width cannot space just overlaps
			if xs.all(func(o): return absf(o - x) >= H.apart):
				break
			x = randf_range(H.size, field.size.x - H.size)
		xs.append(x)
		_later(H.shake + i * H.gap, _debris_chunk.bind(x), true)


func _debris_chunk(x: float) -> void:
	var H: Dictionary = Tuning.HAZARDS.debris
	var h := _hazard_node("debris", Vector2(x, Tuning.TOP_WALL), "debris_fall")
	h.r = H.size / 2
	h.vel = Vector2.DOWN * H.speed


## Board column c's centre x, and the column under an x; lanes are BOARDS[cls].cols wide, the generator's grid.
func _lane_x(c: int) -> float:
	var cols: int = Tuning.BOARDS[cls].cols
	return field.size.x / 2 + (c - (cols - 1) / 2.0) * (Tuning.BRICK_SIZE.x + Tuning.BRICK_GAP)


func _lane(x: float) -> int:
	var cols: int = Tuning.BOARDS[cls].cols
	return clampi(roundi((x - field.size.x / 2) / (Tuning.BRICK_SIZE.x + Tuning.BRICK_GAP) + (cols - 1) / 2.0), 0, cols - 1)


## laser_sweep: a lane on the paddle's column (two: and its mirror) warns, then beams; the paddle inside pays once, a ball
## inside loses its stored damage once. Drawn in _draw; it ticks through a phase end.
func _laser(count: int) -> void:
	var c := _lane(paddle.position.x)
	var mirror: int = Tuning.BOARDS[cls].cols - 1 - c
	for lane in ([c] if count == 1 or mirror == c else [c, mirror]):
		var h := _hazard_node("laser_sweep", Vector2(_lane_x(lane), 0))
		h.t = Tuning.HAZARDS.laser_sweep.warn
	Sfx.play("ui_reveal", 0.5)


func _tick_laser(h: Hazard, delta: float) -> void:
	h.t -= delta
	if h.state == "warn":
		if h.t <= 0:
			h.state = "beam"
			h.t = Tuning.HAZARDS.laser_sweep.beam
			Sfx.play("bolt_sweep", 0.8)
		return
	var half := (Tuning.BRICK_SIZE.x + Tuning.BRICK_GAP) / 2
	if not h.paid and _pads().any(func(p): return absf(p.position.x - h.position.x) <= half):
		h.paid = true
		_hazard_touch(h)
		if over:
			return
	for b in balls:
		if b != rest and b.stored > 0 and absf(b.position.x - h.position.x) <= half and not b.get_instance_id() in h.zapped:
			h.zapped.append(b.get_instance_id())
			b.store(-b.stored)
			Sfx.play("combo_drop", 1.2)
	if h.t <= 0:
		_free_hazard(h)


## shield_row: a solid per board column at SHIELD_Y until `hits` paddle hits; a refire only resets the count.
func _shield_row() -> void:
	shield_left = Tuning.HAZARDS.shield_row.hits
	if shield:
		return
	Sfx.play("armor_pop", 0.7)
	for c in Tuning.BOARDS[cls].cols:
		var pos := Vector2(_lane_x(c), Tuning.SHIELD_Y)
		shield.append(box("solid", Tuning.BRICK_SIZE, pos))
		Fx.play(self, "dust_puff", 12, 12, pos)


func _shield_crumble() -> void:
	Sfx.play("solid_bounce", 0.8)
	for b in shield:
		Fx.play(self, "dust_puff", 12, 12, b.position)
		b.queue_free()
	shield = []
	shield_left = 0


## jam: the paddle clamps to HAZARDS.jam.width of its build for `hits` paddle hits (counted in _paddle_hit); a refire only
## resets the count. The clamp strip plays over the built width, ending on the half paddle.
func _jam() -> void:
	var H: Dictionary = Tuning.HAZARDS.jam
	var fresh := jam_left == 0
	jam_left = H.hits
	Sfx.play("paddle_jam")
	if fresh:
		_paddle_fit()
		Fx.play(paddle, "jam_clamp", 60, 12, Vector2.ZERO).scale = Vector2(paddle_w, Tuning.PADDLE_HEIGHT) / Vector2(60, 8)


## The paddle's width and face for its jam state; the collider is its first child (brick.gd).
func _paddle_fit() -> void:
	var jammed := jam_left > 0
	paddle.size.x = paddle_w * (Tuning.HAZARDS.jam.width if jammed else 1.0)
	paddle.get_child(0).shape.size = paddle.size
	paddle.face("paddle_jam" if jammed else "paddle")
	if not jammed:
		Sfx.play("grow")


## pull: every ball in flight drifts upward (_move_ball) for `secs` per count; the drift strip rises off each one.
func _pull(count: int) -> void:
	pull_t = Tuning.HAZARDS.pull.secs * count
	Sfx.play("pull_lift")
	for b in balls:
		if b != rest:
			Fx.play(b, "pull_drift", 12, 8, Vector2(0, -b.radius - 12))


## coin_junk: a stone goes on top of the bag per count, and into the run's bag for good.
func _coin_junk(count: int) -> void:
	var junk: String = Tuning.HAZARDS.coin_junk.junk
	for i in count:
		Game.add_ball(junk)
		bag.push_front({id = junk, rank = 1})
		Sfx.play("coin", 0.7 * Sfx.st(2 * i), 0.1 * i)
		Sfx.play("teleport_out", 0.5 * Sfx.st(2 * i), 0.1 + 0.1 * i)


## The boss's mouth opens for `mouth` paddle hits: any ball inside is eaten (_physics_process), and on close every eaten
## ball comes back as one enemy ball aimed at the paddle, spit_gap apart.
func _mouth_open() -> void:
	mouth_left = enemy.mouth
	eaten = 0
	Sfx.play("fast_whoosh", 0.5)
	if is_instance_valid(mouth_s):
		mouth_s.queue_free()
	mouth_s = Fx.play(self, "maw_mouth_open", 48, 12, Tuning.MOUTH.rect.get_center(), 0, false, true)


func _mouth_close() -> void:
	mouth_left = 0
	if is_instance_valid(mouth_s):
		mouth_s.queue_free()
	Fx.play(self, "maw_mouth_close", 48, 12, Tuning.MOUTH.rect.get_center())
	Sfx.play("blast", 0.5)
	for i in eaten:
		_later(i * Tuning.MOUTH.spit_gap, _enemy_ball.bind(0.0), true)
	eaten = 0


## The player loses n HP (red bricks and hazards); at 0 the fight is lost.
func hurt(n: int) -> void:
	flash = 0.1
	Sfx.play("hp_lose", Tuning.ladder(Tuning.HP_LOSE, n))
	if Game.hurt(n):
		Game.run.stats.killer = enemy_id
		_end(false)


func _hit(b: Box, ball: Ball) -> void:
	match b.kind:
		"wall": Sfx.play("ball_bounce")
		"solid":
			Fx.play(self, "solid_bounce", 44, 12, b.position)
			Sfx.play("solid_bounce")
		_:
			if b.hp > 0:
				_damage(b, ball)


func _damage(b: Box, ball: Ball) -> void:
	if b.is_queued_for_deletion():
		return
	b.hp -= 1
	if b.hp <= 0:
		_break(b, ball)
		return
	b.flash("%s_hit" % Tuning.hue(b.kind), 30)
	Sfx.play("brick_hit")


## Every box still standing: breakable, not already broken this frame.
func _live() -> Array:
	return get_children().filter(func(o): return o is Box and o.hp > 0 and not o.is_queued_for_deletion())


func _bricks(kind: String) -> Array:
	return _live().filter(func(o): return o.kind == kind)


## The one way anything but a ball's own hit (a blast, a relic) sets off a brick. Bombs go off at once, so a chain of them
## cascades in one frame; the ball that started it is credited with every brick's dmg, and no red it removes hurts.
func _trigger(b: Box, ball: Ball = null) -> void:
	_break(b, ball, false)


## direct: the ball itself hit the brick (false for a blast), which is what arms a red's hurt.
func _break(b: Box, ball: Ball = null, direct := true) -> void:
	if over or b.is_queued_for_deletion():
		return
	b.queue_free()
	Fx.play(self, "%s_break" % Tuning.hue(b.kind), 44, 12, b.position)  # the brick's colour group; sparks stay payout yellow
	Fx.play(self, "spark_burst", 16, 12, b.position)
	breaks += 1
	phase_breaks += 1
	_relics("on_break", ball, b)  # before the store: the combo counts this break
	var pitch: float = ball.row.get("pitch", Sfx.st(mini(combo, 12))) if ball else 1.0
	Sfx.play("brick_break", pitch)
	breakable -= 1
	Game.run.stats.bricks += 1
	if ball:
		ball.store(roundi(ball.dmg * Tuning.BRICKS[b.kind].dmg * combo_mult()))
		ball.poison += ball.at_rank("poison")
		if ball.can_split:
			_split(ball)
		if ball.row.has("every"):  # blaster: every nth break this fight blasts the brick's neighbours too
			ball.entry.breaks = ball.entry.get("breaks", 0) + 1
			if ball.entry.breaks % ball.at_rank("every") == 0:
				_blast(b, ball)
		if ball.row.has("pays"):  # token: every nth break this fight pays its gold, the toll relic's count per ball
			ball.entry.pays = ball.entry.get("pays", 0) + 1
			if ball.entry.pays % ball.at_rank("pays") == 0:
				_pay(ball.row.gold, b.position)
	_effect(b.kind, b, ball, direct)
	if breakable == 0 and refresh_in <= 0 and in_play() > 0:
		refresh_in = Tuning.RUN.refresh_after  # the board is bare with a ball still live: a refresh brick grows


## Balls in flight: every ball but the one resting on the paddle.
func in_play() -> int:
	return balls.size() - int(rest != null)


## A splitter's first break per flight: it becomes `split` balls fanned about its heading. The halves are full copies
## that store their own damage, never return to the bag, and cannot split again until a paddle hit re-arms them.
func _split(ball: Ball) -> void:
	var n := ball.at_rank("split")
	ball.can_split = false
	Fx.play(self, "ball_split_pop", 16, 12, ball.position)
	Sfx.play("split_pop")
	var heading := ball.vel
	for i in n:
		var v := heading.rotated(deg_to_rad(lerpf(-Tuning.SPLIT_DEG, Tuning.SPLIT_DEG, i / float(n - 1))))
		if i == 0:
			ball.vel = v
			continue
		var half := _add_ball(ball.entry.duplicate(), ball.position)
		half.copy = true
		half.vel = v


## A blast at b: every brick within BOMB_RADIUS breaks for the ball. The bomb brick and the blaster ball both fire this.
func _blast(b: Box, ball: Ball = null) -> void:
	Fx.play(self, "bomb_ring", 60, 12, b.position)
	Sfx.play("bomb_boom")
	for n in _near(b, Tuning.BOMB_RADIUS):
		_trigger(n, ball)


## Brick break effects. Crit, refresh and the bomb fire from any break; a red only hurts when a ball broke it directly.
func _effect(kind: String, b: Box, ball: Ball = null, direct := true) -> void:
	match kind:
		"bomb":
			_land(Tuning.BRICKS.bomb.blast)  # the enemy first, then the neighbours for the ball (a win here stops the breaks)
			_blast(b, ball)
		"red":
			if ball and direct:
				hurt(Tuning.BRICKS.red.hurt)
		"crit":
			_crit(b, ball)
		"refresh":
			_refresh(b)
		"gold":  # pays its gold; under a jackpot enemy only the phase that breaks every gold brick pays, the jackpot
			Sfx.play("gold_hit")
			if not enemy.has("jackpot"):
				_pay(Tuning.BRICKS.gold.gold, b.position)
				return
			phase_gold += 1
			if phase_gold == layout.filter(func(s): return s.kind == "gold").size():
				_pay(enemy.jackpot, b.position)
				Sfx.play("jackpot")


## n gold paid at pos: the token ball, a gold brick, relic toll.
func _pay(n: int, pos: Vector2) -> void:
	Game.add_gold(n)
	Fx.play(self, "toll_pay", 30, 12, pos)
	Sfx.play("coin")


## A crit at b: the bag's next ball launches from the paddle (two with relic twin_crit); an empty bag refuses, a stone's
## crits launch nothing.
func _crit(b: Box, ball: Ball) -> void:
	Fx.play(self, "crit_launch", 30, 12, b.position)
	if ball and ball.id == "ball_junk":
		return
	for i in (Tuning.RELICS.twin_crit.launches if Game.has("twin_crit") else 1):
		if bag.is_empty():
			Sfx.play("hit_refused", 0.8)
			return
		var n := in_play()  # the ladder counts balls already in flight, not one resting on the paddle
		var nb := _add_ball(bag.pop_front(), paddle.position + Vector2(0, -Tuning.PADDLE_HEIGHT / 2 - Tuning.BALL_RADIUS * 1.5 - 1))
		_launch(nb)
		Sfx.play("multiball_pop", Sfx.st(2 * mini(n, 4)))


# --- Relics (docs/content.md "Relics") ---

## Every owned relic hooked at `hook` (its row's hook or reset) fires here, one match by id. ball and b are the break's.
## The stat relics are Game.has reads at their site: wide_paddle and magnet_paddle at the paddle build and _move_ball,
## twin_crit in _crit, mini_paddle's second paddle in _pads once this builds it.
func _relics(hook: String, ball: Ball = null, b: Box = null) -> void:
	for id in Game.run.relics:
		var R: Dictionary = Tuning.RELICS[id]
		if hook != R.hook and hook != R.get("reset"):
			continue
		match id:
			"shield_floor":
				saves_left = R.saves
			"tenth_bomb":
				var plain: Array = layout.filter(func(s): return s.kind == "plain")
				for i in range(R.every - 1, plain.size(), R.every):
					plain[i].kind = "bomb"
				if plain and plain.size() < R.every:
					plain.back().kind = "bomb"
			"mini_paddle":
				mini = box("paddle_mini", R.size, Vector2(field.size.x / 2, field.size.y - Tuning.PADDLE_UP))
			"opener":
				if phase_breaks == 1:
					_crit(b, ball)
			"toll":
				if breaks % R.per == 0:
					_pay(R.gold, b.position)
			"combo":
				combo = combo + 1 if combo_t > 0 else 1
				combo_t = Tuning.COMBO_WINDOW_START
			"recall":
				for e in dropped.slice(0, R.balls):
					discard.erase(e)
					bag.push_front(e)
					Fx.play(self, "recall_rise", 12, 12, Vector2(field.size.x / 2, field.size.y - 12))
					Sfx.play("recall")


## relic combo's multiplier on stored damage: 1 + COMBO_MULT_PER_HIT per break past the first, capped; 1 when idle.
func combo_mult() -> float:
	return minf(1 + Tuning.COMBO_MULT_PER_HIT * (combo - 1), Tuning.RELICS.combo.cap) if combo > 0 else 1.0


func _near(b: Box, dist: float) -> Array:
	return _live().filter(func(o): return o != b and o.position.distance_to(b.position) <= dist)


## The fight ends: balls freeze (over stops the physics), hazards and the shield row go; on a win the enemy dies and the
## board breaks outward from it over win_break seconds; then done after a beat.
func _end(win: bool) -> void:
	if over:
		return
	over = true
	_clear_hazards(false)
	if shield:
		_shield_crumble()
	if win:
		Game.run.stats.fights += 1
		Game.run.stats.elites += int(enemy.role == "elite")
		var pitch := 0.6 if enemy.role == "boss" else 1.0
		Sfx.play("enemy_die", pitch)
		_enemy_play("die")
		var live := _live()
		var far: float = maxf(1.0, live.map(func(b): return b.position.distance_to(Tuning.ENEMY_FOOT)).max()) if live else 1.0
		for b in live:
			var id: int = b.get_instance_id()
			var burst := func():
				var o = instance_from_id(id)
				if o:
					Fx.play(self, "%s_break" % Tuning.hue(o.kind), 44, 12, o.position)
					o.queue_free()
			_later(Tuning.RUN.win_break * b.position.distance_to(Tuning.ENEMY_FOOT) / far, burst)
		won.emit()
	else:
		lost.emit()
	create_tween().tween_callback(done.emit.bind(win)).set_delay(Tuning.RUN.end_beat)  # a tween dies with the arena; a timer would not


func _process(_delta: float) -> void:
	hp_l.text = str(enemy.hp) + (" P%d" % enemy.poison if enemy.poison else "")
	intent_s.modulate.a = 0.8 + 0.2 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 2) if enemy.cd_left <= 1 else 1.0
	cd_l.text = str(ceili(enemy.cd_left))
	var px: float = Tuning.HAZARDS.debris.shake_px
	position = home + (Vector2(randf_range(-px, px), randf_range(-px, px)) if shake > 0 else Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	# Base and dots come from the cabinet (ui, drawn beneath this). Here: the frame, the enemy's HP bar, the top wall's
	# line, the bottom lamps and the balls. The frame sits just outside the arena, under the rails.
	var C := Tuning.COLORS
	var w := field.size.x
	var h := field.size.y
	draw_polyline([Vector2(-2, h), Vector2(-2, -2), Vector2(w + 2, -2), Vector2(w + 2, h)], C.trim_hi, 4)
	draw_rect(Rect2(320, 4, 320, 8), C.trim)
	draw_rect(Rect2(320, 4, 320.0 * enemy.hp / enemy.hp_max, 8), C.danger)
	draw_rect(Rect2(0, Tuning.TOP_WALL - 2, w, 4), C.trim_hi)
	var f := int(Time.get_ticks_msec() / 125) % 4  # 8 fps
	for x in range(0, int(w), 64):
		var cw := minf(64, w - x)  # the last chunk stops at the arena's edge
		draw_texture_rect_region(SHIELD_TEX if saves_left > 0 else HAZARD_TEX, Rect2(x, h - 8, cw, 8), Rect2(f * 32, 0, cw / 2, 4))
	for hz in hazards:  # laser lanes: the warn loop, then the beam's frames over its 0.4 s, tiled from the top wall to the floor
		if hz.kind == "laser_sweep":
			var warn: bool = hz.state == "warn"
			var lf := f if warn else mini(int((Tuning.HAZARDS.laser_sweep.beam - hz.t) * 12), 5)
			var y := Tuning.TOP_WALL
			while y < h:
				var th := minf(12, h - y)
				draw_texture_rect_region(LASER_WARN_TEX if warn else LASER_FIRE_TEX, Rect2(hz.position.x - 30, y, 60, th), Rect2(lf * 30, 0, 30, th / 2))
				y += 12
	for b in balls:
		# The ball's own face, its afterimages fading back along the heading: three while piercing, two at FAST_SPEED.
		# The needle's shard is drawn pointing up-right, so it turns by heading + 45 degrees.
		var r := b.radius
		var v: Vector2 = b.vel if b.vel != Vector2.ZERO else Vector2.UP
		var turn := v.angle() + PI / 4 if b.id == "ball_pierce" else 0.0
		var ghosts := 0 if b == rest or b.hold > 0 else 3 if b.pierce_left > 0 else 2 if b.speed >= Tuning.FAST_SPEED else 0
		for i in range(ghosts, -1, -1):
			draw_set_transform(b.position - v.normalized() * r * 1.5 * i, turn)
			draw_texture_rect(b.tex, Rect2(-r, -r, r * 2, r * 2), false, Color(1, 1, 1, 1.0 - i * 0.25))
		draw_set_transform(Vector2.ZERO)
	if flash > 0:
		draw_rect(field, Color(C.danger, 0.25))
