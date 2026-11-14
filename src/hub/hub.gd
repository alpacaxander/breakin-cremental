extends Control
## The upgrade screen (docs/art.md, "Upgrade screen"; docs/design/upgrades.md): the top bar, the web, the detail
## panel and the level panel.
##
## Everything on it is drawn from Progress: it redraws on coins_changed, rank_changed and level_unlocked, and
## whenever it is shown again. Play hides it with processing off while a level is open, so nothing here runs
## from _process. Esc and the back button go to the main menu.

var selected: HubNode

@onready var _web: HubWeb = $Web
@onready var _detail: PanelContainer = $Detail
@onready var _levels: PanelContainer = $Levels


func _ready() -> void:
	($Bar as UiTopBar).back.pressed.connect(Main.show_menu)
	for n in _web.nodes():
		n.pressed.connect(select.bind(n))
		n.focus_entered.connect(select.bind(n))
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


## Redraws, and gives the selected node the keyboard focus: a keyboard player arrives here by Enter on the
## menu's Play or the Summary's Upgrades, and Godot moves focus only from a control that has it.
func _shown() -> void:
	select(selected)


func _refresh() -> void:
	($Bar/Coins as UiPrice).amount = Progress.coins
	_web.refresh(selected)
	_detail.show_node(selected, _web.state(selected))
	_levels.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		Main.show_menu()
