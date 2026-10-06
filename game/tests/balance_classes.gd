extends SceneTree
## Class balance check (the method of docs/design/balance-report-2026-10-05.md, section 4).
##   godot --path game --headless -s res://tests/balance_classes.gd -- [--runs=800] [--seed=100000] [--fights=1500] [--out=PATH]
## 1. Plays greedy-bot runs against one growing Echo pool (user://sandbox/, never the player's files)
##    and records every fight as it was met: the party, the opponent, the kind.
## 2. Swap test: in a sample of recorded fights, each hero slot is swapped to every class of its
##    tier (base: the 4 base classes; advanced: every advanced class) at the same level and items,
##    the party is re-placed with the default auto-placement (preferred column, rows 1, 2, 0, 3),
##    and the fight is re-fought with 2 seeds. Win rate per class, per fight kind; pairwise
##    "beats / loses" shares within a base (near-strict pairs).
## 3. Run-level: victory rate, the classes heroes end in, and how many are PROVISIONAL stand-ins.
## Prints a report and writes the raw numbers as JSON (default user://sandbox/balance_classes.json).

const Run = preload("res://core/run/run.gd")
const RunBot = preload("res://core/run/run_bot.gd")
const EchoPool = preload("res://core/run/echo_pool.gd")
const CombatSim = preload("res://core/combat_sim.gd")
const GameData = preload("res://core/game_data.gd")
const Alignment = preload("res://core/alignment.gd")
const Rng = preload("res://core/rng.gd")
const RunTuning = preload("res://core/run/run_tuning.gd")

const SEEDS := 2


func _init() -> void:
	var runs_n := 800
	var seed0 := 100000
	var fights_n := 1500
	var out := "user://sandbox/balance_classes.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs_n = int(a.trim_prefix("--runs="))
		elif a.begins_with("--seed="):
			seed0 = int(a.trim_prefix("--seed="))
		elif a.begins_with("--fights="):
			fights_n = int(a.trim_prefix("--fights="))
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var t0 := Time.get_ticks_msec()
	var rec := _play_runs(runs_n, seed0)
	print("runs: %d in %.0f s, fights recorded: %d" % [runs_n, (Time.get_ticks_msec() - t0) / 1000.0, (rec["fights"] as Array).size()])
	var t1 := Time.get_ticks_msec()
	var sw := _swap_test(rec["fights"], fights_n)
	print("swap test: %d sims in %.0f s" % [int(sw["sims"]), (Time.get_ticks_msec() - t1) / 1000.0])
	_report(rec, sw)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://sandbox"))
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"runs": rec["summary"], "swap": sw}, "  ", true))
		print("raw numbers: ", ProjectSettings.globalize_path(out))
	quit(0)


# ------------------------------------------------------------------ runs

func _play_runs(n: int, seed0: int) -> Dictionary:
	var path := "user://sandbox/balance_pool.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var pool: RefCounted = EchoPool.open(path)
	var fights: Array = []
	var victories := 0
	var crystal_reached := 0
	var crystal_won := 0
	var end_class := {}
	var adv_heroes := 0
	var stand_ins := 0
	var best_floor := 0
	var kind_wl := {}
	for k in n:
		var run: RefCounted = Run.new()
		run.start_run(seed0 + k, {"pool": pool, "log": false, "best_floor": best_floor})
		var rng := Rng.new(seed0 + k + 77)
		var pending := {}
		for _i in 600:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			if v["step"] == "fight":
				pending = {"kind": String(run.get("_fight_kind")), "party": run.combat_party(),
					"opp": (run.get("_opponent") as Dictionary).duplicate(true), "run": k}
			var before := int(run.get("_fight_attempt"))
			RunBot.step(run, rng, "greedy", 0.2)
			if int(run.get("_fight_attempt")) != before and not pending.is_empty():
				var last: Dictionary = run.get("_last")
				pending["won"] = bool(last.get("fight", {}).get("won", false))
				fights.append(pending)
				var kw: Array = kind_wl.get(pending["kind"], [0, 0])
				kind_wl[pending["kind"]] = [int(kw[0]) + (1 if pending["won"] else 0), int(kw[1]) + 1]
				pending = {}
		var s: Dictionary = run.summary()
		best_floor = maxi(best_floor, int(s["floor"]))
		if s["outcome"] == "victory":
			victories += 1
		for h: Dictionary in s["heroes"]:
			var cid := String(h["class"])
			end_class[cid] = int(end_class.get(cid, 0)) + 1
			if String(GameData.get_class_def(cid).get("tier", "")) == "advanced":
				adv_heroes += 1
				if bool(h.get("placeholder_class", false)):
					stand_ins += 1
	for fr: Dictionary in fights:
		if fr["kind"] == "crystal":
			crystal_reached += 1
			crystal_won += 1 if fr["won"] else 0
	return {"fights": fights, "summary": {"runs": n, "victories": victories, "crystal": [crystal_won, crystal_reached],
		"end_class": end_class, "advanced_heroes": adv_heroes, "stand_ins": stand_ins, "kinds": kind_wl}}


# ------------------------------------------------------------------ swap test

static func _place(heroes: Array) -> void:
	var used := {}
	for h: Dictionary in heroes:
		var pref := int(GameData.get_class_def(String(h["class"]))["preferred_col"])
		var done := false
		for col in [pref, 1 - pref]:
			for row in [1, 2, 0, 3]:
				if not done and not used.has(col * 4 + row):
					h["slot"] = [col, row]
					used[col * 4 + row] = true
					done = true


func _fight(fr: Dictionary, party: Dictionary, sd: int) -> bool:
	var r: Dictionary
	if fr["kind"] == "crystal":
		r = CombatSim.simulate_crystal(sd, party, {"memories": fr["opp"]["memories"], "integrity": int(RunTuning.RUN["crystal_integrity"])}, {"log": false})
	else:
		r = CombatSim.simulate(sd, party, fr["opp"], {"log": false})
	return int(r.get("winner", -1)) == 0


func _swap_test(fights: Array, limit: int) -> Dictionary:
	var by_tier := {"base": [], "advanced": []}
	for cid: String in GameData.Classes.CLASSES:
		var t := String(GameData.Classes.CLASSES[cid]["tier"])
		if by_tier.has(t):
			(by_tier[t] as Array).append(cid)
	# sample fights evenly; prefer ones with an advanced hero (the point of this check)
	var with_adv: Array = []
	for fr: Dictionary in fights:
		for h: Dictionary in fr["party"]["heroes"]:
			if String(GameData.get_class_def(String(h["class"]))["tier"]) == "advanced":
				with_adv.append(fr)
				break
	var step := maxf(1.0, float(with_adv.size()) / float(limit))
	var sample: Array = []
	var x := 0.0
	while int(x) < with_adv.size() and sample.size() < limit:
		sample.append(with_adv[int(x)])
		x += step
	var wins := {}      # class -> kind -> [wins, n]
	var pair := {}      # "a|b" -> [a better, b better, n]   (same slot, same base)
	var sims := 0
	var fi := 0
	for fr: Dictionary in sample:
		fi += 1
		var heroes: Array = fr["party"]["heroes"]
		for si in heroes.size():
			var tier := String(GameData.get_class_def(String(heroes[si]["class"]))["tier"])
			if tier != "advanced" and tier != "base":
				continue
			var score := {}
			for cid: String in by_tier[tier]:
				var p: Dictionary = (fr["party"] as Dictionary).duplicate(true)
				var h: Dictionary = p["heroes"][si]
				h["class"] = cid
				h["level"] = mini(int(h["level"]), GameData.max_level(cid))
				_place(p["heroes"])
				var w := 0
				for s in SEEDS:
					if _fight(fr, p, fi * 7919 + si * 131 + s):
						w += 1
					sims += 1
				score[cid] = w
				for kind: String in [String(fr["kind"]), "all"]:
					var d: Dictionary = wins.get(cid, {})
					var a: Array = d.get(kind, [0, 0])
					d[kind] = [int(a[0]) + w, int(a[1]) + SEEDS]
					wins[cid] = d
			if tier == "advanced":
				var ids: Array = score.keys()
				for i in ids.size():
					for j in range(i + 1, ids.size()):
						var ca := String(ids[i])
						var cb := String(ids[j])
						if GameData.get_class_def(ca)["base"] != GameData.get_class_def(cb)["base"]:
							continue
						var key := "%s|%s" % [ca, cb]
						var pr: Array = pair.get(key, [0, 0, 0])
						pr[0] = int(pr[0]) + (1 if int(score[ca]) > int(score[cb]) else 0)
						pr[1] = int(pr[1]) + (1 if int(score[cb]) > int(score[ca]) else 0)
						pr[2] = int(pr[2]) + 1
						pair[key] = pr
	return {"wins": wins, "pairs": pair, "sims": sims, "fights": sample.size()}


# ------------------------------------------------------------------ report

static func _pct(a: Variant) -> String:
	var arr: Array = a
	return "-" if int(arr[1]) == 0 else "%.1f%%" % (100.0 * float(arr[0]) / float(arr[1]))


func _report(rec: Dictionary, sw: Dictionary) -> void:
	var s: Dictionary = rec["summary"]
	print("\n== Runs (greedy): victory %.1f%%, Crystal won %s; advanced heroes %d, PROVISIONAL stand-ins %.1f%%" % [
		100.0 * int(s["victories"]) / maxf(1, int(s["runs"])), _pct(s["crystal"]), int(s["advanced_heroes"]),
		100.0 * int(s["stand_ins"]) / maxf(1, int(s["advanced_heroes"]))])
	for kind: String in s["kinds"]:
		print("   %s win %s (n %d)" % [kind, _pct(s["kinds"][kind]), int(s["kinds"][kind][1])])
	print("\n== Classes heroes end runs in")
	var ec: Dictionary = s["end_class"]
	var keys: Array = ec.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(ec[a]) > int(ec[b]))
	for cid: String in keys:
		print("   %-14s %d" % [cid, int(ec[cid])])
	var wins: Dictionary = sw["wins"]
	print("\n== Swap test (%d fights, %d seeds): win rate when the slot plays this class" % [int(sw["fights"]), SEEDS])
	print("   %-14s %-8s %7s %7s %7s %7s %7s" % ["class", "base", "all", "pvp", "guardian", "monster", "crystal"])
	var cls: Array = wins.keys()
	cls.sort_custom(func(a: String, b: String) -> bool:
		var aa: Array = wins[a]["all"]
		var bb: Array = wins[b]["all"]
		return float(aa[0]) / float(aa[1]) > float(bb[0]) / float(bb[1]))
	for cid: String in cls:
		var d: Dictionary = wins[cid]
		print("   %-14s %-8s %7s %7s %7s %7s %7s" % [cid, String(GameData.get_class_def(cid)["base"]), _pct(d["all"]),
			_pct(d.get("pvp", [0, 0])), _pct(d.get("guardian", [0, 0])), _pct(d.get("monster", [0, 0])), _pct(d.get("crystal", [0, 0]))])
	print("\n== Near-strict pairs within a base (beats / loses, share of slots; the rest tie)")
	var pairs: Dictionary = sw["pairs"]
	for key: String in pairs:
		var pr: Array = pairs[key]
		var a := float(pr[0]) / float(pr[2])
		var b := float(pr[1]) / float(pr[2])
		if absf(a - b) >= 0.10:
			print("   %-30s %4.0f%% / %4.0f%%" % [key, 100.0 * a, 100.0 * b])
