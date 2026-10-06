extends "res://tests/test_case.gd"
## Balance gate (user design rule, 2026-10-06): an advanced class is STRONGER than its base class
## (heroes earn it by spending memories); advanced classes are sidegrades to each other, not to the
## base. Paired swap test: in the same random fight (same party, same slot, same level, same
## opponent, same seed), hero 0 plays the advanced class, then its base class. The advanced class
## must win more of those fights than the base by at least MARGIN.
##
## Also run as a report: godot --path game --headless -s res://tests/class_gate_report.gd

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const GameData = preload("res://core/game_data.gd")
const Rng = preload("res://core/rng.gd")

const MARGIN := 0.05     # advanced win rate must beat its base's by 5 percentage points
const FIGHTS := 80       # paired fights per class in the suite (the report runs more)
const LEVEL := 2


## -> {class id: {"base", "adv": wins, "base_wins": wins, "n": fights}}, every advanced class.
static func measure(fights: int, seed0: int = 5150) -> Dictionary:
	var out := {}
	var adv_ids: Array = []
	for cid: String in GameData.Classes.CLASSES:
		if String(GameData.Classes.CLASSES[cid]["tier"]) == "advanced":
			adv_ids.append(cid)
			out[cid] = {"base": String(GameData.Classes.CLASSES[cid]["base"]), "adv": 0, "base_wins": 0, "n": 0}
	var rng := Rng.new(seed0)
	for i in fights:
		var a := PartyGen.random_party(rng, {"size": 3 + i % 2})
		var foe := PartyGen.monster_group(rng, 2 + i % 7) if i % 3 == 0 else PartyGen.random_party(rng)
		for cid: String in adv_ids:
			var row: Dictionary = out[cid]
			for variant: String in [cid, String(row["base"])]:
				var p := a.duplicate(true)
				var h: Dictionary = p["heroes"][0]
				h["class"] = variant
				h["level"] = LEVEL
				var r := CombatSim.simulate(seed0 + i, p, foe, {"log": false})
				if int(r.get("winner", -1)) == 0:
					row["adv" if variant == cid else "base_wins"] = int(row["adv" if variant == cid else "base_wins"]) + 1
			row["n"] = int(row["n"]) + 1
	return out


static func stat_total(stats: Dictionary) -> float:
	var t := 0.0
	for k: String in GameData.Classes.BUDGET_WEIGHTS:
		t += float(stats[k]) * float(GameData.Classes.BUDGET_WEIGHTS[k])
	return t


func test_advanced_stat_budget_is_above_its_base() -> void:
	for b: String in GameData.Classes.BASE_CLASS_IDS:
		var c: Dictionary = GameData.get_class_def(b)
		var bud: Dictionary = GameData.Classes.BUDGET[b]
		check(float(bud["stats"]) >= stat_total(c["stats"]) * 1.2,
			"%s: advanced level-1 budget %s is clearly above the base's %.1f" % [b, bud["stats"], stat_total(c["stats"])])
		check(float(bud["growth"]) >= stat_total(c["growth"]) * 1.1,
			"%s: advanced growth budget %s is clearly above the base's %.2f" % [b, bud["growth"], stat_total(c["growth"])])


func test_every_advanced_class_beats_its_base() -> void:
	var m := measure(FIGHTS)
	for cid: String in m:
		var row: Dictionary = m[cid]
		var n := float(row["n"])
		var d := (float(row["adv"]) - float(row["base_wins"])) / n
		check(d >= MARGIN, "%s beats base %s by %+.1f pp (%d vs %d of %d paired fights; needs +%.0f)" % [cid, row["base"],
			100.0 * d, int(row["adv"]), int(row["base_wins"]), int(n), 100.0 * MARGIN])
