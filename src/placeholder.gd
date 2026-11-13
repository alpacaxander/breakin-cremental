extends Control
## A stand-in for a screen that a later lane replaces. It names itself and links to the other screens, so the
## game can be walked from the menu to a level and back before any screen exists. The lane that owns an entry
## scene overwrites the scene and stops using this script; delete it when the last placeholder is gone.

## Play sets this on the Level scene before it enters the tree (see play.gd).
var level := 0


func _ready() -> void:
	var links: Dictionary = {
		"MainMenu": {"Play": Main.show_hub, "Settings": Main.show_settings, "Exit": Main.quit},
		"Settings": {"Back": Main.show_menu},
		"Hub": {"Play level 1": Main.show_level.bind(1), "Menu": Main.show_menu},
		"Level": {"Upgrades": Main.show_hub},
	}[String(name)]
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(box)
	var title := Label.new()
	title.text = "%s%s (placeholder)" % [name, " %d" % level if level else ""]
	title.add_theme_color_override("font_color", Palette.TEXT)
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	for text: String in links:
		var button := Button.new()
		button.text = text
		button.custom_minimum_size.y = 44
		button.pressed.connect(links[text])
		box.add_child(button)
