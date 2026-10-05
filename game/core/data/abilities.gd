extends RefCounted
## Actions: basic attacks and charged abilities share one schema.
##
## name:      display name.
## kind:      "basic" or "ability" (informational; the sim decides by charge).
## target:    primary target selector (see README "Targeting").
## duration:  seconds the action occupies the timeline.
## impact:    seconds after action start when effects land (wind-up for animation).
## area:      optional; overrides the action_start "area" (e.g. a primary hit + splash on everyone).
## anim:      hint for the battle scene ("melee", "shoot", "cast", "heal", "slam"...).
## effects:   applied in order. Each effect:
##   op:     "damage" | "heal" | "charge"
##   to:     "primary" | "primary_adjacent" | "primary_column" | "primary_column_rest" |
##           "other_enemies" (all enemies except the primary) | "melee_enemy" (whoever melee
##           targeting would hit, e.g. a healer's smite rider) | "all_enemies" |
##           "front_enemies" | "front_random" | "self" | "all_allies" | "lowest_hp_ally" | "random_enemy"
##   kind:   "physical" | "magic"            (damage)
##   power:  multiplier                       (damage / heal; heal scales with Mag)
##   hits:   repeat count, each hit re-picks if the target is down (default 1)
##   bonus_below_hp: [fraction, mult] -> extra multiplier when target HP% is below
##   drain:  fraction of damage dealt healed to the source
##   amount: charge added (op "charge")

const ACTIONS := {
	# ---------------- basic attacks ----------------
	"strike": {"name": "Strike", "kind": "basic", "target": "melee", "duration": 0.49, "impact": 0.23, "anim": "melee",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.0, "to": "primary"}]},
	"stab": {"name": "Stab", "kind": "basic", "target": "melee", "duration": 0.45, "impact": 0.21, "anim": "melee",
		"effects": [{"op": "damage", "kind": "physical", "power": 0.9, "to": "primary"}]},
	"smite": {"name": "Smite", "kind": "basic", "target": "melee", "duration": 0.49, "impact": 0.26, "anim": "cast",
		"effects": [{"op": "damage", "kind": "magic", "power": 0.7, "to": "primary"}]},
	"bolt": {"name": "Bolt", "kind": "basic", "target": "back_first", "duration": 0.52, "impact": 0.29, "anim": "shoot",
		"effects": [{"op": "damage", "kind": "magic", "power": 0.8, "to": "primary"}]},
	"claw": {"name": "Claw", "kind": "basic", "target": "melee", "duration": 0.45, "impact": 0.23, "anim": "melee",
		"effects": [{"op": "damage", "kind": "physical", "power": 0.85, "to": "primary"}]},
	"slam": {"name": "Slam", "kind": "basic", "target": "melee", "duration": 0.55, "impact": 0.29, "anim": "slam",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.0, "to": "primary"}]},
	"flicker": {"name": "Flicker", "kind": "basic", "target": "lowest_hp_enemy", "duration": 0.49, "impact": 0.26, "anim": "shoot",
		"effects": [{"op": "damage", "kind": "magic", "power": 0.7, "to": "primary"}]},

	"kindle": {"name": "Kindle", "kind": "basic", "target": "melee", "duration": 0.55, "impact": 0.3, "anim": "cast",
		"effects": [{"op": "damage", "kind": "magic", "power": 0.7, "to": "primary"}, {"op": "heal", "power": 0.9, "to": "lowest_hp_ally"}]},

	# ---------------- base class abilities ----------------
	"cleave": {"name": "Cleave", "kind": "ability", "target": "melee", "duration": 0.72, "impact": 0.36, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.9, "to": "primary"}, {"op": "damage", "kind": "physical", "power": 0.8, "to": "primary_adjacent"}]},
	"backstab": {"name": "Backstab", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.65, "impact": 0.33, "anim": "dash",
		"effects": [{"op": "damage", "kind": "physical", "power": 3.2, "to": "primary"}]},
	"mend": {"name": "Mend", "kind": "ability", "target": "lowest_hp_ally", "duration": 0.65, "impact": 0.36, "anim": "heal",
		"effects": [{"op": "heal", "power": 2.2, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.9, "to": "melee_enemy"}]},
	"firestorm": {"name": "Firestorm", "kind": "ability", "target": "back_first", "area": "all_enemies", "duration": 0.85, "impact": 0.45, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.6, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.7, "to": "other_enemies"}]},

	# ---------------- advanced (illustrative) ----------------
	"aegis_strike": {"name": "Aegis Strike", "kind": "ability", "target": "melee", "duration": 0.78, "impact": 0.39, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.7, "to": "primary"}, {"op": "heal", "power": 1.4, "to": "lowest_hp_ally"}]},
	"rampage": {"name": "Rampage", "kind": "ability", "target": "melee", "duration": 0.85, "impact": 0.29, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 0.9, "to": "front_random", "hits": 3}]},
	"riposte": {"name": "Riposte", "kind": "ability", "target": "melee", "duration": 0.65, "impact": 0.33, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.9, "to": "primary"}, {"op": "charge", "amount": 40, "to": "self"}]},
	"execute": {"name": "Execute", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.72, "impact": 0.39, "anim": "dash",
		"effects": [{"op": "damage", "kind": "physical", "power": 2.6, "to": "primary", "bonus_below_hp": [0.4, 1.5]}]},
	"sanctuary": {"name": "Sanctuary", "kind": "ability", "target": "all_allies", "duration": 0.78, "impact": 0.42, "anim": "heal_big",
		"effects": [{"op": "heal", "power": 1.2, "to": "all_allies"}, {"op": "damage", "kind": "magic", "power": 0.9, "to": "melee_enemy"}]},
	"grave_drain": {"name": "Grave Drain", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.78, "impact": 0.42, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.8, "to": "primary", "drain": 0.5}]},
	"meteor": {"name": "Meteor", "kind": "ability", "target": "back_first", "duration": 0.91, "impact": 0.52, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 2.2, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.7, "to": "primary_adjacent"}]},
	"hexfire": {"name": "Hexfire", "kind": "ability", "target": "back_first", "area": "all_enemies", "duration": 0.85, "impact": 0.45, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.6, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.75, "to": "other_enemies"}]},
	"lantern_oath": {"name": "Lantern Oath", "kind": "ability", "target": "melee", "duration": 0.91, "impact": 0.45, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 2.0, "to": "primary"}, {"op": "damage", "kind": "physical", "power": 0.9, "to": "primary_adjacent"}, {"op": "heal", "power": 1.4, "to": "lowest_hp_ally"}]},

	# ---------------- monster abilities ----------------
	"gnaw": {"name": "Gnaw", "kind": "ability", "target": "melee", "duration": 0.65, "impact": 0.23, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 0.95, "to": "primary", "hits": 2}]},
	"unravel": {"name": "Unravel", "kind": "ability", "target": "back_first", "area": "all_enemies", "duration": 0.78, "impact": 0.42, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.4, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.6, "to": "other_enemies"}]},
	"quake": {"name": "Quake", "kind": "ability", "target": "melee", "duration": 0.85, "impact": 0.45, "anim": "slam_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.6, "to": "primary"}, {"op": "damage", "kind": "physical", "power": 0.8, "to": "primary_column_rest"}]},
	"siphon": {"name": "Siphon", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.72, "impact": 0.39, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.7, "to": "primary", "drain": 0.5}]},
	"shard_burst": {"name": "Shard Burst", "kind": "ability", "target": "back_first", "area": "all_enemies", "duration": 0.91, "impact": 0.52, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.5, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.7, "to": "other_enemies"}]},
}
