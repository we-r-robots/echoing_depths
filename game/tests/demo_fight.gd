extends SceneTree
## Prints a human-readable log of one demo fight.
## godot --path game --headless -s res://tests/demo_fight.gd [-- --seed=N --random --monsters=DEPTH --crystal[=id,id,id,id]]

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Narrator = preload("res://core/narrator.gd")
const Rng = preload("res://core/rng.gd")


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var seed_value := int(args.get("seed", "7"))
	var a := PartyGen.demo_party()
	var b := PartyGen.demo_rival()
	if args.has("random"):
		var rng := Rng.new(seed_value)
		a = PartyGen.random_party(rng)
		b = PartyGen.random_party(rng)
	elif args.has("monsters"):
		b = PartyGen.monster_group(Rng.new(seed_value), int(args["monsters"]))
	var r := CombatSim.simulate(seed_value, a, b)
	if args.has("crystal"):
		var mems: Array = String(args["crystal"]).split(",") if String(args["crystal"]) != "true" else []
		var copt := {} if mems.is_empty() else {"memories": mems}
		r = CombatSim.simulate_crystal(seed_value, PartyGen.random_party(Rng.new(seed_value), {"advanced_chance": 0.6}), copt)
	if r.has("error"):
		printerr(r["error"])
		quit(1)
		return
	for line in Narrator.narrate(r["events"]):
		print(line)
	var actions := 0
	for ev: Dictionary in r["events"]:
		if ev["type"] == "action_start":
			actions += 1
	print("-- %d actions in %.2fs (%.2f actions/s), %d events, seed %d" % [actions, float(r["duration"]),
		actions / maxf(0.001, float(r["duration"])), (r["events"] as Array).size(), seed_value])
	quit(0)
