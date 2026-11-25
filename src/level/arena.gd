class_name LevelArena
extends Node2D
## The level screen's Arena node: a round drawn in round units (see Board, "TO THE SCREEN"). It sits at ORIGIN
## plus the effects' shake, scaled by the board's zoom. It reads the round and never changes it.
##
## Each child is one z layer (the numbers are fx.gd's seam). A layer has no script: it is drawn from here through
## its `draw` signal, and only when what it shows has changed.
##   Backdrop     0  the backdrop grid and the walls           when the round or the phase changes
##   BoardView   10  every brick, in one draw                  when a brick is hit, broken, grown or brought back,
##                                                             and when a Refresh block's cooldown ends
##   ItemViews   10  the free-form placed items, and in Setup  with the round
##                   the areas (Growth) over the bricks
##   PaddleView  10  the paddle, cut off at the walls          every frame
##   BallViews   20  the Guide's line while a ball waits, the  every frame of Play
##                   drops, the charges in reserve, the balls
##   Ghost      101  the item being dragged in Setup           when it moves. Over SetupUi (100): it follows the
##                   cursor over the tray
##   Fx              the effects, last, so their children sort between these (src/level/fx/fx.gd)
##
## The round steps 120 times a second and the screen draws at its own rate, so the paddle, the balls and the
## drops are drawn between where they were one step ago and where they are now (remember()). That is one step, 8 ms,
## behind the rules, and it is what keeps them steady on a display that is not 60 or 120 Hz.

## Where the grid's top left corner is on screen, and the arena's frame around it (docs/art.md, "Level screen").
const ORIGIN := Vector2(154, 110)
const FRAME := Rect2(96, 104, 1088, 524)
const WALL := 6.0  ## The walls' thickness, in screen pixels at every level size
const STRIPE := 4.0  ## The paddle's cyan stripe, in units
const MARK_RIM := 2.0  ## The orange rim round a charged ball, in units; the ball inside it stays white
const BLOCK_EDGE := 3.0  ## A block that never breaks (Refresh) is a frame this thick round base-colour panes, in units
const DASH := 6.0  ## The ghost's border: dashes this long, 2 units thick
const GHOST_EDGE := 2.0
const AREA_ALPHA := 0.15  ## An area's fill in Setup, see-through so the bricks under it show
## A gate's look, as shares of its length so the tray's icon is the same picture smaller. At the 96 units of the
## Booster: caps 6 long, a centre line 2 thick in dashes 8 long that stops 4 short of each cap.
const GATE_POST := 1.0 / 16.0
const GATE_DASH := 1.0 / 12.0
const GATE_GAP := 1.0 / 24.0
const GATE_LINE := 2.0  ## The centre line's thickness, in units, at any length
## The Guide's line (Round.guide): cyan dashes this thick, half see-through so it stays under the bloom.
const GUIDE_WIDTH := 2.0
const GUIDE_ALPHA := 0.5
## The charges in reserve are stacked this many ball sizes apart.
const CHARGE_PITCH := 1.5

var round: Round

var _setup := true
var _ghost: Layout.Item
var _ghost_fits := false
## Where each ball and each drop (by id) and the paddle were one step ago.
var _was: Dictionary[int, Vector2] = {}
var _was_drops: Dictionary[int, Vector2] = {}
var _was_paddle := 0.0
var _cooling := 0

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
	round.restored.connect(_bricks.queue_redraw.unbind(2))
	remember()
	for layer: Node2D in [_backdrop, _bricks, _items, _paddle, _balls]:
		layer.queue_redraw()
	_process(0.0)


## Notes where the paddle, the balls and the drops are. The level screen calls it on every physics tick, before
## it steps the round or decides not to, so a round that stands still is drawn still.
func remember() -> void:
	_was_paddle = round.paddle.y
	_was.clear()
	for ball in round.balls:
		_was[ball.id] = ball.pos
	_was_drops.clear()
	for d in round.drops:
		_was_drops[d.id] = d.pos


## A point of the screen (the level screen's own coordinates) in round units. The shake is left out.
func to_units(point: Vector2) -> Vector2:
	return (point - ORIGIN) / round.board.zoom()


## Shows `item` as the placement ghost, in blue if it fits and in red if it does not; null shows none. A BRICK
## or AREA item is drawn on its cell, or at item.pos while that cell is off the board.
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
	_paddle.queue_redraw()  # half of it can be past a wall, and the part past it is cut off
	if not _setup:
		_balls.queue_redraw()
		var cooling := 0  # a block's cooldown ends with no signal: redraw when the number cooling changes
		for item in round.layout.items:
			var brick := round.board.brick(item.cell)
			if brick and brick.ready_at > round.clock:
				cooling += 1
		if cooling != _cooling:
			_cooling = cooling
			_bricks.queue_redraw()


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
		var kind := Kinds.of(brick.kind) as PlaceableKind
		var cooling := brick.ready_at > round.clock  # a Refresh block waiting: dim
		_bricks.draw_rect(rect.grow(-1.0), Palette.dim(kind.colour) if cooling else Palette.lit_brick(brick))
		if kind and kind.unbreakable:
			panes(_bricks, rect.grow(-1.0 - BLOCK_EDGE), kind.panes, BLOCK_EDGE, Palette.BASE)


## The inside of a block that never breaks: `count` panes of `colour` stacked in `inside`, `gap` apart, so the
## frame drawn under them shows between. Setup's tray draws its icon with this too.
static func panes(on: CanvasItem, inside: Rect2, count: int, gap: float, colour: Color) -> void:
	var tall := (inside.size.y - gap * (count - 1)) / count
	for i in count:
		on.draw_rect(Rect2(inside.position.x, inside.position.y + i * (tall + gap), inside.size.x, tall), colour)


## A gate (PlaceableKind.gate), `size` wide by long, centred on `at` and turned `angle` radians: a cap
## across each end, in `lit`, and between them an unlit span in `dim` with a dashed `lit` line down its middle,
## the line the ball crosses. Dashes because it can be crossed, so it never reads as a Wall Segment. The tray's icon
## is drawn with this too.
static func gate(on: CanvasItem, at: Vector2, size: Vector2, angle: float, lit: Color, dim: Color) -> void:
	var along := Vector2.DOWN.rotated(angle)
	var across := Vector2.RIGHT.rotated(angle)
	var post := size.y * GATE_POST
	var reach := size.y * 0.5 - post  # from the centre to the inner face of a post
	var w := across * size.x * 0.5
	on.draw_colored_polygon(PackedVector2Array([at - along * reach - w, at - along * reach + w,
			at + along * reach + w, at + along * reach - w]), dim)
	for end: float in [-1.0, 1.0]:
		var c := at + along * end * (reach + post * 0.5)
		var h := along * post * 0.5
		on.draw_colored_polygon(PackedVector2Array([c - h - w, c - h + w, c + h + w, c + h - w]), lit)
	var gap := reach - size.y * GATE_GAP
	on.draw_dashed_line(at - along * gap, at + along * gap, lit, minf(GATE_LINE, size.x * 0.34),
			size.y * GATE_DASH, false)


func _draw_items() -> void:
	for item in round.layout.items:
		if item.kind.placement == PlaceableKind.Placement.AREA and _setup:
			# ponytail: Setup only. In Play its pulses show it (Fx); draw it there too if players lose track of it.
			var r := _area(item)
			_items.draw_rect(r, Color(Palette.PLACEABLE, AREA_ALPHA))
			_items.draw_rect(r.grow(-1.0), Palette.PLACEABLE, false, 2.0)
			_items.draw_rect(round.board.cell_rect(item.cell).grow(-2.0), Palette.lit(Palette.PLACEABLE), false, 2.0)
		if item.kind.placement != PlaceableKind.Placement.FREE:
			continue
		if item.kind.gate:
			gate(_items, item.pos, item.kind.size, deg_to_rad(item.kind.turn + item.rot),
					Palette.lit(Palette.of(item.kind.colour)), Palette.dim(item.kind.colour))
		else:
			_shape(_items, item, Palette.lit(Palette.of(item.kind.colour)))


func _draw_paddle() -> void:
	var p := round.paddle
	var top := maxf(0.0, -_paddle.position.y)  # the part between the walls, in the paddle's own units
	var span := minf(p.length, round.board.size().y - _paddle.position.y) - top
	_paddle.draw_rect(Rect2(0, top, p.thickness, span), Palette.PADDLE)
	_paddle.draw_rect(Rect2(p.thickness - STRIPE, top, STRIPE, span), Palette.lit(Palette.PLAYER))
	if round.stats.rear_paddle > 0.0:  # Round.on_rear_paddle: the back wall's stretch facing this paddle
		var rear := round.board.size().x - p.x
		_paddle.draw_rect(Rect2(rear, top, p.thickness, span), Palette.PADDLE)
		_paddle.draw_rect(Rect2(rear, top, STRIPE, span), Palette.lit(Palette.PLAYER))


func _draw_balls() -> void:
	var guide := round.guide()  # empty unless a ball waits on the paddle and the Guide is owned
	for i in guide.size() - 1:
		_balls.draw_dashed_line(guide[i], guide[i + 1], Color(Palette.PLAYER, GUIDE_ALPHA), GUIDE_WIDTH, DASH)
	var t := _between()
	for d in round.drops:  # over the bricks and items they pass through, under the balls
		var at: Vector2 = _was_drops.get(d.id, d.pos).lerp(d.pos, t)
		_balls.draw_rect(Rect2(at - Vector2.ONE * d.size * 0.5, Vector2.ONE * d.size), Palette.lit(Palette.ABILITY))
	# The charges in reserve: ball squares up the strip behind the paddle, from the bottom wall, without the
	# ball's halo, so they never pass for one in play. The one on the paddle is drawn as a ball.
	# ponytail: one column, so about 25 fit on a 16-row board; the HUD's readout counts them past that.
	var s := round.stats.ball_size
	for i in round.charges:
		_balls.draw_rect(Rect2(-round.board.lane() + (round.stats.paddle_inset - s) * 0.5, round.board.size().y - (i + 1) * s * CHARGE_PITCH,
				s, s), Palette.lit(Palette.BALL))
	for ball in round.balls:
		var at: Vector2 = _was.get(ball.id, ball.pos).lerp(ball.pos, t)
		var square := Rect2(at - Vector2.ONE * ball.size * 0.5, Vector2.ONE * ball.size)
		if charged(round, ball):
			_balls.draw_rect(square.grow(MARK_RIM), Palette.lit(Palette.ABILITY))
		_balls.draw_rect(square, Palette.lit(Palette.BALL, Palette.LIT_BALL))


## Whether `ball` is drawn with the orange rim: it carries an ability, or it is the charge on the paddle and there
## is an ability to fire it with. The first ball, held on the paddle, is no charge.
static func charged(p_round: Round, ball: Ball) -> bool:
	return ball.charge != &"" or (ball == p_round.waiting and not p_round.held and p_round.ability != &"")


func _draw_ghost() -> void:
	if _ghost == null:
		return
	var fill := Palette.PLACEABLE_DIM if _ghost_fits else Palette.DANGER_DIM
	var edge := Palette.PLACEABLE if _ghost_fits else Palette.DANGER
	var kind := _ghost.kind
	if kind.placement == PlaceableKind.Placement.FREE:
		_shape(_ghost_view, _ghost, fill)
		_dashed(_ghost.outline(), edge)
		return
	var cell := round.board.cell_rect(_ghost.cell)
	if round.board.has_cell(_ghost.cell):
		var under := Palette.PLAYER if _ghost_fits else Palette.DANGER
		_ghost_view.draw_rect(cell, Color(under, 0.12))
		_ghost_view.draw_rect(cell.grow(-0.5), Color(under, 0.5), false, 1.0)
	else:
		cell.position = _ghost.pos - cell.size * 0.5
	if kind.placement == PlaceableKind.Placement.AREA:
		var r := _area(_ghost) if round.board.has_cell(_ghost.cell) else cell
		_ghost_view.draw_rect(r, Color(fill, 0.5))
		_dashed(Collide.box(r.grow(-GHOST_EDGE * 0.5)), edge)
	else:
		var body := cell.grow(-1.0 - GHOST_EDGE * 0.5)
		_ghost_view.draw_rect(body, fill)
		_dashed(Collide.box(body), edge)


# What an AREA item covers, cut to the board.
func _area(item: Layout.Item) -> Rect2:
	return item.kind.area(round.board, item.cell, round.stats).intersection(Rect2(Vector2.ZERO, round.board.size()))


# A free-form item's shape, filled.
func _shape(on: Node2D, item: Layout.Item, colour: Color) -> void:
	on.draw_colored_polygon(item.outline(), colour)


func _dashed(outline: PackedVector2Array, colour: Color) -> void:
	for i in outline.size():
		_ghost_view.draw_dashed_line(outline[i], outline[(i + 1) % outline.size()], colour, GHOST_EDGE, DASH)
