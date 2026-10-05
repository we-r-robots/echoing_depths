extends "res://tests/test_case.gd"
## Schema conformance: every event of ~1000 fights (PvP, monsters, forced sudden death) is
## checked field by field against the schema documented in core/README.md: exact key set,
## value types and enumerated values. The narrator must also handle every fight cleanly
## (the runner fails on any script error).

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Narrator = preload("res://core/narrator.gd")
const Rng = preload("res://core/rng.gd")

const I := TYPE_INT
const F := TYPE_FLOAT
const S := TYPE_STRING
const B := TYPE_BOOL
const A := TYPE_ARRAY
const D := TYPE_DICTIONARY

## type -> {field: TYPE or [TYPE, allowed values]}; "t" and "type" are implied.
const EVENTS := {
	"fight_start": {"seed": I, "data_version": I, "sudden_death_at": F, "gauge_fill_per_spd": F, "sides": A},
	"formation": {"side": [I, [0, 1]], "formation": D, "compositions": A},
	"formation_proc": {"side": [I, [0, 1]], "uid": I, "source": S, "name": S,
		"stat": [S, ["hp_pct", "atk_pct", "def_pct", "mag_pct", "spd_pct", "crit_add", "charge_pct", "heal_pct"]],
		"value": F, "sign": [S, ["buff", "debuff"]],
		"trigger": [S, ["start", "turn", "attack", "defend", "crit", "charge", "heal"]]},
	"action_start": {"uid": I, "action": S, "name": S, "kind": [S, ["basic", "ability"]], "anim": S, "target": I,
		"target_side": [I, [0, 1]], "area": [S, ["single", "all_enemies", "all_allies"]], "duration": F, "impact": F,
		"gauges": A},
	"ability": {"uid": I, "action": S, "name": S},
	"damage": {"src": I, "dst": I, "amount": I, "kind": [S, ["physical", "magic", "sudden_death"]], "crit": B,
		"mods": A, "primary": D, "hp": I, "action": S},
	"heal": {"src": I, "dst": I, "amount": I, "hp": I, "action": S},
	"charge": {"uid": I, "charge": I, "delta": I, "reason": [S, ["act", "hit", "effect", "spent"]], "ready": B, "queue": I},
	"ko": {"uid": I, "by": I},
	"sudden_death": {"tick": I, "hp_pct": F, "damage_mult": F, "heal_mult": F, "duration": F},
	"fight_end": {"winner": [I, [-1, 0, 1]], "reason": [S, ["wipe", "fading", "timeout"]], "survivors": A},
}
const SIDE := {"side": I, "name": S, "formation": D, "compositions": A, "units": A}
const FORMATION := {"id": S, "name": S, "buffs": A, "debuffs": A}
const MODIFIER := {"scope": [S, ["all", "front", "back", "class"]], "stat": S, "value": F}
const COMPOSITION := {"id": S, "name": S, "mods": A}
const UNIT := {"uid": I, "side": I, "name": S, "label": S, "class": S, "class_name": S, "base_class": S,
	"tier": [S, ["base", "advanced", "legendary", "monster"]], "level": I, "col": [I, [0, 1]], "row": [I, [0, 1, 2, 3]],
	"hp": I, "max_hp": I, "atk": I, "def": I, "mag": I, "spd": I, "crit": F, "charge": I, "charge_max": I,
	"gauge": F, "basic": D, "ability": D}
const ACTION_REF := {"id": S, "name": S}
const MOD_IDS := ["formation", "back_row_attacker", "back_row_target", "execute", "sudden_death"]
const MOD_FORMATION := {"id": S, "mult": F, "source": S, "name": S, "side": [I, [0, 1]]}
const MOD_PLAIN := {"id": S, "mult": F}
const PRIMARY_IDS := ["crit", "execute", "back_row_attacker", "back_row_target", "back_row_both", "formation", "sudden_death"]

var _bad := 0


func _conform(obj: Dictionary, schema: Dictionary, where: String, implied: Array = []) -> void:
	var keys := {}
	for k: String in schema:
		keys[k] = true
	for k: String in implied:
		keys[k] = true
	for k: Variant in obj:
		if not keys.has(k):
			_fail("%s: undocumented field '%s'" % [where, k])
	for k: String in schema:
		if not obj.has(k):
			_fail("%s: missing field '%s'" % [where, k])
			continue
		var spec: Variant = schema[k]
		var ty: int = spec if spec is int else int(spec[0])
		if typeof(obj[k]) != ty:
			_fail("%s: field '%s' has type %s, expected %s" % [where, k, type_string(typeof(obj[k])), type_string(ty)])
		elif spec is Array and not (spec[1] as Array).has(obj[k]):
			_fail("%s: field '%s' value %s not in %s" % [where, k, str(obj[k]), str(spec[1])])


func _fail(msg: String) -> void:
	_bad += 1
	if _bad <= 10:
		check(false, msg)


func _check_formation(f: Variant, where: String) -> void:
	if not (f is Dictionary):
		_fail(where + ": formation is not a Dictionary")
		return
	_conform(f, FORMATION, where + ".formation")
	for m: Variant in (f["buffs"] as Array) + (f["debuffs"] as Array):
		_conform(m, MODIFIER, where + ".formation modifier")


func _check_event(ev: Dictionary, where: String) -> void:
	var type := String(ev.get("type", ""))
	if not EVENTS.has(type):
		_fail("%s: unknown event type '%s'" % [where, type])
		return
	if typeof(ev.get("t")) != F:
		_fail("%s: 't' is not a float" % where)
	_conform(ev, EVENTS[type], "%s %s" % [where, type], ["t", "type"])
	match type:
		"fight_start":
			if (ev["sides"] as Array).size() != 2:
				_fail(where + ": fight_start needs 2 sides")
			for side: Dictionary in ev["sides"]:
				_conform(side, SIDE, where + " side")
				_check_formation(side["formation"], where)
				for c: Dictionary in side["compositions"]:
					_conform(c, COMPOSITION, where + " composition")
				for u: Dictionary in side["units"]:
					_conform(u, UNIT, where + " unit")
					_conform(u["basic"], ACTION_REF, where + " unit.basic")
					_conform(u["ability"], ACTION_REF, where + " unit.ability")
		"formation":
			_check_formation(ev["formation"], where)
		"action_start":
			for g: Variant in ev["gauges"]:
				if typeof(g) != F or float(g) < 0.0 or float(g) > 1.0:
					_fail(where + ": gauges must be floats in 0..1")
					break
		"damage":
			for m: Variant in ev["mods"]:
				if not (m is Dictionary) or not MOD_IDS.has((m as Dictionary).get("id", "")):
					_fail("%s: damage mod %s is not a documented {id, mult} entry" % [where, str(m)])
					continue
				_conform(m, MOD_FORMATION if m["id"] == "formation" else MOD_PLAIN, where + " mod")
			var p: Dictionary = ev["primary"]
			if not p.is_empty():
				if not PRIMARY_IDS.has(p.get("id", "")):
					_fail("%s: primary %s has an undocumented id" % [where, str(p)])
				else:
					_conform(p, MOD_FORMATION if p["id"] == "formation" else MOD_PLAIN, where + " primary")
			if ev["crit"] and String(p.get("id", "")) != "crit":
				_fail(where + ": a crit must be the primary annotation")
		"fight_end":
			for s: Variant in ev["survivors"]:
				if typeof(s) != I:
					_fail(where + ": survivors must be ints")


func test_every_event_matches_readme_schema() -> void:
	var rng := Rng.new(424242)
	var n := 1000
	var events := 0
	var sd_fights := 0
	var seen := {}
	for i in n:
		var a := PartyGen.random_party(rng)
		var b := PartyGen.monster_group(rng, 1 + i % 10) if i % 3 == 1 else PartyGen.random_party(rng)
		var opts := {}
		if i % 5 == 0:
			opts = {"tuning": {"damage_scale": 0.4}}   # forces sudden death
		var r := CombatSim.simulate(i * 31 + 7, a, b, opts)
		if int(r["sudden_death_ticks"]) > 0:
			sd_fights += 1
		for ev: Dictionary in r["events"]:
			events += 1
			seen[ev["type"]] = true
			_check_event(ev, "fight %d" % i)
		Narrator.narrate(r["events"])   # must never raise a script error
	eq(_bad, 0, "schema violations across %d events" % events)
	check(sd_fights >= int(n * 0.2), "sudden death covered (%d fights)" % sd_fights)
	for type: String in EVENTS:
		check(seen.has(type) or type == "fight_end", "event type %s was exercised" % type)
