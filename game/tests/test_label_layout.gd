extends "res://tests/test_case.gd"
## World labels (damage/heal numbers, CRIT!, KO!, tags, formation cues) under load (hires-ui round 6).
## The layout solver (scenes/battle/label_layout.gd) must keep (a) every label nearest its own unit
## and within its horizontal span, (b) off every other label, (c) off the HUD (banners, caption,
## roster, the Crystal's bar). Overlapping a neighbour's sprite or bar is allowed.
## The synthetic tests pack the 2x4 grid; the real-fight tests play the demo fights (Cleave crit,
## Firestorm on all foes, the Fading, monster KOs, the Crystal) through the real battle scene and
## check every label the moment it is placed.

const LabelLayout = preload("res://scenes/battle/label_layout.gd")
const FX = preload("res://scenes/battle/battle_fx.gd")
const Layout = preload("res://scenes/battle/battle_layout.gd")
const BATTLE = preload("res://scenes/battle/battle.tscn")
const FIELD := Rect2(150, 96, 340, 170)


const Formations = preload("res://core/data/formations.gd")


## Two parties of heroes in the given shapes (cells [col, row], shifted to start at `row0`), with
## real slot positions, hero-sized bodies and plates.
func _parties(cells_a: Array, cells_b: Array, row0 := 0) -> Array:
	var out: Array = []
	var uid := 0
	for side in 2:
		for c: Array in (cells_a if side == 0 else cells_b):
			var p := Layout.slot_pos(side, int(c[0]), int(c[1]) + row0)
			var body := Rect2(p.x - 11.0, p.y - 43.0, 22.0, 43.0)
			var bar := Rect2(p.x - 12.0, p.y + 2.0, 33.0, 8.0) if side == 0 else Rect2(p.x - 20.0, p.y + 2.0, 33.0, 8.0)
			out.append({"uid": uid, "body": body, "bar": bar, "side": side})
			uid += 1
	return out


func _check_label(box: Rect2, uid: int, geo: Array, placed: Array, blocked: Array, field: Rect2, what: String) -> void:
	var own: Dictionary = {}
	var others: Array = []
	for g: Dictionary in geo:
		if int(g["uid"]) == uid:
			own = g
		else:
			others.append(g)
	if own.is_empty():
		check(false, "%s: its unit %d is on the field" % [what, uid])
		return
	# (overlapping a neighbour's sprite or HP bar is allowed: coordinator 2026-10-05)
	for r: Rect2 in placed:
		check(not box.intersection(r).has_area(), "%s %s overlaps another label %s" % [what, box, r])
	for r: Rect2 in blocked:
		check(not box.intersection(r).has_area(), "%s %s overlaps the HUD %s" % [what, box, r])
	check(field.encloses(box), "%s %s stays inside the field %s" % [what, box, field])
	check(LabelLayout.nearest_is_own(box, own, others, 0.0), "%s %s is nearest its own unit %d" % [what, box, uid])
	# never off its own unit's column: its centre stays over its own body's span
	var b: Rect2 = own["body"]
	var sl := LabelLayout.SPAN_SLACK + 0.5
	check(box.get_center().x >= b.position.x - sl and box.get_center().x <= b.end.x + sl,
		"%s centre x %.0f stays within its unit's span %.0f..%.0f" % [what, box.get_center().x, b.position.x, b.end.x])


func test_every_four_hero_shape_takes_a_crit_kill_on_every_hero() -> void:
	# every 4-hero shape against every 4-hero shape, at every height it fits, one whole side hit at
	# once (Firestorm), each a crit kill: the widest label (CRIT! over 3 digits + the KO! pill)
	var shapes: Array = []
	for f: Dictionary in Formations.SHAPES:
		if int(f["size"]) == 4:
			shapes.append(f["cells"])
	var n := 0
	for ca: Array in shapes:
		for cb: Array in shapes:
			var h := 0
			for c: Array in ca + cb:
				h = maxi(h, int(c[1]) + 1)
			for row0 in 4 - h + 1:
				var geo := _parties(ca, cb, row0)
				for side in 2:
					var placed: Array = []
					for g: Dictionary in geo:
						if int(g["side"]) != side:
							continue
						var sz := FX.label_size(188, false, "CRIT!", false, "", true)
						var body: Rect2 = g["body"]
						var box := LabelLayout.place(sz, Vector2(body.get_center().x, body.position.y - 1.0), g, geo, placed, [], FIELD)
						_check_label(box, int(g["uid"]), geo, placed, [], FIELD, "%s vs %s +%d side %d unit %d" % [ca, cb, row0, side, g["uid"]])
						placed.append(box)
						n += 1
	check(n > 100, "checked %d labels" % n)


func test_a_whole_side_in_the_fading_with_tags() -> void:
	# the Fading hits every unit: number + "Fading ×1.48" tag on each of two full parties
	var shapes: Array = []
	for f: Dictionary in Formations.SHAPES:
		if int(f["size"]) == 4:
			shapes.append(f["cells"])
	for ca: Array in shapes:
		var geo := _parties(ca, ca)
		var placed: Array = []
		for g: Dictionary in geo:
			var sz := FX.label_size(24, false, "", false, "Fading ×1.48", false)
			var body: Rect2 = g["body"]
			var box := LabelLayout.place(sz, Vector2(body.get_center().x, body.position.y - 1.0), g, geo, placed, [], FIELD)
			_check_label(box, int(g["uid"]), geo, placed, [], FIELD, "Fading %s unit %d" % [ca, g["uid"]])
			placed.append(box)


func test_a_label_moves_sideways_or_down_never_up_a_stack() -> void:
	var geo := _parties([[0, 0], [0, 1], [1, 0], [1, 1]], [[0, 0], [0, 1], [1, 0], [1, 1]])
	var g: Dictionary = geo[1]
	var body: Rect2 = g["body"]
	var sz := FX.label_size(32, false, "", false, "", false)
	var pref := Vector2(body.get_center().x, body.position.y - 1.0)
	var first := LabelLayout.place(sz, pref, g, geo, [], [], FIELD)
	var second := LabelLayout.place(sz, pref, g, geo, [first], [], FIELD)
	check(second.position.y >= first.position.y - LabelLayout.RISE_UP - 0.5, "a second label on the same unit does not stack above the first (%s vs %s)" % [second, first])
	check(not second.intersects(first), "the two labels don't overlap")


func test_world_labels_meet_the_text_floor() -> void:
	# numbers, head words, KO!, tags and the formation cue plates are all drawn through UIText at
	# these sizes; each must clear the 14 px x-height floor at 1080p (critic r5 read the plates as
	# ~11 px: they are size 10 Depths Sans Bold, 16 px)
	for sz: int in [FX.NUM_SIZE, FX.NUM_PUNCH, FX.HEAD_SIZE, FX.TAG_SIZE]:
		check(UIText.size_ok(UIText.BOLD, sz), "world label size %d is on the grid" % sz)
		check(UIText.x_height_1080(UIText.BOLD, sz) >= UIText.MIN_X_HEIGHT_1080, "world label size %d: x-height %.1f px >= %d" % [sz, UIText.x_height_1080(UIText.BOLD, sz), UIText.MIN_X_HEIGHT_1080])


## Plays one demo fight to its end through the real battle scene, recording every label placement.
## `each` (optional) is called with the battle node every 10 frames.
func _play(fight: String, sequence := "ch1", each := Callable(), every := 10) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var old_size := tree.root.size
	tree.root.size = Vector2i(1920, 1080)   # the capture layout: 640x360 design px
	var b: Node = BATTLE.instantiate()
	b.autoplay_demo = false
	b.demo_fight = fight
	b.demo_sequence = sequence
	tree.root.add_child(b)
	b.fx.recording = true
	b._start_demo()
	var frames := 0
	while frames < 60 * 120 and int(b._state) != 3:
		b._process(1.0 / 60.0)
		frames += 1
		if each.is_valid() and frames % every == 0:
			each.call(b)
	var rec: Array = b.fx.record
	tree.root.remove_child(b)
	b.free()
	tree.root.size = old_size
	return rec


func _check_fight(fight: String, rec: Array, sequence := "") -> Dictionary:
	var stats := {"multi": 0, "ko": 0, "crit": 0, "fading": 0, "cues": 0, "n": rec.size()}
	var by_t := {}
	for r: Dictionary in rec:
		var what := "%s%s label \"%s\" (unit %d)" % [fight, sequence, r["text"], r["uid"]]
		_check_label(r["box"], int(r["uid"]), r["geo"], r["placed"], r["blocked"], r["field"], what)
		var tx := String(r["text"])
		if tx.contains("KO!"):
			stats["ko"] += 1
		if tx.contains("CRIT!"):
			stats["crit"] += 1
		if tx.contains("Fading"):
			stats["fading"] += 1
		if bool(r["small"]):
			stats["cues"] += 1
		var live := 0
		for p: Rect2 in r["placed"]:
			live += 1
		stats["multi"] = maxi(int(stats["multi"]), live + 1)
	return stats


func test_real_pvp_fight_cleave_firestorm_and_the_fading() -> void:
	var st := _check_fight("pvp", _play("pvp"))
	check(int(st["n"]) > 20, "the PvP demo placed labels (%d)" % st["n"])
	check(int(st["multi"]) >= 3, "multi-target hits were laid out together (max %d at once)" % st["multi"])
	check(int(st["crit"]) >= 1, "a crit label was laid out")
	check(int(st["ko"]) >= 1, "a KO! label was laid out")
	check(int(st["fading"]) >= 1, "a Fading-tagged number was laid out")


func test_real_monster_fight_kos() -> void:
	var st := _check_fight("monsters", _play("monsters"))
	check(int(st["ko"]) >= 1, "a monster KO was laid out (%d)" % st["ko"])


var _max_rows := 0
var _banner_checks := 0
var _hud_frame := 0
var _lore_seen := 0


## Every frame of a Crystal fight: no live label (as it is drawn now, in UI px) touches a banner
## (the lore banner, the fragment banner, the Fading line) or comes within its margin (critic r6:
## the fragment-2 "20" sat under the lore banner's bottom rule; numbers bar rule (c)).
func _banners_clear(b: Node) -> void:
	var xf: Transform2D = b._world_xf()
	var banners: Array = []
	var lr: Rect2 = b.hud.lore_rect()
	if lr.has_area():
		_lore_seen += 1
		banners.append(["lore banner", lr])
	if b.hud.frag_t <= b.hud.FRAG_SHOW and b.hud.frag_n > 0:
		banners.append(["fragment banner", b.hud.fragment_rect()])
	var m: float = b.hud.BANNER_MARGIN - 1.0
	for l: Dictionary in b.fx.label_boxes():
		var wb: Rect2 = l["box"]
		var p0: Vector2 = xf * wb.position
		var p1: Vector2 = xf * wb.end
		var ub := Rect2(p0, p1 - p0)
		for bn: Array in banners:
			_banner_checks += 1
			var r: Rect2 = bn[1]
			check(not ub.intersects(r.grow(m)), "label \"%s\" %s keeps %d px clear of the %s %s at %.2f s" % [l["text"], ub, m, bn[0], r, b.sim_t])


func test_real_crystal_fight() -> void:
	_max_rows = 0
	_banner_checks = 0
	_lore_seen = 0
	var st := _check_fight("crystal", _play("crystal", "ch1", _crystal_hud, 1))
	check(int(st["n"]) > 20, "the Crystal demo placed labels (%d)" % st["n"])
	check(_lore_seen > 0, "a memory's lore banner showed during the fight (%d frames)" % _lore_seen)
	check(_banner_checks > 100, "live labels were checked against the banners (%d)" % _banner_checks)
	check(_max_rows == 4, "the Fading's summons filled the enemy roster to its 4-row cap (%d)" % _max_rows)


## The enemy roster never passes 4 rows nor reaches the Crystal's bar and pips, and no hero's HP
## plate touches them (critic r5: a fifth memory row grew the panel over both).
func _crystal_hud(b: Node) -> void:
	if b.crystal_uid < 0:
		return
	_banners_clear(b)
	_hud_frame += 1
	if _hud_frame % 10 != 0:
		return
	var c = b.units[b.crystal_uid]
	if not c.alive:
		return
	var xf: Transform2D = b._world_xf()
	var pr: Rect2 = c.plate_rect()
	var pips := Rect2(xf * pr.position, xf * pr.end - xf * pr.position)
	for side in 2:
		var rows: Array = b.hud.roster_rows(side)
		_max_rows = maxi(_max_rows, rows.size()) if side == 1 else _max_rows
		check(rows.size() <= 4, "side %d roster has %d rows (cap 4)" % [side, rows.size()])
		var h: float = 6.0 + rows.size() * b.hud.ROW_H
		var x0: float = b.hud._l + 4.0 if side == 0 else b.hud._r - 4.0 - b.hud.PANEL_W
		var panel := Rect2(x0, 358.0 - h, b.hud.PANEL_W, h)
		check(not panel.intersects(pips), "side %d roster %s clears the Crystal's bar and pips %s at %.1f s" % [side, panel, pips, b.sim_t])
	for u in b.units:
		if u != c and u.alive:
			check(not u.plate_rect().intersects(pr), "%s's HP plate clears the Crystal's pips at %.1f s" % [u.label, b.sim_t])


# ------------------------------------------------------------------ attribution against drawn units
## Critic round 10 measured four labels nearer the wrong unit on screen (Cleave "CRIT! 103" by Corin
## and "32" by Moth, Firestorm "CRIT! 65 KO!" by Ilse, the monsters' "77 KO!" over the attacker
## Brakka). The cause: the solver measured bodies at their home slots with the idle frame and a
## centre-to-box rule, while the units were DRAWN knocked back, in their hit frames and lunged, and a
## label over a front-row head sat beside the face of the unit one row behind. These tests check
## every live label on every frame of the real fights against where each unit is drawn that frame
## (its current animation frame at its current position): the label's centre is nearer its own
## unit's drawn body than any other's, and clearly nearer its own face point (LabelLayout.HEAD_RATIO).
## A unit dashing to or back from its strike spot is a transient and isn't counted against other
## labels (it is checked where it stands: home and the strike spot).
const FIXTURES := {
	"pvp": [["CRIT! 103", "Moth"], ["32", "Tamsin"], ["CRIT! 65 KO!", "Vael"]],
	"monsters": [["77 KO!", "Hollow Rat"]],
	"crystal": [],
}
var _drawn_checks := 0
var _drawn_fails := 0
var _fixture_frames := {}


func _drawn_attribution(b: Node, fight: String) -> void:
	var fx = b.fx
	for j in fx.MAX_POP:
		if not fx._pp_on[j] or fx._pp_t[j] < 0.0:
			continue
		var own := int(fx._pp_unit[j])
		if b.units[own].acting and b.units[own].in_transit(b.sim_t):
			continue   # its own unit is dashing: the label stays over its slot and plate
		var og := {}
		var others: Array = []
		for u in b.units:
			if u == null or not (u.alive or u.uid == own):
				continue
			if u.acting and u.uid != own and u.in_transit(b.sim_t):
				continue
			var g := {"uid": u.uid, "body": u.drawn_rect()}
			if u.uid == own:
				og = g
			else:
				others.append(g)
		var box: Rect2 = fx._pp_box[j]
		var text: String = fx._label_text(j)
		_drawn_checks += 1
		var miss: float = LabelLayout.misattribution(box, og, others, 0.0)
		if miss > 0.0:
			_drawn_fails += 1
			if _drawn_fails <= 12:
				check(false, "%s %.2f s: \"%s\" on %s %s is nearest its own unit as drawn (misses by %.1f px)" % [fight, b.sim_t, text, b.units[own].label, box, miss])
		for fxt: Array in FIXTURES[fight]:
			if text == fxt[0] and b.units[own].label == fxt[1]:
				var k := "%s/%s" % [fxt[0], fxt[1]]
				_fixture_frames[k] = int(_fixture_frames.get(k, 0)) + 1
				# the critic's own measure: the nearest face on screen is the victim's
				var best := ""
				var bd := INF
				for u in b.units:
					if u != null and (u.alive or u.uid == own):
						var d: float = box.get_center().distance_to(u.head_point())
						if d < bd:
							bd = d
							best = u.label
				check(best == fxt[1], "%s: \"%s\" sits nearest %s's face as drawn (nearest: %s) at %.2f s" % [fight, fxt[0], fxt[1], best, b.sim_t])


func _drawn_fight(fight: String) -> void:
	_drawn_checks = 0
	_drawn_fails = 0
	_fixture_frames = {}
	_play(fight, "ch1", func(b: Node) -> void: _drawn_attribution(b, fight), 1)
	check(_drawn_checks > 200, "%s: live labels were checked against the drawn units (%d label-frames)" % [fight, _drawn_checks])
	eq(_drawn_fails, 0, "%s: label-frames attributed to the wrong drawn unit" % fight)
	for fxt: Array in FIXTURES[fight]:
		var k := "%s/%s" % [fxt[0], fxt[1]]
		check(int(_fixture_frames.get(k, 0)) >= 20, "%s: critic case \"%s\" on %s was on screen and checked (%d frames)" % [fight, fxt[0], fxt[1], int(_fixture_frames.get(k, 0))])


func test_drawn_attribution_pvp_cleave_103_and_32_firestorm_65() -> void:
	_drawn_fight("pvp")


func test_drawn_attribution_monsters_77_ko_on_the_rat() -> void:
	_drawn_fight("monsters")


func test_drawn_attribution_crystal() -> void:
	_drawn_fight("crystal")
