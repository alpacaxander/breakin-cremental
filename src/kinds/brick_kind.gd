class_name BrickKind
extends Kind
## A special brick: explosive, gold, hourglass, tough. When a round is built, stats.count(id) standard bricks are
## replaced by this kind (see Round, "Building"). What it does when it breaks is its on_broken hook.

## The HP a brick has once it becomes this kind, whatever it had before.
@export var hp := 1
## How many bricks it counts as when coins are calculated (gold: 20). See Coins.
@export var worth := 1
## Drawn with a ball-sized slate square in its middle: the ball it holds (the Ball Brick).
@export var mark := false
