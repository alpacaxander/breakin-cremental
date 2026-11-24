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
## stats.boost_cap. When the ball next touches the paddle it drops back to `kept`.
var boost := 1.0
## The part of the boost a Booster gave, which the paddle leaves alone (1: none). Capped like boost.
var kept := 1.0
## The ability this ball carries (an AbilityKind's id), &"" for none. A charge leaves the paddle with
## Round.ability; its first hit on a level brick spends it (Round, ONE BOUNCE).
var charge: StringName = &""
## Rules only: the straight line the ball is on. It began at `from` and the ball is `gone` units along it, so
## pos is always from + dir * gone. The sweep measures every contact from `from`, never from pos, so where a
## ball bounces next does not depend on how the time was cut into steps.
var from: Vector2
var gone := 0.0
## Rules only: true when the minimum angles have turned this ball straight back along the line it came on, so
## the next time they would, it goes to the other side (Round, ONE BOUNCE).
var back := false


## Puts the ball at a point, heading along a unit vector, and starts its line there. The round aims a ball with
## this after every bounce. Setting pos or dir by hand also works: the round sees it on the ball's next move.
func put(p_pos: Vector2, p_dir: Vector2) -> void:
	pos = p_pos
	dir = p_dir
	from = p_pos
	gone = 0.0


## The ball's square, in units.
func rect() -> Rect2:
	return Rect2(pos - Vector2.ONE * size * 0.5, Vector2.ONE * size)
