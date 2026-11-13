class_name Play
extends Control
## The play scene: the Hub and, while one is being played, a Level. Screens do not call this; they call
## Main.show_hub() and Main.show_level(n).
##
## What the two entry scenes can rely on:
##   HUB    is made once and lives as long as Play, so the web keeps its pan and zoom. While a level is open it is
##          hidden and its processing is off. It learns what changed from Progress's signals and from its own
##          visibility_changed.
##   LEVEL  is made new for every visit and freed on the way back to the hub. Retry stays inside the level
##          scene. Its root script has these four members, and tests, shots and the effects rely on them:
##            var level: int     Set here before the scene enters the tree, so _ready can read it.
##            var round: Round   The round on screen: the one Setup shows, then the one Play steps, then the
##                               one the Summary reports. Never null once _ready has run.
##            var fx: Fx         Its Fx node (src/level/fx/fx.gd).
##            func start(seed := -1) -> void
##                               What the Start button does: builds the round from the layout as it is now and
##                               goes from Setup to Play. -1 keeps the seed Setup is showing, which the level
##                               screen picked at random; any other value builds the round with that seed, so a
##                               test or a shot gets the same special bricks every time. Does nothing outside
##                               Setup. It is done when it returns: `round` is then the round Play steps, and
##                               fx.watch(round) and Sfx.connect_round(round) have been called. Nothing waits
##                               for a later frame or a countdown.

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


## Returns the new level's root.
func show_level(number: int) -> Control:
	_drop_level()
	_hub.hide()
	_hub.process_mode = Node.PROCESS_MODE_DISABLED
	_level = (load(LEVEL) as PackedScene).instantiate()
	_level.set("level", number)
	add_child(_level)
	return _level


func _drop_level() -> void:
	if _level:
		remove_child(_level)
		_level.queue_free()
		_level = null
