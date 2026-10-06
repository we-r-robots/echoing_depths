extends "res://tests/test_case.gd"
## Formations (05-formations.md): shape detection, unlocks, roles, behaviours.

const CombatSim = preload("res://core/combat_sim.gd")
const Formation = preload("res://core/formation.gd")
const GameData = preload("res://core/game_data.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Rng = preload("res://core/rng.gd")


func _shifted(cells: Array, off: int) -> Array:
	var out: Array = []
	for c: Array in cells:
		out.append([int(c[0]), int(c[1]) + off])
	return out


func _height(cells: Array) -> int:
	var h := 0
	for c: Array in cells:
		h = maxi(h, int(c[1]) + 1)
	return h


func test_every_shape_at_every_height_and_mirror() -> void:
	var seen := {}
	for sh: Dictionary in GameData.Formations.SHAPES:
		var variants: Array = [sh["cells"]]
		if bool(sh["mirror"]):
			variants.append(Formation._flip(sh["cells"]))
		for v: Array in variants:
			for off in range(0, 4 - _height(v) + 1):
				eq(String(Formation.detect(_shifted(v, off))["id"]), String(sh["id"]), "%s at height %d" % [sh["id"], off])
		seen[sh["id"]] = int(sh["size"])
	var counts := {2: 0, 3: 0, 4: 0}
	for id: String in seen:
		counts[seen[id]] += 1
	eq(counts, {2: 3, 3: 4, 4: 8}, "3 dominoes, 4 trominoes, 8 tetrominoes")


func test_orientation_matters() -> void:
	# swapping front and back columns gives the other shape of the pair, never the same one
	var pairs := {"kindred": "vigil", "tidebreak": "choir", "keystone": "hearth", "seawall": "lumari_chorus",
		"crescent": "lighthouse", "keepers_ring": "shardpoint", "lamplight": "lamplight", "vault_door": "vault_door",
		"echo_step": "echo_step"}
	for sh: Dictionary in GameData.Formations.SHAPES:
		var swapped: Array = []
		for c: Array in sh["cells"]:
			swapped.append([1 - int(c[0]), int(c[1])])
		eq(String(Formation.detect(swapped)["id"]), String(pairs.get(sh["id"], pairs.find_key(sh["id"]))),
			"%s with front/back swapped" % sh["id"])


func test_mirrored_variants_are_the_same_shape() -> void:
	eq(Formation.detect([[0, 1], [0, 2], [1, 2]])["id"], "keystone", "Keystone with its back unit at the bottom end")
	eq(Formation.detect([[0, 3], [1, 2], [1, 3]])["id"], "hearth", "Hearth mirrored")
	eq(Formation.detect([[0, 1], [0, 2], [0, 3], [1, 3]])["id"], "crescent", "Crescent mirrored")
	eq(Formation.detect([[0, 2], [0, 3], [1, 1], [1, 2]])["id"], "echo_step", "Z is the same as S")


func test_strays() -> void:
	eq(Formation.detect([[0, 0], [0, 2]])["id"], "strays", "a gap in the column")
	eq(Formation.detect([[0, 0], [1, 1]])["id"], "strays", "diagonal is not edge-connected")
	eq(Formation.detect([[0, 0], [0, 1], [1, 3]])["id"], "strays", "a pair plus a loner is no single shape (state: partial)")
	eq(Formation.detect([[0, 0], [0, 3], [1, 1], [1, 2]])["id"], "strays", "scattered four")


func test_formation_states() -> void:
	var u := ["kindred", "vigil", "lamplight", "tidebreak", "choir"]
	var st := func(cells: Array, unlocked: Array) -> Dictionary:
		var hs: Array = []
		for c: Array in cells:
			hs.append({"slot": c})
		return Formation.effective({"heroes": hs, "unlocked_formations": unlocked})
	var fx: Dictionary = st.call([[0, 0], [0, 1]], u)
	check(fx["state"] == "active" and fx["effective"]["id"] == "kindred" and fx["sub_cells"].size() == 2, "active Kindred")
	fx = st.call([[0, 0], [1, 1], [0, 2], [1, 3]], u)
	check(fx["state"] == "strays" and fx["effective"]["id"] == "strays" and fx["sub_cells"].is_empty(), "no two adjacent: Strays")
	fx = st.call([[0, 0], [0, 1], [1, 3]], u)
	check(fx["state"] == "partial" and fx["effective"]["id"] == "kindred" and fx["sub_cells"] == [[0, 0], [0, 1]],
		"a pair plus a loner: the pair counts as Kindred, the loner gets nothing (every part counts)")
	fx = st.call([[0, 0], [0, 1], [0, 2], [0, 3]], u)
	check(fx["state"] == "locked_fallback" and fx["shape"]["id"] == "seawall" and fx["effective"]["id"] == "tidebreak" and fx["locked"],
		"locked Seawall falls back to its largest unlocked part, Tidebreak")
	eq(fx["sub_cells"], [[0, 0], [0, 1], [0, 2]], "the fallback's cells (first in slot order)")
	fx = st.call([[0, 0], [0, 1], [0, 2], [0, 3]], [])
	check(fx["state"] == "locked_unformed" and fx["effective"]["id"] == "unformed", "no unlocked part: locked_unformed")
	fx = st.call([[0, 0], [0, 1], [1, 0], [1, 1]], ["kindred", "vigil", "lamplight"])
	check(fx["state"] == "locked_fallback" and fx["effective"]["id"] == "kindred", "Vault Door ties between dominoes break by data order (Kindred)")


func test_fallback_applies_to_sub_shape_heroes_only() -> void:
	var p := party([hero("fighter", 0, 0), hero("fighter", 0, 1), hero("fighter", 0, 2), hero("fighter", 0, 3)])
	var r := CombatSim.simulate(1, p, party([hero("hollow_rat", 0, 0)]))
	var f: Dictionary = r["events"][0]["sides"][0]["formation"]
	check(f["state"] == "locked_fallback" and f["id"] == "tidebreak" and f["shape"] == "seawall", "banner: Seawall locked, fights as Tidebreak")
	eq(f["sub_cells"], [[0, 0], [0, 1], [0, 2]], "banner carries the sub-shape cells")
	var base := int(GameData.get_class_def("fighter")["stats"]["def"])
	var in_def := int(unit_stats(r, 0)["def"])
	var out_def := int(unit_stats(r, 3)["def"])
	check(in_def > out_def, "Tidebreak's Def bonus only on its three heroes (%d vs %d)" % [in_def, out_def])
	eq(out_def, floori(base * 1.10), "the hero outside the sub-shape keeps only Shield Brothers")


func test_matches_ui_stub() -> void:
	var path := "res://scenes/party_setup/formation_words.gd"
	if not ResourceLoader.exists(path):
		check(true, "UI stub not present")
		return
	var stub: GDScript = load(path)
	var rng := Rng.new(77)
	var ids: Array = PartyGen.all_shapes()
	var n := 0
	for i in 400:
		var size := rng.int_range(2, 4)
		var cells: Array = []
		var used := {}
		while cells.size() < size:
			var c := [rng.int_range(0, 1), rng.int_range(0, 3)]
			if not used.has(c[0] * 4 + c[1]):
				used[c[0] * 4 + c[1]] = true
				cells.append(c)
		cells.sort_custom(func(a: Array, b: Array) -> bool: return a[0] * 10 + a[1] < b[0] * 10 + b[1])
		var unlocked: Array = []
		for id: String in ids:
			if rng.next_float() < 0.4:
				unlocked.append(id)
		var hs: Array = []
		for c: Array in cells:
			hs.append({"slot": c})
		var core: Dictionary = Formation.effective({"heroes": hs, "unlocked_formations": unlocked})
		var ui: Dictionary = stub.evaluate(cells, unlocked)
		if core["state"] != ui["state"] or core["effective"]["id"] != ui["effective"]["id"] or core["sub_cells"] != ui["sub_cells"] \
				or core["locked"] != ui["locked"] or core["shape"]["id"] != ui["shape"]["id"]:
			check(false, "core and UI disagree on %s with %s: %s vs %s" % [cells, unlocked, core["state"], ui["state"]])
			return
		n += 1
	check(n == 400, "core Formation.effective matches the UI stub on 400 placements")


func test_banner_lists_bonus_behaviour_cost() -> void:
	var r := CombatSim.simulate(1, PartyGen.demo_party(), PartyGen.demo_rival())
	for s in 2:
		var f: Dictionary = r["events"][1 + s]["formation"]
		check(not (f["buffs"] as Array).is_empty(), "banner has the bonus")
		check(String(f["behaviour"]["name"]) != "" and String(f["behaviour"]["text"]) != "", "banner has the behaviour")
		check(String(f["cost"]) != "", "banner has the cost")


func test_bonus_applies_to_stats() -> void:
	var p := party([hero("fighter", 0, 0), hero("fighter", 0, 1)])
	var r := CombatSim.simulate(1, p, party([hero("hollow_rat", 0, 0)]))
	var base := int(GameData.get_class_def("fighter")["stats"]["def"])
	# Kindred front Def +10%, Shield Brothers +10%
	eq(int(unit_stats(r, 0)["def"]), floori(base * (1.0 + 0.10 + 0.10)), "Kindred + Shield Brothers Def")


func test_compositions_kept() -> void:
	var ids: Array = []
	for c: Dictionary in Formation.compositions(["fighter", "rogue", "healer", "mage"]):
		ids.append(c["id"])
	eq(ids, ["well_rounded"], "four different classes -> Well Rounded")


func test_roles() -> void:
	eq(Formation.roles("keystone", [[0, 0], [0, 1], [1, 0]]), [["front"], ["front", "gap"], ["back", "flanker"]], "Keystone roles")
	eq(Formation.roles("tidebreak", [[0, 0], [0, 1], [0, 2]])[1], ["front", "middle"], "Tidebreak middle")
	eq(Formation.roles("shardpoint", [[0, 1], [1, 0], [1, 1], [1, 2]])[0], ["front", "tip"], "Shardpoint tip")
	eq(Formation.roles("keepers_ring", [[0, 0], [0, 1], [0, 2], [1, 1]])[3], ["back", "keeper"], "Keeper")


## Runs fights with side A in `shape` (all unlocked) until the behaviour `effect` fires; checks
## every such cue is truthful (the named unit really does its trigger at that instant).
func _fires(shape: String, effect: String, size: int, foe_size: int = 4, extra: Dictionary = {}) -> bool:
	var rng := Rng.new(hash(shape + effect))
	for i in 150:
		var a := PartyGen.random_party(rng, {"size": size, "shape": shape})
		var b := PartyGen.random_party(rng, {"size": foe_size})
		for k: String in extra:
			b[k] = extra[k]
		var r := CombatSim.simulate(i, a, b)
		var evs: Array = r["events"]
		eq(String(evs[1]["formation"]["id"]), shape, "side A fights as %s" % shape)
		if String(evs[1]["formation"]["id"]) != shape:
			return false
		var actor := -1
		for k in evs.size():
			var ev: Dictionary = evs[k]
			if ev["type"] == "action_start":
				actor = int(ev["uid"])
			if effect == "hold_the_door" and ev["type"] == "formation_move":
				check(ev["from"][0] == 1 and ev["to"][0] == 0 and ev["from"][1] == ev["to"][1], "steps forward in its row")
				return true
			if ev["type"] != "formation_proc" or String(ev["effect"]) != effect:
				continue
			check(_truthful(evs, k, actor), "%s cue is truthful: %s" % [effect, ev])
			return true
	return false


static func _truthful(evs: Array, k: int, actor: int) -> bool:
	var cue: Dictionary = evs[k]
	var t := float(cue["t"])
	var uid := int(cue["uid"])
	match String(cue["trigger"]):
		"start":
			return t == 0.0
		"protect", "draw":
			return int(cue["related"]) == actor
	for ev: Dictionary in evs:
		if absf(float(ev["t"]) - t) > 0.0005:
			continue
		match String(cue["trigger"]):
			"attack":
				if ev["type"] == "damage" and int(ev["src"]) == uid:
					return true
			"defend":
				if ev["type"] == "damage" and int(ev["dst"]) == uid:
					return true
			"turn":
				if ev["type"] == "action_start" and int(ev["uid"]) == uid:
					return true
			"charge":
				if ev["type"] == "charge" and int(ev["uid"]) == uid:
					return true
	return false


func test_each_behaviour_fires_truthfully() -> void:
	var cases := [
		["kindred", "shoulder_to_shoulder", 2], ["vigil", "covering_fire", 2], ["lamplight", "guardian", 2],
		["tidebreak", "brace", 3], ["choir", "opening_volley", 3], ["keystone", "flank", 3], ["keystone", "draws_melee", 3],
		["hearth", "hearthguard", 3], ["seawall", "share_the_blow", 4], ["lumari_chorus", "opening_volley", 4],
		["vault_door", "hold_the_door", 4], ["crescent", "flank", 4], ["lighthouse", "hearthguard", 4],
		["lighthouse", "taunt", 4], ["keepers_ring", "keepers_ring", 4], ["shardpoint", "shardpoint", 4],
		["echo_step", "echo_step", 4], ["strays", "scattered", 4]]
	for c: Array in cases:
		check(_fires(c[0], c[1], c[2]), "%s: %s fires at least once" % [c[0], c[1]])
	check(_fires("lumari_chorus", "chorus_splash", 4), "lumari_chorus: magic splash bonus fires")


func test_locked_shape_has_no_behaviour() -> void:
	var rng := Rng.new(3)
	for i in 30:
		var a := PartyGen.random_party(rng, {"size": 4, "shape": "seawall", "unlocked": []})
		var r := CombatSim.simulate(i, a, PartyGen.random_party(rng))
		for ev: Dictionary in r["events"]:
			if ev["type"] == "formation_proc" and int(ev["side"]) == 0 and String(ev["stat"]) == "":
				check(false, "a locked shape with no unlocked part (Unformed) has no behaviour: %s" % ev)
				return
	check(true, "locked shapes checked")


func test_keepers_ring_untargetable_while_ring_stands() -> void:
	var rng := Rng.new(41)
	var checked := 0
	for i in 60:
		var r := CombatSim.simulate(i, PartyGen.random_party(rng, {"shape": "keepers_ring"}), PartyGen.random_party(rng))
		var keeper := -1
		var front := {}
		for u: Dictionary in r["events"][0]["sides"][0]["units"]:
			if int(u["col"]) == 1:
				keeper = int(u["uid"])
			else:
				front[int(u["uid"])] = true
		var dead := {}
		var sealed := {}     # round 2: a sealed front unit leaves the shape (Enshriner)
		var sabotaged := {}  # round 2: a Saboteur stops the ring while its foes are sabotaged
		for ev: Dictionary in r["events"]:
			if ev["type"] == "ko":
				dead[int(ev["uid"])] = true
			elif ev["type"] == "status" or ev["type"] == "status_end":
				var on: bool = ev["type"] == "status"
				var tbl: Dictionary = sealed if ev["status"] == "enshrine" else (sabotaged if ev["status"] == "sabotage" else {})
				if on:
					tbl[int(ev["uid"])] = true
				else:
					tbl.erase(int(ev["uid"]))
			elif ev["type"] == "action_start" and int(ev["target"]) == keeper:
				var standing := 0
				for f: int in front:
					if not dead.has(f) and not sealed.has(f):
						standing += 1
				checked += 1
				if standing >= 3 and sabotaged.is_empty():
					check(false, "fight %d: keeper targeted while the ring stands" % i)
					return
	check(true, "keeper never single-targeted while all three front units stand (%d later targetings)" % checked)


func test_lighthouse_post_draws_single_target_ranged() -> void:
	var rng := Rng.new(42)
	var drawn := 0
	for i in 60:
		var r := CombatSim.simulate(i, PartyGen.random_party(rng, {"shape": "lighthouse"}), PartyGen.random_party(rng))
		var post := -1
		for u: Dictionary in r["events"][0]["sides"][0]["units"]:
			if int(u["col"]) == 0:
				post = int(u["uid"])
		var post_alive := true
		var post_hidden := false   # a hidden post can't be targeted at all (Fadewalker, Unseen Warden)
		var post_sealed := false   # round 2: nor a post sealed in crystal (Enshriner)
		var sabotaged := {}        # round 2: a Saboteur's cut ropes put the lantern out (no taunt)
		for ev: Dictionary in r["events"]:
			if ev["type"] == "ko" and int(ev["uid"]) == post:
				post_alive = false
			if (ev["type"] == "status" or ev["type"] == "status_end") and int(ev["uid"]) == post and ev["status"] == "hidden":
				post_hidden = ev["type"] == "status"
			if (ev["type"] == "status" or ev["type"] == "status_end") and int(ev["uid"]) == post and ev["status"] == "enshrine":
				post_sealed = ev["type"] == "status"
			if (ev["type"] == "status" or ev["type"] == "status_end") and ev["status"] == "sabotage" and int(ev["uid"]) < 4:
				if ev["type"] == "status":
					sabotaged[int(ev["uid"])] = true
				else:
					sabotaged.erase(int(ev["uid"]))
			if ev["type"] == "action_start" and int(ev["target_side"]) == 0 and ev["area"] == "single" \
					and int(ev["uid"]) >= 4 and post_alive and not post_hidden and not post_sealed and sabotaged.is_empty() \
					and int(ev["target"]) >= 0:
				eq(int(ev["target"]), post, "fight %d: single-target attack goes to the lit post" % i)
				drawn += 1
	check(drawn > 50, "single-target attacks sampled (%d)" % drawn)


func _firestorm_hits(b: Dictionary) -> Dictionary:
	var a := party([hero("mage", 1, 0, 3), hero("healer", 1, 1)])
	a["unlocked_formations"] = []
	var r := CombatSim.simulate(5, a, b, {"tuning": {"start_charge_bonus": 100}})
	var hit := {}
	var seen := false
	for ev: Dictionary in r["events"]:
		if ev["type"] == "action_start":
			if seen:
				break
			seen = ev["action"] == "firestorm"
		elif seen and ev["type"] == "damage":
			hit[int(ev["dst"])] = true
	return hit


func test_scattered_strays_take_no_splash() -> void:
	# Strays (no two adjacent): Firestorm's splash never spreads from the struck unit.
	var b := party([hero("fighter", 0, 3), hero("fighter", 1, 0), hero("fighter", 1, 2)])
	var hit := _firestorm_hits(b)
	eq(hit.size(), 1, "only the struck Stray is hit")
	# Unformed (partly joined) and locked shapes take normal splash
	eq(_firestorm_hits(party([hero("fighter", 0, 3), hero("fighter", 1, 0), hero("fighter", 1, 1)])).size(), 3,
		"an Unformed side takes splash")
	var wall := party([hero("fighter", 0, 0), hero("fighter", 0, 1), hero("fighter", 0, 2), hero("fighter", 0, 3)])
	wall["unlocked_formations"] = []
	eq(_firestorm_hits(wall).size(), 4, "a locked shape with no unlocked part takes splash on all four")


func test_guardian_ignores_splash() -> void:
	var rng := Rng.new(43)
	for i in 80:
		var r := CombatSim.simulate(i, PartyGen.random_party(rng, {"size": 2, "shape": "lamplight"}), PartyGen.random_party(rng))
		var cur := ""
		var cur_area := ""
		for ev: Dictionary in r["events"]:
			if ev["type"] == "action_start":
				cur = String(ev["action"])
				cur_area = String(ev["area"])
			if ev["type"] == "formation_proc" and ev["effect"] == "guardian":
				check(cur_area == "single" or ev["related"] >= 0, "guardian fired on %s" % cur)
	check(true, "guardian checked")
