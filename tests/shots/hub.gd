extends RefCounted
## The upgrade screen: fresh, mid (the first half of the web bought) and maxed saves, with and without the CRT, a
## node of each shown state selected (and Growth Pulses, low on the web, and Overgrowth, a key node, not bought),
## the orange Abilities branch part bought with Blast, the longest text, in the panel, Shockwave scrolled into
## view, a Buy the player cannot afford, a locked level in the level panel, the pointer over a node, and the web
## zoomed fully out and fully in, and the key moment: level 1 cleared, the first 11 nodes bought, Zap and Blast on
## offer for the one key with the nodes behind them previewed, Zap selected, then a preview behind it selected.


func shots() -> Array[Dictionary]:
	return [
		{"name": "fresh", "setup": _hub},
		{"name": "fresh_flat", "crt": false, "setup": _hub},
		{"name": "mid", "save": "mid", "setup": _hub},
		{"name": "mid_flat", "save": "mid", "crt": false, "setup": _hub},
		{"name": "mid_poor", "save": "mid", "crt": false, "setup": _poor},
		{"name": "mid_locked_level", "save": "mid", "crt": false, "setup": _level.bind(3)},
		{"name": "maxed", "save": "maxed", "setup": _hub},
		{"name": "maxed_flat", "save": "maxed", "crt": false, "setup": _pick.bind(&"Combo")},
		{"name": "mid_growth_pulses", "save": "mid", "crt": false, "setup": _pick.bind(&"GrowthPulses")},
		{"name": "mid_overgrowth", "save": "mid", "crt": false, "setup": _pick.bind(&"Overgrowth")},
		{"name": "mid_abilities", "save": "mid", "crt": false, "setup": _pick.bind(&"Blast")},
		{"name": "mid_abilities_crt", "save": "mid", "setup": _pick.bind(&"Blast")},
		{"name": "maxed_shockwave", "save": "maxed", "crt": false, "setup": _pick.bind(&"Shockwave")},
		{"name": "small", "save": "mid", "size": Vector2i(960, 540), "setup": _hub},
		{"name": "mid_hover", "save": "mid", "crt": false, "setup": _hover.bind(&"Combo")},
		{"name": "maxed_zoom_out", "save": "maxed", "crt": false, "setup": _zoom.bind(HubWeb.ZOOM_MIN)},
		{"name": "maxed_zoom_in", "save": "maxed", "crt": false, "setup": _zoom.bind(HubWeb.ZOOM_MAX)},
		{"name": "key", "crt": false, "setup": _key.bind(&"Zap")},
		{"name": "key_crt", "setup": _key.bind(&"Zap")},
		{"name": "key_preview", "crt": false, "setup": _key.bind(&"ZapRange")},
	]


## The web zoomed to `z` about the view's top left quarter.
func _zoom(main: Main, z: float) -> void:
	Main.show_hub()
	var web: HubWeb = _screen(main).get_node("Web")
	web.zoom_at(web.size / 4, z)


func _hub(_main: Main) -> void:
	Main.show_hub()


func _screen(main: Main) -> Control:
	return main.screen.get_child(0).get_node("Hub")


## Selects the web node with this name.
func _pick(main: Main, node: StringName) -> void:
	Main.show_hub()
	var hub := _screen(main)
	hub.select(hub.get_node("Web").get_node(String(node)))


## An open node the save cannot afford: the first one that is open and costs more than the coins.
func _poor(main: Main) -> void:
	Progress.coins = 5
	Main.show_hub()
	var hub := _screen(main)
	var web: HubWeb = hub.get_node("Web")
	for n in web.nodes():
		if web.state(n) == HubNode.State.AVAILABLE:
			hub.select(n)
			return


## The pointer over the web node with this name, which is not the selected one.
func _hover(main: Main, node: StringName) -> void:
	Main.show_hub()
	var event := InputEventMouseMotion.new()
	event.position = (_screen(main).get_node("Web").get_node(String(node)) as Control).get_global_rect().get_center()
	event.global_position = event.position
	main.view.push_input(event, true)


func _level(main: Main, n: int) -> void:
	Main.show_hub()
	_screen(main).get_node("Levels").pick(n)



## Level 1 cleared (one key in hand), the first 11 nodes owned and a few coins, with this node selected.
func _key(main: Main, node: StringName) -> void:
	Progress.unlocked = 2
	Progress.coins = 40
	HubWeb.own_first(11)
	_pick(main, node)
