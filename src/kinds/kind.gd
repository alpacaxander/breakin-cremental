class_name Kind
extends Resource
## What a special brick or a placeable is. The base of BrickKind and PlaceableKind.
##
## Adding a kind is adding two files: a script in src/kinds/ that extends BrickKind or PlaceableKind and
## overrides the hooks it needs, and a .tres in data/kinds/ that uses that script and holds its numbers. Kinds
## finds it by its file. Nothing else names it: the round only calls hooks, the views draw from the fields here,
## and Sfx plays `cue`. Its count comes from the stat `<id>_count`, which its upgrade raises.
##
## A kind is fixed data. It holds no state of a round, and a hook changes the round only through the round's own
## functions (hit_brick, blast, add_ball, set_boost, add_time), so chains work without special cases.

## The file name: data/kinds/<id>.tres gives &"<id>". Saves, Brick.kind, Brick.mod and the count stat all use
## it. A kind made in code, in a test, has no file and sets its id by hand before Kinds.add.
var id: StringName:
	get:
		return id if id else StringName(resource_path.get_file().get_basename())
## The name shown to the player: "Wall Segment".
@export var title: String
## A Palette meaning (Palette.MEANINGS): &"placeable" for every placeable, &"explosive", &"coins", &"time".
## Screens draw the kind in Palette.of(colour).
@export var colour: StringName
## The cue Sfx plays when this kind acts: for a free-form item when a ball bounces off it, for a brick or a mod
## when its brick breaks. A file name in assets/audio/wav without the extension, &"" for none. Leave it empty
## when the effect has a round signal of its own (the explosive brick: `exploded`).
@export var cue: StringName
## Where it comes in lists (the tray, the legend, the special-brick roll): lowest first, ties by id.
@export var order: int


## A ball touched this placed item (FREE placeables only). The round has already bounced the ball, so ball.dir
## is its new direction; ball_bounced is emitted after this returns. The Booster raises the ball's boost here.
func on_ball_hit(_round: Round, _ball: Ball, _hit: Hit) -> void:
	pass


## A brick of this kind broke: a special brick, or a placed brick such as the Splitter. `brick` is the brick,
## already off the board. `ball` is the ball that broke it, or null when the cause is not Round.Cause.BALL.
## Called after brick_broken is emitted. The explosive brick calls round.blast here; the Splitter adds a ball.
func on_broken(_round: Round, _cell: Vector2i, _brick: Brick, _cause: Round.Cause, _ball: Ball) -> void:
	pass


## A brick carrying this mod broke (MOD placeables only). Same arguments as on_broken, and called after it.
## Zap hits every other brick in the row here, with Round.Cause.ZAP.
func on_host_broken(_round: Round, _cell: Vector2i, _brick: Brick, _cause: Round.Cause, _ball: Ball) -> void:
	pass
