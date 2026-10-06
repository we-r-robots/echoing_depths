extends RefCounted
## Global combat tuning. All numbers are placeholders pending balance.
## Times are integer milliseconds of simulated time; the event log reports seconds.

const DATA_VERSION := 1

const COMBAT := {
	# --- ATB timeline (active-wait: gauges only fill while nobody is acting) ---
	"gauge_max": 100000,
	"fill_per_spd_per_ms": 9,        # Spd 10 fills an empty gauge in ~1.11 s of running time
	"initial_gauge_min": 0.30,       # each unit starts with a seeded random gauge fraction
	"initial_gauge_max": 0.65,
	"action_gap_ms": 70,             # breathing beat after every action, so each one reads
	"intro_ms": 600,                 # nobody acts before this (lets the scene show both sides)

	# --- charge meter ---
	"charge_max": 100,
	"charge_act_scale": 0.30,         # global multiplier on class charge_on_act
	"charge_hit_scale": 0.8,         # global multiplier on class charge_on_hit
	"start_charge_bonus": 25,         # added to every class start_charge
	"start_charge_spread": 25,       # each unit starts at class start_charge +/- this (seeded)
	# (retired 2026-10-06: full_charge_jumps_queue. Abilities now run on their own timer: a full bar
	# casts at the next action boundary, ahead of basic actions, and leaves the ATB gauge alone.)

	# --- damage ---
	"damage_scale": 1.8,              # power * scale * A * A / (A + D)
	"damage_variance": 0.08,         # +/- fraction, seeded
	"crit_mult": 1.5,
	"crit_enabled": true,            # tests switch crits off to check exact formulas
	"formation_mod_threshold": 0.10, # formation effect is annotated on a hit only if >= 10%
	"formation_proc_interval_ms": 120000, # = once per fight per side/source/stat
	"formation_proc_min": 0.0,       # every formation/composition effect cues once per fight
	"behaviour_cue_interval_ms": 6000, # a repeating formation behaviour cues at most every 6 s per side
	"back_row_phys_mult": 0.5,       # back column deals AND takes half physical damage
	"heal_scale": 0.6,

	# --- sudden death ("the Fading": time-based only, never triggered by a side's last unit) ---
	"sudden_death_start_ms": 36000,
	"sudden_death_interval_ms": 1500,
	"sudden_death_side_stagger_ms": 200, # side B's tick numbers land 0.2 s after side A's
	"sudden_death_tick_ms": 700,     # the tick occupies the timeline like an action
	"sudden_death_hp_pct_per_tick": 0.08,   # tick n deals n * this of max HP to everyone
	"sudden_death_dmg_mult_per_tick": 0.25, # +25% dealt damage per tick so far
	"sudden_death_heal_mult_per_tick": 0.25,# -25% healing per tick so far (floored at 0)
	"max_fight_ms": 120000,          # hard cap; reached only if something is badly broken
}

## Legendary gate placeholder (spec option "hard cap of one Legendary per party").
const MAX_LEGENDARY_PER_PARTY := 1

## Level caps per tier.
const MAX_LEVEL := {"base": 6, "advanced": 4, "legendary": 4, "monster": 10, "memory": 1}
