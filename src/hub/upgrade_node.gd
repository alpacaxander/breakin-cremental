@tool
class_name HubNode
extends Button
## One node of the upgrade web (docs/art.md, "Upgrade screen"): a flat box in its category's colour with the
## upgrade's name, a pip per copy of the upgrade owned and, until it is bought, the next copy's price. web.tscn
## places one per purchase: an upgrade has max_rank nodes, its copies, which share its price ladder (buying any
## copy raises the others' price). See web.gd for how to add one. A key node (its upgrade's `key`) has a second
## outline, no pips, and the key glyph and KEY where the others show a price.
##
## It only shows what it is told: HubWeb works out its state from Progress and the web's links and calls show_state.
## In the editor (this is a @tool script so the web can be laid out by eye) it shows its node name and the
## available look in the text colour, and never reads Progress.

enum State { LOCKED, PREVIEW, AVAILABLE, OWNED }

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
var _rank := 0  # the copies of the upgrade owned at the last rank_changed: a pulse only when it rises
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
		_rank = Progress.rank(upgrade)
		Progress.rank_changed.connect(func(u: Upgrade) -> void:
			if u != upgrade:
				return
			if Progress.rank(u) > _rank and Progress.owned and Progress.owned.back() == name:  # not when a copy is undone
				UiTheme.pulse(self, 0.5, UiTheme.PULSE, zoom)
			_rank = Progress.rank(u))


## Shows the node in `s`. `affordable` lights the price gold.
func show_state(s: State, affordable: bool) -> void:
	state = s
	var u := upgrade
	accessibility_name = "%s, %s, %s" % [u.title, State.keys()[s].to_lower(), "costs one key" if u.key else "%d owned" % Progress.rank(u)]
	var pips: UiPips = $Bottom/Pips
	pips.total = 0 if u.key else Progress.rank(u)
	pips.owned = pips.total
	pips.meaning = u.meaning()
	var price: UiPrice = $Bottom/Price
	price.visible = s != State.OWNED
	price.key = u.key
	price.amount = Progress.cost(u)
	if u.key:
		price.text = "KEY"
	price.dim = not affordable
	var name_label: Label = $Name
	if s == State.PREVIEW:
		name_label.add_theme_color_override(&"font_color", Palette.TEXT_DIM)
	else:
		name_label.remove_theme_color_override(&"font_color")
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
	var border := Palette.BORDER if state == State.PREVIEW else hue if editor else Palette.lit(hue)
	match state:
		State.OWNED:
			draw_rect(r, Palette.dim(upgrade.meaning()))
			draw_rect(edge, border, false, 2)
		State.AVAILABLE:
			draw_rect(r, Palette.BASE)
			var p := [edge.position, Vector2(edge.end.x, edge.position.y), edge.end, Vector2(edge.position.x, edge.end.y)]
			for i in 4:
				draw_dashed_line(p[i], p[(i + 1) % 4], border, 2, DASH)
		State.PREVIEW:
			draw_rect(r, Palette.BASE)  # base, not clear: the links run to the centres and would show through
			draw_rect(edge, border, false, 2)
		# LOCKED draws nothing: the web hides a locked node.
	# A key node's second outline: 2 px, 2 px outside the box. The selection ring then goes outside it.
	var out := 3.0
	if not editor and upgrade.key:
		draw_rect(r.grow(3), border, false, 2)
		out = 7.0
	if selected:
		# Over the theme's focus ring (2 px, 4 px out), so a focused, selected node shows one cyan ring.
		draw_rect(r.grow(out), Palette.lit(Palette.PLAYER, Palette.LIT_TEXT), false, 2)
	elif is_hovered():
		draw_rect(r.grow(out), Palette.TEXT_DIM, false, 2)  # where the selection goes, unlit
