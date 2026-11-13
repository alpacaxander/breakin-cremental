extends RefCounted
## What the contracts promise before any lane has written a rule: the project is wired up, the stubs run, and the
## few things that are finished (geometry, upgrade costs, the palette's lit rule, navigation) are right.
## Everything here stays true once the lanes are done.


func run(t: Node) -> void:
	_project(t)
	_numbers(t)
	_geometry(t)
	_round(t)
	_palette(t)
	await _walk(t)


func _project(t: Node) -> void:
	for action: StringName in [&"paddle_up", &"paddle_down", &"rotate_cw", &"rotate_ccw"]:
		t.check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "the input map has %s" % action)
	for bus: StringName in [Settings.BUS_MUSIC, Settings.BUS_SOUND]:
		t.check(AudioServer.get_bus_index(bus) > 0, "the bus layout has a %s bus" % bus)
		t.check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == &"Master", "the %s bus feeds Master" % bus)
	t.check(AudioServer.get_bus_effect_count(0) == 1 and AudioServer.get_bus_effect(0, 0) is AudioEffectHardLimiter, "the master bus has a limiter")
	t.check(Engine.physics_ticks_per_second == 120, "the rules tick 120 times a second")
	t.check(OS.get_user_data_dir().begins_with(ProjectSettings.globalize_path("res://tests/out")), "this run's user:// is inside the checkout (use tests/run.sh)")
	for path: String in [Main.MENU, Main.SETTINGS, Main.PLAY, Play.HUB, Play.LEVEL]:
		t.check(ResourceLoader.exists(path), "the entry scene %s exists" % path)


func _numbers(t: Node) -> void:
	var base: Balance = load(Progress.BALANCE)
	t.check(base != null, "data/balance.tres is a Balance")
	for stat: StringName in [&"paddle_speed", &"paddle_size", &"ball_speed", &"round_time", &"blast_size", &"ball_size",
			&"boost_cap", &"shockwave_boost", &"paddle_thickness", &"paddle_max_angle", &"low_time", &"combo_window",
			&"combo_window_shrink", &"combo_window_min", &"coins_per_brick", &"rotate_step"]:
		t.check(base.base(stat) > 0.0, "balance.tres gives %s a value" % stat)
	t.check(base.combo_breaks_per_step > 0, "balance.tres gives combo_breaks_per_step a value")
	t.check(base.combo_rank == 0.0 and base.shockwave == 0.0, "combos and Shockwave start off")
	t.check(base.count(&"bumper") == 0, "a kind with no count has a count of 0")

	var copy := base.copy()
	copy.put(&"bumper_count", 2.0)
	copy.put(&"ball_speed", 1.0)
	t.check(copy.count(&"bumper") == 2 and copy.ball_speed == 1.0, "Balance.put sets a count and a property by name")
	t.check(base.count(&"bumper") == 0 and base.ball_speed > 1.0, "Balance.copy shares nothing with the original")

	t.check(Progress.coins == 0 and Progress.unlocked == 1, "a fresh save has 0 coins and level 1 unlocked")
	t.check(Progress.is_unlocked(1) and not Progress.is_unlocked(2), "a fresh save can play level 1 only")
	t.check(Progress.snapshot() != Progress.balance, "Progress.snapshot is a copy")

	var u := Upgrade.new()
	u.first_cost = 5
	t.check(range(5).map(u.cost) == [5, 9, 16, 29, 52], "Paddle Speed costs 5, 9, 16, 29, 52")
	u.first_cost = 20
	t.check(u.cost(2) == 65, "the third Explosive Brick costs 65")


func _geometry(t: Node) -> void:
	var base := Board.new()
	t.check(base.rows == 16 and base.cols == 64 and base.zoom() == 1.0, "the base board is 64 x 16 at zoom 1")
	t.check(base.cell_rect(Vector2i(53, 7)) == Rect2(848, 448, 16, 64), "a brick cell is 16 x 64 units")
	t.check(base.cell_at(Vector2(848, 448)) == Vector2i(53, 7) and base.cell_at(Vector2(847.9, 447.9)) == Vector2i(52, 6), "cell_at finds the brick cell under a point")
	t.check(base.has_cell(Vector2i(63, 7)) and not base.has_cell(Vector2i(64, 7)) and not base.has_cell(Vector2i(0, 8)), "the base board has 64 x 8 brick cells")
	t.check(base.field() == Rect2(-58, 0, 1082, 512), "the field runs from the open side to the back wall")
	for rows: int in [12, 16, 18, 24]:
		var b := Board.new(rows)
		t.check((b.size() * b.zoom()).is_equal_approx(Vector2(1024, 512)), "a %d-row grid is 1024 x 512 on screen" % rows)
		t.check(is_equal_approx(b.lane() * b.zoom(), Board.LANE_PX), "a %d-row level's paddle lane is 58 pixels on screen" % rows)


func _round(t: Node) -> void:
	var board := Board.new(18)
	board.bricks[Vector2i(10, 4)] = Brick.new(3)
	var placed := Brick.new()
	placed.placed = true
	board.bricks[Vector2i(11, 4)] = placed
	t.check(board.remaining() == 1, "a placed brick does not count toward a clear")

	var stats := Progress.snapshot()
	var round := Round.new(board, null, stats, 7)
	for i in 240:
		round.step(1.0 / 120.0, 0.0)
	t.check(round.board != board and round.board.brick(Vector2i(10, 4)) != board.brick(Vector2i(10, 4)), "a round plays on its own copy of the board")
	t.check(round.stats == stats and round.layout != null and round.paddle != null and round.combo != null and round.tally != null, "a round holds its stats, layout, paddle, combo and tally")
	t.check(Kinds.of(&"") == null and Kinds.of(&"no_such_kind") == null, "an unknown kind id gives null")
	t.check(Layout.from_data([]).to_data() == [], "an empty layout saves as an empty list")


func _palette(t: Node) -> void:
	for c: Color in [Palette.BASE, Palette.PANEL, Palette.WALL, Palette.BORDER, Palette.PADDLE, Palette.TEXT_DIM, Palette.TEXT]:
		var l := c.srgb_to_linear()
		t.check(maxf(l.r, maxf(l.g, l.b)) < 0.75, "the neutral %s is under the bloom threshold" % c.to_html(false))
	for meaning: StringName in Palette.MEANINGS:
		var l := Palette.lit(Palette.of(meaning)).srgb_to_linear()
		t.check(maxf(l.r, maxf(l.g, l.b)) > 0.75, "lit %s is over the bloom threshold" % meaning)
	t.check(Palette.lit(Palette.COINS, 1.0).is_equal_approx(Palette.COINS), "a boost of 1 leaves a colour as it is")
	t.check(Palette.hp(0) == Palette.HP[0] and Palette.hp(4) == Palette.HP[3] and Palette.hp(9) == Palette.HP[3], "HP 4 and up share the top colour step")
	t.check(Palette.brick(Brick.new(2)) == Palette.HP[1], "a plain brick's colour is its HP step")


## The game can be walked from the menu to a level and back through Main's navigation.
func _walk(t: Node) -> void:
	var main: Main = (load("res://src/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	var screen := func() -> Node: return main.screen.get_child(0)
	t.check(main.screen.get_child_count() == 1 and screen.call().scene_file_path == Main.MENU, "the game opens on the main menu")
	Main.show_settings()
	t.check(screen.call().scene_file_path == Main.SETTINGS, "show_settings opens Settings")
	Main.show_hub()
	var play := screen.call() as Play
	t.check(play != null and play._hub.scene_file_path == Play.HUB and play._hub.visible, "show_hub opens the hub")
	var hub := play._hub
	Main.show_level(1)
	t.check(screen.call() == play and play._hub == hub and not hub.visible, "show_level keeps the hub, hidden")
	t.check(play._level != null and play._level.scene_file_path == Play.LEVEL and play._level.get("level") == 1, "show_level opens the level scene with its number set")
	var level := play._level
	Main.show_hub()
	await t.tree().process_frame
	t.check(not is_instance_valid(level) and play._hub == hub and hub.visible, "show_hub frees the level and shows the same hub again")
	Main.set_bloom(1.0)
	t.check(is_equal_approx(main.env.glow_intensity, Main.GLOW_MAX), "set_bloom(1) raises the bloom to its ceiling")
	Settings.reduce_flashing = true
	t.check(is_equal_approx(main.env.glow_intensity, Main.GLOW_MAX_CALM), "reduce flashing caps the bloom")
	Settings.crt = false
	t.check(main.crt.material.get_shader_parameter("enabled") == false and main.crt.visible, "the CRT setting only switches the shader's flag")
	Main.show_menu()
	t.check(screen.call().scene_file_path == Main.MENU and is_equal_approx(main.env.glow_intensity, Main.GLOW), "changing screen puts the bloom back to rest")
	await _input(t, main)
	main.free()
	t.check(Main._it == null, "a freed Main is forgotten")


## Input reaches the game through Main, with the mouse moved the way the CRT curves the picture.
func _input(t: Node, main: Main) -> void:
	var at := Vector2(60, 40)  # a point on the screen, near a corner, where the curve moves things most
	t.check(main._warp(at) == at, "with the CRT off the mouse is where it is")
	Settings.crt = true
	t.check(main._warp(at).distance_to(at) > 2.0 and main._warp(Main.FRAME / 2) == Main.FRAME / 2, "with the CRT on the mouse is moved, except at the centre")
	var button := Button.new()
	button.size = Vector2(8, 8)
	button.position = main._warp(at) - button.size / 2
	main.screen.add_child(button)
	var presses := [0]
	button.pressed.connect(func() -> void: presses[0] += 1)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		t.get_viewport().push_input(click, true)  # not Input.parse_input_event: headless, the window is 64 x 64
		await t.tree().process_frame
		await t.tree().process_frame
	t.check(presses[0] == 1, "a click lands on the button drawn under it")
	for key: Key in [KEY_W, KEY_UP, KEY_S, KEY_DOWN, KEY_Q, KEY_E]:
		var press := InputEventKey.new()
		press.physical_keycode = key
		var action: StringName = {KEY_W: &"paddle_up", KEY_UP: &"paddle_up", KEY_S: &"paddle_down", KEY_DOWN: &"paddle_down", KEY_Q: &"rotate_ccw", KEY_E: &"rotate_cw"}[key]
		t.check(press.is_action(action), "%s is %s" % [OS.get_keycode_string(key), action])
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	t.check(wheel.is_action(&"rotate_cw"), "the wheel rotates too")
