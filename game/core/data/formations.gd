extends RefCounted
## Formation shapes and class-composition buffs. Placeholder numbers.
##
## Grid: col 0 = front, col 1 = back; rows 0..3 (top to bottom).
## A shape is a list of [col, row] cells normalised so the top-most occupied row is 0.
## "mirror": true also matches the shape flipped vertically. Matching is exact
## (the party's occupied cells must equal the shape after vertical translation).
## Shapes are tried in order; the first match wins. "loose_ranks" is the fallback.
##
## Each modifier: {"scope": "all"|"front"|"back", "stat": <stat>, "value": <float>}
## stat: hp_pct, atk_pct, def_pct, mag_pct, spd_pct (multiplicative, +0.1 = +10%),
##       crit_add (added to crit chance), charge_pct (scales all charge gained),
##       heal_pct (scales healing done).
## Every formation has at least one buff and at least one debuff.

const SHAPES := [
	{"id": "wall", "name": "Wall", "cells": [[0, 0], [0, 1], [0, 2], [0, 3]], "mirror": false,
		"buffs": [{"scope": "all", "stat": "def_pct", "value": 0.30}],
		"debuffs": [{"scope": "all", "stat": "mag_pct", "value": -0.10}]},
	{"id": "rearguard", "name": "Rearguard", "cells": [[1, 0], [1, 1], [1, 2], [1, 3]], "mirror": false,
		"buffs": [{"scope": "all", "stat": "mag_pct", "value": 0.20}],
		"debuffs": [{"scope": "all", "stat": "hp_pct", "value": -0.10}]},
	{"id": "square", "name": "Square", "cells": [[0, 0], [0, 1], [1, 0], [1, 1]], "mirror": false,
		"buffs": [{"scope": "all", "stat": "charge_pct", "value": 0.25}],
		"debuffs": [{"scope": "all", "stat": "spd_pct", "value": -0.08}]},
	{"id": "shield", "name": "Shield", "cells": [[0, 1], [1, 0], [1, 1], [1, 2]], "mirror": false,
		"buffs": [{"scope": "front", "stat": "def_pct", "value": 0.40}, {"scope": "back", "stat": "def_pct", "value": 0.20}],
		"debuffs": [{"scope": "all", "stat": "atk_pct", "value": -0.10}]},
	{"id": "anvil", "name": "Anvil", "cells": [[0, 0], [0, 1], [0, 2], [1, 1]], "mirror": false,
		"buffs": [{"scope": "front", "stat": "atk_pct", "value": 0.15}],
		"debuffs": [{"scope": "front", "stat": "def_pct", "value": -0.10}]},
	{"id": "vanguard", "name": "Vanguard", "cells": [[0, 0], [0, 1], [0, 2], [1, 0]], "mirror": true,
		"buffs": [{"scope": "all", "stat": "crit_add", "value": 0.10}],
		"debuffs": [{"scope": "all", "stat": "hp_pct", "value": -0.08}]},
	{"id": "watchtower", "name": "Watchtower", "cells": [[0, 0], [1, 0], [1, 1], [1, 2]], "mirror": true,
		"buffs": [{"scope": "back", "stat": "mag_pct", "value": 0.15}],
		"debuffs": [{"scope": "front", "stat": "def_pct", "value": -0.15}]},
	{"id": "staggered", "name": "Staggered", "cells": [[0, 0], [0, 1], [1, 1], [1, 2]], "mirror": true,
		"buffs": [{"scope": "all", "stat": "spd_pct", "value": 0.12}],
		"debuffs": [{"scope": "all", "stat": "def_pct", "value": -0.08}]},
	# small-party shapes
	{"id": "shadowing", "name": "Shadowing", "cells": [[0, 0], [1, 0]], "mirror": false,
		"buffs": [{"scope": "back", "stat": "charge_pct", "value": 0.20}],
		"debuffs": [{"scope": "front", "stat": "def_pct", "value": -0.10}]},
	{"id": "twin_blades", "name": "Twin Blades", "cells": [[0, 0], [0, 1]], "mirror": false,
		"buffs": [{"scope": "all", "stat": "atk_pct", "value": 0.10}],
		"debuffs": [{"scope": "all", "stat": "mag_pct", "value": -0.10}]},
	{"id": "spear_line", "name": "Spear Line", "cells": [[0, 0], [0, 1], [0, 2]], "mirror": false,
		"buffs": [{"scope": "all", "stat": "atk_pct", "value": 0.10}],
		"debuffs": [{"scope": "all", "stat": "spd_pct", "value": -0.06}]},
]

const FALLBACK := {"id": "loose_ranks", "name": "Loose Ranks", "cells": [], "mirror": false,
	"buffs": [{"scope": "all", "stat": "charge_pct", "value": 0.10}],
	"debuffs": [{"scope": "all", "stat": "def_pct", "value": -0.05}]}

## Class-composition buffs (small, buff only). Counted over heroes' BASE classes
## (an advanced Paladin counts as a Fighter). Monsters never trigger these.
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
	{"id": "choir", "name": "Choir", "when": {"base": "healer", "count_at_least": 2},
		"mods": [{"scope": "class", "stat": "heal_pct", "value": 0.15}]},
	{"id": "arcane_circle", "name": "Arcane Circle", "when": {"base": "mage", "count_at_least": 2},
		"mods": [{"scope": "class", "stat": "mag_pct", "value": 0.10}]},
]
