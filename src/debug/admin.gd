class_name Admin
extends Node
## A testing panel: ` (backtick) opens and closes it. Main adds it in debug builds only, so an exported release
## has none. It is a Window embedded in the root viewport, outside View: it is drawn over the CRT with Godot's
## default theme, and an embedded window takes the input under it before Main pushes anything into View.
##
## Every change goes straight to Progress and is saved, and Progress's signals tell the screens: coins_changed for
## coins, rank_changed for each upgrade, level_unlocked for the levels (the hub redraws on all three).
## The panel is rebuilt from Progress every time it opens.
##
## Upgrades are owned as web nodes (HubWeb.own), so the hub shows what the rules use: a count of r for an upgrade
## owns its first r nodes in web.tscn's order and drops its others. A debug tool, so they need not hang together
## from the seed; the hub's undo ("still joined to the seed") may then refuse. Nor are keys checked: owning a key
## node with no level cleared shows a negative key count.

const KEY := KEY_QUOTELEFT
## The web nodes the balance bot's average player owns on reaching each level (and after clearing the last), in
## the order it bought them, with `unlocked` to match: from `tests/run.sh bot campaign skill=average` (key=zap) on
## 2026-11-24, levels cleared on rounds 3, 9 and 29; each list holds what was bought up to and on that round.
## Applying one replaces every owned node and leaves the coins alone; the keys come out at 0.
# ponytail: copied by hand from tests/out/bot/campaign.json's purchases. Rerun the campaign and recopy after tuning.
const PRESETS := {
	"Level 1": {"unlocked": 1, "owned": []},
	"Level 2": {"unlocked": 2, "owned": [&"PaddleSpeed", &"Combo", &"Booster", &"PaddleSize", &"ToughBrick",
			&"PowerBrick", &"Zap", &"HourglassBrick", &"Guide"]},
	"Level 3": {"unlocked": 3, "owned": [&"PaddleSpeed", &"Combo", &"Booster", &"PaddleSize", &"ToughBrick",
			&"PowerBrick", &"Zap", &"HourglassBrick", &"Guide", &"GoldBrick", &"ComboWindow", &"WallSegment",
			&"PaddleSize2", &"Booster2", &"Blast", &"Splitter", &"PowerBrick2", &"Growth", &"Guide2"]},
	"Cleared": {"unlocked": 4, "owned": [&"PaddleSpeed", &"Combo", &"Booster", &"PaddleSize", &"ToughBrick",
			&"PowerBrick", &"Zap", &"HourglassBrick", &"Guide", &"GoldBrick", &"ComboWindow", &"WallSegment",
			&"PaddleSize2", &"Booster2", &"Blast", &"Splitter", &"PowerBrick2", &"Growth", &"Guide2", &"PaddleSpeed2",
			&"ToughBrick2", &"BlastSize", &"GoldBrick2", &"Splitter2", &"GuideBounces", &"Multiball", &"RearPaddle",
			&"GrowthReach", &"BlastDamage", &"PaddleSize3", &"ZapRange", &"Guide3", &"BoosterSpeed", &"ComboWindow2",
			&"Shockwave", &"PowerBrick4", &"ToughBrick3", &"Growth2", &"WallSegment2", &"Splitter3", &"Overgrowth",
			&"ZapDamage", &"HourglassFreeze", &"GrowthPulses", &"GoldBrick3"]},
}

var _win := Window.new()
var _coins: Label  # made by _build
var _web: HubWeb = (load(HubWeb.SCENE) as PackedScene).instantiate()  # never in the tree: asked for its nodes


func _exit_tree() -> void:
	_web.free()


func _ready() -> void:
	_win.title = "Admin"
	_win.position = Vector2i(16, 40)
	_win.size = Vector2i(440, 640)
	_win.visible = false
	_win.close_requested.connect(_win.hide)
	_win.window_input.connect(_toggle)  # while it has the focus, keys go to it and never reach _input
	add_child(_win)
	for s: Signal in [Progress.coins_changed, Progress.rank_changed, Progress.level_unlocked]:
		s.connect(_show_counts.unbind(1))


func _show_counts() -> void:
	if _coins:
		_coins.text = "Coins: %d   Keys: %d" % [Progress.coins, Progress.keys()]


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
	_show_counts()
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
			_own(Progress.owned + _names(func(n: HubNode) -> bool: return n.upgrade.category == Upgrade.Category.ABILITIES))))

	# Upgrades
	box.add_child(HSeparator.new())
	var all := HBoxContainer.new()
	box.add_child(all)
	all.add_child(_button("Max all", func() -> void: _own(_names(func(_n: HubNode) -> bool: return true))))
	all.add_child(_button("Clear all", func() -> void: _own([])))
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	for u in Progress.upgrades():
		var title := Label.new()
		title.text = u.title
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(title)
		grid.add_child(_spin(Progress.rank(u), 0, u.max_rank, _set_rank.bind(u)))
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


## Owns u's first r nodes and none of its others; every other node stays as it is.
func _set_rank(r: int, u: Upgrade) -> void:
	if r == Progress.rank(u):
		return
	var others := Progress.owned.filter(func(id: StringName) -> bool:
		var n := _web.get_node_or_null(NodePath(String(id))) as HubNode
		return n and n.upgrade != u)
	_own(others + _names(func(n: HubNode) -> bool: return n.upgrade == u).slice(0, r))


## The names of the web's nodes that pass `keep`, in scene order.
func _names(keep: Callable) -> Array:
	return _web.nodes().filter(keep).map(func(n: HubNode) -> StringName: return n.name)


## Owns exactly the nodes named (HubWeb.own), saves, tells the screens, and redraws the panel so its spin boxes
## match: not now, as the button pressed may be one of the children _build frees.
func _own(names: Array) -> void:
	_web.own(names)
	Progress.save()
	for u in Progress.upgrades():
		Progress.rank_changed.emit(u)
	if _win.visible:
		_build.call_deferred()


## Replaces every owned node and `unlocked` with a preset's.
func _apply(preset: Dictionary) -> void:
	Progress.unlocked = preset.unlocked  # first, so the keys shown on rank_changed count the levels cleared
	_own(preset.owned)
	_set_unlocked(preset.unlocked)


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
