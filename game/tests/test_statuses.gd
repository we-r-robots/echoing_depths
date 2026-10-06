extends "res://tests/test_case.gd"
## The timed status system (data/statuses.gd, core/README.md "Statuses"). Each status is put on a
## unit at the start with the sim's `start_statuses` option, so every test is a deterministic sim.

const CombatSim = preload("res://core/combat_sim.gd")
const GameData = preload("res://core/game_data.gd")

const EXACT := {"crit_enabled": false, "damage_variance": 0.0}


func _sim(seed_value: int, a: Dictionary, b: Dictionary, statuses: Array, tuning := {}) -> Dictionary:
	var tn := EXACT.duplicate()
	tn.merge(tuning, true)
	return CombatSim.simulate(seed_value, a, b, {"tuning": tn, "start_statuses": statuses})


func _st(side: int, slot: Array, status: String, dur_ms: int, extra := {}) -> Dictionary:
	var d := {"side": side, "slot": slot, "status": status, "dur_ms": dur_ms}
	d.merge(extra, true)
	return d


static func _unit(r: Dictionary, uid: int) -> Dictionary:
	for side: Dictionary in r["events"][0]["sides"]:
		for u: Dictionary in side["units"]:
			if int(u["uid"]) == uid:
				return u
	return {}


func _expected(power: float, a: int, d: int) -> int:
	return maxi(1, int(round(power * float(GameData.combat()["damage_scale"]) * float(a * a) / float(a + d))))


func _ends(r: Dictionary, uid: int, status: String) -> Array:
	var out: Array = []
	for ev: Dictionary in of_type(r, "status_end"):
		if int(ev["uid"]) == uid and String(ev["status"]) == status:
			out.append(ev)
	return out


func test_stun_loses_turns_until_it_wears_off() -> void:
	var r := _sim(11, duo(hero("fighter", 0, 0)), duo(hero("fighter", 0, 0)), [_st(0, [0, 0], "stun", 4000)])
	var skips := 0
	for ev: Dictionary in of_type(r, "skip"):
		if int(ev["uid"]) == 0:
			skips += 1
			check(float(ev["t"]) < 4.0 + 1.0, "skips only while stunned")
			eq(ev["reason"], "stun", "skip reason")
	check(skips >= 1, "a stunned unit loses at least one turn (%d)" % skips)
	for ev: Dictionary in of_type(r, "action_start"):
		if int(ev["uid"]) == 0:
			check(float(ev["t"]) >= 4.0, "no action while stunned (acted at %.2f)" % float(ev["t"]))
	var ends := _ends(r, 0, "stun")
	eq(ends.size(), 1, "stun ends once")
	eq(String((ends[0] as Dictionary)["reason"]), "expired", "stun expires")


func test_blind_makes_hits_miss() -> void:
	var r := _sim(12, duo(hero("fighter", 0, 0)), duo(hero("fighter", 0, 0)), [_st(0, [0, 0], "blind", 5000)],
		{"blind_miss": 1.0})
	var misses := 0
	for ev: Dictionary in of_type(r, "miss"):
		eq(int(ev["src"]), 0, "only the blinded unit misses")
		eq(ev["reason"], "blind", "miss reason")
		check(float(ev["t"]) <= 5.0 + 1.0, "misses only while blinded")
		misses += 1
	check(misses >= 1, "a blinded unit's hits miss")
	for ev: Dictionary in of_type(r, "damage"):
		if int(ev["src"]) == 0:
			check(float(ev["t"]) > 5.0, "no hit lands while fully blinded")


func test_blind_draws_rng_only_while_blinded() -> void:
	# a blind that never meets an attack leaves the fight byte-identical (determinism of old replays)
	var a := duo(hero("fighter", 0, 0))
	var b := duo(hero("fighter", 0, 0))
	var plain := CombatSim.simulate(13, a, b, {"tuning": EXACT})
	var r := _sim(13, a, b, [_st(0, [0, 0], "blind", 1)])
	eq(int(r["winner"]), int(plain["winner"]), "same winner")
	eq(int(r["duration_ms"]), int(plain["duration_ms"]), "same length")


func test_sap_and_boon_scale_the_stat() -> void:
	var a := duo(hero("fighter", 0, 0))
	var b := duo(hero("fighter", 0, 0))
	var r := _sim(14, a, b, [_st(0, [0, 0], "sap", 30000, {"stat": "atk", "value": -0.5})])
	var me := _unit(r, 0)
	var foe := _unit(r, 2)
	var hit: Dictionary = {}
	for ev: Dictionary in of_type(r, "damage"):
		if int(ev["src"]) == 0 and String(ev["action"]) == "strike":
			hit = ev
			break
	eq(int(hit["amount"]), _expected(1.0, floori(int(me["atk"]) * 0.5), int(foe["def"])), "sapped Atk -50% hits as half Atk")
	check(mod(hit, "formation").is_empty(), "a sap is not reported as a formation effect")
	var r2 := _sim(14, a, b, [_st(0, [0, 0], "boon", 30000, {"stat": "atk", "value": 0.5})])
	var hit2: Dictionary = {}
	for ev: Dictionary in of_type(r2, "damage"):
		if int(ev["src"]) == 0 and String(ev["action"]) == "strike":
			hit2 = ev
			break
	eq(int(hit2["amount"]), _expected(1.0, floori(int(me["atk"]) * 1.5), int(foe["def"])), "boon Atk +50%")
	var st: Dictionary = of_type(r, "status")[0]
	eq(st["stat"], "atk", "status event names the stat")
	eq(float(st["value"]), -0.5, "status event value")


func test_slow_delays_turns() -> void:
	var a := duo(hero("fighter", 0, 0))
	var b := duo(hero("fighter", 0, 0))
	var first := func(r: Dictionary) -> float:
		for ev: Dictionary in of_type(r, "action_start"):
			if int(ev["uid"]) == 0:
				return float(ev["t"])
		return 999.0
	var t_plain: float = first.call(_sim(15, a, b, []))
	var t_slow: float = first.call(_sim(15, a, b, [_st(0, [0, 0], "slow", 30000, {"value": 0.6})]))
	check(t_slow > t_plain, "a slowed unit acts later (%.2f vs %.2f)" % [t_slow, t_plain])


func test_poison_ticks_every_second_and_is_non_physical() -> void:
	# poison on a BACK-column unit: status damage never takes the back-row halving (ruling 2)
	var a := party([hero("mage", 1, 0), hero("mage", 1, 3)])
	var b := party([hero("healer", 1, 0), hero("healer", 1, 3)])
	var r := _sim(16, a, b, [_st(1, [1, 0], "poison", 4000, {"power": 0.5, "src_side": 0, "src_slot": [1, 0]})])
	var src := _unit(r, 0)
	var dst := _unit(r, 2)
	var per := _expected(0.5, int(src["mag"]), int(dst["mag"]))
	var ticks: Array = []
	for ev: Dictionary in of_type(r, "damage"):
		if String(ev["kind"]) == "status" and int(ev["dst"]) == 2:
			ticks.append(ev)
	eq(ticks.size(), 4, "4 ticks over 4 s")
	for ev: Dictionary in ticks:
		eq(int(ev["amount"]), per, "tick = Mag-vs-Mag formula, no back-row cut")
		eq(String(ev["primary"]["id"]), "poison", "tick primary id")
		eq(int(ev["src"]), 0, "credited to the poisoner")
		check(mod(ev, "back_row_target").is_empty(), "no back-row mod on status damage")
	eq(float((ticks[1] as Dictionary)["t"]) - float((ticks[0] as Dictionary)["t"]) >= 0.99, true, "a second apart (or later, after an action)")


func test_poison_stacks_up_to_three() -> void:
	var a := duo(hero("mage", 1, 0))
	var b := duo(hero("fighter", 0, 0))
	var p := _st(1, [0, 0], "poison", 6000, {"power": 0.2, "src_side": 0, "src_slot": [1, 0]})
	var r := _sim(17, a, b, [p, p, p, p])
	var stacks: Array = []
	for ev: Dictionary in of_type(r, "status"):
		if String(ev["status"]) == "poison":
			stacks.append(int(ev["stacks"]))
	eq(stacks, [1, 2, 3, 3], "stacks cap at 3")


func test_burn_spreads_to_a_neighbour() -> void:
	var a := duo(hero("mage", 1, 0))
	var b := party([hero("fighter", 0, 1), hero("fighter", 0, 2)])
	var r := _sim(18, a, b, [_st(1, [0, 1], "burn", 6000, {"power": 0.1, "spread_ms": 2000, "src_side": 0, "src_slot": [1, 0]})])
	var burned := {}
	for ev: Dictionary in of_type(r, "status"):
		if String(ev["status"]) == "burn":
			burned[int(ev["uid"])] = float(ev["t"])
	check(burned.size() == 2, "the fire jumped to the unit beside it")
	var later: Array = burned.values()
	later.sort()
	check(float(later[1]) >= 2.0, "it jumps after the spread time")


func test_regen_heals_over_time() -> void:
	var a := party([hero("fighter", 0, 0), hero("healer", 1, 0)])
	var b := duo(hero("fighter", 0, 0, 3))
	var r := _sim(19, a, b, [_st(0, [0, 0], "regen", 8000, {"power": 0.5, "src_slot": [1, 0]})])
	var n := 0
	for ev: Dictionary in of_type(r, "heal"):
		if String(ev["action"]) == "status:regen" and int(ev["dst"]) == 0:
			n += 1
	check(n >= 1, "regen ticks heal (%d)" % n)


func test_shield_absorbs_then_breaks() -> void:
	var a := duo(hero("fighter", 0, 0))
	var b := duo(hero("fighter", 0, 0))
	var r := _sim(20, a, b, [_st(1, [0, 0], "shield", 30000, {"amount": 25})])
	var absorbed := 0
	for ev: Dictionary in of_type(r, "absorb"):
		eq(int(ev["uid"]), 2, "the shielded unit absorbs")
		absorbed += int(ev["amount"])
	eq(absorbed, 25, "a 25 shield absorbs exactly 25")
	var ends := _ends(r, 2, "shield")
	eq(String((ends[0] as Dictionary)["reason"]), "broken", "a used-up shield breaks")


func test_hidden_front_unit_is_skipped_by_melee() -> void:
	# ruling 1: melee skips a hidden front unit to the nearest visible front unit
	var a := duo(hero("fighter", 0, 0))
	var b := party([hero("fighter", 0, 0), hero("fighter", 0, 3), hero("mage", 1, 0)])
	var r := _sim(21, a, b, [_st(1, [0, 0], "hidden", 30000)])
	var hidden_uid := uid_at(r, 1, 0, 0)
	var other := uid_at(r, 1, 0, 3)
	var first: Dictionary = {}
	for ev: Dictionary in of_type(r, "action_start"):
		if int(ev["uid"]) == 0:
			first = ev
			break
	eq(int(first["target"]), other, "melee skips the hidden unit to the visible front unit")
	for ev: Dictionary in of_type(r, "action_start"):
		if int(ev["uid"]) <= 1:
			check(int(ev["target"]) != hidden_uid, "nobody single-targets the hidden unit")


func test_melee_reaches_back_only_when_no_visible_front() -> void:
	var a := duo(hero("fighter", 0, 0))
	var b := party([hero("fighter", 0, 0), hero("mage", 1, 0)])
	var r := _sim(22, a, b, [_st(1, [0, 0], "hidden", 30000)])
	var first: Dictionary = {}
	for ev: Dictionary in of_type(r, "action_start"):
		if int(ev["uid"]) == 0:
			first = ev
			break
	eq(int(first["target"]), uid_at(r, 1, 1, 0), "only hidden units in front: melee reaches the back")


func test_heal_block_stops_healing() -> void:
	var a := party([hero("fighter", 0, 0, 6), hero("cleric", 1, 0, 4)])   # Sanctuary heals everyone
	var b := duo(hero("fighter", 0, 0, 6))
	var r := _sim(23, a, b, [_st(0, [0, 0], "heal_block", 60000)])
	for ev: Dictionary in of_type(r, "heal"):
		check(int(ev["dst"]) != 0, "no heal reaches a branded unit")
	var blocked := 0
	for ev: Dictionary in of_type(r, "miss"):
		if String(ev["reason"]) == "heal_block":
			blocked += 1
	check(blocked >= 1, "blocked heals are reported (%d)" % blocked)


func test_single_heals_pass_over_a_branded_ally() -> void:
	# Mend aims at the most hurt ally it can heal: a branded fighter is passed over for the healer
	var a := party([hero("fighter", 0, 0), hero("healer", 1, 0, 6)])
	var b := duo(hero("fighter", 0, 0, 6))
	var r := _sim(23, a, b, [_st(0, [0, 0], "heal_block", 60000)])
	var mends := 0
	for ev: Dictionary in of_type(r, "action_start"):
		if ev["action"] == "mend":
			mends += 1
			check(int(ev["target"]) != 0, "Mend never aims at the branded unit")
	check(mends >= 1, "the healer cast Mend (%d)" % mends)


func test_heal_inversion_hurts() -> void:
	var a := party([hero("fighter", 0, 0, 6), hero("cleric", 1, 0, 4)])   # Sanctuary heals everyone
	var b := duo(hero("fighter", 0, 0, 6))
	var r := _sim(24, a, b, [_st(0, [0, 0], "heal_invert", 60000)])
	var hurt := 0
	for ev: Dictionary in of_type(r, "damage"):
		if int(ev["dst"]) == 0 and String(ev["primary"].get("id", "")) == "heal_invert":
			eq(ev["kind"], "status", "inverted healing is status damage")
			hurt += 1
	check(hurt >= 1, "healing a hexed unit hurts it")


func test_charge_seal_blocks_charge() -> void:
	var r := _sim(25, duo(hero("fighter", 0, 0)), duo(hero("fighter", 0, 0)), [_st(0, [0, 0], "charge_seal", 6000)])
	var acted := false
	for ev: Dictionary in of_type(r, "action_start"):
		if int(ev["uid"]) == 0 and float(ev["t"]) < 6.0 and ev["kind"] == "basic":
			acted = true
	check(acted, "the sealed unit acted while sealed (so it would have charged)")
	for ev: Dictionary in of_type(r, "charge"):
		if int(ev["uid"]) == 0 and float(ev["t"]) < 6.0:
			check(int(ev["delta"]) <= 0, "a sealed unit gains no charge (%s at %.2f)" % [ev["reason"], float(ev["t"])])


func test_link_shares_damage() -> void:
	var a := duo(hero("fighter", 0, 0))
	var b := party([hero("fighter", 0, 0), hero("fighter", 0, 3)])
	var r := _sim(26, a, b, [_st(1, [0, 0], "link", 30000, {"partner": 3}), _st(1, [0, 3], "link", 30000, {"partner": 2})])
	var shared := 0
	for ev: Dictionary in of_type(r, "damage"):
		if String(ev["primary"].get("id", "")) == "link":
			shared += 1
	check(shared >= 1, "linked units share hits (%d)" % shared)


func test_own_ability_effect_locks_charge() -> void:
	# ruling 4: while a status unit 0 applied with its ability is active, unit 0 gains no charge
	var r := _sim(27, duo(hero("fighter", 0, 0)), duo(hero("fighter", 0, 0)),
		[_st(1, [0, 0], "slow", 5000, {"value": 0.1, "src_side": 0, "src_slot": [0, 0], "from_ability": true})])
	for ev: Dictionary in of_type(r, "charge"):
		if int(ev["uid"]) == 0 and float(ev["t"]) < 5.0:
			check(int(ev["delta"]) <= 0, "no charge for the caster while its effect is active")
	var gained := false
	for ev: Dictionary in of_type(r, "charge"):
		if int(ev["uid"]) == 0 and float(ev["t"]) > 5.5 and int(ev["delta"]) > 0:
			gained = true
	check(gained, "charge resumes once the effect ends")


func test_statuses_end_on_ko_and_are_deterministic() -> void:
	var a := duo(hero("mage", 1, 0, 6))
	var b := duo(hero("rogue", 0, 0))
	var sts := [_st(1, [0, 0], "poison", 60000, {"power": 0.6, "src_side": 0, "src_slot": [1, 0]})]
	var r1 := _sim(28, a, b, sts)
	var r2 := _sim(28, a, b, sts)
	eq(JSON.stringify(r1, "", true), JSON.stringify(r2, "", true), "same seed and statuses: identical result")
	var ko_ends := 0
	for ev: Dictionary in of_type(r1, "status_end"):
		if String(ev["reason"]) == "ko":
			ko_ends += 1
	check(ko_ends >= 1, "a falling unit's statuses end with reason ko")
