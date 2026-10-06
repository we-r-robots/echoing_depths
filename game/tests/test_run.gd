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
	check(LegendGate.eligible({"class": "lightsworn", "level": 3}, st), "eligible at advanced level 3, no depth gate")
	check(not LegendGate.eligible({"class": "warlock", "level": 4}, st), "no offer while the class has no authored Legendary")
	check(not LegendGate.eligible({"class": "lightsworn", "level": 2}, st), "not before advanced level 3")
	check(not LegendGate.eligible({"class": "fighter", "level": 6}, st), "base heroes not eligible")
	check(not LegendGate.eligible({"class": "lightsworn", "level": 3}, {"legendaries": 1}), "1 Legendary per party")
	check(not LegendGate.eligible({"class": "lightsworn", "level": 3}, {"appeared": true}), "at most once per run")
	eq(LegendGate.chance({"misses": 0}), 0.08, "starts at 8%")
	eq(LegendGate.chance({"misses": 2}), 0.24, "+8% per node without it")
	eq(LegendGate.chance({"misses": 50}), 0.6, "capped at 60%")
	# a legend's memory exists for every class with an authored Legendary (the only ones offered);
	# the approved round-1 classes (2026-10-06) have none yet, so they're never offered one
	for cid: String in GameData.Classes.CLASSES:
		if String(GameData.Classes.CLASSES[cid]["tier"]) == "legendary":
			var e := LegendGate.encounter_for(String(GameData.Classes.CLASSES[cid]["advances_from"]))
			check(not e.is_empty() and e["choices"].size() >= 2, "legend's memory written for " + cid)
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://core/run/legend_memories.json"))
	for e: Dictionary in (j as Dictionary)["encounters"]:
		check(GameData.has_class(String(e["for_class"])), "legend memory %s names a live class" % e["id"])


func test_legend_memory_is_an_encounter_once_per_run() -> void:
	var offers := 0
	var accepted := 0
	for s in 360:   # round 2: only Lightsworn (Fighter Mercy+Order) has a Legendary now, so offers are rarer
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
				var full: Dictionary = r.get("opponent", {})
				check(full.get("heroes", full.get("memories", [])).size() >= 1, "full opponent in the fight result")
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
						rests += 1   # encounters no longer offer a +health rest (user, 2026-10-06)
			if v["step"] == "fight" and v["type"] == "guardian":
				guardians += 1
			RunBot.step(run, rng, "greedy", 0.2)
	check(rests == 0 and guardians > 20, "saw %d rests (none expected), %d guardian fights" % [rests, guardians])


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


# ---------------------------------------------------------------- playtest 1 (user, 2026-10-05)

## Plays (greedy, no Awakening) until hero `hi` holds `n` memories at base tier. Returns the run or null.
static func _until_memories(seed_value: int, n: int, opts := {}) -> Array:
	var run: RefCounted = Run.new()
	var o := {"pool": _fresh_pool(), "save_echo": false, "log": false}
	o.merge(opts, true)
	run.start_run(seed_value, o)
	var rng := Rng.new(seed_value)
	for _i in 400:
		if run.is_over():
			return []
		var v: Dictionary = run.current_node()
		for i in v["party"].size():
			if int(v["party"][i]["memories"]) >= n:
				return [run, i]
		if v["step"] == "decision":
			return [run, int(v["hero_index"])]
		if v["step"] == "choice":   # level the least-remembered hero; never Awaken on the way
			var best := 0
			for c: Dictionary in v["choices"]:
				if int(c["hero_index"]) >= 0 and (int(v["choices"][best]["hero_index"]) < 0 \
						or int(v["party"][int(c["hero_index"])]["memories"]) > int(v["party"][int(v["choices"][best]["hero_index"])]["memories"])):
					best = int(c["index"])
			run.choose(best)
		elif v["step"] == "fight":
			run.resolve_fight()
		elif v["step"] == "outcome":
			run.advance()
		else:
			RunBot.step(run, rng, "greedy", 0.0)
	return []


func test_awaken_after_the_second_memory() -> void:
	eq(int(T.RUN["advance_threshold"]), 2, "Awakening after the 2nd memory (user, 2026-10-05)")
	eq(int(EncounterDB.rules()["advance_threshold"]), int(T.RUN["advance_threshold"]), "encounter screens use the run's threshold")
	var checked := 0
	for s in 6:
		var one := _until_memories(5100 + s, 1)
		if one.is_empty():
			continue
		var run: RefCounted = one[0]
		var hi: int = one[1]
		var h: Dictionary = run.party_view()[hi]
		eq(int(h["level"]), 2, "level 1 + 1 memory = level 2")
		check(not bool(h["awaken_ready"]), "one memory: not ready")
		check(run.awaken(hi).has("error"), "cannot Awaken with one memory")
		var two := _until_memories(5100 + s, 2)
		run = two[0]
		hi = two[1]
		h = run.party_view()[hi]
		eq(int(h["memories"]), 2, "two memories")
		eq(int(h["level"]), 3, "level 1 + 2 memories = level 3 at the moment of Awakening")
		check(bool(h["awaken_ready"]) and bool(h["awaken_new"]), "ready and not yet answered")
		check(String(h["awaken_class"]) != "", "the class the grid region gives is shown")
		check(String(run.current_node()["step"]) != "decision", "no forced decision prompt")
		var trail: Array = h["trail"]
		eq(trail.size(), 2, "both memories on the trail")
		var res: Dictionary = run.awaken(hi)
		check(res.get("ok", false), "Awaken from any stop (%s)" % run.current_node()["step"])
		h = run.party_view()[hi]
		eq(String(h["class"]), String(res["class"]), "the new class")
		eq(String(h["tier"]), "advanced", "advanced tier")
		eq(int(h["level"]), 1, "the new class starts at level 1")
		eq((h["trail_before"] as Array).size(), 2, "the trail moves to before the Awakening")
		check(run.awaken(hi).has("error"), "an advanced hero cannot Awaken again")
		checked += 1
	check(checked >= 4, "checked %d heroes" % checked)


func test_hold_back_keeps_the_offer() -> void:
	var two := _until_memories(5200, 2)
	var run: RefCounted = two[0]
	var hi: int = two[1]
	check(run.hold_back(hi).get("ok", false), "Hold Back")
	var h: Dictionary = run.party_view()[hi]
	check(bool(h["awaken_ready"]) and not bool(h["awaken_new"]) and bool(h["held"]), "kept: still ready, answered for now")
	eq(String(h["tier"]), "base", "stays base")
	var three := _until_memories(5200, 3)
	# replay the same path: hold at 2, then reach 3
	run = Run.new()
	run.start_run(5200, {"pool": _fresh_pool(), "save_echo": false, "log": false})
	var held := false
	for _i in 400:
		var v: Dictionary = run.current_node()
		var p: Dictionary = v["party"][hi] if hi < v["party"].size() else {}
		if not held and not p.is_empty() and int(p["memories"]) >= 2:
			run.hold_back(hi)
			held = true
		if held and int(p.get("memories", 0)) >= 3:
			check(bool(p["awaken_new"]), "a new memory brings the offer back")
			eq(int(p["level"]), 4, "held heroes keep levelling")
			break
		if v["step"] == "choice":
			var best := 0
			for c: Dictionary in v["choices"]:
				if int(c["hero_index"]) == hi:
					best = int(c["index"])
			run.choose(best)
		elif v["step"] == "fight":
			run.resolve_fight()
		elif v["step"] == "outcome":
			run.advance()
		else:
			break
	check(not three.is_empty(), "a hero reached 3 memories")


func test_advance_prompt_option_keeps_the_decision_step() -> void:
	var two := _until_memories(5300, 2, {"advance_prompt": true})
	var run: RefCounted = two[0]
	var v: Dictionary = run.current_node()
	eq(String(v["step"]), "decision", "advance_prompt: the old decision step")
	var res: Dictionary = run.choose(0)
	check(res.get("ok", false) and String(run.party_view()[int(v["hero_index"])]["tier"]) == "advanced", "choose(0) Awakens")
	check(String(run.current_node()["step"]) != "decision", "decision answered")


func test_recruit_pacing_fills_the_party() -> void:
	var n := 60
	var three_by_pvp := 0
	var four_by_d8 := 0
	var first_offer_late := 0
	for s in n:
		var run := _new_run(5400 + s)
		var rng := Rng.new(s)
		var enc_seen := 0
		var offered := false
		for _i in 600:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			if v["step"] == "choice":
				enc_seen += 1
				for c: Dictionary in v["choices"]:
					offered = offered or c.has("recruit")
				if enc_seen == 2 and not offered:
					first_offer_late += 1
			if v["step"] == "fight" and v["type"] == "pvp" and int(v["floor"]) == 1 and v["party"].size() >= 3:
				three_by_pvp += 1 if int(v["depth"]) == 4 else 0
			if int(v["depth"]) == 8 and v["step"] == "fight" and v["party"].size() == 4:
				four_by_d8 += 1
			RunBot.step(run, rng, "greedy", 0.2)
	eq(first_offer_late, 0, "a party of 2 always meets a recruit offer within its first 2 encounters")
	eq(three_by_pvp, n, "a player who takes recruits has 3 heroes by the first PvP")
	check(four_by_d8 >= n * 9 / 10, "and 4 by early floor 2 (%d of %d at depth 8)" % [four_by_d8, n])


func test_recruit_choice_always_binds_in_recruitment() -> void:
	var seen := 0
	for s in 40:
		var run := _new_run(5500 + s)
		var rng := Rng.new(s)
		for _i in 600:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			if v["step"] == "choice" and v["kind"] == "recruitment" and v["party"].size() < 4:
				var any := false
				for c: Dictionary in v["choices"]:
					any = any or c.has("recruit")
				check(any, "a recruitment node below max party offers a recruit")
				seen += 1
			RunBot.step(run, rng, "random", 0.2)
	check(seen > 40, "checked %d recruitment nodes" % seen)


static func _echo_of(pool: RefCounted, floor_n: int, size: int, level: int, nm: String) -> void:
	var hs: Array = []
	var classes := ["fighter", "healer", "rogue", "mage"]
	for i in size:
		hs.append({"name": "H%d" % i, "class": classes[i], "level": level, "items": {}, "alignment": [0, 0],
			"slot": [i % 2, i / 2]})
	pool.add({"name": nm, "heroes": hs}, {"generated": false, "floor": floor_n, "team_name": nm})


func test_matchmaking_is_size_aware() -> void:
	var party := {"name": "P", "heroes": [
		{"name": "A", "class": "fighter", "level": 2, "items": {}, "alignment": [0, 0], "slot": [0, 1]},
		{"name": "B", "class": "mage", "level": 2, "items": {}, "alignment": [0, 0], "slot": [1, 1]}]}
	var pool: RefCounted = EchoPool.new()
	for k in 3:
		_echo_of(pool, 1, 4, 3, "Four%d" % k)
		_echo_of(pool, 1, 3, 2, "Three%d" % k)
		_echo_of(pool, 1, 2, 2, "Two%d" % k)
		_echo_of(pool, 2, 2, 2, "FloorTwo%d" % k)
	var rng := Rng.new(1)
	var sizes := {}
	for _i in 200:
		var e: Dictionary = pool.pick(1, rng, {}, party)
		sizes[e["heroes"].size()] = true
		eq(EchoPool.floor_of(e), 1, "same floor first")
	eq(sizes.keys(), [2], "a 2-hero party meets 2-hero Echoes when they exist")
	# only 3- and 4-hero Echoes left on floor 1: widen by one hero, never to 4
	var ex := {"Two0": true, "Two1": true, "Two2": true}
	for _i in 100:
		eq(int(pool.pick(1, rng, ex, party)["heroes"].size()), 3, "widened to +-1 hero, never a 4-hero Echo")
	# only 4-hero Echoes on floor 1: a neighbouring floor's 2-hero Echo is closer
	ex.merge({"Three0": true, "Three1": true, "Three2": true})
	for _i in 50:
		var e: Dictionary = pool.pick(1, rng, ex, party)
		eq(int(e["heroes"].size()), 2, "a neighbouring floor before a 4-hero Echo")
		eq(EchoPool.floor_of(e), 2, "from floor 2")
	# power: same size, far stronger Echoes step aside for close ones
	var p2: RefCounted = EchoPool.new()
	_echo_of(p2, 1, 2, 6, "Strong")
	_echo_of(p2, 1, 2, 2, "Even")
	for _i in 50:
		eq(String(p2.pick(1, rng, {}, party)["name"]), "Even", "similar total level first")
	# nothing near at all: the closest Echo
	var p3: RefCounted = EchoPool.new()
	_echo_of(p3, 4, 4, 4, "Far4")
	_echo_of(p3, 5, 3, 4, "Far3")
	eq(String(p3.pick(1, rng, {}, party)["name"]), "Far3", "fallback: the closest hero count")


func test_starter_echoes_sized_like_a_party() -> void:
	var pool := _fresh_pool()
	var sizes: Array = T.RUN["echo_seed_sizes"]
	for f in range(1, T.RUN["floors"].size() + 1):
		var got: Array = []
		for e: Dictionary in pool.echoes:
			if EchoPool.floor_of(e) == f:
				got.append(e["heroes"].size())
		got.sort()
		var want: Array = (sizes[f - 1] as Array).duplicate()
		want.sort()
		eq(got, want, "floor %d starter Echo sizes" % f)
	# a 2-hero floor-1 party never meets a 4-hero starter Echo (closer ones exist)
	for s in 20:
		var run := _new_run(5600 + s)
		var rng := Rng.new(s)
		for _i in 200:
			var v: Dictionary = run.current_node()
			if v["step"] == "fight" and v["type"] == "pvp":
				if v["party"].size() == 2:
					var r: Dictionary = run.resolve_fight()
					check(r["opponent"]["heroes"].size() <= 3, "a 2-hero party never meets a 4-hero Echo")
				break
			if v["step"] == "choice":   # decline recruits: stay at 2 heroes
				var pick := int(v["choices"][0]["index"])
				for c: Dictionary in v["choices"]:
					if not c.has("recruit"):
						pick = int(c["index"])
						break
				run.choose(pick)
			else:
				RunBot.step(run, rng, "greedy", 0.0)


func test_player_files_are_guarded() -> void:
	const UserFiles = preload("res://core/user_files.gd")
	check(not UserFiles.is_real_game(), "tests are never the real game")
	for f: String in UserFiles.PLAYER_FILES:
		check(UserFiles.is_player_file("user://" + f), "%s is a player file" % f)
		check(not UserFiles.is_player_file(UserFiles.path(f)), "the default %s here is the sandbox's" % f)
	check(not UserFiles.is_player_file(EchoPool.default_path()), "the default Echo pool is not the player's")
	check(UserFiles.may_write("user://test_unused_pool.json"), "test files may be written")
	var p: RefCounted = EchoPool.new()
	check(String(p.path) == "", "a new pool has no file until given one")
