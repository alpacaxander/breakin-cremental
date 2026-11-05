extends Node
## Swaps between the shop and a round.

func _ready() -> void:
	_show_shop()


func _show_shop() -> void:
	var s = preload("res://src/shop.gd").new()
	s.play.connect(_play)
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
