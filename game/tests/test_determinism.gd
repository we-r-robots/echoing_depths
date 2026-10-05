extends "res://tests/test_case.gd"

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Rng = preload("res://core/rng.gd")


func _parties(seed_value: int) -> Array:
	var rng := Rng.new(seed_value)
	return [PartyGen.random_party(rng), PartyGen.random_party(rng)]


func test_same_seed_identical_bytes() -> void:
	for s in [1, 2, 3, 42, 9001]:
		var p := _parties(s)
		var a := JSON.stringify(CombatSim.simulate(s, p[0], p[1]), "", true)
		var b := JSON.stringify(CombatSim.simulate(s, p[0], p[1]), "", true)
		check(a == b, "seed %d: two runs byte-identical" % s)
	# also identical when the parties are rebuilt from scratch
	var p1 := _parties(5)
	var p2 := _parties(5)
	eq(JSON.stringify(CombatSim.simulate(5, p1[0], p1[1]), "", true),
		JSON.stringify(CombatSim.simulate(5, p2[0], p2[1]), "", true), "rebuilt inputs give identical result")


func test_different_seed_differs() -> void:
	var p := _parties(8)
	var a := JSON.stringify(CombatSim.simulate(100, p[0], p[1])["events"])
	var b := JSON.stringify(CombatSim.simulate(101, p[0], p[1])["events"])
	check(a != b, "different seeds produce different fights")


func test_hero_order_irrelevant() -> void:
	var p := _parties(9)
	var shuffled: Dictionary = p[0].duplicate(true)
	(shuffled["heroes"] as Array).reverse()
	eq(JSON.stringify(CombatSim.simulate(3, shuffled, p[1]), "", true),
		JSON.stringify(CombatSim.simulate(3, p[0], p[1]), "", true), "hero list order does not matter (sorted by slot)")


func test_log_off_same_outcome() -> void:
	var p := _parties(10)
	var a := CombatSim.simulate(4, p[0], p[1])
	var b := CombatSim.simulate(4, p[0], p[1], {"log": false})
	eq(b["winner"], a["winner"], "winner identical without event log")
	eq(b["duration_ms"], a["duration_ms"], "duration identical without event log")
	eq((b["events"] as Array).size(), 0, "no events when log is off")


func test_inputs_not_mutated() -> void:
	var p := _parties(11)
	var before := JSON.stringify(p, "", true)
	CombatSim.simulate(1, p[0], p[1])
	eq(JSON.stringify(p, "", true), before, "simulate does not mutate its inputs")
