extends StaticBody2D
## Any piece in the arena: board bricks, organ cells, paddle, wall. Rules in arena.gd; this is shape and look.
## The look comes from the kind's row in tuning.gd (face, idle, halo, offset); set_kind changes a live piece's kind.
## A layer (add_layer, drop_layer) sits on top as an overlay sprite and stays through a kind change.

const Tuning = preload("res://src/tuning.gd")
const Fx = preload("res://src/fx.gd")
const PNG := "res://assets/pixel/png/%s.png"

var kind := "plain"
var hp := 1  # < 0 = unbreakable
var size := Vector2.ONE
var tex: Texture2D
var idle_sprite: AnimatedSprite2D
var organ = null  # an organ cell's arena Organ node; null on every other piece
var source := ""  # who made this brick: "design", "relic:<id>", "ball:<uid>", "enemy:<organ id>" (docs/encounter-mechanics.md); "" plain; a keep's brick has keep >= 0
var keep := -1  # index of the arena keep row that placed it; -1 none
var halo_sprite: AnimatedSprite2D
var layer := {}  # {kind, hp, source} on top of it (Tuning.LAYERS), or empty; survives set_kind
var layer_sprite: Sprite2D


func _ready() -> void:
	var c := CollisionShape2D.new()
	c.shape = RectangleShape2D.new()
	c.shape.size = size
	add_child(c)
	_look()


## The one way a live piece changes kind: hp, face, idle and halo come from the new row. The arena's breakable count is
## the caller's (arena.gd _convert).
func set_kind(k: String, src := "", keep_i := -1) -> void:
	kind = k
	source = src
	keep = keep_i
	hp = Tuning.BRICKS[k].hp if k in Tuning.BRICKS else -1
	_look()


func _look() -> void:
	var p := Tuning.spec(kind)
	face(p.get("face"))
	idle(p.get("idle"))
	if halo_sprite:
		halo_sprite.queue_free()
	halo_sprite = null
	if p.has("halo"):
		halo_sprite = Fx.play(self, p.halo, 60, 8, Vector2.ZERO, 0, true)
		halo_sprite.show_behind_parent = true


## Puts a layer of kind k on (docs/encounter-mechanics.md "Layers"): the same kind and source adds its hp, any other on a layered
## piece is refused unless `replace` (the effect's target allows it). True when it took.
func add_layer(k: String, n: int, src: String, replace := false) -> bool:
	if layer and (layer.kind != k or layer.source != src) and not replace:  # another owner's coat: refused, so a death drops only its own
		return false
	if layer.get("kind") == k:
		layer.hp += n
	else:
		layer = {kind = k, hp = n, source = src}
		_drop_sprite()
		layer_sprite = Sprite2D.new()
		layer_sprite.texture = load(PNG % Tuning.LAYERS[k].face)
		layer_sprite.scale = Vector2.ONE * Fx.SCALE
		layer_sprite.z_index = 1  # over the idle strip, which set_kind re-adds
		add_child(layer_sprite)
	return true


func drop_layer() -> void:
	layer = {}
	_drop_sprite()


func _drop_sprite() -> void:
	if layer_sprite:
		layer_sprite.queue_free()
	layer_sprite = null


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
