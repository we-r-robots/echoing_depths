class_name FormationWords
extends RefCounted
## View-model helpers for the formation setup screen: plain-word bonus lines, the growth path
## (which smaller shape a placement grows from, what one more hero grows it into), Training
## Grounds unlock hints, and the mini shape glyph. Geometry and rules come from core
## (core/formation.gd, core/data/formations.gd); nothing here changes them.

const Formation = preload("res://core/formation.gd")
const GameData = preload("res://core/game_data.gd")

const SIZE_WORDS := {2: "Domino", 3: "Tromino", 4: "Tetromino"}
const SCOPE_WORDS := {
	"all": "Everyone", "front": "Front heroes", "back": "Back heroes", "post": "The lone front hero",
	"tip": "The tip", "keeper": "The ringed hero", "flanker": "The flanker", "gap": "The open-end hero",
}
const STAT_WORDS := {
	"hp_pct": "HP", "atk_pct": "Atk", "def_pct": "Def", "mag_pct": "Mag", "spd_pct": "Spd",
	"crit_add": "crit", "charge_pct": "charge", "heal_pct": "healing", "dmg_taken_pct": "damage taken",
}
## Grid role tags drawn on a hero's cell (only the roles a shape gives meaning to).
const ROLE_TAGS := {
	"post": "POST", "tip": "TIP", "keeper": "KEEPER", "flanker": "FLANKER", "gap": "OPEN END",
	"middle": "BRACE",
}
const ROLE_WORDS := {
	"post": "the only wall", "tip": "draws every melee hit", "keeper": "can't be targeted",
	"flanker": "+dmg to its row", "gap": "draws more melee", "middle": "passes hits on",
}


static func shape_by_id(id: String) -> Dictionary:
	if id == "strays":
		return GameData.Formations.STRAYS
	for s: Dictionary in GameData.Formations.SHAPES:
		if String(s["id"]) == id:
			return s
	return {}


## Shape of a set of cells, or {} for fewer than 2 cells (no formation yet).
static func detect(cells: Array) -> Dictionary:
	if cells.size() < 2:
		return {}
	return Formation.detect(cells)


static func is_unlocked(id: String, unlocked: Array) -> bool:
	return id == "strays" or unlocked.has(id)


## UI stand-in for "no formation" (partly joined, not a shape): no bonus, no cost.
const UNFORMED := {"id": "unformed", "name": "No formation", "size": 0, "cells": [], "bonus": [],
	"behaviour": {}, "cost": {"text": "", "mods": []}}


## The formation state of these cells (user decision 2026-10-05, core implements it later):
##   active          a shape, unlocked: it fights as itself
##   strays          no two heroes stand side by side: the Strays formation (always unlocked)
##   unformed        partly joined but not a shape: no bonus, no cost
##   locked_fallback a locked shape: it fights as its largest unlocked smaller shape inside it
##   locked_unformed a locked shape with no unlocked part inside: no formation
## Returns {"shape": geometric shape (or STRAYS / UNFORMED), "effective": what fights,
##          "sub_cells": cells of the effective shape ([] for strays / unformed), "state": ...,
##          "locked": bool (the geometric shape is a locked shape)}; {} shape for < 2 cells.
## LOCAL STUB of the coming core Formation.effective(party) with the same return value.
static func evaluate(cells: Array, unlocked: Array) -> Dictionary:
	if cells.size() < 2:
		return {"shape": {}, "effective": {}, "sub_cells": [], "state": "none", "locked": false}
	var strays: Dictionary = GameData.Formations.STRAYS
	if not _any_adjacent(cells):
		return {"shape": strays, "effective": strays, "sub_cells": [], "state": "strays", "locked": false}
	var shape := Formation.detect(cells)
	if String(shape["id"]) == "strays":
		return {"shape": UNFORMED, "effective": UNFORMED, "sub_cells": [], "state": "unformed", "locked": false}
	if is_unlocked(String(shape["id"]), unlocked):
		return {"shape": shape, "effective": shape, "sub_cells": cells.duplicate(true), "state": "active", "locked": false}
	var best := {}
	var best_cells: Array = []
	for sub: Array in _subsets(cells):
		if sub.size() < 2 or sub.size() >= cells.size():
			continue
		var s := Formation.detect(sub)
		var sid := String(s["id"])
		if sid == "strays" or not is_unlocked(sid, unlocked):
			continue
		if best.is_empty() or int(s["size"]) > int(best["size"]) or \
				(int(s["size"]) == int(best["size"]) and _data_index(sid) < _data_index(String(best["id"]))):
			best = s
			best_cells = sub
	if best.is_empty():
		return {"shape": shape, "effective": UNFORMED, "sub_cells": [], "state": "locked_unformed", "locked": true}
	return {"shape": shape, "effective": best, "sub_cells": best_cells, "state": "locked_fallback", "locked": true}


static func _any_adjacent(cells: Array) -> bool:
	for a: Array in cells:
		for b: Array in cells:
			if absi(int(a[0]) - int(b[0])) + absi(int(a[1]) - int(b[1])) == 1:
				return true
	return false


static func _subsets(cells: Array) -> Array:
	var out: Array = []
	for m in range(1, 1 << cells.size()):
		var sub: Array = []
		for k in cells.size():
			if m & (1 << k):
				sub.append(cells[k])
		out.append(sub)
	return out


static func _data_index(id: String) -> int:
	var shapes: Array = GameData.Formations.SHAPES
	for i in shapes.size():
		if String(shapes[i]["id"]) == id:
			return i
	return 999


## Bonus mods as plain-word lines: "Front heroes: Def +45%". Same scope and value are merged:
## "Everyone: HP, Atk, Def, Mag, Spd +5%".
static func mod_lines(mods: Array) -> Array:
	var groups: Array = []   # [scope, value, [stats]]
	for m: Dictionary in mods:
		var found := false
		for g: Array in groups:
			if g[0] == m["scope"] and is_equal_approx(float(g[1]), float(m["value"])):
				(g[2] as Array).append(String(m["stat"]))
				found = true
		if not found:
			groups.append([String(m["scope"]), float(m["value"]), [String(m["stat"])]])
	var out: Array = []
	# merge scopes with the same value list into one line where the stats differ ("Back heroes: Mag, healing +10%")
	for g: Array in groups:
		var names: Array = []
		for s: String in g[2]:
			names.append(STAT_WORDS.get(s, s))
		var pct := roundi(float(g[1]) * 100.0)
		out.append("%s: %s %+d%%" % [SCOPE_WORDS.get(g[0], String(g[0]).capitalize()), ", ".join(names), pct])
	return out


## Every shape the cells grow from: remove one hero and the rest still form a shape.
static func parents(cells: Array) -> Array:
	var out: Array = []
	if cells.size() < 3:
		return out
	for i in cells.size():
		var rest := cells.duplicate()
		rest.remove_at(i)
		var s := Formation.detect(rest)
		if String(s["id"]) != "strays" and not _has(out, String(s["id"])):
			out.append(s)
	return out


## What one more hero grows these cells into: [{"shape", "cell"}] per distinct shape, using only
## free in-grid cells edge-adjacent to the placement (so every option is really placeable).
static func children(cells: Array) -> Array:
	var out: Array = []
	if cells.size() < 2 or cells.size() >= 4:
		return out
	var cur := Formation.detect(cells)
	if String(cur["id"]) == "strays":
		return out
	for c: Array in growth_cells(cells):
		var s := Formation.detect(cells + [c])
		if String(s["id"]) == "strays":
			continue
		if not _has_entry(out, String(s["id"])):
			out.append({"shape": s, "cell": c})
	return out


## Free cells edge-adjacent to any placed cell, in reading order (row, then front before back).
static func growth_cells(cells: Array) -> Array:
	var out: Array = []
	for row in 4:
		for col in 2:
			var c := [col, row]
			if _cell_in(cells, c):
				continue
			for o: Array in cells:
				if absi(int(o[0]) - col) + absi(int(o[1]) - row) == 1:
					out.append(c)
					break
	return out


## Unlock hint for a locked shape: "Unlock with Shards at the Training Grounds, after Keystone."
static func unlock_hint(id: String, unlocked: Array) -> String:
	var after: Array = []
	var tree: Dictionary = GameData.Formations.UNLOCK_TREE
	for p: String in tree:
		if (tree[p] as Array).has(id):
			var nm := String(shape_by_id(p).get("name", p))
			after.append(nm + ("" if unlocked.has(p) else " (locked)"))
	if after.is_empty():
		return "Unlock with Shards at the Training Grounds."
	return "Unlock with Shards at the Training Grounds, after %s." % " or ".join(after)


static func size_word(shape: Dictionary) -> String:
	return String(SIZE_WORDS.get(int(shape.get("size", 0)), ""))


static func _has(arr: Array, id: String) -> bool:
	for s: Dictionary in arr:
		if String(s["id"]) == id:
			return true
	return false


static func _has_entry(arr: Array, id: String) -> bool:
	for e: Dictionary in arr:
		if String(e["shape"]["id"]) == id:
			return true
	return false


static func _cell_in(cells: Array, c: Array) -> bool:
	for o: Array in cells:
		if int(o[0]) == int(c[0]) and int(o[1]) == int(c[1]):
			return true
	return false


## Mini glyph of a shape (or of explicit cells): a 2-column grid, back column on the LEFT and
## front on the RIGHT (the battle's facing: the foe is to the right). `px` = cell size, 1 px gap.
## rows = how many grid rows to draw (the shape's own height by default, 4 for a full board).
static func draw_glyph(ci: CanvasItem, pos: Vector2, cells: Array, px: int, fill: Color,
		empty := Pal.INK3, rows := 0, frame := true, hi := Color(0, 0, 0, 0)) -> Vector2:
	var min_row := 0
	var h := rows
	if rows <= 0:
		min_row = 99
		var max_row := 0
		for c: Array in cells:
			min_row = mini(min_row, int(c[1]))
			max_row = maxi(max_row, int(c[1]))
		if cells.is_empty():
			min_row = 0
		h = maxi(1, max_row - min_row + 1)
	var w := 2 * px + 1
	var hh := h * px + (h - 1)
	if frame:
		ci.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, hh + 2)), Pal.INK1)
	for row in h:
		for col in 2:
			var x := pos.x + (1 - col) * (px + 1)   # col 0 (front) drawn on the right
			var y := pos.y + row * (px + 1)
			var on := _cell_in(cells, [col, row + min_row])
			ci.draw_rect(Rect2(x, y, px, px), fill if on else empty)
			if on and hi.a > 0.0 and px >= 4:
				ci.draw_rect(Rect2(x, y, px, 1), hi)
	return Vector2(w, hh)


## Glyph of a shape's canonical cells.
static func draw_shape_glyph(ci: CanvasItem, pos: Vector2, shape: Dictionary, px: int, fill: Color,
		empty := Pal.INK3, hi := Color(0, 0, 0, 0)) -> Vector2:
	return draw_glyph(ci, pos, shape.get("cells", []), px, fill, empty, 0, true, hi)
