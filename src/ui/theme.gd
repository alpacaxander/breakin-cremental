class_name UiTheme
## The game's Theme. Main puts build() on its Screen node, so every Control under a screen inherits it.
##
## It is built in code, not saved as a .tres with colours in it, because colours may only come from Palette and
## lit colours only exist as Palette.lit() results. A theme.tres may still hold fonts and sizes; build() would
## load it and add the colours.
##
## STUB: the ui kit lane writes this from docs/art.md ("Type", "UI pieces"). Until then screens get Godot's
## default theme. When it is written, the top of this file lists every type variation and shared widget the lane
## made, by name, because the screen lanes use them from here.
##
## WHAT THE THEME COVERS, so that a screen lays controls out and never restyles one:
##   - Every row of art.md's "UI pieces": the panel, the primary and the disabled button, the "Can't afford"
##     button (a look for a button that is still enabled, see Sfx), the icon button, the toggle and the slider.
##     Godot's CheckBox, CheckButton and HSlider draw with built-in textures by default. None of those may show:
##     art.md allows flat shapes only.
##   - Labels in the three fonts at the sizes of art.md's "Type", the tooltip, and the popup of an OptionButton.
##   - The coin glyph, the rank pips and the back button (the icon button with its arrow drawn; the hub, the
##     level screen and Settings each place one), as shared widgets in src/ui/. The back button is only a
##     button: it has no shortcut and does not listen for Esc. The screen it is on does that (main.gd, "BACK").
## A widget here plays no sound: Sfx plays the click of every button by itself.
##
## FONTS. The font files in assets/fonts/ are fixed. Their import settings (the [params] of each .ttf.import:
## antialiasing, hinting, subpixel positioning) belong to the ui kit lane, which turns antialiasing off for the
## two pixel fonts there.
##
## OUTSIDE A CONTROL TREE. A theme passes down through Controls only. A Control whose parent is a Node2D gets
## Godot's default theme, and a _draw in a Node2D has no theme at all. Fx's coin pop-ups under the Arena are the
## known case. There, set `theme = UiTheme.build()` on the Control, or draw with numbers() and number_size().

static var _theme: Theme


## The one Theme. It is built on the first call, and every later call returns the same object.
static func build() -> Theme:
	if _theme == null:
		_theme = Theme.new()
	return _theme


## Jersey 10 as the theme uses it: the font of numbers, titles, big buttons and pop-ups.
static func numbers() -> Font:
	return ThemeDB.fallback_font


## The font size to give numbers() for a size taken from art.md (36 for a pop-up, 68 for a HUD number): the
## nearest size at which every stem of the pixel font has the same width. The HUD and the pop-ups both go
## through this, so the same art.md size is the same size on screen.
static func number_size(px: int) -> int:
	return px
