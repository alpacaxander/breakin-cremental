class_name Board
extends RefCounted
## The brick grid of one level, and the geometry of the arena around it. A level's bricks as read from its scene
## are a Board (see Levels.read); a Round copies that board and plays on the copy.
##
## ROUND UNITS. Everything in the rules is measured in units. One unit is one screen pixel on a 16-row level, so
## the sizes in docs/art.md's "Level screen" table are the sizes in units at every level size.
##
##   x grows to the right, toward the back wall. y grows downward.
##   (0, 0) is the top left corner of the grid.
##
##      x = -lane()        x = 0                               x = size().x
##        open side          |                                    back wall
##          :                |                                       |
##          :   paddle lane  |  grid: cols x rows cells of 16 x 32   |     y = 0         top wall
##          :   (no bricks,  |  bricks sit in brick cells of 16 x 64 |
##          :    no items)   |                                       |     y = size().y  bottom wall
##
## The walls are lines with no thickness, at y = 0, y = size().y and x = size().x. The open side is the line
## x = -lane(); a ball that is wholly past it is lost. field() is the rectangle between those four lines.
##
## TO THE SCREEN. The grid area is fixed on screen at (154, 110), 1024 x 512, for every level. The level screen's
## Arena node sits at (154, 110) with scale zoom(), and its children draw in units, so
##     screen = Vector2(154, 110) + units * zoom()
## The paddle lane is 58 screen pixels wide at every level size, which makes it lane() = 58 / zoom() units.
## Text inside the arena (coin pop-ups) is placed with that formula but not scaled.
##
## BRICK CELLS. A brick is 1 column by 2 rows and always starts on an even row, so bricks are addressed by brick
## cell: Vector2i(column, brick row), with column in 0 ..< cols and brick row in 0 ..< rows / 2. Brick row r
## covers grid rows 2r and 2r + 1 (docs/design/levels.md counts grid rows: its "rows 8-9" is brick row 4).
## Every `cell` in the rules, in signals and in a saved layout is a brick cell. cell_rect() gives its rectangle.
## "A row" for a Zap is every brick cell with the same brick row.

const CELL := Vector2(16, 32)  ## One grid cell, in units
const BRICK := Vector2(16, 64)  ## One brick cell, in units. Also "a square" is BRICK.y on each side
const BASE_ROWS := 16  ## The level size at which one unit is one screen pixel
const LANE_PX := 58.0  ## The paddle lane's width in screen pixels, the same at every level size

## Grid rows. Even, set by the level.
var rows: int
## Grid columns: always rows * 4.
var cols: int:
	get:
		return rows * 4
## Every brick on the board, by brick cell. A cell with no entry is empty. A broken brick is erased.
var bricks: Dictionary[Vector2i, Brick] = {}


func _init(p_rows := BASE_ROWS) -> void:
	rows = p_rows


## Screen pixels per unit: 16 / rows.
func zoom() -> float:
	return float(BASE_ROWS) / rows


## The grid's size in units: cols * 16 by rows * 32. On screen this is always 1024 x 512.
func size() -> Vector2:
	return Vector2(cols, rows) * CELL


## The paddle lane's width in units.
func lane() -> float:
	return LANE_PX / zoom()


## Everything inside the walls, lane included: from the open side to the back wall.
func field() -> Rect2:
	return Rect2(-lane(), 0.0, lane() + size().x, size().y)


## The grid area: where bricks and placed items can be.
func grid() -> Rect2:
	return Rect2(Vector2.ZERO, size())


## True if `cell` is a brick cell of this board.
func has_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows / 2


## The rectangle of a brick cell, in units. A brick is drawn 1 unit smaller on every side (14 x 62).
func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * BRICK, BRICK)


## The brick cell that contains a point. It may be outside the board; check with has_cell().
func cell_at(point: Vector2) -> Vector2i:
	return Vector2i((point / BRICK).floor())


## The brick at a cell, or null.
func brick(cell: Vector2i) -> Brick:
	return bricks.get(cell)


## Bricks still to break before the level counts as cleared. Bricks the player placed are not counted.
func remaining() -> int:
	var n := 0
	for b: Brick in bricks.values():
		if not b.placed:
			n += 1
	return n


## A board that shares nothing with this one.
func copy() -> Board:
	var b := Board.new(rows)
	for cell: Vector2i in bricks:
		b.bricks[cell] = bricks[cell].copy()
	return b
