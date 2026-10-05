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

	# ================= ADVANCED (illustrative subset of the 36) =================
	"paladin": {"name": "Paladin", "tier": "advanced", "base": "fighter", "region": "LG",
		"stats": {"hp": 200, "atk": 25, "def": 22, "mag": 12, "spd": 10},
		"growth": {"hp": 20, "atk": 2.5, "def": 2.5, "mag": 1.0, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 30, "charge_on_hit": 2.0, "start_charge": 30,
		"basic": "strike", "ability": "aegis_strike", "preferred_col": 0},
	"berserker": {"name": "Berserker", "tier": "advanced", "base": "fighter", "region": "CE",
		"stats": {"hp": 190, "atk": 30, "def": 15, "mag": 6, "spd": 11},
		"growth": {"hp": 18, "atk": 3.5, "def": 1.5, "mag": 0.5, "spd": 0.5},
		"crit": 0.1, "charge_on_act": 35, "charge_on_hit": 2.6, "start_charge": 30,
		"basic": "strike", "ability": "rampage", "preferred_col": 0},
	"duelist": {"name": "Duelist", "tier": "advanced", "base": "rogue", "region": "CG",
		"stats": {"hp": 140, "atk": 28, "def": 13, "mag": 10, "spd": 17},
		"growth": {"hp": 13, "atk": 3.0, "def": 1.5, "mag": 0.5, "spd": 0.7},
		"crit": 0.22, "charge_on_act": 40, "charge_on_hit": 1.6, "start_charge": 40,
		"basic": "stab", "ability": "riposte", "preferred_col": 0},
	"assassin": {"name": "Assassin", "tier": "advanced", "base": "rogue", "region": "LE",
		"stats": {"hp": 125, "atk": 30, "def": 11, "mag": 10, "spd": 18},
		"growth": {"hp": 12, "atk": 3.5, "def": 1.0, "mag": 0.5, "spd": 0.7},
		"crit": 0.25, "charge_on_act": 40, "charge_on_hit": 1.2, "start_charge": 40,
		"basic": "stab", "ability": "execute", "preferred_col": 0},
	"cleric": {"name": "Cleric", "tier": "advanced", "base": "healer", "region": "LG",
		"stats": {"hp": 145, "atk": 10, "def": 14, "mag": 25, "spd": 11},
		"growth": {"hp": 13, "atk": 0.5, "def": 1.5, "mag": 2.5, "spd": 0.4},
		"crit": 0.05, "charge_on_act": 50, "charge_on_hit": 1.0, "start_charge": 25,
		"basic": "smite", "ability": "sanctuary", "preferred_col": 1},
	"necromancer": {"name": "Necromancer", "tier": "advanced", "base": "healer", "region": "CE*",
		"stats": {"hp": 140, "atk": 9, "def": 12, "mag": 28, "spd": 11},
		"growth": {"hp": 12, "atk": 0.5, "def": 1.2, "mag": 3.0, "spd": 0.4},
		"crit": 0.08, "charge_on_act": 45, "charge_on_hit": 1.4, "start_charge": 30,
		"basic": "smite", "ability": "grave_drain", "preferred_col": 1},
	"archmage": {"name": "Archmage", "tier": "advanced", "base": "mage", "region": "N",
		"stats": {"hp": 120, "atk": 8, "def": 10, "mag": 31, "spd": 11},
		"growth": {"hp": 11, "atk": 0.5, "def": 1.0, "mag": 3.5, "spd": 0.4},
		"crit": 0.08, "charge_on_act": 35, "charge_on_hit": 1.0, "start_charge": 35,
		"basic": "bolt", "ability": "meteor", "preferred_col": 1},
	"warlock": {"name": "Warlock", "tier": "advanced", "base": "mage", "region": "CE",
		"stats": {"hp": 125, "atk": 8, "def": 10, "mag": 29, "spd": 11},
		"growth": {"hp": 12, "atk": 0.5, "def": 1.0, "mag": 3.2, "spd": 0.4},
		"crit": 0.08, "charge_on_act": 35, "charge_on_hit": 1.4, "start_charge": 35,
		"basic": "bolt", "ability": "hexfire", "preferred_col": 1},

	# ================= LEGENDARY (illustrative) =================
	"lantern_saint": {"name": "Lantern Saint", "tier": "legendary", "base": "fighter", "advances_from": "paladin",
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
const MONSTER_IDS := ["hollow_rat", "fading_wisp", "stone_sentinel", "memory_wraith", "shard_golem"]
