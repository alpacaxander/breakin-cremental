extends Node
## Autoload `Sfx`: every sound and the music (docs/audio.md).
##
## The wavs are made by assets/audio/gen.mjs (`nix develop -c node assets/audio/gen.mjs`); assets/audio/demo.html
## plays each one. tests/cases/audio.gd checks every file by its numbers (format, length, peak, RMS, the loop's
## seam), because nobody has listened to them yet: judge them by ear on demo.html. The music loops through its .import
## (edit/loop_mode=2, Forward); regenerating the wav keeps that file.
##
## Each cue has up to VOICES players of its own, made on first use and kept as children of this node. Plays of one
## cue closer together than STAGGER are queued STAGGER apart; once VOICES are queued in one burst, the rest are
## dropped. ponytail: the queue is served from _process, so a stagger shorter than a frame lands on the next frame
## (about 16 ms at 60 fps); sample-accurate starts would need an AudioStreamGenerator mixer.
##
## A cue is a StringName and the name of its file: assets/audio/wav/<cue>.wav. Sounds play on the Settings.BUS_SOUND
## bus and the music on Settings.BUS_MUSIC. This script never sets a volume: Settings sets the two bus volumes,
## and the check that a volume setting reaches its bus is in the state lane's case, not the audio lane's.
##
## Everything a round makes is wired by connect_round, so no scene holds audio glue for the rules. The audio case
## drives a round by hand (it emits the round's signals itself and sets round.combo.count and round.time_left);
## tests/cases/contracts.gd wires a real round on every level.
##
## UI CUES, and who plays each:
##   CLICK        this script, for every button in the game. It listens to the scene tree's node_added and
##                connects to `pressed` on each BaseButton that enters, so no screen and no widget plays a click.
##                A button in the group QUIET is skipped. The group is read at the press, so a screen may add
##                it in _ready.
##   BUY          the hub, when Progress.buy returns true.
##   CANT_AFFORD  the hub, when Buy is pressed and the coins do not cover it. That Buy button stays enabled (a
##                disabled Button emits no `pressed`) and shows art.md's "Can't afford" look.
##   PLACE_ITEM   the level screen, when an item is put down in Setup.
##   TALLY_TICK   the level screen, as the Summary counts up.
## A button whose press has a cue of its own goes in QUIET: Buy (BUY or CANT_AFFORD) and Start (ROUND_START, which
## connect_round plays).

## The group of buttons that play no CLICK.
const QUIET := &"quiet"

# Ball and paddle
const PADDLE_HIT := &"paddle_hit"
const WALL_BOUNCE := &"wall_bounce"
const BALL_LOST := &"ball_lost"
# Bricks
const BRICK_HIT := &"brick_hit"
const BRICK_BREAK := &"brick_break"
const EXPLOSION := &"explosion"
const GOLD_BRICK := &"gold_brick"
const HOURGLASS_BRICK := &"hourglass_brick"
# Placeables
const BUMPER := &"bumper"
const BOOSTER := &"booster"
const SPLITTER := &"splitter"
const ZAP := &"zap"
# Round
const ROUND_START := &"round_start"
const LOW_TIMER_TICK := &"low_timer_tick"
const LEVEL_CLEARED := &"level_cleared"
const TALLY_TICK := &"tally_tick"
# UI
const CLICK := &"click"
const BUY := &"buy"
const CANT_AFFORD := &"cant_afford"
const PLACE_ITEM := &"place_item"
# The placeholder loop
const MUSIC := &"music"

const DIR := "res://assets/audio/wav"

## Voices one cue may sound at once.
const VOICES := 4
## Seconds between the voices of one cue that are played together.
const STAGGER := 0.015
## The combo climb in semitones: the major pentatonic scale over two octaves. Combo step n plays CLIMB[n - 1].
const CLIMB: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]

## A voice started: `player` is sounding `cue` now, at its pitch_scale, on its bus. For tests, and for anything
## that wants to know what was heard.
signal played(cue: StringName, player: AudioStreamPlayer)

var _streams: Dictionary[StringName, AudioStream] = {}
## Each cue's players, the one started longest ago first.
var _voices: Dictionary[StringName, Array] = {}
## When each cue's next voice may start, in seconds of _now().
var _next: Dictionary[StringName, float] = {}
## Voices waiting for their stagger: [at, cue, pitch].
var _queue: Array[Array] = []
var _music: AudioStreamPlayer
## The round connect_round is watching for the low-timer tick, until it is over.
var _round: Round
var _second := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # music and clicks go on while the tree is paused
	get_tree().node_added.connect(_on_node_added)


## An autoload leaves the tree only when the game quits. A sound still playing then is never released by the
## AudioServer and Godot logs it as a leak (an ERROR, which fails tests/run.sh boot), so stop them all and give the
## audio thread a few mix steps to drop them. ponytail: a blind 150 ms wait at quit (60 ms leaked now and then
## under the headless driver, 100 ms never did); a script cannot see when the server lets go of a playback.
func _exit_tree() -> void:
	for player: AudioStreamPlayer in find_children("*", "AudioStreamPlayer", false, false):
		player.stop()
	OS.delay_msec(150)


func _process(_delta: float) -> void:
	var now := _now()
	var due := _queue.filter(func(q: Array) -> bool: return q[0] <= now)
	_queue = _queue.filter(func(q: Array) -> bool: return q[0] > now)
	for q: Array in due:
		_start(q[1], q[2])
	if _round:
		var second := ceili(_round.time_left)
		if second < _second and second >= 1 and second <= _round.stats.low_time:
			play(LOW_TIMER_TICK)
		_second = second
		if _round.over:
			_round = null


## Plays a cue once. `pitch` is a pitch scale: 1 is as recorded, 2 is an octave up. An empty cue or one with no
## file does nothing. This is where the voice cap and the stagger live: many plays of one cue in one frame are
## spread a few milliseconds apart and capped.
func play(cue: StringName, pitch := 1.0) -> void:
	if _stream(cue) == null:
		return
	var now := _now()
	var at := maxf(now, _next.get(cue, 0.0))
	if at - now > (VOICES - 0.5) * STAGGER:
		return  # this burst already holds every voice (half a stagger of slack: `now` creeps during a burst)
	_next[cue] = at + STAGGER
	if at == now:
		_start(cue, pitch)
	else:
		_queue.append([at, cue, pitch])


## Starts the music loop if it is not playing. Main calls it once; the loop then runs on every screen.
func start_music() -> void:
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.stream = _stream(MUSIC)
		_music.bus = Settings.BUS_MUSIC
		add_child(_music)
	if not _music.playing:
		_music.play()
		played.emit(MUSIC, _music)


## The pitch scale of the brick break at this combo count: one pentatonic step per combo step, from 1 at a count
## of 0 or 1 up to 4 (two octaves) and no higher.
static func combo_pitch(count: int) -> float:
	return pow(2.0, CLIMB[clampi(count - 1, 0, CLIMB.size() - 1)] / 12.0)


## Wires a round to its sounds and plays ROUND_START. The level screen calls it once, on the round it is about
## to step, when Play starts. Connections end with the round; a new round needs a new call.
##   ball_bounced   WALL: WALL_BOUNCE. PADDLE: PADDLE_HIT. ITEM: hit.item.kind.cue
##   brick_hit      BRICK_HIT
##   brick_broken   BRICK_BREAK, one pentatonic step higher per combo step (round.combo.count), up to two octaves.
##                  Then the cue of the brick's kind and the cue of its mod, if they have one (GOLD_BRICK,
##                  HOURGLASS_BRICK, ZAP), whatever broke it
##   ball_added     SPLITTER: a ball split. A Splitter that a blast or a Zap breaks adds no ball, so its kind has
##                  no cue and the sound follows the signal (the launch ball is not added, so it is silent)
##   exploded       EXPLOSION
##   ball_lost      BALL_LOST
##   grew           the cue of the block that pulsed (Growth: BOOSTER, its rising sweep)
##   ended         CLEARED: LEVEL_CLEARED
## It also plays LOW_TIMER_TICK each time round.time_left crosses a whole second at or under
## round.stats.low_time, by watching the round from _process.
## No handler holds the round itself (a lambda or bind that did would keep it alive through its own signals).
func connect_round(p_round: Round) -> void:
	p_round.ball_bounced.connect(_on_ball_bounced)
	p_round.brick_hit.connect(func(_cell: Vector2i, _hp_left: int, _cause: Round.Cause) -> void: play(BRICK_HIT))
	p_round.brick_broken.connect(_on_brick_broken.bind(p_round.combo))
	p_round.ball_added.connect(func(_ball: Ball) -> void: play(SPLITTER))
	p_round.exploded.connect(func(_pos: Vector2, _reach: float, _cells: Array[Vector2i]) -> void: play(EXPLOSION))
	p_round.ball_lost.connect(func(_ball: Ball) -> void: play(BALL_LOST))
	p_round.grew.connect(_on_grew.bind(p_round.board))
	p_round.ended.connect(_on_ended)
	_round = p_round
	_second = ceili(p_round.time_left)
	play(ROUND_START)


func _on_ended(reason: Round.End) -> void:
	if reason == Round.End.CLEARED:
		play(LEVEL_CLEARED)


func _on_grew(cell: Vector2i, _reach: float, _cells: Array[Vector2i], board: Board) -> void:
	play(Kinds.of(board.brick(cell).kind).cue)


func _on_ball_bounced(_ball: Ball, hit: Hit) -> void:
	match hit.surface:
		Hit.Surface.WALL:
			play(WALL_BOUNCE)
		Hit.Surface.PADDLE:
			play(PADDLE_HIT)
		Hit.Surface.ITEM:
			play(hit.item.kind.cue)


func _on_brick_broken(_cell: Vector2i, brick: Brick, _cause: Round.Cause, _dir: Vector2, _coins: int,
		combo: Combo) -> void:
	play(BRICK_BREAK, combo_pitch(combo.count))
	for id: StringName in [brick.kind, brick.mod]:
		var kind := Kinds.of(id)
		if kind:
			play(kind.cue)


## Every button clicks when pressed. node_added fires again when a button re-enters the tree, hence the check.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button and not button.pressed.is_connected(_click.bind(button)):
		button.pressed.connect(_click.bind(button))


func _click(button: BaseButton) -> void:
	if not button.is_in_group(QUIET):
		play(CLICK)


func _start(cue: StringName, pitch: float) -> void:
	var pool: Array = _voices.get_or_add(cue, [])
	var player: AudioStreamPlayer
	if pool.size() < VOICES:
		player = AudioStreamPlayer.new()
		player.stream = _streams[cue]
		player.bus = Settings.BUS_SOUND
		add_child(player)
	else:
		player = pool.pop_front()  # the voice started longest ago
	pool.append(player)
	player.pitch_scale = pitch
	player.play()
	played.emit(cue, player)


## The cue's stream, loaded once; null for &"" and for a cue with no file.
func _stream(cue: StringName) -> AudioStream:
	if not _streams.has(cue):
		var path := DIR.path_join("%s.wav" % cue)
		_streams[cue] = load(path) if cue and ResourceLoader.exists(path) else null
	return _streams[cue]


func _now() -> float:
	return Time.get_ticks_usec() / 1e6
