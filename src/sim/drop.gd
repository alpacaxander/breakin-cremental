class_name Drop
extends RefCounted
## A power-up on its way to the paddle: the square a Power Brick leaves when it breaks (Round.drop). The round
## moves it; views read it every frame. See Round, CHARGES.

## Unique within its round, counted up from 0 in the order drops are made. Views key on it.
var id: int
## The centre, in round units.
var pos: Vector2
## The side of its square, in units (Balance.drop_size).
var size: float


## Its square, in units.
func rect() -> Rect2:
	return Rect2(pos - Vector2.ONE * size * 0.5, Vector2.ONE * size)
