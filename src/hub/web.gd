@tool
class_name HubWeb
extends Control
## The upgrade web's view (docs/art.md, "Upgrade screen"): the framed dot grid, the connections and the nodes.
##
## web.tscn holds only layout: one node per purchase, so an upgrade with max_rank 3 has three nodes, its copies,
## anywhere on the web. TO ADD AN UPGRADE: make its .tres in data/upgrades/, then in web.tscn instance
## src/hub/upgrade_node.tscn as a child of Web max_rank times, and for each set its Upgrade, its Cell (column, row;
## the seed is at (0, 0), the centre of the view, and one step is 136 x 60 px) and its Links (the node or nodes it
## hangs off). No code changes. tests/cases/hub.gd checks the copies, the seed and what each node needs first.
##
## A node is bought once (its name goes into Progress.owned). An unbought node is on offer once a node it links to
## has been bought; the seed is on offer from the start. An owned node can be undone while the rest stay joined to
## the seed without it (can_undo). That is decided here, from the links, never by Progress (which only checks
## price, key and max rank). A node one link past an offered one, or up to PEEK links behind a
## key node that is on offer or owned, is a PREVIEW: shown dimmed, selectable, not for sale. Every other node is
## LOCKED and hidden, and so are its links.
##
## The view pans and zooms (art.md, "Web view"): a drag with any mouse button or a two-finger swipe pans, the wheel
## or a pinch zooms about the pointer. The nodes are laid out in web.tscn at zoom 1 with no pan; _layout moves and
## scales them from there. The view's centre stays over the shown nodes, so the web can't be lost off screen. The
## hub calls fit() once, when it is made, for the opening view; after that the pan and zoom are the player's.

const SCENE := "res://src/hub/web.tscn"
const DOT := 3.0
const DOT_STEP := 24
const LINE := 3.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 1.5
const ZOOM_STEP := 1.1  ## per wheel notch
const FIT_MIN := 0.6  ## fit() zooms out no further than this, so the names stay readable
const PAN_GESTURE := 16.0  ## px per unit of a touchpad swipe
const REVEAL := 12.0  ## px kept between the selected node and the frame when the view moves to show it
const PEEK := 3  ## how many links past a key node the web previews what only that key opens

## Where the web's origin is in the view, and its scale. (0, 0) and 1 show it as web.tscn lays it out.
var pan := Vector2.ZERO
var zoom := 1.0

# ponytail: the links, read once; the scene doesn't change at run time. The editor reads them on every call.
var _links: Array[Array] = []
var _neighbours := {}  # HubNode -> Array of the HubNodes linked to it
var _depth := {}  # HubNode -> links from the seed
var _behind := {}  # key HubNode -> Array of the HubNodes it previews (see _read_behind)


## Every node of the web, in scene order.
func nodes() -> Array[HubNode]:
	var out: Array[HubNode] = []
	out.assign(get_children().filter(func(c: Node) -> bool: return c is HubNode))
	return out


## For tests and screenshots, which need a save part of the way through the web: owns the first `count` nodes of
## SCENE, and nothing else, as if they had been bought in the scene's order (every node links to one before it,
## so that order can be bought in). See own.
static func own_first(count: int) -> void:
	var web: HubWeb = (load(SCENE) as PackedScene).instantiate()
	web.own(web.nodes().slice(0, count).map(func(n: HubNode) -> StringName: return n.name))
	web.free()


## Owns exactly the nodes named, and nothing else: sets Progress.owned to them (in scene order; a name that is no
## node is dropped) and Progress.ranks to match, one copy of its upgrade per node. Joined to the seed or not, so
## can_undo may then refuse what the web would never have sold. Takes no coins, no keys, does not save or emit.
## For tests, screenshots and the Admin panel; a player buys with Progress.buy.
func own(names: Array) -> void:
	Progress.owned.clear()
	Progress.ranks.clear()
	for n in nodes():
		if n.name in names:
			Progress.owned.append(n.name)
			Progress.ranks[n.upgrade.id] = Progress.rank(n.upgrade) + 1


## The seed: the node open from the start.
func seed_node() -> HubNode:
	for n in nodes():
		if n.is_seed:
			return n
	return null


## Every connection once, as [a, b] pairs, whichever end lists it.
func links() -> Array[Array]:
	if _links and not Engine.is_editor_hint():
		return _links
	var out: Array[Array] = []
	for a in nodes():
		for path in a.links:
			var b := a.get_node_or_null(path) as HubNode
			if b == null:
				push_error("%s links to %s, which is not a node of the web" % [a.name, path])
			elif not out.any(func(l: Array) -> bool: return l.has(a) and l.has(b)):
				out.append([a, b])
	_links = out
	_neighbours = {}
	for l in out:
		for i in 2:
			_neighbours.get_or_add(l[i], []).append(l[1 - i])
	var start := seed_node()
	_depth = _reach(start, {}) if start else {}
	if start and not Engine.is_editor_hint():
		_read_behind(start)
	return out


## Links from `from` to each node it reaches without stepping on a node in `skip` (a Dictionary used as a set).
## Reads _neighbours, so only links() and what runs after it call this.
func _reach(from: HubNode, skip: Dictionary) -> Dictionary:
	var seen := {from: 0}
	var queue: Array[HubNode] = [from]
	while queue:
		var n: HubNode = queue.pop_front()
		for m: HubNode in _neighbours.get(n, []):
			if not seen.has(m) and not skip.has(m):
				seen[m] = seen[n] + 1
				queue.append(m)
	return seen


## What each key node previews: the nodes coins alone can't reach (not reachable from the seed with every key
## node shut), up to PEEK links from the key node without passing another key node or a node coins reach, and
## further from the seed than it.
func _read_behind(start: HubNode) -> void:
	var shut := {}
	for n in nodes():
		if n.upgrade.key:
			shut[n] = true
	var open := _reach(start, shut)
	_behind = {}
	for g: HubNode in shut:
		var skip := open.merged(shut)
		skip.erase(g)
		var near := _reach(g, skip)
		_behind[g] = near.keys().filter(func(n: HubNode) -> bool: return n != g and near[n] <= PEEK and _depth[n] > _depth[g])


## The nodes linked to n.
func neighbours(n: HubNode) -> Array[HubNode]:
	links()
	var out: Array[HubNode] = []
	out.assign(_neighbours.get(n, []))
	return out


## OWNED if the node was bought, AVAILABLE if it is the seed or linked to an owned node, PREVIEW if it is linked
## to an AVAILABLE node or behind a key node that is AVAILABLE or OWNED (see _read_behind), LOCKED otherwise.
func state(n: HubNode) -> HubNode.State:
	if Engine.is_editor_hint():
		return HubNode.State.AVAILABLE
	if owns(n):
		return HubNode.State.OWNED
	if _offered(n):
		return HubNode.State.AVAILABLE
	if neighbours(n).any(_offered) or _behind.keys().any(func(g: HubNode) -> bool: return n in _behind[g] and (owns(g) or _offered(g))):
		return HubNode.State.PREVIEW
	return HubNode.State.LOCKED


## True if the node is the seed or linked to an owned node: AVAILABLE unless it is owned itself.
func _offered(n: HubNode) -> bool:
	return n.is_seed or neighbours(n).any(owns)


## True if this node was bought.
func owns(n: HubNode) -> bool:
	return n.name in Progress.owned


## True if the owned node can be undone: every other owned node still reaches the seed through owned nodes
## without it. So the seed only when nothing else is owned, and a node on a loop while the loop's other way holds.
func can_undo(n: HubNode) -> bool:
	if not owns(n):
		return false
	var rest := nodes().filter(func(m: HubNode) -> bool: return m != n and owns(m))
	if n.is_seed or rest.is_empty():
		return rest.is_empty()
	links()
	var skip := {n: true}
	for m in nodes():
		if not owns(m):
			skip[m] = true
	var held := _reach(seed_node(), skip)
	return rest.all(func(m: HubNode) -> bool: return held.has(m))


## True if the node can be bought now: on offer, and a key or the coins cover the next copy.
func buyable(n: HubNode) -> bool:
	return state(n) == HubNode.State.AVAILABLE and Progress.can_buy(n.upgrade)


## Shows every node's state from Progress, with `selected` outlined, and hides the locked ones. The view moves just
## enough to show `selected` whole, so the arrow keys never leave the selection off screen.
func refresh(selected: HubNode) -> void:
	for n in nodes():
		n.show_state(state(n), buyable(n))
		n.visible = n.state != HubNode.State.LOCKED
		n.selected = n == selected
	_focus_neighbours()
	if selected:
		var r := Rect2(pan + selected.home().position * zoom, selected.size * zoom).grow(REVEAL)
		pan += (-r.position).max(Vector2.ZERO) + (size - r.end).min(Vector2.ZERO)
	_layout()


## Zooms by `factor` about `at`, a point in the view, which stays where it is.
func zoom_at(at: Vector2, factor: float) -> void:
	var z := clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	pan = at - (at - pan) * z / zoom
	zoom = z
	_layout()


func move(by: Vector2) -> void:
	pan += by
	_layout()


## The opening view: centred on the nodes that are not locked, zoomed to fit them REVEAL clear of the frame, from
## FIT_MIN to 1. It reads the states itself, so it can run before the first refresh.
func fit() -> void:
	var shown := nodes().filter(func(n: HubNode) -> bool: return state(n) != HubNode.State.LOCKED)
	var bounds: Rect2 = shown[0].home()
	for n: HubNode in shown:
		bounds = bounds.merge(n.home())
	var room := (size - Vector2.ONE * 2 * REVEAL) / bounds.size
	zoom = clampf(minf(room.x, room.y), FIT_MIN, 1.0)
	pan = size / 2 - bounds.get_center() * zoom
	_layout()


## Keeps the view's centre over the shown nodes, then places and scales every node for pan and zoom. A node's
## pivot is its centre, so its centre lands at pan + home centre × zoom.
func _layout() -> void:
	var shown := nodes().filter(func(n: HubNode) -> bool: return n.visible)
	if shown:
		var bounds: Rect2 = shown[0].home()
		for n: HubNode in shown:
			bounds = bounds.merge(n.home())
		pan = pan.clamp(size / 2 - bounds.end * zoom, size / 2 - bounds.position * zoom)
	for n in nodes():
		n.zoom = zoom
		n.scale = Vector2.ONE * zoom
		n.position = pan + n.home().get_center() * zoom - n.size / 2
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b and b.pressed and b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_at(b.position, ZOOM_STEP if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / ZOOM_STEP)
	elif event is InputEventMouseMotion and event.button_mask:
		move(event.relative)
	elif event is InputEventMagnifyGesture:
		zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		move(-event.delta * PAN_GESTURE)
	else:
		return
	accept_event()


func _ready() -> void:
	clip_contents = true
	# The frame goes over the nodes, which a pan or zoom pushes against it.
	var frame := ReferenceRect.new()
	frame.editor_only = false
	frame.border_color = Palette.WALL
	frame.border_width = 2
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 1)  # its stroke straddles its edge
	add_child(frame, false, INTERNAL_MODE_BACK)
	if Engine.is_editor_hint():
		child_order_changed.connect(queue_redraw)


## The arrows go to the nearest shown node in line on the grid. Godot's own search goes by the boxes and can land
## on a node off the line, past a gap in it. With no node in line, Godot's search stays: Right from the last
## column still reaches the panels.
func _focus_neighbours() -> void:
	var shown := nodes().filter(func(n: HubNode) -> bool: return n.visible)
	for n: HubNode in shown:
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var step: Vector2i = [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN][side]
			var best: HubNode
			for m: HubNode in shown:
				var d := m.cell - n.cell
				var along := d.x * step.x + d.y * step.y
				if along > 0 and d == step * along and (best == null or along < (best.cell - n.cell).length()):
					best = m
			n.set_focus_neighbor(side, n.get_path_to(best) if best else NodePath())


func _draw() -> void:
	var step := DOT_STEP * zoom  # the dots move with the web, so a pan shows even where there is no node
	var x := fposmod(pan.x + step / 2, step)
	while x < size.x:
		var y := fposmod(pan.y + step / 2, step)
		while y < size.y:
			draw_rect(Rect2(x - 1, y - 1, DOT, DOT), Palette.WALL)
			y += step
		x += step
	for l in links():
		var a: HubNode = l[0]
		var b: HubNode = l[1]
		if not (a.visible and b.visible):
			continue
		var outer := b if _depth.get(b, 0) >= _depth.get(a, 0) else a
		var lit := not Engine.is_editor_hint() and (owns(a) or owns(b))
		var colour := Palette.lit(Palette.of(outer.upgrade.meaning()), Palette.LIT_TEXT) if lit else Palette.BORDER
		# ponytail: a straight line between centres; the web's links are all straight across or straight down.
		draw_line(a.position + a.size / 2, b.position + b.size / 2, colour, LINE * zoom)
