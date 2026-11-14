class_name Main
extends Node
## The root of the game. It is never unloaded, so bloom, the CRT and the music are set up once.
##
## NAVIGATION. Screens move between each other only through the static functions here:
##     Main.show_menu()  Main.show_settings()  Main.show_hub()  Main.show_level(n)  Main.quit()
## Main swaps the one child of Screen between the main menu, Settings and Play; Play (play.gd) switches between
## the Hub and a Level. A scene run on its own, without Main, can still call them: they do nothing.
##
## BACK. Every screen but the main menu has a way back, and each screen handles its own: a back icon button, and
## `ui_cancel` (Esc) in its _unhandled_input. The handler calls get_viewport().set_input_as_handled() before it
## navigates: Main.show_hub() wakes the Hub while the same event is still being handed out, so without that call
## one Esc in a level goes on through the Hub to the main menu.
##     Settings -> Main.show_menu()        the Hub -> Main.show_menu()
##     a Level in Setup or in the Summary -> Main.show_hub()        a Level in Play: nothing, a round runs out
## Leaving loses nothing: a purchase and a layout change are saved when they happen.
##
## THE RENDER CHAIN (measured in the render spike, see docs/architecture.md "Rendering"):
##     Main
##     ├─ View              a SubViewport with HDR 2D on. The whole game draws in here, at 1280 x 720 coordinates
##     │   ├─ Backdrop      the base colour
##     │   ├─ Screen        holds the current screen; carries the theme
##     │   └─ WorldEnvironment   the bloom
##     └─ Crt               shows View's picture through assets/shaders/crt.gdshader
## The Crt pass always runs, CRT setting on or off: View's picture is linear and holds values over 1, and the
## shader is what brings them back into range and converts to sRGB. Never hide Crt or drop its material.
##
## Rules for everything drawn inside View:
##   - A lit colour is Palette.lit(colour). Nothing else glows.
##   - Stay on canvas layer 0. A CanvasLayer above 0 is drawn after bloom and does not glow.
##   - Mouse positions are already corrected for the CRT's curve: Main pushes every input event into View with
##     the position moved the way the shader moves the picture. Use get_local_mouse_position() and the event's
##     position as usual. Main also tells View when the pointer enters and leaves the window, which is what
##     makes a control's tooltip_text appear.
##   - A tooltip costs a key press. While one shows, Godot spends the next key on closing it and no screen gets
##     that key: Esc on a hovered back button first closes "Back", and the second Esc goes back. So give
##     tooltip_text only to controls nobody presses keys over, and none to anything on screen during Play.

const FRAME := Vector2(1280, 720)
const MENU := "res://src/menu/main_menu.tscn"
const SETTINGS := "res://src/menu/settings.tscn"
const PLAY := "res://src/play.tscn"

## Glow level weights at a 720-pixel-high window, most local level first.
const GLOW_LEVELS: Array[float] = [1.0, 0.35]
const GLOW := 0.06  ## glow_intensity at rest. Palette's lit boosts were tuned at this value
const GLOW_MAX := 0.18  ## at set_bloom(1). From about 0.2 the 2 px gaps between bricks fill in
const GLOW_MAX_CALM := 0.09  ## the same with reduce flashing on

static var _it: Main

var _bloom := 0.0

@onready var view: SubViewport = $View
@onready var screen: Control = $View/Screen
@onready var crt: TextureRect = $Crt
@onready var env: Environment = $View/WorldEnvironment.environment


static func show_menu() -> void:
	if _it:
		_it._show(MENU)


static func show_settings() -> void:
	if _it:
		_it._show(SETTINGS)


## Opens the upgrade screen. From a level, this frees the level.
static func show_hub() -> void:
	if _it:
		(_it._show(PLAY) as Play).show_hub()


## Opens level `number` in Setup and returns the level scene's root (see play.gd for what it has), or null when
## there is no Main. The caller checks Progress.is_unlocked first.
static func show_level(number: int) -> Control:
	return (_it._show(PLAY) as Play).show_level(number) if _it else null


static func quit() -> void:
	if _it:
		_it.get_tree().quit()


## How strong the bloom is, from 0 (at rest) to 1 (the top of a combo). Effects call this as the combo climbs
## and nothing else touches the Environment. Reduce flashing lowers what 1 means. It goes back to 0 whenever the
## screen changes.
static func set_bloom(t: float) -> void:
	if _it:
		_it._bloom = clampf(t, 0.0, 1.0)
		_it._apply()


func _enter_tree() -> void:
	_it = self


func _exit_tree() -> void:
	if _it == self:
		_it = null


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.BASE)
	($View/Backdrop as ColorRect).color = Palette.BASE
	screen.theme = UiTheme.build()
	crt.texture = view.get_texture()
	view.notification(NOTIFICATION_VP_MOUSE_ENTER)  # the window may open under the pointer, with no enter event
	get_window().size_changed.connect(_fit)
	Settings.changed.connect(_apply)
	_fit()
	_apply()
	Sfx.start_music()
	show_menu()


## Makes `path` the screen and returns it. If it already is, it is kept as it is.
func _show(path: String) -> Node:
	var now := screen.get_child(0) if screen.get_child_count() else null
	if now and now.scene_file_path == path:
		return now
	if now:
		screen.remove_child(now)
		now.queue_free()
	set_bloom(0.0)
	var next: Node = (load(path) as PackedScene).instantiate()
	screen.add_child(next)
	return next


## Applies the settings Main owns: the CRT flag and the bloom's strength.
func _apply() -> void:
	(crt.material as ShaderMaterial).set_shader_parameter("enabled", Settings.crt)
	env.glow_intensity = lerpf(GLOW, GLOW_MAX_CALM if Settings.reduce_flashing else GLOW_MAX, _bloom)


## View renders at the window's real pixels and keeps 1280 x 720 coordinates inside, so text stays sharp.
func _fit() -> void:
	var scale := get_viewport().get_final_transform().get_scale()  # window pixels per frame pixel, after letterboxing
	view.size = Vector2i((FRAME * scale).round())
	# Glow blurs in window pixels and each level is twice as wide as the one before, so the weights move up one
	# level for every doubling of the window. That keeps halos about the same size on the 1280 x 720 frame.
	var shift := maxf(log(scale.y) / log(2.0), 0.0)
	var w := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
	for i in GLOW_LEVELS.size():
		var at := minf(i + shift, 6.0)
		w[int(at)] += GLOW_LEVELS[i] * (1.0 - fmod(at, 1.0))
		w[int(at) + 1] += GLOW_LEVELS[i] * fmod(at, 1.0)
	for i in 7:
		env.set_glow_level(i, w[i])


## Where on the game picture the screen point p looks: the same formula as warp() in crt.gdshader.
func _warp(p: Vector2) -> Vector2:
	var m := crt.material as ShaderMaterial
	if not m.get_shader_parameter("enabled"):
		return p
	var k: float = m.get_shader_parameter("curve")
	var d := p / FRAME - Vector2(0.5, 0.5)
	return (Vector2(0.5, 0.5) + d * (1.0 + k * d.dot(d)) / (1.0 + k * 0.25)) * FRAME


## View is not in a SubViewportContainer, so nothing reaches it unless it is pushed here.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		event = event.duplicate()
		event.position = _warp(event.position)
		event.global_position = event.position
	view.push_input(event, true)


## View never learns by itself whether the pointer is over it, and it shows no tooltip until it is told so.
func _notification(what: int) -> void:
	if view == null:
		return
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		view.notification(NOTIFICATION_VP_MOUSE_ENTER)
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		var away := InputEventMouseMotion.new()  # clears hover when the pointer leaves the window
		away.position = Vector2(-1000, -1000)
		away.global_position = away.position
		view.push_input(away, true)
		view.notification(NOTIFICATION_VP_MOUSE_EXIT)
