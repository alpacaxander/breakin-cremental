class_name UiBackButton
extends Button
## The back button (art.md, "UI pieces"): the 44 x 44 icon button with a left-pointing arrow. The top bar
## (UiTopBar), Setup and the Summary each place one, all at UiTopBar.BACK, and connect `pressed` to their way back.
##
## It is only a button. It has no shortcut and does not listen for Esc: the screen handles ui_cancel itself
## (main.gd, "BACK"). It plays no sound either; Sfx clicks every button. It has no tooltip: one would spend the
## next key press (main.gd), and in Setup that key is Space, Q or E.
##
## It takes no keyboard focus: Esc is the keyboard's way back on every screen that has one. Focus on it would
## put the menu screens' cursor off the left edge of the screen (the top bar starts at x 24), and in the Summary
## a paddle key still held would walk the focus off Retry.


func _init() -> void:
	focus_mode = FOCUS_NONE
	theme_type_variation = &"IconButton"
	icon = UiTheme.icon(UiGlyph.Shape.BACK)
	accessibility_name = "Back"
