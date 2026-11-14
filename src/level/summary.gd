class_name LevelSummary
extends Control
## The Summary (docs/design/overview.md, "Level phases"): how the round ended, the tally by brick type, the best
## combo, the coins it paid, and Retry and Upgrades. There is no mockup; it is a panel over the arena in the
## language of the other screens, with the back button where Setup has it.
##
## It appears a beat after the round ends, so the last hit is seen, then lists its rows one by one and counts
## the coins up, with a tally tick for each. The buttons work from the moment the panel shows.

signal retry_pressed
signal back_pressed

const DELAY := 0.5  ## Seconds from the end of the round to the panel
const ROW := 0.09  ## Seconds between rows
const COUNT := 0.5  ## Seconds the coins take to count up
const TICK := 0.05  ## The least time between two tally ticks while they count
const WIDTH := 440.0

var _tween: Tween
var _coins: UiPrice
var _ticked := 0.0


## Shows the result of `round`, which is over. `unlocked` is true if it has just unlocked the next level.
func open(round: Round, data: LevelData, unlocked: bool) -> void:
	close()
	show()
	var back := UiBackButton.new()
	back.name = "Back"
	back.focus_mode = FOCUS_NONE  # the arrow keys are paddle keys: one still held must not walk the focus off Retry
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

	var cleared := round.reason == Round.End.CLEARED
	var left := round.board.remaining()
	var head := VBoxContainer.new()
	head.add_theme_constant_override(&"separation", -4)
	box.add_child(head)
	_text(head, &"Tag", "LEVEL %d - %s" % [data.number, data.title.to_upper()])
	var title := _text(head, &"Title", "LEVEL CLEARED" if cleared else "TIME UP" if round.reason == Round.End.TIME else "BALL LOST")
	if cleared:
		UiTheme.light(title, Palette.PLAYER)
	_text(head, &"Hint", "Level %d unlocked" % (data.number + 1) if unlocked else "Every brick broken" if cleared
			else "%d brick%s left" % [left, "" if left == 1 else "s"])

	# One row for each kind of brick broken, standard bricks first, in the order the kinds are listed in.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 2)
	box.add_child(grid)
	var rows: Array[Array] = []
	var ids: Array[StringName] = [&""]
	for kind in Kinds.bricks():
		ids.append(kind.id)
	for id in ids:
		if round.tally.broken.get(id, 0) > 0:
			var kind := Kinds.of(id)
			# ponytail: a row's coins are the formula run on that kind alone, so with a coins_per_brick that is
			# not whole the rows can add up to one or two less than the total. Show the points instead if so.
			var one := Tally.new()
			one.points[id] = round.tally.points[id]
			var paid := UiPrice.new()
			paid.style = &"SmallTag"
			paid.amount = Coins.total(one, round.stats)
			rows.append(_row(grid, Palette.of(kind.colour) if kind else Palette.hp(1), kind.title if kind else "Bricks", round.tally.broken[id], paid))
	if round.tally.placed_broken > 0:
		var nothing := Label.new()
		nothing.theme_type_variation = &"Hint"
		nothing.text = "pay nothing"
		rows.append(_row(grid, Palette.PLACEABLE, "Placed bricks", round.tally.placed_broken, nothing))
	if round.stats.combo_rank >= 1.0:
		var times := Label.new()
		times.theme_type_variation = &"SmallTag"
		times.text = "×%d" % round.tally.best_multiplier
		UiTheme.light(times, Palette.COINS)
		rows.append(_row(grid, Palette.COINS, "Best combo", round.tally.best_combo, times))

	var total := HBoxContainer.new()
	box.add_child(total)
	var tag := _text(total, &"Tag", "COINS")
	tag.size_flags_horizontal = SIZE_EXPAND_FILL
	_coins = UiPrice.new()
	total.add_child(_coins)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 12)
	box.add_child(buttons)
	for b: Array in [["Retry", &"SecondaryButton", retry_pressed], ["Upgrades", &"", back_pressed]]:
		var button := Button.new()
		button.name = b[0]
		button.text = (b[0] as String).to_upper()
		button.theme_type_variation = b[1]
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.pressed.connect((b[2] as Signal).emit)
		buttons.add_child(button)

	back.hide()
	panel.hide()
	_tween = create_tween()
	_tween.tween_interval(DELAY)
	_tween.tween_callback(back.show)
	_tween.tween_callback(panel.show)
	_tween.tween_callback((buttons.get_child(0) as Button).grab_focus)  # so Space or Enter retries
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


func _text(parent: Control, variation: StringName, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	parent.add_child(label)
	return label


# One line of the tally: a swatch, a name, a count and whatever stands in the last column. Returns its cells.
func _row(grid: GridContainer, colour: Color, title: String, count: int, last: Control) -> Array:
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	var number := Label.new()
	number.theme_type_variation = &"Name"
	number.text = str(count)
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
