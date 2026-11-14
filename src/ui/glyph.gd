class_name UiGlyph
extends Texture2D
## A flat icon drawn as shapes, not pixels: a Texture2D that draws itself with the RenderingServer. It goes
## anywhere a texture goes (Button.icon, the CheckBox and HSlider icons in the theme, a TextureRect) and stays
## sharp at any window size. art.md: flat filled shapes or 2.5 px strokes, no font glyphs for arrows.
##
## Make one with UiTheme.icon(shape) for a button, or UiGlyph.new(...) for anything else.

enum Shape {
	NONE,  ## Draws nothing. Where the theme needs a texture and none may show
	BACK,  ## Left-pointing arrow: the back button
	PREV,  ## Left chevron: the level panel's ◄
	NEXT,  ## Right chevron: the level panel's ►
	DOWN,  ## Down chevron: an OptionButton's arrow
	PLAY,  ## Filled triangle pointing right: after START and PLAY LEVEL
	PLUS,  ## Zoom in
	MINUS,  ## Zoom out
	DOT,  ## A small filled square: a selected item in a popup
	BOX,  ## The toggle: a square with a 2 px border in `colour`, filled with `fill`
	GRABBER,  ## The slider's grabber: a 16 x 28 rectangle in `colour`, centred in `size`
}

const STROKE := 2.5  ## art.md's icon stroke, in pixels at a 16 px icon

var shape := Shape.NONE
var size := Vector2(16, 16)
## The colour it draws in, times the modulate it is drawn with. Left CLEAR, it draws in that modulate alone:
## that is how a Button's theme icon colours (icon_normal_color, icon_disabled_color...) tint it.
var colour := Palette.CLEAR
var fill := Palette.CLEAR  ## BOX only


func _init(s := Shape.NONE, px := Vector2(16, 16), c := Palette.CLEAR, f := Palette.CLEAR) -> void:
	shape = s
	size = px
	colour = c
	fill = f


func _get_width() -> int:
	return int(size.x)


func _get_height() -> int:
	return int(size.y)


func _has_alpha() -> bool:
	return true


func _is_pixel_opaque(_x: int, _y: int) -> bool:
	return false


func _draw(ci: RID, pos: Vector2, modulate: Color, _transpose: bool) -> void:
	_paint(ci, Rect2(pos, size), modulate)


func _draw_rect(ci: RID, rect: Rect2, _tile: bool, modulate: Color, _transpose: bool) -> void:
	_paint(ci, rect, modulate)


func _draw_rect_region(ci: RID, rect: Rect2, _src: Rect2, modulate: Color, _transpose: bool, _clip_uv: bool) -> void:
	_paint(ci, rect, modulate)


func _paint(ci: RID, r: Rect2, modulate: Color) -> void:
	var c := modulate if colour == Palette.CLEAR else colour * modulate
	var k := minf(r.size.x, r.size.y) / 16.0  # icon shapes are written in a 16 x 16 box, centred in r
	var o := r.get_center() - Vector2(8, 8) * k
	var line := func(points: Array) -> void:
		var p := PackedVector2Array()
		for v: Vector2 in points:
			p.append(o + v * k)
		RenderingServer.canvas_item_add_polyline(ci, p, PackedColorArray([c]), STROKE * k, true)
	match shape:
		Shape.BACK:
			line.call([Vector2(7, 2.5), Vector2(1.5, 8), Vector2(7, 13.5)])
			line.call([Vector2(2, 8), Vector2(14.5, 8)])
		Shape.PREV:
			line.call([Vector2(11, 2), Vector2(5, 8), Vector2(11, 14)])
		Shape.NEXT:
			line.call([Vector2(5, 2), Vector2(11, 8), Vector2(5, 14)])
		Shape.DOWN:
			line.call([Vector2(2, 5), Vector2(8, 11), Vector2(14, 5)])
		Shape.PLUS:
			line.call([Vector2(8, 2), Vector2(8, 14)])
			line.call([Vector2(2, 8), Vector2(14, 8)])
		Shape.MINUS:
			line.call([Vector2(2, 8), Vector2(14, 8)])
		Shape.PLAY:
			var p := PackedVector2Array([o + Vector2(3, 1) * k, o + Vector2(14, 8) * k, o + Vector2(3, 15) * k])
			RenderingServer.canvas_item_add_polygon(ci, p, PackedColorArray([c]))
		Shape.DOT:
			RenderingServer.canvas_item_add_rect(ci, Rect2(o + Vector2(5, 5) * k, Vector2(6, 6) * k), c)
		Shape.BOX:
			if fill.a > 0.0:
				RenderingServer.canvas_item_add_rect(ci, r, fill * modulate)
			for edge in [Rect2(r.position, Vector2(r.size.x, 2)), Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)),
					Rect2(r.position, Vector2(2, r.size.y)), Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y))]:
				RenderingServer.canvas_item_add_rect(ci, edge, c)
		Shape.GRABBER:
			RenderingServer.canvas_item_add_rect(ci, Rect2(r.get_center() - Vector2(8, 14), Vector2(16, 28)), c)
