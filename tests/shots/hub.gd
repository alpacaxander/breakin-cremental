extends RefCounted
## The upgrade screen: fresh, mid and maxed saves, with and without the CRT, a node of each shown state selected, a
## Buy the player cannot afford, a locked level in the level panel, and the pointer over a node.


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
		{"name": "small", "save": "mid", "size": Vector2i(960, 540), "setup": _hub},
		{"name": "mid_hover", "save": "mid", "crt": false, "setup": _hover.bind(&"Combo")},
	]


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
		if web.state(n) in [HubNode.State.AVAILABLE, HubNode.State.OWNED]:
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
