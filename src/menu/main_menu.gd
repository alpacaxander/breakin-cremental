extends Control
## The main menu (docs/design/overview.md, "Flow"): the title, Play (Setup of the highest level unlocked; Esc there
## leads to the upgrades), Settings and Exit, in front of an empty arena
## drawn like the game's: walls, a paddle on the left with the ball resting by it, bricks at the back. It is the one
## screen with no way back, so Esc does nothing here. Focus starts on Play; the arrow keys, the mouse and Enter
## work it, and the focused button is the filled one (UiTheme.selection).

## "BREAKIN" in bricks, one string per letter, rows split by "/", "#" a brick.
const LETTERS: Array[String] = ["###./#..#/###./#..#/###.", "###./#..#/###./#.#./#..#", "###/#../##./#../###",
		".##./#..#/####/#..#/#..#", "#..#/#.#./##../#.#./#..#", "###/.#./.#./.#./###", "#..#/##.#/#.##/#..#/#..#"]
const LOGO_TOP := 124
const LOGO_CELL := 20  ## a brick of the title is this square, drawn 2 px smaller
## The title's rows, top to bottom, by the HP step of their colour.
const LOGO_HP: Array[int] = [4, 3, 2, 1, 1]

const WALL_TOP := 24  ## the arena's top wall; the bottom one mirrors it
const WALL := 6
const BACK_WALL := 1250
const BRICK := Vector2(16, 64)  ## a grid cell, as in the game. Drawn 1 px smaller on every side
## The columns of bricks in front of the back wall, front first, by HP. A row listed in MISSING is a front
## brick already broken.
const BRICK_HP: Array[int] = [1, 2, 3]
const MISSING: Array[int] = [2, 3, 7]
const PADDLE := Rect2(40, 364, 12, 96)  ## level with Play
const STRIPE := 4
const BALL := 12
const BALL_GAP := 48  ## from the paddle's stripe, as in Setup

@onready var _play: Button = %Play


func _ready() -> void:
	UiTheme.light(%Subtitle, Palette.COINS)
	_play.pressed.connect(func() -> void: Main.show_level(mini(Progress.unlocked, Progress.level_count)))
	(%Settings as Button).pressed.connect(Main.show_settings)
	(%Exit as Button).pressed.connect(Main.quit)
	UiTheme.selection($Buttons.get_children())
	_play.grab_focus()


func _draw() -> void:
	var rows: Array[String] = []
	for r in 5:
		rows.append(".".join(LETTERS.map(func(l: String) -> String: return l.split("/")[r])))
	var at := Vector2(roundf((size.x - rows[0].length() * LOGO_CELL) / 2), LOGO_TOP)
	for r in rows.size():
		for c in rows[r].length():
			if rows[r][c] == "#":
				draw_rect(Rect2(at + Vector2(c, r) * LOGO_CELL + Vector2.ONE, Vector2.ONE * (LOGO_CELL - 2)),
						Palette.lit(Palette.hp(LOGO_HP[r])))

	var bottom := size.y - WALL_TOP
	draw_rect(Rect2(0, WALL_TOP, BACK_WALL + WALL, WALL), Palette.WALL)
	draw_rect(Rect2(0, bottom - WALL, BACK_WALL + WALL, WALL), Palette.WALL)
	draw_rect(Rect2(BACK_WALL, WALL_TOP, WALL, bottom - WALL_TOP), Palette.WALL)
	var count := floori((bottom - WALL_TOP - 2 * WALL) / BRICK.y)
	var top := WALL_TOP + WALL + (bottom - WALL_TOP - 2 * WALL - count * BRICK.y) / 2
	for c in BRICK_HP.size():
		var x := BACK_WALL - (BRICK_HP.size() - c) * BRICK.x
		for r in count:
			if c == 0 and r in MISSING:
				continue
			draw_rect(Rect2(Vector2(x, top + r * BRICK.y) + Vector2.ONE, BRICK - Vector2(2, 2)),
					Palette.lit(Palette.hp(BRICK_HP[c])))

	draw_rect(PADDLE, Palette.PADDLE)
	draw_rect(Rect2(PADDLE.end.x - STRIPE, PADDLE.position.y, STRIPE, PADDLE.size.y), Palette.lit(Palette.PLAYER))
	var centre := PADDLE.get_center().y
	draw_rect(Rect2(PADDLE.end.x + BALL_GAP, centre - BALL / 2.0, BALL, BALL), Palette.lit(Palette.BALL, Palette.LIT_BALL))
