class_name UiTheme
## The game's Theme (docs/art.md, "Type" and "UI pieces"). Main puts build() on its Screen node, so every Control
## under a screen inherits it. A screen lays controls out, picks a type variation, and never restyles one.
##
## TYPE VARIATIONS (set `theme_type_variation`). Sizes are art.md's, rounded so every stem of a pixel font is the
## same width; the size actually used follows the arrow.
##   Label (no variation)  Chakra Petch 16 on a 22 line, primary text: descriptions, body text
##   Hint                  Chakra Petch 14, secondary text: a hint line, a key reminder
##   Name                  Chakra Petch SemiBold 18: an upgrade's or a level's name in a panel
##   SmallName             Chakra Petch SemiBold 14: a name on an upgrade node or a tray slot
##   Tag                   Silkscreen 12 -> 16, spacing 2, secondary text: a label over a number (COINS, TIME,
##                         RANK 2/3, a category). Write the text in capitals
##   SmallTag              Silkscreen 11 -> 16 (8 is unreadable), spacing 1, secondary text: a price on a node,
##                         a small caption
##   Title                 Jersey 10 56: a screen title
##   PanelTitle            Jersey 10 46 -> 37: a panel's title (the level panel, the detail panel)
##   Number                Jersey 10 36 -> 37: a number in a panel (a price, a summary line), a pop-up
##   HudNumber             Jersey 10 68 -> 75: the HUD's timer and coin counter, the hub's balance
##   ComboNumber           Jersey 10 84 -> 93: the combo counter
##   Every Label variation is in primary text (Tag, SmallTag and Hint in secondary). A number that should glow
##   (time, combo, coins, prices) is lit with UiTheme.light(label, Palette.COINS).
##
##   Button (no variation) the primary button: cyan fill, base-colour Jersey 10 text, 56 tall. Disabled is the
##                         disabled look. For START with its triangle: icon = UiTheme.icon(UiGlyph.Shape.PLAY, 18),
##                         icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
##   SecondaryButton       the same size with a base fill and a cyan border: a menu button that isn't selected
##                         (selection() swaps the two)
##   CantAfford            no fill, a lit red border, primary text: a buy button you can't afford. Keep it enabled
##                         (Sfx plays "can't afford" on its press); swap the variation back when you can afford it
##   IconButton            44 x 44, base fill, cyan border, the icon in primary text: give it an icon and no text,
##                         icon = UiTheme.icon(UiGlyph.Shape.PREV). Disabled turns the border 424c6e
##   CheckBox, CheckButton the toggle: a 44 x 44 square, base fill off, lit cyan fill on, its text to the right
##   HSlider               the slider: a 6 px track, lit cyan up to a 16 x 28 grabber, 44 tall
##   OptionButton          a dropdown in the SecondaryButton look with a chevron; its popup is a panel
##   Panel, PanelContainer the panel: 1a1932 fill, 2 px 424c6e border, 20 px padding (PanelContainer)
##   Tooltips              any tooltip_text shows in a small panel in Chakra Petch 14
##
## WIDGETS (src/ui/, each a class_name):
##   UiGlyph       a flat vector icon as a Texture2D. UiTheme.icon(shape) makes one a button tints
##   UiCoin        the coin glyph on its own
##   UiPrice       coin glyph + amount, lit gold or dim: coin counters and prices
##   UiPips        rank pips
##   UiBar         the 6 px timer or combo meter
##   UiBackButton  the back button. Connect `pressed`; it has no shortcut, no tooltip and plays no sound
##   UiTopBar      the 84 px top bar of the hub and Settings: the back button and the screen's title
## And here: build(), icon(), light(), pulse(), selection(), numbers(), number_size().
##
## A widget here plays no sound: Sfx plays the click of every button by itself.
##
## It is built in code, not saved as a .tres, because colours may only come from Palette and lit colours only
## exist as Palette.lit() results.
##
## FONTS. The font files in assets/fonts/ are fixed. Antialiasing, hinting and subpixel positioning are off for
## the two pixel fonts in their .ttf.import.
##
## OUTSIDE A CONTROL TREE. A theme passes down through Controls only. A Control whose parent is a Node2D gets
## Godot's default theme, and a _draw in a Node2D has no theme at all. Fx's coin pop-ups under the Arena are the
## known case. There, set `theme = UiTheme.build()` on the Control, or draw with numbers() and number_size().
##
## ponytail: only the controls the demo's screens use are styled. A VSlider, ScrollBar, LineEdit, TabBar or
## ItemList still shows Godot's default look; style it here when a screen first needs one.

const JERSEY := preload("res://assets/fonts/jersey10/Jersey10-Regular.ttf")
const SILKSCREEN := preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const CHAKRA := preload("res://assets/fonts/chakrapetch/ChakraPetch-Regular.ttf")
const CHAKRA_SEMI := preload("res://assets/fonts/chakrapetch/ChakraPetch-SemiBold.ttf")

const JERSEY_PIXEL := 56.0 / 3.0  ## Jersey 10 draws on a grid of 3/56 em: one font pixel per this many px of size
const SILKSCREEN_PIXEL := 8.0  ## Silkscreen draws on a grid of 1/8 em
const HIT := 44  ## art.md's hit target
const BUTTON_HEIGHT := 56
const BORDER := 2
const PULSE := 1.15  ## How far pulse() swells a control
const PULSE_TIME := 0.18  ## and for how long, in seconds

static var _theme: Theme


## The one Theme. It is built on the first call, and every later call returns the same object.
static func build() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_build(_theme)
	return _theme


## Jersey 10 as the theme uses it: the font of numbers, titles, big buttons and pop-ups.
static func numbers() -> Font:
	return JERSEY


## The font size to give numbers() for a size taken from art.md (36 for a pop-up, 68 for a HUD number): the
## nearest size at which every stem of the pixel font has the same width. The HUD and the pop-ups both go
## through this, so the same art.md size is the same size on screen.
static func number_size(px: int) -> int:
	return _pixel_size(px, JERSEY_PIXEL)


## A button icon: `shape` in a px x px box, drawn in the button's icon colour (so it greys out with the button).
static func icon(shape: UiGlyph.Shape, px := 16) -> UiGlyph:
	return UiGlyph.new(shape, Vector2(px, px))


## Lights a Label (or a Button's text) in `colour`: Palette.lit at LIT for text of 36 px and up, at LIT_TEXT
## under that (smaller text shows no halo at LIT). Use it for numbers that glow: time, combo, coins, prices.
static func light(control: Control, colour: Color) -> void:
	var type := control.theme_type_variation if control.theme_type_variation else StringName(control.get_class())
	var px := build().get_font_size(&"font_size", type) if build().has_font_size(&"font_size", type) else build().default_font_size
	control.add_theme_color_override(&"font_color", Palette.lit(colour, Palette.LIT if px >= 36 else Palette.LIT_TEXT))


## A quick swell on a control that has just changed: a HUD number, an upgrade node just bought. `anchor` is
## where across its width it grows from: 0 the left edge, 0.5 the middle, 1 the right edge.
static func pulse(control: Control, anchor := 0.5, by := PULSE) -> void:
	control.pivot_offset = control.size * Vector2(anchor, 0.5)
	control.scale = Vector2.ONE * by
	control.create_tween().tween_property(control, ^"scale", Vector2.ONE, PULSE_TIME)


## The menus' one selection (docs/art.md, "Selection") over a screen's list of `controls`: the mouse (hover takes
## the focus) or the arrows move the focus, and the focus is the selection, so none of them draws a focus outline
## or a hover look of its own. A plain Button among them is drawn primary while it has the focus and secondary
## otherwise. A toggle or a slider has no filled look; its screen points at the focused one (Settings' cursor).
static func selection(controls: Array) -> void:
	for c: Control in controls:
		c.mouse_entered.connect(c.grab_focus)
		c.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		if c.get_class() == "Button":
			c.focus_entered.connect(_fill.bind(controls))
	_fill(controls)


## Hover draws as the button's normal look, so a button the mouse left behind on a key press shows nothing.
static func _fill(controls: Array) -> void:
	for c: Control in controls:
		if c.get_class() == "Button":
			c.theme_type_variation = &"" if c.has_focus() else &"SecondaryButton"
			c.add_theme_stylebox_override(&"hover", c.get_theme_stylebox(&"normal"))


static func _pixel_size(px: int, unit: float) -> int:
	return roundi(maxi(1, roundi(px / unit)) * unit)


static func _box(fill: Color, border := Palette.CLEAR, margin_x := 0.0, margin_y := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.draw_center = fill.a > 0.0
	s.border_color = border
	s.set_border_width_all(BORDER if border.a > 0.0 else 0)
	s.anti_aliasing = false
	s.content_margin_left = margin_x
	s.content_margin_right = margin_x
	s.content_margin_top = margin_y
	s.content_margin_bottom = margin_y
	return s


static func _build(t: Theme) -> void:
	var tag := FontVariation.new()
	tag.base_font = SILKSCREEN
	tag.spacing_glyph = 2
	var small_tag := FontVariation.new()
	small_tag.base_font = SILKSCREEN
	small_tag.spacing_glyph = 1
	var empty := StyleBoxEmpty.new()
	var focus := _box(Palette.CLEAR, Palette.TEXT_DIM)
	focus.set_expand_margin_all(4)
	var none := UiGlyph.new()

	t.default_font = CHAKRA
	t.default_font_size = 16

	# Labels
	t.set_color(&"font_color", &"Label", Palette.TEXT)
	t.set_constant(&"line_spacing", &"Label", 22 - roundi(CHAKRA.get_height(16)))
	t.set_stylebox(&"normal", &"Label", empty)
	t.set_stylebox(&"focus", &"Label", empty)
	for v: Array in [
		[&"Hint", CHAKRA, 14, Palette.TEXT_DIM],
		[&"Name", CHAKRA_SEMI, 18, Palette.TEXT],
		[&"SmallName", CHAKRA_SEMI, 14, Palette.TEXT],
		[&"Tag", tag, _pixel_size(12, SILKSCREEN_PIXEL), Palette.TEXT_DIM],
		# art.md says 11, which rounds to 8: too small to read through the CRT. 16 is the next even size.
		[&"SmallTag", small_tag, _pixel_size(16, SILKSCREEN_PIXEL), Palette.TEXT_DIM],
		[&"Title", JERSEY, number_size(56), Palette.TEXT],
		[&"PanelTitle", JERSEY, number_size(46), Palette.TEXT],
		[&"Number", JERSEY, number_size(36), Palette.TEXT],
		[&"HudNumber", JERSEY, number_size(68), Palette.TEXT],
		[&"ComboNumber", JERSEY, number_size(84), Palette.TEXT],
	]:
		t.set_type_variation(v[0], &"Label")
		t.set_font(&"font", v[0], v[1])
		t.set_font_size(&"font_size", v[0], v[2])
		t.set_color(&"font_color", v[0], v[3])
		t.set_constant(&"line_spacing", v[0], 0)

	# Buttons. Each variation sets its own fills and colours; sizes and fonts come from Button.
	var px := number_size(36)
	var pad_y := (BUTTON_HEIGHT - JERSEY.get_height(px)) / 2.0
	t.set_font(&"font", &"Button", JERSEY)
	t.set_font_size(&"font_size", &"Button", px)
	t.set_constant(&"h_separation", &"Button", 12)
	t.set_stylebox(&"focus", &"Button", focus)
	_button(t, &"Button", Palette.BASE, [
		_box(Palette.lit(Palette.PLAYER, Palette.LIT_FILL), Palette.CLEAR, 24, pad_y),
		_box(Palette.lit(Palette.PLAYER, 3.0), Palette.CLEAR, 24, pad_y),
		_box(Palette.PLAYER, Palette.CLEAR, 24, pad_y),
		_box(Palette.WALL, Palette.CLEAR, 24, pad_y)])
	t.set_type_variation(&"SecondaryButton", &"Button")
	_button(t, &"SecondaryButton", Palette.TEXT, [
		_box(Palette.BASE, Palette.PLAYER, 24, pad_y),
		_box(Palette.PLAYER_DIM, Palette.PLAYER, 24, pad_y),
		_box(Palette.PLAYER, Palette.CLEAR, 24, pad_y),
		_box(Palette.WALL, Palette.CLEAR, 24, pad_y)], Palette.BASE)
	t.set_type_variation(&"CantAfford", &"Button")
	_button(t, &"CantAfford", Palette.TEXT, [
		_box(Palette.CLEAR, Palette.lit(Palette.DANGER), 24, pad_y),
		_box(Palette.DANGER_DIM, Palette.lit(Palette.DANGER), 24, pad_y),
		_box(Palette.DANGER_DIM, Palette.lit(Palette.DANGER), 24, pad_y),
		_box(Palette.WALL, Palette.CLEAR, 24, pad_y)])
	t.set_type_variation(&"IconButton", &"Button")
	var icon_pad := (HIT - 16) / 2.0
	_button(t, &"IconButton", Palette.TEXT, [
		_box(Palette.BASE, Palette.PLAYER, icon_pad, icon_pad),
		_box(Palette.PLAYER_DIM, Palette.PLAYER, icon_pad, icon_pad),
		_box(Palette.PLAYER, Palette.CLEAR, icon_pad, icon_pad),
		_box(Palette.BASE, Palette.BORDER, icon_pad, icon_pad)], Palette.BASE)

	# The toggle. Its square is the icon; the button itself draws nothing but its focus.
	var off := UiGlyph.new(UiGlyph.Shape.BOX, Vector2(HIT, HIT), Palette.PLAYER, Palette.BASE)
	var on := UiGlyph.new(UiGlyph.Shape.BOX, Vector2(HIT, HIT), Palette.lit(Palette.PLAYER), Palette.lit(Palette.PLAYER))
	var off_disabled := UiGlyph.new(UiGlyph.Shape.BOX, Vector2(HIT, HIT), Palette.BORDER, Palette.BASE)
	var on_disabled := UiGlyph.new(UiGlyph.Shape.BOX, Vector2(HIT, HIT), Palette.BORDER, Palette.BORDER)
	for type in [&"CheckBox", &"CheckButton"]:
		for s in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			t.set_stylebox(s, type, empty)
		t.set_stylebox(&"focus", type, focus)
		t.set_font(&"font", type, CHAKRA_SEMI)
		t.set_font_size(&"font_size", type, 18)
		t.set_constant(&"h_separation", type, 16)
		# No hover colour: in a menu's selection the mouse moves the focus, and the screen shows that.
		for c in [&"font_color", &"font_pressed_color", &"font_focus_color", &"font_hover_color", &"font_hover_pressed_color"]:
			t.set_color(c, type, Palette.TEXT)
		t.set_color(&"font_disabled_color", type, Palette.TEXT_DIM)
		for suffix in ["", "_mirrored"]:
			t.set_icon(&"checked" + suffix, type, on)
			t.set_icon(&"unchecked" + suffix, type, off)
			t.set_icon(&"checked_disabled" + suffix, type, on_disabled)
			t.set_icon(&"unchecked_disabled" + suffix, type, off_disabled)
		for s in [&"radio_checked", &"radio_unchecked", &"radio_checked_disabled", &"radio_unchecked_disabled"]:
			t.set_icon(s, type, t.get_icon(s.trim_prefix("radio_"), type))

	# The slider. The track's height is its stylebox's margins; the grabber's box sets the row's height.
	var track := _box(Palette.WALL, Palette.CLEAR, 0, 3)
	var filled := _box(Palette.lit(Palette.PLAYER), Palette.CLEAR, 0, 3)
	t.set_stylebox(&"slider", &"HSlider", track)
	t.set_stylebox(&"grabber_area", &"HSlider", filled)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", filled)
	t.set_icon(&"grabber", &"HSlider", UiGlyph.new(UiGlyph.Shape.GRABBER, Vector2(16, HIT), Palette.lit(Palette.PLAYER)))
	t.set_icon(&"grabber_highlight", &"HSlider", t.get_icon(&"grabber", &"HSlider"))  # no hover look, as on the toggle
	t.set_icon(&"grabber_disabled", &"HSlider", UiGlyph.new(UiGlyph.Shape.GRABBER, Vector2(16, HIT), Palette.BORDER))
	t.set_icon(&"tick", &"HSlider", none)

	# The dropdown: the SecondaryButton look, a chevron in the text colour, and a panel for its list.
	var row_y := (HIT - CHAKRA_SEMI.get_height(18)) / 2.0
	_button(t, &"OptionButton", Palette.TEXT, [
		_box(Palette.BASE, Palette.PLAYER, 16, row_y),
		_box(Palette.PLAYER_DIM, Palette.PLAYER, 16, row_y),
		_box(Palette.PLAYER, Palette.CLEAR, 16, row_y),
		_box(Palette.WALL, Palette.CLEAR, 16, row_y)], Palette.BASE)
	for s in [&"normal", &"hover", &"pressed", &"disabled"]:
		t.set_stylebox(s + "_mirrored", &"OptionButton", t.get_stylebox(s, &"OptionButton"))
	t.set_stylebox(&"focus", &"OptionButton", focus)
	t.set_font(&"font", &"OptionButton", CHAKRA_SEMI)
	t.set_font_size(&"font_size", &"OptionButton", 18)
	t.set_icon(&"arrow", &"OptionButton", icon(UiGlyph.Shape.DOWN))
	t.set_constant(&"modulate_arrow", &"OptionButton", 1)
	t.set_constant(&"arrow_margin", &"OptionButton", 16)
	t.set_constant(&"h_separation", &"OptionButton", 12)

	var panel := _box(Palette.PANEL, Palette.BORDER, 20, 20)
	var line := StyleBoxLine.new()
	line.color = Palette.BORDER
	line.thickness = BORDER
	t.set_stylebox(&"panel", &"PopupMenu", _box(Palette.PANEL, Palette.BORDER, 8, 8))
	t.set_stylebox(&"hover", &"PopupMenu", _box(Palette.PLAYER_DIM))
	for s in [&"separator", &"labeled_separator_left", &"labeled_separator_right"]:
		t.set_stylebox(s, &"PopupMenu", line)
	t.set_font(&"font", &"PopupMenu", CHAKRA)
	t.set_font_size(&"font_size", &"PopupMenu", 16)
	t.set_font(&"font_separator", &"PopupMenu", tag)
	t.set_font_size(&"font_separator_size", &"PopupMenu", _pixel_size(12, SILKSCREEN_PIXEL))
	t.set_constant(&"v_separation", &"PopupMenu", HIT - roundi(CHAKRA.get_height(16)))
	t.set_constant(&"item_start_padding", &"PopupMenu", 8)
	t.set_constant(&"item_end_padding", &"PopupMenu", 16)
	for c in [&"font_color", &"font_hover_color"]:
		t.set_color(c, &"PopupMenu", Palette.TEXT)
	for c in [&"font_disabled_color", &"font_accelerator_color", &"font_separator_color"]:
		t.set_color(c, &"PopupMenu", Palette.TEXT_DIM)
	var dot := UiGlyph.new(UiGlyph.Shape.DOT, Vector2(16, 16), Palette.PLAYER)
	var dot_disabled := UiGlyph.new(UiGlyph.Shape.DOT, Vector2(16, 16), Palette.BORDER)
	for s in [&"checked", &"radio_checked"]:
		t.set_icon(s, &"PopupMenu", dot)
		t.set_icon(s + "_disabled", &"PopupMenu", dot_disabled)
	for s in [&"unchecked", &"unchecked_disabled", &"radio_unchecked", &"radio_unchecked_disabled", &"search"]:
		t.set_icon(s, &"PopupMenu", none)
	t.set_icon(&"submenu", &"PopupMenu", UiGlyph.new(UiGlyph.Shape.NEXT, Vector2(16, 16), Palette.TEXT))
	t.set_icon(&"submenu_mirrored", &"PopupMenu", UiGlyph.new(UiGlyph.Shape.PREV, Vector2(16, 16), Palette.TEXT))

	# Panels and tooltips
	for type in [&"Panel", &"PanelContainer", &"PopupPanel"]:
		t.set_stylebox(&"panel", type, panel)
	t.set_type_variation(&"TooltipPanel", &"PopupPanel")
	t.set_stylebox(&"panel", &"TooltipPanel", _box(Palette.PANEL, Palette.BORDER, 10, 6))
	t.set_type_variation(&"TooltipLabel", &"Label")
	t.set_font(&"font", &"TooltipLabel", CHAKRA)
	t.set_font_size(&"font_size", &"TooltipLabel", 14)
	t.set_color(&"font_color", &"TooltipLabel", Palette.TEXT)


## One button look: its four styleboxes (normal, hover, pressed, disabled) and its text and icon colours, which
## are `ink` until it is disabled, and `pressed_ink` while it is held down if that is given.
static func _button(t: Theme, type: StringName, ink: Color, boxes: Array, pressed_ink := ink) -> void:
	for i in 4:
		t.set_stylebox([&"normal", &"hover", &"pressed", &"disabled"][i], type, boxes[i])
	for c in [&"font_color", &"font_hover_color", &"font_focus_color", &"icon_normal_color", &"icon_hover_color", &"icon_focus_color"]:
		t.set_color(c, type, ink)
	for c in [&"font_pressed_color", &"font_hover_pressed_color", &"icon_pressed_color", &"icon_hover_pressed_color"]:
		t.set_color(c, type, pressed_ink)
	t.set_color(&"font_disabled_color", type, Palette.TEXT_DIM)
	t.set_color(&"icon_disabled_color", type, Palette.TEXT_DIM)
