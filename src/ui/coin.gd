class_name UiCoin
extends Control
## The coin glyph (art.md, "UI pieces"): a gold square turned 45°, lit. Its box is the turned square's
## diagonal, centred. Beside a number, use UiPrice, which sizes it to the number.

## The square's side in pixels: about a quarter of the number's font size.
@export var side := 16.0:
	set(v):
		side = v
		custom_minimum_size = Vector2.ONE * ceilf(side * sqrt(2.0))
		queue_redraw()
## A price you can't afford: secondary text, unlit. art.md: never red.
@export var dim := false:
	set(v):
		dim = v
		queue_redraw()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	side = side


func _draw() -> void:
	var c := size / 2
	var h := side * sqrt(2.0) / 2
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)]),
			Palette.TEXT_DIM if dim else Palette.lit(Palette.COINS))
