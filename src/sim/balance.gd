class_name Balance
extends Resource
## Every number the rules use. The values are in data/balance.tres; the defaults here are 0 on purpose, so a
## number can only come from that file and tuning never has to touch code.
##
## This class is also the stats snapshot a round is built from. Progress.snapshot() returns a copy of
## balance.tres with every owned upgrade applied, so inside the rules `stats.ball_speed` is already the upgraded
## value. Rules code reads numbers from the snapshot it was given and from nowhere else.
##
## Units: lengths are round units (see Board), speeds are units per second, times are seconds, angles are degrees.
##
## A lane that finds a number missing adds the property here with its value as the default and says so in its
## report; the value then moves to balance.tres.

@export_group("Stats")
# Each of these is changed by one upgrade (docs/design/upgrades.md). An Upgrade names one in its `stat` field.
@export var paddle_speed: float  ## How fast the paddle moves toward its target
@export var paddle_size: float  ## The paddle's length
@export var ball_speed: float  ## A ball's speed with no boost
@export var round_time: float  ## Seconds on the timer when Play starts
@export var combo_rank: float  ## 0: combos are off. 1: on. Each rank above 1 widens the window
@export var blast_size: float  ## How far an explosion reaches out from the brick's edges, in squares (1 square = 64 units)
@export var shockwave: float  ## 0: off. 1 or more: an explosion throws the balls inside it
@export var explosion_damage: float  ## Hits an explosion gives each brick in it
@export var hourglass_time: float  ## Seconds an hourglass brick adds on top of its kind's own
@export var hourglass_freeze: float  ## Seconds breaking an hourglass brick holds a running combo's window
@export var zap_range: float  ## Bricks a Zap reaches on each side of its brick
@export var zap_damage: float  ## Hits a Zap gives each brick it reaches
@export var booster_speed: float  ## Added to every Booster's boost
@export var splitter_health: float  ## HP a placed Splitter has on top of its kind's own
@export var splitter_splits: float  ## Balls a Splitter splits a ball into, the ball itself included
@export var rear_paddle: float  ## 0: off. Above 0: a paddle on the back wall adds this to Ball.boost on a hit
@export var growth_reach: float  ## How far a Growth block's pulse reaches out from its edges, in squares (1 square = 64 units)
@export var pulse_rate: float  ## Seconds taken off a Growth block's pulse period and a Refresh block's cooldown, down to pulse_min
@export var refresh_size: float  ## How many broken level bricks a Refresh block brings back
@export var overgrowth: float  ## 0: off. 1: every level brick that breaks comes back, plain and 1 HP, overgrowth_delay s later
## Stats that have no property of their own, by name. The per-kind counts live here: `<kind id>_count` is how many
## of that kind the player may place (a placeable) or how many are rolled onto the board (a special brick). A name
## that is missing is 0, so the shipped file leaves this empty. An entry here is a free item before any upgrade.
@export var extra: Dictionary[StringName, float] = {}

@export_group("Ball")
@export var ball_size: float  ## The side of the ball's square
@export var launch_gap: float  ## At rest, the gap between the paddle's face and the ball's near edge
@export var min_angle_vertical: float  ## After a bounce or a throw, the direction is at least this far from straight up or down
@export var min_angle_horizontal: float  ## ...and at least this far from straight left or right. The launch is exempt
@export var boost_cap: float  ## The highest Ball.boost: 2 is twice the base speed
@export var shockwave_boost: float  ## A Shockwave multiplies Ball.boost by this

@export_group("Paddle")
@export var paddle_thickness: float
@export var paddle_inset: float  ## From the open side to the paddle's back edge
@export var paddle_max_angle: float  ## The angle from horizontal a ball leaves at when it hits the very end of the paddle

@export_group("Round")
@export var low_time: float  ## With this many seconds left or fewer, the timer warns (danger colour, the tick cue)
@export var max_hp: int  ## A pulse (Growth) never takes a brick above this HP
@export var pulse_min: float  ## The shortest a pulse period or a Refresh cooldown gets, whatever pulse_rate takes off
@export var overgrowth_delay: float  ## With Overgrowth, seconds of play (Round.clock) before a broken level brick comes back

@export_group("Combo")
# multiplier = 1 + (count - 1) / combo_breaks_per_step, in whole numbers.
# window = max(combo_window_min,
#         (combo_window + combo_window_per_rank * (combo_rank - 1)) * combo_window_shrink ^ (multiplier - 1))
@export var combo_window: float  ## Seconds to hit the next brick, at combo rank 1 and multiplier 1
@export var combo_window_per_rank: float  ## Seconds each combo rank above 1 adds to the window
@export var combo_breaks_per_step: int  ## Hits in a combo (a break is one) that raise the multiplier by 1
@export var combo_window_shrink: float  ## The window is multiplied by this for every multiplier step above 1
@export var combo_window_min: float  ## The window never shrinks below this

@export_group("Coins")
@export var coins_per_brick: float  ## See Coins.total()
# The bonuses, in points, which coins_per_brick turns into coins like the bricks' (Coins.bonuses()).
@export var chain_bonus: float  ## Per level brick in the round's biggest explosion chain
@export var rally_bonus: float  ## Per level brick in the round's longest rally between two paddle touches
@export var clear_bonus: float  ## For a clear, times the level's target
@export var time_bonus: float  ## For breaking every level brick, per whole second left
@export var first_clear_bonus: float  ## For a level's first clear, times the level's target
@export var kept_bonus: float  ## For ending the round with a ball still in play
@export var efficiency_from: float  ## Bricks per paddle touch where the efficiency bonus starts
@export var efficiency_to: float  ## Bricks per paddle touch where it reaches efficiency_bonus
@export var efficiency_bonus: float  ## The most the efficiency bonus adds, as a share of the round's score

@export_group("Setup")
@export var rotate_step: float  ## Degrees a rotatable item turns per press of rotate_cw / rotate_ccw


## The value of a stat by name: its property, or its entry in `extra`, or 0.
func base(stat: StringName) -> float:
	var v: Variant = get(stat)
	return v if v is float else extra.get(stat, 0.0)


## Sets a stat by name: its property if it has one, else its entry in `extra`.
func put(stat: StringName, value: float) -> void:
	if get(stat) is float:
		set(stat, value)
	else:
		extra[stat] = value


## How many of a kind this snapshot allows: the stat `<kind id>_count`, as a whole number.
func count(kind_id: StringName) -> int:
	return int(base(count_stat(kind_id)))


## The name of the stat that counts a kind: &"bumper" gives &"bumper_count".
static func count_stat(kind_id: StringName) -> StringName:
	return StringName(String(kind_id) + "_count")


## A copy that shares nothing with this one. Use this, not duplicate(), which leaves `extra` shared.
func copy() -> Balance:
	var b: Balance = duplicate()
	b.extra = extra.duplicate()
	return b
