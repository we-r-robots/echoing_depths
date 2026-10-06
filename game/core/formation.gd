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


## Formation rules: "parts" (current: every connected part that forms a shape counts, user
## decision 2026-10-06) and "single" (the old rule: the whole side is one shape or nothing; kept so
## Echoes recorded before the change replay identically). party["formation_rule"] picks it.
const RULE_PARTS := "parts"
const RULE_SINGLE := "single"


## The formation of a party (05-formations.md "Every formation part counts", user decision 2026-10-06).
## The placed heroes split into edge-connected parts; every part of 2+ heroes is judged on its own:
##   active          an unlocked shape: it counts as itself (sub_cells = the part's cells)
##   locked_fallback a locked shape: it counts as its LARGEST unlocked connected sub-shape among its
##                   heroes (ties: SHAPES data order, then first subset found); sub_cells = those cells
##   fallback        a part that matches no shape (5+ heroes): the same fallback; shape = UNFORMED
## A part with no unlocked sub-shape does not count. Heroes outside every counting part get nothing.
## -> {"parts": [{"state", "shape": geometric, "effective": what fights, "sub_cells": [[col,row], ...]
##                (the heroes it applies to), "cells": the whole connected part, "locked": bool}, ...]
##                (counting parts only, ordered by their first cell in slot order),
##     plus the top-level keys old callers read ("state", "shape", "effective", "sub_cells", "locked"):
##   none            fewer than 2 units: No formation, parts []
##   strays          no two heroes edge-adjacent: Strays (always unlocked); one part over every hero
##                   (top-level sub_cells stay [] as before)
##   unformed        no part yields any shape: no bonus, no cost, no behaviour, parts []
##   locked_unformed one connected part holding every hero, a locked shape with no unlocked part
##   active / locked_fallback   exactly one counting part and it is the whole side (old meanings)
##   partial         exactly one counting part that leaves some heroes out (top level = that part)
##   parts           2+ counting parts: "shape" / "effective" are a synthetic entry (id "parts", name
##                   e.g. "Kindred + Vigil", no bonus or behaviour of its own); read "parts"
## Cells are taken in slot order (front column top to bottom, then back) so results don't depend
## on the order heroes are listed.
static func effective(party: Dictionary) -> Dictionary:
	var cells: Array = _cells_of(party)
	cells.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) * 10 + int(a[1]) < int(b[0]) * 10 + int(b[1]))
	var unformed: Dictionary = GameData.Formations.UNFORMED
	if cells.size() < 2:
		return _top("none", unformed, unformed, [], false, [])
	var strays: Dictionary = GameData.Formations.STRAYS
	if not _any_adjacent(cells):
		return _top("strays", strays, strays, [], false, [_part("strays", strays, strays, cells, cells, false)])
	var unlocked: Array = unlocked_of(party)
	if String(party.get("formation_rule", RULE_PARTS)) == RULE_SINGLE:
		return _effective_single(cells, unlocked)
	var parts: Array = []
	var groups: Array = _components(cells)
	var lone_locked: Dictionary = {}
	for g: Array in groups:
		if g.size() < 2:
			continue
		var p := _judge(g, unlocked)
		if bool(p["counts"]):
			p.erase("counts")
			parts.append(p)
		elif bool(p["locked"]):
			lone_locked = p
	if parts.is_empty():
		if groups.size() == 1 and not lone_locked.is_empty():
			return _top("locked_unformed", lone_locked["shape"], unformed, [], true, [])
		return _top("unformed", unformed, unformed, [], false, [])
	if parts.size() == 1:
		var p0: Dictionary = parts[0]
		var state := String(p0["state"])
		if (p0["cells"] as Array).size() < cells.size():
			state = "partial"
		return _top(state, p0["shape"], p0["effective"], p0["sub_cells"], bool(p0["locked"]), parts)
	var names: Array = []
	var any_locked := false
	var all_sub: Array = []
	for p: Dictionary in parts:
		names.append(String(p["effective"]["name"]))
		any_locked = any_locked or bool(p["locked"])
		all_sub.append_array(p["sub_cells"])
	var combo := {"id": "parts", "name": " + ".join(names), "size": 0, "cells": [], "bonus": [],
		"behaviour": {}, "cost": {"text": "", "mods": []}}
	return _top("parts", combo, combo, all_sub, any_locked, parts)


## Which part (index into fx["parts"]) a cell's hero fights in, or -1 if it gets nothing.
static func part_of(fx: Dictionary, cell: Array) -> int:
	var parts: Array = fx.get("parts", [])
	for i in parts.size():
		for c: Array in parts[i]["sub_cells"]:
			if int(c[0]) == int(cell[0]) and int(c[1]) == int(cell[1]):
				return i
	return -1


## One connected part of 2+ heroes -> a part dictionary plus "counts" (false: it gives nothing).
static func _judge(g: Array, unlocked: Array) -> Dictionary:
	var shape: Dictionary = detect(g)
	var sid := String(shape["id"])
	if sid != "strays" and unlocked.has(sid):
		var p := _part("active", shape, shape, g, g, false)
		p["counts"] = true
		return p
	var locked := sid != "strays"
	var geo: Dictionary = shape if locked else GameData.Formations.UNFORMED
	var fb: Array = _best_sub(g, unlocked)
	if fb.is_empty():
		var q := _part("locked_unformed" if locked else "unformed", geo, GameData.Formations.UNFORMED, [], g, locked)
		q["counts"] = false
		return q
	var r := _part("locked_fallback" if locked else "fallback", geo, fb[0], fb[1], g, locked)
	r["counts"] = true
	return r


static func _part(state: String, shape: Dictionary, eff: Dictionary, sub: Array, part_cells: Array, locked: bool) -> Dictionary:
	return {"state": state, "shape": shape, "effective": eff, "sub_cells": sub.duplicate(true),
		"cells": part_cells.duplicate(true), "locked": locked}


static func _top(state: String, shape: Dictionary, eff: Dictionary, sub: Array, locked: bool, parts: Array) -> Dictionary:
	return {"state": state, "shape": shape, "effective": eff, "sub_cells": sub.duplicate(true), "locked": locked,
		"parts": parts}


## The largest unlocked connected shape among the proper subsets of `g` (ties: SHAPES data order,
## then the first subset found). -> [shape, cells] or [].
static func _best_sub(g: Array, unlocked: Array) -> Array:
	var best: Dictionary = {}
	var best_cells: Array = []
	for m in range(1, 1 << g.size()):
		var sub: Array = []
		for k in g.size():
			if m & (1 << k):
				sub.append(g[k])
		if sub.size() < 2 or sub.size() >= g.size():
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
		return []
	return [best, best_cells]


## Edge-connected groups of `cells` (each group keeps `cells` order; groups ordered by first cell).
static func _components(cells: Array) -> Array:
	var seen := {}
	var out: Array = []
	for i in cells.size():
		if seen.has(i):
			continue
		var group: Array = []
		var stack: Array = [i]
		seen[i] = true
		while not stack.is_empty():
			var k: int = stack.pop_back()
			group.append(k)
			for j in cells.size():
				if not seen.has(j) and absi(int(cells[k][0]) - int(cells[j][0])) + absi(int(cells[k][1]) - int(cells[j][1])) == 1:
					seen[j] = true
					stack.append(j)
		group.sort()
		var gc: Array = []
		for k: int in group:
			gc.append(cells[k])
		out.append(gc)
	return out


## The old rule (formation_rule "single", Echoes recorded before 2026-10-06): the whole side is one
## shape or nothing; a partly joined side is unformed.
static func _effective_single(cells: Array, unlocked: Array) -> Dictionary:
	var unformed: Dictionary = GameData.Formations.UNFORMED
	var shape: Dictionary = detect(cells)
	if String(shape["id"]) == "strays":
		return _top("unformed", unformed, unformed, [], false, [])
	if unlocked.has(String(shape["id"])):
		return _top("active", shape, shape, cells, false, [_part("active", shape, shape, cells, cells, false)])
	var fb: Array = _best_sub(cells, unlocked)
	if fb.is_empty():
		return _top("locked_unformed", shape, unformed, [], true, [])
	return _top("locked_fallback", shape, fb[0], fb[1], true, [_part("locked_fallback", shape, fb[0], fb[1], cells, true)])


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
