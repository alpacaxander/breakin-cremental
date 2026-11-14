extends RefCounted
## The three levels against docs/design/levels.md: names, sizes, totals and cells picked from its drawings.
## Cells are brick cells, Vector2i(column, brick row); levels.md's "rows 8-9" is brick row 4.

const LEVELS := {
	1: {"title": "Three Columns", "rows": 16, "bricks": 24, "top": 1, "at_top": 24, "hits": 24},
	2: {"title": "Checkerboard", "rows": 16, "bricks": 128, "top": 1, "at_top": 128, "hits": 128},
	3: {"title": "The Tunnel", "rows": 18, "bricks": 512, "top": 2, "at_top": 134, "hits": 646},
}
## HP at a cell, 0 for empty: grid corners, the first and last brick columns, and the pattern's edges.
const CELLS := {
	1: {
		Vector2i(0, 0): 0, Vector2i(63, 0): 0, Vector2i(0, 7): 0, Vector2i(63, 7): 0,
		Vector2i(52, 3): 0, Vector2i(53, 0): 1, Vector2i(53, 7): 1, Vector2i(54, 4): 0,
		Vector2i(55, 0): 1, Vector2i(55, 7): 1, Vector2i(56, 2): 0, Vector2i(57, 0): 1, Vector2i(57, 7): 1, Vector2i(58, 5): 0,
	},
	2: {
		Vector2i(0, 0): 0, Vector2i(63, 0): 0, Vector2i(0, 7): 0, Vector2i(63, 7): 0, Vector2i(23, 0): 0, Vector2i(56, 7): 0,
		Vector2i(24, 0): 1, Vector2i(27, 0): 1, Vector2i(28, 0): 0, Vector2i(24, 1): 0, Vector2i(28, 1): 1, Vector2i(31, 1): 1,
		Vector2i(48, 0): 1, Vector2i(51, 0): 1, Vector2i(52, 0): 0, Vector2i(55, 0): 0,
		Vector2i(24, 7): 0, Vector2i(28, 7): 1, Vector2i(52, 7): 1, Vector2i(55, 7): 1,
	},
	3: {
		Vector2i(0, 0): 0, Vector2i(71, 0): 0, Vector2i(0, 8): 0, Vector2i(71, 8): 0, Vector2i(3, 0): 0, Vector2i(68, 8): 0,
		Vector2i(4, 0): 2, Vector2i(4, 8): 2, Vector2i(5, 0): 1, Vector2i(67, 0): 1, Vector2i(67, 8): 1, Vector2i(30, 2): 1,
		Vector2i(4, 3): 2, Vector2i(30, 3): 2, Vector2i(67, 3): 2, Vector2i(5, 5): 2, Vector2i(67, 5): 2, Vector2i(30, 6): 1,
		Vector2i(4, 4): 0, Vector2i(30, 4): 0, Vector2i(67, 4): 0,
	},
}


func run(t: Node) -> void:
	t.check(Levels.count() == 3, "there are 3 levels")
	t.check(Levels.read(0) == null and Levels.read(4) == null, "read() of a level that does not exist is null")
	t.check(Levels.read(1).board != Levels.read(1).board, "each read() returns a new board")
	# The tile set every level is painted with: tile n is an n + 1 HP brick. No level uses the 3 and 4 HP tiles now.
	var tile_set: TileSet = load("res://levels/bricks.tres")  # kept in a variable: a tile reads its data through its set
	var tiles := tile_set.get_source(0) as TileSetAtlasSource
	for hp in range(1, 5):
		t.check(tiles.get_tile_data(Vector2i(hp - 1, 0), 0).get_custom_data(&"hp") == hp, "tile %d of bricks.tres is a %d HP brick" % [hp - 1, hp])
	for n: int in LEVELS:
		var want: Dictionary = LEVELS[n]
		var level := Levels.read(n)
		if level == null or level.board == null:
			t.check(false, "level %d reads as a LevelData with a board" % n)
			continue
		var board := level.board
		t.check(level.number == n and level.title == want.title, "level %d is number %d, %s" % [n, n, want.title])
		t.check(board.rows == want.rows and board.cols == want.rows * 4, "level %d is %d x %d" % [n, want.rows * 4, want.rows])
		var hits := 0
		var top := 0
		var at_top := 0
		var legal := true
		for cell: Vector2i in board.bricks:
			var b := board.brick(cell)
			hits += b.hp
			if b.hp > top:
				top = b.hp
				at_top = 0
			at_top += 1 if b.hp == top else 0
			legal = legal and board.has_cell(cell) and b.hp >= 1 and b.hp <= 4 and b.kind == &"" and b.mod == &"" and not b.placed
		t.check(legal, "level %d's bricks are standard, 1 to 4 HP, on cells of its grid" % n)
		t.check(board.bricks.size() == want.bricks and board.remaining() == want.bricks, "level %d has %d bricks" % [n, want.bricks])
		t.check(top == want.top and at_top == want.at_top, "level %d's toughest bricks have %d HP, and there are %d of them" % [n, want.top, want.at_top])
		t.check(hits == want.hits, "level %d takes %d hits to clear" % [n, want.hits])
		for cell: Vector2i in CELLS[n]:
			var b := board.brick(cell)
			var hp := b.hp if b else 0
			t.check(hp == CELLS[n][cell], "level %d's brick cell %s holds %s" % [n, cell, "%d HP" % hp if CELLS[n][cell] else "nothing"])
