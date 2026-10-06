extends SceneTree
## Simulated playthroughs of whole runs with a bot.
##   godot --path game --headless -s res://tests/run_sim.gd -- --seed=N [--n=200] [--policy=greedy|random]
## Prints the readable log of the run for seed N, then aggregate stats over N runs (seeds N..N+n-1)
## played in order against one Echo pool (fresh: user://sandbox/run_sim_pool.json, seeded with generated
## Echoes; every finished run adds its snapshot, as in the real game).

const Run = preload("res://core/run/run.gd")
const RunBot = preload("res://core/run/run_bot.gd")
const EchoPool = preload("res://core/run/echo_pool.gd")
const Rng = preload("res://core/rng.gd")
const T = preload("res://core/run/run_tuning.gd")


func _init() -> void:
	var seed_value := 1
	var n := 200
	var policy := "greedy"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.trim_prefix("--seed="))
		elif a.begins_with("--n="):
			n = maxi(1, int(a.trim_prefix("--n=")))
		elif a.begins_with("--policy="):
			policy = a.trim_prefix("--policy=")
	var path := "user://sandbox/run_sim_pool.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var pool: RefCounted = EchoPool.open(path)
	var t0 := Time.get_ticks_msec()
	var runs: Array = []
	var best_floor := 0   # meta stand-in: depth milestones are one-time across runs
	for k in n:
		var run: RefCounted = Run.new()
		run.start_run(seed_value + k, {"pool": pool, "log": false, "best_floor": best_floor})
		RunBot.play(run, Rng.new(seed_value + k + 77), policy)
		if k == 0:
			for line: String in run.log_lines():
				print(line)
			print("\nSummary: ", JSON.stringify(_brief(run.summary())), "\n")
		runs.append(run.summary())
		best_floor = maxi(best_floor, int(run.summary()["floor"]))
	_report(runs, Time.get_ticks_msec() - t0, policy)
	_routing(seed_value)
	quit(0)


## Share of runs where taking choice 0 vs choice 1 at a depth changes the next encounter met.
func _routing(seed_value: int) -> void:
	var parts: Array = []
	for depth in [2, 5, 9, 11, 23]:
		var diff := 0
		var tot := 0
		for k in 150:
			var a := _next_after(seed_value + k, depth, 0)
			var b := _next_after(seed_value + k, depth, 1)
			if a == "" or b == "":
				continue
			tot += 1
			diff += 1 if a != b else 0
		parts.append("depth %d: %d%% (%d runs)" % [depth, _pct(diff, tot), tot])
	print("Routing, choice 0 vs 1 changes the next encounter (5 = through a guardian, 9 = through PvP): ", ", ".join(parts))


static func _next_after(sd: int, depth: int, pick: int) -> String:
	var pool: RefCounted = EchoPool.new()
	pool.seed_generated(1)
	var run: RefCounted = Run.new()
	run.start_run(sd, {"pool": pool, "save_echo": false, "log": false})
	var rng := Rng.new(sd)
	var chosen := false
	for _i in 400:
		if run.is_over():
			return ""
		var v: Dictionary = run.current_node()
		if v["step"] == "choice" and int(v["depth"]) == depth and not chosen:
			if pick >= v["choices"].size():
				return ""
			run.choose(pick)
			chosen = true
			continue
		if v["step"] == "choice" and int(v["depth"]) > depth and chosen:
			return String(v["encounter_id"])
		RunBot.step(run, rng, "greedy", 0.0)
	return ""


static func _brief(s: Dictionary) -> Dictionary:
	var b := s.duplicate(true)
	b.erase("echo")
	return b


func _report(runs: Array, ms: int, policy: String) -> void:
	var n := runs.size()
	var acc := {"nodes": 0.0, "depth": 0.0, "glimmers": 0.0, "shards": 0.0, "pvp_w": 0.0, "pvp_l": 0.0,
		"mon_w": 0.0, "mon_l": 0.0, "lore": 0.0, "memories": 0.0, "wasted": 0.0, "party": 0.0}
	var phases := {"gathering": 0, "advancement": 0, "legend": 0}
	var ends := {}
	var heroes := 0
	var hero_mem := 0.0
	var mem_hist := {}
	var advanced := 0
	var held := 0
	var placeholder := 0
	var legendary_runs := 0
	var size_hist := {}
	var repeats := 0
	var distinct := 0.0
	var offers := 0
	var seen_all := {}
	var lost := {"gathering": 0, "advancement": 0, "legend": 0}
	var deaths := {}
	var death_nodes := {}
	var enc_nodes := 0
	var two_nodes := 0
	var rests := 0
	var gw := 0
	var gl := 0
	var by_floor := {}
	var g_lost := 0
	var name_repeats := 0
	var frag_hist := {}
	var crystal_n := 0
	for s: Dictionary in runs:
		acc["nodes"] += s["nodes_visited"]
		acc["depth"] += s["depth"]
		acc["glimmers"] += s["glimmers"]
		acc["shards"] += s["shards"]
		acc["pvp_w"] += s["pvp_wins"]
		acc["pvp_l"] += s["pvp_losses"]
		acc["mon_w"] += s["monster_wins"]
		acc["mon_l"] += s["monster_losses"]
		acc["lore"] += s["lore_items"].size()
		acc["memories"] += s["memories"]
		acc["wasted"] += s["wasted_memories"]
		acc["party"] += s["heroes"].size()
		size_hist[s["heroes"].size()] = int(size_hist.get(s["heroes"].size(), 0)) + 1
		phases[s["phase_reached"]] += 1
		var end_key: String = s["outcome"] if s["outcome"] == "victory" else "fallen in %s" % s["phase_reached"]
		ends[end_key] = int(ends.get(end_key, 0)) + 1
		var any_leg := false
		for h: Dictionary in s["heroes"]:
			heroes += 1
			hero_mem += h["memories"]
			var m := mini(int(h["memories"]), 9)
			mem_hist[m] = int(mem_hist.get(m, 0)) + 1
			if h["advanced"]:
				advanced += 1
			if h["held_ever"]:
				held += 1
			if h["placeholder_class"]:
				placeholder += 1
			if h["legendary"]:
				any_leg = true
		if any_leg:
			legendary_runs += 1
		var seen := {}
		for id: String in s["encounters_seen"]:
			if seen.has(id):
				repeats += 1
			seen[id] = true
			seen_all[id] = int(seen_all.get(id, 0)) + 1
		distinct += seen.size()
		offers += 1 if s["legend_offered"] else 0
		for ph: String in lost:
			lost[ph] += int(s["health_lost_by_phase"][ph])
		if not s["death"].is_empty():
			var fl := "floor %d" % int(s["death"]["floor"])
			deaths[fl] = int(deaths.get(fl, 0)) + 1
			death_nodes[s["death"]["node"]] = int(death_nodes.get(s["death"]["node"], 0)) + 1
		enc_nodes += int(s["encounter_nodes"])
		two_nodes += int(s["two_choice_nodes"])
		rests += int(s["rests"])
		g_lost += int(s["guardian_health_lost"])
		if s["crystal_reached"]:
			crystal_n += 1
			if s["outcome"] != "victory":
				frag_hist[int(s["fragments"])] = int(frag_hist.get(int(s["fragments"]), 0)) + 1
		var rv := {}
		for nm: String in s["rivals"]:
			if rv.has(nm):
				name_repeats += 1
			rv[nm] = true
		for f: Variant in s["fights_by_floor"]:
			for kind: String in s["fights_by_floor"][f]:
				var key := "%s|%s" % [str(f), kind]
				var cur: Array = by_floor.get(key, [0, 0])
				var add: Array = s["fights_by_floor"][f][kind]
				by_floor[key] = [int(cur[0]) + int(add[0]), int(cur[1]) + int(add[1])]
		gw += int(s["guardian_wins"])
		gl += int(s["guardian_losses"])
	var pvp_total: float = acc["pvp_w"] + acc["pvp_l"]
	var mon_total: float = acc["mon_w"] + acc["mon_l"]
	print("=== Aggregate over %d runs (policy %s, %d ms) ===" % [n, policy, ms])
	print("Run length: %.1f nodes visited, mean depth %.1f of %d" % [acc["nodes"] / n, acc["depth"] / n,
		"".join(T.RUN["floors"]).length()])
	print("Phases reached: gathering-only %d%%, advancement %d%%, legend %d%%" % [
		_pct(phases["gathering"], n), _pct(phases["advancement"], n), _pct(phases["legend"], n)])
	print("How runs end: ", _fmt_counts(ends, n))
	print("Party size at end: ", _fmt_counts(size_hist, n))
	print("Memories per run: %.1f (%.1f wasted at level cap); per hero: %.2f" % [acc["memories"] / n,
		acc["wasted"] / n, hero_mem / maxi(1, heroes)])
	print("Memories per hero histogram (9 = 9+): ", _fmt_counts(mem_hist, heroes))
	print("Heroes that Advance: %d%% (held back at least once: %d%%; placeholder class for unauthored region: %d%%)" % [
		_pct(advanced, heroes), _pct(held, heroes), _pct(placeholder, heroes)])
	print("Runs with a Legendary: %d%%; legend's-memory offers per run: %.2f" % [_pct(legendary_runs, n), float(offers) / n])
	var counts: Array = seen_all.values()
	counts.sort()
	print("Encounters: %d repeats in %d runs; %.1f distinct per run; %d different encounters met overall (least / most met: %d / %d runs)" % [
		repeats, n, distinct / n, seen_all.size(), counts[0], counts[-1]])
	print("PvP win rate: %d%% (%.1f fights/run); monster win rate: %d%% (%.1f fights/run)" % [
		_pct(int(acc["pvp_w"]), int(pvp_total)), pvp_total / n, _pct(int(acc["mon_w"]), int(mon_total)), mon_total / n])
	print("Health lost per run by phase: gathering %.2f, advancement %.2f, legend %.2f; rests taken per run %.2f" % [
		float(lost["gathering"]) / n, float(lost["advancement"]) / n, float(lost["legend"]) / n, float(rests) / n])
	print("Deaths by floor (share of all runs): ", _fmt_counts(deaths, n), "; killing blow: ", _fmt_counts(death_nodes, n))
	print("Floor guardian win rate: %d%% (%.1f fights/run)" % [_pct(gw, gw + gl), float(gw + gl) / n])
	var rows: Array = []
	for f in range(1, 6):
		var parts: Array = []
		for kind: String in ["pvp", "guardian", "crystal"]:
			var r: Array = by_floor.get("%d|%s" % [f, kind], [0, 0])
			if int(r[1]) > 0:
				parts.append("%s %d%% (n=%d)" % [kind, _pct(int(r[0]), int(r[1])), int(r[1])])
		rows.append("F%d: %s" % [f, ", ".join(parts)])
	print("Win rate by floor: ", " | ".join(rows))
	print("Health lost per guardian loss: %.2f; rival Echo name repeats per run: %.2f" % [float(g_lost) / maxi(1, gl), float(name_repeats) / n])
	var frag_total := 0
	for k: Variant in frag_hist:
		frag_total += int(frag_hist[k])
	print("Crystal reached in %d%% of runs; fragments chipped on a Crystal defeat: %s" % [_pct(crystal_n, n), _fmt_counts(frag_hist, frag_total)])
	print("Encounter nodes with a two-choice hero: %d%%" % _pct(two_nodes, enc_nodes))
	print("Glimmers per run: %.1f; Shards per run: %.2f; lore items per run: %.2f" % [acc["glimmers"] / n,
		acc["shards"] / n, acc["lore"] / n])


static func _pct(a: int, b: int) -> int:
	return int(round(100.0 * a / maxi(1, b)))


static func _fmt_counts(d: Dictionary, total: int) -> String:
	var keys := d.keys()
	keys.sort()
	var parts: Array = []
	for k: Variant in keys:
		parts.append("%s: %d%%" % [str(k), _pct(int(d[k]), total)])
	return ", ".join(parts)
