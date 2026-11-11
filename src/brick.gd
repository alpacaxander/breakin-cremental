extends StaticBody2D
## Any piece in the arena: board bricks, organ cells, paddle, wall. Rules in arena.gd; this is shape and look.
## The look comes from the kind's row in tuning.gd (face, idle, halo, offset).

const Tuning = preload("res://src/tuning.gd")
const Fx = preload("res://src/fx.gd")
const PNG := "res://assets/pixel/png/%s.png"

var kind := "plain"
var hp := 1  # < 0 = unbreakable
var size := Vector2.ONE
var tex: Texture2D
var idle_sprite: AnimatedSprite2D
var organ = null  # an organ cell's arena Organ node; null on every other piece


func _ready() -> void:
	var c := CollisionShape2D.new()
	var p := Tuning.spec(kind)
	c.shape = RectangleShape2D.new()
	c.shape.size = size
	add_child(c)
	face(p.get("face"))
	idle(p.get("idle"))
	if p.has("halo"):
		Fx.play(self, p.halo, 60, 8, Vector2.ZERO, 0, true).show_behind_parent = true


## Axis-aligned bounds.
func rect() -> Rect2:
	return Transform2D(rotation, position) * Rect2(-size / 2, size)


func face(spec) -> void:
	tex = tex_of(spec)
	queue_redraw()


## The texture a face spec names (see Tuning.BRICKS).
static func tex_of(spec) -> Texture2D:
	return null if spec == null else load(PNG % spec) if spec is String else Fx.frame(spec[0], spec[1], spec[2])


func idle(spec) -> void:
	if idle_sprite:
		idle_sprite.queue_free()
	idle_sprite = null if spec == null else Fx.play(self, spec[0], spec[1], spec[2], Vector2.ZERO, 0, true)


## One-shot strip played over this piece.
func flash(name: String, fw: int, fps := 12) -> void:
	Fx.play(self, name, fw, fps, Vector2.ZERO)


func _draw() -> void:
	if tex == null:
		return
	# ponytail: the paddle sprite stretches with its width (relic wide_paddle); 3-slice it if the chrome bands smear.
	var s := size if kind == "paddle" else tex.get_size() * Fx.SCALE
	draw_texture_rect(tex, Rect2(-s / 2 + Tuning.spec(kind).get("offset", Vector2.ZERO), s), false)
