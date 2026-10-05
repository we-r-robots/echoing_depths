class_name PartyModel
extends RefCounted
## Read-only view-model helpers for the hero detail screen. Pure functions over hero
## dictionaries in the core format (see core/README.md) plus two optional UI fields:
##   "memories": Array of [d_good, d_law] shifts in the order they were absorbed (the trail)
##   "held_back": bool, the player suppressed this hero's Advancement at the threshold
## Encounter-style heroes ({pos: Vector2i}) are accepted too (see normalize()).

const GameData = preload("res://core/game_data.gd")
const Alignment = preload("res://core/alignment.gd")
const HeroStats = preload("res://core/hero_stats.gd")

const REGION_ORDER := ["LG*", "LG", "CG", "CG*", "N", "LE*", "LE", "CE", "CE*"]
const STAT_LABELS := {"hp": "HP", "atk": "Atk", "def": "Def", "mag": "Mag", "spd": "Spd"}
const TIER_LABELS := {"base": "Base", "advanced": "Advanced", "legendary": "Legendary"}
const TARGET_WORDS := {
	"melee": "the foe in front", "lowest_hp_enemy": "the weakest foe", "lowest_hp_ally": "the weakest ally",
	"all_enemies": "every foe", "all_allies": "every ally", "random_enemy": "a random foe",
	"back_first": "the back row first", "self": "itself",
}
const TO_WORDS := {
	"primary": "", "primary_adjacent": "its neighbours", "all_enemies": "every foe",
	"all_allies": "every ally", "self": "itself", "lowest_hp_ally": "the weakest ally", "melee": "the foe in front",
	"lowest_hp_enemy": "the weakest foe", "front_random": "random front foes", "back_first": "the back row",
}


## Fills in defaults so the screen can trust the shape. Returns a new dictionary.
static func normalize(h: Dictionary) -> Dictionary:
	var o := h.duplicate(true)
	if not o.has("alignment") and o.has("pos"):
		var p: Vector2i = o["pos"]
		o["alignment"] = [p.x, p.y]
	if not o.has("alignment"):
		o["alignment"] = start_of(o)
	if not o.has("items"):
		o["items"] = {}
	if not o.has("level"):
		o["level"] = 1
	return o


static func class_def(h: Dictionary) -> Dictionary:
	return GameData.get_class_def(String(h.get("class", "")))


static func base_class(h: Dictionary) -> String:
	return String(class_def(h).get("base", h.get("class", "")))


static func tier(h: Dictionary) -> String:
	return String(class_def(h).get("tier", "base"))


static func class_name_of(id: String) -> String:
	return String(GameData.get_class_def(id).get("name", id.capitalize()))


static func start_of(h: Dictionary) -> Array:
	return Alignment.start_for(base_class(h))


static func underlying(h: Dictionary) -> Array:
	var a: Array = h.get("alignment", [0, 0])
	return [int(a[0]), int(a[1])]


static func relic_offset(h: Dictionary) -> Array:
	return Alignment.relic_offset(h)


static func effective(h: Dictionary) -> Array:
	return Alignment.effective(underlying(h), relic_offset(h))


## Underlying positions visited: start, then one entry per memory.
static func trail(h: Dictionary) -> Array:
	var out := [start_of(h)]
	for s: Variant in h.get("memories_before", []) + h.get("memories", []):
		out.append(Alignment.apply_shift(out[-1], s))
	if out[-1] != underlying(h):
		out.append(underlying(h))
	return out


static func threshold() -> int:
	return int(EncounterDB.rules().get("advance_threshold", 3))


static func max_level(h: Dictionary) -> int:
	return GameData.max_level(String(h.get("class", "")))


## Memories absorbed in the current tier (a memory is +1 level).
static func memory_count(h: Dictionary) -> int:
	if tier(h) == "base" and h.has("memories"):
		return (h["memories"] as Array).size()
	return maxi(int(h.get("level", 1)) - 1, 0)


static func ready_to_advance(h: Dictionary) -> bool:
	return tier(h) == "base" and memory_count(h) >= threshold()


## Memories a base hero can still absorb (held back heroes keep levelling to the cap).
static func memories_left(h: Dictionary) -> int:
	return maxi(max_level(h) - 1 - memory_count(h), 0)


static func region_of(p: Array) -> String:
	return Alignment.region_of(p)


## The advanced class authored for exactly this region ("" if none yet).
static func class_for_region(base: String, region: String) -> String:
	var classes: Dictionary = GameData.Classes.CLASSES
	for id: String in classes:
		var c: Dictionary = classes[id]
		if String(c.get("tier", "")) == "advanced" and String(c.get("base", "")) == base and String(c.get("region", "")) == region:
			return id
	return ""


## What Advancing would produce right now (core lookup: corner first, then its quadrant).
static func advance_target(h: Dictionary) -> String:
	return Alignment.advanced_class_for(base_class(h), effective(h))


static func axis_word(axis: String, v: int) -> String:
	var ax: Dictionary = EncounterDB.rules()["axes"][axis]
	return String(ax["pos"] if v > 0 else ax["neg"])


static func axis_color(axis: String, v: int) -> Color:
	var ax: Dictionary = EncounterDB.rules()["axes"][axis]
	return Pal.c(String(ax["pos_color"] if v > 0 else ax["neg_color"]))


## "Order · Mercy", "Neutral", "Far Order · Mercy" (corners) for a region code.
static func region_words(region: String) -> String:
	if region == "N":
		return "Neutral cross"
	var law := axis_word("law", 1 if region.begins_with("L") else -1)
	var good := axis_word("good", 1 if region.substr(1, 1) == "G" else -1)
	return "%s · %s" % [law, good]


## A representative cell for a region (corner cell for corners, else the inner diagonal).
static func region_cell(region: String) -> Array:
	if region == "N":
		return [0, 0]
	var g := 1 if region.substr(1, 1) == "G" else -1
	var l := 1 if region.begins_with("L") else -1
	var k := 2 if region.ends_with("*") else 1
	return [g * k, l * k]


static func steps(a: Array, b: Array) -> int:
	return absi(int(a[0]) - int(b[0])) + absi(int(a[1]) - int(b[1]))


## Corner rarity for this hero's base class, relative to its fixed start:
## 1 within reach (single steps get there by the threshold), 3 super rare (the farthest corner;
## ties all get it, e.g. a start on a neutral axis has two far corners), 2 rare otherwise.
static func corner_rarity(h: Dictionary, corner: String) -> int:
	var st := start_of(h)
	var d := steps(st, region_cell(corner))
	if d <= threshold():
		return 1
	var far := 0
	for r in ["LG*", "CG*", "LE*", "CE*"]:
		far = maxi(far, steps(st, region_cell(r)))
	return 3 if d == far else 2


const RARITY_WORDS := ["", "Within reach", "Rare", "Super rare"]


## Lean modifier for a cell inside its region ("Order lean", "Mercy lean", "" if balanced).
static func lean_of(p: Array) -> String:
	var g := int(p[0])
	var l := int(p[1])
	if absi(g) == absi(l):
		return ""
	if absi(l) > absi(g):
		return "%s lean" % axis_word("law", l)
	return "%s lean" % axis_word("good", g)


static func stats(h: Dictionary) -> Dictionary:
	return HeroStats.compute(h)


static func item(id: String) -> Dictionary:
	return GameData.get_item(id)


static func item_stat_words(it: Dictionary) -> String:
	var parts := []
	var st: Dictionary = it.get("stats", {})
	for s: String in GameData.STATS:
		if st.has(s):
			parts.append("%+d %s" % [int(st[s]), STAT_LABELS[s]])
	return "  ".join(parts)


static func ability_of(class_id: String) -> Dictionary:
	var a := GameData.get_action(String(GameData.get_class_def(class_id).get("ability", "")))
	return a


## A label of 20 characters or fewer for an ability (BUILD.md: effects are icons; the full sentence
## from ability_desc lives in the shared tooltip).
const SHORT_TARGET := {
	"melee": "front foe", "lowest_hp_enemy": "weakest foe", "lowest_hp_ally": "weakest ally",
	"all_enemies": "every foe", "all_allies": "every ally", "random_enemy": "random foe",
	"back_first": "back row", "self": "self", "primary_adjacent": "sides", "front_random": "front foes",
	"other_enemies": "all foes", "all_enemies_rest": "all foes", "melee_enemy": "front foe",
	"primary_column_rest": "column",
}


static func ability_short(a: Dictionary) -> String:
	var effs: Array = a.get("effects", [])
	if effs.is_empty():
		return String(a.get("name", ""))
	var tgt := String(SHORT_TARGET.get(String(a.get("target", "")), "a foe"))
	var e0: Dictionary = effs[0]
	var s := ""
	if String(e0.get("op", "")) == "heal":
		s = "Heals " + tgt
	elif e0.has("drain"):
		s = "Drains " + tgt
	else:
		s = "Hits " + tgt
	if int(e0.get("hits", 1)) > 1:
		s += " x%d" % int(e0["hits"])
	if effs.size() > 1 and String((effs[1] as Dictionary).get("op", "")) in ["damage", "heal"]:
		var e1: Dictionary = effs[1]
		var to := String(e1.get("to", "primary"))
		var extra := String(SHORT_TARGET.get(to, ""))
		var verb := "heal" if String(e1.get("op", "")) == "heal" else "hit"
		var first_heal := String(e0.get("op", "")) == "heal"
		if first_heal and verb == "hit":
			s = "Heal %s + hit foe" % ("all" if String(a.get("target", "")) == "all_allies" else "ally")
		elif not first_heal and verb == "heal" and String(e1.get("op", "")) == "heal":
			s = "Hit foe + heal ally"
		elif verb == "hit" and extra != "" and (tgt + " + " + extra).length() <= 20:
			s = tgt.substr(0, 1).to_upper() + tgt.substr(1) + " + " + extra
		elif extra != "" and (s + " + " + extra).length() <= 20:
			s += " + " + extra
		elif (s + ", then " + verb).length() <= 20:
			s += ", then " + verb
	if s.length() > 20:
		s = s.substr(0, 19) + "\u2026"
	return s


## One-line description generated from an action's effects.
static func ability_desc(a: Dictionary) -> String:
	var tgt := String(TARGET_WORDS.get(String(a.get("target", "")), "a foe"))
	var parts := []
	for e: Dictionary in a.get("effects", []):
		var to := String(e.get("to", "primary"))
		var who: String = tgt if to == "primary" else String(TO_WORDS.get(to, to.replace("_", " ")))
		var pct := roundi(float(e.get("power", 1.0)) * 100.0)
		match String(e.get("op", "")):
			"damage":
				var kind := String(e.get("kind", ""))
				var s := "Hits %s for %d%% %s" % [who, pct, kind]
				if int(e.get("hits", 1)) > 1:
					s += " x%d" % int(e["hits"])
				if e.has("drain"):
					s += ", draining life"
				parts.append(s)
			"heal":
				parts.append("Heals %s (%d%%)" % [who, pct])
			_:
				parts.append(String(e.get("op", "")).capitalize())
	if parts.size() > 1:
		parts[1] = String(parts[1]).replace("Hits ", "then ").replace("Heals ", "then heals ")
	return ", ".join(parts) + "."


## The hero this hero would become on Advancing now (new dictionary, level reset to 1).
static func advanced_copy(h: Dictionary) -> Dictionary:
	var o := h.duplicate(true)
	o["class"] = advance_target(h)
	o["level"] = 1
	o["memories_before"] = o.get("memories", [])
	o["memories"] = []
	o["held_back"] = false
	return o
