extends RefCounted
## Formations (spec 05-formations.md). Placeholder numbers from the doc, to tune in playtesting.
##
## Grid: col 0 = front, col 1 = back; rows 0..3 (top to bottom).
## A shape is a list of [col, row] cells normalised so the top-most occupied row is 0. It matches
## at any height; "mirror": true also matches it flipped top/bottom. Front/back orientation is
## never flipped: an L with its single block in front is a different shape from one with it behind.
## Any placement that matches no shape (not edge-connected, or 5+ units) fights as STRAYS.
##
## bonus / cost "mods": {"scope", "stat", "value"} stat modifiers (multiplicative pct, +0.1 = +10%).
##   scope: "all", "front", "back", or a role from formation.gd: "post" (lone front of Hearth /
##   Lighthouse), "tip" (Shardpoint front), "keeper" (Keeper's Ring middle back), "flanker" (back
##   unit of Keystone / Crescent), "gap" (front unit that draws melee in Keystone / Crescent).
##   stat: hp_pct, atk_pct, def_pct, mag_pct, spd_pct, crit_add, charge_pct, heal_pct,
##         dmg_taken_pct (+0.05 = takes 5% more damage).
## behaviour: {"id", "name", "text", ...params}; implemented in combat_sim.gd, each firing emits a
##   formation_proc with effect = behaviour id.
## cost: {"text", "mods"}: every shape has a cost, a stat debuff and/or a weakness of the geometry.

const SHAPES := [
	# ---------------- dominoes (2 heroes) ----------------
	{"id": "kindred", "name": "Kindred", "size": 2, "cells": [[0, 0], [0, 1]], "mirror": false,
		"bonus": [{"scope": "front", "stat": "def_pct", "value": 0.10}],
		"behaviour": {"id": "shoulder_to_shoulder", "name": "Shoulder to shoulder", "charge": 15,
			"text": "When one is hit by melee, the other gains charge."},
		"cost": {"text": "Nobody guards the back if the line falls.", "mods": []}},
	{"id": "vigil", "name": "Vigil", "size": 2, "cells": [[1, 0], [1, 1]], "mirror": false,
		"bonus": [{"scope": "all", "stat": "mag_pct", "value": 0.10}],
		"behaviour": {"id": "covering_fire", "name": "Covering fire",
			"text": "When one is attacked in melee, the other's next basic action targets that attacker."},
		"cost": {"text": "No front line: melee reaches them at once.", "mods": []}},
	{"id": "lamplight", "name": "Lamplight", "size": 2, "cells": [[0, 0], [1, 0]], "mirror": false,
		"bonus": [{"scope": "back", "stat": "mag_pct", "value": 0.10}, {"scope": "back", "stat": "heal_pct", "value": 0.10}],
		"behaviour": {"id": "guardian", "name": "Guardian", "uses": 1,
			"text": "The front unit intercepts the first ranged or magic hit aimed at its back partner, once per fight."},
		"cost": {"text": "The front unit takes the extra hit.", "mods": []}},
	# ---------------- trominoes (3 heroes) ----------------
	{"id": "tidebreak", "name": "Tidebreak", "size": 3, "cells": [[0, 0], [0, 1], [0, 2]], "mirror": false,
		"bonus": [{"scope": "front", "stat": "def_pct", "value": 0.45}],
		"behaviour": {"id": "brace", "name": "Brace", "share": 0.20,
			"text": "A hit on the middle unit passes 20% of its damage to each neighbour."},
		"cost": {"text": "Spd -5%.", "mods": [{"scope": "all", "stat": "spd_pct", "value": -0.05}]}},
	{"id": "choir", "name": "Choir", "size": 3, "cells": [[1, 0], [1, 1], [1, 2]], "mirror": false,
		"bonus": [{"scope": "all", "stat": "mag_pct", "value": 0.05}],
		"behaviour": {"id": "opening_volley", "name": "Opening volley", "gauge": 0.20,
			"text": "The back row's ATB gauges start fuller, so they act first."},
		"cost": {"text": "No front line.", "mods": []}},
	{"id": "keystone", "name": "Keystone", "size": 3, "cells": [[0, 0], [0, 1], [1, 0]], "mirror": true,
		"bonus": [{"scope": "front", "stat": "atk_pct", "value": 0.10}],
		"behaviour": {"id": "flank", "name": "Flank", "dmg": 0.20, "crit": 0.0,
			"text": "The back unit deals +20% to the enemy in its own row."},
		"cost": {"text": "The front unit next to the gap draws more melee.", "mods": [], "draw": "gap"}},
	{"id": "hearth", "name": "Hearth", "size": 3, "cells": [[0, 0], [1, 0], [1, 1]], "mirror": true,
		"bonus": [{"scope": "back", "stat": "heal_pct", "value": 0.10}, {"scope": "back", "stat": "charge_pct", "value": 0.10}],
		"behaviour": {"id": "hearthguard", "name": "Hearthguard", "per_ally": 0.10,
			"text": "The lone front unit takes 10% less damage for each living back ally."},
		"cost": {"text": "That front unit is the only wall.", "mods": []}},
	# ---------------- tetrominoes (4 heroes) ----------------
	{"id": "seawall", "name": "Seawall", "size": 4, "cells": [[0, 0], [0, 1], [0, 2], [0, 3]], "mirror": false,
		"bonus": [{"scope": "front", "stat": "def_pct", "value": 0.55}],
		"behaviour": {"id": "share_the_blow", "name": "Share the blow", "share": 0.30,
			"text": "30% of each hit spreads to the unit in the next row."},
		"cost": {"text": "Spd -3%, and no back row to protect or protect from.",
			"mods": [{"scope": "all", "stat": "spd_pct", "value": -0.03}]}},
	{"id": "lumari_chorus", "name": "Lumari Chorus", "size": 4, "cells": [[1, 0], [1, 1], [1, 2], [1, 3]], "mirror": false,
		"bonus": [{"scope": "all", "stat": "mag_pct", "value": 0.05}],
		"behaviour": {"id": "opening_volley", "name": "Opening volley", "gauge": 0.30, "splash": 0.10,
			"text": "The back row's gauges start much fuller, and magic splash deals +10%."},
		"cost": {"text": "No front line, and physical attackers deal half.", "mods": []}},
	{"id": "vault_door", "name": "Vault Door", "size": 4, "cells": [[0, 0], [0, 1], [1, 0], [1, 1]], "mirror": false,
		"bonus": [{"scope": "all", "stat": "hp_pct", "value": 0.05}, {"scope": "all", "stat": "atk_pct", "value": 0.05},
			{"scope": "all", "stat": "def_pct", "value": 0.05}, {"scope": "all", "stat": "mag_pct", "value": 0.05},
			{"scope": "all", "stat": "spd_pct", "value": 0.05}],
		"behaviour": {"id": "hold_the_door", "name": "Hold the door",
			"text": "When a front unit falls, the back unit in its row steps forward into its slot."},
		"cost": {"text": "No standout strength.", "mods": []}},
	{"id": "crescent", "name": "Crescent", "size": 4, "cells": [[0, 0], [0, 1], [0, 2], [1, 0]], "mirror": true,
		"bonus": [{"scope": "front", "stat": "atk_pct", "value": 0.15}],
		"behaviour": {"id": "flank", "name": "Flank", "dmg": 0.30, "crit": 0.15,
			"text": "The back unit deals +30% and crits more often against the enemy in its own row."},
		"cost": {"text": "The open end draws melee.", "mods": [], "draw": "gap"}},
	{"id": "lighthouse", "name": "Lighthouse", "size": 4, "cells": [[0, 0], [1, 0], [1, 1], [1, 2]], "mirror": true,
		"bonus": [{"scope": "back", "stat": "mag_pct", "value": 0.10}, {"scope": "back", "stat": "heal_pct", "value": 0.10}],
		"behaviour": {"id": "hearthguard", "name": "Hearthguard", "per_ally": 0.10, "taunt": true,
			"text": "The lit post takes 10% less damage for each living back ally, and draws melee and single-target ranged and magic attacks."},
		"cost": {"text": "The post can fall fast.", "mods": []}},
	{"id": "keepers_ring", "name": "Keeper's Ring", "size": 4, "cells": [[0, 0], [0, 1], [0, 2], [1, 1]], "mirror": false,
		"bonus": [{"scope": "keeper", "stat": "heal_pct", "value": 0.40}, {"scope": "keeper", "stat": "charge_pct", "value": 0.40},
			{"scope": "front", "stat": "def_pct", "value": 0.30}],
		"behaviour": {"id": "keepers_ring", "name": "Keeper's ring",
			"text": "While all three front units stand, the ringed back unit can't be targeted at all (area splash still reaches it)."},
		"cost": {"text": "Front units take +5% damage.", "mods": [{"scope": "front", "stat": "dmg_taken_pct", "value": 0.05}]}},
	{"id": "shardpoint", "name": "Shardpoint", "size": 4, "cells": [[0, 1], [1, 0], [1, 1], [1, 2]], "mirror": false,
		"bonus": [{"scope": "tip", "stat": "crit_add", "value": 0.15}],
		"behaviour": {"id": "shardpoint", "name": "Shardpoint", "charge": 8,
			"text": "The tip gains charge whenever an ally behind it acts."},
		"cost": {"text": "The tip draws every melee hit.", "mods": []}},
	{"id": "echo_step", "name": "Echo Step", "size": 4, "cells": [[0, 0], [0, 1], [1, 1], [1, 2]], "mirror": true,
		"bonus": [{"scope": "all", "stat": "spd_pct", "value": 0.05}],
		"behaviour": {"id": "echo_step", "name": "Echo step", "splash": 0.5,
			"text": "The offset spacing halves splash from area abilities."},
		"cost": {"text": "Def -5%.", "mods": [{"scope": "all", "stat": "def_pct", "value": -0.05}]}},
]

const STRAYS := {"id": "strays", "name": "Strays", "size": 0, "cells": [], "mirror": false,
	"bonus": [{"scope": "all", "stat": "spd_pct", "value": 0.05}, {"scope": "all", "stat": "crit_add", "value": 0.05}],
	"behaviour": {"id": "scattered", "name": "Scattered",
		"text": "No splash from area abilities spreads between Strays, since nobody stands next to anyone."},
	"cost": {"text": "No shape behaviour ever fires.", "mods": []}}

## Partly joined but no shape (or a locked shape with no unlocked part): no bonus, no cost, no behaviour.
const UNFORMED := {"id": "unformed", "name": "No formation", "size": 0, "cells": [], "bonus": [],
	"behaviour": {}, "cost": {"text": "", "mods": []}}

## Unlocked from the start (Training Grounds unlocks the rest with Shards). Strays is always available.
const DEFAULT_UNLOCKED := ["kindred", "vigil", "lamplight", "tidebreak", "choir"]

## Suggested Training Grounds tree (shape -> shapes it leads to). Placeholder for the meta builder.
const UNLOCK_TREE := {
	"kindred": ["keystone"], "lamplight": ["keystone", "hearth", "vault_door"], "vigil": ["hearth"],
	"tidebreak": ["seawall", "keepers_ring"], "choir": ["lumari_chorus"], "keystone": ["crescent", "echo_step"],
	"hearth": ["lighthouse", "shardpoint", "echo_step"],
}

## Class-composition buffs (kept from the earlier design: small, buff only, no conflict with
## shapes). Counted over heroes' BASE classes. Monsters never trigger these.
## when: {"distinct_base_at_least": n} or {"base": id, "count_at_least": n}
## scope: "all" or "class" (only heroes of that base class).
const COMPOSITIONS := [
	{"id": "well_rounded", "name": "Well Rounded", "when": {"distinct_base_at_least": 4},
		"mods": [{"scope": "all", "stat": "hp_pct", "value": 0.06}, {"scope": "all", "stat": "atk_pct", "value": 0.06},
			{"scope": "all", "stat": "def_pct", "value": 0.06}, {"scope": "all", "stat": "mag_pct", "value": 0.06}]},
	{"id": "shield_brothers", "name": "Shield Brothers", "when": {"base": "fighter", "count_at_least": 2},
		"mods": [{"scope": "class", "stat": "def_pct", "value": 0.10}]},
	{"id": "night_pack", "name": "Night Pack", "when": {"base": "rogue", "count_at_least": 2},
		"mods": [{"scope": "class", "stat": "crit_add", "value": 0.08}]},
	{"id": "choir_of_healers", "name": "Choir of Healers", "when": {"base": "healer", "count_at_least": 2},
		"mods": [{"scope": "class", "stat": "heal_pct", "value": 0.15}]},
	{"id": "arcane_circle", "name": "Arcane Circle", "when": {"base": "mage", "count_at_least": 2},
		"mods": [{"scope": "class", "stat": "mag_pct", "value": 0.10}]},
]
