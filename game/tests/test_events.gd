extends "res://tests/test_case.gd"

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const GameData = preload("res://core/game_data.gd")
const Rng = preload("res://core/rng.gd")

const TYPES := ["fight_start", "formation", "formation_proc", "formation_move", "action_start", "ability", "damage", "heal", "charge", "ko", "sudden_death", "fight_end",
	"spawn", "status", "status_end", "miss", "skip", "absorb", "move", "gauge", "revive"]
const TOS := ["primary", "primary_adjacent", "primary_column", "primary_column_rest", "other_enemies", "melee_enemy", "all_enemies", "front_enemies", "front_random",
	"random_enemy", "self", "all_allies", "lowest_hp_ally", "adjacent_allies", "column_allies", "other_allies", "primary_neighbours",
	"most_charged_enemy", "highest_hp_enemy", "random_ally", "column_sweep", "primary_behind"]
const SELECTORS := ["melee", "back_first", "lowest_hp_enemy", "random_enemy", "lowest_hp_ally", "self", "all_enemies", "all_allies",
	"most_charged_enemy", "highest_hp_enemy", "random_ally", "column_bottom", "strongest_front_enemy",
	"strongest_sealable_enemy"]


## Actions that are an ability's second half (a status's "then"): shown as an ability, no charge spent.
static func followups() -> Dictionary:
	var out := {}
	for aid: String in GameData.Actions.ACTIONS:
		for e: Dictionary in GameData.Actions.ACTIONS[aid]["effects"]:
			if String(e.get("then", "")) != "":
				out[String(e["then"])] = true
	return out


func test_log_invariants() -> void:
	var rng := Rng.new(2024)
	for i in 60:
		var a := PartyGen.random_party(rng)
		var b := PartyGen.monster_group(rng, 1 + i % 8) if i % 3 == 0 else PartyGen.random_party(rng)
		var r := CombatSim.simulate(i, a, b)
		var evs: Array = r["events"]
		if evs[0]["type"] != "fight_start" or evs[-1]["type"] != "fight_end":
			check(false, "fight %d: log must start with fight_start and end with fight_end" % i)
			return
		var last_t := 0.0
		var fu := followups()
		var hp := {}
		var dead := {}
		var ch := {}
		for ev: Dictionary in evs:
			if not TYPES.has(ev["type"]) or typeof(ev["t"]) != TYPE_FLOAT:
				check(false, "fight %d: bad event %s" % [i, ev])
				return
			if float(ev["t"]) < last_t:
				check(false, "fight %d: time went backwards at %s" % [i, ev])
				return
			last_t = float(ev["t"])
			match String(ev["type"]):
				"fight_start":
					for side: Dictionary in ev["sides"]:
						for u: Dictionary in side["units"]:
							hp[int(u["uid"])] = int(u["hp"])
							ch[int(u["uid"])] = int(u["charge"])
				"charge":
					var cu := int(ev["uid"])
					if int(ch[cu]) + int(ev["delta"]) != int(ev["charge"]) or bool(ev["ready"]) != (int(ev["charge"]) >= 100):
						check(false, "fight %d: charge event inconsistent with previous charge %s" % [i, ev])
						return
					ch[cu] = int(ev["charge"])
				"spawn":
					hp[int(ev["uid"])] = int(ev["unit"]["hp"])
					ch[int(ev["uid"])] = int(ev["unit"]["charge"])
				"revive":
					if not dead.has(int(ev["uid"])):
						check(false, "fight %d: revived a unit that was standing" % i)
						return
					dead.erase(int(ev["uid"]))
					hp[int(ev["uid"])] = int(ev["hp"])
					ch[int(ev["uid"])] = 0
				"action_start":
					if ev["kind"] == "ability" and int(ch[int(ev["uid"])]) < 100 and not fu.has(String(ev["action"])):
						check(false, "fight %d: ability without full charge" % i)
						return
					if dead.has(int(ev["uid"])):
						check(false, "fight %d: KO'd unit acted" % i)
						return
				"damage", "heal":
					var d := int(ev["dst"])
					if dead.has(d) or int(ev["hp"]) < 0:
						check(false, "fight %d: damage/heal on dead unit or negative HP" % i)
						return
					hp[d] = int(ev["hp"])
				"ko":
					if dead.has(int(ev["uid"])) or int(hp[int(ev["uid"])]) != 0:
						check(false, "fight %d: KO without 0 HP or twice" % i)
						return
					dead[int(ev["uid"])] = true
		var end: Dictionary = evs[-1]
		eq(end["winner"], r["winner"], "fight_end winner matches result")
		if int(r["winner"]) >= 0 and r["reason"] != "fading":
			var any_survivor := false
			for uid: int in end["survivors"]:
				if _side_of(evs[0], uid) == int(r["winner"]):
					any_survivor = true
			check(any_survivor, "winner has a survivor")
	check(true, "invariants hold")


func _side_of(fs: Dictionary, uid: int) -> int:
	for side: Dictionary in fs["sides"]:
		for u: Dictionary in side["units"]:
			if int(u["uid"]) == uid:
				return int(u["side"])
	return -1


func test_actions_serialised() -> void:
	# Active-wait timeline: an action never starts before the previous one finished.
	var rng := Rng.new(4)
	var r := CombatSim.simulate(1, PartyGen.random_party(rng), PartyGen.random_party(rng))
	var busy_until := 0.0
	for ev: Dictionary in r["events"]:
		if ev["type"] == "action_start" or ev["type"] == "sudden_death":
			check(float(ev["t"]) >= busy_until - 0.0001, "action at %.3f starts after previous ended %.3f" % [ev["t"], busy_until])
			busy_until = float(ev["t"]) + float(ev["duration"])
			if ev["type"] == "action_start":
				check(float(ev["impact"]) >= float(ev["t"]) and float(ev["impact"]) <= busy_until, "impact inside action")


func test_data_integrity() -> void:
	for cid: String in GameData.Classes.CLASSES:
		var c: Dictionary = GameData.Classes.CLASSES[cid]
		for key in ["basic", "ability"]:
			check(not GameData.get_action(String(c[key])).is_empty(), "%s.%s exists" % [cid, key])
		check(GameData.has_class(String(c["base"])), "%s base exists" % cid)
		for s: String in GameData.STATS:
			check(c["stats"].has(s) and c["growth"].has(s), "%s has stat %s" % [cid, s])
	for aid: String in GameData.Actions.ACTIONS:
		var a: Dictionary = GameData.Actions.ACTIONS[aid]
		check(SELECTORS.has(String(a["target"])), "%s target selector valid" % aid)
		check(float(a["impact"]) < float(a["duration"]), "%s impact before end" % aid)
		check(float(a["duration"]) >= 0.45, "%s lasts long enough to read on screen" % aid)
		for e: Dictionary in a["effects"]:
			check(TOS.has(String(e.get("to", "primary"))), "%s effect target valid" % aid)
	for iid: String in GameData.Items.ITEMS:
		var it: Dictionary = GameData.Items.ITEMS[iid]
		check(GameData.Items.SLOTS.has(String(it["slot"])), "%s slot valid" % iid)
		check(not it.has("alignment") or String(it["slot"]) == "relic", "%s: only relics carry alignment" % iid)


func test_fight_lengths_in_band() -> void:
	var rng := Rng.new(31337)
	var in_band := 0
	var n := 400
	for i in n:
		var foe := PartyGen.monster_group(rng, 1 + i % 10) if i % 2 == 1 else PartyGen.random_party(rng)
		var r := CombatSim.simulate(i, PartyGen.random_party(rng), foe, {"log": false})
		var d := float(r["duration"])
		if d >= 15.0 and d <= 40.0:
			in_band += 1
	check(in_band >= int(n * 0.75), "at least 75%% of PvP + monster fights last 15-40 s (got %d/%d)" % [in_band, n])
