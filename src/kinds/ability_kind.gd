class_name AbilityKind
extends Kind
## An ability: what a charge does. A charge is a ball fired from the paddle with the selected ability
## (Round.ability) in Ball.charge; its first hit on a level brick spends it and calls `fire` at that brick. An
## ability is unlocked when stats.count(id) is 1 or more, which its upgrade raises.


## The charged ball's first hit on a level brick, at `cell`. The ball's hit has already landed, so the brick may
## be gone. `dir` is the way the ball was moving before it bounced.
func fire(_round: Round, _cell: Vector2i, _dir: Vector2, _ball: Ball) -> void:
	pass
