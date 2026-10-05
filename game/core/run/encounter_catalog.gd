extends RefCounted
## All encounters a run can draw from: the authored ones in res://data/encounters/ (loaded through
## the encounter screen's EncounterDB, so format and rules are shared) plus the run-layer pool
## res://core/run/encounter_pool.json (same format, art still to come).
## Choice binding follows EncounterDB: a choice is tied to a hero by class and carries a shift.

const EncDB = preload("res://scenes/encounter/encounter_db.gd")
const POOL_PATH := "res://core/run/encounter_pool.json"

static var _all: Dictionary = {}   # id -> encounter Dictionary (data order: authored first)


static func all() -> Dictionary:
	if _all.is_empty():
		var ids: Array[String] = []
		var dir := DirAccess.open(EncDB.DIR)
		if dir != null:
			for f in dir.get_files():
				if f.ends_with(".json") and not f.begins_with("_"):
					ids.append(f.trim_suffix(".json"))
		ids.sort()
		for id in ids:
			var e: Dictionary = EncDB.get_encounter(id)
			if not e.is_empty():
				_all[id] = e
		var pool: Variant = EncDB.load_json(POOL_PATH)
		if pool is Dictionary:
			for e: Dictionary in pool.get("encounters", []):
				for p in EncDB.validate(e):
					push_warning("Encounter %s: %s" % [e.get("id", "?"), p])
				_all[String(e["id"])] = e
	return _all


static func get_encounter(id: String) -> Dictionary:
	return all().get(id, {})


## Ids of one kind, in stable order.
static func ids_of_kind(kind: String) -> Array:
	var out: Array = []
	for id: String in all():
		if String(all()[id].get("kind", "")) == kind:
			out.append(id)
	return out


## Shift of a choice as [good_evil, lawful_chaotic] (core alignment order).
static func shift(choice: Dictionary) -> Array:
	var s: Vector2i = EncDB.shift_of(choice)
	return [s.x, s.y]


static func is_rare(choice: Dictionary) -> bool:
	return EncDB.is_rare(choice)


## Binds each choice to a party hero of the choice's class. Same rule as EncounterDB.bind_choices
## (by class, choices for absent classes dropped), except that when the party holds two
## heroes of one class the choice goes to the one with fewer memories (lower index on a tie),
## so a duplicate-class recruit can still level. Returns [{choice, hero_index}].
## A hero may get two choices (alignment steering: two directions). An encounter's optional
## "rest" becomes a party-wide choice (hero_index -1): +health, no memory.
static func bind(e: Dictionary, heroes: Array, limit := 6) -> Array:
	var out: Array = []
	for c: Dictionary in e.get("choices", []):
		var best := -1
		for i in heroes.size():
			if String(heroes[i]["base"]) != String(c.get("class", "")):
				continue
			if best < 0 or int(heroes[i]["memories"]) < int(heroes[best]["memories"]):
				best = i
		if best >= 0:
			out.append({"choice": c, "hero_index": best})
		if out.size() >= limit:
			break
	if e.has("rest") and not out.is_empty():
		var r: Dictionary = e["rest"]
		out.append({"hero_index": -1, "choice": {"id": "rest", "class": "", "label": r.get("label", "Rest"),
			"rest": int(r.get("heal", 1)), "shift": {"good": 0, "law": 0}, "outcome": r.get("outcome", "")}})
	return out
