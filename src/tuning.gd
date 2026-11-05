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
const LEVELS := [
	{shape = "grid", cols = 10, rows = 4, holes = 0.1, solid = 0.05, payout = 1},
	{shape = "triangle", cols = 15, rows = 7, holes = 0.1, solid = 0.12, payout = 2},
]

# Placement
const PLACE_MAX_Y := 560.0  # placed bricks must sit above this line
const PLACE_MARGIN := 2.0  # min gap between a placed brick and anything else
const BUMPER_SIZE := Vector2(90, 14)
const BUMPER_ROTATE_DEG := 15.0  # per R press
const BUMPER_COST := 2  # capacity used per bumper
const CAPACITY_BASE := 2
const START_BUMPERS := 1

# Upgrade web. amount = effect per rank. cost(rank) = cost * cost_mult ^ rank.
# links are undirected: a node shows once any linked node has rank >= 1.
const SEED_UPGRADE := "paddle"
const UPGRADES := {
	"paddle": {name = "Wider Paddle", desc = "+25 paddle width", amount = 25, cost = 5, cost_mult = 1.8, ranks = 3, links = ["time", "bumper"], pos = Vector2(640, 420)},
	"time": {name = "More Time", desc = "+5s per round", amount = 5, cost = 8, cost_mult = 1.8, ranks = 3, links = ["combo"], pos = Vector2(420, 300)},
	"combo": {name = "Combo Window", desc = "+0.3s combo window", amount = 0.3, cost = 12, cost_mult = 2.0, ranks = 3, links = [], pos = Vector2(420, 170)},
	"bumper": {name = "Bumper", desc = "+1 placeable bumper", amount = 1, cost = 10, cost_mult = 2.0, ranks = 3, links = ["capacity"], pos = Vector2(860, 300)},
	"capacity": {name = "Capacity", desc = "+2 arena capacity", amount = 2, cost = 15, cost_mult = 2.0, ranks = 3, links = [], pos = Vector2(860, 170)},
}

const COLORS := {
	bg = Color("1a1426"),
	ball = Color("fff4c2"),
	combo = Color("ffcc33"),
	plain = Color("e8486b"),
	solid = Color("6b6880"),
	bumper = Color("3ad1c6"),
	paddle = Color("f2f2f2"),
	line = Color(1, 1, 1, 0.25),
}
