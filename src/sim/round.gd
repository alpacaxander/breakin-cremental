class_name Round
extends RefCounted
## One attempt at a level: the board, the balls, the paddle, the placed items, the combo, the timer and the tally.
## It has no nodes, draws nothing and plays nothing. Screens read its state every frame and connect to its
## signals; effects and sound are built from those two things alone.
##
## The names, types, units, signal payloads and the order of events below are the contract the screens, the
## effects, the sound and the bot are written against.
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
##      time_left is stats.round_time. `charges` is 0: charges come only from caught drops. `ability` is the
##      first of abilities(), or &"" when none is unlocked.
## Nothing moves until step() is called. The first step sends the ball straight left into the paddle. Nothing
## placed is in its way: Layout.fits keeps every item out of launch_path().
## A round counts its bricks as it is built: after that, change the board only through hit_brick and restore
## (grow changes only hp).
##
## ONE STEP, in this order:
##   1. The paddle moves toward paddle_target at stats.paddle_speed.
##   2. Each ball, in `balls` order, moves speed_of(ball) * delta along its dir. Movement is swept, so nothing is
##      passed through. Every contact is resolved where it happens and its signals are emitted then. A ball made
##      during this step (a Splitter) starts moving on the next one. The `waiting` ball rides the paddle instead.
##      Then the drops (see CHARGES): each moves stats.drop_speed * delta LEFT; one that overlaps the paddle is
##      caught (charges + 1, then caught is emitted), one wholly past the open side is removed. Then, with no ball
##      waiting and a charge held, one charge goes onto the paddle.
##   3. The combo's window counts down. If it runs out the combo resets and combo_changed(0, 1) is emitted.
##      Less than TIME_SLOP left has run out, as in 5.
##   4. `clock` goes up by delta. Then each placed brick still on the board and each AREA item, in layout order,
##      gets its kind's on_step hook (Growth pulses here: see grow), and each broken one whose rebuild() is due comes back
##      unless a ball is over it. Then, with Overgrowth (stats.overgrowth >= 1) and a level
##      brick still standing, every broken level cell whose time has come (see ONE BRICK HIT) comes back, in the
##      order they broke, through one restore(NOWHERE, cells) call; a cell a ball is over waits for the next
##      step. With no level brick standing nothing comes back, so 6 ends a cleared board whatever is pending.
##   5. time_left counts down. It stops at 0, and less than TIME_SLOP left is 0: a step such as 1/120 s is not an
##      exact number, so counting down by it ends a hair off 0, and a hair above 0 would be one more whole step
##      at some rates and not at others. A round whose time is a whole number of steps plays exactly that many;
##      any other plays to the end of the step its time runs out in.
##   6. The round ends if every level brick is broken (CLEARED), else if no ball is left, no drop is falling and no
##      ball of the opening volley is still to come (BALL_LOST; a charge held would already be waiting on the
##      paddle, so this is no ball in play, none waiting, none in reserve and none on its way), else if
##      time_left is 0 (TIME). However it ended, the level is cleared if the score has reached `target`. The
##      tally notes the score and whether it cleared, then `ended` is emitted, once; after it step() does nothing. A board with no level bricks ends on its first step.
##
## CHARGES. Balls in reserve. A Power Brick that breaks makes a drop (drop()): a square that moves straight LEFT at
## stats.drop_speed through bricks, items and balls. One that overlaps the solid part of the paddle (paddle.rect)
## is caught and the paddle gets a charge; one wholly past the open side is gone, with no signal.
## # ponytail: a per-step overlap test, not swept. A drop moves about 2 units a step against a 12-unit paddle;
## # sweep it if drops ever get fast or steps long.
## With no ball waiting, the next charge goes onto the paddle's face at once as `waiting`, where it rides and sways
## like the first ball until launch() fires it. Meanwhile the balls in play keep moving, the clock runs, and the
## waiting ball touches nothing. A charge is not announced (no ball_added): read `waiting` and `charges`.
## add_charge() adds one.
##
## ABILITIES. An ability (an AbilityKind) is unlocked when stats.count(id) is 1 or more; abilities() lists the
## unlocked ones in Kinds order. `ability` is the selected one, and cycle() moves the selection. launch() fires a
## charge with Ball.charge = `ability` (a plain ball when none is unlocked). The charged ball's first hit on a
## level brick (not a placed one) lands as usual (ONE BRICK HIT), then the charge is spent (Ball.charge = &"")
## and the ability's fire() runs at that brick's cell: Zap calls zap(), Blast calls blast().
##
## ONE BRICK HIT (hit_brick), in this order:
##   The brick loses 1 hp, unless its kind is unbreakable (PlaceableKind.unbreakable: Growth), which keeps its hp
##   and so always has hp left.
##   If combos are on (stats.combo_rank >= 1) and the hit is on a level brick or breaks the brick, the combo grows
##   and combo_changed is emitted: a hit that leaves a placed brick or a block standing does not grow it. Every
##   point in the combo is paid at the multiplier it has now reached, so a hit that raises it pays the rise on
##   the earlier ones too (Coins.total).
##   If it has hp left: a level brick (not a placed one) scores 1 point (Tally.dent, into the running combo's
##   worth too) and `coins` is updated. Then brick_hit is emitted.
##   If not: it is erased from the board. With Overgrowth, a level brick's cell is due back at clock +
##   stats.overgrowth_delay (see ONE STEP, 4). The tally and `coins` are updated. brick_broken is emitted. Then
##   its kind's on_broken hook runs, then its mod's on_host_broken.
##   Hits a hook asks for (a blast, a Zap) go through hit_brick too, so chains need no special case.
##   # ponytail: a chain is a call inside a call, about three deep per link, and GDScript stops at 1024. That is
##   # some 300 explosive bricks set off by each other in one hit; queue the hits if a level ever gets there.
##
## ONE BOUNCE. The ball is put exactly on the surface and given its new direction:
##   wall, brick, item   mirrored in the surface (Hit.normal)
##   paddle              RIGHT turned by stats.paddle_max_angle times where it landed, from -1 at the top end to
##                       1 at the bottom end. The angle it came in at does not matter. Its boost goes back to ball.kept (what Boosters gave).
## Then the minimum angles apply (see _legal): a direction closer than stats.min_angle_horizontal to level or
## than stats.min_angle_vertical to upright is turned to that angle, on the side the surface faces. So the dead
## centre of the paddle sends the ball back min_angle_horizontal below level, not along the line it came on.
## Turned like that, a ball can leave straight back along the line it came on. Once is harmless. Twice, with
## whatever it touched in between, can be a ball passed back and forth for ever: between two Wall Segments
## turned 105 degrees one above the other, in the neck between two Bumpers, between one Bumper and a paddle
## that stays put. So every second time a ball is turned straight back (Ball.back) it gets the same angle on
## the other side of the axis instead. That still leaves the surface.
## # ponytail: only straight back is caught. A loop through three surfaces is not: a Bumper in a corner beside
## # the lane, the top wall and a paddle at the end of its travel pass a ball round for ever, and moving the
## # paddle a few units does not break it. Catch repeats in general (the same contacts again with no brick between)
## # if players meet one.
## A bounce never changes the speed.
## One exception to the angles: a ball wedged where two surfaces close to a gap narrower than itself (WEDGED
## contacts in a row without moving) leaves along the line between them. If no legal angle fits in that gap it
## keeps the line's angle until its next bounce. The one way found to get there is a board under 14 rows: on
## those the paddle's face is less than a ball away from the grid, and the paddle, which does not mirror, can
## send a ball back into the gap between itself and an item every time.
##
## TICK RATE. A ball's line is measured from where it last turned (Ball.from), so its bounces fall in the same
## places whatever the step size: a round with one ball and a paddle that stays put breaks the same bricks in the
## same order at 60, 120 and 240 steps a second. Two things are still tied to the step: the paddle is where
## step() last put it when a ball lands on it, and with several balls each one finishes its whole step before the
## next starts, so which of two balls reaches a brick first can differ within one step.
##   # ponytail: one ball at a time. To make several balls exact, move them all to the next contact in time order.

## What hit a brick.
enum Cause {
	BALL,
	BLAST,  ## An explosion
	ZAP,  ## A Zap (zap())
}

## Why the round ended.
enum End {
	TIME,  ## The timer ran out
	BALL_LOST,  ## The last ball left through the open side
	CLEARED,  ## Every brick that counts is broken. Whether the level is cleared is tally.cleared, from the score
}

## The most contacts one ball resolves in one step, so that no step can run for ever.
# ponytail: a ball in a slot barely wider than itself can need more at a huge step (the bot at 10 steps a second
# with a 3x boost) and then loses the rest of that step. Raise it, or shorten the step, if that shows up.
const MAX_CONTACTS := 256
## This many contacts in a row that do not move a ball mean it is wedged where two surfaces meet (see _move).
## A corner between two bricks takes 2.
const WEDGED := 8
## Seconds on the timer that count as none (see ONE STEP, 4). Far above what rounding leaves behind (3e-9 after
## two minutes at 10000 steps a second, 1e-11 in a real round) and far below any step.
const TIME_SLOP := 1e-6
## Without the Guide the launch sways at most this many degrees above or below level: a 90 degree spread. With
## it, the sway goes as steep as the minimum angles allow (see launch_dir).
const LAUNCH_ANGLE := 45.0
## restored's `cell` when no block brought the bricks back (Overgrowth). It is off the board.
const NOWHERE := Vector2i(-1, -1)

## A brick took a hit and is still there. `hp_left` is its hp after the hit; board.brick(cell) is the brick.
## A level brick's hit has already scored its point: `coins` includes it.
signal brick_hit(cell: Vector2i, hp_left: int, cause: Cause)

## A brick broke. It is already off the board.
##   brick  the brick that broke, with hp 0. Its kind, mod and placed flag are as they were, so
##          Palette.brick(brick) is the colour it had (a plain brick always breaks from its 1 HP colour).
##   dir    a unit vector for the debris: the ball's direction of travel as it hit (BALL), away from the
##          blast's centre (BLAST), or along the row away from the zapped brick, LEFT or RIGHT (ZAP).
##   coins  what this break added to `coins`. 0 for a placed brick.
## combo.count and combo.multiplier already include this break. For a BALL the ball has already bounced: it
## is on the brick's face (ball.pos) with its new dir.
signal brick_broken(cell: Vector2i, brick: Brick, cause: Cause, dir: Vector2, coins: int)

## A ball bounced off a wall, the paddle or a free-form placed item. Not emitted for bricks: those give brick_hit
## or brick_broken. ball.dir is the new direction. For an ITEM, the item's on_ball_hit hook has already run.
signal ball_bounced(ball: Ball, hit: Hit)

## A ball was made during play (a Splitter). It is already in `balls`. The ball a round starts with and the
## charges put on the paddle are not announced; read `balls` and `waiting`.
signal ball_added(ball: Ball)

## A Power Brick made a drop (drop()). It is already in `drops`.
signal dropped(drop: Drop)

## The paddle caught a drop. It is already out of `drops`, and `charges` already counts it.
signal caught(drop: Drop)

## A ball left through the open side. It is already out of `balls`; ball.pos is where it left.
signal ball_lost(ball: Ball)

## An explosion went off. Emitted before its hits land, so every brick in `cells` is still on the board.
##   pos    the centre of the brick that exploded, in units
##   reach  how far the blast reaches out from that brick's edges, in units
##   cells  every brick cell the blast is about to hit, by column from the paddle side and then down
signal exploded(pos: Vector2, reach: float, cells: Array[Vector2i])

## A Zap went off (zap()). Emitted before its hits land, so every brick in `cells` is still on the board.
##   cell   the brick the charged ball hit
##   cells  every brick the Zap is about to hit, from the paddle side to the back wall
signal zapped(cell: Vector2i, cells: Array[Vector2i])

## A Growth area's pulse gave bricks 1 HP each. Emitted after they gained it, and only if one did.
##   cell   the area's brick cell
##   reach  how far the pulse reaches out from that cell's edges, in units
##   cells  every brick that gained, by column from the paddle side and then down
signal grew(cell: Vector2i, reach: float, cells: Array[Vector2i])

## Broken bricks came back (restore: Refresh, Overgrowth; rebuild: a placed Splitter). Emitted after they are on
## the board, and only if one came.
##   cell   where they were brought back from: the Refresh block's brick cell, NOWHERE for Overgrowth, or the
##          rebuilt Splitter's own cell
##   cells  every brick that came back, in the order they were asked for (Refresh: nearest first; Overgrowth:
##          the order they broke in, all that came due in one step; a Splitter: its cell)
signal restored(cell: Vector2i, cells: Array[Vector2i])

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
## Every ball in play, and the one `waiting` on the paddle. Empty once the last ball is lost and no charge is held.
var balls: Array[Ball] = []
## The ball riding the paddle until launch(): the first one while `held`, then each charge. Null for none. It is
## in `balls`, but it does not move on its own, bounce or get thrown.
var waiting: Ball
## Charges in reserve, not yet on the paddle (see CHARGES).
var charges := 0
## Every drop in flight (see CHARGES), oldest first.
var drops: Array[Drop] = []
## The selected ability's id, which the next charge fired carries; &"" when none is unlocked (see ABILITIES).
var ability: StringName = &""
var paddle := Paddle.new()
var combo := Combo.new()
var tally := Tally.new()
## Seconds left on the timer.
var time_left: float
## Seconds of play: it goes up as time_left goes down, but an hourglass brick does not move it. 0 until the first
## step of play. Pulses are timed by it.
var clock := 0.0
## What the tally pays so far: Coins.total(tally, stats). The HUD shows this during Play, and it is what the
## round pays when it ends, however it ends.
var coins := 0
## True once `ended` has been emitted.
var over := false
## Why it ended. Only meaningful when `over` is true.
var reason: End
## True while the first ball sits on the paddle waiting for launch() (see hold()): play has not started.
var held := false
## The score (Coins.points) a clear needs: LevelData.target. The level screen and the
## bot set it. At 0, the default, every round is a clear.
var target := 0
## Every cell that held a level brick (not a placed one) once the round was built, as keys (all true). Only
## these can have a brick brought back (restore).
var level_cells: Dictionary[Vector2i, bool] = {}
## Seconds a ball has waited on the paddle, from a random start: launch_dir() sways with it.
var sway := 0.0

# The FREE items as the sweep sees them (Collide.Solid), in layout order.
# ponytail: grown for a ball of stats.ball_size. Every ball is that size; if one ever is not, grow per size.
var _solids: Array[Collide.Solid] = []
## FREE items the ball passes through (PlaceableKind.gate).
var _gates: Array[Layout.Item] = []
# Level bricks still to break: board.remaining(), kept as a count because walking 512 bricks every step makes a
# round ten times slower.
# ponytail: so a brick put on or taken off round.board by hand is not seen. Count again there if that is needed.
var _left := 0
var _next_id := 0
var _next_drop := 0
# With Overgrowth: each broken level cell waiting to come back, and the clock it is due at. In the order they
# broke, which is the order they are due in, because the delay is the same for all.
var _due: Dictionary[Vector2i, float] = {}
# Broken placed bricks that come back (rebuild: Splitter Respawn), and the clock each is due at.
var _rebuild: Dictionary[Vector2i, float] = {}


func _init(p_board: Board, p_layout: Layout, p_stats: Balance, p_seed: int) -> void:
	board = p_board.copy()
	stats = p_stats
	rng.seed = p_seed
	time_left = stats.round_time
	_roll_specials()
	layout = (p_layout if p_layout else Layout.new()).fitted(board, stats)
	for item in layout.items:
		match item.kind.placement:
			PlaceableKind.Placement.BRICK:
				board.bricks[item.cell] = _placed(item.kind)
			PlaceableKind.Placement.MOD:
				board.brick(item.cell).mod = item.kind.id
			PlaceableKind.Placement.AREA:
				pass  # nothing in play: its on_step acts
			_:
				if item.kind.gate:
					_gates.append(item)
				else:
					_solids.append(Collide.solid(item, stats.ball_size))
	_left = board.remaining()
	for cell in board.bricks:
		if not board.bricks[cell].placed:
			level_cells[cell] = true
	paddle.length = stats.paddle_size
	paddle.thickness = stats.paddle_thickness
	paddle.x = paddle_face(board, stats)
	paddle.y = board.size().y * 0.5
	_spawn(ball_start(board, stats), Vector2.LEFT, 1.0)
	var unlocked := abilities()
	ability = unlocked[0].id if unlocked else &""


## The x of the paddle's face on a board. Round and Layout.fits both place things from it.
static func paddle_face(p_board: Board, p_stats: Balance) -> float:
	return -p_board.lane() + p_stats.paddle_inset + p_stats.paddle_thickness


## The centre of the ball at rest, before the first step.
static func ball_start(p_board: Board, p_stats: Balance) -> Vector2:
	return Vector2(paddle_face(p_board, p_stats) + p_stats.launch_gap + p_stats.ball_size * 0.5, p_board.size().y * 0.5)


## Everything the first ball covers before it touches the paddle: its square at rest and the strip that square
## crosses on its way straight left to the paddle's face. Layout.fits keeps placed items out of it, so the launch
## always reaches the paddle (docs/design/physics.md, "Start position"). Setup can show it as a keep-out zone.
static func launch_path(p_board: Board, p_stats: Balance) -> Rect2:
	return Rect2(paddle_face(p_board, p_stats), (p_board.size().y - p_stats.ball_size) * 0.5, p_stats.launch_gap + p_stats.ball_size, p_stats.ball_size)


## Puts the first ball on the paddle's face, where it rides with the paddle until launch(). While it is held,
## step() moves the paddle and nothing else: no timer, no combo. The level screen holds every round it builds;
## the bot holds and launches at once.
# ponytail: opt-in, so the rules tests' ball at rest (launch_gap, launch_path) still works. Once nothing
# builds an unheld round, make it the constructor's default and drop launch_gap and launch_path.
## The sway starts at a random point (rng), so the bot, which launches at once, still launches every way.
func hold() -> void:
	if balls.is_empty():
		return
	held = true
	waiting = balls[0]
	sway = rng.randf() * stats.launch_sway
	_glue()


## Sends the waiting ball (the held one or a charge) off the paddle along launch_dir(). A charge leaves carrying
## the selected ability (Ball.charge = `ability`; see ABILITIES). Does nothing if no ball waits.
func launch() -> void:
	if waiting == null:
		return
	if not held:
		waiting.charge = ability
	held = false
	waiting.put(waiting.pos, launch_dir())
	waiting = null


## The unlocked abilities (stats.count(id) >= 1), in Kinds order.
func abilities() -> Array[AbilityKind]:
	var out: Array[AbilityKind] = []
	out.assign(Kinds.abilities().filter(func(k: AbilityKind) -> bool: return stats.count(k.id) >= 1))
	return out


## Moves the selected ability `steps` places along abilities(), wrapping. Does nothing when none is unlocked.
func cycle(steps: int) -> void:
	var ids := abilities().map(func(k: AbilityKind) -> StringName: return k.id)
	if not ids.is_empty():
		ability = ids[posmod(ids.find(ability) + steps, ids.size())]


## Puts one more charge in reserve.
func add_charge() -> void:
	charges += 1


## Makes a drop at the centre of brick cell `cell`, adds it to `drops` and emits dropped. A Power Brick calls this
## as it breaks.
func drop(cell: Vector2i) -> Drop:
	var d := Drop.new()
	d.id = _next_drop
	_next_drop += 1
	d.size = stats.drop_size
	d.pos = board.cell_rect(cell).get_center()
	drops.append(d)
	dropped.emit(d)
	return d


## Where the waiting ball would leave if launched now. It sways from the highest angle to the lowest and back once
## every stats.launch_sway seconds, slowing at each end. The highest is LAUNCH_ANGLE, or with the Guide
## (stats.guide > 0) as steep as the minimum angles allow. Without the Guide the minimum angles then apply, so the
## aim skips the few degrees around level; with it the line shows a flat launch, so every angle between is allowed.
func launch_dir() -> Vector2:
	var top := 90.0 - stats.min_angle_vertical if stats.guide > 0.0 else LAUNCH_ANGLE
	var dir := Vector2.RIGHT.rotated(deg_to_rad(top * sin(TAU * sway / stats.launch_sway)))
	return dir if stats.guide > 0.0 else _legal(dir, Vector2.RIGHT)


## The Guide: the waiting ball's way if launched now, as the ball's centre where it starts, at each bounce and
## where the line ends. The line is stats.guide units long, bounces included. Without stats.guide_bounces it ends
## at the first thing the ball would touch; with it, it ends at the paddle or the open side, where the way depends
## on the player. Empty with no Guide or no ball waiting.
## It is the way with nothing else changing: no blast, Shockwave, Splitter or brick brought back is foreseen.
func guide() -> PackedVector2Array:
	var points := PackedVector2Array()
	if waiting == null or stats.guide <= 0.0:
		return points
	var ghost := Ball.new()
	ghost.size = waiting.size
	ghost.put(waiting.pos, launch_dir())
	points.append(ghost.pos)
	var left := stats.guide
	for i in MAX_CONTACTS:
		var hit := Collide.sweep(self, ghost, left)
		var go := hit.travel if hit else left
		if ghost.dir.x < 0.0:  # the open side, as in _move
			go = minf(go, maxf((-board.lane() - ghost.size * 0.5 - ghost.from.x) / ghost.dir.x - ghost.gone, 0.0))
		points.append(ghost.from + ghost.dir * (ghost.gone + go))
		left -= go
		if hit == null or go < hit.travel or left <= 0.0 or stats.guide_bounces < 1.0 or hit.surface == Hit.Surface.PADDLE:
			break
		ghost.pos = hit.point
		_turn(ghost, hit)
	return points


func _glue() -> void:
	if waiting:
		var half := waiting.size * 0.5  # the paddle's centre can reach a wall; the ball stays clear of it
		waiting.put(Vector2(paddle.x + half, clampf(paddle.y, half, board.size().y - half)), Vector2.RIGHT)


## Advances the round by `delta` seconds. The level screen calls this from _physics_process; to freeze the game
## it skips the call. `paddle_target` is where the paddle's centre should go along y, in units: the mouse's y, or
## -INF / INF while a key is held, or paddle.y to stay.
func step(delta: float, paddle_target: float) -> void:
	if over:
		return
	move_paddle(delta, paddle_target)
	if waiting:
		sway += delta
	if not held:
		for ball in balls.duplicate():  # a copy: a Splitter adds to `balls` and a lost ball leaves it
			if ball != waiting:
				_move(ball, delta)
		_move_drops(delta)
		if waiting == null and charges > 0:
			charges -= 1
			waiting = _spawn(Vector2.ZERO, Vector2.RIGHT, 1.0)
			_glue()
		if combo.tick(delta):
			combo_changed.emit(0, 1)
		clock += delta
		for item in layout.items:
			var brick := board.brick(item.cell)
			if item.kind.placement == PlaceableKind.Placement.AREA:
				item.kind.on_step(self, item.cell, null, delta)
			elif item.kind.placement == PlaceableKind.Placement.BRICK and brick and brick.placed:
				item.kind.on_step(self, item.cell, brick, delta)
			elif brick == null and _rebuild.get(item.cell, INF) <= clock + TIME_SLOP and not _ball_over(board.cell_rect(item.cell)):
				_rebuild.erase(item.cell)
				board.bricks[item.cell] = _placed(item.kind)
				restored.emit(item.cell, [item.cell] as Array[Vector2i])
		if _left > 0 and not _due.is_empty():
			_regrow()
		time_left -= delta
	if time_left < TIME_SLOP:
		time_left = 0.0
	if _left == 0:
		_end(End.CLEARED)
	elif balls.is_empty() and drops.is_empty():
		_end(End.BALL_LOST)
	elif time_left == 0.0:
		_end(End.TIME)


# The drops' part of a step (see CHARGES).
func _move_drops(delta: float) -> void:
	var catcher := paddle.rect(board.size().y)
	for d in drops.duplicate():  # a copy: a drop caught or gone leaves `drops`
		d.pos.x -= stats.drop_speed * delta
		if d.rect().intersects(catcher):
			drops.erase(d)
			charges += 1
			caught.emit(d)
		elif d.pos.x + d.size * 0.5 <= -board.lane():
			drops.erase(d)


## Step 1 of step() alone: the paddle moves toward `paddle_target` at stats.paddle_speed and nothing else does.
## Setup calls it, so the paddle can be placed before the launch while the ball stays at rest.
func move_paddle(delta: float, paddle_target: float) -> void:
	# Only the centre stays on the board: half the paddle can go past a wall, so the edges are easy to aim at.
	paddle.y = clampf(move_toward(paddle.y, paddle_target, stats.paddle_speed * delta), 0.0, board.size().y)
	_glue()


## True if the Rear Paddle is on (stats.rear_paddle > 0) and `y` is within it. It is not a solid of its own: it is
## the stretch of back wall facing the paddle, so it follows paddle.y and has paddle.length.
# ponytail: a wall stretch, not a body; give it its own collision if it ever moves on its own or sticks out.
func on_rear_paddle(y: float) -> bool:
	return stats.rear_paddle > 0.0 and absf(y - paddle.y) <= paddle.length * 0.5


## A ball's speed in units per second: stats.ball_speed * ball.boost.
func speed_of(ball: Ball) -> float:
	return stats.ball_speed * ball.boost


## Gives the brick at `cell` one hit, as described at the top. Does nothing if the cell is empty.
## `dir` is passed on to brick_broken. `ball` is the ball that hit it, or null when the cause is not a ball.
## Hooks call this; the order of several calls is the order they were made in.
func hit_brick(cell: Vector2i, cause: Cause, dir: Vector2, ball: Ball = null) -> void:
	var brick := board.brick(cell)
	if brick == null:
		return
	var hit_kind := Kinds.of(brick.kind)
	if not (hit_kind is PlaceableKind and (hit_kind as PlaceableKind).unbreakable):
		brick.hp -= 1
	if stats.combo_rank >= 1.0 and (brick.hp <= 0 or not brick.placed):  # a level brick's hit, or any break
		combo.add(stats)
		combo_changed.emit(combo.count, combo.multiplier)
	if brick.hp > 0:
		if not brick.placed:
			tally.dent(combo)
			coins = Coins.total(tally, stats)
		brick_hit.emit(cell, brick.hp, cause)
		if hit_kind:
			hit_kind.on_hit(self, cell, brick, cause, dir, ball)
		return
	board.bricks.erase(cell)
	if not brick.placed:
		_left -= 1
		if stats.overgrowth >= 1.0:
			_due[cell] = clock + stats.overgrowth_delay
	tally.add(brick, combo)
	var paid := Coins.total(tally, stats) - coins
	coins += paid
	brick_broken.emit(cell, brick, cause, dir, paid)
	var kind := Kinds.of(brick.kind)
	if kind:
		kind.on_broken(self, cell, brick, cause, dir, ball)
	var mod := Kinds.of(brick.mod)
	if mod:
		mod.on_host_broken(self, cell, brick, cause, dir, ball)


## An explosion from the brick cell `cell`, reaching `reach` units out from the cell's edges on every side, so
## the blast is the rectangle board.cell_rect(cell).grow(reach). A brick is hit if its cell rectangle overlaps
## that rectangle; touching edges do not count. At a reach of 64 that is 4 columns to each side and 1 brick row
## above and below; every 32 more adds 2 columns, and brick rows are added whole as soon as the blast enters them.
## Emits `exploded`, then hits each of those bricks stats.explosion_damage times with Cause.BLAST. `cell` itself may be empty (the
## brick a charged ball hit may be gone); if it still stands, it is in the blast too. A brick this blast breaks may set off a blast of its own
## before the next brick of this one is hit.
## If stats.shockwave is 1 or more, every ball whose centre is inside the blast is thrown: its dir points
## straight away from the blast's centre (then the minimum angles apply) and its boost is multiplied by
## stats.shockwave_boost. The throw comes after the hits, so in a chain the first blast throws last and its
## direction is the one the ball leaves with.
func blast(cell: Vector2i, reach: float) -> void:
	var area := board.cell_rect(cell).grow(reach)
	var centre := area.get_center()
	var cells := board.bricks_in(area)
	exploded.emit(centre, reach, cells)
	for c in cells:
		var away := board.cell_rect(c).get_center() - centre
		for i in int(stats.explosion_damage):
			hit_brick(c, Cause.BLAST, away.normalized() if away else Vector2.RIGHT)
	if stats.shockwave >= 1.0:
		for ball in balls:
			if ball != waiting and area.has_point(ball.pos):
				if ball.pos != centre:
					ball.put(ball.pos, _legal((ball.pos - centre).normalized()))
				set_boost(ball, ball.boost * stats.shockwave_boost)


## A Zap from the brick cell `cell` (the brick a charged ball hit): every other brick in its brick row within
## stats.zap_range columns takes stats.zap_damage hits with Cause.ZAP, from the paddle side to the back wall, each
## one's hits landing before the next brick's. Emits `zapped` first, with those cells.
func zap(cell: Vector2i) -> void:
	var reach := int(stats.zap_range)
	var cells: Array[Vector2i] = []
	for column in range(maxi(cell.x - reach, 0), mini(cell.x + reach + 1, board.cols)):
		var c := Vector2i(column, cell.y)
		if column != cell.x and board.brick(c):
			cells.append(c)
	zapped.emit(cell, cells)
	for c in cells:
		for i in int(stats.zap_damage):
			hit_brick(c, Cause.ZAP, Vector2.LEFT if c.x < cell.x else Vector2.RIGHT)


## A pulse from the Growth area on `cell`, reaching `reach` units out from the cell's edges by the blast's rule
## (Board.bricks_in). Every level brick there (not a placed one) under stats.max_hp gains 1 hp. That is no hit:
## it scores nothing and the tally does not see it. Emits grew if any brick gained.
func grow(cell: Vector2i, reach: float) -> void:
	var cells: Array[Vector2i] = []
	for c in board.bricks_in(board.cell_rect(cell).grow(reach)):
		var brick := board.brick(c)
		if not brick.placed and brick.hp < stats.max_hp:
			brick.hp += 1
			cells.append(c)
	if not cells.is_empty():
		grew.emit(cell, reach, cells)


## Brings broken level bricks back (Refresh, Overgrowth). Each of `cells` that can take one
## (restorable()) gets a standard 1 HP level brick: no kind, no mod, not placed, whatever was there before. It
## scores and counts toward a clear like any level brick, and Overgrowth no longer waits for it. Emits
## restored(cell, those cells) if any came back, and returns them, so a caller can try a cell a ball was over
## again later. `cell` is where they came back from: the block, or NOWHERE.
func restore(cell: Vector2i, cells: Array[Vector2i]) -> Array[Vector2i]:
	var back: Array[Vector2i] = []
	for c in cells:
		if restorable(c):
			board.bricks[c] = Brick.new()
			_left += 1
			_due.erase(c)
			back.append(c)
	if not back.is_empty():
		restored.emit(cell, back)
	return back


## Overgrowth's part of a step: every cell due by now (TIME_SLOP, as for the timer), in one restore call.
func _regrow() -> void:
	var due: Array[Vector2i] = []
	for c in _due:
		if _due[c] > clock + TIME_SLOP:
			break
		due.append(c)
	if not due.is_empty():
		restore(NOWHERE, due)


## True if a level brick can be brought back to `cell`: it held one once the round was built (level_cells), it
## is empty now, and no ball overlaps it (touching does not count).
func restorable(cell: Vector2i) -> bool:
	if board.bricks.has(cell) or not level_cells.has(cell):
		return false
	return not _ball_over(board.cell_rect(cell))


## Schedules the placed brick broken at `cell` to come back `delay` s of play later (Splitter Respawn), as it was
## built: its kind's hp plus its health stat. It waits while a ball is over the cell, and emits restored(cell,
## [cell]) when it is back.
func rebuild(cell: Vector2i, delay: float) -> void:
	_rebuild[cell] = clock + delay


# A placed brick of `kind` as the round builds it.
func _placed(kind: PlaceableKind) -> Brick:
	# ponytail: only the Splitter has a health stat; `<id>_health` reads 0 for the rest.
	var brick := Brick.new(kind.hp + int(stats.base(StringName(String(kind.id) + "_health"))), kind.id)
	brick.placed = true
	return brick


# True if a ball overlaps `rect` (touching does not count).
func _ball_over(rect: Rect2) -> bool:
	for ball in balls:
		if rect.intersects(Rect2(ball.pos - Vector2.ONE * ball.size * 0.5, Vector2.ONE * ball.size)):
			return true
	return false


## Up to `count` cells a brick can be brought back to (restorable()), nearest `cell` first by the distance
## between cell centres; a tie goes to the lower column, then the lower row. Refresh brings these back.
func broken_near(cell: Vector2i, count: int) -> Array[Vector2i]:
	var centre := board.cell_rect(cell).get_center()
	var away := func(c: Vector2i) -> float: return board.cell_rect(c).get_center().distance_squared_to(centre)
	var cells: Array[Vector2i] = []
	cells.assign(level_cells.keys().filter(restorable))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return away.call(a) < away.call(b) or (away.call(a) == away.call(b) and a < b))
	return cells.slice(0, count)


## Adds a ball at `pos` moving along `dir`, turned to the minimum angles (_legal), and emits ball_added. A wide
## split fans a ball past them.
func add_ball(pos: Vector2, dir: Vector2, boost := 1.0) -> Ball:
	var ball := _spawn(pos, _legal(dir), boost)
	ball_added.emit(ball)
	return ball


## Sets a ball's boost, kept between 1 and stats.boost_cap. A Booster calls
## set_boost(ball, ball.boost + its amount); the paddle resets it to ball.kept.
func set_boost(ball: Ball, boost: float) -> void:
	ball.boost = clampf(boost, 1.0, maxf(stats.boost_cap, 1.0))


## Adds seconds to the timer and emits time_changed.
func add_time(seconds: float) -> void:
	time_left += seconds
	time_changed.emit(time_left, seconds)


func _spawn(pos: Vector2, dir: Vector2, boost: float) -> Ball:
	var ball := Ball.new()
	ball.id = _next_id
	_next_id += 1
	ball.size = stats.ball_size
	ball.put(pos, dir)
	set_boost(ball, boost)
	balls.append(ball)
	return ball


func _roll_specials() -> void:
	var pool: Array[Vector2i] = []
	for cell: Vector2i in board.bricks:
		if board.bricks[cell].kind == &"" and not board.bricks[cell].placed:
			pool.append(cell)
	pool.sort()  # so the pick depends on where the bricks are, not on the order the level listed them in
	for kind in Kinds.bricks():
		for i in stats.count(kind.id):
			if pool.is_empty():
				return
			var brick := board.brick(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
			brick.kind = kind.id
			brick.hp = kind.hp


## Moves one ball for `time` seconds, resolving every contact on the way.
func _move(ball: Ball, time: float) -> void:
	if ball.pos != ball.from + ball.dir * ball.gone:  # someone set pos or dir by hand
		ball.put(ball.pos, ball.dir)
	var still := 0  # contacts in a row that did not move the ball
	var last := Vector2.ZERO  # the normal of the contact before
	for i in MAX_CONTACTS:
		var speed := speed_of(ball)
		var reach := speed * time
		var hit := Collide.sweep(self, ball, reach)
		# The open side: the ball is lost once all of it is past the line.
		if ball.dir.x < 0.0:
			var out := (-board.lane() - ball.size * 0.5 - ball.from.x) / ball.dir.x - ball.gone
			if out <= reach and (hit == null or out < hit.travel):
				ball.gone += maxf(out, 0.0)
				ball.pos = ball.from + ball.dir * ball.gone
				balls.erase(ball)
				ball_lost.emit(ball)
				return
		var was := ball.pos
		if hit == null:
			ball.gone += reach
			ball.pos = ball.from + ball.dir * ball.gone
			_cross(ball, was)
			return
		time = maxf(time - hit.travel / speed, 0.0)
		ball.pos = hit.point
		_cross(ball, was)
		_bounce(ball, hit)
		# Wedged: the ball is where two surfaces close to a gap narrower than itself, and each sends it back into
		# the other (the paddle does not mirror, so its bounces can shrink toward that point for ever). It leaves
		# along the line between the two, turned to a legal angle if that still leaves both.
		still = still + 1 if hit.travel < Collide.SKIN else 0
		if still >= WEDGED and not (hit.normal + last).is_zero_approx():
			var between := (hit.normal + last).normalized()
			var nudged := _legal(between)
			ball.put(ball.pos, nudged if nudged.dot(hit.normal) > 0.0 and nudged.dot(last) > 0.0 else between)
			still = 0
		last = hit.normal


## Runs on_ball_hit for every gate whose long centre line the ball crossed going from `was` to ball.pos.
# ponytail: the new speed applies from the next move, not mid-move; fine at 60 Hz steps.
func _cross(ball: Ball, was: Vector2) -> void:
	for item in _gates:
		var half := Vector2(0.0, item.kind.size.y * 0.5).rotated(deg_to_rad(item.kind.turn + item.rot))
		if Geometry2D.segment_intersects_segment(was, ball.pos, item.pos - half, item.pos + half) == null:
			continue
		# The ball goes on, so there is no surface: the point is where the ball is (ball_bounced's contract), at
		# most a step past the line, and the normal faces back along its way.
		var hit := Hit.new()
		hit.surface = Hit.Surface.ITEM
		hit.item = item
		hit.point = ball.pos
		hit.normal = -ball.dir
		item.kind.on_ball_hit(self, ball, hit)
		ball_bounced.emit(ball, hit)


func _bounce(ball: Ball, hit: Hit) -> void:
	var was := _turn(ball, hit)
	match hit.surface:
		Hit.Surface.BRICK:
			var charged := ball.charge != &"" and not board.brick(hit.cell).placed  # a level brick (ABILITIES)
			hit_brick(hit.cell, Cause.BALL, was, ball)
			if charged:
				var kind := Kinds.of(ball.charge) as AbilityKind
				ball.charge = &""
				if kind:
					kind.fire(self, hit.cell, was, ball)
		Hit.Surface.ITEM:
			hit.item.kind.on_ball_hit(self, ball, hit)
			ball_bounced.emit(ball, hit)
		_:
			if hit.surface == Hit.Surface.WALL and hit.normal == Vector2.LEFT and on_rear_paddle(ball.pos.y):
				set_boost(ball, ball.boost + stats.rear_paddle)
			ball_bounced.emit(ball, hit)


## A bounce's new direction (ONE BOUNCE), put on the ball; the paddle also resets its boost. Returns the
## direction it had. The Guide turns its ghost ball with this too.
func _turn(ball: Ball, hit: Hit) -> Vector2:
	var was := ball.dir
	var n := hit.normal
	if hit.surface == Hit.Surface.PADDLE:
		var where := clampf((ball.pos.y - paddle.y) / (paddle.length * 0.5), -1.0, 1.0)
		ball.put(ball.pos, _legal(Vector2.RIGHT.rotated(deg_to_rad(where * stats.paddle_max_angle)), Vector2.RIGHT))
		set_boost(ball, ball.kept)
	elif was.dot(n) < 0.0:
		# Along an axis the mirror is an exact change of sign; off a turned face it is rounded, so it is made a
		# unit vector again or the speed would creep.
		var mirror := was.bounce(n) if n.x == 0.0 or n.y == 0.0 else was.bounce(n).normalized()
		var out := _legal(mirror, n)
		# Turned straight back the way it came (see ONE BOUNCE): every second time, to the other side instead.
		# The turn was across the axis the direction is nearer to, so that is the part that changes sign.
		if out != mirror and out.is_equal_approx(-was):
			if ball.back:
				out *= Vector2(-1.0, 1.0) if absf(out.y) > absf(out.x) else Vector2(1.0, -1.0)
			ball.back = not ball.back
		ball.put(ball.pos, out)
	else:
		ball.put(ball.pos, was)
	return was


## The minimum angles (docs/design/physics.md): `dir`, turned if it has to be so that it is at least
## stats.min_angle_horizontal from level and stats.min_angle_vertical from upright. A direction that is already
## fine comes back untouched, so a bounce off a wall or a brick is an exact mirror.
## `n` is the normal of the surface the ball is leaving, or ZERO for a throw. The turn goes to the side that
## normal points to. That is always away from the surface, and it never turns a ball back into a narrowing gap
## it was on its way out of, which turning to the nearest side can do for ever. What it can do is turn a ball
## straight back the way it came; _bounce sees to that.
func _legal(dir: Vector2, n := Vector2.ZERO) -> Vector2:
	var angle := atan2(absf(dir.y), absf(dir.x))  # from level: 0 to a quarter turn
	var low := deg_to_rad(stats.min_angle_horizontal)
	var high := PI * 0.5 - deg_to_rad(stats.min_angle_vertical)
	if angle >= low and angle <= high:
		return dir
	var side := dir.sign()
	if angle > high and n.x != 0.0:
		side.x = signf(n.x)
	if angle < low and n.y != 0.0:
		side.y = signf(n.y)
	# Dead level or dead upright, off a surface that does not say: toward the board, and down.
	if side.x == 0.0:
		side.x = 1.0
	if side.y == 0.0:
		side.y = 1.0
	angle = clampf(angle, low, high)
	return Vector2(cos(angle), sin(angle)) * side


func _end(why: End) -> void:
	over = true
	reason = why
	tally.target = target
	tally.score = Coins.points(tally, stats)
	tally.cleared = tally.score >= target
	ended.emit(why)
