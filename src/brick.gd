extends StaticBody2D
## Any piece in the arena: board bricks, placeables, paddle, wall. Rules in arena.gd; this is shape and look.
## The look comes from the kind's row in tuning.gd (face, idle, offset); icon kinds derive theirs from the kind name.

const Tuning = preload("res://src/tuning.gd")
const Fx = preload("res://src/fx.gd")
const PNG := "res://assets/pixel/png/%s.png"

var kind := "plain"
var hp := 1  # < 0 = unbreakable
var size := Vector2.ONE
var charge := 0.0  # spawner seconds
var fuse := 0.0  # seconds left on an armed Tuning.FUSED brick, 0 = not armed
var tex: Texture2D
var idle_sprite: AnimatedSprite2D
var overlay_sprite: AnimatedSprite2D  # ghost or hover outline


func _ready() -> void:
	var c := CollisionShape2D.new()
	var p := Tuning.spec(kind)
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
		Fx.play(self, "halo_pulse" if Tuning.hue(kind) == "blue" else "halo_pulse_ora", 60, 8, Vector2.ZERO, 0, true).show_behind_parent = true
	else:
		face(p.get("face"))
		idle(p.get("idle"))


## Axis-aligned bounds. ponytail: a rotated bumper's box is its AABB, so overlap checks are conservative.
func rect() -> Rect2:
	return Transform2D(rotation, position) * Rect2(-size / 2, size)


func face(spec) -> void:
	tex = tex_of(spec)
	queue_redraw()


## The texture a face spec names (see Tuning.BRICKS); the tray shows pieces with it.
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
	draw_texture_rect(tex, Rect2(-s / 2 + Tuning.spec(kind).get("offset", Vector2.ZERO), s), false)
