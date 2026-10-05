extends "res://tests/test_case.gd"

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Echo = preload("res://core/echo.gd")
const Rng = preload("res://core/rng.gd")
const GameData = preload("res://core/game_data.gd")


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


func test_unlocks_round_trip() -> void:
	var p := PartyGen.demo_party()
	p["unlocked_formations"] = ["kindred", "seawall"]
	var e := Echo.make(p)
	eq(e["unlocked_formations"], ["kindred", "seawall"], "Echo records the unlocks used")
	var back: Dictionary = Echo.from_json(Echo.to_json(e))
	check(not back.has("error"), "parses: %s" % back.get("error", ""))
	eq(back["echo"]["unlocked_formations"], ["kindred", "seawall"], "unlocks survive JSON")
	eq(int(back["echo"]["version"]), 2, "Echo v2")
	# the replay fights with the recorded unlocks, identically
	var foe := PartyGen.demo_rival()
	eq(JSON.stringify(CombatSim.simulate(4, p, foe)["events"]), JSON.stringify(CombatSim.simulate(4, back["echo"], foe)["events"]),
		"replay with recorded unlocks matches the live fight")
	# a locked shape in the recorded set fights as Strays
	var wall := {"heroes": [hero("fighter", 0, 0), hero("fighter", 0, 1), hero("rogue", 0, 2), hero("rogue", 0, 3)],
		"unlocked_formations": ["kindred"]}
	var we: Dictionary = Echo.from_json(Echo.to_json(Echo.make(wall)))["echo"]
	var wf: Dictionary = CombatSim.simulate(1, we, foe)["events"][0]["sides"][0]["formation"]
	check(wf["id"] == "kindred" and wf["state"] == "locked_fallback", "locked Seawall Echo falls back to its unlocked Kindred part")


func test_v1_echo_loads_with_default_unlocks() -> void:
	var v1 := '{"format":"echoing_depths.echo","version":1,"heroes":[{"class":"fighter","level":1,"slot":[0,0]},{"class":"mage","level":1,"slot":[1,0]}]}'
	var res := Echo.from_json(v1)
	check(not res.has("error"), "v1 Echo still loads: %s" % res.get("error", ""))
	eq(res["echo"]["unlocked_formations"], GameData.Formations.DEFAULT_UNLOCKED, "v1 Echo gets the default unlocked set")
	eq(int(res["echo"]["version"]), 2, "migrated to v2")


func test_bad_unlocks_rejected() -> void:
	for bad in ['"x"', '["kindred", 5]', '["nope"]']:
		var txt := '{"format":"echoing_depths.echo","version":2,"unlocked_formations":%s,"heroes":[{"class":"fighter","level":1,"slot":[0,0]},{"class":"mage","level":1,"slot":[1,0]}]}' % bad
		check(Echo.from_json(txt).has("error"), "rejected unlocked_formations %s" % bad)
