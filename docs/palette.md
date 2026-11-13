# Palette

Theme: a modern take on arcade and Atari (see "Art & audio" in `design.md`). Flat, lit colours on a near-black base, with bloom on top.

Source: [Endesga 64](https://lospec.com/palette-list/endesga-64) by ENDESGA. The game uses a subset of it: about 11 lit colours, with neutrals and dim shades for everything else. Every value below is provisional.

## Rules

- **Base:** the background is `0e071b`, a near-black and never pure black, so glow has something to brighten.
- **One hue per meaning.** A hue never appears outside its meaning. Effects (sparks, particles, pop-ups) take the hue of whatever made them.
- **White belongs to the ball.** Nothing else in the arena is white except the ball's own trail, so the ball is always the brightest, clearest object on screen. UI text uses `c7cfdd`.
- **Unlit things are slate:** walls, panels, the paddle body and locked upgrade nodes. They stay dim so lit things stand out.
- **Text contrast:** text needs about 7:1 contrast against the base. Danger red is around 5:1, so use it for bars, flashes and outlines, never for numbers.
- **Flashes are a render effect.** A hit flash comes from bloom and brightness, not from an extra palette colour.
- **Check with CRT on and off.** The CRT filter shifts colours slightly. These values are defined before the filter, so check that they stay readable either way.
- **Adding a colour:** take it from Endesga 64 and give it a meaning in this file.

## Neutrals

| Use | Colour |
|---|---|
| Background | `0e071b` |
| Backdrop grid, panel fill | `1a1932` |
| Walls, disabled buttons, setup grid lines | `2a2f4e` |
| Panel borders, locked nodes, unlit connections, empty rank pips | `424c6e` |
| Paddle body | `657392` |
| Secondary text | `92a1b9` |
| Primary text | `c7cfdd` |

## Meanings

| Meaning | Lit | Dim | Used for |
|---|---|---|---|
| Ball | `ffffff` | | The ball and nothing else |
| Player (cyan) | `0cf1ff` | `134c4c` | Paddle stripe, cursor, selection, buttons, Arena upgrade nodes |
| Placeables (blue) | `0098dc` | `00396d` | Bumpers, wall segments, splitters, placeable bricks, brick mods, the placement tray, Placeables upgrade nodes |
| Coins (gold) | `ffc825` | `8a4836` | Coin counter, coin pop-ups, combo counter, coin ×2 bricks, prices |
| Time (green) | `99e65f` | `1e6f50` | Timer, hourglass bricks |
| Explosive (orange) | `ff5000` | `c64524` | Explosive bricks and their blasts |
| Danger (red) | `ff0040` | `891e2b` | Low-timer warning, the flash when the ball is lost, "can't afford". Not for numbers |
| Bricks (magenta glass) | see below | `622461` | Plain bricks, Bricks upgrade nodes |

"Dim" is for inactive states, such as a locked node in that category or an empty slot.

## Brick HP

A brick glows brighter the more HP it has, and drops a step each time it's hit, so its colour always shows the hits it has left. HP 4 and up share the top step; if a level needs more steps than that, show a number on the brick.

| HP | Colour |
|---|---|
| 1 | `ca52c9` |
| 2 | `db3ffd` |
| 3 | `f389f5` |
| 4+ | `fdd2ed` |

## Full Endesga 64 (reference)

```
ff0040 131313 1b1b1b 272727 3d3d3d 5d5d5d 858585 b4b4b4
ffffff c7cfdd 92a1b9 657392 424c6e 2a2f4e 1a1932 0e071b
1c121c 391f21 5d2c28 8a4836 bf6f4a e69c69 f6ca9f f9e6cf
edab50 e07438 c64524 8e251d ff5000 ed7614 ffa214 ffc825
ffeb57 d3fc7e 99e65f 5ac54f 33984b 1e6f50 134c4c 0c2e44
00396d 0069aa 0098dc 00cdf9 0cf1ff 94fdff fdd2ed f389f5
db3ffd 7a09fa 3003d9 0c0293 03193f 3b1443 622461 93388f
ca52c9 c85086 f68187 f5555d ea323c c42430 891e2b 571c27
```
