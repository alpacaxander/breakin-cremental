extends PanelContainer
## The level panel (docs/art.md, "Upgrade screen"): ◄ ► through the levels, the chosen level's number, name and
## a thumbnail of its bricks, and Play Level. A locked level can be looked at (its thumbnail at 35%) but not
## played: its button is disabled and says which level opens it.

const THUMB := Vector2(256, 128)
const LOCKED_ALPHA := 0.35

## The level on show, counted from 1.
var level := 1

var _data: Dictionary[int, LevelData] = {}  # Levels.read builds a scene each call, so each level is read once

@onready var _thumb: Control = %Thumb
@onready var _play: Button = %Play


func _ready() -> void:
	(%Prev as Button).icon = UiTheme.icon(UiGlyph.Shape.PREV)
	(%Next as Button).icon = UiTheme.icon(UiGlyph.Shape.NEXT)
	_play.icon = UiTheme.icon(UiGlyph.Shape.PLAY, 18)
	%Prev.pressed.connect(func() -> void: pick(level - 1))
	%Next.pressed.connect(func() -> void: pick(level + 1))
	_play.pressed.connect(_on_play)
	_thumb.draw.connect(_draw_thumb)
	level = Progress.unlocked


## Shows level `n`, kept between 1 and the last level.
func pick(n: int) -> void:
	level = clampi(n, 1, maxi(1, Progress.level_count))
	refresh()


func refresh() -> void:
	level = clampi(level, 1, maxi(1, Progress.level_count))
	var open := Progress.is_unlocked(level)
	var data := _read(level)
	(%Number as Label).text = str(level)
	(%Title as Label).text = data.title if data else ""
	(%Status as Label).text = "CLEARED" if level < Progress.unlocked else "NOT CLEARED YET" if open else "LOCKED"
	%Prev.disabled = level <= 1
	%Next.disabled = level >= Progress.level_count
	_thumb.modulate.a = 1.0 if open else LOCKED_ALPHA
	_thumb.queue_redraw()
	_play.disabled = not open
	_play.text = "PLAY LEVEL" if open else "CLEAR LEVEL %d FIRST" % (level - 1)
	_play.icon = UiTheme.icon(UiGlyph.Shape.PLAY, 18) if open else null


func _on_play() -> void:
	if Progress.is_unlocked(level):
		Main.show_level(level)


func _read(n: int) -> LevelData:
	if not _data.has(n):
		_data[n] = Levels.read(n)
	return _data[n]


## The whole grid scaled to fit THUMB: 4 x 8 px a cell on a 16-row level, each brick 1 px short each way.
func _draw_thumb() -> void:
	_thumb.draw_rect(Rect2(Vector2.ZERO, THUMB), Palette.BASE)
	_thumb.draw_rect(Rect2(-Vector2(3.5, 3.5), THUMB + Vector2(7, 7)), Palette.WALL, false, 1)
	var data := _read(level)
	if data == null:
		return
	var board := data.board
	var k := minf(THUMB.x / board.size().x, THUMB.y / board.size().y)
	var at := (THUMB - board.size() * k) / 2
	for cell: Vector2i in board.bricks:
		var r := board.cell_rect(cell)
		_thumb.draw_rect(Rect2(at + r.position * k, r.size * k - Vector2.ONE), Palette.hp(board.bricks[cell].hp))
