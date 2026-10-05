extends RefCounted
## Base class for headless tests. Methods named test_* are run by run_all.gd.

var failures: Array[String] = []
var asserts := 0
var current := ""


func check(cond: bool, msg: String) -> void:
	asserts += 1
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	asserts += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: %s (expected %s, got %s)" % [current, msg, var_to_str(expected), var_to_str(actual)])


## Events of one type from a sim result.
static func of_type(result: Dictionary, type: String) -> Array:
	var out: Array = []
	for ev: Dictionary in result["events"]:
		if ev["type"] == type:
			out.append(ev)
	return out


## Modifier entry with this id on a damage event ({} if absent).
static func mod(ev: Dictionary, id: String) -> Dictionary:
	for m: Dictionary in ev["mods"]:
		if String(m["id"]) == id:
			return m
	return {}


static func hero(cls: String, col: int, row: int, level: int = 1, items: Dictionary = {}) -> Dictionary:
	return {"name": cls.capitalize(), "class": cls, "level": level, "items": items, "alignment": [0, 0], "slot": [col, row]}


static func party(heroes: Array) -> Dictionary:
	return {"name": "Test", "heroes": heroes}


## A player side needs 2+ heroes: pad a test hero with a mage in the back corner
## (back row 3), out of the way of front-column melee and row-0 targeting.
static func duo(h: Dictionary) -> Dictionary:
	var f := hero("mage", 1, 3)
	f["name"] = "Filler"
	return party([h, f])


## uid of the unit standing in [col,row] on a side (-1 if none).
static func uid_at(result: Dictionary, side: int, col: int, row: int) -> int:
	for u: Dictionary in result["events"][0]["sides"][side]["units"]:
		if int(u["col"]) == col and int(u["row"]) == row:
			return int(u["uid"])
	return -1


static func unit_stats(result: Dictionary, uid: int) -> Dictionary:
	var fs: Dictionary = result["events"][0]
	for side: Dictionary in fs["sides"]:
		for u: Dictionary in side["units"]:
			if int(u["uid"]) == uid:
				return u
	return {}
