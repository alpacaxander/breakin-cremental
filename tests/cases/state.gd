extends RefCounted
## The state lane: the upgrades, stats, buying, paying a round, the save file and the settings file.

const A := Upgrade.Category.ARENA
const P := Upgrade.Category.PLACEABLES
const B := Upgrade.Category.BRICKS
## The sketched web (docs/design/upgrades.md): id -> [category, ranks, first cost, stat, amount, percent]. Every
## node's ranks and prices are first values, set with the balance bot.
const TABLE := {
	&"paddle_speed": [A, 2, 5, &"paddle_speed", 1.0, true],
	&"paddle_size": [A, 5, 50, &"paddle_size", 0.4, true],
	&"combo": [A, 1, 12, &"combo_rank", 1.0, false],
	&"combo_window": [A, 2, 40, &"combo_rank", 1.0, false],
	&"rear_paddle": [A, 2, 300, &"rear_paddle", 0.2, false],
	&"booster": [P, 2, 12, &"booster_count", 1.0, false],
	&"booster_speed": [P, 2, 500, &"booster_speed", 0.2, false],
	&"zap": [P, 3, 200, &"zap_count", 1.0, false],
	&"zap_range": [P, 2, 400, &"zap_range", 2.0, false],
	&"zap_damage": [P, 2, 800, &"zap_damage", 1.0, false],
	&"splitter": [P, 5, 80, &"splitter_count", 1.0, false],
	&"splitter_respawn": [P, 3, 2000, &"splitter_respawn", 1.0, false],
	&"splitter_health": [P, 2, 500, &"splitter_health", 1.0, false],
	&"wall_segment": [P, 2, 40, &"wall_segment_count", 1.0, false],
	&"explosive_brick": [B, 4, 40, &"explosive_count", 1.0, false],
	&"blast_size": [B, 2, 150, &"blast_size", 1.0, false],
	&"explosion_damage": [B, 2, 300, &"explosion_damage", 1.0, false],
	&"shockwave": [B, 1, 600, &"shockwave", 1.0, false],
	&"gold_brick": [B, 3, 30, &"gold_count", 1.0, false],
	&"hourglass_brick": [B, 2, 25, &"hourglass_count", 1.0, false],
	&"hourglass_time": [B, 2, 1200, &"hourglass_time", 5.0, false],
	&"hourglass_freeze": [B, 2, 800, &"hourglass_freeze", 1.0, false],
	&"tough_brick": [B, 3, 20, &"tough_count", 1.0, false],
	&"growth": [P, 2, 100, &"growth_count", 1.0, false],
	&"growth_reach": [P, 2, 300, &"growth_reach", 1.0, false],
	&"pulse_rate": [P, 2, 1000, &"growth_pulses", 1.0, false],
	&"overgrowth": [A, 1, 8000, &"overgrowth", 1.0, false],
	&"guide": [A, 4, 30, &"guide", 250.0, false],
	&"guide_bounces": [A, 1, 250, &"guide_bounces", 1.0, false],
	&"spare_ball": [A, 3, 300, &"spare_balls", 1.0, false],
	&"ball_brick": [B, 2, 1800, &"ball_count", 1.0, false],
}


func run(t: Node) -> void:
	_upgrades(t)
	_stats(t)
	_buy(t)
	_finish_round(t)
	_round_trip(t)
	_bad_saves(t)
	_settings(t)


func _upgrades(t: Node) -> void:
	var all := Progress.upgrades()
	var ids := all.map(func(u: Upgrade) -> StringName: return u.id)
	var sorted := TABLE.keys()
	sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	t.check(ids == sorted, "there are the web's 31 upgrades, sorted by id: %s" % [ids])
	var purchases := 0
	for u in all:
		var row: Array = TABLE.get(u.id, [])
		if row.is_empty():
			continue
		purchases += u.max_rank
		t.check(u.title != "" and u.text != "", "%s has a title and a text" % u.id)
		t.check([u.category, u.max_rank, u.first_cost, u.stat] == row.slice(0, 4), "%s has the category, ranks, first cost and stat of the table" % u.id)
		t.check(is_equal_approx(u.amount, row[4]) and u.percent == row[5], "%s adds %s%s per rank" % [u.id, row[4], " of the base" if row[5] else ""])
		t.check(u.cost(0) == u.first_cost, "%s's first rank costs its first cost" % u.id)
		t.check(Progress.upgrade(u.id) == u, "Progress.upgrade finds %s" % u.id)
	t.check(purchases == 73, "the web holds 73 purchases, not %d" % purchases)
	t.check(Progress.upgrade(&"nope") == null, "an unknown id is no upgrade")


func _stats(t: Node) -> void:
	var base := Progress.balance
	t.check(Progress.stat(&"paddle_size") == base.paddle_size and Progress.stat(&"zap_count") == 0.0, "a fresh save has base stats")
	Progress.ranks[&"paddle_size"] = 1
	Progress.ranks[&"combo"] = 1
	Progress.ranks[&"combo_window"] = 1
	Progress.ranks[&"zap"] = 1
	Progress.ranks[&"explosive_brick"] = 1
	t.check(is_equal_approx(Progress.stat(&"paddle_size"), base.paddle_size * 1.4), "Paddle Size rank 1 is 140% of the base")
	t.check(Progress.stat(&"combo_rank") == base.combo_rank + 2.0, "Combo and Combo Window both raise combo_rank")
	var s := Progress.snapshot()
	t.check(is_equal_approx(s.paddle_size, base.paddle_size * 1.4) and s.combo_rank == base.combo_rank + 2.0, "the snapshot carries the upgraded stats")
	t.check(s.count(&"zap") == 1 and s.count(&"explosive") == 1 and s.count(&"gold") == 0, "the counts land in the snapshot as <kind id>_count")
	t.check(s.extra.get(&"explosive_count") == 1.0 and not s.extra.has(&"explosive_brick_count"), "a special brick's count is named after the kind, not the upgrade")
	t.check(is_equal_approx(s.paddle_speed, base.paddle_speed) and s.ball_size == base.ball_size, "what no rank changes stays at its base")
	t.check(base.paddle_size == (load(Progress.BALANCE) as Balance).paddle_size and base.extra.is_empty(), "a snapshot leaves balance.tres alone")
	Progress.reset()


func _buy(t: Node) -> void:
	var u := Progress.upgrade(&"paddle_speed")
	var heard := []
	var on_coins := func(c: int) -> void: heard.append(c)
	var on_rank := func(x: Upgrade) -> void: heard.append(x)
	Progress.coins_changed.connect(on_coins)
	Progress.rank_changed.connect(on_rank)
	Progress.coins = 1
	heard.clear()
	t.check(not Progress.buy(u) and Progress.rank(u) == 0 and Progress.coins == 1 and heard.is_empty(), "buy refuses when the coins do not cover it")
	Progress.coins = 200
	heard.clear()
	t.check(Progress.buy(u) and Progress.rank(u) == 1 and Progress.coins == 195, "buy takes 5 coins for Paddle Speed rank 1")
	t.check(heard == [195, u], "buy emits coins_changed and rank_changed")
	t.check(FileAccess.file_exists(Progress.path) and _saved().get("coins") == 195.0, "buy saves")
	while Progress.buy(u):
		pass
	t.check(Progress.maxed(u) and Progress.rank(u) == 2 and Progress.coins == 45, "Paddle Speed tops out at rank 2, the second for 150")
	heard.clear()
	t.check(not Progress.buy(u) and Progress.rank(u) == 2 and heard.is_empty(), "buy refuses at the top rank")
	Progress.coins_changed.disconnect(on_coins)
	Progress.rank_changed.disconnect(on_rank)


func _finish_round(t: Node) -> void:
	Progress.reset()
	Progress.level_count = 3
	var unlocked := []
	var on_unlock := func(l: int) -> void: unlocked.append(l)
	Progress.level_unlocked.connect(on_unlock)
	Progress.finish_round(1, 7, false)
	t.check(Progress.coins == 7 and Progress.unlocked == 1 and unlocked.is_empty(), "a failed round pays and unlocks nothing")
	t.check(_saved().get("coins") == 7.0, "finish_round saves")
	Progress.finish_round(1, 10, true)
	t.check(Progress.coins == 17 and Progress.unlocked == 2 and unlocked == [2], "clearing level 1 unlocks level 2")
	Progress.finish_round(1, 10, true)
	t.check(Progress.coins == 27 and Progress.unlocked == 2 and unlocked == [2], "clearing it again pays again and unlocks nothing")
	Progress.finish_round(2, 0, true)
	t.check(Progress.is_unlocked(3) and not Progress.is_unlocked(4), "is_unlocked follows unlocked")
	t.check(Progress.is_cleared(2) and not Progress.is_cleared(3), "the last level is open and not cleared yet")
	Progress.finish_round(3, 5, true)
	t.check(Progress.is_cleared(3) and unlocked == [2, 3] and Progress.coins == 32, "clearing the last level is recorded, and announces no level")
	t.check(_saved().get("unlocked") == 4.0, "the win is saved: unlocked is one past the last level")
	Progress.use(Progress.path)
	t.check(Progress.is_cleared(3), "and it comes back from the file")
	Progress.level_unlocked.disconnect(on_unlock)


func _round_trip(t: Node) -> void:
	Progress.reset()
	Progress.coins = 142
	Progress.ranks[&"zap"] = 1
	Progress.ranks[&"shockwave"] = 1
	Progress.unlocked = 2
	Progress.layouts[1] = [{"kind": "bumper", "x": 512.0, "y": 256.0, "rot": 0.0}, {"kind": "splitter", "col": 30, "row": 3}]
	Progress.layouts[3] = []
	Progress.save()
	var want := [Progress.coins, Progress.ranks.duplicate(), Progress.unlocked, _json(Progress.layouts)]
	Progress.use(Progress.path)
	t.check(Progress.coins == want[0] and Progress.ranks == want[1] and Progress.unlocked == want[2], "coins, ranks and the highest level come back from the file")
	t.check(Progress.layouts.keys() == [1, 3] and _json(Progress.layouts) == want[3], "the layouts come back by level number")
	t.check(Progress.layouts[1][1]["col"] == 30.0, "a layout comes back as JSON gave it")
	var file := _saved()
	t.check(file.get("version") == Progress.VERSION and file.get("layouts", {}).has("1"), "the file has its version and string level keys")
	Progress.reset()
	t.check(Progress.coins == 0 and Progress.ranks.is_empty() and Progress.layouts.is_empty(), "reset forgets everything in memory")


func _bad_saves(t: Node) -> void:
	var path: String = Progress.path
	var bad := path + ".bad"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad))
	_write(path, JSON.stringify({"coins": 50, "ranks": {"zap": 9, "gone": 2, "booster": "x"}, "unlocked": 2,
			"layouts": {"2": [{"kind": "zap"}], "x": [], "4": "no"}, "future": true}))
	Progress.use(path)
	t.check(Progress.coins == 50 and Progress.unlocked == 2, "a save with no version and an unknown field keeps coins and level")
	t.check(Progress.ranks == ({&"zap": 3} as Dictionary[StringName, int]), "a rank above the top is lowered, and unknown ids and bad ranks are dropped")
	t.check(Progress.layouts.keys() == [2], "only well-formed layouts are kept")
	t.check(not FileAccess.file_exists(bad), "a readable save is not set aside")

	_write(path, JSON.stringify({"version": 1, "coins": "lots", "unlocked": 3}))
	Progress.use(path)
	t.check(Progress.coins == 0 and Progress.unlocked == 3, "a field of the wrong type is skipped, the rest kept")

	for text in ["{ not json", JSON.stringify({"version": Progress.VERSION + 1, "coins": 9}), "[1, 2]"]:
		_write(path, text)
		Progress.use(path)
		t.check(Progress.coins == 0 and Progress.unlocked == 1 and FileAccess.file_exists(bad) and not FileAccess.file_exists(path),
				"an unreadable save (%s) is set aside as .bad and the game starts fresh" % text)
		t.check(FileAccess.get_file_as_string(bad) == text, "the set-aside file is the original")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bad))


func _settings(t: Node) -> void:
	var path: String = Settings.path
	t.check(Settings.crt and not Settings.reduce_flashing and Settings.music_volume == 0.5 and Settings.sound_volume == 0.5, "the settings start at their defaults")
	t.check(_bus(Settings.BUS_MUSIC, 0.5) and _bus(Settings.BUS_SOUND, 0.5), "use() sets both bus volumes")
	var count := [0]
	var on_changed := func() -> void: count[0] += 1
	Settings.changed.connect(on_changed)
	Settings.crt = false
	Settings.reduce_flashing = true
	Settings.music_volume = 0.25
	Settings.sound_volume = 2.0
	t.check(count[0] == 4, "every change emits changed")
	t.check(_bus(Settings.BUS_MUSIC, 0.25) and _bus(Settings.BUS_SOUND, 1.0), "a volume change reaches its bus, clamped to 1")
	t.check(FileAccess.file_exists(path) and not FileAccess.file_exists(Progress.path), "the settings have their own file")
	Settings.music_volume = 0.0
	t.check(_bus(Settings.BUS_MUSIC, 0.0), "volume 0 silences the bus")
	Settings.music_volume = 0.25
	Settings.use(path)
	t.check(count[0] == 7, "use() emits changed once")
	t.check(not Settings.crt and Settings.reduce_flashing and Settings.music_volume == 0.25 and Settings.sound_volume == 1.0, "the four settings come back from the file")
	Settings.changed.disconnect(on_changed)

	_write(path, "[settings]\ncrt=\"yes\"\nmusic_volume=0.1\nfuture=3\n")
	Settings.use(path)
	t.check(Settings.crt and Settings.music_volume == 0.1 and Settings.sound_volume == 0.5, "a bad or missing key keeps its default")
	t.check(_bus(Settings.BUS_MUSIC, 0.1), "use() sets the bus from the loaded volume")
	_write(path, "not a [config")
	Settings.use(path)
	t.check(Settings.crt and Settings.music_volume == 0.5, "an unreadable settings file gives the defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.use(path)


func _bus(bus: StringName, volume: float) -> bool:
	return is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus)), volume)


func _saved() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Progress.path))
	return data if data is Dictionary else {}


## A value as it reads back from JSON: string keys, every number a float.
func _json(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
