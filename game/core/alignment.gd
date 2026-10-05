extends RefCounted
## Alignment grid helpers. Positions are [good_evil, lawful_chaotic], each -2..+2,
## Good and Lawful positive. Only the Relic slot carries an alignment offset.
## Alignment never affects combat stats; it decides advanced classes.

const GameData = preload("res://core/game_data.gd")
const LIMIT := 2


static func clamp_pos(p: Array) -> Array:
	return [clampi(int(p[0]), -LIMIT, LIMIT), clampi(int(p[1]), -LIMIT, LIMIT)]


## Underlying position after a memory's shift (underlying itself stays on the grid).
static func apply_shift(underlying: Array, shift: Array) -> Array:
	return clamp_pos([int(underlying[0]) + int(shift[0]), int(underlying[1]) + int(shift[1])])


## Relic offset of a hero's equipped relic ([0,0] if none).
static func relic_offset(hero: Dictionary) -> Array:
	var items: Dictionary = hero.get("items", {})
	var rid := String(items.get("relic", ""))
	if rid == "":
		return [0, 0]
	var it := GameData.get_item(rid)
	var off: Array = it.get("alignment", [0, 0])
	return [int(off[0]), int(off[1])]


## Effective position = underlying + relic offset, clamped to +/-2.
static func effective(underlying: Array, offset: Array) -> Array:
	return clamp_pos([int(underlying[0]) + int(offset[0]), int(underlying[1]) + int(offset[1])])


static func effective_for_hero(hero: Dictionary) -> Array:
	return effective(hero.get("alignment", [0, 0]), relic_offset(hero))


## Region code: "N" on the neutral cross, "LG"/"CG"/"LE"/"CE" quadrants,
## with "*" appended on the four corners (e.g. "CE*" at [-2,-2]).
static func region_of(p: Array) -> String:
	var ge := int(p[0])
	var lc := int(p[1])
	if ge == 0 or lc == 0:
		return "N"
	var code := ("L" if lc > 0 else "C") + ("G" if ge > 0 else "E")
	if absi(ge) == LIMIT and absi(lc) == LIMIT:
		code += "*"
	return code


static func start_for(base_class: String) -> Array:
	var c := GameData.get_class_def(base_class)
	var s: Array = c.get("start_alignment", [0, 0])
	return [int(s[0]), int(s[1])]


## Advanced class for a base class at a position. Corners first, then the
## surrounding quadrant. Returns "" if that class has not been authored yet
## (the spec has a class for every cell; only a subset exists in data so far).
static func advanced_class_for(base_class: String, pos: Array) -> String:
	var region := region_of(clamp_pos(pos))
	var fallback_region := region.trim_suffix("*")
	var found := ""
	var classes: Dictionary = GameData.Classes.CLASSES
	for id: String in classes:
		var c: Dictionary = classes[id]
		if String(c.get("tier", "")) != "advanced" or String(c.get("base", "")) != base_class:
			continue
		var r := String(c.get("region", ""))
		if r == region:
			return id
		if r == fallback_region and found == "":
			found = id
	return found


static func legendary_class_for(advanced_class: String) -> String:
	var classes: Dictionary = GameData.Classes.CLASSES
	for id: String in classes:
		var c: Dictionary = classes[id]
		if String(c.get("tier", "")) == "legendary" and String(c.get("advances_from", "")) == advanced_class:
			return id
	return ""
