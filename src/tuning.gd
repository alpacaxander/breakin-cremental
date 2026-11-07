## Every tunable number and per-kind table lives here. Edit, rerun.

# Game px are 2x sprite px. The arena's origin is its top-left corner; the cabinet (ui.gd) centres it between the columns.
const ARENA := Vector2(960, 720)  # default arena size and the largest allowed: what fits between the columns at the 1280x720 minimum window

# Paddle / ball feel
const PADDLE_WIDTH := 120.0
const PADDLE_HEIGHT := 16.0
const PADDLE_UP := 40.0  # paddle centre above the arena floor
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

# Board generation. shape: "grid", "triangle" (rows narrow by 2 going up) or "honey" (odd rows one brick short, so offset half a step).
const BRICK_SIZE := Vector2(60, 24)
const BRICK_GAP := 4.0
const BOARD_TOP := 100.0  # 44 + two brick rows (2 * (24 + 4))
# special: kind -> chance per brick (see BRICKS). jackpot: one 777 brick per board. seq: one 1-2-3 run per board.
# arena: size, default ARENA (never larger). walls: extra Rect2s in arena px for other shapes; the board must still fit (test.gd).
# skip: column indices left empty (room for a wall). time: round time scale, default 1. Fit at 960x720: cols <= 15, rows <= 16.
# The ramp: each level puts more on screen and needs a bigger combo than the last (docs/ideas.md, Level design).
const LEVELS := [
	{shape = "grid", cols = 10, rows = 4, holes = 0.1, solid = 0.05, payout = 1, arena = Vector2(800, 640),
		special = {multi = 0.08, x2 = 0.03, combo = 0.03, timer = 0.03}},
	{shape = "triangle", cols = 15, rows = 7, holes = 0.1, solid = 0.12, payout = 2, jackpot = true, seq = true,
		special = {multi = 0.08, multi3 = 0.03, shield = 0.04, cond = 0.04, timed = 0.04, cgate = 0.03, x2 = 0.03, x3 = 0.01, combo = 0.03, timer = 0.02, multiball = 0.02, speedup = 0.03, slowdown = 0.02, chain = 0.03, bomb = 0.02, bolt = 0.01, mystery = 0.02}},
	{shape = "grid", cols = 15, rows = 7, holes = 0.08, solid = 0.1, payout = 3, jackpot = true, seq = true,
		special = {multi = 0.1, multi3 = 0.05, shield = 0.05, cond = 0.06, timed = 0.05, cgate = 0.04, x2 = 0.03, x3 = 0.02, combo = 0.03, timer = 0.02, multiball = 0.03, speedup = 0.03, slowdown = 0.02, chain = 0.04, bomb = 0.03, bolt = 0.02, mystery = 0.03}},
	# 4 Honeycomb: offset rows leave diagonal corridors; bolts and speedups at the mouths.
	{shape = "honey", cols = 13, rows = 8, holes = 0.12, solid = 0.04, payout = 4, jackpot = true, seq = true,
		special = {multi = 0.08, shield = 0.03, cond = 0.04, timed = 0.03, cgate = 0.03, x2 = 0.03, combo = 0.03, timer = 0.02, multiball = 0.03, speedup = 0.06, chain = 0.02, bomb = 0.02, bolt = 0.06, mystery = 0.02}},
	# 5 Multiball rain: a swarm is the normal state, combo bricks keep one chain alive, shorter clock.
	{shape = "grid", cols = 14, rows = 8, holes = 0.08, solid = 0.04, payout = 5, time = 0.8, jackpot = true,
		special = {multi = 0.06, shield = 0.03, cond = 0.04, cgate = 0.04, x2 = 0.04, x3 = 0.02, combo = 0.06, timer = 0.02, multiball = 0.1, speedup = 0.03, chain = 0.02, bomb = 0.02, bolt = 0.02, mystery = 0.02}},
	# 6 Tall stack: the most rows yet, a long trip up that pays the whole way.
	{shape = "grid", cols = 13, rows = 12, holes = 0.1, solid = 0.05, payout = 6, arena = Vector2(900, 720), jackpot = true, seq = true,
		special = {multi = 0.08, multi3 = 0.03, shield = 0.03, cond = 0.05, timed = 0.03, cgate = 0.04, x2 = 0.03, x3 = 0.02, combo = 0.04, timer = 0.03, multiball = 0.04, speedup = 0.06, chain = 0.03, bomb = 0.03, bolt = 0.05, mystery = 0.02}},
	# 7 Pinball: holes and solids as posts between clusters, the ball ricochets cluster to cluster. Sells capacity.
	{shape = "grid", cols = 15, rows = 9, holes = 0.16, solid = 0.1, payout = 7, jackpot = true, seq = true,
		special = {multi = 0.08, multi3 = 0.03, shield = 0.04, cond = 0.05, timed = 0.03, cgate = 0.04, x2 = 0.04, x3 = 0.02, combo = 0.04, timer = 0.02, multiball = 0.05, speedup = 0.05, slowdown = 0.02, chain = 0.03, bomb = 0.03, bolt = 0.03, mystery = 0.03}},
	# 8 Chain field: a tight lattice of shockers and bombs, one hit cascades and the counter climbs on its own.
	{shape = "grid", cols = 15, rows = 10, holes = 0.04, solid = 0.02, payout = 8, jackpot = true,
		special = {multi = 0.06, shield = 0.03, cond = 0.04, cgate = 0.04, x2 = 0.04, x3 = 0.02, combo = 0.04, timer = 0.02, multiball = 0.04, speedup = 0.04, chain = 0.1, bomb = 0.06, bolt = 0.03, mystery = 0.02}},
	# 9 Double wide: two boards split by a divider the ball flies over; the far half is for spawned balls and portals.
	{shape = "grid", cols = 15, rows = 10, holes = 0.06, solid = 0.03, payout = 9, skip = [7], walls = [Rect2(472, 180, 16, 380)], jackpot = true, seq = true,
		special = {multi = 0.08, multi3 = 0.03, shield = 0.03, cond = 0.05, timed = 0.03, cgate = 0.04, x2 = 0.04, x3 = 0.02, combo = 0.05, timer = 0.03, multiball = 0.08, speedup = 0.04, chain = 0.03, bomb = 0.03, bolt = 0.04, mystery = 0.02}},
	# 10 Storm: every action brick at once on a dense tall grid, short clock. The clear is one run that never drops.
	{shape = "grid", cols = 15, rows = 12, holes = 0.08, solid = 0.03, payout = 11, time = 0.7, jackpot = true, seq = true,
		special = {multi = 0.06, shield = 0.03, cond = 0.05, timed = 0.03, cgate = 0.05, x2 = 0.05, x3 = 0.03, combo = 0.05, timer = 0.03, multiball = 0.1, speedup = 0.08, chain = 0.04, bomb = 0.04, bolt = 0.05, mystery = 0.03}},
	# 11 Open sky: a few rows at the top of a full arena, the empty middle is the player's own machine.
	{shape = "grid", cols = 15, rows = 5, holes = 0.05, solid = 0.0, payout = 13, time = 0.9, jackpot = true,
		special = {multi = 0.08, multi3 = 0.04, shield = 0.04, cond = 0.05, cgate = 0.05, x2 = 0.04, x3 = 0.03, combo = 0.06, timer = 0.03, multiball = 0.06, speedup = 0.04, chain = 0.03, bomb = 0.04, bolt = 0.03, mystery = 0.03}},
	# 12 Finale: the biggest board the arena holds, every kind, the shortest clock per brick. Clear it to win.
	{shape = "grid", cols = 15, rows = 15, holes = 0.06, solid = 0.04, payout = 16, time = 0.6, jackpot = true, seq = true,
		special = {multi = 0.08, multi3 = 0.04, shield = 0.04, cond = 0.05, timed = 0.04, cgate = 0.05, x2 = 0.05, x3 = 0.03, combo = 0.05, timer = 0.03, multiball = 0.08, speedup = 0.06, slowdown = 0.02, chain = 0.05, bomb = 0.04, bolt = 0.05, mystery = 0.03}},
]

# Board brick kinds. hp: hits to break (-1 never). pay: payout multiplier on break.
# face: the still look, a sprite name or [strip, frame width, frame]. idle: a looping [strip, frame width, fps] over it.
# Icon kinds (multiball..mystery) fire an effect on break and draw their icon_<kind>_pulse strip, so they carry no face here.
# cond breaks only from a ball at FAST_SPEED. cgate only at combo >= GATE_COMBO. timed only while lit.
# seq1..3 only in order. shield loses its shield first. Behaviour: arena.gd _hit, _damage, _effect (adding a kind: CLAUDE.md).
const BRICKS := {
	plain = {hp = 1, pay = 1, face = "brick_plain_lit"}, solid = {hp = -1, pay = 0, face = "brick_solid"},
	multi = {hp = 2, pay = 2, face = "brick_multi_full"}, multi3 = {hp = 3, pay = 3, face = ["multi3_crack", 30, 0]},
	shield = {hp = 2, pay = 2, face = ["shield_pop", 44, 0]},
	cond = {hp = 1, pay = 3, face = "brick_cond_speed_idle"}, cgate = {hp = 1, pay = 3, face = ["combo_gate", 30, 0]},
	timed = {hp = 1, pay = 2, face = ["timed_blink", 30, 0], idle = ["timed_blink", 30, 8]},
	seq1 = {hp = 1, pay = 1, face = ["sequence_step1", 30, 0]}, seq2 = {hp = 1, pay = 2, face = ["sequence_step2", 30, 0]},
	seq3 = {hp = 1, pay = 5, face = ["sequence_step3", 30, 0]},
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
const PLACE_UP := 160.0  # placed bricks must sit at least this far above the arena floor
const PLACE_MARGIN := 2.0  # min gap between a placed brick and anything else
const ROTATE_DEG := 15.0  # per R press
const CAPACITY_BASE := 2
# Placeables. size in screen px, cost in capacity. Owned = start + rank of the upgrade with the same id.
# thru: the ball flies through and the piece acts on it (arena.gd _pass). round: circle collider.
# face and idle as in BRICKS. offset: a strip taller than the body, shifted so the body lines up.
const PLACEABLES := {
	bumper = {name = "Bumper", size = Vector2(90, 14), cost = 2, start = 1, face = "bumper"},
	pop = {name = "Pop bumper", size = Vector2(48, 48), cost = 2, round = true, face = ["pop_bumper_hit", 24, 4]},
	accel = {name = "Launcher", size = Vector2(60, 24), cost = 1, thru = true, face = ["accel_chevrons", 30, 0], idle = ["accel_chevrons", 30, 8]},
	oneway = {name = "One-way gate", size = Vector2(60, 24), cost = 2, thru = true, face = ["gate_flow", 30, 0], idle = ["gate_flow", 30, 8]},
	sticky = {name = "Sticky pad", size = Vector2(60, 12), cost = 2, thru = true, face = "place_sticky"},
	magnet = {name = "Magnet", size = Vector2(60, 24), cost = 3, thru = true, face = "place_magnet", idle = ["magnet_pull", 44, 8]},
	tele = {name = "Portal", size = Vector2(32, 32), cost = 1, thru = true, round = true, face = "place_tele"},
	spawner = {name = "Spawner", size = Vector2(60, 24), cost = 4, face = ["spawner_charge", 30, 0], offset = Vector2(0, -8)},
}
# The other two pieces. The paddle's sprite stretches to its width; walls are invisible.
const PIECES := {paddle = {face = "paddle"}, wall = {}}
const POP_SPEED := 0.1  # speed added per pop bumper hit
const ACCEL_SPEED := 1.5  # ball leaves an accelerator at least this fast
const STICKY_HOLD := 0.75  # seconds, matches sticky_hold strip
const PASS_GRACE := 0.3  # seconds a ball ignores pass-through pieces after one acts on it
const MAGNET_RADIUS := 160.0
const MAGNET_PULL := 700.0  # px/s^2
const SPAWN_EVERY := 6.0  # seconds per spawner ball

# Upgrade web. amount = effect per rank. cost(rank) = cost * cost_mult ^ rank.
# links are undirected: a node shows once any linked node has rank >= 1. pos: node centre in sprite px on the 640x360 layout;
# the web pans and zooms (shop.gd), so positions may run past the field (80-559) once it fills up.
# Names fit the 66px upgrade column at 2x when wrapped by word; descs use only glyphs the 3x5 font has (no ; or lowercase-only marks).
const SEED_UPGRADE := "paddle"
const UPGRADES := {
	"paddle": {name = "Wider Paddle", desc = "+25 paddle width", amount = 25, cost = 5, cost_mult = 1.8, ranks = 3, links = ["bumper"], pos = Vector2(320, 310)},
	"bumper": {name = "Bumper", desc = "+1 placeable bumper", amount = 1, cost = 10, cost_mult = 2.0, ranks = 3, links = ["capacity", "pop", "sticky"], pos = Vector2(430, 240)},
	"capacity": {name = "Capacity", desc = "+2 arena capacity", amount = 2, cost = 15, cost_mult = 2.0, ranks = 5, links = ["accel", "magnet"], pos = Vector2(330, 170)},
	"pop": {name = "Pop Bumper", desc = "+1 round bumper that speeds the ball up", amount = 1, cost = 12, cost_mult = 2.0, ranks = 3, links = ["oneway"], pos = Vector2(500, 170)},
	"accel": {name = "Launcher", desc = "+1 strip that launches the ball to fast speed", amount = 1, cost = 10, cost_mult = 2.0, ranks = 3, links = [], pos = Vector2(280, 100)},
	"oneway": {name = "One-way Gate", desc = "+1 gate: ball passes up, bounces down", amount = 1, cost = 15, cost_mult = 2.0, ranks = 3, links = ["tele"], pos = Vector2(500, 100)},
	"tele": {name = "Portal", desc = "+1 portal: the ball jumps to the next one placed", amount = 1, cost = 15, cost_mult = 2.0, ranks = 4, links = [], pos = Vector2(500, 40)},
	"sticky": {name = "Sticky Pad", desc = "+1 pad that catches the ball and fires it up", amount = 1, cost = 14, cost_mult = 2.0, ranks = 2, links = ["spawner"], pos = Vector2(430, 310)},
	"spawner": {name = "Spawner", desc = "+1 lamp that spits out an extra ball every few seconds", amount = 1, cost = 30, cost_mult = 2.0, ranks = 2, links = [], pos = Vector2(520, 310)},
	"magnet": {name = "Magnet", desc = "+1 magnet that bends the ball toward it", amount = 1, cost = 20, cost_mult = 2.0, ranks = 2, links = [], pos = Vector2(380, 100)},
}

const COLORS := {  # docs/palette.md. Brick, bumper and paddle colors live in their sprites; these are the cabinet and text.
	bg = Color("000020"),
	trim = Color("2e2e5c"),
	trim_hi = Color("5454a7"),
	trim_lo = Color("21224e"),
	rivet = Color("9797d5"),
	pay = Color("ffff00"),
	pay_hi = Color("ffff73"),
	pay_dim = Color("887809"),
	pay_off = Color("443a05"),
	white = Color("ffffcf"),
	pure_white = Color("ffffff"),
	cream = Color("ebde81"),
	mint = Color("15f2b0"),
	danger = Color("ff0000"),
}


## The row describing a kind, whichever table holds it.
static func spec(kind: String) -> Dictionary:
	return BRICKS.get(kind, PLACEABLES.get(kind, PIECES.get(kind, {})))
