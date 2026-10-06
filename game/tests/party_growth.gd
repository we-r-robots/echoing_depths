extends SceneTree
## Party growth by depth: plays N bot runs and prints the median / mean party size the party has
## when it reaches each depth (runs still alive at that depth), plus the share of runs with 3 and 4
## heroes by the first PvP and by floor 2. Measures recruitment pacing (03 "Gathering").
##   godot --path game --headless -s res://tests/party_growth.gd -- [--n=300] [--seed=1] [--policy=greedy|random|decline]
## policy "decline" takes a recruit only when nothing else is offered (a worst case for growth).
## Uses its own pool file under user://sandbox/ (never the player's files).

const Run = preload("res://core/run/run.gd")
const RunBot = preload("res://core/run/run_bot.gd")
const EchoPool = preload("res://core/run/echo_pool.gd")
const Rng = preload("res://core/rng.gd")


func _init() -> void:
	var n := 300
	var seed_value := 1
	var policy := "greedy"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		elif a.begins_with("--policy="):
			policy = a.substr(9)
	var pool: RefCounted = EchoPool.new()
	pool.path = "user://sandbox/party_growth_pool.json"
	pool.seed_generated(1)
	var by_depth := {}     # depth -> [party sizes]
	var first_pvp := []    # party size at the first PvP
	var floor2 := []       # party size entering floor 2
	var offers := []       # recruit offers seen in the first 10 depths
	for k in n:
		var run: RefCounted = Run.new()
		run.start_run(seed_value + k, {"pool": pool, "log": false, "save_echo": true})
		var rng := Rng.new(seed_value + k + 77)
		var seen := {}
		var n_offers := 0
		for _i in 600:
			if run.is_over():
				break
			var v: Dictionary = run.current_node()
			var d := int(v["depth"])
			if v["step"] != "draft" and not seen.has(d):
				seen[d] = true
				var sz: int = v["party"].size()
				(by_depth.get_or_add(d, []) as Array).append(sz)
				if v["step"] == "fight" and v.get("type", "") == "pvp" and first_pvp.size() <= k:
					first_pvp.append(sz)
				if int(v["floor"]) == 2 and floor2.size() <= k:
					floor2.append(sz)
			if v["step"] == "choice" and d <= 10:
				for c: Dictionary in v["choices"]:
					if c.has("recruit"):
						n_offers += 1
						break
			if policy == "decline" and v["step"] == "choice":
				var pick := -1
				for c: Dictionary in v["choices"]:
					if not c.has("recruit") and not c.has("rest"):
						pick = int(c["index"])
						break
				if pick >= 0:
					run.choose(pick)
					continue
			RunBot.step(run, rng, "greedy" if policy == "decline" else policy, 0.2)
		offers.append(n_offers)
	print("policy %s, %d runs" % [policy, n])
	var keys: Array = by_depth.keys()
	keys.sort()
	var line := PackedStringArray()
	for d: int in keys:
		if d > 16:
			break
		var a: Array = by_depth[d]
		a.sort()
		var mean := 0.0
		for x: int in a:
			mean += x
		line.append("d%d: med %d mean %.2f (n %d)" % [d, a[a.size() / 2], mean / a.size(), a.size()])
	print("party size by depth:\n  " + "\n  ".join(line))
	print("at the first PvP: %s" % _share(first_pvp))
	print("entering floor 2: %s" % _share(floor2))
	var tot := 0
	for o: int in offers:
		tot += o
	print("recruit offers in depths 1-10: mean %.2f" % (float(tot) / maxf(1.0, offers.size())))
	quit(0)


static func _share(a: Array) -> String:
	if a.is_empty():
		return "-"
	var c := {2: 0, 3: 0, 4: 0}
	for x: int in a:
		c[x] = int(c.get(x, 0)) + 1
	return "2: %d%%, 3: %d%%, 4: %d%% (n %d)" % [100 * c[2] / a.size(), 100 * c[3] / a.size(), 100 * c[4] / a.size(), a.size()]
