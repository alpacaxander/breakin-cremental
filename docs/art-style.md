# Art style

Pixel art, pachinko lamp look. Reference implementation: `assets/pixel/gen.mjs`. When this doc and the code disagree, the code wins and this doc gets fixed. Colors: `docs/palette.md`. Inventory: `docs/sprite-spec.md`.

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

| Set | Tube | Ring | Deep | Highlight | Used for |
|---|---|---|---|---|---|
| Magenta | `ff4aff` | `a200a2` | `350035` | `ffcaff` | plain bricks, icon bricks, multi-hit |
| Mint | `15f2b0` | `02936b` | `01563f` | `b7fbe7` | bumpers, placeables, valid ghost |
| Sky | `4fc7ff` | `186fb6` | `0e3556` | `cefaff` | conditional bricks |
| Yellow | `ffff00` | `887809` | `000020` | `ffff73` | payout, combo, ball edge |

Reserved, not yet drawn: orange `ff7500`, violet `7f16ff`. Build their sets from the same palette ramp (top, mid, near-bottom, tint).

## Unlit anatomy

Solids, the paddle, and bumper caps are chrome. Horizontal bands only, top to bottom: `e7e7ff`, `c6c6ff`, `9797d5`, `7777bb`, `5454a7`, `414183`, `21224e`. Use as many bands as the height allows, keep the order. Rivets are single `c6c6ff` pixels. Corners cut.

## States

Shape never changes between states. Only swatches do.

| State | Tube | Ring | Glass | Highlight | Extra |
|---|---|---|---|---|---|
| Lit | set tube | set ring | set deep | on | |
| Dim | set deep-ish dim (`790079` for magenta) | one step darker | base `000020` | off | |
| Flash | `ffffff` | `ffffcf` | `ffffcf` | `ffffff` | 1 frame |
| Cracked | lit | lit | lit | on | 1px crack in `ffffcf`, one lit pip goes dim |
| Ghost | dashed 2 on 2 off in set tube | none | set tube at alpha 50 | off | invalid uses `ff0000` and an X |

## Text

One font: the 3x5 face in `FONT` in the generator. 1px letter spacing. HUD text draws at 2x (6x10). In-sprite text draws at 1x in payout yellow or base navy.

## Effects

- Glow is a shader in-engine. Sprites do not bake glow.
- Halo sprites use checkerboard dither only, three bands, in the object's tube color.
- Sparks are 5x5 plus shapes in yellow with a white center. Debris is a 4x3 chip in the broken brick's tube and deep swatches.

## Animation

- 12 fps for hits and effects, 8 fps for idle loops. Frames are whole-pixel moves, no tweening.
- Every hit starts with one flash frame, then one "hot" frame (tube goes to highlight swatch, glass to ring swatch, highlight to pure white), then the normal state. See `MAG_HOT`.
- Breaks: flash, hot, split into two halves, fade with debris, empty. Fade is alpha on the whole sprite, the only place alpha is allowed on an object.
- Ball squashes to 10x6 on contact and stretches to 6x10 leaving. Never rotates.
- Strips in `anim_*.png` repeat held frames so the demo loops. In-engine, use hold times.

## Rotation

No runtime rotation of pixel art. Bumpers snap to pre-drawn angles or stay as drawn shapes in `_draw`. The two rotated bumpers in `assets/pixel/look.png` show why.

## Don'ts

- No anti-aliasing, gradients, or colors outside `docs/palette.md`.
- No black outlines, no drop shadows.
- No dithering on object faces.
- No sizes that are not whole pixels at 1x canvas scale.
