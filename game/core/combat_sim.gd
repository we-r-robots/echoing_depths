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
	# timed statuses and summons (data/statuses.gd, core/README.md "Statuses")
	var statuses: Array = []   # active status Dictionaries (see _add_status)
	var hidden := false        # a "hidden" status is active: single-target selectors skip it
	var stunned := false       # a "stun" status is active: its turns are lost
	var f_atk := 1             # stats after formation/composition, before statuses (statuses scale these)
	var f_def := 1
	var f_mag := 1
	var f_spd := 1
	var summon := ""           # "" | "echo" | "husk": summons never count as standing or toward shapes
	var summoner := -1         # uid of the unit that summoned / raised it
	var ko_seq := -1           # order it fell in (Rekindler: first fallen; Gravecaller: most recent)
	var raised := false        # already raised as a husk or rekindled (each fallen unit returns once)
	var revive_used := false   # Rekindler: once per fight


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
# timed statuses (data/statuses.gd)
var _st: Dictionary = {}       # Statuses.TUNING
var _st_count := 0             # statuses active on all units (0 = skip the status scan)
var _st_owned := 0             # of those, applied by an ability (ruling 4: the caster gains no charge)
var _followups: Array = []     # [unit, action id]: an ability's second half, due now (Unseen Warden)
var _ko_n := 0                 # KO counter (ko_seq)
var _cur_followup := false     # a follow-up action is resolving (its effects count as the ability's)
var _in_status := false        # status ticks are resolving (their hit charge stops at 99, like an ability's)
var _shown_hit := {}           # uid -> ms of the last hit on it that showed a number (Scattered cue truth)


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
	_st = GameData.Statuses.TUNING
	for k: String in over:   # tests may override status tuning through the same "tuning" option
		if _st.has(k):
			if _st == GameData.Statuses.TUNING:
				_st = _st.duplicate()
			_st[k] = over[k]

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
	# tests and tools: units that start hurt, and statuses already on units (core/README.md "Options")
	for sh: Dictionary in options.get("start_hp", []):
		var hu := _unit_at(int(sh["side"]), sh["slot"])
		if hu != null:
			hu.hp = clampi(int(sh["hp"]), 1, hu.max_hp)
	for ss: Dictionary in options.get("start_statuses", []):
		var dst := _unit_at(int(ss["side"]), ss["slot"])
		var src := dst
		if ss.has("src_slot"):
			src = _unit_at(int(ss.get("src_side", ss["side"])), ss["src_slot"])
		if dst != null and src != null:
			_add_status(dst, String(ss["status"]), src, ss, 0, "", bool(ss.get("from_ability", false)))
	if _crystal != null:
		_release_memory(0, "start")

	_now = int(_c["intro_ms"])
	_sd_next = int(_c["sudden_death_start_ms"])
	var sd_interval := int(_c["sudden_death_interval_ms"])
	var max_ms := int(_c["max_fight_ms"])
	var gap := int(_c["action_gap_ms"])

	while true:
		# statuses due by now (ticks, spreads, expiries) land between actions
		if _st_count > 0 and _next_status_ms() <= _now:
			_process_statuses()
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
		# an ability's second half (Unseen Warden's arrest) plays as its own action, right away
		if not _followups.is_empty():
			var fu: Array = _followups.pop_front()
			var fu_unit: Unit = fu[0]
			if fu_unit.alive:
				_now += _do_action(fu_unit, String(fu[1]))
				if not (_side_down(0) or _side_down(1) or _shard_won):
					_now += gap
			continue

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

		# a status tick or expiry comes before the next turn: run the clock to it
		if _st_count > 0:
			var st_due := _next_status_ms()
			if st_due < _now + best_dt and st_due < _sd_next:
				_advance(st_due - _now)
				_now = st_due
				continue
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
		if actor.stunned:
			# stunned: the turn is lost (a short beat on the timeline so it reads)
			var skip := int(_st["skip_ms"])
			if _log:
				_emit(_now, {"type": "skip", "uid": actor.uid, "reason": "stun", "duration": _sec(skip)})
			_now += skip + gap
			continue
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
	_set_base_stats(c)
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
	_set_base_stats(u)
	u.gauge = int(_gauge_max * _rng.float_range(float(_c["initial_gauge_min"]), float(_c["initial_gauge_max"])))
	u.charge = clampi(int(cdef.get("start_charge", 0)) + int(_c["start_charge_bonus"]) \
		+ _rng.int_range(-int(_c["start_charge_spread"]), int(_c["start_charge_spread"])), 0, _charge_max - 1)
	_units.append(u)
	_sides[1].append(u)
	_alive[1] += 1
	if _log:
		_emit(t, {"type": "spawn", "side": 1, "uid": u.uid, "slot": [u.col, u.row], "unit": _unit_snapshot(u),
			"memory": id, "chapter": int(cdef["chapter"]), "lore": String(cdef["lore"]), "reason": reason,
			"summon": "", "summoner": -1, "raised": -1})
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
		_set_base_stats(u)
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
		if u.summon != "":
			continue
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
		if u.alive and u.summon == "":   # summons are never survivors (they never count as standing)
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
		if u.alive and not u.inert and u.summon == "" and u.hp > maxi(1, ceili(u.max_hp * pct)):
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
## followup: an ability's second half (an action id), played as its own action: shown as an
## ability, but it spends no charge (the first half already did).
func _do_action(u: Unit, followup := "") -> int:
	var use_ability := u.charge >= _charge_max and followup == ""
	var aid := u.ability if use_ability else u.basic
	if followup != "":
		aid = followup
	var a := GameData.get_action(aid)
	if use_ability and a.has("requires") and not _viable(u, a):
		aid = String(a["fallback"])   # nothing for the ability to work on: its fallback instead
		a = GameData.get_action(aid)
	var sel := String(a["target"])
	var skip_heal := use_ability and _heal_ability(a) and not bool(a.get("always", false)) and _has_damage(a) \
		and (not _any_wounded(u.side) or _sd_heal_mult() <= 0.0)
	if skip_heal:
		sel = "melee"   # nobody hurt: the smite rider is the whole action
	_cur_actor = u
	if not _act_info.has(aid):
		var multi := false
		for eff: Dictionary in a["effects"]:
			var to := String(eff.get("to", "primary"))
			if SPLASH.has(to) or to == "all_enemies" or to == "front_enemies" or to == "column_sweep" or int(eff.get("hits", 1)) > 1:
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
		if ct.alive and not ct.hidden and ct.side != u.side and _target_side(u, sel) != u.side and _area_of(sel) == "single" \
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
			"kind": "ability" if use_ability or followup != "" else "basic", "anim": "cast" if skip_heal else a.get("anim", ""),
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
				if _gain_charge(tip, int(_beh[u.side]["charge"]), "effect", _now):
					_beh_cue(tip, "charge", _now, u.uid, float(_beh[u.side]["charge"]))
	_cur_ability = use_ability or followup != ""
	_cur_followup = followup != ""
	if use_ability:
		var old := u.charge
		u.charge = 0
		if _log:
			_emit(_now, {"type": "ability", "uid": u.uid, "action": aid, "name": a["name"]})
			_emit(_now, {"type": "charge", "uid": u.uid, "charge": 0, "delta": -old, "reason": "spent", "ready": false, "queue": 0})
	elif followup != "" and _log:
		_emit(_now, {"type": "ability", "uid": u.uid, "action": aid, "name": a["name"]})

	for eff: Dictionary in a["effects"]:
		if skip_heal and String(eff["op"]) == "heal":
			continue
		_apply_effect(u, a, eff, primary if not skip_heal else null, t_imp, aid)

	_cur_ability = false
	_cur_followup = false
	_cur_melee = false
	if not use_ability and followup == "" and u.alive:
		_gain_charge(u, int(round(u.charge_on_act * u.charge_mult)), "act", t_imp)
	_flush_procs()
	return dur


static func _has_damage(a: Dictionary) -> bool:
	for eff: Dictionary in a["effects"]:
		if String(eff["op"]) == "damage":
			return true
	return false


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
	if sel == "lowest_hp_ally" or sel == "all_allies" or sel == "self" or sel == "random_ally":
		return u.side
	return 1 - u.side


func _apply_effect(u: Unit, a: Dictionary, eff: Dictionary, primary: Unit, t: int, aid: String) -> void:
	var op := String(eff["op"])
	var to := String(eff.get("to", "primary"))
	var hits := int(eff.get("hits", 1))
	if to == "column_sweep":
		_column_sweep(u, eff, primary, t, aid)
		return
	var from_ability := _cur_ability
	for _h in hits:
		if not u.alive and op != "charge":
			return
		if op in ["link", "tithe", "summon", "raise", "revive"]:   # ops that pick their own units
			match op:
				"link":
					_link(u, eff, t, aid, from_ability)
				"tithe":
					_tithe(u, eff, t, aid)
				"summon":
					_summon_echo(u, eff, t)
				"raise":
					_raise_husk(u, eff, t)
				"revive":
					_revive(u, eff, t)
			continue
		var targets := _resolve(u, a, to, primary, eff)
		if op == "damage" and SPLASH.has(to) and not targets.is_empty() and primary != null \
				and _bid[targets[0].side] == "scattered":
			# Strays: splash only spreads between units standing next to each other (the struck
			# unit's edge-connected group); scattered units are spared. Cued on the struck primary.
			var group := _connected_group(primary)
			var kept: Array[Unit] = []
			for tg in targets:
				if group.has(tg.uid):
					kept.append(tg)
			if kept.size() < targets.size() and primary.alive and int(_shown_hit.get(primary.uid, -1)) == t:
				_beh_cue(primary, "defend", t, u.uid, 1.0)
			targets = kept
		for tgt in targets:
			if not tgt.alive:
				continue
			match op:
				"damage":
					_damage(u, tgt, eff, t, aid)
				"heal":
					_heal(u, tgt, float(eff["power"]), t, aid, eff)
				"charge":
					_gain_charge(tgt, int(eff["amount"]), "effect", t)
				"status":
					_add_status(tgt, String(eff["status"]), u, eff, t, aid, from_ability)
				"steal_charge":
					_steal_charge(u, tgt, int(eff["amount"]), t)
				"swap":
					_pull_forward(u, tgt, t)
				"gauge":
					_fill_gauge(u, tgt, float(eff["amount"]), t)
				"hp_cost":
					_pay_hp(tgt, u.uid, int(round(float(tgt.max_hp) * float(eff["pct"]))), t, aid, "cost")
				"boon_random":
					_random_boon(u, tgt, eff, t, aid, from_ability)
		if _side_down(1 - u.side) or _shard_won:
			return


func _resolve(u: Unit, a: Dictionary, to: String, primary: Unit, eff: Dictionary = {}) -> Array[Unit]:
	var out: Array[Unit] = []
	var foes: Array = _sides[1 - u.side]
	match to:
		"adjacent_allies":   # the effect's "adjacency": "edge" (4 sides) or "all" (8 around)
			var all8 := String(eff.get("adjacency", "edge")) == "all"
			for o: Unit in _sides[u.side]:
				if o.alive and not o.inert and o != u and _adjacent(o, u, all8):
					out.append(o)
		"column_allies":
			for o: Unit in _sides[u.side]:
				if o.alive and not o.inert and o.col == u.col:
					out.append(o)
		"other_allies":
			for o: Unit in _sides[u.side]:
				if o.alive and not o.inert and o != u:
					out.append(o)
		"primary_neighbours":   # every unit edge-adjacent to the primary on its side (both columns)
			if primary != null:
				for o: Unit in _sides[primary.side]:
					if o.alive and not o.inert and o != primary and _adjacent(o, primary, false):
						out.append(o)
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
				if o.alive and not o.hidden and o.col == col2:   # single picks: hidden units are skipped
					pool.append(o)
			if not pool.is_empty():
				out.append(pool[_rng.int_range(0, pool.size() - 1)])
		"random_enemy":
			var pool2: Array[Unit] = []
			for o: Unit in foes:
				if o.alive and not o.hidden and not _ring_protected(o):   # Keeper's Ring: the keeper can't be single-targeted
					pool2.append(o)
			if not pool2.is_empty():
				out.append(pool2[_rng.int_range(0, pool2.size() - 1)])
		"self":
			out.append(u)
		"most_charged_enemy", "highest_hp_enemy", "random_ally":
			var sel_u := _select(u, to)
			if sel_u != null:
				out.append(sel_u)
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
			if pick == null:
				pick = _nearest_in_col(foes, 1 - col, u.row)
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
				if not o.alive or o.hidden:
					continue
				if any == null or o.hp < any.hp:
					any = o
				if not _ring_protected(o) and (best == null or o.hp < best.hp):
					best = o
			if best != any and any != null and _cur_actor == u:
				_ring_skip = any.uid   # cued on the unit hit instead, as it takes the blow
			return best
		"random_enemy":
			var pool: Array[Unit] = []
			for o: Unit in foes:
				if o.alive and not o.hidden and not _ring_protected(o):
					pool.append(o)
			if pool.is_empty():
				return null
			return pool[_rng.int_range(0, pool.size() - 1)]
		"most_charged_enemy", "highest_hp_enemy":   # never the Crystal; ties -> lower uid
			var best2: Unit = null
			for o: Unit in foes:
				if not o.alive or o.hidden or o.inert or _ring_protected(o):
					continue
				var v := o.charge if sel == "most_charged_enemy" else o.hp
				var bv := -1 if best2 == null else (best2.charge if sel == "most_charged_enemy" else best2.hp)
				if v > bv:
					best2 = o
			return best2
		"column_bottom":   # Hexfire: the bottom unit of the back column (the front if the back is empty)
			var bcol := 1 if _col_alive(foes, 1) else 0
			var bot: Unit = null
			for o: Unit in foes:
				if o.alive and not o.hidden and not _ring_protected(o) and o.col == bcol \
					and (bot == null or o.row + o.span > bot.row + bot.span):
					bot = o
			return bot
		"random_ally":
			var pool3: Array[Unit] = []
			for o: Unit in _sides[u.side]:
				if o.alive and not o.inert:
					pool3.append(o)
			if pool3.is_empty():
				return null
			return pool3[_rng.int_range(0, pool3.size() - 1)]
		"lowest_hp_ally":
			return _lowest_ally(u)
		"self":
			return u
		"all_enemies", "all_allies":
			return null
	return _nearest_in_col(foes, _melee_col(foes), u.row)


## Front column if a visible unit stands there, else back (ruling 1: melee skips hidden front units
## to the nearest visible one, and reaches the back only when no visible front unit stands).
static func _melee_col(foes: Array) -> int:
	return 0 if _col_alive(foes, 0) else 1


## A visible (targetable) unit stands in this column.
static func _col_alive(foes: Array, col: int) -> bool:
	for o: Unit in foes:
		if o.alive and not o.hidden and o.col == col:
			return true
	return false


## Same row, else nearest occupied row; equal distance -> the upper (lower index) row. Hidden
## units are skipped.
static func _nearest_in_col(foes: Array, col: int, row: int) -> Unit:
	var best: Unit = null
	var best_d := 99
	for o: Unit in foes:
		if not o.alive or o.hidden or o.col != col:
			continue
		var d := absi(o.row - row) if o.span == 1 else mini(absi(o.row - row), absi(o.row + o.span - 1 - row))
		if d < best_d or (d == best_d and o.row < best.row):
			best = o
			best_d = d
	return best


## Lowest HP fraction on u's side. A branded ally (no healing reaches it) is passed over while
## anyone else can be picked, so a heal never aims at a unit it can't touch.
func _lowest_ally(u: Unit) -> Unit:
	var best: Unit = null
	var best_f := 2.0
	var branded: Unit = null
	for o: Unit in _sides[u.side]:
		if not o.alive or o.inert:
			continue
		if not o.statuses.is_empty() and _has_kind(o, "heal_block"):
			if branded == null:
				branded = o
			continue
		var f := float(o.hp) / float(o.max_hp)
		if f < best_f:
			best = o
			best_f = f
	return best if best != null else branded


# ---------------------------------------------------------------- effects

func _damage(src: Unit, dst: Unit, eff: Dictionary, t: int, aid: String) -> void:
	var magic := String(eff["kind"]) == "magic"
	if src.side != dst.side and src.statuses.size() > 0 and _has_kind(src, "blind") \
			and _rng.next_float() < float(_st["blind_miss"]):
		if _log:   # blinded: the hit misses (the RNG is only drawn while blinded)
			_emit(t, {"type": "miss", "src": src.uid, "dst": dst.uid, "action": aid, "reason": "blind"})
		return
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
		var fm := _formation_mod(src, dst, magic, float(src.f_mag if magic else src.f_atk), float(dst.f_mag if magic else dst.f_def))
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
	# damage link (Threadmender): the partner takes its share as its own number
	# (single-target hits only, like Brace: an area or multi-hit action keeps one number per unit)
	var linked := _link_partner(dst) if single else null
	var link_amt := 0
	if linked != null:
		link_amt = int(floor(float(amount) * float(_st["link_share"])))
		amount -= link_amt
	# a shield takes the hit before HP does (an "absorb" event; a fully absorbed hit shows no number)
	amount -= _absorb(dst, amount, src.uid, t)
	var stand := false
	if String(dst.mem.get("id", "")) == "last_stand" and not dst.stand_used and amount >= dst.hp:
		stand = true   # Lumari knight: the first felling blow leaves her at 1 HP
		dst.stand_used = true
	var dealt := mini(amount, dst.hp - (1 if stand else 0))
	dst.hp -= dealt
	if _log:
		var shown := amount > 0   # a fully absorbed hit shows no number, so it cues nothing
		if shown:
			_shown_hit[dst.uid] = t
			_emit(t, {"type": "damage", "src": src.uid, "dst": dst.uid, "amount": amount,
				"kind": "magic" if magic else "physical", "crit": crit, "mods": mods,
				"primary": _primary_mod(crit, mods), "hp": dst.hp, "action": aid})
			for bc: Array in beh_cues:
				_beh_cue(bc[0], bc[1], t, int(bc[2]), float(bc[3]), String(bc[4]))
		if not _drawn.is_empty() and _drawn[0] == dst and src == _cur_actor:
			if shown:
				_beh_cue(dst, "defend", t, src.uid, 1.0, String(_drawn[1]))
			_drawn = []
		if _ring_skip >= 0 and src == _cur_actor and dst.side == _units[_ring_skip].side:
			if shown:
				_beh_cue(dst, "defend", t, _ring_skip, 1.0, "keepers_ring")
			_ring_skip = -1
		if not shown:
			pass
		elif not shares.is_empty():
			_beh_cue(dst, "defend", t, src.uid, float((shares[0] as Array)[3]), String((shares[0] as Array)[2]))
		if not mods.is_empty() and String((mods[0] as Dictionary)["id"]) == "formation":
			_pend_at(t)
			_pend_blocked = true   # no cue at an instant whose hit already shows a formation tag
		if shown and (not src.contribs.is_empty() or not dst.contribs.is_empty()):
			if crit:
				_proc(src, "crit_add", "crit", t)
			_proc(src, "mag_pct" if magic else "atk_pct", "attack", t)
			_proc(dst, "mag_pct" if magic else "def_pct", "defend", t)
			_proc(dst, "dmg_taken_pct", "defend", t)
	if amount > 0:
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
	if linked != null and link_amt > 0:
		_side_hit(src, linked, link_amt, "magic" if magic else "physical", "link", float(_st["link_share"]), t, aid, false)
	# Kindred shoulder to shoulder / Vigil covering fire react to melee hits
	if _cur_melee and src.side != dst.side and dst.in_shape:
		var bid := bd
		if bid == "shoulder_to_shoulder" or bid == "covering_fire":
			for o: Unit in _sides[dst.side]:
				if o != dst and o.alive and o.in_shape:
					if bid == "shoulder_to_shoulder" and o.charge < _charge_max:
						if _gain_charge(o, int(beh_dst["charge"]), "effect", t):
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
	amount -= _absorb(dst, amount, src.uid, t)
	if amount <= 0:
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
			if o.alive and o.summon == "" and not seen.has(o.uid) and absi(o.col - c.col) + absi(o.row - c.row) == 1:
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
		if o == primary or not o.alive or o.draw == 0 or o.hidden:
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


func _heal(src: Unit, dst: Unit, power: float, t: int, aid: String, eff: Dictionary = {}) -> void:
	var amt := int(round(_heal_amount(src, power)))
	var missing := dst.max_hp - dst.hp
	if _apply_heal(src, dst, amt, t, aid) > 0 and _log:
		_proc(src, "heal_pct", "heal", t)
	# Lumenward: healing past full HP becomes a shield of that size
	if bool(eff.get("overheal_shield", false)) and dst.alive and amt > missing and not _has_kind(dst, "heal_block") \
			and not _has_kind(dst, "heal_invert"):
		_add_status(dst, "shield", src, {"amount": amt - missing, "dur_ms": int(eff.get("shield_ms", 6000))}, t, aid, _cur_ability)


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


## Returns the HP actually restored.
func _apply_heal(src: Unit, dst: Unit, amt: int, t: int, aid: String) -> int:
	if amt <= 0 or not dst.alive:
		return 0
	if dst.statuses.size() > 0:
		if _has_kind(dst, "heal_block"):   # Confessor's brand: no healing reaches it
			if _log:
				_emit(t, {"type": "miss", "src": src.uid, "dst": dst.uid, "action": aid, "reason": "heal_block"})
			return 0
		if _has_kind(dst, "heal_invert"):  # hexed: the healing hurts instead
			_status_damage(dst, src.uid, amt, t, aid, "heal_invert")
			return 0
	var healed := mini(amt, dst.max_hp - dst.hp)
	if healed <= 0:
		return 0
	dst.hp += healed
	if _log:
		_emit(t, {"type": "heal", "src": src.uid, "dst": dst.uid, "amount": healed, "hp": dst.hp, "action": aid})
		if String(src.mem.get("id", "")) == "kindle" and dst != src:
			_mem_cue(src, "heal", t, dst.uid, float(healed))
	return healed


## Returns true if any charge was gained.
func _gain_charge(u: Unit, amount: int, reason: String, t: int) -> bool:
	if amount <= 0 or u.charge >= _charge_max or u.inert or u.summon != "":
		return false
	if _st_count > 0 and (_has_kind(u, "charge_seal") or _charge_locked(u)):
		return false   # sealed, or its own ability's effect is still in play (ruling 4)
	var old := u.charge
	var cap := _charge_max
	if reason == "hit" and (_cur_ability or _in_status):
		cap = _charge_max - 1   # cascade cap: an ability's (or a status tick's) hits can't ready an ability
	if old >= cap:
		return false
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
	return true


func _ko(u: Unit, by: int, t: int) -> void:
	u.alive = false
	if u.summon == "":   # summons never count as standing
		_alive[u.side] -= 1
	u.hp = 0
	u.gauge = 0
	_ko_n += 1
	u.ko_seq = _ko_n
	if _log:
		_emit(t, {"type": "ko", "uid": u.uid, "by": by})
	if not u.statuses.is_empty():
		for st: Dictionary in u.statuses.duplicate():
			_end_status(u, st, t, "ko")
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



# ---------------------------------------------------------------- statuses (data/statuses.gd)

func _unit_at(side: int, slot: Array) -> Unit:
	for o: Unit in _sides[side]:
		if o.col == int(slot[0]) and o.row == int(slot[1]):
			return o
	return null


## Fight-start stats (after formation and composition) that statuses scale from.
func _set_base_stats(u: Unit) -> void:
	u.f_atk = u.atk
	u.f_def = u.def
	u.f_mag = u.mag
	u.f_spd = u.spd


## Re-derives Atk/Def/Mag/Spd and the gauge rate from the fight-start stats and the active
## stat (sap / boon) and slow statuses.
func _recalc(u: Unit) -> void:
	var mult := {"atk": 1.0, "def": 1.0, "mag": 1.0, "spd": 1.0}
	var slow := 1.0
	for st: Dictionary in u.statuses:
		match String(st["kind"]):
			"stat":
				var k := String(st["stat"])
				mult[k] = float(mult[k]) + float(st["value"])
			"slow":
				slow -= float(st["value"])
	var fl := float(_st["stat_floor"])
	u.atk = maxi(1, floori(u.f_atk * maxf(fl, float(mult["atk"]))))
	u.def = maxi(1, floori(u.f_def * maxf(fl, float(mult["def"]))))
	u.mag = maxi(1, floori(u.f_mag * maxf(fl, float(mult["mag"]))))
	u.spd = maxi(1, floori(u.f_spd * maxf(fl, float(mult["spd"]))))
	var fill := int(_c["fill_per_spd_per_ms"])
	if slow >= 1.0:
		u.rate = maxi(1, u.spd * fill)
	else:
		u.rate = maxi(1, int(round(float(u.spd * fill) * maxf(float(_st["slow_floor"]), slow))))


func _has_kind(u: Unit, kind: String) -> bool:
	for st: Dictionary in u.statuses:
		if String(st["kind"]) == kind:
			return true
	return false


func _find_status(u: Unit, key: String) -> Dictionary:
	for st: Dictionary in u.statuses:
		if String(st["key"]) == key:
			return st
	return {}


## Ruling 4: a unit gains no charge while an effect of its own ability is still in play (a status it
## applied with its ability, on anyone, or a summon it called that still stands).
func _charge_locked(u: Unit) -> bool:
	if _st_owned > 0:
		for o in _units:
			if not o.alive:
				continue
			for st: Dictionary in o.statuses:
				if int(st["owner"]) == u.uid:
					return true
	for o in _units:
		if o.alive and o.summoner == u.uid and o.summon != "":
			return true
	return false


## Applies (or stacks / refreshes) a status. eff: the effect entry, with "dur_ms" and per kind:
## "value" (stat / slow sizes), "stat" (sap / boon), "power" (dot and regen per-tick size, from the
## source's Mag; shields: Mag-scaled size) or "amount" (a shield of exactly this size), "spread_ms"
## (burn), "then" (an action id that follows when it expires), "partner" (link).
func _add_status(dst: Unit, id: String, src: Unit, eff: Dictionary, t: int, aid: String, from_ability: bool) -> void:
	if not dst.alive or dst.inert:
		return   # the Crystal takes no statuses
	var sd: Dictionary = GameData.Statuses.STATUSES[id]
	var kind := String(sd["kind"])
	var dur := int(eff.get("dur_ms", 3000))
	var stat := String(eff.get("stat", ""))
	var value := float(eff.get("value", 0.0))
	match kind:
		"dot":   # non-physical (ruling 2): Mag against Mag, no back-row halving
			var m := float(src.mag)
			value = maxf(1.0, round(float(eff.get("power", 0.3)) * _k_scale * m * m / (m + float(dst.mag))))
		"regen":
			value = maxf(1.0, round(float(eff.get("power", 0.3)) * float(_c["heal_scale"]) * float(src.mag) * src.heal_mult))
		"shield":
			if eff.has("amount"):
				value = float(eff["amount"])
			else:
				value = round(float(eff.get("power", 1.0)) * float(_c["heal_scale"]) * float(src.mag) * src.heal_mult)
			if value < 1.0:
				return
		"link":
			value = float(_st["link_share"])
	var key := id + (":" + stat if String(sd.get("keyed", "")) == "stat" else "")
	var owner := src.uid if from_ability and src != null else -1
	var cur := _find_status(dst, key)
	var st: Dictionary
	if not cur.is_empty() and String(sd["stack"]) != "replace":
		st = cur
		if String(sd["stack"]) == "stack":
			if int(st["stacks"]) < int(sd.get("max_stacks", 1)):
				st["stacks"] = int(st["stacks"]) + 1
				st["value"] = float(st["value"]) + value
			st["ends"] = maxi(int(st["ends"]), t + dur)
		else:   # refresh: the longer duration, the larger size
			st["ends"] = maxi(int(st["ends"]), t + dur)
			if absf(value) > absf(float(st["value"])):
				st["value"] = value
		if int(st["owner"]) != owner:   # the newest application owns it
			if int(st["owner"]) >= 0:
				_st_owned -= 1
			if owner >= 0:
				_st_owned += 1
			st["owner"] = owner
		st["src"] = src.uid
	else:
		if not cur.is_empty():
			_end_status(dst, cur, t, "replaced")
		st = {"id": id, "key": key, "kind": kind, "src": src.uid, "owner": owner, "start": t, "ends": t + dur,
			"value": value, "stat": stat, "stacks": 1, "tick": int(sd.get("tick", 0)), "next_tick": t + int(sd.get("tick", 0)),
			"spread_ms": int(eff.get("spread_ms", 0)), "next_spread": t + int(eff.get("spread_ms", 0)),
			"then": String(eff.get("then", "")), "partner": int(eff.get("partner", -1)), "action": aid}
		dst.statuses.append(st)
		_st_count += 1
		if owner >= 0:
			_st_owned += 1
	_status_flags(dst)
	if kind == "stat" or kind == "slow":
		_recalc(dst)
	if _log:
		_emit(t, {"type": "status", "uid": dst.uid, "status": id, "src": src.uid, "stat": stat,
			"value": snappedf(float(st["value"]), 0.001), "stacks": int(st["stacks"]),
			"duration": _sec(int(st["ends"]) - t), "action": aid})


func _status_flags(u: Unit) -> void:
	u.hidden = _has_kind(u, "hidden")
	u.stunned = _has_kind(u, "stun")


## Removes a status. reason: "expired", "ko" (its unit fell), "broken" (a shield used up, or the
## link's partner fell), "replaced". An expired status with "then" queues its follow-up action.
func _end_status(u: Unit, st: Dictionary, t: int, reason: String) -> void:
	var k := u.statuses.find(st)
	if k < 0:
		return
	u.statuses.remove_at(k)
	_st_count -= 1
	if int(st["owner"]) >= 0:
		_st_owned -= 1
	_status_flags(u)
	var kind := String(st["kind"])
	if kind == "stat" or kind == "slow":
		_recalc(u)
	if _log:
		_emit(t, {"type": "status_end", "uid": u.uid, "status": String(st["id"]), "stat": String(st["stat"]), "reason": reason})
	if kind == "stun" and u.alive and u.charge >= _charge_max and _k_jump:
		# a charged unit whose turn the stun took acts as soon as the stun ends (the queue jump holds)
		var queue := 0
		for o in _units:
			if o != u and o.alive and o.charge >= _charge_max and o.gauge >= _gauge_max:
				queue += 1
		u.gauge = maxi(u.gauge, _gauge_max) + _gauge_max - queue
	if kind == "link":   # a link ends on both ends
		var p := int(st["partner"])
		if p >= 0 and p < _units.size():
			var other := _find_status(_units[p], "link")
			if not other.is_empty() and int(other["partner"]) == u.uid:
				_end_status(_units[p], other, t, "broken" if reason == "ko" else reason)
	if reason == "expired" and String(st["then"]) != "" and u.alive:
		_followups.append([u, String(st["then"])])


## Earliest pending status tick, spread or expiry (ms).
func _next_status_ms() -> int:
	var best := 1 << 40
	for u in _units:
		if not u.alive or u.statuses.is_empty():
			continue
		for st: Dictionary in u.statuses:
			best = mini(best, int(st["ends"]))
			if int(st["tick"]) > 0 and int(st["next_tick"]) <= int(st["ends"]):
				best = mini(best, int(st["next_tick"]))
			if int(st["spread_ms"]) > 0 and int(st["next_spread"]) < int(st["ends"]):
				best = mini(best, int(st["next_spread"]))
	return best


## Fires every status tick, spread and expiry due by now, in unit order (stable, deterministic).
## Called between actions; anything that fell due during an action lands right after it.
func _process_statuses() -> void:
	_in_status = true
	_process_statuses_now()
	_in_status = false


func _process_statuses_now() -> void:
	for _guard in 64:
		if _next_status_ms() > _now:
			return
		var n := _units.size()
		for i in n:
			var u := _units[i]
			if not u.alive or u.statuses.is_empty():
				continue
			for st: Dictionary in u.statuses.duplicate():
				if not u.alive:
					break
				if u.statuses.find(st) < 0:
					continue
				var ends := int(st["ends"])
				if int(st["tick"]) > 0 and int(st["next_tick"]) <= _now and int(st["next_tick"]) <= ends:
					st["next_tick"] = int(st["next_tick"]) + int(st["tick"])
					_status_tick(u, st)
				if not u.alive or u.statuses.find(st) < 0:
					continue
				if int(st["spread_ms"]) > 0 and int(st["next_spread"]) <= _now and int(st["next_spread"]) < ends:
					st["next_spread"] = int(st["next_spread"]) + int(st["spread_ms"])
					_burn_spread(u, st)
				if ends <= _now and (int(st["tick"]) == 0 or int(st["next_tick"]) > ends):
					_end_status(u, st, _now, "expired")
			if _side_down(0) or _side_down(1) or _shard_won:
				return


func _status_tick(u: Unit, st: Dictionary) -> void:
	var src_uid := int(st["src"])
	match String(st["kind"]):
		"dot":
			_status_damage(u, src_uid, int(st["value"]), _now, "status:" + String(st["id"]), String(st["id"]))
		"regen":
			var src: Unit = _units[src_uid] if src_uid >= 0 else u
			_apply_heal(src, u, int(round(float(st["value"]) * _sd_heal_mult())), _now, "status:regen")


## Wildfire: the fire jumps to one edge-adjacent unburnt unit on the burning unit's side (a copy
## with the time it has left, so a packed shape burns longer).
func _burn_spread(u: Unit, st: Dictionary) -> void:
	var pool: Array[Unit] = []
	for o: Unit in _sides[u.side]:
		if o.alive and not o.inert and o != u and _adjacent(o, u, false) and _find_status(o, "burn").is_empty():
			pool.append(o)
	if pool.is_empty():
		return
	var to := pool[_rng.int_range(0, pool.size() - 1)]
	var src: Unit = _units[int(st["src"])]
	var left := int(st["ends"]) - _now
	if left <= 0:
		return
	var copy := {"id": "burn", "key": "burn", "kind": "dot", "src": src.uid, "owner": int(st["owner"]), "start": _now,
		"ends": int(st["ends"]), "value": float(st["value"]), "stat": "", "stacks": 1, "tick": int(st["tick"]),
		"next_tick": _now + int(st["tick"]), "spread_ms": int(st["spread_ms"]), "next_spread": _now + int(st["spread_ms"]),
		"then": "", "partner": -1, "action": String(st["action"])}
	to.statuses.append(copy)
	_st_count += 1
	if int(copy["owner"]) >= 0:
		_st_owned += 1
	if _log:
		_emit(_now, {"type": "status", "uid": to.uid, "status": "burn", "src": src.uid, "stat": "",
			"value": snappedf(float(copy["value"]), 0.001), "stacks": 1, "duration": _sec(left), "action": String(st["action"])})


## Status damage (poison, burn, a hexed heal): non-physical (ruling 2: never halved by the back
## column), shields absorb it, a link shares it; the hurt unit gains hit charge. Kind "status".
func _status_damage(dst: Unit, src_uid: int, amount: int, t: int, aid: String, id: String, share := true) -> void:
	if not dst.alive or amount <= 0:
		return
	var linked := _link_partner(dst) if share else null
	var link_amt := 0
	if linked != null:
		link_amt = int(floor(float(amount) * float(_st["link_share"])))
		amount -= link_amt
	amount -= _absorb(dst, amount, src_uid, t)
	if amount > 0:
		var dealt := mini(amount, dst.hp)
		dst.hp -= dealt
		if _log:
			var m := {"id": id, "mult": 1.0}
			_emit(t, {"type": "damage", "src": src_uid, "dst": dst.uid, "amount": amount, "kind": "status", "crit": false,
				"mods": [m], "primary": m.duplicate(), "hp": dst.hp, "action": aid})
		if dst.hp <= 0:
			_ko(dst, src_uid, t)
		elif dealt > 0:
			_gain_charge(dst, int(round(float(dealt) * 100.0 / float(dst.max_hp) * dst.charge_on_hit * dst.charge_mult)), "hit", t)
	if linked != null and link_amt > 0:
		_status_damage(linked, src_uid, link_amt, t, aid, "link", false)


## An HP cost (Iron Marshal's drive, Wickburner, the Tithe): never below 1 HP, never shielded or
## linked, builds no charge. A "damage" event of kind "status" with primary id "cost" / "tithe".
func _pay_hp(u: Unit, src_uid: int, amount: int, t: int, aid: String, id: String) -> int:
	var paid := mini(amount, u.hp - 1)
	if paid <= 0 or not u.alive:
		return 0
	u.hp -= paid
	if _log:
		var m := {"id": id, "mult": 1.0}
		_emit(t, {"type": "damage", "src": src_uid, "dst": u.uid, "amount": paid, "kind": "status", "crit": false,
			"mods": [m], "primary": m.duplicate(), "hp": u.hp, "action": aid})
	return paid


## A shield takes up to `amount`; returns what it absorbed (an "absorb" event; a used-up shield ends).
func _absorb(u: Unit, amount: int, src_uid: int, t: int) -> int:
	if u.statuses.is_empty() or amount <= 0:
		return 0
	var sh := _find_status(u, "shield")
	if sh.is_empty():
		return 0
	var left := int(sh["value"])
	var took := mini(left, amount)
	sh["value"] = float(left - took)
	if _log:
		_emit(t, {"type": "absorb", "uid": u.uid, "src": src_uid, "amount": took, "shield": left - took})
	if left - took <= 0:
		_end_status(u, sh, t, "broken")
	return took


## The other end of a unit's damage link (null if none or it fell).
func _link_partner(u: Unit) -> Unit:
	if u.statuses.is_empty():
		return null
	var st := _find_status(u, "link")
	if st.is_empty():
		return null
	var p := int(st["partner"])
	if p < 0 or p >= _units.size() or not _units[p].alive:
		return null
	return _units[p]


static func _adjacent(a: Unit, b: Unit, all8: bool) -> bool:
	var dc := absi(a.col - b.col)
	var dr := absi(a.row - b.row)
	if all8:
		return maxi(dc, dr) == 1
	return dc + dr == 1


# ---------------------------------------------------------------- ability ops (advanced classes)

## Whether an ability with "requires" has something to work on; if not, its "fallback" plays.
func _viable(u: Unit, a: Dictionary) -> bool:
	match String(a["requires"]):
		"adjacent_ally":
			var all8 := false
			for eff: Dictionary in a["effects"]:
				if eff.has("adjacency"):
					all8 = String(eff["adjacency"]) == "all"
			for o: Unit in _sides[u.side]:
				if o.alive and not o.inert and o != u and _adjacent(o, u, all8):
					return true
			return false
		"empty_front":
			return not _empty_front(u.side, u.row).is_empty()
		"fallen":
			return _raisable() != null and not _empty_front(u.side, u.row).is_empty()
		"fallen_ally":
			return not u.revive_used and _revivable(u) != null
		"two_allies":
			var ends := _strong_weak(u.side)
			return not ends.is_empty()
		"tithe":
			var ends2 := _strong_weak(u.side)
			return not ends2.is_empty() and (ends2[0] as Unit).hp > 1
		"wounded_other":
			for o: Unit in _sides[u.side]:
				if o.alive and not o.inert and o != u and o.hp < o.max_hp:
					return _sd_heal_mult() > 0.0
			return false
	return true


## [healthiest, weakest] living allies by HP fraction (distinct; ties -> lower uid), or [] if fewer
## than two different units.
func _strong_weak(side: int) -> Array:
	var hi: Unit = null
	var lo: Unit = null
	for o: Unit in _sides[side]:
		if not o.alive or o.inert or o.summon != "":
			continue
		var f := float(o.hp) / float(o.max_hp)
		if hi == null or f > float(hi.hp) / float(hi.max_hp):
			hi = o
		if lo == null or f < float(lo.hp) / float(lo.max_hp):
			lo = o
	if hi == null or lo == null or hi == lo:
		return []
	return [hi, lo]


## The empty front slot nearest `row` on a side ([col, row]), or [] if the front column is full.
func _empty_front(side: int, row: int) -> Array:
	var taken := {}
	for o: Unit in _sides[side]:
		if o.alive:
			for k in o.span:
				taken[o.col * 4 + o.row + k] = true
	var best: Array = []
	var best_d := 99
	for r in 4:
		if taken.has(r):
			continue
		var d := absi(r - row)
		if d < best_d:
			best_d = d
			best = [0, r]
	return best


## Gravecaller: the most recently fallen hero, monster or memory on either side not yet raised.
func _raisable() -> Unit:
	var best: Unit = null
	for o in _units:
		if o.alive or o.inert or o.summon != "" or o.raised or o.ko_seq < 0:
			continue
		if best == null or o.ko_seq > best.ko_seq:
			best = o
	return best


## Rekindler: the first ally to fall (not a summon, not raised, its slot free again).
func _revivable(u: Unit) -> Unit:
	var best: Unit = null
	for o: Unit in _sides[u.side]:
		if o.alive or o.inert or o.summon != "" or o.raised or o.ko_seq < 0:
			continue
		if _slot_taken(o.side, o.col, o.row):
			continue
		if best == null or o.ko_seq < best.ko_seq:
			best = o
	return best


func _slot_taken(side: int, col: int, row: int) -> bool:
	for o: Unit in _sides[side]:
		if o.alive and o.col == col and row >= o.row and row < o.row + o.span:
			return true
	return false


func _steal_charge(u: Unit, tgt: Unit, amount: int, t: int) -> void:
	var amt := mini(amount, tgt.charge)
	if amt <= 0 or tgt.side == u.side:
		return
	tgt.charge -= amt
	if _log:
		_emit(t, {"type": "charge", "uid": tgt.uid, "charge": tgt.charge, "delta": -amt, "reason": "drain",
			"ready": false, "queue": 0})
	_gain_charge(u, amt, "effect", t)


## Shackler: pulls the foe standing behind `tgt` (same row, back column) forward into the front
## column, pushing `tgt` back; if `tgt` fell to the hit, the back unit steps into its empty slot.
## The side's formation stays the one detected at fight start (as Hold the door). Two "move"
## events (the pulled unit first).
func _pull_forward(u: Unit, tgt: Unit, t: int) -> void:
	if tgt.col != 0 or tgt.span != 1:
		return
	var back: Unit = null
	for o: Unit in _sides[tgt.side]:
		if o.alive and not o.inert and o.span == 1 and o.col == 1 and o.row == tgt.row:
			back = o
	if back == null:
		return
	back.col = 0
	if tgt.alive:
		tgt.col = 1
	if _log:
		_emit(t, {"type": "move", "side": back.side, "uid": back.uid, "from": [1, back.row], "to": [0, back.row],
			"src": u.uid, "effect": "pulled"})
		if tgt.alive:
			_emit(t, {"type": "move", "side": tgt.side, "uid": tgt.uid, "from": [0, tgt.row], "to": [1, tgt.row],
				"src": u.uid, "effect": "pushed"})


## Iron Marshal: fills an ally's ATB gauge (amount 1.0 = full: it acts next, after any fully
## charged unit already waiting). A "gauge" event.
func _fill_gauge(u: Unit, tgt: Unit, amount: float, t: int) -> void:
	var g := maxi(tgt.gauge, int(float(_gauge_max) * amount))
	if g <= tgt.gauge:
		return
	tgt.gauge = g
	if _log:
		_emit(t, {"type": "gauge", "uid": tgt.uid, "src": u.uid,
			"gauge": snappedf(float(mini(g, _gauge_max)) / float(_gauge_max), 0.001)})


## Threadmender: links the healthiest and the weakest ally (by HP fraction) for the effect's time.
func _link(u: Unit, eff: Dictionary, t: int, aid: String, from_ability: bool) -> void:
	var ends := _strong_weak(u.side)
	if ends.is_empty():
		return
	var a: Unit = ends[0]
	var b: Unit = ends[1]
	var e1 := eff.duplicate()
	e1["partner"] = b.uid
	var e2 := eff.duplicate()
	e2["partner"] = a.uid
	_add_status(a, "link", u, e1, t, aid, from_ability)
	_add_status(b, "link", u, e2, t, aid, from_ability)


## Tithekeeper: moves HP from the healthiest ally to the weakest, giving back more than it took.
func _tithe(u: Unit, eff: Dictionary, t: int, aid: String) -> void:
	var ends := _strong_weak(u.side)
	if ends.is_empty():
		return
	var rich: Unit = ends[0]
	var poor: Unit = ends[1]
	var paid := _pay_hp(rich, u.uid, int(round(float(rich.max_hp) * float(eff["pct"]))), t, aid, "tithe")
	if paid > 0:
		_apply_heal(u, poor, int(round(float(paid) * float(eff["give"]) * _sd_heal_mult())), t, aid)


## Starcaller: one random gift from the effect's table to the target ally.
func _random_boon(u: Unit, tgt: Unit, eff: Dictionary, t: int, aid: String, from_ability: bool) -> void:
	var table: Array = eff["table"]
	var pick: Dictionary = table[_rng.int_range(0, table.size() - 1)]
	match String(pick["op"]):
		"status":
			_add_status(tgt, String(pick["status"]), u, pick, t, aid, from_ability)
		"charge":
			_gain_charge(tgt, int(pick["amount"]), "effect", t)


## A summon or husk joins `owner`'s side in a front slot: it fights with a basic action only, never
## charges, never counts as standing or toward shapes (ruling 6), and isn't a survivor.
func _make_summon(owner: Unit, kind: String, slot: Array, model: Unit, frac: Dictionary, t: int, raised_uid: int) -> Unit:
	var s := Unit.new()
	s.uid = _units.size()
	s.side = owner.side
	s.summon = kind
	s.summoner = owner.uid
	s.class_id = model.class_id
	s.base_class = model.base_class
	s.tier = "summon"
	s.level = model.level
	s.name = ("Echo of %s" if kind == "echo" else "Husk of %s") % model.label
	s.label = s.name
	s.col = int(slot[0])
	s.row = int(slot[1])
	s.roles = ["front"]
	s.in_shape = false
	s.max_hp = maxi(1, int(round(float(model.max_hp) * float(frac["hp"]))))
	s.hp = s.max_hp
	s.atk = maxi(1, int(round(float(model.f_atk) * float(frac["atk"]))))
	s.def = maxi(1, int(round(float(model.f_def) * float(frac["def"]))))
	s.mag = maxi(1, int(round(float(model.f_mag) * float(frac["mag"]))))
	s.spd = maxi(1, int(round(float(model.f_spd) * float(frac["spd"]))))
	s.raw_atk = s.atk
	s.raw_def = s.def
	s.raw_mag = s.mag
	s.crit = model.crit
	s.basic = model.basic
	s.ability = ""
	s.rate = maxi(1, s.spd * int(_c["fill_per_spd_per_ms"]))
	_set_base_stats(s)
	_units.append(s)
	_sides[s.side].append(s)
	if _log:
		_emit(t, {"type": "spawn", "side": s.side, "uid": s.uid, "slot": [s.col, s.row], "unit": _unit_snapshot(s),
			"memory": "", "chapter": 0, "lore": "", "reason": "raise" if kind == "husk" else "summon",
			"summon": kind, "summoner": owner.uid, "raised": raised_uid})
	return s


## Echoblade: an echo of itself in the empty front slot nearest its row.
func _summon_echo(u: Unit, eff: Dictionary, t: int) -> void:
	var slot := _empty_front(u.side, u.row)
	if slot.is_empty():
		return
	var f := float(eff.get("hp_frac", 0.4))
	_make_summon(u, "echo", slot, u, {"hp": f, "atk": 1.0, "def": 1.0, "mag": 1.0, "spd": 1.0}, t, -1)


## Gravecaller: raises the most recently fallen unit (either side) as a husk on its own side:
## clearly weaker than it was (eff "frac" of its HP/Atk/Def/Mag, "spd_frac" of its Spd).
func _raise_husk(u: Unit, eff: Dictionary, t: int) -> void:
	var dead := _raisable()
	var slot := _empty_front(u.side, u.row)
	if dead == null or slot.is_empty():
		return
	dead.raised = true
	var f := float(eff.get("frac", 0.5))
	_make_summon(u, "husk", slot, dead, {"hp": f, "atk": f, "def": f, "mag": f, "spd": float(eff.get("spd_frac", 0.75))},
		t, dead.uid)


## Rekindler: the first fallen ally stands again in its slot at a share of its HP (once per fight).
func _revive(u: Unit, eff: Dictionary, t: int) -> void:
	if u.revive_used:
		return
	var o := _revivable(u)
	if o == null:
		return
	u.revive_used = true
	o.raised = true
	o.alive = true
	o.hp = maxi(1, int(round(float(o.max_hp) * float(eff.get("hp_frac", 0.3)))))
	o.gauge = 0
	o.charge = 0
	o.ko_seq = -1
	_alive[o.side] += 1
	if _log:
		_emit(t, {"type": "revive", "uid": o.uid, "src": u.uid, "hp": o.hp})


## Hexfire (Warlock, user tweak): a column of fire from the bottom of the foes' back column (the
## front if the back is empty) up, one space at a time; each unit is hit as the fire reaches its
## space (eff "stagger_ms" apart per space).
func _column_sweep(u: Unit, eff: Dictionary, primary: Unit, t: int, aid: String) -> void:
	if primary == null:
		return
	var col := primary.col
	var side := primary.side
	var order: Array = []
	for o: Unit in _sides[side]:
		if o.alive and o.col == col:
			order.append(o)
	order.sort_custom(func(a: Unit, b: Unit) -> bool: return a.row + a.span > b.row + b.span)
	var stagger := int(eff.get("stagger_ms", 100))
	for o: Unit in order:
		if not o.alive or not u.alive:
			continue
		var space := 3 - (o.row + o.span - 1)   # 0 = the bottom space
		_damage(u, o, eff, t + space * stagger, aid)
		if _side_down(side) or _shard_won:
			return
