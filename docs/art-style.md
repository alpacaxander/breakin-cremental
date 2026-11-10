# Art style

Pixel art, neon tube look. Theme: neon cyberpunk. Reference implementation: `assets/pixel/gen.mjs`. When this doc and the code disagree, the code wins and this doc gets fixed. Colors: `docs/palette.md`. Inventory: `docs/sprite-spec.md`.

Direction set 2026-11-10: the board is a breakout cabinet in a back-alley arcade. Every brick is a lit neon tube on a near-black base, every unlit thing is gunmetal, and the only light that is not a tube is the enemy's single red eye. Cyan is the player's hue, magenta the bricks', hot pink the UI's. Preview: `assets/pixel/preview/palette.html`. The generator still draws the deprecated cabinet palette (the bottom of `docs/palette.md`); the hue sets below are the target, and the old sets stay listed until `SETS` in `gen.mjs` moves.

Enemies are the one place a non-lamp style is allowed: a dark creature or drone sprite with a single lit accent in red, so it reads as the thing that is not part of the machine.

## Canvas

- Game canvas 640x360, shown at 2x with nearest filtering (1280x720 window). One sprite pixel is two screen pixels.
- Everything sits on the pixel grid. No sub-pixel positions, no runtime scaling, no anti-aliasing.
- Base sizes: brick 30x12, bumper 45x7, ball 8x8, paddle 60x8. New field objects are multiples of the brick cell (30x12) or share an existing size.

## Lamp anatomy

Every lit object is built the same way, outside in. See `lamp()`.

```
.TTTTTTTTTTTTTTTTTTTTTTTTTTTT.   row 0   T tube      1px, the hue's bright swatch
TRRRRRRRRRRRRRRRRRRRRRRRRRRRRT   row 1   R ring      1px, the hue's mid swatch
TR.HHHHHHHHHHHHHHHHHHHHHHHH.RT   row 2   H highlight 1px, inset 3 from the edge
TR..........................RT   rows 3-9  glass     the hue's deep swatch
TR..........................RT
TR..........................RT
TR..........................RT
TR..........................RT
TR..........................RT
TR..........................RT
TRRRRRRRRRRRRRRRRRRRRRRRRRRRRT   row 10
.TTTTTTTTTTTTTTTTTTTTTTTTTTTT.   row 11  corners cut
```

- Four corner pixels are always transparent. That is the only rounding.
- Outlines are the object's own hue, never black.
- Light comes from the top: highlight is a single row near the top, nothing on the bottom.
- Icons and pips live in the glass, at least 1px clear of the ring. Max 10px tall on a brick.

## Hue sets

A lit object uses exactly one set. Never mix swatches across sets.

Target sets (neon cyberpunk palette, `docs/palette.md` Groups):

| Set | Tube | Ring | Deep | Highlight | Used for |
|---|---|---|---|---|---|
| Magenta | `ff4aff` | `a200a2` | `350035` | `ffcaff` | basic bricks (plain, multi-hit: the glass steps `350035`, `550055`, `790079` for 1, 2, 3 hits left) |
| Blue | `3131ff` | `0000c4` | `000052` | `c6c6ff` | crit bricks and their halo. On-palette now, still deeper than anything the player owns |
| Mint | `15f2b0` | `02936b` | `01563f` | `b7fbe7` | refresh bricks and the refresh wave |
| Cyan | `00ffff` | `00a0b8` | `003a50` | `b0ffff` | paddle stripe and hit flash, paddle extras, starting paddles, holograms, the map path |
| Orange | `ff7500` | `c44f00` | `791800` | `ffb975` | bomb bricks and the board specials an act places (shield, conditional, timed). Dim is locked, lit is open |
| Amber | `ffb000` | `c07c00` | `503000` | `ffe08a` | telegraphs: intent countdown pips, hazard warning stripes, the timed brick's count |
| Violet | `7f16ff` | `48009f` | `240051` | `c799ff` | relics and ball traits in the HUD and shop, the shield floor |
| Green | `00ff00` | `00bf00` | `003f00` | `a0ff60` | poison, junk and virus traits, the hack cue |
| Gold | `ffc84a` | `9b5b13` | `2b1a06` | `fff5a8` | gold: the run currency, shop prices, the gold brick. Same ramp as amber, lighter end |
| Pink | `ff1493` | `c00c6a` | `300218` | `ffa0d0` | UI accent: buttons, selection, the logo, the shop sign. Never on a brick |
| Yellow | `ffff00` | `887809` | `000020` | `ffff73` | damage: the stored number on a ball, the paddle flash that fires it, sparks and break effects |
| Red | `ff0000` | `9f0000` | `370000` | `ff7f7f` | enemies and everything they put on the board: red bricks, fuse bricks, enemy balls, goo, lasers, debris, the HP bar. Not in `SETS`: the red strips come from `parts/bricks.mjs` and `parts/hazards.mjs` |

Deprecated sets, what `gen.mjs` draws today: Blue `3d6bff` `1f3bc4` `0b1658` `bccbff`; Sky (paddle) `4fc7ff` `186fb6` `0e3556` `cefaff`; Gold `ebdb57` `9b5b13` `2b1a06` `fff5a8`; Red `ff0000` `a30000` `3a0000` `ff8a8a`. Magenta, mint, orange, violet and yellow are unchanged.

The sets are `SETS` in `gen.mjs`; a new one takes top, mid, near-bottom and tint from one palette ramp.

## Unlit anatomy

Solids, the paddle, walls and hull are gunmetal. Horizontal bands only, top to bottom: `e8f4f8`, `c0d4dc`, `98b4c0`, `7494a4`, `567888`, `3e5c6c`, `2c4452`, `1e3040`, `14202c`, `0c141c`. Use as many bands as the height allows, keep the order. Rivets are single `c0d4dc` pixels. Corners cut. The paddle carries one cyan stripe one row above its bottom band.

Deprecated chrome, what `gen.mjs` draws today: `e7e7ff`, `c6c6ff`, `9797d5`, `7777bb`, `5454a7`, `414183`, `21224e`, rivets `c6c6ff`.

## States

Shape never changes between states. Only swatches do.

| State | Tube | Ring | Glass | Highlight | Extra |
|---|---|---|---|---|---|
| Lit | set tube | set ring | set deep | on | |
| Dim | set deep-ish dim (`790079` for magenta) | one step darker | base `000020` | off | |
| Flash | `ffffff` | `ffffcf` | `ffffcf` | `ffffff` | 1 frame |
| Cracked | lit | lit | one step darker | on | 1px crack in `ffffcf`, one lit pip goes dim |
| Ghost | dashed 2 on 2 off in set tube | none | set tube at alpha 50 | off | invalid uses `ff0000` and an X |

## Text

One font: the 3x5 face in `FONT` in the generator. 1px letter spacing. HUD text draws at 2x (6x10) in ice `e0ffff` (deprecated: cream `ffffcf`). In-sprite text draws at 1x in yellow or base navy. The ball stays cream so it reads as an object, not text.

## Effects

- Glow is a shader in-engine. Sprites do not bake glow.
- Halo sprites use checkerboard dither only, three bands, in the object's tube color.
- Sparks are 5x5 plus shapes in yellow with a white center. Debris is a 4x3 chip in the broken brick's tube and deep swatches.

## Animation

- 12 fps for hits and effects, 8 fps for idle loops. Frames are whole-pixel moves, no tweening.
- Every hit starts with one flash frame, then one "hot" frame (tube goes to highlight swatch, glass to ring swatch, highlight to pure white), then the normal state. See `hot()` in the generator. Dim is `dim()`, half-lit transitions are `mid()`.
- Breaks: flash, hot, split into two halves, fade with debris, empty. Fade is alpha on the whole sprite, the only place alpha is allowed on an object.
- Ball squashes to 10x6 on contact and stretches to 6x10 leaving. Never rotates.
- Strips in `anim_*.png` repeat held frames so the demo loops. In-engine, use hold times.
- Loops (pulse, march, scroll, chase) are 4 to 8 frames at 8 fps and must tile seamlessly from last frame to first.
- Icons pulse by color only: yellow, warm white, pure white, warm white. The icon shape never moves.

## Rotation

No runtime rotation of pixel art. Bumpers snap to pre-drawn angles or stay as drawn shapes in `_draw`. The two rotated bumpers in `assets/pixel/preview/look.png` show why.

## Don'ts

- No anti-aliasing, gradients, or colors outside `docs/palette.md`.
- No black outlines, no drop shadows.
- No dithering on object faces. Backdrop glow may dither, in violet's deep end only.
- No sizes that are not whole pixels at 1x canvas scale.
