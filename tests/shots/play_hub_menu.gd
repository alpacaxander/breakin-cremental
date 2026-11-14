extends RefCounted
## The play-test lane's pictures of the hub, the menu, Settings and the joins, each reached with real input events
## pushed into the window (clicks through the CRT's curve). The first five are the four defects the play test found,
## as they look now that they are fixed. A double click is what the OS reports: a second press marked `double_click`.

var _main: Main


func shots() -> Array[Dictionary]:
	return [
		{"name": "hub_fresh_first_look", "setup": _menu_play},
		{"name": "level_panel_bottom", "crt": false, "setup": _menu_play},
		{"name": "play_level_double_click", "setup": _double_play_level, "settle": 20},
		{"name": "menu_play_double_click", "setup": _double_menu_play},
		{"name": "settings_up_from_crt", "setup": _settings_up},
		{"name": "settings_crt_clicked_off", "setup": _settings_crt_click},
		{"name": "hub_after_clearing_level_1", "setup": _clear_level_1},
		{"name": "hub_hover_node_and_buy", "save": "mid", "crt": false, "setup": _hover},
		{"name": "hub_mid_combo_detail", "save": "mid", "crt": false, "setup": _select.bind(&"Combo")},
		{"name": "hub_maxed_coins", "save": "maxed", "crt": false, "setup": _rich},
	]


## The menu's Play clicked once.
func _menu_play(main: Main) -> void:
	_main = main
	await _laid_out()
	await _click(_screen().get_node("%Play"))


## Play clicked on the menu, then Play Level double-clicked: Setup, with Start under the pointer and not pressed.
func _double_play_level(main: Main) -> void:
	await _menu_play(main)
	var at := (_screen().get_node("Hub/Levels/%Play") as Control).get_global_rect().get_center()
	await _click_at(at)
	await _click_at(at, true)


## Play double-clicked on the menu: the hub, with the seed still selected and a node of the web under the pointer.
func _double_menu_play(main: Main) -> void:
	_main = main
	await _laid_out()
	var at := (_screen().get_node("%Play") as Control).get_global_rect().get_center()
	await _click_at(at)
	await _click_at(at, true)


## Settings by keyboard from the menu, then Up from the CRT toggle: the focus and its cursor stay on the toggle.
func _settings_up(main: Main) -> void:
	_main = main
	await _laid_out()
	for key: Key in [KEY_DOWN, KEY_ENTER]:
		_key(key)
		await main.get_tree().process_frame
	await main.get_tree().process_frame
	_key(KEY_UP)


func _settings_crt_click(main: Main) -> void:
	_main = main
	await _laid_out()
	Main.show_settings()
	await main.get_tree().process_frame
	await _click(_screen().get_node("%Crt"))


## Level 1 from the hub, every brick broken through the rules, then Upgrades on the Summary.
func _clear_level_1(main: Main) -> void:
	await _menu_play(main)
	await _click(_screen().get_node("Hub/Levels/%Play"))
	var level := _screen().get_child(-1) as Control
	level.start(1)
	var round: Round = level.round
	for cell: Vector2i in round.board.bricks.keys():
		while round.board.brick(cell):
			round.hit_brick(cell, Round.Cause.BALL, Vector2.RIGHT)
	# The round ends on its next step, and the panel shows half a second after that.
	var upgrades: Control
	while upgrades == null or not upgrades.is_visible_in_tree():
		await main.get_tree().process_frame
		upgrades = level.get_node("Summary").find_child("Upgrades", true, false) as Control
	await _laid_out()
	await _click(upgrades)


## The mouse resting over a node, then over Buy.
func _hover(main: Main) -> void:
	_main = main
	await _laid_out()
	Main.show_hub()
	await main.get_tree().process_frame
	var hub := _screen().get_node("Hub")
	await _click(hub.get_node("Web/Bumper"))
	_mouse((hub.get_node("Detail/%Buy") as Control).get_global_rect().get_center())


func _select(main: Main, node: StringName) -> void:
	_main = main
	await _laid_out()
	Main.show_hub()
	await main.get_tree().process_frame
	await _click(_screen().get_node("Hub/Web/" + String(node)))


func _rich(main: Main) -> void:
	_main = main
	await _laid_out()
	Progress.coins = 250000
	Main.show_hub()


## The harness calls a setup on the frame the menu is made, before its containers lay out: a click then lands on
## the wrong button (Exit, which quits). Two frames, as before any player could click.
func _laid_out() -> void:
	for i in 2:
		await _main.get_tree().process_frame


func _screen() -> Node:
	return _main.screen.get_child(0)


func _at(target: Vector2) -> Vector2:
	var p := target
	for i in 8:
		p += target - _main._warp(p)
	return p


func _click(control: Control) -> void:
	await _click_at(control.get_global_rect().get_center())


## `second` makes it the second click of a double click.
func _click_at(at: Vector2, second := false) -> void:
	_mouse(at)
	for pressed: bool in [true, false]:
		_mouse(at, MOUSE_BUTTON_LEFT, pressed, second and pressed)
		await _main.get_tree().process_frame


func _mouse(at: Vector2, button := MOUSE_BUTTON_NONE, pressed := false, double := false) -> void:
	var event: InputEventMouse
	if button == MOUSE_BUTTON_NONE:
		event = InputEventMouseMotion.new()
	else:
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = pressed
		click.double_click = double
		event = click
	event.position = _at(at)
	event.global_position = event.position
	_main.get_viewport().push_input(event, true)


func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		_main.get_viewport().push_input(event, true)
