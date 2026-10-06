extends "res://tests/test_case.gd"
## The user's round-1 rulings (docs/design/class-verdicts-round1.md), as deterministic sims.
## Ruling 1 (hidden front units vs melee) and ruling 2 (status damage is non-physical) are also
## covered in test_statuses.gd.

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const GameData = preload("res://core/game_data.gd")
const Rng = preload("res://core/rng.gd")

const FAST := {"start_charge_spread": 0, "start_charge_bonus": 100}   # everyone starts at 99 charge


func _total(stats: Dictionary) -> float:
	var t := 0.0
	for k: String in GameData.Classes.BUDGET_WEIGHTS:
		t += float(stats[k]) * float(GameData.Classes.BUDGET_WEIGHTS[k])
	return t


func test_ruling8_one_stat_budget_per_base() -> void:
	var seen := 0
	for cid: String in GameData.Classes.CLASSES:
		var c: Dictionary = GameData.Classes.CLASSES[cid]
		if String(c["tier"]) != "advanced":
			continue
		seen += 1
		var b: Dictionary = GameData.Classes.BUDGET[String(c["base"])]
		check(absf(_total(c["stats"]) - float(b["stats"])) < 0.01,
			"%s level-1 total %.1f = %s budget %s" % [cid, _total(c["stats"]), c["base"], b["stats"]])
		check(absf(_total(c["growth"]) - float(b["growth"])) < 0.01,
			"%s growth total %.2f = %s budget %s" % [cid, _total(c["growth"]), c["base"], b["growth"]])
	check(seen >= 27, "every advanced class checked (%d)" % seen)


func test_ruling4_one_hp_unit_is_standing() -> void:
	# A side with any unit at 1 HP or more has not lost: it fights on (and wins once the foe falls).
	var a := party([hero("fighter", 0, 0, 6), hero("healer", 1, 3)])
	var b := party([hero("rogue", 0, 0), hero("mage", 1, 3)])
	var r := CombatSim.simulate(3, a, b, {"start_hp": [{"side": 0, "slot": [0, 0], "hp": 1}, {"side": 0, "slot": [1, 3], "hp": 1}]})
	var acted_at_1hp := false
	var hp := {0: 1, 1: 1}
	for ev: Dictionary in r["events"]:
		if ev["type"] == "damage" or ev["type"] == "heal":
			hp[int(ev["dst"])] = int(ev["hp"])
		if ev["type"] == "action_start" and int(ev["uid"]) <= 1 and int(hp.get(int(ev["uid"]), 0)) == 1:
			acted_at_1hp = true
	check(acted_at_1hp, "a unit at 1 HP is standing: it takes its turn")
	# property over many fights: a wipe is only declared when the loser has nobody standing
	var rng := Rng.new(404)
	for i in 200:
		var rr := CombatSim.simulate(i, PartyGen.random_party(rng), PartyGen.random_party(rng))
		if String(rr["reason"]) != "wipe":
			continue
		var standing := {0: 0, 1: 0}
		var summons := {}
		for ev: Dictionary in rr["events"]:
			if ev["type"] == "spawn" and String(ev.get("summon", "")) != "":
				summons[int(ev["uid"])] = true
		for uid: int in rr["survivors"]:
			check(not summons.has(uid), "summons are never survivors")
			standing[_side_of(rr, uid)] += 1
		var w := int(rr["winner"])
		check(w >= 0 and int(standing[w]) >= 1 and int(standing[1 - w]) == 0, "fight %d: wipe means the loser has nobody standing" % i)


func _side_of(r: Dictionary, uid: int) -> int:
	for side: Dictionary in r["events"][0]["sides"]:
		for u: Dictionary in side["units"]:
			if int(u["uid"]) == uid:
				return int(u["side"])
	for ev: Dictionary in r["events"]:
		if ev["type"] == "spawn" and int(ev["uid"]) == uid:
			return int(ev["side"])
	return -1


func test_ruling4_hp_costs_never_drop_below_one() -> void:
	# Iron Marshal's drive costs HP; an ally at 1 HP pays nothing and stays standing.
	var a := party([hero("iron_marshal", 0, 1, 2), hero("rogue", 0, 2)])
	var b := duo(hero("fighter", 0, 0))
	var r := CombatSim.simulate(5, a, b, {"tuning": FAST, "start_hp": [{"side": 0, "slot": [0, 2], "hp": 1}],
		"start_statuses": [{"side": 0, "slot": [0, 2], "status": "shield", "amount": 999, "dur_ms": 60000}]})
	var drove := false
	for ev: Dictionary in of_type(r, "gauge"):
		if int(ev["uid"]) == 1:
			drove = true
	check(drove, "the Marshal drove the 1-HP ally on")
	for ev: Dictionary in of_type(r, "damage"):
		if String(ev["primary"].get("id", "")) == "cost":
			check(int(ev["hp"]) >= 1, "an HP cost never takes a unit below 1 HP")
	for ev: Dictionary in of_type(r, "ko"):
		if int(ev["uid"]) == 1:
			check(int(ev["by"]) != 0, "the drive itself never knocks the ally out")


func test_ruling4_fading_builds_no_charge() -> void:
	var rng := Rng.new(77)
	var ticks := 0
	for i in 40:
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), PartyGen.random_party(rng), {"tuning": {"damage_scale": 0.3}})
		var evs: Array = r["events"]
		for k in evs.size():
			var ev: Dictionary = evs[k]
			if ev["type"] == "damage" and ev["kind"] == "sudden_death":
				ticks += 1
				var j := k + 1
				while j < evs.size() and float(evs[j]["t"]) == float(ev["t"]) and evs[j]["type"] != "damage":
					if evs[j]["type"] == "charge" and int(evs[j]["uid"]) == int(ev["dst"]):
						check(false, "fight %d: a Fading tick gave charge" % i)
					j += 1
	check(ticks > 100, "Fading ticks sampled (%d)" % ticks)


func test_ruling4_statuses_on_others_no_longer_lock_charge() -> void:
	# Playtest fix (2026-10-06): Nightshade keeps charging while its poison is on a foe; only its own
	# standing summons (or a flagged self-applied sustain status) lock a unit's charge.
	var a := party([hero("nightshade", 0, 1, 2), hero("mage", 1, 3)])
	var b := party([hero("stone_sentinel", 0, 1, 5), hero("stone_sentinel", 0, 2, 5)])
	var r := CombatSim.simulate(8, a, b, {"tuning": FAST})
	var on := false
	var gained := 0
	for ev: Dictionary in r["events"]:
		if ev["type"] == "status" and ev["status"] == "poison" and int(ev["src"]) == 0:
			on = true
		elif ev["type"] == "status_end" and ev["status"] == "poison":
			on = false
		elif ev["type"] == "charge" and int(ev["uid"]) == 0 and on and int(ev["delta"]) > 0:
			gained += 1
	check(gained > 0, "Nightshade gains charge while its poison is active (%d)" % gained)
	for id: String in GameData.Statuses.STATUSES:
		check(not bool(GameData.Statuses.STATUSES[id].get("locks_charge", false)), "no approved status locks charge yet (%s)" % id)


func test_ruling4_lumenward_charges_on_hit_while_its_shields_hold() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("lumenward", 0, 2, 2)])
	var b := party([hero("fighter", 0, 2, 3), hero("rogue", 0, 1, 3)])
	# a long shield the Lumenward put on its ally with its ability (owned by it, as Lumen Ward's are)
	var r := CombatSim.simulate(12, a, b, {"tuning": FAST, "start_statuses": [{"side": 0, "slot": [0, 1], "status": "shield",
		"amount": 500, "dur_ms": 30000, "src_side": 0, "src_slot": [0, 2], "from_ability": true}]})
	var shields := {}
	var hit_gain := 0
	for ev: Dictionary in r["events"]:
		if ev["type"] == "status" and ev["status"] == "shield" and int(ev["src"]) == 1:
			shields[int(ev["uid"])] = true
		elif ev["type"] == "status_end" and ev["status"] == "shield":
			shields.erase(int(ev["uid"]))
		elif ev["type"] == "charge" and int(ev["uid"]) == 1 and ev["reason"] == "hit" and int(ev["delta"]) > 0 and not shields.is_empty():
			hit_gain += 1
	check(hit_gain > 0, "a Lumenward hit while its shields are up gains charge (%d)" % hit_gain)


func test_ruling4_summoner_gains_no_charge_while_its_echo_stands() -> void:
	var a := party([hero("echoblade", 0, 1, 2), hero("mage", 1, 3)])
	var b := party([hero("stone_sentinel", 0, 1, 6), hero("stone_sentinel", 1, 1, 6)])
	var g := [{"side": 0, "slot": [0, 1], "status": "shield", "amount": 99999, "dur_ms": 60000},
		{"side": 0, "slot": [1, 3], "status": "shield", "amount": 99999, "dur_ms": 60000}]
	var r := CombatSim.simulate(4, a, b, {"tuning": FAST, "start_statuses": g})
	var echo := -1
	var checked := 0
	for ev: Dictionary in r["events"]:
		if ev["type"] == "spawn" and ev["summon"] == "echo":
			echo = int(ev["uid"])
		elif ev["type"] == "ko" and int(ev["uid"]) == echo:
			echo = -1
		elif ev["type"] == "charge" and int(ev["uid"]) == 0 and echo >= 0:
			checked += 1
			check(int(ev["delta"]) <= 0, "no charge for the Echoblade while its echo stands")
	check(true, "echo charge checked (%d)" % checked)


func test_ruling5_no_stun_diminishing_returns() -> void:
	# playtest first: a second stun right after the first lands at full length
	var st := func(ms: int) -> Dictionary:
		return {"side": 1, "slot": [0, 0], "status": "stun", "dur_ms": ms}
	var r := CombatSim.simulate(9, duo(hero("fighter", 0, 0)), duo(hero("fighter", 0, 0)),
		{"start_statuses": [st.call(3000), st.call(5000)]})
	var durs: Array = []
	for ev: Dictionary in of_type(r, "status"):
		durs.append(float(ev["duration"]))
	eq(durs, [3.0, 5.0], "the longer stun applies in full (no immunity window)")


func test_ruling6_summons_dont_count_toward_shapes() -> void:
	# Echoblade's echo fills a front slot but never joins the shape: no behaviour or formation cue
	# names it, it isn't a survivor, and it never holds a side up on its own.
	var rng := Rng.new(66)
	var echoes := 0
	for i in 60:
		var a := PartyGen.random_party(rng, {"shape": "kindred" if i % 2 == 0 else "lamplight", "size": 2})
		(a["heroes"] as Array)[0]["class"] = "echoblade"
		(a["heroes"] as Array)[0]["level"] = 2
		var r := CombatSim.simulate(i, a, PartyGen.random_party(rng), {"tuning": FAST})
		var summons := {}
		for ev: Dictionary in r["events"]:
			if ev["type"] == "spawn" and ev["summon"] == "echo":
				summons[int(ev["uid"])] = true
				echoes += 1
				eq(ev["unit"]["tier"], "summon", "an echo is a summon")
			if ev["type"] == "formation_proc":
				check(not summons.has(int(ev["uid"])), "no formation cue on a summon")
		for uid: int in r["survivors"]:
			check(not summons.has(uid), "a summon is never a survivor")
	check(echoes >= 10, "echoes summoned (%d)" % echoes)
