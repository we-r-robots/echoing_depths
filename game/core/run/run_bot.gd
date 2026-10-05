extends RefCounted
## Simple seeded bot that plays a Run to the end (tests, simulated playthroughs).
## policy "greedy": rest when health is low (<= max - 3), recruit while the party is small, otherwise level the least-remembered hero;
##                  Hold Back sometimes (hold_chance), always accept a legend's memory.
## policy "random": uniform random choices and decisions.

const Rng = preload("res://core/rng.gd")


static func play(run: RefCounted, rng: Rng, policy := "greedy", hold_chance := 0.2, max_steps := 500) -> void:
	for _i in max_steps:
		if run.is_over():
			return
		step(run, rng, policy, hold_chance)


static func step(run: RefCounted, rng: Rng, policy: String, hold_chance: float) -> void:
	var v: Dictionary = run.current_node()
	match String(v["step"]):
		"draft":
			var free: Array = v["offered"].filter(func(o: Dictionary) -> bool: return not o["taken"])
			run.choose(int(free[rng.int_range(0, free.size() - 1)]["index"]))
		"decision":
			var pick := 0
			if policy == "random":
				pick = rng.int_range(0, 1)
			elif v["type"] == "advance":
				var h: Dictionary = v["party"][int(v["hero_index"])]
				pick = 1 if (int(h["level"]) < int(h["max_level"]) and rng.next_float() < hold_chance) else 0
			run.choose(pick)
		"choice":
			var choices: Array = v["choices"]
			if policy == "random":
				run.choose(rng.int_range(0, choices.size() - 1))
				return
			var best := 0
			var best_score := -INF
			for c: Dictionary in choices:
				var score := rng.next_float()
				var hi := int(c["hero_index"])
				if hi >= 0:
					var h: Dictionary = v["party"][hi]
					score -= float(h["memories"]) * 2.0
					if int(h["level"]) >= int(h["max_level"]):
						score -= 10.0
				if c.has("recruit"):
					score += 20.0
				if c.has("legend"):
					score += 50.0
				if c.has("rest"):
					score += 30.0 if int(v["health"]) <= int(v["max_health"]) - 3 else -30.0
				if score > best_score:
					best_score = score
					best = int(c["index"])
			run.choose(best)
		"fight":
			run.resolve_fight()
		"outcome":
			run.advance()
