extends "res://tests/test_case.gd"
## Round 17: timed statuses and the approved advanced classes in the battle scene. Plays the three
## class showcase fights (scenes/battle/battle_demo.gd CLASS_DEMOS) through the real battle scene
## frame by frame, at 1080p and the 19.5:9 phone width, and checks on every frame:
##   - every status row stays inside the field, off the HUD (rosters, caption, banners), off every
##     live label and off every other row;
##   - every `status` event's chip is drawn in its unit's row before the status ends;
##   - every miss, skip, absorb, summon, revive, move, gauge and status tick has its own visible
##     element (a word or number in its unit's column, a cue, a summoned unit, a walk);
##   - labels placed meanwhile keep the column rule and never cover a row or the HUD;
##   - captions name each class's effect ("Tamsin Rune Seal ▸ Sable · sealed").
## No saves are touched.

const BATTLE = preload("res://scenes/battle/battle.tscn")
const StatusScript = preload("res://scenes/battle/battle_status.gd")
const LabelLayout = preload("res://scenes/battle/label_layout.gd")

var _b: Node
var _pending := {}          # "uid:id" -> [frame applied, sim t]
var _seen_events := {}      # event type -> count
var _captions: Array = []
var _last_cap := ""
var _frame_fail := 0
var _hidden_alpha := 1.0
var _linked_pairs := 0
var _hex_beams_ok := true
var _texts: Array = []


func _cap(b: Node) -> String:
	var h = b.hud
	if h.caption_uid < 0:
		return ""
	var lead: String = h.caption_lead_label
	if lead == "":
		lead = "self" if h.caption_target == h.caption_uid else (b.units[h.caption_target].label if h.caption_target >= 0 else h.caption_area)
	if h.caption_area == "column":
		lead = "column"
	if h.caption_extra > 0:
		lead += " + %d" % h.caption_extra
	return "%s %s ▸ %s · %s · %s" % [b.units[h.caption_uid].label, h.caption_text, lead, h.caption_tail_verb, h.caption_note]


func _play(seq: String, res: Vector2i) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var old_size := tree.root.size
	tree.root.size = res
	_b = BATTLE.instantiate()
	_b.autoplay_demo = false
	_b.demo_fight = "classes"
	_b.demo_sequence = seq
	tree.root.add_child(_b)
	_b.fx.recording = true
	_b._start_demo()
	_pending.clear()
	var frames := 0
	while frames < 60 * 90 and not (int(_b._state) == 3 and _b.hud.end_t > 1.0):
		var i0: int = _b._ev_i
		_b._process(1.0 / 60.0)
		frames += 1
		for i in range(i0, _b._ev_i):
			_on_event(_b.events[i], frames)
		_check_frame(seq, frames)
	for k: String in _pending:
		check(false, "%s: status %s (applied at %.2f s) was never drawn in its row" % [seq, k, float(_pending[k][1])])
	_check_labels(seq, _b.fx.record)
	tree.root.remove_child(_b)
	_b.free()
	tree.root.size = old_size


func _on_event(ev: Dictionary, frame: int) -> void:
	var ty := String(ev["type"])
	_seen_events[ty] = int(_seen_events.get(ty, 0)) + 1
	match ty:
		"status":
			_pending["%d:%s" % [int(ev["uid"]), String(ev["status"])]] = [frame, float(ev["t"])]
		"status_end":
			var k := "%d:%s" % [int(ev["uid"]), String(ev["status"])]
			if _pending.has(k):
				# it ended (or its unit fell) before its chip could show: only acceptable the same frame
				check(int(_pending[k][0]) == frame, "status %s ended %.2f s after it landed and was never drawn" % [k, float(ev["t"]) - float(_pending[k][1])])
				_pending.erase(k)
		"spawn":
			if String(ev.get("summon", "")) != "":
				var u = _b.units[int(ev["uid"])]
				eq(u.summon, String(ev["summon"]), "the summon is marked as %s" % ev["summon"])
		"revive":
			check(_b.units[int(ev["uid"])].alive, "a revived unit stands again")


func _check_frame(seq: String, frame: int) -> void:
	var sf = _b.status_fx
	if _cap(_b) != "" and _cap(_b) != _last_cap:
		_last_cap = _cap(_b)
		_captions.append(_last_cap)
	# chips drawn this frame resolve their pending status
	for uid: int in sf.rows:
		for e: Dictionary in StatusScript.row_entries(_b.units[uid]):
			_pending.erase("%d:%s" % [uid, e["id"]])
	if int(_b._state) != 2:
		return
	var labels: Array = _b.fx.live_boxes()
	var hud: Array = _b.fx.clip_rects
	var placed: Array = []
	for uid: int in sf.rows:
		var r: Rect2 = sf.rows[uid]
		var bad := ""
		if not sf.field.encloses(r):
			bad = "outside the field"
		for h: Rect2 in hud:
			if h.intersects(r):
				bad = "over the HUD %s" % h
		for l: Rect2 in labels:
			if l.intersects(r):
				bad = "under a label %s" % l
		for p: Rect2 in placed:
			if p.intersects(r):
				bad = "over another row %s" % p
		placed.append(r)
		if bad != "" and _frame_fail < 12:
			_frame_fail += 1
			check(false, "%s f%d: %s's status row %s is %s" % [seq, frame, _b.units[uid].label, r, bad])
		elif bad == "":
			asserts += 1
	for u in _b.units:
		if u != null and u.alive and u.has_status("hidden"):
			_hidden_alpha = minf(_hidden_alpha, u.spr.self_modulate.a)
		if u != null and u.alive and u.has_status("link"):
			var p := int(u.status_of("link").get("partner", -1))
			if p >= 0 and _b.units[p].status_of("link").get("partner", -1) == u.uid:
				_linked_pairs += 1


## Every label placed: off the HUD, the rows and the other labels (the record's own `blocked` holds
## the rows); numbers and words in their own unit's column.
func _check_labels(seq: String, rec: Array) -> void:
	var fails := 0
	for r: Dictionary in rec:
		var box: Rect2 = r["box"]
		_texts.append(String(r["text"]))
		var ok := true
		for h: Rect2 in r["blocked"]:
			if box.intersection(h).has_area():
				ok = false
				if fails < 8:
					check(false, "%s: label \"%s\" %s covers %s (HUD or a status row)" % [seq, r["text"], box, h])
				fails += 1
		for p: Rect2 in r["placed"]:
			if box.intersection(p).has_area():
				ok = false
				if fails < 8:
					check(false, "%s: label \"%s\" overlaps another label" % [seq, r["text"]])
				fails += 1
		if not bool(r["small"]):
			var own: Dictionary = {}
			var others: Array = []
			for g: Dictionary in r["geo"]:
				if int(g["uid"]) == int(r["uid"]):
					own = g
				else:
					others.append(g)
			if not own.is_empty() and LabelLayout.col_misattribution(box, own, others, 0.0) > 0.0:
				ok = false
				if fails < 8:
					check(false, "%s: label \"%s\" isn't in its own unit's column" % [seq, r["text"]])
				fails += 1
		if ok:
			asserts += 1


func _has_caption(part: String) -> bool:
	for c: String in _captions:
		if c.contains(part):
			return true
	return false


func _has_text(part: String) -> bool:
	for t: String in _texts:
		if t.contains(part):
			return true
	return false


func test_class_showcase_a_binds_summons_moves_and_revives() -> void:
	_play("a", Vector2i(1920, 1080))
	for ty in ["status", "skip", "miss", "spawn", "move", "gauge", "revive"]:
		check(int(_seen_events.get(ty, 0)) > 0, "demo a plays a %s event" % ty)
	check(_has_caption("Moth Unseen Arrest ▸ Brakka") and _has_caption("stunned · 2 blinded"), "Unseen Arrest names the stun and the blinds (%s)" % [_captions])
	check(_has_caption("Brakka is stunned · turn lost"), "the stunned unit's lost turn has its own caption")
	check(_has_caption("Sable Call Echo ▸ Echo of Sable") and _has_caption("summoned"), "Call Echo names the echo it summons")
	check(_has_caption("Brakka Shackle ▸ Corin") and _has_caption("drags Tamsin forward"), "Shackle names the pull")
	check(_has_caption("Corin Drive On ▸ Tamsin + 1") and _has_caption("act now"), "Drive On names the allies it drives on")
	check(_has_caption("Tamsin Rune Seal ▸ Sable") and _has_caption("sealed"), "Rune Seal: \"Tamsin Rune Seal ▸ Sable · sealed\"")
	check(_has_caption("Ilse Rekindle ▸ Sable") and _has_caption("rekindled"), "Rekindle names who stands again")
	for w in ["STUNNED", "MISS", "SUMMONED", "REKINDLED", "Acts Now", "Dragged Forward", "Shoved Back"]:
		check(_has_text(w), "\"%s\" shows on its unit" % w)
	check(_has_text("cost"), "Drive On's HP cost shows as a number tagged cost")


func test_class_showcase_b_afflictions_shields_links() -> void:
	_play("b", Vector2i(1920, 1080))
	for ty in ["status", "absorb", "miss"]:
		check(int(_seen_events.get(ty, 0)) > 0, "demo b plays a %s event" % ty)
	check(_hidden_alpha < 0.6, "a hidden unit fades to a translucent silhouette (alpha %.2f)" % _hidden_alpha)
	check(_linked_pairs > 0, "Bind Lives pairs the two linked units (the tether's ends)")
	check(_has_caption("Brand of Flame") and _has_caption("branded"), "Brand of Flame names the brand")
	check(_has_caption("Lumen Ward ▸ all_allies") and _has_caption("shielded"), "Lumen Ward names the overheal shield %s" % [_captions])
	check(_has_caption("blocked"), "a heal on a branded unit is named blocked")
	check(_has_caption("Wildfire") and _has_caption("set alight"), "Wildfire names the fire")
	check(_has_caption("Bind Lives") and _has_caption("bound to"), "Bind Lives names the pair")
	check(_has_caption("Slow Venom ▸ Moth") and _has_caption("poisoned"), "Slow Venom names the poison")
	check(_has_text("BLOCKED"), "a blocked heal shows BLOCKED on the branded unit")
	check(_has_text("Fire Jumps"), "the fire jumping shows on the unit it jumps to")


func test_class_showcase_c_column_fire_wards_and_hexes() -> void:
	_play("c", Vector2i(1920, 1080))
	check(_has_caption("Vael Hexfire ▸ column"), "Hexfire names the column it climbs")
	check(_has_caption("Raise Husk ▸ Husk of") and _has_caption("raised"), "Raise Husk names the husk")
	check(_has_caption("slowed"), "Slow the Field names the slow")
	check(_has_caption("Burn to Mend") and _has_caption("pays HP") and _has_caption("heal hurts Tamsin"), "Burn to Mend names its cost and the hexed ally")
	check(_has_caption("Ilse Tithe") and _has_caption("takes from"), "Tithe takes from the healthy ally (not \"strikes\") %s" % [_captions])
	check(_has_text("hexed heal") and _has_text("tithe"), "a hexed heal and a tithe show as tagged numbers")
	check(not _has_text("DRAIN"), "no Tithe or Burn to Mend heal is called a drain")


func test_class_showcase_phone_width() -> void:
	# the 19.5:9 phone width (2340x1080 is x3 too): the HUD spreads to the edges, rows keep clear
	_play("a", Vector2i(2340, 1080))
	_play("b", Vector2i(2340, 1080))


func test_hexfire_climbs_the_column_space_by_space() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var old_size := tree.root.size
	tree.root.size = Vector2i(1920, 1080)
	var b: Node = BATTLE.instantiate()
	b.autoplay_demo = false
	b.demo_fight = "classes"
	b.demo_sequence = "c"
	tree.root.add_child(b)
	b._start_demo()
	var starts := {}     # beam y (row) -> frame it started
	var frames := 0
	var hex := false
	while frames < 60 * 40 and not (int(b._state) == 3):
		b._process(1.0 / 60.0)
		frames += 1
		if String(b._cur_action.get("action", "")) == "hexfire":
			hex = true
		for bm: Dictionary in b.fx._beams:
			if float(bm["t"]) > 0.0 and float(bm["at"]) < 0.0 and not starts.has(float(bm["y"])) and hex:
				starts[float(bm["y"])] = frames
		if hex and String(b._cur_action.get("action", "")) != "hexfire":
			break
	check(hex, "the Warlock cast Hexfire")
	var ys: Array = starts.keys()
	ys.sort()
	check(ys.size() >= 4, "the fire stood on all four spaces of the column (%s)" % [starts])
	for i in range(1, ys.size()):
		check(int(starts[ys[i]]) <= int(starts[ys[i - 1]]), "the fire reaches row y %.0f (frame %d) before the row above it (frame %d)" % [ys[i], starts[ys[i]], starts[ys[i - 1]]])
	if ys.size() >= 2:
		check(int(starts[ys[0]]) > int(starts[ys[ys.size() - 1]]), "bottom to top: one space at a time, not all at once")
	tree.root.remove_child(b)
	b.free()
	tree.root.size = old_size


func test_status_row_spots_and_tooltip_sentences() -> void:
	# sap / boon name their stat; poison its stacks; a shield what it has left
	eq(StatusScript.tip_line({"id": "sap", "stat": "def", "value": -0.3}), "Sapped: Def -30%.", "a sap names its stat")
	eq(StatusScript.tip_line({"id": "boon", "stat": "spd", "value": 0.3}), "Blessed: Spd +30%.", "a boon names its stat")
	check(StatusScript.tip_line({"id": "poison", "stacks": 3}).ends_with("(3 stacks)"), "poison names its stacks")
	check(StatusScript.tip_line({"id": "shield", "value": 41.0}).contains("41 damage left"), "a shield says what it has left")
	for id: String in StatusScript.TINT:
		var e := StatusScript.tip_effect({"id": id, "stat": "atk"})
		check(e.get("icon") is Texture2D and String(e.get("name", "")) != "", "%s has an icon and a tooltip title" % id)
	# a row of 5 chips is 59 UI px (under 30 world px) and the touch target is at least 16 px tall
	var sz := StatusScript.row_size(5)
	check(sz.x * StatusScript.ZOOM <= 60.0 and sz.y * StatusScript.ZOOM <= 16.0, "a full row is compact (%s world px)" % sz)
	check(StatusScript.MIN_HIT >= 16.0, "rows keep the 16 px touch target")
