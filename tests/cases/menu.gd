extends RefCounted
## The main menu and Settings, driven through the real Main with the keyboard alone: focus starts on Play and
## shows, each button goes where it says, each setting reaches Settings, Main and the buses and survives a reload,
## a slider drag writes no more often than the slider steps, and Esc in Settings goes back one screen only.


func run(t: Node) -> void:
	var main: Main = (load("res://src/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	await t.tree().process_frame

	var menu := _screen(main)
	t.check(menu.scene_file_path == Main.MENU, "Main opens on the main menu")
	var play: Button = menu.get_node(^"%Play")
	t.check(play.has_focus(true), "focus starts on Play, and it shows")
	t.check(play.theme_type_variation == &"" and (menu.get_node(^"%Exit") as Button).theme_type_variation == &"SecondaryButton",
			"the focused button is the filled one")
	t.check(play.get_theme_stylebox(&"focus") is StyleBoxEmpty, "no outline: the fill shows the focus")
	(menu.get_node(^"%Settings") as Button).mouse_entered.emit()
	t.check((menu.get_node(^"%Settings") as Button).has_focus() and play.theme_type_variation == &"SecondaryButton",
			"the mouse moves the same selection as the arrows")
	play.grab_focus()
	t.check((menu.get_node(^"%Exit") as Button).pressed.is_connected(Main.quit), "Exit quits")
	t.check(not menu.find_children("*", "UiBackButton", true, false), "the main menu has no back button")

	_key(t, KEY_DOWN)
	_key(t, KEY_DOWN)
	t.check((menu.get_node(^"%Exit") as Control).has_focus(), "Down twice reaches Exit")
	_key(t, KEY_UP)
	t.check((menu.get_node(^"%Settings") as Control).has_focus(), "Up goes back to Settings")
	_key(t, KEY_ESCAPE)
	t.check(_screen(main) == menu, "Esc does nothing on the main menu")
	_key(t, KEY_ENTER)
	var settings := _screen(main)
	t.check(settings.scene_file_path == Main.SETTINGS, "Enter on Settings opens Settings")
	await t.tree().process_frame  # the containers lay out at the end of the frame, as before any player could press a key

	var crt: CheckBox = settings.get_node(^"%Crt")
	var calm: CheckBox = settings.get_node(^"%Calm")
	var music: HSlider = settings.get_node(^"%Music")
	var sound: HSlider = settings.get_node(^"%Sound")
	t.check(crt.button_pressed and not calm.button_pressed, "the toggles show the settings")
	t.check(is_equal_approx(music.value, 0.5) and is_equal_approx(sound.value, 0.5), "the sliders show the volumes")
	t.check(crt.has_focus(true), "focus starts on the CRT toggle")
	t.check([crt, calm, music, sound].all(func(c: Control) -> bool: return c.get_theme_stylebox(&"focus") is StyleBoxEmpty),
			"no outline in Settings: the cursor shows the selection")
	sound.mouse_entered.emit()
	t.check(sound.has_focus(), "the mouse moves Settings' selection, as on the main menu")
	crt.grab_focus()
	var shader := main.crt.material as ShaderMaterial
	t.check(shader.get_shader_parameter("enabled") == true, "the CRT is on by default")
	_key(t, KEY_ENTER)
	t.check(not Settings.crt, "Enter on the CRT toggle turns the CRT setting off")
	t.check(shader.get_shader_parameter("enabled") == false, "turning the CRT off switches Main's CRT pass off")
	_key(t, KEY_DOWN)
	_key(t, KEY_SPACE)
	t.check(Settings.reduce_flashing, "Space on Reduce flashing turns it on")
	_key(t, KEY_DOWN)
	t.check(music.has_focus(), "Down reaches the music slider")
	_key(t, KEY_RIGHT)
	t.check(is_equal_approx(Settings.music_volume, 0.55), "Right raises the music volume a step")
	_key(t, KEY_DOWN)
	_key(t, KEY_LEFT)
	_key(t, KEY_LEFT)
	t.check(is_equal_approx(Settings.sound_volume, 0.4), "Left lowers the sound volume a step at a time")
	t.check(is_equal_approx(_bus(Settings.BUS_MUSIC), 0.55), "the music volume reaches its bus")
	t.check(is_equal_approx(_bus(Settings.BUS_SOUND), 0.4), "the sound volume reaches its bus")

	var writes := [0]
	var count := func() -> void: writes[0] += 1
	Settings.changed.connect(count)
	for i in 1001:  # a slow drag from left to right, a thousand mouse moves
		music.value = i / 1000.0
	Settings.changed.disconnect(count)
	t.check(writes[0] <= 21, "a full drag writes the settings once per 5%% step at most, not %d times" % writes[0])
	t.check(is_equal_approx(Settings.music_volume, 1.0), "the drag ends at full volume")
	music.value = 0.55

	Settings.use(Settings.path)
	t.check(not Settings.crt and Settings.reduce_flashing, "the toggles survive a reload from the file")
	t.check(is_equal_approx(Settings.music_volume, 0.55) and is_equal_approx(Settings.sound_volume, 0.4),
			"the volumes survive a reload from the file")

	_key(t, KEY_ESCAPE)
	menu = _screen(main)
	t.check(menu.scene_file_path == Main.MENU, "Esc in Settings returns to the main menu")
	await t.tree().process_frame
	t.check(_screen(main) == menu, "and goes no further")
	t.check((menu.get_node(^"%Play") as Control).has_focus(true), "back on the menu, focus is on Play again")

	_key(t, KEY_DOWN)
	_key(t, KEY_ENTER)
	settings = _screen(main)
	(settings.find_children("*", "UiBackButton", true, false)[0] as Button).pressed.emit()
	t.check(_screen(main).scene_file_path == Main.MENU, "the back button returns to the main menu")

	_key(t, KEY_ENTER)
	var scene := _screen(main)
	t.check(scene.scene_file_path == Main.PLAY and scene.get_child(-1).get("level") == 1, "Play opens the highest level unlocked, level 1 on a fresh save")

	for file in ["main_menu.gd", "settings.gd", "cursor.gd"]:
		var code := FileAccess.get_file_as_string("res://src/menu/" + file)
		t.check(not code.contains("Sfx") and not code.contains("AudioServer"), "src/menu/%s plays no sound and sets no bus" % file)
	for file in ["main_menu.tscn", "settings.tscn"]:
		t.check(not FileAccess.get_file_as_string("res://src/menu/" + file).contains("theme_override_font"),
				"src/menu/%s overrides no font" % file)
	main.free()


func _screen(main: Main) -> Node:
	return main.screen.get_child(main.screen.get_child_count() - 1)


func _bus(bus: StringName) -> float:
	return AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus))


## Presses and releases `key`, through the window as a player would.
func _key(t: Node, key: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		t.get_viewport().push_input(e)
