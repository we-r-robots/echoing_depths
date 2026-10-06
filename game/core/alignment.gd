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


## The approved advanced class authored for exactly this region of a base ("" if the region has
## no approved class yet).
static func region_class(base_class: String, region: String) -> String:
	var classes: Dictionary = GameData.Classes.CLASSES
	for id: String in classes:
		var c: Dictionary = classes[id]
		if String(c.get("tier", "")) == "advanced" and String(c.get("base", "")) == base_class \
				and String(c.get("region", "")) == region:
			return id
	return ""


const REGIONS := ["N", "LG", "CG", "LE", "CE", "LG*", "CG*", "LE*", "CE*"]


## Every grid cell of a region code.
static func region_cells(region: String) -> Array:
	var out: Array = []
	for g in range(-LIMIT, LIMIT + 1):
		for l in range(-LIMIT, LIMIT + 1):
			if region_of([g, l]) == region:
				out.append([g, l])
	return out


static func _steps_to(pos: Array, region: String) -> int:
	var best := 99
	for c: Array in region_cells(region):
		best = mini(best, absi(int(c[0]) - int(pos[0])) + absi(int(c[1]) - int(pos[1])))
	return best


## Advanced class for a base class at a position: the region's approved class; in a region with no
## approved class yet, the approved class of the nearest region by grid steps from the hero's cell
## (ties: the region nearer the base's start, then data order). PROVISIONAL rule (2026-10-06)
## until the user approves a class for every region; is_fallback() tells the two apart.
static func advanced_class_for(base_class: String, pos: Array) -> String:
	var p := clamp_pos(pos)
	var own := region_class(base_class, region_of(p))
	if own != "":
		return own
	var start := start_for(base_class)
	var best := ""
	var best_d := 99
	var best_s := 99
	for r: String in REGIONS:
		var cid := region_class(base_class, r)
		if cid == "":
			continue
		var d := _steps_to(p, r)
		var ds := _steps_to(start, r)
		if d < best_d or (d == best_d and ds < best_s):
			best = cid
			best_d = d
			best_s = ds
	return best


## True when the position's region has no approved class of its own (the class is a stand-in).
static func is_fallback(base_class: String, pos: Array) -> bool:
	return region_class(base_class, region_of(clamp_pos(pos))) == ""


static func legendary_class_for(advanced_class: String) -> String:
	var classes: Dictionary = GameData.Classes.CLASSES
	for id: String in classes:
		var c: Dictionary = classes[id]
		if String(c.get("tier", "")) == "legendary" and String(c.get("advances_from", "")) == advanced_class:
			return id
	return ""
