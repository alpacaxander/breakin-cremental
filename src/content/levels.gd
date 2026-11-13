class_name Levels
## Finds the levels and reads them. The level screen, the hub's thumbnail, the tests and the balance bot all get
## a level through read(); nothing else opens a level scene.
##
## A level is the scene levels/level_<n>.tscn, numbered from 1 with no gaps. Adding a level is adding the next
## file. How bricks, HP, the row count and the name are written inside the scene belongs to this file: the levels
## lane decides it and describes it here.
##
## STUB: the levels lane writes read(), and the three scenes from docs/design/levels.md.

const DIR := "res://levels"


## The scene of level `number`. The file may not exist.
static func path(number: int) -> String:
	return "%s/level_%d.tscn" % [DIR, number]


## How many levels there are: the highest n for which level_1 to level_n all exist.
static func count() -> int:
	var n := 0
	while ResourceLoader.exists(path(n + 1)):
		n += 1
	return n


## Level `number` as board data, or null if there is no such level. Each call returns a new LevelData, so the
## caller may keep it.
static func read(_number: int) -> LevelData:
	return null
