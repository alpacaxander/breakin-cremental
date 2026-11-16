class_name UiTopBar
extends HBoxContainer
## The top bar of a screen that is not a level (art.md, "Upgrade screen"): 84 px tall at x 24 to 1256, with the
## back button and the screen's title on the left. The hub and Settings both use it, so the two sit in the same
## place. Connect `back.pressed`. Children a scene adds come after the title: give one size_flags_horizontal
## EXPAND to push the rest to the right edge (the hub's spacer before its coin counter).

const RECT := Rect2(24, 0, 1232, 84)

@export var title := "":
	set(v):
		title = v
		_title.text = v

var back := UiBackButton.new()
var _title := Label.new()


func _init() -> void:
	position = RECT.position
	size = RECT.size
	add_theme_constant_override(&"separation", 18)
	back.name = "Back"
	back.size_flags_vertical = SIZE_SHRINK_CENTER
	_title.theme_type_variation = &"Title"
	_title.size_flags_vertical = SIZE_SHRINK_CENTER
	add_child(back)
	add_child(_title)
