extends Control
## The level screen: one level, from Setup through Play to the Summary, and back to Setup on Retry
## (docs/design/overview.md, "Level phases"). Play (src/play.gd) makes one for every visit and frees it on the
## way back to the hub.
##
## It owns the clock and the phase and nothing of the rules: it builds a Round, steps it on the physics tick,
## and hands it to the nodes that show it.
##   Arena     arena.gd      the board, the paddle, the balls, the placed items, the ghost; and Fx, last
##   Hud       hud.gd        time, combo, coins; Play's footer
##   SetupUi   setup_ui.gd   the tray, the placing, Start
##   Summary   summary.gd    the result, Retry or Next, Upgrades
##
## SETUP shows a round that never steps, built from the saved layout and this attempt's seed, so the special
## bricks are already where Play will have them. Every edit saves the layout and builds that round again.
## The keys (not the mouse, which places items) move its paddle, and the ball rides on it (Round.hold).
## PLAY builds it once more and steps it, with the ball still on the paddle until a click or Space launches it
## (Round.launch); until then only the paddle moves and the timer waits. Each spare ball that comes onto the
## paddle later is launched the same way (Round, SPARES). There is no way out. The paddle goes where the last thing the player
## used says: a held key (W/S, the arrows) moves it, the mouse's height draws it, both at paddle speed. A key
## takes over at once, and the mouse takes it back only by moving, so a key player's paddle stays where it was
## left and a resting mouse never pulls it away.
## SUMMARY pays the round, once, as it ends, and shows the result.

enum Phase { SETUP, PLAY, SUMMARY }

## How far the mouse has to move up or down, in screen pixels, to take the paddle back from the keys.
const MOUSE_WAKES := 4.0

## Play sets this before the scene enters the tree (see play.gd for these four members).
var level := 1
## The round on screen: Setup's, then the one Play steps, then the one the Summary reports.
var round: Round
var fx: Fx
var phase := Phase.SETUP

var _data: LevelData
var _stats: Balance
## The level's layout as it is being edited. The round is built from it; it is saved on every change.
var _layout: Layout
var _seed := 0
var _by_mouse := false
var _mouse_y := 0.0
## The mouse's height when the keys last had the paddle.
var _mouse_rest := 0.0

@onready var _arena: LevelArena = $Arena
@onready var _hud: LevelHud = $Hud
@onready var _setup_ui: LevelSetupUi = $SetupUi
@onready var _summary: LevelSummary = $Summary


func _ready() -> void:
	fx = _arena.fx
	_data = Levels.read(level)
	_stats = Progress.snapshot()
	_layout = Progress.layout(level).fitted(_data.board, _stats)
	_setup_ui.open(_layout, _data.board, _stats, _arena)
	_setup_ui.edited.connect(_on_edited)
	_setup_ui.start_pressed.connect(start)
	_setup_ui.back_pressed.connect(_leave)
	_summary.retry_pressed.connect(_setup)
	_summary.next_pressed.connect(_next)
	_summary.back_pressed.connect(_leave)
	_setup()


## What the Start button does (see play.gd): builds the round from the layout as it is and goes from Setup to
## Play, all before it returns. -1 keeps the seed Setup is showing.
func start(with_seed := -1) -> void:
	if phase != Phase.SETUP:
		return
	_setup_ui.cancel()
	if with_seed != -1:
		_seed = with_seed
	phase = Phase.PLAY
	_setup_ui.hide()
	_build()
	round.ended.connect(_on_ended)
	fx.watch(round)
	Sfx.connect_round(round)
	_by_mouse = false
	_mouse_rest = _mouse_y


func _physics_process(delta: float) -> void:
	_arena.remember()
	if phase == Phase.PLAY and not fx.frozen:
		round.step(delta, _paddle_target())
	elif phase == Phase.SETUP:
		# Keys only: in Setup the mouse places items, and it would drag the paddle to Start's height on a click.
		var keys := Input.get_axis(&"paddle_up", &"paddle_down")
		if keys != 0.0:
			round.move_paddle(delta, signf(keys) * INF)


func _input(event: InputEvent) -> void:
	# Main clears hover with a motion to Main.AWAY when the pointer leaves the window. That is not the player's
	# aim: the paddle keeps the last height the pointer had inside. Every other motion steers, also one outside
	# the frame: a wide screen's bars, or the left edge, which the CRT's curve puts a few pixels outside.
	if event is InputEventMouseMotion and event.position != Main.AWAY:
		_mouse_y = (make_input_local(event) as InputEventMouseMotion).position.y
		if absf(_mouse_y - _mouse_rest) >= MOUSE_WAKES:
			_by_mouse = true
	# Here, not in _unhandled_input: the screen's Controls take clicks before that sees them.
	var b := event as InputEventMouseButton
	if b and b.pressed and b.button_index == MOUSE_BUTTON_LEFT and phase == Phase.PLAY and round.waiting:
		get_viewport().set_input_as_handled()
		round.launch()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_leave()
	elif event.is_action_pressed(&"ui_accept") and phase == Phase.SETUP:
		get_viewport().set_input_as_handled()
		start()
	elif event.is_action_pressed(&"ui_accept") and phase == Phase.PLAY and round.waiting:
		get_viewport().set_input_as_handled()
		round.launch()


## Setup: a new attempt, with the special bricks rolled again.
func _setup() -> void:
	fx.clear()
	_summary.close()
	phase = Phase.SETUP
	# ponytail: a new seed, not a check that the special bricks moved. With one special brick among level 1's 20
	# bricks, 1 retry in 20 shows it where it was; compare and roll again if anyone notices.
	_seed = randi()
	_setup_ui.show()
	round = null  # a new attempt starts with the paddle centred
	_build()


## Builds the round from the layout and the seed and puts it on screen. The paddle stays where Setup moved it.
func _build() -> void:
	var paddle_y := round.paddle.y if round else NAN
	round = Round.new(_data.board, _layout, _stats, _seed)
	if not is_nan(paddle_y):
		round.paddle.y = paddle_y
	round.hold()
	round.target = _data.target
	_arena.show_round(round, phase == Phase.SETUP)
	_hud.show_round(round, _data, phase == Phase.SETUP, phase == Phase.PLAY)
	_setup_ui.refresh(round)


func _on_edited(save: bool) -> void:
	if save:
		Progress.set_layout(level, _layout)
	_build()


func _on_ended(_reason: Round.End) -> void:
	phase = Phase.SUMMARY
	var before := Progress.unlocked
	Progress.finish_round(level, round.coins, round.tally.cleared)
	_hud.show_round(round, _data, false, false)
	# The last level's first clear raises `unlocked` too (it is how the win is saved), but opens no level.
	_summary.open(round, _data, Progress.unlocked > before and level < Progress.level_count)


## Back to the hub, from Setup or the Summary. During Play there is no way out.
func _leave() -> void:
	if phase == Phase.PLAY:
		return
	get_viewport().set_input_as_handled()  # or the hub gets the same Esc and goes on to the main menu
	fx.clear()
	Main.show_hub()


## The Summary's Next, after a clear: the next level's Setup, in a new level screen.
func _next() -> void:
	fx.clear()
	Main.show_level(level + 1)


## Where the paddle's centre should go, in units (Round.step).
func _paddle_target() -> float:
	var keys := Input.get_axis(&"paddle_up", &"paddle_down")
	if keys != 0.0:
		_by_mouse = false
		_mouse_rest = _mouse_y
		return signf(keys) * INF
	# The mouse is read in this screen's own pixels, not the Arena's, so a screen shake does not move the target.
	return _arena.to_units(Vector2(0.0, _mouse_y)).y if _by_mouse else round.paddle.y
