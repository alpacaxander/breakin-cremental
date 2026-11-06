extends Node
## Swaps between the main menu, the shop and a round.

const Ui = preload("res://src/ui.gd")


func _ready() -> void:
	_show_menu()


func _show_menu() -> void:
	_swap(Ui.screen("Breakin' Cremental", [
		Ui.button("Play", _show_shop),
		Ui.button("Settings", func(): _swap(Ui.settings(_show_menu))),
		Ui.button("Quit", get_tree().quit),
	]))


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
