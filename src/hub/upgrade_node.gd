@tool
class_name HubNode
extends Button
## One node of the upgrade web (docs/art.md, "Upgrade screen"): a flat box in its category's colour with the
## upgrade's name, a pip per copy of the upgrade owned and, until it is bought, the next copy's price. web.tscn
## places one per purchase: an upgrade has max_rank nodes, its copies, which share its price ladder (buying any
## copy raises the others' price). See web.gd for how to add one.
##
## It only shows what it is told: HubWeb works out its state from Progress and the web's links and calls show_state.
## In the editor (this is a @tool script so the web can be laid out by eye) it shows its node name and the
## available look in the text colour, and never reads Progress.

enum State { LOCKED, AVAILABLE, OWNED }

const PITCH := Vector2(170, 116)  ## art.md: one grid step, centre to centre
const ORIGIN := Vector2(432, 304)  ## The centre of cell (0, 0), the seed's, in the web view: the view's centre
const SIZE := Vector2(148, 60)
const SEED_SIZE := Vector2(168, 72)
const DASH := 6.0

## The upgrade this node sells: a .tres from data/upgrades/.
@export var upgrade: Upgrade:
	set(v):
		upgrade = v
		_place()
## Where it sits on the web's grid: column, row. (0, 0) is the seed's, at the centre of the view.
@export var cell := Vector2i.ZERO:
	set(v):
		cell = v
		_place()
## The seed is open from the start and drawn larger. The web has one.
@export var is_seed := false:
	set(v):
		is_seed = v
		_place()
## The nodes this one is connected to. A link is listed on either end, once; the web draws each as a line.
@export var links: Array[NodePath] = []

var state := State.AVAILABLE
## The web view's zoom, which HubWeb also sets as this node's scale: a pulse swells from it and settles back to it.
var zoom := 1.0
## Drawn with the selection outline.
var selected := false:
	set(v):
		selected = v
		queue_redraw()


func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = MOUSE_FILTER_PASS  # the wheel and drags over a node go on to the web, which pans and zooms
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	_place()
	if not Engine.is_editor_hint():  # this node was just bought: it swells for a moment
		Progress.rank_changed.connect(func(u: Upgrade) -> void:
			if u == upgrade and Progress.owned and Progress.owned.back() == name:
				UiTheme.pulse(self, 0.5, UiTheme.PULSE, zoom))


## Shows the node in `s`. `affordable` lights the price gold.
func show_state(s: State, affordable: bool) -> void:
	state = s
	var u := upgrade
	accessibility_name = "%s, %s, %d owned" % [u.title, State.keys()[s].to_lower(), Progress.rank(u)]
	var pips: UiPips = $Bottom/Pips
	pips.total = Progress.rank(u)
	pips.owned = Progress.rank(u)
	pips.meaning = u.meaning()
	var price: UiPrice = $Bottom/Price
	price.visible = s != State.OWNED
	price.amount = Progress.cost(u)
	price.dim = not affordable
	queue_redraw()


## Where the node sits in web.tscn's layout: at zoom 1 with no pan.
func home() -> Rect2:
	return Rect2(ORIGIN + Vector2(cell) * PITCH - size / 2, size)


func _place() -> void:
	size = SEED_SIZE if is_seed else SIZE
	pivot_offset = size / 2
	position = home().position
	if is_node_ready():
		($Name as Label).theme_type_variation = &"Name" if is_seed else &"SmallName"
		($Name as Label).text = String(name) if Engine.is_editor_hint() or upgrade == null else upgrade.title


func _draw() -> void:
	var editor := Engine.is_editor_hint() or upgrade == null
	var hue := Palette.TEXT if editor else Palette.of(upgrade.meaning())
	var r := Rect2(Vector2.ZERO, size)
	var edge := Rect2(Vector2.ONE, size - Vector2(2, 2))  # a 2 px stroke centred 1 px in, so it stays inside the box
	match state:
		State.OWNED:
			draw_rect(r, Palette.dim(upgrade.meaning()))
			draw_rect(edge, Palette.lit(hue), false, 2)
		State.AVAILABLE:
			draw_rect(r, Palette.BASE)
			var c := hue if editor else Palette.lit(hue)
			var p := [edge.position, Vector2(edge.end.x, edge.position.y), edge.end, Vector2(edge.position.x, edge.end.y)]
			for i in 4:
				draw_dashed_line(p[i], p[(i + 1) % 4], c, 2, DASH)
		# LOCKED draws nothing: the web hides a locked node.
	if selected:
		# Over the theme's focus ring (2 px, 4 px out), so a focused, selected node shows one cyan ring.
		draw_rect(Rect2(-Vector2(3, 3), size + Vector2(6, 6)), Palette.lit(Palette.PLAYER, Palette.LIT_TEXT), false, 2)
	elif is_hovered():
		draw_rect(Rect2(-Vector2(3, 3), size + Vector2(6, 6)), Palette.TEXT_DIM, false, 2)  # where the selection goes, unlit
