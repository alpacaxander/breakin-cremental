extends StaticBody2D
## Any piece in the arena: board bricks, placeables, paddle, wall. Rules in arena.gd; this is shape and look.

const Tuning = preload("res://src/tuning.gd")
const Fx = preload("res://src/fx.gd")
const PNG := "res://assets/pixel/png/%s.png"

# kind -> still face. A string is a sprite; [strip, frame width, frame] is one frame of an animation strip.
const FACE := {
	plain = "brick_plain_lit", solid = "brick_solid", bumper = "bumper", paddle = "paddle",
	multi = "brick_multi_full", multi3 = ["multi3_crack", 30, 0], shield = ["shield_pop", 44, 0],
	cond = "brick_cond_speed_idle", cgate = ["combo_gate", 30, 0], timed = ["timed_blink", 30, 0],
	seq1 = ["sequence_step1", 30, 0], seq2 = ["sequence_step2", 30, 0], seq3 = ["sequence_step3", 30, 0],
	pop = ["pop_bumper_hit", 24, 4], oneway = ["gate_flow", 30, 0], accel = ["accel_chevrons", 30, 0],
	spawner = ["spawner_charge", 30, 0], sticky = "place_sticky", magnet = "place_magnet", tele = "place_tele",
}
# kind -> looping idle [strip, frame width, fps] layered over the face.
const IDLE := {
	timed = ["timed_blink", 30, 8], mystery = ["mystery_cycle", 30, 8],
	oneway = ["gate_flow", 30, 8], accel = ["accel_chevrons", 30, 8], magnet = ["magnet_pull", 44, 8],
}
const FACE_OFFSET := {spawner = Vector2(0, -8)}  # strips taller than the body: shift so the body lines up

var kind := "plain"
var hp := 1  # < 0 = unbreakable
var size := Vector2.ONE
var charge := 0.0  # spawner seconds
var tex: Texture2D
var idle_sprite: AnimatedSprite2D
var overlay_sprite: AnimatedSprite2D  # ghost or hover outline


func _ready() -> void:
	var c := CollisionShape2D.new()
	var p: Dictionary = Tuning.PLACEABLES.get(kind, {})
	if p.get("round", false):
		c.shape = CircleShape2D.new()
		c.shape.radius = size.x / 2
	else:
		c.shape = RectangleShape2D.new()
		c.shape.size = size
	add_child(c)
	if p.get("thru", false):
		collision_layer = 0  # the ball flies through; arena.gd checks overlap itself
	if kind in Tuning.ICON_KINDS:
		face(["icon_%s_pulse" % kind, 30, 0])
		idle(["icon_%s_pulse" % kind, 30, 8])
		Fx.play(self, "halo_pulse", 60, 8, Vector2.ZERO, 0, true).show_behind_parent = true
	else:
		face(FACE.get(kind))
		idle(IDLE.get(kind))


## Axis-aligned bounds. ponytail: a rotated bumper's box is its AABB, so overlap checks are conservative.
func rect() -> Rect2:
	return Transform2D(rotation, position) * Rect2(-size / 2, size)


func face(spec) -> void:
	tex = tex_of(spec)
	queue_redraw()


## The texture a face spec names (see FACE); the tray shows pieces with it.
static func tex_of(spec) -> Texture2D:
	return null if spec == null else load(PNG % spec) if spec is String else Fx.frame(spec[0], spec[1], spec[2])


func idle(spec) -> void:
	idle_sprite = _swap(idle_sprite, spec, true)


func overlay(spec) -> void:
	overlay_sprite = _swap(overlay_sprite, spec, true)


## One-shot strip played over this piece.
func flash(name: String, fw: int, fps := 12) -> void:
	Fx.play(self, name, fw, fps, Vector2.ZERO)


func _swap(old: AnimatedSprite2D, spec, loop: bool) -> AnimatedSprite2D:
	if old:
		old.queue_free()
	return null if spec == null else Fx.play(self, spec[0], spec[1], spec[2], Vector2.ZERO, 0, loop)


func _draw() -> void:
	if tex == null:
		return
	# ponytail: the paddle sprite stretches with width upgrades; 3-slice it if the chrome bands smear.
	var s := size if kind == "paddle" else tex.get_size() * Fx.SCALE
	draw_texture_rect(tex, Rect2(-s / 2 + FACE_OFFSET.get(kind, Vector2.ZERO), s), false)
