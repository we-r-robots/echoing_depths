extends "res://tests/test_case.gd"
## The battle HUD never covers the board (user playtest 2026-10-06: the rosters and the caption hid
## the bottom-row heroes in a wide, short window). At 16:9 (1920x1080), the 19.5:9 phone
## (2340x1080), a wide short desktop window (1890x730, ~2.6:1) and 4:3 (1440x1080), every demo fight
## plays frame by frame and, on every frame of play, no HUD rect (the top band: badges, team tabs,
## the Fading readout; the bottom band: clock, caption, cut-in, lore, the Fading line, x1 / SKIP)
## touches any living unit's drawn rect, HP plate or status row. No saves are touched.

const BATTLE = preload("res://scenes/battle/battle.tscn")
const SHAPES := [Vector2i(1920, 1080), Vector2i(2340, 1080), Vector2i(1890, 730), Vector2i(1440, 1080)]
## [demo_fight, demo_sequence]
const FIGHTS := [["pvp", ""], ["monsters", ""], ["crystal", "ch1"], ["classes", "a"], ["classes", "b"], ["classes", "c"], ["classes", "d"], ["classes", "e"]]


func _play(fight: Array, res: Vector2i) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var old_size := tree.root.size
	tree.root.size = res
	var b: Node = BATTLE.instantiate()
	b.autoplay_demo = false
	b.demo_fight = String(fight[0])
	if String(fight[1]) != "":
		b.demo_sequence = String(fight[1])
	tree.root.add_child(b)
	b._start_demo()
	var what := "%s%s at %dx%d" % [fight[0], (" " + String(fight[1])) if String(fight[1]) != "" else "", res.x, res.y]
	var vr: Rect2 = b.hud.get_viewport_rect()
	check(vr.size.y >= 360.0, "%s: the design view is at least 360 px tall (%s)" % [what, vr.size])
	var frames := 0
	var fails := 0
	var checked := 0
	while frames < 60 * 100 and int(b._state) != 3:
		b._process(1.0 / 60.0)
		frames += 1
		if int(b._state) != 2:
			continue
		var hud: Array = b._hud_world_rects(b._world_xf().affine_inverse())
		for u in b.units:
			if u == null or not u.alive:
				continue
			var parts := {"body": u.drawn_rect(), "HP bar": u.plate_rect()}
			if b.status_fx.rows.has(u.uid):
				parts["status row"] = b.status_fx.rows[u.uid]
			for k: String in parts:
				var r: Rect2 = parts[k]
				for h: Rect2 in hud:
					if h.intersection(r).has_area():
						fails += 1
						if fails <= 4:
							check(false, "%s f%d: the HUD %s covers %s's %s %s" % [what, frames, h, u.label, k, r])
				checked += 1
	check(checked > 500, "%s: checked the units on every frame of play (%d checks)" % [what, checked])
	if fails == 0:
		asserts += 1
	else:
		check(false, "%s: %d unit parts under the HUD in all" % [what, fails])
	tree.root.remove_child(b)
	b.free()
	tree.root.size = old_size


func test_hud_bands_clear_the_board_at_16_9() -> void:
	for f: Array in FIGHTS:
		_play(f, SHAPES[0])


func test_hud_bands_clear_the_board_on_a_phone() -> void:
	for f: Array in FIGHTS:
		_play(f, SHAPES[1])


func test_hud_bands_clear_the_board_in_a_wide_short_window() -> void:
	for f: Array in FIGHTS:
		_play(f, SHAPES[2])


func test_hud_bands_clear_the_board_at_4_3() -> void:
	for f: Array in FIGHTS:
		_play(f, SHAPES[3])
