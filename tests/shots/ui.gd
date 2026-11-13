extends RefCounted
## The ui kit's sheet: every type variation and widget, every button in each state, on one screen. Compare it
## with docs/art.md ("Type", "UI pieces") after changing src/ui/theme.gd. Hover and pressed are faked by giving
## a button the theme's hover or pressed stylebox as its normal one.


func shots() -> Array[Dictionary]:
	return [
		{"name": "ui_sheet", "crt": false, "setup": _sheet},
		{"name": "ui_sheet_crt", "setup": _sheet},
		{"name": "ui_popup", "crt": false, "setup": _popup},
		{"name": "ui_tooltip", "crt": false, "setup": _tooltip, "settle": 60},
	]


func _sheet(main: Main) -> Control:
	for child in main.screen.get_children():
		child.free()
	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		page.add_theme_constant_override("margin_" + side, 32)
	main.screen.add_child(page)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	page.add_child(rows)

	var row := _row(rows)
	_label(row, "Title", "UPGRADES")
	_label(row, "PanelTitle", "LEVEL 1")
	UiTheme.light(_label(row, "Number", "+120"), Palette.COINS)
	UiTheme.light(_label(row, "HudNumber", "0:20"), Palette.TIME)
	UiTheme.light(_label(row, "ComboNumber", "x12"), Palette.COINS)
	var price := UiPrice.new()
	price.amount = 1234
	row.add_child(price)

	row = _row(rows)
	_label(row, "Tag", "COINS")
	_label(row, "SmallTag", "RANK 2/3")
	_label(row, "Name", "Ball Speed")
	_label(row, "SmallName", "Booster")
	_label(row, "", "Body text: the ball moves\n10% faster per rank.")
	_label(row, "Hint", "Esc goes back")

	row = _row(rows)
	_button(row, "", "PLAY", "")
	_button(row, "", "PLAY", "hover")
	_button(row, "", "PLAY", "pressed")
	_button(row, "", "PLAY", "disabled")
	_button(row, "", "PLAY", "focus")
	var start := _button(row, "", "START", "")
	start.icon = UiTheme.icon(UiGlyph.Shape.PLAY, 18)
	start.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	row = _row(rows)
	_button(row, "SecondaryButton", "RETRY", "")
	_button(row, "SecondaryButton", "RETRY", "hover")
	_button(row, "SecondaryButton", "RETRY", "disabled")
	_button(row, "CantAfford", "BUY", "")
	_button(row, "CantAfford", "BUY", "hover")
	var option := OptionButton.new()
	for item in ["Windowed", "Fullscreen", "Borderless"]:
		option.add_item(item)
	row.add_child(option)

	row = _row(rows)
	row.add_child(UiBackButton.new())
	for shape in [UiGlyph.Shape.PREV, UiGlyph.Shape.NEXT, UiGlyph.Shape.PLUS, UiGlyph.Shape.MINUS]:
		_button(row, "IconButton", "", "").icon = UiTheme.icon(shape)
	_button(row, "IconButton", "", "hover").icon = UiTheme.icon(UiGlyph.Shape.NEXT)
	_button(row, "IconButton", "", "disabled").icon = UiTheme.icon(UiGlyph.Shape.NEXT)
	for state in [[false, false], [true, false], [false, true], [true, true]]:
		var toggle := CheckBox.new()
		toggle.text = "Shake"
		toggle.button_pressed = state[0]
		toggle.disabled = state[1]
		row.add_child(toggle)

	var panel := PanelContainer.new()
	rows.add_child(panel)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	for disabled in [false, true]:
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 180
		slider.value = 60
		slider.editable = not disabled
		row.add_child(slider)
	for dim in [false, true]:
		var p := UiPrice.new()
		p.style = &"SmallTag"
		p.amount = 40
		p.dim = dim
		row.add_child(p)
	var big := UiPrice.new()
	big.style = &"Number"
	big.amount = 250
	row.add_child(big)
	for pips: Array in [[3, 1, &"player", 8, 4, false], [5, 3, &"bricks", 16, 6, false], [3, 3, &"placeable", 8, 4, true]]:
		var u := UiPips.new()
		u.total = pips[0]
		u.owned = pips[1]
		u.meaning = pips[2]
		u.side = pips[3]
		u.gap = pips[4]
		u.on_lit = pips[5]
		row.add_child(u)

	row = _row(rows)
	for bar: Array in [[&"time", 0.7, 220], [&"coins", 0.4, 160]]:
		var b := UiBar.new()
		b.meaning = bar[0]
		b.value = bar[1]
		b.custom_minimum_size.x = bar[2]
		row.add_child(b)
	var tip := PanelContainer.new()
	tip.theme_type_variation = &"TooltipPanel"
	var tip_text := Label.new()
	tip_text.theme_type_variation = &"TooltipLabel"
	tip_text.text = "A tooltip, styled"
	tip.add_child(tip_text)
	row.add_child(tip)
	var coin := UiCoin.new()
	coin.side = 18
	row.add_child(coin)
	return page


func _popup(main: Main) -> void:
	var page := _sheet(main)
	await main.get_tree().process_frame
	var option: OptionButton = page.find_children("*", "OptionButton", true, false)[0]
	option.select(1)
	option.show_popup()


func _tooltip(main: Main) -> void:
	var page := _sheet(main)
	await main.get_tree().process_frame
	var back: Button = page.find_children("*", "Button", true, false).filter(func(n: Node) -> bool: return n is UiBackButton)[0]
	var move := InputEventMouseMotion.new()
	move.position = back.get_global_rect().get_center()
	move.global_position = move.position
	# View shows no tooltip until it is told the mouse is in it; main.gd does not tell it yet.
	main.view.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	main.view.push_input(move, true)


func _row(rows: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	rows.add_child(row)
	return row


func _label(row: Control, variation: StringName, text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.text = text
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return l


## A button in `state`: "", "hover", "pressed" or "disabled" (the theme's stylebox of that name shown as its
## normal one), or "focus" (focused).
func _button(row: Control, variation: StringName, text: String, state: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	b.text = text
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	match state:
		"disabled":
			b.disabled = true
		"focus":
			b.grab_focus.call_deferred()
		"hover", "pressed":
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox(state))
	return b
