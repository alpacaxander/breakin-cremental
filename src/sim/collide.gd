class_name Collide
## Swept collision for a ball (docs/design/physics.md, "Collision"), and the overlap test Layout.fits uses.
## Only Round and Layout call it; nothing outside the rules depends on its shape.
##
## HOW THE SWEEP WORKS. The ball is a square that never turns, so it is treated as its centre point and every
## solid is grown by half the ball: a wall, a brick and the paddle by a plain margin, an item by the square
## itself (its outline with the ball's square added on, which is still a convex polygon). The ball's line is then
## a ray against those shapes and the nearest entry wins. Nothing is tested by overlap after a move, so no speed
## and no step size passes through anything.
##
## The ray starts at Ball.from, where the ball last changed direction, not at Ball.pos. A contact is the same
## number whether the ball got there in one step or in ten, so a round bounces in the same places at any tick
## rate (with one ball and a paddle that is not moving as the ball lands; see Round).
##
## WHAT IT DECIDES:
##   - A brick is hit on the face the ray enters through: one of LEFT, RIGHT, UP, DOWN. An exact corner takes
##     the side face. When the ball lands across two bricks at once, the one more of the ball is on takes the
##     hit, so a seam inside a wall of bricks is never an edge.
##   - An item (Bumper, Wall Segment) bounces the ball off its faces. Where a corner of the item meets a flat
##     side of the ball, the normal is that side's. A gate (the Booster) is not a solid: Round checks it.
##   - The paddle is solid on every side, so its ends save a ball too. If the paddle moves onto a ball that is
##     heading out, the ball bounces where it is and is then let out of the paddle.
##   - A ball that is already inside something by more than SKIN is let out of it, never pushed.

## How deep, in units, a ball may be inside something and still bounce off it. It only has to cover rounding;
## anything deeper means the thing moved onto the ball. Also the least overlap that counts for overlap().
const SKIN := 0.01

## A free-form item as the sweep sees it. Round makes one per FREE item when it is built.
class Solid:
	extends RefCounted
	var item: Layout.Item
	## Its bounds, already grown, for a quick miss.
	var box: Rect2
	## A point on each face of the grown outline, and that face's outward normal.
	var points := PackedVector2Array()
	var normals := PackedVector2Array()

# What the last _slab or _poly that found a hit also found: the surface normal, and for a face that
# lies along an axis the coordinate the ball's centre has on it (else NAN). Kept here so a miss allocates nothing.
static var _normal: Vector2
static var _plane: float


## The first thing `ball` touches while moving `distance` units along its dir, or null if nothing is in the way.
## hit.point is where the ball's centre is then, and hit.travel how far that is from where it is now.
static func sweep(round: Round, ball: Ball, distance: float) -> Hit:
	var a := ball.from
	var d := ball.dir
	var gone := ball.gone
	var limit := gone + distance
	var h := ball.size * 0.5
	var size := round.board.size()
	# The best so far. `t` is a distance along the ray from `a`.
	var t := INF
	var normal := Vector2.ZERO
	var plane := NAN
	var surface := Hit.Surface.WALL
	var cell := Vector2i.ZERO
	var item: Layout.Item = null

	# The walls are lines, so a ball that is somehow past one is brought back to it.
	if d.y < 0.0:
		t = maxf((h - a.y) / d.y, gone)
		normal = Vector2.DOWN
		plane = h
	elif d.y > 0.0:
		t = maxf((size.y - h - a.y) / d.y, gone)
		normal = Vector2.UP
		plane = size.y - h
	if d.x > 0.0:
		var back := maxf((size.x - h - a.x) / d.x, gone)
		if back < t:
			t = back
			normal = Vector2.LEFT
			plane = size.x - h

	var far := minf(limit, t)
	var p := a + d * gone
	var q := a + d * far

	var pad := round.paddle.rect().grow(h)
	var e := _slab(pad.position.x, pad.position.y, pad.end.x, pad.end.y, a, d, gone)
	if e == INF and d.x < 0.0 and pad.grow(-SKIN).has_point(p):
		e = gone  # the paddle moved onto a ball that is heading out
		_plane = NAN
		_normal = Vector2.RIGHT if p.x >= round.paddle.x else (Vector2.UP if p.y < round.paddle.y else Vector2.DOWN)
	if e < t:
		t = e
		normal = _normal
		plane = _plane
		surface = Hit.Surface.PADDLE

	# Bricks: only the cells the ball's square can reach in this move.
	var bricks := round.board.bricks
	var bw := Board.BRICK.x
	var bh := Board.BRICK.y
	var share := -INF  # how much of the ball is on the best brick, along the face it hit
	var x0 := maxi(floori((minf(p.x, q.x) - h - 1.0) / bw), 0)
	var x1 := mini(floori((maxf(p.x, q.x) + h + 1.0) / bw), round.board.cols - 1)
	var y0 := maxi(floori((minf(p.y, q.y) - h - 1.0) / bh), 0)
	var y1 := mini(floori((maxf(p.y, q.y) + h + 1.0) / bh), round.board.rows / 2 - 1)
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var c := Vector2i(cx, cy)
			if not bricks.has(c):
				continue
			e = _slab(cx * bw - h, cy * bh - h, cx * bw + bw + h, cy * bh + bh + h, a, d, gone)
			if e == INF or e > t:
				continue
			var at := a + d * e
			var on := (minf(at.y + h, cy * bh + bh) - maxf(at.y - h, cy * bh)) if _normal.x != 0.0 \
					else (minf(at.x + h, cx * bw + bw) - maxf(at.x - h, cx * bw))
			if e < t or (surface == Hit.Surface.BRICK and on > share):
				t = e
				share = on
				normal = _normal
				plane = _plane
				surface = Hit.Surface.BRICK
				cell = c

	var path := Rect2(p, Vector2.ZERO).expand(q)
	for s: Solid in round._solids:
		if not s.box.intersects(path, true):
			continue
		e = _poly(s, a, d, gone)
		if e < t:
			t = e
			normal = _normal
			plane = _plane
			surface = Hit.Surface.ITEM
			item = s.item

	if t > limit:
		return null
	var hit := Hit.new()
	hit.surface = surface
	hit.normal = normal
	hit.travel = t - gone
	hit.point = a + d * t
	if not is_nan(plane):  # exactly on the face, so the ball is never a rounding error inside it
		if normal.x != 0.0:
			hit.point.x = plane
		else:
			hit.point.y = plane
	if surface == Hit.Surface.BRICK:
		hit.cell = cell
	hit.item = item
	return hit


## Where the ray from `a` along `d` enters the rectangle (l, t, r, b), as a distance from `a`. INF if it misses,
## if it is past it at `gone`, or if at `gone` it is already more than SKIN inside.
static func _slab(l: float, t: float, r: float, b: float, a: Vector2, d: Vector2, gone: float) -> float:
	var in_x := -INF
	var out_x := INF
	if d.x > 0.0:
		in_x = (l - a.x) / d.x
		out_x = (r - a.x) / d.x
	elif d.x < 0.0:
		in_x = (r - a.x) / d.x
		out_x = (l - a.x) / d.x
	elif a.x <= l or a.x >= r:
		return INF
	var in_y := -INF
	var out_y := INF
	if d.y > 0.0:
		in_y = (t - a.y) / d.y
		out_y = (b - a.y) / d.y
	elif d.y < 0.0:
		in_y = (b - a.y) / d.y
		out_y = (t - a.y) / d.y
	elif a.y <= t or a.y >= b:
		return INF
	var enter := maxf(in_x, in_y)
	var leave := minf(out_x, out_y)
	if enter >= leave or leave <= gone:
		return INF
	if in_x >= in_y:  # a corner takes the side face
		if (gone - enter) * absf(d.x) > SKIN:
			return INF
		_normal = Vector2.LEFT if d.x > 0.0 else Vector2.RIGHT
		_plane = l if d.x > 0.0 else r
	else:
		if (gone - enter) * absf(d.y) > SKIN:
			return INF
		_normal = Vector2.UP if d.y > 0.0 else Vector2.DOWN
		_plane = t if d.y > 0.0 else b
	return maxf(enter, gone)


## The same for an item's grown outline: the ray is clipped against each face in turn.
static func _poly(s: Solid, a: Vector2, d: Vector2, gone: float) -> float:
	var enter := -INF
	var leave := INF
	var face := Vector2.ZERO
	for i in s.points.size():
		var n := s.normals[i]
		var toward := d.dot(n)
		var off := (s.points[i] - a).dot(n)
		if toward < 0.0:
			if off / toward > enter:
				enter = off / toward
				face = n
		elif toward > 0.0:
			leave = minf(leave, off / toward)
		elif off <= 0.0:  # along this face, on its outside
			return INF
	if face == Vector2.ZERO or enter >= leave or leave <= gone or (gone - enter) * -d.dot(face) > SKIN:
		return INF
	_normal = face
	_plane = NAN
	return maxf(enter, gone)


## A FREE item as the sweep needs it, for balls of side `ball_size`.
static func solid(item: Layout.Item, ball_size: float) -> Solid:
	var s := Solid.new()
	s.item = item
	var h := ball_size * 0.5
	# The outline with the ball's square added on: every corner of one plus every corner of the other, and the
	# hull of those.
	var sums := PackedVector2Array()
	for corner in item.outline():
		for off in box(Rect2(-h, -h, ball_size, ball_size)):
			sums.append(corner + off)
	var hull := Geometry2D.convex_hull(sums)
	s.box = Rect2(hull[0], Vector2.ZERO)
	for i in hull.size() - 1:  # the hull is closed: its last point is its first again
		var edge := hull[i + 1] - hull[i]
		if edge.length() < SKIN:
			continue
		# Rounded, so a wall turned 90 degrees has a normal of exactly (0, 1) and bounces like a brick's face.
		var n := edge.orthogonal().snapped(Vector2.ONE * 1e-6).normalized()
		s.points.append(hull[i])
		s.normals.append(n if n.dot(hull[i] - item.pos) > 0.0 else -n)
		s.box = s.box.expand(hull[i])
	return s


## The four corners of a rectangle, as a polygon.
static func box(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


## True if two convex polygons share area. Touching does not count, and neither does an overlap under SKIN.
static func overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for poly: PackedVector2Array in [a, b]:
		for i in poly.size():
			# Apart if some face of either has the other wholly beyond it.
			var axis := (poly[(i + 1) % poly.size()] - poly[i]).orthogonal().normalized()
			var a_lo := INF
			var a_hi := -INF
			for point in a:
				a_lo = minf(a_lo, point.dot(axis))
				a_hi = maxf(a_hi, point.dot(axis))
			var b_lo := INF
			var b_hi := -INF
			for point in b:
				b_lo = minf(b_lo, point.dot(axis))
				b_hi = maxf(b_hi, point.dot(axis))
			if a_hi - b_lo < SKIN or b_hi - a_lo < SKIN:
				return false
	return true
