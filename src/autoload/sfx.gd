extends Node
## Autoload `Sfx`: every sound and the music (docs/audio.md).
##
## STUB: the audio lane writes the bodies, assets/audio/gen.mjs and the wavs. As shipped here it is silent.
##
## A cue is a StringName and the name of its file: assets/audio/wav/<cue>.wav. Sounds play on the Settings.BUS_SOUND
## bus and the music on Settings.BUS_MUSIC; this script never sets a volume.
##
## Screens play the UI cues themselves (CLICK, BUY, CANT_AFFORD, PLACE_ITEM, TALLY_TICK). Everything a round
## makes is wired by connect_round, so no scene holds audio glue for the rules.

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


## Plays a cue once. `pitch` is a pitch scale: 1 is as recorded, 2 is an octave up. An empty cue or one with no
## file does nothing. This is where the voice cap and the stagger live: many plays of one cue in one frame are
## spread a few milliseconds apart and capped.
func play(_cue: StringName, _pitch := 1.0) -> void:
	pass


## Starts the music loop if it is not playing. Main calls it once; the loop then runs on every screen.
func start_music() -> void:
	pass


## Wires a round to its sounds and plays ROUND_START. The level screen calls it once, on the round it is about
## to step, when Play starts. Connections end with the round; a new round needs a new call.
##   ball_bounced   WALL: WALL_BOUNCE. PADDLE: PADDLE_HIT. ITEM: hit.item.kind.cue
##   brick_hit      BRICK_HIT
##   brick_broken   BRICK_BREAK, one pentatonic step higher per combo step (round.combo.count), up to two octaves.
##                  Then the cue of the brick's kind and the cue of its mod, if they have one (GOLD_BRICK,
##                  HOURGLASS_BRICK, SPLITTER, ZAP)
##   exploded       EXPLOSION
##   ball_lost      BALL_LOST
##   ended          CLEARED: LEVEL_CLEARED
## It also plays LOW_TIMER_TICK each time round.time_left crosses a whole second at or under
## round.stats.low_time, by watching the round from _process.
func connect_round(_round: Round) -> void:
	pass
