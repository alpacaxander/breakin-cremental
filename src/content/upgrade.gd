class_name Upgrade
extends Resource
## One node of the upgrade web. Each is a .tres in data/upgrades/, and its file name is its id. It changes one
## stat (see Progress.stat). Where the node sits and what it connects to is in the hub's web scene, not here.
## The demo's fifteen are listed in docs/design/upgrades.md.

enum Category { ARENA, PLACEABLES, BRICKS }

## The file name: data/upgrades/<id>.tres gives &"<id>". The save stores ranks by it. An upgrade made in code,
## in a test, has no file and sets its id by hand.
var id: StringName:
	get:
		return id if id else StringName(resource_path.get_file().get_basename())
## The name on the node: "Paddle Speed".
@export var title: String
@export var category: Category
## What one rank does, for the detail panel: "+20% paddle speed", "One more Bumper".
@export_multiline var text: String
## The price of rank 1.
@export var first_cost: int
## Each rank costs this many times the one before.
@export var growth := 1.8
## The number of ranks it has.
@export var max_rank := 1
## The stat it changes: a Balance property (&"paddle_speed") or a count (&"bumper_count").
@export var stat: StringName
## What each rank adds to the stat.
@export var amount: float
## If true, `amount` is a share of the stat's base value: 0.2 adds 20% of the base per rank.
@export var percent: bool


## The price of the next rank for someone who owns `owned` ranks: first_cost * growth ^ owned, rounded to a whole
## coin. Explosive Brick (8, 3.5) costs 8, 28, 98, 343.
func cost(owned: int) -> int:
	return roundi(first_cost * pow(growth, owned))


## The Palette meaning of its category: Palette.of(upgrade.meaning()) is the node's lit colour.
func meaning() -> StringName:
	return [&"player", &"placeable", &"bricks"][category]
