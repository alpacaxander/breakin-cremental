extends Control
## Settings: the CRT filter, reduce flashing, and the music and sound volumes. Each control sets its Settings
## property when it changes, and Settings applies and saves it at once, so there is nothing to confirm. A slider
## moves in steps of 5%, so a drag writes the file once per step it crosses, never once per frame. The back
## button and Esc return to the main menu.

@onready var _crt: CheckBox = %Crt
@onready var _calm: CheckBox = %Calm


func _ready() -> void:
	_crt.set_pressed_no_signal(Settings.crt)
	_calm.set_pressed_no_signal(Settings.reduce_flashing)
	_crt.toggled.connect(func(on: bool) -> void: Settings.crt = on)
	_calm.toggled.connect(func(on: bool) -> void: Settings.reduce_flashing = on)
	for pair: Array in [[%Music, &"music_volume"], [%Sound, &"sound_volume"]]:
		var slider: HSlider = pair[0]
		var shown: Label = slider.get_parent().get_node(^"Value")
		slider.set_value_no_signal(Settings.get(pair[1]))
		shown.text = _percent(slider.value)
		slider.value_changed.connect(func(v: float) -> void:
			Settings.set(pair[1], v)
			shown.text = _percent(v))
	($Bar as UiTopBar).back.pressed.connect(Main.show_menu)
	_crt.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		Main.show_menu()


func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100)
