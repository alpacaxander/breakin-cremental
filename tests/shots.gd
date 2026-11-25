extends Node
## The screenshot harness. It boots the real Main in a window on a virtual display and saves what a player would
## see, bloom and CRT included. Run it with: tests/run.sh shots            (every list)
##                                           tests/run.sh shots hub fx     (only those lists)
## PNGs go to tests/out/shots/<list>/<name>.png, a folder git and Godot's importer both ignore.
## It cannot run with --headless: that renders nothing.
##
## ADDING SHOTS. Each lane adds one file, tests/shots/<lane>.gd, and never edits this one or another lane's
## list. A list is a script with one function that returns the shots to take:
##
##     extends RefCounted
##     func shots() -> Array[Dictionary]:
##         return [
##             {"name": "hub_fresh"},
##             {"name": "hub_maxed", "save": "maxed", "setup": func(_main: Main) -> void: Main.show_hub()},
##             {"name": "blast", "setup": _blast, "settle": 0, "frames": 6, "every": 3},
##         ]
##
## A shot is a Dictionary. Only "name" is needed:
##   name    the file name, without .png
##   save    the save to start from: "fresh" (the default), "mid" or "maxed". See _seed
##   crt     the CRT setting. Default true
##   calm    the reduce flashing setting. Default false
##   size    the window size. Default Vector2i(1280, 720)
##   setup   a Callable taking the Main node, run once the state above is in place and Main shows a new main
##           menu. It may await. Use it to navigate (Main.show_level(1)), to change Progress or Settings further,
##           or to reach into the screen: main.screen.get_child(0) is the current screen, and Main.show_level(n)
##           returns the level's root, which has `round`, `fx` and `start(seed)` (see src/play.gd)
##   settle  frames to wait after setup before the first capture. Default 4. Use 0 when setup has just set off
##           an effect
##   frames  how many pictures to take. Default 1. More than one makes a strip: <name>_00.png, <name>_01.png, ...
##   every   for a strip, frames from one capture to the next: with 4, three frames go by unseen. Default 1
## Godot runs at a fixed 60 frames a second here, so a strip covers the same game time on any machine.
##
## Every shot starts from its own save and settings files under tests/out/, never from user://.

const LISTS := "res://tests/shots"
const OUT := "res://tests/out/shots"
const KEYS := ["name", "save", "crt", "calm", "size", "setup", "settle", "frames", "every"]

var _taken := 0


func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Progress.use(OUT.path_join("save.json"))
	Settings.use(OUT.path_join("settings.cfg"))
	var main: Main = (load("res://src/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var files := Array(DirAccess.get_files_at(LISTS)).filter(func(f: String) -> bool: return f.ends_with(".gd"))
	files.sort()
	for file: String in files:
		var list := file.get_basename()
		if not only.is_empty() and not list in only:
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.path_join(list)))
		var lane: RefCounted = (load(LISTS.path_join(file)) as GDScript).new()  # kept in a variable so the setups it hands out stay alive
		for shot: Dictionary in lane.shots():
			await _take(main, list, shot)
	print("%d picture(s) in %s" % [_taken, ProjectSettings.globalize_path(OUT)])
	get_tree().quit()


func _take(main: Main, list: String, shot: Dictionary) -> void:
	for key: String in shot:
		assert(key in KEYS, "%s: a shot has no key \"%s\"" % [list, key])
	_seed(shot.get("save", "fresh"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT.path_join("settings.cfg")))  # Settings saves on every change, so the last shot's file is there
	Settings.use(OUT.path_join("settings.cfg"))
	Settings.crt = shot.get("crt", true)
	Settings.reduce_flashing = shot.get("calm", false)
	get_window().size = shot.get("size", Vector2i(1280, 720))
	for child in main.screen.get_children():  # a new menu, so no shot sees what the one before left behind
		child.free()
	Main.show_menu()
	if shot.has("setup"):
		@warning_ignore("redundant_await")
		await (shot.setup as Callable).call(main)
	for i: int in shot.get("settle", 4):
		await get_tree().process_frame
	var frames: int = shot.get("frames", 1)
	for i in frames:
		if i > 0:
			for j: int in shot.get("every", 1):  # the picture is taken as this last frame is drawn
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var file := "%s.png" % shot.name if frames == 1 else "%s_%02d.png" % [shot.name, i]
		var path := ProjectSettings.globalize_path(OUT.path_join(list).path_join(file))
		get_viewport().get_texture().get_image().save_png(path)
		print(path)
		_taken += 1


## Puts Progress on a new save file under tests/out/ and fills it in memory:
##   fresh  0 coins, no upgrades, level 1 only
##   mid    250 coins, level 2 unlocked, the first half of the web's nodes bought (HubWeb.own_first)
##   maxed  99999 coins, every level unlocked, every web node bought: every upgrade at its top rank
## A setup may change Progress further before it navigates.
func _seed(save: String) -> void:
	var path := OUT.path_join("save.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Progress.use(path)
	assert(save in ["fresh", "mid", "maxed"], "a shot's save is fresh, mid or maxed, not \"%s\"" % save)
	if save == "fresh":
		return
	var top := save == "maxed"
	Progress.coins = 99999 if top else 250
	Progress.unlocked = maxi(1, Levels.count() if top else mini(2, Levels.count()))
	var nodes := 0
	for u in Progress.upgrades():
		nodes += u.max_rank
	HubWeb.own_first(nodes if top else ceili(nodes / 2.0))
