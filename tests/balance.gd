extends Node
## The balance bot: plays the real rules headless with a paddle that stands in for a person, to measure what a
## level pays and how far a player gets. A tuner changes numbers under data/ and runs this to see what moved.
##
##   tests/run.sh bot                       the standard report: every level fresh and maxed, and a campaign
##   tests/run.sh bot batch level=1 ranks=fresh skill=average seeds=20 layout=auto
##   tests/run.sh bot campaign skill=average rounds=400
##   tests/run.sh bot check                 is the bot itself sane: lost balls and caught drops by skill, same seed same line
##
## Keys (all optional):
##   level   a level number, or all. 0 is a test board: no bricks but one that cannot break, at the back; -1 is
##           the same with a column of Power Bricks (_board)
##   ranks   fresh, max, or a list such as max,combo:0 or paddle_speed:2,bumper:1 (applied left to right)
##   skill   clumsy, average, good, or all (a campaign then plays as average)
##   seeds   rounds per line in a batch
##   layout  empty, or auto: the best spot for each item the ranks allow, found by playing (see _auto), or a
##           file such as res://tests/layouts/found.json: a layout for some levels, kept the same whatever the
##           ranks are, of which a round uses the items its ranks allow, in the file's order (see _given). A
##           level the file leaves out gets the auto layout
##   rounds  the campaign's round limit
##   base    added to every seed a batch or a campaign plays with (default 0), to measure on other seeds
##   reaction, aim, steer, focus   override the skill's own numbers (see THE PLAYER); focus=0 ignores the aims
##   probe   seeds per skill for the campaign's stage probes (default 10; 0 skips them, see _stages)
##   charges hold (default): a charge waits on the paddle until no other ball is in play, as insurance, or until the
##           round's last SPEND seconds, when what is left is spent; launch: it goes at once
##   ability zap, blast, or first (default: whatever the round selects when built, the first unlocked): the ability
##           every charge is fired with. One that is not unlocked changes nothing
##   key     zap (default), blast or overgrowth: the key node the campaign's buyer takes first when a key is in
##           hand and more than one key node is on offer
##
## tests/layouts/found.json is what the search found, kept: on levels 1 and 2 the Splitters only (wherever
## the search puts a Bumper, a Booster or a Wall Segment there, this player does no better, and often worse: it does
## not foresee a bounce off its own item), on level 3 every item, from the best of several searches with every
## upgrade owned. Tuning compared numbers on it. A campaign with it takes a second; with the search, minutes. It
## was searched before the ability system, when Zaps were placed items; those entries are gone, and nothing has
## been searched again since.
##
## Every number is seeded: the same arguments give the same report. A table is printed and the full results
## are written as JSON to tests/out/bot/<mode>.json. The save is tests/out/bot/save.json (Progress.use), never
## the player's.
##
## THE PLAYER. A person watches the ball, sees a bounce a moment late, guesses where the ball will come back to
## the paddle's side, and puts the paddle there, not exactly. So the bot sees each ball as it was `reaction`
## seconds ago, traces its straight line off the walls (not off bricks or items: nobody foresees those) to the
## paddle's face, and aims the paddle's centre there plus an error drawn from a normal curve of width `aim`
## units, drawn again every time it sees that ball turn. It follows the ball that will arrive first. Better
## players also `steer`: they catch the ball off centre so it leaves toward the middle of the bricks left.
## Without that a ball caught dead centre always leaves at the minimum angle below level, and on level 3 it
## walks down the wall's face until it comes back too steep to reach, even for the perfect player.
## A level can mark cells a skilled player goes for (LevelData.aims: the aim tile, painted in the level scene),
## such as level 3's tunnel mouth. Each time the bot plans a catch, it aims
## at the easiest of them instead of steering, with the chance `focus`, if one can be reached: in a straight
## line or off the top or bottom wall once, from the paddle's middle 80%. That is the player knowing the level.
## A drop (from a Power Brick) is one more thing arriving: it comes straight along its row, so it arrives at its own
## y after its distance over drop_speed. The bot sees it as late as a ball and aims at it with the same error, drawn
## once (a drop never turns), with no steering. Balls and drops are one list and the bot goes for whichever arrives
## first: it never lets a ball go to catch a drop, and goes for a drop only when no ball comes back sooner. A drop
## wholly behind the paddle is forgotten.
## # ponytail: the skills are three hand-set rows in SKILLS. Fit them to recordings of real players once there
## # are any.

const STEP := 1.0 / 120.0
## With charges=hold, the seconds left on the timer at which the bot fires the charges it still holds: insurance
## that was not needed is spent before the round ends, as a person would, with time for a ball to cross the board.
const SPEND := 3.0
const OUT := "res://tests/out/bot"
const SKILLS := {
	"clumsy": {"reaction": 0.30, "aim": 44.0, "steer": 0.0, "focus": 0.0},
	"average": {"reaction": 0.20, "aim": 18.0, "steer": 0.4, "focus": 0.3},
	"good": {"reaction": 0.12, "aim": 8.0, "steer": 0.8, "focus": 0.8},
	"perfect": {"reaction": 0.0, "aim": 0.0, "steer": 0.8, "focus": 1.0},  # nobody plays like this: it tells the bot's misses from the rules'
}
## The auto layout's search (_best_spot): the seeds every spot is played with, how many of the best go on to be
## played again with FINAL_SEEDS, and the turns it tries a rotatable item at. None of these are the batch's seeds.
const SEARCH_SEEDS := [1001, 1002, 1003]
const KEEP := 4
const FINAL_SEEDS := [2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012]
const ROTATIONS := [0.0, 45.0, 90.0, 135.0]
## Where each level's stages should end (_stages), in rounds from its first: [stage 1, stage 2]. The goals in
## docs/design.md, "Progression"; change them there too.
const STAGE_GOALS := {1: [2, 6], 2: [4, 10], 3: [6, 16]}
## The upgrade web's scene: the bot asks an instance of it, never on screen, which nodes are on offer, so it buys
## what the hub would.
const WEB_SCENE := HubWeb.SCENE

var _args := {"mode": "report", "level": "all", "ranks": "fresh", "skill": "average", "seeds": "20",
		"layout": "auto", "rounds": "400", "base": "0", "charges": "hold", "ability": "first", "key": "zap"}
var _boards := {}  # level -> Board, read once
var _targets := {}  # level -> its LevelData.target, read with its board; the test boards are never cleared
var _aims := {}  # level -> its LevelData.aims as cell centres, for Player
var _layouts := {}  # cache key -> Layout, for _auto
var _web: HubWeb  # WEB_SCENE, instanced for the length of a campaign and never put on screen


## Stands in for a person at the mouse. See THE PLAYER at the top.
class Player:
	var reaction_steps: int
	var aim: float
	var steer: float
	var focus: float
	var aims: Array[Vector2] = []  # the level's aim cells' centres, in units
	var rng := RandomNumberGenerator.new()
	var _seen: Array = []  # what each step showed: [[id, pos, dir, speed], ...], oldest first; a drop's id is -1 - drop.id
	var _plan := {}  # that id -> [the dir it was last seen with, how far off its arrival the paddle goes]

	func _init(skill: Dictionary, p_seed: int, p_aims: Array[Vector2] = []) -> void:
		reaction_steps = roundi(skill.reaction / STEP)
		aim = skill.aim
		steer = skill.steer
		focus = skill.focus
		aims = p_aims
		rng.seed = p_seed

	## Where the paddle's centre should go this step.
	func target(round: Round) -> float:
		var now := []
		for ball in round.balls:
			if ball == round.waiting:  # a charge on the paddle: nothing to chase
				continue
			now.append([ball.id, ball.pos, ball.dir, round.speed_of(ball)])
		# ponytail: whichever arrives first wins, so a drop never beats a ball that comes back sooner. A better
		# player would weigh them: take a drop just ahead of a ball it could still reach after, or skip a ball
		# that is lost anyway for a drop it can catch.
		for d in round.drops:
			if d.pos.x + d.size * 0.5 >= round.paddle.x - round.paddle.thickness:  # not yet wholly behind the paddle
				now.append([-1 - d.id, d.pos, Vector2.LEFT, round.stats.drop_speed])
		_seen.append(now)
		if _seen.size() > reaction_steps + 1:
			_seen.pop_front()
		var soonest := INF
		var aim_at := round.paddle.y
		for seen: Array in _seen[0]:
			var arrival := Player.arrival(seen[1], seen[2], round)
			if arrival.y / seen[3] >= soonest:
				continue
			soonest = arrival.y / seen[3]
			var plan: Array = _plan.get(seen[0], [Vector2.ZERO, 0.0])
			if plan[0] != seen[2]:
				var off := 0.0 if seen[0] < 0 else NAN  # a drop: nothing to steer
				if is_nan(off) and focus > 0.0 and aims and rng.randf() < focus:  # no draw without aims, so other levels play as before
					off = _aim(round, arrival.x)
				plan = [seen[2], (_steer(round, arrival.x) if is_nan(off) else off) + rng.randfn(0.0, aim)]
				_plan[seen[0]] = plan
			aim_at = arrival.x + plan[1]
		return aim_at

	## How far from the ball's arrival to put the paddle's centre so that the ball leaves for the easiest aim
	## cell: the shallowest line to one, straight or off the top or bottom wall once, that leaves from the
	## paddle's middle 80%. NAN if none can be reached.
	# ponytail: aims never switch off, and the line ignores bricks and items in the way. Give an aim a condition
	# (while bricks stand behind it, say) or trace the line if a level's aims start to cost the bot.
	func _aim(round: Round, arrival_y: float) -> float:
		var best := NAN
		var h := round.board.size().y
		for a in aims:
			for y: float in [a.y, -a.y, 2.0 * h - a.y]:
				var angle := rad_to_deg(atan2(y - arrival_y, a.x - round.paddle.x))
				var where := angle / round.stats.paddle_max_angle
				if absf(where) <= 0.8 and (is_nan(best) or absf(where) < absf(best)):
					best = where
		return NAN if is_nan(best) else -best * round.paddle.length * 0.5

	## How far from the ball's arrival to put the paddle's centre so that the ball leaves toward the middle of
	## the level bricks still standing, times `steer`. Never more than 0.8 of the way to the paddle's end.
	func _steer(round: Round, arrival_y: float) -> float:
		if steer == 0.0:
			return 0.0
		var sum := Vector2.ZERO
		var n := 0
		for cell: Vector2i in round.board.bricks:
			if not round.board.bricks[cell].placed:
				sum += round.board.cell_rect(cell).get_center()
				n += 1
		var to := sum / n if n else round.board.size() * 0.5
		var angle := rad_to_deg(atan2(to.y - arrival_y, to.x - round.paddle.x))
		var where := clampf(angle / round.stats.paddle_max_angle, -0.8, 0.8)
		return -where * round.paddle.length * 0.5 * steer

	## Where a ball at `pos` going along `dir` meets the paddle's face, bouncing off the walls only:
	## Vector2(y there, distance to get there).
	static func arrival(pos: Vector2, dir: Vector2, round: Round) -> Vector2:
		var h := round.stats.ball_size * 0.5
		var size := round.board.size()
		var face := round.paddle.x + h
		var gone := 0.0
		for i in 16:
			var tx := INF
			if dir.x < 0.0:
				tx = (face - pos.x) / dir.x
			elif dir.x > 0.0:
				tx = (size.x - h - pos.x) / dir.x
			var ty := INF
			if dir.y < 0.0:
				ty = (h - pos.y) / dir.y
			elif dir.y > 0.0:
				ty = (size.y - h - pos.y) / dir.y
			var t := maxf(minf(tx, ty), 0.0)
			pos += dir * t
			gone += t
			if tx <= ty:
				if dir.x < 0.0:
					break
				dir.x = -dir.x
			else:
				dir.y = -dir.y
		return Vector2(pos.y, gone)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if "=" in arg:
			_args[arg.get_slice("=", 0)] = arg.get_slice("=", 1)
		else:
			_args.mode = arg
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Progress.use(OUT.path_join("save.json"))
	var started := Time.get_ticks_msec()
	var result: Dictionary
	match _args.mode:
		"batch":
			result = {"batch": _batches(_levels(), _args.ranks, _skills(), int(_args.seeds), _args.layout)}
		"campaign":
			result = {"campaign": _campaign(_skills()[1 if _args.skill == "all" else 0], int(_args.rounds))}
		"check":
			result = _check()
		"trace":
			_set_ranks(_args.ranks)
			var stats := Progress.snapshot()
			var level := int(_args.level)
			result = _play(level, _given(level, stats, _args.layout), stats, _args.skill, int(_args.get("seed", "1")), true)
		"report":
			var lines := _batches(_levels(), "fresh", _skills(), int(_args.seeds), "empty")
			lines.append_array(_batches(_levels(), "max", _skills(), int(_args.seeds), _args.layout))
			result = {"batch": lines, "campaign": _campaign(_skills()[1 if _args.skill == "all" else 0], int(_args.rounds))}
		_:
			push_error("unknown mode %s: batch, campaign, check or report" % _args.mode)
			get_tree().quit(1)
			return
	result.args = _args
	result.seconds = (Time.get_ticks_msec() - started) / 1000.0
	var path := OUT.path_join("%s.json" % _args.mode)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t"))
	f.close()
	print("\n%.1f s. Full results in %s" % [result.seconds, ProjectSettings.globalize_path(path)])
	get_tree().quit(1 if result.get("failed") else 0)


func _levels() -> Array:
	return range(1, Levels.count() + 1) if _args.level == "all" else [int(_args.level)]


func _skills() -> Array:
	return ["clumsy", "average", "good"] if _args.skill == "all" else [_args.skill]


## A level's board, read once. Level 0 is the test board: a level-1-sized grid whose one brick, at the back
## wall in the middle, cannot be broken in a round, so a round there ends only by time or by a lost ball.
## Level -1 is the drop board (_check): the test board with a column of Power Bricks, one per brick row, a third of
## the way back, so every round breaks some and their drops come from every height.
func _board(level: int) -> Board:
	if not _boards.has(level):
		if level <= 0:
			var b := Board.new()
			b.bricks[Vector2i(b.cols - 1, b.rows / 4)] = Brick.new(100000)
			for row in (b.rows / 2 if level < 0 else 0):
				b.bricks[Vector2i(b.cols / 3, row)] = Brick.new(1, &"power")
			_boards[level] = b
			_targets[level] = 1 << 30
			_aims[level] = [] as Array[Vector2]
		else:
			var data := Levels.read(level)
			_boards[level] = data.board
			_targets[level] = data.target
			var aims: Array[Vector2] = []
			for cell in data.aims:
				aims.append(data.board.cell_rect(cell).get_center())
			_aims[level] = aims
	return _boards[level]


## Sets Progress.ranks from a ranks argument. Does not save.
func _set_ranks(spec: String) -> void:
	Progress.reset()
	for part in spec.split(",", false):
		if part == "max":
			for u in Progress.upgrades():
				Progress.ranks[u.id] = u.max_rank
		elif part != "fresh":
			var u := Progress.upgrade(StringName(part.get_slice(":", 0)))
			if u == null:
				push_error("no upgrade %s" % part)
				continue
			Progress.ranks[u.id] = clampi(int(part.get_slice(":", 1)), 0, u.max_rank)


## Plays one round to its end. Returns its line for the JSON.
## With `trace`, prints every bounce, hit and loss with the time, the ball and the paddle.
func _play(level: int, layout: Layout, stats: Balance, skill: String, seed: int, trace := false) -> Dictionary:
	var round := Round.new(_board(level), layout, stats, seed)
	round.hold()  # the game's launch, at once: off the centred paddle at a random point of the sway
	round.launch()
	round.target = _targets[level]
	if round.abilities().any(func(k: AbilityKind) -> bool: return k.id == StringName(_args.ability)):
		round.ability = StringName(_args.ability)  # nothing else changes it, so every charge fires with it
	var numbers: Dictionary = SKILLS[skill].duplicate()
	for key: String in numbers:  # reaction=, aim=, steer= and focus= on the command line override the skill's own
		numbers[key] = float(_args.get(key, numbers[key]))
	var player := Player.new(numbers, hash([seed, skill]), _aims[level])
	var steps := [0]  # an Array, so the lambdas see it change
	var paddle := round.paddle  # the lambdas hold this, not the round, which would then hold itself and leak
	if trace:
		var say := func(what: String, ball: Ball) -> void:
			print("%6.2f %-22s %s" % [steps[0] * STEP, what, "ball %s dir %s paddle %.0f" % [ball.pos.round(), ball.dir.snappedf(0.01), paddle.y] if ball else ""])
		round.ball_bounced.connect(func(b: Ball, h: Hit) -> void: say.call(Hit.Surface.find_key(h.surface), b))
		round.brick_hit.connect(func(c: Vector2i, hp: int, _c: Round.Cause) -> void: say.call("hit %s, %d left" % [c, hp], null))
		round.brick_broken.connect(func(c: Vector2i, _b: Brick, _c: Round.Cause, _d: Vector2, _n: int) -> void: say.call("broke %s" % c, null))
		round.ball_lost.connect(func(b: Ball) -> void: say.call("LOST", b))
		round.dropped.connect(func(d: Drop) -> void: say.call("drop at %s" % d.pos.round(), null))
		round.caught.connect(func(d: Drop) -> void: say.call("CAUGHT at %s" % d.pos.round(), null))
	# A lost ball is hopeless if, from the ball's last turn, the paddle at full speed could not have got to where it
	# left: nobody could have saved it, however quick. Many of those mean the rules, not the player, lose balls.
	var turned := {}  # ball id -> [its line's start, the step it turned on, the paddle's y then]
	var lost := [0, 0]  # balls lost, hopeless ones
	round.ball_lost.connect(func(b: Ball) -> void:
		var t: Array = turned[b.id]
		var reach: float = stats.paddle_speed * (steps[0] + 1 - t[1]) * STEP + (paddle.length + b.size) * 0.5
		lost[0] += 1
		lost[1] += int(absf(b.pos.y - t[2]) > reach))
	var power := [0, 0, 0]  # drops made, drops caught, charges fired
	round.dropped.connect(func(_d: Drop) -> void: power[0] += 1)
	round.caught.connect(func(_d: Drop) -> void: power[1] += 1)
	while not round.over:
		for ball in round.balls:
			if turned.get(ball.id, [null])[0] != ball.from:
				turned[ball.id] = [ball.from, steps[0], round.paddle.y]
		# A charge on the paddle goes at once with `charges=launch`, else when no other ball is left to play or the
		# round is SPEND seconds from its end.
		if round.waiting and (_args.charges == "launch" or round.balls.size() == 1 or round.time_left <= SPEND):
			round.launch()
			power[2] += 1
		var target := player.target(round)
		if trace and steps[0] % 12 == 0:
			print("%6.2f   paddle %.0f, going to %.0f" % [steps[0] * STEP, round.paddle.y, target])
		round.step(STEP, target)
		steps[0] += 1
	var bricks := 0
	for n: int in round.tally.broken.values():
		bricks += n
	return {"seed": seed, "bricks": bricks, "coins": round.coins, "time": steps[0] * STEP,
			"end": String(Round.End.find_key(round.reason)).to_lower(), "best_combo": round.tally.best_combo,
			"cleared": round.tally.cleared, "lost": lost[0], "hopeless": lost[1], "drops": power[0], "caught": power[1],
			"fired": power[2]}


## One line per level and skill: `seeds` rounds each, summed up. Prints the table: "of" is the level's bricks,
## "hopeless" the lost balls nobody could have saved out of all lost balls (see _play), "caught" the drops caught
## out of all drops made, "fired" the charges fired.
func _batches(levels: Array, ranks: String, skills: Array, seeds: int, layout_kind: String) -> Array:
	_set_ranks(ranks)
	var stats := Progress.snapshot()
	var out := []
	print("\nranks %s, layout %s, %d seeds" % [ranks, layout_kind, seeds])
	print("%-5s %-8s %-4s %-12s %-12s %-11s %-6s %-6s %-6s %-8s %-8s %-5s %s" % ["level", "skill", "of", "bricks", "coins",
			"time s", "clear", "lost", "combo", "hopeless", "caught", "fired", "items"])
	for level: int in levels:
		var layout := _given(level, stats, layout_kind)
		for skill: String in skills:
			var rounds := []
			for i in seeds:
				rounds.append(_play(level, layout, stats, skill, int(_args.base) + i + 1))
			var line := {"level": level, "ranks": ranks, "skill": skill, "of": _board(level).bricks.size(), "layout": layout.to_data(), "rounds": rounds}
			for key: String in ["bricks", "coins", "time", "best_combo"]:
				line[key] = _spread(rounds.map(func(r: Dictionary) -> float: return r[key]))
			var ends := {"time": 0, "ball_lost": 0, "cleared": 0}
			for key: String in ["lost", "hopeless", "drops", "caught", "fired"]:  # summed over the rounds
				line[key] = 0
			for r: Dictionary in rounds:
				ends[r.end] += 1
				for key: String in ["lost", "hopeless", "drops", "caught", "fired"]:
					line[key] += r[key]
			line.ends = ends
			line.clear_rate = rounds.filter(func(r: Dictionary) -> bool: return r.cleared).size() / float(seeds)  # the target, not End.CLEARED
			line.lost_rate = ends.ball_lost / float(seeds)
			out.append(line)
			print("%-5d %-8s %-4d %-12s %-12s %-11s %-6s %-6s %-6.1f %-8s %-8s %-5d %d" % [level, skill, line.of, _show(line.bricks),
					_show(line.coins), _show(line.time), _pct(line.clear_rate), _pct(line.lost_rate), line.best_combo.mean,
					"%d/%d" % [line.hopeless, line.lost], "%d/%d" % [line.caught, line.drops], line.fired, layout.items.size()])
	return out


func _pct(share: float) -> String:
	return "%d%%" % roundi(share * 100)


## Mean, standard deviation, lowest and highest.
func _spread(values: Array) -> Dictionary:
	var mean := 0.0
	for v: float in values:
		mean += v / values.size()
	var sd := 0.0
	for v: float in values:
		sd += (v - mean) * (v - mean) / values.size()
	return {"mean": mean, "sd": sqrt(sd), "min": values.min(), "max": values.max()}


func _show(s: Dictionary) -> String:
	return "%.1f ±%.1f" % [s.mean, s.sd] if s.mean < 100 else "%d ±%d" % [s.mean, s.sd]


## The layout a batch plays: none, the auto layout, or the one a file gives for the level. The file is JSON, a
## dictionary from level number to a layout's saved form (Layout.to_data, which is also a batch line's "layout" in
## the bot's own results). It may hold more items than the ranks allow: Layout.fitted keeps the first of each kind.
## A file's layout is the same for every set of numbers, which the auto layout is not: its search starts again
## when a number changes and can land somewhere else, and on level 3 that alone moves a batch by 100 bricks.
func _given(level: int, stats: Balance, kind: String) -> Layout:
	if kind == "empty":
		return Layout.new()
	var data: Variant = _filed(level, kind)
	return Layout.from_data(data).fitted(_board(level), stats) if data is Array else _auto(level, stats)


## The saved form the layout file `kind` holds for a level, or null: no file was named, or it leaves the level out.
func _filed(level: int, kind: String) -> Variant:
	if kind == "auto" or kind == "empty":
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(kind))
	if not data is Dictionary:
		push_error("layout=%s: not a file holding {\"<level>\": [items]}" % kind)
		return null
	return data.get(str(level))


## The auto layout for a level and a snapshot, from nothing. Cached: a batch asks for it once per level.
func _auto(level: int, stats: Balance) -> Layout:
	var key := [level, Kinds.placeables().map(func(k: PlaceableKind) -> int: return stats.count(k.id)), _args.get("aim"),
			_args.get("reaction"), _args.get("steer"), _args.get("focus")]
	if not _layouts.has(key):
		_layouts[key] = _fill(level, Layout.new(), stats)
	return _layouts[key]


## The layout a player would make: `start`, fitted, plus one item at a time while the stats allow more of a kind
## than it holds, in tray order, each put where it pays most and never moved again (as a player keeps a layout
## and adds what they bought). Where it pays most is found by playing (_best_spot).
func _fill(level: int, start: Layout, stats: Balance) -> Layout:
	var board := _board(level)
	var layout := start.fitted(board, stats)
	for kind in Kinds.placeables():
		while layout.count(kind.id) < stats.count(kind.id):
			var spots := _spots(board, layout, kind, stats)
			if spots.is_empty():
				break
			layout.add(_best_spot(level, layout, spots, stats))
	return layout


## Every place one more `kind` could go that the search tries. A free-form item, a placed brick or an area: the centre of
## each 64-unit square of the grid (a 4 x 1 block of brick cells), at each of ROTATIONS if it turns.
# ponytail: a raster, not every spot. A finer one costs time squared; try it if layouts look clumsy.
func _spots(board: Board, layout: Layout, kind: PlaceableKind, stats: Balance) -> Array[Layout.Item]:
	var out: Array[Layout.Item] = []
	for x in range(32, int(board.size().x), 64):
		for y in range(32, int(board.size().y), 64):
			for rot: float in ROTATIONS if kind.rotatable else [0.0]:
				var item := Layout.Item.new()
				item.kind = kind
				item.pos = Vector2(x, y)
				item.rot = rot
				item.cell = board.cell_at(item.pos)
				if layout.fits(item, board, stats):
					out.append(item)
	return out


## The spot that pays most: each is played with SEARCH_SEEDS by the average player, and the best KEEP of those
## are played again with FINAL_SEEDS, which decide. What pays is coins: every hit on a level brick scores, so a
## spot that only wears the bricks down still beats one that does nothing, and a hit on a placed brick or a
## block (Growth, Refresh) counts only for what it does to the level bricks.
func _best_spot(level: int, layout: Layout, spots: Array[Layout.Item], stats: Balance) -> Layout.Item:
	var scored := []
	for item in spots:
		scored.append([_value(level, layout, item, stats, SEARCH_SEEDS), scored.size(), item])
	# Best first; a tie goes to the earlier spot in the raster, so it is settled the same way every run.
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var best: Array = []
	for entry: Array in scored.slice(0, KEEP):
		var value := _value(level, layout, entry[2], stats, FINAL_SEEDS)
		if best.is_empty() or value > best[0]:
			best = [value, entry[2]]
	return best[1]


func _value(level: int, layout: Layout, item: Layout.Item, stats: Balance, seeds: Array) -> float:
	var trial := Layout.new()
	trial.items = layout.items.duplicate()
	trial.add(item)
	var sum := 0.0
	for s: int in seeds:
		var r := _play(level, trial, stats, "average", s)
		sum += r.coins
	return sum / seeds.size()


## From a fresh save, as a player would: play the highest level unlocked with its saved layout plus anything new
## the ranks allow (_fill; with layout=<file> or empty, that layout instead), take the coins, then buy. Stops after
## `limit` rounds, or once the last level is cleared and every level's stages are measured (_stages) or every
## rank is bought: until then it goes on playing the last level, as a player farming it would. Buying: while
## anything is affordable, the cheapest node the web offers (HubWeb.buyable: the seed, or one linked to a node
## owned); a tie goes to the first in the scene. A key node costs no coins, so it goes first while a key is in hand,
## and the one `key` names before any other (_price).
# ponytail: cheapest first is one sensible player, not the best one. Add a smarter buyer (save up for a node
# that unlocks a kind, say) if the campaign's pace looks wrong for a reason the buying explains.
func _campaign(skill: String, limit: int) -> Dictionary:
	var save := OUT.path_join("save.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	Progress.use(save)
	_web = (load(WEB_SCENE) as PackedScene).instantiate()
	var rounds := []
	var purchases := []
	var levels := {}  # level -> {rounds, coins, cleared_on}: rounds played and coins earned there up to its first clear
	var stages := {}  # level -> what _stages measured
	var probe := int(_args.get("probe", "10"))
	var done_on := 0  # the round the last level was first cleared on
	var last_progress := 0  # the last round that bought something or unlocked a level
	print("\ncampaign, skill %s, at most %d rounds" % [skill, limit])
	for i in limit:
		var level := mini(Progress.unlocked, Progress.level_count)
		var stats := Progress.snapshot()
		var layout := _fill(level, Progress.layout(level), stats) if _filed(level, _args.layout) == null and _args.layout != "empty" else _given(level, stats, _args.layout)
		Progress.set_layout(level, layout)
		if probe > 0:
			_stages(stages, i + 1, probe)
		if done_on and (stages.values().all(func(s: Dictionary) -> bool: return s.stage2 > 0)
				or Progress.upgrades().all(func(u: Upgrade) -> bool: return Progress.rank(u) >= u.max_rank)):
			break  # measured, or nothing left to buy that could change it
		var r := _play(level, layout, stats, skill, int(_args.base) + i + 1)
		r.level = level
		r.items = layout.items.size()
		rounds.append(r)
		var first: Dictionary = levels.get(level, {"rounds": 0, "coins": 0, "cleared_on": -1})
		if first.cleared_on < 0:
			first.rounds += 1
			first.coins += r.coins
			if r.cleared:
				first.cleared_on = i + 1
				last_progress = i + 1
				print("round %d: cleared level %d, %d rounds and %d coins after first playing it" % [i + 1, level,
						first.rounds, first.coins])
		levels[level] = first
		Progress.finish_round(level, r.coins, r.cleared)
		while true:
			var pick: HubNode = null
			for n in _web.nodes():
				if _web.buyable(n) and (pick == null or _price(n) < _price(pick)):
					pick = n
			if pick == null:
				break
			var u := pick.upgrade
			var price := 0 if u.key else Progress.cost(u)
			Progress.buy(u, pick.name)
			last_progress = i + 1
			purchases.append({"round": i + 1, "node": String(pick.name), "id": String(u.id), "rank": Progress.rank(u), "cost": price})
			print("round %d: bought %s (%s rank %d) for %d" % [i + 1, pick.name, u.id, Progress.rank(u), price])
		if r.cleared and level == Progress.level_count and not done_on:
			done_on = i + 1
			if probe <= 0:
				break
	print("\n%-5s %-8s %-8s %s" % ["level", "rounds", "coins", "first clear on round"])
	for level: int in levels:
		print("%-5d %-8d %-8d %s" % [level, levels[level].rounds, levels[level].coins,
				levels[level].cleared_on if levels[level].cleared_on > 0 else "never"])
	if stages:
		_print_stages(stages, levels)
	var of := _web.nodes().size()
	_web.free()
	var done := done_on > 0
	var keyed := purchases.filter(func(p: Dictionary) -> bool: return Progress.upgrade(p.id).key)
	var first_key: String = keyed[0].node if keyed else "none"
	print("%s, %d rounds played, %d of %d nodes bought, first key node %s, %d coins left. Last progress on round %d." % [
			"Finished on round %d" % done_on if done else "STUCK on level %d" % Progress.unlocked, rounds.size(),
			purchases.size(), of, first_key, Progress.coins, last_progress])
	return {"skill": skill, "finished": done, "finished_on": done_on, "stuck": not done, "rounds_played": rounds.size(),
			"last_progress": last_progress, "levels": levels, "stages": stages, "purchases": purchases,
			"nodes_bought": purchases.size(), "nodes": of, "first_key": first_key, "ranks": Progress.ranks,
			"coins_left": Progress.coins, "rounds": rounds}


## What the campaign's buyer compares: the next copy's price, or -1 for the key node `key` names, so it comes first.
func _price(n: HubNode) -> int:
	return -1 if n.upgrade.id == StringName(_args.key) else Progress.cost(n.upgrade)


## THE THREE STAGES of a level (docs/design.md, "Progression"), measured as a campaign goes. Before each round,
## every level reached so far is played `seeds` times by the good player and by the clumsy one, with the ranks
## owned then and the layout saved for the level. Stage 1, almost unbeatable, ends on the first round the good
## player clears 10% or more; stage 2, beatable with skill, ends on the first round the clumsy player clears half.
## A level stops being probed once both are found. Rounds count from the level's first round, which is round 1.
## On that first round the average player also plays the new level and the one before it: the new level should pay
## more, or farming the old one beats trying the new one. Probes play their own seeds, the same every time, so a
## change from one round to the next is the upgrades and not the dice.
# ponytail: a level left behind is probed with its saved layout, so items bought after leaving it are not placed
# there (with layout=<file>, the file's layout is). Run the search for it too if that makes stage 2 look late.
func _stages(stages: Dictionary, round_no: int, seeds: int) -> void:
	var stats := Progress.snapshot()
	for level in range(1, mini(Progress.unlocked, Progress.level_count) + 1):
		if not stages.has(level):
			stages[level] = {"first_round": round_no, "stage1": -1, "stage2": -1}
			if level > 1:
				stages[level].pays_new = _probe(level, stats, "average", seeds).coins
				stages[level].pays_old = _probe(level - 1, stats, "average", seeds).coins
		var s: Dictionary = stages[level]
		var nth: int = round_no - s.first_round + 1
		if s.stage1 < 0 and _probe(level, stats, "good", seeds).clear >= 0.1:
			s.stage1 = nth
		if s.stage1 > 0 and s.stage2 < 0 and _probe(level, stats, "clumsy", seeds).clear >= 0.5:
			s.stage2 = nth


## `seeds` rounds of a level by one skill with the ranks in `stats` and the level's saved layout:
## {clear: the share cleared, coins: the mean paid}.
func _probe(level: int, stats: Balance, skill: String, seeds: int) -> Dictionary:
	var layout := Layout.new()
	if _args.layout != "empty":
		layout = _given(level, stats, _args.layout) if _filed(level, _args.layout) != null else Progress.layout(level).fitted(_board(level), stats)
	var out := {"clear": 0.0, "coins": 0.0}
	for j in seeds:
		var r := _play(level, layout, stats, skill, int(_args.base) + 100001 + j)
		out.clear += float(r.cleared) / seeds
		out.coins += float(r.coins) / seeds
	return out


## The stages table: where each stage ended against STAGE_GOALS, with a ! where it is off by more than half the
## goal, and on a level's first round what the average player earns there and on the level before.
func _print_stages(stages: Dictionary, levels: Dictionary) -> void:
	print("\nstages, in rounds from the level's first (goal in brackets; ! is off by more than half)")
	print("%-5s %-12s %-14s %-14s %-15s %s" % ["level", "first round", "stage 1 ends", "stage 2 ends",
			"average clears", "pays on arrival, new / old"])
	for level: int in stages:
		var s: Dictionary = stages[level]
		var goal: Array = STAGE_GOALS.get(level, [0, 0])
		var cells := []
		for k in 2:
			var got: int = s["stage%d" % (k + 1)]
			var off: bool = goal[k] > 0 and (got < 0 or absf(got - goal[k]) > goal[k] * 0.5)
			cells.append("%s (%d)%s" % [str(got) if got > 0 else "never", goal[k], " !" if off else ""])
		var first: Dictionary = levels.get(level, {})
		var clears: String = str(first.rounds) if first.get("cleared_on", -1) > 0 else "never"
		var pays := "%.0f / %.0f%s" % [s.pays_new, s.pays_old, "" if s.pays_new >= s.pays_old else " !"] if s.has("pays_new") else ""
		print("%-5d %-12d %-14s %-14s %-15s %s" % [level, s.first_round, cells[0], cells[1], clears, pays])


## Is the bot itself sane? On the test board (level 0), where only a lost ball ends a round early: how often each
## skill loses the ball, against what a person of that skill would. On the drop board (level -1): what share of
## the drops each skill catches, and that every charge fired is counted and was caught first. And the same seed
## must give the same line, with every upgrade owned. Fails the run (exit 1) if not.
func _check() -> Dictionary:
	_set_ranks("fresh")
	var stats := Progress.snapshot()
	var want := {"clumsy": [0.3, 1.0], "average": [0.0, 0.25], "good": [0.0, 0.1]}  # the lost rate's bounds
	var out := {}
	var failed := []
	print("\n%-8s %-6s %s" % ["skill", "lost", "wanted"])
	for skill: String in want:
		var lost := 0
		for i in 40:
			lost += int(_play(0, Layout.new(), stats, skill, i + 1).end == "ball_lost")
		var rate := lost / 40.0
		out[skill] = rate
		var ok: bool = rate >= want[skill][0] and rate <= want[skill][1]
		print("%-8s %-6s %s to %s%s" % [skill, _pct(rate), _pct(want[skill][0]), _pct(want[skill][1]), "" if ok else "  FAIL"])
		if not ok:
			failed.append(skill)
	# The caught share's bounds. A drop comes straight and slow, so it is easier than a ball; a skill misses one
	# mostly when a ball comes back first and keeps the paddle away.
	var catch := {"clumsy": [0.3, 0.9], "average": [0.6, 1.0], "good": [0.75, 1.0], "perfect": [0.9, 1.0]}
	var fired := 0
	print("\n%-8s %-8s %-7s %-6s %s" % ["skill", "caught", "of", "fired", "wanted"])
	for skill: String in catch:
		var sum := {"drops": 0, "caught": 0, "fired": 0}
		var ok := true
		for i in 40:
			var r := _play(-1, Layout.new(), stats, skill, i + 1)
			ok = ok and r.fired <= r.caught  # a charge comes only from a catch
			for key: String in sum:
				sum[key] += r[key]
		var rate: float = sum.caught / maxf(sum.drops, 1.0)
		out["caught_" + skill] = rate
		ok = ok and rate >= catch[skill][0] and rate <= catch[skill][1]
		print("%-8s %-8s %-7d %-6d %s to %s%s" % [skill, _pct(rate), sum.drops, sum.fired, _pct(catch[skill][0]),
				_pct(catch[skill][1]), "" if ok else "  FAIL"])
		if not ok:
			failed.append("caught_" + skill)
		fired += sum.fired
	if fired == 0:  # someone loses a ball with a charge in hand, or the count is broken
		print("no charge fired  FAIL")
		failed.append("fired")
	_set_ranks("max")
	stats = Progress.snapshot()
	var a := _play(2, Layout.new(), stats, "average", 7)
	var b := _play(2, Layout.new(), stats, "average", 7)
	out.same_seed_same_line = a == b
	print("same seed, same line: %s" % ("yes" if a == b else "NO  FAIL"))
	if a != b:
		failed.append("seed")
	out.failed = failed
	if failed:
		push_error("the bot's check failed: %s" % ", ".join(failed))
	return out
