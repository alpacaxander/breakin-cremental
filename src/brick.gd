extends StaticBody2D
## Any rectangle in the arena: plain/solid brick, bumper, paddle, wall.

const Tuning = preload("res://src/tuning.gd")

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
	if kind != "wall":
		draw_rect(Rect2(-size / 2, size), Tuning.COLORS[kind])
