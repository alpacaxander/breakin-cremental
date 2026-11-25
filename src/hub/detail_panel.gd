extends PanelContainer
## The detail panel (docs/art.md, "Upgrade screen"): the selected node's category and state, name, what a copy
## does, a note on what buying it takes, the price (coins, or 1 KEY for a key node) and Buy.
##
## Buy stays pressable when the coins or keys don't cover it (Sfx.CANT_AFFORD, the CantAfford look). It is
## disabled for a preview (LOCKED) and for an owned node (OWNED); a locked node is hidden on the web, so it is
## never shown here. It is in Sfx.QUIET because its press has a cue of its own. Buying goes through Progress.buy
## with the node's name; the hub redraws from Progress's signals.

var _node: HubNode

@onready var _buy: Button = %Buy


func _ready() -> void:
	_buy.add_to_group(Sfx.QUIET)
	_buy.pressed.connect(_on_buy)


## Shows `node` in `state`.
func show_node(node: HubNode, state: HubNode.State) -> void:
	_node = node
	var u := node.upgrade
	var open := state == HubNode.State.AVAILABLE
	var owned := state == HubNode.State.OWNED
	var category: Label = %Category
	category.text = Upgrade.Category.keys()[u.category]
	UiTheme.light(category, Palette.of(u.meaning()))
	(%State as Label).text = HubNode.State.keys()[state]
	(%Name as Label).text = u.title
	(%Text as Label).text = u.text
	var got := Progress.rank(u)
	# ponytail: an owned node's note is empty until undo (the redesign's step 4) says what undoing it gives back.
	(%Note as Label).text = "" if owned else "COSTS 1 KEY, NO COINS" if u.key else "BUY A NODE NEXT TO IT FIRST" if not open \
			else "YOU OWN %d. EACH ONE RAISES THE REST" % got if got else "NONE OWNED YET"
	%Cost.visible = not owned
	var price: UiPrice = %Price
	price.key = u.key
	price.amount = Progress.cost(u)
	if u.key:
		price.text = "1 KEY"
	price.dim = not (open and Progress.can_buy(u))
	_buy.disabled = not open
	_buy.theme_type_variation = &"CantAfford" if open and not Progress.can_buy(u) else &""
	# Short of coins or a key, the red outline and grey price say it ("CAN'T AFFORD" overflows the panel).
	_buy.text = "BUY" if open else "OWNED" if owned else "LOCKED"


## Buy, for a double click on a node: does what pressing it does, and nothing on an owned node or a preview.
func buy() -> void:
	if not _buy.disabled:
		_on_buy()


## Only an open node's Buy is enabled, and a disabled button never presses.
func _on_buy() -> void:
	if Progress.buy(_node.upgrade, _node.name):
		Sfx.play(Sfx.BUY)
	else:
		Sfx.play(Sfx.CANT_AFFORD)
	# A click gives Buy a focus Godot does not draw, and the next Space or Enter (Start and Retry in a level) would
	# buy again unseen. Hand that focus back to the node; one a keyboard player brought here shows, and stays.
	if not _buy.has_focus(true):
		_node.grab_focus()
