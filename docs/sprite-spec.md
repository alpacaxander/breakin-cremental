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
| place_splitter, place_ramp, place_toll | 30x12 | center | mint | lit | 1 each | ideas.md placeables: fork icon, curved arrow, "$" | done, unused |
| place_flipper | 24x8 | left pivot (0,4) | mint, chrome cap | lit | 1 | tapers toward the tip; flipper_flick rotates it | done, unused |
| place_wedge | 12x12 | center | chrome | unlit | 1 | bottom-left right triangle, hypotenuse is the bounce face | done, unused |
| paddle_mini | 24x6 | center | chrome, yellow strip | 1 | mini paddle for the ideas.md upgrade | done, unused |
| brick_ghost, brick_mirror, brick_regrow, brick_key, brick_lock | 30x12 | center | sky | lit (lock dim) | 1 each | ideas.md level blocks; key icon in payout yellow | done, unused |
| brick_gold | 30x12 | center | gold | lit | 1 | five white pips, gold_crack takes them away | done, unused |
| brick_tele | 30x12 | center | violet | lit | 1 | ring icon, pairs with place_tele's hue | done, unused |

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

## Cabinet UI

Every screen is a 640x360 sprite-space Control shown at 2x (`src/ui.gd`): score/stats column 0-77, rail, field 80-559, rail, pieces/menu column 562-639. Reference renders: `assets/pixel/preview/ui_*.png` and `assets/pixel/preview/ui.html`.

| Sprite | Size | Use |
|---|---|---|
| font_3x5.png + .fnt | 192x6 | BMFont, size 5, advance 4, line 6. Capitals, digits, `$ + , - . / : ! ' ?` and a small `x`; lowercase maps onto the capitals. Scaled 2x/3x/4x for cash, time and combo. |
| ui_panel | 24x24 | Column and dialog panel, nine-patch with 3px corners |
| ui_rail | 2x8 | Tiled rail beside each column, flipped on the right |
| ui_button_chrome, _hot | 24x16 | Chrome button (theme `Button`), nine-patch 3px |
| ui_button_mint, _hot, _dim | 24x16 | Lamp button (theme variation `Mint`): normal, hover/pressed, disabled |
| ui_slot, ui_slot_hover | 36x18 | Piece slot in the tray; piece face centred, ui_badge (9x7) with the count at (30,-3) |
| ui_pip_on/off/pay | 4x4 | Capacity and rank pips at 5px pitch |
| coin | 8x8 | Beside CASH and costs |
| node_dim/lit/max | 30x12 | Upgrade web lamp by rank; icon_<upgrade> (12x5) overlaid at (9,3), rank pips drawn at row 8. One icon per `UICONS` key in gen.mjs, including every node proposed in docs/ideas.md (paddle, ability `ab_*`, placement, block unlock and block upgrade ids) |
| ui_toggle_on/off, ui_slider_track, ui_slider_knob | 16x8, 1x4, 6x8 | CheckButton icons and HSlider styles in theme.tres |
| ui_cursor | 8x8 | Mouse cursor, scaled 2x at runtime |
| title_logo | 177x63 | Menu logo (gen.mjs `LOGOS.split_mag_pay`) |

## Field overlays (drawn in-engine, no sprite)

Placement line (dashed mint), peg-board dots, combo bar, bottom lamp row (anim_hazard_strip). See `MOCK.play` in the generator for the reference rendering.
