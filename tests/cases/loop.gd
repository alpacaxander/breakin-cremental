extends RefCounted
## The whole game in one walk, through the real Main and with real input events only: the menu, Play into level
## 1's Setup, Esc to the hub on a fresh save, a level with nothing placed, a round to its end, the Summary, Upgrades, buying, the level
## again with an item placed, Retry, back to the hub, back to the menu, Settings, the CRT toggle, back. After
## each step it checks which screen is showing and what the save file holds.
##
## The CRT is on, as it is for a new player, so every click goes through Main's warp: a control is clicked at the
## window point the curved picture shows it under (_at). The two rounds are played by a mouse that follows the
## ball, with Engine.time_scale raised so 20 seconds of play take about two.

const SETUP := 0
const PLAY := 1
const SUMMARY := 2
const FAST := 10.0  ## Engine.time_scale while a round is played
const SPLITTER_AT := Vector2(300, 100)  ## Round units on level 1, in a brick cell clear of the bricks and the lane

var t: Node
var main: Main
var heard: Array[StringName] = []


func run(p_t: Node) -> void:
	t = p_t
	main = (load("res://src/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	var on_played := func(cue: StringName, _player: AudioStreamPlayer) -> void: heard.append(cue)
	Sfx.played.connect(on_played)
	await t.tree().process_frame
	await _walk()
	Engine.time_scale = 1.0
	Sfx.played.disconnect(on_played)
	main.free()


func _walk() -> void:
	# The menu, then Play: level 1's Setup on a fresh save, and Esc to the hub.
	t.check(_screen().scene_file_path == Main.MENU, "the game opens on the main menu")
	_key(KEY_ENTER)
	await t.tree().process_frame
	await t.tree().process_frame
	var play := _screen() as Play
	t.check(play != null and play.get_child(-1).get("level") == 1 and play.get_child(-1).get("phase") == SETUP,
			"Enter on Play opens level 1 in Setup")
	if play == null:
		return
	_key(KEY_ESCAPE)
	await t.tree().process_frame
	var hub: Control = play.get_node("Hub")
	var web: HubWeb = hub.get_node("Web")
	var buy: Button = hub.get_node("Detail/%Buy")
	var levels: Control = hub.get_node("Levels")
	var counter: UiPrice = hub.get_node("Bar/Coins")
	t.check(hub.is_visible_in_tree() and counter.amount == 0 and Progress.unlocked == 1, "a fresh save: the hub, no coins, level 1")
	var open := web.nodes().filter(func(n: HubNode) -> bool: return web.state(n) == HubNode.State.AVAILABLE)
	t.check(open.size() == 1 and open[0] == web.seed_node() and buy.theme_type_variation == &"CantAfford", "only the seed is open, and it can't be afforded yet")
	t.check(levels.level == 1 and not (levels.get_node("%Play") as Button).disabled, "the level panel offers level 1")

	# Into level 1. Nothing to place, so Start at once, and play the round out.
	await _click(levels.get_node("%Play"))
	var level := play.get_child(-1) as Control
	t.check(level != hub and not hub.visible and level.get("level") == 1 and level.get("phase") == SETUP, "Play Level opens level 1 in Setup, and the hub is hidden")
	if level == hub:
		return
	var setup: LevelSetupUi = level.get_node("SetupUi")
	t.check(setup._slots.is_empty() and level.round.layout.items.is_empty(), "a fresh save has nothing to place")
	heard.clear()
	await _click(setup.find_child("Start", true, false))
	t.check(level.phase == PLAY and not setup.visible, "Start begins the round")
	await _play_out(level)
	t.check(level.phase == SUMMARY and level.round.over, "the round runs to its end and the Summary takes over")
	t.check(heard.has(Sfx.ROUND_START) and heard.has(Sfx.PADDLE_HIT), "the round was heard: its start and the paddle (heard %s)" % [heard])
	var earned: int = level.round.coins
	t.check(Progress.coins == earned and _saved().coins == earned and _saved().unlocked == Progress.unlocked, "the round is paid once and saved (%d coins)" % earned)
	var summary: Control = level.get_node("Summary")
	var how := "LEVEL CLEARED" if level.round.tally.cleared else "TIME UP" if level.round.reason == Round.End.TIME else "BALL LOST" if level.round.reason == Round.End.BALL_LOST else "BOARD EMPTY"
	t.check(summary.is_visible_in_tree() and _texts(summary).has(how), "the Summary says how it ended (%s)" % how)

	# Upgrades: the hub again, with the coins. Buy the seed, then the Splitter, with coins given for the test.
	await _click(summary.find_child("Upgrades", true, false))
	await t.tree().process_frame
	t.check(_screen() == play and hub.is_visible_in_tree() and not is_instance_valid(level), "Upgrades goes back to the hub and the level is gone")
	t.check(counter.amount == Progress.coins, "the hub shows the coins the round paid")
	for node_name: String in ["PaddleSpeed", "Combo", "Splitter"]:
		var node: HubNode = web.get_node(node_name)
		await _click(node)
		t.check(hub.selected == node, "clicking %s selects it" % node_name)
		var price := Progress.cost(node.upgrade)
		Progress.coins += price
		t.check(buy.theme_type_variation == &"" and not buy.disabled, "with the coins for it, Buy is the primary button on %s" % node_name)
		await t.tree().create_timer(0.15).timeout
		heard.clear()
		await _click(buy)
		await t.tree().create_timer(0.15).timeout
		t.check(Progress.rank(node.upgrade) == 1 and Progress.coins == earned and heard.has(Sfx.BUY), "Buy buys a rank of %s for its price" % node_name)
		t.check(int(_saved().ranks.get(String(node.upgrade.id), 0)) == 1 and _saved().coins == earned, "and the purchase is in the save")
	t.check(web.state(web.get_node("SplitterRespawn")) == HubNode.State.AVAILABLE and web.state(web.get_node("SplitterHealth")) == HubNode.State.LOCKED, "buying opens the next ring and no more")

	# The level again: place the Splitter, start with Space, play it out.
	await _click(levels.get_node("%Play"))
	level = play.get_child(-1) as Control
	setup = level.get_node("SetupUi")
	t.check(level.phase == SETUP and setup._slots.size() == 1 and setup._slots[0].kind.id == &"splitter" and setup._slots[0].left == 1, "the tray now holds one Splitter")
	t.check(level.round.stats.paddle_speed > Progress.balance.paddle_speed, "the round has the faster paddle that was bought")
	heard.clear()
	var slot := (setup._slots[0] as Control).get_global_rect().get_center()
	var spot: Vector2 = LevelArena.ORIGIN + SPLITTER_AT * level.round.board.zoom()
	_mouse(slot, MOUSE_BUTTON_LEFT, true)
	_mouse(slot.lerp(spot, 0.5))
	_mouse(spot)
	_mouse(spot, MOUSE_BUTTON_LEFT, false)
	await t.tree().process_frame
	await t.tree().create_timer(0.15).timeout
	var items: Array[Layout.Item] = level.round.layout.items
	t.check(items.size() == 1 and items[0].kind.id == &"splitter" and items[0].cell == level.round.board.cell_at(SPLITTER_AT), "dragging the Splitter from the tray places it in the cell under the cursor, through the CRT's curve")
	t.check(setup._slots[0].left == 0 and heard.has(Sfx.PLACE_ITEM), "the tray has none left, and the placing was heard")
	t.check((_saved().layouts.get("1", []) as Array).size() == 1, "the layout is in the save")
	_key(KEY_SPACE)
	t.check(level.phase == PLAY and level.round.layout.items.size() == 1, "Space starts the round with the Splitter on the board")
	var before := Progress.coins
	# Missed on purpose, as a clear would offer Next and Retry is tested below. The round's seed is random, and a
	# lucky one scores level 1's target before the ball is lost, so this round's target is out of reach.
	level.round.target = 1 << 30
	await _play_out(level, false)
	t.check(level.phase == SUMMARY and Progress.coins == before + level.round.coins and _saved().coins == Progress.coins, "the second round is paid once and saved too")

	# Retry with the keyboard: Setup again on a new round, the layout still there, and the old round let go.
	var old: WeakRef = weakref(level.round)
	var paid := Progress.coins
	summary = level.get_node("Summary")
	t.check((summary.find_child("Retry", true, false) as Button).has_focus(), "Retry has the focus in the Summary")
	_key(KEY_ENTER)
	await t.tree().process_frame
	await t.tree().process_frame
	t.check(level.phase == SETUP and not level.round.over and not summary.visible and setup.visible, "Enter retries: Setup again, and the same Enter does not start the round")
	t.check(level.round.layout.items.size() == 1 and Progress.coins == paid, "the Splitter is still placed after Retry, and Retry pays nothing")
	t.check(old.get_ref() == null, "the round that was played is freed on Retry: nothing holds an attempt after it")

	# Esc: the hub, and one Esc goes no further. Esc again: the menu.
	_key(KEY_ESCAPE)
	await t.tree().process_frame
	t.check(_screen() == play and hub.is_visible_in_tree() and not is_instance_valid(level), "Esc in Setup goes to the hub and stops there")
	_key(KEY_ESCAPE)
	await t.tree().process_frame
	t.check(_screen().scene_file_path == Main.MENU and not is_instance_valid(play), "Esc in the hub goes to the main menu")

	# Settings: toggle the CRT, and back.
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	await t.tree().process_frame
	t.check(_screen().scene_file_path == Main.SETTINGS, "Settings opens from the menu")
	var shader := main.crt.material as ShaderMaterial
	t.check(Settings.crt and shader.get_shader_parameter("enabled") == true, "the CRT was on all along")
	_key(KEY_ENTER)
	t.check(not Settings.crt and shader.get_shader_parameter("enabled") == false, "Enter on the CRT toggle turns the filter off")
	Settings.use(Settings.path)
	t.check(not Settings.crt, "and the setting is in its file")
	_key(KEY_ESCAPE)
	await t.tree().process_frame
	t.check(_screen().scene_file_path == Main.MENU, "Esc in Settings goes back to the menu")

	# What a new session would find.
	var coins := Progress.coins
	Progress.use(Progress.path)
	t.check(Progress.coins == coins and Progress.rank(Progress.upgrade(&"paddle_speed")) == 1 and Progress.rank(Progress.upgrade(&"splitter")) == 1
			and Progress.layout(1).count(&"splitter") == 1, "read back from the file, the save has the coins, both ranks and the placed Splitter")
	_key(KEY_ENTER)
	await t.tree().process_frame
	play = _screen() as Play
	t.check(play != null and (play.get_node("Hub/Bar/Coins") as UiPrice).amount == coins, "Play again opens the hub on that save")


## Plays the round on screen to its end, as a player who keeps the mouse level with the ball (or, without
## `follow`, at the arena's top edge), and waits for the Summary's panel.
func _play_out(level: Control, follow := true) -> void:
	Engine.time_scale = FAST
	var round: Round = level.round
	t.check(round.held, "Play waits with the ball on the paddle")
	_mouse(LevelArena.ORIGIN + Vector2(200, 200), MOUSE_BUTTON_LEFT, true)
	_mouse(LevelArena.ORIGIN + Vector2(200, 200), MOUSE_BUTTON_LEFT, false)
	t.check(not round.held, "a click launches the ball")
	var started := Time.get_ticks_msec()
	while level.phase == PLAY and Time.get_ticks_msec() - started < 60000:
		if not round.balls.is_empty():
			_mouse(LevelArena.ORIGIN + Vector2(-40.0, round.balls[0].pos.y if follow else 0.0) * round.board.zoom())
		await t.tree().physics_frame
	var summary: Control = level.get_node("Summary")
	while level.phase == SUMMARY and summary.find_child("Upgrades", true, false) and not (summary.find_child("Upgrades", true, false) as Control).is_visible_in_tree() \
			and Time.get_ticks_msec() - started < 70000:
		await t.tree().process_frame
	Engine.time_scale = 1.0
	await t.tree().process_frame


func _screen() -> Node:
	return main.screen.get_child(main.screen.get_child_count() - 1)


func _texts(under: Node) -> Array:
	return under.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _saved() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Progress.path))


## The window point the CRT shows the game's point `target` under: the inverse of Main's warp.
func _at(target: Vector2) -> Vector2:
	var p := target
	for i in 8:
		p += target - main._warp(p)
	return p


## A left click on the middle of `control`, as the player sees it.
func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	_mouse(at)
	for pressed: bool in [true, false]:
		_mouse(at, MOUSE_BUTTON_LEFT, pressed)
		await t.tree().process_frame


## A mouse event at the game's point `at`, pushed into the window (headless, it is 64 x 64; see tests/test.gd).
func _mouse(at: Vector2, button := MOUSE_BUTTON_NONE, pressed := false) -> void:
	var event: InputEventMouse
	if button == MOUSE_BUTTON_NONE:
		event = InputEventMouseMotion.new()
	else:
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = pressed
		event = click
	event.position = _at(at)
	event.global_position = event.position
	t.get_viewport().push_input(event, true)


## Presses and releases `key`.
func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		t.get_viewport().push_input(event, true)
