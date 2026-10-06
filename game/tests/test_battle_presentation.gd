extends "res://tests/test_case.gd"
## Battle presentation, critic round 11 backlog (round-16 build): captions name every kind of target,
## an ability's banner waits for the previous actor, the Fading's line comes before its readout and
## its tag marks only each step's first hit, the result restages the survivors centre front.
## Plays the PvP demo through the real battle scene frame by frame (no saves are touched).

const BATTLE = preload("res://scenes/battle/battle.tscn")
const BattleScript = preload("res://scenes/battle/battle.gd")

var _captions: Array = []        # [actor, ability, lead, tail] per caption shown
var _last_cap := ""
var _cutins := 0
var _cutin_busy := 0
var _prev_cutin_t := 99.0
var _readout_before_line := 0
var _line_seen := false
var _readouts: Array = []
var _result := {}
var _actor := -1
var _prev_actor := -1


func _cap_text(b: Node) -> String:
	var h = b.hud
	if h.caption_uid < 0:
		return ""
	var lead: String = "self" if h.caption_target == h.caption_uid else (b.units[h.caption_target].label if h.caption_target >= 0 else h.caption_area)
	if h.caption_extra > 0:
		lead += " + %d" % h.caption_extra
	var tail := ""
	if h.caption_tail_verb != "" and h.caption_tail >= 0:
		tail = "%s %s" % [h.caption_tail_verb, "self" if h.caption_tail == h.caption_uid else b.units[h.caption_tail].label]
		if h.caption_tail_extra > 0:
			tail += " + %d" % h.caption_tail_extra
	return "%s|%s|%s|%s" % [b.units[h.caption_uid].label, h.caption_text, lead, tail]


func _frame(b: Node) -> void:
	var c := _cap_text(b)
	if c != "" and c != _last_cap:
		_last_cap = c
		_captions.append(c.split("|"))
	if b._last_actor != _actor:
		_prev_actor = _actor
		_actor = b._last_actor
	# a new ability cut-in: the unit that acted before is idle (or the hold ran out)
	if b.hud.cutin_t < _prev_cutin_t and b.hud.cutin_t < 0.05:
		_cutins += 1
		var p = b.units[_prev_actor] if _prev_actor >= 0 else null
		if p != null and p.uid != b.hud.cutin_uid and p.alive and (p.acting or p.swing_left > 0.0):
			_cutin_busy += 1
			check(false, "the %s banner waits for %s to finish (acting %s, swing %.2f s left) at %.2f s" % [b.hud.cutin_name, p.label, p.acting, p.swing_left, b.sim_t])
	_prev_cutin_t = b.hud.cutin_t
	if b.hud.fading_line_on():
		_line_seen = true
	var ro: String = b.hud.fading_readout()
	if ro != "":
		if not _line_seen:
			_readout_before_line += 1
		if _readouts.is_empty() or _readouts[-1] != ro:
			_readouts.append(ro)
	if int(b._state) == 3 and b.hud.end_t > 1.2 and _result.is_empty():
		var win: Array = []
		var fallen: Array = []
		for u in b.units:
			if u.alive and u.side == b.hud.winner:
				win.append([u.label, u.position])
			elif not u.alive:
				fallen.append([u.label, u.modulate.a, u.z_index])
		_result = {"win": win, "fallen": fallen}


func _play_pvp() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var old_size := tree.root.size
	tree.root.size = Vector2i(1920, 1080)
	var b: Node = BATTLE.instantiate()
	b.autoplay_demo = false
	b.demo_fight = "pvp"
	tree.root.add_child(b)
	b.fx.recording = true
	b._start_demo()
	var frames := 0
	while frames < 60 * 120 and not (int(b._state) == 3 and b.hud.end_t > 1.3):
		b._process(1.0 / 60.0)
		frames += 1
		_frame(b)
	var rec: Array = b.fx.record
	tree.root.remove_child(b)
	b.free()
	tree.root.size = old_size
	return rec


func test_pvp_presentation_backlog() -> void:
	var rec := _play_pvp()
	# 2: captions name every kind of target; "+ N" only for the same kind
	var by_name := {}
	for c: Array in _captions:
		by_name["%s %s" % [c[0], c[1]]] = by_name.get("%s %s" % [c[0], c[1]], []) + [c]
	var mend_ilse: Array = by_name.get("Ilse Mend", [])
	check(not mend_ilse.is_empty(), "Ilse's Mend had a caption")
	if not mend_ilse.is_empty():
		eq(mend_ilse[0][2], "Sable", "Ilse Mend leads with the ally it heals")
		eq(mend_ilse[0][3], "strikes Corin", "and names the enemy it strikes (not \"+ 1\")")
	var mend_oren: Array = by_name.get("Oren Mend", [])
	check(not mend_oren.is_empty(), "Oren's Mend had a caption")
	if not mend_oren.is_empty():
		eq(mend_oren[0][2], "Ilse", "Oren Mend on himself leads with the hero it strikes")
		eq(mend_oren[0][3], "heals self", "and says it heals himself")
	var cleave: Array = by_name.get("Brakka Cleave", [])
	check(not cleave.is_empty() and cleave[0][2] == "Moth + 2" and cleave[0][3] == "", "Brakka's first Cleave reads \"Moth + 2\", all struck (%s)" % [cleave])
	# 4: every ability banner waited for the previous actor
	check(_cutins >= 4, "ability banners were seen (%d)" % _cutins)
	eq(_cutin_busy, 0, "banners that came up while the previous actor was still busy")
	# 6: the Fading's line before its readout, no ×1.00, the per-hit tag once per step
	check(_line_seen, "the Fading line showed")
	eq(_readout_before_line, 0, "frames with a Fading readout before its line")
	check(not _readouts.is_empty(), "the Fading readout showed (%s)" % [_readouts])
	for ro: String in _readouts:
		check(not ro.contains("×1.00"), "readout \"%s\" starts at the first real step" % ro)
	var tags := 0
	for r: Dictionary in rec:
		if String(r["text"]).contains("Fading ×"):
			tags += 1
	check(tags >= 1 and tags <= 4, "the \"Fading ×N\" tag marks only each step's first hit (%d tags, 4 steps)" % tags)
	# 5: the survivors stand centre front, the fallen recede
	check(not _result.is_empty(), "the result played")
	if not _result.is_empty():
		var win: Array = _result["win"]
		check(win.size() >= 1, "survivors stand at the result")
		for w: Array in win:
			var p: Vector2 = w[1]
			check(absf(p.x - 320.0) <= 70.0 and absf(p.y - BattleScript.VICTORY_Y) <= 1.0, "%s stands centre front at the result (%s)" % [w[0], p])
		for f: Array in _result["fallen"]:
			check(float(f[1]) < 0.5 and int(f[2]) < 0, "%s has faded back behind the survivors (alpha %.2f, z %d)" % [f[0], f[1], f[2]])

