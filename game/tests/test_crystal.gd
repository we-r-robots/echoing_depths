extends "res://tests/test_case.gd"
## The Crystal of Remembrance (06-crystal-of-remembrance.md).

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const GameData = preload("res://core/game_data.gd")
const Rng = preload("res://core/rng.gd")


func _fight(i: int, crystal: Dictionary = {}, opts: Dictionary = {}) -> Dictionary:
	var p := PartyGen.random_party(Rng.new(1000 + i), {"advanced_chance": 0.7})
	return CombatSim.simulate_crystal(i, p, crystal, opts)


static func _crystal_uid(r: Dictionary) -> int:
	for u: Dictionary in r["events"][0]["sides"][1]["units"]:
		if u["tier"] == "crystal":
			return int(u["uid"])
	return -1


func test_fragment_thresholds_and_shard_victory() -> void:
	var wins := 0
	for i in 40:
		var r := _fight(i, {"integrity": 400})
		var frags := of_type(r, "crystal_fragment")
		for f: Dictionary in frags:
			var k := int(f["index"])
			check(int(f["integrity"]) <= 400 - 100 * k, "fragment %d only once 25%% x %d is lost (%d)" % [k, k, f["integrity"]])
		eq(int(r["fragments"]), frags.size(), "result counts the fragments")
		eq(int(r["events"][-1]["fragments"]), frags.size(), "fight_end counts the fragments")
		if r["reason"] == "shard":
			wins += 1
			eq(int(r["winner"]), 0, "shard is a party victory")
			eq(frags.size(), 4, "the fourth fragment frees the Shard")
		else:
			check(frags.size() < 4 and int(r["winner"]) == 1, "defeat before the fourth fragment")
	check(wins > 0 and wins < 40, "both victories and defeats happen (%d/40)" % wins)


func test_defeat_reports_fragments() -> void:
	var seen := false
	for i in 40:
		var r := _fight(i)
		if r["reason"] != "shard" and int(r["fragments"]) > 0:
			eq(int(r["fragments"]), of_type(r, "crystal_fragment").size(), "fragments chipped on a defeat are reported")
			eq(r["survivors"].size(), 0, "a defeat leaves no hero standing (the Crystal never counts)")
			seen = true
			break
	check(seen, "a defeat with fragments chipped occurred")


func test_spawns_placement_and_determinism() -> void:
	var r := _fight(3, {"memories": ["ferryman", "miller", "lumari_knight", "the_keeper"]})
	var spawns := of_type(r, "spawn")
	check(spawns.size() >= 1 and float(spawns[0]["t"]) == 0.0 and spawns[0]["reason"] == "start", "a memory surfaces at the start")
	eq(spawns[0]["slot"], [0, 1], "front column first (in front of the Crystal)")
	eq(spawns.size(), 1 + mini(3, int(r["fragments"])), "one more memory per fragment 1-3")
	for k in spawns.size():
		var sp: Dictionary = spawns[k]
		check(int(sp["uid"]) == int(sp["unit"]["uid"]) and sp["unit"]["tier"] == "memory", "spawn carries the unit snapshot")
		check(not (sp["slot"] == [1, 1] or sp["slot"] == [1, 2]), "never on the Crystal's slots")
	eq(JSON.stringify(r, "", true), JSON.stringify(_fight(3, {"memories": ["ferryman", "miller", "lumari_knight", "the_keeper"]}), "", true),
		"same seed: byte-identical Crystal fight")
	check(JSON.stringify(_fight(4)["events"]) != JSON.stringify(_fight(5)["events"]), "different seeds differ")


func test_crystal_never_acts_or_stands() -> void:
	for i in 20:
		var r := _fight(i)
		var c := _crystal_uid(r)
		var snap: Dictionary = r["events"][0]["sides"][1]["units"][0]
		check(int(snap["span"]) == 2 and int(snap["col"]) == 1 and int(snap["row"]) == 1, "the Crystal fills the two middle back slots")
		for ev: Dictionary in r["events"]:
			match String(ev["type"]):
				"action_start":
					if int(ev["uid"]) == c:
						check(false, "the Crystal acted")
						return
				"charge", "ko":
					if int(ev["uid"]) == c:
						check(false, "the Crystal got a %s event" % ev["type"])
						return
				"damage":
					if int(ev["dst"]) == c and ev["kind"] == "sudden_death":
						check(false, "the Fading erodes the fighters, not the Crystal")
						return
		check(not (r["survivors"] as Array).has(c), "the Crystal never counts as standing")


func test_memories_shield_the_crystal_from_melee() -> void:
	var checked := 0
	for i in 30:
		var r := _fight(i)
		var c := _crystal_uid(r)
		var front := {}
		for ev: Dictionary in r["events"]:
			match String(ev["type"]):
				"spawn":
					if int(ev["slot"][0]) == 0:
						front[int(ev["uid"])] = true
				"ko":
					front.erase(int(ev["uid"]))
				"action_start":
					var a := GameData.get_action(String(ev["action"]))
					if int(ev["target"]) == c and String(a["target"]) == "melee":
						checked += 1
						check(front.is_empty(), "melee reached the Crystal while a memory stood in front")
	check(checked > 0, "melee reaches the Crystal once the front is clear (%d)" % checked)


func test_ranged_reaches_the_crystal() -> void:
	var hit := false
	for i in 30:
		var r := _fight(i)
		var c := _crystal_uid(r)
		var front := 0
		for ev: Dictionary in r["events"]:
			if ev["type"] == "spawn" and int(ev["slot"][0]) == 0:
				front += 1
			elif ev["type"] == "ko" and int(ev["uid"]) != c:
				front -= 1
			elif ev["type"] == "damage" and int(ev["dst"]) == c and front > 0 and ev["kind"] == "magic":
				hit = true
	check(hit, "magic reaches the Crystal past the memories in front")


func test_each_memory_behaviour_fires_truthfully() -> void:
	for mid: String in GameData.Memories.MEMORIES:
		var effect := String(GameData.Memories.MEMORIES[mid]["behaviour"]["id"])
		var fired := false
		for i in 40:
			var r := _fight(i, {"memories": [mid, "ferryman", "miller", "weaver"]})
			var evs: Array = r["events"]
			var actor := -1
			for k in evs.size():
				var ev: Dictionary = evs[k]
				if ev["type"] == "action_start":
					actor = int(ev["uid"])
				if ev["type"] == "formation_proc" and String(ev["source"]) == "memory:" + mid:
					check(_truthful(evs, k), "%s cue is truthful: %s" % [mid, ev])
					fired = true
			if fired:
				break
		check(fired, "%s: %s fires" % [mid, effect])


static func _truthful(evs: Array, k: int) -> bool:
	var cue: Dictionary = evs[k]
	var t := float(cue["t"])
	var uid := int(cue["uid"])
	for ev: Dictionary in evs:
		if absf(float(ev["t"]) - t) > 0.0005:
			continue
		match String(cue["trigger"]):
			"attack":
				if ev["type"] == "damage" and int(ev["src"]) == uid:
					return true
			"defend":
				if ev["type"] == "damage" and int(ev["dst"]) == uid:
					return true
			"turn":
				if ev["type"] == "action_start" and int(ev["uid"]) == uid:
					return true
			"heal":
				if ev["type"] == "heal" and int(ev["src"]) == uid:
					return true
	return false


func test_keeper_dims_hero_behaviours() -> void:
	for i in 20:
		var r := _fight(i, {"memories": ["the_keeper", "ferryman", "miller", "weaver"]})
		var keeper := -1
		for ev: Dictionary in r["events"]:
			if ev["type"] == "spawn" and ev["memory"] == "the_keeper":
				keeper = int(ev["uid"])
			elif ev["type"] == "ko" and int(ev["uid"]) == keeper:
				keeper = -2
			elif ev["type"] == "formation_proc" and int(ev["side"]) == 0 and String(ev["stat"]) == "" and keeper >= 0 \
					and ev["effect"] != "draws_melee":   # draws_melee is a shape's cost, not a behaviour
				check(false, "fight %d: a hero formation behaviour fired while the Keeper stood: %s" % [i, ev])
				return
	check(true, "the lantern stays dark while the Keeper stands")


func test_sealing_hastens_the_fading() -> void:
	var r := _fight(2, {"memories": ["the_sealing", "ferryman", "miller", "weaver"]})
	var ticks := of_type(r, "sudden_death")
	var first := float(ticks[0]["t"]) if not ticks.is_empty() else 999.0
	check(first < float(GameData.combat()["sudden_death_start_ms"]) / 1000.0 or float(r["duration"]) < 30.0,
		"the Fading comes before its usual time (first tick %.1f s)" % first)


func test_bad_crystal_options_rejected() -> void:
	var p := PartyGen.demo_party()
	check(CombatSim.simulate_crystal(1, p, {"memories": ["nope"]}).has("error"), "unknown memory rejected")
	check(not CombatSim.simulate_crystal(1, p).has("error"), "defaults work")
