extends RefCounted
## One descent into a Memory Vault: pure logic, deterministic from (seed, options, Echo pool).
## A UI drives it step by step; see core/run/README.md for the API and the step machine.
## The map is hidden: it lives in _map and is never returned by any public method.

const Rng = preload("res://core/rng.gd")
const GameData = preload("res://core/game_data.gd")
const Alignment = preload("res://core/alignment.gd")
const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Formation = preload("res://core/formation.gd")
const Catalog = preload("res://core/run/encounter_catalog.gd")
const EchoPool = preload("res://core/run/echo_pool.gd")
const T = preload("res://core/run/run_tuning.gd")
const LegendGate = preload("res://core/run/legend_gate.gd")


var seed_value := 0
var _opts := {}
var _pool: RefCounted = null
var _map: Array = []            # hidden: layers of nodes {type, kind, enc, recruit_class, lore, route}
var _layer := -1
var _idx := 0
var _step := "draft"            # draft | choice | decision | fight | outcome | ended
var _offered: Array = []
var _heroes: Array = []
var _health := 0
var _vault := ""
var _bound: Array = []
var _decisions: Array = []      # queue of {kind: "advance", hero_index}
var _enc: Dictionary = {}       # the encounter shown at the current node (map's or a legend's memory)
var _enc_kind := ""
var _legend_appeared := false   # the legend's memory appears at most once per run
var _legend_misses := 0
var _seen: Array = []           # encounter ids met this run (summary)
var _types: Array = []          # node type per layer: encounter | pvp | guardian | crystal
var _floors: Array = []         # floor (1-based) per layer
var _snapshots: Dictionary = {} # floor -> party snapshot (Echoes are recorded per floor)
var _health_lost := {"gathering": 0, "advancement": 0, "legend": 0}
var _death: Dictionary = {}
var _fights_by_floor: Dictionary = {}   # floor -> {kind: [wins, fights]}
var _met_names: Dictionary = {}         # rival Echo names already met this run
var _rivals: Array = []
var _fragments := 0
var _memories_defeated: Array = []
var _choice_done := false
var _fight_pending := false
var _fight_kind := ""           # monster | pvp | guardian | crystal
var _fight_attempt := 0
var _opponent: Dictionary = {}
var _next_idx := -1
var _last: Dictionary = {}
var _phase_reached := "gathering"
var _outcome := ""
var _stats := {"pvp_wins": 0, "pvp_losses": 0, "monster_wins": 0, "monster_losses": 0, "nodes": 0,
	"memories": 0, "wasted_memories": 0, "guardian_wins": 0, "guardian_losses": 0, "rests": 0, "healed": 0,
	"encounter_nodes": 0, "two_choice_nodes": 0, "guardian_health_lost": 0}
var _lore: Array = []
var _items_found: Array = []
var _legendaries := 0
var _summary: Dictionary = {}
var _log: Array[String] = []


# ======================= public API =======================

## Starts a run. options: pool (an EchoPool), pool_path (default user://echo_pool.json),
## save_echo (default true: the finished run's snapshot is added to the pool and saved),
## best_floor (meta: deepest floor reached before, for depth milestones), start_pool_size,
## party_name, log (default true: fight results carry the event log for playback),
## unlocked_formations (Training Grounds shape ids; default Formations.DEFAULT_UNLOCKED).
func start_run(seed_in: int, options: Dictionary = {}) -> Dictionary:
	seed_value = seed_in
	_opts = options.duplicate()
	_pool = options.get("pool", null)
	if _pool == null:
		_pool = EchoPool.open(String(options.get("pool_path", EchoPool.DEFAULT_PATH)))
	_health = int(T.RUN["max_health"])
	var rng := _rng(5)
	_vault = T.VAULTS[rng.int_range(0, T.VAULTS.size() - 1)]
	var bases: Array = GameData.Classes.BASE_CLASS_IDS.duplicate()
	_shuffle(bases, rng)
	var n := clampi(int(options.get("start_pool_size", T.RUN["start_pool_size"])), 2, bases.size())
	var names: Array = T.HERO_NAMES.duplicate()
	_shuffle(names, rng)
	for i in n:
		_offered.append({"name": names[i], "class": bases[i], "taken": false})
	_gen_map()
	_say("== Run %d: %s ==" % [seed_value, _vault])
	return current_node()


## What the player sees now. Never contains map structure or where a choice leads.
func current_node() -> Dictionary:
	var v := {"step": _step, "depth": _layer + 1, "floor": _floor(), "phase": _phase(_layer),
		"health": _health, "max_health": int(T.RUN["max_health"]), "vault": _vault, "party": party_view()}
	match _step:
		"draft":
			var offered: Array = []
			for i in _offered.size():
				var o: Dictionary = _offered[i]
				offered.append({"index": i, "name": o["name"], "class": o["class"], "taken": o["taken"],
					"alignment": Alignment.start_for(String(o["class"]))})
			v["offered"] = offered
			v["picks_left"] = int(T.RUN["start_picks"]) - _heroes.size()
		"choice":
			var node: Dictionary = _node()
			v["type"] = "encounter"
			v["kind"] = _enc_kind
			v["encounter_id"] = _enc.get("id", "")
			v["title"] = _enc.get("title", "")
			v["text"] = _enc.get("text", "")
			var choices: Array = []
			for i in _bound.size():
				var b: Dictionary = _bound[i]
				var c: Dictionary = b["choice"]
				var hi := int(b["hero_index"])
				var entry := {"index": i, "id": c.get("id", ""), "label": c.get("label", ""),
					"hero_index": hi, "hero_name": _heroes[hi]["name"] if hi >= 0 else "",
					"class": c.get("class", ""), "shift": Catalog.shift(c), "rare": Catalog.is_rare(c)}
				if bool(c.get("legend", false)):
					entry["legend"] = true
				if c.has("rest"):
					entry["rest"] = int(c["rest"])   # +health, but nobody gains a memory here
				if c.has("luck"):
					entry["uncertain"] = true        # the shift may turn out differently
				if c.has("recruit") and _heroes.size() < int(T.RUN["max_party"]):
					entry["recruit"] = node["recruit_class"] if String(c["recruit"].get("class", "*")) == "*" \
						else String(c["recruit"]["class"])
				choices.append(entry)
			v["choices"] = choices
		"decision":
			var d: Dictionary = _decisions[0]
			var h: Dictionary = _heroes[int(d["hero_index"])]
			v["type"] = d["kind"]
			v["hero_index"] = d["hero_index"]
			v["hero_name"] = h["name"]
			v["choices"] = [{"index": 0, "label": "Advance"}, {"index": 1, "label": "Hold back"}]
		"fight":
			# Only what a player may know before the fight (05-formations "Decided": the opponent's
			# formation is hidden until the fight starts). The full opponent is in resolve_fight().
			v["type"] = _fight_kind
			var meta: Dictionary = _opponent.get("meta", {})
			v["opponent"] = {"name": _opponent.get("name", ""), "title": String(meta.get("title", "")),
				"crest": String(meta.get("crest", "")), "intro": String(meta.get("intro", ""))}
			v["attempt"] = _fight_attempt
		"outcome":
			v["last"] = _last.duplicate(true)
		"ended":
			v["outcome"] = _outcome
	return v


## Applies choice `i` of the current step (draft pick, encounter choice or decision).
## Returns {"ok": true, ...what happened} or {"error": String}.
func choose(i: int) -> Dictionary:
	match _step:
		"draft":
			if i < 0 or i >= _offered.size() or _offered[i]["taken"]:
				return {"error": "bad draft index %d" % i}
			_offered[i]["taken"] = true
			var o: Dictionary = _offered[i]
			_add_hero(String(o["class"]), String(o["name"]))
			_say("Drafted %s the %s" % [o["name"], String(o["class"]).capitalize()])
			if _heroes.size() >= int(T.RUN["start_picks"]):
				_enter(0, 0)
			return {"ok": true}
		"decision":
			if i < 0 or i > 1:
				return {"error": "decision index must be 0 or 1"}
			var d: Dictionary = _decisions.pop_front()
			var h: Dictionary = _heroes[int(d["hero_index"])]
			var res := {"ok": true, "hero_index": d["hero_index"], "kind": d["kind"]}
			if i == 0:
				_advance_hero(h)
				res["class"] = h["class"]
			else:
				h["held"] = true
				h["held_ever"] = true
				_say("  %s holds back (level %d)" % [h["name"], h["level"]])
			_update_step()
			return res
		"choice":
			if i < 0 or i >= _bound.size():
				return {"error": "bad choice index %d" % i}
			return _apply_choice(i)
	return {"error": "nothing to choose in step '%s'" % _step}


## Places heroes: slots[k] = [col, row] for party hero k (col 0 front, 1 back; row 0..3).
## Formation effects are computed by core from the shape; the run only stores the placement.
func set_formation(slots: Array) -> Dictionary:
	if _step == "draft" or _step == "ended":
		return {"error": "no party to arrange in step '%s'" % _step}
	if slots.size() != _heroes.size():
		return {"error": "need %d slots, got %d" % [_heroes.size(), slots.size()]}
	var trial := combat_party()
	for k in slots.size():
		var s: Variant = slots[k]
		if not (s is Array) or (s as Array).size() != 2:
			return {"error": "slot %d must be [col, row]" % k}
		trial["heroes"][k]["slot"] = [int(s[0]), int(s[1])]
	var errs := GameData.validate_party(trial, "player")
	if not errs.is_empty():
		return {"error": "; ".join(errs)}
	for k in slots.size():
		_heroes[k]["slot"] = [int(slots[k][0]), int(slots[k][1])]
	return {"ok": true, "formation": Formation.detect_party(combat_party())["id"]}


## Runs the pending fight in the core sim and applies its result. Returns the sim result (events
## for the battle scene to play back) plus "run": {won, kind, health, ended}.
func resolve_fight() -> Dictionary:
	if _step != "fight":
		return {"error": "no fight in step '%s'" % _step}
	var fseed := _rng(1000 + _layer * 8 + _fight_attempt).next_u32()
	var result: Dictionary
	if _fight_kind == "crystal":   # always logged: spawn/ko events feed the codex record
		result = CombatSim.simulate_crystal(fseed, combat_party(), {"memories": _opponent["memories"],
			"integrity": int(T.RUN["crystal_integrity"])}, {"log": true})
	else:
		result = CombatSim.simulate(fseed, combat_party(), _opponent, {"log": bool(_opts.get("log", true))})
	if result.has("error"):
		return result
	var won := int(result["winner"]) == 0
	_fight_pending = false
	_fight_attempt += 1
	var info := {"won": won, "kind": _fight_kind, "opponent": _opponent.get("name", "")}
	match _fight_kind:
		"pvp":
			_stats["pvp_wins" if won else "pvp_losses"] += 1
			if not won:
				_lose(int(T.RUN["pvp_loss_health"]))
		"monster":
			_stats["monster_wins" if won else "monster_losses"] += 1
			if won:
				var drop := _rng(3000 + _layer)
				if drop.next_float() < float(T.RUN["item_drop_chance"]):
					var ids: Array = GameData.Items.ITEMS.keys()
					var hi := drop.int_range(0, _heroes.size() - 1)
					info["item"] = _grant_item(hi, String(ids[drop.int_range(0, ids.size() - 1)]))
			else:
				_lose(int(T.RUN["monster_loss_health"]))
		"guardian":   # losing costs more than PvP, rising per floor
			_stats["guardian_wins" if won else "guardian_losses"] += 1
			if not won:
				var before := _health
				_lose(int(_guardian_def().get("loss_health", 2)))
				info["health_lost"] = before - _health
				_stats["guardian_health_lost"] += before - _health
		"crystal":   # no retreat: the Shard breaks free, or every hero falls and the run ends here
			_fragments = int(result.get("fragments", 0))
			info["fragments"] = _fragments
			_memories_defeated = _defeated_memories(result)
			info["memories_defeated"] = _memories_defeated.duplicate()
			if not won:
				_health = 0
	var fl: Dictionary = _fights_by_floor.get(_floor(), {})
	var rec: Array = fl.get(_fight_kind, [0, 0])
	fl[_fight_kind] = [int(rec[0]) + (1 if won else 0), int(rec[1]) + 1]
	_fights_by_floor[_floor()] = fl
	_say("  %s vs %s: %s (%.1fs) health %d%s" % [_fight_kind.to_upper(), _opponent.get("name", ""),
		"WIN" if won else "LOSS", float(result["duration"]), _health,
		" (rival power %d vs %d)" % [EchoPool.power(_opponent), EchoPool.power(combat_party())] if _fight_kind == "pvp" else ""])
	_last = {"type": "fight", "fight": info.duplicate(true), "health": _health}
	if _health <= 0:
		_death = {"depth": _layer + 1, "floor": _floor(), "node": _fight_kind, "phase": _phase(_layer)}
		_end("fallen")
	elif _fight_kind == "crystal" and won:
		_end("victory")
	else:
		_update_step()
	info["health"] = _health
	info["ended"] = _step == "ended"
	result["run"] = info
	result["opponent"] = _opponent.duplicate(true)   # revealed now, for playback
	if _fight_kind == "crystal" and not bool(_opts.get("log", true)):
		result["events"] = []
	return result


## Moves to the next node once the current one is resolved (step "outcome").
func advance() -> Dictionary:
	if _step != "outcome":
		return {"error": "cannot advance in step '%s'" % _step}
	var nl := _layer + 1
	if _fixed(nl):
		_enter(nl, 0)   # PvP / guardians sit on every path; the choice before them still decides the node after
		return current_node()
	var nxt := _next_idx
	if nxt < 0 or nxt >= _map[nl].size():
		nxt = _rng(4000 + _layer).int_range(0, _map[nl].size() - 1)
	_enter(nl, nxt)
	return current_node()


## Run summary for meta progression (valid once step == "ended"; partial before).
func summary() -> Dictionary:
	if not _summary.is_empty():
		return _summary.duplicate(true)
	return _make_summary()


func is_over() -> bool:
	return _step == "ended"


func log_lines() -> Array[String]:
	return _log.duplicate()


## Public view of the party (no map data).
func party_view() -> Array:
	var out: Array = []
	for h: Dictionary in _heroes:
		var cdef := GameData.get_class_def(String(h["class"]))
		out.append({"name": h["name"], "class": h["class"], "class_name": cdef.get("name", ""),
			"base": h["base"], "tier": "legendary" if h["legendary"] else String(cdef.get("tier", "base")),
			"level": h["level"], "max_level": GameData.max_level(String(h["class"])),
			"memories": h["memories"], "alignment": h["alignment"].duplicate(),
			"effective_alignment": Alignment.effective_for_hero(h), "items": h["items"].duplicate(),
			"slot": h["slot"].duplicate(), "held": h["held"], "legendary": h["legendary"]})
	return out


## The party as the combat sim / Echo format wants it.
func combat_party() -> Dictionary:
	var hs: Array = []
	for h: Dictionary in _heroes:
		hs.append({"name": h["name"], "class": h["class"], "level": h["level"], "items": h["items"].duplicate(),
			"alignment": h["alignment"].duplicate(), "slot": h["slot"].duplicate()})
	var unlocked: Array = _opts.get("unlocked_formations", GameData.Formations.DEFAULT_UNLOCKED)
	return {"name": _party_name(), "heroes": hs, "unlocked_formations": unlocked.duplicate()}


# ======================= internals =======================

func _rng(salt: int) -> Rng:
	return Rng.new(seed_value ^ (salt << 32))


static func _shuffle(a: Array, rng: Rng) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.int_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


func _say(s: String) -> void:
	_log.append(s)


func _party_name() -> String:
	if _opts.has("party_name"):
		return String(_opts["party_name"]).left(32)
	return EchoPool.team_name(_rng(8).next_u32())


func _node() -> Dictionary:
	return _map[_layer][_idx]


func _floor() -> int:
	return int(_floors[maxi(0, _layer)])


func _phase(layer: int) -> String:
	var pf: Array = T.RUN["phase_by_floor"]
	return String(pf[clampi(int(_floors[maxi(0, layer)]) - 1, 0, pf.size() - 1)])


func _layer_type(layer: int) -> String:
	return String(_types[layer])


## PvP and guardian nodes are single fixed points on every path.
func _fixed(layer: int) -> bool:
	return _types[layer] == "pvp" or _types[layer] == "guardian"


func _lose(n: int) -> void:
	var lost := mini(n, _health)
	_health -= lost
	_health_lost[_phase(_layer)] += lost


func _gen_map() -> void:
	var rng := _rng(1)
	var letters := {"E": "encounter", "P": "pvp", "G": "guardian", "C": "crystal"}
	_types.clear()
	_floors.clear()
	for f in T.RUN["floors"].size():
		for ch in String(T.RUN["floors"][f]):
			_types.append(letters[ch])
			_floors.append(f + 1)
	var total := _types.size()
	var used := {}
	var lore_left: Array = T.LORE_ITEMS.duplicate()
	_shuffle(lore_left, rng)
	_map.clear()
	for layer in total:
		var ltype := _layer_type(layer)
		var width := 1 if (ltype != "encounter" or layer == 0) else rng.int_range(int(T.RUN["layer_width_min"]), int(T.RUN["layer_width_max"]))
		var nodes: Array = []
		for j in width:
			var n := {"type": ltype, "kind": "", "enc": "", "recruit_class": "", "lore": "", "route": []}
			if ltype == "encounter":
				var kind := _weighted(T.RUN["kind_weights"][_phase(layer)], rng)
				var ids: Array = Catalog.ids_of_kind(kind).filter(func(x: String) -> bool: return not used.has(x))
				if ids.is_empty():
					ids = Catalog.all().keys().filter(func(x: String) -> bool: return not used.has(x))
				if ids.is_empty():
					ids = Catalog.ids_of_kind(kind)
				var enc: String = ids[rng.int_range(0, ids.size() - 1)]
				used[enc] = true
				n["enc"] = enc
				n["kind"] = String(Catalog.get_encounter(enc)["kind"])
				n["recruit_class"] = GameData.Classes.BASE_CLASS_IDS[rng.int_range(0, 3)]
				if (n["kind"] == "riddle" or n["kind"] == "moral") and not lore_left.is_empty() \
						and rng.next_float() < float(T.RUN["lore_chance"]):
					n["lore"] = lore_left.pop_back()
			nodes.append(n)
		_map.append(nodes)
	# edges: each encounter node links to nodes of the next non-PvP layer near its relative position
	# (PvP layers are single fixed points on every path); every node is reachable
	var branch_layers: Array = range(total).filter(func(l: int) -> bool: return not _fixed(l))
	for li in branch_layers.size() - 1:
		var a: Array = _map[branch_layers[li]]
		var b: Array = _map[branch_layers[li + 1]]
		var incoming := {}
		for j in a.size():
			var pos := (float(j) * (b.size() - 1) / float(a.size() - 1)) if a.size() > 1 else (b.size() - 1) / 2.0
			var edges: Array = []
			for k in b.size():
				if absf(k - pos) <= 1.0:
					edges.append(k)
					incoming[k] = true
			a[j]["route"] = edges
		for k in b.size():
			if not incoming.has(k):
				var j := clampi(int(round(float(k) * (a.size() - 1) / float(maxi(1, b.size() - 1)))), 0, a.size() - 1)
				a[j]["route"].append(k)
		for j in a.size():   # choice i -> route[i % size]; the order is a hidden seeded shuffle
			_shuffle(a[j]["route"], rng)


static func _weighted(weights: Dictionary, rng: Rng) -> String:
	var total := 0
	for k: String in weights:
		total += int(weights[k])
	var r := rng.int_range(0, total - 1)
	for k: String in weights:
		r -= int(weights[k])
		if r < 0:
			return k
	return weights.keys()[0]


func _enter(layer: int, idx: int) -> void:
	var prev_phase := _phase(_layer) if _layer >= 0 else ""
	_layer = layer
	_idx = idx
	_stats["nodes"] += 1
	_choice_done = false
	_fight_pending = false
	_fight_attempt = 0
	if not _fixed(layer):
		_next_idx = -1   # a PvP / guardian node carries the route chosen before it
	_bound = []
	_last = {}
	var phase := _phase(layer)
	if phase != prev_phase:
		_say("-- Phase: %s (depth %d) --" % [phase.capitalize(), layer + 1])
		if ["gathering", "advancement", "legend"].find(phase) > ["gathering", "advancement", "legend"].find(_phase_reached):
			_phase_reached = phase
	var node: Dictionary = _node()
	match String(node["type"]):
		"encounter":
			if not _roll_legend():
				_enc = Catalog.get_encounter(String(node["enc"]))
				_enc_kind = String(node["kind"])
				_bound = Catalog.bind(_enc, _heroes)
			if _bound.is_empty():
				_bound = [{"hero_index": -1, "choice": {"id": "press_on", "label": "Press on", "class": "",
					"shift": {"good": 0, "law": 0}, "outcome": "Nothing here answers to you. You press on."}}]
			_seen.append(String(_enc.get("id", "")))
			_stats["encounter_nodes"] += 1
			var per_hero := {}
			for b: Dictionary in _bound:
				per_hero[int(b["hero_index"])] = int(per_hero.get(int(b["hero_index"]), 0)) + 1
			for k: int in per_hero:
				if k >= 0 and int(per_hero[k]) >= 2:
					_stats["two_choice_nodes"] += 1
					break
			_say("[%d] %s: %s" % [layer + 1, _enc_kind.capitalize(), _enc.get("title", "")])
		"pvp":
			_choice_done = true
			if not _snapshots.has(_floor()):
				_snapshots[_floor()] = combat_party()   # recorded as it first met rivals on this floor
			_start_fight("pvp", _pool.pick(_floor(), _rng(100 + layer), _met_names))
			_met_names[String(_opponent.get("name", ""))] = true
			_rivals.append(String(_opponent.get("name", "")))
			_say("[%d] PvP: %s" % [layer + 1, _opponent.get("name", "")])
		"guardian":
			_choice_done = true
			_start_fight("guardian", _floor_guardian())
			_say("[%d] Floor %d guardian: %s" % [layer + 1, _floor(), _opponent["name"]])
		"crystal":
			_choice_done = true
			var cd: Dictionary = _guardian_data().get("crystal", {})
			_start_fight("crystal", {"name": String(cd.get("name", "The Crystal of Remembrance")),
				"memories": _crystal_sequence(),
				"meta": {"title": String(cd.get("name", "")), "intro": String(cd.get("intro", ""))}})
			_say("[%d] %s" % [layer + 1, _opponent["name"]])
	_update_step()


func _update_step() -> void:
	if _step == "ended":
		return
	if not _decisions.is_empty():
		_step = "decision"
	elif not _choice_done:
		_step = "choice"
	elif _fight_pending:
		_step = "fight"
	else:
		_step = "outcome"


func _start_fight(kind: String, opponent: Dictionary) -> void:
	_fight_kind = kind
	_opponent = opponent
	_fight_pending = true


func _apply_choice(i: int) -> Dictionary:
	var node: Dictionary = _node()
	var b: Dictionary = _bound[i]
	var c: Dictionary = b["choice"]
	var hi := int(b["hero_index"])
	var res := {"ok": true, "hero_index": hi}
	var rng := _rng(2000 + _layer)
	var sh := Catalog.shift(c)
	var lucky_text := ""
	if c.has("luck") and rng.next_float() < float(c["luck"].get("chance", 0.0)):
		sh = [int(c["luck"].get("good", 0)), int(c["luck"].get("law", 0))]
		lucky_text = String(c["luck"].get("text", ""))
		res["luck"] = true
	if bool(c.get("legend", false)):
		_ascend(_heroes[hi])
		res["legendary"] = _heroes[hi]["class"]
	elif c.has("rest"):
		var healed := mini(int(c["rest"]), int(T.RUN["max_health"]) - _health)
		_health += healed
		_stats["rests"] += 1
		_stats["healed"] += healed
		res["healed"] = healed
		_say("  the party rests: +%d health (%d), no memory" % [healed, _health])
	elif hi >= 0:
		res["memory"] = _memory(hi, c, sh)
	var o: Variant = c.get("outcome", "") if lucky_text == "" else lucky_text
	if o is Array:
		var total := 0.0
		for v: Dictionary in o:
			total += float(v.get("weight", 1))
		var r := rng.next_float() * total
		var text := String(o[-1].get("text", ""))
		for v: Dictionary in o:
			r -= float(v.get("weight", 1))
			if r < 0.0:
				text = String(v.get("text", ""))
				break
		res["text"] = text
	else:
		res["text"] = String(o)
	if c.has("item") and hi >= 0:
		res["item"] = _grant_item(hi, String(c["item"]))
	if c.has("recruit") and _heroes.size() < int(T.RUN["max_party"]):
		var rc := String(c["recruit"].get("class", "*"))
		if rc == "*" or not GameData.has_class(rc):
			rc = String(node["recruit_class"])
		var rname := String(c["recruit"].get("name", ""))
		if rname == "" or _has_name(rname):
			rname = _fresh_name(rng)
		_add_hero(rc, rname)
		res["recruited"] = _heroes.size() - 1
		_say("  + %s the %s joins (party %d)" % [rname, rc.capitalize(), _heroes.size()])
	if String(node["lore"]) != "" and _enc_kind != "legend":
		_lore.append(node["lore"])
		res["lore"] = node["lore"]
		_say("  lore item: %s" % node["lore"])
	_next_idx = int(node["route"][i % node["route"].size()]) if not node["route"].is_empty() else -1
	_choice_done = true
	if _enc_kind == "monster":
		_start_fight("monster", _monsters())
	_last = res.duplicate(true)
	_last["type"] = "choice"
	_update_step()
	return res


## A memory: bound to the choice's hero. +1 level (up to the tier cap) and the alignment shift.
func _memory(hi: int, c: Dictionary, sh: Array) -> Dictionary:
	var h: Dictionary = _heroes[hi]
	var before := {"level": h["level"], "alignment": h["alignment"].duplicate()}
	h["memories"] += 1
	_stats["memories"] += 1
	h["alignment"] = Alignment.apply_shift(h["alignment"], sh)
	if int(h["level"]) < GameData.max_level(String(h["class"])):
		h["level"] += 1
	else:
		_stats["wasted_memories"] += 1
	_say("  %s takes \"%s\": memory %d, level %d, shift %s -> %s%s" % [h["name"], c.get("label", ""),
		h["memories"], h["level"], sh, h["alignment"], " (rare)" if Catalog.is_rare(c) else ""])
	var tier := String(GameData.get_class_def(String(h["class"]))["tier"])
	if tier == "base" and int(h["memories"]) >= int(T.RUN["advance_threshold"]):
		_decisions.append({"kind": "advance", "hero_index": hi})
	return {"hero_index": hi, "level_before": before["level"], "level": h["level"],
		"alignment_before": before["alignment"], "alignment": h["alignment"].duplicate(), "shift": sh,
		"rare": Catalog.is_rare(c)}


## Legendary gate (legend_gate.gd): if a hero is eligible, this encounter node rolls the rising
## chance; on success the node BECOMES that hero's legend's memory (instead of the map's encounter).
func _roll_legend() -> bool:
	var state := {"legendaries": _legendaries, "appeared": _legend_appeared, "misses": _legend_misses}
	var best := -1
	for i in _heroes.size():
		if LegendGate.eligible(_heroes[i], state) and not LegendGate.encounter_for(String(_heroes[i]["class"])).is_empty() \
				and (best < 0 or int(_heroes[i]["memories"]) > int(_heroes[best]["memories"])):
			best = i
	if best < 0:
		return false
	if not LegendGate.roll(_rng(7000 + _layer), state):
		_legend_misses += 1
		return false
	_legend_appeared = true
	_enc = LegendGate.encounter_for(String(_heroes[best]["class"]))
	_enc_kind = "legend"
	_bound = []
	for c: Dictionary in _enc.get("choices", []):
		_bound.append({"choice": c, "hero_index": best})
	_say("  a legend's memory surfaces for %s" % _heroes[best]["name"])
	return true


func _advance_hero(h: Dictionary) -> void:
	var eff := Alignment.effective_for_hero(h)
	var region := Alignment.region_of(eff)
	var cid := Alignment.advanced_class_for(String(h["base"]), eff)
	if cid == "":
		cid = _nearest_advanced(String(h["base"]), eff)
	h["class"] = cid
	h["level"] = 1
	h["held"] = false
	h["region"] = region
	h["placeholder"] = String(GameData.get_class_def(cid).get("region", "")) != region
	h["advanced_at"] = _layer + 1
	_say("  %s ADVANCES at %s (%s) -> %s%s" % [h["name"], eff, region, GameData.get_class_def(cid)["name"],
		" [placeholder: region class not authored]" if h["placeholder"] else ""])


## Authored advanced class of this base whose region centre is nearest (content-gap fallback).
static func _nearest_advanced(base: String, pos: Array) -> String:
	var centres := {"N": [0, 0], "LG": [1.5, 1.5], "CG": [1.5, -1.5], "LE": [-1.5, 1.5], "CE": [-1.5, -1.5],
		"LG*": [2, 2], "CG*": [2, -2], "LE*": [-2, 2], "CE*": [-2, -2]}
	var best := ""
	var best_d := INF
	for id: String in GameData.Classes.CLASSES:
		var c: Dictionary = GameData.Classes.CLASSES[id]
		if String(c.get("tier", "")) != "advanced" or String(c.get("base", "")) != base:
			continue
		var ctr: Array = centres.get(String(c.get("region", "N")), [0, 0])
		var d := pow(float(ctr[0]) - pos[0], 2) + pow(float(ctr[1]) - pos[1], 2)
		if d < best_d:
			best_d = d
			best = id
	return best


func _ascend(h: Dictionary) -> void:
	var leg := Alignment.legendary_class_for(String(h["class"]))
	h["legendary"] = true
	_legendaries += 1
	h["legendary_placeholder"] = leg == ""
	if leg != "":
		h["class"] = leg
		h["level"] = 1
	_say("  %s becomes LEGENDARY%s" % [h["name"], " (" + GameData.get_class_def(leg)["name"] + ")" if leg != ""
		else " [placeholder: no Legendary authored for " + String(h["class"]) + "]"])


func _add_hero(cls: String, hname: String) -> void:
	var used := {}
	for h: Dictionary in _heroes:
		used[int(h["slot"][0]) * 4 + int(h["slot"][1])] = true
	var pref := int(GameData.get_class_def(cls)["preferred_col"])
	var slot := [0, 0]
	var found := false
	for col in [pref, 1 - pref]:
		for row in [1, 2, 0, 3]:
			if not found and not used.has(col * 4 + row):
				slot = [col, row]
				found = true
	_heroes.append({"name": hname, "class": cls, "base": cls, "level": 1,
		"items": {"weapon": "", "armor": "", "relic": ""}, "alignment": Alignment.start_for(cls),
		"slot": slot, "memories": 0, "held": false, "held_ever": false, "legendary": false,
		"legendary_placeholder": false, "region": "", "placeholder": false, "advanced_at": 0,
		"joined_at": maxi(0, _layer + 1)})


func _has_name(n: String) -> bool:
	for h: Dictionary in _heroes:
		if h["name"] == n:
			return true
	return false


func _fresh_name(rng: Rng) -> String:
	var start := rng.int_range(0, T.HERO_NAMES.size() - 1)
	for k in T.HERO_NAMES.size():
		var n: String = T.HERO_NAMES[(start + k) % T.HERO_NAMES.size()]
		if not _has_name(n):
			return n
	return "Wanderer"


## Gives an item to hero hi. Relics bind on equip: a hero's relic is never replaced, so a relic
## goes to the first hero (starting at hi) with an empty relic slot, or is left behind.
## Weapons/armor replace the current one only if their stat total is higher.
func _grant_item(hi: int, iid: String) -> String:
	var it := GameData.get_item(iid)
	if it.is_empty():
		return ""
	var slot := String(it["slot"])
	if slot == "relic":
		for k in _heroes.size():
			var rh: Dictionary = _heroes[(hi + k) % _heroes.size()]
			if String(rh["items"]["relic"]) == "":
				rh["items"]["relic"] = iid
				_items_found.append(iid)
				_say("  %s binds relic %s (offset %s)" % [rh["name"], iid, it.get("alignment", [0, 0])])
				return iid
		_say("  relic %s left behind (every relic slot is bound)" % iid)
		return ""
	var h: Dictionary = _heroes[hi]
	var cur := String(h["items"][slot])
	if cur == "" or _item_value(iid) > _item_value(cur):
		h["items"][slot] = iid
		_items_found.append(iid)
		_say("  %s equips %s" % [h["name"], iid])
		return iid
	return ""


static func _item_value(iid: String) -> float:
	var v := 0.0
	var stats: Dictionary = GameData.get_item(iid).get("stats", {})
	for k: String in stats:
		v += float(stats[k]) * (0.2 if k == "hp" else 1.0)
	return v


func _monsters() -> Dictionary:
	var rng := _rng(5000 + _layer)
	var g := PartyGen.monster_group(rng, _layer + 1)
	var count := clampi(_heroes.size(), int(T.RUN["monster_count_min"]), int(T.RUN["monster_count_max"]))
	@warning_ignore("integer_division")
	var lvl := clampi(int(T.RUN["monster_level_base"]) + _layer / int(T.RUN["monster_level_per_layers"]), 1, 10)
	var hs: Array = g["heroes"].slice(0, count)
	for h: Dictionary in hs:
		h["level"] = lvl
	return {"name": "Vault Monsters", "heroes": hs}


## Guardian definition for the current floor (guardians.json).
func _guardian_def() -> Dictionary:
	var gs: Array = _guardian_data().get("guardians", [])
	return gs[mini(_floor() - 1, gs.size() - 1)]


static var _guardian_cache: Dictionary = {}


static func _guardian_data() -> Dictionary:
	if _guardian_cache.is_empty():
		var f := FileAccess.open("res://core/run/guardians.json", FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		if d is Dictionary:
			_guardian_cache = d
	return _guardian_cache


static func _guardians() -> Array:
	return _guardian_data().get("guardians", [])


## The Crystal's memory sequence from story progress (run option story_chapter, default 1):
## every memory of the current chapter first, filled up from earlier chapters; seeded order.
func _crystal_sequence() -> Array:
	var chapter := maxi(1, int(_opts.get("story_chapter", 1)))
	var rng := _rng(9)
	var cur: Array = []
	var earlier: Array = []
	var mems: Dictionary = GameData.Memories.MEMORIES
	for id: String in mems:
		var c := int(mems[id]["chapter"])
		if c == chapter:
			cur.append(id)
		elif c < chapter:
			earlier.append(id)
	if cur.is_empty() and earlier.is_empty():   # chapter beyond what is written: everything
		cur = mems.keys()
	_shuffle(cur, rng)
	_shuffle(earlier, rng)
	var seq: Array = (cur + earlier).slice(0, int(T.RUN["crystal_memories"]))
	_shuffle(seq, rng)
	return seq


## Memory ids knocked out in a Crystal fight (a ko whose uid came from a spawn): codex records.
static func _defeated_memories(result: Dictionary) -> Array:
	var by_uid := {}
	var out: Array = []
	for ev: Dictionary in result.get("events", []):
		if ev["type"] == "spawn":
			by_uid[int(ev["uid"])] = String(ev["memory"])
		elif ev["type"] == "ko" and by_uid.has(int(ev["uid"])):
			out.append(by_uid[int(ev["uid"])])
	return out


## Floor guardian as a monster side: authored name, intro and composition.
func _floor_guardian() -> Dictionary:
	var g := _guardian_def()
	var hs: Array = []
	var counts := {}
	for m: Dictionary in g["monsters"]:
		counts[m["class"]] = int(counts.get(m["class"], 0)) + 1
	var seen := {}
	for m: Dictionary in g["monsters"]:
		var cid := String(m["class"])
		var nm := String(m.get("name", GameData.get_class_def(cid)["name"]))
		if int(counts[cid]) > 1:
			nm += " " + "ABCD"[int(seen.get(cid, 0))]
			seen[cid] = int(seen.get(cid, 0)) + 1
		hs.append({"name": nm, "class": cid, "level": clampi(int(g["level"]) + int(m.get("level_offset", 0)), 1, 10), "items": {}, "alignment": [0, 0],
			"slot": [int(m["slot"][0]), int(m["slot"][1])]})
	return {"name": String(g["name"]), "heroes": hs, "meta": {"title": String(g["name"]), "intro": String(g["intro"])}}


func _end(outcome: String) -> void:
	_outcome = outcome
	_step = "ended"
	_say("== %s at depth %d (floor %d), health %d ==" % [outcome.to_upper(), _layer + 1, _floor(), _health])
	_summary = _make_summary()
	if bool(_opts.get("save_echo", true)) and _heroes.size() >= 2:
		if not _snapshots.has(_floor()):
			_snapshots[_floor()] = combat_party()
		var added: Array = []
		var keys: Array = _snapshots.keys()
		keys.sort()
		for f: int in keys:
			added.append(_pool.add(_snapshots[f], {"generated": false, "floor": f, "depth": _layer + 1,
				"team_name": _party_name(), "crest": String(_opts.get("crest", "")),
				"outcome": outcome, "seed": seed_value, "pvp_wins": _stats["pvp_wins"]}))
		_pool.save()
		_summary["echo"] = added[-1]
		_summary["echoes_recorded"] = added.size()


func _make_summary() -> Dictionary:
	var depth := _layer + 1
	var best_floor := int(_opts.get("best_floor", 0))
	var new_floors: Array = range(best_floor + 1, _floor() + 1) if _layer >= 0 else []
	var g_depth := depth * int(T.RUN["glimmers_per_layer"])
	var g_pvp := int(_stats["pvp_wins"]) * int(T.RUN["glimmers_per_pvp_win"])
	var g_ms := new_floors.size() * int(T.RUN["glimmers_per_new_floor"])
	var g_frag := _fragments * int(T.RUN["glimmers_per_fragment"]) if _outcome == "fallen" else 0
	var heroes: Array = []
	for h: Dictionary in _heroes:
		var tier := String(GameData.get_class_def(String(h["class"]))["tier"])
		heroes.append({"name": h["name"], "base": h["base"], "class": h["class"],
			"tier": "legendary" if h["legendary"] else tier, "level": h["level"], "memories": h["memories"],
			"advanced": tier != "base", "held_ever": h["held_ever"], "legendary": h["legendary"],
			"region": h["region"], "placeholder_class": h["placeholder"] or h["legendary_placeholder"],
			"joined_at": h["joined_at"], "advanced_at": h["advanced_at"]})
	var s := {"seed": seed_value, "vault": _vault, "outcome": _outcome if _outcome != "" else "in_progress",
		"depth": depth, "floor": _floor(), "phase_reached": _phase_reached, "nodes_visited": _stats["nodes"],
		"health": _health, "pvp_wins": _stats["pvp_wins"], "pvp_losses": _stats["pvp_losses"],
		"monster_wins": _stats["monster_wins"], "monster_losses": _stats["monster_losses"],
		"memories": _stats["memories"], "wasted_memories": _stats["wasted_memories"],
		"glimmers": g_depth + g_pvp + g_ms + g_frag,
		"glimmer_breakdown": {"depth": g_depth, "pvp": g_pvp, "milestones": g_ms, "fragments": g_frag},
		"crystal_reached": _fight_kind == "crystal", "fragments": _fragments,
		"memories_defeated": _memories_defeated.duplicate(), "story_chapter": maxi(1, int(_opts.get("story_chapter", 1))),
		"new_floors": new_floors, "shards": 0, "lore_items": _lore.duplicate(), "items_found": _items_found.duplicate(),
		"heroes": heroes, "encounters_seen": _seen.duplicate(), "legend_offered": _legend_appeared,
		"guardian_wins": _stats["guardian_wins"], "guardian_losses": _stats["guardian_losses"],
		"rests": _stats["rests"], "healed": _stats["healed"], "health_lost_by_phase": _health_lost.duplicate(),
		"death": _death.duplicate(), "encounter_nodes": _stats["encounter_nodes"],
		"two_choice_nodes": _stats["two_choice_nodes"], "fights_by_floor": _fights_by_floor.duplicate(true),
		"guardian_health_lost": _stats["guardian_health_lost"], "team_name": _party_name(), "rivals": _rivals.duplicate()}
	if _outcome == "victory":
		s["shards"] = int(T.RUN["victory_shards"])
		var party := combat_party()
		var f: Dictionary = Formation.effective(party)["effective"]   # the shape that actually fought
		s["monument"] = {"vault": _vault, "seed": seed_value, "party_name": party["name"],
			"heroes": party["heroes"], "formation": {"id": f["id"], "name": f["name"]}}
		var ch := clampi(int(_opts.get("story_chapter", 1)), 1, T.REMEMBRANCES.size())
		s["remembrance"] = T.REMEMBRANCES[ch].duplicate()
	return s
