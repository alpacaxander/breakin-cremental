extends PanelContainer
## The detail panel (docs/art.md, "Upgrade screen"): the selected node's category and state, name, rank, what a
## rank does, the next rank's price and Buy.
##
## Buy stays pressable when the coins don't cover it (Sfx.CANT_AFFORD, the CantAfford look). It is disabled only
## for a locked or maxed node. It is in Sfx.QUIET because its press has a cue of its own. Buying goes through
## Progress.buy; the hub redraws from Progress's signals.

const STATES := ["LOCKED", "AVAILABLE", "OWNED", "MAXED"]

var _node: HubNode

@onready var _buy: Button = %Buy


func _ready() -> void:
	_buy.add_to_group(Sfx.QUIET)
	_buy.pressed.connect(_on_buy)


## Shows `node` in `state`.
func show_node(node: HubNode, state: HubNode.State) -> void:
	_node = node
	var u := node.upgrade
	var open := state in [HubNode.State.AVAILABLE, HubNode.State.OWNED]
	var category: Label = %Category
	category.text = Upgrade.Category.keys()[u.category]
	UiTheme.light(category, Palette.of(u.meaning()))
	(%State as Label).text = STATES[state]
	(%Name as Label).text = u.title
	var pips: UiPips = %Pips
	pips.total = u.max_rank
	pips.owned = Progress.rank(u)
	pips.meaning = u.meaning()
	(%Rank as Label).text = "RANK %d/%d" % [Progress.rank(u), u.max_rank]
	(%Text as Label).text = u.text
	%Cost.visible = state != HubNode.State.MAXED
	var price: UiPrice = %Price
	price.amount = Progress.cost(u)
	price.dim = not (open and Progress.can_buy(u))
	_buy.disabled = not open
	var poor := open and not Progress.can_buy(u)
	_buy.theme_type_variation = &"CantAfford" if poor else &""
	_buy.text = "MAXED" if state == HubNode.State.MAXED else "LOCKED" if not open else "BUY"  # poor: the red outline and grey price say it ("CAN'T AFFORD" overflows the panel)


## Only an open node's Buy is enabled, and a disabled button never presses.
func _on_buy() -> void:
	if Progress.buy(_node.upgrade):
		Sfx.play(Sfx.BUY)
	else:
		Sfx.play(Sfx.CANT_AFFORD)
	# A click gives Buy a focus Godot does not draw, and the next Space or Enter (Start and Retry in a level) would
	# buy again unseen. Hand that focus back to the node; one a keyboard player brought here shows, and stays.
	if not _buy.has_focus(true):
		_node.grab_focus()
