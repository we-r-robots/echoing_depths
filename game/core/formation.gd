extends RefCounted
## Formation shape detection and class-composition buffs.

const GameData = preload("res://core/game_data.gd")


## cells: Array of [col,row]. Returns the matching shape dictionary (or FALLBACK).
## Shapes are compared as bitmasks normalised so the top occupied row is 0 (precomputed once).
static var _masks: Array = []   # [[mask, mirrored_mask_or_-1, shape], ...] in data order


static func detect(cells: Array) -> Dictionary:
	if _masks.is_empty():
		for shape: Dictionary in GameData.Formations.SHAPES:
			var sc: Array = shape["cells"]
			_masks.append([_mask(sc), _mask(_flip(sc)) if bool(shape.get("mirror", false)) else -1, shape])
	var m := _mask(cells)
	for entry: Array in _masks:
		if int(entry[0]) == m or int(entry[1]) == m:
			return entry[2]
	return GameData.Formations.FALLBACK


## Bit (col * 4 + row - top_row) per occupied cell.
static func _mask(cells: Array) -> int:
	var min_row := 99
	for c: Array in cells:
		min_row = mini(min_row, int(c[1]))
	var m := 0
	for c: Array in cells:
		m |= 1 << (int(c[0]) * 4 + int(c[1]) - min_row)
	return m


static func detect_party(party: Dictionary) -> Dictionary:
	var cells: Array = []
	for h: Dictionary in party.get("heroes", []):
		cells.append(h["slot"])
	return detect(cells)


static func _flip(cells: Array) -> Array:
	var max_row := 0
	for c: Array in cells:
		max_row = maxi(max_row, int(c[1]))
	var out: Array = []
	for c: Array in cells:
		out.append([int(c[0]), max_row - int(c[1])])
	return out


## base_ids: base class of every hero on the side (monsters excluded by caller).
## Returns the composition entries whose condition holds, in data order.
static func compositions(base_ids: Array) -> Array:
	var counts := {}
	for b: String in base_ids:
		counts[b] = int(counts.get(b, 0)) + 1
	var out: Array = []
	for comp: Dictionary in GameData.Formations.COMPOSITIONS:
		var w: Dictionary = comp["when"]
		var ok := false
		if w.has("distinct_base_at_least"):
			ok = counts.size() >= int(w["distinct_base_at_least"])
		elif w.has("base"):
			ok = int(counts.get(String(w["base"]), 0)) >= int(w["count_at_least"])
		if ok:
			out.append(comp)
	return out
