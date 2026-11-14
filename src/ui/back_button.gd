class_name UiBackButton
extends Button
## The back button (art.md, "UI pieces"): the 44 x 44 icon button with a left-pointing arrow. The top bar
## (UiTopBar), the Setup footer and the Summary each place one and connect `pressed` to their way back.
##
## It is only a button. It has no shortcut and does not listen for Esc: the screen handles ui_cancel itself
## (main.gd, "BACK"). It plays no sound either; Sfx clicks every button. It has no tooltip: one would spend the
## next key press (main.gd), and in Setup that key is Space, Q or E.


func _init() -> void:
	theme_type_variation = &"IconButton"
	icon = UiTheme.icon(UiGlyph.Shape.BACK)
	accessibility_name = "Back"
