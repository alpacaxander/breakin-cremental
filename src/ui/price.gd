class_name UiPrice
extends HBoxContainer
## A coin glyph and an amount: the coin counter in the HUD and the hub's top bar, the price in the detail
## panel, the price on an upgrade node. `style` is the label's type variation and sets the size; the glyph is
## sized to it (art.md: about a quarter of the number's height).
##     HudNumber   the coin counters        Number   the detail panel's price        SmallTag   a node's price
## The amount is lit gold, or secondary text and unlit when `dim` (a price you can't afford; never red).
## With `key` the glyph is the key instead (the hub's key counter, a key node's price); set `text` after `amount`
## to show a word in place of the number ("KEY", "1 KEY").

@export var amount := 0:
	set(v):
		amount = v
		_label.text = str(v)
@export var dim := false:
	set(v):
		dim = v
		_paint()
@export var style := &"HudNumber":
	set(v):
		style = v
		_paint()
@export var key := false:
	set(v):
		key = v
		_coin.key = v
## What the label shows: `amount`, unless set to something else after it.
var text: String:
	get:
		return _label.text
	set(v):
		_label.text = v

var _coin := UiCoin.new()
var _label := Label.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_child(_coin)
	add_child(_label)
	_coin.size_flags_vertical = SIZE_SHRINK_CENTER
	_label.text = "0"
	_paint()


func _paint() -> void:
	_label.theme_type_variation = style
	var px := UiTheme.build().get_font_size(&"font_size", style)
	_coin.side = maxf(6.0, roundf(px / 4.0))
	_coin.dim = dim
	add_theme_constant_override(&"separation", int(maxf(6.0, _coin.side * 0.8)))
	if dim:
		_label.add_theme_color_override(&"font_color", Palette.TEXT_DIM)
	else:
		UiTheme.light(_label, Palette.COINS)
