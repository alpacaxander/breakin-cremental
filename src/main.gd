extends Node
## Swaps between the main menu, the shop and a round. The shop and a round form the play group: Esc in either opens the one
## pause dialog (RESUME / SETTINGS / MENU), and MENU drops whatever is up and returns to the menu, so a live round is
## abandoned with no result. Movement inside the group is the cabinet columns' buttons.

const Ui = preload("res://src/ui.gd")
const Tuning = preload("res://src/tuning.gd")
const Sfx = preload("res://src/sfx.gd")


var zoom := 0.0  # the cabinet's scale k: a sprite px is 2k screen px
var group := false  # in the shop or a round: Esc pauses
var pause: Control = null


func _ready() -> void:
	get_tree().auto_accept_quit = false  # the window's close button goes through Sfx.quit too
	get_window().size_changed.connect(_scale)
	_scale()
	_show_menu()


## The scale at which 1280x720 just fits, with the canvas covering the whole window: the cabinet grows with the window and
## the padding beside the columns is drawn sheet, not bars. Godot's own stretch modes letterbox instead. Below 1280x720
## (a tiling window manager ignores any minimum size) the canvas keeps its 720 height, so the 2x columns always fit, and
## Ui.Root.content shrinks the field to the width left between them. The cursor follows: it is in screen px, not sprite px.
func _scale() -> void:
	var w := get_window()
	var k := minf(w.size.y / 720.0, maxf(1, w.size.x / 1280.0))
	if k == zoom:
		return
	zoom = k
	w.content_scale_factor = k
	var cursor := Ui.tex("ui_cursor").get_image()
	cursor.resize(roundi(16 * k), roundi(16 * k), Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(cursor))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Sfx.quit()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)  # else the cursor texture outlives the renderer and logs a leak at quit


func _show_menu() -> void:
	group = false
	if Game.sandbox:
		Game.leave_sandbox()
	var r := Ui.chassis()
	Sfx.loop(r, "lamp_hum")
	Ui.bulbs(r, 4)
	var logo := Ui.tex("title_logo")
	Ui.icon(r, logo, 320 - logo.get_width() / 2, 50)
	# Logo above a pause-sized card of stacked buttons, the record as one caption line beneath.
	Ui.panel(r, 240, 140, 160, 106)
	Ui.button(r, "PLAY", 260, 150, 120, 18, _show_shop, true, 2, "ui_start")
	Ui.button(r, "SANDBOX", 260, 174, 120, 18, func(): Game.enter_sandbox(); _show_shop(), false, 2, "ui_start")
	Ui.button(r, "SETTINGS", 260, 198, 120, 18, func(): _swap(Ui.settings(_show_menu)))
	Ui.button(r, "QUIT", 260, 222, 120, 18, Sfx.quit, false, 2, "")
	var record := "BEST $%s   RUNS %d   LEVEL %d" % [Ui.money(Game.best), Game.runs, Game.unlocked + 1]
	Ui.centre(r, record + ("   YOU WIN!" if Game.won else ""), 256, Tuning.COLORS.rivet)
	Ui.centre(r, "BUILD THE BOARD. BREAK THE BOARD.", 300, Tuning.COLORS.rivet)
	for i in 6:
		Ui.icon(r, "brick_plain_lit" if i % 3 == 0 else "brick_plain_dim", 230 + i * 32, 330)
	_swap(r)


func _show_shop() -> void:
	var s = preload("res://src/shop.gd").new()
	s.play.connect(_play)
	group = true
	_swap(s)


func _play(level: int) -> void:
	var a = preload("res://src/arena.gd").new()
	a.level = level
	a.done.connect(_show_shop)
	a.again.connect(_play.bind(level))
	group = true
	_swap(a)


func _swap(n: Node) -> void:
	_pause(false)
	for c in get_children():
		c.queue_free()
	add_child(n)


# --- Pause ---

## Screens with their own Esc (settings, the pause dialog itself) take it first through Ui.Root.back; the rest falls through here.
func _unhandled_input(e: InputEvent) -> void:
	if group and not pause and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		_pause(true)


func _pause(on: bool) -> void:
	if on != get_tree().paused:
		Sfx.play("ui_pause" if on else "ui_unpause")
	get_tree().paused = on
	if pause:
		pause.queue_free()
		pause = null
	if not on:
		return
	pause = Ui.dialog("PAUSED", [["RESUME", true, _pause.bind(false)], ["SETTINGS", false, _pause_settings], ["MENU", false, _abandon]])
	pause.back.connect(_pause.bind(false))
	add_child(pause)


func _pause_settings() -> void:
	Sfx.play("ui_click")
	pause.queue_free()
	pause = Ui.settings(_pause.bind(true))  # Back rebuilds the pause menu
	add_child(pause)


## Straight to the menu: a live round ends with no result and does not count as a run; what it paid out so far is kept.
func _abandon() -> void:
	Game.save()
	_show_menu()
