extends PanelContainer
## The detail panel (docs/art.md, "Upgrade screen"): the selected node's category and state, name, what a copy
## does, a note on what buying or undoing it takes, the price (coins, or 1 KEY for a key node) or, on an owned
## node, the refund, and the button: Buy, or Undo on an owned node.
##
## Buy stays pressable when the coins or keys don't cover it (Sfx.CANT_AFFORD, the CantAfford look). It is
## disabled for a preview (LOCKED); a locked node is hidden on the web, so it is never shown here. On an owned node
## it is UNDO (SecondaryButton) when HubWeb.can_undo allows it, and disabled and IN USE when it doesn't. It is in
## Sfx.QUIET because its press has a cue of its own: BUY or CANT_AFFORD, and PLACE_ITEM for an undo (a falling
## thunk where buy rises). Buying and undoing go through Progress with the node's name; the hub redraws from
## Progress's signals.

var _node: HubNode
var _state: HubNode.State
var _undoable := false

@onready var _buy: Button = %Buy


func _ready() -> void:
	_buy.add_to_group(Sfx.QUIET)
	_buy.pressed.connect(_on_press)


## Shows `node` in `state`. `undoable` is HubWeb.can_undo(node), read only when the node is owned.
func show_node(node: HubNode, state: HubNode.State, undoable := false) -> void:
	_node = node
	_state = state
	_undoable = undoable
	_buy.focus_previous = _buy.get_path_to(node)  # Shift+Tab goes back to the node, as Tab on it came here
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
	var note := "COSTS 1 KEY, NO COINS" if u.key else "BUY A NODE NEXT TO IT FIRST" if not open \
			else "YOU OWN %d. EACH ONE RAISES THE REST" % got if got else "NONE OWNED YET"
	if owned:
		note = "UNDO WHAT HANGS OFF IT FIRST" if not undoable else "UNDO GIVES THE KEY BACK" if u.key else "UNDO REFUNDS THE LAST PRICE PAID"
	(%Note as Label).text = note
	(%PriceTag as Label).text = "REFUND" if owned else "PRICE"
	var price: UiPrice = %Price
	price.key = u.key
	price.amount = u.cost(got - 1) if owned else Progress.cost(u)
	if u.key:
		price.text = "1 KEY"
	price.dim = not (owned or open and Progress.can_buy(u))
	_buy.disabled = not open and not (owned and undoable)
	_buy.theme_type_variation = &"SecondaryButton" if owned else &"CantAfford" if open and not Progress.can_buy(u) else &""
	# Short of coins or a key, the red outline and grey price say it ("CAN'T AFFORD" overflows the panel).
	_buy.text = "BUY" if open else ("UNDO" if undoable else "IN USE") if owned else "LOCKED"


## Buy, for a double click on a node: does what pressing it does, and nothing on an owned node or a preview.
func buy() -> void:
	if _state == HubNode.State.AVAILABLE:
		_on_press()


## Undo, for a right click on a node: does what pressing Undo does, plays can't afford on a node in use, and does
## nothing on a node not owned.
func undo() -> void:
	if _state == HubNode.State.OWNED:
		_on_press()


## Only an open or undoable node's button is enabled, and a disabled button never presses.
func _on_press() -> void:
	if _state == HubNode.State.OWNED:
		Sfx.play(Sfx.PLACE_ITEM if _undoable and Progress.undo(_node.upgrade, _node.name) else Sfx.CANT_AFFORD)
	elif Progress.buy(_node.upgrade, _node.name):
		Sfx.play(Sfx.BUY)
	else:
		Sfx.play(Sfx.CANT_AFFORD)
	# Hand the focus back to the node, which now shows it. Left here, the next Space or Enter would press the button
	# again, and the button has just turned from BUY to UNDO or back: a click's focus, which Godot does not draw,
	# would press it unseen (Space is Start and Retry in a level), and a second Enter would undo what the first
	# bought. Tab from the node comes back here (hub.gd sets it).
	_node.grab_focus()
