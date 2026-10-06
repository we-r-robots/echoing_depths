extends RefCounted
## Local Echo pool: the rival parties PvP nodes draw from. Persisted as JSON (the player's
## user://echo_pool.json in the real game; default_path() elsewhere). Every finished run (won or lost) adds a snapshot of its party; a fresh
## pool is seeded with generated Echoes so a first run has opponents. Entries are core Echo
## dictionaries (core/echo.gd) whose meta carries {"power", "floor", "depth", "outcome",
## "generated", "team_name", "crest"} (crest "" until player crests exist).
## Matching is by floor: an Echo meets parties on the floor where it was recorded.

const Echo = preload("res://core/echo.gd")
const Rng = preload("res://core/rng.gd")
const GameData = preload("res://core/game_data.gd")
const Alignment = preload("res://core/alignment.gd")
const T = preload("res://core/run/run_tuning.gd")

const UserFiles = preload("res://core/user_files.gd")

const FORMAT := "echoing_depths.echo_pool"
const DEFAULT_PATH := "user://echo_pool.json"   # the player's pool: only the real game uses it

var path := ""


## The pool file for this process: the player's in the real game, a sandbox copy anywhere else
## (tests, captures, simulations; core/user_files.gd).
static func default_path() -> String:
	return UserFiles.path("echo_pool.json")
var echoes: Array = []


## Loads the pool at `p`, or creates (and saves) a seeded one if missing or unreadable.
static func open(p: String = "") -> RefCounted:
	var pool: RefCounted = (load("res://core/run/echo_pool.gd") as GDScript).new()
	pool.path = p if p != "" else default_path()
	if not pool.load_from_disk():
		pool.seed_generated(1)
		pool.save()
	return pool


func load_from_disk() -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK or not (j.data is Dictionary) or j.data.get("format", "") != FORMAT:
		return false
	echoes.clear()
	for raw: Variant in j.data.get("echoes", []):
		if raw is Dictionary:
			var r := Echo.from_dict(raw)
			if r.has("echo"):
				echoes.append(r["echo"])
	return not echoes.is_empty()


func save() -> bool:
	if path == "" or not UserFiles.may_write(path):
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"format": FORMAT, "version": 1, "echoes": echoes}, "", true))
	return true


## Adds a party snapshot. Oldest non-generated Echoes are dropped past echo_pool_max.
func add(party: Dictionary, meta: Dictionary) -> Dictionary:
	var m := meta.duplicate(true)
	m["power"] = power(party)
	var e := Echo.make(party, m)
	echoes.append(e)
	var cap := int(T.RUN["echo_pool_max"])
	var i := 0
	while echoes.size() > cap and i < echoes.size():
		if not bool(echoes[i]["meta"].get("generated", false)):
			echoes.remove_at(i)
		else:
			i += 1
	return e


## Opponent for a party on `floor` (size-aware, user 2026-10-05: a 2-hero party should not meet a
## full, levelled team). Candidates widen only when needed:
##   1. same floor, same hero count, power within RUN.echo_power_gap of the party's
##   2. same floor, +-1 hero, power within RUN.echo_power_gap_wide
##   3. the same two steps on the nearest floors (+-1, +-2 ...)
##   4. the closest Echo anywhere (hero count, then power, then floor)
## Within a step: a seeded pick among that floor's most recent real Echoes; generated ones join only
## while fewer than RUN.echo_min_real real ones match. `party` {} (no party given) matches by floor
## only. `exclude`: names already met this run (never picked twice while any alternative exists).
func pick(floor_n: int, rng: Rng, exclude: Dictionary = {}, party: Dictionary = {}) -> Dictionary:
	if echoes.is_empty():
		return {}
	var size: int = party.get("heroes", []).size()
	var pw := power(party) if size > 0 else 0
	var steps: Array = [[0, gap(pw, T.RUN["echo_power_gap"])], [1, gap(pw, T.RUN["echo_power_gap_wide"])]] \
		if size > 0 else [[99, 1 << 30]]
	var rows: Array = []   # [echo, floor, hero count, power] of the Echoes not met yet
	var far := 0
	for e: Dictionary in echoes:
		if not exclude.has(String(e.get("name", ""))):
			var r := [e, floor_of(e), (e.get("heroes", []) as Array).size(), power(e) if size > 0 else 0]
			rows.append(r)
			far = maxi(far, absi(int(r[1]) - floor_n))
	for dist in far + 1:
		for f in ([floor_n] if dist == 0 else [floor_n - dist, floor_n + dist]):
			for st: Array in steps:
				var real: Array = []
				var gen: Array = []
				for r: Array in rows:
					if int(r[1]) != f or absi(int(r[2]) - size) > int(st[0]) or absi(int(r[3]) - pw) > int(st[1]):
						continue
					var e: Dictionary = r[0]
					(gen if bool(e["meta"].get("generated", false)) else real).append(e)
				real = real.slice(maxi(0, real.size() - int(T.RUN["echo_recent_per_floor"])))
				var cands: Array = real if real.size() >= int(T.RUN["echo_min_real"]) else real + gen
				if not cands.is_empty():
					return (cands[rng.int_range(0, cands.size() - 1)] as Dictionary).duplicate(true)
	# nothing near enough anywhere: the closest by hero count, then power, then floor
	var best: Array = []
	var best_key: Array = []
	for r: Array in rows:
		var key := [absi(int(r[2]) - size), absi(int(r[3]) - pw), absi(int(r[1]) - floor_n)]
		if best.is_empty() or key < best_key:
			best = r
			best_key = key
	if best.is_empty():   # every Echo met already
		return echoes[rng.int_range(0, echoes.size() - 1)].duplicate(true)
	return (best[0] as Dictionary).duplicate(true)


## Power gap allowed around party power `p`: [absolute, share] -> max(absolute, share * p).
static func gap(p: int, g: Array) -> int:
	return maxi(int(g[0]), int(ceil(float(g[1]) * p)))


## "The <epithet> <company>" from a number (seeded by the caller).
static func team_name(n: int) -> String:
	var a: Array = T.TEAM_EPITHETS
	var b: Array = T.TEAM_COMPANIES
	@warning_ignore("integer_division")
	return "The %s %s" % [a[n % a.size()], b[(n / a.size()) % b.size()]]


## Floor an Echo was recorded on (older entries without one: from depth, 6 nodes per floor).
static func floor_of(e: Dictionary) -> int:
	var m: Dictionary = e.get("meta", {})
	if m.has("floor"):
		return int(m["floor"])
	@warning_ignore("integer_division")
	return 1 + int(m.get("depth", 0)) / 6


## Strength score: sum over heroes of tier offset + level, +1 per equipped item.
static func power(party: Dictionary) -> int:
	var p := 0
	for h: Dictionary in party.get("heroes", []):
		var tier := String(GameData.get_class_def(String(h["class"])).get("tier", "base"))
		p += int(T.TIER_POWER.get(tier, 0)) + int(h["level"])
		for k: String in h.get("items", {}):
			if String(h["items"][k]) != "":
				p += 1
	return p


## Fills the pool with generated Echoes for every floor, sized like a party at that floor's first
## PvP (RUN.echo_seed_sizes / echo_seed_memories: the recruit pacing and the Awakening threshold).
func seed_generated(seed_value: int) -> void:
	var rng := Rng.new(seed_value)
	var floors: int = T.RUN["floors"].size()
	var per := int(T.RUN["echo_seed_per_floor"])
	var used_names := {}
	for f in range(1, floors + 1):
		var stage := float(f - 1) / float(maxi(1, floors - 1))   # 0 = floor 1 .. 1 = last floor
		for k in per:
			var sizes: Array = T.RUN["echo_seed_sizes"][mini(f - 1, T.RUN["echo_seed_sizes"].size() - 1)]
			var size := clampi(int(sizes[k % sizes.size()]), 2, 4)
			var avg_mem := float(T.RUN["echo_seed_memories"][mini(f - 1, T.RUN["echo_seed_memories"].size() - 1)])
			var heroes: Array = []
			var used := {}
			for i in size:
				var base: String = rng.pick(GameData.Classes.BASE_CLASS_IDS)
				var mem := clampi(int(round(avg_mem + rng.float_range(-1.0, 1.0))), 0, 8)
				var pos := Alignment.start_for(base)
				for s in mem:
					pos = Alignment.apply_shift(pos, [rng.int_range(-1, 1), rng.int_range(-1, 1)])
				var cid := base
				var lvl := mini(1 + mem, GameData.max_level(base))
				if mem >= int(T.RUN["advance_threshold"]):
					var adv := Alignment.advanced_class_for(base, pos)
					if adv != "":
						cid = adv
						lvl = mini(1 + mem - int(T.RUN["advance_threshold"]), GameData.max_level(adv))
				var items := {"weapon": "", "armor": "", "relic": ""}
				for slot: String in GameData.Items.SLOTS:
					if rng.next_float() < stage * 0.5:
						var ids: Array = []
						for iid: String in GameData.Items.ITEMS:
							if String(GameData.Items.ITEMS[iid]["slot"]) == slot:
								ids.append(iid)
						items[slot] = rng.pick(ids)
				var pref := int(GameData.get_class_def(cid)["preferred_col"])
				var hname: String = T.HERO_NAMES[(f * 7 + k * 4 + i) % T.HERO_NAMES.size()]
				heroes.append({"name": hname, "class": cid, "level": lvl, "items": items,
					"alignment": pos, "slot": _free_slot(used, pref)})
			var tn := team_name(rng.next_u32())
			while used_names.has(tn):
				tn = team_name(rng.next_u32())
			used_names[tn] = true
			add({"name": tn, "heroes": heroes}, {"generated": true, "floor": f, "depth": (f - 1) * 6 + 3,
				"outcome": "generated", "team_name": tn, "crest": ""})


static func _free_slot(used: Dictionary, pref_col: int) -> Array:
	for col in [pref_col, 1 - pref_col]:
		for row in 4:
			var key: int = col * 4 + row
			if not used.has(key):
				used[key] = true
				return [col, row]
	return [0, 0]
