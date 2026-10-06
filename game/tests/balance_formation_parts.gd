extends SceneTree
## Balance check for "every formation part counts" (05-formations.md, user decision 2026-10-06):
## the SAME four heroes placed as two separate pairs vs as one 4-hero shape.
##   godot --path game --headless -s res://tests/balance_formation_parts.gd -- [--trials=200] [--seed=1]
## Per trial: 4 random heroes (PartyGen classes, levels, items) and one random 4-hero opponent
## (random shape, everything unlocked). Each layout places the heroes by preferred column (front
## cells to front-preferring heroes first) and fights the opponent with SEEDS seeds on each side.
## Reports the win rate per layout, best split vs best 4-shape per trial, and a head-to-head of the
## same heroes split vs as their best 4-shape. Writes nothing (no save files touched).

const CombatSim = preload("res://core/combat_sim.gd")
const GameData = preload("res://core/game_data.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Formation = preload("res://core/formation.gd")
const Rng = preload("res://core/rng.gd")

const SEEDS := 2   # per side (4 fights per layout per trial)
const SPLITS := {
	"Kindred+Vigil (F0F1|B2B3)": [[0, 0], [0, 1], [1, 2], [1, 3]],
	"Vigil+Kindred (B0B1|F2F3)": [[1, 0], [1, 1], [0, 2], [0, 3]],
	"Lamplight x2 (row 0|row 2)": [[0, 0], [1, 0], [0, 2], [1, 2]],
	"Lamplight x2 (row 0|row 3)": [[0, 0], [1, 0], [0, 3], [1, 3]],
	"Kindred+Lamplight (F0F1|row 3)": [[0, 0], [0, 1], [0, 3], [1, 3]],
	"Vigil+Lamplight (B0B1|row 3)": [[1, 0], [1, 1], [0, 3], [1, 3]],
}


func _init() -> void:
	var trials := 200
	var seed0 := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trials="):
			trials = int(a.trim_prefix("--trials="))
		elif a.begins_with("--seed="):
			seed0 = int(a.trim_prefix("--seed="))
	var t0 := Time.get_ticks_msec()
	var layouts := {}
	for k: String in SPLITS:
		layouts["split: " + k] = SPLITS[k]
	for sh: Dictionary in GameData.Formations.SHAPES:
		if int(sh["size"]) == 4:
			layouts["shape: " + String(sh["name"])] = sh["cells"]
	var wins := {}
	for k: String in layouts:
		wins[k] = 0
	wins["old rule: Kindred+Vigil (Unformed)"] = 0
	var per := 4 * SEEDS
	var split_better := 0
	var shape_better := 0
	var ties := 0
	var best_split_sum := 0.0
	var best_shape_sum := 0.0
	var h2h_split := 0
	var h2h_n := 0
	var best_split_names := {}
	var rng := Rng.new(seed0)
	for t in trials:
		var base := PartyGen.random_party(rng, {"size": 4})
		var opp := PartyGen.random_party(rng, {"size": 4})
		var best_split := -1
		var best_split_k := ""
		var best_shape := -1
		var best_shape_k := ""
		for k: String in layouts:
			var p := _placed(base, layouts[k])
			var w := _wins(p, opp, t)
			wins[k] = int(wins[k]) + w
			if k.begins_with("split") and w > best_split:
				best_split = w
				best_split_k = k
			elif k.begins_with("shape") and w > best_shape:
				best_shape = w
				best_shape_k = k
		var old := _placed(base, SPLITS["Kindred+Vigil (F0F1|B2B3)"])
		old["formation_rule"] = "single"
		wins["old rule: Kindred+Vigil (Unformed)"] = int(wins["old rule: Kindred+Vigil (Unformed)"]) + _wins(old, opp, t)
		best_split_sum += float(best_split) / per
		best_shape_sum += float(best_shape) / per
		best_split_names[best_split_k] = int(best_split_names.get(best_split_k, 0)) + 1
		if best_split > best_shape:
			split_better += 1
		elif best_shape > best_split:
			shape_better += 1
		else:
			ties += 1
		# head-to-head: the same heroes, best split vs best 4-shape
		var ps := _placed(base, layouts[best_split_k])
		ps["name"] = "Split"
		var pf := _placed(base, layouts[best_shape_k])
		pf["name"] = "Shape"
		h2h_split += _wins(ps, pf, 7000 + t)
		h2h_n += per
	var keys: Array = wins.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(wins[a]) > int(wins[b]))
	print("Formation parts balance: %d trials, %d fights per layout per trial (%d ms)" % [trials, per, Time.get_ticks_msec() - t0])
	print("Win rate vs the same random 4-hero opponents (same heroes every layout):")
	for k: String in keys:
		print("  %5.1f%%  %s" % [100.0 * int(wins[k]) / (trials * per), k])
	print("Per trial, best of the 6 split layouts vs best of the 8 4-shapes:")
	print("  mean win rate: best split %.1f%%, best 4-shape %.1f%%" % [100.0 * best_split_sum / trials, 100.0 * best_shape_sum / trials])
	print("  split strictly better in %d trials, 4-shape better in %d, tied %d" % [split_better, shape_better, ties])
	print("  best split layout counts: %s" % str(best_split_names))
	print("Head-to-head, same heroes, best split vs best 4-shape: split wins %.1f%% (%d fights)" % [100.0 * h2h_split / h2h_n, h2h_n])
	quit()


## A copy of `base` with its heroes placed on `cells`: front cells go to front-preferring heroes
## first, back cells to back-preferring ones; the rest fill the leftovers in hero order.
static func _placed(base: Dictionary, cells: Array) -> Dictionary:
	var p := base.duplicate(true)
	var front: Array = []
	var back: Array = []
	for c: Array in cells:
		(front if int(c[0]) == 0 else back).append(c)
	var heroes: Array = p["heroes"]
	var left: Array = []
	for h: Dictionary in heroes:
		var pref := int(GameData.get_class_def(String(h["class"]))["preferred_col"])
		var mine: Array = front if pref == 0 else back
		if not mine.is_empty():
			h["slot"] = mine.pop_front()
		else:
			left.append(h)
	for h: Dictionary in left:
		h["slot"] = front.pop_front() if not front.is_empty() else back.pop_front()
	return p


## Wins of `a` against `b` over SEEDS seeds with a on side 0 and SEEDS with a on side 1.
static func _wins(a: Dictionary, b: Dictionary, t: int) -> int:
	var w := 0
	for s in SEEDS:
		var sd := t * 100 + s
		if int(CombatSim.simulate(sd, a, b, {"log": false})["winner"]) == 0:
			w += 1
		if int(CombatSim.simulate(sd + 50, b, a, {"log": false})["winner"]) == 1:
			w += 1
	return w
