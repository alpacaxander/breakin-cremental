extends RefCounted
## What the contracts promise before any lane has written a rule: the project is wired up, the stubs run, and the
## few things that are finished (geometry, upgrade costs, the palette's lit rule, navigation) are right.
## Everything here stays true once the lanes are done.
##
## ACROSS THE LANES (_across and what it calls): the things two or three lanes typed by hand and that fail
## without a word in the game. A kind's cue that names no sound is silence, an upgrade whose stat is misspelt is
## bought and does nothing, a kind no upgrade counts can never be placed. They are checked here against the
## real files, on the real levels, through the real save.


func run(t: Node) -> void:
	_project(t)
	_numbers(t)
	_geometry(t)
	_round(t)
	_palette(t)
	await _walk(t)
	await _across(t)  # last: it owns every upgrade and saves layouts


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
	Progress.level_count = 99
	Progress.use(Progress.path)
	t.check(Progress.level_count == Levels.count(), "Progress.use puts the level count back")

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
	var kind := BrickKind.new()
	kind.id = &"made_in_a_test"
	Kinds.add(kind)
	t.check(Kinds.of(&"made_in_a_test") == kind and kind in Kinds.bricks(), "Kinds.add makes a kind findable")
	Kinds.reset()
	t.check(Kinds.of(&"made_in_a_test") == null, "Kinds.reset forgets a kind that has no file")
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
	var level := Main.show_level(1)
	t.check(screen.call() == play and play._hub == hub and not hub.visible, "show_level keeps the hub, hidden")
	t.check(level != null and level == play._level and level.scene_file_path == Play.LEVEL and level.get("level") == 1, "show_level opens the level scene with its number set, and returns it")
	t.check(main.screen.theme == UiTheme.build(), "the screens carry the one theme")
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
	# A tooltip: View is fed by Main alone, and shows none unless Main has told it the pointer is over it.
	button.tooltip_text = "Tip"
	var hover := InputEventMouseMotion.new()
	hover.position = at
	hover.global_position = at
	t.get_viewport().push_input(hover, true)
	await t.tree().create_timer(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec") + 0.3).timeout
	var tips := main.view.find_children("*", "PopupPanel", true, false).filter(func(p: Node) -> bool: return (p as Window).visible)
	t.check(tips.size() == 1, "hovering a control shows its tooltip")
	# Godot spends the first key pressed while a tooltip shows on closing the tooltip: no screen gets that key.
	var behind_tip := EscListener.new()
	main.screen.add_child(behind_tip)
	var first := InputEventKey.new()
	first.keycode = KEY_ESCAPE
	first.pressed = true
	t.get_viewport().push_input(first, true)
	await t.tree().process_frame
	t.check(behind_tip.heard == 0 and main.view.find_children("*", "PopupPanel", true, false).is_empty(), "a key pressed while a tooltip shows closes the tooltip and goes no further")
	behind_tip.free()
	for key: Key in [KEY_W, KEY_UP, KEY_S, KEY_DOWN, KEY_Q, KEY_E]:
		var press := InputEventKey.new()
		press.physical_keycode = key
		var action: StringName = {KEY_W: &"paddle_up", KEY_UP: &"paddle_up", KEY_S: &"paddle_down", KEY_DOWN: &"paddle_down", KEY_Q: &"rotate_ccw", KEY_E: &"rotate_cw"}[key]
		t.check(press.is_action(action), "%s is %s" % [OS.get_keycode_string(key), action])
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	t.check(wheel.is_action(&"rotate_cw"), "the wheel rotates too")
	# Back (see main.gd): Esc reaches a screen's _unhandled_input, and a handled Esc stops at the first screen.
	var behind := EscListener.new()
	var front := EscListener.new()
	main.screen.add_child(behind)
	main.screen.add_child(front)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	t.get_viewport().push_input(esc, true)
	t.check(front.heard == 1 and behind.heard == 0, "Esc reaches the screen in front as ui_cancel, and stops there once it is handled")


class EscListener:
	extends Node
	var heard := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_cancel"):
			heard += 1
			get_viewport().set_input_as_handled()


func _across(t: Node) -> void:
	_names(t)
	_snapshot(t)
	await _levels(t)


## Ids and names one lane wrote and another reads: cues (kinds -> Sfx), colours (kinds -> Palette), stats
## (upgrades -> Balance and the kinds).
func _names(t: Node) -> void:
	var cues: Array[StringName] = []
	var constants := (Sfx.get_script() as GDScript).get_script_constant_map()
	for constant: String in constants:
		if constants[constant] is StringName and constant != "QUIET":
			cues.append(constants[constant])
			t.check(ResourceLoader.exists(Sfx.DIR.path_join("%s.wav" % constants[constant])), "Sfx.%s has a wav file" % constant)
	t.check(not Kinds.bricks().is_empty() and not Kinds.placeables().is_empty(), "data/kinds holds special bricks and placeables")
	for kind in Kinds.all():
		t.check(kind.cue == &"" or kind.cue in cues, "the %s kind's cue, \"%s\", is a cue Sfx has" % [kind.id, kind.cue])
		t.check(Palette.MEANINGS.has(kind.colour), "the %s kind's colour, \"%s\", is a Palette meaning" % [kind.id, kind.colour])
		t.check(kind.title != "", "the %s kind has a title" % kind.id)

	var counted: Array[StringName] = []
	t.check(not Progress.upgrades().is_empty(), "data/upgrades holds upgrades")
	for u in Progress.upgrades():
		t.check(Palette.MEANINGS.has(u.meaning()), "the %s upgrade's category has a Palette meaning" % u.id)
		if Progress.balance.get(u.stat) is float:
			continue
		var kind_id := StringName(String(u.stat).trim_suffix("_count"))
		t.check(String(u.stat).ends_with("_count") and Kinds.of(kind_id) != null,
				"the %s upgrade's stat, \"%s\", is a Balance property or the count of a kind that exists" % [u.id, u.stat])
		counted.append(kind_id)
	for kind in Kinds.all():
		t.check(kind.id in counted, "an upgrade raises %s, or nobody can ever have a %s" % [Balance.count_stat(kind.id), kind.title])


## With every upgrade owned, Progress.snapshot() hands a round each number it reads, moved off its base.
func _snapshot(t: Node) -> void:
	_own_everything()
	var stats := Progress.snapshot()
	for u in Progress.upgrades():
		t.check(stats.base(u.stat) > Progress.balance.base(u.stat) and is_equal_approx(stats.base(u.stat), Progress.stat(u.stat)),
				"owning %s raises %s in the snapshot" % [u.id, u.stat])
	var round := Round.new(Levels.read(1).board, null, stats, 1)
	t.check(round.paddle.length == stats.paddle_size and round.time_left == stats.round_time
			and is_equal_approx(round.speed_of(round.balls[0]), stats.ball_speed), "a round takes its paddle, timer and ball speed from the snapshot")
	for kind in Kinds.bricks():
		var n := round.board.bricks.values().filter(func(b: Brick) -> bool: return b.kind == kind.id).size()
		t.check(n == stats.count(kind.id) and n > 0, "a round rolls as many %s bricks as the snapshot counts (%d, and %d rolled)" % [kind.id, stats.count(kind.id), n])
	var plain: Array = round.board.bricks.keys().filter(func(c: Vector2i) -> bool: return round.board.brick(c).kind == &"" and round.board.brick(c).hp == 1)
	round.hit_brick(plain[0], Round.Cause.ZAP, Vector2.RIGHT)
	t.check(round.combo.count == 1 and round.combo.window > Progress.balance.combo_window, "the snapshot turns combos on and widens the window")
	Progress.reset()


## Every level plays: its board builds a round that steps to an end on a fresh save, and again with every upgrade
## owned and one of each placeable on it, placed through Layout.fits and brought back through the save file.
func _levels(t: Node) -> void:
	t.check(Levels.count() > 0, "there are levels")
	for n in range(1, Levels.count() + 1):
		var level := Levels.read(n)
		var fresh := Progress.snapshot()
		# The lane is 58 screen pixels at every size, but the paddle and the ball keep their size in units, so a
		# small level has no room for them: with the shipped numbers a level needs 14 rows.
		t.check(level.board.lane() - fresh.paddle_inset - fresh.paddle_thickness >= fresh.ball_size, "level %d is big enough for a ball to pass between the paddle and the grid" % n)
		var path := Round.launch_path(level.board, fresh)
		for cell: Vector2i in level.board.bricks:
			if level.board.cell_rect(cell).intersects(path):
				t.check(false, "level %d has no brick where the ball rests or between it and the paddle (%s)" % [n, cell])
		await _play(t, "level %d on a fresh save" % n, Round.new(level.board, null, fresh, n), false)

		_own_everything()
		var stats := Progress.snapshot()
		var layout := Layout.new()
		for kind in Kinds.placeables():
			var item := _place(kind, layout, level.board, stats)
			t.check(item != null, "a %s has somewhere to go on level %d" % [kind.title, n])
			if item:
				layout.add(item)
		Progress.set_layout(n, layout)
		Progress.use(Progress.path)  # from the file: the ranks and the layout have been through JSON
		var back := Progress.layout(n)
		t.check(back.to_data() == layout.to_data() and not layout.items.is_empty(), "level %d's layout comes back from the save as it went in" % n)
		stats = Progress.snapshot()
		var round := Round.new(level.board, back, stats, n)
		t.check(round.layout.items.size() == layout.items.size(), "every saved item still fits level %d after the trip (%d of %d)" % [n, round.layout.items.size(), layout.items.size()])
		await _play(t, "level %d with every upgrade and one of each placeable" % n, round, true)
		Progress.reset()
		Progress.save()


## Steps a round to its end with a paddle that follows the ball nearest to it, a little off centre, and checks
## that it ended, that the ball reached the bricks and that the coins are the formula's. With `sound`, Sfx is
## wired to it as the level screen will wire it, and must be heard.
func _play(t: Node, what: String, round: Round, sound: bool) -> void:
	var heard: Array[StringName] = []
	var listen := func(cue: StringName, _player: AudioStreamPlayer) -> void: heard.append(cue)
	if sound:
		# The whole round is stepped within a few milliseconds, and Sfx spaces a cue's voices in real time: wait
		# out what the round before queued, or this round's first sounds are dropped as part of that burst.
		await t.tree().create_timer(0.15).timeout
		Sfx.played.connect(listen)
		Sfx.connect_round(round)
	var touched := [0]
	round.brick_hit.connect(func(_cell: Vector2i, _hp: int, _cause: Round.Cause) -> void: touched[0] += 1)
	round.brick_broken.connect(func(_cell: Vector2i, _brick: Brick, _cause: Round.Cause, _dir: Vector2, _coins: int) -> void: touched[0] += 1)
	var steps := 0
	while not round.over and steps < 120 * 120:  # two minutes: hourglass bricks add time, but not that much
		var target := round.paddle.y
		var nearest := INF
		for ball in round.balls:
			if ball.pos.x < nearest:
				nearest = ball.pos.x
				target = ball.pos.y + round.paddle.length * 0.3
		round.step(1.0 / 120.0, target)
		steps += 1
	t.check(round.over, "%s: the round ends" % what)
	t.check(touched[0] > 0, "%s: the ball reaches a brick" % what)
	t.check(round.coins == Coins.total(round.tally, round.stats), "%s: the coins are the formula's" % what)
	if sound:
		await t.tree().create_timer(0.15).timeout  # the voices Sfx queued have started by now
		Sfx.played.disconnect(listen)
		# Not always the paddle: the first free cell for the Splitter can be right in front of the resting ball.
		t.check(Sfx.ROUND_START in heard and (Sfx.PADDLE_HIT in heard or Sfx.WALL_BOUNCE in heard) and (Sfx.BRICK_HIT in heard or Sfx.BRICK_BREAK in heard),
				"%s: Sfx plays the round: its start, a bounce and a brick (heard %s)" % [what, heard])
	var broken: int = round.tally.broken.values().reduce(func(a: int, b: int) -> int: return a + b, 0)
	print("   contracts: %s: %s after %.1f s, %d bricks broken, %d coins" % [what, Round.End.find_key(round.reason), steps / 120.0, broken, round.coins])


## A place where one more `kind` fits on the layout, found by trying: the first spot of a 16-unit raster for a
## free-form item (upright, or lying down if it only fits that way), the first empty cell for a placed brick,
## the first brick for a mod. Null if there is none.
func _place(kind: PlaceableKind, layout: Layout, board: Board, stats: Balance) -> Layout.Item:
	var item := Layout.Item.new()
	item.kind = kind
	if kind.placement == PlaceableKind.Placement.FREE:
		for rot: float in [0.0, 90.0] if kind.rotatable else [0.0]:
			item.rot = rot
			for x in range(8, int(board.size().x), 16):
				for y in range(8, int(board.size().y), 16):
					item.pos = Vector2(x, y)
					if layout.fits(item, board, stats):
						return item
		return null
	for x in board.cols:
		@warning_ignore("integer_division")
		for y in board.rows / 2:
			item.cell = Vector2i(x, y)
			if layout.fits(item, board, stats):
				return item
	return null


## Every upgrade at its top rank, saved.
func _own_everything() -> void:
	for u in Progress.upgrades():
		Progress.ranks[u.id] = u.max_rank
	Progress.save()
