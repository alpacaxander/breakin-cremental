extends PlaceableKind
## The Booster: the one round item. The ball bounces off the point where it touches and leaves faster.

## Added to Ball.boost on every hit: 0.25 is a quarter of the ball's base speed. The round caps the boost.
@export var boost := 0.0


func on_ball_hit(round: Round, ball: Ball, _hit: Hit) -> void:
	round.set_boost(ball, ball.boost + boost)
