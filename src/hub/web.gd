@tool
class_name HubWeb
extends Control
## The upgrade web's view (docs/art.md, "Upgrade screen"): the framed dot grid, the connections and the nodes.
##
## web.tscn holds only layout. TO ADD AN UPGRADE: make its .tres in data/upgrades/, then in web.tscn instance
## src/hub/upgrade_node.tscn as a child of Web, set its Upgrade, its Cell (column, row; (2, 2) is the centre of
## the view, one step is 170 x 116 px) and its Links (the node or nodes it hangs off). No code changes.
##
## A node is reachable once a node it links to has been bought; the seed is reachable from the start. That is
## decided here, from the links, never by Progress (which only checks price and max rank). A node that is not
## reachable (LOCKED) is hidden, and so are its links: the web shows only what is bought or what coins alone buy.
##
## The view pans and zooms (art.md, "Web view"): a drag with any mouse button or a two-finger swipe pans, the wheel
## or a pinch zooms about the pointer. The nodes are laid out in web.tscn at zoom 1 with no pan; _layout moves and
## scales them from there. The view's centre stays over the shown nodes, so the web can't be lost off screen.

const DOT := 3.0
const DOT_STEP := 24
const LINE := 3.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 1.5
const ZOOM_STEP := 1.1  ## per wheel notch
const PAN_GESTURE := 16.0  ## px per unit of a touchpad swipe
const REVEAL := 12.0  ## px kept between the selected node and the frame when the view moves to show it

## Where the web's origin is in the view, and its scale. (0, 0) and 1 show it as web.tscn lays it out.
var pan := Vector2.ZERO
var zoom := 1.0


## Every node of the web, in scene order.
func nodes() -> Array[HubNode]:
	var out: Array[HubNode] = []
	out.assign(get_children().filter(func(c: Node) -> bool: return c is HubNode))
	return out


## The seed: the node open from the start.
func seed_node() -> HubNode:
	for n in nodes():
		if n.is_seed:
			return n
	return null


## Every connection once, as [a, b] pairs, whichever end lists it.
func links() -> Array[Array]:
	var out: Array[Array] = []
	for a in nodes():
		for path in a.links:
			var b := a.get_node_or_null(path) as HubNode
			if b == null:
				push_error("%s links to %s, which is not a node of the web" % [a.name, path])
			elif not out.any(func(l: Array) -> bool: return l.has(a) and l.has(b)):
				out.append([a, b])
	return out


func neighbours(n: HubNode) -> Array[HubNode]:
	var out: Array[HubNode] = []
	for l in links():
		if l.has(n):
			out.append(l[1] if l[0] == n else l[0])
	return out


func state(n: HubNode) -> HubNode.State:
	if Engine.is_editor_hint():
		return HubNode.State.AVAILABLE
	if Progress.maxed(n.upgrade):
		return HubNode.State.MAXED
	if Progress.rank(n.upgrade) > 0:
		return HubNode.State.OWNED
	if n.is_seed or neighbours(n).any(func(m: HubNode) -> bool: return Progress.rank(m.upgrade) > 0):
		return HubNode.State.AVAILABLE
	return HubNode.State.LOCKED


## True if the node's next rank can be bought now: reachable, not maxed, and the coins cover it.
func buyable(n: HubNode) -> bool:
	return state(n) in [HubNode.State.AVAILABLE, HubNode.State.OWNED] and Progress.can_buy(n.upgrade)


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


## The arrows go to the nearest shown node in line on the grid. Godot's own search goes by the boxes, and the
## seed's larger box sticks out past its neighbours, so Up or Down from beside it would land on it. With no node
## in line, Godot's search stays: Right from the last column still reaches the panels.
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
	var depth := _depth()
	for l in links():
		var a: HubNode = l[0]
		var b: HubNode = l[1]
		if not (a.visible and b.visible):
			continue
		var outer := b if depth.get(b, 0) >= depth.get(a, 0) else a
		var lit := not Engine.is_editor_hint() and (Progress.rank(a.upgrade) > 0 or Progress.rank(b.upgrade) > 0)
		var colour := Palette.lit(Palette.of(outer.upgrade.meaning()), Palette.LIT_TEXT) if lit else Palette.BORDER
		# ponytail: a straight line between centres; the demo's links are all straight across or straight down.
		draw_line(a.position + a.size / 2, b.position + b.size / 2, colour, LINE * zoom)


## Steps from the seed to each node, for colouring a line by its outer end.
func _depth() -> Dictionary:
	var start := seed_node()
	if start == null:
		return {}
	var depth := {start: 0}
	var queue: Array[HubNode] = [start]
	while queue:
		var n: HubNode = queue.pop_front()
		for m in neighbours(n):
			if not depth.has(m):
				depth[m] = depth[n] + 1
				queue.append(m)
	return depth
