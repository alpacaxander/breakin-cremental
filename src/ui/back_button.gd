class_name UiBackButton
extends Button
## The back button (art.md, "UI pieces"): the 44 x 44 icon button with a left-pointing arrow. The hub's top
## bar, the Setup footer, the Summary and Settings each place one and connect `pressed` to their way back.
##
## It is only a button. It has no shortcut and does not listen for Esc: the screen handles ui_cancel itself
## (main.gd, "BACK"). It plays no sound either; Sfx clicks every button.


func _init() -> void:
	theme_type_variation = &"IconButton"
	icon = UiTheme.icon(UiGlyph.Shape.BACK)
	tooltip_text = "Back"
	accessibility_name = "Back"
