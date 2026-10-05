extends RefCounted
## Read-only access to combat data tables plus party validation.
## Usage: const GameData = preload("res://core/game_data.gd")

const Tuning = preload("res://core/data/tuning.gd")
const Classes = preload("res://core/data/classes.gd")
const Actions = preload("res://core/data/abilities.gd")
const Items = preload("res://core/data/items.gd")
const Formations = preload("res://core/data/formations.gd")
const Memories = preload("res://core/data/memories.gd")

const STATS := ["hp", "atk", "def", "mag", "spd"]
const MAX_PARTY_HEROES := 4      # player parties / Echoes
const MIN_PARTY_HEROES := 2      # parties start with two heroes (spec)
const MAX_SIDE_UNITS := 8        # monster sides may fill every slot
const MAX_HERO_NAME := 24
static var _shape_ids := {}
const COLS := 2
const ROWS := 4


static func has_class(id: String) -> bool:
	return Classes.CLASSES.has(id)


static func get_class_def(id: String) -> Dictionary:
	var c: Dictionary = Classes.CLASSES.get(id, {})
	if c.is_empty():
		return Memories.MEMORIES.get(id, {})   # Crystal memories use the class schema
	return c


static func get_action(id: String) -> Dictionary:
	return Actions.ACTIONS.get(id, {})


static func get_item(id: String) -> Dictionary:
	return Items.ITEMS.get(id, {})


static func combat() -> Dictionary:
	return Tuning.COMBAT


static func max_level(class_id: String) -> int:
	var c := get_class_def(class_id)
	return int(Tuning.MAX_LEVEL.get(String(c.get("tier", "base")), 1))


## True for an int, or a float holding a whole number in int range (JSON numbers are floats).
static func is_whole(v: Variant) -> bool:
	if v is int:
		return true
	if v is float:
		var f := float(v)
		return is_finite(f) and f == floorf(f) and absf(f) < 1.0e15
	return false


## Side kind: "monster" if every unit is a monster, otherwise "player".
static func side_kind(party: Dictionary) -> String:
	var heroes: Variant = party.get("heroes", [])
	if not (heroes is Array) or (heroes as Array).is_empty():
		return "player"
	for h: Variant in heroes:
		if not (h is Dictionary):
			return "player"
		var cid: Variant = (h as Dictionary).get("class", "")
		if not (cid is String) or String(get_class_def(String(cid)).get("tier", "")) != "monster":
			return "player"
	return "monster"


## Returns a list of human-readable problems; empty means valid. Never errors on bad types.
## kind: "auto" (monster side if every unit is a monster, else player), "player" or "monster".
## Player sides (and Echoes): 2-4 heroes, no monster classes, at most
## Tuning.MAX_LEGENDARY_PER_PARTY Legendaries. Monster sides: 1-8 monsters.
static func validate_party(party: Variant, kind: String = "auto") -> Array[String]:
	var errs: Array[String] = []
	if not (party is Dictionary):
		errs.append("party is not a Dictionary")
		return errs
	var pd: Dictionary = party
	if not pd.has("heroes") or not (pd["heroes"] is Array):
		errs.append("party has no 'heroes' array")
		return errs
	if kind == "auto":
		kind = side_kind(pd)
	var heroes: Array = pd["heroes"]
	var max_heroes := MAX_SIDE_UNITS if kind == "monster" else MAX_PARTY_HEROES
	if heroes.is_empty():
		errs.append("party is empty")
	elif kind == "player" and heroes.size() < MIN_PARTY_HEROES:
		errs.append("player side has %d hero (min %d)" % [heroes.size(), MIN_PARTY_HEROES])
	if heroes.size() > max_heroes:
		errs.append("%s side has %d units (max %d)" % [kind, heroes.size(), max_heroes])
	if pd.has("name") and not (pd["name"] is String):
		errs.append("party name is not a String")
	var used := {}
	var legendaries := 0
	for i in heroes.size():
		var h: Variant = heroes[i]
		if not (h is Dictionary):
			errs.append("hero %d is not a Dictionary" % i)
			continue
		var hd: Dictionary = h
		var cv: Variant = hd.get("class", null)
		if not (cv is String) or not has_class(String(cv)):
			errs.append("hero %d has unknown class %s" % [i, var_to_str(cv)])
			continue
		var cid := String(cv)
		var tier := String(get_class_def(cid)["tier"])
		if kind == "player" and (tier == "monster" or tier == "memory"):
			errs.append("hero %d: monster class '%s' on a player side" % [i, cid])
		if kind == "monster" and tier != "monster":
			errs.append("hero %d: hero class '%s' on a monster side" % [i, cid])
		if tier == "legendary":
			legendaries += 1
		if hd.has("name") and (not (hd["name"] is String) or String(hd["name"]).length() > MAX_HERO_NAME):
			errs.append("hero %d name must be a String of at most %d characters" % [i, MAX_HERO_NAME])
		var lv: Variant = hd.get("level", 1)
		if not is_whole(lv):
			errs.append("hero %d level %s is not a whole number" % [i, var_to_str(lv)])
		elif int(lv) < 1 or int(lv) > max_level(cid):
			errs.append("hero %d level %d out of range 1..%d" % [i, int(lv), max_level(cid)])
		var slot: Variant = hd.get("slot", null)
		if not (slot is Array) or (slot as Array).size() != 2 or not is_whole(slot[0]) or not is_whole(slot[1]):
			errs.append("hero %d needs a whole-number [col,row] slot" % i)
		else:
			var col := int(slot[0])
			var row := int(slot[1])
			if col < 0 or col >= COLS or row < 0 or row >= ROWS:
				errs.append("hero %d slot [%d,%d] off the grid" % [i, col, row])
			var key := col * ROWS + row
			if used.has(key):
				errs.append("hero %d shares slot [%d,%d]" % [i, col, row])
			used[key] = true
		var al: Variant = hd.get("alignment", [0, 0])
		if not (al is Array) or (al as Array).size() != 2 or not is_whole(al[0]) or not is_whole(al[1]) \
				or absi(int(al[0])) > 2 or absi(int(al[1])) > 2:
			errs.append("hero %d alignment must be two whole numbers in -2..2" % i)
		var items: Variant = hd.get("items", {})
		if items == null:
			items = {}
		if not (items is Dictionary):
			errs.append("hero %d items is not a Dictionary" % i)
			continue
		var idict: Dictionary = items
		for slot_name: Variant in idict:
			if not (slot_name is String) or not Items.SLOTS.has(String(slot_name)):
				errs.append("hero %d has unknown item slot %s" % [i, var_to_str(slot_name)])
				continue
			var iv: Variant = idict[slot_name]
			if iv == null or (iv is String and String(iv) == ""):
				continue
			if not (iv is String):
				errs.append("hero %d item in %s is not a String" % [i, slot_name])
				continue
			var it := get_item(String(iv))
			if it.is_empty():
				errs.append("hero %d has unknown item '%s'" % [i, iv])
			elif String(it["slot"]) != String(slot_name):
				errs.append("hero %d item '%s' is not a %s" % [i, iv, slot_name])
	if pd.has("unlocked_formations"):
		var uf: Variant = pd["unlocked_formations"]
		if _shape_ids.is_empty():
			for sh: Dictionary in Formations.SHAPES:
				_shape_ids[sh["id"]] = true
		var known := _shape_ids
		if not (uf is Array) or (uf as Array).size() > known.size():
			errs.append("unlocked_formations must be an Array of shape ids")
		else:
			for f: Variant in uf:
				if not (f is String) or not known.has(String(f)):
					errs.append("unknown formation in unlocked_formations: %s" % var_to_str(f))
	if kind == "player" and legendaries > int(Tuning.MAX_LEGENDARY_PER_PARTY):
		errs.append("party has %d Legendary heroes (max %d)" % [legendaries, Tuning.MAX_LEGENDARY_PER_PARTY])
	return errs
