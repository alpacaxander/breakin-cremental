extends Node
## Autoload: run state, save, and the game's rules. Rules are checked by test.gd.

const Tuning = preload("res://src/tuning.gd")
const SAVE_PATH := "user://save.json"

var currency := 0
var unlocked := 0  # highest playable level index
var won := false
var ranks := {}  # upgrade id -> rank


func _ready() -> void:
	load_save()


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({currency = currency, unlocked = unlocked, won = won, ranks = ranks}))


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	currency = int(d.get("currency", 0))
	unlocked = clampi(int(d.get("unlocked", 0)), 0, Tuning.LEVELS.size() - 1)
	won = bool(d.get("won", false))
	for k in d.get("ranks", {}):
		if k in Tuning.UPGRADES:
			ranks[k] = int(d.ranks[k])


func reset() -> void:
	currency = 0
	unlocked = 0
	won = false
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


func bumpers() -> int:
	return Tuning.START_BUMPERS + int(bonus("bumper"))


func round_time(breakable: int) -> float:
	return Tuning.ROUND_TIME_BASE + breakable * Tuning.ROUND_TIME_PER_BRICK + bonus("time")


func combo_window(combo: int) -> float:
	return maxf(Tuning.COMBO_WINDOW_MIN, Tuning.COMBO_WINDOW_START + bonus("combo") - Tuning.COMBO_WINDOW_SHRINK * (combo - 1))


func combo_mult(combo: int) -> float:
	return 1.0 + Tuning.COMBO_MULT_PER_HIT * maxi(combo - 1, 0)


func payout(level: int, combo: int) -> int:
	return roundi(Tuning.LEVELS[level].payout * combo_mult(combo))


# --- Board generation ---

## Returns [{pos: Vector2, kind: "plain" | "solid"}]. Always has at least one plain brick.
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
			out.append({pos = pos, kind = "solid" if rng.randf() < L.solid else "plain"})
	if not out.any(func(b): return b.kind == "plain"):
		out[0].kind = "plain"  # ponytail: assumes holes never empty the whole board
	return out
