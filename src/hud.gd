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
var tbar: ColorRect
var best_l: Label
var shield_l: Label


## Positions are sprite px inside the score column (see ui.gd).
func _init(a: Node2D, ui: Ui.Root) -> void:
	arena = a
	var C := Tuning.COLORS
	cash_l = Ui.cash(ui.left, 0, Game.currency)
	extra_l = Ui.label(ui.left, "", 6, 44, C.cream)
	boost_l = Ui.label(ui.left, "", 6, 52, C.cream)
	Ui.label(ui.left, "COMBO" if Game.rank("combos") else "COMBO LOCKED", 6, 60, C.rivet)  # the Combos node turns combos on (arena.gd _break)
	combo_l = Ui.label(ui.left, "-", 6, 68, C.rivet, 4)
	combo_l.pivot_offset = Vector2(0, 10)
	Ui.rect(ui.left, 6, 92, 68, 3, C.trim_lo)
	bar = Ui.rect(ui.left, 6, 92, 0, 3, C.pay)
	mult_l = Ui.label(ui.left, "", 6, 98, C.rivet)
	Ui.label(ui.left, "TIME", 6, 108, C.rivet)
	time_l = Ui.label(ui.left, "", 6, 116, C.cream, 3)
	Ui.rect(ui.left, 6, 132, minf(68, arena.time_max * Tuning.TIME_BAR_PX), 3, C.trim_lo)
	tbar = Ui.rect(ui.left, 6, 132, 0, 3, C.cream)
	best_l = Ui.label(ui.left, "", 6, 138, C.rivet)
	Ui.label(ui.left, "LEVEL %d" % (a.level + 1), 6, 146, C.rivet)
	shield_l = Ui.label(ui.left, "", 6, 154, Tuning.CATS.round.lit)
	if Game.sandbox:
		Ui.label(ui.left, "SANDBOX", 6, 162, C.rivet)


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
	tbar.size.x = minf(68, t * Tuning.TIME_BAR_PX)
	tbar.color = time_l.get_theme_color("font_color")
	best_l.text = "BEST x%d" % arena.best_combo if arena.best_combo > 1 else ""
	shield_l.text = "SHIELD x%d" % arena.shields if arena.shields else ""


## The combo counter jumps on each break.
func pop_combo() -> void:
	create_tween().tween_property(combo_l, "scale", Vector2.ONE, 0.25).from(Vector2.ONE * 1.5)


func result(msg: String, cleared: bool, unlocked: bool) -> void:
	var C := Tuning.COLORS
	var r := Ui.overlay(0.6)
	Ui.bulbs(r, 4)
	Ui.panel(r, 160, 70, 320, 180)
	# The payout is the headline, counted up; how the round ended is the subline. A lost round is still a payout.
	var pay := Ui.centre(r, "+$0", 78, C.pay, 4)
	var id := pay.get_instance_id()
	create_tween().tween_method(func(v: int): if instance_from_id(id): instance_from_id(id).text = "+$%s" % Ui.money(v), 0, arena.earned, 0.8)
	Ui.centre(r, msg, 102, C.cream)
	Ui.centre(r, "x%d BEST COMBO" % arena.best_combo, 114, C.white)
	if cleared and arena.level == Tuning.LEVELS.size() - 1:
		Ui.centre(r, "YOU WIN!", 124, C.mint)
	elif unlocked:
		Ui.centre(r, "LEVEL %d UNLOCKED" % (arena.level + 2), 124, C.mint)
	# Left column: where the money came from. Right column: the biggest combo runs.
	Ui.label(r, "SOURCES", 170, 140, C.rivet)
	var y := 150
	for k in arena.tally:
		var v: int = arena.tally[k]
		if v == 0:
			continue
		var name: String = "BRICKS x%d" % (v / Tuning.LEVELS[arena.level].payout) if k == "bricks" else k.to_upper()
		Ui.label(r, name, 170, y, C.cream)
		Ui.label(r, "+$%s" % Ui.money(v), 170, y, C.pay, 1, 140, HORIZONTAL_ALIGNMENT_RIGHT)  # no share: the font has no "%"
		y += 10
	Ui.label(r, "COMBOS", 330, 140, C.rivet)
	var runs: Array = arena.combos.duplicate()
	runs.sort_custom(func(a, b): return a[1] > b[1])
	y = 150
	for run in runs.slice(0, 6):  # ponytail: top six by pay fit the panel; a scroll list if runs matter past that
		Ui.label(r, "x%d" % run[0], 330, y, C.cream)
		Ui.label(r, "+$%s" % Ui.money(run[1]), 330, y, C.pay, 1, 140, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 10
	if runs.is_empty():
		Ui.label(r, "NONE", 330, 150, C.rivet)
	Ui.button(r, "PLAY AGAIN", 214, 222, 96, 20, arena.again.emit, true, 2, "ui_start")
	Ui.button(r, "UPGRADES", 330, 222, 96, 20, arena.done.emit)
	add_child(r)
