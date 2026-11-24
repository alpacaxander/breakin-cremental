class_name Paddle
extends RefCounted
## The paddle. It sits in the paddle lane, moves only along y, and its centre stays inside the top and bottom walls.
## The round moves it toward the target passed to Round.step at stats.paddle_speed.

## The centre along y, in round units. Kept between 0 and board.size().y, so half of it can go past a wall.
var y: float
## The face: the edge toward the board, where the cyan stripe is. Fixed for the round at
## -board.lane() + stats.paddle_inset + stats.paddle_thickness.
var x: float
## Its length along y (stats.paddle_size).
var length: float
## Its size along x (stats.paddle_thickness). The body runs from x - thickness to x.
var thickness: float


## The part of the paddle between the top and bottom walls (0 to `height`), in units: half of it can be past a
## wall, and only this part is solid. Where a ball lands on it (the bounce angle) still counts from y and length.
func rect(height: float) -> Rect2:
	var top := maxf(y - length * 0.5, 0.0)
	return Rect2(x - thickness, top, thickness, minf(y + length * 0.5, height) - top)
