class_name Play
extends Control
## The play scene: the Hub and, while one is being played, a Level. Screens do not call this; they call
## Main.show_hub() and Main.show_level(n).
##
## What the two entry scenes can rely on:
##   HUB    is made once and lives as long as Play, so the web keeps its pan and zoom. While a level is open it is
##          hidden and its processing is off. It learns what changed from Progress's signals and from its own
##          visibility_changed.
##   LEVEL  is made new for every visit and freed on the way back to the hub. Its root has a property
##          `level: int`, which is set before the scene enters the tree, so _ready can read it. Retry stays
##          inside the level scene.

const HUB := "res://src/hub/hub.tscn"
const LEVEL := "res://src/level/level.tscn"

var _hub: Control
var _level: Control


func _ready() -> void:
	_hub = (load(HUB) as PackedScene).instantiate()
	add_child(_hub)


func show_hub() -> void:
	_drop_level()
	Main.set_bloom(0.0)
	_hub.process_mode = Node.PROCESS_MODE_INHERIT
	_hub.show()


func show_level(number: int) -> void:
	_drop_level()
	_hub.hide()
	_hub.process_mode = Node.PROCESS_MODE_DISABLED
	_level = (load(LEVEL) as PackedScene).instantiate()
	_level.set("level", number)
	add_child(_level)


func _drop_level() -> void:
	if _level:
		remove_child(_level)
		_level.queue_free()
		_level = null
