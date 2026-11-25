class_name LevelHud
extends Control
## The level screen's HUD (docs/art.md, "Level screen" and "HUD numbers"): time on the left, with the selected
## ability and the charges held at the far end of its column, the combo (Play) or SETUP (Setup) in the centre,
## coins on the right, and under the arena Play's footer: the level's name, a legend of the bricks on this board
## and the score against the level's target. It only reads the round. A number swells for a moment when it goes
## up (UiTheme.pulse): the coins, the combo, the multiplier, the charges, and the time when an hourglass adds to it.
##
## The pixel fonts are taller than their digits (Jersey 10 at 75 is an 82 px line around 40 px digits), so every
## piece is placed by hand against the sizes theme.gd gives, not stacked in a container.

const LEFT := 96.0
const RIGHT := 1184.0
const COLUMN := 280.0  ## The width of the time and coin columns
const CENTRE := 640.0
const BAR_Y := 86.0
const TIME_BAR := 220.0
const COMBO_BAR := 160.0
const FOOTER := Rect2(96, 644, 1088, 56)
const SWATCH := Vector2(6, 22)  ## A legend swatch
const STEP_PULSE := 1.5  ## How far the multiplier swells when it steps up

const LAUNCH_HINT := "Click, or press Space, to launch the ball\nThe mouse, W / S or the arrow keys move the paddle"
## Line 1 of the launch hint once an ability is unlocked: a click fires each charge as it launches the first ball.
const ABILITY_HINT := "Click or Space launches  ·  Q / E or the wheel picks the ability"

var _round: Round
var _playing := false
var _combos := false
var _time_was := 0.0  ## What the round's clock, combo and multiplier were a frame ago
var _count_was := 0
var _charges_was := 0
var _abilities := false  ## Whether an ability is unlocked
var _times_was := 1

var _time_tag := _label(&"Tag", Rect2(LEFT, 3, COLUMN, 21), HORIZONTAL_ALIGNMENT_LEFT, "TIME")
var _time := _label(&"HudNumber", Rect2(LEFT, 11, COLUMN, 82), HORIZONTAL_ALIGNMENT_LEFT)
var _time_bar := UiBar.new()
var _coins := UiPrice.new()
var _combo_tag := _label(&"Tag", Rect2(CENTRE - 200, 3, 400, 21), HORIZONTAL_ALIGNMENT_CENTER, "COMBO")
var _combo := _label(&"ComboNumber", Rect2(CENTRE - 200, 1, 400, 100), HORIZONTAL_ALIGNMENT_CENTER)
var _multiplier := _label(&"Number", Rect2(CENTRE, 36, 120, 40), HORIZONTAL_ALIGNMENT_LEFT)
## Right-aligned at the inner end of the time column: the time is four digits at most, so the column's far half
## is free, and it is clear of the launch hint and the combo in the centre.
var _ability_tag := _label(&"Tag", Rect2(LEFT, 3, COLUMN, 21), HORIZONTAL_ALIGNMENT_RIGHT, "ABILITY")
var _ability := _label(&"Number", Rect2(LEFT, 36, COLUMN, 40), HORIZONTAL_ALIGNMENT_RIGHT)
var _combo_bar := UiBar.new()
var _setup_title := _label(&"Title", Rect2(CENTRE - 264, -1, 528, 60), HORIZONTAL_ALIGNMENT_CENTER, "SETUP")
var _hint := _label(&"Hint", Rect2(CENTRE - 264, 52, 528, 40), HORIZONTAL_ALIGNMENT_CENTER)
var _footer := HBoxContainer.new()
var _level_tag := Label.new()
var _level_name := Label.new()
var _legend := HBoxContainer.new()
var _left := Label.new()


## A lit swatch in a legend: the kit has none, so this is a ColorRect in a Palette colour.
static func swatch(colour: Color, px := SWATCH) -> ColorRect:
	var s := ColorRect.new()
	s.color = Palette.lit(colour)
	s.custom_minimum_size = px
	s.size_flags_vertical = SIZE_SHRINK_CENTER
	s.mouse_filter = MOUSE_FILTER_IGNORE
	return s


## The charges a round holds: those in reserve and the one waiting on the paddle (the held first ball is none).
static func held_charges(round: Round) -> int:
	return round.charges + int(round.waiting != null and not round.held)


func _ready() -> void:
	UiTheme.light(_time, Palette.TIME)
	UiTheme.light(_multiplier, Palette.COINS)
	UiTheme.light(_setup_title, Palette.PLAYER)
	_place(_time_bar, Rect2(LEFT, BAR_Y, TIME_BAR, UiBar.HEIGHT))
	_combo_bar.meaning = &"coins"
	_place(_combo_bar, Rect2(CENTRE - COMBO_BAR * 0.5, BAR_Y, COMBO_BAR, UiBar.HEIGHT))
	_place(_coins, Rect2(RIGHT - COLUMN, 11, COLUMN, 82))
	_label(&"Tag", Rect2(RIGHT - COLUMN, 3, COLUMN, 21), HORIZONTAL_ALIGNMENT_RIGHT, "COINS")

	_place(_footer, FOOTER)
	_footer.mouse_filter = MOUSE_FILTER_IGNORE
	var level := _column(BoxContainer.ALIGNMENT_BEGIN)
	_level_tag.theme_type_variation = &"Tag"
	_level_name.theme_type_variation = &"Name"
	level.add_child(_level_tag)
	level.add_child(_level_name)
	_legend.alignment = BoxContainer.ALIGNMENT_CENTER
	_legend.size_flags_horizontal = SIZE_EXPAND_FILL
	_legend.add_theme_constant_override(&"separation", 18)
	_footer.add_child(_legend)
	var left := _column(BoxContainer.ALIGNMENT_END)
	var left_tag := Label.new()
	left_tag.theme_type_variation = &"Tag"
	left_tag.text = "SCORE"
	left_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_left.theme_type_variation = &"Number"
	_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	left.add_theme_constant_override(&"separation", -8)
	left.add_child(left_tag)
	left.add_child(_left)


## Shows `round`, in Setup's dress or in Play's. The Summary keeps Play's HUD, without the footer.
func show_round(round: Round, data: LevelData, setup: bool, footer: bool) -> void:
	_round = round
	_playing = not setup
	_time_was = round.time_left
	_count_was = 0
	_times_was = 1
	_coins.amount = round.coins
	_combos = round.stats.combo_rank >= 1.0
	_abilities = not round.abilities().is_empty()
	_charges_was = 0
	_setup_title.visible = setup
	_footer.visible = footer
	# The hint names only what this tray can do: turning waits for an item that turns (the Wall Segment).
	var tray := Kinds.placeables().filter(func(k: PlaceableKind) -> bool: return round.stats.count(k.id) > 0)
	var turns := tray.any(func(k: PlaceableKind) -> bool: return k.rotatable)
	var launch := LAUNCH_HINT if not _abilities else ABILITY_HINT + LAUNCH_HINT.substr(LAUNCH_HINT.find("\n"))
	_hint.text = launch if not setup else "Press Start, or Space, to begin\nW / S or the arrow keys move the paddle" if tray.is_empty() \
			else "Drag items onto the board, then press Start\n" + ("Q / E or the wheel turns one  ·  right-click removes one" if turns else "Right-click removes one")
	_waiting()
	if setup or not footer:
		return
	_level_tag.text = "LEVEL %d" % data.number
	_level_name.text = data.title
	for old in _legend.get_children():
		old.free()
	# What is on this board: every HP step up to its toughest plain brick (a brick shows each step on its way
	# down, so a level that starts at 1 and 4 HP shows 2 and 3 too), then its special bricks. A tough brick is
	# drawn in the HP steps, so it is one of those and has no entry of its own.
	# ponytail: one row. Four HP steps and the demo's three coloured special bricks come to about 660 px of the 708
	# between the two columns; a fourth coloured one needs shorter names or swatches alone.
	var top := 0
	var kinds := {}
	for brick: Brick in round.board.bricks.values():
		var kind := Kinds.of(brick.kind)
		if kind == null or not kind.colour:
			top = maxi(top, mini(brick.hp, Palette.HP.size()))
		elif not brick.placed:
			kinds[brick.kind] = true
	for hp in range(1, top + 1):
		_entry(Palette.hp(hp), "%d%s HP" % [hp, "+" if hp == Palette.HP.size() else ""])
	for kind in Kinds.bricks():
		if kinds.has(kind.id):
			_entry(Palette.of(kind.colour), kind.title.trim_suffix(" Brick").to_upper())


## Setup's hint, or Play's launch hint in the combo's place while the ball waits on the paddle.
func _waiting() -> void:
	var waiting := _playing and _round.held and not _round.over
	_hint.visible = not _playing or waiting
	for c: Control in [_combo_tag, _combo, _combo_bar, _multiplier]:
		c.visible = _playing and _combos and not waiting


func _process(_delta: float) -> void:
	if _round == null:
		return
	if _hint.visible and _playing:
		_waiting()
	_time.text = "%.1f" % _round.time_left
	_time_bar.value = _round.time_left / _round.stats.round_time
	# The warning is the bar turning red; the number stays green, because red is never a number (palette.md).
	_time_bar.meaning = &"danger" if _playing and _round.time_left <= _round.stats.low_time else &"time"
	if _round.time_left > _time_was:
		UiTheme.pulse(_time, 0.0)
	_time_was = _round.time_left
	# The ability readout: the selected one and the charges held, the one on the paddle included.
	var charges := held_charges(_round)
	_ability.visible = _playing and (_abilities or charges > 0)
	_ability_tag.visible = _ability.visible
	if _ability.visible:
		var kind := Kinds.of(_round.ability)
		_ability.text = ("%s ×%d" % [kind.title.to_upper(), charges]) if kind else "×%d" % charges
		# Lit while a charge is held; dim at none, as the combo's 0 is.
		_ability.add_theme_color_override(&"font_color", Palette.lit(Palette.ABILITY) if charges else Palette.ABILITY_DIM)
		if charges > _charges_was:
			UiTheme.pulse(_ability, 1.0)
	_charges_was = charges
	if _round.coins > _coins.amount:
		UiTheme.pulse(_coins, 1.0)
	_coins.amount = _round.coins
	if _combo.visible:
		var combo := _round.combo
		_combo.text = str(combo.count)
		_combo.add_theme_color_override(&"font_color", Palette.lit(Palette.COINS) if combo.count else Palette.COINS_DIM)
		_combo_bar.value = combo.time_left / combo.window if combo.window > 0.0 else 0.0
		_multiplier.text = "×%d" % combo.multiplier if combo.multiplier > 1 else ""
		if combo.count > _count_was:
			UiTheme.pulse(_combo)
		if combo.multiplier > _times_was:
			UiTheme.pulse(_multiplier, 0.0, STEP_PULSE)
		_count_was = combo.count
		_times_was = combo.multiplier
		_multiplier.position.x = CENTRE + _combo.get_theme_font(&"font").get_string_size(_combo.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				_combo.get_theme_font_size(&"font_size")).x * 0.5 + 10.0
	if _footer.visible:
		_left.text = "%d / %d" % [Coins.points(_round.tally, _round.stats), _round.target]


func _entry(colour: Color, text: String) -> void:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override(&"separation", 8)
	entry.add_child(swatch(colour))
	var label := Label.new()
	label.theme_type_variation = &"SmallTag"
	label.text = text
	entry.add_child(label)
	_legend.add_child(entry)


func _column(alignment: BoxContainer.AlignmentMode) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.x = 190
	column.add_theme_constant_override(&"separation", 0)
	column.size_flags_horizontal = SIZE_SHRINK_BEGIN if alignment == BoxContainer.ALIGNMENT_BEGIN else SIZE_SHRINK_END
	_footer.add_child(column)
	return column


func _label(variation: StringName, rect: Rect2, align: HorizontalAlignment, text := "") -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.horizontal_alignment = align
	label.text = text
	_place(label, rect)
	return label


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	control.mouse_filter = MOUSE_FILTER_IGNORE
	if control.get_parent() == null:
		add_child(control)
