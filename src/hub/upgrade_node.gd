@tool
class_name HubNode
extends Button
## One node of the upgrade web (docs/art.md, "Upgrade screen"): a flat box in its category's colour with the
## upgrade's name, its rank pips and its price or MAX. web.tscn places one per upgrade; see web.gd for how to add one.
##
## It only shows what it is told: HubWeb works out its state from Progress and the web's links and calls show_state.
## In the editor (this is a @tool script so the web can be laid out by eye) it shows its node name and the
## available look in the text colour, and never reads Progress.

enum State { LOCKED, AVAILABLE, OWNED, MAXED }

const PITCH := Vector2(170, 116)  ## art.md: one grid step, centre to centre
const ORIGIN := Vector2(92, 72)  ## The centre of cell (0, 0) in the web view, so cell (2, 2) is the view's centre
const SIZE := Vector2(148, 60)
const SEED_SIZE := Vector2(168, 72)
const DASH := 6.0

## The upgrade this node sells: a .tres from data/upgrades/.
@export var upgrade: Upgrade:
	set(v):
		upgrade = v
		_place()
## Where it sits on the web's grid: column, row. (2, 2) is the centre of the view.
@export var cell := Vector2i(2, 2):
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
## Drawn with the selection outline.
var selected := false:
	set(v):
		selected = v
		queue_redraw()


func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	_place()
	if not Engine.is_editor_hint():  # a rank of this node was bought: it swells for a moment
		Progress.rank_changed.connect(func(u: Upgrade) -> void:
			if u == upgrade:
				UiTheme.pulse(self))


## Shows the node in `s`. `affordable` lights the price gold.
func show_state(s: State, affordable: bool) -> void:
	state = s
	var u := upgrade
	accessibility_name = "%s, %s, rank %d of %d" % [u.title, State.keys()[s].to_lower(), Progress.rank(u), u.max_rank]
	($Name as Label).add_theme_color_override(&"font_color",
			Palette.BASE if s == State.MAXED else Palette.TEXT)
	var pips: UiPips = $Bottom/Pips
	pips.total = u.max_rank
	pips.owned = Progress.rank(u)
	pips.meaning = u.meaning()
	pips.on_lit = s == State.MAXED
	var price: UiPrice = $Bottom/Price
	price.visible = s != State.MAXED
	price.amount = Progress.cost(u)
	price.dim = not affordable
	var max_label: Label = $Bottom/Max
	max_label.visible = s == State.MAXED
	max_label.add_theme_color_override(&"font_color", Palette.BASE)
	queue_redraw()


func _place() -> void:
	size = SEED_SIZE if is_seed else SIZE
	position = ORIGIN + Vector2(cell) * PITCH - size / 2
	if is_node_ready():
		($Name as Label).theme_type_variation = &"Name" if is_seed else &"SmallName"
		($Name as Label).text = String(name) if Engine.is_editor_hint() or upgrade == null else upgrade.title


func _draw() -> void:
	var editor := Engine.is_editor_hint() or upgrade == null
	var hue := Palette.TEXT if editor else Palette.of(upgrade.meaning())
	var r := Rect2(Vector2.ZERO, size)
	var edge := Rect2(Vector2.ONE, size - Vector2(2, 2))  # a 2 px stroke centred 1 px in, so it stays inside the box
	match state:
		State.MAXED:
			# The palette colour as it is, not lit: a lit cyan fill blooms over the 14 px name and washes it out. The
			# border is lit, so a maxed node still glows.
			draw_rect(r, hue)
			draw_rect(edge, Palette.lit(hue), false, 2)
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
