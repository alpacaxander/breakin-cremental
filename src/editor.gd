extends Node
## The encounter editor, a dev tool off the run (the menu's EDITOR, debug builds only). The board is a grid of half-brick
## cells (a brick is 2 cells by 1), drawn where the arena puts it, under the band portrait and above the floor line.
## Bricks and organ cells come from the TOOLS column: pick one and click or drag-paint, or drag the entry onto the board;
## a click on a piece selects it and dragging moves the selection, snapped; right button erases. The SETUP page holds the
## role, tier, band, organs (id, first countdown, win) and the test loadout (HP, gold, bag, relics). SAVE writes
## encounters/<name>.json: an ENCOUNTERS row whose board is `half` (Game.generate reads it as is) plus the loadout. PLAY runs
## it in arena.gd on a throwaway Game.run (run.json is never written; Esc stops it). Moving a design into the game is hand
## work: its row goes into Tuning.ENCOUNTERS.

const Ui = preload("res://src/ui.gd")
const Tuning = preload("res://src/tuning.gd")
const Sfx = preload("res://src/sfx.gd")
const Fx = preload("res://src/fx.gd")
const Box = preload("res://src/brick.gd")
const Arena = preload("res://src/arena.gd")
const DIR := "res://encounters/"
const CELL := Vector2(16, 14)  # a cell in sprite px: half the arena's brick step (BRICK_SIZE + BRICK_GAP), at 1/2
const MAX := Vector2i(30, 12)  # cells across the arena; rows down to BOARD_FLOOR
const TOOLS := [["", "SELECT"], ["x", "PLAIN"], ["?", "ROLLED"], ["#", "SOLID"], ["b", "BOMB"], ["R", "RED"], ["r", "REFRESH"], ["g", "GOLD"]]
const ROW := 17  # setup page row pitch: a dropdown stands 15 tall
const HELP := ["LMB PAINT, MOVE", "RMB ERASE", "SHIFT+CLICK ADD", "SELECT: DRAG BOX", "CTRL C V D A", "DEL ERASE SEL"]

var back: Callable  # main.gd's menu
var file := "untitled"
var enc := {}  # the ENCOUNTERS row, minus its board
var dims := Vector2i(22, 6)  # cells across, rows
var cells := {}  # Vector2i(col, row) of a piece's left cell -> its glyph: a Tuning.BOARD_KEYS key or an organ digit
var loadout := {}
var tool := "x"  # the painting glyph; "" selects
var sel := {}  # piece cells -> true
var clip := []  # [offset from the copy's top-left, glyph]
var page := "board"  # board, setup, load
var note := ""
var root: Ui.Root
var grid: Grid
var arena: Node2D  # the test fight while one runs


func _ready() -> void:
	_new()


func _new() -> void:
	var o: String = Tuning.ORGANS.keys()[0]
	enc = {role = "regular", tier = 1, band = "warden", w = 64, organs = [o], cd_start = [Tuning.organ(o).cd], win = [o]}
	loadout = {hp = Tuning.RUN.hp, gold = 0, bag = Tuning.BAG_START.map(func(id): return {id = id, rank = 1}), relics = []}
	dims = Vector2i(22, 6)
	cells = {}
	sel = {}
	file = "untitled"
	_build()


func _build() -> void:
	if root:
		root.queue_free()
	root = Ui.chassis("TOOLS", "FILE")
	add_child(root)
	grid = null
	var C := Tuning.COLORS
	# Right column: the file, the page, the board size, play.
	Ui.label(root.right, "NAME", Ui.RX + 4, 20, C.rivet)
	var name_e := LineEdit.new()
	name_e.position = Vector2(Ui.RX + 4, 28)
	name_e.size = Vector2(70, 12)
	name_e.text = file
	name_e.text_changed.connect(func(t): file = t.strip_edges().to_lower().validate_filename())
	root.right.add_child(name_e)
	Ui.button(root.right, "SAVE", Ui.RX + 4, 46, 70, 14, _save)
	Ui.button(root.right, "LOAD", Ui.RX + 4, 64, 70, 14, func(): page = "load"; _build())
	Ui.button(root.right, "NEW", Ui.RX + 4, 82, 70, 14, _new)
	Ui.button(root.right, "SETUP" if page == "board" else "BOARD", Ui.RX + 4, 108, 70, 14, func(): page = "setup" if page == "board" else "board"; _build())
	_num(root.right, Ui.RX + 4, 130, "W", dims.x, 2, MAX.x, func(v): dims.x = v; _crop())
	_num(root.right, Ui.RX + 4, 144, "H", dims.y, 1, MAX.y, func(v): dims.y = v; _crop())
	Ui.button(root.right, "PLAY", Ui.RX + 4, 300, 70, 18, _play, true, 2, "ui_start")
	Ui.button(root.right, "MENU", Ui.RX + 4, 322, 70, 18, back, false, 2, "ui_back")
	# Left column: the palette, then the organs, then the keys.
	var y := 20
	for t in TOOLS:
		_tool(t[0], t[1], y)
		y += 13
	for i in enc.organs.size():
		_tool(str(i + 1), "%d %s" % [i + 1, enc.organs[i].to_upper().replace("_", " ")], y)
		y += 13
	for h in HELP:
		Ui.label(root.left, h, 4, y + 6, C.trim_hi)
		y += 8
	match page:
		"board":
			grid = Grid.new(self)
			root.field.add_child(grid)
		"setup":
			_setup()
		"load":
			_load_page()
	Ui.label(root, note, Ui.FIELD_X + 4, 350, C.pay)


func _say(s: String) -> void:
	note = s
	_build()


## A palette entry: click picks the glyph, or drag it onto the board.
func _tool(g: String, text: String, y: float) -> void:
	var b := Ui.button(root.left, text, 4, y, 70, 11, func(): tool = g; _build(), tool == g, 1)
	var lift := func(_p):
		var t := TextureRect.new()
		t.texture = face(g)
		t.scale = root.scale
		t.position = -t.texture.get_size() * root.scale / 2
		var c := Control.new()  # the preview's offset from the cursor is its child's position
		c.add_child(t)
		b.set_drag_preview(c)
		return {glyph = g}
	if g:
		b.set_drag_forwarding(lift, Callable(), Callable())


## A label, "-", the value and "+": set gets the new value, clamped, then the screen rebuilds.
func _num(parent: Node, x: float, y: float, text: String, v, lo, hi, set: Callable, step = 1) -> void:
	Ui.label(parent, text, x, y + 2, Tuning.COLORS.rivet)
	Ui.button(parent, "-", x + 26, y, 10, 10, func(): set.call(clamp(v - step, lo, hi)); _build(), false, 1)
	Ui.label(parent, str(v), x + 38, y + 2, Tuning.COLORS.white)
	Ui.button(parent, "+", x + 60, y, 10, 10, func(): set.call(clamp(v + step, lo, hi)); _build(), false, 1)


## A dropdown of ids; set gets the picked one, then the screen rebuilds.
func _pick(x: float, y: float, w: float, ids: Array, cur: String, set: Callable) -> void:
	var o := OptionButton.new()
	o.position = Vector2(x, y)
	o.size = Vector2(w, 11)
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false
	for id in ids:
		o.add_item(id.to_upper().replace("_", " "))
	o.selected = ids.find(cur)
	o.get_popup().add_theme_font_size_override("font_size", 10)  # the popup is its own window, outside the Root's 2x
	o.item_selected.connect(func(i): set.call(ids[i]); _build())
	root.add_child(o)


func _setup() -> void:
	var C := Tuning.COLORS
	var x := Ui.FIELD_X + 8
	Ui.label(root, "ENCOUNTER", x, 8, C.pay)
	Ui.label(root, "ROLE", x, 22, C.rivet)
	_pick(x + 30, 20, 80, ["regular", "elite", "boss"], enc.role, func(v): enc.role = v)
	_num(root, x, 38, "TIER", enc.tier, 1, 3, func(v): enc.tier = v)
	var bands := {}
	for id in Tuning.encounters():
		var e: Dictionary = Tuning.encounter(id)
		bands[e.band] = e.w
	Ui.label(root, "BAND", x, 56, C.rivet)
	_pick(x + 30, 54, 80, bands.keys(), enc.band, func(v): enc.band = v; enc.w = bands[v])
	Ui.label(root, "ORGANS: ID, FIRST COUNTDOWN, WIN", x, 74, C.pay)
	var ids: Array = Tuning.ORGANS.keys() + Tuning.ENEMIES.keys()
	for i in enc.organs.size():
		var y: int = 86 + ROW * i
		var id: String = enc.organs[i]
		Ui.label(root, str(i + 1), x, y + 2, C.white)
		var swap := func(v):
			enc.organs[i] = v
			enc.cd_start[i] = Tuning.organ(v).cd
			if id in enc.win:
				enc.win[enc.win.find(id)] = v
		var win := func():
			if id in enc.win:
				enc.win.erase(id)
			else:
				enc.win.append(id)
			_build()
		_pick(x + 8, y, 100, ids, id, swap)
		_num(root, x + 112, y, "CD", enc.cd_start[i], 0, 99, func(v): enc.cd_start[i] = v)
		Ui.button(root, "WIN", x + 186, y, 22, 10, win, id in enc.win, 1)
		Ui.button(root, "X", x + 212, y, 10, 10, _drop_organ.bind(i), false, 1)
	if enc.organs.size() < 9:
		var add := func():
			enc.organs.append(ids[0])
			enc.cd_start.append(Tuning.organ(ids[0]).cd)
			enc.win.append(ids[0])
			_build()
		Ui.button(root, "+ ORGAN", x, 86 + ROW * enc.organs.size(), 50, 10, add, false, 1)
	Ui.label(root, "RELICS", x, 250, C.pay)
	var relics: Array = Tuning.RELICS.keys()
	for i in relics.size():
		var r: String = relics[i]
		var flip := func():
			if r in loadout.relics:
				loadout.relics.erase(r)
			else:
				loadout.relics.append(r)
			_build()
		Ui.button(root, Tuning.RELICS[r].name, x + 112 * (i % 2), 262 + 13 * (i / 2), 108, 11, flip, r in loadout.relics, 1)
	x = Ui.FIELD_X + 250
	Ui.label(root, "LOADOUT", x, 8, C.pay)
	_num(root, x, 20, "HP", loadout.hp, 1, 999, func(v): loadout.hp = v, 5)
	_num(root, x, 38, "GOLD", loadout.gold, 0, 999, func(v): loadout.gold = v, 10)
	Ui.label(root, "BAG: BALL, RANK", x, 56, C.pay)
	var bag: Array = loadout.bag
	for i in mini(bag.size(), 16):  # ponytail: 16 rows fit the field; scroll if test bags grow past it
		var y: int = 68 + ROW * i
		_pick(x, y, 110, Tuning.BALLS.keys(), bag[i].id, func(v): bag[i].id = v)
		_num(root, x + 90, y, "", bag[i].rank, 1, Tuning.MAX_RANK, func(v): bag[i].rank = v)
		Ui.button(root, "X", x + 164, y, 10, 10, func(): bag.remove_at(i); _build(), false, 1)
	if bag.size() < 16:
		Ui.button(root, "+ BALL", x, 68 + ROW * bag.size(), 50, 10, func(): bag.append({id = Tuning.BAG_START[0], rank = 1}); _build(), false, 1)


## Removes organ i, its cells with it; the later organs' digits move down one.
func _drop_organ(i: int) -> void:
	var id: String = enc.organs[i]
	enc.organs.remove_at(i)
	enc.cd_start.remove_at(i)
	if not id in enc.organs:
		enc.win.erase(id)
	for k in cells.keys():
		var g: String = cells[k]
		if g.is_valid_int():
			if int(g) == i + 1:
				cells.erase(k)
			elif int(g) > i + 1:
				cells[k] = str(int(g) - 1)
	if tool.is_valid_int() and int(tool) > enc.organs.size():
		tool = "x"
	_build()


func _load_page() -> void:
	Ui.centre(root, "LOAD", 8, Tuning.COLORS.pay, 2)
	var files := Array(DirAccess.get_files_at(DIR)).filter(func(f): return f.ends_with(".json"))
	if files.is_empty():
		Ui.centre(root, "NOTHING IN ENCOUNTERS/ YET", 40, Tuning.COLORS.rivet)
	for i in files.size():
		Ui.button(root, files[i].get_basename(), Ui.FIELD_X + 16 + 152 * (i % 3), 36 + 16 * (i / 3), 144, 12, _load.bind(DIR + files[i]), false, 1)
	Ui.button(root, "BACK", 264, 320, 112, 18, func(): page = "board"; _build(), false, 2, "ui_back")


# --- Board ---

func face(g: String) -> Texture2D:
	return Box.tex_of("organ_cell" if g.is_valid_int() else "brick_plain_dim" if g == "?" else Tuning.BRICKS[Tuning.BOARD_KEYS[g]].face)


## The cell of the piece covering cell c, or null.
func at(c: Vector2i) -> Variant:
	for k in [c, c - Vector2i(1, 0)]:
		if cells.has(k):
			return k
	return null


## A piece fits with its left cell at c: on the board and clear of every piece but those in skip.
func fits(c: Vector2i, skip := {}) -> bool:
	if c.x < 0 or c.y < 0 or c.x + 1 >= dims.x or c.y >= dims.y:
		return false
	for d in [-1, 0, 1]:
		var k := c + Vector2i(d, 0)
		if cells.has(k) and not skip.has(k):
			return false
	return true


func place(c: Vector2i) -> void:
	if tool and fits(c):
		cells[c] = tool
		Sfx.play("ui_click", 1.3)


func erase(c: Vector2i) -> void:
	var k = at(c)
	if k != null:
		cells.erase(k)
		sel.erase(k)
		Sfx.play("ui_click", 0.8)


## Moves the selection by d cells, or nothing when any piece would land off the board or on another.
func move(d: Vector2i) -> void:
	if d == Vector2i.ZERO:
		return
	if not sel.keys().all(func(k): return fits(k + d, sel)):
		Sfx.play("hit_refused")
		return
	var moved := {}
	for k in sel:
		moved[k + d] = cells[k]
		cells.erase(k)
	cells.merge(moved)
	sel = {}
	for k in moved:
		sel[k] = true


## Copies the selection; pastes it with its top-left at the cursor's brick, selected, when all of it fits.
func copy() -> void:
	if sel.is_empty():
		return
	var top := Vector2i(sel.keys().map(func(k): return k.x).min(), sel.keys().map(func(k): return k.y).min())
	clip = sel.keys().map(func(k): return [k - top, cells[k]])


func paste(to = null) -> void:  # to: the top-left cell, else the cursor's brick
	var at_c: Vector2i = to if to != null else grid.brick(grid.get_local_mouse_position())
	if clip.is_empty() or not clip.all(func(p): return fits(at_c + p[0])):
		Sfx.play("hit_refused")
		return
	sel = {}
	for p in clip:
		cells[at_c + p[0]] = p[1]
		sel[at_c + p[0]] = true
	Sfx.play("ui_pickup")


## Drops the pieces the new size leaves off the board.
func _crop() -> void:
	for k in cells.keys():
		if k.x + 1 >= dims.x or k.y >= dims.y:
			cells.erase(k)
	sel = {}


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if arena:
		if e.keycode == KEY_ESCAPE:
			_played(false, "STOPPED")
		return
	if not grid:
		return
	var ctrl: bool = e.ctrl_pressed or e.meta_pressed
	match e.keycode:
		KEY_C when ctrl: copy()
		KEY_V when ctrl: paste()
		KEY_D when ctrl:
			copy()
			paste()
		KEY_A when ctrl:
			for k in cells:
				sel[k] = true
		KEY_DELETE, KEY_BACKSPACE:
			for k in sel:
				cells.erase(k)
			sel = {}
		_: return
	get_viewport().set_input_as_handled()
	grid.queue_redraw()


# --- File, play ---

## The board as half-cell rows, every row dims.x glyphs.
func rows() -> Array:
	var out := []
	for r in dims.y:
		var line := []
		line.resize(dims.x)
		line.fill(".")
		for k in cells:
			if k.y == r:
				line[k.x] = cells[k]
				line[k.x + 1] = cells[k]
		out.append("".join(line))
	return out


## The ENCOUNTERS row: enc plus the board.
func row() -> Dictionary:
	var e := enc.duplicate(true)
	e.board = {half = true, rows = rows()}
	return e


func _save() -> void:
	if not file:
		file = "untitled"
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + file + ".json", FileAccess.WRITE)
	if not f:
		_say("SAVE FAILED: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(row().merged({loadout = loadout}), "\t", false) + "\n")
	_say("SAVED %s%s.json" % [DIR.trim_prefix("res://"), file])


func _load(path: String) -> void:
	var d = Game._ints(JSON.parse_string(FileAccess.get_file_as_string(path)))
	if typeof(d) != TYPE_DICTIONARY or not d.has("board") or not d.has("organs"):
		_say("NOT AN ENCOUNTER: " + path.get_file())
		return
	loadout = d.get("loadout", loadout)
	var rs: Array = d.board.rows
	dims = Vector2i(rs.map(func(l): return l.length()).max(), rs.size())
	cells = {}
	for r in rs.size():
		var c := 0
		while c < rs[r].length():
			if rs[r][c] == ".":
				c += 1
				continue
			cells[Vector2i(c, r)] = rs[r][c]
			c += 2
	d.erase("board")
	d.erase("loadout")
	enc = d
	sel = {}
	file = path.get_file().get_basename()
	page = "board"
	_say("LOADED " + file)


## Runs the encounter in arena.gd on a fresh in-memory run with the loadout. Never saved: run.json is only written by main.gd.
func _play() -> void:
	var glyphs := cells.values()
	for i in enc.organs.size():
		if not str(i + 1) in glyphs:
			_say("ORGAN %d HAS NO CELLS" % (i + 1))
			return
	if enc.win.is_empty():
		_say("NO ORGAN IS MARKED WIN")
		return
	if loadout.bag.is_empty():
		_say("THE BAG IS EMPTY")
		return
	Game.new_run()
	Game.run.merge({hp = loadout.hp, hp_max = loadout.hp, gold = loadout.gold, bag = loadout.bag.duplicate(true), relics = loadout.relics.duplicate()}, true)
	var a := Arena.new()
	a.enc = row()
	a.done.connect(func(win): _played(win, "WON" if win else "LOST"))
	root.queue_free()
	root = null
	arena = a
	add_child(a)


func _played(_win: bool, how: String) -> void:
	arena.queue_free()
	arena = null
	_say("%s, HP %d/%d" % [how, Game.run.hp, Game.run.hp_max])


## The board page's field: the arena's landmarks, the cells and pieces, and the mouse.
class Grid extends Control:
	var ed  # the editor; untyped, an inner class can't name its outer script
	var drag := {}  # {mode: paint, erase, move (from: the press's cell) or box (a: the press's px)}
	var o := Vector2.ZERO  # the board's top-left corner in field px: centred, its first row's centre at BOARD_TOP

	func _init(e) -> void:
		ed = e
		size = Vector2(Ui.FIELD_W, Ui.SIZE.y)
		focus_mode = FOCUS_CLICK  # a click takes the keys back from the name field
		o = Vector2(Ui.FIELD_W / 2.0 - ed.dims.x * CELL.x / 2, Tuning.BOARD_TOP / Fx.SCALE - CELL.y / 2)
		mouse_exited.connect(queue_redraw)
		set_drag_forwarding(Callable(), func(_p, d): return d is Dictionary and d.has("glyph"), _drop)

	## A palette entry dragged onto the board: it becomes the tool and lands where it was let go.
	func _drop(p: Vector2, d: Dictionary) -> void:
		ed.tool = d.glyph
		ed.place(brick(p))
		ed._build()

	func cell(p: Vector2) -> Vector2i:
		return Vector2i(((p - o) / CELL).floor())

	## The left cell of the brick whose centre is nearest p.
	func brick(p: Vector2) -> Vector2i:
		return Vector2i(floori((p.x - o.x) / CELL.x - 0.5), floori((p.y - o.y) / CELL.y))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			if not e.pressed:
				if drag.get("mode") == "move":
					ed.move(cell(e.position) - drag.from)
				elif drag.get("mode") == "box":
					var box := Rect2(drag.a, e.position - drag.a).abs()
					for k in ed.cells:
						if box.intersects(Rect2(o + Vector2(k) * CELL, CELL * Vector2(2, 1))):
							ed.sel[k] = true
				drag = {}
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				drag = {mode = "erase"}
				ed.erase(cell(e.position))
			elif e.button_index == MOUSE_BUTTON_LEFT:
				var k = ed.at(cell(e.position))
				if k != null:
					if e.shift_pressed and ed.sel.has(k):
						ed.sel.erase(k)
					elif e.shift_pressed:
						ed.sel[k] = true
					elif not ed.sel.has(k):
						ed.sel = {k: true}
					drag = {mode = "move", from = cell(e.position)}
				elif ed.tool:
					drag = {mode = "paint"}
					ed.place(brick(e.position))
				else:
					if not e.shift_pressed:
						ed.sel = {}
					drag = {mode = "box", a = e.position}
			queue_redraw()
		elif e is InputEventMouseMotion:
			match drag.get("mode"):
				"paint": ed.place(brick(e.position))
				"erase": ed.erase(cell(e.position))
			queue_redraw()

	func _draw() -> void:
		var C := Tuning.COLORS
		draw_rect(Rect2(0, 0, size.x, Tuning.TOP_WALL / Fx.SCALE), C.trim_lo)  # the band, above the top wall
		var band := Fx.frame("%s_idle" % ed.enc.band, ed.enc.w, 0)
		draw_texture(band, Tuning.ENEMY_FOOT / Fx.SCALE - Vector2(0, 24) - band.get_size() / 2)
		var floor_y := (Tuning.ARENA.y - Tuning.BOARD_FLOOR) / Fx.SCALE
		draw_dashed_line(Vector2(0, floor_y), Vector2(size.x, floor_y), C.pay_dim, 1, 4)  # no brick below
		draw_rect(Rect2(size.x / 2 - Tuning.PADDLE_WIDTH / 4, (Tuning.ARENA.y - Tuning.PADDLE_UP) / Fx.SCALE - 4, Tuning.PADDLE_WIDTH / 2, 8), C.trim_hi)
		for r in ed.dims.y:
			for c in ed.dims.x:
				draw_rect(Rect2(o + Vector2(c, r) * CELL, CELL), C.trim, false)
		var m := get_local_mouse_position()
		var d := Vector2(cell(m) - drag.from) * CELL if drag.get("mode") == "move" else Vector2.ZERO
		for k in ed.cells:
			var p := o + Vector2(k) * CELL + (d if ed.sel.has(k) else Vector2.ZERO)
			_piece(ed.cells[k], p + Vector2(CELL.x, CELL.y / 2))
			if ed.sel.has(k):
				draw_rect(Rect2(p, CELL * Vector2(2, 1)), C.pay, false)
		if drag.get("mode") == "box":
			draw_rect(Rect2(drag.a, m - drag.a).abs(), C.pay, false)
		elif not drag and ed.tool and Rect2(Vector2.ZERO, size).has_point(m) and ed.fits(brick(m)):
			_piece(ed.tool, o + Vector2(brick(m)) * CELL + Vector2(CELL.x, CELL.y / 2), 0.4)  # where a click lands

	func _piece(g: String, centre: Vector2, a := 1.0) -> void:
		var t: Texture2D = ed.face(g)
		var organ: bool = g.is_valid_int()
		var tint: Color = Tuning.organ(ed.enc.organs[int(g) - 1]).get("tint", Color.WHITE) if organ else Color.WHITE
		draw_texture(t, (centre - t.get_size() / 2).floor(), Color(tint, a))
		if organ or g == "?":
			draw_string(get_theme_default_font(), centre + Vector2(-1, 3), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(Tuning.COLORS.white if organ else Tuning.COLORS.bg, a))  # dark on the pale rolled brick
