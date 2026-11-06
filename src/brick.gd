extends StaticBody2D
## Any rectangle in the arena: plain/solid brick, bumper, paddle, wall.

const Tuning = preload("res://src/tuning.gd")
const TEX := {
	plain = preload("res://assets/pixel/png/brick_plain_lit.png"),
	solid = preload("res://assets/pixel/png/brick_solid.png"),
	bumper = preload("res://assets/pixel/png/bumper.png"),
	paddle = preload("res://assets/pixel/png/paddle.png"),
}

var kind := "plain"
var hp := 1  # < 0 = unbreakable
var size := Vector2.ONE
var _shape := RectangleShape2D.new()


func _ready() -> void:
	_shape.size = size
	var c := CollisionShape2D.new()
	c.shape = _shape
	add_child(c)


## Axis-aligned bounds. ponytail: a rotated bumper's box is its AABB, so overlap checks are conservative.
func rect() -> Rect2:
	return Transform2D(rotation, position) * Rect2(-size / 2, size)


func _draw() -> void:
	# ponytail: the paddle sprite stretches with width upgrades; 3-slice it if the chrome bands smear.
	if kind in TEX:
		draw_texture_rect(TEX[kind], Rect2(-size / 2, size), false)
