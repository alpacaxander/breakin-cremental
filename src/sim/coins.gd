class_name Coins
## The coin formula: one function that turns a tally into coins. Nothing else decides what a round pays.
##
## The formula is an open question (docs/design/overview.md, "Coins"). The placeholder: each brick pays 1 coin
## times the combo multiplier it broke at, and a gold brick counts as 5 bricks. Written against the tally:
##
##     floor(stats.coins_per_brick * sum over kind ids k of tally.points[k] * worth(k))
##
## where worth(&"") is 1 and worth(k) is the BrickKind's `worth` (gold: 5).
##
## STUB: the rules lane writes it.


static func total(_tally: Tally, _stats: Balance) -> int:
	return 0
