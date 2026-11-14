extends Node
## The balance bot: plays the real rules headless with a paddle that stands in for a person, to measure what a
## level pays and how far a player gets. A tuner changes numbers under data/ and runs this to see what moved.
##
##   tests/run.sh bot                       the standard report: every level fresh and maxed, and a campaign
##   tests/run.sh bot batch level=1 ranks=fresh skill=average seeds=20 layout=auto
##   tests/run.sh bot campaign skill=average rounds=400
##   tests/run.sh bot check                 is the bot itself sane: drop rates by skill, same seed same line
##
## Keys (all optional):
##   level   a level number, or all. 0 is a test board: no bricks but one that cannot break, at the back
##   ranks   fresh, max, or a list such as max,combo:0 or paddle_speed:2,bumper:1 (applied left to right)
##   skill   clumsy, average, good, or all (a campaign then plays as average)
##   seeds   rounds per line in a batch
##   layout  empty, or auto: the best spot for each item the ranks allow, found by playing (see _auto)
##   rounds  the campaign's round limit
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
## # ponytail: the skills are three hand-set rows in SKILLS. Fit them to recordings of real players once there
## # are any.

const STEP := 1.0 / 120.0
const OUT := "res://tests/out/bot"
const SKILLS := {
	"clumsy": {"reaction": 0.30, "aim": 44.0, "steer": 0.0},
	"average": {"reaction": 0.20, "aim": 18.0, "steer": 0.4},
	"good": {"reaction": 0.12, "aim": 8.0, "steer": 0.8},
	"perfect": {"reaction": 0.0, "aim": 0.0, "steer": 0.8},  # nobody plays like this: it tells the bot's misses from the rules'
}
## The auto layout's search (_best_spot): the seeds every spot is played with, how many of the best go on to be
## played again with FINAL_SEEDS, and the turns it tries a rotatable item at. None of these are the batch's seeds.
const SEARCH_SEEDS := [1001, 1002, 1003]
const KEEP := 4
const FINAL_SEEDS := [2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012]
const ROTATIONS := [0.0, 45.0, 90.0, 135.0]
## The upgrade web's connections, from the drawing in docs/design/upgrades.md.
# ponytail: copied by hand because the web scene (src/hub/web.tscn) is the hub lane's and does not exist here
# yet. Read the connections from that scene once it does, so the two cannot drift.
const WEB := [
	["paddle_speed", "ball_speed"], ["paddle_speed", "paddle_size"], ["paddle_speed", "bumper"],
	["paddle_speed", "explosive_brick"], ["ball_speed", "booster"], ["ball_speed", "gold_brick"],
	["gold_brick", "zap"], ["bumper", "combo"], ["combo", "splitter"], ["paddle_size", "wall_segment"],
	["explosive_brick", "shockwave"], ["explosive_brick", "blast_size"], ["explosive_brick", "round_time"],
	["round_time", "hourglass_brick"],
]
const SEED_NODE := "paddle_speed"

var _args := {"mode": "report", "level": "all", "ranks": "fresh", "skill": "average", "seeds": "20",
		"layout": "auto", "rounds": "400"}
var _boards := {}  # level -> Board, read once
var _layouts := {}  # cache key -> Layout, for _auto


## Stands in for a person at the mouse. See THE PLAYER at the top.
class Player:
	var reaction_steps: int
	var aim: float
	var steer: float
	var rng := RandomNumberGenerator.new()
	var _seen: Array = []  # what each step showed: [[id, pos, dir, speed], ...], oldest first
	var _plan := {}  # ball id -> [the dir it was last seen with, how far off its arrival the paddle goes]

	func _init(skill: Dictionary, p_seed: int) -> void:
		reaction_steps = roundi(skill.reaction / STEP)
		aim = skill.aim
		steer = skill.steer
		rng.seed = p_seed

	## Where the paddle's centre should go this step.
	func target(round: Round) -> float:
		var now := []
		for ball in round.balls:
			now.append([ball.id, ball.pos, ball.dir, round.speed_of(ball)])
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
				plan = [seen[2], _steer(round, arrival.x) + rng.randfn(0.0, aim)]
				_plan[seen[0]] = plan
			aim_at = arrival.x + plan[1]
		return aim_at

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
			result = _play(level, _auto(level, stats) if _args.layout == "auto" else Layout.new(), stats, _args.skill, int(_args.get("seed", "1")), true)
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
## wall in the middle, cannot be broken in a round, so a round there ends only by time or by a drop.
func _board(level: int) -> Board:
	if not _boards.has(level):
		if level == 0:
			var b := Board.new()
			b.bricks[Vector2i(b.cols - 1, b.rows / 4)] = Brick.new(100000)
			_boards[level] = b
		else:
			_boards[level] = Levels.read(level).board
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
	var numbers: Dictionary = SKILLS[skill].duplicate()
	for key: String in numbers:  # reaction=, aim= and steer= on the command line override the skill's own
		numbers[key] = float(_args.get(key, numbers[key]))
	var player := Player.new(numbers, hash([seed, skill]))
	var steps := [0]  # an Array, so the lambdas see it change
	var paddle := round.paddle  # the lambdas hold this, not the round, which would then hold itself and leak
	if trace:
		var say := func(what: String, ball: Ball) -> void:
			print("%6.2f %-22s %s" % [steps[0] * STEP, what, "ball %s dir %s paddle %.0f" % [ball.pos.round(), ball.dir.snappedf(0.01), paddle.y] if ball else ""])
		round.ball_bounced.connect(func(b: Ball, h: Hit) -> void: say.call(Hit.Surface.find_key(h.surface), b))
		round.brick_hit.connect(func(c: Vector2i, hp: int, _c: Round.Cause) -> void: say.call("hit %s, %d left" % [c, hp], null))
		round.brick_broken.connect(func(c: Vector2i, _b: Brick, _c: Round.Cause, _d: Vector2, _n: int) -> void: say.call("broke %s" % c, null))
		round.ball_lost.connect(func(b: Ball) -> void: say.call("LOST", b))
	# A drop is hopeless if, from the ball's last turn, the paddle at full speed could not have got to where it
	# left: nobody could have saved it, however quick. Many of those mean the rules, not the player, lose balls.
	var turned := {}  # ball id -> [its line's start, the step it turned on, the paddle's y then]
	var drops := [0, 0]  # drops, hopeless drops
	var hits := [0]  # every hit on a brick, broken or not
	round.brick_hit.connect(func(_c: Vector2i, _hp: int, _c2: Round.Cause) -> void: hits[0] += 1)
	round.brick_broken.connect(func(_c: Vector2i, _b: Brick, _c2: Round.Cause, _d: Vector2, _n: int) -> void: hits[0] += 1)
	round.ball_lost.connect(func(b: Ball) -> void:
		var t: Array = turned[b.id]
		var reach: float = stats.paddle_speed * (steps[0] + 1 - t[1]) * STEP + (paddle.length + b.size) * 0.5
		drops[0] += 1
		drops[1] += int(absf(b.pos.y - t[2]) > reach))
	while not round.over:
		for ball in round.balls:
			if turned.get(ball.id, [null])[0] != ball.from:
				turned[ball.id] = [ball.from, steps[0], round.paddle.y]
		var target := player.target(round)
		if trace and steps[0] % 12 == 0:
			print("%6.2f   paddle %.0f, going to %.0f" % [steps[0] * STEP, round.paddle.y, target])
		round.step(STEP, target)
		steps[0] += 1
	var bricks := 0
	for n: int in round.tally.broken.values():
		bricks += n
	return {"seed": seed, "bricks": bricks, "hits": hits[0], "coins": round.coins, "time": steps[0] * STEP,
			"end": String(Round.End.find_key(round.reason)).to_lower(), "best_combo": round.tally.best_combo,
			"cleared": round.reason == Round.End.CLEARED, "drops": drops[0], "hopeless": drops[1]}


## One line per level and skill: `seeds` rounds each, summed up. Prints the table: "of" is the level's bricks,
## "hopeless" the drops nobody could have saved out of all drops (see _play).
func _batches(levels: Array, ranks: String, skills: Array, seeds: int, layout_kind: String) -> Array:
	_set_ranks(ranks)
	var stats := Progress.snapshot()
	var out := []
	print("\nranks %s, layout %s, %d seeds" % [ranks, layout_kind, seeds])
	print("%-5s %-8s %-4s %-12s %-12s %-11s %-6s %-6s %-6s %-8s %s" % ["level", "skill", "of", "bricks", "coins", "time s",
			"clear", "lost", "combo", "hopeless", "items"])
	for level: int in levels:
		var layout := _auto(level, stats) if layout_kind == "auto" else Layout.new()
		for skill: String in skills:
			var rounds := []
			for i in seeds:
				rounds.append(_play(level, layout, stats, skill, i + 1))
			var line := {"level": level, "ranks": ranks, "skill": skill, "of": _board(level).bricks.size(), "layout": layout.to_data(), "rounds": rounds}
			for key: String in ["bricks", "coins", "time", "best_combo"]:
				line[key] = _spread(rounds.map(func(r: Dictionary) -> float: return r[key]))
			var ends := {"time": 0, "ball_lost": 0, "cleared": 0}
			var drops := 0
			var hopeless := 0
			for r: Dictionary in rounds:
				ends[r.end] += 1
				drops += r.drops
				hopeless += r.hopeless
			line.ends = ends
			line.clear_rate = ends.cleared / float(seeds)
			line.lost_rate = ends.ball_lost / float(seeds)
			line.drops = drops
			line.hopeless_drops = hopeless
			out.append(line)
			print("%-5d %-8s %-4d %-12s %-12s %-11s %-6s %-6s %-6.1f %-8s %d" % [level, skill, line.of, _show(line.bricks),
					_show(line.coins), _show(line.time), _pct(line.clear_rate), _pct(line.lost_rate),
					line.best_combo.mean, "%d/%d" % [hopeless, drops], layout.items.size()])
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


## The auto layout for a level and a snapshot, from nothing. Cached: a batch asks for it once per level.
func _auto(level: int, stats: Balance) -> Layout:
	var key := [level, Kinds.placeables().map(func(k: PlaceableKind) -> int: return stats.count(k.id)), _args.get("aim"),
			_args.get("reaction"), _args.get("steer")]
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


## Every place one more `kind` could go that the search tries. A free-form item or a placed brick: the centre of
## each 64-unit square of the grid (a 4 x 1 block of brick cells), at each of ROTATIONS if it turns. A mod: in
## each brick row, the brick nearest the paddle and the nearest 1 HP brick.
# ponytail: a raster, not every spot. A finer one costs time squared; try it if layouts look clumsy.
func _spots(board: Board, layout: Layout, kind: PlaceableKind, stats: Balance) -> Array[Layout.Item]:
	var out: Array[Layout.Item] = []
	if kind.placement == PlaceableKind.Placement.MOD:
		var cells := board.bricks.keys()
		for item in layout.items:
			if item.kind.placement == PlaceableKind.Placement.BRICK:
				cells.append(item.cell)
		cells.sort()  # by column, so the first of a row is the nearest the paddle
		var taken := {}
		for cell: Vector2i in cells:
			var soft := board.brick(cell) == null or board.brick(cell).hp == 1
			for which: String in ["front", "soft"] if soft else ["front"]:
				if taken.has([cell.y, which]):
					continue
				taken[[cell.y, which]] = true
				var item := Layout.Item.new()
				item.kind = kind
				item.cell = cell
				if layout.fits(item, board, stats) and not out.any(func(o: Layout.Item) -> bool: return o.cell == cell):
					out.append(item)
		return out
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
## are played again with FINAL_SEEDS, which decide. What pays is coins, and a tenth of a coin for every hit on
## a brick, so that on a level where nothing breaks yet the spot that wears the bricks down still wins.
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
		sum += r.coins + 0.1 * r.hits
	return sum / seeds.size()


## From a fresh save, as a player would: play the highest level unlocked with its saved layout plus anything new
## the ranks allow (_fill), take the coins, then buy. Stops when the last level is cleared or after `limit`
## rounds. Buying: while anything is affordable, the cheapest next rank of a node the web offers (the seed node,
## or one next to a node owned); a tie goes to the first by id.
# ponytail: cheapest first is one sensible player, not the best one. Add a smarter buyer (save up for a node
# that unlocks a kind, say) if the campaign's pace looks wrong for a reason the buying explains.
func _campaign(skill: String, limit: int) -> Dictionary:
	var save := OUT.path_join("save.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	Progress.use(save)
	var rounds := []
	var purchases := []
	var levels := {}  # level -> {rounds, coins, cleared_on}: rounds played and coins earned there up to its first clear
	var done := false
	var last_progress := 0  # the last round that bought something or unlocked a level
	print("\ncampaign, skill %s, at most %d rounds" % [skill, limit])
	for i in limit:
		var level := Progress.unlocked
		var stats := Progress.snapshot()
		var layout := _fill(level, Progress.layout(level), stats)
		Progress.set_layout(level, layout)
		var r := _play(level, layout, stats, skill, i + 1)
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
			var pick: Upgrade = null
			for u in Progress.upgrades():
				if Progress.can_buy(u) and _offered(u.id) and (pick == null or Progress.cost(u) < Progress.cost(pick)):
					pick = u
			if pick == null:
				break
			var price := Progress.cost(pick)
			Progress.buy(pick)
			last_progress = i + 1
			purchases.append({"round": i + 1, "id": String(pick.id), "rank": Progress.rank(pick), "cost": price})
			print("round %d: bought %s rank %d for %d" % [i + 1, pick.id, Progress.rank(pick), price])
		if r.cleared and level == Progress.level_count:
			done = true
			break
	print("\n%-5s %-8s %-8s %s" % ["level", "rounds", "coins", "first clear on round"])
	for level: int in levels:
		print("%-5d %-8d %-8d %s" % [level, levels[level].rounds, levels[level].coins,
				levels[level].cleared_on if levels[level].cleared_on > 0 else "never"])
	var stuck := not done
	print("%s after %d rounds, %d purchases, %d coins left. Last progress on round %d." % [
			"Finished" if done else "STUCK on level %d" % Progress.unlocked, rounds.size(), purchases.size(),
			Progress.coins, last_progress])
	return {"skill": skill, "finished": done, "stuck": stuck, "rounds_played": rounds.size(),
			"last_progress": last_progress, "levels": levels, "purchases": purchases, "ranks": Progress.ranks,
			"coins_left": Progress.coins, "rounds": rounds}


## True if the hub offers this node: the seed node, or one next to an owned node.
func _offered(id: StringName) -> bool:
	if id == SEED_NODE:
		return true
	for edge: Array in WEB:
		if id in edge and Progress.ranks.get(StringName(edge[0] if edge[1] == id else edge[1]), 0) > 0:
			return true
	return false


## Is the bot itself sane? On the test board (level 0), where only a drop ends a round early: how often each
## skill drops the ball, against what a person of that skill would; and the same seed must give the same line.
## Fails the run (exit 1) if not.
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
