extends Node
## Drives the run (and the menu's catalog of the balls and encounters met, Game.see): menu -> map -> the node's screen (a fight in arena.gd; the shop, an event or a treasure built here)
## -> map, until the boss falls (run won) or HP hits 0 (run over); the elite's death and the run's end set the meta-unlock
## flags (Game.unlock / Game.end_run). Every screen but the fight is a Ui.chassis with the run
## columns; reward and treasure are overlays over the fight or the map. The run autosaves (Game.save_run) on every screen
## change and never mid-fight, so CONTINUE on the menu resumes at the node entered (a fight restarts, a shop keeps its
## stock, an event its choice). The map, shop, event, fight and end screens form the play group: Esc opens the one pause
## dialog (RESUME / SETTINGS / MENU), and MENU drops the screen; a fight is abandoned, the last autosave stands.
## docs/content.md "Screens" is the contract.

const Ui = preload("res://src/ui.gd")
const Tuning = preload("res://src/tuning.gd")
const Sfx = preload("res://src/sfx.gd")
const Fx = preload("res://src/fx.gd")
const END_ROWS := 9  # bag rows the end screen lists before "+N MORE"
const PICK_CUES := {ball = "ui_buy", rank = "ui_unlock", relic = "cond_primed", gold = "coin_cascade"}  # per reward card kind


var zoom := 0.0  # the cabinet's scale k: a sprite px is 2k screen px
var group := false  # in a run screen or a fight: Esc pauses
var pause: Control = null


func _ready() -> void:
	get_tree().auto_accept_quit = false  # the window's close button goes through Sfx.quit too
	get_window().size_changed.connect(_scale)
	_scale()
	_show_menu()


func _process(delta: float) -> void:
	if group and Game.run:
		Game.run.stats.seconds += delta  # the end screen's TIME; a paused tree stops this too


## The scale at which 1280x720 just fits, with the canvas covering the whole window: the cabinet grows with the window and
## the padding beside the columns is drawn sheet, not bars. Godot's own stretch modes letterbox instead. Below 1280x720
## (a tiling window manager ignores any minimum size) the canvas keeps its 720 height, so the 2x columns always fit, and
## Ui.Root.content shrinks the field to the width left between them. The cursor follows: it is in screen px, not sprite px.
func _scale() -> void:
	var w := get_window()
	var k := minf(w.size.y / 720.0, maxf(1, w.size.x / 1280.0))
	if k == zoom:
		return
	zoom = k
	w.content_scale_factor = k
	var cursor := Ui.tex("ui_cursor").get_image()
	cursor.resize(roundi(16 * k), roundi(16 * k), Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(cursor))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Sfx.quit()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)  # else the cursor texture outlives the renderer and logs a leak at quit


# --- Menu ---

func _show_menu() -> void:
	group = false
	var r := Ui.chassis()
	Sfx.loop(r, "lamp_hum")
	Ui.bulbs(r, 4)
	var logo := Ui.tex("title_logo")
	Ui.icon(r, logo, 320 - logo.get_width() / 2, 50)
	# Logo above a pause-sized card of stacked buttons; CONTINUE joins them while a saved run exists.
	var saved := Game.has_run()
	Ui.panel(r, 240, 140, 160, 106 + (24 if saved else 0))
	var y := 150
	if saved:
		Ui.button(r, "CONTINUE", 260, y, 120, 18, _continue, true, 2, "ui_start")
		y += 24
	Ui.button(r, "PLAY", 260, y, 120, 18, _confirm_new if saved else _new_run, not saved, 2, "ui_start" if not saved else "ui_click")
	Ui.button(r, "CATALOG", 260, y + 24, 120, 18, _show_catalog)
	Ui.button(r, "SETTINGS", 260, y + 48, 120, 18, func(): _swap(Ui.settings(_show_menu)))
	Ui.button(r, "QUIT", 260, y + 72, 120, 18, Sfx.quit, false, 2, "")
	Ui.centre(r, "BREAK THE BOARD. BEAT THE BOSS.", 300, Tuning.COLORS.rivet)
	var meta: Dictionary = Game.settings.meta
	if meta.runs:
		Ui.centre(r, "RUNS %d  WINS %d" % [meta.runs, meta.wins], 312, Tuning.COLORS.trim_hi)
	for i in 6:
		Ui.icon(r, "brick_plain_lit" if i % 3 == 0 else "brick_plain_dim", 230 + i * 32, 330)
	_swap(r)


## Every ball and encounter, the ones met in any run (Game.see) in full, the rest as a dark silhouette named "???". Two pages:
## balls, a 4-wide grid of face at 2x, name, card line, damage per rank; encounters, rows of the band's idle frame 0, name, role, HP (summed over organs),
## every organ's intents, wrapped to the field's width.
func _show_catalog(enemies := false) -> void:
	var C := Tuning.COLORS
	var seen: Array = Game.settings.meta.get("seen", [])
	var r := Ui.chassis()
	var ids: Array = Tuning.encounters() if enemies else Tuning.BALLS.keys()
	Ui.centre(r, "CATALOG: %s %d/%d" % ["ENEMIES" if enemies else "BALLS", ids.filter(func(id): return id in seen).size(), ids.size()], 14, C.pay, 2)
	var ex := 96.0
	var ey := 40.0
	for i in ids.size():
		var id: String = ids[i]
		var met: bool = id in seen
		if not enemies:
			var row: Dictionary = Tuning.BALLS[id]
			var x := 92 + 118 * (i % 4)
			var y := 46 + 40 * (i / 4)
			var t := Ui.face({id = id, rank = 1})
			var f := Ui.icon(r, t, x + 12 - t.get_width(), y + 12 - t.get_height())
			f.scale = Vector2.ONE * Fx.SCALE
			if not met:
				f.modulate = C.trim
			Ui.label(r, row.name if met else "???", x + 28, y, C.white)
			if met:
				Ui.label(r, row.desc, x + 28, y + 7, C.rivet, 1, 80)
				Ui.label(r, "DMG " + "/".join(row.dmg.map(func(d): return str(d))) if row.rarity != "none" else "DMG 0", x + 28, y + 25, C.pay)
			elif not Game.unlocked(id):
				Ui.label(r, "LOCKED", x + 28, y + 7, C.trim_hi)
			continue
		var e: Dictionary = Tuning.encounter(id)
		if ex + e.w > Ui.FIELD_X + 480 - 16:  # past the field's right edge: the next row
			ex = 96.0
			ey += 84
		var f := Ui.icon(r, Fx.frame("%s_idle" % e.band, e.w, 0), ex, ey)
		if not met:
			f.modulate = C.trim
		Ui.label(r, id.to_upper().replace("_", " ") if met else "???", ex, ey + 52, C.white, 1, e.w, HORIZONTAL_ALIGNMENT_CENTER)
		if met:
			Ui.label(r, "TIER %d" % e.tier if e.role == "regular" else e.role.to_upper(), ex, ey + 59, C.rivet, 1, e.w, HORIZONTAL_ALIGNMENT_CENTER)
			Ui.label(r, "HP %d" % e.organs.reduce(func(s, o): return s + Tuning.organ(o).hp, 0), ex, ey + 66, C.pay, 1, e.w, HORIZONTAL_ALIGNMENT_CENTER)
			var icons := []
			for o in e.organs:
				icons += Tuning.organ(o).intents.map(func(it): return it[0])
			var n := icons.size()
			for j in n:
				Ui.icon(r, "intent_%s" % icons[j], ex + e.w / 2.0 - 6.5 * n + 13 * j, ey + 74)
		ex += e.w + 8  # ponytail: 8 px gaps keep 16 encounters on three rows; pages when the next one overflows
	Ui.button(r, "BACK", 200, 330, 112, 18, _show_menu, false, 2, "ui_back")
	Ui.button(r, "BALLS" if enemies else "ENEMIES", 328, 330, 112, 18, _show_catalog.bind(not enemies))
	r.back.connect(_show_menu)
	_swap(r)


func _confirm_new() -> void:
	var d := Ui.dialog("ABANDON RUN?", [["ABANDON", false, _new_run], ["BACK", true, _show_menu]])
	d.back.connect(_show_menu)
	add_child(d)


func _new_run() -> void:
	Game.delete_run()
	Game.new_run()
	_back_to_map()


## Resumes the saved run at the node it stood on; a fight restarts, the rest reopen.
func _continue() -> void:
	if not Game.load_run():
		_show_menu()
		return
	group = true
	match Game.run.pending:
		"": _show_map()
		"shop": _show_shop()
		"event": _show_event()
		"treasure":
			_show_map()
			_show_treasure()
		_: _play()


# --- Map ---

## The map with the node resolved: clears pending, drops the shop stock, saves.
func _back_to_map() -> void:
	Game.run.pending = ""
	Game.run.erase("shop")
	Game.save_run()
	_show_map()


## Nodes per Tuning.MAP at x = MAP_X + MAP_DX * layer, y spread evenly; edges beneath them, the walked ones pay; the next
## layer's reachable nodes lit and ringed, visited ones half, the rest dim; the ball marks the node stood on.
func _show_map() -> void:
	group = true
	var C := Tuning.COLORS
	var m: Dictionary = Game.run.map
	var r := _run_chassis("MAP", "NODE %d/%d" % [m.layer + 1, Tuning.MAP.size()])
	Ui.label(r.left, "LEGEND", 6, 120, C.rivet)
	var i := 0
	for k in Tuning.MAP_LEGEND:
		var big: bool = k == "boss"
		Ui.icon(r.left, "map_node_%s" % k, 4 if big else 6, 128 + 12 * i - (2 if big else 0))
		Ui.label(r.left, Tuning.MAP_LEGEND[k], 22, 131 + 12 * i, C.white)
		i += 1
	var lines := Ui.Lines.new()
	r.add_child(lines)
	for L in Tuning.MAP.size() - 1:
		for s in Tuning.MAP[L].slots.size():
			for t in Tuning.MAP[L].edges[s]:
				var walked: bool = L < m.layer and m.path[L] == s and m.path[L + 1] == t
				lines.segs.append([_node_pos(L, s), _node_pos(L + 1, t), C.pay if walked else C.trim_hi])
	for L in Tuning.MAP.size():
		for s in Tuning.MAP[L].slots.size():
			var p := _node_pos(L, s)
			var reach: bool = L == m.layer + 1 and Game.reachable(s)
			var visited: bool = L <= m.layer and m.path[L] == s
			var kind: String = m.layers[L][s]
			var w := 16 if kind == "boss" else 12
			var ic := Ui.icon(r, "map_node_%s" % kind, p.x - w / 2, p.y - w / 2)
			ic.modulate.a = 1.0 if reach else 0.5 if visited else 0.35
			if reach:
				Fx.play(r, "map_ring_pulse", 16, 8, p, 0, true).scale = Vector2.ONE
			var h := Ui.hotspot(r, p.x - 10, p.y - 10, 20, 20, _pick_node.bind(s) if reach else Sfx.play.bind("ui_invalid"), "ui_start" if reach else "")
			if reach:
				h.mouse_entered.connect(Sfx.play.bind("ui_hover"))
	Sfx.play("ui_unpause")
	Sfx.play("ui_reveal", 0.8, 0.3)  # the next layer lights
	if m.layer >= 0:
		var here := _node_pos(m.layer, m.node)
		Ui.icon(r, "ball", here.x - 4, here.y - 16)
	_swap(r)


func _node_pos(layer: int, slot: int) -> Vector2:
	var n: int = Tuning.MAP[layer].slots.size()
	return Vector2(Ui.FIELD_X + Tuning.MAP_X + Tuning.MAP_DX * layer, Ui.SIZE.y * (slot + 1) / (n + 1))


func _pick_node(slot: int) -> void:
	var kind := Game.enter_node(slot)
	match kind:
		"shop":
			Sfx.play("ui_unpause")
			_show_shop()
		"event":
			Sfx.play("mystery_reel")
			_show_event()
		"treasure":
			_show_map()
			_show_treasure()
		_:
			_play()


## A chassis with the run columns and the field's title line (rivet) and subtitle (pay, 2x).
func _run_chassis(title: String, sub := "", on_pick := Callable()) -> Ui.Root:
	var r := Ui.chassis("YOU", "BAG %d" % Game.run.bag.size())
	Ui.run_columns(r, on_pick)
	Ui.centre(r, title, 6, Tuning.COLORS.rivet)
	if sub:
		Ui.centre(r, sub, 16, Tuning.COLORS.pay, 2)
	return r


# --- Fight, reward, treasure ---

func _play() -> void:
	var m: Dictionary = Game.run.map
	var a = preload("res://src/arena.gd").new()
	a.encounter_id = m.enemies[m.layer][m.node]
	a.done.connect(_fight_done)
	group = true
	_swap(a)


## After the end beat: a loss is the run over, the boss down is the run won, else gold and the reward cards over the
## arena (an elite's reward is followed by three relic cards).
func _fight_done(win: bool) -> void:
	var m: Dictionary = Game.run.map
	var kind: String = m.layers[m.layer][m.node]
	if not win or kind == "boss":
		Game.end_run(win)
		_show_end(win)
		return
	if kind == "elite":
		Game.unlock("killed_elite")
	var r := Game.node_rng(1)
	var G: Array = Tuning.GOLD[kind]
	var gold: int = G[0] + r.randi_range(0, G[1])
	Game.add_gold(gold)
	Sfx.play("round_clear")
	Sfx.play("coin", 1.0, 0.3)
	_show_reward("VICTORY", Game.roll_reward(r), gold, true, _show_treasure.bind(1) if kind == "elite" else _back_to_map)


## Three relic cards, no skip; the salt keeps an elite's relics apart from its reward roll.
func _show_treasure(salt := 0) -> void:
	var cards := Game.roll_relics(Game.node_rng(2 + salt), 3).map(func(id): return {kind = "relic", id = id})
	Sfx.play("lock_open")
	_show_reward("TREASURE", cards, 0, cards.is_empty(), _back_to_map)  # ponytail: no relic left shows an empty panel with SKIP


## The reward overlay: cards from Game.roll_reward, one pick (saved) or SKIP, then `then`.
func _show_reward(title: String, cards: Array, gold: int, skip: bool, then: Callable) -> void:
	var C := Tuning.COLORS
	var r := Ui.overlay(0.6)
	Ui.panel(r, 160, 70, 320, 180)
	Ui.centre(r, title, 78, C.pay, 2)
	Ui.centre(r, "PICK ONE", 96, C.rivet)
	if gold:
		Ui.icon(r, "coin", 416, 78)
		Ui.label(r, "+%d GOLD" % gold, 426, 79, C.pay)
	var x0: float = 320 - 40 * (cards.size() - 1)
	if cards:
		Sfx.play("mystery_reel", 1.3, 0.2)
	for i in cards.size():
		var c: Dictionary = cards[i]
		var look := _card_look(c)
		var cx := x0 + 80 * i
		var pick := func():
			Game.take_reward(c)
			Game.save_run()
			Sfx.play(PICK_CUES[c.kind], 1.0, 0.1)
			if c.kind == "relic":  # the card flips face up before the overlay goes; the cover blocks a second pick meanwhile
				Ui.rect(r, 0, 0, Ui.SIZE.x, Ui.SIZE.y, Color.TRANSPARENT).mouse_filter = Control.MOUSE_FILTER_STOP
				var s := Fx.play(r, "relic_get", 36, 12, Vector2(cx, 132))
				s.scale = Vector2.ONE
				await s.animation_finished
			r.queue_free()
			then.call()
		Ui.card(r, cx, 108, look[0], look[1], look[2], pick, c.kind == "rank")
	if skip:
		Ui.button(r, "SKIP", 272, 224, 96, 20, func(): r.queue_free(); then.call())
	add_child(r)


## A reward card's face, name and description.
func _card_look(c: Dictionary) -> Array:
	match c.kind:
		"ball":
			var row: Dictionary = Tuning.BALLS[c.id]
			return [Ui.face({id = c.id, rank = 1}), row.name, "BALL\nDMG %d\n%s" % [row.dmg[0], row.desc]]
		"rank":
			var b: Dictionary = Game.run.bag[c.at]
			var row: Dictionary = Tuning.BALLS[b.id]
			return [Ui.face(b), row.name, "RANK UP\nDMG %d TO %d" % [row.dmg[b.rank - 1], row.dmg[b.rank]]]
		"relic":
			return [Ui.tex("relic_%s" % c.id), Tuning.RELICS[c.id].name, "RELIC\n" + Tuning.RELICS[c.id].desc]
	return [Ui.tex("coin"), "GOLD", "+%d GOLD" % c.gold]


# --- Shop ---

## The pawn shop: the stock rolled once per visit (kept in run.shop, so a reload shows the same), ball and relic cards with
## prices, REMOVE (pick a bag row), HEAL once, BUY BACK (the last ball removed this run, run.removed, at half price), LEAVE.
## Rebuilt on every change; removing = the bag rows are pickable.
func _show_shop(removing := false) -> void:
	group = true
	var C := Tuning.COLORS
	var S := Tuning.SHOP
	var run: Dictionary = Game.run
	if not run.has("shop"):
		run.shop = Game.roll_shop(Game.node_rng())
		run.shop.healed = false
	Game.save_run()
	var shop: Dictionary = run.shop
	var r := _run_chassis("SHOP", "PAWN SHOP", _remove_pick if removing else Callable())
	Sfx.loop(r, "lamp_hum")
	for i in shop.balls.size():
		var row: Dictionary = Tuning.BALLS[shop.balls[i]]
		var cx: float = Ui.FIELD_X + 90 + 80 * i
		Ui.card(r, cx, 40, Ui.face({id = shop.balls[i], rank = 1}), row.name, "DMG %d" % row.dmg[0], _buy.bind("balls", i, S.ball))
		_price(r, cx, 124, S.ball)
	for i in shop.relics.size():
		var id: String = shop.relics[i]
		var cx: float = Ui.FIELD_X + 370 + 80 * i
		Ui.card(r, cx, 40, Ui.tex("relic_%s" % id), Tuning.RELICS[id].name, Tuning.RELICS[id].desc, _buy.bind("relics", i, Game.relic_price(id)))
		_price(r, cx, 124, Game.relic_price(id))
	Ui.rect(r, 87, 150, 466, 1, C.trim_hi)
	Ui.label(r, "REMOVE A BALL", 90, 165, C.white)
	_price(r, 380, 164, S.remove)
	Ui.button(r, "REMOVE", Ui.FIELD_X + 344, 160, 96, 18, _remove_mode, false, 1, "")
	Ui.label(r, "HEAL +%d HP" % S.heal_hp, 90, 189, C.white)
	_price(r, 380, 188, S.heal)
	var heal := Ui.button(r, "HEAL", Ui.FIELD_X + 344, 184, 96, 18, _heal, false, 1, "")
	heal.disabled = shop.healed or run.hp >= run.hp_max
	var back: String = run.get("removed", "")  # get: a run.json saved before the pawn shop has no field
	Ui.label(r, "BUY BACK %s" % (Tuning.BALLS[back].name if back else "NOTHING"), 90, 213, C.white)
	_price(r, 380, 212, S.buy_back)
	Ui.button(r, "BUY BACK", Ui.FIELD_X + 344, 208, 96, 18, _buy_back, false, 1, "").disabled = back == ""
	Ui.centre(r, "PICK A BALL TO REMOVE" if removing else "", 234, C.rivet)
	Ui.button(r.right, "LEAVE", Ui.RX + 6, 300, 66, 24, _back_to_map, true, 2, "ui_back")
	_swap(r)


## A coin and a price centred on cx.
func _price(parent: Node, cx: float, y: float, n: int) -> void:
	Ui.icon(parent, "coin", cx - 10, y)
	Ui.label(parent, str(n), cx, y + 1, Tuning.COLORS.pay)


## Buys run.shop[list][i] at price: the card goes, the ball joins the bag or the relic the belt.
func _buy(list: String, i: int, price: int) -> void:
	if not Game.spend(price):
		Sfx.play("ui_cant_afford")
		return
	var id: String = Game.run.shop[list].pop_at(i)
	if list == "balls":
		Game.add_ball(id)
	else:
		Game.run.relics.append(id)
	Sfx.play("ui_buy")
	_show_shop()


func _remove_mode() -> void:
	if Game.run.gold < Tuning.SHOP.remove:
		Sfx.play("ui_cant_afford")
		return
	Sfx.play("ui_click")
	_show_shop(true)


func _remove_pick(i: int) -> void:
	if not Game.remove_ball(i):
		Sfx.play("ui_invalid")  # the last non-junk ball stays
		return
	Game.spend(Tuning.SHOP.remove)
	Sfx.play("teleport_in", 0.8)
	_show_shop()


func _buy_back() -> void:
	if not Game.spend(Tuning.SHOP.buy_back):
		Sfx.play("ui_cant_afford")
		return
	Game.add_ball(Game.run.removed)
	Game.run.removed = ""
	Sfx.play("ui_buy")
	_show_shop()


func _heal() -> void:
	if not Game.spend(Tuning.SHOP.heal):
		Sfx.play("ui_cant_afford")
		return
	Game.heal(Tuning.SHOP.heal_hp)
	Game.run.shop.healed = true
	Sfx.play("grow")
	Sfx.play("coin", 0.8, 0.1)
	_show_shop()


# --- Event ---

## The node's event: title, body and two choices; after a choice (applied and saved at once, so a reload lands on the
## map) the body is the result line and CONTINUE returns to the map.
func _show_event(result := "") -> void:
	group = true
	var C := Tuning.COLORS
	var m: Dictionary = Game.run.map
	var id: String = m.events[m.layer][m.node]
	var E: Dictionary = Tuning.EVENTS[id]
	var r := _run_chassis("EVENT")
	Ui.panel(r, 120, 60, 400, 230)
	Ui.label(r, E.title, 136, 72, C.pay, 2, 368, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.label(r, result if result else E.body, 136, 110, C.white, 1, 368, HORIZONTAL_ALIGNMENT_CENTER)
	if result:
		Ui.button(r, "CONTINUE", 272, 250, 96, 20, _back_to_map, true, 2, "ui_reveal")
	else:
		var a := Ui.button(r, E.a, 136, 220, 368, 18, _choose.bind(id, "a"), false, 1)
		a.disabled = not Game.event_can(id, "a")
		Ui.button(r, E.b, 136, 244, 368, 18, _choose.bind(id, "b"), false, 1).disabled = not Game.event_can(id, "b")
	_swap(r)


## The outcome cue: a junk ball joining teleport_out, anything gained (gold, HP, a relic, a rank) ui_unlock, else ui_cant_afford.
## ponytail: judged by diffing the run, not tagged per outcome in Tuning.EVENTS; tag them if an event gains and loses the same thing.
func _choose(id: String, which: String) -> void:
	var run: Dictionary = Game.run
	var ranks := func(): return run.bag.reduce(func(n, b): return n + b.rank, 0)
	var was := [run.gold, run.hp, run.relics.size(), ranks.call(), run.bag.size()]
	var line := Game.event_choice(id, which)
	if run.bag.size() > was[4]:
		Sfx.play("teleport_out", 0.5)
	elif run.gold > was[0] or run.hp > was[1] or run.relics.size() > was[2] or ranks.call() > was[3]:
		Sfx.play("ui_unlock", 1.0, 0.1)
	else:
		Sfx.play("ui_cant_afford", 0.8, 0.1)
	Game.run.pending = ""
	Game.save_run()
	_show_event(line)


# --- End ---

## Run over or run won: the title, how it ended, the stats, the bag and relics, NEW RUN / MENU. Deletes run.json.
## Game.end_run has already counted the run and set its flags; this only shows them ("UNLOCKED:" lists run.unlocked).
## ponytail: the numbers show at once; the 0.8 s tick-up is not here.
func _show_end(win: bool) -> void:
	group = true
	Game.delete_run()
	var C := Tuning.COLORS
	var run: Dictionary = Game.run
	var st: Dictionary = run.stats
	var r := Ui.chassis()
	Sfx.play("run_won" if win else "run_over")
	Ui.centre(r, "RUN WON" if win else "RUN OVER", 40, C.pay if win else C.white, 4)
	if not win:
		Ui.rect(r, 256, 62, 128, 1, C.danger)
	var name := func(id: String) -> String: return id.to_upper().replace("_", " ")
	var boss: String = run.map.enemies[run.map.layer][run.map.node] if win else ""
	Ui.centre(r, "THE %s IS DOWN" % name.call(boss) if win else "SLAIN BY %s AT NODE %d/%d" % [name.call(st.killer), run.map.layer + 1, Tuning.MAP.size()], 70, C.cream)
	Ui.label(r, "STATS", 180, 92, C.rivet)
	var rows := [["FIGHTS WON", st.fights], ["DAMAGE DEALT", st.damage], ["BRICKS BROKEN", st.bricks], ["BIGGEST SHOT", st.best_fire],
		["BALLS DROPPED", st.drops], ["GOLD EARNED", st.gold_earned], ["TIME", "%d:%02d" % [int(st.seconds) / 60, int(st.seconds) % 60]]]
	for i in rows.size():
		Ui.label(r, rows[i][0], 180, 102 + 10 * i, C.white)
		Ui.label(r, str(rows[i][1]), 240, 102 + 10 * i, C.pay, 1, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	Ui.label(r, "BAG", 340, 92, C.rivet)
	for i in mini(run.bag.size(), END_ROWS):
		Ui.icon(r, Ui.face(run.bag[i]), 340, 102 + 12 * i)
		Ui.label(r, Tuning.BALLS[run.bag[i].id].name, 352, 104 + 12 * i, C.white)
	if run.bag.size() > END_ROWS:
		Ui.label(r, "+%d MORE" % (run.bag.size() - END_ROWS), 352, 104 + 12 * END_ROWS, C.rivet)
	Ui.label(r, "RELICS", 440, 92, C.rivet)
	for i in run.relics.size():
		Ui.icon(r, "relic_%s" % run.relics[i], 440, 102 + 14 * i)
		Ui.label(r, Tuning.RELICS[run.relics[i]].name, 456, 105 + 14 * i, C.white)
	var fresh: Array = run.get("unlocked", [])
	if fresh:
		Ui.centre(r, "UNLOCKED: " + ", ".join(fresh.map(func(id): return Tuning.BALLS.get(id, Tuning.RELICS.get(id, {})).name)), 180, C.mint)
		Sfx.play("ui_unlock", 1.2, 1.0)
	Ui.button(r, "NEW RUN", 214, 220, 96, 20, _new_run, true, 2, "ui_start")
	Ui.button(r, "MENU", 330, 220, 96, 20, _show_menu, false, 2, "ui_back")
	_swap(r)


func _swap(n: Node) -> void:
	_pause(false)
	for c in get_children():
		c.queue_free()
	add_child(n)


# --- Pause ---

## Screens with their own Esc (settings, the pause dialog itself) take it first through Ui.Root.back; the rest falls through here.
func _unhandled_input(e: InputEvent) -> void:
	if group and not pause and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		_pause(true)


func _pause(on: bool) -> void:
	if on != get_tree().paused:
		Sfx.play("ui_pause" if on else "ui_unpause")
	get_tree().paused = on
	if pause:
		pause.queue_free()
		pause = null
	if not on:
		return
	pause = Ui.dialog("PAUSED", [["RESUME", true, _pause.bind(false)], ["SETTINGS", false, _pause_settings], ["MENU", false, _show_menu]])
	pause.back.connect(_pause.bind(false))
	add_child(pause)


func _pause_settings() -> void:
	Sfx.play("ui_click")
	pause.queue_free()
	pause = Ui.settings(_pause.bind(true))  # Back rebuilds the pause menu
	add_child(pause)
