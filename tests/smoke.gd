extends Node
## Runs one round headless for a few seconds: godot --headless tests/smoke.tscn. Any script error prints.
## (A scene, not -s, so the Game autoload exists.)


func _ready() -> void:
	var a = load("res://src/arena.gd").new()
	add_child(a)
	await get_tree().process_frame
	a._start()
	a._launch()
	for i in 600:  # 5 s at 120 ticks
		await get_tree().physics_frame
		if a.over:
			break
	print("smoke ok: over=%s earned=%d fx=%d" % [a.over, a.earned, a.get_children().filter(func(c): return c is AnimatedSprite2D).size()])
	get_tree().quit()
