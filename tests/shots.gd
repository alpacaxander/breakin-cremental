extends Node
## Renders every screen at a set of window sizes to user://shots/, to check the layout by eye. Needs a display with no
## window manager fighting the sizes, so run it under Xvfb (nothing opens on the desktop):
## nix develop -c xvfb-run -s "-screen 0 3840x2160x24" godot --display-driver x11 --rendering-driver opengl3 tests/shots.tscn

const SIZES := [Vector2i(1000, 600), Vector2i(960, 1080), Vector2i(1280, 720), Vector2i(1800, 1100), Vector2i(1920, 1080), Vector2i(1280, 1440), Vector2i(2520, 1370), Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)]


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)  # the saved settings may say fullscreen
	Game.enter_sandbox()  # every level open, nothing saved
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	var dir := ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	print("shots -> ", dir)
	# Each screen is built once and then resized live, the way a player drags the window.
	var screens := [["menu", main._show_menu], ["shop", main._show_shop], ["arena1", main._play.bind(0)], ["arena2", main._play.bind(1)],
		["pause", func(): main._play(1); main._pause(true)]]
	for sc in screens:
		sc[1].call()
		for s in SIZES:
			get_window().size = s
			await _settle()
			if get_window().size != s:
				push_warning("window is %s, not %s" % [get_window().size, s])
			_save(dir, sc[0], s)
		get_tree().paused = false
	preload("res://src/sfx.gd").quit()


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(dir: String, name: String, s: Vector2i) -> void:
	var w := get_window()
	print("%s %dx%d: k %.3f, canvas %s" % [name, s.x, s.y, w.content_scale_factor, w.get_visible_rect().size])
	w.get_texture().get_image().save_png("%s/%s_%dx%d.png" % [dir, name, s.x, s.y])
