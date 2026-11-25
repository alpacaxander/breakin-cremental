class_name UiCoin
extends Control
## The coin glyph (art.md, "UI pieces"): a gold square turned 45°, lit. Its box is the turned square's
## diagonal, centred. With `key`, the key glyph instead: a key lying flat, as tall as the coin's box. Beside a
## number, use UiPrice, which sizes it to the number.

## The key glyph on its 14 x 8 grid: an 8 x 8 head round a 3 x 3 hole, a 6 x 2 shaft and a 2 x 2 tooth.
const KEY_RECTS: Array[Rect2] = [Rect2(0, 0, 8, 2.5), Rect2(0, 5.5, 8, 2.5), Rect2(0, 2.5, 2.5, 3), Rect2(5.5, 2.5, 2.5, 3),
		Rect2(8, 3, 6, 2), Rect2(11, 5, 2, 2)]
const KEY_UNIT_MIN := 1.25  ## px per grid step at the smallest: below it the hole closes up

## The square's side in pixels: about a quarter of the number's font size.
@export var side := 16.0:
	set(v):
		side = v
		_fit()
## A price you can't afford: secondary text, unlit. art.md: never red.
@export var dim := false:
	set(v):
		dim = v
		queue_redraw()
## Draws the key glyph: a price in keys, or the keys held.
@export var key := false:
	set(v):
		key = v
		_fit()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_fit()


func _unit() -> float:
	return maxf(KEY_UNIT_MIN, side * sqrt(2.0) / 8)


func _fit() -> void:
	custom_minimum_size = (Vector2(14, 8) * _unit()).ceil() if key else Vector2.ONE * ceilf(side * sqrt(2.0))
	queue_redraw()


func _draw() -> void:
	var colour := Palette.TEXT_DIM if dim else Palette.lit(Palette.COINS)
	var c := size / 2
	if key:
		var u := _unit()
		var at := c - Vector2(7, 4) * u
		for r in KEY_RECTS:
			draw_rect(Rect2(at + r.position * u, r.size * u), colour)
		return
	var h := side * sqrt(2.0) / 2
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)]), colour)
