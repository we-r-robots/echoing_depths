extends RefCounted
## Class definitions. All numbers are placeholders pending balance.
##
## tier:        "base" | "advanced" | "legendary" | "monster"
## base:        base class id this class descends from (self for base classes)
## region:      advanced only. Alignment region that produces it:
##              "LG","CG","LE","CE","N" (core) or "LG*","CG*","LE*","CE*" (corners)
## advances_from: legendary only. The advanced class it is the Legendary form of.
## start_alignment: base only. Fixed starting grid position [good_evil, lawful_chaotic].
## stats:       level-1 stats.   growth: added per level above 1 (stats are floored).
## crit:        crit chance (0..1).
## charge_on_act: charge gained after each basic action.
## charge_on_hit: charge gained per 1% of max HP lost to damage.
## start_charge: charge at fight start (0..99).
## basic / ability: action ids from abilities.gd.
## preferred_col: 0 front / 1 back (hint for auto-placement and demo parties).
## provisional: why a class's data may change (a decision the user hasn't made yet).

const CLASSES := {
	# ================= BASE CLASSES =================
	"fighter": {"name": "Fighter", "tier": "base", "base": "fighter", "start_alignment": [0, 1],
		"stats": {"hp": 130, "atk": 18, "def": 14, "mag": 6, "spd": 9},
		"growth": {"hp": 16, "atk": 2.0, "def": 2.0, "mag": 0.5, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 30, "charge_on_hit": 2.0, "start_charge": 30,
		"basic": "strike", "ability": "cleave", "preferred_col": 0},
	"rogue": {"name": "Rogue", "tier": "base", "base": "rogue", "start_alignment": [-1, -1],
		"stats": {"hp": 90, "atk": 19, "def": 8, "mag": 8, "spd": 14},
		"growth": {"hp": 10, "atk": 2.5, "def": 1.0, "mag": 0.5, "spd": 0.6},
		"crit": 0.2, "charge_on_act": 40, "charge_on_hit": 1.2, "start_charge": 40,
		"basic": "stab", "ability": "backstab", "preferred_col": 0},
	"healer": {"name": "Healer", "tier": "base", "base": "healer", "start_alignment": [1, 1],
		"stats": {"hp": 95, "atk": 7, "def": 9, "mag": 16, "spd": 10},
		"growth": {"hp": 10, "atk": 0.5, "def": 1.0, "mag": 2.0, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 50, "charge_on_hit": 1.0, "start_charge": 25,
		"basic": "smite", "ability": "mend", "preferred_col": 1},
	"mage": {"name": "Mage", "tier": "base", "base": "mage", "start_alignment": [1, -1],
		"stats": {"hp": 80, "atk": 6, "def": 7, "mag": 20, "spd": 10},
		"growth": {"hp": 8, "atk": 0.5, "def": 0.7, "mag": 2.5, "spd": 0.4},
		"crit": 0.08, "charge_on_act": 35, "charge_on_hit": 1.0, "start_charge": 35,
		"basic": "bolt", "ability": "firestorm", "preferred_col": 1},

	# ================= ADVANCED =================
	# Only classes the user APPROVED (docs/design/class-verdicts-round1.md and -round2.md), one per
	# region. Regions with no approved class fall back to the nearest approved region
	# (core/alignment.gd, PROVISIONAL). Stats follow ruling 8: every advanced class of a base spends
	# the same budget (BUDGET below).

	# ---- Fighter (start N): N Halberdier, LG Lightsworn, CG Bladebreaker, LE Warden of Chains (id
	#      shackler), CE Berserker, LE* Iron Marshal, CG* Echoblade, CE* Ravager, LG* Aegisbearer (round 3)
	"halberdier": {"name": "Halberdier", "tier": "advanced", "base": "fighter", "region": "N",
		"stats": {"hp": 190, "atk": 30, "def": 17, "mag": 7, "spd": 12},
		"growth": {"hp": 19, "atk": 3.2, "def": 1.8, "mag": 0.6, "spd": 0.6},
		"crit": 0.06, "charge_on_act": 30, "charge_on_hit": 2.0, "start_charge": 30,
		"basic": "strike", "ability": "long_reach", "preferred_col": 0},
	# Lightsworn replaces the retired Paladin (round 2): same region, same stats, Paladin's ability name
	"lightsworn": {"name": "Lightsworn", "tier": "advanced", "base": "fighter", "region": "LG",
		"stats": {"hp": 195, "atk": 24, "def": 21, "mag": 10, "spd": 10},
		"growth": {"hp": 20, "atk": 2.5, "def": 2.5, "mag": 0.6, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 30, "charge_on_hit": 2.0, "start_charge": 30,
		"basic": "strike", "ability": "aegis_strike", "preferred_col": 0},
	"bladebreaker": {"name": "Bladebreaker", "tier": "advanced", "base": "fighter", "region": "CG",
		"stats": {"hp": 210, "atk": 20, "def": 24, "mag": 7, "spd": 11},
		"growth": {"hp": 21, "atk": 1.8, "def": 2.8, "mag": 0.6, "spd": 0.6},
		"crit": 0.05, "charge_on_act": 30, "charge_on_hit": 2.2, "start_charge": 30,
		"basic": "strike", "ability": "break_blade", "preferred_col": 0},
	"ravager": {"name": "Ravager", "tier": "advanced", "base": "fighter", "region": "CE*",
		"stats": {"hp": 200, "atk": 33, "def": 15, "mag": 5, "spd": 11},
		"growth": {"hp": 20, "atk": 3.6, "def": 1.5, "mag": 0.4, "spd": 0.5},
		"crit": 0.08, "charge_on_act": 32, "charge_on_hit": 2.4, "start_charge": 30,
		"basic": "strike", "ability": "whirlwind", "preferred_col": 0},
	"aegisbearer": {"name": "Aegisbearer", "tier": "advanced", "base": "fighter", "region": "LG*",
		"stats": {"hp": 215, "atk": 18, "def": 27, "mag": 7, "spd": 9},
		"growth": {"hp": 22, "atk": 1.6, "def": 3.0, "mag": 0.5, "spd": 0.5},
		"crit": 0.04, "charge_on_act": 30, "charge_on_hit": 2.2, "start_charge": 30,
		"basic": "strike", "ability": "raise_the_aegis", "preferred_col": 0},
	"berserker": {"name": "Berserker", "tier": "advanced", "base": "fighter", "region": "CE",
		"stats": {"hp": 200, "atk": 31, "def": 16, "mag": 6, "spd": 11},
		"growth": {"hp": 20, "atk": 3.5, "def": 1.5, "mag": 0.5, "spd": 0.5},
		"crit": 0.1, "charge_on_act": 35, "charge_on_hit": 2.6, "start_charge": 30,
		"basic": "strike", "ability": "rampage", "preferred_col": 0},
	"shackler": {"name": "Warden of Chains", "tier": "advanced", "base": "fighter", "region": "LE",
		# stable id "shackler"; renamed Warden of Chains in round 2 (q-5), ability and data unchanged
		"stats": {"hp": 170, "atk": 28, "def": 22, "mag": 9, "spd": 11},
		"growth": {"hp": 17, "atk": 2.8, "def": 2.5, "mag": 0.8, "spd": 0.5},
		"crit": 0.05, "charge_on_act": 30, "charge_on_hit": 2.0, "start_charge": 30,
		"basic": "strike", "ability": "shackle", "preferred_col": 0},
	"iron_marshal": {"name": "Iron Marshal", "tier": "advanced", "base": "fighter", "region": "LE*",
		"stats": {"hp": 205, "atk": 20, "def": 25, "mag": 8, "spd": 10},
		"growth": {"hp": 21, "atk": 1.8, "def": 3.0, "mag": 0.6, "spd": 0.4},
		"crit": 0.04, "charge_on_act": 30, "charge_on_hit": 2.2, "start_charge": 30,
		"basic": "strike", "ability": "drive_on", "preferred_col": 0},
	"echoblade": {"name": "Echoblade", "tier": "advanced", "base": "fighter", "region": "CG*",
		"stats": {"hp": 170, "atk": 31, "def": 16, "mag": 8, "spd": 15},
		"growth": {"hp": 16, "atk": 3.5, "def": 1.8, "mag": 0.7, "spd": 0.8},
		"crit": 0.08, "charge_on_act": 32, "charge_on_hit": 2.0, "start_charge": 30,
		"basic": "strike", "ability": "call_echo", "preferred_col": 0},

	# ---- Rogue (start CE): CE Cutpurse, CE* Fadewalker, CG Duelist, LE Assassin, LE* Nightshade,
	#      LG* Unseen Warden, N Saboteur, LG Nightwatch, CG* Informant (round 3)
	"saboteur": {"name": "Saboteur", "tier": "advanced", "base": "rogue", "region": "N",
		"stats": {"hp": 125, "atk": 24, "def": 12, "mag": 10, "spd": 24},
		"growth": {"hp": 12, "atk": 2.4, "def": 1.1, "mag": 0.6, "spd": 1.7},
		"crit": 0.15, "charge_on_act": 40, "charge_on_hit": 1.2, "start_charge": 40,
		"basic": "stab", "ability": "cut_the_ropes", "preferred_col": 0},
	"nightwatch": {"name": "Nightwatch", "tier": "advanced", "base": "rogue", "region": "LG",
		"stats": {"hp": 140, "atk": 22, "def": 17, "mag": 8, "spd": 20},
		"growth": {"hp": 14, "atk": 2.2, "def": 1.6, "mag": 0.4, "spd": 1.2},
		"crit": 0.12, "charge_on_act": 40, "charge_on_hit": 1.4, "start_charge": 40,
		"basic": "stab", "ability": "keep_watch", "preferred_col": 0},
	"informant": {"name": "Informant", "tier": "advanced", "base": "rogue", "region": "CG*",
		"stats": {"hp": 120, "atk": 10, "def": 11, "mag": 26, "spd": 24},
		"growth": {"hp": 11, "atk": 0.6, "def": 1.0, "mag": 2.8, "spd": 1.6},
		"crit": 0.05, "charge_on_act": 40, "charge_on_hit": 1.2, "start_charge": 40,
		"basic": "stab", "ability": "read_the_orders", "preferred_col": 1},
	"duelist": {"name": "Duelist", "tier": "advanced", "base": "rogue", "region": "CG",
		"stats": {"hp": 140, "atk": 28, "def": 12, "mag": 10, "spd": 17},
		"growth": {"hp": 13, "atk": 3.0, "def": 1.4, "mag": 0.5, "spd": 0.7},
		"crit": 0.22, "charge_on_act": 40, "charge_on_hit": 1.6, "start_charge": 40,
		"basic": "stab", "ability": "riposte", "preferred_col": 0},
	"assassin": {"name": "Assassin", "tier": "advanced", "base": "rogue", "region": "LE",
		"stats": {"hp": 130, "atk": 30, "def": 11, "mag": 10, "spd": 18},
		"growth": {"hp": 12.5, "atk": 3.5, "def": 1.0, "mag": 0.5, "spd": 0.7},
		"crit": 0.25, "charge_on_act": 40, "charge_on_hit": 1.2, "start_charge": 40,
		"basic": "stab", "ability": "execute", "preferred_col": 0},
	"cutpurse": {"name": "Cutpurse", "tier": "advanced", "base": "rogue", "region": "CE",
		"stats": {"hp": 125, "atk": 27, "def": 11, "mag": 10, "spd": 22},
		"growth": {"hp": 12, "atk": 2.8, "def": 1.0, "mag": 0.5, "spd": 1.5},
		"crit": 0.2, "charge_on_act": 40, "charge_on_hit": 1.2, "start_charge": 40,
		"basic": "stab", "ability": "pilfer", "preferred_col": 0},
	"fadewalker": {"name": "Fadewalker", "tier": "advanced", "base": "rogue", "region": "CE*",
		"stats": {"hp": 120, "atk": 29, "def": 10, "mag": 10, "spd": 22},
		"growth": {"hp": 11, "atk": 3.2, "def": 0.9, "mag": 0.5, "spd": 1.4},
		"crit": 0.25, "charge_on_act": 40, "charge_on_hit": 1.2, "start_charge": 40,
		"basic": "stab", "ability": "vanishing_cut", "preferred_col": 0},
	"nightshade": {"name": "Nightshade", "tier": "advanced", "base": "rogue", "region": "LE*",
		"stats": {"hp": 125, "atk": 20, "def": 10, "mag": 22, "spd": 18},
		"growth": {"hp": 12, "atk": 1.5, "def": 0.9, "mag": 2.4, "spd": 1.0},
		"crit": 0.15, "charge_on_act": 40, "charge_on_hit": 1.2, "start_charge": 40,
		"basic": "stab", "ability": "slow_venom", "preferred_col": 0},
	"unseen_warden": {"name": "Unseen Warden", "tier": "advanced", "base": "rogue", "region": "LG*",
		"stats": {"hp": 140, "atk": 18, "def": 18, "mag": 10, "spd": 21},
		"growth": {"hp": 14, "atk": 1.5, "def": 1.9, "mag": 0.6, "spd": 1.4},
		"crit": 0.1, "charge_on_act": 40, "charge_on_hit": 1.4, "start_charge": 40,
		"basic": "stab", "ability": "unseen_arrest", "preferred_col": 0},

	# ---- Healer (start LG): LG Cleric, N Threadmender, LG* Lumenward, CG Rekindler, LE Tithekeeper,
	#      CG* Wickburner, LE* Confessor, CE* Gravecaller (replaces the dropped Necromancer),
	#      CE Bloodletter
	"cleric": {"name": "Cleric", "tier": "advanced", "base": "healer", "region": "LG",
		"stats": {"hp": 145, "atk": 10, "def": 14, "mag": 25, "spd": 11},
		"growth": {"hp": 13, "atk": 0.5, "def": 1.5, "mag": 2.5, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 50, "charge_on_hit": 1.0, "start_charge": 25,
		"basic": "smite", "ability": "sanctuary", "preferred_col": 1},
	"threadmender": {"name": "Threadmender", "tier": "advanced", "base": "healer", "region": "N",
		"stats": {"hp": 160, "atk": 8, "def": 12, "mag": 26, "spd": 11},
		"growth": {"hp": 15, "atk": 0.5, "def": 1.2, "mag": 2.4, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 50, "charge_on_hit": 1.2, "start_charge": 25,
		"basic": "smite", "ability": "bind_lives", "preferred_col": 1},
	"lumenward": {"name": "Lumenward", "tier": "advanced", "base": "healer", "region": "LG*",
		"stats": {"hp": 140, "atk": 8, "def": 17, "mag": 25, "spd": 11},
		"growth": {"hp": 12, "atk": 0.5, "def": 1.8, "mag": 2.4, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 50, "charge_on_hit": 1.0, "start_charge": 25,
		"basic": "smite", "ability": "lumen_ward", "preferred_col": 1},
	"rekindler": {"name": "Rekindler", "tier": "advanced", "base": "healer", "region": "CG",
		"stats": {"hp": 155, "atk": 8, "def": 12, "mag": 27, "spd": 11},
		"growth": {"hp": 14, "atk": 0.5, "def": 1.2, "mag": 2.6, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 50, "charge_on_hit": 1.0, "start_charge": 25,
		"basic": "smite", "ability": "rekindle", "preferred_col": 1},
	"tithekeeper": {"name": "Tithekeeper", "tier": "advanced", "base": "healer", "region": "LE",
		"stats": {"hp": 165, "atk": 8, "def": 17, "mag": 20, "spd": 11},
		"growth": {"hp": 16, "atk": 0.5, "def": 1.6, "mag": 1.8, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 50, "charge_on_hit": 1.2, "start_charge": 25,
		"basic": "smite", "ability": "tithe", "preferred_col": 1},
	"wickburner": {"name": "Wickburner", "tier": "advanced", "base": "healer", "region": "CG*",
		"stats": {"hp": 170, "atk": 8, "def": 10, "mag": 26, "spd": 11},
		"growth": {"hp": 17, "atk": 0.5, "def": 0.8, "mag": 2.4, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 50, "charge_on_hit": 1.4, "start_charge": 25,
		"basic": "smite", "ability": "burn_to_mend", "preferred_col": 1},
	"confessor": {"name": "Confessor", "tier": "advanced", "base": "healer", "region": "LE*",
		"stats": {"hp": 140, "atk": 8, "def": 16, "mag": 26, "spd": 11},
		"growth": {"hp": 12, "atk": 0.5, "def": 1.6, "mag": 2.6, "spd": 0.4},
		"crit": 0.06, "charge_on_act": 45, "charge_on_hit": 1.2, "start_charge": 30,
		"basic": "smite", "ability": "brand_of_flame", "preferred_col": 1},
	"gravecaller": {"name": "Gravecaller", "tier": "advanced", "base": "healer", "region": "CE*",
		"stats": {"hp": 140, "atk": 9, "def": 12, "mag": 29, "spd": 11},
		"growth": {"hp": 12, "atk": 0.5, "def": 1.2, "mag": 3.0, "spd": 0.4},
		"crit": 0.08, "charge_on_act": 45, "charge_on_hit": 1.4, "start_charge": 30,
		"basic": "smite", "ability": "raise_husk", "preferred_col": 1},
	"bloodletter": {"name": "Bloodletter", "tier": "advanced", "base": "healer", "region": "CE",
		"stats": {"hp": 140, "atk": 8, "def": 11, "mag": 31, "spd": 11},
		"growth": {"hp": 12, "atk": 0.5, "def": 1.1, "mag": 3.1, "spd": 0.4},
		"crit": 0.06, "charge_on_act": 45, "charge_on_hit": 1.2, "start_charge": 25,
		"basic": "smite", "ability": "bloodletting", "preferred_col": 1},

	# ---- Mage (start CG): CG Stormwake, N Archmage, CG* Starcaller, LG Lampwright, CE Warlock,
	#      LE Runebinder, LG* Chronist, CE* Wildfire, LE* Reliquarist (id enshriner)
	"archmage": {"name": "Archmage", "tier": "advanced", "base": "mage", "region": "N",
		"stats": {"hp": 120, "atk": 8, "def": 10, "mag": 31, "spd": 11},
		"growth": {"hp": 11, "atk": 0.5, "def": 1.0, "mag": 3.4, "spd": 0.4},
		"crit": 0.08, "charge_on_act": 35, "charge_on_hit": 1.0, "start_charge": 35,
		"basic": "bolt", "ability": "meteor", "preferred_col": 1},
	"warlock": {"name": "Warlock", "tier": "advanced", "base": "mage", "region": "CE",
		"stats": {"hp": 125, "atk": 8, "def": 10, "mag": 30, "spd": 11},
		"growth": {"hp": 12, "atk": 0.5, "def": 1.0, "mag": 3.2, "spd": 0.4},
		"crit": 0.08, "charge_on_act": 35, "charge_on_hit": 1.4, "start_charge": 35,
		"basic": "bolt", "ability": "hexfire", "preferred_col": 1},
	"stormwake": {"name": "Stormwake", "tier": "advanced", "base": "mage", "region": "CG",
		"stats": {"hp": 115, "atk": 7, "def": 9, "mag": 30, "spd": 15},
		"growth": {"hp": 10, "atk": 0.5, "def": 0.8, "mag": 3.4, "spd": 0.8},
		"crit": 0.08, "charge_on_act": 35, "charge_on_hit": 1.0, "start_charge": 35,
		"basic": "bolt", "ability": "chain_storm", "preferred_col": 1},
	"starcaller": {"name": "Starcaller", "tier": "advanced", "base": "mage", "region": "CG*",
		"stats": {"hp": 120, "atk": 7, "def": 10, "mag": 31, "spd": 12},
		"growth": {"hp": 11, "atk": 0.5, "def": 1.0, "mag": 3.4, "spd": 0.4},
		"crit": 0.08, "charge_on_act": 40, "charge_on_hit": 1.0, "start_charge": 35,
		"basic": "bolt", "ability": "draw_star", "preferred_col": 1},
	"lampwright": {"name": "Lampwright", "tier": "advanced", "base": "mage", "region": "LG",
		"stats": {"hp": 125, "atk": 7, "def": 14, "mag": 27, "spd": 11},
		"growth": {"hp": 12, "atk": 0.5, "def": 1.4, "mag": 2.8, "spd": 0.4},
		"crit": 0.06, "charge_on_act": 35, "charge_on_hit": 1.2, "start_charge": 35,
		"basic": "bolt", "ability": "column_ward", "preferred_col": 1},
	"runebinder": {"name": "Runebinder", "tier": "advanced", "base": "mage", "region": "LE",
		"stats": {"hp": 120, "atk": 7, "def": 10, "mag": 31, "spd": 12},
		"growth": {"hp": 11, "atk": 0.5, "def": 1.0, "mag": 3.4, "spd": 0.4},
		"crit": 0.08, "charge_on_act": 35, "charge_on_hit": 1.0, "start_charge": 35,
		"basic": "bolt", "ability": "rune_seal", "preferred_col": 1},
	"chronist": {"name": "Chronist", "tier": "advanced", "base": "mage", "region": "LG*",
		"stats": {"hp": 115, "atk": 7, "def": 9, "mag": 29, "spd": 16},
		"growth": {"hp": 10, "atk": 0.5, "def": 0.8, "mag": 3.2, "spd": 1.0},
		"crit": 0.08, "charge_on_act": 35, "charge_on_hit": 1.0, "start_charge": 35,
		"basic": "bolt", "ability": "slow_field", "preferred_col": 1},
	"wildfire": {"name": "Wildfire", "tier": "advanced", "base": "mage", "region": "CE*",
		"stats": {"hp": 120, "atk": 7, "def": 10, "mag": 31, "spd": 12},
		"growth": {"hp": 11, "atk": 0.5, "def": 1.0, "mag": 3.4, "spd": 0.4},
		"crit": 0.08, "charge_on_act": 35, "charge_on_hit": 1.2, "start_charge": 35,
		"basic": "bolt", "ability": "wildfire", "preferred_col": 1},
	# stable id "enshriner"; renamed Reliquarist in round 3 (the name lives only here, in data)
	"enshriner": {"name": "Reliquarist", "tier": "advanced", "base": "mage", "region": "LE*",
		"stats": {"hp": 125, "atk": 7, "def": 14, "mag": 27, "spd": 11},
		"growth": {"hp": 12, "atk": 0.5, "def": 1.4, "mag": 2.8, "spd": 0.4},
		"crit": 0.06, "charge_on_act": 35, "charge_on_hit": 1.2, "start_charge": 35,
		"basic": "bolt", "ability": "enshrine", "preferred_col": 1,
		"provisional": "Seal rules (a)-(d) are PROVISIONAL; the user will settle them in playtesting (round 3)."},

	# ================= LEGENDARY (illustrative) =================
	# PROVISIONAL parent: Paladin retired in round 2; Lightsworn (same region) is the proposed parent
	"lantern_saint": {"name": "Lantern Saint", "tier": "legendary", "base": "fighter", "advances_from": "lightsworn",
		"provisional": "Parent class Lightsworn is a proposal (Paladin retired, round 2); the user hasn't confirmed it.",
		"stats": {"hp": 280, "atk": 34, "def": 30, "mag": 18, "spd": 11},
		"growth": {"hp": 24, "atk": 3.0, "def": 3.0, "mag": 1.5, "spd": 0.5},
		"crit": 0.06, "charge_on_act": 35, "charge_on_hit": 2.0, "start_charge": 30,
		"basic": "strike", "ability": "lantern_oath", "preferred_col": 0},

	# ================= VAULT MONSTERS =================
	"hollow_rat": {"name": "Hollow Rat", "tier": "monster", "base": "hollow_rat",
		"stats": {"hp": 69, "atk": 14, "def": 6, "mag": 4, "spd": 15},
		"growth": {"hp": 10, "atk": 1.8, "def": 0.8, "mag": 0.3, "spd": 0.5},
		"crit": 0.1, "charge_on_act": 40, "charge_on_hit": 1.2, "start_charge": 30,
		"basic": "claw", "ability": "gnaw", "preferred_col": 0},
	"fading_wisp": {"name": "Fading Wisp", "tier": "monster", "base": "fading_wisp",
		"stats": {"hp": 63, "atk": 4, "def": 6, "mag": 17, "spd": 11},
		"growth": {"hp": 8, "atk": 0.3, "def": 0.7, "mag": 2.0, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 35, "charge_on_hit": 1.0, "start_charge": 30,
		"basic": "flicker", "ability": "unravel", "preferred_col": 1},
	"stone_sentinel": {"name": "Stone Sentinel", "tier": "monster", "base": "stone_sentinel",
		"stats": {"hp": 195, "atk": 15, "def": 20, "mag": 6, "spd": 6},
		"growth": {"hp": 23, "atk": 1.5, "def": 2.5, "mag": 0.5, "spd": 0.3},
		"crit": 0.03, "charge_on_act": 30, "charge_on_hit": 2.4, "start_charge": 20,
		"basic": "slam", "ability": "quake", "preferred_col": 0},
	"memory_wraith": {"name": "Memory Wraith", "tier": "monster", "base": "memory_wraith",
		"stats": {"hp": 98, "atk": 8, "def": 8, "mag": 18, "spd": 12},
		"growth": {"hp": 12, "atk": 0.5, "def": 0.8, "mag": 2.2, "spd": 0.5},
		"crit": 0.05, "charge_on_act": 40, "charge_on_hit": 1.2, "start_charge": 30,
		"basic": "flicker", "ability": "siphon", "preferred_col": 1},
	"shard_golem": {"name": "Shard Golem", "tier": "monster", "base": "shard_golem",
		"stats": {"hp": 368, "atk": 22, "def": 18, "mag": 18, "spd": 7},
		"growth": {"hp": 34, "atk": 2.5, "def": 2.0, "mag": 2.0, "spd": 0.3},
		"crit": 0.05, "charge_on_act": 30, "charge_on_hit": 1.6, "start_charge": 20,
		"basic": "slam", "ability": "shard_burst", "preferred_col": 0},
}

const BASE_CLASS_IDS := ["fighter", "rogue", "healer", "mage"]

## Ruling 8 (user, 2026-10-06): one stat budget per base class. Every advanced class of a base
## spends the same level-1 total and the same growth total; the classes differ only in how it is
## spread (their lean). Total = Σ stat × weight: HP counts 1/5 (it runs ~5× the other stats), the
## others 1. Crit and charge rates are class identity, not budget. The numbers are the mean of the
## live advanced classes of each base before the rule (tests/test_rulings.gd checks every class).
const BUDGET_WEIGHTS := {"hp": 0.2, "atk": 1.0, "def": 1.0, "mag": 1.0, "spd": 1.0}
const BUDGET := {
	"fighter": {"stats": 104, "growth": 10.0},
	"rogue": {"stats": 95, "growth": 8.2},
	"healer": {"stats": 89, "growth": 7.5},
	"mage": {"stats": 84, "growth": 7.5},
}

## Renamed or replaced class ids: saved heroes, Echoes and pools load as the new class.
## Necromancer was dropped by the user (round-1 verdicts); Gravecaller holds its corner.
## Paladin was retired in round 2; Lightsworn holds its region (Mercy+Order quad).
const CLASS_RENAMES := {"necromancer": "gravecaller", "paladin": "lightsworn"}
const MONSTER_IDS := ["hollow_rat", "fading_wisp", "stone_sentinel", "memory_wraith", "shard_golem"]
