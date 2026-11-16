class_name Coins
## The coin formula: one function that turns a tally into coins. Nothing else decides what a round pays.
##
## The formula is an open question (docs/design/overview.md, "Coins"). The placeholder: each brick pays its
## worth (1, a gold brick 20), and a combo multiplies the worth of every brick broken in it by the multiplier it
## reached. Written against the tally:
##
##     floor(stats.coins_per_brick * (sum over kind ids k of tally.broken[k] * worth(k)
##                                    + sum over combos c of c.worth * (c.multiplier - 1)))
##
## So the bricks pay once at x1 and each combo adds its bonus on top; the Summary shows the two apart.


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


static func total(tally: Tally, stats: Balance) -> int:
	var sum := 0
	for id: StringName in tally.broken:
		sum += tally.broken[id] * worth(id)
	for run in tally.combos:
		sum += bonus(run)
	return pay(sum, stats)
