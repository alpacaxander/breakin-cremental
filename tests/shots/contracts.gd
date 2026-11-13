extends RefCounted
## The contracts' pictures: the placeholder menu through the whole render chain, and a chart that shows which
## colours glow. Look at the chart after changing Palette, the bloom settings in main.tscn or the CRT shader.


func shots() -> Array[Dictionary]:
	return [
		{"name": "menu"},
		{"name": "menu_crt_off", "crt": false},
		{"name": "bloom", "crt": false, "setup": _chart},
		{"name": "bloom_crt", "setup": _chart},
	]


## Top row: every lit colour, drawn lit, as a brick and as a block. Second row: the same colours unlit.
## Third row: the neutrals, which must not glow. Then the ball, and a line of lit text beside plain text.
func _chart(main: Main) -> void:
	for child in main.screen.get_children():
		child.free()
	var chart := Control.new()
	main.screen.add_child(chart)
	var lit: Array[Color] = [Palette.PLAYER, Palette.PLACEABLE, Palette.COINS, Palette.TIME, Palette.EXPLOSIVE, Palette.DANGER]
	lit.append_array(Palette.HP)
	for i in lit.size():
		_rect(chart, Vector2(120 + i * 104, 120), Vector2(14, 62), Palette.lit(lit[i]))
		_rect(chart, Vector2(150 + i * 104, 120), Vector2(48, 62), Palette.lit(lit[i]))
		_rect(chart, Vector2(120 + i * 104, 240), Vector2(78, 62), lit[i])
	var neutrals: Array[Color] = [Palette.PANEL, Palette.WALL, Palette.BORDER, Palette.PADDLE, Palette.TEXT_DIM, Palette.TEXT]
	for i in neutrals.size():
		_rect(chart, Vector2(120 + i * 104, 360), Vector2(78, 62), neutrals[i])
	_rect(chart, Vector2(120, 500), Vector2(12, 12), Palette.lit(Palette.BALL, Palette.LIT_BALL))
	_text(chart, Vector2(224, 480), "LIT 1,234", Palette.lit(Palette.COINS))
	_text(chart, Vector2(536, 480), "plain text", Palette.TEXT)


func _rect(parent: Control, at: Vector2, size: Vector2, colour: Color) -> void:
	var r := ColorRect.new()
	r.position = at
	r.size = size
	r.color = colour
	parent.add_child(r)


func _text(parent: Control, at: Vector2, text: String, colour: Color) -> void:
	var l := Label.new()
	l.position = at
	l.text = text
	l.add_theme_font_size_override("font_size", 48)
	l.add_theme_color_override("font_color", colour)
	parent.add_child(l)
