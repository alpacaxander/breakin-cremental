class_name Admin
extends Node
## A testing panel: ` (backtick) opens and closes it. Main adds it in debug builds only, so an exported release
## has none. It is a Window embedded in the root viewport, outside View: it is drawn over the CRT with Godot's
## default theme, and an embedded window takes the input under it before Main pushes anything into View.
##
## Every change goes straight to Progress and is saved, and Progress's signals tell the screens: coins_changed for
## coins, rank_changed for each upgrade, level_unlocked for the levels (the hub redraws on all three).
## The panel is rebuilt from Progress every time it opens.

const KEY := KEY_QUOTELEFT

var _win := Window.new()
var _coins: Label  # made by _build


func _ready() -> void:
	_win.title = "Admin"
	_win.position = Vector2i(16, 40)
	_win.size = Vector2i(440, 640)
	_win.visible = false
	_win.close_requested.connect(_win.hide)
	_win.window_input.connect(_toggle)  # while it has the focus, keys go to it and never reach _input
	add_child(_win)
	Progress.coins_changed.connect(func(c: int) -> void:
		if _coins:
			_coins.text = "Coins: %d" % c)


func _input(event: InputEvent) -> void:
	_toggle(event)


func _toggle(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY:
		_win.visible = not _win.visible
		if _win.visible:
			_build()
		get_viewport().set_input_as_handled()


func _build() -> void:
	for child in _win.get_children():
		_win.remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_win.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	# Coins
	_coins = Label.new()
	_coins.text = "Coins: %d" % Progress.coins
	box.add_child(_coins)
	var row := HBoxContainer.new()
	box.add_child(row)
	for n: int in [100, 1000, 10000, 100000]:
		row.add_child(_button("+%d" % n, func() -> void: _add_coins(n)))
	row.add_child(_button("Zero", func() -> void: _add_coins(-Progress.coins)))

	# Levels
	box.add_child(HSeparator.new())
	var levels := HBoxContainer.new()
	box.add_child(levels)
	var label := Label.new()
	label.text = "Unlocked up to level (%d = all cleared)" % (Progress.level_count + 1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels.add_child(label)
	levels.add_child(_spin(Progress.unlocked, 1, Progress.level_count + 1, _set_unlocked))

	# Upgrades
	box.add_child(HSeparator.new())
	var spins: Array[SpinBox] = []
	var all := HBoxContainer.new()
	box.add_child(all)
	all.add_child(_button("Max all", func() -> void:
		for s in spins:
			s.value = s.max_value))
	all.add_child(_button("Clear all", func() -> void:
		for s in spins:
			s.value = 0))
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	for u in Progress.upgrades():
		var title := Label.new()
		title.text = u.title
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(title)
		var spin := _spin(Progress.rank(u), 0, u.max_rank, _set_rank.bind(u))
		spins.append(spin)
		grid.add_child(spin)
		var top := Label.new()
		top.text = "/ %d" % u.max_rank
		grid.add_child(top)


func _add_coins(n: int) -> void:
	Progress.coins += n
	Progress.save()


func _set_unlocked(n: int) -> void:
	Progress.unlocked = n
	Progress.save()
	# The hub's level panel shows the level it is given; a lowered `unlocked` needs the same redraw.
	Progress.level_unlocked.emit(mini(n, Progress.level_count))


func _set_rank(r: int, u: Upgrade) -> void:
	if r == Progress.rank(u):
		return
	if r > 0:
		Progress.ranks[u.id] = r
	else:
		Progress.ranks.erase(u.id)
	Progress.save()
	Progress.rank_changed.emit(u)


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b


func _spin(value: int, lo: int, hi: int, on_change: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = value
	s.value_changed.connect(func(v: float) -> void: on_change.call(int(v)))
	return s
