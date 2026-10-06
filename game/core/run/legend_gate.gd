extends RefCounted
## The Legendary gate (05-formations.md "Legendary: The Legend's Memory"), kept behind one small
## interface so it can be replaced as the design firms up. Numbers: RunTuning.LEGEND_GATE.
## Data: legend_memories.json (one legend's-memory encounter per authored advanced class).
##
## run_state: {"legendaries": int, "appeared": bool, "misses": int}
##  - a hero is eligible from advanced level 3 (no depth gate), while the party has no Legendary,
##    and only if their advanced class has an authored Legendary (today: Lightsworn -> Lantern Saint, a PROVISIONAL parent);
##  - from then on each encounter node rolls chance(): 8 %, +8 % after each node where it does
##    not appear, capped at 60 %; it appears at most once per run (declining ends it).

const GameData = preload("res://core/game_data.gd")
const Alignment = preload("res://core/alignment.gd")
const Rng = preload("res://core/rng.gd")
const T = preload("res://core/run/run_tuning.gd")
const DATA_PATH := "res://core/run/legend_memories.json"

static var _by_class: Dictionary = {}


static func eligible(hero: Dictionary, run_state: Dictionary) -> bool:
	if bool(run_state.get("appeared", false)):
		return false
	if int(run_state.get("legendaries", 0)) >= int(GameData.Tuning.MAX_LEGENDARY_PER_PARTY):
		return false
	if bool(hero.get("legendary", false)):
		return false
	if String(GameData.get_class_def(String(hero.get("class", ""))).get("tier", "")) != "advanced":
		return false
	if not enabled_for(String(hero.get("class", ""))):
		return false
	return int(hero.get("level", 0)) >= int(T.LEGEND_GATE["min_advanced_level"])


## Only classes with an authored Legendary get the offer (so "accept" always does something).
## The other templates stay in legend_memories.json, dormant, until their Legendaries exist.
static func enabled_for(advanced_class: String) -> bool:
	return Alignment.legendary_class_for(advanced_class) != "" and not encounter_for(advanced_class).is_empty()


static func chance(run_state: Dictionary) -> float:
	var g: Dictionary = T.LEGEND_GATE
	return minf(float(g["base_chance"]) + float(g["step"]) * int(run_state.get("misses", 0)), float(g["cap"]))


## Does the legend's memory appear at this encounter node? Caller bumps "misses" on false.
static func roll(rng: Rng, run_state: Dictionary) -> bool:
	return rng.next_float() < chance(run_state)


## The legend's-memory encounter for an advanced class ({} if none is written).
static func encounter_for(advanced_class: String) -> Dictionary:
	if _by_class.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for e: Dictionary in d.get("encounters", []):
					_by_class[GameData.canonical_class(String(e["for_class"]))] = e   # renamed classes too
	return _by_class.get(GameData.canonical_class(advanced_class), {})
