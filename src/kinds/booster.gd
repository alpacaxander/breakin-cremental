extends PlaceableKind
## The Booster: the one round item. The ball bounces off the point where it touches and leaves faster.

## Added to Ball.boost on every hit, before stats.booster_speed: 0.2 is a fifth of the ball's base speed (100 units/s at 500). The
## round caps the boost. Unlike other boosts it is also added to Ball.kept, so the paddle does not take it away.
@export var boost := 0.0


func on_ball_hit(round: Round, ball: Ball, _hit: Hit) -> void:
	var add := boost + round.stats.booster_speed
	round.set_boost(ball, ball.boost + add)
	ball.kept = clampf(ball.kept + add, 1.0, maxf(round.stats.boost_cap, 1.0))
