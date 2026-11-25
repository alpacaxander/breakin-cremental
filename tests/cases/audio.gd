extends RefCounted
## The audio lane: the files by their numbers, and Sfx's wiring. Nobody has listened to these sounds; the numbers
## below are what stands in for an ear (assets/audio/demo.html is where to judge them).

## Cues fired many times a second in play or in menus: short, so a run of them does not smear.
const RAPID := [&"paddle_hit", &"wall_bounce", &"brick_hit", &"brick_break", &"bumper", &"booster", &"splitter",
		&"zap", &"low_timer_tick", &"tally_tick", &"click", &"place_item"]
## The big cues, with the sine thump and the noise burst under them.
const BIG := [&"explosion", &"level_cleared", &"ball_lost"]

## What Sfx.played reported: [cue, pitch_scale, bus, usec].
var heard: Array[Array] = []


func run(t: Node) -> void:
	Sfx.played.connect(_on_played)
	_files(t)
	await _round(t)
	await _splitter(t)
	await _abilities(t)
	_climb(t)
	await _burst(t)
	await _buttons(t)
	await _music(t)
	for h: Array in heard:
		t.check(h[2] == (Settings.BUS_MUSIC if h[0] == Sfx.MUSIC else Settings.BUS_SOUND), "%s plays on its bus" % h[0])
	for p: AudioStreamPlayer in Sfx.find_children("*", "AudioStreamPlayer", false, false):
		t.check(p.volume_db == 0.0, "Sfx sets no volume (%s)" % p.stream.resource_path)
	Sfx.played.disconnect(_on_played)
	Kinds.reset()


func _on_played(cue: StringName, player: AudioStreamPlayer) -> void:
	heard.append([cue, player.pitch_scale, player.bus, Time.get_ticks_usec()])


## Runs `f`, waits for staggered voices to land, and returns the cues heard meanwhile.
func _hear(t: Node, f: Callable) -> Array:
	heard.clear()
	f.call()
	await t.tree().create_timer(0.12).timeout
	var out := []
	for h: Array in heard:
		out.append(h[0])
	return out


func _cues() -> Array[StringName]:
	var out: Array[StringName] = []
	var map: Dictionary = Sfx.get_script().get_script_constant_map()
	for name: String in map:
		if map[name] is StringName and name != "QUIET":
			out.append(map[name])
	return out


func _files(t: Node) -> void:
	var cues := _cues()
	t.check(cues.size() == 22, "Sfx has the twenty-one cues of audio.md and the music (has %d)" % cues.size())
	for file in DirAccess.get_files_at(Sfx.DIR):
		if file.get_extension() == "wav":
			t.check(StringName(file.get_basename()) in cues, "%s is named after a cue constant" % file)
	var sfx_peak := 1.0
	var music_peak := 0.0
	for cue in cues:
		var path := Sfx.DIR.path_join("%s.wav" % cue)
		var stream := load(path) as AudioStreamWAV
		t.check(stream != null, "%s loads as a wav" % path)
		if stream == null:
			continue
		var loop := cue == Sfx.MUSIC
		t.check(stream.loop_mode == (AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED),
				"%s %s" % [cue, "loops" if loop else "does not loop"])
		var n := _numbers(t, path)
		if n.is_empty():
			continue
		var limit := 40.0 if loop else 0.8 if cue in BIG else 0.15 if cue in RAPID else 0.35
		t.check(n.seconds >= (20.0 if loop else 0.005) and n.seconds <= limit,
				"%s lasts at most %.2f s (%.3f s)" % [cue, limit, n.seconds])
		t.check(n.peak < 0.9, "%s does not clip (peak %.2f)" % [cue, n.peak])
		t.check(n.peak > 0.3 and n.rms > 0.03, "%s is not silent (peak %.2f, rms %.3f)" % [cue, n.peak, n.rms])
		t.check(absf(n.last) < 0.01, "%s ends on silence, so it stops without a click" % cue)
		if loop:
			t.check(absf(n.first) < 0.01, "the music starts on silence, so its seam has no click")
			music_peak = n.peak
		else:
			sfx_peak = minf(sfx_peak, n.peak)
	t.check(music_peak < sfx_peak, "the music is quieter than every sound (%.2f < %.2f)" % [music_peak, sfx_peak])


## The format, length, peak, RMS, first and last sample of a wav as gen.mjs writes it, in full scale (1 = 32767).
## Empty if the header is not 44.1 kHz mono 16-bit PCM with its data at byte 44.
func _numbers(t: Node, path: String) -> Dictionary:
	var b := FileAccess.get_file_as_bytes(path)
	var ok := b.slice(0, 4).get_string_from_ascii() == "RIFF" and b.slice(8, 12).get_string_from_ascii() == "WAVE" \
			and b.decode_u16(20) == 1 and b.decode_u16(22) == 1 and b.decode_u32(24) == 44100 \
			and b.decode_u16(34) == 16 and b.slice(36, 40).get_string_from_ascii() == "data"
	t.check(ok, "%s is 44.1 kHz mono 16-bit PCM" % path)
	if not ok:
		return {}
	var count := b.decode_u32(40) / 2
	var peak := 0
	var sum := 0.0
	for i in count:
		var s := b.decode_s16(44 + i * 2)
		peak = maxi(peak, absi(s))
		sum += s * s
	return {seconds = count / 44100.0, peak = peak / 32767.0, rms = sqrt(sum / count) / 32767.0,
			first = b.decode_s16(44) / 32767.0, last = b.decode_s16(44 + (count - 1) * 2) / 32767.0}


func _round(t: Node) -> void:
	var r := Round.new(Board.new(), null, load("res://data/balance.tres"), 1)
	t.check(await _hear(t, func() -> void: Sfx.connect_round(r)) == [Sfx.ROUND_START], "connect_round plays ROUND_START")

	for want: Array in [[Hit.Surface.WALL, Sfx.WALL_BOUNCE], [Hit.Surface.PADDLE, Sfx.PADDLE_HIT], [Hit.Surface.ITEM, Sfx.BUMPER]]:
		var hit := Hit.new()
		hit.surface = want[0]
		hit.item = Layout.Item.new()
		hit.item.kind = PlaceableKind.new()
		hit.item.kind.cue = Sfx.BUMPER
		t.check(await _hear(t, func() -> void: r.ball_bounced.emit(Ball.new(), hit)) == [want[1]],
				"a bounce off %s plays %s" % [Hit.Surface.find_key(want[0]), want[1]])

	t.check(await _hear(t, func() -> void: r.brick_hit.emit(Vector2i.ZERO, 1, Round.Cause.BALL)) == [Sfx.BRICK_HIT],
			"brick_hit plays BRICK_HIT")

	var brick := Brick.new(0)
	r.combo.count = 3
	t.check(await _hear(t, func() -> void: r.brick_broken.emit(Vector2i.ZERO, brick, Round.Cause.BALL, Vector2.RIGHT, 1)) \
			== [Sfx.BRICK_BREAK], "a plain brick breaking plays BRICK_BREAK alone")
	t.check(is_equal_approx(heard[0][1], Sfx.combo_pitch(3)), "the break is pitched by round.combo.count")

	var gold := BrickKind.new()
	gold.id = &"test_gold"
	gold.cue = Sfx.GOLD_BRICK
	Kinds.add(gold)
	brick.kind = gold.id
	t.check(await _hear(t, func() -> void: r.brick_broken.emit(Vector2i.ZERO, brick, Round.Cause.ZAP, Vector2.LEFT, 5)) \
			== [Sfx.BRICK_BREAK, Sfx.GOLD_BRICK], "a break plays BRICK_BREAK, then its kind's cue")
	Kinds.reset()

	var cells: Array[Vector2i] = [Vector2i.ZERO]
	t.check(await _hear(t, func() -> void: r.exploded.emit(Vector2.ZERO, 64.0, cells)) == [Sfx.EXPLOSION], "exploded plays EXPLOSION")
	t.check(await _hear(t, func() -> void: r.zapped.emit(Vector2i.ZERO, cells)) == [Sfx.ZAP], "zapped plays ZAP")
	t.check(await _hear(t, func() -> void: r.caught.emit(Drop.new())) == [Sfx.CATCH], "caught plays CATCH")
	t.check(await _hear(t, func() -> void: r.dropped.emit(Drop.new())) == [], "a drop being made plays nothing")
	t.check(await _hear(t, func() -> void: r.ball_lost.emit(Ball.new())) == [Sfx.BALL_LOST], "ball_lost plays BALL_LOST")
	t.check(await _hear(t, func() -> void: r.ended.emit(Round.End.TIME)) == [], "running out of time plays nothing")
	t.check(await _hear(t, func() -> void: r.ended.emit(Round.End.CLEARED)) == [Sfx.LEVEL_CLEARED], "a clear plays LEVEL_CLEARED")

	# The low timer: stats.low_time is 5, so crossing 5, 4, ... ticks and crossing 7 does not.
	var ticks := []
	for left: float in [7.5, 6.2, 4.9, 4.5, 3.9, 3.1, 0.5, 0.0]:
		ticks.append((await _hear(t, func() -> void: r.time_left = left)).size())
	t.check(ticks == [0, 0, 1, 0, 1, 0, 1, 0], "LOW_TIMER_TICK sounds once per whole second crossed at or under low_time (%s)" % [ticks])
	r.over = true
	await t.tree().process_frame


## The Splitter's cue is the sound of a ball splitting, so it follows ball_added and not the break: a real round
## with the real kind, one Splitter broken by a blast and one by a ball.
func _splitter(t: Node) -> void:
	var stats: Balance = (load("res://data/balance.tres") as Balance).copy()
	stats.put(&"splitter_count", 2)
	var layout := Layout.new()
	for cell: Vector2i in [Vector2i(20, 2), Vector2i(30, 2)]:
		var item := Layout.Item.new()
		item.kind = Kinds.of(&"splitter")
		item.cell = cell
		layout.add(item)
	var r := Round.new(Board.new(), layout, stats, 1)
	await _hear(t, func() -> void: Sfx.connect_round(r))
	var got := await _hear(t, func() -> void: r.hit_brick(Vector2i(20, 2), Round.Cause.BLAST, Vector2.RIGHT))
	t.check(got == [Sfx.BRICK_BREAK] and r.balls.size() == 1, "a Splitter broken by a blast splits no ball and plays no SPLITTER (heard %s)" % [got])
	var into := Vector2(1, 1).normalized()  # the way the ball was moving when it hit
	got = await _hear(t, func() -> void: r.hit_brick(Vector2i(30, 2), Round.Cause.BALL, into, r.balls[0]))
	t.check(got == [Sfx.BRICK_BREAK, Sfx.SPLITTER] and r.balls.size() == 2, "a Splitter broken by a ball splits it and plays SPLITTER once (heard %s)" % [got])
	t.check(r.balls[1].dir.is_equal_approx(into) and r.balls[1].pos == r.balls[0].pos, "the new ball starts at the first and carries on the way it came in")
	r.over = true
	await t.tree().process_frame


## The ability system in a real round on level 1: a Power Brick's break plays its kind's cue (SPLITTER), its
## drop is caught with CATCH, and a whole-row Zap and a blast each play their cue once over a burst of breaks
## that the voice cap holds to VOICES.
func _abilities(t: Node) -> void:
	var stats: Balance = (load("res://data/balance.tres") as Balance).copy()
	stats.put(&"power_count", 1)
	stats.put(&"zap_count", 1)
	stats.zap_range = 64.0
	var r := Round.new(Levels.read(1).board, null, stats, 1)
	await _hear(t, func() -> void: Sfx.connect_round(r))
	var power: Vector2i = r.board.bricks.keys().filter(func(c: Vector2i) -> bool: return r.board.brick(c).kind == &"power")[0]
	var got := await _hear(t, func() -> void: r.hit_brick(power, Round.Cause.BALL, Vector2.RIGHT))
	t.check(got == [Sfx.BRICK_BREAK, Sfx.SPLITTER] and r.drops.size() == 1, "a Power Brick breaking plays its kind's cue, SPLITTER, and drops (heard %s)" % [got])
	r.drops[0].pos = r.paddle.rect(r.board.size().y).get_center()
	got = await _hear(t, func() -> void: r.step(1.0 / 120.0, r.paddle.y))
	t.check(got.count(Sfx.CATCH) == 1 and r.drops.is_empty(), "the paddle catching it plays CATCH once (heard %s)" % [got])
	got = await _hear(t, func() -> void: r.zap(power))
	t.check(got.count(Sfx.ZAP) == 1 and got.count(Sfx.BRICK_BREAK) >= 1 and got.count(Sfx.BRICK_BREAK) <= Sfx.VOICES, "a whole-row Zap plays ZAP once, and its breaks at most %d voices (heard %s)" % [Sfx.VOICES, got])
	got = await _hear(t, func() -> void: r.blast(power, 128.0))
	t.check(got.count(Sfx.EXPLOSION) == 1 and got.count(Sfx.BRICK_BREAK) <= Sfx.VOICES, "a blast plays EXPLOSION once (heard %s)" % [got])
	r.over = true
	await t.tree().process_frame


func _climb(t: Node) -> void:
	t.check(Sfx.combo_pitch(0) == 1.0 and Sfx.combo_pitch(1) == 1.0, "the climb starts at the recorded pitch")
	for count in range(2, 12):
		var steps := 12.0 * log(Sfx.combo_pitch(count) / Sfx.combo_pitch(count - 1)) / log(2.0)
		var note := roundi(12.0 * log(Sfx.combo_pitch(count)) / log(2.0)) % 12
		t.check(roundi(steps) in [2, 3] and note in [0, 2, 4, 7, 9], "combo %d is the next note of the pentatonic scale" % count)
	t.check(is_equal_approx(Sfx.combo_pitch(11), 4.0) and Sfx.combo_pitch(40) == Sfx.combo_pitch(11), "the climb stops two octaves up")


func _burst(t: Node) -> void:
	var r := Round.new(Board.new(), null, load("res://data/balance.tres"), 1)
	Sfx.connect_round(r)
	await t.tree().create_timer(0.12).timeout
	var got := await _hear(t, func() -> void:
		for i in 64:
			r.brick_broken.emit(Vector2i(i, 0), Brick.new(0), Round.Cause.ZAP, Vector2.RIGHT, 1)
		t.check(heard.size() == 1, "the first of a burst sounds at once, the rest wait"))
	t.check(got.size() == Sfx.VOICES, "64 breaks in one frame give %d voices, not %d" % [Sfx.VOICES, got.size()])
	for i in range(1, heard.size()):
		t.check(heard[i][3] - heard[0][3] >= i * Sfx.STAGGER * 1e6, "voice %d of a burst starts at least %d staggers after the first (%s)" % [i, i, heard.map(func(h: Array) -> int: return h[3])])
	var players := Sfx.find_children("*", "AudioStreamPlayer", false, false).filter(func(p: AudioStreamPlayer) -> bool:
		return p.stream.resource_path.ends_with("brick_break.wav"))
	t.check(players.size() <= Sfx.VOICES, "one cue never has more than %d players" % Sfx.VOICES)
	r.over = true
	await t.tree().process_frame


func _buttons(t: Node) -> void:
	var b := Button.new()
	t.add_child(b)
	t.check(await _hear(t, func() -> void: b.pressed.emit()) == [Sfx.CLICK], "a button clicks when pressed")
	t.remove_child(b)
	t.add_child(b)
	t.check(await _hear(t, func() -> void: b.pressed.emit()) == [Sfx.CLICK], "a button that left and re-entered the tree clicks once")
	b.add_to_group(Sfx.QUIET)
	t.check(await _hear(t, func() -> void: b.pressed.emit()) == [], "a button put in QUIET after it entered the tree does not click")
	b.free()


func _music(t: Node) -> void:
	var got := await _hear(t, func() -> void:
		Sfx.start_music()
		Sfx.start_music())
	t.check(got == [Sfx.MUSIC], "start_music starts the loop once")
