extends Node
## Autoload: settings (settings.json, with the meta-unlock flags, run / win counts and the catalog's seen ids under `meta`), the run state (`run`: hp, gold, the bag,
## relics, the map with its visited path and rolled enemies and events, `pending` = the node kind entered and not yet
## resolved, stats) with its mid-run save (run.json), and the pure rules: map generation, node entry, reward / shop / enemy
## rolls, event choices, gold and HP, the bag invariant, board generation. No scene dependencies, so test.gd instantiates
## it headless. docs/content.md "Run state" is the contract.

const Tuning = preload("res://src/tuning.gd")
const SETTINGS_PATH := "user://settings.json"
const RUN_PATH := "user://run.json"
const RUN_VERSION := 1

var settings := {fullscreen = false, volume = 1.0, meta = {flags = [], runs = 0, wins = 0, seen = []}}
var run := {}  # empty until new_run / load_run


func _ready() -> void:
	load_settings()


# --- Settings ---

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	FileAccess.open(SETTINGS_PATH, FileAccess.WRITE).store_string(JSON.stringify(settings))


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = _ints(JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH)))
		if typeof(d) == TYPE_DICTIONARY:
			for k in settings:
				if k == "meta" and typeof(d.get(k)) == TYPE_DICTIONARY:
					settings.meta.merge(d.meta, true)
				elif k in d:
					settings[k] = type_convert(d[k], typeof(settings[k]))
	apply_settings()


func apply_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(settings.volume, 0.001)))  # every cue (src/sfx.gd) plays on the master bus


## Sets a meta-unlock flag. True when it was new (the end screen's "UNLOCKED:" line).
func set_flag(flag: String) -> bool:
	if flag in settings.meta.flags:
		return false
	settings.meta.flags.append(flag)
	set_setting("meta", settings.meta)
	return true


## A ball or relic id whose row has no `locked`, or whose flag is set.
func unlocked(id: String) -> bool:
	var row: Dictionary = Tuning.BALLS.get(id, Tuning.RELICS.get(id, {}))
	return not row.has("locked") or row.locked in settings.meta.flags


## Sets a flag; when it is new, its ids join run.unlocked (the end screen's "UNLOCKED:" line).
func unlock(flag: String) -> void:
	if set_flag(flag):
		run.unlocked = run.get("unlocked", []) + Tuning.UNLOCKS[flag]  # get: a run.json saved before meta-unlocks has no list


## Records a ball or enemy id as met, for the menu's catalog. Writes settings.json only when it is new.
func see(id: String) -> void:
	var seen: Array = settings.meta.get_or_add("seen", [])  # get_or_add: a meta reset by test.gd has no list
	if not id in seen:
		seen.append(id)
		set_setting("meta", settings.meta)


## The run is over: counts it (and a win) in meta, sets finished_run and, on a win, won_boss.
func end_run(win: bool) -> void:
	settings.meta.runs += 1
	settings.meta.wins += int(win)
	unlock("finished_run")
	if win:
		unlock("won_boss")
	set_setting("meta", settings.meta)


# --- Run state ---

func new_run(seed: int = randi()) -> void:
	run = {version = RUN_VERSION, seed = seed, hp = Tuning.RUN.hp, hp_max = Tuning.RUN.hp, gold = Tuning.RUN.gold,
		bag = Tuning.BAG_START.map(func(id): return {id = id, rank = 1}), relics = [], map = gen_map(seed), pending = "", unlocked = [], removed = "",
		stats = {fights = 0, elites = 0, damage = 0, bricks = 0, best_fire = 0, drops = 0, gold_earned = 0, seconds = 0, killer = ""}}
	for id in Tuning.BAG_START:
		see(id)


func save_run(path: String = RUN_PATH) -> void:
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(run))


## True when a saved run of this version loaded into `run`.
func load_run(path: String = RUN_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var d = _ints(JSON.parse_string(FileAccess.get_file_as_string(path)))
	if typeof(d) != TYPE_DICTIONARY or d.get("version") != RUN_VERSION:
		return false
	run = d
	return true


func has_run() -> bool:
	return FileAccess.file_exists(RUN_PATH)


func delete_run() -> void:
	DirAccess.remove_absolute(RUN_PATH)


## True when hp hit 0: the run is over.
func hurt(n: int) -> bool:
	run.hp = maxi(0, run.hp - n)
	return run.hp <= 0


func heal(n: int) -> void:
	run.hp = mini(run.hp_max, run.hp + n)


func add_gold(n: int) -> void:
	run.gold += n
	run.stats.gold_earned += n


## Pays n gold; false and nothing paid when short.
func spend(n: int) -> bool:
	if run.gold < n:
		return false
	run.gold -= n
	return true


func has(relic: String) -> bool:
	return relic in run.relics


func add_ball(id: String, rank: int = 1) -> void:
	run.bag.append({id = id, rank = rank})
	see(id)


## Removes bag[i] unless that would leave no non-junk ball (the bag invariant). True when removed; the id stays in
## run.removed for the shop's BUY BACK.
func remove_ball(i: int) -> bool:
	var rest: Array = run.bag.duplicate()
	rest.remove_at(i)
	if not rest.any(func(b): return b.id != "ball_junk"):
		return false
	run.removed = run.bag[i].id
	run.bag = rest
	return true


func relic_price(id: String) -> int:
	return Tuning.RELIC_RARITY[Tuning.RELICS[id].rarity].price


## Deterministic per roll site: seed + the node's index, so a reload replays the same map, shop and rewards.
func rng(site: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = run.seed + site
	return r


## A node's roll-site index: its position in reading order, from 1 (0 is the map itself).
static func node_index(layer: int, slot: int) -> int:
	var n := 1
	for i in layer:
		n += Tuning.MAP[i].slots.size()
	return n + slot


## The rng of the node the run stands on; salt keeps a node's second roll site (reward after enemy, treasure after reward) apart.
func node_rng(salt: int = 0) -> RandomNumberGenerator:
	return rng(node_index(run.map.layer, run.map.node) + 1000 * salt)


# --- Map ---

## Rolls the layer kinds. Enemies and events are "" until enter_node rolls them, since both depend on the path walked.
## layer -1 / node -1 means nothing entered yet; path is the slot entered in each layer.
func gen_map(seed: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var layers := []
	for L in Tuning.MAP:
		var row := []
		for s in L.slots:
			row.append(s if s is String else _weighted(s, r))
		if L.has("force") and not "fight" in row:
			row[L.force] = "fight"
		layers.append(row)
	var blank := layers.map(func(row): return row.map(func(_k): return ""))
	return {layers = layers, enemies = blank, events = blank.duplicate(true), path = [], layer = -1, node = -1}


func reachable(slot: int) -> bool:
	var m: Dictionary = run.map
	if m.layer < 0:
		return slot < Tuning.MAP[0].slots.size()
	return m.layer + 1 < Tuning.MAP.size() and slot in Tuning.MAP[m.layer].edges[m.node]


## Steps onto the next layer's slot, rolling its enemy or event (never the last fight's enemy, events without
## replacement along the path), marks it pending (main.gd clears that back on the map), autosaves, and returns the node kind.
func enter_node(slot: int) -> String:
	var m: Dictionary = run.map
	m.layer += 1
	m.node = slot
	m.path.append(slot)
	var kind: String = m.layers[m.layer][slot]
	run.pending = kind
	var r := rng(node_index(m.layer, slot))
	if kind in ["fight", "elite", "boss"]:
		m.enemies[m.layer][slot] = pick_enemy(kind, m.layer + 1, last_enemy(m.layer), r)
		see(m.enemies[m.layer][slot])
	elif kind == "event":
		var seen := []
		for i in m.layer:
			seen.append(m.events[i][m.path[i]])
		var pool := Tuning.EVENTS.keys().filter(func(e): return not e in seen)
		m.events[m.layer][slot] = pool[r.randi() % pool.size()]
	save_run()
	return kind


## The enemy fought most recently before `layer` along the path, or "".
func last_enemy(layer: int) -> String:
	var m: Dictionary = run.map
	for i in range(layer - 1, -1, -1):
		if m.enemies[i][m.path[i]] != "":
			return m.enemies[i][m.path[i]]
	return ""


## An enemy for a fight / elite / boss node in a 1-based layer: regulars of tier <= layer, never prev when another fits.
func pick_enemy(kind: String, layer: int, prev: String, r: RandomNumberGenerator) -> String:
	var role := "regular" if kind == "fight" else kind
	var ids := Tuning.ENEMIES.keys().filter(func(id):
		var e: Dictionary = Tuning.ENEMIES[id]
		return e.role == role and (kind != "fight" or e.tier <= layer))
	if ids.size() > 1:
		ids.erase(prev)
	return ids[r.randi() % ids.size()]


# --- Rewards and shop ---

## Up to 3 cards of distinct kinds: {kind = "ball", id} / {kind = "rank", at} (bag index) / {kind = "relic", id} / {kind = "gold", gold}.
## ponytail: a kind with nothing eligible is dropped, so a full bag of rank-3 balls and no relics left yields 2 cards; the screen shows what it gets.
func roll_reward(r: RandomNumberGenerator) -> Array:
	var kinds: Dictionary = Tuning.REWARDS.duplicate()
	var cards := []
	while cards.size() < 3 and not kinds.is_empty():
		var k := _weighted(kinds, r)
		kinds.erase(k)
		var c := _card(k, r)
		if not c.is_empty():
			cards.append(c)
	return cards


func _card(kind: String, r: RandomNumberGenerator) -> Dictionary:
	match kind:
		"ball":
			return {kind = kind, id = roll_ball(r)}
		"rank":
			var ok := range(run.bag.size()).filter(func(i): return run.bag[i].id != "ball_junk" and run.bag[i].rank < Tuning.MAX_RANK)
			return {kind = kind, at = ok[r.randi() % ok.size()]} if ok else {}
		"relic":
			var id := roll_relic(r)
			return {kind = kind, id = id} if id else {}
	return {kind = kind, gold = Tuning.REWARD_GOLD}


## Applies a reward card to the run.
func take_reward(c: Dictionary) -> void:
	match c.kind:
		"ball": add_ball(c.id)
		"rank": run.bag[c.at].rank += 1
		"relic": run.relics.append(c.id)
		"gold": add_gold(c.gold)


## A random unlocked non-junk ball: rarity tier roll, then uniform within the tier (an empty tier rerolls).
func roll_ball(r: RandomNumberGenerator) -> String:
	var pool := []
	while pool.is_empty():
		var tier := _weighted(Tuning.RARITY, r)
		pool = Tuning.BALLS.keys().filter(func(id): return Tuning.BALLS[id].rarity == tier and unlocked(id))
	return pool[r.randi() % pool.size()]


## A random unowned unlocked relic weighted by rarity (RELIC_RARITY's weights, or `weights` where it names the rarity),
## from `rarities`, or "" when none is left.
func roll_relic(r: RandomNumberGenerator, rarities: Array = Tuning.RELIC_RARITY.keys(), skip: Array = [], weights: Dictionary = {}) -> String:
	var w := {}
	for id in Tuning.RELICS:
		var rarity: String = Tuning.RELICS[id].rarity
		if not has(id) and unlocked(id) and not id in skip and rarity in rarities:
			w[id] = weights.get(rarity, Tuning.RELIC_RARITY[rarity].weight)
	return _weighted(w, r) if w else ""


## Up to n distinct unowned unlocked relic ids (the treasure's cards); fewer when the pool runs dry.
func roll_relics(r: RandomNumberGenerator, n: int) -> Array:
	var out := []
	for i in n:
		var id := roll_relic(r, Tuning.RELIC_RARITY.keys(), out)
		if id:
			out.append(id)
	return out


# --- Events ---

## The node's relic (the vendor's, the fried cabinet's): a common or uncommon one, the same for this node's dim check and
## its choice; "" when none is left.
func event_relic() -> String:
	return roll_relic(node_rng(3), ["common", "uncommon"])


## False when a choice is dimmed: the vendor's buy needs its price and a relic, the fried cabinet's plug its gold and its play a relic.
func event_can(id: String, which: String) -> bool:
	match [id, which]:
		["event_vendor", "a"]: return run.gold >= Tuning.EVENTS[id].price and event_relic() != ""
		["event_fried_cabinet", "a"]: return run.gold >= Tuning.EVENTS[id].gold
		["event_fried_cabinet", "b"]: return event_relic() != ""
	return true


## Applies an event choice (docs/content.md "Gold, rewards, shop, events") and returns its result line. An HP cost floors at RUN.hp_floor.
func event_choice(id: String, which: String) -> String:
	var E: Dictionary = Tuning.EVENTS[id]
	var r := node_rng()
	var cost := func(n: int): run.hp = maxi(Tuning.RUN.hp_floor, run.hp - n)
	match id:
		"event_coin_return":
			if which == "b":
				return "YOU WALK ON."
			add_gold(E.gold)
			add_ball(E.junk)
			return "+%d GOLD. A STONE RATTLES INTO YOUR BAG." % E.gold
		"event_mod_shop":
			if which == "b":  # sells a stone when there is one, else any ball the invariant lets go
				var junk := range(run.bag.size()).filter(func(i): return run.bag[i].id == "ball_junk")
				var pool: Array = junk if junk else range(run.bag.size())
				var i: int = pool[r.randi() % pool.size()]
				var name: String = Tuning.BALLS[run.bag[i].id].name
				if not remove_ball(i):
					return "THE KID EYES YOUR LAST BALL. YOU KEEP IT."
				add_gold(E.gold)
				return "%s SOLD. +%d GOLD." % [name, E.gold]
			var ok := range(run.bag.size()).filter(func(i): return run.bag[i].id != "ball_junk" and run.bag[i].rank < Tuning.MAX_RANK)
			if ok.is_empty():
				return "NOTHING LEFT TO MOD. YOU WALK ON."
			var b: Dictionary = run.bag[ok[r.randi() % ok.size()]]
			b.rank += 1
			cost.call(E.hp)
			return "%s IS NOW RANK %d. THE IRON COST %d HP." % [Tuning.BALLS[b.id].name, b.rank, E.hp]
		"event_fried_cabinet":
			if which == "a":
				spend(E.gold)
				heal(E.heal)
				return "THE SMOKE CLEARS. +%d HP, -%d GOLD." % [E.heal, E.gold]
			var relic := event_relic()
			run.relics.append(relic)
			cost.call(E.hp)
			return "IT PLAYS YOU. %s IS YOURS. -%d HP." % [Tuning.RELICS[relic].name, E.hp]
		"event_vendor":
			var relic := event_relic()
			if which == "a":
				spend(E.price)
				run.relics.append(relic)
				return "%s IS YOURS." % Tuning.RELICS[relic].name
			if relic and r.randf() < E.haggle:
				run.relics.append(relic)
				return "IT SHRUGS. %s IS YOURS, FREE." % Tuning.RELICS[relic].name
			add_ball(E.junk)
			return "IT SNEERS. A STONE JOINS YOUR BAG."
	if which == "a":  # event_spring
		heal(E.heal)
		return "WARM. +%d HP." % E.heal
	add_gold(E.gold)
	cost.call(E.hp)
	return "+%d GOLD, AND A CHILL. -%d HP." % [E.gold, E.hp]


## Shop stock: {balls = [3 distinct unlocked ids of SHOP.rarities, the first a SHOP.map ball when one fits], relics = [up to
## 2 distinct unowned unlocked ids, weighted by SHOP.relic_weights]}.
func roll_shop(r: RandomNumberGenerator) -> Dictionary:
	var S: Dictionary = Tuning.SHOP
	var balls := Tuning.BALLS.keys().filter(func(id): return Tuning.BALLS[id].rarity in S.rarities and unlocked(id))
	var stock := {balls = [], relics = []}
	for i in S.balls:
		var pool: Array = balls.filter(func(id): return Tuning.BALLS[id].get("map", 0) == S.map) if i == 0 else []
		if pool.is_empty():
			pool = balls
		var id: String = pool[r.randi() % pool.size()]
		balls.erase(id)
		stock.balls.append(id)
	for i in S.relics:
		var id := roll_relic(r, Tuning.RELIC_RARITY.keys(), stock.relics, S.relic_weights)
		if id:
			stock.relics.append(id)
	return stock


## A key of w drawn by weight.
func _weighted(w: Dictionary, r: RandomNumberGenerator) -> String:
	var roll: float = r.randf() * w.values().reduce(func(a, b): return a + b, 0)
	for k in w:
		roll -= w[k]
		if roll < 0:
			return k
	return w.keys().back()


## JSON reads every number as a float; whole ones come back as ints so they index arrays and print without ".0".
func _ints(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if v == floorf(v) else v
		TYPE_ARRAY:
			return v.map(_ints)
		TYPE_DICTIONARY:
			for k in v:
				v[k] = _ints(v[k])
	return v


# --- Board generation ---

## A board for a fight class (Tuning.BOARDS key) from an enemy's `board`: [{pos, row, col, kind}] in arena px (origin
## top-left), kinds from Tuning.BRICKS. board.rows is the drawn layout (Tuning.BOARD_KEYS): drawn kinds stand, and each
## "?" rolls solid / bomb / red in that order under their max; a roll that breaks a placement rule (solid off the row's
## ends and the bottom row and never touching a solid, red in its rows and never touching a red) stays plain. Then plain
## bricks convert until there are at least crit and refresh of each: crit away from solids and crits in the column with
## the fewest, refresh in the top half away from crits and one per column; a conversion with nothing eligible drops its
## rules so the count holds. Touching means within one column step, so offset rows count their pair.
## board: rows, top (px below BOARD_TOP), no_refresh_rows.
func generate(cls: String, seed: int, board: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var B: Dictionary = Tuning.BOARDS[cls]
	var rows: Array = board.rows
	var step := Tuning.BRICK_SIZE + Vector2.ONE * Tuning.BRICK_GAP
	var out := []
	for r in rows.size():
		var line: String = rows[r]
		for c in line.length():
			var kind: String = Tuning.BOARD_KEYS[line[c]]
			if kind:
				out.append({pos = Vector2(Tuning.ARENA.x / 2 + (c - (line.length() - 1) / 2.0) * step.x, Tuning.BOARD_TOP + board.get("top", 0) + r * step.y), row = r, col = c, kind = kind})
	var count := {solid = 0, bomb = 0, red = 0}
	var near := func(b: Dictionary, kind: String) -> bool:
		return out.any(func(o): return o != b and o.kind == kind and o.pos.distance_to(b.pos) <= step.x + 1)
	for b in out.filter(func(o): return o.kind == "?"):
		b.kind = "plain"
		for k in ["solid", "bomb", "red"]:
			if count[k] < B[k][1] and rng.randf() < B[k][0]:
				b.kind = k
				break
		var edge: bool = b.col == 0 or b.col == rows[b.row].length() - 1 or b.row == rows.size() - 1
		if b.kind == "solid" and (edge or near.call(b, "solid")) or b.kind == "red" and (b.row >= B.get("red_rows", rows.size()) or near.call(b, "red")):
			b.kind = "plain"  # a failing slot rolls plain
		if b.kind in count:
			count[b.kind] += 1
	var plain := func(ok: Callable) -> Array:
		var e: Array = out.filter(func(b): return b.kind == "plain" and ok.call(b))
		return e if e else out.filter(func(b): return b.kind == "plain")  # nothing eligible: the rules drop, the count holds
	var crits := func(col: int) -> int: return out.filter(func(o): return o.kind == "crit" and o.col == col).size()
	var drawn := func(kind: String) -> int: return out.filter(func(o): return o.kind == kind).size()
	for i in B.crit - drawn.call("crit"):
		var e: Array = plain.call(func(b): return not near.call(b, "solid") and not near.call(b, "crit"))
		if e.is_empty():
			break
		var least: int = e.map(func(b): return crits.call(b.col)).min()
		e = e.filter(func(b): return crits.call(b.col) == least)
		e[rng.randi() % e.size()].kind = "crit"
	for i in B.refresh - drawn.call("refresh"):
		var one_per_col := func(b: Dictionary) -> bool: return not out.any(func(o): return o.kind == "refresh" and o.col == b.col)
		var e: Array = plain.call(func(b): return b.row >= board.get("no_refresh_rows", 0) and b.row < rows.size() / 2 and not near.call(b, "crit") and one_per_col.call(b))
		if e.is_empty():
			break
		e[rng.randi() % e.size()].kind = "refresh"
	return out
