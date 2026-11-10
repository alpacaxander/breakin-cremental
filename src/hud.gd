extends Node
## The fight's two run columns, read from the arena every frame: left YOU (HP bar, gold, phase, damage this phase, balls
## in play, the next ball, red bricks on the board, the combo relic's multiplier, the relic icons), right BAG (the queue in
## launch order with rank pips, the discard count, DISCARD). The reward overlay and end screens are main.gd's.

const Tuning = preload("res://src/tuning.gd")
const Ui = preload("res://src/ui.gd")
const Fx = preload("res://src/fx.gd")

var arena  # the fight (arena.gd), read each frame; untyped so the two scripts need not preload each other
var hp_bar: ColorRect
var hp_l: Label
var gold_l: Label
var phase_l: Label
var dmg_l: Label
var play_l: Label
var next_l: Label
var red_l: Label
var combo_l: Label
var combo_x: Label  # the multiplier, inside the combo_chase tube (combo_s)
var combo_s: AnimatedSprite2D
var spent_l: Label
var queue: Control  # the bag rows, rebuilt when the bag changes
var queue_key := ""


## Positions are sprite px inside the columns (see ui.gd).
func _init(a: Node2D, ui: Ui.Root) -> void:
	arena = a
	var C := Tuning.COLORS
	var L := ui.left
	hp_bar = Ui.hp_bar(L, 6, 22, 1.0)
	hp_l = Ui.label(L, "", 16, 23, C.pay)
	Ui.icon(L, "coin", 6, 38)
	gold_l = Ui.label(L, "", 16, 39, C.pay)
	phase_l = Ui.label(L, "", 6, 56, C.rivet)
	Ui.label(L, "DAMAGE", 6, 70, C.rivet)
	dmg_l = Ui.label(L, "", 6, 78, C.pay, 3)
	play_l = Ui.label(L, "", 6, 100, C.white)
	next_l = Ui.label(L, "", 6, 110, C.white, 1, 66)
	red_l = Ui.label(L, "", 6, 124, C.danger)
	combo_l = Ui.label(L, "COMBO", 6, 131, C.pay)
	combo_s = Fx.play(L, "combo_chase", 30, 8, Vector2(55, 134), 0, true)
	combo_s.scale = Vector2.ONE  # the column is already 2x
	combo_x = Ui.label(L, "", 40, 131, C.pay, 1, 30, HORIZONTAL_ALIGNMENT_CENTER)
	combo_x.z_index = 2  # over the strip's z 1
	for i in Game.run.relics.size():  # ponytail: rows of five below the lines, not under the gold as docs/content.md says: the phase lines sit there
		Ui.icon(L, "relic_%s" % Game.run.relics[i], 6 + 13 * (i % 5), 142 + 13 * (i / 5))
	var R := ui.right
	queue = Control.new()
	R.add_child(queue)
	spent_l = Ui.label(R, "", Ui.RX + 6, 288, C.rivet)
	Ui.button(R, "DISCARD", Ui.RX + 6, 300, 66, 24, func(): if arena.rest and not arena.discarded and not arena.over: arena._discard(), false, 2, "")
	Ui.label(R, "D DISCARD", Ui.RX + 6, 328, C.rivet)


func _process(_delta: float) -> void:
	var run: Dictionary = Game.run
	hp_l.text = str(run.hp)
	hp_bar.size.x = 68.0 * run.hp / run.hp_max
	gold_l.text = str(run.gold)
	phase_l.text = "PHASE %d" % arena.phase
	dmg_l.text = str(arena.phase_dmg)
	play_l.text = "IN PLAY %d" % arena.in_play()
	next_l.text = "NEXT: %s" % Tuning.BALLS[arena.rest.id].name if arena.rest else ("NEXT: %s" % Tuning.BALLS[arena.bag[0].id].name if arena.bag else "BAG EMPTY")
	var reds: int = arena._bricks("red").size()
	red_l.text = "RED BRICKS %d" % reds if reds else ""
	var on: bool = arena.combo > 0
	combo_x.text = "x%.2f" % arena.combo_mult() if on else ""
	combo_l.visible = on
	combo_s.visible = on
	spent_l.text = "SPENT %d" % arena.discard.size()
	var rows: Array = ([{id = arena.rest.id, rank = arena.rest.rank}] if arena.rest else []) + arena.bag
	var key := str(rows)
	if key != queue_key:
		queue_key = key
		for c in queue.get_children():
			c.free()
		Ui.bag_rows(queue, rows, true)
