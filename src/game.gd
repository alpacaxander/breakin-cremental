extends Node
## Autoload: run state, save, and the game's rules. Rules are checked by test.gd.

const Tuning = preload("res://src/tuning.gd")
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"  # separate from the save: reset() leaves settings alone

var currency := 0
var unlocked := 0  # highest playable level index
var won := false
var best := 0  # most earned in one round
var runs := 0
var ranks := {}  # upgrade id -> rank
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
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(settings.volume, 0.001)))  # no audio yet; the master bus is ready for it


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({currency = currency, unlocked = unlocked, won = won, best = best, runs = runs, ranks = ranks}))


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	currency = int(d.get("currency", 0))
	unlocked = clampi(int(d.get("unlocked", 0)), 0, Tuning.LEVELS.size() - 1)
	won = bool(d.get("won", false))
	best = int(d.get("best", 0))
	runs = int(d.get("runs", 0))
	for k in d.get("ranks", {}):
		if k in Tuning.UPGRADES:
			ranks[k] = int(d.ranks[k])


func reset() -> void:
	currency = 0
	unlocked = 0
	won = false
	best = 0
	runs = 0
	ranks = {}
	save()


func clear_level(level: int) -> void:
	unlocked = clampi(maxi(unlocked, level + 1), 0, Tuning.LEVELS.size() - 1)
	if level == Tuning.LEVELS.size() - 1:
		won = true


# --- Upgrades ---

func rank(id: String) -> int:
	return ranks.get(id, 0)


func bonus(id: String) -> float:
	return rank(id) * Tuning.UPGRADES[id].amount


func cost(id: String) -> int:
	var u: Dictionary = Tuning.UPGRADES[id]
	return roundi(u.cost * pow(u.cost_mult, rank(id)))


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

func paddle_width() -> float:
	return Tuning.PADDLE_WIDTH + bonus("paddle")


func capacity() -> int:
	return Tuning.CAPACITY_BASE + int(bonus("capacity"))


## How many of a placeable the player can put down.
func owned(kind: String) -> int:
	return Tuning.PLACEABLES[kind].get("start", 0) + rank(kind)


func round_time(breakable: int) -> float:
	return Tuning.ROUND_TIME_BASE + breakable * Tuning.ROUND_TIME_PER_BRICK + bonus("time")


func combo_window(combo: int) -> float:
	return maxf(Tuning.COMBO_WINDOW_MIN, Tuning.COMBO_WINDOW_START + bonus("combo") - Tuning.COMBO_WINDOW_SHRINK * (combo - 1))


func combo_mult(combo: int) -> float:
	return 1.0 + Tuning.COMBO_MULT_PER_HIT * maxi(combo - 1, 0)


func payout(level: int, combo: int) -> int:
	return roundi(Tuning.LEVELS[level].payout * combo_mult(combo))


# --- Board generation ---

## Returns [{pos: Vector2, kind: String}], kinds from Tuning.BRICKS. Always has at least one breakable brick.
func generate(level: int, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var L: Dictionary = Tuning.LEVELS[level]
	var step := Tuning.BRICK_SIZE + Vector2.ONE * Tuning.BRICK_GAP
	var out := []
	for r in L.rows:
		var cols: int = L.cols - (2 * (L.rows - 1 - r) if L.shape == "triangle" else 0)
		for c in cols:
			if rng.randf() < L.holes:
				continue
			var pos := Vector2(Tuning.VIEW.x / 2 + (c - (cols - 1) / 2.0) * step.x, Tuning.BOARD_TOP + r * step.y)
			var kind := "solid" if rng.randf() < L.solid else "plain"
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
			if b.kind != "solid" and n1 and n2 and n1[0].kind != "solid" and n2[0].kind != "solid":
				b.kind = "seq1"
				n1[0].kind = "seq2"
				n2[0].kind = "seq3"
				break
	if L.get("jackpot", false):
		var free := breakable.filter(func(b): return not b.kind.begins_with("seq"))
		free[rng.randi() % free.size()].kind = "jackpot"
	return out
