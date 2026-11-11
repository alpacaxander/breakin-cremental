# Encounters and organs

Proposal, 2026-11-10. Nothing here is in `tuning.gd` yet; the game still plays one enemy per fight with damage cashed in at the paddle. When a row lands, `docs/content.md` wins over this file. This replaces the enemy model for every map, including the map proposals: their enemies become encounters (see Converting enemies).

## The model

Three jobs, three owners:

- **Bricks charge the ball.** A ball breaking a brick adds `ball.dmg * brick.dmg` to `ball.stored`, as now.
- **Organs cash the charge in.** A ball touching an organ deals its stored damage to that organ and `stored` resets to 0. This is the only way damage reaches an enemy.
- **The paddle keeps the ball alive.** A paddle hit no longer deals damage. A drop still loses whatever the ball carried.

Refresh still matters: regrown bricks are more fuel to charge on before going for the organs.

## Vocabulary

- **Encounter**: the top-level entity of a fight. Authored, never generated. It decides the board, which organs exist, where, when and how they appear, and the end condition.
- **Organ**: one enemy. One HP bar, its own countdown (`cd`) and intent cycle, any size and shape on the board. An organ lives in the board, not above it. A thematic foe can be several organs: a knight is three, a body, a sword and a shield, each with its own HP bar and attacks.
- **Enemy band**: decoration only. It shows the encounter as a picture of what is happening on the board (the sword raised when the sword organ winds up, the shield cracked when the shield organ is hurt). No game rule reads it, and nothing in it links to an organ by colour or lane: organs are authored to look like what they are.

## Rules

| topic | rule |
|---|---|
| Organ hit | A player ball touching any cell of an organ: `organ.hp -= stored`, `stored = 0`, the ball bounces. Plays `damage_fire` on the organ, the organ's `_hit` strip and the `damage_land` ladder (moved from the paddle). |
| Zero charge | A ball with 0 stored touching an organ is a plain bounce with `hit_refused`. Charging is the only way to deal damage. |
| One hit per contact | A ball touching two cells of one organ in the same frame is one hit. |
| Organ shape | An organ is a set of board cells drawn with one glyph. Each cell is a `Box` pointing at one shared organ, so any shape works and `generate` places it like any drawn brick. Organs are never broken by hits, never removed by blasts and never regrown by refresh. |
| Organ countdown | Each organ has its own `cd` and intent cycle, counted while a ball is in flight, as now. The intent icon and countdown sit on the organ; the band mirrors them. |
| Organ effects | Anything on a timer: fire enemy balls, paint red bricks, raise a shield row, grow more bricks, spawn organs. A hazard spawns from the organ that fires it, so hazards start closer to the paddle than they did from the band: retune `enemy_balls` speed and wind-up, and `cd`. |
| Organ death | At 0 HP the organ plays its `_die` strip and its cells go. Its countdown stops; hazards already in flight keep flying. |
| End condition | Default: every organ dead. An encounter can name the organs that end it (`win`), so the knight dies with its body and the sword and shield are optional. A fight still ends in a loss at 0 HP. |
| Encounter script | An encounter can react to events: an organ below an HP mark, an organ dead, a phase number. Reactions: spawn organs, swap the board, change an organ's fields. Deep Net's `fork_bomb` split and `trojan` reveal are scripts, not enemy signatures. |
| Multiple foes | Nothing special: an encounter with several organs is several enemies. Their countdowns should start staggered (the encounter authors `cd_start` per organ) so they do not fire on one frame. |

## Bombs

| step | rule |
|---|---|
| First hit | Arms the bomb: it switches to its armed face (`icon_bomb_pulse` lit) and stays on the board. |
| Second hit | Detonates it. The blast hits every brick in `BRICKS.bomb.blast` radius once, and the charge of every brick it breaks goes to the ball that detonated it. |
| Blast hits | One hit per brick: a multi-hit brick loses one, an unarmed bomb in range arms, an armed bomb detonates (chains you set up). Crit and refresh fire from a blast break through `_trigger`, as now. |
| Organs | The blast never touches organs. Only a ball cashes in. |
| BLASTER ball | Its every-nth-break blast is the same blast, charging the ball that carries it. |

`tenth_bomb` is unchanged (it places bombs; they follow the new rules).

## What else changes

| thing | ruling |
|---|---|
| `stored_tag`, drop loses charge | Unchanged. |
| HP bar | A small bar on each organ, plus the organ's portrait in the band. The HUD's damage line counts damage landed this phase on any organ. |
| Poison | Stacks on the organ it hits; ticks at phase end on that organ. |
| `riposte`, `twice`, `mimic`, `enraged` | Organ fields. |
| `steal`, `jackpot`, `advance`, `shield_start` | Encounter fields. |
| The maw's mouth | A mouth organ: it swallows balls that touch it and spits them back as enemy balls (the old band zone goes). |
| `shield_row` | Stays a hazard. Growing bricks around an organ is a separate organ effect. |
| Crit, refresh, red, solid, gold | Unchanged. |
| `sticky` (GUM) | The aiming tool: a charged ball held on the paddle keeps its charge and is relaunched at an organ. |
| `ball_magnet` | Flips: a charged ball is drawn to the nearest organ. `magnet_paddle` (relic) keeps pulling to the paddle, as survival. |
| `shield_floor`, `recall`, `ball_rubber`, `mini_paddle` | Unchanged; worth more now, since they protect charge. |
| `stats.killer` | The organ id. |
| Catalog | The enemies page lists encounters, each with its organs. `meta.seen` keys by encounter. |
| Map | `map.enemies` holds encounter ids; `pick_enemy` becomes `pick_encounter` (role, tier as now). `run.json` version bumps; an older save is dropped. |
| Phase end, clock | Unchanged: a phase ends when every ball has dropped; organ countdowns run while a ball is in flight. |

Deferred: refresh regrowing the bricks that bury organs could stall a fight. If play shows it, exclude organ-adjacent cells from refresh.

## Data shape (proposed)

Organs get their own table so the catalog and `stats.killer` key by organ; encounters reference them. Organ glyphs on the board are digits, `1`-`9`, indexing the encounter's `organs` list, so they never collide with `BOARD_KEYS`.

```gdscript
const ORGANS := {
	knight_body = {hp = 60, cd = 14.0, intents = [["debris", 4]], off = -3, w = 48},
	knight_sword = {hp = 25, cd = 8.0, intents = [["laser_sweep", 1], ["enemy_balls", 2]], off = 0, w = 32},
	knight_shield = {hp = 30, cd = 12.0, intents = [["grow", 6]], off = -5, w = 32},  # grow: n plains around this organ
}
const ENCOUNTERS := {
	knight = {role = "regular", tier = 2, organs = ["knight_body", "knight_sword", "knight_shield"], cd_start = [14.0, 4.0, 9.0],
		win = ["knight_body"], board = {rows = [
		"xx?xxxxx?xx",
		"x33?x1x?2?x",  # 1 body, 2 sword, 3 shield
		"x33?111?2?x",
		"x33?111?2?x",
		"x?x?x1x?2xx",
		"xx?xxxxx?xx",
	]}},
}
```

Encounter fields: `role`, `tier`, `organs`, `board`, optional `cd_start`, `win`, `script`, and the encounter-level signatures (`steal`, `jackpot`, `advance`, `shield_start`). Organ fields: `hp`, `cd`, `intents`, `off`, `w`, optional organ-level signatures. Numbers above are placeholders.

## Converting enemies

Every current `ENEMIES` row becomes a one-organ encounter that keeps its HP, `cd`, intents and board; the author draws the organ into the board's thematic centre (the glob's goo core, the coin slug's gut, the mason's vault). Elites and bosses are the first to split into several organs. The map proposals convert the same way: `fork_bomb` and `trojan` become encounter scripts.

## Art and sound

- Each organ needs its own look: a face per hue for its cells plus one overlay sprite sized to its footprint (the sword, the shield), in a new `assets/pixel/parts/organs.mjs`. Strips `<organ>_hit` and `<organ>_die` on the board; the band keeps an encounter portrait with idle and attack strips. Rows go into `docs/animations.md` and `test.gd` as usual.
- The armed bomb needs an armed face; the blast reuses `ora_break` and `bomb_boom`.
- No new cues are required: organ hits reuse the `damage_land` ladder, zero-charge hits `hit_refused`.

## First slice

Prove that hitting organs on purpose feels good before converting everything:

1. One authored encounter, the knight: three organs, `win` on the body.
2. Paddle cash-in removed, organ cash-in with the reset.
3. The new bombs.
4. Placeholder organ art (tinted solid faces) is enough.

If aiming at organs feels like luck, the levers are organ size, open lanes in the authored board, and `sticky` / `ball_magnet` in the starting pools.
