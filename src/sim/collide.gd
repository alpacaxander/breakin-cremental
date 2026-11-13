class_name Collide
## Swept collision for a ball (docs/design/physics.md, "Collision"). Only Round calls it; nothing outside the
## rules depends on its shape, so the rules lane may change this file's functions freely.
##
## What is fixed by the docs: the ball is a square of side ball.size; movement is swept, so no speed passes
## through a brick, a wall or the paddle; a brick hit resolves against exactly one of its edges, and a corner
## picks one edge.
##
## STUB: the rules lane writes it.


## The first thing `ball` touches while moving `distance` units along its dir, or null if nothing is in the way.
static func sweep(_round: Round, _ball: Ball, _distance: float) -> Hit:
	return null
