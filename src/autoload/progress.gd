extends Node
## Autoload `Progress`: the one save slot, and the stats that come out of it.
##
## THE SAVE is one JSON file:
##     {
##       "version": 2,
##       "coins": 142,
##       "ranks": {"paddle_speed": 2, "bumper": 1},
##       "owned": ["PaddleSpeed", "PaddleSpeed2", "Bumper"],
##       "unlocked": 2,
##       "layouts": {"1": [{"kind": "bumper", "x": 512.0, "y": 256.0, "rot": 0.0}]}
##     }
##   version   VERSION of the build that wrote it. A later build reads an older file by upgrading it step by step.
##   ranks     upgrade id -> ranks owned. A missing id is rank 0. An id with no file is ignored, and a rank above
##             the upgrade's max_rank is lowered to it. Each rank is a copy: one bought web node of that upgrade.
##   owned     the names of the web nodes bought (nodes of the hub's web.tscn), as buy() was told them. Progress
##             only records them: whether the web still hangs together is the hub's business.
##   unlocked  the highest level unlocked, counted from 1: one more than the highest level cleared. So once the
##             last level is cleared it is one past the last level. That is how the win is saved, and a level
##             added later is then already open.
##   layouts  level number, as a string -> that level's Layout.to_data().
## Nothing about a round in progress is saved, nor are the keys: keys() counts them from `unlocked` and `ranks`.
## A missing file is a fresh save: 0 coins, no ranks, no nodes, level 1 unlocked, no layouts. A version 1 file
## (or one with no version) had ranks and no node names: its ranks are dropped and refunded (see _load). A file that cannot be read, or whose version is newer than VERSION, is renamed to
## <path>.bad and the game starts fresh.
##
## It saves after every purchase (buy) and undo (undo), after every round (finish_round) and when a layout changes (set_layout).
## Changing a field directly does not save.
##
## WHAT THIS SCRIPT DOES NOT LOOK INTO. A layout is stored as the Array that Layout.to_data() gave, and handed to
## Layout.from_data() as the file returned it; Progress never reads what is inside. After a trip through JSON
## every number in it is a float (30 comes back as 30.0), and from_data accepts that. So the save round trip can
## be checked on the `layouts` field with any Array of Dictionaries, before Layout is written. The number of
## levels is `level_count`, which a test may set, so unlocking can be checked before any level scene exists.

## The coin balance changed.
signal coins_changed(coins: int)
## An upgrade was bought or undone. rank(upgrade) is its new rank.
signal rank_changed(upgrade: Upgrade)
## A level was unlocked. `level` is the new highest level, and it exists: clearing the last level emits nothing.
signal level_unlocked(level: int)

const VERSION := 2
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
## The names of the web nodes bought, as buy() and undo() were told them.
var owned: Array[StringName] = []
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
	owned = []
	unlocked = 1
	layouts = {}
	coins = 0


## Writes the save to `path`.
func save() -> void:
	var data := {"version": VERSION, "coins": coins, "ranks": ranks, "owned": owned, "unlocked": unlocked, "layouts": layouts}
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


## Keys in hand: one per level cleared, less one per copy owned of a key upgrade (Upgrade.key).
func keys() -> int:
	var spent := 0
	for u: Upgrade in _all().values():
		if u.key:
			spent += rank(u)
	return mini(unlocked - 1, level_count) - spent


## True if the next rank exists and a key (for a key upgrade) or the coins cover it. Whether the node is
## reachable in the web is the hub's business: the web scene holds the connections, and the hub only offers a
## node whose neighbour is owned.
func can_buy(u: Upgrade) -> bool:
	return not maxed(u) and (keys() > 0 if u.key else coins >= cost(u))


## Buys the next rank if can_buy: takes the coins (a key upgrade takes none: owning it spends the key), raises
## the rank, records `node` in `owned` when given, saves, and emits coins_changed and rank_changed. Returns false
## and changes nothing otherwise.
func buy(u: Upgrade, node := &"") -> bool:
	if not can_buy(u):
		return false
	var price := 0 if u.key else cost(u)
	ranks[u.id] = rank(u) + 1
	if node:
		owned.append(node)
	coins -= price
	save()
	rank_changed.emit(u)
	return true


## Undoes one copy: lowers the rank by one, gives back what that copy cost (u.cost of the new rank; nothing for a
## key upgrade, whose key comes back through keys()), forgets `node` when given, saves, and emits coins_changed
## and rank_changed. Needs a copy owned, and `node` in `owned` when given; returns false and changes nothing
## otherwise. Whether the web still hangs together without the node is the hub's question, not this one's.
func undo(u: Upgrade, node := &"") -> bool:
	if rank(u) == 0 or (node and node not in owned):
		return false
	var r := rank(u) - 1
	if r > 0:
		ranks[u.id] = r
	else:
		ranks.erase(u.id)
	owned.erase(node)
	coins += 0 if u.key else u.cost(r)
	save()
	rank_changed.emit(u)
	return true


## The value of a stat: its base value from balance.tres plus, for every upgrade that changes it, its amount
## times the ranks owned. A percent amount is a share of the base value, so a 10% upgrade at rank 3 is
## base + base * 0.1 * 3. Stat names are Balance's "Stats" properties and the counts, `<kind id>_count`.
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
	# ponytail: a version 1 file (or one with no version) has ranks but no node names, so it cannot say which web
	# nodes are owned. Its ranks are dropped and what they cost at today's prices is added to the coins (a key
	# upgrade refunds nothing: its key comes back by itself). The next format change adds its step here too.
	if not _num(version) or version < 2:
		for id: StringName in ranks:
			var u := upgrade(id)
			for r in ranks[id]:
				coins += 0 if u.key else u.cost(r)
		ranks = {}
	var saved_owned: Variant = data.get("owned")
	if saved_owned is Array:
		for n: Variant in saved_owned:
			if n is String:
				owned.append(StringName(n))
	var saved_layouts: Variant = data.get("layouts")
	if saved_layouts is Dictionary:
		for key: Variant in saved_layouts:
			if str(key).is_valid_int() and saved_layouts[key] is Array:
				layouts[int(str(key))] = saved_layouts[key]


static func _num(v: Variant) -> bool:
	return v is float or v is int
