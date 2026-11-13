class_name Round
extends RefCounted
## One attempt at a level: the board, the balls, the paddle, the placed items, the combo, the timer and the tally.
## It has no nodes, draws nothing and plays nothing. Screens read its state every frame and connect to its
## signals; effects and sound are built from those two things alone.
##
## STUB: the rules lane writes the bodies. The names, types, units, signal payloads and the order of events
## below are the contract the screens, the effects, the sound and the bot are written against.
##
## INPUTS. A round is built from four things and reads nothing else, so the same four inputs and the same
## paddle targets always give the same round:
##   board   the level's bricks (Levels.read(n).board). The round copies it; the caller's board is not changed.
##   layout  the items the player placed, or null for none. Items that do not fit are dropped.
##   stats   a Balance snapshot (Progress.snapshot()). Every number the rules use comes from it.
##   seed    for the round's own random numbers. The level screen picks a new one for every attempt.
## Kinds are looked up by id through Kinds, which is fixed data, not state.
##
## BUILDING, in this order:
##   1. The board is copied.
##   2. Special bricks are rolled. For each BrickKind in Kinds.bricks() order, stats.count(kind.id) times: one
##      of the standard bricks left (kind &"", not placed) is picked with `rng`, its kind is set and its hp
##      becomes kind.hp. Rolling stops when no standard brick is left. The roll depends on the board, the stats
##      and the seed only, never on the layout, so building again with the same seed and an edited layout gives
##      the same special bricks. Setup relies on this: it shows a round, and Start builds it again.
##   3. The layout is fitted (Layout.fitted) and applied: a BRICK item becomes a placed brick (Brick.placed,
##      kind = the item's kind id, hp = kind.hp), a MOD item sets Brick.mod on the brick at its cell, a FREE
##      item is an obstacle. `layout` holds the fitted layout afterwards.
##   4. The paddle is centred (paddle.y = board.size().y / 2). One ball is at rest: its centre is at
##      x = paddle.x + stats.launch_gap + stats.ball_size / 2, y = paddle.y, its dir is LEFT, its boost is 1.
##      time_left is stats.round_time.
## Nothing moves until step() is called. The first step sends the ball straight left into the paddle.
##
## ONE STEP, in this order:
##   1. The paddle moves toward paddle_target at stats.paddle_speed.
##   2. Each ball, in `balls` order, moves speed_of(ball) * delta along its dir. Movement is swept, so nothing is
##      passed through. Every contact is resolved where it happens and its signals are emitted then.
##   3. The combo's window counts down. If it runs out the combo resets and combo_changed(0, 1) is emitted.
##   4. time_left counts down.
##   5. The round ends if board.remaining() is 0 (CLEARED), else if no ball is left (BALL_LOST), else if
##      time_left is 0 or less (TIME). `ended` is emitted once; after it step() does nothing.
##
## ONE BRICK HIT (hit_brick), in this order:
##   The brick loses 1 hp.
##   If it has hp left: brick_hit is emitted.
##   If not: it is erased from the board. If combos are on (stats.combo_rank >= 1) the combo grows and
##   combo_changed is emitted, so the break is paid at the multiplier it just reached. The tally and `coins`
##   are updated. brick_broken is emitted. Then its kind's on_broken hook runs, then its mod's on_host_broken.
##   Hits a hook asks for (a blast, a Zap) go through hit_brick too, so chains need no special case.

## What hit a brick.
enum Cause {
	BALL,
	BLAST,  ## An explosion
	ZAP,  ## A brick mod's effect
}

## Why the round ended.
enum End {
	TIME,  ## The timer ran out
	BALL_LOST,  ## The last ball left through the open side
	CLEARED,  ## Every brick that counts is broken
}

## A brick took a hit and is still there. `hp_left` is its hp after the hit; board.brick(cell) is the brick.
signal brick_hit(cell: Vector2i, hp_left: int, cause: Cause)

## A brick broke. It is already off the board.
##   brick  the brick that broke, with hp 0. Its kind, mod and placed flag are as they were, so
##          Palette.brick(brick) is the colour it had (a plain brick always breaks from its 1 HP colour).
##   dir    a unit vector for the debris: the ball's direction of travel as it hit (BALL), away from the
##          blast's centre (BLAST), or along the row away from the tagged brick, LEFT or RIGHT (ZAP).
##   coins  what this break added to `coins`. 0 for a placed brick.
## combo.count and combo.multiplier already include this break.
signal brick_broken(cell: Vector2i, brick: Brick, cause: Cause, dir: Vector2, coins: int)

## A ball bounced off a wall, the paddle or a free-form placed item. Not emitted for bricks: those give brick_hit
## or brick_broken. ball.dir is the new direction. For an ITEM, the item's on_ball_hit hook has already run.
signal ball_bounced(ball: Ball, hit: Hit)

## A ball was made during play (a Splitter). It is already in `balls`. The ball a round starts with is not
## announced; read `balls` after building the round.
signal ball_added(ball: Ball)

## A ball left through the open side. It is already out of `balls`; ball.pos is where it left.
signal ball_lost(ball: Ball)

## An explosion went off. Emitted before its hits land, so every brick in `cells` is still on the board.
##   pos    the centre of the brick that exploded, in units
##   reach  how far the blast reaches out from that brick's edges, in units
##   cells  every brick cell the blast is about to hit
signal exploded(pos: Vector2, reach: float, cells: Array[Vector2i])

## The combo grew, or it reset (count 0, multiplier 1). Not emitted while combos are off.
signal combo_changed(count: int, multiplier: int)

## Time was added to the timer (an hourglass brick). `added` is the seconds added.
signal time_changed(seconds_left: float, added: float)

## The round is over. Emitted once.
signal ended(reason: End)

var board: Board
## The items that fitted. Its FREE items are the obstacles in play, in the order they are tested.
var layout: Layout
var stats: Balance
var rng := RandomNumberGenerator.new()
## Every ball in play. Empty once the last ball is lost.
var balls: Array[Ball] = []
var paddle := Paddle.new()
var combo := Combo.new()
var tally := Tally.new()
## Seconds left on the timer.
var time_left: float
## What the tally pays so far: Coins.total(tally, stats). The HUD shows this during Play, and it is what the
## round pays when it ends, however it ends.
var coins := 0
## True once `ended` has been emitted.
var over := false
## Why it ended. Only meaningful when `over` is true.
var reason: End


func _init(p_board: Board, p_layout: Layout, p_stats: Balance, p_seed: int) -> void:
	board = p_board.copy()
	layout = p_layout if p_layout else Layout.new()
	stats = p_stats
	rng.seed = p_seed
	time_left = stats.round_time


## Advances the round by `delta` seconds. The level screen calls this from _physics_process; to freeze the game
## it skips the call. `paddle_target` is where the paddle's centre should go along y, in units: the mouse's y, or
## -INF / INF while a key is held, or paddle.y to stay.
func step(_delta: float, _paddle_target: float) -> void:
	pass


## A ball's speed in units per second: stats.ball_speed * ball.boost.
func speed_of(ball: Ball) -> float:
	return stats.ball_speed * ball.boost


## Gives the brick at `cell` one hit, as described at the top. Does nothing if the cell is empty.
## `dir` is passed on to brick_broken. `ball` is the ball that hit it, or null when the cause is not a ball.
## Hooks call this; the order of several calls is the order they were made in.
func hit_brick(_cell: Vector2i, _cause: Cause, _dir: Vector2, _ball: Ball = null) -> void:
	pass


## An explosion from the brick cell `cell`, reaching `reach` units out from the cell's edges on every side, so
## the blast is the rectangle board.cell_rect(cell).grow(reach). A brick is hit if its cell rectangle overlaps
## that rectangle; touching edges do not count. At a reach of 64 that is 4 columns to each side and 1 brick row
## above and below; every 32 more adds 2 columns, and brick rows are added whole as soon as the blast enters them.
## Emits `exploded`, then hits each of those bricks once with Cause.BLAST. `cell` itself may be empty (the
## explosive brick that calls this is already gone).
## If stats.shockwave is 1 or more, every ball whose centre is inside the blast is thrown: its dir points
## straight away from the blast's centre (then the minimum angles apply) and its boost is multiplied by
## stats.shockwave_boost.
func blast(_cell: Vector2i, _reach: float) -> void:
	pass


## Adds a ball at `pos` moving along `dir` and emits ball_added.
func add_ball(_pos: Vector2, _dir: Vector2, _boost := 1.0) -> Ball:
	return null


## Sets a ball's boost, kept between 1 and stats.boost_cap. A Booster calls
## set_boost(ball, ball.boost + its amount); the paddle resets it to 1.
func set_boost(_ball: Ball, _boost: float) -> void:
	pass


## Adds seconds to the timer and emits time_changed.
func add_time(_seconds: float) -> void:
	pass
