extends "res://tests/test_case.gd"

const CombatSim = preload("res://core/combat_sim.gd")


func _u(col: int, row: int, hp: int = 100) -> CombatSim.Unit:
	var u := CombatSim.Unit.new()
	u.col = col
	u.row = row
	u.hp = hp
	u.max_hp = 100
	return u


func test_melee_same_row() -> void:
	var foes: Array = [_u(0, 0), _u(0, 1), _u(0, 2), _u(1, 1)]
	eq(CombatSim._nearest_in_col(foes, CombatSim._melee_col(foes), 1), foes[1], "same row in front column")


func test_melee_nearest_row_and_tie() -> void:
	var foes: Array = [_u(0, 0), _u(0, 2), _u(1, 1)]
	eq(CombatSim._nearest_in_col(foes, 0, 3), foes[1], "row 3 attacker -> nearest front row 2")
	eq(CombatSim._nearest_in_col(foes, 0, 1), foes[0], "equidistant rows -> upper row wins")


func test_melee_empty_front_column() -> void:
	var foes: Array = [_u(0, 1), _u(1, 0), _u(1, 3)]
	foes[0].alive = false
	eq(CombatSim._melee_col(foes), 1, "front column empty -> back column")
	eq(CombatSim._nearest_in_col(foes, 1, 2), foes[2], "then nearest back row")


func test_melee_ignores_back_while_front_stands() -> void:
	# A's fighter on row 3; B has front units on rows 0/1 and a back unit on row 3.
	var r := CombatSim.simulate(11, party([hero("fighter", 0, 3), hero("mage", 1, 0)]),
		party([hero("fighter", 0, 0), hero("fighter", 0, 1), hero("mage", 1, 3)]))
	for ev: Dictionary in of_type(r, "action_start"):
		if int(ev["uid"]) == 0:
			var t := unit_stats(r, int(ev["target"]))
			eq(int(t["col"]), 0, "melee targets front column")
			eq(int(t["row"]), 1, "nearest occupied row to row 3")
			return
	check(false, "fighter never acted")


func test_back_first_targets_back_column() -> void:
	var r := CombatSim.simulate(12, duo(hero("mage", 1, 0)), party([hero("fighter", 0, 0), hero("healer", 1, 2)]))
	for ev: Dictionary in of_type(r, "action_start"):
		if int(ev["uid"]) == uid_at(r, 0, 1, 0) and ev["action"] == "bolt":
			eq(int(unit_stats(r, int(ev["target"]))["col"]), 1, "mage bolt snipes the back column")
			return
	check(false, "mage never bolted")


func test_backstab_lowest_hp() -> void:
	# Over several seeds: every Backstab targets the enemy with the lowest current HP,
	# and a Backstab into the back column is halved like every physical hit (spec) but still big
# (x2 power vs back-column targets).
	var backstabs := 0
	var into_back := 0
	for seed_value in 20:
		var r := CombatSim.simulate(seed_value, party([hero("rogue", 0, 0, 6), hero("paladin", 0, 1, 4)]),
			party([hero("hollow_rat", 0, 0, 2), hero("fading_wisp", 1, 2, 2), hero("memory_wraith", 1, 3, 2)]))
		var hp := {}
		var col := {}
		for side: Dictionary in r["events"][0]["sides"]:
			for u: Dictionary in side["units"]:
				hp[int(u["uid"])] = int(u["hp"])
				col[int(u["uid"])] = int(u["col"])
		var pending := false
		for ev: Dictionary in r["events"]:
			match String(ev["type"]):
				"action_start":
					if ev["action"] == "backstab":
						backstabs += 1
						var lowest := 1 << 30
						for uid: int in [2, 3, 4]:
							if int(hp[uid]) > 0:
								lowest = mini(lowest, int(hp[uid]))
						eq(int(hp[int(ev["target"])]), lowest, "backstab picks the lowest-HP enemy")
						pending = true
				"damage":
					if pending and ev["action"] == "backstab" and int(col[int(ev["dst"])]) == 1:
						into_back += 1
						check(not mod(ev, "back_row_target").is_empty() and float(ev["primary"].get("mult", 0.5)) in [0.5, 0.25, 1.5],
							"backstab into the back column is halved and the tag is the true factor")
						check(int(ev["amount"]) >= 30, "a halved backstab is still a big number (%d)" % int(ev["amount"]))
					pending = false
					hp[int(ev["dst"])] = int(ev["hp"])
				"heal":
					hp[int(ev["dst"])] = int(ev["hp"])
	check(backstabs > 0, "rogue backstabbed at least once")
	check(into_back > 0, "at least one backstab hit the back column")


func test_cleave_hits_adjacent_rows() -> void:
	var r := CombatSim.simulate(14, duo(hero("fighter", 0, 1, 4)),
		party([hero("stone_sentinel", 0, 0, 5), hero("stone_sentinel", 0, 1, 5), hero("stone_sentinel", 0, 2, 5), hero("stone_sentinel", 0, 3, 5)]),
		{"tuning": {"start_charge_bonus": 100}})
	var hit := {}
	for d: Dictionary in of_type(r, "damage"):
		if d["action"] == "cleave":
			hit[int(d["dst"])] = true
		elif not hit.is_empty():
			break
	eq(hit.keys().size(), 3, "cleave hits primary + 2 adjacent")
	check(hit.has(2) and hit.has(3) and hit.has(4) and not hit.has(5), "rows 0-2 hit, row 3 untouched")
