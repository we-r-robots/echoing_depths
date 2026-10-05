extends "res://tests/test_case.gd"
## Run layer: determinism, spec rules, Echo pool persistence.

const Run = preload("res://core/run/run.gd")
const RunBot = preload("res://core/run/run_bot.gd")
const EchoPool = preload("res://core/run/echo_pool.gd")
const LegendGate = preload("res://core/run/legend_gate.gd")
const Echo = preload("res://core/echo.gd")
const Rng = preload("res://core/rng.gd")
const T = preload("res://core/run/run_tuning.gd")
const GameData = preload("res://core/game_data.gd")
const Catalog = preload("res://core/run/encounter_catalog.gd")

const SEEDED := 30   # 5 floors x echo_seed_per_floor 6
const FORBIDDEN_KEYS := ["route", "map", "next", "edges", "layers", "nodes", "_map"]


static func _fresh_pool() -> RefCounted:
	var p: RefCounted = EchoPool.new()
	p.path = "user://test_unused_pool.json"
	p.seed_generated(1)
	return p


static func _new_run(seed_value: int, pool: RefCounted = null) -> RefCounted:
	var run: RefCounted = Run.new()
	run.start_run(seed_value, {"pool": pool if pool != null else _fresh_pool(), "save_echo": false, "log": false})
	return run


static func _mem_list(run: RefCounted) -> Array:
	var out: Array = []
	for h: Dictionary in run.party_view():
		out.append(int(h["memories"]))
	return out


static func _find_keys(v: Variant, keys: Array, found: Array) -> void:
	if v is Dictionary:
		for k: Variant in v:
			if keys.has(str(k)):
				found.append(str(k))
			_find_keys(v[k], keys, found)
	elif v is Array:
		for x: Variant in v:
			_find_keys(x, keys, found)


func test_determinism() -> void:
	var a := _new_run(42)
	var b := _new_run(42)
	RunBot.play(a, Rng.new(9))
	RunBot.play(b, Rng.new(9))
	check(a.is_over() and b.is_over(), "bot finishes the run")
	eq(JSON.stringify(a.summary(), "", true), JSON.stringify(b.summary(), "", true), "same seed -> same summary")
	eq(a.log_lines(), b.log_lines(), "same seed -> same log")
	var c := _new_run(43)
	RunBot.play(c, Rng.new(9))
	check(c.log_lines() != a.log_lines(), "different seed -> different run")


func test_map_never_exposed() -> void:
	for m: Dictionary in Run.new().get_method_list():
		var mn := String(m["name"])
		check(mn.begins_with("_") or not ("map" in mn or "route" in mn), "no public map accessor: " + mn)
	for s in 3:
		var run := _new_run(100 + s)
		var rng := Rng.new(s)
		for _i in 400:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			var found: Array = []
			_find_keys(v, FORBIDDEN_KEYS, found)
			_find_keys(run.summary(), FORBIDDEN_KEYS, found)
			if not found.is_empty():
				check(false, "map data leaked through the API: %s" % [found])
				return
			RunBot.step(run, rng, "random", 0.2)
	check(true, "walked 3 runs without leaking map data")


func test_choice_binds_memory_to_its_hero() -> void:
	var checked := 0
	for s in 4:
		var run := _new_run(200 + s)
		var rng := Rng.new(s)
		for _i in 400:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			if v["step"] == "choice" and v["kind"] != "legend":
				var before := _mem_list(run)
				var shift_before: Array = []
				for h: Dictionary in v["party"]:
					shift_before.append(h["alignment"])
				var pick := rng.int_range(0, v["choices"].size() - 1)
				var c: Dictionary = v["choices"][pick]
				var hi := int(c["hero_index"])
				if hi >= 0:
					eq(String(v["party"][hi]["base"]), String(c["class"]), "choice bound to a hero of its class")
				var res: Dictionary = run.choose(pick)
				var after := _mem_list(run)
				for k in before.size():
					eq(after[k], before[k] + (1 if k == hi else 0), "only the choice's hero gains the memory")
				if hi >= 0:
					eq(int(res["memory"]["hero_index"]), hi, "memory reported for that hero")
				for k in range(before.size(), after.size()):
					eq(after[k], 0, "a recruit joins with no memories")
				checked += 1
			else:
				RunBot.step(run, rng, "random", 0.2)
	check(checked > 30, "checked %d choices" % checked)


func test_pvp_grants_no_memories_and_defeat_costs_health() -> void:
	var pvp := 0
	var losses := 0
	for s in 8:
		var run := _new_run(300 + s)
		var rng := Rng.new(s)
		for _i in 400:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			if v["step"] == "fight" and v["type"] == "pvp":
				var mem := _mem_list(run)
				var levels: Array = v["party"].map(func(h: Dictionary) -> int: return int(h["level"]))
				var hp := int(v["health"])
				var r: Dictionary = run.resolve_fight()
				eq(_mem_list(run), mem, "PvP grants no memories")
				eq(run.party_view().map(func(h: Dictionary) -> int: return int(h["level"])), levels, "PvP grants no levels")
				var lost := not bool(r["run"]["won"])
				eq(int(r["run"]["health"]), hp - (int(T.RUN["pvp_loss_health"]) if lost else 0), "PvP loss costs health, win does not")
				pvp += 1
				losses += 1 if lost else 0
			else:
				RunBot.step(run, rng, "greedy", 0.2)
		if run.summary()["outcome"] == "fallen":
			eq(int(run.summary()["health"]), 0, "a fallen run ends at 0 health")
	check(pvp > 20 and losses > 0, "saw %d PvP fights, %d losses" % [pvp, losses])


func test_party_size_between_2_and_4() -> void:
	var run: RefCounted = Run.new()
	var v: Dictionary = run.start_run(5, {"pool": _fresh_pool(), "save_echo": false, "log": false})
	eq(v["step"], "draft", "a run starts with the draft")
	eq(int(v["offered"].size()), int(T.RUN["start_pool_size"]), "offered pool size")
	run.choose(0)
	check(run.choose(0).has("error"), "cannot draft the same hero twice")
	eq(run.current_node()["step"], "draft", "still drafting after one pick")
	run.choose(1)
	eq(run.party_view().size(), 2, "party starts with two heroes")
	var max_seen := 0
	for s in 6:
		var r := _new_run(400 + s)
		var rng := Rng.new(s)
		for _i in 400:
			if r.is_over():
				break
			var n: int = r.party_view().size()
			max_seen = maxi(max_seen, n)
			if r.current_node()["step"] == "draft":
				RunBot.step(r, rng, "greedy", 0.2)
				continue
			if n < 2 or n > 4:
				check(false, "party size %d out of 2..4" % n)
				return
			var cv: Dictionary = r.current_node()
			if cv["step"] == "choice" and n >= 4:
				for c: Dictionary in cv["choices"]:
					check(not c.has("recruit"), "no recruitment offered to a full party")
			RunBot.step(r, rng, "greedy", 0.2)
	eq(max_seen, 4, "parties do reach 4")


func test_set_formation() -> void:
	var run := _new_run(7)
	run.choose(0)
	run.choose(1)  # draft done
	var bad: Dictionary = run.set_formation([[0, 0], [0, 0]].slice(0, run.party_view().size()))
	check(bad.has("error"), "shared slot rejected")
	check(run.set_formation([[0, 0]]).has("error"), "wrong count rejected")
	var slots: Array = []
	for k in run.party_view().size():
		slots.append([1, k])
	var ok: Dictionary = run.set_formation(slots)
	check(ok.get("ok", false), "valid placement accepted: %s" % ok)
	eq(run.combat_party()["heroes"][0]["slot"], [1, 0], "placement reaches the combat party")


func test_legend_gate() -> void:
	var st := {"legendaries": 0, "appeared": false, "misses": 0}
	check(LegendGate.eligible({"class": "paladin", "level": 3}, st), "eligible at advanced level 3, no depth gate")
	check(not LegendGate.eligible({"class": "warlock", "level": 4}, st), "no offer while the class has no authored Legendary")
	check(not LegendGate.eligible({"class": "paladin", "level": 2}, st), "not before advanced level 3")
	check(not LegendGate.eligible({"class": "fighter", "level": 6}, st), "base heroes not eligible")
	check(not LegendGate.eligible({"class": "paladin", "level": 3}, {"legendaries": 1}), "1 Legendary per party")
	check(not LegendGate.eligible({"class": "paladin", "level": 3}, {"appeared": true}), "at most once per run")
	eq(LegendGate.chance({"misses": 0}), 0.08, "starts at 8%")
	eq(LegendGate.chance({"misses": 2}), 0.24, "+8% per node without it")
	eq(LegendGate.chance({"misses": 50}), 0.6, "capped at 60%")
	for cid: String in GameData.Classes.CLASSES:
		if String(GameData.Classes.CLASSES[cid]["tier"]) == "advanced":
			var e := LegendGate.encounter_for(cid)
			check(not e.is_empty() and e["choices"].size() >= 2, "legend's memory written for " + cid)


func test_legend_memory_is_an_encounter_once_per_run() -> void:
	var offers := 0
	var accepted := 0
	for s in 120:
		var run := _new_run(600 + s)
		var rng := Rng.new(s)
		var seen := 0
		var decline := s % 2 == 0
		for _i in 400:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			if v["step"] == "choice" and v["kind"] == "legend":
				seen += 1
				offers += 1
				eq(v["choices"].size(), 2, "accept or let it go")
				var hi := int(v["choices"][0]["hero_index"])
				eq(String(v["party"][hi]["tier"]), "advanced", "offered to an advanced hero")
				check(int(v["party"][hi]["level"]) >= 3, "at advanced level 3+")
				var pick := 0
				for c: Dictionary in v["choices"]:
					if c.has("legend") != decline:
						pick = int(c["index"])
				run.choose(pick)
				eq(bool(run.party_view()[hi]["legendary"]), not decline, "accepting makes the hero Legendary")
				accepted += 0 if decline else 1
				continue
			RunBot.step(run, rng, "random", 0.0)
		check(seen <= 1, "legend's memory appears at most once per run (seed %d: %d)" % [600 + s, seen])
	check(offers >= 3 and accepted > 0, "saw %d offers" % offers)


func test_opponent_hidden_before_fight() -> void:
	var fights := 0
	for s in 3:
		var run := _new_run(700 + s)
		var rng := Rng.new(s)
		for _i in 400:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			if v["step"] == "fight":
				var found: Array = []
				_find_keys(v["opponent"], ["heroes", "slot", "formation", "class", "level", "items"], found)
				check(found.is_empty(), "pre-fight view hides the opponent's party: %s" % [found])
				var r: Dictionary = run.resolve_fight()
				check(r.has("opponent") and r["opponent"]["heroes"].size() >= 1, "full opponent in the fight result")
				fights += 1
			else:
				RunBot.step(run, rng, "greedy", 0.2)
	check(fights > 10, "checked %d fights" % fights)


func test_no_encounter_repeats() -> void:
	var pool := _fresh_pool()
	var all_seen := {}
	for s in 30:
		var run := _new_run(800 + s, pool)
		RunBot.play(run, Rng.new(s), "random")
		var ids: Array = run.summary()["encounters_seen"]
		var seen := {}
		for id: String in ids:
			check(not seen.has(id), "seed %d repeats %s" % [800 + s, id])
			seen[id] = true
			all_seen[id] = true
	check(all_seen.size() >= 50, "runs see varied subsets (%d different encounters over 30 runs)" % all_seen.size())
	check(Catalog.all().size() >= 60, "catalog has %d encounters" % Catalog.all().size())


func test_choices_route_through_pvp() -> void:
	var diff := 0
	var tot := 0
	for s in 30:
		for depth in [2, 5, 9, 11]:   # 5: through a floor guardian, 9: through a PvP node
			var a := _next_after(900 + s, depth, 0)
			var b := _next_after(900 + s, depth, 1)
			if a != "" and b != "":
				tot += 1
				diff += 1 if a != b else 0
	check(tot > 90 and diff >= tot * 0.9, "choice 0 vs 1 changes the next encounter in %d/%d" % [diff, tot])


static func _next_after(sd: int, depth: int, pick: int) -> String:
	var run := _new_run(sd)
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


func test_pvp_matched_by_floor() -> void:
	var pool := _fresh_pool()
	eq(pool.echoes.size(), int(T.RUN["echo_seed_per_floor"]) * T.RUN["floors"].size(), "seeds cover every floor")
	var rng := Rng.new(3)
	for f in range(1, T.RUN["floors"].size() + 1):
		eq(EchoPool.floor_of(pool.pick(f, rng)), f, "opponent recorded on the same floor")
	var picks := {}
	for s in 12:
		var run := _new_run(1000 + s, pool)
		var r: RefCounted = run
		RunBot.play(r, Rng.new(s))
		pool.add(r.combat_party(), {"generated": false, "floor": 2, "outcome": "fallen"})
	for _i in 200:
		var e: Dictionary = pool.pick(2, rng)
		picks[bool(e["meta"].get("generated", false))] = int(picks.get(bool(e["meta"].get("generated", false)), 0)) + 1
	eq(int(picks.get(true, 0)), 0, "with enough real Echoes on a floor, generated ones step aside")


func test_rest_and_guardians() -> void:
	var rests := 0
	var guardians := 0
	for s in 20:
		var run := _new_run(1100 + s)
		var rng := Rng.new(s)
		for _i in 500:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			if v["step"] == "choice":
				for c: Dictionary in v["choices"]:
					if c.has("rest"):
						var mem := _mem_list(run)
						var hp := int(v["health"])
						run.choose(int(c["index"]))
						eq(_mem_list(run), mem, "resting grants no memory")
						eq(int(run.current_node()["health"]), mini(hp + int(c["rest"]), int(T.RUN["max_health"])), "rest heals")
						rests += 1
						break
			if v["step"] == "fight" and v["type"] == "guardian":
				guardians += 1
			RunBot.step(run, rng, "greedy", 0.2)
	check(rests > 3 and guardians > 20, "saw %d rests, %d guardian fights" % [rests, guardians])


func test_guardians_escalate_and_identity() -> void:
	var defs: Array = Run._guardians()
	eq(defs.size(), T.RUN["floors"].size() - 1, "one guardian per floor before the Crystal")
	var prev_cost := 0
	var prev_level := 0
	for g: Dictionary in defs:
		check(String(g["name"]) != "" and String(g["intro"]).length() > 40, "authored name and intro: " + String(g["name"]))
		check(int(g["loss_health"]) >= prev_cost and int(g["loss_health"]) > int(T.RUN["pvp_loss_health"]), "loss cost rises and beats PvP")
		check(int(g["level"]) >= prev_level, "levels never fall")
		prev_cost = int(g["loss_health"])
		prev_level = int(g["level"])
	var run := _new_run(1200)
	var rng := Rng.new(1)
	for _i in 300:
		if run.is_over():
			break
		var v: Dictionary = run.current_node()
		if v["step"] == "fight" and v["type"] == "guardian":
			check(String(v["opponent"]["intro"]) != "", "guardian intro shown before the fight")
			check(not v["opponent"].has("heroes"), "composition hidden before the fight")
			var hp := int(v["health"])
			var r: Dictionary = run.resolve_fight()
			if not r["run"]["won"]:
				check(hp - int(r["run"]["health"]) >= 2, "a guardian loss costs more than a PvP loss")
			return
		RunBot.step(run, rng, "greedy", 0.2)
	check(false, "no guardian reached")


func test_rivals_and_team_names() -> void:
	var pool := _fresh_pool()
	var names := {}
	for e: Dictionary in pool.echoes:
		check(e["meta"].has("team_name") and e["meta"].has("crest"), "seed Echo has team_name and crest")
		names[e["name"]] = true
	eq(names.size(), pool.echoes.size(), "generated Echo names are distinct")
	for s in 10:
		var run: RefCounted = Run.new()
		run.start_run(1300 + s, {"pool": pool, "log": false})
		RunBot.play(run, Rng.new(s))
		var sm: Dictionary = run.summary()
		var seen := {}
		for nm: String in sm["rivals"]:
			check(not seen.has(nm), "rival %s met twice in one run" % nm)
			seen[nm] = true
		eq(String(sm["echo"]["meta"]["team_name"]), String(sm["team_name"]), "snapshot carries the team name")
		check(sm["echo"]["meta"].has("crest"), "snapshot carries a crest field")
		for line: String in run.log_lines():
			if line.begins_with("[") and "PvP" in line:
				check(not "power" in line, "no power shown before the fight: " + line)


func test_crystal_final_node() -> void:
	var pool := _fresh_pool()
	var defeats := 0
	var reached := 0
	for s in 40:
		var run: RefCounted = Run.new()
		run.start_run(1400 + s, {"pool": pool, "save_echo": false, "log": false, "story_chapter": 2})
		var rng := Rng.new(s)
		for _i in 500:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			if v["step"] == "fight" and v["type"] == "crystal":
				reached += 1
				check(not v["opponent"].has("memories") and String(v["opponent"]["intro"]) != "", "Crystal: intro shown, memories hidden")
				var r: Dictionary = run.resolve_fight()
				var seq: Array = r["opponent"]["memories"]
				eq(seq.size(), int(T.RUN["crystal_memories"]), "four memories queued")
				check(seq.has("lumari_knight"), "the chapter's memory is in the sequence")
				for id: String in seq:
					check(int(GameData.Memories.MEMORIES[id]["chapter"]) <= 2, "no memory beyond the story chapter")
				check(run.is_over(), "no retry: the Crystal fight ends the run either way")
				var sm: Dictionary = run.summary()
				if not r["run"]["won"]:
					defeats += 1
					eq(int(sm["glimmer_breakdown"]["fragments"]), int(r["fragments"]) * int(T.RUN["glimmers_per_fragment"]), "fragments become Glimmers")
					eq(int(sm["health"]), 0, "the party fell")
				else:
					eq(String(sm["remembrance"]["id"]), String(T.REMEMBRANCES[2]["id"]), "chapter 2 Remembrance")
				break
			RunBot.step(run, rng, "greedy", 0.2)
	check(reached > 5, "reached the Crystal %d times" % reached)
	var a := _new_run(77)
	var b := _new_run(77)
	eq(a._crystal_sequence(), b._crystal_sequence(), "memory sequence is deterministic per seed")


func test_echo_pool_persistence() -> void:
	var path := "user://test_echo_pool.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var pool: RefCounted = EchoPool.open(path)
	eq(pool.echoes.size(), SEEDED, "fresh pool is seeded with generated Echoes")
	check(FileAccess.file_exists(path), "seeded pool saved to disk")
	var run: RefCounted = Run.new()
	run.start_run(11, {"pool_path": path, "log": false})
	RunBot.play(run, Rng.new(1))
	check(run.is_over(), "run ended")
	var s: Dictionary = run.summary()
	check(s.has("echo"), "finished run reports its Echo")
	var reopened: RefCounted = EchoPool.open(path)
	check(int(s["echoes_recorded"]) >= 1, "finished run recorded at least one Echo")
	eq(reopened.echoes.size(), SEEDED + int(s["echoes_recorded"]), "one snapshot per floor reached, on disk")
	var floors := {}
	for e: Dictionary in reopened.echoes.slice(SEEDED):
		floors[int(e["meta"]["floor"])] = true
	eq(floors.size(), int(s["echoes_recorded"]), "snapshots are recorded per floor")
	eq(Echo.to_json(reopened.echoes[-1]), Echo.to_json(s["echo"]), "snapshot round-trips byte-identically")
	eq(String(reopened.echoes[-1]["meta"]["outcome"]), String(s["outcome"]), "snapshot records the outcome")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var healed: RefCounted = EchoPool.open(path)
	eq(healed.echoes.size(), SEEDED, "corrupt pool file is replaced by a seeded one")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_victory_rewards() -> void:
	var pool := _fresh_pool()
	for s in 40:
		var run := _new_run(500 + s, pool)
		RunBot.play(run, Rng.new(s))
		var sm: Dictionary = run.summary()
		if sm["outcome"] == "victory":
			eq(int(sm["shards"]), int(T.RUN["victory_shards"]), "victory grants a Shard")
			check(sm.has("monument") and sm.has("remembrance"), "victory grants a Monument and a Remembrance")
			eq(int(sm["glimmer_breakdown"]["fragments"]), 0, "no fragment Glimmers on a victory (the Shard is the reward)")
			check(int(sm["glimmers"]) > 0, "Glimmers granted")
			return
	check(false, "no victory in 40 bot runs")
