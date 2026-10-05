extends "res://tests/test_case.gd"

const CombatSim = preload("res://core/combat_sim.gd")
const GameData = preload("res://core/game_data.gd")


func test_full_charge_triggers_ability() -> void:
	var r := CombatSim.simulate(21, duo(hero("fighter", 0, 0, 4)), party([hero("stone_sentinel", 0, 0, 1)]))
	var full_at := -1.0
	var used := false
	for ev: Dictionary in r["events"]:
		if ev["type"] == "charge" and int(ev["uid"]) == 0 and int(ev["charge"]) >= 100 and full_at < 0.0:
			full_at = float(ev["t"])
		elif ev["type"] == "action_start" and int(ev["uid"]) == 0 and full_at >= 0.0:
			eq(ev["kind"], "ability", "first action after reaching full charge is the ability")
			eq(ev["action"], "cleave", "fighter ability")
			used = true
			break
	check(used, "fighter reached full charge and acted again")
	var spent := false
	for ev: Dictionary in of_type(r, "charge"):
		if int(ev["uid"]) == 0 and ev["reason"] == "spent":
			eq(int(ev["charge"]), 0, "charge resets after the ability")
			spent = true
			break
	check(spent, "spent charge event emitted")
	var abil := of_type(r, "ability")
	check(not abil.is_empty(), "ability event emitted")


func test_charge_on_act_rate() -> void:
	var r := CombatSim.simulate(22, duo(hero("mage", 1, 0)), duo(hero("mage", 1, 0)))
	var rate := int(round(float(GameData.get_class_def("mage")["charge_on_act"]) * float(GameData.combat()["charge_act_scale"])))
	var mult := 1.0   # duo() placements are Strays: no charge bonus
	for ev: Dictionary in of_type(r, "charge"):
		if ev["reason"] == "act" and int(ev["charge"]) < 100:
			eq(int(ev["delta"]), int(round(rate * mult)), "charge gained per basic action")
			return
	check(false, "no act charge event")


func test_charge_on_hit() -> void:
	var r := CombatSim.simulate(23, duo(hero("fighter", 0, 0)), duo(hero("fighter", 0, 0)))
	var dmg := {}
	for ev: Dictionary in r["events"]:
		if ev["type"] == "damage":
			dmg = ev
		elif ev["type"] == "action_start":
			dmg = {}
		elif ev["type"] == "charge" and ev["reason"] == "hit" and int(ev["charge"]) < 99 and not dmg.is_empty():
			var u := unit_stats(r, int(ev["uid"]))
			eq(int(ev["uid"]), int(dmg["dst"]), "hit charge goes to the damaged unit")
			var expect := int(round(float(dmg["amount"]) * 100.0 / float(u["max_hp"]) *
				float(GameData.get_class_def(String(u["class"]))["charge_on_hit"]) * float(GameData.combat()["charge_hit_scale"])))
			eq(int(ev["delta"]), expect, "charge per % HP lost")
			return
	check(false, "no hit charge event")


func test_class_charge_rates_differ() -> void:
	var rates := {}
	for cid: String in GameData.Classes.BASE_CLASS_IDS:
		rates[int(GameData.get_class_def(cid)["charge_on_act"])] = true
	check(rates.size() > 1, "base classes have different charge rates")


func test_heal_ability_never_wasted() -> void:
	var PartyGen := preload("res://core/party_gen.gd")
	var Rng := preload("res://core/rng.gd")
	var rng := Rng.new(5)
	for i in 30:
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), PartyGen.random_party(rng))
		var hp := {}
		var mx := {}
		for side: Dictionary in r["events"][0]["sides"]:
			for u: Dictionary in side["units"]:
				hp[int(u["uid"])] = int(u["hp"])
				mx[int(u["uid"])] = int(u["max_hp"])
		for ev: Dictionary in r["events"]:
			if ev["type"] == "damage" or ev["type"] == "heal":
				hp[int(ev["dst"])] = int(ev["hp"])
			elif ev["type"] == "action_start" and ev["action"] == "mend":
				var tgt := int(ev["target"])
				if hp[tgt] >= mx[tgt]:
					check(false, "Mend cast on a full-HP ally (fight %d)" % i)
					return
	check(true, "no wasted heals")
