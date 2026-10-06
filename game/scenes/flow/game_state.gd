class_name GameState
extends RefCounted
## Everything that outlives one screen: player settings, meta progress (Lanternrest) and the
## saved run in progress. Static, so it works without an autoload (headless tests run without
## autoloads). Pure data + JSON files under user://; no nodes.
##
##   GameState.load_all()                  # reads settings + meta (defaults when missing)
##   GameState.battle_effects()            # 0 Low / 1 Medium / 2 High (battle spectacle_level)
##   GameState.set_battle_effects(2)       # saves settings
##   GameState.run_options()               # start_run options from meta (unlocks, team name, crest...)
##   GameState.apply_summary(summary)      # banks a finished run into meta, saves; -> rewards
##   GameState.unlock_shape(id) / unlock_crest(id) / form_shard() / set_team(name, crest)
## Tests point the paths elsewhere (use_paths) so they never touch a player's files.
## All meta numbers are placeholders (04-meta-progression.md leaves rates open).

const Run = preload("res://core/run/run.gd")
const RunTuning = preload("res://core/run/run_tuning.gd")
const GameData = preload("res://core/game_data.gd")

const FORMAT := "echoing_depths.meta"
## Run saves replay actions under the run's rules; version 2: Awakening at 2 memories from the camp.
const RUN_SAVE_VERSION := 2
const DEFAULT_TEAM := "The Lanternrest Company"
const TEAM_MAX := 32

## Meta tuning (placeholders, see the open questions in 04-meta-progression.md).
## Glimmers form a Shard at the core's reference rate; shapes cost Shards (size 3: 1, size 4: 2);
## crests are small decorations bought with Glimmers.
const GLIMMERS_PER_SHARD: int = RunTuning.RUN["glimmers_per_shard"]
const SHAPE_COST := {3: 1, 4: 2}
const CREST_COST := 25

## The player's files (user://) only in the real game; tests, captures and tools get
## user://sandbox/ (core/user_files.gd), and writing a player file from them is refused.
const UserFiles = preload("res://core/user_files.gd")
static var settings_path := UserFiles.path("settings.json")
static var meta_path := UserFiles.path("meta.json")
static var run_path := UserFiles.path("run_save.json")
static var pool_path := UserFiles.path("echo_pool.json")

static var settings: Dictionary = {}
static var meta: Dictionary = {}
static var _loaded := false
## Demos and captures set this: changes stay in memory, nothing is written.
static var read_only := false


## Points every file somewhere else (tests). Clears the cached state.
static func use_paths(dir: String) -> void:
	settings_path = dir.path_join("settings.json")
	meta_path = dir.path_join("meta.json")
	run_path = dir.path_join("run_save.json")
	pool_path = dir.path_join("echo_pool.json")
	_loaded = false
	settings = {}
	meta = {}


## Back to this process's default files (the player's in the real game, the sandbox elsewhere).
static func use_default_paths() -> void:
	use_paths(UserFiles.dir())


static func default_settings() -> Dictionary:
	return {"battle_effects": 2}


static func default_meta() -> Dictionary:
	return {"format": FORMAT, "version": 1, "glimmers": 0, "glimmers_total": 0, "shards": 0,
		"shards_total": 0, "runs": 0, "victories": 0, "best_floor": 0, "best_depth": 0,
		"story_chapter": 1, "unlocked_formations": GameData.Formations.DEFAULT_UNLOCKED.duplicate(),
		"crests": Crests.DEFAULT_UNLOCKED.duplicate(), "crest": Crests.DEFAULT_CREST,
		"team_name": DEFAULT_TEAM, "lore": [], "remembrances": [], "monuments": [], "memories_met": [],
		"last_run": {}, "identity_chosen": false, "village_seen": []}


static func load_all() -> void:
	settings = default_settings()
	settings.merge(_read(settings_path), true)
	meta = default_meta()
	var m := _read(meta_path)
	if String(m.get("format", FORMAT)) == FORMAT:
		meta.merge(m, true)
	_loaded = true


static func ensure() -> void:
	if not _loaded:
		load_all()


static func save_settings() -> bool:
	return _write(settings_path, settings)


static func save_meta() -> bool:
	return _write(meta_path, meta)


# ----------------------------------------------------------------- settings

static func battle_effects() -> int:
	ensure()
	return clampi(int(settings.get("battle_effects", 2)), 0, 2)


static func set_battle_effects(level: int) -> void:
	ensure()
	settings["battle_effects"] = clampi(level, 0, 2)
	save_settings()


# ----------------------------------------------------------------- run options

## start_run options from meta: Training Grounds unlocks, the team's name and crest, depth
## milestones and story progress. The Echo pool lives at pool_path.
static func run_options() -> Dictionary:
	ensure()
	return {"pool_path": pool_path, "best_floor": int(meta["best_floor"]),
		"story_chapter": int(meta["story_chapter"]), "party_name": team_name(), "crest": crest(),
		"unlocked_formations": (meta["unlocked_formations"] as Array).duplicate()}


static func team_name() -> String:
	ensure()
	var t := String(meta.get("team_name", "")).strip_edges()
	return DEFAULT_TEAM if t == "" else t.left(TEAM_MAX)


static func crest() -> String:
	ensure()
	return String(meta.get("crest", Crests.DEFAULT_CREST))


# ----------------------------------------------------------------- banking a run

## Banks a finished run's summary into meta and saves. Returns what changed, for the results
## screen: {glimmers, shards, shards_formed, new_floors, story_chapter_before/after, ...}.
static func apply_summary(s: Dictionary) -> Dictionary:
	ensure()
	var g := int(s.get("glimmers", 0))
	var sh := int(s.get("shards", 0))
	meta["runs"] = int(meta["runs"]) + 1
	meta["glimmers"] = int(meta["glimmers"]) + g
	meta["glimmers_total"] = int(meta["glimmers_total"]) + g
	meta["shards"] = int(meta["shards"]) + sh
	meta["shards_total"] = int(meta["shards_total"]) + sh
	meta["best_floor"] = maxi(int(meta["best_floor"]), int(s.get("floor", 0)))
	meta["best_depth"] = maxi(int(meta["best_depth"]), int(s.get("depth", 0)))
	var lore: Array = meta["lore"]
	var new_lore: Array = []
	for l: String in s.get("lore_items", []):
		if not lore.has(l):
			lore.append(l)
			new_lore.append(l)
	var met: Array = meta["memories_met"]
	for m: String in s.get("memories_defeated", []):
		if not met.has(m):
			met.append(m)
	var ch_before := int(meta["story_chapter"])
	if String(s.get("outcome", "")) == "victory":
		meta["victories"] = int(meta["victories"]) + 1
		if s.has("remembrance"):
			(meta["remembrances"] as Array).append(s["remembrance"])
		if s.has("monument"):
			(meta["monuments"] as Array).append(s["monument"])
		# Placeholder story progress: each victory opens the next chapter (06: story, not difficulty).
		meta["story_chapter"] = mini(ch_before + 1, RunTuning.REMEMBRANCES.size())
	meta["last_run"] = {"outcome": s.get("outcome", ""), "depth": s.get("depth", 0), "floor": s.get("floor", 0),
		"glimmers": g, "shards": sh, "team_name": s.get("team_name", "")}
	save_meta()
	return {"glimmers": g, "shards": sh, "new_lore": new_lore, "new_floors": s.get("new_floors", []),
		"story_chapter_before": ch_before, "story_chapter": int(meta["story_chapter"]),
		"glimmers_now": int(meta["glimmers"]), "shards_now": int(meta["shards"])}


# ----------------------------------------------------------------- Lanternrest spending

## Glimmers form one Shard (the player chooses when).
static func can_form_shard() -> bool:
	ensure()
	return int(meta["glimmers"]) >= GLIMMERS_PER_SHARD


static func form_shard() -> bool:
	if not can_form_shard():
		return false
	meta["glimmers"] = int(meta["glimmers"]) - GLIMMERS_PER_SHARD
	meta["shards"] = int(meta["shards"]) + 1
	meta["shards_total"] = int(meta["shards_total"]) + 1
	save_meta()
	return true


static func is_shape_unlocked(id: String) -> bool:
	ensure()
	return (meta["unlocked_formations"] as Array).has(id)


static func shape_cost(id: String) -> int:
	var s := FormationWords.shape_by_id(id)
	return int(SHAPE_COST.get(int(s.get("size", 4)), 2))


## Shapes the Training Grounds can teach next: locked shapes grown from an unlocked one
## (Formations.UNLOCK_TREE), in data order.
static func shape_available(id: String) -> bool:
	ensure()
	if is_shape_unlocked(id):
		return false
	var tree: Dictionary = GameData.Formations.UNLOCK_TREE
	for parent: String in tree:
		if (tree[parent] as Array).has(id) and is_shape_unlocked(parent):
			return true
	return false


## The unlocked shapes a locked one grows from (for "Needs Keystone" hints).
static func shape_parents(id: String) -> Array:
	var out: Array = []
	var tree: Dictionary = GameData.Formations.UNLOCK_TREE
	for parent: String in tree:
		if (tree[parent] as Array).has(id):
			out.append(parent)
	return out


static func unlock_shape(id: String) -> bool:
	if not shape_available(id) or int(meta["shards"]) < shape_cost(id):
		return false
	meta["shards"] = int(meta["shards"]) - shape_cost(id)
	(meta["unlocked_formations"] as Array).append(id)
	save_meta()
	return true


static func has_crest(id: String) -> bool:
	ensure()
	return (meta["crests"] as Array).has(id)


static func unlock_crest(id: String) -> bool:
	ensure()
	if has_crest(id) or not Crests.exists(id) or int(meta["glimmers"]) < CREST_COST:
		return false
	meta["glimmers"] = int(meta["glimmers"]) - CREST_COST
	(meta["crests"] as Array).append(id)
	save_meta()
	return true


## A save exists (the title offers Continue instead of New game).
static func has_save() -> bool:
	return FileAccess.file_exists(meta_path) or has_saved_run()


## The first visit to Lanternrest asks for a team name and crest (docs/BUILD.md "Team identity").
## Saves from before the village (a run already played) count as chosen.
static func identity_needed() -> bool:
	ensure()
	return not bool(meta.get("identity_chosen", false)) and int(meta.get("runs", 0)) == 0


static func set_identity(name: String, crest_id: String) -> void:
	ensure()
	meta["identity_chosen"] = true
	set_team(name, crest_id)


## The player has looked at a newly built place (its NEW tag goes).
static func mark_seen(place_id: String) -> void:
	ensure()
	var seen: Array = meta["village_seen"]
	if not seen.has(place_id):
		seen.append(place_id)
		save_meta()


## Sets the team's name and crest (Banner Hall). An empty name falls back to the default.
static func set_team(name: String, crest_id: String) -> void:
	ensure()
	var t := name.strip_edges().left(TEAM_MAX)
	meta["team_name"] = t if t != "" else DEFAULT_TEAM
	if has_crest(crest_id):
		meta["crest"] = crest_id
	save_meta()


# ----------------------------------------------------------------- run save / continue
## A run is deterministic from its seed, options and the Echo pool, so the save is the seed,
## the options and the list of player actions; continuing replays them.

static func save_run(seed_value: int, options: Dictionary, actions: Array) -> void:
	_write(run_path, {"format": "echoing_depths.run", "version": RUN_SAVE_VERSION, "seed": seed_value,
		"options": options, "actions": actions})


static func has_saved_run() -> bool:
	return not _read(run_path).is_empty()


static func clear_saved_run() -> void:
	if not read_only and FileAccess.file_exists(run_path) and UserFiles.may_write(run_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path))


## Rebuilds the saved run by replaying its actions. -> {"run", "seed", "options", "actions"} or {}.
static func load_run() -> Dictionary:
	var d := _read(run_path)
	if d.is_empty():
		return {}
	if int(d.get("version", 1)) != RUN_SAVE_VERSION:   # older rules: the replay would not match
		clear_saved_run()
		return {}
	var run: RefCounted = Run.new()
	var opts: Dictionary = d.get("options", {})
	run.call("start_run", int(d.get("seed", 1)), opts)
	var actions: Array = d.get("actions", [])
	for a: Array in actions:
		if replay(run, a).has("error"):
			clear_saved_run()
			return {}
	return {"run": run, "seed": int(d["seed"]), "options": opts, "actions": actions}


## Applies one recorded action: ["choose", i] / ["formation", slots] / ["fight"] / ["advance"] /
## ["awaken", hero] / ["hold", hero].
static func replay(run: RefCounted, a: Array) -> Dictionary:
	match String(a[0]):
		"choose":
			return run.call("choose", int(a[1]))
		"formation":
			var slots: Array = []
			for s: Array in a[1]:
				slots.append([int(s[0]), int(s[1])])
			return run.call("set_formation", slots)
		"fight":
			return run.call("resolve_fight")
		"advance":
			return run.call("advance")
		"awaken":
			return run.call("awaken", int(a[1]))
		"hold":
			return run.call("hold_back", int(a[1]))
	return {"error": "unknown action %s" % str(a)}


# ----------------------------------------------------------------- files

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK or not (j.data is Dictionary):
		return {}
	return j.data


static func _write(path: String, d: Dictionary) -> bool:
	if read_only:
		return true
	if not UserFiles.may_write(path):
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true
