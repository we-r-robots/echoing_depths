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


## {"shape": geometric shape, "effective": shape that fights (Strays if locked), "locked": bool}
static func effective(party: Dictionary) -> Dictionary:
	var shape: Dictionary = detect_party(party)
	var sid: String = String(shape["id"])
	var unlocked: Array = unlocked_of(party)
	var locked: bool = sid != "strays" and not unlocked.has(sid)
	var eff: Dictionary = shape
	if locked:
		eff = GameData.Formations.STRAYS
	return {"shape": shape, "effective": eff, "locked": locked}


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
