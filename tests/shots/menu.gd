extends RefCounted
## The main menu and Settings: each screen with the CRT on and off, the cursor on other rows, and Settings with
## every value moved off its default. The menu does not read the save; the mid and maxed shots show it doesn't.


func shots() -> Array[Dictionary]:
	return [
		{"name": "menu"},
		{"name": "menu_flat", "crt": false},
		{"name": "menu_exit", "save": "maxed", "setup": _focus.bind(^"%Exit")},
		{"name": "settings", "setup": _settings},
		{"name": "settings_flat", "crt": false, "setup": _settings},
		{"name": "settings_moved", "save": "mid", "calm": true, "crt": false, "setup": _moved},
		{"name": "settings_slider", "setup": _slider},
	]


func _focus(main: Main, path: NodePath) -> void:
	(main.screen.get_child(0).get_node(path) as Control).grab_focus()


func _settings(_main: Main) -> void:
	Main.show_settings()


func _moved(_main: Main) -> void:
	Settings.music_volume = 0.2
	Settings.sound_volume = 1.0
	Main.show_settings()


## Focus on the sound slider, moved by the keyboard as a player would.
func _slider(main: Main) -> void:
	Main.show_settings()
	(main.screen.get_child(0).get_node(^"%Sound") as Control).grab_focus()
	for i in 3:
		var key := InputEventKey.new()
		key.keycode = KEY_LEFT
		key.pressed = true
		main.view.push_input(key)
		key = key.duplicate()
		key.pressed = false
		main.view.push_input(key)
