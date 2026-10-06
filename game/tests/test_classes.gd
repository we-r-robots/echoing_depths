extends "res://tests/test_case.gd"
## The advanced classes the user approved in round 1 (docs/design/class-verdicts-round1.md): the
## roster and its regions, the fallback for regions with no approved class, save migration, and
## every new ability as a deterministic sim.

const CombatSim = preload("res://core/combat_sim.gd")
const GameData = preload("res://core/game_data.gd")
const Alignment = preload("res://core/alignment.gd")
const Echo = preload("res://core/echo.gd")

const FAST := {"start_charge_spread": 0, "start_charge_bonus": 100}   # everyone starts at 99 charge

## base -> region -> class: exactly the APPROVED regions (live classes kept where the region is
## PICK ONE or the live class was voted maybe: Paladin, Duelist).
const ROSTER := {
	"fighter": {"LG": "paladin", "LE": "shackler", "CE": "berserker", "LE*": "iron_marshal", "CG*": "echoblade"},
	"rogue": {"CE": "cutpurse", "CE*": "fadewalker", "CG": "duelist", "LE": "assassin", "LE*": "nightshade",
		"LG*": "unseen_warden"},
	"healer": {"LG": "cleric", "N": "threadmender", "LG*": "lumenward", "CG": "rekindler", "LE": "tithekeeper",
		"CG*": "wickburner", "LE*": "confessor", "CE*": "gravecaller"},
	"mage": {"CG": "stormwake", "N": "archmage", "CG*": "starcaller", "LG": "lampwright", "CE": "warlock",
		"LE": "runebinder", "LG*": "chronist", "CE*": "wildfire"},
}


func _sim(seed_value: int, a: Dictionary, b: Dictionary, opts := {}) -> Dictionary:
	var o := {"tuning": FAST}
	o.merge(opts, true)
	return CombatSim.simulate(seed_value, a, b, o)


## Huge shields on side-0 units (by slot) so the fixture's heroes live long enough to show the
## ability under test.
static func _guard(slots: Array) -> Array:
	var out: Array = []
	for sl: Array in slots:
		out.append({"side": 0, "slot": sl, "status": "shield", "amount": 99999, "dur_ms": 60000})
	return out


func _first(r: Dictionary, type: String, pred: Callable) -> Dictionary:
	for ev: Dictionary in of_type(r, type):
		if pred.call(ev):
			return ev
	return {}


func _ability_of(r: Dictionary, uid: int) -> Dictionary:
	return _first(r, "action_start", func(ev: Dictionary) -> bool: return int(ev["uid"]) == uid and ev["kind"] == "ability")


## Events between an action_start and the next action_start.
func _during(r: Dictionary, act: Dictionary) -> Array:
	var out: Array = []
	var on := false
	for ev: Dictionary in r["events"]:
		if ev == act:
			on = true
			continue
		if on and ev["type"] == "action_start":
			break
		if on:
			out.append(ev)
	return out


# ------------------------------------------------------------------ roster

func test_roster_is_exactly_the_approved_regions() -> void:
	var n := 0
	for cid: String in GameData.Classes.CLASSES:
		var c: Dictionary = GameData.Classes.CLASSES[cid]
		if String(c["tier"]) != "advanced":
			continue
		n += 1
		var want: Dictionary = ROSTER.get(String(c["base"]), {})
		eq(String(want.get(String(c["region"]), "")), cid, "%s sits in an approved %s region" % [cid, c["base"]])
	var total := 0
	for b: String in ROSTER:
		total += (ROSTER[b] as Dictionary).size()
		for reg: String in ROSTER[b]:
			eq(Alignment.region_class(b, reg), String(ROSTER[b][reg]), "%s %s -> %s" % [b, reg, ROSTER[b][reg]])
	eq(n, total, "no unapproved advanced class in data")
	check(not GameData.has_class("necromancer"), "Necromancer is gone (the user dropped it)")
	eq(String(GameData.get_class_def("shackler")["name"]), "Shackler", "Shackler keeps a stable id; its name is data only")


func test_unwritten_regions_fall_back_to_the_nearest_approved_region() -> void:
	# PROVISIONAL: nearest region by grid steps from the hero's cell; ties -> nearer the base's start
	eq(Alignment.advanced_class_for("fighter", [0, 1]), "paladin", "Fighter N (start): LG and LE tie at 1 step -> data order (LG)")
	eq(Alignment.advanced_class_for("fighter", [0, -1]), "berserker", "Fighter N, Freedom side -> CE 1 step")
	eq(Alignment.advanced_class_for("fighter", [1, -1]), "paladin", "Fighter CG: LG, CE, CG* tie at 2 -> LG is nearest the start")
	eq(Alignment.advanced_class_for("fighter", [2, 2]), "paladin", "Fighter LG* -> LG")
	eq(Alignment.advanced_class_for("fighter", [-2, -2]), "berserker", "Fighter CE* -> CE")
	eq(Alignment.advanced_class_for("rogue", [0, 0]), "cutpurse", "Rogue N -> CE (the start's region)")
	eq(Alignment.advanced_class_for("rogue", [2, -2]), "duelist", "Rogue CG* -> CG")
	eq(Alignment.advanced_class_for("rogue", [1, 1]), "duelist", "Rogue LG: CG, LE, LG* tie at 2; CG and LE tie on the start -> data order")
	eq(Alignment.advanced_class_for("healer", [-1, -1]), "threadmender", "Healer CE (pick one) -> N 1 step")
	eq(Alignment.advanced_class_for("healer", [-2, -1]), "threadmender", "Healer CE edge: N and CE* tie at 1 -> N is nearer the start")
	eq(Alignment.advanced_class_for("healer", [-2, -2]), "gravecaller", "Healer CE* -> its own class")
	eq(Alignment.advanced_class_for("mage", [-2, 2]), "runebinder", "Mage LE* (open) -> LE")
	check(Alignment.is_fallback("mage", [-2, 2]) and not Alignment.is_fallback("mage", [-1, 1]), "is_fallback marks stand-ins")
	for b: String in ROSTER:
		for g in range(-2, 3):
			for l in range(-2, 3):
				check(Alignment.advanced_class_for(b, [g, l]) != "", "%s at [%d,%d] always advances" % [b, g, l])


func test_necromancer_saves_migrate_to_gravecaller() -> void:
	var raw := {"format": Echo.FORMAT, "version": 2, "data_version": 1, "name": "Old", "meta": {},
		"heroes": [{"name": "Vael", "class": "necromancer", "level": 2, "items": {}, "alignment": [-2, -2], "slot": [1, 1]},
			{"name": "Pell", "class": "fighter", "level": 1, "items": {}, "alignment": [0, 1], "slot": [0, 1]}]}
	var res := Echo.from_dict(raw)
	check(res.has("echo"), "an Echo naming the dropped Necromancer still loads: %s" % str(res.get("error", "")))
	eq(String(res["echo"]["heroes"][0]["class"]), "gravecaller", "Necromancer -> Gravecaller")
	eq(GameData.canonical_class("necromancer"), "gravecaller", "canonical id")
	var heroes := [{"class": "necromancer"}, {"class": "cleric"}]
	eq(GameData.migrate_heroes(heroes), 1, "one hero migrated")
	eq(String(heroes[0]["class"]), "gravecaller", "in place")


func test_every_new_ability_has_label_tooltip_and_icon() -> void:
	for b: String in ROSTER:
		for reg: String in ROSTER[b]:
			var cid: String = ROSTER[b][reg]
			var a := GameData.get_action(String(GameData.get_class_def(cid)["ability"]))
			var s := PartyModel.ability_short(a)
			check(s != "" and s.length() <= 20, "%s short label '%s'" % [cid, s])
			check(PartyModel.ability_desc(a).length() > 20, "%s has a tooltip sentence" % cid)
			if a.has("icon"):
				check(EffectIcons.ICONS.has(String(a["icon"])), "%s icon %s is in the shared set" % [cid, a["icon"]])
			if a.has("fallback"):
				check(not GameData.get_action(String(a["fallback"])).is_empty(), "%s fallback exists" % cid)
	for id: String in GameData.Statuses.STATUSES:
		var st: Dictionary = GameData.Statuses.STATUSES[id]
		check(EffectIcons.ICONS.has(String(st["icon"])), "status %s has an icon" % id)
		check(String(st["short"]).length() <= 20, "status %s short label" % id)
	check(GameData.get_action("grave_bolt").has("provisional"), "Gravecaller's fallback is marked PROVISIONAL in data")
	check(String(GameData.get_action("brand_of_flame")["name"]).contains("Flame"), "Confessor's brand is flame-themed")


# ------------------------------------------------------------------ Fighter

func test_shackler_drags_the_back_foe_forward() -> void:
	var a := party([hero("shackler", 0, 1, 2), hero("mage", 1, 3)])
	var b := party([hero("fighter", 0, 1, 3), hero("healer", 1, 1)])
	var r := _sim(1, a, b)
	var front := uid_at(r, 1, 0, 1)
	var back := uid_at(r, 1, 1, 1)
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "shackle", "Shackle fires")
	var moves: Array = []
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "move":
			moves.append(ev)
	eq(moves.size(), 2, "two moves: pulled and pushed")
	eq([int(moves[0]["uid"]), moves[0]["effect"], moves[0]["to"]], [back, "pulled", [0, 1]], "the back foe is pulled forward")
	eq([int(moves[1]["uid"]), moves[1]["effect"], moves[1]["to"]], [front, "pushed", [1, 1]], "the struck foe is pushed back")
	var next := _first(r, "action_start", func(ev: Dictionary) -> bool:
		return int(ev["uid"]) == 0 and float(ev["t"]) > float(act["t"]))
	if not next.is_empty():
		eq(int(next["target"]), back, "melee now meets the pulled unit")


func test_iron_marshal_drives_edge_adjacent_allies() -> void:
	var a := party([hero("iron_marshal", 0, 1, 2), hero("rogue", 0, 2), hero("mage", 1, 1), hero("healer", 1, 3)])
	var b := party([hero("stone_sentinel", 0, 1, 6), hero("stone_sentinel", 0, 2, 6)])
	var r := _sim(2, a, b)
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "drive_on", "Drive On fires")
	var driven := {}
	var paid := {}
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "gauge":
			driven[int(ev["uid"])] = true
			eq(float(ev["gauge"]), 1.0, "its gauge is full")
		if ev["type"] == "damage" and String(ev["primary"].get("id", "")) == "cost":
			paid[int(ev["dst"])] = true
	var rogue := uid_at(r, 0, 0, 2)
	var mage := uid_at(r, 0, 1, 1)
	var healer := uid_at(r, 0, 1, 3)
	check(driven.has(rogue) and driven.has(mage) and not driven.has(healer), "edge-adjacent allies only (%s)" % str(driven.keys()))
	check(paid.has(rogue) and paid.has(mage) and not paid.has(0), "each driven ally pays a little HP, not the Marshal")
	var eff: Dictionary = GameData.get_action("drive_on")["effects"][0]
	eq(String(eff["adjacency"]), "edge", "the adjacency set is a data field (edge as written; 'all' = each adjacent)")


func test_iron_marshal_alone_strikes_instead() -> void:
	var a := party([hero("iron_marshal", 0, 0, 2), hero("mage", 1, 3)])
	var r := _sim(3, a, duo(hero("fighter", 0, 0)))
	eq(String(_ability_of(r, 0)["action"]), "marshal_strike", "no ally beside it: the fallback strike")


func test_echoblade_summons_an_echo_that_never_charges() -> void:
	var a := party([hero("echoblade", 0, 1, 2), hero("mage", 1, 3)])
	var b := party([hero("stone_sentinel", 0, 1, 6), hero("stone_sentinel", 1, 1, 6)])
	var r := _sim(4, a, b, {"start_statuses": _guard([[0, 1], [1, 3]])})
	var sp := _first(r, "spawn", func(ev: Dictionary) -> bool: return ev["summon"] == "echo")
	check(not sp.is_empty(), "an echo is summoned")
	eq(int(sp["summoner"]), 0, "summoned by the Echoblade")
	eq(int(sp["slot"][0]), 0, "into the front column")
	check(int(sp["slot"][1]) == 0 or int(sp["slot"][1]) == 2, "the empty front slot nearest its row")
	eq(sp["unit"]["basic"]["id"], "strike", "copies its basic attack")
	eq(sp["unit"]["ability"]["id"], "", "and nothing else")
	var echo := int(sp["uid"])
	var echo_alive := true
	for ev: Dictionary in r["events"]:
		if float(ev["t"]) < float(sp["t"]):
			continue
		if ev["type"] == "ko" and int(ev["uid"]) == echo:
			echo_alive = false
		if ev["type"] == "charge" and int(ev["uid"]) == echo:
			check(false, "an echo never charges")
		if ev["type"] == "charge" and int(ev["uid"]) == 0 and echo_alive and int(ev["delta"]) > 0:
			check(false, "no charge for the Echoblade while its echo stands (ruling 4)")
	var acted := _first(r, "action_start", func(ev: Dictionary) -> bool: return int(ev["uid"]) == echo)
	check(not acted.is_empty(), "the echo fights")


func test_echoblade_with_a_full_front_strikes_instead() -> void:
	var a := party([hero("echoblade", 0, 0, 2), hero("fighter", 0, 1), hero("rogue", 0, 2), hero("fighter", 0, 3)])
	var r := _sim(5, a, duo(hero("fighter", 0, 0)))
	eq(String(_ability_of(r, 0)["action"]), "echo_strike", "no empty front slot: the fallback strike")


# ------------------------------------------------------------------ Rogue

func test_cutpurse_steals_charge_from_the_most_charged_foe() -> void:
	var a := party([hero("cutpurse", 0, 1, 2), hero("mage", 1, 3)])
	var b := party([hero("fighter", 0, 1, 3), hero("healer", 1, 2, 3)])
	var r := _sim(6, a, b, {"tuning": {"start_charge_spread": 0, "start_charge_bonus": 0}})
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "pilfer", "Pilfer fires")
	var drained := false
	var gained := false
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "charge" and ev["reason"] == "drain" and int(ev["uid"]) == int(act["target"]):
			drained = true
			check(int(ev["delta"]) < 0 and int(ev["delta"]) >= -30, "takes up to 30 charge")
		if ev["type"] == "charge" and int(ev["uid"]) == 0 and ev["reason"] == "effect":
			gained = true
	check(drained and gained, "the foe loses charge and the Cutpurse gains it")


func test_fadewalker_vanishes_after_striking() -> void:
	var a := party([hero("fadewalker", 0, 1, 2), hero("fighter", 0, 2, 2)])
	var b := party([hero("fighter", 0, 1, 3), hero("rogue", 0, 2, 3)])
	var r := _sim(7, a, b, {"start_statuses": _guard([[0, 1], [0, 2]])})
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "vanishing_cut", "Vanishing Cut fires")
	var hid := _first(r, "status", func(ev: Dictionary) -> bool: return int(ev["uid"]) == 0 and ev["status"] == "hidden")
	check(not hid.is_empty(), "it is hidden after the strike")
	var until := float(hid["t"]) + float(hid["duration"])
	for ev: Dictionary in of_type(r, "action_start"):
		if int(ev["uid"]) >= 2 and float(ev["t"]) > float(hid["t"]) and float(ev["t"]) < until - 0.05 and ev["area"] == "single":
			check(int(ev["target"]) != 0, "no foe single-targets it while hidden")


func test_nightshade_poisons_the_healthiest_foe() -> void:
	var a := party([hero("nightshade", 0, 1, 2), hero("mage", 1, 3)])
	var b := party([hero("hollow_rat", 0, 1, 1), hero("stone_sentinel", 0, 2, 4)])
	var r := _sim(8, a, b, {"start_statuses": _guard([[0, 1], [1, 3]])})
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "slow_venom", "Slow Venom fires")
	eq(int(act["target"]), uid_at(r, 1, 0, 2), "the healthiest foe (the Sentinel)")
	var ticks := 0
	for ev: Dictionary in of_type(r, "damage"):
		if ev["kind"] == "status" and ev["primary"]["id"] == "poison":
			ticks += 1
	check(ticks >= 3, "the poison ticks (%d)" % ticks)


func test_unseen_warden_vanishes_then_arrests() -> void:
	var a := party([hero("unseen_warden", 0, 1, 2), hero("fighter", 0, 2, 2)])
	var b := party([hero("fighter", 0, 0, 2), hero("fighter", 0, 1, 2), hero("fighter", 0, 2, 2)])
	var r := _sim(9, a, b)
	var act := _ability_of(r, 0)
	eq(String(act["action"]), "unseen_arrest", "Unseen Arrest fires")
	var hid := _first(r, "status", func(ev: Dictionary) -> bool: return int(ev["uid"]) == 0 and ev["status"] == "hidden")
	check(not hid.is_empty(), "it slips out of sight first")
	var arrest := _first(r, "action_start", func(ev: Dictionary) -> bool: return ev["action"] == "unseen_arrest_strike")
	check(not arrest.is_empty() and float(arrest["t"]) >= float(hid["t"]) + float(hid["duration"]) - 0.001, "then the arrest follows")
	var stunned := -1
	var blinded := {}
	for ev: Dictionary in _during(r, arrest):
		if ev["type"] == "status" and ev["status"] == "stun":
			stunned = int(ev["uid"])
		if ev["type"] == "status" and ev["status"] == "blind":
			blinded[int(ev["uid"])] = true
	eq(stunned, int(arrest["target"]), "the most charged foe is stunned")
	check(blinded.size() >= 1 and not blinded.has(stunned), "the foes beside it are blinded (%s)" % str(blinded.keys()))


# ------------------------------------------------------------------ Healer

func test_threadmender_links_healthiest_and_weakest() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("threadmender", 1, 1, 2), hero("mage", 1, 2)])
	var r := _sim(10, a, duo(hero("fighter", 0, 0, 2)), {"start_hp": [{"side": 0, "slot": [1, 2], "hp": 20}],
		"start_statuses": _guard([[0, 1], [1, 1], [1, 2]])})
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "bind_lives", "Bind Lives fires")
	var linked := {}
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "status" and ev["status"] == "link":
			linked[int(ev["uid"])] = true
	check(linked.has(uid_at(r, 0, 1, 2)) and linked.size() == 2, "the weakest ally is linked to the healthiest")


func test_lumenward_overheal_becomes_a_shield() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("lumenward", 1, 1, 2)])
	var r := _sim(11, a, duo(hero("fighter", 0, 0)), {"start_hp": [{"side": 0, "slot": [0, 1], "hp": 200}]})
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "lumen_ward", "Lumen Ward fires")
	var healed := {}
	var shields := {}
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "heal":
			healed[int(ev["dst"])] = int(ev["amount"])
		if ev["type"] == "status" and ev["status"] == "shield":
			shields[int(ev["uid"])] = int(float(ev["value"]))
	check(shields.has(1), "the unhurt Lumenward turns its whole heal into a shield")
	if healed.has(0) and shields.has(0):
		check(int(healed[0]) > 0 and int(shields[0]) > 0, "a nearly full ally is topped up and shielded with the rest")


func test_rekindler_relights_the_first_fallen_once() -> void:
	var a := party([hero("rogue", 0, 1), hero("rekindler", 1, 1, 2), hero("fighter", 0, 2, 3)])
	var b := party([hero("berserker", 0, 1, 4), hero("archmage", 1, 1, 4)])
	var r := CombatSim.simulate(12, a, b, {"start_hp": [{"side": 0, "slot": [0, 1], "hp": 1}]})
	var rev := of_type(r, "revive")
	check(rev.size() >= 1, "a fallen ally is rekindled")
	check(rev.size() <= 1, "once per fight")
	if not rev.is_empty():
		var ko := _first(r, "ko", func(ev: Dictionary) -> bool: return true)
		eq(int(rev[0]["uid"]), int(ko["uid"]), "the first to fall")
		var mx := 0
		for u: Dictionary in r["events"][0]["sides"][0]["units"]:
			if int(u["uid"]) == int(rev[0]["uid"]):
				mx = int(u["max_hp"])
		eq(int(rev[0]["hp"]), int(round(mx * 0.3)), "at 30% HP")


func test_rekindler_heals_when_nobody_has_fallen() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("rekindler", 1, 1, 2)])
	var r := _sim(13, a, duo(hero("fighter", 0, 0)), {"start_hp": [{"side": 0, "slot": [0, 1], "hp": 60}],
		"start_statuses": _guard([[0, 1], [1, 1]])})
	eq(String(_ability_of(r, 1)["action"]), "rekindle_mend", "nobody to relight: it heals the weakest")


func test_tithekeeper_moves_hp_from_strong_to_weak() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("tithekeeper", 1, 1, 2), hero("mage", 1, 2)])
	var r := _sim(14, a, duo(hero("fighter", 0, 0)), {"start_hp": [{"side": 0, "slot": [1, 2], "hp": 20}]})
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "tithe", "Tithe fires")
	var paid := 0
	var given := 0
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "damage" and ev["primary"].get("id", "") == "tithe":
			paid = int(ev["amount"])
		if ev["type"] == "heal" and int(ev["dst"]) == uid_at(r, 0, 1, 2):
			given = int(ev["amount"])
	check(paid > 0 and given > paid, "the weakest gets back more than the healthiest paid (%d -> %d)" % [paid, given])


func test_wickburner_burns_its_hp_to_heal_the_others() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("wickburner", 1, 1, 2), hero("rogue", 0, 2)])
	var r := _sim(15, a, duo(hero("fighter", 0, 0)),
		{"start_hp": [{"side": 0, "slot": [0, 1], "hp": 60}, {"side": 0, "slot": [0, 2], "hp": 30}],
		"start_statuses": _guard([[0, 1], [1, 1], [0, 2]])})
	var act := _ability_of(r, 2)   # slot order: fighter 0, rogue 1, Wickburner 2
	eq(String(act["action"]), "burn_to_mend", "Burn to Mend fires")
	var cost := 0
	var healed := 0
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "damage" and int(ev["dst"]) == 2 and ev["primary"].get("id", "") == "cost":
			cost = int(ev["amount"])
		if ev["type"] == "heal":
			check(int(ev["dst"]) != 2, "it heals the others, not itself")
			healed += int(ev["amount"])
	check(cost > 0 and healed > cost, "spends HP (%d) to heal more (%d)" % [cost, healed])


func test_confessor_brands_against_healing() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("confessor", 1, 1, 2)])
	var b := party([hero("fighter", 0, 1), hero("cleric", 1, 1, 3)])
	var r := _sim(16, a, b)
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "brand_of_flame", "Brand of Flame fires")
	var br := _first(r, "status", func(ev: Dictionary) -> bool: return ev["status"] == "heal_block")
	eq(int(br["uid"]), int(act["target"]), "the struck foe is branded")


func test_gravecaller_raises_a_weaker_husk() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("gravecaller", 1, 1, 2)])
	var b := party([hero("rogue", 0, 1), hero("mage", 1, 3)])
	var r := CombatSim.simulate(17, a, b, {"start_hp": [{"side": 1, "slot": [0, 1], "hp": 1}]})
	var sp := _first(r, "spawn", func(ev: Dictionary) -> bool: return ev["summon"] == "husk")
	check(not sp.is_empty(), "a husk is raised")
	if sp.is_empty():
		return
	var src: Dictionary = {}
	for side: Dictionary in r["events"][0]["sides"]:
		for u: Dictionary in side["units"]:
			if int(u["uid"]) == int(sp["raised"]):
				src = u
	eq(int(sp["side"]), 0, "it fights for the Gravecaller's side")
	eq(int(sp["unit"]["max_hp"]), int(round(int(src["max_hp"]) * 0.5)), "clearly weaker: half its max HP")
	check(int(sp["unit"]["atk"]) < int(src["atk"]), "and weaker blows")
	eq(String(sp["unit"]["basic"]["id"]), String(src["basic"]["id"]), "it fights with the fallen unit's basic action")


func test_gravecaller_with_no_fallen_hits_the_weakest_foe() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("gravecaller", 1, 1, 2)])
	var r := _sim(18, a, party([hero("fighter", 0, 1, 3), hero("mage", 1, 3)]))
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "grave_bolt", "PROVISIONAL fallback: Grave Bolt")


# ------------------------------------------------------------------ Mage

func test_warlock_hexfire_climbs_the_back_column() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("warlock", 1, 1, 2)])
	var b := party([hero("fighter", 0, 1, 4), hero("mage", 1, 0), hero("healer", 1, 2), hero("mage", 1, 3)])
	var r := _sim(19, a, b)
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "hexfire", "Hexfire fires")
	eq(act["area"], "column", "a column area")
	eq(int(act["target"]), uid_at(r, 1, 1, 3), "it starts at the bottom of the back column")
	var order: Array = []
	var last_t := -1.0
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "damage" and int(ev["src"]) == 1:
			order.append(int(ev["dst"]))
			check(float(ev["t"]) > last_t, "each space is hit after the one below it")
			last_t = float(ev["t"])
	eq(order, [uid_at(r, 1, 1, 3), uid_at(r, 1, 1, 2), uid_at(r, 1, 1, 0)], "bottom to top, back column only")


func test_stormwake_strikes_three_times() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("stormwake", 1, 1, 2)])
	var r := _sim(20, a, party([hero("stone_sentinel", 0, 1, 6), hero("stone_sentinel", 0, 2, 6)]))
	var act := _ability_of(r, 1)
	var hits := 0
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "damage" and int(ev["src"]) == 1:
			hits += 1
			eq(ev["kind"], "magic", "magic hits")
	eq(hits, 3, "three separate hits")


func test_starcaller_draws_a_gift_for_an_ally() -> void:
	var gifts := {}
	for s in 12:
		var a := party([hero("fighter", 0, 1, 3), hero("starcaller", 1, 1, 2)])
		var r := _sim(100 + s, a, duo(hero("fighter", 0, 0)))
		var act := _ability_of(r, 1)
		eq(String(act["action"]), "draw_star", "Draw a Star fires")
		for ev: Dictionary in _during(r, act):
			if ev["type"] == "status":
				gifts[String(ev["status"]) + String(ev["stat"])] = true
			if ev["type"] == "charge" and ev["reason"] == "effect":
				gifts["charge"] = true
	check(gifts.size() >= 3, "the gift varies (%s)" % str(gifts.keys()))


func test_lampwright_shields_its_column() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("lampwright", 1, 1, 2), hero("healer", 1, 2)])
	var r := _sim(21, a, duo(hero("fighter", 0, 0)))
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "column_ward", "Column Ward fires")
	var shielded := {}
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "status" and ev["status"] == "shield":
			shielded[int(ev["uid"])] = true
	check(shielded.has(1) and shielded.has(2) and not shielded.has(0), "every ally in its column, nobody else")


func test_runebinder_seals_the_most_charged_foe() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("runebinder", 1, 1, 2)])
	var r := _sim(22, a, party([hero("fighter", 0, 1, 2), hero("mage", 1, 1, 2)]))
	var act := _ability_of(r, 1)
	eq(String(act["action"]), "rune_seal", "Rune Seal fires")
	var seal := _first(r, "status", func(ev: Dictionary) -> bool: return ev["status"] == "charge_seal")
	eq(int(seal["uid"]), int(act["target"]), "the struck foe is sealed")
	var until := float(seal["t"]) + float(seal["duration"])
	for ev: Dictionary in of_type(r, "charge"):
		if int(ev["uid"]) == int(seal["uid"]) and float(ev["t"]) > float(seal["t"]) and float(ev["t"]) < until:
			check(int(ev["delta"]) <= 0, "the sealed foe gains no charge")


func test_chronist_slows_every_foe() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("chronist", 1, 1, 2)])
	var b := party([hero("fighter", 0, 1), hero("rogue", 0, 2), hero("mage", 1, 1)])
	var r := _sim(23, a, b)
	var act := _ability_of(r, 1)
	var slowed := {}
	for ev: Dictionary in _during(r, act):
		if ev["type"] == "status" and ev["status"] == "slow":
			slowed[int(ev["uid"])] = true
	eq(slowed.size(), 3, "every foe is slowed")


func test_wildfire_burns_and_spreads() -> void:
	var a := party([hero("fighter", 0, 1, 3), hero("wildfire", 1, 1, 2)])
	var b := party([hero("stone_sentinel", 0, 1, 4), hero("stone_sentinel", 0, 2, 4), hero("stone_sentinel", 1, 1, 4)])
	var r := _sim(24, a, b)
	var burned := {}
	for ev: Dictionary in of_type(r, "status"):
		if ev["status"] == "burn":
			burned[int(ev["uid"])] = true
	check(burned.size() >= 2, "the fire jumps to a neighbour (%d burned)" % burned.size())
