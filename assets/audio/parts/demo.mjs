// Demo cues for "Peglin but breakout" (docs/content.md, Sound row). A CUES fragment for assets/audio/gen.mjs:
// spread it into the CUES literal there as `...demo({ tone, noise, layer, notes, bell, click })`.
// Five new wavs; none loops (no edit/loop_mode=1 sidecar needed).
//
// Reuse (no new wav): moment -> existing cue, semitones (st) or rate. Enemy offsets `off`: glob 0, lobber -2, mason -4, warden -5, maw -7.
//   fight_start -> round_go, 0            | enemy_enter -> fast_whoosh rate 0.6, then bumper_hit rate 0.5 at delay 0.3
//   ball_launch -> ball_launch, rank-1    | junk launch -> ball_launch rate 0.6; junk break -> brick_break rate 0.6
//   paddle_catch (0 stored) -> paddle_hit, speed ladder (heavy rate 0.7)
//   ball_drop -> ball_lost, 0 if it carried damage, else rate 0.7 at gain 0.5
//   phase_end -> combo_drop rate 0.8      | poison tick -> pips_shrink rate 0.8
//   crit_launch -> multiball_pop, 2*min(n,4) (n balls in play); empty bag -> hit_refused rate 0.8
//   refresh -> regrow, 0                  | bomb -> bomb_boom, 0          | solid -> solid_bounce, 0
//   red_break -> brick_break rate 0.7, then hp_lose (ladder) at delay 0.05
//   enemy_hit -> bumper_hit rate 0.6, +off | enemy_act (cd hits 0) -> hit_refused rate 0.5, +off
//   cd reaches 1 -> timed_off, 0          | hp <= 12 at phase start -> time_low rate 0.5
//   red_bricks paint -> cond_primed rate 0.6, -1 per target | enemy_balls -> ball_launch rate 0.5, wall ball_bounce rate 0.6
//   debris shake -> blast rate 0.6, floor solid_bounce rate 1.3 at gain 0.5
//   laser warn -> ui_reveal rate 0.5, beam bolt_sweep rate 0.8, ball zapped combo_drop rate 1.2
//   shield_row raise -> armor_pop rate 0.7, crumble solid_bounce rate 0.8
//   maw mouth open -> fast_whoosh rate 0.5, eat teleport_in rate 0.6, close blast rate 0.5
//   relic proc -> toll_ding, 0; relic pickup -> cond_primed, 0; relic recall -> recall, 0; shield_floor -> shield_pop, 0
//   relic combo break -> brick_break, min(combo, 12)
//   split -> split_pop, 0 | pierce -> pierce_swish, 0 | sticky -> sticky_catch / sticky_fire, 0
//   gold gain -> coin, 0; gold roll -> count_tick, 0; gold card -> coin_cascade, 0
//   fight won -> round_clear, 0; cards show -> mystery_reel rate 1.3; treasure -> lock_open, 0
//   reward ball / shop buy -> ui_buy, 0; rank-up -> ui_unlock, 0; refused -> ui_cant_afford, 0
//   shop remove -> teleport_in rate 0.8; shop heal -> grow, 0 then coin rate 0.8 at delay 0.1
//   shop/map open -> ui_unpause, 0; shop leave -> ui_back, 0; shop ambience -> lamp_hum loop
//   event open -> mystery_reel, 0; choice -> ui_click, 0; good -> ui_unlock, 0; bad -> ui_cant_afford rate 0.8; junk added -> teleport_out rate 0.5
//   map click -> ui_start, 0; unreachable -> ui_invalid, 0; hover -> ui_hover, 0; next layer -> ui_reveal rate 0.8
//   end screen roll -> result_roll loop; unlock line -> ui_unlock rate 1.2 at delay 1.0; discard -> ui_drop, 0; pick -> ui_pickup, 0
const E = 1.05946, st = n => Math.pow(E, n);

export const demo = ({ tone, noise, layer, notes, bell, click }) => ({
	// --- Fight ---
	damage_land: { g: "Fight", d: "stored damage fires on the paddle; ladder = 1-9 / 10-29 / 30-99 / 100+", gen: () => layer([tone({ f: 392, f1: 784, dur: 0.1, duty: 0.3 })], [bell(1568, 0.18), 0.03], [noise({ dur: 0.04, lp: 6000, hp: 2000 }), 0, 0.3]), ladder: [1, st(2), st(4), st(7)] },
	hp_lose: { g: "Fight", d: "player loses HP; ladder = 1-2 / 3-5 / 6+", gen: () => layer([tone({ f: 180, f1: 90, dur: 0.3, duty: 0.5, k: 9 })], [noise({ dur: 0.15, lp: 1500, lp1: 200 }), 0, 0.7], [tone({ f: 60, dur: 0.12, wave: "sin" }), 0, 0.9]), ladder: [1, 0.85, 0.7] },
	enemy_die: { g: "Fight", d: "enemy HP hits 0; boss at 0.6", gen: () => layer([tone({ f: 600, f1: 80, dur: 0.45, wave: "saw", lp: 3000, vib: 0.05, vibf: 9, k: 5 })], [noise({ dur: 0.4, lp: 4000, lp1: 200 }), 0.05, 0.8], [tone({ f: 120, f1: 40, dur: 0.35, wave: "sin" }), 0.1, 1]), ladder: [1, 0.6] },

	// --- Run flow ---
	run_over: { g: "Run flow", d: "run over screen opens, sad descend", gen: () => layer([notes([[392, 0.2], [370, 0.2], [330, 0.2], [294, 0.6]], { k: 6 }, 0.03)], [notes([[196, 0.4], [165, 0.4], [147, 0.8]], { wave: "tri", k: 4 }), 0, 0.6], [tone({ f: 49, dur: 1.4, wave: "sin", a: 0.1, k: 2 }), 0.6, 0.5]) },
	run_won: { g: "Run flow", d: "run won screen opens, round_clear's motif plus a bar", gen: () => layer([notes([[523, 0.1], [659, 0.1], [784, 0.1], [1047, 0.2], [784, 0.1], [1047, 0.1], [1319, 0.1], [1568, 0.6]], { k: 8 })], [notes([[262, 0.3], [330, 0.3], [392, 0.3], [523, 0.9]], { wave: "tri", k: 5 }), 0, 0.5], [bell(2093, 0.8, 0.6), 1.0], [bell(3136, 0.7, 0.3), 1.1], [noise({ dur: 0.6, lp: 12000, hp: 6000 }), 1.0, 0.1]) },
});
