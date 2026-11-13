class_name Paddle
extends RefCounted
## The paddle. It sits in the paddle lane, moves only along y, and stays inside the top and bottom walls.
## The round moves it toward the target passed to Round.step at stats.paddle_speed.

## The centre along y, in round units. Kept between length / 2 and board.size().y - length / 2.
var y: float
## The face: the edge toward the board, where the cyan stripe is. Fixed for the round at
## -board.lane() + stats.paddle_inset + stats.paddle_thickness.
var x: float
## Its length along y (stats.paddle_size).
var length: float
## Its size along x (stats.paddle_thickness). The body runs from x - thickness to x.
var thickness: float


## The paddle's rectangle, in units.
func rect() -> Rect2:
	return Rect2(x - thickness, y - length * 0.5, thickness, length)
