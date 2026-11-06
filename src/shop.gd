extends Node
## Between rounds: the upgrade web in the field, stats in the left column, the selected upgrade and level select on the right.

signal play(level: int)
signal menu

const Tuning = preload("res://src/tuning.gd")
const Ui = preload("res://src/ui.gd")
const Fx = preload("res://src/fx.gd")
const Sfx = preload("res://src/sfx.gd")

var selected: String = Tuning.SEED_UPGRADE
var level := 0
var root: Ui.Root


## Dashed links between revealed nodes; the node buttons and rank pips are its children.
class Web extends Control:
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for id in Tuning.UPGRADES:
			var u: Dictionary = Tuning.UPGRADES[id]
			for l in u.links:
				if Game.is_revealed(id) and Game.is_revealed(l):
					draw_dashed_line(u.pos, Tuning.UPGRADES[l].pos, Tuning.COLORS.pay if Game.rank(id) and Game.rank(l) else Tuning.COLORS.pay_dim, 1.0, 3.0, false)


func _ready() -> void:
	level = Game.unlocked
	Sfx.loop(self, "lamp_hum")
	_build()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_SPACE:
		Sfx.play("ui_start")
		play.emit(level)


# ponytail: the whole screen is rebuilt on every change. Fine for a dozen nodes.
func _build() -> void:
	if root:
		root.queue_free()
	root = Ui.chassis("STATS", "UPGRADE")
	root.back.connect(menu.emit)
	add_child(root)
	var C := Tuning.COLORS

	# Left: cash, owned upgrades, reset and menu.
	Ui.cash(root, 0, Game.currency)
	if Game.won:
		Ui.label(root, "YOU WIN!", 6, 44, C.pay)
	Ui.label(root, "OWNED", 6, 52, C.rivet)
	var i := 0
	for id in Tuning.UPGRADES:
		if Game.rank(id) == 0:
			continue
		var maxed: bool = Game.rank(id) >= Tuning.UPGRADES[id].ranks
		Ui.label(root, Tuning.UPGRADES[id].name, 6, 60 + i * 8, C.white)
		Ui.label(root, "%d/%d" % [Game.rank(id), Tuning.UPGRADES[id].ranks], 60, 60 + i * 8, C.pay if maxed else C.cream)
		i += 1
	# ponytail: instant wipe, no confirm. It's a tuning tool.
	Ui.button(root, "RESET", 6, 316, 66, 14, func(): Game.reset(); _build(), false, 1, "ui_back")
	Ui.button(root, "MENU", 6, 334, 66, 14, menu.emit, false, 1, "ui_back")

	# Field: the web. Node lamps, icons, then rank pips on top.
	Ui.centre(root, "UPGRADE WEB", 6, C.rivet)
	var web := Web.new()
	root.add_child(web)
	for id in Tuning.UPGRADES:
		if Game.is_revealed(id):
			_node(web, id, Tuning.UPGRADES[id].pos - Vector2(15, 6)).pressed.connect(func(): Sfx.play("ui_click"); selected = id; _build())
	for id in Tuning.UPGRADES:
		if not Game.is_revealed(id):
			continue
		var u: Dictionary = Tuning.UPGRADES[id]
		var dim := Game.rank(id) == 0
		for p in u.ranks:
			var on: bool = p < Game.rank(id)
			Ui.rect(web, u.pos.x - ((u.ranks * 3 - 1) >> 1) + p * 3, u.pos.y + 2, 2, 2, (C.pay_dim if dim else C.pay_hi) if on else (C.pay_off if dim else C.pay_dim))
	Fx.play(web, "hover_outline_34x16", 34, 8, Tuning.UPGRADES[selected].pos, 0, true).scale = Vector2.ONE

	# Right: the selected upgrade, then level select.
	var u: Dictionary = Tuning.UPGRADES[selected]
	var maxed: bool = Game.rank(selected) >= u.ranks
	_node(root, selected, Vector2(Ui.RX + 24, 20))
	var text := VBoxContainer.new()
	text.position = Vector2(Ui.RX + 6, 36)
	text.size.x = 66
	text.add_theme_constant_override("separation", 2)
	root.add_child(text)
	Ui.label(text, u.name, 0, 0, C.white, 2, 66)
	Ui.label(text, u.desc, 0, 0, C.rivet, 1, 66)
	Ui.label(root, "RANK", Ui.RX + 6, 86, C.rivet)
	Ui.pips(root, Ui.RX + 28, 86, u.ranks, Game.rank(selected), "ui_pip_pay")
	Ui.icon(root, "coin", Ui.RX + 6, 98)
	Ui.label(root, "MAX" if maxed else str(Game.cost(selected)), Ui.RX + 18, 96, C.pay, 2)
	Ui.button(root, "BUY", Ui.RX + 6, 112, 66, 18, _buy.bind(1), true, 2, "").disabled = not Game.can_buy(selected)
	Ui.button(root, "BUY MAX", Ui.RX + 6, 134, 66, 14, _buy.bind(u.ranks), false, 1, "").disabled = not Game.can_buy(selected)
	Ui.rect(root, Ui.RX + 3, 154, 72, 1, C.rivet)
	Ui.label(root, "LEVEL", Ui.RX + 6, 160, C.rivet)
	for l in Tuning.LEVELS.size():
		Ui.button(root, str(l + 1), Ui.RX + 6 + (l % 2) * 35, 170 + (l / 2) * 22, 31, 18, func(): level = l; _build(), l == level).disabled = l > Game.unlocked
	var y := 174 + ((Tuning.LEVELS.size() + 1) / 2) * 22
	var L: Dictionary = Tuning.LEVELS[level]
	Ui.label(root, "LEVEL %d" % (level + 1), Ui.RX + 6, y, C.white)
	Ui.label(root, "%d x %d %s" % [L.cols, L.rows, L.shape], Ui.RX + 6, y + 8, C.rivet)
	Ui.button(root, "PLAY", Ui.RX + 6, 300, 66, 24, play.emit.bind(level), true, 2, "ui_start")
	Ui.label(root, "SPACE", Ui.RX, 328, C.rivet, 1, 78, HORIZONTAL_ALIGNMENT_CENTER)


## A node lamp with its icon, as a button. Look from rank: dim, lit, max.
func _node(parent: Node, id: String, at: Vector2) -> TextureButton:
	var r := Game.rank(id)
	var maxed: bool = r >= Tuning.UPGRADES[id].ranks
	var b := TextureButton.new()
	b.texture_normal = Ui.tex("node_max" if maxed else "node_lit" if r else "node_dim")
	b.position = at
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	Ui.icon(b, "icon_" + id, 9, 3).modulate = Tuning.COLORS.pure_white if maxed else Tuning.COLORS.white if r else Tuning.COLORS.pay_dim
	return b


func _buy(n: int) -> void:
	var shown := Tuning.UPGRADES.keys().filter(Game.is_revealed).size()
	var r := Game.rank(selected)
	for i in n:
		Game.buy(selected)  # a no-op once it can't
	Sfx.play("ui_buy" if Game.rank(selected) > r else "ui_cant_afford")
	if Tuning.UPGRADES.keys().filter(Game.is_revealed).size() > shown:
		Sfx.play("ui_reveal", 1.0, 0.3)
	Game.save()
	_build()
