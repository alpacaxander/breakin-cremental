extends Control
## The upgrade screen (docs/art.md, "Upgrade screen"; docs/design/upgrades.md): the top bar (the keys held and
## the coins), the web, the detail panel and the level panel.
##
## Everything on it is drawn from Progress: it redraws on coins_changed, rank_changed and level_unlocked, and
## whenever it is shown again. Play hides it with processing off while a level is open, so nothing here runs
## from _process. Esc and the back button go to the main menu.

const DRAG := 4.0  ## px a right press may move and still be a right click, not a pan

var selected: HubNode
var _right_at := Vector2.INF  # where the right button went down on a node; INF once it has moved off as a drag

@onready var _web: HubWeb = $Web
@onready var _detail: PanelContainer = $Detail
@onready var _levels: PanelContainer = $Levels


func _ready() -> void:
	($Bar as UiTopBar).back.pressed.connect(Main.show_menu)
	for n in _web.nodes():
		n.pressed.connect(select.bind(n))
		n.focus_entered.connect(select.bind(n))
		n.gui_input.connect(_node_input.bind(n))
	selected = _web.seed_node()
	Progress.coins_changed.connect(_refresh.unbind(1))
	Progress.rank_changed.connect(_refresh.unbind(1))
	Progress.level_unlocked.connect(_levels.pick)
	visibility_changed.connect(_shown)
	_shown()


## Shows `node` in the detail panel, and gives it the focus so the focus ring never sits on another node.
func select(node: HubNode) -> void:
	selected = node
	_refresh()
	if is_visible_in_tree():
		node.grab_focus()  # from focus_entered, it has it already and this does nothing


## Redraws, and gives the selected node the keyboard focus: a keyboard player arrives here by Esc in Setup
## or Enter on the Summary's Upgrades, and Godot moves focus only from a control that has it.
func _shown() -> void:
	if _web.state(selected) == HubNode.State.LOCKED:  # hidden: the save was reset under it
		selected = _web.seed_node()
	select(selected)


## A double click on a node buys it, as Buy would. A right click selects it and undoes it, as Undo would. A drag
## with any button pans the web, so a right click counts on the release, and only if the pointer has stayed
## within DRAG of the press all along (the press goes to this node, and so do the moves and the release after it).
func _node_input(event: InputEvent, node: HubNode) -> void:
	var b := event as InputEventMouseButton
	if event is InputEventMouseMotion and event.global_position.distance_to(_right_at) > DRAG:
		_right_at = Vector2.INF
	elif b and b.pressed and b.double_click and b.button_index == MOUSE_BUTTON_LEFT:
		select(node)
		_detail.buy()
	elif b and b.button_index == MOUSE_BUTTON_RIGHT:
		if b.pressed:
			_right_at = b.global_position
		elif b.global_position.distance_to(_right_at) <= DRAG:
			select(node)
			_detail.undo()


func _refresh() -> void:
	($Bar/Coins as UiPrice).amount = Progress.coins
	var keys: UiPrice = $Bar/Keys
	keys.amount = Progress.keys()
	keys.dim = keys.amount <= 0
	_web.refresh(selected)
	_detail.show_node(selected, _web.state(selected), _web.can_undo(selected))
	_levels.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		Main.show_menu()
