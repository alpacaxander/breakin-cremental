# BreakIn cremental

**Logline:** Peglin, but breakout. A run-based roguelike where every fight is a breakout board: the bricks you break are the damage you deal, the balls you collect are your deck, and the paddle is the skill that keeps a turn alive.

*Status: WIP. Redirected on 2026-11-09 from an incremental (currency, upgrade web, between-round brick placement) to a Peglin-style roguelike. The code still implements the old loop; see Migration below. Every decision below is provisional. The name is a leftover and will change.*

## Unique selling point

Peglin's loop (shoot an orb into a peg board, damage is the pegs you hit, collect orbs and relics across a branching map, die and start over) with breakout physics instead of pachinko. In Peglin a shot is a roll of the dice once it leaves the launcher and a phase is one orb; here a phase has no clock and can in principle last forever, because the paddle keeps the ball alive. What ends it is the player: crit bricks launch the next ball in the bag, so a good rally keeps adding balls until there are more than two hands can juggle. Paddle skill is the floor, the ball bag and relics are the engine, generated boards are the variance.

## Peglin parts and their breakout counterparts

| Peglin | Here |
|---|---|
| Orbs, bought and found, levelled up to three ranks | Balls, same |
| Relics (passive rules) | Relics, same |
| Crit pegs (damage multiplier for the shot) | Crit brick: launches the next ball in the bag |
| Refresh pegs (restore every hit peg) | Refresh brick, same |
| Bomb pegs | Bomb brick, same |
| Slime-coated and special pegs (poison, etc.) | Brick coatings from enemies and relics, later |
| Buckets at the bottom (bounce back, reload, pit) | The paddle |
| Discard an orb | Discard a ball before launch |
| Stone orbs (junk added by enemies and events) | Junk balls, same |
| Status effects on orbs and enemies (poison, blind, spin, etc.) | Ball traits and enemy debuffs |
| Enemy intents shown above their heads | Same |
| Map nodes: fight, elite, treasure, peddler, mystery event, boss | Same |
| Gold and HP | Same |
| Classes (Peglin, Roundrel, Spinventor, Balladin) | Starting paddles |
| Cruciball (ascension difficulty) | Out of scope for v1 |

## Core fantasy

Feel like a juggler who is also an engineer: a desperate save at the paddle keeps a four-ball rally alive and deletes the enemy, and the right ball-and-relic combination makes that happen more and more often. Early you survive on reflexes; late the board explodes on its own.

## Core loop

1. Pick a node on a branching map: fight, elite, treasure, shop, event, boss.
2. In a fight, take turns. On your turn the next ball in your bag launches onto the board. Every brick a ball breaks deals that ball's damage to the enemy. Crit bricks launch the next ball in the bag, so several balls can be in play at once, each dealing its own damage. The turn ends when every ball in play has dropped past the paddle.
3. Enemies act: damage to your HP, debuffs, changes to the board.
4. Win the fight and pick one of three rewards: a new ball, a rank-up for a ball you own, a relic, or gold.
5. Run ends on death or on the final boss. Meta-unlocks (new balls, relics, starting paddles) carry over; nothing else does.

## Key mechanics

- **Bricks are pegs.** Each fight generates a board. Basic bricks deal the ball's per-brick damage. Crit bricks launch the next ball in the bag, so a rally that keeps finding crits keeps adding balls. Refresh bricks respawn every broken brick. Bomb bricks break their neighbours and deal direct damage. Unbreakable bricks shape the bounces. Most of these exist in `tuning.gd` already; `hourglass` and the payout kinds need new meanings or get cut.
- **Phase end.** A phase has no timer. It ends when every ball in play has dropped past the paddle, with no HP cost: like a wasted shot in Peglin, the penalty is the damage you did not deal. The natural limiter is the player's own success: each crit adds a ball to juggle, and an empty board stops the damage until a refresh brick appears. If play shows phases that never end, the fallback is a speed ramp on balls that stay alive too long.
- **Damage.** In Peglin damage is stored as the orb hits pegs and fired when the orb leaves the board. Here each ball stores damage as it breaks bricks and fires it when it hits the paddle. The paddle hit is the shot: a ball shows its stored total as it flies, lands it on contact, and starts again from zero. A ball that drops past the paddle loses whatever it was carrying. Balls target the front enemy by default; some hit every enemy.
- **Enemy damage.** Peglin's enemies act once per shot. Here they act on the board: hazards that hurt you when they touch the paddle or cross the paddle line. See Enemy attacks below. What times them is still open.
- **Ball bag (the deck).** Start with four or five basic balls. A ball has per-brick damage and one trait: heavy (bigger, slower, more damage), split (becomes two on the first bounce), piercing (passes through bricks), sticky (first paddle catch holds it for an aimed relaunch), poison (damage over the next turns), and so on. Balls launch in bag order, both at the start of a phase and from crit bricks; a discard action skips one before launch. When the bag runs out mid-phase, crit bricks do nothing more. Three ranks per ball. Some enemies and events add junk stone balls.
- **Paddle.** One paddle. Size, speed and extras come from relics, not an upgrade tree. Vertical movement and sibling paddles from the old upgrade ideas become relics or starting paddles.
- **Relics.** Passive rules picked up at treasures, elites and shops: wider paddle, crit bricks launch two balls, the first brick each phase counts as a crit, a dropped ball returns to the bag, bricks drop gold, every tenth brick is a bomb. The old upgrade ideas (sibling paddles, vertical paddle movement, splitter, flipper, toll and ghost bricks) are relic candidates; their faces already exist in `docs/sprite-spec.md`.
- **Enemies.** HP, an attack value and a countdown of turns. Some touch the board: add unbreakable bricks, remove refresh bricks, shrink the paddle, speed the ball. Elites and bosses have a gimmick each.
- **Map.** Slay the Spire style branching, three acts, a boss at the end of each.
- **Gold.** One currency, spent at shops on balls, relics, ball removal and healing.
- **HP.** One pool. Zero ends the run.

## Enemy attacks

Enemies hurt you through things on the board, not through a number that lands at the end of a turn. One rule ties them together: anything hostile that touches the paddle or crosses the paddle line costs HP. The paddle lane is then shared by balls you want to catch and hazards you want to miss, which is the fight's core tension. What times the attacks (seconds, paddle hits, bricks broken) is still open; each enemy has an intent that says which hazard is coming.

Hazard pool, roughly by build cost:

- **Red bricks.** Breaking one deals damage to you. The ball does not care, so steering it around them is the skill. Variant: a fuse brick counts down and blows up on its own unless you break it first, so one kind must be hit and the other avoided.
- **Enemy balls.** The enemy lobs balls down the board. They look like yours but carry the enemy's damage: catching one on the paddle takes the hit, letting it drop is free. Variants: homing, spread of three, slow heavy ones that must be dodged early.
- **Advancing bricks.** Rows march toward the paddle, Space Invaders style. A row reaching the paddle line deals damage per brick and vanishes. Breaking bricks slows the front; refresh bricks add rows at the top.
- **Drifting invaders.** Arkanoid-style critters wander the board, deflect balls unpredictably and sink toward the paddle. A ball kills them for bonus damage; one touching the paddle costs HP.
- **Laser sweep.** A telegraphed beam across a lane or column fires after a beat. A paddle or ball in the beam takes it; a ball hit by the beam is pushed or loses its stored damage.
- **Debris.** The enemy slams the board and shakes loose bricks that fall straight down. Dodge them; they are not worth catching.
- **Floor goo.** A hazard zone grows along the paddle line from one side, shrinking the safe lane. The paddle standing in goo takes damage per second. Breaking bricks of a certain kind, or a timer, clears it.
- **Cursed ball.** The enemy swaps the next ball in your bag for one that stores damage against you instead of the enemy. Catch it once and it hurts; the counter is to let it drop, which costs you a turn of the bag.
- **Parasite bricks.** A brick turns hostile and spreads to a neighbour every few seconds. Hostile bricks heal the enemy when broken, or hurt you. Break the source fast or the board turns against you.
- **Shield rows.** The enemy raises a layer of unbreakable or high-HP bricks in front of itself. Damage still lands, but the ball spends more time behind the shield and less near the paddle.
- **Thieves.** Small enemies run onto the board and grab a ball mid-flight or steal gold, then leave by the top. Hitting one with a ball drops the loot.
- **Paddle debuffs delivered as objects.** Ice slicks the paddle lane (slide), a weight shrinks it, a mirror reverses controls for a few seconds. Each is a thing to dodge, not a status applied from nowhere.
- **Boss as the board.** The boss is the top wall. It slams down a row at a time, opens a mouth that eats balls, or tilts the arena so gravity bends every ball.

## Progression

- Within a run: balls, ball ranks, relics, gold. No permanent stats.
- Across runs: unlocks that widen the ball and relic pools, plus a few starting paddles (archetypes). Nothing that makes the next run numerically easier.
- Enemies scale per act; the pool of boards and brick kinds widens per act.

## Win / lose

Win by beating the act three boss. Lose when HP hits zero. Both end the run; a run should take 30-45 minutes.

## Controls

- In a fight: arrows / WASD or mouse move the paddle; click or space launches and relaunches a sticky catch.
- Between fights: click on map nodes, rewards and shop items.

## Target audience & platform

Steam roguelike players who like Peglin, Slay the Spire and Balatro: short runs, build variety, visible numbers. Tone: an arcade cabinet that has wandered into a dungeon. The pixel art pipeline and cabinet layout stay.

## MVP

- One act: six fights and a boss on a linear path, no branching.
- One enemy kind plus a boss, with HP and a flat attack.
- A bag of five basic balls plus two trait balls (heavy, piercing).
- Bricks: basic, crit, refresh, unbreakable.
- Reward after each fight: pick one of three balls. No relics, shop, gold or events.
- Crit bricks launch the next ball; the phase ends when every ball has dropped.

Deliberately out: map branching, relics, events, meta-unlocks, multiple enemies, starting paddles, the speed-ramp fallback. The MVP exists to answer two questions: is a multi-ball breakout rally more fun than a pachinko shot, and do phases end on their own at a length that feels right?

## Migration from the incremental build

- **Survives:** `arena.gd` ball and paddle physics, `brick.gd`, `generate()` boards, `fx.gd`, `sfx.gd`, the `ui.gd` cabinet, the `tuning.gd` tables as the home for numbers.
- **Repurposed:** the combo window and multiplier are cut from the base rules and may return as a relic (damage ramps while bricks keep breaking). The HUD score column becomes enemy HP, damage this phase, balls in play and the bag.
- **Cut:** currency, the upgrade web and level select in `shop.gd`, placement mode in `place.gd`, the round timer, level unlock rules. Placement may return as a relic (place one brick before each fight).
- **New:** map screen, fight screen with enemies, bag and relic state in `game.gd`, reward picks, shop.

## Risks

1. **Phase length.** A Peglin shot is finite by physics; a breakout phase is as long as the player can hold it. Too short and there is no agency; unbounded and there is no threat. The bet is that crit bricks adding balls ends phases by overload, with crit density and bag size as the levers. If a skilled player with a small bag can rally forever, the speed ramp comes in.
2. **Damage legibility.** Peglin shows damage ticking up per peg; bricks break fast and many at once. The running counter on the enemy has to read at a glance.
3. **Enemy turns in an arcade game.** Waiting while an enemy swings kills flow. Enemy turns stay around a second, with the board visible throughout.
4. **Generated boards.** Peglin boards are hand-laid. Generated boards must give every ball a fair rally and never trap the ball.
5. **Paddle feel.** Still the base of everything; a bad drop still feels unfair.
6. **Rewrite cost.** Shop and placement are about a third of the code, and `game.gd` is built around ranks and currency. Rebuilding it is the first job.
