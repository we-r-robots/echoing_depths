class_name EncounterDB
extends RefCounted
## Loads encounter definitions (data/encounters/<id>.json) and the shared rules file.
## Pure data helpers: no nodes. Party heroes are plain Dictionaries:
##   { name: String, class: String, level: int, pos: Vector2i(good, law) }

const DIR := "res://data/encounters/"
const KINDS := ["riddle", "chance", "monster", "recruitment", "moral"]

static var _rules: Dictionary = {}
static var _cache: Dictionary = {}


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("EncounterDB: cannot open %s" % path)
		return null
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data == null:
		push_error("EncounterDB: bad JSON in %s" % path)
	return data


static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = load_json(DIR + "_rules.json")
	return _rules


## Memories a hero holds in its current tier: the "memories" count when given (the run's heroes),
## else level - 1 (a hero starts at level 1; each memory is +1 level).
static func memories_of(h: Dictionary) -> int:
	var m: Variant = h.get("memories", null)
	if m is int or m is float:
		return int(m)
	return maxi(0, int(h.get("level", 1)) - 1)


## True when one more memory makes this base hero able to Awaken (rules "advance_threshold").
static func awakens_after(h: Dictionary) -> bool:
	var thr := int(rules().get("advance_threshold", 2))
	return String(h.get("tier", "base")) == "base" and memories_of(h) + 1 == thr


static func get_encounter(id: String) -> Dictionary:
	if not _cache.has(id):
		var d: Variant = load_json(DIR + id + ".json")
		if d == null:
			return {}
		_cache[id] = d
		var problems := validate(d)
		for p in problems:
			push_warning("Encounter %s: %s" % [id, p])
	return _cache[id]


## Returns a list of human-readable problems; empty when the definition is valid.
static func validate(e: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in ["id", "kind", "title", "art", "text", "choices"]:
		if not e.has(k):
			out.append("missing '%s'" % k)
	if e.get("kind", "") not in KINDS:
		out.append("unknown kind '%s'" % e.get("kind", ""))
	var classes: Dictionary = rules().get("classes", {})
	for cid in classes:
		class_info(cid)  # fails loudly if display data and core drift apart
	for c in e.get("choices", []):
		if not classes.has(c.get("class", "")):
			out.append("choice %s has unknown class" % c.get("id", "?"))
		var s := shift_of(c)
		if s == Vector2i.ZERO or absi(s.x) + absi(s.y) > 2:
			out.append("choice %s shift must be 1 or 2 steps" % c.get("id", "?"))
		if not c.has("outcome"):
			out.append("choice %s has no outcome" % c.get("id", "?"))
	return out


static func shift_of(choice: Dictionary) -> Vector2i:
	var s: Dictionary = choice.get("shift", {})
	return Vector2i(int(s.get("good", 0)), int(s.get("law", 0)))


## The move a hero actually makes once the grid edge clamps it.
static func effective_shift(pos: Vector2i, choice: Dictionary) -> Vector2i:
	return clamp_pos(pos + shift_of(choice)) - pos


## Strong (rare) shifts: diagonal or two steps on one axis.
static func is_rare(choice: Dictionary) -> bool:
	var s := shift_of(choice)
	return absi(s.x) + absi(s.y) >= 2


const CoreClasses := preload("res://core/data/classes.gd")


## Display data from _rules.json plus the starting position, which always comes from core
## (core/data/classes.gd is the source of truth). Fails loudly if the two files disagree on classes.
static func class_info(cls: String) -> Dictionary:
	var info: Dictionary = rules().get("classes", {}).get(cls, {}).duplicate()
	if info.has("start"):
		push_error("EncounterDB: _rules.json must not define 'start' for %s; core/data/classes.gd owns it" % cls)
		assert(false, "duplicate starting position for " + cls)
	var core: Dictionary = CoreClasses.CLASSES.get(cls, {})
	if core.is_empty() or not core.has("start_alignment"):
		push_error("EncounterDB: class '%s' has no start_alignment in core/data/classes.gd" % cls)
		assert(false, "unknown class " + cls)
		return info
	info["start"] = core["start_alignment"]
	return info


static func class_start(cls: String) -> Vector2i:
	var s: Array = class_info(cls).get("start", [0, 0])
	return Vector2i(int(s[0]), int(s[1]))


static func kind_info(kind: String) -> Dictionary:
	return rules().get("kinds", {}).get(kind, {})


static func clamp_pos(p: Vector2i) -> Vector2i:
	var lo: int = int(rules().get("grid_min", -2))
	var hi: int = int(rules().get("grid_max", 2))
	return Vector2i(clampi(p.x, lo, hi), clampi(p.y, lo, hi))


## Pairs each choice with the party hero it binds to (first hero of that class). Choices whose
## class is not in the party are dropped. Returns [{choice, hero_index}], at most `limit`.
static func bind_choices(e: Dictionary, party: Array, limit := 4) -> Array:
	var out := []
	for c in e.get("choices", []):
		for i in party.size():
			if party[i]["class"] == c.get("class", ""):
				out.append({"choice": c, "hero_index": i})
				break
		if out.size() >= limit:
			break
	return out


## Applies a choice to the bound hero: +1 level (a memory) and the alignment shift, clamped.
static func apply_choice(hero: Dictionary, choice: Dictionary) -> Dictionary:
	var before := {"level": hero["level"], "pos": hero["pos"]}
	hero["level"] = int(hero["level"]) + 1
	if hero.get("memories", null) is int:
		before["memories"] = hero["memories"]
		hero["memories"] = int(hero["memories"]) + 1
	hero["pos"] = clamp_pos(hero["pos"] + shift_of(choice))
	return before


## Outcome text: a string, or a list of {weight, text} picked with the global (seeded) RNG.
static func pick_outcome(choice: Dictionary) -> String:
	var o: Variant = choice.get("outcome", "")
	if o is String:
		return o
	var total := 0.0
	for v in o:
		total += float(v.get("weight", 1))
	var r := randf() * total
	for v in o:
		r -= float(v.get("weight", 1))
		if r <= 0.0:
			return v.get("text", "")
	return o[-1].get("text", "")


## Words for a shift, e.g. "Cruelty" / "Mercy +2" / "Cruelty, Freedom".
static func shift_words(s: Vector2i) -> Array:
	var axes: Dictionary = rules()["axes"]
	var out := []
	for pair in [["good", s.x], ["law", s.y]]:
		var v: int = pair[1]
		if v == 0:
			continue
		var ax: Dictionary = axes[pair[0]]
		var word: String = ax["pos"] if v > 0 else ax["neg"]
		var col: String = ax["pos_color"] if v > 0 else ax["neg_color"]
		out.append({"word": word, "amount": absi(v), "color": col})
	return out


## Grid-space direction (x right = Freedom, y down = Cruelty) for arrow glyphs.
static func screen_dir(s: Vector2i) -> Vector2i:
	return Vector2i(-s.y, -s.x)


static func arrow_icon(s: Vector2i) -> String:
	var d := screen_dir(s)
	var base := "res://ui/icons/"
	if d.x != 0 and d.y != 0:
		return base + "arrow_%s%s.png" % ["up" if d.y < 0 else "down", "left" if d.x < 0 else "right"]
	var two := absi(d.x) + absi(d.y) >= 2
	var dname := "up"
	if d.y > 0:
		dname = "down"
	elif d.x < 0:
		dname = "left"
	elif d.x > 0:
		dname = "right"
	return base + ("arrow2_" if two else "arrow_") + dname + ".png"


const TAGS := {
	"crystal": "crystal4", "amber": "amber5", "fade": "fade3",
	"violet": "violet3", "blood": "blood3", "life": "life4", "gold": "amber6",
}


## Converts encounter markup ([crystal]..[/crystal] etc.) to RichTextLabel BBCode.
static func markup(s: String) -> String:
	for tag in TAGS:
		var col: Color = Pal.c(TAGS[tag])
		s = s.replace("[%s]" % tag, "[color=#%s]" % col.to_html(false)).replace("[/%s]" % tag, "[/color]")
	return s
