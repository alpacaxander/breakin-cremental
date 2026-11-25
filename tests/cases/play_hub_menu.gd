extends RefCounted
## A first player's pass over the hub, the main menu, Settings and the joins between the screens, through the real
## Main with real input events only. The CRT is on, as it is for a new player, so every click lands where the
## curved picture shows the control (_at, as in loop.gd).
##
## The hub: every node read on fresh, mid and maxed saves against docs/design/upgrades.md's table and drawn web,
## every path out from the seed to a leaf bought and the open set compared with the drawn links, a node owned and
## its copy's price, then undone by a right click (a right drag only pans) and by Undo, Buy with too few coins,
## each level picked, a locked one tried, and the hub after a real round on level 1 that clears it.
## The menu and Settings by mouse and by keyboard, each setting at once and after a restart.
## The joins: Esc twice from every screen and state, back buttons, double clicks, and how many times each UI cue
## plays.
##
## A double click here is what the OS reports: a second press marked `double_click` (_double_click_at).

## docs/design/upgrades.md's table, by upgrade id: name, category, ranks (its nodes on the web), "Each rank", first
## cost, growth. Every upgrade's ranks and prices are first values, set with the balance bot.
const TABLE := {
	&"paddle_speed": ["Paddle Speed", Upgrade.Category.ARENA, 2, "+100% paddle speed", 5, 30.0],
	&"paddle_size": ["Paddle Size", Upgrade.Category.ARENA, 5, "+40% paddle length", 20, 4.0],
	&"combo": ["Combo", Upgrade.Category.ARENA, 1, "Turns combos on", 4, 1.0],
	&"combo_window": ["Combo Window", Upgrade.Category.ARENA, 2, "Combos last longer", 40, 15.0],
	&"rear_paddle": ["Rear Paddle", Upgrade.Category.ARENA, 2, "+20% speed off the Rear Paddle", 300, 8.0],
	&"booster": ["Booster", Upgrade.Category.PLACEABLES, 2, "One more Booster", 5, 20.0],
	&"booster_speed": ["Booster Speed", Upgrade.Category.PLACEABLES, 2, "Balls leave a Booster 20% faster still", 500, 6.0],
	&"splitter": ["Splitter", Upgrade.Category.PLACEABLES, 5, "One more Splitter", 80, 3.0],
	&"splitter_respawn": ["Splitter Respawn", Upgrade.Category.PLACEABLES, 3, "A broken Splitter comes back", 2000, 2.5],
	&"splitter_health": ["Splitter Health", Upgrade.Category.PLACEABLES, 2, "A Splitter takes one more hit", 500, 6.0],
	&"wall_segment": ["Wall Segment", Upgrade.Category.PLACEABLES, 2, "One more Wall Segment", 40, 10.0],
	&"gold_brick": ["Gold Brick", Upgrade.Category.BRICKS, 3, "One more gold brick", 30, 6.0],
	&"hourglass_brick": ["Hourglass Brick", Upgrade.Category.BRICKS, 2, "One more hourglass brick", 25, 100.0],
	&"hourglass_time": ["Hourglass Time", Upgrade.Category.BRICKS, 2, "An hourglass brick adds 5 s more", 1200, 5.0],
	&"hourglass_freeze": ["Hourglass Freeze", Upgrade.Category.BRICKS, 2, "Breaking an hourglass brick holds the combo", 800, 5.0],
	&"tough_brick": ["Tough Brick", Upgrade.Category.BRICKS, 3, "One more tough brick", 20, 6.0],
	&"growth": ["Growth", Upgrade.Category.PLACEABLES, 2, "One more Growth area", 100, 4.5],
	&"growth_reach": ["Growth Reach", Upgrade.Category.PLACEABLES, 2, "Growth areas reach one square further", 300, 10.0],
	&"pulse_rate": ["Growth Pulses", Upgrade.Category.PLACEABLES, 2, "Growth pulses once more", 1000, 6.0],
	&"overgrowth": ["Overgrowth", Upgrade.Category.ARENA, 1, "Broken bricks grow back", 0, 1.0],
	&"guide": ["Guide", Upgrade.Category.ARENA, 4, "+250 guide length", 30, 4.0],
	&"guide_bounces": ["Guide Bounces", Upgrade.Category.ARENA, 1, "The guide line bounces", 250, 1.0],
	&"multiball": ["Multiball", Upgrade.Category.ARENA, 3, "One more ball", 300, 5.0],
	&"power_brick": ["Power Brick", Upgrade.Category.ABILITIES, 4, "One more Power Brick", 25, 4.0],
	&"zap": ["Zap", Upgrade.Category.ABILITIES, 1, "Unlocks Zap: a charged ball hits the rest of its brick's row", 0, 1.0],
	&"zap_range": ["Zap Range", Upgrade.Category.ABILITIES, 2, "A Zap reaches 2 more bricks each way", 400, 5.0],
	&"zap_damage": ["Zap Damage", Upgrade.Category.ABILITIES, 2, "A Zap hits each brick once more", 800, 5.0],
	&"blast": ["Blast", Upgrade.Category.ABILITIES, 1, "Unlocks Blast: a charged ball sets off a blast at the brick it hits", 0, 1.0],
	&"blast_size": ["Blast Size", Upgrade.Category.ABILITIES, 2, "Blasts reach one square further", 150, 20.0],
	&"explosion_damage": ["Blast Damage", Upgrade.Category.ABILITIES, 2, "Blasts hit each brick once more", 300, 10.0],
	&"shockwave": ["Shockwave", Upgrade.Category.ABILITIES, 1, "Blasts throw balls", 600, 1.0],
}
## The drawn web of upgrades.md, by web node: its cell (column, row; the seed's is (0, 0)) and the nodes it hangs
## off, towards the seed. The scene lists the nodes in this order, which is one they can be bought in.
const DRAWN := {
	&"PaddleSpeed": [Vector2i(0, 0)], &"Combo": [Vector2i(1, 0), &"PaddleSpeed"],
	&"Booster": [Vector2i(0, -1), &"PaddleSpeed"], &"PaddleSize": [Vector2i(-1, 0), &"PaddleSpeed"],
	&"ToughBrick": [Vector2i(0, 1), &"PaddleSpeed"], &"PowerBrick": [Vector2i(-2, 0), &"PaddleSize"],
	&"HourglassBrick": [Vector2i(2, 0), &"Combo"], &"Guide": [Vector2i(0, -2), &"Booster"],
	&"GoldBrick": [Vector2i(0, 2), &"ToughBrick"], &"ComboWindow": [Vector2i(2, -1), &"HourglassBrick"],
	&"WallSegment": [Vector2i(0, 3), &"GoldBrick"], &"Zap": [Vector2i(-2, -1), &"PowerBrick"],
	&"PaddleSize2": [Vector2i(3, 0), &"HourglassBrick"], &"Booster2": [Vector2i(0, -3), &"Guide"],
	&"Splitter": [Vector2i(1, -3), &"Booster2"], &"PowerBrick2": [Vector2i(-3, 0), &"PowerBrick"],
	&"Growth": [Vector2i(0, 4), &"WallSegment"], &"PaddleSpeed2": [Vector2i(1, -4), &"Splitter"],
	&"ToughBrick2": [Vector2i(1, -5), &"PaddleSpeed2"], &"Guide2": [Vector2i(0, -5), &"ToughBrick2"],
	&"GoldBrick2": [Vector2i(4, 0), &"PaddleSize2"], &"Splitter2": [Vector2i(-1, 4), &"Growth"],
	&"GuideBounces": [Vector2i(-1, -3), &"Booster2"], &"Multiball": [Vector2i(3, 1), &"PaddleSize2"],
	&"RearPaddle": [Vector2i(2, -3), &"Splitter"], &"GrowthReach": [Vector2i(1, 4), &"Growth"],
	&"PaddleSize3": [Vector2i(-4, 0), &"PowerBrick2"], &"PowerBrick3": [Vector2i(-2, -2), &"Zap"],
	&"ZapRange": [Vector2i(-3, -2), &"PowerBrick3"], &"BoosterSpeed": [Vector2i(3, -3), &"RearPaddle"],
	&"ComboWindow2": [Vector2i(3, 2), &"Multiball"], &"ToughBrick3": [Vector2i(-1, 5), &"Splitter2"],
	&"Growth2": [Vector2i(-2, 5), &"ToughBrick3"], &"WallSegment2": [Vector2i(-2, 6), &"Growth2"],
	&"Splitter3": [Vector2i(-3, 5), &"Growth2"], &"ZapDamage": [Vector2i(-4, -2), &"ZapRange"],
	&"Guide3": [Vector2i(-4, -3), &"ZapDamage"], &"HourglassFreeze": [Vector2i(3, 3), &"ComboWindow2"],
	&"GrowthPulses": [Vector2i(1, 5), &"GrowthReach"], &"GoldBrick3": [Vector2i(1, 6), &"GrowthPulses"],
	&"HourglassTime": [Vector2i(4, 3), &"HourglassFreeze"], &"Blast": [Vector2i(-2, 1), &"PowerBrick"],
	&"BlastSize": [Vector2i(-2, 2), &"Blast"], &"BlastDamage": [Vector2i(-3, 2), &"BlastSize"],
	&"Shockwave": [Vector2i(-4, 2), &"BlastDamage"], &"PaddleSize4": [Vector2i(-1, -5), &"Guide2"],
	&"Multiball2": [Vector2i(-4, 5), &"Splitter3"], &"SplitterHealth": [Vector2i(-4, 6), &"Multiball2"],
	&"PowerBrick4": [Vector2i(-5, 2), &"Shockwave"], &"Guide4": [Vector2i(3, -4), &"BoosterSpeed"],
	&"SplitterRespawn": [Vector2i(1, -6), &"ToughBrick2"], &"ZapRange2": [Vector2i(-4, -4), &"Guide3"],
	&"Splitter4": [Vector2i(-5, -2), &"ZapDamage"], &"HourglassBrick2": [Vector2i(3, 4), &"HourglassFreeze"],
	&"BlastDamage2": [Vector2i(-4, 3), &"Shockwave"], &"SplitterHealth2": [Vector2i(3, -5), &"Guide4"],
	&"RearPaddle2": [Vector2i(4, -5), &"SplitterHealth2"], &"BlastSize2": [Vector2i(-6, 2), &"PowerBrick4"],
	&"GrowthReach2": [Vector2i(0, 6), &"GoldBrick3"], &"BoosterSpeed2": [Vector2i(3, -6), &"SplitterHealth2"],
	&"HourglassFreeze2": [Vector2i(4, 4), &"HourglassTime", &"HourglassBrick2"],
	&"ZapDamage2": [Vector2i(-5, -4), &"ZapRange2"], &"SplitterRespawn2": [Vector2i(-6, -2), &"Splitter4"],
	&"PaddleSize5": [Vector2i(-6, 3), &"BlastSize2"], &"HourglassTime2": [Vector2i(3, 5), &"HourglassBrick2"],
	&"GrowthPulses2": [Vector2i(2, 6), &"GoldBrick3"], &"Splitter5": [Vector2i(-5, 5), &"Multiball2"],
	&"Multiball3": [Vector2i(-6, -4), &"ZapDamage2"], &"SplitterRespawn3": [Vector2i(-5, 4), &"Splitter5"],
	&"Overgrowth": [Vector2i(2, 2), &"ComboWindow2"],
}
## art.md's category colours, by Upgrade.Category: cyan, blue, magenta, orange.
const HUE := [Palette.PLAYER, Palette.PLACEABLE, Palette.BRICKS, Palette.ABILITY]
const DETAIL := Rect2(904, 88, 352, 284)  ## art.md, "Upgrade screen"
const LEVELS := Rect2(904, 388, 352, 308)
const SPACE := 0.06  ## Sfx spaces plays of one cue 15 ms apart in real time; wait this long before counting them

var t: Node
var main: Main
var heard: Array[StringName] = []


func run(p_t: Node) -> void:
	t = p_t
	var on_played := func(cue: StringName, _p: AudioStreamPlayer) -> void: heard.append(cue)
	Sfx.played.connect(on_played)
	await _boot()
	await _menu_into_hub()
	for save: String in ["fresh", "mid", "maxed"]:
		await _details(save)
	await _paths()
	await _max_and_poor()
	await _levels()
	await _round_trip()
	await _esc_and_back()
	await _double_clicks()
	await _settings()
	await _restart()
	Engine.time_scale = 1.0
	Sfx.played.disconnect(on_played)
	main.free()


func _boot() -> void:
	if main:
		main.free()
	main = (load("res://src/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	await t.tree().process_frame
	await t.tree().process_frame


## A fresh save, the menu, Play clicked: level 1's Setup, one click heard. Then Esc: the hub, the seed selected.
func _menu_into_hub() -> void:
	var menu := _screen()
	await _quiet()
	await _click(menu.get_node("%Play"))
	await _heard_settle()
	t.check(_screen().scene_file_path == Main.PLAY and _play().get_child(-1).get("level") == 1 and not _hub().visible,
			"clicking Play opens level 1's Setup on a fresh save")
	t.check(heard.count(Sfx.CLICK) == 1, "clicking Play clicks once (heard %s)" % [heard])
	_key(KEY_ESCAPE)
	await _frames(2)
	t.check(_hub().is_visible_in_tree(), "Esc in that Setup opens the hub")
	t.check(_hub().selected == _web().seed_node(), "the hub opens with the seed selected, the one thing a new player can buy")
	t.check((_hub().get_node("Bar/Hint") as Label).text == "RIGHT CLICK AN OWNED NODE TO UNDO IT", "the top bar's one hint line is how to undo")
	for c: Control in _screen().find_children("*", "Control", true, false):
		t.check(c.tooltip_text == "", "%s has no tooltip (main.gd: a tooltip costs a key press)" % c.name)
	var bar := _hub().get_node("Bar") as Control
	var detail := _hub().get_node("Detail") as Control
	var levels := _hub().get_node("Levels") as Control
	t.check(detail.get_global_rect() == DETAIL, "the detail panel is art.md's 352 x 284 at (904, 88) (is %s)" % detail.get_global_rect())
	t.check(levels.get_global_rect() == LEVELS,
			"the level panel is art.md's 352 x 308 at (904, 388), bottom-aligned with the web view at y 696 (is %s)" % levels.get_global_rect())
	Progress.coins = 250000  # what the balance bot ends level 3 with
	await _frames(1)
	var coins := _hub().get_node("Bar/Coins") as Control
	t.check(bar.get_global_rect().end.x <= 1256.5 and coins.get_global_rect().end.x <= 1256.5,
			"with 250000 coins the top bar still ends at x 1256 (coins end at %d)" % coins.get_global_rect().end.x)


## Every node clicked on a save, its detail panel and its face read against the docs.
func _details(save: String) -> void:
	_seed(save)
	await _fresh_hub()
	var web := _web()
	var buy: Button = _hub().get_node("Detail/%Buy")
	t.check(web.nodes().map(func(n: HubNode) -> StringName: return n.name) == DRAWN.keys(), "the web's nodes are upgrades.md's, in its order")
	for n in web.nodes():
		var row: Array = TABLE[n.upgrade.id]
		var what := "%s on a %s save" % [n.name, save]
		var drawn: Array = DRAWN.get(StringName(n.name), [null])
		t.check(n.cell == drawn[0], "%s sits at upgrades.md's cell %s (is %s)" % [what, drawn[0], n.cell])
		if web.state(n) == HubNode.State.LOCKED:
			t.check(not n.visible, "%s is locked, so it is hidden" % what)
			continue
		_web().refresh(n)  # the web is taller than the view: bring n into it, as the arrow keys would
		await _click(n)
		t.check(_hub().selected == n, "clicking %s selects it" % what)
		var u := n.upgrade
		var r := Progress.rank(u)
		t.check(_text("Detail/%Name") == row[0] and u.title == row[0], "%s: the name is upgrades.md's %s" % [what, row[0]])
		t.check(u.category == row[1] and _text("Detail/%Category") == Upgrade.Category.keys()[row[1]], "%s: the category is the table's" % what)
		# The node, its pips and its lit lines all take Palette.of(meaning()); the panel lights the category in it.
		var hue: Color = HUE[row[1]]
		t.check(Palette.of(u.meaning()) == hue and (_hub().get_node("Detail/%Category") as Label).get_theme_color(&"font_color") == Palette.lit(hue, Palette.LIT_TEXT)
				and (n.get_node("Bottom/Pips") as UiPips).meaning == u.meaning(),
				"%s: the node, its pips and the panel's category are in art.md's %s" % [what, hue.to_html(false)])
		var text := _hub().get_node("Detail/%Text") as Label
		t.check(text.get_line_count() <= 2 and text.get_visible_line_count() == text.get_line_count(),
				"%s: the text fits the panel's two lines (%d lines, %d shown)" % [what, text.get_line_count(), text.get_visible_line_count()])
		var owned := StringName(n.name) in Progress.owned
		var open := web.state(n) == HubNode.State.AVAILABLE
		var undo := owned and web.can_undo(n)  # the rule itself is checked in hub.gd
		var note := "COSTS 1 KEY, NO COINS" if u.key else "BUY A NODE NEXT TO IT FIRST" if not open \
				else "YOU OWN %d. EACH ONE RAISES THE REST" % r if r else "NONE OWNED YET"
		if owned:
			note = "UNDO WHAT HANGS OFF IT FIRST" if not undo else "UNDO GIVES THE KEY BACK" if u.key else "UNDO REFUNDS THE LAST PRICE PAID"
		t.check(u.max_rank == row[2] and _text("Detail/%Note") == note, "%s: the note reads \"%s\" (reads \"%s\")" % [what, note, _text("Detail/%Note")])
		var note_label := _hub().get_node("Detail/%Note") as Label
		t.check(note_label.get_minimum_size().x <= note_label.size.x + 0.5, "%s: the note fits the panel" % what)
		t.check((n.get_node("Bottom/Pips") as UiPips).total == (0 if u.key else r), "%s: %d pips on the node, one per copy owned, none on a key node" % [what, r])
		t.check(_text("Detail/%Text").begins_with(row[3]), "%s: the effect is the table's \"%s\" (reads \"%s\")" % [what, row[3], _text("Detail/%Text")])
		t.check(_text("Detail/%State") == HubNode.State.keys()[web.state(n)] and (owned or open or web.state(n) == HubNode.State.PREVIEW),
				"%s: the state on the panel is the node's (%s)" % [what, _text("Detail/%State")])
		var price: int = roundi(row[4] * pow(row[5], r))
		if not owned:
			t.check((_hub().get_node("Detail/%Price") as UiPrice).amount == price and (n.get_node("Bottom/Price") as UiPrice).amount == price,
					"%s: the next copy costs %d, on the panel and on the node" % [what, price])
		elif not u.key:
			var back: int = roundi(row[4] * pow(row[5], r - 1))
			t.check(_text("Detail/%PriceTag") == "REFUND" and (_hub().get_node("Detail/%Price") as UiPrice).amount == back,
					"%s: the panel offers a refund of %d, the last price paid" % [what, back])
		t.check((n.get_node("Bottom/Price") as Control).visible != owned, "%s: the node's price shows only until it is bought" % what)
		t.check(buy.text == ("BUY" if open else ("UNDO" if undo else "IN USE") if owned else "LOCKED") and buy.disabled == not (open or undo),
				"%s: Buy reads %s" % [what, buy.text])
		var can := open and (Progress.keys() > 0 if u.key else Progress.coins >= price)
		t.check((n.get_node("Bottom/Price") as UiPrice).dim == not can, "%s: the node's price is gold only when it can be bought now" % what)
		t.check((_hub().get_node("Detail") as Control).get_global_rect() == DETAIL, "%s: the detail panel keeps its size (is %s)" % [what, (_hub().get_node("Detail") as Control).get_global_rect()])
		var label := n.get_node("Name") as Label
		t.check(label.get_minimum_size().x <= label.size.x + 0.5 or not label.clip_text, "%s: the name fits on the node" % what)


## Every path out from the seed to a leaf (a node nothing hangs off), bought node by node with clicks, each node
## by the first one it hangs off: after each buy the open nodes are exactly the unbought ones with a bought
## neighbour on the drawn web, and each copy costs what the table says for the copies owned before it.
func _paths() -> void:
	var hung := []
	for k: StringName in DRAWN:
		hung.append_array(DRAWN[k].slice(1))
	for leaf: StringName in DRAWN:
		if leaf in hung:
			continue
		var path: Array[StringName] = [leaf]
		while DRAWN[path[0]].size() > 1:
			path.push_front(DRAWN[path[0]][1])
		_seed("fresh")
		Progress.coins = 999999
		Progress.unlocked = Progress.level_count + 1  # every level cleared: a key for each of Zap, Blast and Overgrowth
		await _fresh_hub()
		var buy: Button = _hub().get_node("Detail/%Buy")
		for step: StringName in path:
			var n: HubNode = _web().get_node(String(step))
			_web().refresh(n)
			await _click(n)
			var before := Progress.coins
			var r := Progress.rank(n.upgrade)
			var row: Array = TABLE[n.upgrade.id]
			var price: int = roundi(row[4] * pow(row[5], r))
			await _click(buy)
			t.check(Progress.rank(n.upgrade) == r + 1 and StringName(step) in Progress.owned and before - Progress.coins == price,
					"on the path to %s, Buy on %s buys copy %d for %d" % [leaf, step, r + 1, price])
			var want: Array[String] = []
			for m in _web().nodes():
				var id := StringName(m.name)
				if id not in Progress.owned and _docs_neighbours(id).any(func(o: StringName) -> bool: return o in Progress.owned):
					want.append(m.name)
			var have: Array[String] = []
			for m in _web().nodes():
				if _web().state(m) == HubNode.State.AVAILABLE:
					have.append(m.name)
			want.sort()
			have.sort()
			t.check(have == want, "after buying %s on the path to %s, open are %s (open: %s)" % [step, leaf, want, have])


## The seed bought with clicks, a Buy with too few coins, and the cues of each.
func _max_and_poor() -> void:
	_seed("fresh")
	await _fresh_hub()
	var seed := _web().seed_node()
	var buy: Button = _hub().get_node("Detail/%Buy")
	await _click(seed)
	Progress.coins = 1
	await _quiet()
	await _click(buy)
	await _heard_settle()
	t.check(Progress.coins == 1 and Progress.rank(seed.upgrade) == 0, "Buy with 1 coin on a 5-coin node buys nothing")
	t.check(heard == [Sfx.CANT_AFFORD], "it plays can't afford once and nothing else (heard %s)" % [heard])
	t.check(buy.theme_type_variation == &"CantAfford" and not buy.disabled and buy.text == "BUY", "it reads BUY in the can't-afford look")
	Progress.coins = 200
	await _quiet()
	await _click(buy)
	await _heard_settle()
	t.check(heard == [Sfx.BUY] and Progress.coins == 195, "buying the seed costs 5 and plays the buy cue once and nothing else (heard %s)" % [heard])
	t.check(_web().state(seed) == HubNode.State.OWNED and not buy.disabled and buy.text == "UNDO", "once bought it is owned, and Buy reads UNDO: the seed is the only node owned")
	t.check(_text("Detail/%PriceTag") == "REFUND" and (_hub().get_node("Detail/%Price") as UiPrice).amount == 5 and not (seed.get_node("Bottom/Price") as Control).visible,
			"the panel offers the 5 back, and the node's price is gone")
	t.check((_web().get_node("PaddleSpeed2/Bottom/Price") as UiPrice).amount == 150, "Paddle Speed's other copy now costs 150, its second rank")
	# A right click on it undoes it, through the CRT as the player sees it; a right drag that ends there too only pans.
	var pan := _web().pan
	await _quiet()
	await _right_click_at(seed.get_global_rect().get_center(), Vector2(40, 0))
	await _heard_settle()
	t.check(_web().owns(seed) and heard.is_empty() and _web().pan != pan, "a right drag from the seed pans and undoes nothing (heard %s)" % [heard])
	await _quiet()
	await _right_click_at(seed.get_global_rect().get_center())
	await _heard_settle()
	t.check(not _web().owns(seed) and Progress.coins == 200 and heard == [Sfx.PLACE_ITEM] and _hub().selected == seed and buy.text == "BUY",
			"a right click on the seed undoes it: the 5 come back, place item plays once and nothing else (heard %s)" % [heard])
	t.check((_web().get_node("PaddleSpeed2/Bottom/Price") as UiPrice).amount == 5, "and the other copy's price falls back to 5")
	await _click(buy)
	await _quiet()
	await _click(buy)
	await _heard_settle()
	t.check(not _web().owns(seed) and Progress.coins == 200 and heard == [Sfx.PLACE_ITEM], "bought again, a click on UNDO undoes it too (heard %s)" % [heard])
	await _quiet()
	await _click(_web().get_node("Combo"))
	await _heard_settle()
	t.check(heard == [Sfx.CLICK], "clicking a node clicks once (heard %s)" % [heard])


## The level panel on a fresh save: each level by ◄ ►, the locked ones, and Play on one.
func _levels() -> void:
	_seed("fresh")
	await _fresh_hub()
	var levels: Control = _hub().get_node("Levels")
	var play: Button = levels.get_node("%Play")
	t.check(levels.level == 1 and _text("Levels/%Status") == "NOT CLEARED YET" and not play.disabled and play.text == "PLAY LEVEL", "a fresh save shows level 1, not cleared, playable")
	await _quiet()
	await _click(levels.get_node("%Next"))
	await _heard_settle()
	t.check(heard == [Sfx.CLICK], "► clicks once (heard %s)" % [heard])
	t.check(levels.level == 2 and play.disabled and play.text == "CLEAR LEVEL 1 FIRST" and _text("Levels/%Status") == "LOCKED", "level 2 is locked and says what opens it")
	t.check(is_equal_approx((levels.get_node("%Thumb") as Control).modulate.a, 0.35), "a locked level's thumbnail is at 35%")
	await _quiet()
	await _click(play)
	await _heard_settle()
	t.check(_hub().is_visible_in_tree() and heard.is_empty(), "the locked Play opens nothing and plays nothing")
	await _click(levels.get_node("%Next"))
	t.check(levels.level == 3 and (levels.get_node("%Next") as Button).disabled and play.text == "CLEAR LEVEL 2 FIRST", "level 3 is the last, locked")
	await _click(levels.get_node("%Prev"))
	await _click(levels.get_node("%Prev"))
	t.check(levels.level == 1 and (levels.get_node("%Prev") as Button).disabled, "◄ goes back to level 1, the first")


## Level 1 played for real from the hub, every brick broken by the rules, the Summary, Upgrades: the hub then shows
## the round's coins, level 2 on show and open, level 1 cleared, and the seed affordable.
func _round_trip() -> void:
	_seed("fresh")
	await _fresh_hub()
	var hub := _hub()
	await _click(hub.get_node("Levels/%Play"))
	var level := _play().get_child(-1) as Control
	t.check(level != hub and level.get("level") == 1 and level.get("phase") == 0, "Play Level opens level 1 in Setup")
	_key(KEY_SPACE)
	await t.tree().process_frame
	t.check(level.get("phase") == 1, "Space starts the round")
	var round: Round = level.round
	for cell: Vector2i in round.board.bricks.keys():
		while round.board.brick(cell):
			round.hit_brick(cell, Round.Cause.BALL, Vector2.RIGHT)
	await _summary_ready(level)
	t.check(round.reason == Round.End.CLEARED and Progress.unlocked == 2, "breaking every brick clears level 1 and unlocks level 2")
	var texts := _labels(level.get_node("Summary"))
	t.check(texts.has("LEVEL CLEARED") and texts.has("Level 2 unlocked"), "the Summary says LEVEL CLEARED and that level 2 is unlocked")
	var earned := round.coins
	await _quiet()
	await _click(level.get_node("Summary").find_child("Upgrades", true, false))
	await _heard_settle()
	t.check(heard == [Sfx.CLICK], "Upgrades clicks once (heard %s)" % [heard])
	t.check(hub.is_visible_in_tree() and not is_instance_valid(level), "Upgrades goes back to the hub")
	var levels: Control = hub.get_node("Levels")
	t.check((hub.get_node("Bar/Coins") as UiPrice).amount == earned and Progress.coins == earned and earned >= 5, "the hub shows the %d coins the round paid" % earned)
	t.check(levels.level == 2 and not (levels.get_node("%Play") as Button).disabled and _text("Levels/%Status") == "NOT CLEARED YET", "the new level 2 is on show and playable")
	var seed := _web().seed_node()
	t.check(not (seed.get_node("Bottom/Price") as UiPrice).dim and (hub.get_node("Detail/%Buy") as Button).theme_type_variation == &"", "the seed's price is gold now and Buy is the primary button")
	await _click(levels.get_node("%Prev"))
	t.check(_text("Levels/%Status") == "CLEARED", "level 1 reads CLEARED")


## Esc twice in one frame from every screen and state, and each back button.
func _esc_and_back() -> void:
	_seed("fresh")
	# Settings: one step to the menu, and the menu ignores the second.
	Main.show_settings()
	await _frames(2)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	await _frames(2)
	t.check(_screen().scene_file_path == Main.MENU, "Esc twice in Settings ends on the main menu")
	# The hub.
	Main.show_hub()
	await _frames(2)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	await _frames(2)
	t.check(_screen().scene_file_path == Main.MENU, "Esc twice in the hub ends on the main menu")
	# Setup: one Esc a step, so two reach the menu.
	Main.show_level(1)
	await _frames(2)
	_key(KEY_ESCAPE)
	await _frames(1)
	t.check(_screen().scene_file_path == Main.PLAY and _hub().is_visible_in_tree(), "one Esc in Setup goes to the hub only")
	Main.show_level(1)
	await _frames(2)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	await _frames(2)
	t.check(_screen().scene_file_path == Main.MENU, "two Esc in Setup go hub, then menu")
	# Play: no way out.
	var level := Main.show_level(1)
	await _frames(2)
	level.start(1)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	await _frames(2)
	t.check(is_instance_valid(level) and level.is_visible_in_tree() and level.get("phase") == 1, "Esc during Play does nothing")
	# The Summary, before and after its panel shows.
	level.round.time_left = 0.0
	await _frames(3)
	t.check(level.get("phase") == 2, "the round ends on the timer")
	_key(KEY_ESCAPE)
	await _frames(1)
	t.check(_hub().is_visible_in_tree(), "Esc in the Summary, before its panel shows, goes to the hub")
	level = Main.show_level(1)
	await _frames(2)
	level.start(1)
	level.round.time_left = 0.0
	await _summary_ready(level)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	await _frames(2)
	t.check(_screen().scene_file_path == Main.MENU, "two Esc in the Summary go hub, then menu")
	# Back buttons, each double-clicked where it is. They share a spot on every screen, so the second press would
	# land on the next screen's back button if main.gd did not drop it; two separate clicks go back twice.
	for where: String in ["settings", "hub", "setup", "summary"]:
		var back: Control
		var to := Main.MENU
		match where:
			"settings":
				Main.show_settings()
				await _frames(2)
				back = _screen().get_node("Bar/Back")
			"hub":
				Main.show_hub()
				await _frames(2)
				back = _hub().get_node("Bar/Back")
			"setup":
				level = Main.show_level(1)
				await _frames(2)
				back = level.get_node("SetupUi").find_child("Back*", true, false)
				if back == null:
					back = level.get_node("SetupUi").find_children("*", "UiBackButton", true, false)[0]
				to = Main.PLAY
			"summary":
				level = Main.show_level(1)
				await _frames(2)
				level.start(1)
				level.round.time_left = 0.0
				await _summary_ready(level)
				back = level.get_node("Summary/Back")
				to = Main.PLAY
		t.check(back.get_global_rect().position.is_equal_approx(UiTopBar.BACK), "the back button in %s is where every screen has it (%s)" % [where, back.get_global_rect().position])
		var at := back.get_global_rect().get_center()
		await _quiet()
		await _double_click_at(at)
		await _heard_settle()
		t.check(_screen().scene_file_path == to and (to == Main.MENU or _hub().is_visible_in_tree()), "the back button in %s, double-clicked, goes one step back" % where)
		t.check(heard.count(Sfx.CLICK) == 1, "the back button in %s clicks once (heard %s)" % [where, heard])
		Main.show_menu()
		await _frames(1)


## A double click on a button that changes the screen must not press what the next screen has under the cursor.
func _double_clicks() -> void:
	_seed("fresh")
	# Play Level, double-clicked: Setup's Start sits under it.
	await _fresh_hub()
	var at := (_hub().get_node("Levels/%Play") as Control).get_global_rect().get_center()
	await _double_click_at(at)
	var level := _play().get_child(-1) as Control
	t.check(level != _hub() and level.get("phase") == 0,
			"a double click on Play Level opens Setup and stays there; the second click must not press Start (phase %s)" % level.get("phase"))
	await _click_at(at)
	t.check(level.get("phase") == 1, "a click after that, on Start, starts the round")
	level.round.time_left = 0.0
	await _summary_ready(level)
	# Upgrades on the Summary, double-clicked: the web is under it.
	var seed := _web().seed_node()
	await _double_click_at((level.get_node("Summary").find_child("Upgrades", true, false) as Control).get_global_rect().get_center())
	t.check(_hub().is_visible_in_tree() and _hub().selected == seed, "a double click on Upgrades opens the hub and selects nothing new")
	Main.show_menu()
	await _frames(2)
	# Play on the menu, double-clicked: Setup, and the second click presses nothing there.
	at = (_screen().get_node("%Play") as Control).get_global_rect().get_center()
	await _double_click_at(at)
	level = _play().get_child(-1) as Control if _screen() is Play else null
	t.check(level != null and level != _hub() and level.get("phase") == 0,
			"a double click on Play opens Setup and stays there (phase %s)" % (level.get("phase") if level else null))
	Main.show_hub()
	await _frames(2)
	t.check(_hub().selected == _web().seed_node(), "the hub still has the seed selected (selected %s)" % _hub().selected.name)
	HubWeb.own_first(DRAWN.size())  # every node owned, so whichever is under the pointer is shown
	Progress.rank_changed.emit(_web().seed_node().upgrade)
	await _double_click_at(at)
	t.check(_hub().selected != _web().seed_node(), "a double click that starts in the hub is not dropped: the node under it is selected")
	Progress.ranks.clear()
	Progress.owned.clear()
	Progress.rank_changed.emit(_web().seed_node().upgrade)


## Settings by keyboard and by mouse: focus can't leave the screen, each control applies at once and clicks once.
func _settings() -> void:
	Main.show_menu()
	await _frames(2)
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	await _frames(2)
	var settings := _screen()
	t.check(settings.scene_file_path == Main.SETTINGS, "Down, Enter opens Settings")
	var cursor: Control = settings.get_node("Cursor")
	# Walk the focus with the arrows: it never lands where the cursor is off screen or hidden.
	for key: Key in [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_DOWN]:
		_key(key)
		await _frames(1)
		var owner := settings.get_viewport().gui_get_focus_owner()
		t.check(owner != null and settings.is_ancestor_of(owner), "after %s focus is still on a Settings control" % OS.get_keycode_string(key))
		t.check(cursor.visible and cursor.get_global_rect().position.x >= 0.0,
				"after %s the focus cursor shows on screen beside %s (at x %d)" %[OS.get_keycode_string(key), owner.name if owner else "nothing", cursor.get_global_rect().position.x])
	var crt: CheckBox = settings.get_node("%Crt")
	var calm: CheckBox = settings.get_node("%Calm")
	var music: HSlider = settings.get_node("%Music")
	var shader := main.crt.material as ShaderMaterial
	await _quiet()
	await _click(crt)
	await _heard_settle()
	t.check(not Settings.crt and shader.get_shader_parameter("enabled") == false, "a click on the CRT toggle turns the picture flat at once")
	t.check(heard == [Sfx.CLICK], "the toggle clicks once (heard %s)" % [heard])
	await _click(calm)
	t.check(Settings.reduce_flashing and is_equal_approx(main.env.glow_intensity, Main.GLOW), "a click on Reduce flashing turns it on; the glow at rest is unchanged")
	var track := music.get_global_rect()
	await _click_at(Vector2(track.position.x + 2, track.get_center().y))
	t.check(Settings.music_volume <= 0.05 and AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(Settings.BUS_MUSIC)) <= 0.05,
			"a click at the left end of the music track turns the music down on its bus (%.2f)" % Settings.music_volume)
	t.check((music.get_parent().get_node("Value") as Label).text == "%d%%" % roundi(Settings.music_volume * 100), "the percentage follows")
	await _click_at(Vector2(track.end.x - 2, track.get_center().y))
	t.check(Settings.music_volume >= 0.95, "a click at the right end turns it full up")
	await _click_at(track.get_center())
	var sound: HSlider = settings.get_node("%Sound")
	sound.grab_focus()
	_key(KEY_LEFT)
	t.check(is_equal_approx(Settings.sound_volume, 0.45) and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(Settings.BUS_SOUND)), 0.45), "Left on Sound lowers the sound bus a step at once")


## A restart: a new Main on the same files keeps every setting, on the picture, the buses and the controls.
func _restart() -> void:
	var music := Settings.music_volume
	main.free()
	main = null
	Settings.use(Settings.path)
	await _boot()
	var shader := main.crt.material as ShaderMaterial
	t.check(not Settings.crt and shader.get_shader_parameter("enabled") == false, "after a restart the CRT is still off on the picture")
	t.check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(Settings.BUS_MUSIC)), music)
			and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(Settings.BUS_SOUND)), 0.45), "and the buses keep their volumes")
	Main.show_settings()
	await _frames(2)
	var s := _screen()
	t.check(not (s.get_node("%Crt") as CheckBox).button_pressed and (s.get_node("%Calm") as CheckBox).button_pressed
			and is_equal_approx((s.get_node("%Music") as HSlider).value, music), "and Settings shows them")
	Settings.crt = true


# --- Helpers ---------------------------------------------------------------------------------------------------

func _seed(save: String) -> void:
	Progress.use(Progress.path)
	Progress.reset()
	if save == "fresh":
		Progress.save()
		return
	var top := save == "maxed"
	Progress.coins = 99999 if top else 250
	Progress.unlocked = Levels.count() + 1 if top else 2  # every level cleared, so the 3 keys pay for the 3 key upgrades
	HubWeb.own_first(DRAWN.size() if top else ceili(DRAWN.size() / 2.0))
	Progress.save()


## A new hub on the save as it is: back to the menu, then Play.
func _fresh_hub() -> void:
	Main.show_menu()
	await _frames(1)
	Main.show_hub()
	await _frames(2)


## Waits, at ten times the speed, for the round to end, the Summary's buttons to show and its tally to stop
## ticking: a check that counts cues after this must not hear a tally tick among them.
func _summary_ready(level: Control) -> void:
	Engine.time_scale = 10.0
	var started := Time.get_ticks_msec()
	while level.get("phase") != 2 and Time.get_ticks_msec() - started < 5000:
		await t.tree().physics_frame
	while Time.get_ticks_msec() - started < 8000:
		var b := level.get_node("Summary").find_child("Upgrades", true, false) as Control
		if b and b.is_visible_in_tree() and not (level.get_node("Summary")._tween as Tween).is_running():
			break
		await t.tree().process_frame
	Engine.time_scale = 1.0
	await _frames(1)


func _screen() -> Node:
	return main.screen.get_child(main.screen.get_child_count() - 1)


func _play() -> Play:
	return _screen() as Play


func _hub() -> Control:
	return _screen().get_node("Hub")


func _web() -> HubWeb:
	return _hub().get_node("Web")


func _text(path: String) -> String:
	return (_hub().get_node(path) as Label).text


func _labels(under: Node) -> Array:
	return under.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _docs_neighbours(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in DRAWN:
		if k == id:
			out.append_array(DRAWN[k].slice(1))
		elif id in DRAWN[k].slice(1):
			out.append(k)
	return out


func _frames(n: int) -> void:
	for i in n:
		await t.tree().process_frame


## Lets cues already queued go out, then forgets them.
func _quiet() -> void:
	await t.tree().create_timer(SPACE).timeout
	heard.clear()


func _heard_settle() -> void:
	await t.tree().create_timer(SPACE).timeout


## The window point the CRT shows the game's point `target` under: the inverse of Main's warp.
func _at(target: Vector2) -> Vector2:
	var p := target
	for i in 8:
		p += target - main._warp(p)
	return p


func _click(control: Control) -> void:
	await _click_at(control.get_global_rect().get_center())


## A left click at the game's point `at`, as the player sees it: a move there, a press and a release a frame apart.
## `second` makes it the second click of a double click.
func _click_at(at: Vector2, second := false) -> void:
	_mouse(at)
	for pressed: bool in [true, false]:
		_mouse(at, MOUSE_BUTTON_LEFT, pressed, second and pressed)
		await t.tree().process_frame


## Two clicks at `at` as the OS reports a double click: it marks the second press `double_click`.
func _double_click_at(at: Vector2) -> void:
	await _click_at(at)
	await _click_at(at, true)


func _mouse(at: Vector2, button := MOUSE_BUTTON_NONE, pressed := false, double := false) -> void:
	var event: InputEventMouse
	if button == MOUSE_BUTTON_NONE:
		event = InputEventMouseMotion.new()
	else:
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = pressed
		click.double_click = double
		event = click
	event.position = _at(at)
	event.global_position = event.position
	t.get_viewport().push_input(event, true)


func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		t.get_viewport().push_input(event, true)


## A right click at the game's point `at`: a move there and a press, then with `drag` a move by that much with the
## right button held, and the release where the pointer ends.
func _right_click_at(at: Vector2, drag := Vector2.ZERO) -> void:
	_mouse(at)
	_mouse(at, MOUSE_BUTTON_RIGHT, true)
	await t.tree().process_frame
	if drag:
		var move := InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_RIGHT
		move.position = _at(at + drag)
		move.global_position = move.position
		move.relative = move.position - _at(at)
		t.get_viewport().push_input(move, true)
		await t.tree().process_frame
	_mouse(at + drag, MOUSE_BUTTON_RIGHT, false)
	await t.tree().process_frame
