class_name UiTheme
## The game's Theme. Main calls build() once and puts the result on its Screen node, so every screen inherits it.
##
## It is built in code, not saved as a .tres with colours in it, because colours may only come from Palette and
## lit colours only exist as Palette.lit() results. A theme.tres may still hold fonts and sizes; build() would
## load it and add the colours.
##
## STUB: the ui kit lane writes this from docs/art.md ("Type", "UI pieces"). Until then screens get Godot's
## default theme.


static func build() -> Theme:
	return Theme.new()
