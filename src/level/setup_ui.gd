class_name LevelSetupUi
extends Control
## Setup's back button, where the top bar has one (UiTopBar.BACK), its footer (docs/art.md, "Level screen": the
## placeable tray, this run's special bricks, Start) and the placing itself (docs/design/placeables.md). It
## covers the screen while Setup is open, so every press on the tray or the board comes here.
##
## PLACING. Press on a tray slot or on a placed item and drag: the item leaves the layout and follows the cursor
## as the Arena's ghost, from the press on and over the tray too. In the arena it is blue where it fits and red
## where it does not (Layout.fits is the only judge); outside the arena nothing has refused it yet, so it is
## blue there. Release:
##   on the board, where it fits   it is placed there
##   on the board, anywhere else   refused: a new item goes back to the tray, a moved one back where it was
##   outside the arena             a new item goes back to the tray, a moved one is removed
## A right click removes the item under the cursor, or drops the drag as if refused. The wheel, Q and E turn a
## rotatable item, the held one or else the one under the cursor.
##
## THE TRAY SCROLLS. When its slots are wider than the room the footer leaves it, arrows at both ends step it a
## slot at a time, and so does the wheel over the tray while nothing is held. Only the part of a slot in view
## can be picked.
##
## This script edits the Layout it was given and says so with `edited`; the level screen saves it and builds
## the round again.

## The layout changed, or the round has to be drawn again without the item now held. `save` is false when
## nothing is different from the saved layout.
signal edited(save: bool)
signal start_pressed
signal back_pressed

## Between the footer's pieces.
const FOOTER_GAP := 8
const WHEEL: Array[MouseButton] = [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]

var _layout: Layout
var _board: Board
var _stats: Balance
var _arena: LevelArena

## The item being dragged. It is not in the layout.
var _held: Layout.Item
## A copy of the held item as it was when it was picked off the board; null for one from the tray.
var _home: Layout.Item
## From the cursor to the held item's centre, so an item picked up by its edge does not jump.
var _grab := Vector2.ZERO
var _mouse := Vector2.ZERO

var _slots: Array[Slot] = []
var _tray := HBoxContainer.new()
var _scroll := ScrollContainer.new()
var _prev := Button.new()
var _next := Button.new()
var _run := VBoxContainer.new()
var _run_list := GridContainer.new()


## One placeable in the tray: its shape, its name, and a pip for each one allowed, lit while it is still to
## place. The kit has no such piece; it is the kit's pips and labels on flat rectangles (the mockup's slot).
class Slot:
	extends MarginContainer

	const PAD := 8.0
	const ICON := 24.0

	var kind: PlaceableKind
	var left := 0:
		set(v):
			left = v
			_pips.owned = v
			queue_redraw()
	## The cursor is over it and it can be picked up.
	var hot := false:
		set(v):
			hot = v
			queue_redraw()

	var _pips := UiPips.new()


	func _init(p_kind: PlaceableKind, total: int) -> void:
		kind = p_kind
		mouse_filter = MOUSE_FILTER_IGNORE
		custom_minimum_size.y = UiTheme.BUTTON_HEIGHT
		add_theme_constant_override(&"margin_left", int(PAD + ICON + 6.0))
		add_theme_constant_override(&"margin_right", int(PAD))
		var text := VBoxContainer.new()
		text.mouse_filter = MOUSE_FILTER_IGNORE
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.add_theme_constant_override(&"separation", 5)
		var title := Label.new()
		title.theme_type_variation = &"SmallName"
		title.text = kind.title
		text.add_child(title)
		_pips.total = total
		_pips.meaning = kind.colour
		text.add_child(_pips)
		add_child(text)


	func _draw() -> void:
		var on := left > 0
		var fill := Palette.dim(kind.colour) if hot and on else Palette.PANEL
		draw_rect(Rect2(Vector2.ZERO, size), fill)
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Palette.of(kind.colour) if on else Palette.BORDER, false, 2.0)
		var c := Vector2(PAD + ICON * 0.5, size.y * 0.5)
		var colour := Palette.lit(Palette.of(kind.colour)) if on else Palette.dim(kind.colour)
		match kind.placement:
			PlaceableKind.Placement.BRICK:
				if kind.unbreakable:  # hollow, as on the board
					draw_rect(Rect2(c - Vector2(4, 12), Vector2(8, 24)), colour)
					LevelArena.panes(self, Rect2(c - Vector2(2, 10), Vector2(4, 20)), kind.panes, 2.0, fill)
				else:
					draw_rect(Rect2(c - Vector2(3, 12), Vector2(6, 24)), colour)
			PlaceableKind.Placement.AREA:  # a frame round its cell, as in Setup
				draw_rect(Rect2(c - Vector2(11, 11), Vector2(22, 22)), colour, false, 2.0)
				draw_rect(Rect2(c - Vector2(2, 6), Vector2(4, 12)), colour)
			PlaceableKind.Placement.MOD:
				draw_rect(Rect2(c - Vector2(5, 12), Vector2(10, 24)), Palette.BORDER)
				draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), colour)
			_:
				if kind.gate:  # upright and as long as the icon, so its dashes show
					LevelArena.gate(self, c, Vector2(6.0, ICON), 0.0, colour,
							Palette.dim(kind.colour) if on else Palette.BORDER)
					return
				# The item's own rectangle, shrunk until its turned outline fits the icon's box, no side under 5 px.
				var item := Layout.Item.new()
				item.kind = kind
				var reach := 0.0
				for point in item.outline():
					reach = maxf(reach, maxf(absf(point.x), absf(point.y)))
				var half := (kind.size * ICON * 0.5 / reach).max(Vector2(5, 5)) * 0.5
				var shape := PackedVector2Array()
				for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					shape.append(c + (corner * half).rotated(deg_to_rad(kind.turn)))
				draw_colored_polygon(shape, colour)


func _ready() -> void:
	var footer := HBoxContainer.new()
	footer.position = LevelHud.FOOTER.position
	footer.size = LevelHud.FOOTER.size
	footer.mouse_filter = MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override(&"separation", FOOTER_GAP)
	add_child(footer)
	var back := UiBackButton.new()
	back.name = "Back"
	back.position = UiTopBar.BACK
	back.pressed.connect(back_pressed.emit)
	add_child(back)
	for arrow: Button in [_prev, _next]:
		arrow.focus_mode = FOCUS_NONE  # as the back button: no focus to walk off with a key
		arrow.theme_type_variation = &"IconButton"
		arrow.size_flags_vertical = SIZE_SHRINK_CENTER
		arrow.visible = false
	_prev.icon = UiTheme.icon(UiGlyph.Shape.PREV)
	_prev.accessibility_name = "Scroll the tray left"
	_prev.pressed.connect(_step.bind(-1))
	_next.icon = UiTheme.icon(UiGlyph.Shape.NEXT)
	_next.accessibility_name = "Scroll the tray right"
	_next.pressed.connect(_step.bind(1))
	_scroll.mouse_filter = MOUSE_FILTER_IGNORE  # the wheel comes through _gui_input
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bar := _scroll.get_h_scroll_bar()
	bar.changed.connect(_fit_arrows)
	bar.value_changed.connect(_fit_arrows.unbind(1))
	_tray.mouse_filter = MOUSE_FILTER_IGNORE
	_tray.add_theme_constant_override(&"separation", 4)
	_scroll.add_child(_tray)
	footer.add_child(_prev)
	footer.add_child(_scroll)
	footer.add_child(_next)
	_run.mouse_filter = MOUSE_FILTER_IGNORE
	_run.alignment = BoxContainer.ALIGNMENT_CENTER
	_run.add_theme_constant_override(&"separation", 2)
	var tag := Label.new()
	tag.theme_type_variation = &"Tag"
	tag.text = "THIS RUN"
	_run.add_child(tag)
	_run_list.add_theme_constant_override(&"h_separation", 12)
	_run_list.add_theme_constant_override(&"v_separation", 0)
	_run.add_child(_run_list)
	footer.add_child(_run)
	var start := Button.new()
	start.name = "Start"
	start.text = "START"
	start.icon = UiTheme.icon(UiGlyph.Shape.PLAY, 18)
	start.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	start.add_to_group(Sfx.QUIET)  # connect_round plays the round start
	start.pressed.connect(start_pressed.emit)
	footer.add_child(start)


## Fills the tray for a level. `layout` is the one this script edits; `board` is the level's own board.
func open(layout: Layout, board: Board, stats: Balance, arena: LevelArena) -> void:
	_layout = layout
	_board = board
	_stats = stats
	_arena = arena
	for kind in Kinds.placeables():
		if stats.count(kind.id) > 0:
			var slot := Slot.new(kind, stats.count(kind.id))
			_tray.add_child(slot)
			_slots.append(slot)


## Brings the footer up to date with the layout and with `round`'s special bricks.
func refresh(round: Round) -> void:
	for slot in _slots:
		slot.left = _stats.count(slot.kind.id) - _layout.count(slot.kind.id) - int(_held != null and _held.kind == slot.kind)
	var counts := {}
	for brick: Brick in round.board.bricks.values():
		if brick.kind and not brick.placed:
			counts[brick.kind] = counts.get(brick.kind, 0) + 1
	for old in _run_list.get_children():
		old.free()
	for kind in Kinds.bricks():
		if counts.has(kind.id):
			var entry := HBoxContainer.new()
			entry.add_theme_constant_override(&"separation", 8)
			entry.add_child(LevelHud.swatch(Palette.kind(kind), Vector2(6, 18)))
			var label := Label.new()
			label.theme_type_variation = &"Hint"
			label.text = "%d %s" % [counts[kind.id], kind.title.trim_suffix(" Brick")]
			entry.add_child(label)
			_run_list.add_child(entry)
	_run_list.columns = maxi(1, ceili(counts.size() / 2.0))  # two rows at most: the footer is 56 px tall
	_run.visible = not counts.is_empty()


## Ends a drag as if it was refused. The level screen calls it before it leaves Setup.
func cancel() -> void:
	_release(false, false)


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	_mouse = mouse.position
	var button := event as InputEventMouseButton
	if button == null:
		var under := _slot_at()
		for slot in _slots:
			slot.hot = _held == null and slot == under
		_aim()
	elif button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_pick()
		else:
			var there := LevelArena.FRAME.has_point(_mouse)
			_release(there, not there)
	elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		if _held:
			cancel()
		else:
			var item := _layout.item_at(_arena.to_units(_mouse))
			if item:
				_layout.remove(item)
				edited.emit(true)
	elif _held == null and button.pressed and _scroll.get_global_rect().has_point(_mouse) and button.button_index in WHEEL:
		_step(-1 if button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1)
	else:
		_turn(event)


## Q and E. The wheel comes through _gui_input.
func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey:
		_turn(event)


func _pick() -> void:
	if _held:
		return
	var at := _arena.to_units(_mouse)
	var slot := _slot_at()
	if slot and slot.left > 0:
		_held = Layout.Item.new()
		_held.kind = slot.kind
		_home = null
		_grab = Vector2.ZERO
		slot.left -= 1
		slot.hot = false
	if _held == null:
		var item := _layout.item_at(at)
		if item == null:
			return
		_home = Layout.Item.new()
		_home.pos = item.pos
		_home.cell = item.cell
		_home.rot = item.rot
		_grab = item.pos - at if item.kind.placement == PlaceableKind.Placement.FREE else Vector2.ZERO
		_layout.remove(item)
		_held = item
		edited.emit(false)
	_aim()


## The tray slot under the cursor, counting only the part of it in view.
func _slot_at() -> Slot:
	if not _scroll.get_global_rect().has_point(_mouse):
		return null
	for slot in _slots:
		if slot.get_global_rect().has_point(_mouse):
			return slot
	return null


## Scrolls the tray a slot left (-1) or right (1): the nearest slot cut off on that side comes fully into view.
func _step(dir: int) -> void:
	var view := float(_scroll.scroll_horizontal)
	var to := view
	var order := _slots.duplicate()
	if dir < 0:
		order.reverse()
	for slot: Slot in order:
		if dir > 0 and slot.position.x + slot.size.x > view + _scroll.size.x + 0.5:
			to = slot.position.x + slot.size.x - _scroll.size.x
			break
		if dir < 0 and slot.position.x < view - 0.5:
			to = slot.position.x
			break
	_scroll.scroll_horizontal = ceili(to)


## Shows the arrows only while the slots overflow, each disabled at its end. The room is what the footer's
## other pieces leave, without the arrows, so showing them cannot change the answer (the scroll's own width
## lags a frame behind).
func _fit_arrows() -> void:
	var footer := _scroll.get_parent() as Control
	var room := footer.size.x
	for piece: Control in footer.get_children():
		if piece.visible and piece not in [_prev, _scroll, _next]:
			room -= piece.get_combined_minimum_size().x + FOOTER_GAP
	var over := _tray.get_combined_minimum_size().x > room + 0.5
	_prev.visible = over
	_next.visible = over
	var bar := _scroll.get_h_scroll_bar()
	_prev.disabled = bar.value <= 0.0
	_next.disabled = bar.value >= bar.max_value - bar.page - 0.5


## Moves the held item to the cursor and shows it as the ghost.
func _aim() -> void:
	if _held == null:
		return
	var at := _arena.to_units(_mouse)
	_held.pos = at + _grab
	_held.cell = _board.cell_at(at)
	_arena.ghost(_held, not LevelArena.FRAME.has_point(_mouse) or _layout.fits(_held, _board, _stats))


## Ends the drag. The held item is placed where it is if `there` and it fits. If not, a moved item goes back
## where it was, or off the board if `discard`.
func _release(there: bool, discard: bool) -> void:
	if _held == null:
		return
	var item := _held
	_held = null
	_arena.ghost(null)
	var placed := there and _layout.fits(item, _board, _stats)
	var removed := not placed and _home != null and discard
	if not placed and _home and not discard:
		item.pos = _home.pos
		item.cell = _home.cell
		item.rot = _home.rot
	if placed or (_home and not discard):
		_layout.add(item)
	if placed:
		Sfx.play(Sfx.PLACE_ITEM)
	edited.emit(placed or removed)


func _turn(event: InputEvent) -> void:
	var steps := int(event.is_action_pressed(&"rotate_cw")) - int(event.is_action_pressed(&"rotate_ccw"))
	if steps == 0:
		return
	var item := _held if _held else _layout.item_at(_arena.to_units(_mouse))
	if item == null or not item.kind.rotatable:
		return
	var was := item.rot
	item.rot = fposmod(was + steps * _stats.rotate_step, 360.0)
	if _held:
		_aim()
		return
	_layout.remove(item)
	if not _layout.fits(item, _board, _stats):
		item.rot = was
	_layout.add(item)
	edited.emit(item.rot != was)
