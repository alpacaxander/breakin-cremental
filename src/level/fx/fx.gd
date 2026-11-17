class_name Fx
extends Node2D
## Everything that decorates a round and changes nothing in it: particles, shockwaves, light pools, the ball
## trail, coin pop-ups, screen shake, freezes, flashes, and the bloom that climbs with the combo
## (docs/art.md, "Effects"). It is built only from a round's signals and the state it reads from the round.
##
## THE SEAM WITH THE LEVEL SCREEN. The level screen owns everything outside src/level/fx/ and does seven things:
##   1. It has one Fx node, a Node2D with this script, as the last child of its Arena node. Arena sits at
##      (154, 110) with scale Board.zoom(), so Fx and its children draw in round units (see Board). Text is
##      the exception: a pop-up is placed in units but scaled back by 1 / zoom, so it keeps its pixel size.
##   2. It calls watch(round) once, when Play starts, with the round it is about to step, and clear() when that
##      round is thrown away (Retry, leaving the level).
##   3. On a physics tick where `frozen` is true it does not call Round.step.
##   4. Every frame it sets Arena's position to Vector2(154, 110) + shake.
##   5. It keeps what it draws inside Arena at these z_index values, so Fx can put its own children between
##      them: the backdrop grid at 0, bricks, placed items and the paddle at 10, balls at 20. Arena and the Fx
##      node themselves stay at z_index 0.
##   6. It gives Hud, SetupUi and Summary a z_index of 100. z_index sorts across the whole canvas layer, not
##      inside a parent, so without this anything in Arena above 0 would draw over the Summary. The one thing
##      over them is Setup's ghost, at 101: the held item follows the cursor over the tray.
##   7. Its root script has the three members a test or a shot drives it with (see play.gd): `round`, `fx` and
##      `start(seed)`. So an effect can be set off on the real screen:
##          var level := Main.show_level(1)
##          level.start(7)
##          level.round.blast(Vector2i(55, 3), 64.0)
## Fx's side of it: its children use z_index 1 to 99 and nothing else: 5 for light pools (under the bricks), 15
## for particles and shockwaves, 18 for pop-ups and 19 for the trail. So no effect, a flash included, covers the
## HUD or the Summary, and none covers a ball. Pop-up text uses UiTheme.numbers() and UiTheme.number_size(),
## because no theme reaches a Node2D's children.
## Fx also calls Main.set_bloom as the combo climbs and reads Settings.reduce_flashing. It never changes the
## round, the HUD or anything else the level screen draws.
##
## WHAT IS IN HERE. One script and four layers, each drawn from a plain list. There is no scene per effect.
##   squares   every particle, in fixed arrays of PARTICLES that are written round and round, so there are
##             never more. What a frame's breaks ask for is thinned evenly to DEBRIS (see _process).
##   shapes    a rectangle that grows and fades: a shockwave, an item's pulse, a Growth block's reach, the outline
##             closing on a brick a Refresh brought back, the Zap's bolt, the red bar where a ball left
##   marks     the same, but small and many: the flash of a brick a ball hit or a Growth pulse grew or a
##             Refresh brought back, and the combo's ring. Kept apart, so a run of them never pushes a shockwave out
##   pools     the light under an explosion
##   pops      "+12" and "+15s"
##   the trail is drawn from where each ball was on the last physics ticks.
## Every layer is clipped to the inside of the walls. Which signal sets off what is in the _on_ functions below;
## the numbers are the constants that follow.
## FADES. A lit colour is its palette colour times a strength (see _lit), and a fade lowers the strength, not
## the alpha: the picture shows every over-bright colour at its full hue, so a lit colour at half alpha looks
## the same as at full. Above a strength of 1 a thing glows less and less; under 1 it turns see-through.
## `heat` is how far the combo is up its curve, 0 to 1 (heat_of). Squares, shockwaves, the shake and the bloom
## all grow with it, and a ball's break gets a gold ring and gold squares that grow with it too.
## A freeze, a shake and a flash (a kick on top of the bloom) come with an explosion; a Zap freezes and shakes;
## a lost ball and the last brick of a clear shake, and the clear flashes. Nothing else freezes the game.
## Reduce flashing drops the light pools, the flashes and the red bar, halves the shake, and draws the Zap's
## bolt and a hit brick's flash no brighter than a brick. Shockwaves, squares, pop-ups and the trail stay.
## Left without an effect: a wall bounce (the wall is slate, and white is the ball's), the Shockwave upgrade
## (the ball it throws leaves with a longer trail, as any boosted ball does), and bricks Overgrowth brings back
## (they reappear in their 1 HP colour; see _on_restored).

# The combo.
const COMBO_TOP := 160  ## The combo count at which the effects are at their biggest
const COMBO_CURVE := 0.5  ## heat = (share of the way to COMBO_TOP) to this power. Under 1 rises fast, then eases
## The share of set_bloom's range the heat alone reaches. The rest is left to the flashes, so that a blast at the
## top of a combo still lights the screen.
const HEAT_BLOOM := 0.7
const BLOOM_RISE := 6.0  ## How fast the bloom follows the heat up, in set_bloom's 0..1 a second
const BLOOM_FALL := 2.0  ## and back down when the combo ends: half a second from the top
const FADE := 2.0  ## A fading thing's strength falls as (what is left of its life) to this power
const KICK_FALL := 3.0  ## How fast a flash (a kick on top of the bloom) dies away, a second
const MORE_SPARKS := 1.0  ## At full heat a burst has (1 + this) times the squares
const MORE_SIZE := 0.3  ## and a shockwave is (1 + this) times as big, and squares fly that much further
const MORE_SHAKE := 1.0  ## and a shake is (1 + this) times as strong

# Squares.
const PARTICLES := 600  ## The most squares alive at once
const DEBRIS := 240.0  ## The most squares one frame's breaks and hits may add, shared evenly between them
const DRAG := 7.0  ## How fast a square slows, a second. It lands its whole throw in about 3 / DRAG seconds
const LIFE := 0.55  ## Seconds a square lasts, at most
const SPREAD := 0.9  ## Radians to each side of the direction a break throws its squares in
const RIM := 1.0  ## The dark rim around a square, in units
const BREAK_SPARKS := 8.0
const BREAK_SIZE := Vector2(3, 5)  ## Smallest and biggest square, in units
const BREAK_THROW := Vector2(14, 80)  ## Nearest and farthest a square lands, in units
const HIT_SPARKS := 6.0  ## A brick that was hit and held: chips off the face the ball hit
const HIT_THROW := Vector2(14, 60)
const SPECIAL_SPARKS := 2.0  ## A special or placed brick throws this many times a plain brick's squares
const BREAK_POP := 8.0  ## A brick a ball broke is filled once more, growing by this as it goes, in units
const BREAK_POP_TIME := 0.08  ## Short: any longer and the brick still looks whole
const HIT_POP := 6.0  ## The same for a brick that held: its flash
const HIT_POP_TIME := 0.15
# A ball's break in a combo, in the combo's gold: a ring and squares. Each pair is the value as the combo starts
# and at COMBO_TOP.
const HOT_RING := Vector2(40, 120)  ## The ring's size
const HOT_WIDTH := Vector2(2, 5)  ## and its line
const HOT_SPARKS := 10.0  ## Gold squares at COMBO_TOP
const HOT_THROW := 1.6  ## They fly this many times as far as the brick's own, out into the open

# Shapes.
const SHAPES := 48  ## The most shapes at once, and the most marks
const RING_START := 0.35  ## A shockwave starts at this share of its peak size
const RING_BOOST := 8.0  ## Palette.lit's boost for outlines: a thin line shows no halo at the 4 of a filled shape
const SPECIAL_RING := 72.0  ## The ring from a gold or hourglass brick, a new ball, a lost ball, a multiplier step, time running out
const SPECIAL_TIME := 0.3
const ITEM_RING := 18.0  ## A placed item's outline grows by this when a ball bounces off it
const ITEM_TIME := 0.25
const ITEM_SPARKS := 4.0
const BOOST_SPARKS := 8.0  ## More of them off an item while the ball is boosted
const BOLT := 10.0  ## The Zap's bolt along its row: this thick at first, in units
const BOLT_TIME := 0.3
const PADDLE_RING := 34.0
const PADDLE_SPARKS := 5.0
const GROW_TIME := 0.5  ## A Growth pulse or bricks brought back (Refresh): outlines and the bricks flashing

# The explosion (docs/art.md). Sizes are for the base blast (a reach of one square) and grow with the reach.
const BLAST_RINGS: Array[float] = [96.0, 160.0]  ## Peak sizes
const BLAST_WIDTHS: Array[float] = [3.0, 2.0]
const BLAST_TIMES: Array[float] = [0.3, 0.45]
const BLAST_OUTER := 0.4  ## The outer shockwave's strength: an unlit echo of the inner one
const BLAST_SPARKS := 24.0
const BLAST_SIZE := Vector2(3, 6)
const BLAST_THROW := Vector2(24, 120)
const BLAST_MOST := 4  ## Explosions in one frame that throw squares. Each one after the first throws fewer
const CHAIN_GAP := 0.07  ## Seconds between the shockwaves of blasts that set each other off, so a chain reads as one
const POOL := 360.0  ## The light pool's width at the base blast. It grows by what the reach grows
const POOL_ALPHA := 0.24  ## at its centre
const POOL_FADE := 0.68  ## The share of its radius at which it has faded to nothing
const POOL_TIME := 0.5
const POOLS := 4
const POOL_SIDES := 16  ## Round: it is light, not a shape. As a square it showed its edges and its diagonals

# The ball's trail (docs/art.md): 7 squares at the base speed, and more behind a boosted ball.
const TRAIL := 7
const TRAIL_GAP := 13.0
const TRAIL_SIZE := Vector2(11, 5)  ## From the first square to the last
const TRAIL_ALPHA := Vector2(0.44, 0.08)
const TRAIL_SAMPLES := 24  ## Physics ticks of path kept for each ball; 20 cover the trail at any speed

# Pop-ups (docs/art.md).
const POPS := 6
const POP_SIZE := 36  ## Through UiTheme.number_size it is 37 px, the one size near it the pixel font has
## A coin pop-up's strength: the newest (lit), the one before it, and the rest. Older ones dim; they do not shrink.
const POP_STRENGTHS: Array[float] = [Palette.LIT, 0.6, 0.35]
const POP_TIME := 0.9
const POP_RISE := 40.0  ## Screen pixels
const POP_ABOVE := 6.0  ## Screen pixels between the brick and its pop-up
const POP_TALL := 20.0  ## Screen pixels from a pop-up's baseline to the top of its digits
const POP_RIM := 6  ## Screen pixels of dark rim around the text (3 on each side), so it reads on a brick of any colour
const POP_JOIN := 0.3  ## A coin pop-up younger than this, in seconds,
const POP_NEAR := 60.0  ## and this near, in screen pixels, takes the next coins: no new pop-up on top of it

# Shake, freeze, flash.
const SHAKE := 8.0  ## Screen pixels at full strength. Strength adds up, and the shake goes with its square
const SHAKE_TIME := 0.4  ## Seconds for full strength to die away
const SHAKE_CALM := 0.5  ## With reduce flashing on
const BREAK_SHAKE := 0.07  ## One break cannot be felt (0.07 squared); a chain can
const BLAST_SHAKE := 0.55
const ZAP_SHAKE := 0.4
const LOST_SHAKE := 0.8
const CLEAR_SHAKE := 1.0
const BLAST_FREEZE := 0.05  ## Seconds
const ZAP_FREEZE := 0.035
const FREEZE_GAP := 0.4  ## The least time from the end of one freeze to the start of the next
const BLAST_FLASH := 0.3  ## Added to the bloom, in set_bloom's 0..1
const STEP_FLASH := 0.15  ## The multiplier went up
const CLEAR_FLASH := 0.6

# The ball lost and the level cleared.
const LOST_BAR := 10.0  ## The red bar down the open side, in units
const LOST_TIME := 0.4
const LOST_SPARKS := 12
const CLEAR_RINGS: Array[float] = [300.0, 600.0, 900.0]  ## They cross the arena
const CLEAR_TIME := 0.6
const CLEAR_SPARKS := 40

const HEARD: Array[StringName] = [&"brick_hit", &"brick_broken", &"ball_bounced", &"ball_added", &"ball_lost",
		&"exploded", &"grew", &"restored", &"combo_changed", &"time_changed", &"ended"]


class Shape:
	var at: Vector2  ## The centre, in units
	var from: Vector2  ## Its size as it starts
	var to: Vector2  ## and at its peak, as it is gone
	var colour: Color  ## A palette colour
	var boost := RING_BOOST  ## Its strength as it starts (see _lit)
	var width := 0.0  ## The outline's width; 0 fills it
	var turn := 0.0
	var life := 0.3
	var age := 0.0  ## Below 0 it has not started


class Pop:
	var at: Vector2  ## The middle of the text's baseline as it starts, in units
	var text: String
	var colour: Color
	var coins := 0
	var age := 0.0


## True while the game should stand still: during the brief freeze on a big hit, which Fx counts down itself,
## or because someone set it (a test holds the round still with it). Fx never writes it but in clear().
var frozen := false:
	get:
		return frozen or _hold > 0.0
## How far to move the Arena this frame, in screen pixels (screen shake). Zero when nothing shakes.
var shake := Vector2.ZERO
## How far the combo is up its curve, 0 to 1.
var heat := 0.0

var _round: Round
var _px := 1.0  ## Units per screen pixel: 1 / zoom
var _field: Rect2  ## Inside the walls, in units

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _size := PackedFloat32Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _col := PackedColorArray()  ## Palette colours, in linear light
var _next := 0
var _live := 0
## What this frame's breaks and hits ask for: [area, colour, dir, how many, throw]. Dealt out in _process.
var _asked: Array[Array] = []
var _asked_n := 0.0
var _blasts := 0  ## Explosions this frame

var _shapes: Array[Shape] = []
var _marks: Array[Shape] = []  ## The small ones, kept apart so that a run of them never pushes a shockwave out
var _pools: Array[Shape] = []
var _pops: Array[Pop] = []
var _paid: Pop  ## The pop-up this frame's coins add up in
var _paths: Dictionary[int, PackedVector2Array] = {}  ## Where each ball was on the last ticks, newest first

var _strength := 0.0  ## The shake's, 0 to 1
var _hold := 0.0  ## Seconds of freeze left
var _rest := 0.0  ## Seconds until the next freeze may start
var _glow := 0.0  ## The bloom that follows the heat
var _kick := 0.0  ## The flash on top of it
var _sent := 0.0  ## What Main.set_bloom last got
var _multiplier := 1
var _stepped := false  ## The multiplier went up this frame
var _last := Vector2.ZERO  ## The centre of the brick hit or broken last

var _under := _layer(5, _draw_pools)
var _sparks := _layer(15, _draw_sparks)
var _tails := _layer(19, _draw_trail)
var _text := _layer(18, _draw_pops)


func _init() -> void:
	_pos.resize(PARTICLES)
	_vel.resize(PARTICLES)
	_size.resize(PARTICLES)
	_age.resize(PARTICLES)
	_life.resize(PARTICLES)
	_col.resize(PARTICLES)


## Starts decorating `round`: connects to its signals and reads its balls, board and combo from then on.
func watch(round: Round) -> void:
	clear()
	_round = round
	_px = 1.0 / round.board.zoom()
	_field = round.board.field()
	_text.scale = Vector2.ONE * _px  # text is not zoomed: the pop-up layer draws in screen pixels
	for sig in HEARD:
		round.connect(sig, Callable(self, "_on_" + sig))


## Forgets the round and removes every effect on screen. Also puts `frozen`, `shake` and the bloom back to rest.
func clear() -> void:
	if _round:
		for sig in HEARD:
			_round.disconnect(sig, Callable(self, "_on_" + sig))
	_round = null
	_age.fill(0.0)
	_life.fill(0.0)
	_live = 0
	_asked.clear()
	_asked_n = 0.0
	_blasts = 0
	_shapes.clear()
	_marks.clear()
	_pools.clear()
	_pops.clear()
	_paid = null
	_paths.clear()
	frozen = false
	shake = Vector2.ZERO
	heat = 0.0
	_strength = 0.0
	_hold = 0.0
	_rest = 0.0
	_glow = 0.0
	_kick = 0.0
	_sent = 0.0
	_multiplier = 1
	_stepped = false
	Main.set_bloom(0.0)
	_redraw()


## How far up the curve a combo of `count` is, 0 to 1.
static func heat_of(count: int) -> float:
	return pow(clampf((count - 1.0) / (COMBO_TOP - 1.0), 0.0, 1.0), COMBO_CURVE)


## How many squares are on screen.
func squares() -> int:
	return _live


func _physics_process(_delta: float) -> void:
	if _round == null:
		return
	# Every tick, a frozen one too: the trail is what the ball left behind, so it catches up with a ball that
	# stands still. Level steps the round before this runs, so path[1] is where Arena draws the ball from.
	for ball in _round.balls:
		var path: PackedVector2Array = _paths.get(ball.id, PackedVector2Array())
		path.insert(0, ball.pos)
		if path.size() > TRAIL_SAMPLES:
			path.resize(TRAIL_SAMPLES)
		_paths[ball.id] = path


func _process(delta: float) -> void:
	if _round == null:
		return
	_rest = maxf(_rest - delta, 0.0)
	_hold = maxf(_hold - delta, 0.0)
	if _strength > 0.0:  # `shake` is only written while a shake of our own runs: a test sets it by hand
		_strength = maxf(_strength - delta / SHAKE_TIME, 0.0)
		var reach := SHAKE * _strength * _strength * (SHAKE_CALM if Settings.reduce_flashing else 1.0)
		shake = (Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * reach).round()  # whole pixels: text stays sharp
	_glow = move_toward(_glow, heat, (BLOOM_RISE if heat > _glow else BLOOM_FALL) * delta)
	_kick = move_toward(_kick, 0.0, KICK_FALL * delta)
	var bloom := minf(_glow * HEAT_BLOOM + _kick, 1.0)
	if bloom != _sent:
		_sent = bloom
		Main.set_bloom(bloom)
	if _stepped:
		_stepped = false
		_ring(_last, SPECIAL_RING, 2.0, Palette.COINS, SPECIAL_TIME)
		_flash(STEP_FLASH)

	# A Zap breaks 63 bricks in one step and blasts chain, so what the frame asked for is dealt out here: every
	# break gets the same share of DEBRIS, and a row that broke at once sparkles evenly along its length.
	var share := minf(1.0, DEBRIS / maxf(_asked_n, 1.0))
	var owed := randf()
	for ask in _asked:
		owed += ask[3] * share
		while owed >= 1.0:
			owed -= 1.0
			_square(ask[0], ask[1], ask[2], ask[4], BREAK_SIZE)
	_asked.clear()
	_asked_n = 0.0
	_blasts = 0
	_paid = null

	if _live > 0:
		_live = 0
		var keep := exp(-DRAG * delta)
		var moved := (1.0 - keep) / DRAG
		for i in PARTICLES:
			var age := _age[i]
			if age < _life[i]:
				age += delta
				_age[i] = age
				_pos[i] += _vel[i] * moved
				_vel[i] *= keep
				if age < _life[i]:
					_live += 1
	for list: Array[Shape] in [_marks, _shapes, _pools]:
		for i in range(list.size() - 1, -1, -1):
			list[i].age += delta
			if list[i].age >= list[i].life:
				list.remove_at(i)
	for i in range(_pops.size() - 1, -1, -1):
		_pops[i].age += delta
		if _pops[i].age >= POP_TIME:
			_pops.remove_at(i)
	_redraw()


# --- What sets off what. ---

func _on_brick_hit(cell: Vector2i, _hp_left: int, cause: Round.Cause) -> void:
	var rect := _round.board.cell_rect(cell).grow(-1.0)
	_last = rect.get_center()
	var colour := Palette.brick(_round.board.brick(cell))
	var ball := _nearest(rect.get_center()) if cause == Round.Cause.BALL else null
	if ball == null:  # a blast or a Zap, which has its own picture: a few chips, every way
		_ask(rect, colour, Vector2.ZERO, HIT_SPARKS * 0.5, HIT_THROW)
		return
	# The ball is on the face it hit. The chips fly off that face, out into the open where they are seen (on
	# the brick they would be squares of its own colour), and the brick flashes.
	var at := ball.pos.clamp(rect.position, rect.end)
	_ask(Rect2(at, Vector2.ZERO), colour, at.direction_to(ball.pos), HIT_SPARKS, HIT_THROW)
	_pulse(rect, colour, HIT_POP, HIT_POP_TIME)


func _on_brick_broken(cell: Vector2i, brick: Brick, cause: Round.Cause, dir: Vector2, coins: int) -> void:
	var rect := _round.board.cell_rect(cell).grow(-1.0)
	var colour := Palette.brick(brick)
	_last = rect.get_center()
	var kind := Kinds.of(brick.kind)
	# A ball's squares fly back out with it, ahead of the ball as it leaves: it came through open space, so they
	# are seen. Thrown on the way the ball was going they fly over a wall of bricks of their own colour.
	var by_ball := cause == Round.Cause.BALL
	_ask(rect, colour, -dir if by_ball else dir,
			BREAK_SPARKS * (SPECIAL_SPARKS if kind else 1.0) * (1.0 + MORE_SPARKS * heat), BREAK_THROW * (1.0 + MORE_SIZE * heat))
	_shake(BREAK_SHAKE)
	if by_ball:
		# The brick flashes as it goes. Not for a blast or a Zap: they have a shockwave or a bolt, and the hole
		# they leave is the picture.
		_pulse(rect, colour, BREAK_POP, BREAK_POP_TIME)
	# In a combo a ball's break also rings and throws squares in the combo's gold, more the hotter it is: what
	# makes one break at x40 plainly bigger than one at x1, on a full wall of bricks too. Gold shows on every
	# brick colour; a ring in the brick's own colour was lost on a wall of it.
	if by_ball and heat > 0.0:
		var size := Vector2.ONE * lerpf(HOT_RING.x, HOT_RING.y, heat)
		_shape(_marks, _last, size * RING_START, size, Palette.COINS, lerpf(HOT_WIDTH.x, HOT_WIDTH.y, heat), SPECIAL_TIME)
		_ask(rect, Palette.COINS, -dir, HOT_SPARKS * heat, BREAK_THROW * HOT_THROW)
	# A brick worth more than one (gold) rings as it pays. The other special bricks have a signal of their own:
	# `exploded`, time_changed, ball_added.
	if kind is BrickKind and (kind as BrickKind).worth > 1:
		_ring(_last, SPECIAL_RING, 2.0, colour, SPECIAL_TIME)
	# A brick mod went off.
	# ponytail: every mod gets the Zap's bolt along its row, the only mod there is. A mod that does something
	# else needs a field on its kind that says what to draw.
	var mod := Kinds.of(brick.mod)
	if mod:
		var row := Vector2(_round.board.size().x, BOLT)
		# With reduce flashing it is unlit: a lit bar the width of the board is a flash.
		_shape(_shapes, Vector2(row.x * 0.5, _last.y), row, Vector2(row.x, 1.0), Palette.of(mod.colour), 0.0, BOLT_TIME).boost = 1.0 if Settings.reduce_flashing else Palette.LIT
		_shake(ZAP_SHAKE)
		_freeze(ZAP_FREEZE)
	if coins > 0:
		# ponytail: one pop-up for everything a frame pays, where its first brick broke, so a blast reads "+12"
		# and not twelve "+1". Two balls that break bricks far apart in the same frame share it; give each
		# cause its own if that is ever seen.
		if _paid == null:
			_paid = _pop(Vector2(_last.x, rect.position.y - POP_ABOVE * _px), Palette.COINS, true)
		_paid.coins += coins
		_paid.text = "+%d" % _paid.coins


func _on_exploded(pos: Vector2, reach: float, cells: Array[Vector2i]) -> void:
	var grow := reach / Board.BRICK.y * (1.0 + MORE_SIZE * heat)
	var wait := _blasts * CHAIN_GAP
	_ring(pos, BLAST_RINGS[0] * grow, BLAST_WIDTHS[0], Palette.EXPLOSIVE, BLAST_TIMES[0], wait)
	_ring(pos, BLAST_RINGS[1] * grow, BLAST_WIDTHS[1], Palette.EXPLOSIVE_DIM, BLAST_TIMES[1], wait).boost = BLAST_OUTER
	if not Settings.reduce_flashing:
		_shape(_pools, pos, Vector2.ZERO, Vector2.ONE * (POOL + 2.0 * (reach - Board.BRICK.y)), Palette.EXPLOSIVE, 0.0, POOL_TIME, wait)
		if _pools.size() > POOLS:
			_pools.pop_front()
	_flash(BLAST_FLASH)
	_shake(BLAST_SHAKE)
	_freeze(BLAST_FREEZE)
	# Two thirds orange, a third in the colours of the bricks it is about to hit.
	if _blasts < BLAST_MOST:
		var board := _round.board
		for i in int(BLAST_SPARKS * (1.0 + MORE_SPARKS * heat) / (1 + _blasts)):
			var colour := Palette.EXPLOSIVE if i % 3 != 0 or cells.is_empty() else Palette.brick(board.brick(cells.pick_random()))
			_square(Rect2(pos, Vector2.ZERO), colour, Vector2.ZERO, BLAST_THROW * grow, BLAST_SIZE)
	_blasts += 1


## A Growth block pulsed: a blue outline grows from the block out to the edge of its reach, and every brick that
## gained HP flashes in its new colour. No shake and no freeze: it is not a hit.
func _on_grew(cell: Vector2i, reach: float, cells: Array[Vector2i]) -> void:
	var rect := _round.board.cell_rect(cell).grow(-1.0)
	_shape(_shapes, rect.get_center(), rect.size, rect.size + Vector2.ONE * reach * 2.0, Palette.PLACEABLE, 2.0, GROW_TIME)
	for c in cells:
		_pulse(_round.board.cell_rect(c).grow(-1.0), Palette.brick(_round.board.brick(c)), HIT_POP, GROW_TIME)


## Bricks brought back (Refresh): an outline closing in on each, in the Placeables blue, as it flashes in, and the
## block that brought them flashing too. Overgrowth's (no block: Round.NOWHERE) have none: on level 3 hundreds
## come back in a few seconds, and one each would push the shockwaves and the combo's ring out of their lists.
func _on_restored(cell: Vector2i, cells: Array[Vector2i]) -> void:
	if cell == Round.NOWHERE:
		return
	_pulse(_round.board.cell_rect(cell).grow(-1.0), Palette.PLACEABLE, HIT_POP, GROW_TIME)
	for c in cells:
		var rect := _round.board.cell_rect(c).grow(-1.0)
		_shape(_shapes, rect.get_center(), rect.size + Vector2.ONE * HIT_POP * 2.0, rect.size, Palette.PLACEABLE, 2.0, GROW_TIME)
		_pulse(rect, Palette.brick(_round.board.brick(c)), HIT_POP, GROW_TIME)


func _on_ball_bounced(ball: Ball, hit: Hit) -> void:
	match hit.surface:
		Hit.Surface.PADDLE:
			var at := hit.point - hit.normal * ball.size * 0.5
			_ring(at, PADDLE_RING, 2.0, Palette.PLAYER, ITEM_TIME)
			_ask(Rect2(at, Vector2.ZERO), Palette.PLAYER, ball.dir, PADDLE_SPARKS, HIT_THROW * 1.5)
		Hit.Surface.ITEM:
			# The item's own outline, growing: a diamond off the Bumper, a bar off the Wall Segment, a frame round
			# the Booster's gate.
			var kind := hit.item.kind
			var colour := Palette.of(kind.colour)
			# A gate's only widens, opening round the line the ball went through.
			var size := kind.size
			var grow := Vector2(ITEM_RING * 2.0, 0.0) if kind.gate else Vector2.ONE * ITEM_RING
			_shape(_shapes, hit.item.pos, size, size + grow, colour, 2.0, ITEM_TIME, 0.0,
					deg_to_rad(kind.turn + hit.item.rot))
			_ask(Rect2(hit.point - hit.normal * ball.size * 0.5, Vector2.ZERO), colour, ball.dir,
					BOOST_SPARKS * ball.boost if ball.boost > 1.0 else ITEM_SPARKS, BREAK_THROW)
	# A wall bounce shows nothing: the wall is slate and the ball's own colour is the ball's alone.


## A Splitter made a ball.
func _on_ball_added(ball: Ball) -> void:
	_ring(ball.pos, SPECIAL_RING, 2.0, Palette.PLACEABLE, SPECIAL_TIME)


func _on_ball_lost(ball: Ball) -> void:
	_paths.erase(ball.id)
	# The ball is past the open side, outside the field, so its mark goes on the edge it left through.
	var at := Vector2(_field.position.x, ball.pos.y)
	_ring(at, SPECIAL_RING, 2.0, Palette.DANGER, SPECIAL_TIME)
	for i in LOST_SPARKS:
		_square(Rect2(at, Vector2.ZERO), Palette.DANGER, Vector2.RIGHT, BREAK_THROW * 1.5, BREAK_SIZE)
	if not Settings.reduce_flashing:  # the bar runs the height of the screen: a flash
		var bar := Vector2(LOST_BAR, _field.size.y)
		_shape(_shapes, Vector2(_field.position.x + LOST_BAR * 0.5, _field.get_center().y), bar, bar, Palette.DANGER, 0.0, LOST_TIME).boost = Palette.LIT
	_shake(LOST_SHAKE)


func _on_combo_changed(count: int, multiplier: int) -> void:
	heat = heat_of(count)
	_stepped = _stepped or multiplier > _multiplier
	_multiplier = multiplier


## An hourglass brick added time. It comes right after that brick's brick_broken, so _last is the brick.
func _on_time_changed(_seconds_left: float, added: float) -> void:
	var amount := "%d" % added if added == floorf(added) else "%.1f" % added
	_ring(_last, SPECIAL_RING, 2.0, Palette.TIME, SPECIAL_TIME)
	# Under the brick, as its coins are over it, and rising into the hole it left. A top-row brick's coins have no
	# room above it and _pop pushes them down to here, so the time keeps a text height under this frame's coins.
	var at := _last + Vector2(0.0, Board.BRICK.y * 0.5 + (POP_ABOVE + POP_TALL) * _px)
	if _paid:
		at.y = maxf(at.y, _paid.at.y + (POP_TALL + POP_RIM) * _px)
	_pop(at, Palette.TIME).text = "+%ss" % amount


func _on_ended(reason: Round.End) -> void:
	heat = 0.0  # the combo is over with the round, and the bloom comes down before the Summary shows
	match reason:
		Round.End.TIME:  # every ball stops in a ring of the timer's green
			for ball in _round.balls:
				_ring(ball.pos, SPECIAL_RING, 2.0, Palette.TIME, SPECIAL_TIME)
				for i in LOST_SPARKS:
					_square(Rect2(ball.pos, Vector2.ZERO), Palette.TIME, Vector2.ZERO, BREAK_THROW, BREAK_SIZE)
		Round.End.CLEARED:
			for i in CLEAR_RINGS.size():
				_ring(_last, CLEAR_RINGS[i], 3.0, Palette.PLAYER, CLEAR_TIME, i * CHAIN_GAP)
			for i in CLEAR_SPARKS:
				_square(Rect2(_last, Vector2.ZERO), Palette.PLAYER, Vector2.ZERO, BLAST_THROW * 1.5, BLAST_SIZE)
			_flash(CLEAR_FLASH)
			_shake(CLEAR_SHAKE)


# --- The pieces. ---

func _shake(strength: float) -> void:
	_strength = minf(_strength + strength * (1.0 + MORE_SHAKE * heat), 1.0)


## Stands the game still for `seconds`, unless a freeze is running or one ended less than FREEZE_GAP ago.
func _freeze(seconds: float) -> void:
	if _rest > 0.0:
		return
	_hold = seconds
	_rest = seconds + FREEZE_GAP


## A flash: `amount` on top of the bloom, dying away at once. Reduce flashing has none.
func _flash(amount: float) -> void:
	if not Settings.reduce_flashing:
		_kick = maxf(_kick, amount)


## Asks for `n` squares from somewhere in `area`, thrown along `dir` (ZERO: every way) to land between throw.x
## and throw.y units out. _process deals them out, fewer of each when the frame asks for more than DEBRIS.
func _ask(area: Rect2, colour: Color, dir: Vector2, n: float, throw: Vector2) -> void:
	_asked.append([area, colour, dir, n, throw])
	_asked_n += n


## One square in `colour` (a palette colour), now. It takes the place of the oldest when PARTICLES are out.
func _square(area: Rect2, colour: Color, dir: Vector2, throw: Vector2, size: Vector2) -> void:
	var i := _next
	_next = (i + 1) % PARTICLES
	var way := dir.rotated(randf_range(-SPREAD, SPREAD)) if dir else Vector2.from_angle(randf() * TAU)
	_pos[i] = area.position + area.size * Vector2(randf(), randf())
	_vel[i] = way * randf_range(throw.x, throw.y) * DRAG  # slowing by DRAG a second, it travels speed / DRAG
	_size[i] = randf_range(size.x, size.y)
	_col[i] = colour.srgb_to_linear()
	if _age[i] >= _life[i]:  # the place was free
		_live += 1
	_age[i] = 0.0
	_life[i] = LIFE * randf_range(0.6, 1.0)


## A rectangle in `colour` (a palette colour), added to `list` (_shapes, _marks or _pools), that grows from `from`
## to `to` and fades over `life`. It starts at RING_BOOST; set `boost` on what comes back for another strength.
func _shape(list: Array[Shape], at: Vector2, from: Vector2, to: Vector2, colour: Color, width: float, life: float, delay := 0.0, turn := 0.0) -> Shape:
	var shape := Shape.new()
	shape.at = at
	shape.from = from
	shape.to = to
	shape.colour = colour
	shape.width = width
	shape.life = life
	shape.age = -delay
	shape.turn = turn
	list.append(shape)
	if list.size() > SHAPES:
		list.pop_front()
	return shape


## A square shockwave in `colour` that grows to `size`.
func _ring(at: Vector2, size: float, width: float, colour: Color, life: float, delay := 0.0) -> Shape:
	return _shape(_shapes, at, Vector2.ONE * size * RING_START, Vector2.ONE * size, colour, width, life, delay)


## The flash of a brick a ball has just hit: the brick filled once more, swelling by `grow` as it fades. With
## reduce flashing it is no brighter than the brick.
func _pulse(rect: Rect2, colour: Color, grow: float, life: float) -> void:
	_shape(_marks, rect.get_center(), rect.size, rect.size + Vector2.ONE * grow, colour, 0.0, life).boost = Palette.LIT if Settings.reduce_flashing else RING_BOOST


## The ball nearest to `point`, or null when there is none. Round.brick_hit does not say which ball it was, but
## that ball is on the brick's face as the signal arrives.
func _nearest(point: Vector2) -> Ball:
	var best: Ball = null
	for ball in _round.balls:
		if best == null or ball.pos.distance_squared_to(point) < best.pos.distance_squared_to(point):
			best = ball
	return best


## `colour` (a palette colour) at `strength` times its palette value: lit while that is over 1, see-through
## under it. Every fade goes through here (see FADES at the top).
static func _lit(colour: Color, strength: float) -> Color:
	return Color(Palette.lit(colour, maxf(strength, 1.0)), minf(strength, 1.0))


## A pop-up whose text starts with its baseline at `at`, kept where its whole rise stays inside the arena. With
## `joins`, a coin pop-up that started close by a moment ago is handed back instead, to add to: a run of breaks
## side by side counts up in one place and does not pile its numbers on each other.
func _pop(at: Vector2, colour: Color, joins := false) -> Pop:
	var size := _round.board.size()
	at = Vector2(clampf(at.x, 40.0 * _px, size.x - 40.0 * _px), clampf(at.y, (POP_RISE + 40.0) * _px, size.y))
	if joins:
		for near in _pops:
			if near.coins > 0 and near.age < POP_JOIN and near.at.distance_to(at) < POP_NEAR * _px:
				return near
	var pop := Pop.new()
	pop.at = at
	pop.colour = colour
	_pops.append(pop)
	if _pops.size() > POPS:
		_pops.pop_front()
	return pop


func _layer(z: int, draws: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.z_index = z
	layer.draw.connect(_clip.bind(layer))
	layer.draw.connect(draws)
	add_child(layer)
	return layer


## Nothing shows outside the walls: a big shockwave or a thrown square would cross into the HUD's space.
## Every draw, as a Control with clip_contents does it: the server forgets the clip when an item is cleared.
func _clip(layer: Node2D) -> void:
	var k := 1.0 / layer.scale.x  # the pop-up layer is in screen pixels
	RenderingServer.canvas_item_set_custom_rect(layer.get_canvas_item(), true, Rect2(_field.position * k, _field.size * k))
	RenderingServer.canvas_item_set_clip(layer.get_canvas_item(), true)


func _redraw() -> void:
	for layer: Node2D in [_under, _sparks, _tails, _text]:
		layer.queue_redraw()


# --- Drawing. ---

func _draw_pools() -> void:
	for pool in _pools:
		if pool.age < 0.0:
			continue
		# Light falls off with the square of the way out, so it is drawn in two bands: to a quarter at half way,
		# then to nothing. One straight ramp reads as a flat disc with an edge.
		var fade := 1.0 - pool.age / pool.life
		var centre := Color(pool.colour, POOL_ALPHA * fade * fade)
		var half := Color(pool.colour, centre.a * 0.25)
		var rim := Color(pool.colour, 0.0)
		var reach := pool.to.x * 0.5 * POOL_FADE
		for i in POOL_SIDES:
			var a := Vector2.from_angle(i * TAU / POOL_SIDES) * reach
			var b := Vector2.from_angle((i + 1) * TAU / POOL_SIDES) * reach
			_under.draw_primitive(PackedVector2Array([pool.at, pool.at + a * 0.5, pool.at + b * 0.5]), PackedColorArray([centre, half, half]), PackedVector2Array())
			_under.draw_primitive(PackedVector2Array([pool.at + a * 0.5, pool.at + a, pool.at + b, pool.at + b * 0.5]), PackedColorArray([half, rim, rim, half]), PackedVector2Array())


func _draw_sparks() -> void:
	for shape: Shape in _marks + _shapes:
		if shape.age < 0.0:
			continue
		var t := shape.age / shape.life
		var size := shape.from.lerp(shape.to, 1.0 - (1.0 - t) * (1.0 - t))  # fast out, then easing
		var colour := _lit(shape.colour, shape.boost * pow(1.0 - t, FADE))
		_sparks.draw_set_transform(shape.at, shape.turn)
		if shape.width > 0.0:
			_sparks.draw_rect(Rect2(-size * 0.5, size), colour, false, shape.width)
		else:
			_sparks.draw_rect(Rect2(-size * 0.5, size), colour)
	_sparks.draw_set_transform(Vector2.ZERO)
	if _live == 0:
		return
	for i in PARTICLES:
		var age := _age[i]
		var life := _life[i]
		if age < life:
			var side := Vector2(_size[i], _size[i])
			var square := Rect2(_pos[i] - side * 0.5, side)
			# _lit, written out: this runs for every square. _col is already in linear light.
			var strength := Palette.LIT * pow(1.0 - age / life, FADE)
			var colour := (_col[i] * maxf(strength, 1.0)).linear_to_srgb()
			colour.a = minf(strength, 1.0)
			# A dark rim, as on the Zap mark: a brick's squares fly over bricks of their own colour.
			_sparks.draw_rect(square.grow(RIM), Color(Palette.BASE, colour.a))
			_sparks.draw_rect(square, colour)


func _draw_trail() -> void:
	if _round == null:
		return
	var between := Engine.get_physics_interpolation_fraction()
	for ball in _round.balls:
		var path: PackedVector2Array = _paths.get(ball.id, PackedVector2Array())
		if path.size() < 2:
			continue
		# The trail lasts a fixed time, so a boosted ball's is longer: the same squares at the same gap, more of them.
		var count := roundi(TRAIL * ball.boost)
		var at := path[1].lerp(path[0], between)  # where Arena draws the ball
		var next := 1
		var gap := TRAIL_GAP
		var drawn := 0
		while drawn < count and next < path.size():
			var left := at.distance_to(path[next])
			if left < gap:
				gap -= left
				at = path[next]
				next += 1
				continue
			at = at.move_toward(path[next], gap)
			gap = TRAIL_GAP
			var t := drawn / (count - 1.0)
			var side := Vector2.ONE * lerpf(TRAIL_SIZE.x, TRAIL_SIZE.y, t)
			_tails.draw_rect(Rect2(at - side * 0.5, side), Color(Palette.BALL, lerpf(TRAIL_ALPHA.x, TRAIL_ALPHA.y, t)))
			drawn += 1


func _draw_pops() -> void:
	var font := UiTheme.numbers()
	var size := UiTheme.number_size(POP_SIZE)
	var newer := 0  # coin pop-ups after this one. Only they age each other: "+15s" is rare and stays whole
	for pop in _pops:
		newer += 1 if pop.coins > 0 else 0
	for pop in _pops:  # oldest first, so the newest is on top
		newer -= 1 if pop.coins > 0 else 0
		var t := pop.age / POP_TIME
		var rise := POP_RISE * (1.0 - (1.0 - t) * (1.0 - t))
		var width := font.get_string_size(pop.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		# The layer is in screen pixels (see watch), and the text sits on whole ones, so the pixel font stays sharp.
		var at := (pop.at / _px - Vector2(width * 0.5, rise)).round()
		var colour := _lit(pop.colour, POP_STRENGTHS[mini(newer, POP_STRENGTHS.size() - 1) if pop.coins > 0 else 0] * (1.0 - t * t))
		# A dark rim, as on the Zap mark: on level 3 a pop-up is always over bricks.
		_text.draw_string_outline(font, at, pop.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, POP_RIM, Color(Palette.BASE, colour.a))
		_text.draw_string(font, at, pop.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
