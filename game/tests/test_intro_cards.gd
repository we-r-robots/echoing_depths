extends "res://tests/test_case.gd"
## Battle intro cards (BUILD.md: title, stat chips with ▲/▼, a behaviour glyph with a short label).
## Critic r6: one card read "Oren +40%" twice (heal and charge) and showed two chips with no label.
## Every chip keeps a label of 20 characters or fewer, no two chips on a card share a label, and
## every row fits the card.

const BATTLE = preload("res://scenes/battle/battle.tscn")


func _cards(fight: String) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var old := tree.root.size
	tree.root.size = Vector2i(1920, 1080)
	var b: Node = BATTLE.instantiate()
	b.autoplay_demo = false
	b.demo_fight = fight
	tree.root.add_child(b)
	b._start_demo()
	b.hud._build_intro()
	var out: Array = []
	for side in 2:
		var rows: Array = []
		for row: Array in b.hud._intro_rows[side]:
			var r: Array = []
			for it: Array in row:
				r.append([String((it[0] as Dictionary)["title"]), float(it[1])])
			rows.append([r, b.hud._row_w(row)])
		out.append(rows)
	var inner: float = b.hud.INTRO_W - 24.0
	tree.root.remove_child(b)
	b.free()
	tree.root.size = old
	return [out, inner]


func test_every_intro_chip_is_labelled_once() -> void:
	var n := 0
	for fight: String in ["pvp", "monsters", "crystal"]:
		var res := _cards(fight)
		var inner: float = res[1]
		for side in 2:
			var seen := {}
			for row: Array in res[0][side]:
				check(float(row[1]) <= inner + 0.5, "%s side %d: a chip row (%.0f px) fits the card (%.0f px)" % [fight, side, row[1], inner])
				for it: Array in row[0]:
					n += 1
					var t: String = it[0]
					check(float(it[1]) > 0.0 and t != "", "%s side %d: chip \"%s\" shows its label" % [fight, side, t])
					check(t.length() <= 20, "%s side %d: chip label \"%s\" is 20 characters or fewer" % [fight, side, t])
					check(not seen.has(t), "%s side %d: chip label \"%s\" is not repeated on the card" % [fight, side, t])
					seen[t] = true
	check(n >= 6, "intro chips were checked (%d)" % n)
