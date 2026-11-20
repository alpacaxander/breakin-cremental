# Audio

How the game's sound is made and played. The look it has to match is in [design.md](design.md#art--audio). Every value is provisional.

## How it is made

Every sound is synthesised by one script. Nothing is recorded or downloaded.

- **Generator:** `assets/audio/gen.mjs`, a Node script with no dependencies, taken over from the purged build. It has a tone voice (square, triangle, saw or sine, with pitch glide, decay, vibrato and duty cycle), a filtered noise voice, and a function that layers them.
- **Cues:** each sound is one recipe in the script, for the list below.
- **Output:** 44.1 kHz mono 16-bit WAV files, committed to the repo. The noise is seeded, so running the script again only changes the cues whose recipe changed.
- **Audition page:** the script also writes a `demo.html` with a play button for every cue. Sounds are judged by ear on that page.
- **Dev shell:** `flake.nix` provides Node, so the script runs under `nix develop`.
- **In the game:** a cue's name is its file name, `assets/audio/wav/<cue>.wav`. `Sfx` (`src/autoload/sfx.gd`) has a constant for each cue below, and `Sfx.connect_round(round)` wires a round's signals to them.
- **Clicks:** `Sfx` plays the click for every button in the game by itself, so no screen and no widget plays one. A button whose press has a cue of its own (Buy, Start) is put in the group `Sfx.QUIET` and gets no click. The other UI cues are played by the screen they belong to: buy and can't afford by the hub, place item and the tally tick by the level screen (see the header of `sfx.gd`).

## Sound cues

| Group | Cues |
|---|---|
| Ball and paddle | paddle hit, wall bounce, ball lost |
| Bricks | brick hit, brick break, explosion, gold brick, hourglass brick. A ball brick plays splitter: both give a ball. A spare going onto the paddle is silent |
| Placeables | bumper, booster, splitter, zap. A Growth pulse plays booster, its rising sweep; bricks a Refresh block brings back play place item, the thunk of a brick put down. Bricks Overgrowth brings back are silent: hundreds come back in a few seconds on level 3, which would bury the break and combo cues under a steady patter, and it is the arena acting, not the player |
| Round | round start, low-timer tick, level cleared, summary tally tick |
| UI | click, buy, can't afford, place item |

## Playback rules

- **Combo pitch climb.** There is one brick break sample. Each combo step plays it one note higher on a pentatonic scale, up to two octaves above the start, so any run of hits sounds musical.
- **Punch.** Big cues (explosion, level cleared, ball lost) layer a low sine thump and a noise burst under the square wave. The master bus has a limiter.
- **Voice cap.** Many bricks can break in one frame, for example 64 from a Zap on level 3. Stagger those sounds by a few milliseconds and cap the voices per cue so the mix doesn't clip. `Sfx` gives each cue 4 voices and starts them 15 ms apart; a play beyond that in one burst is dropped.
- **Low timer.** `Sfx` ticks once for each whole second the timer crosses from the low-timer mark down to 1.
- **Volumes.** `Sfx` never sets a volume. Settings owns the two bus volumes, and the balance between music and sounds is in the files.
- **Effects follow the cause.** A sound is played because of a game event, such as a brick breaking. Game rules never depend on a sound.

## Music

The demo has one simple placeholder loop, made by the same script: a square-wave lead, a triangle bass and a noise hi-hat, about 16 bars long (25.6 s at 150 bpm, in A minor). It loops through the loop mode in `music.wav.import`, so keep that file when the wav is made again. It loops on every screen and plays quieter than the sound effects.

**Nobody has listened to any of it yet.** The cues and the loop were checked by their numbers only (format, length, peak, loudness, silent ends, a silent loop seam). Judge them by ear on `assets/audio/demo.html`. Settings has a volume slider for music and one for sound.
