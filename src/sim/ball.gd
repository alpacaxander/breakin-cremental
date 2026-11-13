class_name Ball
extends RefCounted
## One ball in a round. The round moves it; views read it every frame.

## Unique within its round, counted up from 0 in the order balls are made. Views key on it.
var id: int
## The centre, in round units.
var pos: Vector2
## The direction of travel, a unit vector. A bounce changes this and nothing else.
var dir: Vector2
## The side of its square, in units (Balance.ball_size).
var size: float
## Speed as a multiple of the base speed: 1 is no boost. The ball's speed is always stats.ball_speed * boost
## (see Round.speed_of). A Booster and a Shockwave raise it through Round.set_boost, which caps it at
## stats.boost_cap. It drops back to 1 when the ball next touches the paddle.
var boost := 1.0


## The ball's square, in units.
func rect() -> Rect2:
	return Rect2(pos - Vector2.ONE * size * 0.5, Vector2.ONE * size)
