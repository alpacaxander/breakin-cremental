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
## decided here, from the links, never by Progress (which only checks price and max rank).
##
## ponytail: no pan or zoom. The demo's 5 x 5 web fills the 864 x 608 view; a bigger web needs a drag-to-pan
## offset on the nodes' parent and clip_contents, which is already on.

const DOT := 3.0
const DOT_STEP := 24
const LINE := 3.0


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


## Shows every node's state from Progress, with `selected` outlined.
func refresh(selected: HubNode) -> void:
	for n in nodes():
		n.show_state(state(n), buyable(n))
		n.selected = n == selected
	queue_redraw()


func _ready() -> void:
	clip_contents = true
	if Engine.is_editor_hint():
		child_order_changed.connect(queue_redraw)


func _draw() -> void:
	for x in range(DOT_STEP / 2, int(size.x), DOT_STEP):
		for y in range(DOT_STEP / 2, int(size.y), DOT_STEP):
			draw_rect(Rect2(x - 1, y - 1, DOT, DOT), Palette.WALL)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Palette.WALL, false, 2)
	var depth := _depth()
	for l in links():
		var a: HubNode = l[0]
		var b: HubNode = l[1]
		var outer := b if depth.get(b, 0) >= depth.get(a, 0) else a
		var lit := not Engine.is_editor_hint() and (Progress.rank(a.upgrade) > 0 or Progress.rank(b.upgrade) > 0)
		var colour := Palette.lit(Palette.of(outer.upgrade.meaning()), Palette.LIT_TEXT) if lit else Palette.BORDER
		# ponytail: a straight line between centres; the demo's links are all straight across or straight down.
		draw_line(a.position + a.size / 2, b.position + b.size / 2, colour, LINE)


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
