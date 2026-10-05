extends SceneTree
## Simulates N random 4v4 fights and N party-vs-monster fights; prints ms/fight and fight lengths.
## godot --path game --headless -s res://tests/benchmark.gd [-- --n=1000 --seed=1]

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Rng = preload("res://core/rng.gd")

const TARGET_MS := 2.0


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var n := int(args.get("n", "1000"))
	var rng := Rng.new(int(args.get("seed", "1")))
	var parties: Array = []
	var monsters: Array = []
	for i in n:
		parties.append([PartyGen.random_party(rng), PartyGen.random_party(rng)])
	for i in n:
		monsters.append([PartyGen.random_party(rng), PartyGen.monster_group(rng, 1 + i % 10)])
	for i in mini(50, n):   # untimed warm-up, so the first section isn't charged for it
		CombatSim.simulate(i, parties[i][0], parties[i][1])
	var report := run(parties, true)
	print("=== PvP: random 4v4 ===")
	print(report["text"])
	var mreport := run(monsters, true)
	print("=== PvE: random party vs Vault monsters (depth 1-10) ===")
	print(mreport["text"])
	var ok := float(report["ms_per_fight"]) < TARGET_MS and float(mreport["ms_per_fight"]) < TARGET_MS
	quit(0 if ok else 2)


static func run(parties: Array, with_log: bool) -> Dictionary:
	var n := parties.size()
	var lengths: Array[float] = []
	var wins := [0, 0, 0]
	var reasons := {}
	var sd_fights := 0
	var actions := 0
	var events := 0
	var sim_us := 0
	var per: Array[int] = []
	for i in n:
		var t0 := Time.get_ticks_usec()
		var r := CombatSim.simulate(1000 + i, parties[i][0], parties[i][1], {"log": with_log})
		var dt := Time.get_ticks_usec() - t0   # time the simulation only, not this script's stats
		sim_us += dt
		per.append(dt)
		lengths.append(float(r["duration"]))
		wins[int(r["winner"]) + 1] += 1
		reasons[r["reason"]] = int(reasons.get(r["reason"], 0)) + 1
		if int(r["sudden_death_ticks"]) > 0:
			sd_fights += 1
		for ev: Dictionary in r["events"]:
			events += 1
			if ev["type"] == "action_start":
				actions += 1
	var ms := float(sim_us) / 1000.0 / float(n)
	lengths.sort()
	var buckets := [[0, 10], [10, 12], [12, 15], [15, 20], [20, 25], [25, 30], [30, 35], [35, 40], [40, 45], [45, 60], [60, 999]]
	var lines := PackedStringArray()
	per.sort()
	lines.append("fights: %d   mean %.3f ms/fight (target < %.1f, event log %s)   per-fight median %.3f p95 %.3f ms" % [n, ms, TARGET_MS,
		"on" if with_log else "off", per[n >> 1] / 1000.0, per[int(n * 0.95)] / 1000.0])
	var mean := 0.0
	for l in lengths:
		mean += l
	mean /= float(n)
	lines.append("length s: mean %.1f  p5 %.1f  p25 %.1f  median %.1f  p75 %.1f  p95 %.1f  max %.1f" % [mean,
		lengths[int(n * 0.05)], lengths[int(n * 0.25)], lengths[n >> 1], lengths[int(n * 0.75)], lengths[int(n * 0.95)], lengths[n - 1]])
	var in_band := 0
	for l in lengths:
		if l >= 15.0 and l <= 40.0:
			in_band += 1
	for bk: Array in buckets:
		var c := 0
		for l in lengths:
			if l >= float(bk[0]) and l < float(bk[1]):
				c += 1
		lines.append("  %3d-%-3s s %5.1f%%  %s" % [int(bk[0]), str(bk[1]) if int(bk[1]) < 999 else "", 100.0 * c / n, "#".repeat(roundi(60.0 * c / n))])
	lines.append("in 15-40 s band: %.1f%%   reached sudden death: %.1f%%   outcomes: %s" % [100.0 * in_band / n, 100.0 * sd_fights / n, str(reasons)])
	lines.append("winner A %d / B %d / draw %d   mean actions/fight %.1f   mean events/fight %.1f" % [wins[1], wins[2], wins[0],
		float(actions) / n, float(events) / n])
	return {"text": "\n".join(lines), "ms_per_fight": ms, "in_band": float(in_band) / n,
		"sd_rate": float(sd_fights) / n, "draws": wins[0], "timeouts": int(reasons.get("timeout", 0))}
