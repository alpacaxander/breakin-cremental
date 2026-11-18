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
## The sum before the floor is the round's score (points()); a clear needs it to reach Round.target.


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


## The round's score in points: the bricks, the hits that broke nothing and the combos' bonuses.
static func points(tally: Tally, _stats: Balance) -> int:
	var sum := tally.dents
	for id: StringName in tally.broken:
		sum += tally.broken[id] * worth(id)
	for run in tally.combos:
		sum += bonus(run)
	return sum


static func total(tally: Tally, stats: Balance) -> int:
	return pay(points(tally, stats), stats)

