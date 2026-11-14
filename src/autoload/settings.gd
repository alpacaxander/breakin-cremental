extends Node
## Autoload `Settings`: the four settings, kept apart from the save.
##
## The file is a ConfigFile at `path`, section "settings", one key per property below. It is loaded at start and
## by use(), and written on every change. A key that is missing or holds the wrong type keeps its default.
##
## Who reacts to what: Main applies `crt` and the bloom cap of `reduce_flashing`. Effects read `reduce_flashing`
## themselves. This script sets the volume of the BUS_MUSIC and BUS_SOUND buses from the two volumes
## (AudioServer.set_bus_volume_linear), so nothing else touches a bus. It does so on every change and in use().
## The check that a volume reaches its bus is in the state lane's case; Sfx only picks which bus a player is on.

## A setting changed, or use() loaded another file.
signal changed

## The audio buses in default_bus_layout.tres. Both feed Master, which has the limiter.
const BUS_MUSIC := &"Music"
const BUS_SOUND := &"Sfx"
const SECTION := "settings"
const KEYS: Array[StringName] = [&"crt", &"reduce_flashing", &"music_volume", &"sound_volume"]

## Where the settings file is. Change it with use(), never directly.
var path := "user://settings.cfg"
## The CRT filter. On by default.
var crt := true:
	set(v):
		crt = v
		_changed()
## Reduce flashing: no light pools or screen flashes, and bloom is capped.
var reduce_flashing := false:
	set(v):
		reduce_flashing = v
		_changed()
## 0 to 1, linear. The music plays quieter than the sounds by default.
var music_volume := 0.5:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		_changed()
## 0 to 1, linear.
var sound_volume := 0.8:
	set(v):
		sound_volume = clampf(v, 0.0, 1.0)
		_changed()

## True while use() sets the values, so it neither saves nor emits once per value.
var _loading := false


func _ready() -> void:
	use(path)


## Switches to another settings file: back to the defaults, then loads `new_path` if it exists. Tests and the
## screenshot harness call this with a path inside the checkout, so the real settings are never touched.
func use(new_path: String) -> void:
	path = new_path
	_loading = true
	crt = true
	reduce_flashing = false
	music_volume = 0.5
	sound_volume = 0.8
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(path) and cfg.load(path) == OK:
		for key in KEYS:
			var v: Variant = cfg.get_value(SECTION, key, get(key))
			# ponytail: an exact type match only, so a hand-edited `music_volume=1` (an int) is ignored.
			if typeof(v) == typeof(get(key)):
				set(key, v)
	_loading = false
	_apply()
	changed.emit()


## Writes the settings to `path`.
func save() -> void:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value(SECTION, key, get(key))
	var err := cfg.save(path)
	if err != OK:
		push_error("cannot write the settings to %s: %s" % [path, error_string(err)])


func _changed() -> void:
	if _loading:
		return
	_apply()
	save()
	changed.emit()


func _apply() -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(BUS_MUSIC), music_volume)
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(BUS_SOUND), sound_volume)
