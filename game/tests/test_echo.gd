extends "res://tests/test_case.gd"

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Echo = preload("res://core/echo.gd")
const Rng = preload("res://core/rng.gd")


func test_round_trip_json() -> void:
	var echo := Echo.make(PartyGen.demo_party(), {"owner": "tester", "depth": 3})
	var text := Echo.to_json(echo)
	var back := Echo.from_json(text)
	check(not back.has("error"), "parses: %s" % back.get("error", ""))
	var restored: Dictionary = back["echo"]
	eq(Echo.to_json(restored), text, "JSON -> Echo -> JSON is byte-identical")
	eq(typeof(restored["heroes"][0]["level"]), TYPE_INT, "levels come back as ints, not floats")
	eq(typeof(restored["heroes"][0]["slot"][0]), TYPE_INT, "slots come back as ints")
	eq(restored["version"], Echo.VERSION, "version stamped")
	eq(restored["meta"]["owner"], "tester", "meta preserved")


func test_replay_identical() -> void:
	var rng := Rng.new(3)
	for i in 10:
		var a := PartyGen.random_party(rng)
		var b := PartyGen.random_party(rng)
		var live := CombatSim.simulate(i, a, b)
		var echo_b: Dictionary = Echo.from_json(Echo.to_json(Echo.make(b)))["echo"]
		var echo_a: Dictionary = Echo.from_json(Echo.to_json(Echo.make(a)))["echo"]
		var replay := CombatSim.simulate(i, echo_a, echo_b)
		if JSON.stringify(live["events"]) != JSON.stringify(replay["events"]):
			check(false, "fight %d: Echo replay differs from live fight" % i)
			return
	check(true, "Echo replays match live fights")


func test_rejects_bad_input() -> void:
	check(Echo.from_json("{not json").has("error"), "invalid JSON rejected")
	check(Echo.from_json("[1,2]").has("error"), "non-object rejected")
	check(Echo.from_dict({"format": "other"}).has("error"), "wrong format rejected")
	var e := Echo.make(PartyGen.demo_party())
	e["version"] = Echo.VERSION + 1
	check(Echo.from_dict(e).has("error"), "newer version rejected")
	var bad := Echo.make(PartyGen.demo_party())
	bad["heroes"][1]["slot"] = bad["heroes"][0]["slot"].duplicate()
	check(Echo.from_dict(bad).has("error"), "duplicate slot rejected")
	var big := Echo.make(PartyGen.demo_party())
	big["heroes"].append(big["heroes"][0].duplicate(true))
	big["heroes"][4]["slot"] = [0, 3]
	check(Echo.from_dict(big).has("error"), "more than 4 heroes rejected")
	var unk := Echo.make(PartyGen.demo_party())
	unk["heroes"][0]["class"] = "space_wizard"
	check(Echo.from_dict(unk).has("error"), "unknown class rejected")


func test_sim_rejects_invalid_party() -> void:
	var r := CombatSim.simulate(1, {"heroes": []}, PartyGen.demo_party())
	check(r.has("error"), "empty party reported as error, not a crash")
