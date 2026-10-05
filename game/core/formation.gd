extends RefCounted
## Formation shape detection (dominoes, trominoes, tetrominoes; spec 05-formations.md),
## Training Grounds unlocks, per-unit roles, and class-composition buffs.

const GameData = preload("res://core/game_data.gd")

## [[mask, mirrored_mask_or_-1, shape], ...] in data order, precomputed once.
static var _masks: Array = []


## cells: Array of [col,row]. Returns the matching shape (geometry only, ignores unlocks) or STRAYS.
## Shapes match at any height; mirrored top/bottom variants count as the same shape; front/back
## orientation matters. Non-connected placements (and 5+ units) are Strays.
static func detect(cells: Array) -> Dictionary:
	if _masks.is_empty():
		for shape: Dictionary in GameData.Formations.SHAPES:
			var sc: Array = shape["cells"]
			_masks.append([_mask(sc), _mask(_flip(sc)) if bool(shape.get("mirror", false)) else -1, shape])
	var m := _mask(cells)
	for entry: Array in _masks:
		if int(entry[0]) == m or int(entry[1]) == m:
			return entry[2]
	return GameData.Formations.STRAYS


## Bit (col * 4 + row - top_row) per occupied cell.
static func _mask(cells: Array) -> int:
	var min_row := 99
	for c: Array in cells:
		min_row = mini(min_row, int(c[1]))
	var m := 0
	for c: Array in cells:
		m |= 1 << (int(c[0]) * 4 + int(c[1]) - min_row)
	return m


static func _flip(cells: Array) -> Array:
	var max_row := 0
	for c: Array in cells:
		max_row = maxi(max_row, int(c[1]))
	var out: Array = []
	for c: Array in cells:
		out.append([int(c[0]), max_row - int(c[1])])
	return out


static func _cells_of(party: Dictionary) -> Array:
	var cells: Array = []
	for h: Dictionary in party.get("heroes", []):
		cells.append([int(h["slot"][0]), int(h["slot"][1])])
	return cells


## Geometric shape of a party (what the player arranged), ignoring unlocks.
static func detect_party(party: Dictionary) -> Dictionary:
	return detect(_cells_of(party))


## The side's unlocked shape ids: party["unlocked_formations"] if present, else the default set.
static func unlocked_of(party: Dictionary) -> Array:
	var u: Variant = party.get("unlocked_formations", null)
	if u is Array:
		return u
	return GameData.Formations.DEFAULT_UNLOCKED


## The formation state of a party (05-formations.md, user decision 2026-10-05):
##   active          an unlocked shape: it fights as itself (sub_cells = all cells)
##   strays          no two heroes edge-adjacent: the Strays formation (always unlocked)
##   unformed        partly joined but no shape: no bonus, no cost, no behaviour
##   locked_fallback a locked shape: it fights as its LARGEST unlocked connected sub-shape among
##                   the placed heroes (ties: SHAPES data order, then first subset found), applied
##                   to those heroes' cells (sub_cells)
##   locked_unformed a locked shape with no unlocked part: no formation
## -> {"state", "shape": geometric (a SHAPES entry, STRAYS or UNFORMED), "effective": what fights,
##     "sub_cells": [[col,row], ...] (all cells when active, the sub-shape's cells when
##     locked_fallback, [] otherwise), "locked": bool}
## Cells are taken in slot order (front column top to bottom, then back) so results don't depend
## on the order heroes are listed. Fewer than 2 units: state "none", No formation.
static func effective(party: Dictionary) -> Dictionary:
	var cells: Array = _cells_of(party)
	cells.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) * 10 + int(a[1]) < int(b[0]) * 10 + int(b[1]))
	var unformed: Dictionary = GameData.Formations.UNFORMED
	if cells.size() < 2:
		return {"state": "none", "shape": unformed, "effective": unformed, "sub_cells": [], "locked": false}
	var strays: Dictionary = GameData.Formations.STRAYS
	if not _any_adjacent(cells):
		return {"state": "strays", "shape": strays, "effective": strays, "sub_cells": [], "locked": false}
	var shape: Dictionary = detect(cells)
	if String(shape["id"]) == "strays":
		return {"state": "unformed", "shape": unformed, "effective": unformed, "sub_cells": [], "locked": false}
	var unlocked: Array = unlocked_of(party)
	if unlocked.has(String(shape["id"])):
		return {"state": "active", "shape": shape, "effective": shape, "sub_cells": cells.duplicate(true), "locked": false}
	var best: Dictionary = {}
	var best_cells: Array = []
	for m in range(1, 1 << cells.size()):
		var sub: Array = []
		for k in cells.size():
			if m & (1 << k):
				sub.append(cells[k])
		if sub.size() < 2 or sub.size() >= cells.size():
			continue
		var sh: Dictionary = detect(sub)
		var sid: String = String(sh["id"])
		if sid == "strays" or not unlocked.has(sid):
			continue
		if best.is_empty() or int(sh["size"]) > int(best["size"]) or \
				(int(sh["size"]) == int(best["size"]) and _data_index(sid) < _data_index(String(best["id"]))):
			best = sh
			best_cells = sub
	if best.is_empty():
		return {"state": "locked_unformed", "shape": shape, "effective": unformed, "sub_cells": [], "locked": true}
	return {"state": "locked_fallback", "shape": shape, "effective": best, "sub_cells": best_cells, "locked": true}


static func _any_adjacent(cells: Array) -> bool:
	for a: Array in cells:
		for b: Array in cells:
			if absi(int(a[0]) - int(b[0])) + absi(int(a[1]) - int(b[1])) == 1:
				return true
	return false


static func _data_index(id: String) -> int:
	var shapes: Array = GameData.Formations.SHAPES
	for i in shapes.size():
		if String(shapes[i]["id"]) == id:
			return i
	return 999


## Roles of each cell in an (effective) shape, same order as `cells`. Always "front"/"back";
## plus "post" (lone front of Hearth / Lighthouse), "tip" (Shardpoint front), "keeper" (Keeper's
## Ring back), "flanker" (back of Keystone / Crescent), "gap" (front unit of Keystone / Crescent
## farthest from the flanker: it draws melee), "middle" (Tidebreak middle front).
static func roles(shape_id: String, cells: Array) -> Array:
	var out: Array = []
	var back_row := -1
	var front_rows: Array = []
	for c: Array in cells:
		if int(c[0]) == 1:
			back_row = int(c[1])
		else:
			front_rows.append(int(c[1]))
	var far_row := -1
	var far_d := -1
	for r: int in front_rows:
		if absi(r - back_row) > far_d:
			far_d = absi(r - back_row)
			far_row = r
	for c: Array in cells:
		var col := int(c[0])
		var row := int(c[1])
		var r: Array = ["front" if col == 0 else "back"]
		match shape_id:
			"hearth", "lighthouse":
				if col == 0:
					r.append("post")
			"shardpoint":
				if col == 0:
					r.append("tip")
			"keepers_ring":
				if col == 1:
					r.append("keeper")
			"keystone", "crescent":
				if col == 1:
					r.append("flanker")
				elif row == far_row:
					r.append("gap")
			"tidebreak":
				if col == 0 and front_rows.has(row - 1) and front_rows.has(row + 1):
					r.append("middle")
		out.append(r)
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
