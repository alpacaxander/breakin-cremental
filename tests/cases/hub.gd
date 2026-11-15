extends RefCounted
## The upgrade screen, through the real Main and real clicks: the web's connections, which nodes are open, Buy
## (coins, ranks, sounds), the level panel and Esc.

## docs/design/upgrades.md's web: each node and the one it hangs off.
const WEB := {
	&"BallSpeed": &"PaddleSpeed", &"PaddleSize": &"PaddleSpeed", &"Bumper": &"PaddleSpeed",
	&"ExplosiveBrick": &"PaddleSpeed", &"Combo": &"Bumper", &"WallSegment": &"PaddleSize",
	&"RoundTime": &"ExplosiveBrick", &"GoldBrick": &"BallSpeed", &"Booster": &"BallSpeed",
	&"BlastSize": &"ExplosiveBrick", &"Shockwave": &"ExplosiveBrick", &"HourglassBrick": &"RoundTime",
	&"Splitter": &"Combo", &"Zap": &"GoldBrick",
}

var _heard: Array[StringName] = []


func run(t: Node) -> void:
	Settings.crt = false  # clicks land where they are pushed
	var main: Main = (load("res://src/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	Sfx.played.connect(_listen)
	await t.tree().process_frame

	# By keyboard from the menu: Enter on Play leaves the focus on the selected node, so Tab and the arrows work.
	_key(t, KEY_ENTER)
	await t.tree().process_frame
	var hub: Control = main.screen.get_child(0).get_node("Hub")
	var web: HubWeb = hub.get_node("Web")
	var at := func(name: StringName) -> HubNode: return web.get_node(String(name))
	var focus := func() -> Control: return main.view.gui_get_focus_owner()
	t.check(focus.call() == hub.selected and hub.selected == web.seed_node() and Progress.rank(web.seed_node().upgrade) == 0,
			"Enter on the menu's Play puts the focus on the hub's selected node, and buys nothing")
	_key(t, KEY_TAB)
	t.check(focus.call() != null and focus.call() != web.seed_node() and hub.is_ancestor_of(focus.call()), "Tab moves the focus on from there")
	# The arrows go to the node in line on the web's grid, not to the larger seed beside it. Every node is owned
	# for this, so every node is shown; the hub opens again on a fresh save below.
	for u in Progress.upgrades():
		Progress.ranks[u.id] = 1
	Progress.rank_changed.emit(web.seed_node().upgrade)
	for pair: Array in [[&"Bumper", KEY_UP, &"GoldBrick"], [&"ExplosiveBrick", KEY_DOWN, &"RoundTime"], [&"Bumper", KEY_DOWN, &"WallSegment"],
			[&"Combo", KEY_RIGHT, &"Bumper"], [&"BallSpeed", KEY_UP, &"Booster"]]:
		(at.call(pair[0]) as Control).grab_focus()
		_key(t, pair[1])
		t.check(focus.call() == at.call(pair[2]), "%s from %s goes to %s (went to %s)" % [OS.get_keycode_string(pair[1]), pair[0], pair[2], focus.call().name])
	Progress.ranks.clear()
	Main.show_menu()
	Main.show_hub()
	await t.tree().process_frame
	hub = main.screen.get_child(0).get_node("Hub")
	web = hub.get_node("Web")
	at = func(name: StringName) -> HubNode: return web.get_node(String(name))
	t.check(focus.call() == hub.selected, "the hub takes the focus every time it opens")

	# The web is the documented one, and every upgrade is on it once.
	var pairs := web.links().map(func(l: Array) -> String: return _pair(l[0].name, l[1].name))
	var want := WEB.keys().map(func(k: StringName) -> String: return _pair(k, WEB[k]))
	pairs.sort()
	want.sort()
	t.check(pairs == want, "the web's links are upgrades.md's (have %s)" % [pairs])
	var ids := web.nodes().map(func(n: HubNode) -> StringName: return n.upgrade.id)
	t.check(ids.size() == Progress.upgrades().size() and Progress.upgrades().all(func(u: Upgrade) -> bool: return ids.count(u.id) == 1),
			"every upgrade is on the web exactly once")
	t.check(web.seed_node() == at.call(&"PaddleSpeed"), "Paddle Speed is the seed")
	for n in web.nodes():
		t.check(web.get_rect().encloses(Rect2(web.position + n.position, n.size)), "%s sits inside the web view" % n.name)

	# A fresh save: only the seed is open, and the rest is hidden.
	for n in web.nodes():
		var open: bool = web.state(n) == HubNode.State.AVAILABLE
		t.check(open == n.is_seed and n.visible == n.is_seed, "on a fresh save only the seed is open and shown (%s)" % n.name)

	# Buy the seed's first rank with a click: coins go, the rank comes, BUY plays and no CLICK.
	var buy: Button = hub.get_node("Detail/%Buy")
	var seed: HubNode = at.call(&"PaddleSpeed")
	t.check(hub.selected == seed, "the seed is selected at first")
	await _click(t, seed)
	await t.tree().create_timer(0.15).timeout  # Sfx spaces voices in real time: let this click's cue go first
	Progress.coins = 100
	var price := Progress.cost(seed.upgrade)
	_heard.clear()
	await _click(t, buy)
	await t.tree().create_timer(0.15).timeout
	t.check(Progress.rank(seed.upgrade) == 1 and Progress.coins == 100 - price, "Buy takes the price and adds a rank")
	t.check(Sfx.BUY in _heard and not Sfx.CLICK in _heard, "Buy plays the buy cue and no click (heard %s)" % [_heard])
	var opened := web.nodes().filter(func(n: HubNode) -> bool: return web.state(n) == HubNode.State.AVAILABLE).map(func(n: HubNode) -> String: return n.name)
	opened.sort()
	t.check(opened == ["BallSpeed", "Bumper", "ExplosiveBrick", "PaddleSize"], "buying the seed opens its four neighbours and nothing else (open: %s)" % [opened])
	t.check(web.state(seed) == HubNode.State.OWNED and web.state(at.call(&"Combo")) == HubNode.State.LOCKED, "the seed is owned and the next ring stays locked")
	t.check(web.nodes().all(func(n: HubNode) -> bool: return n.visible == (web.state(n) != HubNode.State.LOCKED)), "every open node is shown and every locked one hidden")	# A click leaves no focus on Buy: Space is Start and Retry in a level, and here it would buy the next rank.
	_key(t, KEY_SPACE)
	t.check(focus.call() == seed and Progress.rank(seed.upgrade) == 1, "after a click on Buy the focus is back on the selected node, and Space buys nothing")
	buy.grab_focus()
	_key(t, KEY_ENTER)
	t.check(focus.call() == buy and Progress.rank(seed.upgrade) == 2, "by keyboard the focus stays on Buy, and Enter buys the next rank")

	# Too poor: Buy can still be pressed, buys nothing and plays can't afford.
	var bumper: HubNode = at.call(&"Bumper")
	await _click(t, bumper)
	t.check(hub.selected == bumper and (hub.get_node("Detail/%Name") as Label).text == "Bumper", "clicking a node selects it and shows it in the detail panel")
	await t.tree().create_timer(0.15).timeout
	Progress.coins = Progress.cost(bumper.upgrade) - 1
	t.check(not buy.disabled and buy.theme_type_variation == &"CantAfford", "Buy stays pressable when the coins don't cover it, and looks it")
	_heard.clear()
	await _click(t, buy)
	await t.tree().create_timer(0.15).timeout
	t.check(Progress.rank(bumper.upgrade) == 0 and Progress.coins == Progress.cost(bumper.upgrade) - 1, "a Buy you can't afford buys nothing")
	t.check(Sfx.CANT_AFFORD in _heard and not Sfx.BUY in _heard and not Sfx.CLICK in _heard, "it plays can't afford (heard %s)" % [_heard])

	# A maxed node can't be bought.
	Progress.coins = 99999
	Progress.ranks[seed.upgrade.id] = seed.upgrade.max_rank
	Progress.rank_changed.emit(seed.upgrade)
	await _click(t, seed)
	t.check(buy.disabled and web.state(seed) == HubNode.State.MAXED, "Buy is disabled on a maxed node")

	# The level panel: a locked level can be looked at but not played; Play opens the level on show.
	var levels: Control = hub.get_node("Levels")
	var play: Button = levels.get_node("%Play")
	t.check(levels.level == 1, "a fresh save shows level 1")
	await _click(t, levels.get_node("%Next"))
	t.check(levels.level == 2 and play.disabled, "the next level is locked and its Play is disabled")
	await _click(t, play)
	t.check(main.screen.get_child(0).get_node("Hub").visible, "pressing a locked level's Play opens nothing")

	# While a level is open the hub is hidden; it shows what changed when it comes back.
	await _click(t, levels.get_node("%Prev"))
	await _click(t, play)
	var open_level = main.screen.get_child(0).get_child(-1)
	t.check(not hub.visible and open_level.get("level") == 1, "Play opens the level on show (level %s)" % [open_level.get("level")])
	Progress.finish_round(1, 777, true)
	Main.show_hub()
	await t.tree().process_frame
	t.check(hub.visible and (hub.get_node("Bar/Coins") as UiPrice).amount == Progress.coins, "back on the hub, the coins are the new total")
	t.check(levels.level == 2 and not play.disabled, "a newly unlocked level is the one on show, and playable")
	t.check(focus.call() == hub.selected, "back from a level, the selected node has the focus again")

	# Esc goes to the main menu and is handled there.
	var viewport := hub.get_viewport()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	t.get_viewport().push_input(esc, true)
	t.check(main.screen.get_child(0).scene_file_path == Main.MENU and viewport.is_input_handled(), "Esc goes back to the menu and goes no further")

	Sfx.played.disconnect(_listen)
	main.free()


func _listen(cue: StringName, _player: AudioStreamPlayer) -> void:
	_heard.append(cue)


func _pair(a: StringName, b: StringName) -> String:
	return "%s-%s" % ([a, b] if String(a) < String(b) else [b, a])


func _key(t: Node, key: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		t.get_viewport().push_input(e)


## A left click at the middle of `control`, pushed into the viewport (headless, the window is 64 x 64).
func _click(t: Node, control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		t.get_viewport().push_input(click, true)
		await t.tree().process_frame
