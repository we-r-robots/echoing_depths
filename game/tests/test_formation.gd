extends "res://tests/test_case.gd"

const CombatSim = preload("res://core/combat_sim.gd")
const Formation = preload("res://core/formation.gd")
const GameData = preload("res://core/game_data.gd")


func test_shapes_detected() -> void:
	eq(Formation.detect([[0, 0], [0, 1], [0, 2], [0, 3]])["id"], "wall", "4 front = Wall")
	eq(Formation.detect([[1, 0], [1, 1], [1, 2], [1, 3]])["id"], "rearguard", "4 back = Rearguard")
	eq(Formation.detect([[0, 2], [0, 3], [1, 2], [1, 3]])["id"], "square", "square anywhere vertically")
	eq(Formation.detect([[0, 2], [1, 1], [1, 2], [1, 3]])["id"], "shield", "T: 3 back + 1 front = Shield")
	eq(Formation.detect([[0, 1], [0, 2], [0, 3], [1, 2]])["id"], "anvil", "T: 3 front + 1 back = Anvil")
	eq(Formation.detect([[0, 1], [0, 2], [0, 3], [1, 3]])["id"], "vanguard", "mirrored L matches")
	eq(Formation.detect([[0, 2], [0, 1], [1, 1], [1, 0]])["id"], "staggered", "Z matches S via mirror")
	eq(Formation.detect([[0, 0], [0, 3], [1, 1], [1, 2]])["id"], "loose_ranks", "unknown shape -> fallback")
	eq(Formation.detect([[0, 2], [1, 2]])["id"], "shadowing", "2-hero shape")


func test_every_formation_has_buff_and_debuff() -> void:
	var all: Array = GameData.Formations.SHAPES.duplicate()
	all.append(GameData.Formations.FALLBACK)
	for s: Dictionary in all:
		var buffs: Array = s["buffs"]
		var debuffs: Array = s["debuffs"]
		check(buffs.size() >= 1 and debuffs.size() >= 1, "%s has a buff and a debuff" % s["id"])
		for m: Dictionary in buffs:
			check(float(m["value"]) > 0.0, "%s buff is positive" % s["id"])
		for m: Dictionary in debuffs:
			check(float(m["value"]) < 0.0, "%s debuff is negative" % s["id"])


func test_formation_applies_to_stats() -> void:
	var wall := party([hero("fighter", 0, 0), hero("fighter", 0, 1), hero("fighter", 0, 2), hero("fighter", 0, 3)])
	var r := CombatSim.simulate(1, wall, party([hero("hollow_rat", 0, 0)]))
	var u := unit_stats(r, 0)
	var base := int(GameData.get_class_def("fighter")["stats"]["def"])
	# Wall +20% Def, Shield Brothers (2+ fighters) +10% Def
	eq(int(u["def"]), floori(base * (1.0 + 0.30 + 0.10)), "Wall (+30%) + Shield Brothers (+10%) Def")
	eq(r["events"][0]["sides"][0]["formation"]["id"], "wall", "formation reported in fight_start")
	var hit: Dictionary = {}
	for d: Dictionary in of_type(r, "damage"):
		if int(d["dst"]) < 4:
			hit = d
			break
	var fm := mod(hit, "formation")
	eq(String(fm.get("source", "")), "formation:wall", "hit names its dominant formation source")
	check(float(fm.get("mult", 1.0)) < 1.0, "a defensive buff shows as a multiplier below 1")
	eq(int(fm.get("side", -1)), 0, "modifier names the side whose formation caused it")


func test_compositions() -> void:
	var ids: Array = []
	for c: Dictionary in Formation.compositions(["fighter", "rogue", "healer", "mage"]):
		ids.append(c["id"])
	eq(ids, ["well_rounded"], "four different classes -> Well Rounded")
	ids.clear()
	for c: Dictionary in Formation.compositions(["fighter", "fighter", "mage"]):
		ids.append(c["id"])
	eq(ids, ["shield_brothers"], "two fighters -> Shield Brothers")
	# advanced classes count as their base class; monsters never trigger
	var r := CombatSim.simulate(1, party([hero("paladin", 0, 0), hero("fighter", 0, 1)]),
		party([hero("hollow_rat", 0, 0), hero("hollow_rat", 0, 1)]))
	eq((r["events"][0]["sides"][0]["compositions"] as Array).size(), 1, "paladin + fighter = Shield Brothers")
	eq((r["events"][0]["sides"][1]["compositions"] as Array).size(), 0, "monsters get no composition buffs")
