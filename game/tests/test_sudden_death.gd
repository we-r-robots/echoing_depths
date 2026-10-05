extends "res://tests/test_case.gd"

const CombatSim = preload("res://core/combat_sim.gd")
const GameData = preload("res://core/game_data.gd")


func _stalemate() -> Dictionary:
	# Damage scaled to almost nothing + healers: only sudden death can end this.
	var a := party([hero("fighter", 0, 1, 4), hero("healer", 1, 0, 4), hero("healer", 1, 2, 4)])
	var b := party([hero("fighter", 0, 1, 6), hero("healer", 1, 1, 4), hero("healer", 1, 2, 4)])
	return CombatSim.simulate(31, a, b, {"tuning": {"damage_scale": 0.001}})


func test_sudden_death_ends_stalemate() -> void:
	var r := _stalemate()
	var c := GameData.combat()
	eq(r["reason"], "fading", "stalemate ended by sudden death (the Fading)")
	check(int(r["duration_ms"]) < int(c["max_fight_ms"]), "ended before the hard cap")
	var ticks := of_type(r, "sudden_death")
	check(ticks.size() >= 1, "sudden death ticks logged")
	check(float(ticks[0]["t"]) >= float(c["sudden_death_start_ms"]) / 1000.0, "first tick after the start time")
	eq(of_type(r, "fight_end").size(), 1, "exactly one fight_end")


func test_sudden_death_escalates() -> void:
	var r := _stalemate()
	var per := float(GameData.combat()["sudden_death_hp_pct_per_tick"])
	var prev_mult := 1.0
	for ev: Dictionary in of_type(r, "sudden_death"):
		var n := int(ev["tick"])
		check(absf(float(ev["hp_pct"]) - per * n) < 0.0011, "tick %d deals n * pct" % n)
		check(float(ev["damage_mult"]) > prev_mult, "damage multiplier grows")
		prev_mult = float(ev["damage_mult"])
	var sd_dmg := 0
	for ev: Dictionary in of_type(r, "damage"):
		if ev["kind"] == "sudden_death":
			sd_dmg += 1
			eq(int(ev["src"]), -1, "sudden death damage has no source")
	check(sd_dmg > 0, "sudden death damage events")


func test_no_stalemates_in_random_fights() -> void:
	var PartyGen := preload("res://core/party_gen.gd")
	var Rng := preload("res://core/rng.gd")
	var rng := Rng.new(77)
	var timeouts := 0
	var draws := 0
	for i in 200:
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), PartyGen.random_party(rng), {"log": false})
		if r["reason"] == "timeout":
			timeouts += 1
		if int(r["winner"]) < 0:
			draws += 1
	eq(timeouts, 0, "no fight reaches the hard cap")
	check(draws <= 2, "draws are vanishingly rare (%d/200)" % draws)


func test_fading_is_time_based_and_evenly_spaced() -> void:
	# User decision: sudden death starts only at sudden_death_at, never because a side is down to
	# its last unit; ticks are interval apart, measured from when each tick actually fired.
	var PartyGen := preload("res://core/party_gen.gd")
	var Rng := preload("res://core/rng.gd")
	var c := GameData.combat()
	var start := float(c["sudden_death_start_ms"]) / 1000.0
	var interval := float(c["sudden_death_interval_ms"]) / 1000.0
	var rng := Rng.new(8)
	var ticks := 0
	for i in 300:
		var b := PartyGen.monster_group(rng, 1 + i % 10) if i % 2 == 1 else PartyGen.random_party(rng)
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), b, {"tuning": {"damage_scale": 1.0}})
		var last := -1.0
		for ev: Dictionary in of_type(r, "sudden_death"):
			ticks += 1
			if float(ev["t"]) < start - 0.0005 or (last >= 0.0 and float(ev["t"]) - last < interval - 0.0005):
				check(false, "fight %d: tick at %.3f (previous %.3f)" % [i, float(ev["t"]), last])
				return
			last = float(ev["t"])
		if float(r["duration"]) < start:
			eq(int(r["sudden_death_ticks"]), 0, "no tick before the Fading starts")
	check(ticks > 100, "ticks exercised (%d)" % ticks)
