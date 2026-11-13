extends Node
## Autoload `Progress`: the one save slot, and the stats that come out of it.
##
## STUB: the state lane writes the bodies and the fifteen files in data/upgrades/. As shipped here it keeps
## everything in memory, reads and writes no file, finds no upgrades and returns base stats.
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
##   unlocked  the highest level unlocked, counted from 1.
##   layouts   level number, as a string -> that level's Layout.to_data().
## Nothing about a round in progress is saved. A missing file is a fresh save: 0 coins, no ranks, level 1
## unlocked, no layouts. A file that cannot be read, or whose version is newer than VERSION, is renamed to
## <path>.bad and the game starts fresh.
##
## It saves after every purchase (buy), after every round (finish_round) and when a layout changes (set_layout).
## Changing a field directly does not save.

## The coin balance changed.
signal coins_changed(coins: int)
## An upgrade was bought. rank(upgrade) is its new rank.
signal rank_changed(upgrade: Upgrade)
## A level was unlocked. `level` is the new highest level.
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
## The highest level unlocked, counted from 1.
var unlocked := 1
## Level number -> Layout.to_data(). Read and write it with layout() and set_layout().
var layouts: Dictionary[int, Array] = {}


## Switches to another save file: forgets everything in memory, then loads `new_path` (a missing file is a fresh
## save). Tests and the screenshot harness call this with a path inside the checkout before they do anything
## else, so the real save is never touched.
func use(new_path: String) -> void:
	path = new_path
	reset()


## Back to a fresh save in memory. Does not write the file.
func reset() -> void:
	ranks = {}
	unlocked = 1
	layouts = {}
	coins = 0


## Writes the save to `path`.
func save() -> void:
	pass


## Every upgrade: each .tres in UPGRADES, sorted by id. The id is the file name (see Upgrade.id).
func upgrades() -> Array[Upgrade]:
	return []


## The upgrade with this id, or null.
func upgrade(_id: StringName) -> Upgrade:
	return null


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
func buy(_u: Upgrade) -> bool:
	return false


## The value of a stat: its base value from balance.tres plus, for every upgrade that changes it, its amount
## times the ranks owned. A percent amount is a share of the base value, so Ball Speed at rank 5 is
## base + base * 0.15 * 5. Stat names are Balance's "Stats" properties and the counts, `<kind id>_count`.
func stat(stat_name: StringName) -> float:
	return balance.base(stat_name)


## Every number a round needs, with the upgrades applied: a copy of balance.tres in which each stat is stat().
## The level screen takes one when a round starts and passes it to Round.new. Changing the copy changes nothing else.
func snapshot() -> Balance:
	return balance.copy()


## True if the level may be played.
func is_unlocked(level: int) -> bool:
	return level <= unlocked


## Called once when a round ends, however it ends: adds `earned` coins, unlocks level + 1 if `cleared` and that
## level exists and is still locked (emitting level_unlocked), and saves.
func finish_round(_level: int, _earned: int, _cleared: bool) -> void:
	pass


## The saved layout of a level, or an empty one. It is not fitted: build the round from it and the round drops
## what no longer fits, or call Layout.fitted yourself.
func layout(_level: int) -> Layout:
	return Layout.new()


## Stores a level's layout and saves.
func set_layout(_level: int, _layout: Layout) -> void:
	pass
