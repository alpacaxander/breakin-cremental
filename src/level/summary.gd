class_name LevelSummary
extends Control
## The Summary (docs/design/overview.md, "Level phases"): how the round ended, whether the score reached the
## level's target, the tally by brick type, the hits that broke nothing, each combo's bonus, the coins it paid, and Retry (Next after a clear that has a level after it) and Upgrades. There is no mockup; it is a panel
## over the arena in the language of the other screens, with the back button where Setup has it.
##
## It appears a beat after the round ends, so the last hit is seen, then lists its rows one by one and counts
## the coins up, with a tally tick for each. The buttons work from the moment the panel shows.

signal retry_pressed
signal next_pressed
signal back_pressed

const DELAY := 0.5  ## Seconds from the end of the round to the panel
const ROW := 0.09  ## Seconds between rows
const COUNT := 0.5  ## Seconds the coins take to count up
const TICK := 0.05  ## The least time between two tally ticks while they count
const WIDTH := 880.0
const COMBO_ROWS := 3  ## The most rows the combos take

var _tween: Tween
var _coins: UiPrice
var _ticked := 0.0


## Shows the result of `round`, which is over. `unlocked` is true if it has just unlocked the next level.
func open(round: Round, data: LevelData, unlocked: bool) -> void:
	close()
	show()
	var back := UiBackButton.new()
	back.name = "Back"
	back.position = LevelHud.FOOTER.position + Vector2(0, (LevelHud.FOOTER.size.y - UiTheme.HIT) * 0.5)
	back.pressed.connect(back_pressed.emit)
	add_child(back)
	var centre := CenterContainer.new()
	centre.position = LevelArena.FRAME.position
	centre.size = LevelArena.FRAME.size
	centre.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = WIDTH
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)

	var cleared := round.tally.cleared
	var head := VBoxContainer.new()
	head.add_theme_constant_override(&"separation", -4)
	box.add_child(head)
	_text(head, &"Tag", "LEVEL %d - %s" % [data.number, data.title.to_upper()])
	var title := _text(head, &"Title", "LEVEL CLEARED" if cleared else "BOARD EMPTY" if round.reason == Round.End.CLEARED
			else "TIME UP" if round.reason == Round.End.TIME else "BALL LOST")
	if cleared:
		UiTheme.light(title, Palette.PLAYER)
	_text(head, &"Hint", "Level %d unlocked" % (data.number + 1) if unlocked else "Every brick broken" if cleared and round.reason == Round.End.CLEARED
			else "Score %d of %d" % [round.tally.score, round.tally.target])

	# Two columns of rows: what broke on the left, the combos on the right.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 32)
	box.add_child(columns)
	var grids: Array[GridContainer] = []
	for i in 2:
		var g := GridContainer.new()
		g.columns = 4
		g.size_flags_horizontal = SIZE_EXPAND_FILL
		g.add_theme_constant_override(&"h_separation", 12)
		g.add_theme_constant_override(&"v_separation", 2)
		columns.add_child(g)
		grids.append(g)
	var grid := grids[0]
	var right := grids[1]
	# One row for each kind of brick broken, standard bricks first, in the order the kinds are listed in.
	var rows: Array[Array] = []
	var ids: Array[StringName] = [&""]
	for kind in Kinds.bricks():
		ids.append(kind.id)
	for id in ids:
		if round.tally.broken.get(id, 0) > 0:
			var kind := Kinds.of(id)
			# ponytail: each row's coins are rounded on their own, so with a coins_per_brick that is not whole the
			# rows can add up to a little less than the total. Show the points instead if so.
			rows.append(_row(grid, Palette.kind(kind) if kind else Palette.hp(1), kind.title if kind else "Bricks", str(round.tally.broken[id]),
					_price(Coins.pay(round.tally.broken[id] * Coins.worth(id), round.stats))))
	# The hits that left a level brick standing, 1 point each, in the 2 HP colour: only a brick with HP to spare takes one.
	if round.tally.dents:
		rows.append(_row(grid, Palette.hp(2), "Hits", str(round.tally.dents), _price(Coins.pay(round.tally.dents, round.stats))))
	# Each combo that reached a multiplier, in order, with the bricks in it and the bonus it added. Past
	# COMBO_ROWS, the ones with the smallest bonus share one last row.
	var runs := round.tally.combos.filter(func(r: Tally.Run) -> bool: return r.multiplier > 1)
	var top := runs.duplicate()
	top.sort_custom(func(a: Tally.Run, b: Tally.Run) -> bool: return Coins.bonus(a) > Coins.bonus(b))
	top.resize(mini(top.size(), COMBO_ROWS if runs.size() <= COMBO_ROWS else COMBO_ROWS - 1))
	var rest := 0
	for run: Tally.Run in runs:
		if run in top:
			rows.append(_row(right, Palette.COINS, "Combo ×%d" % run.multiplier, str(run.count), _price(Coins.pay(Coins.bonus(run), round.stats))))
		else:
			rest += Coins.bonus(run)
	if runs.size() > top.size():
		rows.append(_row(right, Palette.COINS, "%d more combos" % (runs.size() - top.size()), "", _price(Coins.pay(rest, round.stats))))

	var total := HBoxContainer.new()
	box.add_child(total)
	var tag := _text(total, &"Tag", "COINS")
	tag.size_flags_horizontal = SIZE_EXPAND_FILL
	_coins = UiPrice.new()
	total.add_child(_coins)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 12)
	box.add_child(buttons)
	# A clear with a level after it offers Next in Retry's place; the last level's clear keeps Retry.
	var first: Array = ["Next", next_pressed] if cleared and data.number < Progress.level_count else ["Retry", retry_pressed]
	for b: Array in [first, ["Upgrades", back_pressed]]:
		var button := Button.new()
		button.name = b[0]
		button.text = (b[0] as String).to_upper()
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.pressed.connect((b[1] as Signal).emit)
		buttons.add_child(button)
	UiTheme.selection(buttons.get_children())  # the focused one is filled

	back.hide()
	panel.hide()
	_tween = create_tween()
	_tween.tween_interval(DELAY)
	_tween.tween_callback(back.show)
	_tween.tween_callback(panel.show)
	_tween.tween_callback((buttons.get_child(0) as Button).grab_focus)  # so Space or Enter retries, or goes on
	for i in rows.size():
		for cell: Control in rows[i]:
			cell.modulate.a = 0.0
		_tween.tween_interval(ROW)
		_tween.tween_callback(_reveal.bind(rows[i], i))
	_tween.tween_interval(ROW)
	_tween.tween_method(_count, 0.0, float(round.coins), COUNT if round.coins else 0.0)


## Takes the Summary off the screen.
func close() -> void:
	if _tween:
		_tween.kill()
	for child in get_children():
		remove_child(child)
		child.queue_free()  # not free(): Retry is one of them, and it is still emitting `pressed`
	hide()


func _price(amount: int) -> UiPrice:
	var paid := UiPrice.new()
	paid.style = &"SmallTag"
	paid.amount = amount
	return paid


func _text(parent: Control, variation: StringName, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	parent.add_child(label)
	return label


# One line of the tally: a swatch, a name, a count and whatever stands in the last column. Returns its cells.
func _row(grid: GridContainer, colour: Color, title: String, count: String, last: Control) -> Array:
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	var number := Label.new()
	number.theme_type_variation = &"Name"
	number.text = count
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	last.size_flags_horizontal = SIZE_SHRINK_END
	last.custom_minimum_size.x = 96
	if last is Label:
		(last as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var cells := [LevelHud.swatch(colour, Vector2(6, 18)), name_label, number, last]
	for cell: Control in cells:
		grid.add_child(cell)
	return cells


func _reveal(cells: Array, index: int) -> void:
	for cell: Control in cells:
		cell.modulate.a = 1.0
	Sfx.play(Sfx.TALLY_TICK, 1.0 + index * 0.06)


func _count(value: float) -> void:
	if int(value) == _coins.amount:
		return
	_coins.amount = int(value)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _ticked >= TICK:
		_ticked = now
		Sfx.play(Sfx.TALLY_TICK, 1.5)
