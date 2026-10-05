extends "res://tests/test_case.gd"
## Readability targets from the round-1 critique (Super Auto Pets bar), measured like the
## critic's probe: abilities fire, charged units get their turn, turns come around quickly,
## formation effects are signed and sized, names are unambiguous.

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Rng = preload("res://core/rng.gd")


func _measure(monsters: bool) -> Dictionary:
	var rng := Rng.new(1)
	var n := 300
	var units := 0
	var fired_units := 0
	var charged_never := 0
	var wait_sum := 0.0
	var wait_n := 0
	var band := 0
	for i in n:
		var a := PartyGen.random_party(rng)
		var b := PartyGen.monster_group(rng, 1 + i % 10) if monsters else PartyGen.random_party(rng)
		var r := CombatSim.simulate(i + 1000, a, b)
		var d := float(r["duration"])
		if d >= 15.0 and d <= 40.0:
			band += 1
		var last := {}
		var fired := {}
		var charged := {}
		for ev: Dictionary in r["events"]:
			match String(ev["type"]):
				"fight_start":
					for s: Dictionary in ev["sides"]:
						units += (s["units"] as Array).size()
				"action_start":
					var u := int(ev["uid"])
					if last.has(u):
						wait_sum += float(ev["t"]) - float(last[u])
						wait_n += 1
					last[u] = float(ev["t"])
					if ev["kind"] == "ability":
						fired[u] = true
				"charge":
					if int(ev["charge"]) >= 100:
						charged[int(ev["uid"])] = true
		fired_units += fired.size()
		for u: int in charged:
			if not fired.has(u):
				charged_never += 1
	return {"fired": float(fired_units) / units, "charged_never": float(charged_never) / units,
		"wait": wait_sum / maxf(1.0, wait_n), "band": float(band) / n}


func _check_targets(m: Dictionary, what: String) -> void:
	check(float(m["fired"]) >= 0.85, "%s: >=85%% of units fire their ability (%.1f%%)" % [what, 100.0 * float(m["fired"])])
	check(float(m["charged_never"]) < 0.08, "%s: <8%% charged but never fired (%.1f%%)" % [what, 100.0 * float(m["charged_never"])])
	check(float(m["wait"]) <= 4.5, "%s: mean wait between a unit's turns <= 4.5 s (%.2f)" % [what, float(m["wait"])])
	check(float(m["band"]) >= 0.78, "%s: >=78%% of fights in 15-40 s (%.1f%%)" % [what, 100.0 * float(m["band"])])


func test_pvp_targets() -> void:
	_check_targets(_measure(false), "PvP")


func test_monster_targets() -> void:
	_check_targets(_measure(true), "monsters")


func test_full_charge_jumps_queue() -> void:
	# After a "ready" charge event, the charged unit's ability is the next action that
	# starts (unless another unit was already charged and queued first).
	var rng := Rng.new(9)
	var waits := 0
	var ready_total := 0
	for i in 50:
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), PartyGen.random_party(rng))
		var queue: Array = []
		for ev: Dictionary in r["events"]:
			match String(ev["type"]):
				"charge":
					if ev["ready"]:
						queue.append(int(ev["uid"]))
						ready_total += 1
				"ko":
					queue.erase(int(ev["uid"]))
				"action_start":
					if not queue.is_empty():
						if queue.has(int(ev["uid"])):
							# its ability, or a held heal (nobody wounded): either way it got its turn
							if ev["kind"] != "ability":
								check(ev["action"] == "smite", "only healers hold a charged ability")
							queue.erase(int(ev["uid"]))
						else:
							waits += 1
	check(ready_total > 0, "units reach full charge")
	eq(waits, 0, "no basic action happens while a fully charged unit waits")


func test_formation_mods_signed_and_sparse() -> void:
	var rng := Rng.new(8)
	var hits := 0
	var with_formation := 0
	for i in 100:
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), PartyGen.random_party(rng))
		for ev: Dictionary in of_type(r, "damage"):
			if ev["kind"] == "sudden_death":
				continue
			hits += 1
			var n := 0
			for m: Dictionary in ev["mods"]:
				check(m.has("id") and m["mult"] is float, "every modifier has an id and a numeric multiplier")
				if m["id"] == "formation":
					n += 1
					check(absf(float(m["mult"]) - 1.0) >= 0.0499, "formation modifier only when it matters (>=5%)")
					check(String(m["name"]) != "" and String(m["source"]).contains(":"), "formation modifier names its source")
			check(n <= 1, "at most one formation modifier per hit")
			if n > 0:
				with_formation += 1
	check(float(with_formation) / hits < 0.6, "formation modifiers are not on every hit (%.0f%%)" % [100.0 * with_formation / hits])
	var r2 := CombatSim.simulate(1, PartyGen.demo_party(), PartyGen.demo_rival())
	eq(of_type(r2, "formation").size(), 2, "one formation banner event per side")


func test_unique_labels() -> void:
	var dup := party([hero("mage", 1, 0), hero("mage", 1, 1), hero("fighter", 0, 0)])
	for h: Dictionary in dup["heroes"]:
		h["name"] = "Tamsin"
	var r := CombatSim.simulate(1, dup, PartyGen.demo_rival())
	var labels := {}
	for u: Dictionary in r["events"][0]["sides"][0]["units"]:
		labels[u["label"]] = true
	eq(labels.size(), 3, "duplicate names get distinct labels")
	check(labels.has("Tamsin") and labels.has("Tamsin 2") and labels.has("Tamsin 3"), "labels are Name, Name 2, Name 3")
	var rng := Rng.new(3)
	for i in 100:
		for p: Dictionary in [PartyGen.random_party(rng), PartyGen.monster_group(rng, 1 + i % 10)]:
			var names := {}
			for h: Dictionary in p["heroes"]:
				names[h["name"]] = true
			if names.size() != (p["heroes"] as Array).size():
				check(false, "generator produced duplicate names: %s" % str(names.keys()))
				return
	check(true, "generators produce unique names per side")


func test_ability_pacing() -> void:
	# Round-2 critique: abilities ~25-30% of actions, spread out, no cascades, few numbers at once.
	for monsters in [false, true]:
		var rng := Rng.new(2)
		var acts := 0
		var abil := 0
		var cascade := 0
		var max_streak := 0
		var max_numbers := 0
		for i in 300:
			var a := PartyGen.random_party(rng)
			var b := PartyGen.monster_group(rng, 1 + i % 10) if monsters else PartyGen.random_party(rng)
			var r := CombatSim.simulate(i, a, b)
			var cur_kind := ""
			var ready_by_ability := {}
			var streak := 0
			var at := {}
			for ev: Dictionary in r["events"]:
				match String(ev["type"]):
					"action_start":
						acts += 1
						cur_kind = String(ev["kind"])
						if cur_kind == "ability":
							abil += 1
							streak += 1
							max_streak = maxi(max_streak, streak)
							if ready_by_ability.has(int(ev["uid"])):
								cascade += 1
							ready_by_ability.erase(int(ev["uid"]))
						else:
							streak = 0
					"charge":
						if ev["ready"] and ev["reason"] == "hit" and cur_kind == "ability":
							ready_by_ability[int(ev["uid"])] = true
					"damage", "heal":
						var k := int(round(float(ev["t"]) * 1000.0))
						at[k] = int(at.get(k, 0)) + 1
						max_numbers = maxi(max_numbers, int(at[k]))
		var share := float(abil) / acts
		var tag := "monsters" if monsters else "PvP"
		check(share >= 0.22 and share <= 0.32, "%s: abilities are 22-32%% of actions (%.1f%%)" % [tag, 100.0 * share])
		eq(cascade, 0, "%s: no ability is readied by another ability's hit" % tag)
		check(max_streak <= 3, "%s: at most 3 abilities in a row (%d)" % [tag, max_streak])
		check(max_numbers <= 5, "%s: at most 5 numbers land at one instant (%d)" % [tag, max_numbers])


func test_abilities_beat_basics() -> void:
	# An ability's total effect must beat the same unit's average basic action, in >= 95% of casts.
	var rng := Rng.new(11)
	var weak := 0
	var total := 0
	for i in 300:
		var b := PartyGen.monster_group(rng, 1 + i % 10) if i % 2 == 1 else PartyGen.random_party(rng)
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), b)
		var basic_sum := {}
		var basic_n := {}
		var abil: Array = []
		var cur := {}
		for ev: Dictionary in (r["events"] as Array) + [{"type": "action_start", "uid": -1, "kind": "", "t": 0.0}]:
			match String(ev["type"]):
				"action_start":
					if not cur.is_empty():
						if cur["kind"] == "ability":
							abil.append(cur)
						else:
							basic_sum[cur["uid"]] = float(basic_sum.get(cur["uid"], 0.0)) + float(cur["total"])
							basic_n[cur["uid"]] = int(basic_n.get(cur["uid"], 0)) + 1
					cur = {"uid": int(ev["uid"]), "kind": ev["kind"], "total": 0.0}
				"damage", "heal":
					if int(ev["src"]) >= 0 and not cur.is_empty():
						cur["total"] = float(cur["total"]) + float(ev["amount"])
		for ab: Dictionary in abil:
			if basic_n.has(ab["uid"]):
				total += 1
				if float(ab["total"]) <= float(basic_sum[ab["uid"]]) / float(basic_n[ab["uid"]]):
					weak += 1
	check(total > 1000, "enough abilities sampled")
	check(float(weak) / total <= 0.05, "abilities beat the unit's mean basic action (weak %.1f%%)" % [100.0 * weak / total])


func test_formation_cues_are_truthful_and_banner_complete() -> void:
	# Truth beats coverage: every non-start formation_proc names a unit doing its trigger at that
	# exact instant (critic5/cue.gd); every buff and debuff is listed in the side's banner.
	var rng := Rng.new(11)
	var bad := 0
	var cues := 0
	for i in 400:
		var b := PartyGen.monster_group(rng, 1 + i % 10) if i % 2 == 1 else PartyGen.random_party(rng)
		var r := CombatSim.simulate(500 + i, PartyGen.random_party(rng), b)
		var evs: Array = r["events"]
		var at := {}
		for ev: Dictionary in evs:
			var t := int(round(float(ev["t"]) * 1000.0))
			if not at.has(t):
				at[t] = {"attack": {}, "defend": {}, "turn": {}, "heal": {}, "crit": {}, "charge": {}}
			match String(ev["type"]):
				"action_start":
					at[t]["turn"][int(ev["uid"])] = true
				"damage":
					at[t]["attack"][int(ev["src"])] = true
					at[t]["defend"][int(ev["dst"])] = true
					if ev["crit"]:
						at[t]["crit"][int(ev["src"])] = true
				"heal":
					at[t]["heal"][int(ev["src"])] = true
				"charge":
					at[t]["charge"][int(ev["uid"])] = true
		for ev: Dictionary in evs:
			if ev["type"] != "formation_proc" or ev["trigger"] == "start":
				continue
			cues += 1
			if not at[int(round(float(ev["t"]) * 1000.0))][String(ev["trigger"])].has(int(ev["uid"])):
				bad += 1
		# banner: the formation event lists every buff and debuff of the side's shape (data)
		for s in 2:
			var banner: Dictionary = evs[1 + s]
			eq(String(banner["type"]), "formation", "banner event follows fight_start")
			var f: Dictionary = banner["formation"]
			check((f["buffs"] as Array).size() >= 1 and (f["debuffs"] as Array).size() >= 1, "banner shows a buff and a debuff")
	check(cues > 1000, "cues sampled (%d)" % cues)
	eq(bad, 0, "formation cues on a unit not doing the named trigger")


func test_ready_unit_beats_sudden_death_tick() -> void:
	var rng := Rng.new(5)
	var broken := 0
	for i in 200:
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), PartyGen.random_party(rng), {"tuning": {"damage_scale": 0.6}})
		var pending: Array = []
		for ev: Dictionary in r["events"]:
			match String(ev["type"]):
				"charge":
					if ev["ready"]:
						pending.append(int(ev["uid"]))
				"ko":
					pending.erase(int(ev["uid"]))
				"sudden_death":
					if not pending.is_empty():
						broken += 1
				"action_start":
					pending.erase(int(ev["uid"]))
	eq(broken, 0, "a sudden-death tick never cuts in front of a fully charged unit")


func test_formation_cue_rules() -> void:
	# Cues once per fight per effect, never for a KO'd unit, never alongside a formation tag on a
	# hit at the same instant; no "pierce" anywhere.
	var rng := Rng.new(12)
	var cues := 0
	var n := 300
	for i in n:
		var b := PartyGen.monster_group(rng, 1 + i % 10) if i % 2 == 1 else PartyGen.random_party(rng)
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), b)
		var once := {}
		var dead := {}
		var tagged_at := {}
		for ev: Dictionary in r["events"]:
			match String(ev["type"]):
				"ko":
					dead[int(ev["uid"])] = true
				"damage":
					for m: Dictionary in ev["mods"]:
						check(m["id"] != "pierce", "no pierce modifier")
						if m["id"] == "formation":
							tagged_at[ev["t"]] = true
				"formation_proc":
					cues += 1
					var key := "%d|%s|%s" % [ev["side"], ev["source"], ev["stat"]]
					if once.has(key) or dead.has(int(ev["uid"])) or tagged_at.has(ev["t"]):
						check(false, "cue breaks the rules: %s" % ev)
						return
					once[key] = true
	check(float(cues) / n <= 8.0, "few formation cues per fight (%.1f)" % (float(cues) / n))


func test_heal_never_announced_empty() -> void:
	var rng := Rng.new(13)
	for i in 300:
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), PartyGen.random_party(rng))
		var evs: Array = r["events"]
		for k in evs.size():
			var ev: Dictionary = evs[k]
			if ev["type"] == "action_start" and ev["kind"] == "ability" and String(ev["anim"]).begins_with("heal"):
				var healed := false
				var j := k + 1
				while j < evs.size() and evs[j]["type"] != "action_start" and evs[j]["type"] != "sudden_death":
					healed = healed or evs[j]["type"] == "heal"
					j += 1
				if not healed:
					check(false, "fight %d: a heal was announced but healed nothing" % i)
					return
	check(true, "every announced heal heals")
