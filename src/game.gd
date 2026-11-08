extends Node
## Autoload: run state, save, and the game's rules. Rules are checked by test.gd.

const Tuning = preload("res://src/tuning.gd")
const SAVE_PATH := "user://save.json"
const SANDBOX_PATH := "user://sandbox.json"  # the dev save: same shape, starts with every rank maxed and every level open
const SETTINGS_PATH := "user://settings.json"  # separate from the save: reset() leaves settings alone

var currency := 0
var unlocked := 0  # highest playable level index
var won := false
var best := 0  # most earned in one round
var runs := 0
var broken := {}  # level index (as a string, JSON keys) -> best share of bricks broken in one round, 0..100. Not a win condition
var ranks := {}  # upgrade id -> rank
var layouts := {}  # level index (as a string) -> [{kind, x, y, rot}]: the pieces placed last time, put back at the next placement
var slot := SAVE_PATH  # which file holds the run in memory: SAVE_PATH or SANDBOX_PATH (enter_sandbox / leave_sandbox)
var sandbox: bool:
	get: return slot == SANDBOX_PATH
var settings := {fullscreen = false, volume = 1.0}


func _ready() -> void:
	load_save()
	load_settings()


# --- Settings ---

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	FileAccess.open(SETTINGS_PATH, FileAccess.WRITE).store_string(JSON.stringify(settings))


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(d) == TYPE_DICTIONARY:
			for k in settings:
				if k in d:
					settings[k] = type_convert(d[k], typeof(settings[k]))
	apply_settings()


func apply_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(settings.volume, 0.001)))  # every cue (src/sfx.gd) plays on the master bus


# --- Save: one JSON object per slot file. load_save wipes to the slot's defaults first, so slots never mix. ---

func save() -> void:
	var f := FileAccess.open(slot, FileAccess.WRITE)
	f.store_string(JSON.stringify({currency = currency, unlocked = unlocked, won = won, best = best, runs = runs, ranks = ranks, broken = broken, layouts = layouts}))


func load_save() -> void:
	wipe()
	if not FileAccess.file_exists(slot):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(slot))
	if typeof(d) != TYPE_DICTIONARY:
		return
	currency = int(d.get("currency", 0))
	unlocked = clampi(int(d.get("unlocked", 0)), 0, Tuning.LEVELS.size() - 1)
	won = bool(d.get("won", false))
	best = int(d.get("best", 0))
	runs = int(d.get("runs", 0))
	for k in d.get("broken", {}):
		broken[k] = int(d.broken[k])
	for k in d.get("ranks", {}):
		if k in Tuning.UPGRADES:
			ranks[k] = int(d.ranks[k])
	layouts = d.get("layouts", {})  # place.gd drops any entry that no longer fits (unowned kind, over capacity, off the board)


func reset() -> void:
	wipe()
	save()


## The slot's fresh state: zero for the real run, everything owned for the sandbox.
func wipe() -> void:
	currency = 999999 if sandbox else 0
	unlocked = Tuning.LEVELS.size() - 1 if sandbox else 0
	won = false
	best = 0
	runs = 0
	ranks = {}
	broken = {}
	layouts = {}
	if sandbox:
		for id in Tuning.UPGRADES:
			ranks[id] = Tuning.UPGRADES[id].ranks


## Best share of bricks broken on a level, kept across rounds. A retry stat, not a win condition.
func note_broken(level: int, done: int, total: int) -> void:
	broken[str(level)] = maxi(broken.get(str(level), 0), 100 * done / maxi(total, 1))


## A level's unlock row as a label for the shop: "CLEAR" or "COMBO x10".
func unlock_text(level: int) -> String:
	var u: Dictionary = Tuning.LEVELS[level].get("unlock", {})
	return "COMBO x%d" % u.combo if u.has("combo") else "CLEAR"


## Round over on `level`: win on clearing the last, open the next if its `unlock` row is met. Returns whether a level just opened.
func finish_level(level: int, cleared: bool, best_combo: int) -> bool:
	var next := level + 1
	if cleared and next == Tuning.LEVELS.size():
		won = true
	if next >= Tuning.LEVELS.size() or unlocked >= next:
		return false
	var u: Dictionary = Tuning.LEVELS[next].get("unlock", {})
	if not (best_combo >= u.combo if u.has("combo") else cleared):
		return false
	unlocked = next
	return true


# --- Sandbox ---

## Switch to the dev save. Every change already saves to its own file, so switching is just loading the other one.
func enter_sandbox() -> void:
	slot = SANDBOX_PATH
	load_save()


func leave_sandbox() -> void:
	slot = SAVE_PATH
	load_save()


# --- Upgrades ---

func rank(id: String) -> int:
	return ranks.get(id, 0)


func bonus(id: String) -> float:
	return rank(id) * Tuning.UPGRADES[id].amount


## A tuning number plus an upgrade's bonus. Most nodes are one of these at their call site.
func stat(base: float, id: String) -> float:
	return base + bonus(id)


func cost(id: String) -> int:
	var u: Dictionary = Tuning.UPGRADES[id]
	return roundi(u.cost * pow(Tuning.COST_MULT, rank(id)))


func is_revealed(id: String) -> bool:
	if id == Tuning.SEED_UPGRADE:
		return true
	for o in Tuning.UPGRADES:
		if rank(o) > 0 and (id in Tuning.UPGRADES[o].links or o in Tuning.UPGRADES[id].links):
			return true
	return false


func can_buy(id: String) -> bool:
	return is_revealed(id) and rank(id) < Tuning.UPGRADES[id].ranks and currency >= cost(id)


func buy(id: String) -> void:
	if not can_buy(id):
		return
	currency -= cost(id)
	ranks[id] = rank(id) + 1


# --- Derived stats ---

func paddle_speed() -> float:
	return stat(Tuning.PADDLE_SPEED, "speed")


func capacity() -> int:
	return Tuning.CAPACITY_BASE + int(bonus("capacity"))


## How many of a placeable the player can put down.
func owned(kind: String) -> int:
	return Tuning.PLACEABLES[kind].get("start", 0) + rank(kind)


func piece_cost(kind: String) -> int:
	return maxi(1, Tuning.PLACEABLES[kind].cost - int(bonus("cheaper")))


## How far above the arena floor placed pieces must stay.
func place_up() -> float:
	return stat(Tuning.PLACE_UP, "floor")


func rotate_deg() -> float:
	return Tuning.ROTATE_DEG / (1 + rank("rotate"))


func base_pay(level: int) -> int:
	return Tuning.LEVELS[level].payout + int(bonus("payout"))


## The arena's size for a level, game px, from the row's size in standard bricks (each brick plus a gap, and one more gap).
## ponytail: an upgrade that widens the arena adds its bonus here, capped at Tuning.ARENA.
func arena_size(level: int) -> Vector2:
	if not Tuning.LEVELS[level].has("arena"):
		return Tuning.ARENA
	var gap := Vector2.ONE * Tuning.BRICK_GAP
	return Tuning.LEVELS[level].arena * (Tuning.BRICK_SIZE + gap) + gap


## Centre y of the first brick row, arena px.
func board_top(level: int) -> float:
	return Tuning.LEVELS[level].get("top", Tuning.BOARD_TOP)


func round_time(level: int) -> float:
	return stat(Tuning.ROUND_TIME_BASE, "time") * Tuning.LEVELS[level].get("time", 1.0)


func combo_window(combo: int) -> float:
	return maxf(Tuning.COMBO_WINDOW_MIN, stat(Tuning.COMBO_WINDOW_START, "combos") - Tuning.COMBO_WINDOW_SHRINK * (combo - 1))


func combo_mult(combo: int) -> float:
	return 1.0 + Tuning.COMBO_MULT_PER_HIT * maxi(combo - 1, 0)


func payout(level: int, combo: int) -> int:
	return roundi(base_pay(level) * combo_mult(combo))


# --- Board generation ---

## Returns [{pos: Vector2, kind: String}] in arena px (origin top-left), kinds from Tuning.BRICKS. Always has at least one breakable brick.
func generate(level: int, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var L: Dictionary = Tuning.LEVELS[level]
	var step := Tuning.BRICK_SIZE + Vector2.ONE * Tuning.BRICK_GAP
	# Extra rows stop where the board would reach the placement line (the same bound test.gd checks).
	var max_rows := int((arena_size(level).y - Tuning.PLACE_UP - board_top(level) - Tuning.BRICK_SIZE.y / 2 - 1) / step.y) + 1
	var rows: int = mini(L.rows + int(bonus("row")), max_rows)
	var holes: float = maxf(0, stat(L.holes, "holes"))
	var solid: float = maxf(0, stat(L.solid, "solids"))
	var out := []
	for r in rows:
		var cols: int = L.cols - (r % 2 if L.shape == "honey" else 0)
		for c in cols:
			if c in L.get("skip", []):
				continue
			# columns: 2-wide pairs a one-brick gap apart; the centre pair is a row short at both ends, each pair out one row shorter again.
			if L.shape == "columns" and (c % 3 == 2 or absf(r - (rows - 1) / 2.0) > (rows - 1) / 2.0 - 1 - absi(c / 3 - cols / 3 / 2)):
				continue
			var pos := Vector2(arena_size(level).x / 2 + (c - (cols - 1) / 2.0) * step.x, board_top(level) + r * step.y)
			# A hole is a brick kind, not a gap: every seed fills the same slots, so a saved layout always fits (place.gd).
			var kind := "hole" if rng.randf() < holes else "solid" if rng.randf() < solid else "plain"
			if kind == "plain":
				var roll := rng.randf()
				for k in L.get("special", {}):
					roll -= L.special[k]
					if roll < 0:
						kind = k
						break
			out.append({pos = pos, kind = kind})
	var breakable := out.filter(func(b): return Tuning.BRICKS[b.kind].hp > 0)
	if breakable.is_empty():
		out[0].kind = "plain"  # ponytail: assumes holes never empty the whole board
		breakable = [out[0]]
	if L.get("seq", false):
		# First brick (from a random start) with two neighbours to its right becomes the 1-2-3 run.
		var at := func(p: Vector2): return out.filter(func(b): return b.pos.is_equal_approx(p))
		var start := rng.randi() % out.size()
		for i in out.size():
			var b: Dictionary = out[(start + i) % out.size()]
			var n1: Array = at.call(b.pos + Vector2(step.x, 0))
			var n2: Array = at.call(b.pos + Vector2(step.x * 2, 0))
			var soft := func(x: Dictionary): return Tuning.BRICKS[x.kind].hp > 0  # not solid, not a hole
			if soft.call(b) and n1 and n2 and soft.call(n1[0]) and soft.call(n2[0]):
				b.kind = "seq1"
				n1[0].kind = "seq2"
				n2[0].kind = "seq3"
				break
	if L.get("jackpot", false):
		var free := breakable.filter(func(b): return not b.kind.begins_with("seq"))
		free[rng.randi() % free.size()].kind = "jackpot"
	# Unlocked icon kinds: each rank (plus twin) turns one plain brick into that kind, while plain bricks last.
	for k in Tuning.ICON_KINDS:
		if k in Tuning.UPGRADES and rank(k) > 0:
			for i in rank(k) + rank("twin"):
				var plain := out.filter(func(b): return b.kind == "plain")
				if plain.is_empty():
					break
				plain[rng.randi() % plain.size()].kind = k
	return out
