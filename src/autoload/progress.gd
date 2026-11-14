extends Node
## Autoload `Progress`: the one save slot, and the stats that come out of it.
##
## THE SAVE is one JSON file:
##     {
##       "version": 1,
##       "coins": 142,
##       "ranks": {"paddle_speed": 2, "bumper": 1},
##       "unlocked": 2,
##       "layouts": {"1": [{"kind": "bumper", "x": 512.0, "y": 256.0, "rot": 0.0}]}
##     }
##   version   VERSION of the build that wrote it. A later build reads an older file by upgrading it step by step.
##   ranks     upgrade id -> ranks owned. A missing id is rank 0. An id with no file is ignored, and a rank above
##             the upgrade's max_rank is lowered to it.
##   unlocked  the highest level unlocked, counted from 1: one more than the highest level cleared. So once the
##             last level is cleared it is one past the last level. That is how the win is saved, and a level
##             added later is then already open.
##   layouts  level number, as a string -> that level's Layout.to_data().
## Nothing about a round in progress is saved. A missing file is a fresh save: 0 coins, no ranks, level 1
## unlocked, no layouts. A file that cannot be read, or whose version is newer than VERSION, is renamed to
## <path>.bad and the game starts fresh.
##
## It saves after every purchase (buy), after every round (finish_round) and when a layout changes (set_layout).
## Changing a field directly does not save.
##
## WHAT THIS SCRIPT DOES NOT LOOK INTO. A layout is stored as the Array that Layout.to_data() gave, and handed to
## Layout.from_data() as the file returned it; Progress never reads what is inside. After a trip through JSON
## every number in it is a float (30 comes back as 30.0), and from_data accepts that. So the save round trip can
## be checked on the `layouts` field with any Array of Dictionaries, before Layout is written. The number of
## levels is `level_count`, which a test may set, so unlocking can be checked before any level scene exists.

## The coin balance changed.
signal coins_changed(coins: int)
## An upgrade was bought. rank(upgrade) is its new rank.
signal rank_changed(upgrade: Upgrade)
## A level was unlocked. `level` is the new highest level, and it exists: clearing the last level emits nothing.
signal level_unlocked(level: int)

const VERSION := 1
const BALANCE := "res://data/balance.tres"
const UPGRADES := "res://data/upgrades"

## Where the save is. Change it with use(), never directly.
var path := "user://save.json"
## The base numbers, loaded from BALANCE. Read-only: stat() and snapshot() are how to get a number.
var balance: Balance = load(BALANCE)
var coins := 0:
	set(v):
		coins = v
		coins_changed.emit(coins)
## Upgrade id -> ranks owned. Read it with rank().
var ranks: Dictionary[StringName, int] = {}
## The highest level unlocked, counted from 1. It is level_count + 1 once the last level is cleared, so it is
## not always a level: ask is_unlocked and is_cleared, and clamp it before showing it as one.
var unlocked := 1
## Level number -> Layout.to_data(). Read and write it with layout() and set_layout().
var layouts: Dictionary[int, Array] = {}
## How many levels there are: Levels.count(). A test may set it; use() puts it back.
var level_count := Levels.count()

## Upgrade id -> upgrade, in id order. Read once, on first use.
var _upgrades: Dictionary[StringName, Upgrade] = {}


func _ready() -> void:
	use(path)


## Switches to another save file: forgets everything in memory, then loads `new_path` (a missing file is a fresh
## save). Tests and the screenshot harness call this with a path inside the checkout before they do anything
## else, so the real save is never touched.
func use(new_path: String) -> void:
	path = new_path
	level_count = Levels.count()
	reset()
	_load()


## Back to a fresh save in memory. Does not write the file.
func reset() -> void:
	ranks = {}
	unlocked = 1
	layouts = {}
	coins = 0


## Writes the save to `path`.
func save() -> void:
	var data := {"version": VERSION, "coins": coins, "ranks": ranks, "unlocked": unlocked, "layouts": layouts}
	# Written beside the save and then moved over it, so a crash mid-write never leaves half a save.
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("cannot write the save to %s: %s" % [tmp, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(data, "\t"))  # int keys (layouts) become "1", as the format says
	f.close()
	DirAccess.rename_absolute(tmp, path)


## Every upgrade: each .tres in UPGRADES, sorted by id. The id is the file name (see Upgrade.id).
func upgrades() -> Array[Upgrade]:
	var out: Array[Upgrade] = []
	out.assign(_all().values())
	return out


## The upgrade with this id, or null.
func upgrade(id: StringName) -> Upgrade:
	return _all().get(id)


## Ranks owned of an upgrade.
func rank(u: Upgrade) -> int:
	return ranks.get(u.id, 0)


## True if every rank is owned.
func maxed(u: Upgrade) -> bool:
	return rank(u) >= u.max_rank


## The price of the next rank: u.cost(rank(u)). Meaningless once maxed.
func cost(u: Upgrade) -> int:
	return u.cost(rank(u))


## True if the next rank exists and the coins cover it. Whether the node is reachable in the web is the hub's
## business: the web scene holds the connections, and the hub only offers a node whose neighbour is owned.
func can_buy(u: Upgrade) -> bool:
	return not maxed(u) and coins >= cost(u)


## Buys the next rank if can_buy: takes the coins, raises the rank, saves, and emits coins_changed and
## rank_changed. Returns false and changes nothing otherwise.
func buy(u: Upgrade) -> bool:
	if not can_buy(u):
		return false
	var price := cost(u)
	ranks[u.id] = rank(u) + 1
	coins -= price
	save()
	rank_changed.emit(u)
	return true


## The value of a stat: its base value from balance.tres plus, for every upgrade that changes it, its amount
## times the ranks owned. A percent amount is a share of the base value, so Ball Speed at rank 5 is
## base + base * 0.15 * 5. Stat names are Balance's "Stats" properties and the counts, `<kind id>_count`.
func stat(stat_name: StringName) -> float:
	var base := balance.base(stat_name)
	var value := base
	for u: Upgrade in _all().values():
		if u.stat == stat_name:
			value += rank(u) * (u.amount * base if u.percent else u.amount)
	return value


## Every number a round needs, with the upgrades applied: a copy of balance.tres in which each stat is stat().
## The level screen takes one when a round starts and passes it to Round.new. Changing the copy changes nothing else.
func snapshot() -> Balance:
	var b := balance.copy()
	for u: Upgrade in _all().values():  # only an upgrade moves a stat off its base
		b.put(u.stat, stat(u.stat))
	return b


## True if the level may be played.
func is_unlocked(level: int) -> bool:
	return level <= unlocked


## True if the level has been cleared at least once. For the last level, that is the game won.
func is_cleared(level: int) -> bool:
	return level < unlocked


## Called once when a round ends, however it ends: adds `earned` coins, and on a level's first clear raises
## `unlocked` to level + 1, emitting level_unlocked if that level exists (level < level_count). Then it saves.
func finish_round(level: int, earned: int, cleared: bool) -> void:
	coins += earned
	if cleared and level >= unlocked:
		unlocked = level + 1
		if level < level_count:
			level_unlocked.emit(unlocked)
	save()


## The saved layout of a level, or an empty one. It is not fitted: build the round from it and the round drops
## what no longer fits, or call Layout.fitted yourself.
func layout(level: int) -> Layout:
	return Layout.from_data(layouts.get(level, []))


## Stores a level's layout and saves.
func set_layout(level: int, l: Layout) -> void:
	layouts[level] = l.to_data()
	save()


func _all() -> Dictionary[StringName, Upgrade]:
	if _upgrades.is_empty():
		var files := Array(ResourceLoader.list_directory(UPGRADES))
		files.sort()  # the id is the file name, so this is id order
		for file: String in files:
			var u: Upgrade = load(UPGRADES.path_join(file)) as Upgrade if file.get_extension() == "tres" else null
			if u:
				_upgrades[u.id] = u
	return _upgrades


## Reads the file at `path` into the fresh state reset() left. Keeps every field it can read and skips the rest.
func _load() -> void:
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()  # not JSON.parse_string, which logs an error on a broken file
	var data: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	var version: Variant = data.get("version") if data is Dictionary else null
	if not data is Dictionary or (_num(version) and version > VERSION):
		push_warning("%s cannot be read: it is kept as %s.bad and the game starts fresh" % [path, path])
		DirAccess.rename_absolute(path, path + ".bad")
		return
	# ponytail: VERSION 1 is the only format, so a missing or older version is read as it is. The first format
	# change adds an upgrade step here, keyed on `version`.
	if _num(data.get("coins")):
		coins = maxi(0, int(data.coins))
	if _num(data.get("unlocked")):
		unlocked = maxi(1, int(data.unlocked))
	var saved_ranks: Variant = data.get("ranks")
	if saved_ranks is Dictionary:
		for id: Variant in saved_ranks:
			var u := upgrade(StringName(str(id)))
			if u and _num(saved_ranks[id]):
				ranks[u.id] = clampi(int(saved_ranks[id]), 0, u.max_rank)
	var saved_layouts: Variant = data.get("layouts")
	if saved_layouts is Dictionary:
		for key: Variant in saved_layouts:
			if str(key).is_valid_int() and saved_layouts[key] is Array:
				layouts[int(str(key))] = saved_layouts[key]


static func _num(v: Variant) -> bool:
	return v is float or v is int
