## Every tunable number and per-kind table lives here. Edit, rerun.
## Run rewrite (docs/content.md "Code steps"): the incremental loop's tables are cut; the run tables below drive game.gd,
## arena.gd and main.gd. Numbers and names follow docs/content.md; it wins where they differ.

# Game px are 2x sprite px. The arena's origin is its top-left corner; the cabinet (ui.gd) centres it between the columns.
const ARENA := Vector2(960, 720)  # the arena size: the cabinet's 4:3 field

# Paddle / ball feel
const PADDLE_WIDTH := 120.0
const PADDLE_HEIGHT := 16.0
const PADDLE_UP := 40.0  # paddle centre above the arena floor
const PADDLE_SPEED := 800.0  # px/s cap for both mouse-follow and keys
const BALL_SPEED := 480.0
const BALL_RADIUS := 8.0
const MAX_BOUNCE_DEG := 60.0  # angle off vertical when the ball hits the paddle edge
const MIN_VERTICAL := 0.25  # min |vy| as a fraction of speed, stops near-horizontal loops

# Combo (relic `combo`, step 7): window START seconds, mult = 1 + PER_HIT * (combo - 1)
const COMBO_WINDOW_START := 1.0
const COMBO_MULT_PER_HIT := 0.25

# Board generation. Each enemy draws its own board (ENEMIES board.rows), one BOARD_KEYS glyph per brick. Every row centres
# on the arena, so a row one shorter than its neighbours sits half a step over (honeycomb).
const BRICK_SIZE := Vector2(60, 24)
const BRICK_GAP := 4.0
const BOARD_TOP := 168.0  # centre y of the first brick row (the enemy band and top wall sit above it)
const BOARD_FLOOR := 240.0  # bricks must sit at least this far above the arena floor
# One row per fight class (the map node kind). cols: the widest layout row, and the lane grid for lasers and the shield
# row. solid / bomb / red: [chance per "?" brick, hard max], rolled in that order; red_rows limits rolled reds to the first
# n rows. crit / refresh: at least this many, drawn ones first, the rest converted from plain bricks. Placement rules:
# game.gd generate. Fit: rows <= 11, 10 for the boss; every brick reachable past the solids (test.gd).
const BOARDS := {
	fight = {cols = 11, solid = [0.03, 2], bomb = [0.03, 2], red = [0.04, 3], red_rows = 4, crit = 3, refresh = 1},
	elite = {cols = 13, solid = [0.05, 4], bomb = [0.04, 3], red = [0.06, 6], crit = 4, refresh = 2},
	boss = {cols = 15, solid = [0.06, 6], bomb = [0.05, 4], red = [0.08, 10], crit = 5, refresh = 2},
}
const BOARD_KEYS := {".": "", "x": "plain", "?": "?", "#": "solid", "b": "bomb", "R": "red", "c": "crit", "r": "refresh", "g": "gold"}  # "" empty, "?" rolled

# Board brick kinds. hp: hits to break (-1 never). dmg: damage per break (the ball stores ball.dmg * brick.dmg).
# face: the still look, a sprite name or [strip, frame width, frame]. idle: a looping [strip, frame width, fps] over it.
# halo: a looping 60-wide strip behind it. hue: the colour group (docs/palette.md), which picks the <hue>_hit/_break/_spawn
# strips: mag basic, ora bomb, blue crit, mint refresh, red hazard. blast: the bomb's direct enemy damage. hurt: HP a ball
# break of a red costs the player. Behaviour: arena.gd _hit, _damage, _effect (adding a kind: CLAUDE.md).
const BRICKS := {
	plain = {hp = 1, dmg = 1, hue = "mag", face = "brick_plain_lit"},
	solid = {hp = -1, dmg = 0, face = "brick_solid"},  # ponytail: no hue, so it spawns with mag_spawn; a chrome_spawn strip is step 9's call
	bomb = {hp = 1, dmg = 0, hue = "ora", blast = 8, face = ["icon_bomb_pulse", 30, 0], idle = ["icon_bomb_pulse", 30, 8], halo = "halo_pulse_ora"},
	crit = {hp = 1, dmg = 1, hue = "blue", face = ["crit_pulse", 30, 0], idle = ["crit_pulse", 30, 8], halo = "halo_pulse"},  # launches the bag's next ball
	refresh = {hp = 1, dmg = 1, hue = "mint", face = ["refresh_pulse", 30, 0], idle = ["refresh_pulse", 30, 8]},  # regrows the layout
	red = {hp = 1, dmg = 0, hue = "red", hurt = 3, face = "brick_red"},  # a ball break costs the player HP; a blast just removes it
	gold = {hp = 1, dmg = 1, hue = "gold", gold = 5, face = "brick_gold"},  # pays `gold` on a break; an enemy with `jackpot` pays that instead, only when every gold brick breaks in one phase
}
const ICON_KINDS := ["crit", "refresh", "bomb"]  # kinds whose face is a pulse strip (an idle row above), not a static

# Icon effects
const SPEED_MIN := 0.6  # ball speed multipliers
const SPEED_MAX := 2.0
const FAST_SPEED := 1.4  # at or above: ball draws a trail
const BOMB_RADIUS := 72.0  # 3x3 block

# The two pieces. The paddle's sprite stretches to its width; walls are invisible.
const PIECES := {paddle = {face = "paddle"}, paddle_mini = {face = "paddle_mini"}, wall = {}}  # paddle_mini: relic mini_paddle's second paddle
const STICKY_HOLD := 1.5  # seconds a sticky catch holds the ball on the paddle before it fires itself
const MAGNET_RADIUS := 160.0  # relic magnet_paddle: balls this close above the paddle centre are pulled toward it
const MAGNET_PULL := 700.0  # px/s^2

# --- Run (game.gd). docs/content.md "Run state" ---
# enemy_turn: the between-phase beat. refresh_after: seconds an emptied board waits before growing a refresh brick.
# end_beat: seconds between the fight ending and its done signal. hp_floor: the least HP an event's cost leaves. ramp_*: speed
# ramp on long-lived balls (off by default): after ramp_after s a ball's speed multiplier gains ramp_per_s each second up to ramp_max.
const RUN := {hp = 50, gold = 0, enemy_turn = 0.8, regen_below = 10, refresh_after = 1.0, end_beat = 0.6, win_break = 0.6, hp_floor = 1,
	ramp_on = false, ramp_after = 20.0, ramp_per_s = 0.02, ramp_max = 1.6}  # win_break: seconds the board takes to break outward on a win
# Cue ladders, [at least n, value]: the last row n reaches wins (ladder()). damage_land semitones; hp_lose pitch.
const DAMAGE_LAND := [[1, 0], [10, 2], [30, 4], [100, 7]]
const HP_LOSE := [[1, 1.0], [3, 0.85], [6, 0.7]]
const TOP_WALL := 112.0  # y of the top wall body; the enemy band is above it
const SHIELD_Y := 140.0  # centre y of the shield_row hazard
const GOLD := {fight = [12, 6], elite = [30, 6]}  # win gold: base + rand 0..n
const REWARDS := {ball = 40, rank = 25, relic = 15, gold = 20}  # card kind weights; 3 cards of distinct kinds
const REWARD_GOLD := 30  # the gold card
# The pawn shop (map 1): balls of `rarities` only, one slot a `map` ball when any fits; relic slots weighted by
# `relic_weights` (over RELIC_RARITY's); BUY BACK returns run.removed (the last ball removed this run) for `buy_back` = half the ball price.
const SHOP := {ball = 15, remove = 12, heal = 20, heal_hp = 20, balls = 3, relics = 2, rarities = ["common", "uncommon"], map = 1,
	relic_weights = {common = 5, uncommon = 2, rare = 1}, buy_back = 7}
const RELIC_RARITY := {common = {weight = 3, price = 40}, uncommon = {weight = 2, price = 60}, rare = {weight = 1, price = 80}}
const RARITY := {common = 60, uncommon = 30, rare = 10}  # ball tier roll, then uniform within the tier
const BAG_START := ["ball_basic", "ball_basic", "ball_basic", "ball_basic", "ball_heavy", "ball_pierce"]
const MAX_RANK := 3

# Map layers: slots is a kind per slot (a string, or kind -> weight to roll); force names the slot made a fight when no
# slot rolled one; edges[slot] lists the next layer's reachable slots. Node x = MAP_X + MAP_DX * layer, y spread evenly.
const MAP := [
	{slots = ["fight", "fight"], edges = [[0, 1], [1, 2]]},
	{slots = [{fight = 50, event = 30, treasure = 20}, {fight = 50, event = 30, treasure = 20}, {fight = 50, event = 30, treasure = 20}], edges = [[0, 1], [0, 1], [0, 1]], force = 1},
	{slots = ["elite", {fight = 60, event = 40}], edges = [[0], [0]]},
	{slots = ["shop"], edges = [[0]]},
	{slots = ["boss"], edges = []},
]
const MAP_KINDS := ["fight", "elite", "boss", "event", "treasure", "shop"]
const MAP_X := 60
const MAP_DX := 90
const MAP_LEGEND := {fight = "FIGHT", elite = "ELITE", treasure = "TREASURE", shop = "SHOP", event = "EVENT", boss = "BOSS"}  # the map's left column, in this order

# Events: two choices a / b. Numbers are what the choice does; the text is the panel's. Results apply in game.gd event_choice.
const EVENTS := {
	event_coin_return = {title = "COIN RETURN", body = "A DEAD CABINET. THE COIN BOX RATTLES.", a = "PRY IT OPEN", b = "WALK ON", gold = 25, junk = "ball_junk"},
	event_mod_shop = {title = "THE MOD SHOP", body = "A KID WITH A SOLDERING IRON LOOKS UP.", a = "MOD A BALL", b = "SELL ONE", hp = 6, gold = 15},  # a: ranks a ball up for hp; b: sells one (a stone first) for gold
	event_fried_cabinet = {title = "FRIED CABINET", body = "SMOKE. THE SCREEN STILL FLICKERS.", a = "PULL THE PLUG", b = "PLAY IT", heal = 10, gold = 10, hp = 8},  # a: heals for gold; b: the node's relic for hp
	event_vendor = {title = "A GHOST VENDOR", body = "IT HOLDS OUT A RELIC AND SAYS NOTHING.", a = "BUY IT FOR 20", b = "HAGGLE", price = 20, haggle = 0.5, junk = "ball_junk"},
	event_spring = {title = "A HOT SPRING", body = "STEAM. SOMETHING SHINES UNDER THE WATER.", a = "BATHE", b = "DIVE FOR COINS", heal = 15, gold = 25, hp = 5},
}

# Balls: dmg per brick by rank; size and speed multiply BALL_RADIUS and BALL_SPEED; a trait key holds its [r1, r2, r3]:
# split = balls it forks into on its first break per flight, pierce = bricks it passes through per flight, catches = sticky
# paddle catches per phase, every = breaks between blasts (per fight), poison = stacks stored per break, pays = breaks between
# payouts of `gold` (per fight), floor = floor bounces per phase (relic shield_floor's path), magnet = a float multiplier on
# MAGNET_PULL (stacks with relic magnet_paddle). map: the map whose shop prefers it. catch: the 0-stored
# paddle cue's pitch; pitch: the launch and break cue pitch (junk). locked names an UNLOCKS flag. Faces are frame rank-1 of
# <id>_rank. desc: the card line (<= 36 glyphs, wraps at 72 px). Behaviour: arena.gd Ball, _launch, _paddle_hit, _break and _effect.
const BALLS := {
	ball_basic = {name = "PEBBLE", desc = "PLAIN AND STEADY", rarity = "common", dmg = [1, 2, 3], size = 1.0, speed = 1.0},
	ball_heavy = {name = "BOULDER", desc = "BIG AND SLOW", rarity = "common", dmg = [3, 5, 7], size = 1.5, speed = 0.8, catch = 0.7},
	ball_split = {name = "SPLITTER", desc = "FORKS ON ITS FIRST BREAK", rarity = "common", dmg = [1, 2, 3], size = 1.0, speed = 1.0, split = [2, 2, 3]},
	ball_pierce = {name = "NEEDLE", desc = "PASSES THROUGH BRICKS", rarity = "uncommon", dmg = [1, 2, 3], size = 0.75, speed = 1.2, pierce = [3, 5, 8]},
	ball_sticky = {name = "GUM", desc = "CATCHES ON THE PADDLE", rarity = "uncommon", dmg = [2, 3, 4], size = 1.0, speed = 1.0, catches = [1, 2, 3]},
	ball_bomb = {name = "BLASTER", desc = "EVERY NTH BREAK BLASTS", rarity = "uncommon", dmg = [1, 2, 3], size = 1.0, speed = 1.0, every = [5, 4, 3], locked = "finished_run"},
	ball_poison = {name = "SPORE", desc = "STACKS POISON", rarity = "rare", dmg = [0, 0, 1], size = 1.0, speed = 1.0, poison = [1, 2, 3], locked = "killed_elite"},
	ball_token = {name = "TOKEN", desc = "PAYS OUT EVERY NTH BREAK", rarity = "common", dmg = [1, 2, 3], size = 1.0, speed = 1.0, pays = [8, 6, 4], gold = 1, map = 1},
	ball_rubber = {name = "RUBBER", desc = "BOUNCES OFF THE FLOOR", rarity = "uncommon", dmg = [1, 2, 3], size = 1.0, speed = 1.0, floor = [1, 2, 3], map = 1},
	ball_magnet = {name = "MAGNET", desc = "DRAWN TO THE PADDLE", rarity = "uncommon", dmg = [2, 3, 4], size = 1.0, speed = 1.0, magnet = [0.5, 1.0, 1.5], map = 1},
	ball_junk = {name = "STONE", desc = "STORES NOTHING", rarity = "none", dmg = [0, 0, 0], size = 1.0, speed = 0.9, pitch = 0.6},  # never a card, no ranks, its crits launch nothing
}
const SPLIT_DEG := 20.0  # a splitter's halves fan from -SPLIT_DEG to +SPLIT_DEG about its heading

# Enemies: one per fight. role picks the node kind (fight = regular), tier the earliest layer a regular appears.
# cd: paddle hits between intents. intents cycle: [hazard id or "mouth", count]. board: rows = the drawn layout
# (BOARD_KEYS), top = px below BOARD_TOP, no_refresh_rows (game.gd generate).
# off: cue pitch offset in semitones. w: frame width of its <id>_idle/_hit/_attack/_die strips (48 tall). Behaviour: arena.gd.
# Signatures: riposte = a landing of this much counts the intent down by 2; enraged = fields merged into the row below `at`
# of its HP (cd, mouth, mimic = its enemy balls copy the bag's balls in order); steal = gold a dropped ball costs; twice =
# seconds between the two firings of a phase's first intent; jackpot = gold when every gold brick breaks in one phase;
# shield_start = the shield row stands at fight start; advance = rows the board slides toward the paddle each phase while
# it fits above BOARD_FLOOR.
const ENEMIES := {
	glob = {role = "regular", tier = 1, hp = 30, cd = 6, intents = [["red_bricks", 3], ["debris", 4]], off = 0, w = 48, board = {rows = [
		"....xxx....",
		"..xx???xx..",
		".x??xRx??x.",
		"x??xRcRx??x",  # the goo core: a crit behind reds
		".x??xRx??x.",
		"..xx???xx..",
		"....xxx....",
	]}},
	lobber = {role = "regular", tier = 1, hp = 40, cd = 5, intents = [["enemy_balls", 1], ["enemy_balls", 3]], off = -2, w = 48, board = {rows = [
		"x.x.x.x.x.x",  # battlements
		"xxxxxxxxxxx",
		"#?????????#",
		"#?????????#",
		"#?????????#",
		"##xx...xx##",  # the gate
	]}},
	mason = {role = "regular", tier = 3, hp = 55, cd = 6, intents = [["shield_row", 1], ["debris", 6]], off = -4, w = 64, board = {rows = [
		"??xxxxxxx??",
		"?x#######x?",
		"?x#?ccc?#x?",  # the vault
		"?x#?????#x?",
		"?x##xxx##x?",  # the door
		"??xxxxxxx??",
	]}},
	warden = {role = "elite", tier = 4, hp = 120, cd = 5, riposte = 10, intents = [["laser_sweep", 1], ["enemy_balls", 3], ["shield_row", 1]], off = -5, w = 64, board = {rows = [
		"xxx#xxxxx#xxx",
		"x??#????#??x",  # odd rows one short: honeycomb, so the pillars zigzag
		"x??#??c??#??x",
		"x??#????#??x",
		"x??#?c?c?#??x",
		"x??#????#??x",
		"x??#??c??#??x",
		"xxx.xxxx.xxx",
	]}},
	rat_king = {role = "regular", tier = 1, hp = 35, cd = 6, intents = [["coin_junk", 1], ["debris", 3]], off = 3, w = 64, board = {rows = [
		"c?xxxxxxx?c",  # the nest: crits in the four corners
		"?xx?????xx?",
		"xx???????xx",
		"xx???????xx",
		"?xx?????xx?",
		"c?xxxxxxx?c",
	]}},
	coin_slug = {role = "regular", tier = 1, hp = 40, cd = 5, intents = [["coin_junk", 2], ["red_bricks", 2]], off = -1, w = 48, board = {rows = [
		"...xxxxx...",
		".xx?????xx.",
		"xx???????xx",
		"x???xgx???x",  # the coin in its gut
		"xx???????xx",
		".xx?????xx.",
		"...xxxxx...",
	]}},
	fuse_box = {role = "regular", tier = 2, hp = 45, cd = 6, intents = [["red_bricks", 2], ["debris", 6]], off = 1, w = 48, board = {rows = [
		"xxxxxxxxxxx",
		"x?b???????x",  # the fuse: a diagonal of bombs, each inside the next one's blast
		"x??b??????x",
		"x???b?????x",
		"x????b????x",
		"x?????b???x",
		"xxxxxxxxxxx",
	]}},
	claw_rig = {role = "regular", tier = 2, hp = 50, cd = 5, intents = [["pull", 1], ["enemy_balls", 2]], off = -3, w = 64, board = {rows = [
		"xx???????xx",
		"x?#..c..#?x",  # two pillars, the prize lane of crits between them
		"x?#.c.c.#?x",
		"x?#..c..#?x",
		"x?#.....#?x",
		"xx???????xx",
	]}},
	ticket_printer = {role = "regular", tier = 2, hp = 45, cd = 6, advance = 1, intents = [["jam", 1], ["red_bricks", 4]], off = 2, w = 48, board = {rows = [
		"xxxxxxxxxxx",  # the paper: rows that feed toward the paddle a phase at a time
		"?c???????c?",
		"xxxxxxxxxxx",
		"????c??????",
		"xxxxxxxxxxx",
	]}},
	bootleg_cabinet = {role = "regular", tier = 3, hp = 55, cd = 5, intents = [["enemy_balls", 3], ["debris", 4]], off = -2, w = 48, board = {rows = [
		"x#########x",  # the case
		"x#???????#x",
		"x#?R?c?R?#x",  # the cracked screen
		"x#???????#x",
		"x#xxxxxxx#x",
		"x.........x",
		"...xxxxx...",  # the coin door
	]}},
	repo_man = {role = "elite", tier = 4, hp = 110, cd = 5, steal = 1, shield_start = true, intents = [["shield_row", 1], ["coin_junk", 2], ["debris", 6]], off = -6, w = 64, board = {rows = [
		"x???????????x",
		"x?#########?x",  # the vault
		"x?#?c?c?c?#?x",
		"x?#???????#?x",
		"x?###???###?x",  # the door
		"x???????????x",
	]}},
	arcade_bouncer = {role = "elite", tier = 4, hp = 130, cd = 5, twice = 0.3, intents = [["jam", 2], ["enemy_balls", 4]], off = -5, w = 64, board = {rows = [
		"?????#?#?????",  # the rope line, narrowing toward the top
		"????#???#????",
		"???#?????#???",
		"??#???????#??",
		"?#?????????#?",
		"xxxxxxxxxxxxx",
	]}},
	jackpot_reel = {role = "elite", tier = 4, hp = 115, cd = 6, jackpot = 30, intents = [["pull", 1], ["red_bricks", 3], ["debris", 8]], off = -3, w = 64, board = {rows = [
		".xxx.xxx.xxx.",  # three reels
		".x?x.x?x.x?x.",
		".xgx.xgx.xgx.",  # a gold brick in each: all three in one phase pays the jackpot
		".x?x.x?x.x?x.",
		".xxx.xxx.xxx.",
		"xxxxxxxxxxxxx",
	]}},
	attract_mode = {role = "boss", tier = 5, hp = 220, cd = 4, enraged = {at = 0.5, cd = 4, mimic = true},
		intents = [["jam", 1], ["enemy_balls", 5], ["pull", 1]], off = -8, w = 160, board = {top = 32, no_refresh_rows = 2, rows = [
		"x#############x",  # the screen frame
		"x#..ccc..cc..#x",  # the top score
		"x#.xxxxx.xx.x#x",  # the table
		"x#.xxxxx.xx.x#x",
		"x#.?????.??.?#x",
		"x#.xxxxx.xx.x#x",
		"x#.?????.??.?#x",
		"x#.xxxxx.xx.x#x",
		"x#.xxxxx.xx.x#x",
		"x.............x",  # the open bottom
	]}},
	maw = {role = "boss", tier = 5, hp = 240, cd = 4, mouth = 4, enraged = {at = 0.5, cd = 3, mouth = 6},
		intents = [["debris", 8], ["mouth", 1], ["laser_sweep", 2]], off = -7, w = 160, board = {top = 32, no_refresh_rows = 2, rows = [
		"...xxxxxxxxx...",
		".xxx???????xxx.",
		"xx???????????xx",
		"x?#.#.#.#.#.#?x",  # upper teeth
		"x?...........?x",
		"x?....ccc....?x",  # the throat
		"x?...........?x",
		"x?#.#.#.#.#.#?x",  # lower teeth
		"xx???????????xx",
		".xxx???????xxx.",
	]}},
}
const ENEMY_FOOT := Vector2(480, 108)  # bottom centre of the enemy sprite, in the band above TOP_WALL
const ENEMY_STRIPS := {idle = 4, hit = 6, attack = 6, die = 8}  # frames per <id>_<strip>; idle loops at 8 fps, the rest play at 12
const ENEMY_FPS := {idle = 8, hit = 12, attack = 12, die = 12}
const ENEMY_SPAWN_FRAME := 3  # the hazard spawns on this frame of <id>_attack
const MOUTH := {rect = Rect2(432, 0, 96, 32), spit_gap = 0.4}  # boss intent, not a hazard: the zone balls vanish into, seconds between spat balls

# Hazards: hp is what one touching the paddle costs (0 never touches). Sizes and speeds in game px; rows: the live rows
# nearest the paddle red_bricks picks from; enemy_balls speed multiplies BALL_SPEED. flight: in the air, so a phase end
# clears it (and any volley of it still pending); the rest stay placed. jam: the paddle draws at `width` of its build for
# `hits` paddle hits (a refire resets the count; the mini paddle is never jammed). pull: every ball in flight gets `force`
# px/s^2 upward for `secs` per count. coin_junk: a `junk` ball on top of the bag per count. Behaviour: arena.gd _hazard.
const HAZARDS := {
	red_bricks = {hp = 0, rows = 3, stagger = 0.05},  # the red brick's own hurt pays, on a ball break
	enemy_balls = {hp = 5, flight = true, speed = 0.7, radius = 8.0, spread_deg = 15.0, gap = 0.15, windup = 0.5, origin = Vector2(480, 60)},
	debris = {hp = 3, flight = true, size = 16.0, speed = 300.0, apart = 80.0, gap = 0.2, shake = 0.3, shake_px = 4.0},
	laser_sweep = {hp = 6, warn = 1.0, beam = 0.4},  # a lane is one board column (BRICK_SIZE.x + BRICK_GAP wide)
	shield_row = {hp = 0, hits = 8},
	jam = {hp = 0, hits = 6, width = 0.5},
	pull = {hp = 0, flight = true, secs = 1.0, force = 490.0},  # half gravity; flight, so a pull still pending dies with the phase
	coin_junk = {hp = 0, junk = "ball_junk"},
}

# Relics: one passive rule each at hook. on_fight_start / on_break / on_phase_end fire through arena.gd _relics (one match
# by id; `reset` names a second hook the row also fires at); a stat relic is a Game.has read at its site (the paddle build,
# _move_ball, _crit). numbers it needs; desc: the card line (<= 36 glyphs); locked as for balls.
const RELIC_HOOKS := ["stat", "on_fight_start", "on_break", "on_phase_end"]
const RELICS := {
	wide_paddle = {name = "WIDE PADDLE", desc = "PADDLE 160 WIDE", rarity = "common", hook = "stat", width = 160.0},
	shield_floor = {name = "SHIELD FLOOR", desc = "FIRST DROP A PHASE BOUNCES", rarity = "common", hook = "on_fight_start", reset = "on_phase_end", saves = 1},  # floor bounces per phase
	opener = {name = "OPENER", desc = "FIRST BREAK A PHASE IS A CRIT", rarity = "common", hook = "on_break"},  # the phase's first break is a crit too
	toll = {name = "TOLL", desc = "1 GOLD PER 10 BRICKS", rarity = "common", hook = "on_break", per = 10, gold = 1},  # gold per `per` breaks a fight
	tenth_bomb = {name = "TENTH BOMB", desc = "EVERY 10TH BRICK IS A BOMB", rarity = "uncommon", hook = "on_fight_start", every = 10},  # every nth plain (row-major) is a bomb, at least one
	magnet_paddle = {name = "MAGNET PADDLE", desc = "PULLS BALLS TO THE PADDLE", rarity = "uncommon", hook = "stat"},  # MAGNET_RADIUS / MAGNET_PULL
	combo = {name = "COMBO", desc = "FAST BREAKS STORE MORE", rarity = "uncommon", hook = "on_break", cap = 3.0},  # COMBO_WINDOW_START / COMBO_MULT_PER_HIT, mult capped
	twin_crit = {name = "TWIN CRIT", desc = "A CRIT LAUNCHES TWO", rarity = "rare", hook = "on_break", launches = 2, locked = "won_boss"},  # read in _crit, the one break site that launches
	recall = {name = "RECALL", desc = "FIRST DROP A PHASE REJOINS", rarity = "rare", hook = "on_phase_end", balls = 1},  # the first n non-junk drops go back on top of the bag
	mini_paddle = {name = "MINI PADDLE", desc = "A SECOND MIRRORED PADDLE", rarity = "rare", hook = "on_fight_start", size = Vector2(48, 12), locked = "killed_elite"},  # a mirrored paddle_mini
}

# Meta-unlocks: flag -> the BALLS / RELICS ids it unlocks. Flags live in settings.json under meta (step 10 sets them).
const UNLOCKS := {finished_run = ["ball_bomb"], killed_elite = ["ball_poison", "mini_paddle"], won_boss = ["twin_crit"]}

const COLORS := {  # docs/palette.md. Brick and paddle colors live in their sprites; these are the cabinet and text.
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
	return BRICKS.get(kind, PIECES.get(kind, {}))


## A board brick's colour group, the row's hue field: "mag" unless the row says otherwise.
static func hue(kind: String) -> String:
	return BRICKS[kind].get("hue", "mag")


## The value of the last [at least n, value] row of a cue ladder that n reaches (the first row's below that).
static func ladder(table: Array, n: int) -> Variant:
	var v = table[0][1]
	for row in table:
		if n >= row[0]:
			v = row[1]
	return v
