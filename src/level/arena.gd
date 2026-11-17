class_name LevelArena
extends Node2D
## The level screen's Arena node: a round drawn in round units (see Board, "TO THE SCREEN"). It sits at ORIGIN
## plus the effects' shake, scaled by the board's zoom. It reads the round and never changes it.
##
## Each child is one z layer (the numbers are fx.gd's seam). A layer has no script: it is drawn from here through
## its `draw` signal, and only when what it shows has changed.
##   Backdrop     0  the backdrop grid and the walls           when the round or the phase changes
##   BoardView   10  every brick, in one draw                  when a brick is hit or broken
##   ItemViews   10  the free-form placed items                with the round
##   PaddleView  10  the paddle; it is moved, not redrawn      with the round
##   BallViews   20  the balls                                 every frame of Play
##   Ghost      101  the item being dragged in Setup           when it moves. Over SetupUi (100): it follows the
##                   cursor over the tray
##   Fx              the effects, last, so their children sort between these (src/level/fx/fx.gd)
##
## The round steps 120 times a second and the screen draws at its own rate, so the paddle and the balls are
## drawn between where they were one step ago and where they are now (remember()). That is one step, 8 ms,
## behind the rules, and it is what keeps them steady on a display that is not 60 or 120 Hz.

## Where the grid's top left corner is on screen, and the arena's frame around it (docs/art.md, "Level screen").
const ORIGIN := Vector2(154, 110)
const FRAME := Rect2(96, 104, 1088, 524)
const WALL := 6.0  ## The walls' thickness, in screen pixels at every level size
const STRIPE := 4.0  ## The paddle's cyan stripe, in units
const MARK_RIM := 2.0  ## The dark rim around a Zap mark, in units, so it reads on a brick of any colour
const BLOCK_EDGE := 3.0  ## A block that never breaks (Growth) is a frame this thick round a base-colour centre, in units
const DASH := 6.0  ## The ghost's border: dashes this long, 2 units thick
const GHOST_EDGE := 2.0

var round: Round

var _setup := true
var _ghost: Layout.Item
var _ghost_fits := false
## Where each ball (by id) and the paddle were one step ago.
var _was: Dictionary[int, Vector2] = {}
var _was_paddle := 0.0

@onready var fx: Fx = $Fx
@onready var _backdrop: Node2D = $Backdrop
@onready var _bricks: Node2D = $BoardView
@onready var _items: Node2D = $ItemViews
@onready var _paddle: Node2D = $PaddleView
@onready var _balls: Node2D = $BallViews
@onready var _ghost_view: Node2D = $Ghost


func _ready() -> void:
	_backdrop.draw.connect(_draw_backdrop)
	_bricks.draw.connect(_draw_bricks)
	_items.draw.connect(_draw_items)
	_paddle.draw.connect(_draw_paddle)
	_balls.draw.connect(_draw_balls)
	_ghost_view.draw.connect(_draw_ghost)


## Draws `p_round` from now on. `setup` picks Setup's backdrop grid.
func show_round(p_round: Round, setup: bool) -> void:
	round = p_round
	_setup = setup
	scale = Vector2.ONE * round.board.zoom()
	round.brick_hit.connect(_bricks.queue_redraw.unbind(3))
	round.brick_broken.connect(_bricks.queue_redraw.unbind(5))
	round.grew.connect(_bricks.queue_redraw.unbind(3))
	remember()
	for layer: Node2D in [_backdrop, _bricks, _items, _paddle, _balls]:
		layer.queue_redraw()
	_process(0.0)


## Notes where the paddle and the balls are. The level screen calls it on every physics tick, before it steps
## the round or decides not to, so a round that stands still is drawn still.
func remember() -> void:
	_was_paddle = round.paddle.y
	_was.clear()
	for ball in round.balls:
		_was[ball.id] = ball.pos


## A point of the screen (the level screen's own coordinates) in round units. The shake is left out.
func to_units(point: Vector2) -> Vector2:
	return (point - ORIGIN) / round.board.zoom()


## Shows `item` as the placement ghost, in blue if it fits and in red if it does not; null shows none. A BRICK
## or MOD item is drawn on its cell, or at item.pos while that cell is off the board.
func ghost(item: Layout.Item, fits := false) -> void:
	_ghost = item
	_ghost_fits = fits
	_ghost_view.queue_redraw()


func _process(_delta: float) -> void:
	position = ORIGIN + fx.shake
	if round == null:
		return
	var p := round.paddle
	_paddle.position = Vector2(p.x - p.thickness, lerpf(_was_paddle, p.y, _between()) - p.length * 0.5)
	if not _setup:
		_balls.queue_redraw()


# How far the picture is from the step before (0) to the last step (1).
func _between() -> float:
	return 1.0 if _setup else Engine.get_physics_interpolation_fraction()


func _draw_backdrop() -> void:
	var size := round.board.size()
	if _setup:
		for x in range(0, int(size.x), int(Board.CELL.x)):
			_backdrop.draw_rect(Rect2(x, 0, 1, size.y), Palette.PANEL)
		for y in range(0, int(size.y), int(Board.CELL.y)):
			_backdrop.draw_rect(Rect2(0, y, size.x, 1), Palette.PANEL)
	var line := Palette.WALL if _setup else Palette.PANEL
	for x in range(0, int(size.x), int(Board.BRICK.y)):
		_backdrop.draw_rect(Rect2(x, 0, 2, size.y), line)
	for y in range(0, int(size.y), int(Board.BRICK.y)):
		_backdrop.draw_rect(Rect2(0, y, size.x, 2), line)
	# The walls keep their place and thickness on screen at every zoom.
	var px := 1.0 / round.board.zoom()
	var frame := Rect2((FRAME.position - ORIGIN) * px, FRAME.size * px)
	_backdrop.draw_rect(Rect2(frame.position, Vector2(frame.size.x, WALL * px)), Palette.WALL)
	_backdrop.draw_rect(Rect2(frame.position.x, size.y, frame.size.x, WALL * px), Palette.WALL)
	_backdrop.draw_rect(Rect2(size.x, frame.position.y, WALL * px, frame.size.y), Palette.WALL)


func _draw_bricks() -> void:
	var board := round.board
	for cell: Vector2i in board.bricks:
		var brick := board.bricks[cell]
		var rect := board.cell_rect(cell)
		_bricks.draw_rect(rect.grow(-1.0), Palette.lit_brick(brick))
		var kind := Kinds.of(brick.kind) as PlaceableKind
		if kind and kind.unbreakable:
			_bricks.draw_rect(rect.grow(-1.0 - BLOCK_EDGE), Palette.BASE)
		var mod := Kinds.of(brick.mod) as PlaceableKind
		if mod:
			var mark := Rect2(rect.get_center() - mod.size * 0.5, mod.size)
			_bricks.draw_rect(mark.grow(MARK_RIM), Palette.BASE)
			_bricks.draw_rect(mark, Palette.lit(Palette.of(mod.colour)))


func _draw_items() -> void:
	for item in round.layout.items:
		if item.kind.placement == PlaceableKind.Placement.FREE:
			_shape(_items, item, Palette.lit(Palette.of(item.kind.colour)))


func _draw_paddle() -> void:
	var p := round.paddle
	_paddle.draw_rect(Rect2(0, 0, p.thickness, p.length), Palette.PADDLE)
	_paddle.draw_rect(Rect2(p.thickness - STRIPE, 0, STRIPE, p.length), Palette.lit(Palette.PLAYER))
	if round.stats.rear_paddle > 0.0:  # Round.on_rear_paddle: the back wall's stretch facing this paddle
		var rear := round.board.size().x - p.x
		_paddle.draw_rect(Rect2(rear, 0, p.thickness, p.length), Palette.PADDLE)
		_paddle.draw_rect(Rect2(rear, 0, STRIPE, p.length), Palette.lit(Palette.PLAYER))


func _draw_balls() -> void:
	var t := _between()
	for ball in round.balls:
		var at: Vector2 = _was.get(ball.id, ball.pos).lerp(ball.pos, t)
		_balls.draw_rect(Rect2(at - Vector2.ONE * ball.size * 0.5, Vector2.ONE * ball.size), Palette.lit(Palette.BALL, Palette.LIT_BALL))


func _draw_ghost() -> void:
	if _ghost == null:
		return
	var fill := Palette.PLACEABLE_DIM if _ghost_fits else Palette.DANGER_DIM
	var edge := Palette.PLACEABLE if _ghost_fits else Palette.DANGER
	var kind := _ghost.kind
	if kind.placement == PlaceableKind.Placement.FREE:
		_shape(_ghost_view, _ghost, fill)
		if kind.shape == PlaceableKind.Shape.CIRCLE:
			var turn := GHOST_EDGE * DASH / kind.size.x  # the angle of one dash
			for i in int(TAU / turn / 2.0):
				_ghost_view.draw_arc(_ghost.pos, kind.size.x * 0.5, i * turn * 2.0, i * turn * 2.0 + turn, 4, edge, GHOST_EDGE)
		else:
			_dashed(_ghost.outline(), edge)
		return
	var cell := round.board.cell_rect(_ghost.cell)
	if round.board.has_cell(_ghost.cell):
		var under := Palette.PLAYER if _ghost_fits else Palette.DANGER
		_ghost_view.draw_rect(cell, Color(under, 0.12))
		_ghost_view.draw_rect(cell.grow(-0.5), Color(under, 0.5), false, 1.0)
	else:
		cell.position = _ghost.pos - cell.size * 0.5
	if kind.placement == PlaceableKind.Placement.BRICK:
		var body := cell.grow(-1.0 - GHOST_EDGE * 0.5)
		_ghost_view.draw_rect(body, fill)
		_dashed(Collide.box(body), edge)
	else:
		var mark := Rect2(cell.get_center() - kind.size * 0.5, kind.size)
		_ghost_view.draw_rect(mark.grow(MARK_RIM), Palette.BASE)
		_ghost_view.draw_rect(mark, edge)


# A free-form item's shape, filled.
func _shape(on: Node2D, item: Layout.Item, colour: Color) -> void:
	if item.kind.shape == PlaceableKind.Shape.CIRCLE:
		on.draw_circle(item.pos, item.kind.size.x * 0.5, colour, true, -1.0, true)
	else:
		on.draw_colored_polygon(item.outline(), colour)


func _dashed(outline: PackedVector2Array, colour: Color) -> void:
	for i in outline.size():
		_ghost_view.draw_dashed_line(outline[i], outline[(i + 1) % outline.size()], colour, GHOST_EDGE, DASH)
