## Cabinet UI: every screen is a 640x360 sprite-space Control shown at 2x. A score/stats column sits at x 0, the field spans
## 80-559 and a pieces/menu column sits at 562, with rails between. Look: src/theme.tres and assets/pixel/preview/ui_*.png.
extends Node

const Tuning = preload("res://src/tuning.gd")
const Fx = preload("res://src/fx.gd")
const PNG := "res://assets/pixel/png/%s.png"
const SIZE := Vector2(640, 360)
const RX := 562  # right column x; columns are 78 wide, text inset 6
const FIELD_X := 80
const FIELD_W := 480


## A 2x sprite-space screen. Esc emits back when something listens; otherwise the event falls through (to the arena).
class Root extends Control:
	signal back

	func _init() -> void:
		size = SIZE
		scale = Vector2.ONE * Fx.SCALE
		z_index = 2  # above the arena's effect sprites (z 1), so overlays dim them too
		mouse_filter = MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working over a paused tree

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and back.has_connections():
			get_viewport().set_input_as_handled()
			back.emit()


## The peg-board dots behind the field. Static, so drawn once.
class Dots extends Control:
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for y in range(10, 360, 10):
			for x in range(90, 560, 10):
				draw_rect(Rect2(x, y, 1, 1), Tuning.COLORS.trim)


static func tex(name: String) -> Texture2D:
	return load(PNG % name)


## Base, dots, both columns (titled when given) and rails. under: base and dots draw beneath the parent's own drawing (the arena's balls).
static func chassis(left := "", right := "", under := false) -> Root:
	var r := Root.new()
	var base := ColorRect.new()
	base.color = Tuning.COLORS.bg
	base.size = SIZE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in [base, Dots.new()]:
		if under:
			n.z_index = -3  # relative to the root's 2: lands at -1, beneath the parent's own drawing
		r.add_child(n)
	for x in [0, RX]:
		var p := panel(r, x, 0, 78, 360)
		p.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks on a column never reach the field
		var rail := TextureRect.new()
		rail.texture = tex("ui_rail")
		rail.stretch_mode = TextureRect.STRETCH_TILE
		rail.flip_h = x > 0
		rail.position.x = 78 if x == 0 else RX - 2
		rail.size = Vector2(2, 360)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(rail)
	for t in [[0, left], [RX, right]]:
		if t[1]:
			label(r, t[1], t[0], 6, Tuning.COLORS.rivet, 1, 78, HORIZONTAL_ALIGNMENT_CENTER)
			rect(r, t[0] + 3, 14, 72, 1, Tuning.COLORS.rivet)
	return r


static func panel(parent: Node, x: float, y: float, w: float, h: float) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = tex("ui_panel")
	for side in ["left", "top", "right", "bottom"]:
		p.set("patch_margin_" + side, 3)
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


static func rect(parent: Node, x: float, y: float, w: float, h: float, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.position = Vector2(x, y)
	r.size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## k: glyph scale (1 = 5px). w > 0 fixes the width and wraps by word.
static func label(parent: Node, s: String, x: float, y: float, c: Color, k := 1, w := 0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = s
	l.position = Vector2(x, y)
	l.add_theme_color_override("font_color", c)
	if k != 1:
		l.add_theme_font_size_override("font_size", 5 * k)
	if w > 0:
		l.size.x = w
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.horizontal_alignment = align
	parent.add_child(l)
	return l


## Centred across the field.
static func centre(parent: Node, s: String, y: float, c: Color, k := 1) -> Label:
	return label(parent, s, FIELD_X, y, c, k, FIELD_W, HORIZONTAL_ALIGNMENT_CENTER)


## mint: the lamp button, else chrome. k: text scale.
static func button(parent: Node, s: String, x: float, y: float, w: float, h: float, on_press: Callable, mint := false, k := 2) -> Button:
	var b := Button.new()
	b.text = s
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE  # else Space re-presses the last clicked button
	if mint:
		b.theme_type_variation = &"Mint"
	if k != 1:
		b.add_theme_font_size_override("font_size", 5 * k)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## A sprite by name or texture at a sprite-space position.
static func icon(parent: Node, t, x: float, y: float) -> TextureRect:
	var i := TextureRect.new()
	i.texture = tex(t) if t is String else t
	i.position = Vector2(x, y)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(i)
	return i


## n pips, the first `on` lit. ponytail: 5px pitch so a 12-capacity row fits the column.
static func pips(parent: Node, x: float, y: float, n: int, on: int, lit := "ui_pip_on") -> void:
	for i in n:
		icon(parent, lit if i < on else "ui_pip_off", x + i * 5, y)


## Coin, CASH caption and the amount. Returns the amount label.
static func cash(parent: Node, x: float, n: int) -> Label:
	icon(parent, "coin", x + 6, 22)
	label(parent, "CASH", x + 16, 23, Tuning.COLORS.rivet)
	return label(parent, money(n), x + 6, 32, Tuning.COLORS.pay, 2)


## Thousands separators. ponytail: 9 digits overflow the 66px column at 2x; shorten with K/M if the economy gets there.
static func money(n: int) -> String:
	var s := str(n)
	var o := ""
	for i in s.length():
		o += ("," if i and (s.length() - i) % 3 == 0 else "") + s[i]
	return o


## A row of blinking lamps across the field.
static func bulbs(parent: Node, y: float) -> void:
	for x in range(FIELD_X, FIELD_X + FIELD_W, 32):
		Fx.play(parent, "hazard_strip", 32, 8, Vector2(x + 16, y + 2), 0, true).scale = Vector2.ONE


## A translucent full-screen sheet that swallows clicks, for panels over the arena.
static func overlay(alpha: float) -> Root:
	var r := Root.new()
	var c := ColorRect.new()
	c.color = Color(Tuning.COLORS.bg, alpha)
	c.size = SIZE
	r.add_child(c)
	return r


## Centred panel with a title and stacked buttons. buttons: [[text, mint, callable], ...]
static func dialog(title: String, buttons: Array) -> Root:
	var r := overlay(0.7)
	panel(r, 240, 110, 160, 38 + buttons.size() * 24)
	centre(r, title, 120, Tuning.COLORS.pay, 2)
	for i in buttons.size():
		button(r, buttons[i][0], 260, 140 + i * 24, 120, 18, buttons[i][2], buttons[i][1])
	return r


static func settings(back: Callable) -> Root:
	var r := chassis()
	centre(r, "SETTINGS", 60, Tuning.COLORS.pay, 2)
	label(r, "FULLSCREEN", 220, 104, Tuning.COLORS.white)
	var fs := CheckButton.new()
	fs.position = Vector2(380, 102)
	fs.focus_mode = Control.FOCUS_NONE
	fs.button_pressed = Game.settings.fullscreen
	fs.toggled.connect(func(on): Game.set_setting("fullscreen", on))
	r.add_child(fs)
	label(r, "VOLUME", 220, 128, Tuning.COLORS.white)
	var vol := HSlider.new()
	vol.position = Vector2(300, 126)
	vol.size = Vector2(96, 8)
	vol.focus_mode = Control.FOCUS_NONE
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Game.settings.volume
	vol.value_changed.connect(func(v): Game.set_setting("volume", v))
	r.add_child(vol)
	button(r, "BACK", 260, 160, 120, 18, back)
	r.back.connect(back)
	return r
