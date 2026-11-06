extends Node2D
## Placement mode: the pieces tray, picking, dragging, rotating and dropping placeables before a round.
## Pieces are children of the arena so the ball sees them; this node owns which are placed. Emits started once locked in.

signal started

const Tuning = preload("res://src/tuning.gd")
const Box = preload("res://src/brick.gd")
const Fx = preload("res://src/fx.gd")
const Ui = preload("res://src/ui.gd")
const Sfx = preload("res://src/sfx.gd")

var arena  # the round (arena.gd); untyped so the two scripts need not preload each other
var tray := Control.new()  # right column contents, rebuilt by refresh
var placing := true
var placed: Array[Box] = []
var holding: Box = null
var hovered: Box = null


func _init(a: Node2D, ui: Ui.Root) -> void:
	arena = a
	tray.position.x = Ui.RX
	ui.right.add_child(tray)


func _ready() -> void:
	refresh()


func _count(kind: String) -> int:
	return placed.filter(func(b): return b.kind == kind).size()


func _used() -> int:
	var n := 0
	for b in placed:
		n += Tuning.PLACEABLES[b.kind].cost
	return n


func _can_take(kind: String) -> bool:
	return holding == null and _count(kind) < Game.owned(kind) and _used() + Tuning.PLACEABLES[kind].cost <= Game.capacity()


## Rebuilds the pieces column: a slot per owned piece with its count left, capacity pips, hints and the start button.
func refresh() -> void:
	for c in tray.get_children():
		c.queue_free()
	var C := Tuning.COLORS
	var kinds: Array = Tuning.PLACEABLES.keys().filter(func(k): return Game.owned(k) > 0)
	for i in kinds.size():
		var kind: String = kinds[i]
		var left := Game.owned(kind) - _count(kind)
		var slot := TextureButton.new()
		slot.texture_normal = Ui.tex("ui_slot")
		slot.texture_hover = Ui.tex("ui_slot_hover")
		slot.texture_disabled = slot.texture_normal
		slot.position = Vector2(22, 22 + i * 20)
		slot.focus_mode = Control.FOCUS_NONE
		slot.disabled = not _can_take(kind)
		slot.pressed.connect(_take.bind(kind))
		tray.add_child(slot)
		var t := Box.tex_of(Tuning.PLACEABLES[kind].face)
		Ui.icon(slot, t, 18 - t.get_width() / 2, 9 - t.get_height() / 2).modulate.a = 1.0 if left and placing else 0.3
		if left:
			Ui.icon(slot, "ui_badge", 30, -3)
			Ui.label(slot, str(left), 33, -2, C.bg)
	var y := 26 + kinds.size() * 20
	Ui.label(tray, "CAP", 6, y, C.rivet)
	Ui.label(tray, "%d/%d" % [_used(), Game.capacity()], 24, y, C.white)
	Ui.pips(tray, 6, y + 8, Game.capacity(), _used())
	if not placing:
		Ui.label(tray, "LOCKED", 6, y + 24, C.rivet)
		return
	var hints := ["LMB PICK/DROP", "WHEEL/A/D ROTATE", "RMB REMOVE", "ESC PAUSE"]
	for i in hints.size():
		Ui.label(tray, hints[i], 6, y + 24 + i * 8, C.rivet)
	Ui.button(tray, "START", 6, 300, 66, 24, _start, true, 2, "")
	Ui.label(tray, "SPACE", 0, 328, C.rivet, 1, 78, HORIZONTAL_ALIGNMENT_CENTER)


func _take(kind: String) -> void:
	if not _can_take(kind):
		return
	Sfx.play("ui_pickup")
	_hover(null)
	holding = arena.box(kind, Tuning.PLACEABLES[kind].size, get_local_mouse_position())
	placed.append(holding)
	_drag()
	refresh()


func _valid(b: Box) -> bool:
	var zone := Rect2(Vector2.ZERO, Vector2(arena.field.size.x, arena.place_y()))
	if not zone.encloses(b.rect()):
		return false
	for o in arena.get_children():
		if o is Box and o != b and o.rect().grow(Tuning.PLACE_MARGIN).intersects(b.rect()):
			return false
	return true


func _drag() -> void:
	holding.position = get_local_mouse_position()
	var s := holding.size / Fx.SCALE
	holding.overlay([("ghost_march_%dx%d" if _valid(holding) else "ghost_invalid_shake_%dx%d") % [s.x, s.y], int(s.x), 8])


func _hover(b: Box) -> void:
	if b == hovered:
		return
	if hovered:
		hovered.overlay(null)
	hovered = b
	if b:
		var s := b.size / Fx.SCALE + Vector2(4, 4)
		b.overlay(["hover_outline_%dx%d" % [s.x, s.y], int(s.x), 8])


func _placed_at(p: Vector2) -> Box:
	for b in placed:
		if b.rect().has_point(p):
			return b
	return null


func _place_click(button: int) -> void:
	var m := get_local_mouse_position()
	if button == MOUSE_BUTTON_LEFT:
		if holding and _valid(holding):
			Sfx.play("ui_drop")
			holding.overlay(null)
			holding = null
			_hover(_placed_at(m))
		elif not holding:
			_hover(null)
			holding = _placed_at(m)
			if holding:
				Sfx.play("ui_pickup")
				_drag()
		else:
			Sfx.play("ui_invalid")
	elif button == MOUSE_BUTTON_RIGHT:
		var b := holding if holding else _placed_at(m)
		if b:
			Sfx.play("ui_back")
			_hover(null)
			placed.erase(b)
			b.queue_free()
			holding = null
	refresh()


## Locks the board in. A piece still held over an invalid spot is dropped back into the tray.
func _start() -> void:
	if not placing:
		return
	if holding and not _valid(holding):
		placed.erase(holding)
		holding.queue_free()
	elif holding:
		holding.overlay(null)
	_hover(null)
	holding = null
	placing = false
	Sfx.play("ui_start")
	refresh()
	started.emit()


## Motion comes through _input: the cabinet columns swallow events over them, and a held piece must still follow the mouse there.
func _input(e: InputEvent) -> void:
	if not placing or not e is InputEventMouseMotion:
		return
	if holding:
		_drag()
	else:
		_hover(_placed_at(get_local_mouse_position()))


func _unhandled_input(e: InputEvent) -> void:
	if not placing:
		return
	var key: bool = e is InputEventKey and e.pressed and not e.echo
	var wheel: bool = e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	if wheel and holding:
		_rotate(1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
	elif e is InputEventMouseButton and e.pressed:
		_place_click(e.button_index)
	elif key and e.keycode == KEY_SPACE:
		_start()
	elif key and e.keycode in [KEY_R, KEY_D] and holding:
		_rotate(1)
	elif key and e.keycode == KEY_A and holding:
		_rotate(-1)
	else:
		return
	get_viewport().set_input_as_handled()  # the arena sees the event next and would launch on the same press


func _rotate(dir: int) -> void:
	Sfx.play("ui_rotate")
	holding.rotation += dir * deg_to_rad(Tuning.ROTATE_DEG)
	_drag()
