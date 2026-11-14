extends RefCounted
## The contracts' pictures: the main menu through the whole render chain, and a chart that shows which
## colours glow. Look at the chart after changing Palette, the bloom settings in main.tscn or the CRT shader.
##
## The white_<n> shots are a check as well as a picture: they measure the ball against the bricks of each level
## and log an error, which fails `tests/run.sh shots`, if a brick comes near the ball's white (see _white).

## The most white a brick's pixel may hold, as a share of the ball's. The whitest step now, 3 HP, measures 0.56.
## The pale colour that once was the top step (fdd2ed) measured 0.83 and outshone the ball in rows.
const WHITE_MOST := 0.7


func shots() -> Array[Dictionary]:
	return [
		{"name": "menu"},
		{"name": "menu_crt_off", "crt": false},
		{"name": "bloom", "crt": false, "setup": _chart},
		{"name": "bloom_crt", "setup": _chart},
		{"name": "white_1", "save": "maxed", "crt": false, "setup": _white.bind(1)},
		{"name": "white_2", "save": "maxed", "crt": false, "setup": _white.bind(2)},
		{"name": "white_3", "save": "maxed", "crt": false, "setup": _white.bind(3)},
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


## White belongs to the ball (docs/palette.md): on level `number`, with every upgrade owned so the special bricks
## are there, no brick's pixel may come near the ball's white, at rest or at the top of the bloom.
## The picture shows every lit colour with its strongest channel at full, so what sets the ball apart is its
## weakest channel: how much white a pixel holds. That is what is measured, on the picture as the player gets
## it, with the CRT off so no scanline darkens a pixel. The picture kept is the one at the top of the bloom.
func _white(main: Main, number: int) -> void:
	Progress.layouts.erase(number)
	var level := Main.show_level(number)
	level.call("start", 7)
	(level.get("fx") as Fx).frozen = true  # the round stands still: nothing breaks, and the bloom stays where it is put
	var round: Round = level.get("round")
	var zoom := round.board.zoom()
	for bloom: float in [0.0, 1.0]:
		Main.set_bloom(bloom)
		await main.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := main.get_viewport().get_texture().get_image()
		var ball := _whitest(image, Rect2(LevelArena.ORIGIN + (round.balls[0].pos - Vector2.ONE * round.balls[0].size * 0.5) * zoom, Vector2.ONE * round.balls[0].size * zoom))
		var brick := Palette.BASE
		for cell: Vector2i in round.board.bricks:
			var rect := round.board.cell_rect(cell).grow(-1.0)
			var found := _whitest(image, Rect2(LevelArena.ORIGIN + rect.position * zoom, rect.size * zoom))
			if _white_in(found) > _white_in(brick):
				brick = found
		var share := _white_in(brick) / _white_in(ball)
		print("white: level %d at %s: the ball's whitest pixel is %s and a brick's is %s, which holds %.2f of the ball's white (%.2f at most)"
				% [number, "the top of the bloom" if bloom else "rest bloom", ball.to_html(false), brick.to_html(false), share, WHITE_MOST])
		if share > WHITE_MOST:
			push_error("white: a brick on level %d is nearly as white as the ball (%s against %s). White belongs to the ball: see Palette.HP" % [number, brick.to_html(false), ball.to_html(false)])


## How much white a colour holds: its weakest channel.
func _white_in(c: Color) -> float:
	return minf(c.r, minf(c.g, c.b))


## The whitest pixel of `image` inside `rect`, which is in frame pixels.
func _whitest(image: Image, rect: Rect2) -> Color:
	var best := Palette.BASE
	for y in range(ceili(rect.position.y), floori(rect.end.y)):
		for x in range(ceili(rect.position.x), floori(rect.end.x)):
			var c := image.get_pixel(x, y)
			if _white_in(c) > _white_in(best):
				best = c
	return best


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
