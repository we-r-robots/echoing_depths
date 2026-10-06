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


## What the hero's next level adds: compute() at level + 1 minus compute() now, per stat, with only
## the stats that really change (flooring makes a fractional growth give +0 on some levels). Keys in
## GameData.STATS order. {} at the class's max level (a memory there gives no level).
static func level_gain(hero: Dictionary) -> Dictionary:
	var cid := String(hero.get("class", ""))
	var lvl := clampi(int(hero.get("level", 1)), 1, GameData.max_level(cid))
	if lvl >= GameData.max_level(cid):
		return {}
	return gain_between(hero, lvl, lvl + 1)


## compute() at level `to` minus compute() at level `from` for this hero (class and items kept),
## non-zero stats only, in GameData.STATS order.
static func gain_between(hero: Dictionary, from: int, to: int) -> Dictionary:
	var a := hero.duplicate()
	a["level"] = from
	var b := hero.duplicate()
	b["level"] = to
	var sa := compute(a)
	var sb := compute(b)
	var out := {}
	for s: String in GameData.STATS:
		var d := int(sb[s]) - int(sa[s])
		if d != 0:
			out[s] = d
	return out


## A class's real per-level gains over its whole level range (no items): {stat: [lowest, highest]}
## of compute(n + 1) - compute(n) for n = 1 .. max - 1, every stat, GameData.STATS order. A growth
## of 2.5 gives [2, 3]; 0.4 gives [0, 1]. {} for a class with one level.
static func growth_range(class_id: String) -> Dictionary:
	var out := {}
	for n in range(1, GameData.max_level(class_id)):
		var a := compute({"class": class_id, "level": n})
		var b := compute({"class": class_id, "level": n + 1})
		for s: String in GameData.STATS:
			var d := int(b[s]) - int(a[s])
			if not out.has(s):
				out[s] = [d, d]
			else:
				out[s] = [mini(int(out[s][0]), d), maxi(int(out[s][1]), d)]
	return out
