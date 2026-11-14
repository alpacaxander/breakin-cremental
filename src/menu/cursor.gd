extends TextureRect
## The arcade cursor of the menu screens: a lit triangle to the left of whichever control on this screen has the
## keyboard focus, beside the theme's focus outline. On a row (a control inside an HBoxContainer, such as a
## volume slider after its name) it points at the row, so it also shows focus on a slider, which has no outline.

const GAP := 12


func _ready() -> void:
	texture = UiGlyph.new(UiGlyph.Shape.PLAY, Vector2(18, 18), Palette.lit(Palette.PLAYER))
	mouse_filter = MOUSE_FILTER_IGNORE


# ponytail: polled every frame, so it follows focus and container layout without wiring; signals if it ever shows up in a profile.
func _process(_delta: float) -> void:
	var c := get_viewport().gui_get_focus_owner()
	visible = c != null and get_parent().is_ancestor_of(c)
	if not visible:
		return
	var at: Control = c.get_parent() if c.get_parent() is HBoxContainer else c
	global_position = Vector2(at.global_position.x - GAP - size.x, c.get_global_rect().get_center().y - size.y / 2).round()
