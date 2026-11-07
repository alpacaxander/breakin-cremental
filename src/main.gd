extends Node
## Swaps between the main menu, the shop and a round.

const Ui = preload("res://src/ui.gd")
const Tuning = preload("res://src/tuning.gd")
const Sfx = preload("res://src/sfx.gd")


func _ready() -> void:
	var cursor := Ui.tex("ui_cursor").get_image()
	cursor.resize(16, 16, Image.INTERPOLATE_NEAREST)  # the cursor is in screen px, not sprite px
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(cursor))
	get_tree().auto_accept_quit = false  # the window's close button goes through Sfx.quit too
	get_window().min_size = Vector2i(1280, 720)  # the field between the columns must always hold Tuning.ARENA
	_show_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Sfx.quit()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)  # else the cursor texture outlives the renderer and logs a leak at quit


func _show_menu() -> void:
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
	s.menu.connect(_show_menu)
	_swap(s)


func _play(level: int) -> void:
	var a = preload("res://src/arena.gd").new()
	a.level = level
	a.done.connect(_show_shop)
	a.again.connect(_play.bind(level))
	_swap(a)


func _swap(n: Node) -> void:
	for c in get_children():
		c.queue_free()
	add_child(n)
