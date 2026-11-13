class_name Palette
## Every colour in the game, copied from docs/palette.md. No other file may contain a colour value:
## tests/cases/layers.gd fails on a colour literal anywhere else, scenes and resources included. So a scene never
## sets a colour property in the inspector; its script assigns one of these in _ready.
##
## A colour here is the palette value, which is what an unlit thing shows. A lit thing (anything that should
## glow) is drawn in `lit(colour)`. See lit() for the rule.

# Neutrals. Slate never glows: every one of these is under the bloom threshold.
const BASE := Color("0e071b")  ## Background
const PANEL := Color("1a1932")  ## Backdrop grid, panel fill
const WALL := Color("2a2f4e")  ## Walls, disabled buttons, setup grid lines, the web view's frame and dots
const BORDER := Color("424c6e")  ## Panel borders, locked nodes, unlit connections, empty rank pips
const PADDLE := Color("657392")  ## Paddle body
const TEXT_DIM := Color("92a1b9")  ## Secondary text
const TEXT := Color("c7cfdd")  ## Primary text
const CLEAR := Color(0, 0, 0, 0)  ## No fill

# Meanings: one hue per meaning, lit and dim. Dim is for inactive states (a locked node, an empty slot).
const BALL := Color("ffffff")  ## The ball and its trail, and nothing else
const PLAYER := Color("0cf1ff")  ## Cyan: paddle stripe, cursor, selection, buttons, Arena upgrade nodes
const PLAYER_DIM := Color("134c4c")
const PLACEABLE := Color("0098dc")  ## Blue: every placeable, the tray, Placeables upgrade nodes
const PLACEABLE_DIM := Color("00396d")
const COINS := Color("ffc825")  ## Gold: coin counter, pop-ups, combo counter, gold bricks, prices
const COINS_DIM := Color("8a4836")
const TIME := Color("99e65f")  ## Green: timer, hourglass bricks
const TIME_DIM := Color("1e6f50")
const EXPLOSIVE := Color("ff5000")  ## Orange: explosive bricks and their blasts
const EXPLOSIVE_DIM := Color("c64524")
const DANGER := Color("ff0040")  ## Red: low-timer warning, ball-lost flash, "can't afford". Never for numbers
const DANGER_DIM := Color("891e2b")
const BRICKS := Color("ca52c9")  ## Magenta: Bricks upgrade nodes. Same value as a 1 HP brick
const BRICKS_DIM := Color("622461")

## Plain brick colour by hits left: HP[0] is 1 HP, HP[3] is 4 and up. Use hp() to index it.
const HP: Array[Color] = [Color("ca52c9"), Color("db3ffd"), Color("f389f5"), Color("fdd2ed")]

## The meaning names a kind's `colour` and Upgrade.meaning() use, each with its lit and dim colour.
const MEANINGS: Dictionary = {
	&"player": [PLAYER, PLAYER_DIM],
	&"placeable": [PLACEABLE, PLACEABLE_DIM],
	&"coins": [COINS, COINS_DIM],
	&"time": [TIME, TIME_DIM],
	&"explosive": [EXPLOSIVE, EXPLOSIVE_DIM],
	&"danger": [DANGER, DANGER_DIM],
	&"bricks": [BRICKS, BRICKS_DIM],
}

# Boosts for lit(). They were measured in the render spike at glow_intensity 0.06.
const LIT := 4.0  ## Shapes and big numbers: bricks, placeables, bars, the paddle stripe, text of 36 px and up
const LIT_BALL := 12.0  ## The ball and its trail. The strongest halo on screen; nothing else may use it
const LIT_TEXT := 8.0  ## Lit text under 36 px, which shows no halo at 4. Anything from 8 to 16 works
const LIT_FILL := 2.0  ## A lit fill with dark text on it (the primary button). At 4 the text washes out


## The colour to draw a lit thing in: `c` multiplied in linear light, so it lands over the bloom threshold and
## glows. The result has channels above 1 and works wherever a Color goes (ColorRect.color, draw_rect,
## StyleBoxFlat colours, a font colour override, modulate).
##
## Anything not passed through here keeps its palette value and does not glow. On screen a lit colour shows as
## the full-brightness version of its hue: exact for cyan, gold, orange, red and white, brighter than the hex for
## the others (HP 1 shows as ff6afe, blue as 00b1ff, green as aaff6a).
static func lit(c: Color, boost := LIT) -> Color:
	var l := c.srgb_to_linear() * boost
	l.a = c.a
	return l.linear_to_srgb()


## The lit colour of a meaning, by name (see MEANINGS). An unknown name gives TEXT.
static func of(meaning: StringName) -> Color:
	return MEANINGS[meaning][0] if MEANINGS.has(meaning) else TEXT


## The dim colour of a meaning, by name. An unknown name gives BORDER.
static func dim(meaning: StringName) -> Color:
	return MEANINGS[meaning][1] if MEANINGS.has(meaning) else BORDER


## The colour of a plain brick with `hits_left` HP. 0 or less gives the 1 HP colour, 4 and up share the top step.
static func hp(hits_left: int) -> Color:
	return HP[clampi(hits_left, 1, HP.size()) - 1]


## The palette colour of a brick: its kind's meaning if it has a kind (a special brick, a Splitter), else its HP
## step. The board, the thumbnail, the legend and the break particles all use this, so they always agree.
static func brick(b: Brick) -> Color:
	var kind := Kinds.of(b.kind)
	return of(kind.colour) if kind else hp(b.hp)


## The colour to draw a brick in on the board: lit(brick(b)). Every brick is lit at the same boost, so the HP
## steps differ on screen by hue, not by brightness (1 HP shows as ff6afe, 2 as dd40ff, 3 as fd8fff, 4 as
## ffd4ef). This is the one place to change if 1 HP bricks should be drawn dimmer or unlit.
static func lit_brick(b: Brick) -> Color:
	return lit(brick(b))
