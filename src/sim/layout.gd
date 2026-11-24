class_name Layout
extends RefCounted
## The items a player placed on one level. The save keeps one per level; a round is built from one.
##
## SAVED FORM. to_data() gives an Array of Dictionaries, one per item, holding only JSON types:
##     {"kind": "wall_segment", "x": 600.0, "y": 256.0, "rot": 90.0}    a FREE item
##     {"kind": "splitter", "col": 30, "row": 3}                        a BRICK or AREA item
## "kind" is the PlaceableKind's id. x, y are the item's centre in round units; rot is in degrees. col, row are
## a brick cell (Board). from_data() reads the same thing and skips an entry whose kind no longer exists.
## The save is JSON, which hands every number back as a float, so from_data() reads "col": 30.0 as column 30.
## to_data() always writes col and row as ints and x, y and rot as floats: a layout that has been through the
## save file gives the same to_data() as it did before.
##
## VALIDITY. fits() is the only place that decides whether an item may be where it is. Setup calls it for the
## ghost under the cursor; loading calls it through fitted(). Overlap means sharing area: touching does not count.
## The one exception is the launch path (Round.launch_path), which an item may not touch from above or below.

## How far, in units, an item must stay from the launch path above and below it. Collide.overlap lets an overlap
## under SKIN pass, but the sweep has no such allowance: a corner that far into the path would take the launch's
## first bounce. So the path is tested this much taller than it is. One SKIN is the overlap that does not count,
## the other is the gap that is left, which is far more than rounding.
const CLEAR := Collide.SKIN * 2.0

class Item:
	extends RefCounted
	var kind: PlaceableKind
	## FREE: the centre of the shape, in round units. Not snapped to anything.
	var pos: Vector2
	## BRICK and AREA: the brick cell.
	var cell: Vector2i
	## FREE and kind.rotatable: degrees, clockwise on screen, added to kind.turn. 0 otherwise.
	var rot := 0.0


	## FREE only: the rectangle's four corners, in round units, turned by kind.turn + rot. fits() and the sweep
	## both work from this.
	func outline() -> PackedVector2Array:
		var out := PackedVector2Array()
		for corner in Collide.box(Rect2(-kind.size * 0.5, kind.size)):
			out.append(pos + corner.rotated(deg_to_rad(kind.turn + rot)))
		return out

var items: Array[Item] = []


## Reads the saved form. Never fails: anything it cannot read is skipped.
static func from_data(data: Array) -> Layout:
	var out := Layout.new()
	for entry: Variant in data:
		if not entry is Dictionary:
			continue
		var item := Item.new()
		item.kind = Kinds.of(StringName(str(entry.get("kind", "")))) as PlaceableKind
		if item.kind == null:
			continue
		if item.kind.placement == PlaceableKind.Placement.FREE:
			if not (_number(entry, "x") and _number(entry, "y")):
				continue
			item.pos = Vector2(entry.x, entry.y)
			if item.kind.rotatable and _number(entry, "rot"):
				item.rot = entry.rot
		else:
			if not (_number(entry, "col") and _number(entry, "row")):
				continue
			item.cell = Vector2i(int(entry.col), int(entry.row))
		out.items.append(item)
	return out


## The saved form of this layout.
func to_data() -> Array:
	var out := []
	for item in items:
		if item.kind.placement == PlaceableKind.Placement.FREE:
			out.append({"kind": String(item.kind.id), "x": float(item.pos.x), "y": float(item.pos.y), "rot": float(item.rot)})
		else:
			out.append({"kind": String(item.kind.id), "col": item.cell.x, "row": item.cell.y})
	return out


## How many items of a kind are in the layout.
func count(kind_id: StringName) -> int:
	var n := 0
	for item in items:
		if item.kind.id == kind_id:
			n += 1
	return n


## Puts an item in. It does not test it: call fits() first.
func add(item: Item) -> void:
	items.append(item)


## True if `item` may be added to this layout on `board`. `item` must not already be in the layout: to move an
## item, take it out, test the new place, then add it back. All of these must hold:
##   - Its count allows one more: count(kind.id) < stats.count(kind.id).
##   - FREE: the whole shape is inside board.grid(), which keeps it out of the paddle lane and off the walls. It
##     overlaps no brick of the board, no BRICK item's cell and no other FREE item. It is clear of the launch
##     path, which is the ball at rest and its way straight left to the paddle (Round.launch_path), by CLEAR
##     above and below. It may touch the right side of the ball at rest.
##   - BRICK: board.has_cell(cell). The cell holds no brick and no other BRICK item, no FREE item overlaps it,
##     and it is clear of the launch path in the same way.
##   - AREA: board.has_cell(cell) and no other AREA item is on that cell. Bricks and other items do not matter:
##     nothing touches an area.
## Pass the level's board as read (Levels.read), not a round's board, which already has the layout's bricks on it.
func fits(item: Item, board: Board, stats: Balance) -> bool:
	if count(item.kind.id) >= stats.count(item.kind.id):
		return false
	if item.kind.placement == PlaceableKind.Placement.AREA:
		return board.has_cell(item.cell) and _on(item.cell, PlaceableKind.Placement.AREA) == null
	var shape: PackedVector2Array
	if item.kind.placement == PlaceableKind.Placement.BRICK:
		if not board.has_cell(item.cell) or board.brick(item.cell) != null or _on(item.cell, PlaceableKind.Placement.BRICK) != null:
			return false
		shape = Collide.box(board.cell_rect(item.cell))
	else:
		shape = item.outline()
		var bounds := Rect2(shape[0], Vector2.ZERO)
		for point in shape:
			if not board.grid().grow(Collide.SKIN).has_point(point):
				return false
			bounds = bounds.expand(point)
		var first := board.cell_at(bounds.position)
		var last := board.cell_at(bounds.end)
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				if board.bricks.has(Vector2i(x, y)) and Collide.overlap(shape, Collide.box(board.cell_rect(Vector2i(x, y)))):
					return false
	if Collide.overlap(shape, Collide.box(Round.launch_path(board, stats).grow_individual(0.0, CLEAR, 0.0, CLEAR))):
		return false
	for other in items:
		match other.kind.placement:
			PlaceableKind.Placement.FREE:
				if Collide.overlap(shape, other.outline()):
					return false
			PlaceableKind.Placement.BRICK:
				if Collide.overlap(shape, Collide.box(board.cell_rect(other.cell))):
					return false
	return true


## A new layout holding every item of this one that fits, tested one at a time in order. So when a count went
## down the later items of that kind are the ones dropped. The items themselves are shared with this layout, not
## copied.
func fitted(board: Board, stats: Balance) -> Layout:
	var out := Layout.new()
	for item in items:
		if out.fits(item, board, stats):
			out.add(item)
	return out


## Takes an item out.
func remove(item: Item) -> void:
	items.erase(item)


## The item whose shape contains `point` (round units), or null. The topmost is the last one added. A BRICK item
## is hit anywhere in its cell. An AREA item is hit anywhere in its own cell, after every other item there.
func item_at(point: Vector2) -> Item:
	var cell := Vector2i((point / Board.BRICK).floor())
	for i in range(items.size() - 1, -1, -1):
		var item := items[i]
		match item.kind.placement:
			PlaceableKind.Placement.BRICK:
				if item.cell == cell:
					return item
			PlaceableKind.Placement.FREE:
				if Geometry2D.is_point_in_polygon(point, item.outline()):
					return item
	return _on(cell, PlaceableKind.Placement.AREA)


# The item of one placement on a brick cell, or null.
func _on(cell: Vector2i, placement: PlaceableKind.Placement) -> Item:
	for item in items:
		if item.kind.placement == placement and item.cell == cell:
			return item
	return null


static func _number(entry: Dictionary, key: String) -> bool:
	return entry.get(key) is float or entry.get(key) is int
