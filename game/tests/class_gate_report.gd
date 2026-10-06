extends SceneTree
## Advanced-vs-base gate as a report (tests/test_class_gate.gd runs a smaller sample in the suite).
##   godot --path game --headless -s res://tests/class_gate_report.gd -- [--fights=400]

const Gate = preload("res://tests/test_class_gate.gd")
const GameData = preload("res://core/game_data.gd")


func _init() -> void:
	var n := 400
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fights="):
			n = int(a.trim_prefix("--fights="))
	var m := Gate.measure(n, 7272)
	var rows: Array = []
	for cid: String in m:
		rows.append([cid, m[cid]])
	rows.sort_custom(func(x: Array, y: Array) -> bool:
		return float(x[1]["adv"]) - float(x[1]["base_wins"]) < float(y[1]["adv"]) - float(y[1]["base_wins"]))
	print("| Class | Base | Stat total (adv / base) | Advanced wins | Base wins | Delta |")
	print("|---|---|---|---|---|---|")
	for row: Array in rows:
		var r: Dictionary = row[1]
		var nn := float(r["n"])
		var cd: Dictionary = GameData.get_class_def(String(row[0]))
		var bd: Dictionary = GameData.get_class_def(String(r["base"]))
		print("| %s | %s | %.0f / %.0f | %.1f%% | %.1f%% | %+.1f pp |" % [cd["name"], bd["name"], Gate.stat_total(cd["stats"]),
			Gate.stat_total(bd["stats"]), 100.0 * float(r["adv"]) / nn, 100.0 * float(r["base_wins"]) / nn,
			100.0 * (float(r["adv"]) - float(r["base_wins"])) / nn])
	quit(0)
