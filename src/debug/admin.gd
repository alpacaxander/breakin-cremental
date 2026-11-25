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
## The ranks the balance bot's average player owns on reaching each level (and after clearing the last), with
## `unlocked` to match: from `tests/run.sh bot campaign skill=average` on 2026-11-24 (levels cleared on rounds
## 3, 9 and 19). Applying one replaces every rank and leaves the coins alone.
# ponytail: copied by hand from tests/out/bot/campaign.json's purchases. Rerun the campaign and recopy after tuning.
const PRESETS := {
	"Level 1": {"unlocked": 1, "ranks": {}},
	"Level 2": {"unlocked": 2, "ranks": {&"booster": 1, &"combo": 1, &"gold_brick": 1, &"hourglass_brick": 1,
			&"paddle_size": 1, &"paddle_speed": 1, &"power_brick": 1, &"tough_brick": 1}},
	"Level 3": {"unlocked": 3, "ranks": {&"blast": 1, &"blast_size": 1, &"booster": 2, &"combo": 1, &"combo_window": 1,
			&"gold_brick": 2, &"growth": 1, &"guide": 2, &"hourglass_brick": 1, &"paddle_size": 2, &"paddle_speed": 2,
			&"power_brick": 2, &"splitter": 1, &"tough_brick": 2, &"wall_segment": 1, &"zap": 1}},
	"Cleared": {"unlocked": 4, "ranks": {&"blast": 1, &"blast_size": 1, &"booster": 2, &"booster_speed": 1,
			&"combo": 1, &"combo_window": 2, &"explosion_damage": 1, &"gold_brick": 2, &"growth": 2, &"growth_reach": 1,
			&"guide": 3, &"guide_bounces": 1, &"hourglass_brick": 1, &"multiball": 1, &"paddle_size": 3,
			&"paddle_speed": 2, &"power_brick": 3, &"rear_paddle": 1, &"shockwave": 1, &"splitter": 3,
			&"tough_brick": 3, &"wall_segment": 2, &"zap": 1, &"zap_range": 1}},
}

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

	# Presets
	box.add_child(HSeparator.new())
	var presets := HBoxContainer.new()
	box.add_child(presets)
	var preset_label := Label.new()
	preset_label.text = "Bot at"
	presets.add_child(preset_label)
	for preset_name: String in PRESETS:
		presets.add_child(_button(preset_name, func() -> void: _apply(PRESETS[preset_name])))

	# The test level (levels/level_0.tscn): painted Power Bricks, so drops come at any rank
	if Levels.read(0):
		var test := HBoxContainer.new()
		box.add_child(test)
		test.add_child(_button("Play the test level", func() -> void:
			_win.hide()
			Main.show_level(0)))
		test.add_child(_button("Max abilities", func() -> void:
			for u in Progress.upgrades():
				if u.category == Upgrade.Category.ABILITIES:
					_set_rank(u.max_rank, u)
			_build.call_deferred()))

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


## Replaces every rank and `unlocked` with a preset's, then redraws the panel so its spin boxes match.
func _apply(preset: Dictionary) -> void:
	Progress.ranks.assign(preset.ranks)
	for u in Progress.upgrades():
		Progress.rank_changed.emit(u)
	_set_unlocked(preset.unlocked)  # saves
	_build.call_deferred()  # not now: the button pressed is one of the children _build frees


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
