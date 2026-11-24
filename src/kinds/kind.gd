class_name Kind
extends Resource
## What a special brick, a placeable or an ability is. The base of BrickKind, PlaceableKind and AbilityKind.
##
## Adding a kind is adding two files, or one: a script in src/kinds/ that extends BrickKind, PlaceableKind or
## AbilityKind and overrides the hooks it needs, and a .tres in data/kinds/ that uses that script and holds its
## numbers. A kind with no hook (the tough brick) needs no script: its .tres uses BrickKind's own. Kinds finds it
## by its file.
## Nothing else names it: the round only calls hooks, the views draw from the fields here, and Sfx plays `cue`.
## Its count comes from the stat `<id>_count`, which its upgrade raises.
##
## A kind is fixed data. It holds no state of a round (a placed brick's own Brick can), and a hook changes the
## round only through the round's functions (hit_brick, blast, zap, grow, restore, add_ball, add_charge, drop,
## set_boost, add_time), so what it sets off needs no special case.

## The file name: data/kinds/<id>.tres gives &"<id>". Saves, Brick.kind, Ball.charge and the count stat all use
## it. A kind made in code, in a test, has no file and sets its id by hand before Kinds.add.
var id: StringName:
	get:
		return id if id else StringName(resource_path.get_file().get_basename())
## The name shown to the player: "Wall Segment".
@export var title: String
## A Palette meaning (Palette.MEANINGS): &"placeable" for every placeable, &"ability", &"coins", &"time". &"" for
## a brick kind drawn in the HP steps like a plain brick (the tough brick); Palette.brick and Palette.kind see to it.
## Otherwise screens draw the kind in Palette.of(colour).
@export var colour: StringName
## The cue Sfx plays when this kind acts: for a free-form item when a ball bounces off it, for a brick when it
## breaks, for a placed block when it acts (Refresh: `restored`). A file name in
## assets/audio/wav without the extension, &"" for none. Leave it empty when the effect has a round signal of its
## own that Sfx gives a sound (the Splitter: `ball_added`; the Zap: `zapped`).
@export var cue: StringName
## Where it comes in lists (the tray, the legend, the special-brick roll): lowest first, ties by id.
@export var order: int


## A ball touched this placed item (FREE placeables only). The round has already bounced the ball, so ball.dir
## is its new direction; ball_bounced is emitted after this returns. A gate (the Booster) is not bounced off: this
## runs as the ball crosses its middle line, hit.normal points back along the ball's way and dir is unchanged. The
## Booster raises the ball's boost here.
func on_ball_hit(_round: Round, _ball: Ball, _hit: Hit) -> void:
	pass


## A brick of this kind took a hit and still stands (hp left, brick_hit already emitted). Same arguments as
## on_broken. The Splitter splits the ball here.
func on_hit(_round: Round, _cell: Vector2i, _brick: Brick, _cause: Round.Cause, _dir: Vector2, _ball: Ball) -> void:
	pass


## A brick of this kind broke: a special brick, or a placed brick such as the Splitter. `brick` is the brick,
## already off the board. `dir` is the hit's direction from Round.hit_brick: for a ball, the way it was moving
## before it bounced. `ball` is the ball that broke it, or null when the cause is not Round.Cause.BALL.
## Called after brick_broken is emitted. The Power Brick makes a drop here.
func on_broken(_round: Round, _cell: Vector2i, _brick: Brick, _cause: Round.Cause, _dir: Vector2, _ball: Ball) -> void:
	pass


## Every step of play, for each placed brick of this kind still on the board (BRICK placeables) and for each AREA
## item of this kind (`brick` null), in layout order, after the balls have moved and round.clock has gone up by
## `delta`. Not called while the ball is held. Growth pulses here.
func on_step(_round: Round, _cell: Vector2i, _brick: Brick, _delta: float) -> void:
	pass
