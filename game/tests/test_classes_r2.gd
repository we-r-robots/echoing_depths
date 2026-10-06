extends "res://tests/test_case.gd"
## The round-2 classes (docs/design/class-verdicts-round2.md) as deterministic sims: Halberdier,
## Lightsworn, Bladebreaker (disarm), Ravager, Saboteur (sabotage), Duelist's Riposte rework,
## Nightwatch (watch), Bloodletter, the Gravecaller's nameless husk, and the Enshriner with its
## PROVISIONAL seal rules (a)-(d). Roster, budgets, labels, icons and migrations: test_classes.gd,
## test_rulings.gd.

const CombatSim = preload("res://core/combat_sim.gd")
const GameData = preload("res://core/game_data.gd")
const Rng = preload("res://core/rng.gd")
const PartyGen = preload("res://core/party_gen.gd")

const FAST := {"start_charge_spread": 0, "start_charge_bonus": 100}   # everyone starts at 99 charge


func _sim(seed_value: int, a: Dictionary, b: Dictionary, opts := {}) -> Dictionary:
	var o := {"tuning": FAST}
	o.merge(opts, true)
	return CombatSim.simulate(seed_value, a, b, o)


static func _guard(side: int, slots: Array) -> Array:
	var out: Array = []
	for sl: Array in slots:
		out.append({"side": side, "slot": sl, "status": "shield", "amount": 99999, "dur_ms": 60000})
	return out


func _first(r: Dictionary, type: String, pred: Callable) -> Dictionary:
	for ev: Dictionary in of_type(r, type):
		if pred.call(ev):
			return ev
	return {}


func _ability_of(r: Dictionary, uid: int) -> Dictionary:
	return _first(r, "action_start", func(ev: Dictionary) -> bool: return int(ev["uid"]) == uid and ev["kind"] == "ability")


## Events between an action_start and the next action_start.
func _during(r: Dictionary, act: Dictionary) -> Array:
	var out: Array = []
	var on := false
	for ev: Dictionary in r["events"]:
		if ev == act:
			on = true
			continue
		if on and ev["type"] == "action_start":
			break
		if on:
			out.append(ev)
	return out


## [start, end) seconds of the first status `id` on uid (end = its status_end, else the fight end).
func _window(r: Dictionary, uid: int, id: String) -> Array:
	var st := _first(r, "status", func(ev: Dictionary) -> bool: return int(ev["uid"]) == uid and ev["status"] == id)
	if st.is_empty():
		return []
	var en := _first(r, "status_end", func(ev: Dictionary) -> bool:
		return int(ev["uid"]) == uid and ev["status"] == id and float(ev["t"]) >= float(st["t"]))
	return [float(st["t"]), float(en["t"]) if not en.is_empty() else float(r["duration"])]


# ------------------------------------------------------------------ Fighter

func test_halberdier_reaches_the_foe_behind() -> void:
	var a := party([hero("halberdier", 0, 1, 2), hero("mage", 1, 3)])
	var b := party([hero("fighter", 0, 1, 3), hero("healer", 1, 1, 3)])
	var r := _sim(31, a, b)
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "long_reach", "Long Reach fires")
	var front := uid_at(r, 1, 0, 1)
	var behind := uid_at(r, 1, 1, 1)
	var hit := {}
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "damage" and int(ev["src"]) == 0:
			hit[int(ev["dst"])] = ev
	check(hit.has(front) and hit.has(behind), "the front foe and the foe behind it in the same row (%s)" % str(hit.keys()))
	if hit.has(behind):
		check(not mod(hit[behind], "back_row_target").is_empty(), "the back-column foe takes half, like any physical hit")


func test_halberdier_with_nobody_behind_hits_one() -> void:
	var a := party([hero("halberdier", 0, 1, 2), hero("mage", 1, 3)])
	var b := party([hero("fighter", 0, 1, 3), hero("healer", 1, 3, 3)])
	var r := _sim(32, a, b)
	var act := _ability_of(r, 0)
	var n := 0
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "damage" and int(ev["src"]) == 0:
			n += 1
	eq(n, 1, "no foe behind the front foe in its row: one hit")


func test_lightsworn_shields_the_weakest_ally() -> void:
	var a := party([hero("lightsworn", 0, 1, 2), hero("mage", 1, 3)])
	var r := _sim(33, a, duo(hero("fighter", 0, 1, 2)), {"start_hp": [{"side": 0, "slot": [1, 3], "hp": 30}]})
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "aegis_strike", "Lightsworn keeps Paladin's ability name, Aegis Strike")
	eq(String(act["name"]), "Aegis Strike", "displayed as Aegis Strike")
	var mage := uid_at(r, 0, 1, 3)
	var shield := {}
	var healed := false
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "status" and ev["status"] == "shield":
			shield = ev
		if ev["type"] == "heal":
			healed = true
	eq(int(shield.get("uid", -1)), mage, "the lowest-HP ally is shielded")
	check(not healed, "a shield, not a heal")
	var df := int(unit_stats(r, 0)["def"])
	eq(int(float(shield.get("value", 0.0))), int(round(1.6 * 0.6 * df)), "the shield is sized by the Lightsworn's Def")


func test_bladebreaker_disarms_the_strongest_front_foe() -> void:
	var a := party([hero("bladebreaker", 0, 1, 2), hero("mage", 1, 3)])
	var b := party([hero("rogue", 0, 0), hero("berserker", 0, 2), hero("archmage", 1, 1)])
	var r := _sim(34, a, b, {"start_statuses": _guard(0, [[0, 1], [1, 3]])})
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "break_blade", "Break Blade fires")
	var bers := uid_at(r, 1, 0, 2)
	eq(int(act["target"]), bers, "the strongest FRONT foe (the Berserker; the back Archmage doesn't count)")
	var w := _window(r, bers, "disarm")
	check(not w.is_empty(), "it is disarmed")
	if w.is_empty():
		return
	var skips := 0
	for ev: Dictionary in r["events"]:
		var t := float(ev["t"])
		if t <= float(w[0]) or t >= float(w[1]):
			continue
		if ev["type"] == "action_start" and int(ev["uid"]) == bers:
			check(ev["kind"] == "ability", "no basic attack while disarmed")
		if ev["type"] == "charge" and int(ev["uid"]) == bers:
			check(ev["reason"] != "act", "no charge from acting while disarmed")
		if ev["type"] == "skip" and int(ev["uid"]) == bers:
			eq(ev["reason"], "disarm", "its turn passes as a disarm skip")
			skips += 1
	check(skips >= 1, "its turn came and passed with no attack (%d)" % skips)


func test_disarmed_unit_still_charges_from_hits_and_fires_its_ability() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("rogue", 0, 2, 3)])
	var b := party([hero("fighter", 0, 1, 2), hero("mage", 1, 3, 2)])
	var r := _sim(35, a, b, {"start_statuses": [{"side": 1, "slot": [0, 1], "status": "disarm", "dur_ms": 20000}]})
	var foe := uid_at(r, 1, 0, 1)
	var hit_charge := false
	var fired := false
	for ev: Dictionary in r["events"]:
		if float(ev["t"]) > 20.0:
			break
		if ev["type"] == "charge" and int(ev["uid"]) == foe and ev["reason"] == "hit" and int(ev["delta"]) > 0:
			hit_charge = true
		if ev["type"] == "action_start" and int(ev["uid"]) == foe:
			check(ev["kind"] == "ability", "only its ability while disarmed")
			fired = fired or ev["kind"] == "ability"
	check(hit_charge, "hits still charge a disarmed unit")
	check(fired, "a full bar still fires its ability")


func test_ravager_whirlwind_hits_front_foes_and_every_adjacent_ally() -> void:
	var a := party([hero("ravager", 0, 1, 2), hero("fighter", 0, 2, 3), hero("mage", 1, 0, 3), hero("healer", 1, 3, 3)])
	var b := party([hero("stone_sentinel", 0, 0, 6), hero("stone_sentinel", 0, 2, 6), hero("fading_wisp", 1, 1, 4)])
	var r := _sim(36, a, b)
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "whirlwind", "Whirlwind fires")
	var hit := {}
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "damage" and int(ev["src"]) == 0:
			hit[int(ev["dst"])] = true
	check(hit.has(uid_at(r, 1, 0, 0)) and hit.has(uid_at(r, 1, 0, 2)), "every foe in the front column")
	check(not hit.has(uid_at(r, 1, 1, 1)), "not the back column")
	check(hit.has(uid_at(r, 0, 0, 2)), "the ally beside it")
	check(hit.has(uid_at(r, 0, 1, 0)), "the diagonal ally (adjacency all)")
	check(not hit.has(uid_at(r, 0, 1, 3)), "not an ally two rows away")
	check(not hit.has(0), "never itself")


func test_ravager_alone_hurts_only_foes() -> void:
	# Strays: nobody stands beside it, so no friendly fire (its natural home)
	var a := party([hero("ravager", 0, 1, 2), hero("mage", 1, 3)])
	var b := party([hero("stone_sentinel", 0, 0, 6), hero("stone_sentinel", 0, 1, 6)])
	var r := _sim(37, a, b)
	var act := _ability_of(r, 0)
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "damage" and int(ev["src"]) == 0:
			eq(int(_unit_side(r, int(ev["dst"]))), 1, "only foes are hit")


func _unit_side(r: Dictionary, uid: int) -> int:
	for side: Dictionary in r["events"][0]["sides"]:
		for u: Dictionary in side["units"]:
			if int(u["uid"]) == uid:
				return int(u["side"])
	return -1


# ------------------------------------------------------------------ Rogue

func test_saboteur_stops_the_foes_formation_behaviour() -> void:
	# Hearth: the lone post takes less damage per back ally (hearthguard). Cut ropes stop it.
	var a := party([hero("saboteur", 0, 1, 2), hero("fighter", 0, 2, 3)])
	var b := party([hero("fighter", 0, 1, 4), hero("mage", 1, 1, 1), hero("healer", 1, 2, 1)])
	b["unlocked_formations"] = ["hearth"]
	var r := _sim(38, a, b, {"start_statuses": _guard(0, [[0, 1], [0, 2]])})
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "cut_the_ropes", "Cut the Ropes fires")
	var sab := {}
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "status" and ev["status"] == "sabotage":
			sab[int(ev["uid"])] = float(ev["t"]) + float(ev["duration"])
	eq(sab.size(), 3, "every foe is sabotaged")
	var post := uid_at(r, 1, 0, 1)
	var w := _window(r, post, "sabotage")
	var inside := 0
	var before := 0
	for ev: Dictionary in of_type(r, "damage"):
		if int(ev["dst"]) != post or ev["kind"] != "physical":
			continue
		var t := float(ev["t"])
		if t > float(w[0]) and t < float(w[1]):
			inside += 1
			check(mod(ev, "hearthguard").is_empty(), "no Hearthguard while sabotaged")
		elif t < float(w[0]) and not mod(ev, "hearthguard").is_empty():
			before += 1
	check(inside >= 1, "the post is hit while sabotaged (%d)" % inside)
	check(before >= 1, "Hearthguard worked before the ropes were cut (%d)" % before)
	var after := 0
	for ev: Dictionary in of_type(r, "damage"):
		if int(ev["dst"]) == post and float(ev["t"]) >= float(w[1]) and not mod(ev, "hearthguard").is_empty():
			after += 1
	check(after >= 1 or float(r["duration"]) < float(w[1]) + 1.0, "Hearthguard comes back when the sabotage ends")


func test_duelist_parries_and_counters_a_melee_hit() -> void:
	var parried := 0
	for s in 8:
		var a := party([hero("duelist", 0, 1, 2), hero("mage", 1, 3)])
		var b := party([hero("fighter", 0, 1, 3), hero("rogue", 0, 2, 3)])
		var r := _sim(400 + s, a, b, {"start_statuses": _guard(0, [[1, 3]])})
		var act := _ability_of(r, 0)
		eq(String(act["action"]), "riposte", "Riposte fires")
		var stance := _first(r, "status", func(ev: Dictionary) -> bool: return int(ev["uid"]) == 0 and ev["status"] == "riposte")
		check(not stance.is_empty(), "it takes guard")
		var pm := _first(r, "miss", func(ev: Dictionary) -> bool: return ev["reason"] == "parry")
		if pm.is_empty():
			continue
		parried += 1
		eq(int(pm["dst"]), 0, "the Duelist parries")
		var counter := {}
		for ev: Dictionary in r["events"]:
			if float(ev["t"]) != float(pm["t"]):
				continue
			if ev["type"] == "damage" and int(ev["dst"]) == 0 and int(ev["src"]) == int(pm["src"]) and ev["action"] == pm["action"]:
				check(false, "a parried hit deals no damage")
			if ev["type"] == "damage" and int(ev["src"]) == 0 and ev["action"] == "riposte_counter":
				counter = ev
		eq(int(counter.get("dst", -1)), int(pm["src"]), "it answers the attacker")
		check(bool(counter.get("crit", false)), "with a critical counter")
		var ends := _first(r, "status_end", func(ev: Dictionary) -> bool: return int(ev["uid"]) == 0 and ev["status"] == "riposte")
		eq(String(ends.get("reason", "")), "triggered", "the stance is spent")
		var lunge := _first(r, "action_start", func(ev: Dictionary) -> bool:
			return ev["action"] == "riposte_lunge" and float(ev["t"]) < float(pm["t"]) + 4.0)
		check(lunge.is_empty(), "no lunge after a parry")
	check(parried >= 3, "the stance catches a swing in most fights (%d of 8)" % parried)


func test_duelist_lunges_if_nobody_swings() -> void:
	var a := party([hero("duelist", 0, 1, 2), hero("fighter", 0, 2, 2)])
	var b := party([hero("mage", 1, 1, 2), hero("mage", 1, 2, 2)])   # magic only: nobody swings in melee
	var r := _sim(41, a, b, {"start_statuses": _guard(0, [[0, 1], [0, 2]])})
	var stance := _first(r, "status", func(ev: Dictionary) -> bool: return int(ev["uid"]) == 0 and ev["status"] == "riposte")
	check(not stance.is_empty(), "it takes guard")
	var ends := _first(r, "status_end", func(ev: Dictionary) -> bool: return int(ev["uid"]) == 0 and ev["status"] == "riposte")
	eq(String(ends.get("reason", "")), "expired", "nobody swings: the stance runs out")
	var lunge := _first(r, "action_start", func(ev: Dictionary) -> bool: return ev["action"] == "riposte_lunge")
	check(not lunge.is_empty() and int(lunge["uid"]) == 0, "it lunges at the front foe instead")
	if not lunge.is_empty():
		eq(lunge["kind"], "ability", "the lunge is the ability's second half")


func test_nightwatch_catches_the_foe_that_hits_its_neighbour() -> void:
	var caught := 0
	for s in 6:
		var a := party([hero("nightwatch", 0, 1, 2), hero("fighter", 0, 2, 3)])
		var b := party([hero("fighter", 0, 2, 2), hero("mage", 1, 3)])
		var r := _sim(420 + s, a, b, {"start_statuses": _guard(0, [[0, 1], [0, 2]])})
		var act := _ability_of(r, 0)
		eq(String(act["action"]), "keep_watch", "Keep Watch fires")
		var ends := _first(r, "status_end", func(ev: Dictionary) -> bool: return int(ev["uid"]) == 0 and ev["status"] == "watch")
		if String(ends.get("reason", "")) != "triggered":
			continue
		caught += 1
		var strike := {}
		var stun := {}
		var strikes := 0
		for ev: Dictionary in r["events"]:
			if ev["type"] == "damage" and ev["action"] == "watch_strike":
				strikes += 1
				if strike.is_empty():
					strike = ev
			if ev["type"] == "status" and ev["status"] == "stun" and ev["action"] == "watch_strike" and stun.is_empty():
				stun = ev
		eq(int(strike.get("src", -1)), 0, "the Nightwatch strikes")
		eq(float(strike.get("t", -1.0)), float(ends["t"]), "at once, as the neighbour is hit")
		eq(int(stun.get("uid", -2)), int(strike.get("dst", -1)), "and stuns the attacker")
		var cast_n := 0
		for ev: Dictionary in of_type(r, "status"):
			if ev["status"] == "watch":
				cast_n += 1
		check(strikes <= cast_n, "one catch per watch (%d strikes, %d watches)" % [strikes, cast_n])
	check(caught >= 3, "the watch catches an attacker in most fights (%d of 6)" % caught)


func test_nightwatch_with_nobody_beside_it_strikes() -> void:
	var a := party([hero("nightwatch", 0, 0, 2), hero("mage", 1, 2)])
	var r := _sim(43, a, duo(hero("fighter", 0, 0)))
	eq(String(_ability_of(r, 0)["action"]), "nightwatch_blow", "no ally beside it: the fallback blow")


# ------------------------------------------------------------------ Healer

func test_bloodletter_drains_every_foe_to_heal_all_allies() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("rogue", 0, 2, 3), hero("bloodletter", 1, 1, 2)])
	var b := party([hero("stone_sentinel", 0, 1, 5), hero("stone_sentinel", 0, 2, 5), hero("memory_wraith", 1, 1, 5)])
	var r := _sim(44, a, b, {"start_hp": [{"side": 0, "slot": [0, 1], "hp": 40}, {"side": 0, "slot": [0, 2], "hp": 30},
		{"side": 0, "slot": [1, 1], "hp": 50}], "start_statuses": _guard(0, [[0, 1], [0, 2], [1, 1]])})
	var bl := uid_at(r, 0, 1, 1)
	var act := _ability_of(r, bl)
	eq(String(act["action"]), "bloodletting", "Bloodletting fires")
	var dealt := 0
	var hit := {}
	var heals := {}
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "damage" and int(ev["src"]) == bl:
			dealt += int(ev["amount"])
			hit[int(ev["dst"])] = true
		if ev["type"] == "heal" and int(ev["src"]) == bl:
			heals[int(ev["dst"])] = int(ev["amount"])
	eq(hit.size(), 3, "every foe is hit")
	eq(heals.size(), 3, "every (hurt) ally is healed")
	var total := 0
	for k: int in heals:
		total += int(heals[k])
	check(total > 0 and total <= int(ceil(dealt * 0.4)) + 3, "heals share out 40%% of the damage (%d of %d)" % [total, dealt])
	var amounts: Array = heals.values()
	check(amounts.min() == amounts.max(), "an even share each (%s)" % str(amounts))


func test_gravecaller_raises_a_nameless_husk_when_nobody_has_fallen() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("gravecaller", 1, 1, 2)])
	var r := _sim(45, a, party([hero("fighter", 0, 1, 3), hero("mage", 1, 3)]), {"start_statuses": _guard(0, [[0, 1], [1, 1]])})
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "raise_husk", "Raise Husk fires with nobody fallen (Grave Bolt is gone here)")
	var sp := _first(r, "spawn", func(ev: Dictionary) -> bool: return ev["summon"] == "husk")
	check(not sp.is_empty(), "a husk rises")
	if sp.is_empty():
		return
	eq(int(sp["raised"]), -1, "a nameless one: nobody it was")
	eq(String(sp["unit"]["name"]), "Nameless Husk", "named as the Vault's long-dead")
	eq(String(sp["unit"]["class_name"]), "Nameless Husk", "no class of its own")
	eq(int(sp["slot"][0]), 0, "in a front slot")
	eq(String(sp["unit"]["tier"]), "summon", "a summon (never standing, never in the shape)")
	# weaker than any raised hero: below half of every hero class's level-1 HP and stat total
	var nm: Dictionary = GameData.get_action("raise_husk")["effects"][0]["nameless"]["stats"]
	var nm_total := float(nm["hp"]) / 5.0 + float(nm["atk"]) + float(nm["def"]) + float(nm["mag"]) + float(nm["spd"])
	for cid: String in GameData.Classes.CLASSES:
		var c: Dictionary = GameData.Classes.CLASSES[cid]
		if not ["base", "advanced", "legendary"].has(String(c["tier"])):
			continue
		var st: Dictionary = c["stats"]
		var raised_total := 0.5 * (float(st["hp"]) / 5.0 + float(st["atk"]) + float(st["def"]) + float(st["mag"])) + 0.75 * float(st["spd"])
		check(float(nm["hp"]) < 0.5 * float(st["hp"]), "nameless husk HP below a raised %s" % cid)
		check(nm_total < raised_total, "nameless husk total %.1f below a raised %s (%.1f)" % [nm_total, cid, raised_total])


func test_gravecaller_still_raises_the_fallen_first() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("gravecaller", 1, 1, 2)])
	var b := party([hero("rogue", 0, 1), hero("mage", 1, 3)])
	var r := CombatSim.simulate(17, a, b, {"start_hp": [{"side": 1, "slot": [0, 1], "hp": 1}]})
	var sp := _first(r, "spawn", func(ev: Dictionary) -> bool: return ev["summon"] == "husk")
	check(not sp.is_empty() and int(sp["raised"]) >= 0, "with someone fallen, it raises them (not a nameless husk)")


# ------------------------------------------------------------------ Mage: Enshriner

func _enshrine_fight(seed_value: int, opts := {}) -> Dictionary:
	var a := party([hero("fighter", 0, 1, 3), hero("enshriner", 1, 1, 2)])
	var b := party([hero("berserker", 0, 1, 2), hero("fighter", 0, 2, 2), hero("mage", 1, 1, 2)])
	return _sim(seed_value, a, b, opts)


func test_enshriner_seals_the_strongest_foe() -> void:
	var r := _enshrine_fight(46, {"start_statuses": _guard(0, [[0, 1], [1, 1]])})
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "enshrine", "Enshrine fires")
	var bers := uid_at(r, 1, 0, 1)
	eq(int(act["target"]), bers, "the strongest foe: highest Atk or Mag (the Berserker)")
	var w := _window(r, bers, "enshrine")
	check(not w.is_empty(), "it is sealed")
	if w.is_empty():
		return
	for ev: Dictionary in r["events"]:
		var t := float(ev["t"])
		if t <= float(w[0]) or t >= float(w[1]):
			continue
		if ev["type"] == "action_start":
			check(int(ev["uid"]) != bers, "a sealed unit can't act")
			if int(ev["uid"]) == 0:
				check(int(ev["target"]) != bers, "melee reaches past a sealed front unit (rule (d))")
		if ev["type"] in ["damage", "heal"] and int(ev["dst"]) == bers:
			check(ev["kind"] == "sudden_death" if ev["type"] == "damage" else false, "nothing but the Fading reaches it")
		if ev["type"] == "status" and int(ev["uid"]) == bers:
			check(false, "no status lands on a sealed unit")
	var imm := _first(r, "status", func(ev: Dictionary) -> bool: return int(ev["uid"]) == bers and ev["status"] == "seal_immune")
	check(not imm.is_empty() and absf(float(imm["t"]) - float(w[1])) < 0.001, "released: crystal-worn at once (rule (c))")


func test_sealed_last_foe_still_stands() -> void:
	# rule (a): you can't win by sealing the last foe
	var a := party([hero("fighter", 0, 1, 3), hero("enshriner", 1, 1, 2)])
	var b := party([hero("stone_sentinel", 0, 1, 1)])
	var r := _sim(47, a, b, {"start_statuses": [{"side": 1, "slot": [0, 1], "status": "enshrine", "dur_ms": 6000}]})
	check(float(r["duration"]) > 6.0, "the fight goes on while the last foe is sealed (ended %.1f s)" % float(r["duration"]))
	var ko := _first(r, "ko", func(ev: Dictionary) -> bool: return true)
	check(ko.is_empty() or float(ko["t"]) >= 6.0, "the sealed foe isn't counted as fallen")


func test_the_fading_reaches_a_sealed_unit() -> void:
	# rule (b): sealing can't win a Fading race
	var a := party([hero("fighter", 0, 1, 3), hero("mage", 1, 1, 2)])
	var b := party([hero("fighter", 0, 1, 3), hero("mage", 1, 1, 2)])
	var r := CombatSim.simulate(48, a, b, {"tuning": {"sudden_death_start_ms": 2000},
		"start_statuses": [{"side": 1, "slot": [0, 1], "status": "enshrine", "dur_ms": 30000}]})
	var sealed := uid_at(r, 1, 0, 1)
	var faded := _first(r, "damage", func(ev: Dictionary) -> bool: return int(ev["dst"]) == sealed and ev["kind"] == "sudden_death")
	check(not faded.is_empty(), "the Fading erodes a sealed unit")
	var other := _first(r, "damage", func(ev: Dictionary) -> bool: return int(ev["dst"]) == sealed and ev["kind"] != "sudden_death")
	check(other.is_empty() or float(other["t"]) >= 30.0, "nothing else reaches it while sealed")


func test_seal_immunity_turns_the_enshriner_elsewhere() -> void:
	# rule (c): a crystal-worn unit can't be sealed again for a while; the next strongest is
	var r := _enshrine_fight(49, {"start_statuses": [{"side": 1, "slot": [0, 1], "status": "seal_immune", "dur_ms": 60000}]})
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "enshrine", "Enshrine fires")
	check(int(act["target"]) != uid_at(r, 1, 0, 1), "the crystal-worn Berserker is passed over")


func test_enshriner_with_nobody_sealable_strikes() -> void:
	var imm: Array = []
	for sl: Array in [[0, 1], [0, 2], [1, 1]]:
		imm.append({"side": 1, "slot": sl, "status": "seal_immune", "dur_ms": 60000})
	var r := _enshrine_fight(50, {"start_statuses": imm})
	eq(String(_ability_of(r, 1)["action"]), "shrine_shard", "nobody can be sealed: the fallback shard")


func test_a_sealed_unit_leaves_its_formation() -> void:
	# Keeper's Ring: the ringed keeper can't be single-targeted while all three front units stand
	# in the shape. Sealing one front unit takes it out of the shape, so the ring breaks.
	var a := party([hero("fighter", 0, 1, 3), hero("mage", 1, 1, 2)])
	var b := party([hero("stone_sentinel", 0, 0, 4), hero("stone_sentinel", 0, 1, 4), hero("stone_sentinel", 0, 2, 4),
		hero("fading_wisp", 1, 1, 2)])
	b["unlocked_formations"] = ["keepers_ring"]
	var keeper_hits := func(r: Dictionary, until: float) -> int:
		var n := 0
		var keeper := uid_at(r, 1, 1, 1)
		for ev: Dictionary in of_type(r, "action_start"):
			if float(ev["t"]) < until and int(ev["target"]) == keeper and ev["area"] == "single":
				n += 1
		return n
	var base := CombatSim.simulate(51, a, b)
	eq(String(base["events"][0]["sides"][1]["formation"]["id"]), "keepers_ring", "the foes stand in Keeper's Ring")
	eq(int(keeper_hits.call(base, 8.0)), 0, "unsealed: nobody single-targets the keeper")
	var r := CombatSim.simulate(51, a, b, {"start_statuses": [{"side": 1, "slot": [0, 1], "status": "enshrine", "dur_ms": 8000}]})
	check(int(keeper_hits.call(r, 8.0)) >= 1, "a front unit sealed: the ring is broken and the keeper is reachable")


# ------------------------------------------------------------------ broad

func test_round2_classes_fight_cleanly() -> void:
	# every round-2 class, in random parties against random parties and monsters: the fight ends,
	# and the round-2 statuses show up
	var ids := ["halberdier", "lightsworn", "bladebreaker", "ravager", "saboteur", "duelist", "nightwatch",
		"bloodletter", "gravecaller", "enshriner", "aegisbearer", "informant", "confessor"]
	var rng := Rng.new(777)
	var seen := {}
	for i in 120:
		var p := PartyGen.random_party(rng)
		(p["heroes"] as Array)[0]["class"] = ids[i % ids.size()]
		(p["heroes"] as Array)[0]["level"] = 2
		var foe := PartyGen.monster_group(rng, 1 + i % 8) if i % 3 == 0 else PartyGen.random_party(rng)
		var r := CombatSim.simulate(i, p, foe, {"tuning": FAST} if i % 2 == 0 else {})
		check(not r.has("error"), "fight %d runs: %s" % [i, str(r.get("error", ""))])
		check([-1, 0, 1].has(int(r.get("winner", -2))), "fight %d ends" % i)
		for ev: Dictionary in of_type(r, "status"):
			seen[ev["status"]] = true
		for ev: Dictionary in of_type(r, "skip"):
			seen["skip:" + String(ev["reason"])] = true
		for ev: Dictionary in of_type(r, "miss"):
			seen["miss:" + String(ev["reason"])] = true
	for k: String in ["disarm", "sabotage", "riposte", "watch", "enshrine", "seal_immune", "skip:disarm", "miss:parry", "heal_invert"]:
		check(seen.has(k), "%s happens in random fights" % k)


# ------------------------------------------------------------------ round 3 (user-approved via the lead)

func test_aegisbearer_shield_draws_every_melee_hit() -> void:
	var a := party([hero("aegisbearer", 0, 1, 2), hero("fighter", 0, 2, 3), hero("rogue", 0, 0, 3)])
	var b := party([hero("fighter", 0, 0, 2), hero("rogue", 0, 2, 2), hero("berserker", 0, 3, 2)])
	var r := _sim(60, a, b)
	var ab := uid_at(r, 0, 0, 1)
	var act := _ability_of(r, ab)
	eq(String(act["action"]), "raise_the_aegis", "Raise the Aegis fires")
	var sh := _first(r, "status", func(ev: Dictionary) -> bool: return int(ev["uid"]) == ab and ev["status"] == "shield")
	check(not sh.is_empty() and float(sh.get("value", 0.0)) >= 40.0, "a large shield on itself (%s)" % str(sh.get("value", 0)))
	var w := _window(r, ab, "shield")
	if w.is_empty():
		return
	var melee := 0
	for ev: Dictionary in of_type(r, "action_start"):
		var t := float(ev["t"])
		if t <= float(w[0]) or t >= float(w[1]) or _unit_side(r, int(ev["uid"])) != 1:
			continue
		var ad: Dictionary = GameData.get_action(String(ev["action"]))
		if String(ad["target"]) == "melee" or String(ad.get("anim", "")) == "dash":
			melee += 1
			eq(int(ev["target"]), ab, "every foe's melee hits the Aegisbearer while the shield holds")
	check(melee >= 1, "melee sampled while the shield held (%d)" % melee)
	eq(String(GameData.get_class_def("aegisbearer")["region"]), "LG*", "Fighter Mercy+Order corner")


func test_informant_shields_the_target_of_the_next_enemy_ability() -> void:
	# The foe Fighter is stunned, so the foe Rogue's Backstab comes next: it hits the enemy with the
	# lowest current HP (our Mage, 40 HP), not our weakest by HP fraction (the Fighter, 60/162). The
	# Informant must shield the Mage, the Backstab's target, and nobody else.
	var hits := 0
	for s in 6:
		# Strays on both sides (no Kindred charge), and the Informant's own stab lands on the stunned
		# Fighter in its row, so the Rogue isn't charged to full before the cast
		var a := party([hero("fighter", 0, 1, 3), hero("informant", 1, 3, 2), hero("mage", 1, 0)])
		var b := party([hero("rogue", 0, 0, 2), hero("fighter", 0, 3, 2)])
		var r := _sim(610 + s, a, b, {"start_hp": [{"side": 0, "slot": [1, 0], "hp": 40}, {"side": 0, "slot": [0, 1], "hp": 60}],
			"start_statuses": [{"side": 1, "slot": [0, 3], "status": "stun", "dur_ms": 60000}]})
		var inf := uid_at(r, 0, 1, 3)
		var mage := uid_at(r, 0, 1, 0)
		var act := _ability_of(r, inf)
		if act.is_empty():
			continue
		var shielded := {}
		for ev: Dictionary in _during(r, act):
			if ev["type"] == "status" and ev["status"] == "shield" and int(ev["src"]) == inf:
				shielded[int(ev["uid"])] = true
		var bs := _first(r, "action_start", func(ev: Dictionary) -> bool:
			return ev["action"] == "backstab" and float(ev["t"]) > float(act["t"]))
		if not bs.is_empty() and int(bs["target"]) == mage:
			hits += 1
			eq(shielded.keys(), [mage], "seed %d: the Backstab's target alone is shielded" % (610 + s))
	check(hits >= 3, "the foreseen Backstab came (%d of 6)" % hits)


func test_informant_splits_the_shield_against_an_area_ability() -> void:
	# PROVISIONAL: a foe Mage's Firestorm will hit everyone: each ally gets an even share
	var a := party([hero("fighter", 0, 1, 3), hero("informant", 1, 1, 2), hero("rogue", 0, 2, 3)])
	var b := party([hero("fighter", 0, 1, 3), hero("mage", 1, 1, 3)])
	var r := _sim(62, a, b, {"start_statuses": [{"side": 1, "slot": [0, 1], "status": "stun", "dur_ms": 60000}]})
	var inf := uid_at(r, 0, 1, 1)
	var act := _ability_of(r, inf)
	var vals := {}
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "status" and ev["status"] == "shield" and int(ev["src"]) == inf:
			vals[int(ev["uid"])] = int(float(ev["value"]))
	eq(vals.size(), 3, "every ally the Firestorm will hit is shielded (%s)" % str(vals))
	if vals.size() > 1:
		var v: Array = vals.values()
		check(v.min() == v.max(), "an even split (%s)" % str(vals))
		var whole := int(round(3.4 * 0.6 * float(unit_stats(r, inf)["mag"])))
		check(absi(int(v[0]) * v.size() - whole) <= v.size(), "the shares add up to one shield (%d x %d ~ %d)" % [v[0], v.size(), whole])


func test_informant_with_no_ability_coming_shields_the_weakest() -> void:
	# PROVISIONAL: no foe is near a full bar, so the whole shield goes to the weakest ally
	var a := party([hero("fighter", 0, 1, 3), hero("informant", 1, 1, 2), hero("rogue", 0, 2, 3)])
	var b := party([hero("stone_sentinel", 0, 1, 6), hero("stone_sentinel", 0, 2, 6)])
	var r := CombatSim.simulate(63, a, b, {"tuning": {"start_charge_spread": 0, "start_charge_bonus": 0},
		"start_hp": [{"side": 0, "slot": [0, 2], "hp": 20}],
		"start_statuses": [{"side": 0, "slot": [1, 1], "status": "boon", "stat": "spd", "value": 3.0, "dur_ms": 60000}]})
	var inf := uid_at(r, 0, 1, 1)
	var act := _ability_of(r, inf)
	check(not act.is_empty(), "Read the Orders fires")
	var got: Array = []
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "status" and ev["status"] == "shield" and int(ev["src"]) == inf:
			got.append(int(ev["uid"]))
	eq(got.size(), 1, "one ally, the whole shield")


func test_confessor_brands_the_last_attacker_and_its_heals_burn() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("confessor", 1, 1, 2)])
	var b := party([hero("fighter", 0, 1, 2), hero("cleric", 1, 1, 3)])
	var r := _sim(64, a, b, {"start_statuses": _guard(0, [[0, 1], [1, 1]])})
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "brand_of_flame", "the Retribution Flame fires")
	eq(String(act["name"]), "Retribution Flame", "named Retribution Flame")
	var br := _first(r, "status", func(ev: Dictionary) -> bool: return ev["status"] == "heal_invert")
	eq(int(br.get("uid", -1)), int(act["target"]), "the brand is heal inversion")


func test_confessor_targets_the_last_attacker() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("confessor", 1, 1, 2)])
	var b := party([hero("fighter", 0, 1, 2), hero("archmage", 1, 1, 1), hero("rogue", 0, 2, 2)])
	var r := CombatSim.simulate(66, a, b, {"start_statuses": _guard(0, [[0, 1], [1, 1]])})
	var act := _ability_of(r, 1)
	check(not act.is_empty(), "the Confessor fires")
	var last := -1
	for ev: Dictionary in r["events"]:
		if ev == act:
			break
		if ev["type"] == "absorb" and int(ev["src"]) >= 0 and _unit_side(r, int(ev["src"])) == 1:
			last = last   # absorbed hits aren't hurt: no change
		if ev["type"] == "damage" and int(ev["src"]) >= 0 and _unit_side(r, int(ev["src"])) == 1 and int(ev["amount"]) > 0:
			last = int(ev["src"])
	if last >= 0:
		eq(int(act["target"]), last, "it brands the foe that last hurt an ally")
	else:
		eq(int(act["target"]), uid_at(r, 1, 1, 1), "nobody hurt an ally yet: the strongest foe (the Archmage)")


func test_reliquarist_is_the_enshriner_renamed() -> void:
	eq(String(GameData.get_class_def("enshriner")["name"]), "Reliquarist", "display name")
	check(String(GameData.get_action("enshrine")["text"]).contains("reliquar"), "reliquary flavour")


# ------------------------------------------------------------------ separate ability timer (user rule, 2026-10-06)

func test_a_full_bar_casts_before_a_full_gauge() -> void:
	# A unit at full charge acts before a unit whose gauge is already full, and the cast leaves its
	# own gauge as it was.
	var checked := 0
	for s in 20:
		var r := CombatSim.simulate(700 + s, PartyGen.demo_party(), PartyGen.demo_rival())
		var evs: Array = r["events"]
		for k in evs.size():
			var ev: Dictionary = evs[k]
			if ev["type"] != "charge" or not ev["ready"]:
				continue
			var uid := int(ev["uid"])
			var nxt := {}
			for j in range(k + 1, evs.size()):
				if evs[j]["type"] == "action_start":
					nxt = evs[j]
					break
				if evs[j]["type"] in ["skip", "sudden_death", "fight_end", "ko"]:
					break
			if nxt.is_empty() or int(nxt["uid"]) != uid:
				continue
			checked += 1
			eq(nxt["kind"], "ability", "the charged unit's next action is its ability")
			var g: Array = nxt["gauges"]
			check(float(g[uid]) < 1.0 or float(g[uid]) == 1.0, "gauges snapshot present")
	check(checked > 10, "ready units cast next (%d)" % checked)


func test_ability_cast_leaves_the_gauge() -> void:
	# The caster's gauge in the cast's snapshot is its real fill (not spent), and its next basic turn
	# comes no later than it would have: the gauge kept filling.
	var a := party([hero("fighter", 0, 1, 3), hero("mage", 1, 1, 3)])
	var b := party([hero("stone_sentinel", 0, 1, 6), hero("stone_sentinel", 0, 2, 6)])
	var r := _sim(71, a, b)
	var cast := _ability_of(r, 0)
	check(not cast.is_empty(), "the Fighter casts")
	var g := float((cast["gauges"] as Array)[0])
	check(g < 1.0, "its gauge is untouched by the cast (%.3f, not spent to 0 or shown as a full turn)" % g)
	var basic := _first(r, "action_start", func(ev: Dictionary) -> bool:
		return int(ev["uid"]) == 0 and ev["kind"] == "basic" and float(ev["t"]) > float(cast["t"]))
	var before := _first(r, "action_start", func(ev: Dictionary) -> bool:
		return int(ev["uid"]) == 0 and ev["kind"] == "basic" and float(ev["t"]) < float(cast["t"]))
	check(not basic.is_empty() and not before.is_empty(), "basic turns around the cast")


func test_charge_on_act_only_from_basic_actions() -> void:
	var r := _sim(72, party([hero("fighter", 0, 1, 3), hero("mage", 1, 1, 3)]), party([hero("stone_sentinel", 0, 1, 6)]))
	var cast := _ability_of(r, 0)
	for ev: Dictionary in _during(r, cast):
		if ev["type"] == "charge" and int(ev["uid"]) == 0:
			check(ev["reason"] != "act", "an ability cast grants no charge_on_act")


func test_a_stunned_charged_unit_waits_for_the_stun() -> void:
	# side 1's Fighter is stunned for 4 s from the start at 99 charge; it is hit to full while stunned,
	# and casts only once the stun is over
	var a := party([hero("rogue", 0, 1, 3), hero("rogue", 0, 2, 3)])
	var b := party([hero("fighter", 0, 1, 3), hero("mage", 1, 3)])
	var r := _sim(73, a, b, {"start_statuses": [{"side": 1, "slot": [0, 1], "status": "stun", "dur_ms": 4000}]})
	var foe := uid_at(r, 1, 0, 1)
	var ready := _first(r, "charge", func(ev: Dictionary) -> bool: return int(ev["uid"]) == foe and ev["ready"])
	var cast := _ability_of(r, foe)
	check(not ready.is_empty() and float(ready["t"]) < 4.0, "it is full while stunned")
	check(not cast.is_empty() and float(cast["t"]) >= 4.0, "its ability waits for the stun to end (%.2f s)" % float(cast.get("t", -1.0)))
	var end := _first(r, "status_end", func(ev: Dictionary) -> bool: return int(ev["uid"]) == foe and ev["status"] == "stun")
	var between := 0
	for ev: Dictionary in of_type(r, "action_start"):
		if not end.is_empty() and float(ev["t"]) > float(end["t"]) and float(ev["t"]) < float(cast["t"]):
			between += 1
	eq(between, 0, "and fires at the very next boundary after it")
