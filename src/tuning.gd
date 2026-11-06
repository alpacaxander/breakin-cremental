## Every tunable number lives here. Edit, rerun.

const VIEW := Vector2(1280, 720)
const HUD_HEIGHT := 40.0

# Paddle / ball feel
const PADDLE_WIDTH := 120.0
const PADDLE_HEIGHT := 16.0
const PADDLE_Y := 680.0
const PADDLE_SPEED := 1400.0  # px/s cap for both mouse-follow and keys
const BALL_SPEED := 480.0
const BALL_RADIUS := 8.0
const MAX_BOUNCE_DEG := 60.0  # angle off vertical when the ball hits the paddle edge
const MIN_VERTICAL := 0.25  # min |vy| as a fraction of speed, stops near-horizontal loops

# Round
const ROUND_TIME_BASE := 15.0
const ROUND_TIME_PER_BRICK := 0.4  # seconds added per breakable brick on the board

# Combo: window(n) = START + upgrades - SHRINK * (n - 1), floored at MIN
const COMBO_WINDOW_START := 1.5
const COMBO_WINDOW_SHRINK := 0.1
const COMBO_WINDOW_MIN := 0.4
const COMBO_MULT_PER_HIT := 0.25  # mult = 1 + this * (combo - 1)

# Board generation. shape: "grid" or "triangle" (rows narrow by 2 going up).
const BRICK_SIZE := Vector2(60, 24)
const BRICK_GAP := 4.0
const BOARD_TOP := 90.0
# special: kind -> chance per brick (see BRICKS). jackpot: one 777 brick per board. seq: one 1-2-3 run per board.
const LEVELS := [
	{shape = "grid", cols = 10, rows = 4, holes = 0.1, solid = 0.05, payout = 1,
		special = {multi = 0.08, x2 = 0.03, combo = 0.03, timer = 0.03}},
	{shape = "triangle", cols = 15, rows = 7, holes = 0.1, solid = 0.12, payout = 2, jackpot = true, seq = true,
		special = {multi = 0.08, multi3 = 0.03, shield = 0.04, cond = 0.04, timed = 0.04, cgate = 0.03, x2 = 0.03, x3 = 0.01, combo = 0.03, timer = 0.02, multiball = 0.02, speedup = 0.03, slowdown = 0.02, chain = 0.03, bomb = 0.02, bolt = 0.01, mystery = 0.02}},
	{shape = "grid", cols = 16, rows = 7, holes = 0.08, solid = 0.1, payout = 3, jackpot = true, seq = true,
		special = {multi = 0.1, multi3 = 0.05, shield = 0.05, cond = 0.06, timed = 0.05, cgate = 0.04, x2 = 0.03, x3 = 0.02, combo = 0.03, timer = 0.02, multiball = 0.03, speedup = 0.03, slowdown = 0.02, chain = 0.04, bomb = 0.03, bolt = 0.02, mystery = 0.03}},
]

# Board brick kinds. hp: hits to break (-1 never). pay: payout multiplier on break.
# cond breaks only from a ball at FAST_SPEED. cgate only at combo >= GATE_COMBO. timed only while lit.
# seq1..3 only in order. shield loses its shield first. Icon kinds (multiball..mystery) fire an effect on break.
const BRICKS := {
	plain = {hp = 1, pay = 1}, solid = {hp = -1, pay = 0},
	multi = {hp = 2, pay = 2}, multi3 = {hp = 3, pay = 3}, shield = {hp = 2, pay = 2},
	cond = {hp = 1, pay = 3}, cgate = {hp = 1, pay = 3}, timed = {hp = 1, pay = 2},
	seq1 = {hp = 1, pay = 1}, seq2 = {hp = 1, pay = 2}, seq3 = {hp = 1, pay = 5},
	multiball = {hp = 1, pay = 1}, speedup = {hp = 1, pay = 1}, slowdown = {hp = 1, pay = 1},
	x2 = {hp = 1, pay = 1}, x3 = {hp = 1, pay = 1}, combo = {hp = 1, pay = 1}, timer = {hp = 1, pay = 1},
	chain = {hp = 1, pay = 1}, bomb = {hp = 1, pay = 1}, bolt = {hp = 1, pay = 1}, jackpot = {hp = 1, pay = 1}, mystery = {hp = 1, pay = 1},
}
const ICON_KINDS := ["multiball", "speedup", "slowdown", "x2", "x3", "combo", "timer", "chain", "bomb", "bolt", "jackpot", "mystery"]

# Icon and conditional effects
const SPEED_MIN := 0.6  # ball speed multipliers
const SPEED_MAX := 2.0
const FAST_SPEED := 1.4  # at or above: cond bricks break, ball draws a trail
const SPEEDUP := 1.25
const SLOWDOWN := 0.8
const BOOST_HITS := 5  # x2/x3 apply to this many breaks
const COMBO_EXTEND := 1.0  # seconds, C+ brick
const TIME_EXTEND := 5.0  # seconds, hourglass brick
const CHAIN_DIST := 66.0  # orthogonal neighbours only (step is 64 x 28)
const BOMB_RADIUS := 72.0  # 3x3 block
const JACKPOT_MULT := 20  # times the level payout
const GATE_COMBO := 3
const CHASE_AT := 0.5  # combo seconds left when the pulse turns into the chase

# Placement
const PLACE_MAX_Y := 560.0  # placed bricks must sit above this line
const PLACE_MARGIN := 2.0  # min gap between a placed brick and anything else
const ROTATE_DEG := 15.0  # per R press
const CAPACITY_BASE := 2
# Placeables. size in screen px, cost in capacity. Owned = start + rank of the upgrade with the same id.
# thru: the ball flies through and the piece acts on it. round: circle collider.
const PLACEABLES := {
	bumper = {name = "Bumper", size = Vector2(90, 14), cost = 2, start = 1},
	pop = {name = "Pop bumper", size = Vector2(48, 48), cost = 2, round = true},
	accel = {name = "Accelerator", size = Vector2(60, 24), cost = 1, thru = true},
	oneway = {name = "One-way gate", size = Vector2(60, 24), cost = 2, thru = true},
	sticky = {name = "Sticky pad", size = Vector2(60, 12), cost = 2, thru = true},
	magnet = {name = "Magnet", size = Vector2(60, 24), cost = 3, thru = true},
	tele = {name = "Teleporter", size = Vector2(32, 32), cost = 1, thru = true, round = true},
	spawner = {name = "Spawner", size = Vector2(60, 24), cost = 4},
}
const POP_SPEED := 0.1  # speed added per pop bumper hit
const ACCEL_SPEED := 1.5  # ball leaves an accelerator at least this fast
const STICKY_HOLD := 0.75  # seconds, matches sticky_hold strip
const PASS_GRACE := 0.3  # seconds a ball ignores pass-through pieces after one acts on it
const MAGNET_RADIUS := 160.0
const MAGNET_PULL := 700.0  # px/s^2
const SPAWN_EVERY := 6.0  # seconds per spawner ball

# Upgrade web. amount = effect per rank. cost(rank) = cost * cost_mult ^ rank.
# links are undirected: a node shows once any linked node has rank >= 1.
const SEED_UPGRADE := "paddle"
const UPGRADES := {
	"paddle": {name = "Wider Paddle", desc = "+25 paddle width", amount = 25, cost = 5, cost_mult = 1.8, ranks = 3, links = ["time", "bumper"], pos = Vector2(640, 420)},
	"time": {name = "More Time", desc = "+5s per round", amount = 5, cost = 8, cost_mult = 1.8, ranks = 3, links = ["combo"], pos = Vector2(420, 300)},
	"combo": {name = "Combo Window", desc = "+0.3s combo window", amount = 0.3, cost = 12, cost_mult = 2.0, ranks = 3, links = [], pos = Vector2(420, 170)},
	"bumper": {name = "Bumper", desc = "+1 placeable bumper", amount = 1, cost = 10, cost_mult = 2.0, ranks = 3, links = ["capacity", "pop", "sticky"], pos = Vector2(860, 300)},
	"capacity": {name = "Capacity", desc = "+2 arena capacity", amount = 2, cost = 15, cost_mult = 2.0, ranks = 5, links = ["accel", "magnet"], pos = Vector2(860, 170)},
	"pop": {name = "Pop Bumper", desc = "+1 round bumper that speeds the ball up", amount = 1, cost = 12, cost_mult = 2.0, ranks = 3, links = ["oneway"], pos = Vector2(1060, 300)},
	"accel": {name = "Accelerator", desc = "+1 strip that launches the ball to fast speed", amount = 1, cost = 10, cost_mult = 2.0, ranks = 3, links = [], pos = Vector2(1060, 170)},
	"oneway": {name = "One-way Gate", desc = "+1 gate: ball passes up, bounces down", amount = 1, cost = 15, cost_mult = 2.0, ranks = 3, links = ["tele"], pos = Vector2(1060, 440)},
	"tele": {name = "Teleporter", desc = "+1 portal; the ball jumps to the next one placed", amount = 1, cost = 15, cost_mult = 2.0, ranks = 4, links = [], pos = Vector2(1060, 560)},
	"sticky": {name = "Sticky Pad", desc = "+1 pad that catches the ball and fires it up", amount = 1, cost = 14, cost_mult = 2.0, ranks = 2, links = ["spawner"], pos = Vector2(860, 440)},
	"spawner": {name = "Spawner", desc = "+1 lamp that spits out an extra ball every few seconds", amount = 1, cost = 30, cost_mult = 2.0, ranks = 2, links = [], pos = Vector2(860, 560)},
	"magnet": {name = "Magnet", desc = "+1 magnet that bends the ball toward it", amount = 1, cost = 20, cost_mult = 2.0, ranks = 2, links = [], pos = Vector2(640, 170)},
}

const COLORS := {  # docs/palette.md. Brick, bumper and paddle colors live in their sprites.
	bg = Color("000020"),
	combo = Color("ffff00"),
	line = Color("5454a7"),
	trim = Color("2e2e5c"),
}
