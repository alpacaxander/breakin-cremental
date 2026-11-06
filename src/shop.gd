extends Control
## Between rounds: upgrade web and level select.

signal play(level: int)
signal menu

const Tuning = preload("res://src/tuning.gd")
const BTN := Vector2(180, 64)


func _ready() -> void:
	size = Tuning.VIEW
	_build()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		menu.emit()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var top := Label.new()
	top.text = "$%d" % Game.currency + ("        YOU WIN! Keep playing if you like." if Game.won else "")
	top.position = Vector2(16, 12)
	top.add_theme_font_size_override("font_size", 24)
	add_child(top)
	_button("Menu (Esc)", Vector2(1150, 12)).pressed.connect(menu.emit)

	for id in Tuning.UPGRADES:
		if not Game.is_revealed(id):
			continue
		var u: Dictionary = Tuning.UPGRADES[id]
		var maxed: bool = Game.rank(id) >= u.ranks
		var b := _button("%s\n%d/%d   %s" % [u.name, Game.rank(id), u.ranks, "MAX" if maxed else "$%d" % Game.cost(id)], u.pos - BTN / 2)
		b.custom_minimum_size = BTN
		b.tooltip_text = u.desc
		b.disabled = not Game.can_buy(id)
		b.pressed.connect(_buy.bind(id))

	for i in Game.unlocked + 1:
		_button("Play level %d" % (i + 1), Vector2(16 + i * 160, 640)).pressed.connect(play.emit.bind(i))
	# ponytail: instant wipe, no confirm. It's a tuning tool.
	_button("Reset save", Vector2(1150, 640)).pressed.connect(func(): Game.reset(); _build())
	queue_redraw()


func _button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	return b


func _buy(id: String) -> void:
	Game.buy(id)
	Game.save()
	_build()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Tuning.COLORS.bg)
	draw_rect(Rect2(0, 0, size.x, Tuning.HUD_HEIGHT + 8), Tuning.COLORS.trim)
	for id in Tuning.UPGRADES:
		if not Game.is_revealed(id):
			continue
		for l in Tuning.UPGRADES[id].links:
			if Game.is_revealed(l):
				draw_line(Tuning.UPGRADES[id].pos, Tuning.UPGRADES[l].pos, Tuning.COLORS.line, 3)
