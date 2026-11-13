class_name Layout
extends RefCounted
## The items a player placed on one level. The save keeps one per level; a round is built from one.
##
## STUB: the rules lane writes the bodies.
##
## SAVED FORM. to_data() gives an Array of Dictionaries, one per item, holding only JSON types:
##     {"kind": "wall_segment", "x": 600.0, "y": 256.0, "rot": 90.0}    a FREE item
##     {"kind": "splitter", "col": 30, "row": 3}                        a BRICK or MOD item
## "kind" is the PlaceableKind's id. x, y are the item's centre in round units; rot is in degrees. col, row are
## a brick cell (Board). from_data() reads the same thing and skips an entry whose kind no longer exists.
## The save is JSON, which hands every number back as a float, so from_data() reads "col": 30.0 as column 30.
## to_data() always writes col and row as ints and x, y and rot as floats: a layout that has been through the
## save file gives the same to_data() as it did before.
##
## VALIDITY. fits() is the only place that decides whether an item may be where it is. Setup calls it for the
## ghost under the cursor; loading calls it through fitted(). Overlap means sharing area: touching does not count.

class Item:
	extends RefCounted
	var kind: PlaceableKind
	## FREE: the centre of the shape, in round units. Not snapped to anything.
	var pos: Vector2
	## BRICK and MOD: the brick cell.
	var cell: Vector2i
	## FREE and kind.rotatable: degrees, clockwise on screen, added to kind.turn. 0 otherwise.
	var rot := 0.0

var items: Array[Item] = []


## Reads the saved form. Never fails: anything it cannot read is skipped.
static func from_data(_data: Array) -> Layout:
	return Layout.new()


## The saved form of this layout.
func to_data() -> Array:
	return []


## How many items of a kind are in the layout.
func count(_kind_id: StringName) -> int:
	return 0


## Puts an item in. It does not test it: call fits() first.
func add(_item: Item) -> void:
	pass


## True if `item` may be added to this layout on `board`. `item` must not already be in the layout: to move an
## item, take it out, test the new place, then add it back. All of these must hold:
##   - Its count allows one more: count(kind.id) < stats.count(kind.id).
##   - FREE: the whole shape is inside board.grid(), which keeps it out of the paddle lane and off the walls. It
##     overlaps no brick of the board, no BRICK item's cell, no other FREE item, and not the ball at rest (see
##     Round, "Building").
##   - BRICK: board.has_cell(cell). The cell holds no brick and no other BRICK item, and no FREE item and not the
##     ball at rest overlap it.
##   - MOD: the cell holds a brick of the board or a BRICK item, and no other MOD item is on that cell.
## Pass the level's board as read (Levels.read), not a round's board, which already has the layout's bricks on it.
func fits(_item: Item, _board: Board, _stats: Balance) -> bool:
	return false


## A new layout holding every item of this one that fits, tested one at a time in order, BRICK and FREE items
## first and MOD items after them. So when a count went down the later items of that kind are the ones dropped,
## and a Zap whose brick is gone is dropped with it.
func fitted(_board: Board, _stats: Balance) -> Layout:
	return Layout.new()


## Takes an item out. Taking out a BRICK item also takes out a MOD item on its cell.
func remove(_item: Item) -> void:
	pass


## The item whose shape contains `point` (round units), or null. The topmost is the last one added. A BRICK item
## is hit anywhere in its cell. A MOD item is checked before the brick under it.
func item_at(_point: Vector2) -> Item:
	return null
