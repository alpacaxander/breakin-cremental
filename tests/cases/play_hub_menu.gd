extends RefCounted
## A first player's pass over the hub, the main menu, Settings and the joins between the screens, through the real
## Main with real input events only. The CRT is on, as it is for a new player, so every click lands where the
## curved picture shows the control (_at, as in loop.gd).
##
## The hub: every node read on fresh, mid and maxed saves against docs/design/upgrades.md's table, every path out
## from the seed bought and the open set compared with the documented links, a node maxed, Buy with too few coins,
## each level picked, a locked one tried, and the hub after a real round on level 1 that clears it.
## The menu and Settings by mouse and by keyboard, each setting at once and after a restart.
## The joins: Esc twice from every screen and state, back buttons, double clicks, and how many times each UI cue
## plays.
##
## A double click here is what the OS reports: a second press marked `double_click` (_double_click_at).

## docs/design/upgrades.md's table, by web node: name, category, ranks, "Each rank", first cost, growth. Every
## node's ranks and prices are first values, set with the balance bot.
const TABLE := {
	&"PaddleSpeed": ["Paddle Speed", Upgrade.Category.ARENA, 2, "+100% paddle speed", 5, 30.0],
	&"PaddleSize": ["Paddle Size", Upgrade.Category.ARENA, 5, "+40% paddle length", 50, 3.5],
	&"Combo": ["Combo", Upgrade.Category.ARENA, 1, "Turns combos on", 12, 1.0],
	&"ComboWindow": ["Combo Window", Upgrade.Category.ARENA, 2, "Combos last longer", 40, 15.0],
	&"RearPaddle": ["Rear Paddle", Upgrade.Category.ARENA, 2, "+20% speed off the Rear Paddle", 300, 8.0],
	&"Booster": ["Booster", Upgrade.Category.PLACEABLES, 2, "One more Booster", 12, 20.0],
	&"BoosterSpeed": ["Booster Speed", Upgrade.Category.PLACEABLES, 2, "Balls leave a Booster 20% faster still", 500, 6.0],
	&"Zap": ["Zap", Upgrade.Category.PLACEABLES, 3, "One more Zap", 200, 4.0],
	&"ZapRange": ["Zap Range", Upgrade.Category.PLACEABLES, 2, "A Zap reaches 2 more bricks each way", 400, 5.0],
	&"ZapDamage": ["Zap Damage", Upgrade.Category.PLACEABLES, 2, "A Zap hits each brick once more", 800, 5.0],
	&"Splitter": ["Splitter", Upgrade.Category.PLACEABLES, 5, "One more Splitter", 80, 3.0],
	&"SplitterSplits": ["Splitter Splits", Upgrade.Category.PLACEABLES, 2, "A Splitter splits a ball into one more", 2000, 5.0],
	&"SplitterHealth": ["Splitter Health", Upgrade.Category.PLACEABLES, 2, "A Splitter takes one more hit", 500, 6.0],
	&"WallSegment": ["Wall Segment", Upgrade.Category.PLACEABLES, 2, "One more Wall Segment", 40, 10.0],
	&"ExplosiveBrick": ["Explosive Brick", Upgrade.Category.BRICKS, 4, "One more explosive brick", 40, 3.5],
	&"ExplosionSize": ["Explosion Size", Upgrade.Category.BRICKS, 2, "Explosions reach one square further", 150, 20.0],
	&"ExplosionDamage": ["Explosion Damage", Upgrade.Category.BRICKS, 2, "Explosions hit each brick once more", 300, 10.0],
	&"Shockwave": ["Shockwave", Upgrade.Category.BRICKS, 1, "Explosions throw balls", 600, 1.0],
	&"GoldBrick": ["Gold Brick", Upgrade.Category.BRICKS, 3, "One more gold brick", 30, 6.0],
	&"HourglassBrick": ["Hourglass Brick", Upgrade.Category.BRICKS, 2, "One more hourglass brick", 25, 100.0],
	&"HourglassTime": ["Hourglass Time", Upgrade.Category.BRICKS, 2, "An hourglass brick adds 5 s more", 1200, 5.0],
	&"HourglassFreeze": ["Hourglass Freeze", Upgrade.Category.BRICKS, 2, "Breaking an hourglass brick holds the combo", 800, 5.0],
	&"ToughBrick": ["Tough Brick", Upgrade.Category.BRICKS, 3, "One more tough brick", 20, 6.0],
	&"Growth": ["Growth", Upgrade.Category.PLACEABLES, 3, "One more Growth block", 100, 4.5],
	&"GrowthReach": ["Growth Reach", Upgrade.Category.PLACEABLES, 2, "Growth reaches one square further", 300, 10.0],
	&"Refresh": ["Refresh", Upgrade.Category.PLACEABLES, 3, "One more Refresh block", 150, 4.5],
	&"RefreshSize": ["Refresh Size", Upgrade.Category.PLACEABLES, 2, "Refresh brings back 2 more bricks", 400, 10.0],
	&"PulseRate": ["Pulse Rate", Upgrade.Category.PLACEABLES, 2, "Growth and Refresh are 1 s faster", 1000, 6.0],
	&"Overgrowth": ["Overgrowth", Upgrade.Category.ARENA, 1, "Broken bricks grow back", 8000, 1.0],
	&"Guide": ["Guide", Upgrade.Category.ARENA, 4, "+250 guide length", 30, 4.0],
	&"GuideBounces": ["Guide Bounces", Upgrade.Category.ARENA, 1, "The guide line bounces", 250, 1.0],
}
## The drawn web of upgrades.md: each node and the one it hangs off, towards the seed. A node with two links
## (Pulse Rate) hangs off one here and has the other in CROSS.
const PARENT := {
	&"HourglassBrick": &"PaddleSpeed", &"HourglassTime": &"HourglassBrick", &"HourglassFreeze": &"HourglassTime",
	&"Booster": &"PaddleSpeed", &"BoosterSpeed": &"Booster", &"Zap": &"Booster", &"ZapRange": &"Zap",
	&"ZapDamage": &"ZapRange", &"RearPaddle": &"Zap", &"Combo": &"PaddleSpeed", &"ComboWindow": &"Combo",
	&"GoldBrick": &"Combo", &"WallSegment": &"GoldBrick", &"Splitter": &"Combo", &"SplitterSplits": &"Splitter",
	&"SplitterHealth": &"SplitterSplits", &"PaddleSize": &"PaddleSpeed", &"ExplosiveBrick": &"PaddleSize",
	&"ExplosionSize": &"ExplosiveBrick", &"ExplosionDamage": &"ExplosionSize", &"Shockwave": &"ExplosiveBrick",
	&"ToughBrick": &"GoldBrick", &"Growth": &"ToughBrick", &"GrowthReach": &"Growth",
	&"Refresh": &"ToughBrick", &"RefreshSize": &"Refresh", &"PulseRate": &"Refresh",
	&"Overgrowth": &"PulseRate",
	&"Guide": &"Booster", &"GuideBounces": &"Guide",
}
const CROSS := {&"PulseRate": &"Growth"}
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
	t.check(not _hub().has_node("Bar/Hint"), "the top bar has no hint line")
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
	for n in web.nodes():
		var row: Array = TABLE[StringName(n.name)]
		var what := "%s on a %s save" % [n.name, save]
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
		t.check(u.max_rank == row[2] and _text("Detail/%Rank") == "RANK %d" % r, "%s: the rank reads RANK %d, with no max" % [what, r])
		var pips_shown := mini(r + 1, row[2])
		t.check((_hub().get_node("Detail/%Pips") as UiPips).total == pips_shown and (n.get_node("Bottom/Pips") as UiPips).total == pips_shown,
				"%s: %d pips, the ranks owned and the next, on the panel and on the node" % [what, pips_shown])
		t.check(_text("Detail/%Text").begins_with(row[3]), "%s: the effect is the table's \"%s\" (reads \"%s\")" % [what, row[3], _text("Detail/%Text")])
		t.check(_text("Detail/%State") == ["LOCKED", "AVAILABLE", "OWNED", "MAXED"][web.state(n)], "%s: the state on the panel is the node's" % what)
		var price: int = roundi(row[4] * pow(row[5], r))
		var maxed: bool = r >= row[2]
		if not maxed:
			t.check((_hub().get_node("Detail/%Price") as UiPrice).amount == price and (n.get_node("Bottom/Price") as UiPrice).amount == price,
					"%s: the next rank costs %d, on the panel and on the node" % [what, price])
		t.check((_hub().get_node("Detail/%Cost") as Control).visible != maxed and (n.get_node("Bottom/Max") as Control).visible == maxed,
				"%s: the price is gone and MAX shows only when maxed" % what)
		t.check(buy.text == ("MAXED" if maxed else "BUY") and buy.disabled == maxed, "%s: Buy reads %s" % [what, buy.text])
		t.check((n.get_node("Bottom/Price") as UiPrice).dim == not (not maxed and Progress.coins >= price), "%s: the node's price is gold only when it can be bought now" % what)
		t.check((_hub().get_node("Detail") as Control).get_global_rect() == DETAIL, "%s: the detail panel keeps its size (is %s)" % [what, (_hub().get_node("Detail") as Control).get_global_rect()])
		var label := n.get_node("Name") as Label
		t.check(label.get_minimum_size().x <= label.size.x + 0.5 or not label.clip_text, "%s: the name fits on the node" % what)


## Every path out from the seed, bought node by node with clicks: after each buy the open nodes are exactly the
## unbought ones with a bought neighbour on the drawn web, and each rank costs what the table says.
func _paths() -> void:
	for leaf: StringName in PARENT:
		var path: Array[StringName] = [leaf]
		while PARENT.has(path[0]):
			path.push_front(PARENT[path[0]])
		_seed("fresh")
		Progress.coins = 9999
		await _fresh_hub()
		var buy: Button = _hub().get_node("Detail/%Buy")
		for step: StringName in path:
			var n: HubNode = _web().get_node(String(step))
			_web().refresh(n)
			await _click(n)
			var before := Progress.coins
			await _click(buy)
			t.check(Progress.rank(n.upgrade) == 1 and before - Progress.coins == TABLE[step][4], "on the path to %s, Buy on %s buys rank 1 for %d" % [leaf, step, TABLE[step][4]])
			var want: Array[String] = []
			for m in _web().nodes():
				var id := StringName(m.name)
				if Progress.rank(m.upgrade) == 0 and _docs_neighbours(id).any(func(o: StringName) -> bool: return Progress.rank(_web().get_node(String(o)).upgrade) > 0):
					want.append(m.name)
			var have: Array[String] = []
			for m in _web().nodes():
				if _web().state(m) == HubNode.State.AVAILABLE:
					have.append(m.name)
			want.sort()
			have.sort()
			t.check(have == want, "after buying %s on the path to %s, open are %s (open: %s)" % [step, leaf, want, have])


## Paddle Speed bought to its top rank with clicks, a Buy with too few coins, and the cues of each.
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
	var paid: Array[int] = []
	Progress.coins = 200
	for i in 2:
		var before := Progress.coins
		await _quiet()
		await _click(buy)
		await _heard_settle()
		paid.append(before - Progress.coins)
		t.check(heard == [Sfx.BUY], "buying rank %d plays the buy cue once and nothing else (heard %s)" % [i + 1, heard])
	t.check(paid == [5, 150], "Paddle Speed's two ranks cost 5 and 150 (paid %s)" % [paid])
	t.check(_web().state(seed) == HubNode.State.MAXED and buy.disabled and buy.text == "MAXED", "after its top rank it is maxed and Buy reads MAXED")
	t.check(not (_hub().get_node("Detail/%Cost") as Control).visible and (seed.get_node("Bottom/Max") as Control).visible, "the price is gone and the node says MAX")
	var coins := Progress.coins
	await _quiet()
	await _click(buy)
	await _heard_settle()
	t.check(Progress.coins == coins and heard.is_empty(), "a click on the maxed Buy does nothing and plays nothing (heard %s)" % [heard])
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
	# Back buttons, each clicked twice where it is.
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
		var at := back.get_global_rect().get_center()
		await _quiet()
		await _click_at(at)
		await _click_at(at)
		await _heard_settle()
		t.check(_screen().scene_file_path == to and (to == Main.MENU or _hub().is_visible_in_tree()), "the back button in %s, clicked twice, goes one step back" % where)
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
	for u in Progress.upgrades():  # every node owned, so whichever is under the pointer is shown
		Progress.ranks[u.id] = 1
	Progress.rank_changed.emit(_web().seed_node().upgrade)
	await _double_click_at(at)
	t.check(_hub().selected != _web().seed_node(), "a double click that starts in the hub is not dropped: the node under it is selected")
	Progress.ranks.clear()
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
	Progress.unlocked = Levels.count() if top else 2
	for u in Progress.upgrades():
		Progress.ranks[u.id] = u.max_rank if top else ceili(u.max_rank / 2.0)
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
	for links: Dictionary in [PARENT, CROSS]:
		for k: StringName in links:
			if k == id:
				out.append(links[k])
			elif links[k] == id:
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
