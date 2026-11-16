extends RefCounted
## The effects (src/level/fx/fx.gd), as far as they can be checked without eyes: what clear() leaves, that the
## round is let go, the freeze and its cap, the caps in the worst burst and what that burst costs, the layers,
## what reduce flashing drops, the bloom against the combo, how pop-ups join and stay unzoomed, and that a
## watched round plays exactly like one nobody watches. How they look is tests/shots/fx.gd.
##
## Every upgrade is owned, so combos are on and the round has its special bricks. Fx's own clock is driven by
## hand (fx._process(seconds)) wherever a check needs an exact time.

const PLAY := 1
## The script time one frame may cost at the worst burst, in microseconds.
const BUDGET := 4000

var t: Node
var main: Main
var level: Control
var fx: Fx
var round: Round


func run(p_t: Node) -> void:
	t = p_t
	Settings.crt = false
	Progress.unlocked = Levels.count()
	for u in Progress.upgrades():
		Progress.ranks[u.id] = u.max_rank
	main = (load("res://src/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	await _seam_and_clear()
	await _freeze()
	await _bloom()
	await _pop_ups()
	await _calm()
	await _bursts()
	await _same_round()
	await _cost()
	main.free()


## Level `number` in Play, with seed 7.
func _play(number: int) -> void:
	Main.show_hub()
	level = Main.show_level(number)
	level.start(7)
	fx = level.fx
	round = level.round
	round.launch()
	await t.tree().process_frame


## Puts the round's combo at `count`, with a window that outlasts the case, and tells whoever listens.
func _combo(of: Round, count: int) -> void:
	of.combo.count = count
	@warning_ignore("integer_division")
	of.combo.multiplier = 1 + maxi(count - 1, 0) / of.stats.combo_breaks_per_step
	of.combo.window = 60.0
	of.combo.time_left = 60.0
	of.combo_changed.emit(count, of.combo.multiplier)


## How many effects of every kind are on screen.
func _count(of: Fx) -> int:
	return of.squares() + of._shapes.size() + of._marks.size() + of._pools.size() + of._pops.size() + of._paths.size() + of._asked.size()


func _seam_and_clear() -> void:
	await _play(1)
	t.check(fx.get_child_count() == 4, "Fx has four layers and no node per effect")
	for layer: Node2D in fx.get_children():
		t.check(layer.z_index >= 1 and layer.z_index <= 99, "%s is at z 1 to 99 (it is at %d)" % [layer.name, layer.z_index])
	t.check(fx.z_index == 0, "Fx itself stays at z 0")

	_combo(round, 20)
	round.blast(Vector2i(48, 3), 64.0)
	round.add_time(2.0)
	t.check(fx.frozen and fx._strength > 0.0 and fx.heat > 0.0, "a blast freezes and shakes, and the combo heats up")
	for i in 3:
		await t.tree().physics_frame
	await t.tree().process_frame
	t.check(fx.squares() > 0 and not fx._shapes.is_empty() and not fx._pools.is_empty() and fx._pops.size() >= 2 and not fx._paths.is_empty(),
			"a blast leaves squares, shockwaves, a light pool and a pop-up, and the ball has a trail")
	t.check(main._bloom > 0.0, "and the bloom is up")
	t.check(fx._shapes.any(func(s: Fx.Shape) -> bool: return s.boost == Fx.BLAST_OUTER) and fx._shapes.any(func(s: Fx.Shape) -> bool: return s.boost == Fx.RING_BOOST),
			"the inner shockwave is lit and the outer one is an unlit echo of it")
	var dim := Fx._lit(Palette.EXPLOSIVE, 0.4)
	t.check(is_equal_approx(dim.a, 0.4) and is_equal_approx(dim.r, Palette.EXPLOSIVE.r) and Fx._lit(Palette.EXPLOSIVE, 2.0).a == 1.0 and Fx._lit(Palette.EXPLOSIVE, 2.0).r < Fx._lit(Palette.EXPLOSIVE, 8.0).r,
			"a fade lowers a lit colour's brightness first and its alpha only under a strength of 1")
	t.check(fx._pops[0].coins == round.coins and fx._pops[0].text == "+%d" % round.coins, "one pop-up carries everything a frame paid (%s for %d)" % [fx._pops[0].text, round.coins])
	t.check(fx._paths.size() == round.balls.size() and fx._paths[round.balls[0].id].size() <= Fx.TRAIL_SAMPLES, "every ball has a path for its trail, of TRAIL_SAMPLES at most")

	var heard := round.brick_broken.get_connections().size()
	fx.clear()
	t.check(_count(fx) == 0 and fx.get_child_count() == 4, "clear() leaves no effect (%d left)" % _count(fx))
	t.check(fx.shake == Vector2.ZERO and not fx.frozen and fx.heat == 0.0, "clear() leaves no shake, no freeze and no heat")
	t.check(main._bloom == 0.0 and is_equal_approx(main.env.glow_intensity, Main.GLOW), "clear() puts the bloom back to rest")
	t.check(round.brick_broken.get_connections().size() == heard - 1, "clear() stops listening to the round")
	round.blast(Vector2i(32, 5), 64.0)
	await t.tree().process_frame
	t.check(_count(fx) == 0 and not fx.frozen, "a cleared Fx shows nothing of a round it no longer watches")

	# A round nobody else holds is freed the moment Fx lets go of it.
	var lone := Round.new(Levels.read(1).board, null, Progress.snapshot(), 7)
	var held: WeakRef = weakref(lone)
	fx.watch(lone)
	lone.blast(Vector2i(48, 3), 64.0)
	lone.step(1.0 / 120.0, 0.0)
	fx._process(1.0 / 60.0)
	lone = null
	t.check(held.get_ref() != null, "Fx reads the round it watches")
	fx.clear()
	t.check(held.get_ref() == null, "clear() lets go of the round: it is freed")


func _freeze() -> void:
	await _play(1)
	round.blast(Vector2i(48, 3), 64.0)
	t.check(fx.frozen, "an explosion freezes the game")
	var left := round.time_left
	await t.tree().create_timer(0.3).timeout
	t.check(not fx.frozen and round.time_left < left, "the freeze ends by itself, well inside the second the level case waits")

	await _play(1)
	round.blast(Vector2i(48, 3), 64.0)
	fx._process(Fx.BLAST_FREEZE * 0.5)
	t.check(fx.frozen, "a freeze lasts BLAST_FREEZE")
	fx._process(Fx.BLAST_FREEZE)
	t.check(not fx.frozen, "and no longer")
	round.blast(Vector2i(48, 5), 64.0)
	fx._process(Fx.FREEZE_GAP * 0.5)
	round.blast(Vector2i(48, 1), 64.0)
	t.check(not fx.frozen, "a second and a third big hit inside FREEZE_GAP do not freeze again")
	fx._process(Fx.FREEZE_GAP)
	round.blast(Vector2i(62, 6), 64.0)
	t.check(fx.frozen, "after FREEZE_GAP the next one does")
	fx.frozen = false
	fx._hold = 0.0
	fx.frozen = true
	fx._process(1.0)
	t.check(fx.frozen, "a freeze somebody else holds is left alone")
	round.blast(Vector2i(32, 2), 64.0)
	fx._process(1.0)
	t.check(fx.frozen, "also when a freeze of Fx's own ends while it is held")
	fx.frozen = false


func _bloom() -> void:
	t.check(Fx.heat_of(0) == 0.0 and Fx.heat_of(1) == 0.0 and Fx.heat_of(Fx.COMBO_TOP) == 1.0 and Fx.heat_of(Fx.COMBO_TOP * 3) == 1.0,
			"heat is 0 with no combo and 1 from COMBO_TOP on")
	var before := 0.0
	for count in range(2, Fx.COMBO_TOP + 1):
		t.check(Fx.heat_of(count) > before, "heat climbs with every break up to COMBO_TOP (at %d)" % count)
		before = Fx.heat_of(count)

	await _play(2)
	var plain: Array[Vector2i] = []
	for cell: Vector2i in round.board.bricks:
		if round.board.brick(cell).kind == &"":
			plain.append(cell)
	plain.sort()
	_combo(round, 11)
	round.hit_brick(plain[0], Round.Cause.BALL, Vector2.RIGHT)
	fx._process(1.0)
	var at_12: float = main._bloom
	t.check(is_equal_approx(fx.heat, Fx.heat_of(12)) and is_equal_approx(at_12, Fx.heat_of(12) * Fx.HEAT_BLOOM), "at a combo of 12 the bloom is heat_of(12) of what the heat may reach (it is %.2f)" % at_12)
	t.check(main.env.glow_intensity > Main.GLOW, "and the picture glows more than at rest")
	_combo(round, Fx.COMBO_TOP - 1)
	round.hit_brick(plain[1], Round.Cause.BALL, Vector2.RIGHT)
	fx._process(1.0)
	t.check(is_equal_approx(main._bloom, Fx.HEAT_BLOOM) and main._bloom > at_12, "at COMBO_TOP the bloom is as high as the heat takes it")
	round.blast(plain[2], 64.0)
	fx._process(0.0)
	t.check(main._bloom > Fx.HEAT_BLOOM, "and a blast still flashes on top of that (%.2f)" % main._bloom)
	fx._process(1.0)

	# The combo runs out: the round says so, and the bloom comes down over half a second, not at once.
	round.combo.time_left = 1.0 / 240.0
	for i in 3:
		await t.tree().physics_frame
	t.check(round.combo.count == 0 and fx.heat == 0.0, "the heat is gone when the combo ends")
	fx._kick = 0.0
	fx._glow = 1.0
	fx._process(0.1)
	t.check(main._bloom < Fx.HEAT_BLOOM and main._bloom > Fx.HEAT_BLOOM * 0.5, "the bloom comes down smoothly (%.2f a tenth of a second on)" % main._bloom)
	fx._process(1.0)
	t.check(main._bloom == 0.0, "and is back at rest within the second")

	# The round ends in the middle of a combo.
	_combo(round, 30)
	fx._process(1.0)
	round.time_left = 0.0
	for i in 3:
		await t.tree().physics_frame
	t.check(round.over and fx.heat == 0.0, "the heat is gone when the round ends, so the Summary opens over a calm picture")
	t.check(round.reason == Round.End.TIME and fx._shapes.size() >= round.balls.size() and fx.squares() > 0, "time running out leaves a ring and squares at every ball")


## Coin pop-ups from bricks side by side join, and a pop-up is drawn in screen pixels on a zoomed level.
func _pop_ups() -> void:
	await _play(2)
	var plain: Array[Vector2i] = []
	for cell: Vector2i in round.board.bricks:
		if round.board.brick(cell).kind == &"":
			plain.append(cell)
	plain.sort()
	var first: Vector2i = plain.filter(func(c: Vector2i) -> bool: return c + Vector2i(3, 0) in plain and c.y > 1)[0]
	round.hit_brick(first, Round.Cause.BALL, Vector2.RIGHT)
	fx._process(1.0 / 60.0)
	round.hit_brick(first + Vector2i.RIGHT, Round.Cause.BALL, Vector2.RIGHT)
	fx._process(1.0 / 60.0)
	t.check(fx._pops.size() == 1 and fx._pops[0].coins == round.coins, "coins from the brick next door, a frame later, join the pop-up that is there (%d pop-ups)" % fx._pops.size())
	round.hit_brick(plain[-1], Round.Cause.BALL, Vector2.RIGHT)
	t.check(fx._pops.size() == 2, "a break far away starts its own")
	fx._process(Fx.POP_JOIN)
	round.hit_brick(first + Vector2i(2, 0), Round.Cause.BALL, Vector2.RIGHT)
	t.check(fx._pops.size() == 3, "and so does one next door after POP_JOIN")

	await _play(3)
	round.blast(Vector2i(40, 2), 64.0)
	t.check(not fx._pops.is_empty() and round.board.zoom() < 1.0 and fx._text.get_global_transform().get_scale().is_equal_approx(Vector2.ONE),
			"on a zoomed level a pop-up is still drawn one font pixel to one screen pixel")

	# A top-row brick's coins have no room above it and are pushed down, to where an hourglass's time goes.
	for number: int in [1, 3]:
		await _play(number)
		var top: Vector2i = round.board.bricks.keys().filter(func(c: Vector2i) -> bool: return c.y == 0)[0]
		round.board.brick(top).kind = &"hourglass"
		round.board.brick(top).hp = 1
		round.hit_brick(top, Round.Cause.BALL, Vector2.RIGHT)
		t.check(fx._pops.size() == 2 and fx._pops[1].at.y - fx._pops[0].at.y >= (Fx.POP_TALL + Fx.POP_RIM) * fx._px,
				"level %d: a top-row hourglass's time is a text height under its coins, not on them" % number)


func _calm() -> void:
	await _play(1)
	Settings.reduce_flashing = true
	round.blast(Vector2i(48, 3), 64.0)
	fx._process(1.0 / 60.0)
	t.check(fx._pools.is_empty() and fx._kick == 0.0, "reduce flashing: no light pool and no flash")
	var tagged := round.board.bricks.keys()[0] as Vector2i
	round.board.brick(tagged).mod = &"zap"
	round.board.brick(tagged).hp = 2
	round.hit_brick(tagged, Round.Cause.BALL, Vector2.RIGHT)
	round.hit_brick(tagged, Round.Cause.BALL, Vector2.RIGHT)
	t.check(fx._shapes.any(func(s: Fx.Shape) -> bool: return s.width == 0.0 and s.boost == 1.0), "reduce flashing: the Zap's bolt is unlit")
	t.check(fx._marks.size() >= 2 and fx._marks.all(func(s: Fx.Shape) -> bool: return s.width > 0.0 or s.boost <= Palette.LIT), "reduce flashing: a hit brick's flash is no brighter than a brick")
	t.check(fx._shapes.size() >= 2 and fx.squares() > 0 and not fx._pops.is_empty(), "reduce flashing: shockwaves, squares and pop-ups stay")
	var shapes := fx._shapes.size()
	round.ball_lost.emit(round.balls[0])
	t.check(fx._shapes.size() == shapes + 1, "reduce flashing: a lost ball leaves its ring and no red bar down the screen")
	var calm := _widest_shake()  # its frames deal out what the breaks above left queued, so count again after
	Settings.reduce_flashing = false  # live: nothing is rebuilt
	shapes = fx._shapes.size()
	round.ball_lost.emit(round.balls[0])
	t.check(fx._shapes.size() == shapes + 2, "without it the bar is there")
	round.blast(Vector2i(48, 5), 64.0)
	fx._process(1.0 / 60.0)
	t.check(fx._pools.size() == 1 and fx._kick > 0.0, "and so are the pool and the flash, the moment the setting changes")
	var wild := _widest_shake()
	t.check(calm <= Fx.SHAKE * Fx.SHAKE_CALM and wild > Fx.SHAKE * Fx.SHAKE_CALM and wild <= Fx.SHAKE,
			"reduce flashing halves the shake (%.0f px against %.0f)" % [calm, wild])
	t.check(fx.shake == fx.shake.round(), "the shake is in whole pixels, so text stays sharp")


## The furthest the shake goes at full strength, over 60 frames.
func _widest_shake() -> float:
	var widest := 0.0
	for i in 60:
		fx._strength = 1.0
		fx._process(0.0)
		widest = maxf(widest, maxf(absf(fx.shake.x), absf(fx.shake.y)))
	return widest


## The worst burst on level 3 (tests/shots/fx.gd, `worst`), and then a blast every frame for a second.
func _bursts() -> void:
	await _play(3)
	_combo(round, Fx.COMBO_TOP)
	fx._process(1.0)
	var bricks := round.board.bricks.size()
	(load("res://tests/shots/fx.gd") as GDScript).worst(round)
	t.check(bricks - round.board.bricks.size() > 250, "the worst burst breaks more than 250 bricks in one step (%d)" % (bricks - round.board.bricks.size()))
	fx._process(1.0 / 60.0)
	# What one frame may add: DEBRIS shared by the breaks, and each blast's own squares, fewer for each one after.
	var most := Fx.DEBRIS + 1.0
	for i in Fx.BLAST_MOST:
		most += Fx.BLAST_SPARKS * (1.0 + Fx.MORE_SPARKS) / (1 + i)
	t.check(fx.squares() > 100 and fx.squares() <= most, "the burst adds no more squares than a frame may (%d of %d)" % [fx.squares(), most])
	t.check(fx._marks.size() == 4, "a burst leaves no mark on each brick: only the two a ball broke flash and ring (%d)" % fx._marks.size())
	t.check(fx._shapes.size() >= 8 and fx._shapes.size() <= Fx.SHAPES, "its shockwaves and bolts are all there (%d)" % fx._shapes.size())
	t.check(fx._pools.size() <= Fx.POOLS and fx._pops.size() <= Fx.POPS, "pools and pop-ups stay under their caps")

	var cells := round.board.bricks.keys()
	var seen := 0
	for i in 60:
		if cells.is_empty():
			break
		round.blast(cells.pop_at(cells.size() / 2), 128.0)
		fx._process(1.0 / 60.0)
		seen = maxi(seen, fx.squares())
		if fx.squares() > Fx.PARTICLES or fx._shapes.size() > Fx.SHAPES or fx._marks.size() > Fx.SHAPES or fx._pools.size() > Fx.POOLS or fx._pops.size() > Fx.POPS:
			t.check(false, "a blast every frame stays under every cap (frame %d: %d squares, %d shapes, %d marks)" % [i, fx.squares(), fx._shapes.size(), fx._marks.size()])
			break
	t.check(seen > Fx.PARTICLES / 2, "and that fills most of the squares there are (%d of %d)" % [seen, Fx.PARTICLES])
	fx._process(5.0)
	t.check(fx.squares() + fx._shapes.size() + fx._marks.size() + fx._pools.size() + fx._pops.size() == 0, "every effect ends by itself")


## Effects never change the round: the same round, watched and not, ends the same.
func _same_round() -> void:
	Main.show_hub()
	var watcher := Fx.new()
	t.add_child(watcher)
	var board := Levels.read(2).board
	var stats := Progress.snapshot()
	var watched := Round.new(board, null, stats, 11)
	var bare := Round.new(board, null, stats, 11)
	watcher.watch(watched)
	for i in 1500:
		for one: Round in [watched, bare]:
			if not one.balls.is_empty():
				one.step(1.0 / 120.0, one.balls[0].pos.y)
		if i % 2 == 0:
			watcher._physics_process(1.0 / 120.0)
			watcher._process(1.0 / 60.0)
	var same := watched.coins == bare.coins and watched.time_left == bare.time_left and watched.board.bricks.size() == bare.board.bricks.size() and watched.balls.size() == bare.balls.size() and watched.over == bare.over
	for i in mini(watched.balls.size(), bare.balls.size()):
		same = same and watched.balls[i].pos == bare.balls[i].pos
	t.check(same and watched.tally.best_combo > 3, "a watched round plays exactly like one nobody watches (%d coins against %d)" % [watched.coins, bare.coins])
	watcher.free()


## What the worst burst costs in script time: the signal handlers, dealing the burst out, and drawing it.
## The least of five runs, so that a busy machine does not fail the case.
func _cost() -> void:
	var worst := load("res://tests/shots/fx.gd") as GDScript
	var board := Levels.read(3).board
	var stats := Progress.snapshot()
	var bare := 1 << 60
	var handlers := 1 << 60
	var dealing := 1 << 60
	var drawing := 1 << 60
	var later := 1 << 60
	for run in 5:
		var watcher := Fx.new()
		t.add_child(watcher)
		watcher.set_process(false)  # its clock is ours, so one _process is one draw
		var spent := [0, 0]  # microseconds in the draws, and how many layers drew
		for layer: Node2D in watcher.get_children():
			var draws: Callable = layer.draw.get_connections()[-1].callable
			layer.draw.disconnect(draws)
			layer.draw.connect(func() -> void:
				var from := Time.get_ticks_usec()
				draws.call()
				spent[0] += Time.get_ticks_usec() - from
				spent[1] += 1)
		var watched := Round.new(board, null, stats, 7)
		var alone := Round.new(board, null, stats, 7)
		watcher.watch(watched)
		_combo(watched, Fx.COMBO_TOP)
		_combo(alone, Fx.COMBO_TOP)
		watched.step(1.0 / 120.0, 0.0)
		watcher._physics_process(1.0 / 120.0)
		watcher._physics_process(1.0 / 120.0)

		var from := 0
		for one: Round in [alone, watched] if run % 2 == 0 else [watched, alone]:  # turn about: the second is warm
			from = Time.get_ticks_usec()
			worst.worst(one)
			if one == alone:
				bare = mini(bare, Time.get_ticks_usec() - from)
			else:
				handlers = mini(handlers, Time.get_ticks_usec() - from)
		from = Time.get_ticks_usec()
		watcher._process(1.0 / 60.0)
		dealing = mini(dealing, Time.get_ticks_usec() - from)
		var squares := watcher.squares()
		await t.tree().process_frame
		await t.tree().process_frame
		t.check(spent[1] == 4 and squares > 100, "all four layers drew the burst (%d did, %d squares)" % [spent[1], squares])
		drawing = mini(drawing, spent[0])

		spent[0] = 0
		spent[1] = 0
		from = Time.get_ticks_usec()
		watcher._process(1.0 / 60.0)
		var updating := Time.get_ticks_usec() - from
		await t.tree().process_frame
		await t.tree().process_frame
		t.check(spent[1] == 4, "and the frame after it")
		later = mini(later, updating + spent[0])
		watcher.free()
	var frame := maxi(handlers - bare, 0) + dealing + drawing
	print("fx: the worst burst costs %.2f ms of script in its frame (handlers %.2f, dealing it out %.2f, drawing %.2f) and %.2f ms the frame after; the round's own work in that step is %.2f ms"
			% [frame / 1000.0, maxi(handlers - bare, 0) / 1000.0, dealing / 1000.0, drawing / 1000.0, later / 1000.0, bare / 1000.0])
	t.check(frame < BUDGET and later < BUDGET, "the worst burst stays under %d ms of script a frame (%.2f, then %.2f)" % [BUDGET / 1000, frame / 1000.0, later / 1000.0])
