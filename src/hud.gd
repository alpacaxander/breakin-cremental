extends Node
## The round's score column (cash, combo, timer, best), refreshed from the arena every frame, and the result panel.

const Tuning = preload("res://src/tuning.gd")
const Ui = preload("res://src/ui.gd")

var arena  # the round (arena.gd), read each frame; untyped so the two scripts need not preload each other
var cash_l: Label
var extra_l: Label
var boost_l: Label
var combo_l: Label
var bar: ColorRect
var mult_l: Label
var time_l: Label
var best_l: Label


## Positions are sprite px inside the score column (see ui.gd).
func _init(a: Node2D, ui: Control) -> void:
	arena = a
	var C := Tuning.COLORS
	cash_l = Ui.cash(ui, 0, Game.currency)
	extra_l = Ui.label(ui, "", 6, 44, C.cream)
	boost_l = Ui.label(ui, "", 6, 52, C.cream)
	Ui.label(ui, "COMBO", 6, 60, C.rivet)
	combo_l = Ui.label(ui, "-", 6, 68, C.rivet, 4)
	combo_l.pivot_offset = Vector2(0, 10)
	Ui.rect(ui, 6, 92, 68, 3, C.trim_lo)
	bar = Ui.rect(ui, 6, 92, 0, 3, C.pay)
	mult_l = Ui.label(ui, "", 6, 98, C.rivet)
	Ui.label(ui, "TIME", 6, 108, C.rivet)
	time_l = Ui.label(ui, "", 6, 116, C.cream, 3)
	best_l = Ui.label(ui, "", 6, 138, C.rivet)
	Ui.label(ui, "LEVEL %d" % (a.level + 1), 6, 146, C.rivet)


func _process(_delta: float) -> void:
	var C := Tuning.COLORS
	cash_l.text = Ui.money(Game.currency)
	extra_l.text = "+%d" % arena.earned if arena.earned else ""
	boost_l.text = "x%d FOR %d" % [arena.boost_mult, arena.boost_hits] if arena.boost_hits > 0 else ""
	combo_l.text = "x%d" % arena.combo if arena.combo else "-"
	combo_l.add_theme_color_override("font_color", C.pay if arena.combo else C.rivet)
	bar.size.x = 68 * clampf(arena.combo_timer / Game.combo_window(arena.combo), 0, 1) if arena.combo else 0.0
	mult_l.text = "x%.2f PAY" % Game.combo_mult(arena.combo) if arena.combo > 1 else ""
	var t := maxf(arena.time_left, 0)
	time_l.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	time_l.add_theme_color_override("font_color", C.danger if arena.launched and t < 5 else C.cream)
	best_l.text = "BEST x%d" % arena.best_combo if arena.best_combo > 1 else ""


## The combo counter jumps on each break.
func pop_combo() -> void:
	create_tween().tween_property(combo_l, "scale", Vector2.ONE, 0.25).from(Vector2.ONE * 1.5)


func result(msg: String, cleared: bool, unlocked: bool) -> void:
	var C := Tuning.COLORS
	var r := Ui.overlay(0.6)
	Ui.bulbs(r, 4)
	Ui.panel(r, 200, 118, 240, 112)
	Ui.centre(r, msg, 128, C.cream)
	Ui.centre(r, "+$%s" % Ui.money(arena.earned), 140, C.pay, 4)
	Ui.centre(r, "x%d BEST COMBO" % arena.best_combo, 166, C.white)
	if cleared and arena.level == Tuning.LEVELS.size() - 1:
		Ui.centre(r, "YOU WIN!", 176, C.mint)
	elif unlocked:
		Ui.centre(r, "LEVEL %d UNLOCKED" % (arena.level + 2), 176, C.mint)
	Ui.button(r, "CONTINUE", 272, 194, 96, 20, arena.done.emit, true)
	add_child(r)
