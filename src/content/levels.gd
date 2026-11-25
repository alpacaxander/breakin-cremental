class_name Levels
## Finds the levels and reads them. The level screen, the hub's thumbnail, the tests and the balance bot all get
## a level through read(); nothing else opens a level scene.
##
## A level is the scene levels/level_<n>.tscn, numbered from 1 with no gaps. Adding a level is adding the next
## file. levels/level_0.tscn is the test level: count() leaves it out, so the hub never shows it and clearing it
## unlocks nothing; the Admin panel opens it (src/debug/admin.gd). The balance bot's own `level=0` is another thing.
##
## HOW A LEVEL IS WRITTEN. The scene's root is a TileMapLayer with levels/level.gd, which gives it `title` and
## `rows` (even; columns are always rows x 4). Its tile set is levels/bricks.tres, whose tiles are one brick cell
## (16 x 64), so a map cell is a Board brick cell, Vector2i(column, brick row), and one tile is one brick. A
## tile's HP is its custom data `hp`; each tile shows its HP as a digit and, in the editor, in the game's HP
## colour. A tile's custom data `kind` is "" for a standard brick, which every demo level's bricks are, or the id
## of a special brick painted into the level (the orange alternative of the 1 HP tile is a Power Brick); those
## are there every round, on top of the ones the round rolls. No brick read is placed. A tile outside the grid is
## an error and is left out.
##
## The tile whose `hp` is 0 (the hollow one with a cross) is not a brick: it marks a cell a skilled player aims
## for, such as a gap that lets the ball behind a wall. It goes to LevelData.aims, and only the balance bot reads
## those; the game never sees them.

const DIR := "res://levels"


## The scene of level `number`. The file may not exist.
static func path(number: int) -> String:
	return "%s/level_%d.tscn" % [DIR, number]


## How many levels there are: the highest n for which level_1 to level_n all exist.
static func count() -> int:
	var n := 0
	while ResourceLoader.exists(path(n + 1)):
		n += 1
	return n


## Level `number` as board data, or null if there is no such level. Each call returns a new LevelData, so the
## caller may keep it.
static func read(number: int) -> LevelData:
	if number < 0 or not ResourceLoader.exists(path(number)):
		return null
	var layer: TileMapLayer = load(path(number)).instantiate()
	var level := LevelData.new()
	level.number = number
	level.title = layer.title
	level.target = layer.target
	level.board = Board.new(layer.rows)
	for cell in layer.get_used_cells():
		var tile := layer.get_cell_tile_data(cell)
		var hp: int = tile.get_custom_data(&"hp")
		if not level.board.has_cell(cell):
			push_error("%s: the tile at %s is outside the %d-row grid" % [path(number), cell, layer.rows])
		elif hp == 0:
			level.aims.append(cell)
		else:
			level.board.bricks[cell] = Brick.new(hp, StringName(tile.get_custom_data(&"kind")))
	level.aims.sort()
	layer.free()
	return level
