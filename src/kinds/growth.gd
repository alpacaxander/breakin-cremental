extends PlaceableKind
## Growth: an area (Placement.AREA) on a brick cell, reaching stats.growth_reach squares out from the cell's
## edges. It pulses stats.growth_pulses times at the start of a round: the first `delay` seconds of play in, then
## one every `gap`. Each pulse gives every level brick in the area 1 HP, up to stats.max_hp (Round.grow).

## Seconds of play (Round.clock) before the first pulse.
@export var delay := 0.0
## Seconds between pulses.
@export var gap := 0.0


func area(board: Board, cell: Vector2i, stats: Balance) -> Rect2:
	return board.cell_rect(cell).grow(stats.growth_reach * Board.BRICK.y)


## A pulse for each one whose time round.clock passed in this step. Less than Round.TIME_SLOP short of one counts
## as on it, as the timer does.
func on_step(round: Round, cell: Vector2i, _brick: Brick, delta: float) -> void:
	for i in int(round.stats.growth_pulses):
		var at := delay + gap * i - Round.TIME_SLOP
		if round.clock - delta < at and at <= round.clock:
			round.grow(cell, round.stats.growth_reach * Board.BRICK.y)
