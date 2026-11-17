class_name Coins
## The coin formula: one function that turns a tally into coins. Nothing else decides what a round pays.
##
## The formula is an open question (docs/design/overview.md, "Coins"). The placeholder: every hit on a level
## brick scores 1 point and the hit that breaks it scores its worth instead (1, a gold brick 20), and a combo
## multiplies every point scored while it ran by the multiplier it reached. Written against the tally:
##
##     floor(stats.coins_per_brick * (sum over kind ids k of tally.broken[k] * worth(k) + tally.dents
##                                    + sum over combos c of c.worth * (c.multiplier - 1)))
##
## So the bricks and hits pay once at x1 and each combo adds its bonus on top; the Summary shows them apart.
## The bonuses (bonuses()) are added inside the same floor, in points too. The sum before the floor is the
## round's score (points()); a clear needs the score before the end bonuses to reach Round.target.


## What a brick of kind `id` counts as: 1, or its BrickKind's `worth` (gold: 20, in data/kinds/gold.tres).
static func worth(id: StringName) -> int:
	var kind := Kinds.of(id) as BrickKind
	return kind.worth if kind else 1


## Coins for `points` bricks' worth: floor(stats.coins_per_brick * points).
static func pay(points: int, stats: Balance) -> int:
	return floori(stats.coins_per_brick * points)


## What a combo adds on top of its bricks: their worth times its multiplier above 1.
static func bonus(run: Tally.Run) -> int:
	return run.worth * (run.multiplier - 1)


## The bonuses the tally has earned, each [id, count, points], in the Summary's order. Only those that pay:
##   chain        the biggest explosion chain: chain_bonus points per level brick in it
##   rally        the longest rally: rally_bonus points per level brick broken between two paddle touches
##   clear        a clear: clear_bonus times the level's target
##   time         every level brick broken: time_bonus points per whole second left
##   first_clear  a level's first clear: first_clear_bonus times the level's target
##   kept         the round ended with a ball in play (every brick broken, or the timer): kept_bonus
##   efficiency   once the round is over: the bricks and everything above, times a share that grows from 0 at
##                efficiency_from bricks per paddle touch (per_touch()) to efficiency_bonus at efficiency_to
static func bonuses(tally: Tally, stats: Balance) -> Array[Array]:
	var all: Array[Array] = [
		[&"chain", tally.best_chain, floori(stats.chain_bonus * tally.best_chain)],
		[&"rally", tally.best_rally, floori(stats.rally_bonus * tally.best_rally)],
		[&"clear", 0, floori(stats.clear_bonus * tally.target) if tally.cleared else 0],
		[&"time", tally.seconds_left, floori(stats.time_bonus * tally.seconds_left)],
		[&"first_clear", 0, floori(stats.first_clear_bonus * tally.target) if tally.first_clear else 0],
		[&"kept", 0, floori(stats.kept_bonus) if tally.kept else 0],
	]
	if tally.ended:
		var sum := _bricks(tally)
		for b in all:
			sum += b[2]
		var share := clampf(inverse_lerp(stats.efficiency_from, stats.efficiency_to, per_touch(tally)), 0.0, 1.0) * stats.efficiency_bonus
		all.append([&"efficiency", 0, floori(sum * share)])
	return all.filter(func(b: Array) -> bool: return b[2] > 0)


## Level bricks broken per paddle touch, the launch counted as one.
static func per_touch(tally: Tally) -> float:
	var bricks := 0
	for n: int in tally.broken.values():
		bricks += n
	return float(bricks) / maxi(tally.paddle_touches, 1)


## The round's score: the bricks, the combos and the bonuses, in points.
static func points(tally: Tally, stats: Balance) -> int:
	var sum := _bricks(tally)
	for b in bonuses(tally, stats):
		sum += b[2]
	return sum


static func total(tally: Tally, stats: Balance) -> int:
	return pay(points(tally, stats), stats)


# The bricks' worth, the hits that broke nothing and the combos' bonuses.
static func _bricks(tally: Tally) -> int:
	var sum := tally.dents
	for id: StringName in tally.broken:
		sum += tally.broken[id] * worth(id)
	for run in tally.combos:
		sum += bonus(run)
	return sum
