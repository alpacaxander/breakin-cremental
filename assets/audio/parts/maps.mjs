// Map cues for the three proposed maps (docs/content/maps/: back-alley-arcade, corp-tower, deep-net). A CUES fragment for
// assets/audio/gen.mjs, spread into the CUES literal there as `...maps({ tone, noise, layer, notes, bell, click })`.
// Six new wavs (paddle_jam, pull_lift, blackout, lock_shut, virus_infect, glitch_tear); none loops (no edit/loop_mode=1 sidecar).
// Everything else reuses a cue at a rate or st (semitones), as in parts/demo.mjs. Game-side `Sfx.play(name, pitch, delay)`.
//
// Enemy offsets `off` (st, added to enemy_hit / enemy_act / enemy_enter; bigger and meaner = lower). Existing: glob 0, lobber -2, mason -4, warden -5, maw -7.
//   Arcade: rat_king +3, coin_slug -1, fuse_box +1, claw_rig -3, ticket_printer +2, bootleg_cabinet -2,
//           repo_man -6, arcade_bouncer -5, jackpot_reel -3, attract_mode -8
//   Tower:  sentry_drone +4, turnstile -3, camera_cluster +2, server_rack -4, intern_swarm +5, auditor -1, elevator -6,
//           ice_wall -6, head_of_security -5, legal -3, twin_sentries left +2 / right -2, mainframe -9, ceo -10
//   Deep:   worm +1, glitch +3, mirror_daemon 0, null -4, packet_storm +6, rootkit -5, ghost_process +2, checksum +4,
//           hive_mind -6, fork_bomb -5 (each half -3), recursion -4, trojan 0 disguised (glob's) then -6, compiler -9, admin -11
//
// Hazards (fire = when the intent's cd hits 0, after enemy_act):
//   jam fire / refire -> paddle_jam, 0          | jam wears off -> grow, 0
//   pull fire -> pull_lift, 0 (1.0 s, = secs)   | pull ends -> none (the balls falling again says it)
//   coin_junk -> coin rate 0.7, then teleport_out rate 0.5 at delay 0.1 per junk (st(+2) each further count)
//   wall_col raise -> armor_pop rate 0.6, then solid_bounce rate 0.7 at delay 0.05 | wall_col bounce -> solid_bounce, 0
//   wall_col crumble -> solid_bounce rate 0.8, then blast rate 0.8 at delay 0.03
//   blackout fire -> blackout, 0                | lights back at next phase -> tube_flicker, 0
//   lockdown fire -> lock_shut, 0               | locked brick refuses -> hit_refused rate 0.8 | release at next phase -> lock_open rate 0.8
//   virus seed -> virus_infect, 0 (-2 st per further count) | spread on paddle hit -> virus_infect rate 1.15 gain 0.6 (one per hit, not per brick)
//   virus brick refuses -> hit_refused rate 1.2 | cluster clear -> chain_zap rate 0.8, then brick_break at +1 st per brick, 0.03 apart
//   scramble -> glitch_tear, 0                  | mirror fire / refire -> mirror_ping rate 0.7, then teleport_in rate 1.2 at delay 0.05
//   mirror wears off -> mirror_ping, 0          | ghost fade out -> ghost_phase rate 0.8 | ghost back at phase start -> ghost_phase, 0
//   ball passes a ghost brick -> pierce_swish rate 1.3 gain 0.5
//
// Ball traits:
//   token payout -> toll_ding, 0, then coin at delay 0.05     | rubber floor bounce -> sticky_fire rate 0.8, +2 st per bounce used
//   magnet (pull first bends it, once per flight) -> recall rate 1.3 gain 0.5
//   laser column -> bolt_sweep rate 1.2, then brick_hit per brick 0.02 apart (+1 st each)
//   badge pass -> gate_pass, +2 st per pass used | drone hover start -> ability_on rate 0.8 | drone drop -> ability_off rate 0.8
//   virus infect (player) -> virus_infect rate 1.3 | virus_player break -> brick_break, then x2_sting rate 1.2 gain 0.6
//   ghost phase through a brick -> ghost_phase rate 1.4 gain 0.5, +1 st per brick phased | solidify -> solid_bounce rate 1.4, then x2_sting at delay 0.04
//   fork drop -> teleport_in rate 1.3 | fork re-entry from the top -> teleport_out rate 1.3 at delay 0.15
//
// Enemy signatures and mid-fight swaps:
//   repo_man steal -> coin rate 0.6 per drop    | legal drop cost -> hp_lose, ladder 0 | arcade_bouncer double -> the hazard cue again at delay 0.12, +2 st
//   jackpot_reel gold break -> gold_hit (ladder) | all three in one phase -> jackpot, 0 | phase ends short -> combo_drop, 0
//   attract_mode copied ball -> ball_launch rate 0.5, then that ball's trait cue (split_pop, pierce_swish ...) at delay 0.05
//   ticket_printer rows advance -> ui_rotate rate 0.6 x3, 0.05 apart | elevator scroll -> accel_zip rate 0.5, then solid_bounce at delay 0.1
//   ice_wall regrow at phase end -> armor_pop rate 0.7 | head_of_security wide lane -> bolt_sweep rate 0.65 (normal laser 0.8)
//   checksum in order -> seq_step (ladder) | out of order -> hit_refused, then cond_primed rate 0.6 at delay 0.08
//   glitch board redraw at phase end -> glitch_tear rate 1.2, then regrow at delay 0.2
//   hive_mind virus absorbs a hit -> virus_infect rate 0.7 gain 0.6 | recursion repeat -> rewind rate 1.3, then the hazard cue at +2 st
//   admin heals the last brick -> regrow rate 1.2 | admin hidden HP bar: enemy_hit as usual (the sound is the only tell)
//   trojan reveal -> glitch_tear rate 0.8, then fast_whoosh rate 0.6 + bumper_hit rate 0.5 (enemy_enter) at -6, delay 0.3; heal 20 -> regrow rate 0.8 at delay 0.6
//   fork_bomb split -> split_pop rate 0.5, then blast rate 0.8 at delay 0.05, then multiball_pop rate 0.6 at delay 0.15
//   compiler rewrite (75 / 50 / 25 %) -> glitch_tear rate 1 / 0.85 / 0.7, then regrow at the same rate, delay 0.25
//   mainframe core down -> enemy_die rate 0.8 (last core: enemy_die rate 0.6, the boss ladder), then lock_shut rate 0.8 at delay 0.4
//   twin_sentries one side down -> enemy_die rate 0.9
//   ceo shield blocks a non-crit ball -> solid_bounce, 0 | crit ball passes -> gate_pass rate 0.8
//   ceo shield drop -> shield_pop rate 0.5, then blast rate 0.6 at delay 0.05 | cd halves -> speedup rate 0.6 at delay 0.4
//
// Shop:
//   buy back -> ui_buy, then teleport_out rate 0.8 at delay 0.1 (remove's teleport_in, reversed)
//   rising price (Company Store) -> ui_buy at -n st after the nth buy this visit, then count_tick per label at delay 0.2
//   Company Store free heal -> grow, 0 (no coin)
//   hidden price (Darknet) buy -> mystery_reel rate 1.6, then ui_buy at delay 0.3
//   fake junk reveal -> glitch_tear, then ui_cant_afford rate 0.8 at delay 0.25 | rank up slot -> ui_buy, then ui_unlock at delay 0.1
//
// Events (open/choice/good/bad as demo.mjs):
//   vending SHAKE IT coin flip -> coin rate 1.4, then mystery_reel rate 1.2 at delay 0.1; heads -> ui_unlock, tails -> ui_cant_afford rate 0.8 (then jam's pending note: paddle_jam at fight start)
//   pending_hazard at fight start (badge check, vending, honeypot) -> round_go, then that hazard's fire cue at delay 0.4
//   corrupted save -> per ball, 0.08 apart: rank up combo_up, rank down boost_end | coin return -> coin, then teleport_out rate 0.5 at delay 0.1
//   mirror terminal LOOK -> split_pop, 0; SMASH -> hp_lose ladder 0, then teleport_in rate 0.8 if a junk leaves | fried cabinet PULL -> tube_flicker, then grow
//   fried cabinet PLAY -> hp_lose ladder 1, then cond_primed (relic pickup) | badge check JUMP IT -> gate_pass, then lock_shut rate 0.8 at delay 0.1
//   server closet COPY -> ui_buy; WIPE -> teleport_in rate 0.8 | honeypot TAKE -> cond_primed, then virus_infect rate 0.8 at delay 0.3
export const maps = ({ tone, noise, layer, notes, bell, click }) => {
	// n square blips at random pitch and time; Math.random is seeded per cue name in gen.mjs, so the tear is stable across regens
	const blips = (n, span, lo, hi) => [...Array(n)].map(() => [tone({ f: lo + Math.random() * (hi - lo), dur: 0.015 + Math.random() * 0.025, duty: 0.25, a: 0 }), Math.random() * span, 0.4 + Math.random() * 0.6]);
	return {
		// --- Arcade ---
		paddle_jam: { g: "Maps", d: "jam: the paddle ratchets down to half width", gen: () => layer(...[1200, 1000, 800, 600].map((f, i) => [click(f, 0.015), i * 0.035, 0.7]), [tone({ f: 400, f1: 150, dur: 0.2, duty: 0.25 }), 0.02, 0.7], [noise({ dur: 0.1, lp: 1500, lp1: 400 }), 0.1, 0.6]) },
		pull_lift: { g: "Maps", d: "pull: every ball drifts upward for 1 s", gen: () => layer([tone({ f: 220, f1: 660, dur: 1.0, wave: "sin", a: 0.05, k: 3, trem: 0.5, tremf: 6 })], [noise({ dur: 1.0, lp: 400, lp1: 3000, hp: 200, a: 0.15, k: 3 }), 0, 0.4]), gain: 0.8 },
		// --- Tower ---
		blackout: { g: "Maps", d: "blackout: relay clunk, the lights power down", gen: () => layer([click(300, 0.02)], [tone({ f: 440, f1: 55, dur: 0.5, wave: "saw", lp: 2500, k: 5 }), 0.01, 0.8], [tone({ f: 120, f1: 40, dur: 0.3, wave: "sin" }), 0, 0.8]) },
		lock_shut: { g: "Maps", d: "lockdown: three bolts slam home", gen: () => layer(...[0, 0.09, 0.18].map((t, i) => [layer([tone({ f: 260 - i * 40, f1: 120, dur: 0.06, duty: 0.3 })], [tone({ f: 150, f1: 60, dur: 0.08, wave: "sin" }), 0, 1], [noise({ dur: 0.04, lp: 900 }), 0, 0.5]), t, 0.6 + i * 0.2])) },
		// --- Deep Net ---
		virus_infect: { g: "Maps", d: "virus: a plain turns green; wet glitchy blip", gen: () => layer([tone({ f: 300, f1: 900, dur: 0.12, duty: 0.25, vib: 0.15, vibf: 45 })], [tone({ f: 600, f1: 1200, dur: 0.08, duty: 0.25, vib: 0.15, vibf: 45 }), 0.06, 0.6]), gain: 0.7 },
		glitch_tear: { g: "Maps", d: "scramble / glitch / reveal: torn random blips", gen: () => layer(...blips(12, 0.3, 200, 3000), [noise({ dur: 0.05, lp: 9000, hp: 3000 }), 0, 0.5], [noise({ dur: 0.05, lp: 9000, hp: 3000 }), 0.17, 0.4]) },
	};
};
