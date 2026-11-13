class_name UiPips
extends Control
## Rank pips (art.md, "Upgrade screen"): one square per rank, in a row. Owned ranks are lit in the meaning's
## colour, the rest are 424c6e. On an upgrade node: side 8, gap 4. In the detail panel: side 16, gap 6.

@export var total := 3:
	set(v):
		total = v
		_fit()
@export var owned := 0:
	set(v):
		owned = v
		queue_redraw()
## A Palette meaning name (&"player", &"placeable", &"bricks"...): the colour of an owned pip.
@export var meaning := &"player":
	set(v):
		meaning = v
		queue_redraw()
@export var side := 8:
	set(v):
		side = v
		_fit()
@export var gap := 4:
	set(v):
		gap = v
		_fit()
## For pips on a lit fill (a maxed node): every pip is the base colour.
@export var on_lit := false:
	set(v):
		on_lit = v
		queue_redraw()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_fit()


func _fit() -> void:
	custom_minimum_size = Vector2(maxi(total * (side + gap) - gap, 0), side)
	queue_redraw()


func _draw() -> void:
	var y := (size.y - side) / 2
	for i in total:
		var c := Palette.BASE if on_lit else Palette.lit(Palette.of(meaning)) if i < owned else Palette.BORDER
		draw_rect(Rect2(i * (side + gap), y, side, side), c)
