class_name UiBar
extends Control
## A 6 px meter (art.md, "HUD numbers"): the meaning's colour, lit, from the left end to `value`, over the
## meaning's dim shade. The timer is 220 wide in &"time", the combo window 160 wide in &"coins". The screen
## sets the width; the height is 6.

@export var meaning := &"time":
	set(v):
		meaning = v
		queue_redraw()
## How full, from 0 to 1.
@export_range(0.0, 1.0) var value := 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

const HEIGHT := 6


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size.y = HEIGHT


func _draw() -> void:
	var y := (size.y - HEIGHT) / 2
	draw_rect(Rect2(0, y, size.x, HEIGHT), Palette.dim(meaning))
	draw_rect(Rect2(0, y, size.x * value, HEIGHT), Palette.lit(Palette.of(meaning)))
