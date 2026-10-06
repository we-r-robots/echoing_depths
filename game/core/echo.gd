extends RefCounted
## Echo snapshots: a party frozen to a plain Dictionary / JSON string and back.
## An Echo is also a valid party for CombatSim.simulate() (it has "heroes").
##
## Echo v2 (v1 Echoes still load: they get the default unlocked set):
## {
##   "format": "echoing_depths.echo", "version": 1, "data_version": <int>,
##   "name": String (<= 32 chars), "meta": Dictionary (free-form: owner, banner, depth...; <= 2048 chars as JSON),
##   "unlocked_formations": [String, ...],  # v2: Training Grounds shapes unlocked when recorded
##   "heroes": [ {"name": String (<= 24 chars), "class": String, "level": int,   # 2..4 heroes
##                "items": {"weapon": String, "armor": String, "relic": String},  # "" = empty
##                "alignment": [int, int],   # underlying grid position
##                "slot": [int, int]} ]     # [col 0 front / 1 back, row 0..3]
## }
## Stats are NOT stored: they are re-derived from class data at replay time, so an
## Echo always fights under the current balance. data_version records the balance
## version it was captured under.

const GameData = preload("res://core/game_data.gd")
const Formation = preload("res://core/formation.gd")

const FORMAT := "echoing_depths.echo"
const VERSION := 2
const MAX_JSON_CHARS := 65536
const MAX_META_CHARS := 2048
const MAX_PARTY_NAME := 32
const MAX_DATA_VERSION := 1000000


## Builds a normalised Echo from a party dictionary.
static func make(party: Dictionary, meta: Dictionary = {}) -> Dictionary:
	var heroes: Array = []
	for h: Dictionary in party.get("heroes", []):
		heroes.append(_norm_hero(h))
	return {"format": FORMAT, "version": VERSION, "data_version": GameData.Tuning.DATA_VERSION,
		"name": str(party.get("name", "")).left(MAX_PARTY_NAME), "meta": meta.duplicate(true), "heroes": heroes,
		"unlocked_formations": (Formation.unlocked_of(party) as Array).duplicate()}


## Stable JSON (sorted keys, no whitespace).
static func to_json(echo: Dictionary) -> String:
	return JSON.stringify(echo, "", true)


## Parses JSON text. Returns {"echo": Dictionary} or {"error": String}. Never errors.
static func from_json(text: String) -> Dictionary:
	if text.length() > MAX_JSON_CHARS:
		return {"error": "Echo JSON longer than %d characters" % MAX_JSON_CHARS}
	var j := JSON.new()
	if j.parse(text) != OK:
		return {"error": "invalid JSON: %s (line %d)" % [j.get_error_message(), j.get_error_line()]}
	if not (j.data is Dictionary):
		return {"error": "Echo JSON is not an object"}
	return from_dict(j.data)


## Validates, migrates and normalises a raw Dictionary (e.g. from JSON, where every
## number is a float). Every field is type-checked before it is converted.
## Returns {"echo": Dictionary} or {"error": String}.
static func from_dict(d: Dictionary) -> Dictionary:
	var fmt: Variant = d.get("format", null)
	if not (fmt is String) or String(fmt) != FORMAT:
		return {"error": "not an Echo (format must be \"%s\")" % FORMAT}
	var vv: Variant = d.get("version", null)
	if not GameData.is_whole(vv):
		return {"error": "Echo version must be a whole number"}
	var v := int(vv)
	if v < 1:
		return {"error": "bad Echo version %d" % v}
	if v > VERSION:
		return {"error": "Echo version %d is newer than supported %d" % [v, VERSION]}
	var dv: Variant = d.get("data_version", 0)
	if not GameData.is_whole(dv) or int(dv) < 0 or int(dv) > MAX_DATA_VERSION:
		return {"error": "Echo data_version must be a whole number in 0..%d" % MAX_DATA_VERSION}
	var nm: Variant = d.get("name", "")
	if not (nm is String) or String(nm).length() > MAX_PARTY_NAME:
		return {"error": "Echo name must be a String of at most %d characters" % MAX_PARTY_NAME}
	var meta: Variant = d.get("meta", {})
	if not (meta is Dictionary):
		return {"error": "Echo meta must be an object"}
	if JSON.stringify(meta).length() > MAX_META_CHARS:
		return {"error": "Echo meta larger than %d characters" % MAX_META_CHARS}
	var src := _migrate(d.duplicate(true), v)
	var raw_party := {"heroes": src.get("heroes", null)}
	if src.has("unlocked_formations"):
		raw_party["unlocked_formations"] = src["unlocked_formations"]
	var raw_errs := GameData.validate_party(raw_party, "player")
	if not raw_errs.is_empty():
		return {"error": "; ".join(raw_errs)}
	var heroes: Array = []
	for h: Dictionary in src["heroes"]:
		heroes.append(_norm_hero(h))
	var echo := {"format": FORMAT, "version": VERSION, "data_version": int(dv),
		"name": String(nm), "meta": _ints(meta), "heroes": heroes,
		"unlocked_formations": (src.get("unlocked_formations", GameData.Formations.DEFAULT_UNLOCKED) as Array).duplicate()}
	var errs := GameData.validate_party(echo, "player")
	if not errs.is_empty():
		return {"error": "; ".join(errs)}
	return {"echo": echo}


## JSON has no int type: turn whole-number floats back into ints (recursively).
static func _ints(v: Variant) -> Variant:
	if v is float and GameData.is_whole(v):
		return int(v)
	if v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[k] = _ints((v as Dictionary)[k])
		return d
	if v is Array:
		var a: Array = []
		for x: Variant in v:
			a.append(_ints(x))
		return a
	return v


## Hook for future format changes: upgrade dictionary d from version v to VERSION.
static func _migrate(d: Dictionary, v: int) -> Dictionary:
	var out := d
	while v < VERSION:
		if v == 1:
			# v1 had no Training Grounds unlocks: it fights with the default unlocked set
			out["unlocked_formations"] = (GameData.Formations.DEFAULT_UNLOCKED as Array).duplicate()
		v += 1
	out["version"] = VERSION
	GameData.migrate_heroes(out.get("heroes", null))   # renamed classes (Necromancer -> Gravecaller)
	return out


static func _norm_hero(h: Dictionary) -> Dictionary:
	var items_in: Variant = h.get("items", {})
	if items_in == null:
		items_in = {}
	var items := {"weapon": "", "armor": "", "relic": ""}
	if items_in is Dictionary:
		for k: String in items:
			var val: Variant = (items_in as Dictionary).get(k, "")
			items[k] = "" if val == null else String(val)
	var al: Variant = h.get("alignment", [0, 0])
	var sl: Variant = h.get("slot", [0, 0])
	var al_arr: Array = al if (al is Array and (al as Array).size() == 2) else [0, 0]
	var sl_arr: Array = sl if (sl is Array and (sl as Array).size() == 2) else [-1, -1]
	return {"name": str(h.get("name", "")).left(GameData.MAX_HERO_NAME), "class": str(h.get("class", "")),
		"level": int(h.get("level", 1)), "items": items,
		"alignment": [int(al_arr[0]), int(al_arr[1])], "slot": [int(sl_arr[0]), int(sl_arr[1])]}
