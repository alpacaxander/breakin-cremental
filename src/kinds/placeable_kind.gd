class_name PlaceableKind
extends Kind
## An item the player places during Setup. The player may place stats.count(id) of it.
## The three placements are docs/design/placeables.md's three kinds; Layout.fits holds their rules.

enum Placement {
	FREE,  ## Anywhere in the grid area, not snapped. A rectangle the ball bounces off, or passes through (`gate`). Uses size, turn
	BRICK,  ## Snaps to an empty brick cell and becomes a brick of this kind there, with `hp`
	MOD,  ## Goes on a brick that is already there and sets Brick.mod. Drawn as a mark of `size` at the brick's centre
}

@export var placement: Placement
## In round units. FREE: the rectangle's width by height before it is turned. MOD: the mark's size. BRICK: unused,
## it fills its brick cell.
@export var size: Vector2
## FREE only: degrees the rectangle is always turned by, clockwise on screen. The Bumper is 30 x 30 with turn 45.
@export var turn: float
## FREE only: true if the player may rotate it. Its Layout.Item.rot is then added to `turn`.
@export var rotatable: bool
## FREE only: the ball passes through it instead of bouncing, and on_ball_hit runs as it crosses its long centre line.
@export var gate := false
## BRICK only: the placed brick's HP.
@export var hp := 1
## BRICK only: true for a block that never breaks (Growth). The ball bounces off it as off a brick, and a hit
## from a ball, a blast or a Zap takes no HP: it counts in the tally's `hits`, emits brick_hit and calls on_hit.
## It cannot carry a mod, which would never go off (Layout.fits).
@export var unbreakable := false
## Unbreakable only: the block is drawn as a frame round this many base-colour panes, stacked, so blocks that do
## different things look different (Growth 1, Refresh 2).
@export var panes := 1
