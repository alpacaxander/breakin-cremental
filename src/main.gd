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
	_show_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Sfx.quit()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)  # else the cursor texture outlives the renderer and logs a leak at quit


func _show_menu() -> void:
	var r := Ui.chassis("RECORD", "MENU")
	Sfx.loop(r, "lamp_hum")
	var rows := ["BEST $%s" % Ui.money(Game.best), "RUNS %d" % Game.runs, "LEVEL %d" % (Game.unlocked + 1), "YOU WIN!" if Game.won else ""]
	for i in rows.size():
		Ui.label(r, rows[i], 6, 22 + i * 10, Tuning.COLORS.white if i == 0 else Tuning.COLORS.rivet)
	Ui.bulbs(r, 4)
	var logo := Ui.tex("title_logo")
	Ui.icon(r, logo, 320 - logo.get_width() / 2, 110)
	Ui.centre(r, "BUILD THE BOARD. BREAK THE BOARD.", 300, Tuning.COLORS.rivet)
	for i in 6:
		Ui.icon(r, "brick_plain_lit" if i % 3 == 0 else "brick_plain_dim", 230 + i * 32, 330)
	Ui.button(r, "PLAY", Ui.RX + 6, 22, 66, 18, _show_shop, true, 2, "ui_start")
	Ui.button(r, "SETTINGS", Ui.RX + 6, 46, 66, 18, func(): _swap(Ui.settings(_show_menu)), false, 1)
	Ui.button(r, "QUIT", Ui.RX + 6, 70, 66, 18, Sfx.quit, false, 1, "")
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
	_swap(a)


func _swap(n: Node) -> void:
	for c in get_children():
		c.queue_free()
	add_child(n)
