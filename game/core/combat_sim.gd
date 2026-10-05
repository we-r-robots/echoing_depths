extends RefCounted
## Deterministic auto-battle simulation. Pure logic: no nodes, no rendering,
## no global randomness. Same (seed, party_a, party_b, options) -> identical result.
##
## Usage:
##   const CombatSim = preload("res://core/combat_sim.gd")
##   var result := CombatSim.simulate(seed, party_a, party_b)
##   # result.events is the timestamped event log (schema: core/README.md)
##
## Timeline model: "active-wait" ATB. Every living unit's gauge fills at a rate
## proportional to Spd. When one is full, that unit acts; while an action plays
## (its `duration`) the timeline is paused, so actions never overlap on screen.

const Rng = preload("res://core/rng.gd")
const GameData = preload("res://core/game_data.gd")
const Formation = preload("res://core/formation.gd")
const HeroStats = preload("res://core/hero_stats.gd")

const PHYS := 0
const MAGIC := 1


class Unit:
	var uid := 0
	var side := 0
	var name := ""
	var class_id := ""
	var base_class := ""
	var tier := ""
	var level := 1
	var col := 0
	var row := 0
	var hp := 1
	var max_hp := 1
	var atk := 1
	var def := 1
	var mag := 1
	var spd := 1
	var crit := 0.0
	var charge := 0
	var charge_on_act := 0
	var charge_on_hit := 0.0
	var charge_mult := 1.0
	var heal_mult := 1.0
	var gauge := 0
	var rate := 1
	var basic := ""
	var ability := ""
	var alive := true
	var label := ""
	# pre-formation stats, used to size the formation/composition effect on each hit
	var raw_atk := 1
	var raw_def := 1
	var raw_mag := 1
	# per stat: the formation/composition source with the largest effect, and its display name
	var src_tag := {}
	var src_name := {}
	# per stat: every formation/composition contribution [source, name, value] (for formation_proc)
	var contribs := {}
	var roles: Array = []      # "front"/"back" + shape roles (post, tip, keeper, flanker, gap, middle)
	var in_shape := true       # part of the shape that fights (a locked shape's fallback covers only some)
	var draw := 0              # 1 = draws nearby melee (gap), 2 = taunts all melee (Lighthouse post)
	var dmg_taken := 1.0       # Keeper's Ring cost
	var cover_target := -1     # Vigil covering fire: uid this unit's next basic action targets
	var draw_effect := ""      # cue effect when this unit draws an attack ("draws_melee" / "taunt")
	var inert := false         # the Crystal: never acts, never "stands" for KO / fight end
	var span := 1              # rows occupied (the Crystal spans 2)
	var mem: Dictionary = {}   # Crystal memory behaviour {id, ...} ({} for heroes / monsters)
	var mem_id := ""
	var stand_used := false    # Lumari knight's last stand


var _rng: Rng
var _c: Dictionary
var _units: Array[Unit] = []
var _sides: Array = [[], []]
var _events: Array = []
var _log := true
var _now := 0
var _sd_ticks := 0
var _gauge_max := 100000
var _charge_max := 100
var _seed := 0
# Crystal of Remembrance (06-crystal-of-remembrance.md)
var _crystal: Unit = null
var _mem_queue: Array = []     # memory ids still to be released (start + one per fragment)
var _mem_pending: Array = []   # released but waiting for a free slot: [id, reason]
var _frags := 0
var _shard_won := false
var _sd_next := 0
var _fallen_memories := 0
var _ferry_count := 0
var _mirror := ""              # Weaver: "guard" / "strike" (from the heroes' formation behaviour)
var _dimmed_beh: Dictionary = {}   # heroes' behaviour saved while the Keeper dims the lantern
const GUARD_BEHAVIOURS := ["hearthguard", "brace", "share_the_blow", "echo_step", "guardian", "keepers_ring",
	"scattered", "hold_the_door", "shoulder_to_shoulder"]
# hot tuning values, cached from _c at fight start
var _k_scale := 1.0
var _k_brm := 0.5
var _k_crit := 1.5
var _k_crit_on := true
var _k_var := 0.0
var _k_fm_thr := 0.1
var _k_jump := true
var _alive := [0, 0]
# formations (05-formations.md): effective shape and behaviour per side
var _shape: Array = [{}, {}]
var _beh: Array = [{}, {}]
var _guard_uses := [0, 0]
var _cur_melee := false        # the resolving action is a melee attack
var _cur_actor: Unit = null
var _cur_splash := false       # the resolving action also hits several units (no Brace/Share then)
var _after_start: Array = []   # behaviour cues/charges that belong right after action_start
var _drawn: Array = []         # [unit, effect]: this action's target was drawn / taunted onto it
var _ring_skip := -1           # Keeper's Ring kept this action off the keeper (uid)
var _beh_last := {}            # "side|effect" -> last behaviour cue time (ms)
const SPLASH := ["primary_adjacent", "other_enemies", "primary_column_rest"]
static var _act_info := {}      # action id -> [is_melee, hits several units], computed once
var _bid: Array[String] = ["", ""]   # behaviour id per side (cached from _beh)
var _cur_ability := false      # an ability is resolving (cascade cap)
var _proc_last := {}           # "side|source|stat" -> last formation_proc time (ms)
var _proc_at := -1             # time (ms) of the last formation_proc: at most one per instant
var _pend_t := -1              # instant whose formation_proc candidates are being collected
var _pend: Array = []          # candidates [unit, stat, trigger] at _pend_t
var _pend_blocked := false     # a hit at _pend_t carries a formation tag: no cue at this instant


## party_a / party_b: party dictionaries ({"heroes": [...]}) or Echo dictionaries.
## options:
##   "log": bool (default true)    -- false skips building events (faster)
##   "tuning": Dictionary          -- overrides keys of Tuning.COMBAT (tests)
## The final chamber: `party` against the Crystal of Remembrance.
## crystal: {"integrity": int (default Memories.CRYSTAL), "memories": [memory ids] (default
## Memories.DEFAULT_SEQUENCE): one released at the start and one at each of fragments 1-3}.
static func simulate_crystal(seed_value: int, party: Dictionary, crystal: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var opts := options.duplicate()
	opts["crystal"] = crystal
	return simulate(seed_value, party, {"heroes": []}, opts)


static func simulate(seed_value: int, party_a: Dictionary, party_b: Dictionary, options: Dictionary = {}) -> Dictionary:
	var sim := new()
	return sim._run(seed_value, party_a, party_b, options)


func _run(seed_value: int, party_a: Dictionary, party_b: Dictionary, options: Dictionary) -> Dictionary:
	var errs: Array[String] = []
	for e in GameData.validate_party(party_a):
		errs.append("side 0: " + e)
	var crystal_opts: Variant = options.get("crystal", null)
	if crystal_opts == null:
		for e in GameData.validate_party(party_b):
			errs.append("side 1: " + e)
	else:
		if not (crystal_opts is Dictionary):
			errs.append("crystal option must be a Dictionary")
		else:
			for mid: Variant in (crystal_opts as Dictionary).get("memories", []):
				if not (mid is String) or not GameData.Memories.MEMORIES.has(String(mid)):
					errs.append("unknown memory %s" % var_to_str(mid))
	if not errs.is_empty():
		return {"error": errs, "winner": -1, "events": []}

	_seed = seed_value
	_rng = Rng.new(seed_value)
	_log = bool(options.get("log", true))
	var over: Dictionary = options.get("tuning", {})
	_c = GameData.combat()   # read-only const; copied only when a test overrides keys
	if not over.is_empty():
		_c = _c.duplicate()
		for k: String in over:
			_c[k] = over[k]
	_gauge_max = int(_c["gauge_max"])
	_charge_max = int(_c["charge_max"])
	_k_scale = float(_c["damage_scale"])
	_k_brm = float(_c["back_row_phys_mult"])
	_k_crit = float(_c["crit_mult"])
	_k_crit_on = bool(_c["crit_enabled"])
	_k_var = float(_c["damage_variance"])
	_k_fm_thr = float(_c["formation_mod_threshold"])
	_k_jump = bool(_c["full_charge_jumps_queue"])

	var side_info: Array = [_build_side(0, party_a), _build_crystal_side(crystal_opts) if crystal_opts != null else _build_side(1, party_b)]
	# initial gauges (seeded, in stable unit order)
	var gmin := float(_c["initial_gauge_min"])
	var gmax := float(_c["initial_gauge_max"])
	var spread := int(_c["start_charge_spread"])
	for u in _units:
		if u.inert:
			continue
		u.gauge = int(_gauge_max * _rng.float_range(gmin, gmax))
		u.charge = clampi(u.charge + _rng.int_range(-spread, spread), 0, _charge_max - 1)
	var volley: Array = []
	for u in _units:   # Choir / Lumari Chorus: the back row starts with fuller gauges
		var b: Dictionary = _beh[u.side]
		if String(b["id"]) == "opening_volley" and u.col == 1 and u.in_shape:
			u.gauge = mini(int(_gauge_max * 0.95), u.gauge + int(_gauge_max * float(b["gauge"])))
			volley.append(u)

	if _log:
		var sides_ev: Array = []
		for s in 2:
			var info: Dictionary = side_info[s]
			var units_ev: Array = []
			for u: Unit in _sides[s]:
				units_ev.append(_unit_snapshot(u))
			info["units"] = units_ev
			sides_ev.append(info)
		_emit(0, {"type": "fight_start", "seed": seed_value, "data_version": GameData.Tuning.DATA_VERSION,
			"sudden_death_at": _sec(int(_c["sudden_death_start_ms"])),
			"gauge_fill_per_spd": float(_c["fill_per_spd_per_ms"]) * 1000.0 / float(_gauge_max),
			"sides": sides_ev})
		for s in 2:
			var info2: Dictionary = side_info[s]
			_emit(0, {"type": "formation", "side": s, "formation": info2["formation"], "compositions": info2["compositions"]})
		for u in _units:
			for _c_entry in u.contribs.get("hp_pct", []):
				_proc(u, "hp_pct", "start", 0)   # one cue per side/source (rate-limited)
		for u: Unit in volley:
			_beh_cue(u, "start", 0, -1, float(_beh[u.side]["gauge"]))
	if _crystal != null:
		_release_memory(0, "start")

	_now = int(_c["intro_ms"])
	_sd_next = int(_c["sudden_death_start_ms"])
	var sd_interval := int(_c["sudden_death_interval_ms"])
	var max_ms := int(_c["max_fight_ms"])
	var gap := int(_c["action_gap_ms"])

	while true:
		var alive0 := _alive_count(0)
		var alive1 := _alive_count(1)

		if _crystal != null:
			if alive0 == 0:
				return _finish(1, "wipe")
			if _shard_won:
				return _finish(0, "shard")
		elif alive0 == 0 or alive1 == 0:
			var w := -1
			if alive0 > 0:
				w = 0
			elif alive1 > 0:
				w = 1
			return _finish(w, "wipe")
		if _now >= max_ms:
			return _finish(1 if _crystal != null else _hp_leader(), "timeout")


		# time until the next gauge fills
		var best_dt := 1 << 40
		for u in _units:
			if not u.alive or u.inert:
				continue
			var need := _gauge_max - u.gauge
			var dt := 0
			if need > 0:
				@warning_ignore("integer_division")
				dt = (need + u.rate - 1) / u.rate
			if dt < best_dt:
				best_dt = dt

		if _now + best_dt >= _sd_next and (best_dt > 0 or not _ready_pending()):
			var run := maxi(0, _sd_next - _now)
			_advance(run)
			_now = maxi(_now, _sd_next)
			var fired_at := _now
			var outcome := _sudden_death_tick()
			_sd_next = fired_at + sd_interval   # from when the tick actually fired
			if outcome != -2:
				return _finish(outcome, "fading")
			continue

		_advance(best_dt)
		_now += best_dt
		# actor: fullest gauge, then higher Spd, then lower uid (stable)
		var actor: Unit = null
		for u in _units:
			if not u.alive or u.inert or u.gauge < _gauge_max:
				continue
			if actor == null or _acts_before(u, actor):
				actor = u
		actor.gauge = 0
		var dur := _do_action(actor)
		_now += dur
		if _side_down(0) or _side_down(1) or _shard_won:
			continue  # loop head ends the fight at action end (no gap)
		_now += gap
	return {}


## The Crystal's side: just the Crystal (2 middle back slots); memories spawn into it.
func _build_crystal_side(opts: Dictionary) -> Dictionary:
	var cd: Dictionary = GameData.Memories.CRYSTAL
	var c := Unit.new()
	c.uid = _units.size()
	c.side = 1
	c.name = "Crystal of Remembrance"
	c.label = c.name
	c.class_id = "crystal"
	c.base_class = "crystal"
	c.tier = "crystal"
	c.col = 1
	c.row = 1
	c.span = 2
	c.inert = true
	c.max_hp = int(opts.get("integrity", cd["integrity"]))
	c.hp = c.max_hp
	c.atk = 1
	c.def = int(cd["def"])
	c.mag = int(cd["mag"])
	c.raw_def = c.def
	c.raw_mag = c.mag
	c.spd = 1
	c.roles = ["back"]
	_units.append(c)
	_sides[1].append(c)
	_crystal = c
	_mem_queue = (opts.get("memories", GameData.Memories.DEFAULT_SEQUENCE) as Array).duplicate()
	var chamber := {"id": "crystal_chamber", "name": "Crystal of Remembrance",
		"bonus": [], "behaviour": {"id": "none", "name": "Crystal", "text": "It never acts. Memories surface from it as it cracks."},
		"cost": {"text": "", "mods": []}}
	_shape[1] = chamber
	_beh[1] = chamber["behaviour"]
	_bid[1] = "none"
	return {"side": 1, "name": "Crystal of Remembrance",
		"formation": {"id": "crystal_chamber", "name": "Crystal of Remembrance", "shape": "crystal_chamber",
			"shape_name": "Crystal of Remembrance", "state": "none", "sub_cells": [], "locked": false, "buffs": [], "debuffs": [],
			"behaviour": {"id": "none", "name": "Crystal", "text": chamber["behaviour"]["text"]}, "cost": ""},
		"compositions": []}


## Releases the next queued memory (at the start and at fragments 1-3).
func _release_memory(t: int, reason: String) -> void:
	if _mem_queue.is_empty():
		return
	_spawn_memory(String(_mem_queue.pop_front()), t, reason)


## Spawns a memory into the first free enemy slot: front column (rows 1, 2, 0, 3), then the back
## corners. With no free slot it waits and surfaces when a memory falls.
func _spawn_memory(id: String, t: int, reason: String) -> void:
	var taken := {}
	for o: Unit in _sides[1]:
		if o.alive:
			for k in o.span:
				taken[o.col * 4 + o.row + k] = true
	var slot: Array = []
	for cell: Array in [[0, 1], [0, 2], [0, 0], [0, 3], [1, 0], [1, 3]]:
		if not taken.has(int(cell[0]) * 4 + int(cell[1])):
			slot = cell
			break
	if slot.is_empty():
		_mem_pending.append([id, reason])
		return
	var cdef := GameData.get_class_def(id)
	var u := Unit.new()
	u.uid = _units.size()
	u.side = 1
	u.class_id = id
	u.mem_id = id
	u.mem = cdef["behaviour"]
	u.base_class = "memory"
	u.tier = "memory"
	u.name = String(cdef["name"])
	var n := 1
	for o: Unit in _sides[1]:
		if o.name == u.name:
			n += 1
	u.label = u.name if n == 1 else "%s %d" % [u.name, n]
	u.level = 1
	u.col = int(slot[0])
	u.row = int(slot[1])
	u.roles = ["front" if u.col == 0 else "back"]
	var st := HeroStats.compute({"class": id, "level": 1, "items": {}})
	u.max_hp = int(st["hp"])
	u.hp = u.max_hp
	u.atk = int(st["atk"])
	u.def = int(st["def"])
	u.mag = int(st["mag"])
	u.spd = int(st["spd"])
	u.raw_atk = u.atk
	u.raw_def = u.def
	u.raw_mag = u.mag
	u.crit = float(cdef["crit"])
	u.charge_on_act = int(round(float(cdef["charge_on_act"]) * float(_c["charge_act_scale"])))
	u.charge_on_hit = float(cdef["charge_on_hit"]) * float(_c["charge_hit_scale"])
	u.basic = String(cdef["basic"])
	u.ability = String(cdef["ability"])
	u.rate = maxi(1, u.spd * int(_c["fill_per_spd_per_ms"]))
	u.gauge = int(_gauge_max * _rng.float_range(float(_c["initial_gauge_min"]), float(_c["initial_gauge_max"])))
	u.charge = clampi(int(cdef.get("start_charge", 0)) + int(_c["start_charge_bonus"]) \
		+ _rng.int_range(-int(_c["start_charge_spread"]), int(_c["start_charge_spread"])), 0, _charge_max - 1)
	_units.append(u)
	_sides[1].append(u)
	_alive[1] += 1
	if _log:
		_emit(t, {"type": "spawn", "side": 1, "uid": u.uid, "slot": [u.col, u.row], "unit": _unit_snapshot(u),
			"memory": id, "chapter": int(cdef["chapter"]), "lore": String(cdef["lore"]), "reason": reason})
	match String(u.mem["id"]):
		"mirror":   # copies the heroes' formation: guarding shapes make her sturdy, attacking ones sharp
			_mirror = "guard" if GUARD_BEHAVIOURS.has(_bid[0]) else "strike"
		"dim_lantern":
			if _dimmed_beh.is_empty() and _bid[0] != "none":
				_dimmed_beh = {0: _beh[0], 1: _bid[0]}
				_beh[0] = {"id": "dimmed", "name": "Dimmed", "text": "The Keeper has dimmed the lantern."}
				_bid[0] = "dimmed"


## Each 25% of integrity lost breaks a fragment; fragments 1-3 release a memory, the 4th frees the Shard.
func _check_fragments(t: int) -> void:
	var total := int(GameData.Memories.CRYSTAL["fragments"])
	var lost := _crystal.max_hp - maxi(0, _crystal.hp)
	@warning_ignore("integer_division")
	var n := mini(total, lost * total / _crystal.max_hp)
	while _frags < n:
		_frags += 1
		if _log:
			_emit(t, {"type": "crystal_fragment", "index": _frags, "integrity": maxi(0, _crystal.hp),
				"max_integrity": _crystal.max_hp})
		if _frags >= total:
			_shard_won = true
		else:
			_release_memory(t, "fragment")


## A memory's behaviour happening right now, on the memory doing it (same truth rule as formation
## cues). Emitted as formation_proc with source "memory:<id>".
func _mem_cue(u: Unit, trigger: String, t: int, related: int, value: float) -> void:
	if not _log or u.mem.is_empty():
		return
	var effect := String(u.mem["id"])
	var key := "m%d|%s" % [u.uid, effect]
	if _beh_last.has(key) and t - int(_beh_last[key]) < int(_c["behaviour_cue_interval_ms"]):
		return
	_beh_last[key] = t
	_proc_at = t
	_emit(t, {"type": "formation_proc", "side": u.side, "uid": u.uid, "source": "memory:" + u.mem_id,
		"name": u.name, "stat": "", "effect": effect, "value": value, "sign": "buff", "trigger": trigger, "related": related})


## A side has nothing left to fight: no unit standing and (for the Crystal side) no Crystal.
func _side_down(side: int) -> bool:
	return _alive[side] == 0 and (_crystal == null or _crystal.side != side)


## A fully charged unit is waiting for its (immediate) turn: sudden death waits for it.
func _ready_pending() -> bool:
	for u in _units:
		if u.alive and u.charge >= _charge_max and u.gauge >= _gauge_max:
			return true
	return false


## Queue order among ready units: fully charged first, then fullest gauge, higher Spd, lower uid.
func _acts_before(u: Unit, other: Unit) -> bool:
	var uc := u.charge >= _charge_max
	var oc := other.charge >= _charge_max
	if uc != oc:
		return uc
	if u.gauge != other.gauge:
		return u.gauge > other.gauge
	return u.spd > other.spd


# ---------------------------------------------------------------- setup

func _build_side(side: int, party: Dictionary) -> Dictionary:
	var heroes: Array = party["heroes"].duplicate()
	heroes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["slot"][0]) * 10 + int(a["slot"][1]) < int(b["slot"][0]) * 10 + int(b["slot"][1]))
	var cells: Array = []
	var bases: Array = []
	for h: Dictionary in heroes:
		cells.append([int(h["slot"][0]), int(h["slot"][1])])
		var cdef := GameData.get_class_def(String(h["class"]))
		if String(cdef["tier"]) != "monster":
			bases.append(String(cdef["base"]))
	var fx := Formation.effective({"heroes": heroes, "unlocked_formations": Formation.unlocked_of(party)})
	var shape: Dictionary = fx["effective"]
	var geo: Dictionary = fx["shape"]
	var state := String(fx["state"])
	# who the fighting shape applies to: everyone (active / strays), the fallback's heroes, or nobody
	var members: Array = []
	if state == "active" or state == "strays":
		members = cells
	elif state == "locked_fallback":
		members = fx["sub_cells"]
	var sub_roles := Formation.roles(String(shape["id"]), members)
	var roles: Array = []
	for c: Array in cells:
		var k := members.find(c)
		roles.append(sub_roles[k] if k >= 0 else ["front" if int(c[0]) == 0 else "back"])
	var beh_def: Dictionary = shape["behaviour"]
	if beh_def.is_empty():
		beh_def = {"id": "none", "name": "", "text": ""}
	_shape[side] = shape
	_beh[side] = beh_def
	_bid[side] = String(beh_def["id"])
	_guard_uses[side] = int(beh_def.get("uses", 0))
	var comps := Formation.compositions(bases)
	var hi := 0

	for h: Dictionary in heroes:
		var cid := String(h["class"])
		var cdef := GameData.get_class_def(cid)
		var u := Unit.new()
		u.roles = roles[hi]
		u.in_shape = members.has(cells[hi])
		hi += 1
		u.uid = _units.size()
		u.side = side
		u.class_id = cid
		u.base_class = String(cdef["base"])
		u.tier = String(cdef["tier"])
		u.name = String(h.get("name", cdef["name"]))
		u.level = clampi(int(h.get("level", 1)), 1, GameData.max_level(cid))
		u.col = int(h["slot"][0])
		u.row = int(h["slot"][1])
		u.crit = float(cdef["crit"])
		u.charge_on_act = int(round(float(cdef["charge_on_act"]) * float(_c["charge_act_scale"])))
		u.charge = clampi(int(cdef.get("start_charge", 0)) + int(_c["start_charge_bonus"]), 0, _charge_max - 1)
		u.charge_on_hit = float(cdef["charge_on_hit"]) * float(_c["charge_hit_scale"])
		u.basic = String(cdef["basic"])
		u.ability = String(cdef["ability"])
		var st := HeroStats.compute(h)
		# collect multiplicative modifiers
		var pct := {"hp_pct": 0.0, "atk_pct": 0.0, "def_pct": 0.0, "mag_pct": 0.0, "spd_pct": 0.0,
			"crit_add": 0.0, "charge_pct": 0.0, "heal_pct": 0.0, "dmg_taken_pct": 0.0}
		var mods: Array = []
		if u.in_shape:   # the shape's bonus and cost apply to the heroes forming it
			for m: Dictionary in shape["bonus"]:
				mods.append([m, "formation:" + String(shape["id"]), "", String(shape["name"])])
			for m: Dictionary in shape["cost"]["mods"]:
				mods.append([m, "formation:" + String(shape["id"]), "", String(shape["name"])])
		for comp: Dictionary in comps:
			for m: Dictionary in comp["mods"]:
				mods.append([m, "comp:" + String(comp["id"]), String(comp["when"].get("base", "")), String(comp["name"])])
		var best := {}
		for entry: Array in mods:
			var m: Dictionary = entry[0]
			if not _scope_applies(m, u, entry):
				continue
			var stat := String(m["stat"])
			var val := float(m["value"])
			pct[stat] = float(pct[stat]) + val
			if absf(val) >= float(_c["formation_proc_min"]):   # smaller: fight-start banner only
				if not u.contribs.has(stat):
					u.contribs[stat] = []
				(u.contribs[stat] as Array).append([String(entry[1]), String(entry[3]), val,
					"%d|%s|%s" % [side, entry[1], stat]])
			if absf(val) > float(best.get(stat, 0.0)):
				best[stat] = absf(val)
				u.src_tag[stat] = String(entry[1])
				u.src_name[stat] = String(entry[3])
		u.raw_atk = int(st["atk"])
		u.raw_def = int(st["def"])
		u.raw_mag = int(st["mag"])
		u.max_hp = maxi(1, floori(float(st["hp"]) * (1.0 + float(pct["hp_pct"]))))
		u.hp = u.max_hp
		u.atk = maxi(1, floori(float(st["atk"]) * (1.0 + float(pct["atk_pct"]))))
		u.def = maxi(1, floori(float(st["def"]) * (1.0 + float(pct["def_pct"]))))
		u.mag = maxi(1, floori(float(st["mag"]) * (1.0 + float(pct["mag_pct"]))))
		u.spd = maxi(1, floori(float(st["spd"]) * (1.0 + float(pct["spd_pct"]))))
		u.crit = clampf(u.crit + float(pct["crit_add"]), 0.0, 1.0)
		u.charge_mult = maxf(0.0, 1.0 + float(pct["charge_pct"]))
		u.heal_mult = maxf(0.0, 1.0 + float(pct["heal_pct"]))
		u.dmg_taken = maxf(0.0, 1.0 + float(pct["dmg_taken_pct"]))
		if String(shape["cost"].get("draw", "")) == "gap" and u.roles.has("gap"):
			u.draw = 1
			u.draw_effect = "draws_melee"
		if bool(beh_def.get("taunt", false)) and u.roles.has("post"):
			u.draw = 2
			u.draw_effect = "taunt"
		if u.roles.has("tip"):   # Shardpoint cost: the tip draws every melee hit
			u.draw = 2
			u.draw_effect = "draws_melee"
		u.rate = maxi(1, u.spd * int(_c["fill_per_spd_per_ms"]))
		_units.append(u)
		_sides[side].append(u)
		_alive[side] += 1

	# unique display labels per side: duplicates become "Name 2", "Name 3"...
	var seen := {}
	for u: Unit in _sides[side]:
		var n := int(seen.get(u.name, 0)) + 1
		seen[u.name] = n
		u.label = u.name if n == 1 else "%s %d" % [u.name, n]
	var comp_ev: Array = []
	for comp: Dictionary in comps:
		comp_ev.append({"id": comp["id"], "name": comp["name"], "mods": comp["mods"]})
	return {"side": side, "name": String(party.get("name", "Side %d" % side)),
		"formation": {"id": shape["id"], "name": shape["name"], "shape": geo["id"], "shape_name": geo["name"],
			"state": state, "sub_cells": (fx["sub_cells"] as Array).duplicate(true),
			"locked": bool(fx["locked"]), "buffs": shape["bonus"], "debuffs": shape["cost"]["mods"],
			"behaviour": {"id": beh_def["id"], "name": beh_def["name"], "text": beh_def["text"]},
			"cost": String(shape["cost"]["text"])},
		"compositions": comp_ev}


static func _scope_applies(m: Dictionary, u: Unit, entry: Array) -> bool:
	match String(m["scope"]):
		"all":
			return true
		"front":
			return u.col == 0
		"back":
			return u.col == 1
		"class":
			return String(entry[2]) == u.base_class
	return u.roles.has(String(m["scope"]))   # shape roles: post, tip, keeper, flanker, gap, middle


func _unit_snapshot(u: Unit) -> Dictionary:
	var cname := u.name if u.inert else String(GameData.get_class_def(u.class_id)["name"])
	return {"uid": u.uid, "side": u.side, "name": u.name, "label": u.label, "class": u.class_id, "class_name": cname,
		"span": u.span,
		"base_class": u.base_class, "tier": u.tier, "level": u.level, "col": u.col, "row": u.row,
		"hp": u.hp, "max_hp": u.max_hp, "atk": u.atk, "def": u.def, "mag": u.mag, "spd": u.spd,
		"crit": snappedf(u.crit, 0.001), "charge": u.charge, "charge_max": _charge_max,
		"gauge": snappedf(float(u.gauge) / float(_gauge_max), 0.001),
		"basic": {"id": u.basic, "name": String(GameData.get_action(u.basic).get("name", ""))},
		"ability": {"id": u.ability, "name": String(GameData.get_action(u.ability).get("name", ""))}}


# ---------------------------------------------------------------- timeline

func _advance(dt: int) -> void:
	if dt <= 0:
		return
	for u in _units:
		if u.alive and not u.inert:
			u.gauge += u.rate * dt


func _alive_count(side: int) -> int:
	return _alive[side]


func _hp_frac(side: int) -> float:
	var hp := 0
	var mx := 0
	for u: Unit in _sides[side]:
		hp += u.hp
		mx += u.max_hp
	return float(hp) / float(maxi(1, mx))


func _hp_leader() -> int:
	var a := _hp_frac(0)
	var b := _hp_frac(1)
	if a > b:
		return 0
	if b > a:
		return 1
	return -1


func _finish(winner: int, reason: String) -> Dictionary:
	_flush_procs()
	var survivors: Array = []
	for u in _units:
		if u.alive:
			survivors.append(u.uid)
	if _log:
		var surv := survivors.duplicate()
		if _crystal != null:
			surv.erase(_crystal.uid)
		_emit(_now, {"type": "fight_end", "winner": winner, "reason": reason, "survivors": surv, "fragments": _frags})
	if _crystal != null:
		survivors.erase(_crystal.uid)   # the Crystal never counts as standing
	return {"winner": winner, "reason": reason, "duration": _sec(_now), "duration_ms": _now,
		"sudden_death_ticks": _sd_ticks, "survivors": survivors, "seed": _seed, "fragments": _frags,
		"data_version": GameData.Tuning.DATA_VERSION, "events": _events}


func _sec(ms: int) -> float:
	return float(ms) / 1000.0


func _emit(ms: int, ev: Dictionary) -> void:
	if _pend_t >= 0 and ms != _pend_t:
		_flush_procs()   # cues of an earlier instant go out before any later event
	ev["t"] = float(ms) / 1000.0
	_events.append(ev)


# ---------------------------------------------------------------- sudden death

## Returns -2 if the fight continues, otherwise the winner (-1 draw).
func _sudden_death_tick() -> int:
	_sd_ticks += 1
	var pct := float(_c["sudden_death_hp_pct_per_tick"]) * _sd_ticks
	var tick_ms := int(_c["sudden_death_tick_ms"])
	var hit_t := _now + (tick_ms >> 1)
	var before := [_hp_frac(0), _hp_frac(1)]
	if _log:
		_emit(_now, {"type": "sudden_death", "tick": _sd_ticks, "hp_pct": snappedf(pct, 0.001),
			"damage_mult": _sd_damage_mult(), "heal_mult": _sd_heal_mult(), "duration": _sec(tick_ms)})
	# if this tick wipes both sides, both sides' numbers land together (the screen matches the result)
	var survives := [false, false]
	for u in _units:
		if u.alive and not u.inert and u.hp > maxi(1, ceili(u.max_hp * pct)):
			survives[u.side] = true
	var stagger := int(_c["sudden_death_side_stagger_ms"]) if (survives[0] or survives[1]) else 0
	for u in _units:
		if not u.alive or u.inert:   # the Fading erodes the fighters, not the Crystal
			continue
		var dmg := maxi(1, ceili(u.max_hp * pct))
		var dealt := mini(dmg, u.hp)
		u.hp -= dealt
		if _log:
			_emit(hit_t + u.side * stagger, {"type": "damage", "src": -1, "dst": u.uid,
				"amount": dmg, "kind": "sudden_death", "crit": false, "mods": [{"id": "sudden_death", "mult": 1.0}],
				"primary": {"id": "sudden_death", "mult": 1.0}, "hp": u.hp, "action": ""})
		if u.hp <= 0:
			_ko(u, -1, hit_t + u.side * stagger)
	_now += tick_ms
	var a0 := _alive_count(0)
	var a1 := _alive_count(1)
	if _crystal != null:   # the Crystal fight only ends when the party falls (or the Shard breaks)
		if a0 > 0:
			_now += int(_c["action_gap_ms"])
			return -2
		return 1
	if a0 > 0 and a1 > 0:
		_now += int(_c["action_gap_ms"])
		return -2
	if a0 > 0:
		return 0
	if a1 > 0:
		return 1
	# mutual wipe: the side that was healthier before the tick wins
	if float(before[0]) > float(before[1]):
		return 0
	if float(before[1]) > float(before[0]):
		return 1
	return -1


func _sd_damage_mult() -> float:
	return 1.0 + float(_c["sudden_death_dmg_mult_per_tick"]) * _sd_ticks


func _sd_heal_mult() -> float:
	return maxf(0.0, 1.0 - float(_c["sudden_death_heal_mult_per_tick"]) * _sd_ticks)


# ---------------------------------------------------------------- actions

## Performs one action, returns its duration in ms.
func _do_action(u: Unit) -> int:
	var use_ability := u.charge >= _charge_max
	var aid := u.ability if use_ability else u.basic
	var a := GameData.get_action(aid)
	var sel := String(a["target"])
	var skip_heal := use_ability and _heal_ability(a) and (not _any_wounded(u.side) or _sd_heal_mult() <= 0.0)
	if skip_heal:
		sel = "melee"   # nobody hurt: the smite rider is the whole action
	_cur_actor = u
	if not _act_info.has(aid):
		var multi := false
		for eff: Dictionary in a["effects"]:
			var to := String(eff.get("to", "primary"))
			if SPLASH.has(to) or to == "all_enemies" or to == "front_enemies" or int(eff.get("hits", 1)) > 1:
				multi = true
		_act_info[aid] = [_is_melee(a), multi]
	var info: Array = _act_info[aid]
	_cur_melee = info[0]
	_after_start = []
	_drawn = []
	_ring_skip = -1
	var primary := _select(u, sel)
	if primary != null and primary.side != u.side:
		var single_target := String(a.get("area", _area_of(sel))) == "single"
		if _cur_melee or single_target:
			primary = _apply_draw(u, primary, _cur_melee)   # melee = physical melee-targeted or a dash
	_cur_splash = info[1]
	var taunted := not _drawn.is_empty() and String(_drawn[1]) == "taunt"
	if not use_ability and u.cover_target >= 0:
		var ct := _units[u.cover_target]
		# a Lighthouse taunt wins over covering fire: the lit post draws the attack
		if ct.alive and ct.side != u.side and _target_side(u, sel) != u.side and _area_of(sel) == "single" \
				and not _ring_protected(ct) and not taunted:
			if ct != primary:
				primary = ct
				_after_start.append([u, "turn", ct.uid, 1.0, "covering_fire"])
		u.cover_target = -1
	var dur := int(round(float(a["duration"]) * 1000.0))
	var imp := int(round(float(a["impact"]) * 1000.0))
	var t_imp := _now + imp
	if _log:
		var gauges: Array = []
		for o in _units:
			gauges.append(snappedf(float(mini(o.gauge, _gauge_max)) / float(_gauge_max), 0.001) if o.alive else 0.0)
		gauges[u.uid] = 1.0
		_emit(_now, {"type": "action_start", "uid": u.uid, "action": aid, "name": a["name"],
			"kind": "ability" if use_ability else "basic", "anim": "cast" if skip_heal else a.get("anim", ""),
			"target": primary.uid if primary != null else -1,
			"target_side": _target_side(u, sel), "area": "single" if skip_heal else String(a.get("area", _area_of(sel))),
			"duration": _sec(dur), "impact": _sec(t_imp), "gauges": gauges})
	_proc(u, "spd_pct", "turn", _now)
	for cue: Array in _after_start:
		_beh_cue(cue[0], cue[1], _now, int(cue[2]), float(cue[3]), String(cue[4]))
	_after_start = []
	var mid := String(u.mem.get("id", ""))
	if mid == "hasten_fading":
		_sd_next = maxi(_now + 1, _sd_next - int(u.mem["ms"]))
		_mem_cue(u, "turn", _now, -1, float(u.mem["ms"]) / 1000.0)
	elif mid == "dim_lantern" and not _dimmed_beh.is_empty():
		_mem_cue(u, "turn", _now, -1, 1.0)
	# Shardpoint: the tip gains charge whenever an ally behind it acts
	if _bid[u.side] == "shardpoint" and u.col == 1 and u.in_shape:
		for tip: Unit in _sides[u.side]:
			if tip.alive and tip.roles.has("tip") and tip.col == 0 and tip.charge < _charge_max:
				_gain_charge(tip, int(_beh[u.side]["charge"]), "effect", _now)
				_beh_cue(tip, "charge", _now, u.uid, float(_beh[u.side]["charge"]))
	_cur_ability = use_ability
	if use_ability:
		var old := u.charge
		u.charge = 0
		if _log:
			_emit(_now, {"type": "ability", "uid": u.uid, "action": aid, "name": a["name"]})
			_emit(_now, {"type": "charge", "uid": u.uid, "charge": 0, "delta": -old, "reason": "spent", "ready": false, "queue": 0})

	for eff: Dictionary in a["effects"]:
		if skip_heal and String(eff["op"]) == "heal":
			continue
		_apply_effect(u, a, eff, primary if not skip_heal else null, t_imp, aid)

	_cur_ability = false
	_cur_melee = false
	if not use_ability and u.alive:
		_gain_charge(u, int(round(u.charge_on_act * u.charge_mult)), "act", t_imp)
	_flush_procs()
	return dur


static func _heal_ability(a: Dictionary) -> bool:
	for eff: Dictionary in a["effects"]:
		if String(eff["op"]) == "heal":
			return true
	return false


func _any_wounded(side: int) -> bool:
	for o: Unit in _sides[side]:
		if o.alive and o.hp < o.max_hp:
			return true
	return false


static func _area_of(sel: String) -> String:
	if sel == "all_enemies" or sel == "all_allies":
		return sel
	return "single"


static func _target_side(u: Unit, sel: String) -> int:
	if sel == "lowest_hp_ally" or sel == "all_allies" or sel == "self":
		return u.side
	return 1 - u.side


func _apply_effect(u: Unit, a: Dictionary, eff: Dictionary, primary: Unit, t: int, aid: String) -> void:
	var op := String(eff["op"])
	var to := String(eff.get("to", "primary"))
	var hits := int(eff.get("hits", 1))
	for _h in hits:
		if not u.alive and op != "charge":
			return
		var targets := _resolve(u, a, to, primary)
		if op == "damage" and SPLASH.has(to) and not targets.is_empty() and primary != null \
				and _bid[targets[0].side] == "scattered":
			# Strays: splash only spreads between units standing next to each other (the struck
			# unit's edge-connected group); scattered units are spared. Cued on the struck primary.
			var group := _connected_group(primary)
			var kept: Array[Unit] = []
			for tg in targets:
				if group.has(tg.uid):
					kept.append(tg)
			if kept.size() < targets.size() and primary.alive:
				_beh_cue(primary, "defend", t, u.uid, 1.0)
			targets = kept
		for tgt in targets:
			match op:
				"damage":
					if tgt.alive:
						_damage(u, tgt, eff, t, aid)
				"heal":
					if tgt.alive:
						_heal(u, tgt, float(eff["power"]), t, aid)
				"charge":
					if tgt.alive:
						_gain_charge(tgt, int(eff["amount"]), "effect", t)
		if _side_down(1 - u.side) or _shard_won:
			return


func _resolve(u: Unit, a: Dictionary, to: String, primary: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	var foes: Array = _sides[1 - u.side]
	match to:
		"primary":
			var p := primary
			if p == null or not p.alive:
				p = _select(u, String(a["target"]))
			if p != null and p.alive:
				out.append(p)
		"primary_adjacent":
			if primary != null:
				for o: Unit in _sides[primary.side]:
					if o.alive and o.col == primary.col and (o.row + o.span == primary.row or o.row == primary.row + primary.span):
						out.append(o)
		"primary_column_rest":
			if primary != null:
				for o: Unit in _sides[primary.side]:
					if o.alive and o.col == primary.col and o != primary:
						out.append(o)
		"melee_enemy":
			var m := _select(u, "melee")
			if m != null:
				out.append(m)
		"other_enemies":
			for o: Unit in foes:
				if o.alive and o != primary:
					out.append(o)
		"primary_column":
			if primary != null:
				for o: Unit in _sides[primary.side]:
					if o.alive and o.col == primary.col:
						out.append(o)
		"all_enemies":
			for o: Unit in foes:
				if o.alive:
					out.append(o)
		"front_enemies":
			var col := _melee_col(foes)
			for o: Unit in foes:
				if o.alive and o.col == col:
					out.append(o)
		"front_random":
			var col2 := _melee_col(foes)
			var pool: Array[Unit] = []
			for o: Unit in foes:
				if o.alive and o.col == col2:
					pool.append(o)
			if not pool.is_empty():
				out.append(pool[_rng.int_range(0, pool.size() - 1)])
		"random_enemy":
			var pool2: Array[Unit] = []
			for o: Unit in foes:
				if o.alive and not _ring_protected(o):   # Keeper's Ring: the keeper can't be single-targeted
					pool2.append(o)
			if not pool2.is_empty():
				out.append(pool2[_rng.int_range(0, pool2.size() - 1)])
		"self":
			out.append(u)
		"all_allies":
			for o: Unit in _sides[u.side]:
				if o.alive and not o.inert:
					out.append(o)
		"lowest_hp_ally":
			var w := _lowest_ally(u)
			if w != null:
				out.append(w)
	return out


# ---------------------------------------------------------------- targeting

func _select(u: Unit, sel: String) -> Unit:
	var foes: Array = _sides[1 - u.side]
	match sel:
		"melee":
			return _nearest_in_col(foes, _melee_col(foes), u.row)
		"back_first":
			var col := 1 if _col_alive(foes, 1) else 0
			var pick := _nearest_in_col(foes, col, u.row)
			if pick != null and _ring_protected(pick):
				# Keeper's Ring: the keeper can't be targeted; next nearest back unit, else the front
				var others: Array = []
				for o: Unit in foes:
					if o != pick:
						others.append(o)
				var alt := _nearest_in_col(others, 1, u.row)
				if alt == null:
					alt = _nearest_in_col(others, 0, u.row)
				if _cur_actor == u:
					_ring_skip = pick.uid
				return alt
			return pick
		"lowest_hp_enemy":
			var best: Unit = null
			var any: Unit = null
			for o: Unit in foes:
				if o.alive and (any == null or o.hp < any.hp):
					any = o
				if o.alive and not _ring_protected(o) and (best == null or o.hp < best.hp):
					best = o
			if best != any and any != null and _cur_actor == u:
				_ring_skip = any.uid   # cued on the unit hit instead, as it takes the blow
			return best
		"random_enemy":
			var pool: Array[Unit] = []
			for o: Unit in foes:
				if o.alive and not _ring_protected(o):
					pool.append(o)
			if pool.is_empty():
				return null
			return pool[_rng.int_range(0, pool.size() - 1)]
		"lowest_hp_ally":
			return _lowest_ally(u)
		"self":
			return u
		"all_enemies", "all_allies":
			return null
	return _nearest_in_col(foes, _melee_col(foes), u.row)


## Front column if anyone there is standing, else back.
static func _melee_col(foes: Array) -> int:
	return 0 if _col_alive(foes, 0) else 1


static func _col_alive(foes: Array, col: int) -> bool:
	for o: Unit in foes:
		if o.alive and o.col == col:
			return true
	return false


## Same row, else nearest occupied row; equal distance -> the upper (lower index) row.
static func _nearest_in_col(foes: Array, col: int, row: int) -> Unit:
	var best: Unit = null
	var best_d := 99
	for o: Unit in foes:
		if not o.alive or o.col != col:
			continue
		var d := absi(o.row - row) if o.span == 1 else mini(absi(o.row - row), absi(o.row + o.span - 1 - row))
		if d < best_d or (d == best_d and o.row < best.row):
			best = o
			best_d = d
	return best


func _lowest_ally(u: Unit) -> Unit:
	var best: Unit = null
	var best_f := 2.0
	for o: Unit in _sides[u.side]:
		if not o.alive or o.inert:
			continue
		var f := float(o.hp) / float(o.max_hp)
		if f < best_f:
			best = o
			best_f = f
	return best


# ---------------------------------------------------------------- effects

func _damage(src: Unit, dst: Unit, eff: Dictionary, t: int, aid: String) -> void:
	var magic := String(eff["kind"]) == "magic"
	var splash := SPLASH.has(String(eff.get("to", "primary")))
	var guarded: Unit = null
	# Lamplight guardian: the front unit intercepts the first ranged/magic hit on its back partner
	if _guard_uses[dst.side] > 0 and dst.col == 1 and dst.in_shape and not _cur_splash and (magic or not _cur_melee):
		for g: Unit in _sides[dst.side]:
			if g.alive and g.in_shape and g.col == 0 and g.row == dst.row:
				_guard_uses[dst.side] -= 1
				guarded = dst
				dst = g
				break
	var ferried: Unit = null
	if dst.inert and not _cur_splash:
		for f: Unit in _sides[dst.side]:
			if f.alive and String(f.mem.get("id", "")) == "shield_crystal":
				_ferry_count += 1
				if _ferry_count % int(f.mem["every"]) == 0:
					ferried = f
					dst = f
				break
	var a := float(src.mag if magic else src.atk)
	var d := float(dst.mag if magic else dst.def)
	var k_scale := float(eff["power"]) * _k_scale
	var base := k_scale * a * a / (a + d)
	var mods: Array = []
	if _log:
		var fm := _formation_mod(src, dst, magic, a, d)
		if not fm.is_empty():
			mods.append(fm)
	if not magic:
		var brm := _k_brm
		if src.col == 1:
			base *= brm
			mods.append({"id": "back_row_attacker", "mult": brm})
		if dst.col == 1:
			base *= brm
			mods.append({"id": "back_row_target", "mult": brm})
	var beh_src: Dictionary = _beh[src.side]
	var beh_dst: Dictionary = _beh[dst.side]
	var bs := _bid[src.side]
	var bd := _bid[dst.side]
	var beh_cues: Array = []
	if bs == "flank" and src.roles.has("flanker") and src.col == 1 and dst.row == src.row:
		base *= 1.0 + float(beh_src["dmg"])
		mods.append({"id": "flank", "mult": 1.0 + float(beh_src["dmg"])})
		beh_cues.append([src, "attack", dst.uid, float(beh_src["dmg"]), "flank"])
	if bd == "hearthguard" and dst.roles.has("post") and dst.col == 0:
		var allies := 0
		for o: Unit in _sides[dst.side]:
			if o.alive and o.in_shape and o.col == 1:
				allies += 1
		if allies > 0:
			var hg := maxf(0.0, 1.0 - float(beh_dst["per_ally"]) * allies)
			base *= hg
			mods.append({"id": "hearthguard", "mult": snappedf(hg, 0.01)})
			beh_cues.append([dst, "defend", src.uid, snappedf(1.0 - hg, 0.01), "hearthguard"])
	if splash and bd == "echo_step" and dst.in_shape:
		base *= float(beh_dst["splash"])
		mods.append({"id": "echo_step", "mult": float(beh_dst["splash"])})
		beh_cues.append([dst, "defend", src.uid, float(beh_dst["splash"]), "echo_step"])
	if splash and magic and bs == "opening_volley" and beh_src.has("splash") and src.in_shape:
		base *= 1.0 + float(beh_src["splash"])
		mods.append({"id": "chorus_splash", "mult": 1.0 + float(beh_src["splash"])})
		beh_cues.append([src, "attack", dst.uid, float(beh_src["splash"]), "chorus_splash"])
	if dst.dmg_taken != 1.0:
		base *= dst.dmg_taken
	# Crystal memories
	var mem_cues: Array = []
	if String(src.mem.get("id", "")) == "harvest" and _fallen_memories > 0:
		var hm := 1.0 + float(src.mem["per_fallen"]) * _fallen_memories
		base *= hm
		mods.append({"id": "harvest", "mult": hm})
		mem_cues.append([src, "attack", dst.uid, hm - 1.0])
	if _mirror == "strike" and String(src.mem.get("id", "")) == "mirror":
		base *= 1.0 + float(src.mem["amount"])
		mods.append({"id": "mirror", "mult": 1.0 + float(src.mem["amount"])})
		mem_cues.append([src, "attack", dst.uid, float(src.mem["amount"])])
	if _mirror == "guard" and String(dst.mem.get("id", "")) == "mirror":
		base *= 1.0 - float(dst.mem["amount"])
		mods.append({"id": "mirror", "mult": 1.0 - float(dst.mem["amount"])})
		mem_cues.append([dst, "defend", src.uid, float(dst.mem["amount"])])
	if ferried != null:
		mem_cues.append([ferried, "defend", _crystal.uid, 1.0])
	if guarded != null:
		beh_cues.append([dst, "defend", guarded.uid, 1.0, "guardian"])
	if eff.has("bonus_below_hp"):
		var b: Array = eff["bonus_below_hp"]
		if float(dst.hp) < float(b[0]) * float(dst.max_hp):
			base *= float(b[1])
			mods.append({"id": "execute", "mult": float(b[1])})
	var crit_roll := _rng.next_float()   # always drawn, so disabling crits keeps the RNG stream aligned
	var crit_chance := src.crit
	if bs == "flank" and src.roles.has("flanker") and src.col == 1 and dst.row == src.row:
		crit_chance += float(beh_src["crit"])
	var crit := _k_crit_on and crit_roll < crit_chance
	if crit:
		base *= _k_crit
	var v := _k_var
	base *= 1.0 + _rng.float_range(-v, v)
	if _sd_ticks > 0:
		base *= _sd_damage_mult()
		mods.append({"id": "sudden_death", "mult": _sd_damage_mult()})
	var amount := maxi(1, int(round(base)))
	# Tidebreak brace / Seawall share the blow: part of the hit passes to front neighbours
	var shares: Array = []
	var single := not _cur_splash
	if not single:
		pass   # shares only pass on single-target hits (keeps an area attack to one number per unit)
	elif dst.col == 0 and bd == "brace" and dst.roles.has("middle"):
		for o: Unit in _sides[dst.side]:
			if o.alive and o.in_shape and o.col == 0 and absi(o.row - dst.row) == 1:
				shares.append([o, maxi(1, int(round(amount * float(beh_dst["share"])))), "brace", float(beh_dst["share"])])
	elif dst.col == 0 and bd == "share_the_blow" and dst.in_shape:
		var nxt: Unit = null
		for o: Unit in _sides[dst.side]:
			if o.alive and o.in_shape and o.col == 0 and o.row == dst.row + 1:
				nxt = o
		if nxt == null:
			for o: Unit in _sides[dst.side]:
				if o.alive and o.in_shape and o.col == 0 and o.row == dst.row - 1:
					nxt = o
		if nxt != null:
			shares.append([nxt, maxi(1, int(round(amount * float(beh_dst["share"])))), "share_the_blow", float(beh_dst["share"])])
	for sh: Array in shares:
		amount = maxi(1, amount - int(sh[1]))
	var stand := false
	if String(dst.mem.get("id", "")) == "last_stand" and not dst.stand_used and amount >= dst.hp:
		stand = true   # Lumari knight: the first felling blow leaves her at 1 HP
		dst.stand_used = true
	var dealt := mini(amount, dst.hp - (1 if stand else 0))
	dst.hp -= dealt
	if _log:
		_emit(t, {"type": "damage", "src": src.uid, "dst": dst.uid, "amount": amount,
			"kind": "magic" if magic else "physical", "crit": crit, "mods": mods,
			"primary": _primary_mod(crit, mods), "hp": dst.hp, "action": aid})
		for bc: Array in beh_cues:
			_beh_cue(bc[0], bc[1], t, int(bc[2]), float(bc[3]), String(bc[4]))
		if not _drawn.is_empty() and _drawn[0] == dst and src == _cur_actor:
			_beh_cue(dst, "defend", t, src.uid, 1.0, String(_drawn[1]))
			_drawn = []
		if _ring_skip >= 0 and src == _cur_actor and dst.side == _units[_ring_skip].side:
			_beh_cue(dst, "defend", t, _ring_skip, 1.0, "keepers_ring")
			_ring_skip = -1
		if not shares.is_empty():
			_beh_cue(dst, "defend", t, src.uid, float((shares[0] as Array)[3]), String((shares[0] as Array)[2]))
		if not mods.is_empty() and String((mods[0] as Dictionary)["id"]) == "formation":
			_pend_at(t)
			_pend_blocked = true   # no cue at an instant whose hit already shows a formation tag
		if not src.contribs.is_empty() or not dst.contribs.is_empty():
			if crit:
				_proc(src, "crit_add", "crit", t)
			_proc(src, "mag_pct" if magic else "atk_pct", "attack", t)
			_proc(dst, "mag_pct" if magic else "def_pct", "defend", t)
			_proc(dst, "dmg_taken_pct", "defend", t)
	for mc: Array in mem_cues:
		_mem_cue(mc[0], mc[1], t, int(mc[2]), float(mc[3]))
	if dst.inert:
		_check_fragments(t)
	elif dst.hp <= 0:
		_ko(dst, src.uid, t)
	elif stand:
		_gain_charge(dst, _charge_max, "effect", t)
		_mem_cue(dst, "defend", t, src.uid, 1.0)
	elif dealt > 0:
		var gain := int(round(float(dealt) * 100.0 / float(dst.max_hp) * dst.charge_on_hit * dst.charge_mult))
		_gain_charge(dst, gain, "hit", t)
	# The Draw: its basic attacks pull charge out of the most charged hero
	if String(src.mem.get("id", "")) == "draw_memory" and not _cur_ability and src.alive:
		var rich: Unit = null
		for h: Unit in _sides[1 - src.side]:
			if h.alive and not h.inert and h.charge > 0 and (rich == null or h.charge > rich.charge):
				rich = h
		if rich != null:
			var amt := mini(int(src.mem["amount"]), rich.charge)
			rich.charge -= amt
			if _log:
				_emit(t, {"type": "charge", "uid": rich.uid, "charge": rich.charge, "delta": -amt, "reason": "drain",
					"ready": false, "queue": 0})
			_gain_charge(src, amt, "effect", t)
			_mem_cue(src, "attack", t, rich.uid, float(amt))
	for sh: Array in shares:
		_side_hit(src, sh[0], int(sh[1]), "magic" if magic else "physical", String(sh[2]), float(sh[3]), t, aid,
			not magic and src.col == 1)
	# Kindred shoulder to shoulder / Vigil covering fire react to melee hits
	if _cur_melee and src.side != dst.side and dst.in_shape:
		var bid := bd
		if bid == "shoulder_to_shoulder" or bid == "covering_fire":
			for o: Unit in _sides[dst.side]:
				if o != dst and o.alive and o.in_shape:
					if bid == "shoulder_to_shoulder" and o.charge < _charge_max:
						_gain_charge(o, int(beh_dst["charge"]), "effect", t)
						_beh_cue(o, "charge", t, dst.uid, float(beh_dst["charge"]))
					elif bid == "covering_fire":
						o.cover_target = src.uid
	if eff.has("drain") and src.alive and dealt > 0:
		var amt := int(round(float(dealt) * float(eff["drain"]) * _sd_heal_mult()))
		_apply_heal(src, src, amt, t, aid)


## Damage passed on by Brace / Share the blow: a plain number on the neighbour, tagged with its cause.
func _side_hit(src: Unit, dst: Unit, amount: int, kind: String, id: String, share: float, t: int, aid: String,
		back_attacker: bool) -> void:
	if not dst.alive:
		return
	var dealt := mini(amount, dst.hp)
	dst.hp -= dealt
	if _log:
		var m := {"id": id, "mult": share}
		var mods: Array = [m]
		if back_attacker:   # the share comes out of a hit that was already halved at the source
			mods.append({"id": "back_row_attacker", "mult": _k_brm})
		_emit(t, {"type": "damage", "src": src.uid, "dst": dst.uid, "amount": amount, "kind": kind, "crit": false,
			"mods": mods, "primary": m.duplicate(), "hp": dst.hp, "action": aid})
	if dst.hp <= 0:
		_ko(dst, src.uid, t)
	elif dealt > 0:
		_gain_charge(dst, int(round(float(dealt) * 100.0 / float(dst.max_hp) * dst.charge_on_hit * dst.charge_mult)), "hit", t)


## uids of the living units edge-connected (through living units) to `start` on its side.
func _connected_group(start: Unit) -> Dictionary:
	var seen := {start.uid: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var c: Unit = stack.pop_back()
		for o: Unit in _sides[c.side]:
			if o.alive and not seen.has(o.uid) and absi(o.col - c.col) + absi(o.row - c.row) == 1:
				seen[o.uid] = true
				stack.append(o)
	return seen


## Melee = a physical attack aimed by melee targeting, or a dash (Backstab / Execute).
static func _is_melee(a: Dictionary) -> bool:
	if String(a.get("anim", "")) == "dash":
		return true
	if String(a["target"]) != "melee":
		return false
	for eff: Dictionary in a["effects"]:
		if String(eff["op"]) == "damage":
			return String(eff["kind"]) == "physical"
	return false


## Keeper's Ring: the keeper can't be targeted by melee while all three front units stand.
func _ring_protected(o: Unit) -> bool:
	if not o.roles.has("keeper") or _bid[o.side] != "keepers_ring":
		return false   # (single-target selection only: area splash still reaches the keeper)
	var front := 0
	for f: Unit in _sides[o.side]:
		if f.alive and f.in_shape and f.col == 0:
			front += 1
	return front >= 3


## Keystone / Crescent gap units draw nearby melee; the Shardpoint tip draws all melee; the
## Lighthouse post taunts all melee and also single-target ranged and magic attacks.
func _apply_draw(u: Unit, primary: Unit, melee: bool) -> Unit:
	for o: Unit in _sides[primary.side]:
		if o == primary or not o.alive or o.draw == 0:
			continue
		if not melee and o.draw_effect != "taunt":
			continue
		if o.draw_effect == "taunt" and _bid[o.side] == "dimmed":
			continue   # the Keeper has dimmed the lantern: the lit post's taunt goes dark
		if o.draw == 2 or (o.col == primary.col and absi(o.row - u.row) <= absi(primary.row - u.row) + 1):
			_drawn = [o, o.draw_effect]   # cued on o as it takes the hit
			return o
	return primary


## A formation behaviour happening right now, on the unit doing it (truthful; rate-limited per
## side/effect so a repeating behaviour doesn't flood the screen). Suppresses stat cues at t.
func _beh_cue(u: Unit, trigger: String, t: int, related: int, value: float, effect: String = "") -> void:
	if not _log:
		return
	var b: Dictionary = _beh[u.side]
	if effect == "":
		effect = String(b["id"])
	var key := "%d|%s" % [u.side, effect]
	if _beh_last.has(key) and t - int(_beh_last[key]) < int(_c["behaviour_cue_interval_ms"]):
		return
	_beh_last[key] = t
	_proc_at = t
	var shape: Dictionary = _shape[u.side]
	_emit(t, {"type": "formation_proc", "side": u.side, "uid": u.uid, "source": "formation:" + String(shape["id"]),
		"name": String(shape["name"]), "stat": "", "effect": effect, "value": value,
		"sign": "debuff" if effect == "draws_melee" else "buff",
		"trigger": trigger, "related": related})


## The combined formation/composition effect on a hit, as one signed, sized modifier
## named after its dominant source; {} when it changes the hit by less than the threshold.
func _formation_mod(src: Unit, dst: Unit, magic: bool, a: float, d: float) -> Dictionary:
	var ra := float(src.raw_mag if magic else src.raw_atk)
	var rd := float(dst.raw_mag if magic else dst.raw_def)
	var raw := ra * ra / (ra + rd)
	var mult := (a * a / (a + d)) / raw
	if absf(mult - 1.0) < _k_fm_thr:
		return {}
	var off_effect := absf((a * a / (a + rd)) / raw - 1.0)
	var def_effect := absf((ra * ra / (ra + d)) / raw - 1.0)
	var who := src if off_effect >= def_effect else dst
	var stat := "mag_pct" if magic else ("atk_pct" if who == src else "def_pct")
	return {"id": "formation", "mult": snappedf(mult, 0.01), "source": String(who.src_tag.get(stat, "")),
		"name": String(who.src_name.get(stat, "")), "side": who.side}


func _heal_amount(src: Unit, power: float) -> float:
	return power * float(_c["heal_scale"]) * float(src.mag) * src.heal_mult * _sd_heal_mult()


func _heal(src: Unit, dst: Unit, power: float, t: int, aid: String) -> void:
	_apply_heal(src, dst, int(round(_heal_amount(src, power))), t, aid)
	if _log:
		_proc(src, "heal_pct", "heal", t)


## The single annotation a scene should show on this number, by priority:
## crit > execute > back row (back_row_attacker / back_row_target 0.5, back_row_both 0.25)
## > formation > sudden_death. {} = plain hit.
static func _primary_mod(crit: bool, mods: Array) -> Dictionary:
	if crit:
		return {"id": "crit", "mult": 1.5}
	var back := 1.0
	var has_back := false
	var found := {}
	var found_ids := {}
	for m: Dictionary in mods:
		var id := String(m["id"])
		if id == "back_row_attacker" or id == "back_row_target":
			back *= float(m["mult"])
			has_back = true
			found_ids[id] = true
		elif not found.has(id):
			found[id] = m
	for id: String in ["execute"]:
		if found.has(id):
			return {"id": id, "mult": float(found[id]["mult"])}
	if has_back:
		var who := "back_row_both"
		if not found_ids.has("back_row_target"):
			who = "back_row_attacker"
		elif not found_ids.has("back_row_attacker"):
			who = "back_row_target"
		return {"id": who, "mult": back}
	for id: String in ["formation", "sudden_death"]:
		if found.has(id):
			return (found[id] as Dictionary).duplicate()
	return {}


## One causing event -> at most one formation_proc cue: among the formation/composition
## contributions to `stat` on this unit, the largest |value| that is not rate-limited
## (once per side/source/stat every formation_proc_interval_ms; "start" cues once ever).
func _proc(u: Unit, stat: String, trigger: String, t: int) -> void:
	if not _log:
		return
	if t == 0:
		_proc_best([[u, stat, trigger]], t)   # fight-start cues: one per effect
		return
	if u.contribs.has(stat):
		for c: Array in u.contribs[stat]:
			if not _proc_last.has(c[3]):   # only effects not yet shown this fight are candidates
				_pend_at(t)
				_pend.append([u, stat, trigger])
				return


## Starts collecting cue candidates for instant t (flushing the previous instant first).
func _pend_at(t: int) -> void:
	if t != _pend_t:
		_flush_procs()
		_pend_t = t


## Emits at most one cue for the collected instant, unless a hit there carried a formation tag.
## Truth beats coverage: a cue only ever names a unit doing its trigger at that instant; effects
## that never get a truthful moment are surfaced by the fight-start banner (and t=0 start cues).
func _flush_procs() -> void:
	var cands := _pend
	var t := _pend_t
	var blocked := _pend_blocked
	_pend = []
	_pend_blocked = false
	_pend_t = -1
	if not cands.is_empty() and not blocked:
		_proc_best(cands, t)


## cands: [[unit, stat, trigger], ...] from one causing event; emits the single best cue.
func _proc_best(cands: Array, t: int) -> void:
	if not _log or (t == _proc_at and t > 0):
		return
	var interval := int(_c["formation_proc_interval_ms"])
	var best: Array = []
	var best_abs := -1.0
	for cand: Array in cands:
		var u: Unit = cand[0]
		var stat: String = cand[1]
		if not u.alive or not u.contribs.has(stat):
			continue
		for c: Array in u.contribs[stat]:
			var key: String = c[3]
			if _proc_last.has(key) and (cand[2] == "start" or t - int(_proc_last[key]) < interval):
				continue
			# effects not yet shown this fight first, then the biggest
			var score := absf(float(c[2])) + (0.0 if _proc_last.has(key) else 10.0)
			if score > best_abs:
				best_abs = score
				best = [u, stat, cand[2], c, key]
	if best.is_empty():
		return
	var bu: Unit = best[0]
	var bc: Array = best[3]
	_proc_last[best[4]] = t
	_proc_at = t
	var val := float(bc[2])
	_emit(t, {"type": "formation_proc", "side": bu.side, "uid": bu.uid, "source": bc[0], "name": bc[1],
		"stat": best[1], "effect": best[1], "value": val,
		"sign": ("debuff" if val > 0.0 else "buff") if best[1] == "dmg_taken_pct" else ("buff" if val > 0.0 else "debuff"),
		"trigger": best[2], "related": -1})


func _apply_heal(src: Unit, dst: Unit, amt: int, t: int, aid: String) -> void:
	var healed := mini(amt, dst.max_hp - dst.hp)
	if healed <= 0:
		return
	dst.hp += healed
	if _log:
		_emit(t, {"type": "heal", "src": src.uid, "dst": dst.uid, "amount": healed, "hp": dst.hp, "action": aid})
		if String(src.mem.get("id", "")) == "kindle" and dst != src:
			_mem_cue(src, "heal", t, dst.uid, float(healed))


func _gain_charge(u: Unit, amount: int, reason: String, t: int) -> void:
	if amount <= 0 or u.charge >= _charge_max or u.inert:
		return
	var old := u.charge
	var cap := _charge_max
	if reason == "hit" and _cur_ability:
		cap = _charge_max - 1   # cascade cap: an ability's hits can't ready another ability
	if old >= cap:
		return
	u.charge = mini(cap, u.charge + amount)
	if (reason == "act" or reason == "hit") and _log:
		_proc(u, "charge_pct", "charge", t)
	var ready := u.charge >= _charge_max
	var queue := 0
	if ready:
		for o in _units:   # fully charged units already waiting go first
			if o != u and o.alive and o.charge >= _charge_max and o.gauge >= _gauge_max:
				queue += 1
		if _k_jump:
			u.gauge = maxi(u.gauge, _gauge_max) + _gauge_max - queue   # acts after those already queued
	if _log:
		_emit(t, {"type": "charge", "uid": u.uid, "charge": u.charge, "delta": u.charge - old, "reason": reason,
			"ready": ready, "queue": queue})


func _ko(u: Unit, by: int, t: int) -> void:
	u.alive = false
	_alive[u.side] -= 1
	u.hp = 0
	u.gauge = 0
	if _log:
		_emit(t, {"type": "ko", "uid": u.uid, "by": by})
	if u.mem_id != "":
		_fallen_memories += 1
		if String(u.mem.get("id", "")) == "dim_lantern" and not _dimmed_beh.is_empty():
			_beh[1 - u.side] = _dimmed_beh[0]   # the lantern relights
			_bid[1 - u.side] = _dimmed_beh[1]
			_dimmed_beh = {}
		if not _mem_pending.is_empty():
			var nxt: Array = _mem_pending.pop_front()
			_spawn_memory(String(nxt[0]), t, String(nxt[1]))
	# Vault Door hold the door: the back unit in the fallen front unit's row steps into its slot
	if u.col == 0 and _bid[u.side] == "hold_the_door" and u.in_shape:
		for o: Unit in _sides[u.side]:
			if o.alive and o.in_shape and o.col == 1 and o.row == u.row:
				o.col = 0
				if _log:
					_emit(t, {"type": "formation_move", "side": o.side, "uid": o.uid, "from": [1, o.row], "to": [0, o.row],
						"source": "formation:" + String(_shape[o.side]["id"]), "effect": "hold_the_door", "replaces": u.uid})
				break
