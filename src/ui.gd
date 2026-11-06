## Menu screens: a full-screen backdrop with a centered column of controls. Look comes from src/theme.tres.
extends Node

const Tuning = preload("res://src/tuning.gd")


class Screen extends ColorRect:
	signal back  # Esc

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			back.emit()


## rows: Controls stacked under the title. dim: translucent, for overlays on a paused arena.
static func screen(title: String, rows: Array, dim := false) -> Screen:
	var s := Screen.new()
	s.color = Color(Tuning.COLORS.bg, 0.8 if dim else 1.0)
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.size = Tuning.VIEW  # anchors are no-ops under a Node2D parent (the arena)
	s.process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working over a paused tree
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 48)
	t.add_theme_color_override("font_color", Tuning.COLORS.combo)
	box.add_child(t)
	for r in rows:
		box.add_child(r)
	s.add_child(box)
	return s


static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 48)
	b.pressed.connect(on_press)
	return b


static func settings(back: Callable) -> Screen:
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Game.settings.fullscreen
	fs.toggled.connect(func(on): Game.set_setting("fullscreen", on))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = "Volume"
	var vol := HSlider.new()
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Game.settings.volume
	vol.custom_minimum_size.x = 200
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol.value_changed.connect(func(v): Game.set_setting("volume", v))
	row.add_child(l)
	row.add_child(vol)
	var s := screen("Settings", [fs, row, button("Back", back)])
	s.back.connect(back)
	return s
