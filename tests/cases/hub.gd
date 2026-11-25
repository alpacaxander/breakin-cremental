extends RefCounted
## The upgrade screen, through the real Main and real clicks: which nodes are open, previewed and hidden, Buy
## (coins, keys, copies, sounds), undo (the rule, the refund, a key back, right click against right drag, the
## button's faces), the key counter, the arrows, pan and zoom, the level panel and Esc. The web
## scene's own shape is checked in contracts.gd.

var _heard: Array[StringName] = []


func run(t: Node) -> void:
	Settings.crt = false  # clicks land where they are pushed
	var main: Main = (load("res://src/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	Sfx.played.connect(_listen)
	await t.tree().process_frame

	# By keyboard from the menu: Enter on Play opens Setup, and Esc there leaves the focus on the hub's selected
	# node, so Tab and the arrows work.
	_key(t, KEY_ENTER)
	await t.tree().process_frame
	_key(t, KEY_ESCAPE)
	await t.tree().process_frame
	var hub: Control = main.screen.get_child(0).get_node("Hub")
	var web: HubWeb = hub.get_node("Web")
	var at := func(name: StringName) -> HubNode: return web.get_node(String(name))
	var focus := func() -> Control: return main.view.gui_get_focus_owner()
	t.check(focus.call() == hub.selected and hub.selected == web.seed_node() and Progress.rank(web.seed_node().upgrade) == 0,
			"Enter on the menu's Play, then Esc, puts the focus on the hub's selected node, and buys nothing")
	_key(t, KEY_TAB)
	t.check(focus.call() != null and focus.call() != web.seed_node() and hub.is_ancestor_of(focus.call()), "Tab moves the focus on from there")
	# The arrows go to the nearest node in line on the web's grid, not to the larger seed beside it. Every node is
	# owned for this, so every node is shown; the hub opens again on a fresh save below.
	HubWeb.own_first(web.nodes().size())
	Progress.rank_changed.emit(web.seed_node().upgrade)
	for pair: Array in [[&"Combo", KEY_UP, &"Splitter"], [&"Combo", KEY_DOWN, &"GrowthReach"], [&"PaddleSize", KEY_UP, &"GuideBounces"],
			[&"PaddleSize", KEY_DOWN, &"Splitter2"], [&"Booster", KEY_DOWN, &"PaddleSpeed"], [&"Blast", KEY_RIGHT, &"ToughBrick"],
			[&"HourglassFreeze", KEY_RIGHT, &"HourglassTime"], [&"Zap", KEY_UP, &"Guide2"], [&"Shockwave", KEY_LEFT, &"PowerBrick4"]]:
		(at.call(pair[0]) as Control).grab_focus()
		_key(t, pair[1])
		t.check(focus.call() == at.call(pair[2]), "%s from %s goes to %s (went to %s)" % [OS.get_keycode_string(pair[1]), pair[0], pair[2], focus.call().name])
	# The web is 13 rows tall and the view shows 5: a drag reaches the bottom row, and the arrows reach every shown
	# node and bring each into view. Then the same walk part of the way through the web, where some nodes are hidden.
	var bottom: HubNode = at.call(&"GrowthReach2")
	(at.call(&"PaddleSpeed") as Control).grab_focus()
	web.move(-web.pan)  # the pairs above scrolled the view
	t.check(not web.get_global_rect().encloses(bottom.get_global_rect()), "at first the bottom row (GrowthReach2) is below the view")
	web.move(Vector2(0, -99999))
	t.check(web.get_global_rect().encloses(bottom.get_global_rect()) and web.get_global_rect().encloses(at.call(&"GrowthPulses2").get_global_rect()),
			"a drag up brings the bottom row, GrowthReach2 to GrowthPulses2, into the view")
	_walk(t, web, "every node owned")
	for count in [5, 20, 40]:
		HubWeb.own_first(count)
		Progress.rank_changed.emit(web.seed_node().upgrade)
		_walk(t, web, "the first %d nodes owned" % count)
	HubWeb.own_first(web.nodes().size())
	Progress.rank_changed.emit(web.seed_node().upgrade)
	# Pan and zoom: the wheel over a node zooms about the pointer, a drag on the background pans, and the view's
	# centre can't leave the web.
	var combo: HubNode = at.call(&"Combo")
	web.refresh(combo)  # the walks left the view anywhere: bring Combo into it
	var spot := combo.get_global_rect().get_center()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = spot
	wheel.global_position = spot
	t.get_viewport().push_input(wheel, true)
	t.check(web.zoom > 1.0 and combo.get_global_rect().get_center().distance_to(spot) < 0.5,
			"the wheel over a node zooms in about the pointer (zoom %.2f)" % web.zoom)
	var before := combo.global_position
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = web.global_position + Vector2(4, 4)
	drag.global_position = drag.position
	drag.relative = Vector2(-30, 20)
	t.get_viewport().push_input(drag, true)
	t.check(combo.global_position.distance_to(before + drag.relative) < 0.5, "a drag pans the web with the pointer")
	web.move(Vector2(99999, 99999))
	var middle := web.get_global_rect().get_center()
	t.check(web.nodes().any(func(n: HubNode) -> bool: return n.get_global_rect().position.x <= middle.x + 1)
			and web.nodes().any(func(n: HubNode) -> bool: return n.get_global_rect().position.y <= middle.y + 1),
			"a long drag stops with the web still under the view's centre")
	web.zoom_at(Vector2.ZERO, 0.001)
	t.check(web.zoom == HubWeb.ZOOM_MIN, "zoom stops at its minimum")
	Progress.ranks.clear()
	Progress.owned.clear()
	Main.show_menu()
	Main.show_hub()
	await t.tree().process_frame
	hub = main.screen.get_child(0).get_node("Hub")
	web = hub.get_node("Web")
	at = func(name: StringName) -> HubNode: return web.get_node(String(name))
	t.check(focus.call() == hub.selected, "the hub takes the focus every time it opens")

	t.check(web.seed_node() == at.call(&"PaddleSpeed"), "Paddle Speed is the seed")
	t.check(web.seed_node().get_global_rect().get_center().is_equal_approx(web.get_global_rect().get_center()),
			"the seed sits at the centre of the view")

	# A fresh save: only the seed is open, its four neighbours are previews, and the rest is hidden.
	var ring: Array[StringName] = [&"Booster", &"Combo", &"PaddleSize", &"ToughBrick"]
	for n in web.nodes():
		var want := HubNode.State.AVAILABLE if n.is_seed else HubNode.State.PREVIEW if StringName(n.name) in ring else HubNode.State.LOCKED
		t.check(web.state(n) == want and n.visible == (want != HubNode.State.LOCKED),
				"on a fresh save %s is %s (is %s, %s)" % [n.name, HubNode.State.keys()[want], HubNode.State.keys()[web.state(n)], "shown" if n.visible else "hidden"])
	t.check((hub.get_node("Bar/Keys") as UiPrice).amount == 0 and (hub.get_node("Bar/Keys") as UiPrice).dim, "the top bar shows no keys, dim")

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
	t.check(Progress.rank(seed.upgrade) == 1 and Progress.coins == 100 - price and Progress.owned == [&"PaddleSpeed"], "Buy takes the price, adds a copy and owns the node")
	t.check(Sfx.BUY in _heard and not Sfx.CLICK in _heard, "Buy plays the buy cue and no click (heard %s)" % [_heard])
	var opened := web.nodes().filter(func(n: HubNode) -> bool: return web.state(n) == HubNode.State.AVAILABLE).map(func(n: HubNode) -> String: return n.name)
	opened.sort()
	t.check(opened == ["Booster", "Combo", "PaddleSize", "ToughBrick"], "buying the seed opens its four neighbours and nothing else (open: %s)" % [opened])
	t.check(web.state(seed) == HubNode.State.OWNED and web.state(at.call(&"PowerBrick")) == HubNode.State.PREVIEW
			and web.state(at.call(&"Zap")) == HubNode.State.LOCKED, "the seed is owned, the next ring is previewed and the one after stays locked")
	t.check(web.nodes().all(func(n: HubNode) -> bool: return n.visible == (web.state(n) != HubNode.State.LOCKED)), "every open node is shown and every locked one hidden")
	# Copies share a price ladder and the pips: the other Paddle Speed node now asks the second rank's price, and
	# both show the one copy owned.
	var copy: HubNode = at.call(&"PaddleSpeed2")
	t.check((copy.get_node("Bottom/Price") as UiPrice).amount == seed.upgrade.cost(1) and (copy.get_node("Bottom/Pips") as UiPips).total == 1
			and (seed.get_node("Bottom/Pips") as UiPips).total == 1 and not (seed.get_node("Bottom/Price") as Control).visible,
			"the other copy asks %d, the next copy's price, every copy shows one pip, and the bought one no price" % seed.upgrade.cost(1))
	# A click leaves no focus on Buy: Space is Start and Retry in a level, and here it would press Buy again.
	_key(t, KEY_SPACE)
	t.check(focus.call() == seed and Progress.rank(seed.upgrade) == 1, "after a click on Buy the focus is back on the selected node, and Space buys nothing")
	(at.call(&"Combo") as Control).grab_focus()
	buy.grab_focus()
	_key(t, KEY_ENTER)
	t.check(focus.call() == buy and Progress.rank(at.call(&"Combo").upgrade) == 1, "by keyboard the focus stays on Buy, and Enter buys the selected node (Combo, which opens Hourglass Brick)")
	# A preview can be selected and read, not bought: Buy is disabled and reads LOCKED, and a double click buys nothing.
	var power: HubNode = at.call(&"PowerBrick")
	await _click(t, power)
	t.check(hub.selected == power and buy.disabled and buy.text == "LOCKED" and (hub.get_node("Detail/%State") as Label).text == "PREVIEW"
			and (hub.get_node("Detail/%Note") as Label).text == "BUY A NODE NEXT TO IT FIRST", "a preview is selected, and the panel says it can't be bought yet")
	t.check((power.get_node("Bottom/Price") as UiPrice).dim and (hub.get_node("Detail/%Price") as UiPrice).dim, "a preview's price is dim, on the node and the panel")
	var before_coins := Progress.coins
	await t.tree().create_timer(0.15).timeout
	await _click(t, power, true)
	t.check(Progress.rank(power.upgrade) == 0 and Progress.coins == before_coins and not web.owns(power), "a double click on a preview buys nothing")
	(hub.get_node("Detail") as Node).call(&"buy")
	t.check(Progress.rank(power.upgrade) == 0, "nor does the panel's buy()")

	# Too poor: Buy can still be pressed, buys nothing and plays can't afford.
	var splitter: HubNode = at.call(&"HourglassBrick")
	await _click(t, splitter)
	t.check(hub.selected == splitter and (hub.get_node("Detail/%Name") as Label).text == "Hourglass Brick", "clicking a node selects it and shows it in the detail panel")
	await t.tree().create_timer(0.15).timeout
	Progress.coins = Progress.cost(splitter.upgrade) - 1
	t.check(not buy.disabled and buy.theme_type_variation == &"CantAfford", "Buy stays pressable when the coins don't cover it, and looks it")
	_heard.clear()
	await _click(t, buy)
	await t.tree().create_timer(0.15).timeout
	t.check(Progress.rank(splitter.upgrade) == 0 and Progress.coins == Progress.cost(splitter.upgrade) - 1, "a Buy you can't afford buys nothing")
	t.check(Sfx.CANT_AFFORD in _heard and not Sfx.BUY in _heard and not Sfx.CLICK in _heard, "it plays can't afford (heard %s)" % [_heard])

	# A double click on a node buys it, as Buy does; a single click only selected it above.
	Progress.coins = 99999
	await _click(t, at.call(&"Combo"))
	await t.tree().create_timer(0.15).timeout
	_heard.clear()
	await _click(t, splitter, true)
	await t.tree().create_timer(0.15).timeout
	t.check(hub.selected == splitter and Progress.rank(splitter.upgrade) == 1 and Sfx.BUY in _heard, "a double click on a node selects it and buys it (heard %s)" % [_heard])

	# An owned node can't be bought again, though its upgrade has a copy left elsewhere.
	await _click(t, seed)
	t.check(buy.disabled and web.state(seed) == HubNode.State.OWNED and not Progress.maxed(seed.upgrade), "Buy is disabled on an owned node")
	var coins := Progress.coins
	await _click(t, seed, true)
	t.check(Progress.rank(seed.upgrade) == 1 and Progress.coins == coins, "a double click on an owned node buys nothing")

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

	# Keys: level 1 is cleared, so one is held. With the first 11 nodes owned (Power Brick among them), Zap and Blast
	# are on offer, and up to 3 links behind each of them is previewed; past that, and past another way in, is not.
	var keys: UiPrice = hub.get_node("Bar/Keys")
	t.check(Progress.keys() == 1 and keys.amount == 1 and not keys.dim and keys.key, "the top bar shows the key level 1 paid, in gold")
	HubWeb.own_first(11)
	Progress.coins = 0
	Progress.rank_changed.emit(seed.upgrade)
	for pair: Array in [[&"Zap", HubNode.State.AVAILABLE], [&"Blast", HubNode.State.AVAILABLE], [&"Guide2", HubNode.State.PREVIEW],
			[&"ZapRange", HubNode.State.PREVIEW], [&"ZapDamage", HubNode.State.PREVIEW], [&"BlastSize", HubNode.State.PREVIEW],
			[&"BlastDamage", HubNode.State.PREVIEW], [&"Shockwave", HubNode.State.PREVIEW], [&"Splitter4", HubNode.State.LOCKED],
			[&"PowerBrick3", HubNode.State.LOCKED], [&"PowerBrick4", HubNode.State.LOCKED], [&"BlastDamage2", HubNode.State.LOCKED]]:
		var n: HubNode = at.call(pair[0])
		t.check(web.state(n) == pair[1] and n.visible == (pair[1] != HubNode.State.LOCKED),
				"with Power Brick owned, %s is %s (is %s)" % [pair[0], HubNode.State.keys()[pair[1]], HubNode.State.keys()[web.state(n)]])
	var zap: HubNode = at.call(&"Zap")
	var zap_price: UiPrice = zap.get_node("Bottom/Price")
	t.check(zap_price.key and zap_price.text == "KEY" and not zap_price.dim and (zap.get_node("Bottom/Pips") as UiPips).total == 0,
			"a key node shows the key glyph and KEY, gold with a key in hand, and no pips")
	hub.select(zap)
	var panel_price: UiPrice = hub.get_node("Detail/%Price")
	t.check((hub.get_node("Detail/%Note") as Label).text == "COSTS 1 KEY, NO COINS" and panel_price.key and panel_price.text == "1 KEY"
			and not panel_price.dim and not buy.disabled and buy.theme_type_variation == &"", "with a key, Zap's panel asks 1 KEY and Buy is the primary button, with no coins")
	Progress.unlocked = 1  # the key is gone
	hub.select(zap)
	t.check(keys.amount == 0 and keys.dim and zap_price.dim and panel_price.dim and buy.theme_type_variation == &"CantAfford" and not buy.disabled,
			"with no key the counter reads 0, dim, the price is dim and Buy has the can't-afford look")
	await t.tree().create_timer(0.15).timeout
	_heard.clear()
	await _click(t, buy)
	await t.tree().create_timer(0.15).timeout
	t.check(not web.owns(zap) and Sfx.CANT_AFFORD in _heard, "Buy with no key buys nothing and plays can't afford (heard %s)" % [_heard])
	Progress.unlocked = 2
	hub.select(zap)
	_heard.clear()
	await _click(t, buy)
	await t.tree().create_timer(0.15).timeout
	t.check(web.owns(zap) and Progress.coins == 0 and Progress.keys() == 0 and keys.amount == 0 and Sfx.BUY in _heard,
			"Buy with the key owns Zap, spends the key and no coins (heard %s)" % [_heard])
	hub.select(at.call(&"Blast"))
	t.check(buy.theme_type_variation == &"CantAfford" and (at.call(&"Blast").get_node("Bottom/Price") as UiPrice).dim, "then Blast, the other key node, can't be afforded")

	# Undo. The rule: an owned node can be undone when every other owned node still reaches the seed through owned
	# nodes without it. With the first 11 nodes owned, the leaves can and the nodes others hang off can't.
	HubWeb.own_first(11)
	Progress.unlocked = 1
	Progress.coins = 0
	Progress.rank_changed.emit(seed.upgrade)
	for pair: Array in [[&"ComboWindow", true], [&"PowerBrick", true], [&"WallSegment", true], [&"PaddleSize", false],
			[&"HourglassBrick", false], [&"PaddleSpeed", false], [&"Zap", false], [&"Guide2", false]]:
		t.check(web.can_undo(at.call(pair[0])) == pair[1], "with the first 11 nodes owned, %s %s be undone" % [pair[0], "can" if pair[1] else "can't"])
	# The web's one loop, bottom right: Hourglass Freeze, Hourglass Time, Hourglass Freeze 2, Hourglass Brick 2.
	HubWeb.own_first(web.nodes().size())
	t.check(web.can_undo(at.call(&"HourglassTime")) and web.can_undo(at.call(&"HourglassFreeze2")) and not web.can_undo(at.call(&"HourglassFreeze")),
			"with every node owned, Hourglass Time and Hourglass Freeze 2 on the loop can be undone and Hourglass Freeze, where it hangs, can't")
	Progress.owned.erase(&"HourglassTime2")
	Progress.owned.erase(&"HourglassBrick2")
	t.check(not web.can_undo(at.call(&"HourglassTime")), "without Hourglass Brick 2 the loop is open, and Hourglass Time holds up Hourglass Freeze 2")
	HubWeb.own_first(1)
	t.check(web.can_undo(seed), "the seed can be undone when it is the only node owned")
	HubWeb.own_first(0)
	t.check(not web.can_undo(seed), "and nothing can be undone with nothing owned")

	# A right click undoes a leaf: Paddle Size 2, the second copy, gives back the last price paid; the copies'
	# prices fall back a step, the node is on offer again and stays selected, and what it alone opened is a preview.
	HubWeb.own_first(13)  # Zap among them, with level 1's key
	Progress.unlocked = 2
	Progress.rank_changed.emit(seed.upgrade)
	var size2: HubNode = at.call(&"PaddleSize2")
	var size_u := size2.upgrade
	hub.select(size2)
	t.check(Progress.rank(size_u) == 2 and web.state(at.call(&"Multiball")) == HubNode.State.AVAILABLE, "Paddle Size 2 is owned, the second copy, and Multiball hangs off it")
	t.check((hub.get_node("Detail/%Note") as Label).text == "UNDO REFUNDS THE LAST PRICE PAID" and (hub.get_node("Detail/%PriceTag") as Label).text == "REFUND"
			and panel_price.amount == size_u.cost(1) and not panel_price.dim and not panel_price.key and not buy.disabled and buy.text == "UNDO"
			and buy.theme_type_variation == &"SecondaryButton", "an owned leaf's panel: the refund of %d, gold, and UNDO in the secondary look" % size_u.cost(1))
	await t.tree().create_timer(0.15).timeout
	_heard.clear()
	await _right_click(t, size2)
	await t.tree().create_timer(0.15).timeout
	t.check(not web.owns(size2) and Progress.rank(size_u) == 1 and Progress.coins == size_u.cost(1) and hub.selected == size2
			and web.state(size2) == HubNode.State.AVAILABLE, "a right click undoes it: one copy, %d coins back, on offer again and selected" % size_u.cost(1))
	t.check(Sfx.PLACE_ITEM in _heard and not Sfx.CLICK in _heard, "an undo plays place item and no click (heard %s)" % [_heard])
	t.check((size2.get_node("Bottom/Price") as UiPrice).amount == size_u.cost(1) and (at.call(&"PaddleSize3").get_node("Bottom/Price") as UiPrice).amount == size_u.cost(1)
			and (at.call(&"PaddleSize").get_node("Bottom/Pips") as UiPips).total == 1, "the copies ask %d again, and the one left shows one pip" % size_u.cost(1))
	t.check(web.state(at.call(&"Multiball")) == HubNode.State.PREVIEW and web.state(at.call(&"GoldBrick2")) == HubNode.State.PREVIEW
			and web.state(at.call(&"ComboWindow2")) == HubNode.State.LOCKED and not at.call(&"ComboWindow2").visible,
			"what it alone opened is a preview again, and the ring past that hidden")
	t.check((hub.get_node("Detail/%Note") as Label).text == "YOU OWN 1. EACH ONE RAISES THE REST" and buy.text == "BUY",
			"the panel shows it on offer again")
	# A right press that turns into a drag pans and undoes nothing, wherever it is let go.
	var paddle_size: HubNode = at.call(&"PaddleSize")
	var hour: HubNode = at.call(&"HourglassBrick")
	var ladder := at.call(&"ComboWindow") as HubNode
	var pan := web.pan
	await _right_click(t, ladder, Vector2(30, 0), true)
	t.check(web.owns(ladder), "a right drag that comes back to where it began undoes nothing")
	await _right_click(t, ladder, Vector2(30, 0))
	t.check(web.owns(ladder) and web.pan != pan, "nor does one let go elsewhere, which pans the web")
	# A node in use: IN USE, disabled, and a right click only selects it and plays can't afford.
	hub.select(hour)
	t.check((hub.get_node("Detail/%Note") as Label).text == "UNDO WHAT HANGS OFF IT FIRST" and buy.disabled and buy.text == "IN USE",
			"a node others hang off: the panel says undo those first and the button is IN USE, disabled")
	await t.tree().create_timer(0.15).timeout
	_heard.clear()
	await _right_click(t, paddle_size)
	await t.tree().create_timer(0.15).timeout
	t.check(web.owns(paddle_size) and hub.selected == paddle_size and buy.text == "IN USE" and Sfx.CANT_AFFORD in _heard,
			"a right click on a node in use selects it, undoes nothing and plays can't afford (heard %s)" % [_heard])
	# A node not owned: a right click selects it, silently. And a double click on an owned node undoes nothing.
	_heard.clear()
	await _right_click(t, size2)
	await t.tree().create_timer(0.15).timeout
	t.check(hub.selected == size2 and not web.owns(size2) and Progress.coins == size_u.cost(1) and _heard.is_empty(),
			"a right click on a node on offer selects it and does nothing else (heard %s)" % [_heard])
	hub.select(ladder)  # in view
	await _click(t, ladder, true)
	t.check(web.owns(ladder) and Progress.rank(ladder.upgrade) == 1, "a double click on an owned leaf undoes nothing")
	# A key comes back: Zap bought with level 1's key, then undone by keyboard, Enter on UNDO.
	Progress.unlocked = 2
	HubWeb.own_first(12)
	Progress.rank_changed.emit(seed.upgrade)
	hub.select(zap)
	t.check(Progress.keys() == 0 and (hub.get_node("Detail/%Note") as Label).text == "UNDO GIVES THE KEY BACK" and panel_price.key and panel_price.text == "1 KEY"
			and not buy.disabled and buy.text == "UNDO", "an owned key node: UNDO gives the key back, the refund is 1 KEY")
	var coins_before := Progress.coins
	buy.grab_focus()
	_key(t, KEY_ENTER)
	t.check(not web.owns(zap) and Progress.keys() == 1 and keys.amount == 1 and Progress.coins == coins_before and hub.selected == zap
			and web.state(zap) == HubNode.State.AVAILABLE, "Enter on UNDO undoes Zap: the key is back in the top bar, no coins")

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


## From the seed, every arrow key from every node reached: the arrows reach each shown node, never a hidden one,
## and each node they land on is moved wholly into the view.
func _walk(t: Node, web: HubWeb, save: String) -> void:
	var view := web.get_global_rect()
	var reached: Array[HubNode] = [web.seed_node()]
	var i := 0
	while i < reached.size():
		for key: Key in [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN]:
			reached[i].grab_focus()
			_key(t, key)
			var n := web.get_viewport().gui_get_focus_owner() as HubNode
			if n == null or n in reached:
				continue
			t.check(n.visible, "%s: %s from %s lands on a shown node (%s)" % [save, OS.get_keycode_string(key), reached[i].name, n.name])
			t.check(view.grow(0.5).encloses(n.get_global_rect()), "%s: %s from %s brings %s into the view" % [save, OS.get_keycode_string(key), reached[i].name, n.name])
			reached.append(n)
		i += 1
	var shown := web.nodes().filter(func(n: HubNode) -> bool: return n.visible)
	t.check(reached.size() == shown.size(), "%s: the arrows reach all %d shown nodes (reached %d)" % [save, shown.size(), reached.size()])


func _key(t: Node, key: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		t.get_viewport().push_input(e)


## A left click at the middle of `control`, pushed into the viewport (headless, the window is 64 x 64). `double`
## adds a second click whose press is a double click, as Godot sends it.
func _click(t: Node, control: Control, double := false) -> void:
	var at := control.get_global_rect().get_center()
	for i in 4 if double else 2:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = i % 2 == 0
		click.double_click = i == 2
		click.position = at
		click.global_position = at
		t.get_viewport().push_input(click, true)
		await t.tree().process_frame


## A right click on a web node, as _click. With `drag`, the pointer moves that much with the button held before the
## release; with `back` too, it moves back to where it began first.
func _right_click(t: Node, control: Control, drag := Vector2.ZERO, back := false) -> void:
	(control.get_parent() as HubWeb).refresh(control)  # bring it into the view, as the arrow keys would
	var at := control.get_global_rect().get_center()
	var path: Array[Vector2] = [at]
	if drag:
		path.append(at + drag)
	if back:
		path.append(at)
	for i in path.size() + 1:
		var e: InputEventMouse
		if i in [0, path.size()]:
			e = InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_RIGHT
			e.pressed = i == 0
		else:
			e = InputEventMouseMotion.new()
			e.button_mask = MOUSE_BUTTON_MASK_RIGHT
			e.relative = path[i] - path[i - 1]
		e.position = path[mini(i, path.size() - 1)]
		e.global_position = e.position
		t.get_viewport().push_input(e, true)
		await t.tree().process_frame
