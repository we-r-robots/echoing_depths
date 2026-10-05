extends "res://tests/test_case.gd"

const CombatSim = preload("res://core/combat_sim.gd")
const GameData = preload("res://core/game_data.gd")

const EXACT := {"tuning": {"crit_enabled": false, "damage_variance": 0.0}}


func _expected(power: float, a: int, d: int) -> int:
	var scale := float(GameData.combat()["damage_scale"])
	return maxi(1, int(round(power * scale * float(a) * float(a) / float(a + d))))


func _first_hit(r: Dictionary, src: int) -> Dictionary:
	for ev: Dictionary in of_type(r, "damage"):
		if int(ev["src"]) == src:
			return ev
	return {}


func test_physical_atk_vs_def() -> void:
	var r := CombatSim.simulate(1, duo(hero("fighter", 0, 0)), duo(hero("fighter", 0, 0, 3)), EXACT)
	var a := unit_stats(r, 0)
	var b := unit_stats(r, 2)
	var hit := _first_hit(r, 0)
	eq(hit["kind"], "physical", "fighter strike is physical")
	eq(int(hit["amount"]), _expected(1.0, int(a["atk"]), int(b["def"])), "Atk vs Def formula")
	eq(hit["crit"], false, "crits disabled")
	var back := _first_hit(r, 2)
	eq(int(back["amount"]), _expected(1.0, int(b["atk"]), int(a["def"])), "formula other direction")
	check(int(back["amount"]) > int(hit["amount"]), "higher level hits harder")


func test_magic_mag_vs_mag() -> void:
	var r := CombatSim.simulate(2, duo(hero("mage", 0, 0)), duo(hero("fighter", 0, 0)), EXACT)
	var a := unit_stats(r, 0)
	var hit := _first_hit(r, 0)
	var b := unit_stats(r, int(hit["dst"]))
	eq(hit["kind"], "magic", "bolt is magic")
	eq(int(hit["amount"]), _expected(0.8, int(a["mag"]), int(b["mag"])), "Mag vs Mag formula (target Def ignored)")


func test_back_row_halves_physical_taken() -> void:
	# B has nobody in front, so A's melee must hit B's back column at half damage.
	var r := CombatSim.simulate(3, duo(hero("fighter", 0, 0)), duo(hero("fighter", 1, 0)), EXACT)
	var a := unit_stats(r, 0)
	var b := unit_stats(r, 2)
	var hit := _first_hit(r, 0)
	eq(int(hit["dst"]), 2, "melee reaches the back column when the front is empty")
	eq(float(mod(hit, "back_row_target").get("mult", 0.0)), 0.5, "back_row_target x0.5 reported")
	var full := float(GameData.combat()["damage_scale"]) * float(a["atk"]) * float(a["atk"]) / float(int(a["atk"]) + int(b["def"]))
	eq(int(hit["amount"]), maxi(1, int(round(full * 0.5))), "half damage to back column")


func test_back_row_halves_physical_dealt() -> void:
	var r := CombatSim.simulate(3, duo(hero("fighter", 0, 0)), duo(hero("fighter", 1, 0)), EXACT)
	var a := unit_stats(r, 0)
	var b := unit_stats(r, 2)
	var hit := _first_hit(r, 2)
	eq(float(mod(hit, "back_row_attacker").get("mult", 0.0)), 0.5, "back_row_attacker x0.5 reported")
	var full := float(GameData.combat()["damage_scale"]) * float(b["atk"]) * float(b["atk"]) / float(int(b["atk"]) + int(a["def"]))
	eq(int(hit["amount"]), maxi(1, int(round(full * 0.5))), "half damage from back column")


func test_back_vs_back_quarter() -> void:
	var r := CombatSim.simulate(4, duo(hero("fighter", 1, 0)), duo(hero("fighter", 1, 0)), EXACT)
	var a := unit_stats(r, 0)
	var b := unit_stats(r, 2)
	var hit := _first_hit(r, 0)
	var full := float(GameData.combat()["damage_scale"]) * float(a["atk"]) * float(a["atk"]) / float(int(a["atk"]) + int(b["def"]))
	eq(int(hit["amount"]), maxi(1, int(round(full * 0.25))), "back attacker into back target = quarter")


func test_magic_ignores_back_row() -> void:
	var r := CombatSim.simulate(5, duo(hero("mage", 1, 0)), duo(hero("mage", 1, 0)), EXACT)
	var a := unit_stats(r, 0)
	var b := unit_stats(r, 2)
	var hit := _first_hit(r, 0)
	check(mod(hit, "back_row_target").is_empty() and mod(hit, "back_row_attacker").is_empty(), "no back-row mods on magic")
	eq(int(hit["amount"]), _expected(0.8, int(a["mag"]), int(b["mag"])), "magic unaffected by back column")


func test_crit_multiplier() -> void:
	# Find a crit stab (deterministic per seed) and compare it with formula * crit_mult.
	for seed_value in 50:
		var r := CombatSim.simulate(seed_value, duo(hero("rogue", 0, 0, 1)), party([hero("stone_sentinel", 0, 0, 1)]),
			{"tuning": {"damage_variance": 0.0}})
		var a := unit_stats(r, 0)
		var b := unit_stats(r, 2)
		for ev: Dictionary in of_type(r, "damage"):
			if int(ev["src"]) == 0 and ev["crit"] and ev["action"] == "stab":
				var full := 0.9 * float(GameData.combat()["damage_scale"]) * float(a["atk"]) * float(a["atk"]) / float(int(a["atk"]) + int(b["def"]))
				eq(int(ev["amount"]), int(round(full * float(GameData.combat()["crit_mult"]))), "crit = formula x crit_mult")
				return
	check(false, "expected at least one rogue crit in 50 seeds")


func test_items_modify_stats() -> void:
	var plain := CombatSim.simulate(1, duo(hero("fighter", 0, 0)), duo(hero("fighter", 0, 0)), EXACT)
	var armed := CombatSim.simulate(1, duo(hero("fighter", 0, 0, 1, {"weapon": "iron_sword", "armor": "chain_mail"})),
		duo(hero("fighter", 0, 0)), EXACT)
	var p := unit_stats(plain, 0)
	var q := unit_stats(armed, 0)
	check(int(q["atk"]) > int(p["atk"]), "weapon raises Atk")
	check(int(q["def"]) > int(p["def"]), "armor raises Def")
