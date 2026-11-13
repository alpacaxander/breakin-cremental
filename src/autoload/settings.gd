extends Node
## Autoload `Settings`: the four settings, kept apart from the save.
##
## STUB: the state lane adds the file (a ConfigFile at `path`, section "settings", one key per property below),
## loading at start, saving on every change, and setting the two bus volumes. As shipped here the values live in
## memory only.
##
## Who reacts to what: Main applies `crt` and the bloom cap of `reduce_flashing`. Effects read `reduce_flashing`
## themselves. This script sets the volume of the BUS_MUSIC and BUS_SOUND buses from the two volumes
## (AudioServer.set_bus_volume_linear), so nothing else touches a bus.

## A setting changed, or use() loaded another file.
signal changed

## The audio buses in default_bus_layout.tres. Both feed Master, which has the limiter.
const BUS_MUSIC := &"Music"
const BUS_SOUND := &"Sfx"

## Where the settings file is. Change it with use(), never directly.
var path := "user://settings.cfg"
## The CRT filter. On by default.
var crt := true:
	set(v):
		crt = v
		changed.emit()
## Reduce flashing: no light pools or screen flashes, and bloom is capped.
var reduce_flashing := false:
	set(v):
		reduce_flashing = v
		changed.emit()
## 0 to 1, linear. The music plays quieter than the sounds by default.
var music_volume := 0.5:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		changed.emit()
## 0 to 1, linear.
var sound_volume := 0.8:
	set(v):
		sound_volume = clampf(v, 0.0, 1.0)
		changed.emit()


## Switches to another settings file: back to the defaults, then loads `new_path` if it exists. Tests and the
## screenshot harness call this with a path inside the checkout, so the real settings are never touched.
func use(new_path: String) -> void:
	path = new_path
	crt = true
	reduce_flashing = false
	music_volume = 0.5
	sound_volume = 0.8


## Writes the settings to `path`.
func save() -> void:
	pass
