extends RefCounted
## The ui kit: the theme covers every control it claims to (no default stylebox or texture shows), the sizes
## art.md asks for, pixel-font sizes with even stems, and the widgets.

const VARIATIONS := [&"Hint", &"Name", &"SmallName", &"NodeName", &"Tag", &"SmallTag", &"Title", &"PanelTitle", &"Number",
		&"HudNumber", &"ComboNumber", &"SecondaryButton", &"CantAfford", &"IconButton", &"TooltipPanel", &"TooltipLabel"]


func run(t: Node) -> void:
	var theme := UiTheme.build()
	t.check(UiTheme.build() == theme, "build() returns the same Theme every call")
	for v in VARIATIONS:
		t.check(theme.get_type_variation_base(v) != &"", "the theme has the variation %s" % v)
	t.check(UiTheme.numbers() == UiTheme.JERSEY, "numbers() is Jersey 10")
	for pair in [[36, 37], [46, 37], [56, 56], [68, 75], [84, 93]]:
		t.check(UiTheme.number_size(pair[0]) == pair[1], "number_size(%d) is %d" % pair)
	_stems(t, theme)

	var root := Control.new()
	root.theme = theme
	t.add_child(root)
	var buttons := {}
	for v in [&"", &"SecondaryButton", &"CantAfford", &"IconButton"]:
		var b := Button.new()
		b.theme_type_variation = v
		if v == &"IconButton":
			b.icon = UiTheme.icon(UiGlyph.Shape.PREV)
		else:
			b.text = "PLAY"
		root.add_child(b)
		buttons[v] = b
	var check := CheckBox.new()
	check.text = "Screen shake"
	var slider := HSlider.new()
	var option := OptionButton.new()
	option.add_item("Windowed")
	var back := UiBackButton.new()
	var controls: Array[Node] = [check, CheckButton.new(), slider, option, PopupMenu.new(), Label.new(), Panel.new(),
			PanelContainer.new(), back]
	for c in controls:
		root.add_child(c)
	controls.append_array(buttons.values())
	controls.append(option.get_popup())
	_covered(t, controls)

	for v in [&"", &"SecondaryButton", &"CantAfford"]:
		t.check(buttons[v].get_combined_minimum_size().y == UiTheme.BUTTON_HEIGHT, "a %s button is 56 tall" % [v if v else &"primary"])
	for b: Button in [buttons[&"IconButton"], back]:
		t.check(b.get_combined_minimum_size() == Vector2(44, 44), "an icon button is 44 x 44")
	t.check(check.get_combined_minimum_size().y >= 44, "a toggle is at least 44 tall")
	t.check(slider.get_combined_minimum_size().y == 44, "a slider row is 44 tall")
	t.check(option.get_combined_minimum_size().y == 44, "a dropdown is 44 tall")
	t.check(back.shortcut == null and back.icon is UiGlyph, "the back button has an arrow and no shortcut")
	var fill: Color = theme.get_stylebox(&"normal", &"Button").bg_color
	t.check(maxf(fill.r, maxf(fill.g, fill.b)) > 1.0, "the primary button's fill is lit")
	for v in [&"Button", &"SecondaryButton", &"IconButton", &"OptionButton"]:
		t.check((theme.get_stylebox(&"pressed", v) as StyleBoxFlat).bg_color == Palette.PLAYER and theme.get_color(&"icon_pressed_color", v) == Palette.BASE
				and theme.get_color(&"font_hover_pressed_color", v) == Palette.BASE, "a pressed %s is plain unlit cyan with base-colour ink" % v)

	var price := UiPrice.new()
	price.amount = 1234
	root.add_child(price)
	var label: Label = price.get_child(1)
	t.check(label.text == "1234", "UiPrice shows its amount")
	t.check(label.get_theme_color(&"font_color").r > 1.0, "a UiPrice is lit gold")
	price.dim = true
	t.check(label.get_theme_color(&"font_color") == Palette.TEXT_DIM, "a dim UiPrice is secondary text")
	var pips := UiPips.new()
	pips.total = 3
	t.check(pips.custom_minimum_size == Vector2(32, 8), "three 8 px pips with 4 px gaps are 32 x 8")
	pips.free()
	root.free()

	for f in DirAccess.get_files_at("res://src/ui"):
		if f.ends_with(".gd"):
			var code := "\n".join(Array(FileAccess.get_file_as_string("res://src/ui/" + f).split("\n")).map(
					func(l: String) -> String: return l.get_slice("#", 0)))
			t.check(not code.contains("Sfx") and not code.contains("ui_cancel"), "src/ui/%s plays no sound and handles no Esc" % f)


## No control the theme claims shows a stylebox or a texture from Godot's default theme.
func _covered(t: Node, controls: Array[Node]) -> void:
	var default := ThemeDB.get_default_theme()
	for c in controls:
		var type := c.get_class()
		for n in default.get_stylebox_list(type):
			t.check(c.get_theme_stylebox(n) != default.get_stylebox(n, type), "%s %s is the game's stylebox" % [type, n])
		for n in default.get_icon_list(type):
			t.check(c.get_theme_icon(n) is UiGlyph, "%s %s is drawn as shapes" % [type, n])


## Every pixel-font size in the theme renders every stem the same width: each run of opaque pixels across a
## glyph, either way, is a whole number of font pixels.
func _stems(t: Node, theme: Theme) -> void:
	var ts := TextServerManager.get_primary_interface()
	for type in theme.get_font_size_type_list():
		if not theme.has_font(&"font", type):
			continue
		var font := theme.get_font(&"font", type)
		var base: Font = font.base_font if font is FontVariation else font
		var unit := UiTheme.JERSEY_PIXEL if base == UiTheme.JERSEY else UiTheme.SILKSCREEN_PIXEL if base == UiTheme.SILKSCREEN else 0.0
		if unit == 0.0:
			continue
		var px := theme.get_font_size(&"font_size", type)
		var p := roundi(px / unit)
		var rid: RID = base.get_rids()[0]
		var size := Vector2i(px, 0)
		var odd := 0
		for ch in "0123456789ABCDEFHIJKLMNPTUVXYZ":
			var g := ts.font_get_glyph_index(rid, px, ch.unicode_at(0), 0)
			ts.font_render_glyph(rid, size, g)
			var img := ts.font_get_texture_image(rid, size, ts.font_get_glyph_texture_idx(rid, size, g))
			var r := Rect2i(ts.font_get_glyph_uv_rect(rid, size, g))
			for across in [true, false]:
				for a in (range(r.position.y, r.end.y) if across else range(r.position.x, r.end.x)):
					var run := 0
					for b in (range(r.position.x, r.end.x + 1) if across else range(r.position.y, r.end.y + 1)):
						var at := Vector2i(b, a) if across else Vector2i(a, b)
						if (b < (r.end.x if across else r.end.y)) and img.get_pixelv(at).a > 0.5:
							run += 1
						elif run:
							odd += int(run % p != 0)
							run = 0
		t.check(odd == 0, "%s at %d px has even stems (%d odd runs)" % [type, px, odd])
