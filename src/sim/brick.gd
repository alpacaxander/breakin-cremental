class_name Brick
extends RefCounted
## One brick on a Board. Bricks are not nodes; BoardView draws them all from the board.

## Hits left. A hit takes 1. At 0 the brick is broken and erased from the board.
var hp := 1
## &"" for a standard brick. Otherwise the id of its kind: a special brick (a BrickKind, such as &"gold") or
## a placed brick (a PlaceableKind whose placement is BRICK, such as &"splitter"). Look it up with Kinds.of().
var kind: StringName = &""
## &"" for none. Otherwise the id of the brick mod on it (a PlaceableKind whose placement is MOD, such as &"zap").
var mod: StringName = &""
## True if the player put this brick there. A placed brick pays nothing and does not count toward a clear, but
## breaking it still extends the combo.
var placed := false
## A placed block with a cooldown (Refresh): the round.clock at which it is ready again. 0 is ready from the start.
var ready_at := 0.0


func _init(p_hp := 1, p_kind: StringName = &"") -> void:
	hp = p_hp
	kind = p_kind


func copy() -> Brick:
	var b := Brick.new(hp, kind)
	b.mod = mod
	b.placed = placed
	b.ready_at = ready_at
	return b
