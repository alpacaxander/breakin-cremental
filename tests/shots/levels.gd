extends RefCounted
## Each level scene as the editor shows it (tinted tiles, the grid's outline), not as the game draws it.


func shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in range(1, Levels.count() + 1):
		out.append({"name": "level_%d_scene" % n, "crt": false, "setup": _show.bind(n)})
	return out


func _show(main: Main, n: int) -> void:
	for child in main.screen.get_children():
		child.free()
	var layer: Node2D = load(Levels.path(n)).instantiate()
	layer.position = Vector2(64, 72)
	main.screen.add_child(layer)
