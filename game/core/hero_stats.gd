extends RefCounted
## Pre-combat stats of a hero: class stats at level + equipment.
## Formation and composition modifiers are applied by the combat sim.

const GameData = preload("res://core/game_data.gd")


## Returns {"hp","atk","def","mag","spd"} as ints (min 1).
static func compute(hero: Dictionary) -> Dictionary:
	var c := GameData.get_class_def(String(hero.get("class", "")))
	var lvl := clampi(int(hero.get("level", 1)), 1, GameData.max_level(String(hero.get("class", ""))))
	var base: Dictionary = c.get("stats", {})
	var growth: Dictionary = c.get("growth", {})
	var raw := {}
	for s: String in GameData.STATS:
		raw[s] = float(base.get(s, 0)) + float(growth.get(s, 0)) * float(lvl - 1)
	var items: Dictionary = hero.get("items", {})
	for slot: String in GameData.Items.SLOTS:
		var iid := String(items.get(slot, ""))
		if iid == "":
			continue
		var it := GameData.get_item(iid)
		var st: Dictionary = it.get("stats", {})
		for s: String in st:
			raw[s] = float(raw[s]) + float(st[s])
	var out := {}
	for s: String in GameData.STATS:
		out[s] = maxi(1, floori(float(raw[s])))
	return out
