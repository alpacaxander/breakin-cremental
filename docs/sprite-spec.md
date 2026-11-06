# Sprite spec

One row per asset in `assets/pixel/png/`. Sizes are native 1x canvas pixels (2x on screen). Anchor is where the game positions it. Hue sets and states are defined in `docs/art-style.md`. Regenerate with `node assets/pixel/gen.mjs`.

## Bricks (30x12, anchor center)

| Name | Set | State | Frames | Notes | Status |
|---|---|---|---|---|---|
| brick_plain_lit | magenta | lit | 1 | the base brick | done |
| brick_plain_dim | magenta | dim | 1 | | done |
| brick_plain_flash | magenta | flash | 1 | shared hit flash for all magenta bricks | done |
| brick_multi_full | magenta | lit | 1 | two yellow pips at bottom | done |
| brick_multi_cracked | magenta | cracked | 1 | one pip dim, crack in warm white | done |
| brick_icon_multiball | magenta | lit | 1 | three white plus-dots | done |
| brick_icon_x2 | magenta | lit | 1 | "x2" in 3x5 font, yellow | done |
| brick_cond_speed_idle | sky | dim | 1 | chevrons in ring color | done |
| brick_cond_speed_primed | sky | lit | 1 | chevrons in warm white | done |
| brick_solid | chrome | unlit | 1 | bevel bands, two rivets | done |
| brick_icon_* (other effects) | magenta | lit | 1 | per icon in design.md | todo |
| brick_plain_* per extra currency | orange, violet | lit, dim, flash | 1 each | when currency 2 and 3 exist | todo |

## Placeables

| Name | Size | Anchor | Set | State | Frames | Notes | Status |
|---|---|---|---|---|---|---|---|
| bumper | 45x7 | center | mint | lit | 1 | chrome caps 4px each end | done |
| bumper_r15, bumper_r30, ... | varies | center | mint | lit | 1 each | pre-drawn angles, replaces runtime rotation | todo |
| place_sticky | 30x6 | center | mint | lit | 1 | sticky pad body; sticky_hold shows it with the ball | done |
| place_magnet | 30x12 | center | mint | lit | 1 | magnet icon; magnet_pull loops around it | done |
| place_tele | 16x16 | center | violet | ring | 1 | empty portal ring; teleport_in/out add the ball | done |
| ghost_valid | 30x12 | center | mint | ghost | 1 | dashed, alpha fill | done |
| ghost_invalid | 30x12 | center | red | ghost | 1 | dashed, X | done |

## Ball and paddle

| Name | Size | Anchor | Set | Frames | Notes | Status |
|---|---|---|---|---|---|---|
| ball | 8x8 | center | yellow edge, warm white body | 1 | white 3px highlight top-left | done |
| paddle | 60x8 | center | chrome, yellow strip row 4 | 1 | width upgrades need a 3-slice or per-width sprites | done |
| paddle_cap_l, paddle_mid, paddle_cap_r | 4x8, 1x8, 4x8 | left | chrome | 1 each | 3-slice for scalable width | todo |

## Effects

| Name | Size | Anchor | Set | Frames | Notes | Status |
|---|---|---|---|---|---|---|
| fx_halo | 60x30 | center | magenta | 1 | checker dither, additive blend | done |
| fx_spark | 5x5 | center | yellow | 1 | | done |
| fx_debris | 4x3 | center | magenta | 1 | | done |
| fx_payout_tag | 17x8 | bottom center | yellow | 1 | "+12" placeholder, number drawn in-engine | done |
| fx_halo per set | 60x30 | center | mint, sky | 1 each | | todo |

## Animations

Strips `anim_*.png`, one row per animation in `docs/animations.md`. All listed there are generated.

## Field overlays (drawn in-engine, no sprite)

Placement line, peg-board dots, rails, combo bar, HUD text. See `board()` in the generator for the reference rendering.
