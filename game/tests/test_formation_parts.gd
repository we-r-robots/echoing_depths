extends "res://tests/test_case.gd"
## Every formation part counts (05-formations.md, user decision 2026-10-06): a partly connected
## side fights with every connected part that yields a shape, each on its own heroes.

const CombatSim = preload("res://core/combat_sim.gd")
const Echo = preload("res://core/echo.gd")
const Formation = preload("res://core/formation.gd")
const GameData = preload("res://core/game_data.gd")
const HeroStats = preload("res://core/hero_stats.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Rng = preload("res://core/rng.gd")

const ALL := ["kindred", "vigil", "lamplight", "tidebreak", "choir", "keystone", "hearth", "seawall",
	"lumari_chorus", "vault_door", "crescent", "lighthouse", "keepers_ring", "shardpoint", "echo_step"]


static func _fx(cells: Array, unlocked: Array = GameData.Formations.DEFAULT_UNLOCKED) -> Dictionary:
	var hs: Array = []
	for c: Array in cells:
		hs.append({"slot": c})
	return Formation.effective({"heroes": hs, "unlocked_formations": unlocked})


static func _ids(fx: Dictionary) -> Array:
	var out: Array = []
	for p: Dictionary in fx["parts"]:
		out.append(String(p["effective"]["id"]))
	return out


## The playtest case: Vael F1 + Ash F2 (Kindred), Brakka B3 + Corin B4 (Vigil).
static func _two_pairs(cls_front := "fighter", cls_back := "mage") -> Dictionary:
	return party([hero(cls_front, 0, 0, 3), hero(cls_front, 0, 1, 3), hero(cls_back, 1, 2, 3), hero(cls_back, 1, 3, 3)])


func test_two_pairs_both_count() -> void:
	var fx := _fx([[0, 0], [0, 1], [1, 2], [1, 3]])
	eq(String(fx["state"]), "parts", "two separate pairs: state parts")
	eq(_ids(fx), ["kindred", "vigil"], "Kindred and Vigil both count, in slot order")
	eq(String(fx["effective"]["name"]), "Kindred + Vigil", "the summary names both parts")
	check((fx["effective"]["bonus"] as Array).is_empty(), "the summary entry has no bonus of its own")
	eq(fx["parts"][0]["sub_cells"], [[0, 0], [0, 1]], "Kindred's heroes")
	eq(fx["parts"][1]["sub_cells"], [[1, 2], [1, 3]], "Vigil's heroes")
	eq(Formation.part_of(fx, [1, 3]), 1, "part_of finds the Vigil hero")
	# the old rule (Echoes recorded before the change) still calls it Unformed
	var hs: Array = []
	for c: Array in [[0, 0], [0, 1], [1, 2], [1, 3]]:
		hs.append({"slot": c})
	var old := Formation.effective({"heroes": hs, "formation_rule": "single"})
	check(String(old["state"]) == "unformed" and (old["parts"] as Array).is_empty(), "old rule: Unformed")


func test_two_pairs_in_combat() -> void:
	var a := _two_pairs("hollow_rat", "hollow_rat")   # monsters: no class compositions in the numbers
	var r := CombatSim.simulate(3, a, party([hero("hollow_rat", 0, 0)]))
	var f: Dictionary = r["events"][1]["formation"]
	eq(String(f["state"]), "parts", "banner state parts")
	eq((f["parts"] as Array).size(), 2, "banner lists both parts")
	eq(String(f["parts"][0]["id"]), "kindred", "first part Kindred")
	eq(String(f["parts"][1]["behaviour"]["id"]), "covering_fire", "second part's behaviour is Vigil's")
	eq(f["parts"][0]["uids"], [0, 1], "Kindred's units")
	eq(f["parts"][1]["uids"], [2, 3], "Vigil's units")
	var st := HeroStats.compute(hero("hollow_rat", 0, 0, 3))
	eq(int(unit_stats(r, 0)["def"]), floori(float(st["def"]) * 1.10), "Kindred: front Def +10% on its heroes")
	eq(int(unit_stats(r, 0)["mag"]), int(st["mag"]), "no Vigil Mag on the Kindred heroes")
	eq(int(unit_stats(r, 2)["mag"]), floori(float(st["mag"]) * 1.10), "Vigil: Mag +10% on its heroes")
	eq(int(unit_stats(r, 2)["def"]), int(st["def"]), "no Kindred Def on the Vigil heroes")


func test_behaviours_stay_inside_their_part() -> void:
	var rng := Rng.new(77)
	var shoulder := 0
	for i in 40:
		var a := _two_pairs("fighter", "mage")
		var r := CombatSim.simulate(i, a, PartyGen.random_party(rng, {"size": 4}))
		for ev: Dictionary in of_type(r, "formation_proc"):
			if int(ev["side"]) != 0 or String(ev["stat"]) != "":
				continue
			var uid := int(ev["uid"])
			match String(ev["effect"]):
				"shoulder_to_shoulder":
					shoulder += 1
					check(uid <= 1 and String(ev["source"]) == "formation:kindred", "shoulder to shoulder only charges Kindred heroes")
				"covering_fire":
					check(uid >= 2 and String(ev["source"]) == "formation:vigil", "covering fire only from Vigil heroes")
	check(shoulder > 0, "Kindred's behaviour fires in a two-part side (%d)" % shoulder)


func test_pair_plus_trio() -> void:
	# Keystone F0 F1 B0 and Lamplight F3 B3 (five units: a monster side)
	var cells := [[0, 0], [0, 1], [1, 0], [0, 3], [1, 3]]
	var fx := _fx(cells, ALL)
	eq(String(fx["state"]), "parts", "pair + trio: parts")
	eq(_ids(fx), ["keystone", "lamplight"], "Keystone and Lamplight both count")
	var hs: Array = []
	for c: Array in cells:
		hs.append(hero("hollow_rat", int(c[0]), int(c[1]), 3))
	var p := party(hs)
	p["unlocked_formations"] = ALL
	var r := CombatSim.simulate(5, p, party([hero("hollow_rat", 0, 0)]))
	var f: Dictionary = r["events"][1]["formation"]
	eq((f["parts"] as Array).size(), 2, "banner lists both parts")
	var st := HeroStats.compute(hero("hollow_rat", 0, 0, 3))
	eq(int(unit_stats(r, uid_at(r, 0, 0, 0))["atk"]), floori(float(st["atk"]) * 1.10), "Keystone front Atk +10%")
	eq(int(unit_stats(r, uid_at(r, 0, 0, 3))["atk"]), int(st["atk"]), "the Lamplight front gets no Keystone Atk")
	eq(int(unit_stats(r, uid_at(r, 0, 1, 3))["mag"]), floori(float(st["mag"]) * 1.10), "Lamplight back Mag +10%")
	eq(int(unit_stats(r, uid_at(r, 0, 1, 0))["mag"]), int(st["mag"]), "the Keystone flanker gets no Lamplight Mag")


func test_locked_part_falls_back() -> void:
	# a locked Keystone part next to an unlocked Lamplight part: Keystone fights as Kindred
	var fx := _fx([[0, 0], [0, 1], [1, 0], [0, 3], [1, 3]])
	eq(String(fx["state"]), "parts", "two counting parts")
	var k: Dictionary = fx["parts"][0]
	check(String(k["state"]) == "locked_fallback" and String(k["shape"]["id"]) == "keystone" and bool(k["locked"]),
		"the locked Keystone part falls back")
	eq(String(k["effective"]["id"]), "kindred", "to its largest unlocked shape, Kindred (data order)")
	eq(k["sub_cells"], [[0, 0], [0, 1]], "on the Kindred heroes only")
	eq(Formation.part_of(fx, [1, 0]), -1, "the left-out hero gets nothing")
	# four heroes: a locked Keystone and a loner -> partial
	var fx2 := _fx([[0, 0], [0, 1], [1, 0], [1, 3]])
	check(String(fx2["state"]) == "partial" and String(fx2["effective"]["id"]) == "kindred", "Keystone + loner: partial Kindred")
	# a part with no unlocked sub-shape gives nothing, while another part counts
	var fx3 := _fx([[0, 0], [0, 1], [1, 3]], ["vigil"])
	eq(String(fx3["state"]), "unformed", "no part counts: Unformed")
	var fx4 := _fx([[0, 0], [0, 1], [1, 2], [1, 3]], ["vigil"])
	eq(String(fx4["state"]), "partial", "the locked Kindred gives nothing, Vigil still counts")
	eq(_ids(fx4), ["vigil"], "only Vigil counts")


func _same_fights(shape: String, size: int, seed_base: int) -> void:
	var rng := Rng.new(seed_base)
	for i in 25:
		var a := PartyGen.random_party(rng, {"size": size, "shape": shape})
		a["unlocked_formations"] = ALL
		var b := PartyGen.random_party(rng)
		var old := a.duplicate(true)
		old["formation_rule"] = "single"
		var now := CombatSim.simulate(i, a, b)
		if String(now["events"][1]["formation"]["id"]) != shape:
			check(false, "side fights as %s" % shape)
			return
		var then := CombatSim.simulate(i, old, b)
		if JSON.stringify(now["events"]) != JSON.stringify(then["events"]):
			check(false, "%s fight %d differs between the old and new rule" % [shape, i])
			return
	check(true, "%s fights unchanged" % shape)


func test_one_four_shape_unchanged() -> void:
	for sh: String in ["seawall", "vault_door", "crescent", "lighthouse", "keepers_ring", "shardpoint", "echo_step", "lumari_chorus"]:
		_same_fights(sh, 4, hash(sh))


func test_strays_unchanged() -> void:
	_same_fights("strays", 4, 11)
	var fx := _fx([[0, 0], [1, 1], [0, 2], [1, 3]])
	check(String(fx["state"]) == "strays" and (fx["sub_cells"] as Array).is_empty(), "no two adjacent: Strays")
	eq((fx["parts"] as Array).size(), 1, "Strays is one part over every hero")


func test_saboteur_stops_every_part() -> void:
	var foe := party([hero("fighter", 0, 1, 3), hero("rogue", 0, 2, 3), hero("mage", 1, 1, 3)])
	var fired := {}
	var leaked := 0
	for i in 20:
		var free := CombatSim.simulate(i, _two_pairs("fighter", "mage"), foe)
		for ev: Dictionary in of_type(free, "formation_proc"):
			if int(ev["side"]) == 0 and String(ev["stat"]) == "":
				fired[String(ev["source"])] = true
		var sab := CombatSim.simulate(i, _two_pairs("fighter", "mage"), foe,
			{"start_statuses": _sabotage_all()})
		for ev: Dictionary in of_type(sab, "formation_proc"):
			if int(ev["side"]) == 0 and String(ev["stat"]) == "" and String(ev["source"]).begins_with("formation:"):
				leaked += 1
	check(fired.has("formation:kindred") and fired.has("formation:vigil"), "both parts' behaviours fire unsabotaged: %s" % [fired.keys()])
	eq(leaked, 0, "while sabotaged, no part's behaviour fires")


## Every hero of the two-pair side sabotaged for the whole fight (a status ends when its unit falls).
static func _sabotage_all() -> Array:
	var out: Array = []
	for sl: Array in [[0, 0], [0, 1], [1, 2], [1, 3]]:
		out.append({"side": 0, "slot": sl, "status": "sabotage", "dur_ms": 600000})
	return out


func test_parts_fights_are_deterministic() -> void:
	var rng := Rng.new(5)
	for i in 10:
		var b := PartyGen.random_party(rng)
		var x := CombatSim.simulate(i, _two_pairs(), b)
		var y := CombatSim.simulate(i, _two_pairs(), b)
		if JSON.stringify(x["events"]) != JSON.stringify(y["events"]):
			check(false, "fight %d differs between runs" % i)
			return
	check(true, "two-part fights are deterministic")


func test_old_echo_replays_under_the_old_rule() -> void:
	# a v2 Echo of the playtest placement, recorded when it was Unformed
	var v2 := '{"format":"echoing_depths.echo","version":2,"name":"Test","unlocked_formations":["kindred","vigil","lamplight","tidebreak","choir"],"heroes":[' \
		+ '{"name":"Fighter","class":"fighter","level":3,"slot":[0,0]},{"name":"Fighter","class":"fighter","level":3,"slot":[0,1]},' \
		+ '{"name":"Mage","class":"mage","level":3,"slot":[1,2]},{"name":"Mage","class":"mage","level":3,"slot":[1,3]}]}'
	var res := Echo.from_json(v2)
	check(not res.has("error"), "v2 Echo loads: %s" % res.get("error", ""))
	var echo: Dictionary = res["echo"]
	eq(String(echo["formation_rule"]), "single", "migrated with the old rule")
	var foe := PartyGen.demo_rival()
	var r := CombatSim.simulate(9, echo, foe)
	eq(String(r["events"][1]["formation"]["state"]), "unformed", "the old Echo still fights Unformed")
	var old_party := _two_pairs()
	old_party["formation_rule"] = "single"
	eq(JSON.stringify(r["events"]), JSON.stringify(CombatSim.simulate(9, old_party, foe)["events"]),
		"the old Echo replays exactly as under the old rule")
	# round trip keeps the rule; a new Echo records "parts" and replays like the live fight
	var back: Dictionary = Echo.from_json(Echo.to_json(echo))["echo"]
	eq(String(back["formation_rule"]), "single", "rule survives JSON")
	var live := _two_pairs()
	var e3: Dictionary = Echo.from_json(Echo.to_json(Echo.make(live)))["echo"]
	eq(String(e3["formation_rule"]), "parts", "new Echoes record the parts rule")
	eq(JSON.stringify(CombatSim.simulate(9, e3, foe)["events"]), JSON.stringify(CombatSim.simulate(9, live, foe)["events"]),
		"a v3 Echo replays the live fight")
	check(Echo.from_json(v2.replace('"version":2', '"version":3,"formation_rule":"nope"')).has("error"), "a bad rule is rejected")
