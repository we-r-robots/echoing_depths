extends "res://tests/test_case.gd"
## Lanternrest, the village hub (scenes/lanternrest/), a top-down 3/4 town: a fresh save shows only
## the starting places, every place has a tap zone and opens its own menu from a real tap, each
## panel slides its place aside and never covers it, the Vault entrance starts a run, the Training
## Grounds stand after the unlock rule, the first visit asks for the team's identity, the camera
## starts on the plaza (Vault and lantern in view at 16:9 and 19.5:9) and stays inside the town, the
## hint learns and stays gone, edge cues stay off places, the bar's numbers keep their contrast with
## a panel open, and the signboards meet the text floors. Uses a scratch user:// folder, never the
## player's files.

const DIR := "user://test_lanternrest"
const STARTING := ["plot_w2", "plot_e2", "plot_w1", "plot_e1", "plot_s1", "vault", "lantern",
	"fog_north", "fog_west", "fog_east", "fog_south"]
const WIDE := Vector2i(1920, 1080)    # 640 x 360 design px
const PHONE := Vector2i(2340, 1080)   # 780 x 360 design px


func _fresh() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for f in ["settings.json", "meta.json", "run_save.json", "echo_pool.json"]:
		var p := DIR.path_join(f)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	GameState.read_only = false
	GameState.use_paths(DIR)
	GameState.load_all()


func _done() -> void:
	GameState.use_default_paths()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


var _old_size := Vector2i.ZERO


## Opens the screen as the flow does (not the demo), at a screen size (1080p by default).
func _screen(res := WIDE) -> LanternrestScreen:
	if _old_size == Vector2i.ZERO:
		_old_size = _root().size
	_root().size = res
	return LanternrestScreen.open(_root())


func _free(s: Node) -> void:
	s.get_parent().remove_child(s)
	s.free()
	Tip.close()
	if _old_size != Vector2i.ZERO:
		_root().size = _old_size


## A real tap (press and release, no movement) on a place: the camera first brings it on screen.
func _tap_place(s: LanternrestScreen, id: String) -> void:
	s.set_cam(Village.cam_for(Village.zone(id).get_center(), s.view_size()))
	_click(s, s.to_screen(_tap_point(s, id)))


## A point inside the place's zone that is on screen and below the top bar.
func _tap_point(s: LanternrestScreen, id: String) -> Vector2:
	var z := Village.zone(id)
	var vis := Rect2(s.to_world(Vector2(0, LanternrestScreen.TOP + 1)), s.view_size() - Vector2(0, LanternrestScreen.TOP + 1))
	return z.intersection(vis).get_center()


func _click(s: LanternrestScreen, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	s._gui_input(down)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	s._gui_input(up)


func _drag(s: LanternrestScreen, from: Vector2, by: Vector2, steps := 10) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	s._gui_input(down)
	for k in range(1, steps + 1):
		var mv := InputEventMouseMotion.new()
		mv.position = from + by * float(k) / steps
		s._gui_input(mv)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	up.position = from + by
	s._gui_input(up)


## WCAG contrast ratio of two opaque colours.
static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	var ch := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


func test_fresh_town_has_only_the_starting_places() -> void:
	var meta := GameState.default_meta()
	var ids := Village.visible_places(meta)
	eq(Array(ids), STARTING, "a fresh save: five empty plots, the Vault entrance, the lantern and the mist on four sides")
	check(not ids.has("grounds"), "no Training Grounds yet")
	var kinds := {}
	for id in ids:
		kinds[Village.kind(id)] = int(kinds.get(Village.kind(id), 0)) + 1
	eq(kinds, {"plot": 5, "vault": 1, "lantern": 1, "fog": 4}, "place kinds on a fresh save")
	# the town is bigger than any screen both ways (about 3 x 2 screens at 640 x 360)
	var ws := Village.world_size()
	check(ws.x >= 3 * 640 and ws.y >= 2 * 360, "the town is about three screens wide and two high (%s)" % ws)
	check(int(ws.x) % 16 == 0 and int(ws.y) % 16 == 0, "the town is a whole number of 16 px tiles")
	# every place has a tap zone (at least 16 px each way, inside the town), a sign point and its
	# art and highlight; zones of places that stand together never overlap
	var all: Array = Village.PLACES.keys()
	for id: String in all:
		var z := Village.zone(id)
		check(z.size.x >= 16 and z.size.y >= 16, "%s tap zone %s is at least 16x16" % [id, z])
		check(Rect2(Vector2.ZERO, ws).encloses(z), "%s tap zone lies inside the town" % id)
		check(Rect2(Vector2.ZERO, ws).has_point(Village.sign_at(id)), "%s has a sign point in the town" % id)
		var art := Village.art(id)
		if art != "":
			check(Village.texture(art) != null, "%s has its art" % id)
		check(Village.texture((art if art != "" else id) + "_hi") != null, "%s has its highlight" % id)
	var built := GameState.default_meta()
	built["runs"] = 1
	for meta_case: Dictionary in [meta, built]:
		var vis := Village.visible_places(meta_case)
		for i in vis.size():
			for j in range(i + 1, vis.size()):
				check(not Village.zone(vis[i]).intersects(Village.zone(vis[j])), "zones of %s and %s overlap" % [vis[i], vis[j]])
	# the screen builds exactly those places as world objects, then asks who carries the lantern
	_fresh()
	var s := _screen()
	eq(Array(s.visible_ids), STARTING, "the screen builds the starting places")
	eq(s.places.size(), STARTING.size(), "one world object per place")
	for id: String in s.places:
		check(s.places[id] is VillagePlace and s.world.is_ancestor_of(s.places[id] as Node), "%s is a positioned world object" % id)
	eq(s.panel_kind(), "identity", "the first visit asks for the team's name and crest")
	eq(s.panel_place(), "lantern", "the identity panel points at the lantern")
	_free(s)
	_done()


func test_first_visit_picks_a_team_identity() -> void:
	_fresh()
	check(GameState.identity_needed(), "a fresh save needs a team identity")
	var s := _screen()
	var p := s.panel as IdentityPanel
	check(p != null, "the identity panel is open")
	check(not p.closable, "it can't be dismissed without choosing")
	s.finish_camera()
	check(not Rect2(p.position, p.size).intersects(s.zone_on_screen("lantern")), "the picker does not cover the lantern")
	_click(s, s.to_screen(Village.zone("vault").get_center()))
	eq(s.panel_kind(), "identity", "the town waits behind it (a tap on a place does nothing)")
	check(IdentityPanel.NAMES.size() >= 4, "a handful of generic names")
	p.pick_name(IdentityPanel.NAMES[2])
	p.pick_crest("moon")
	p.confirm()
	eq(s.panel_kind(), "", "choosing closes the panel")
	GameState.load_all()
	eq(GameState.team_name(), IdentityPanel.NAMES[2], "the chosen name is saved")
	eq(GameState.crest(), "moon", "the chosen crest is saved")
	check(not GameState.identity_needed(), "asked once")
	eq((s.places["lantern"] as VillagePlace).crest_id, "moon", "the lantern's banner shows the new crest")
	_free(s)
	var s2 := _screen()
	eq(s2.panel_kind(), "", "the next visit opens straight onto the town")
	_free(s2)
	_done()


func test_every_place_opens_its_panel_beside_it() -> void:
	for res: Vector2i in [WIDE, PHONE]:
		_fresh()
		GameState.set_identity("The Wayfarers", "lantern")
		GameState.meta["runs"] = 1
		var s := _screen(res)
		var tag := "%dx%d" % [res.x, res.y]
		for id in s.visible_ids:
			_tap_place(s, id)
			check(s.panel != null, "%s: tapping %s opens a panel" % [tag, id])
			if s.panel == null:
				continue
			eq(s.panel.place_id, id, "%s: the panel belongs to %s" % [tag, id])
			match Village.kind(id):
				"lantern":
					check(s.panel is LanternPanel, "the Lantern opens the progress and Banner Hall menu")
				"vault":
					check(s.panel is VaultPanel, "the Vault entrance opens the descent menu")
				"building":
					check(s.panel is TrainingGroundsPanel, "the Training Grounds open the shapes menu")
				_:
					check(not (s.panel is LanternPanel or s.panel is VaultPanel or s.panel is TrainingGroundsPanel),
						"%s opens a note" % id)
			check((s.places[id] as VillagePlace).highlight, "%s: %s is highlighted while its panel is open" % [tag, id])
			# the camera slides the place aside; the panel opens on the other half, never over it
			s.finish_camera()
			var pr := Rect2(s.panel.position, s.panel.size)
			var zs := s.zone_on_screen(id)
			check(not pr.intersects(zs), "%s: the %s panel %s does not cover its place %s" % [tag, id, pr, zs])
			check(Rect2(Vector2.ZERO, s.view_size()).encloses(pr), "%s: the %s panel is on screen" % [tag, id])
			check(pr.position.y >= LanternrestScreen.TOP, "%s: the %s panel is under the top bar" % [tag, id])
			var vis := Rect2(Vector2(0, LanternrestScreen.TOP), s.view_size() - Vector2(0, LanternrestScreen.TOP))
			check(vis.intersects(zs), "%s: %s stays in view beside its panel" % [tag, id])
			s.close_panel()
			check(s.panel == null, "Close closes it")
		# a tap on empty ground opens nothing; a drag never taps
		s.set_cam(Village.cam_for(Vector2(960, 408), s.view_size()))
		_click(s, s.to_screen(Vector2(860, 412)))
		eq(s.panel_kind(), "", "%s: a tap on the high street opens nothing" % tag)
		var at := s.to_screen(Village.zone("lantern").get_center())
		_drag(s, at, Vector2(40, 10))
		eq(s.panel_kind(), "", "%s: dragging across the lantern does not open it" % tag)
		# a tap on the dim outside the panel closes it
		_tap_place(s, "lantern")
		var out := InputEventMouseButton.new()
		out.button_index = MOUSE_BUTTON_LEFT
		out.pressed = true
		out.position = Vector2(4, 350)
		s._shade.gui_input.emit(out)
		eq(s.panel_kind(), "", "%s: a tap outside the panel closes it" % tag)
		_free(s)
		_done()


func test_lantern_menu_keeps_the_banner_hall_working() -> void:
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	GameState.meta["glimmers"] = 87
	var s := _screen()
	s.open_place("lantern")
	var p := s.panel as LanternPanel
	eq(p.bar_text(), "87 / 100 Glimmers", "the bar shows the Glimmers toward a Shard")
	check((p.find_child("FormShard", true, false) as Button).disabled, "not enough Glimmers: Form a Shard is off")
	eq((p.find_child("ShardNote", true, false) as Label).text, "Needs 100 Glimmers: 13 more to go.", "and it says why")
	# the Glimmers section comes first
	var tags: Array = []
	for c: Node in p.body.get_children():
		if c is Label and (c as Label).theme_type_variation == &"TagLabel":
			tags.append((c as Label).text)
	eq(tags[0], "GLIMMERS INTO SHARDS", "the Glimmers section is first")
	GameState.meta["glimmers"] = GameState.GLIMMERS_PER_SHARD + GameState.CREST_COST
	p.refresh()
	p.select_crest("star")
	p.unlock_crest()
	eq(GameState.crest(), "star", "a crest is remembered for Glimmers and worn")
	eq((s.places["lantern"] as VillagePlace).crest_id, "star", "the banner follows")
	(p.find_child("FormShard", true, false) as Button).pressed.emit()
	eq(int(GameState.meta["shards"]), 1, "Glimmers form a Shard at the Lantern")
	(p.find_child("TeamName", true, false) as LineEdit).text = "The Night Lamps"
	p.close()
	GameState.load_all()
	eq(GameState.team_name(), "The Night Lamps", "a renamed team is saved on close")
	_free(s)
	_done()


func test_vault_entrance_starts_a_run() -> void:
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	var s := _screen()
	var fired := []
	s.new_run.connect(func() -> void: fired.append("new"))
	s.continue_run.connect(func() -> void: fired.append("continue"))
	_tap_place(s, "vault")
	var v := s.panel as VaultPanel
	check(v != null and not v.has_saved, "no saved run: the Vault offers only Descend")
	(v.find_child("New", true, false) as Button).pressed.emit()
	eq(fired, ["new"], "Descend starts a new run")
	_free(s)
	# with a run in progress: Continue resumes it; a new descent needs a second tap
	GameState.save_run(5, GameState.run_options(), [])
	var s2 := _screen()
	fired.clear()
	s2.new_run.connect(func() -> void: fired.append("new"))
	s2.continue_run.connect(func() -> void: fired.append("continue"))
	s2.open_place("vault")
	var v2 := s2.panel as VaultPanel
	check(v2.has_saved, "the saved run is offered")
	(v2.find_child("Continue", true, false) as Button).pressed.emit()
	v2.new_descent()
	eq(fired, ["continue"], "Continue resumes; the first tap on a new descent only warns")
	v2.new_descent()
	eq(fired, ["continue", "new"], "the second tap starts the new run")
	_free(s2)
	GameState.clear_saved_run()
	# the flow: title -> Lanternrest -> the Vault entrance starts the run (bot plays it)
	var flow: Flow = Flow.new()
	flow.bot = true
	flow.show_title()
	check(flow.bot_step(), "title answered")
	eq(String(flow.pending.get("kind", "")), "lanternrest", "the title leads into Lanternrest")
	check(flow.bot_step(), "Lanternrest answered")
	check(flow.run != null, "the Vault entrance started a run")
	eq(String(flow.pending.get("kind", "")), "draft", "the run opens on the draft")
	var n := 0
	while flow.bot_step("title") and n < 2000:
		n += 1
	var seen := flow.visited
	eq(seen[seen.size() - 2], "lanternrest", "the run's results return to Lanternrest")
	flow.free()
	_done()


func test_training_grounds_stand_after_the_first_run() -> void:
	var meta := GameState.default_meta()
	check(not Village.is_built("grounds", meta), "not before any run")
	meta["runs"] = 1
	check(Village.is_built("grounds", meta), "built once the first run comes home (placeholder rule)")
	var ids := Village.visible_places(meta)
	check(ids.has("grounds"), "the Training Grounds stand")
	check(not ids.has("plot_e1"), "on the plot they were built on")
	eq(ids.size(), STARTING.size(), "the plot is replaced, nothing else changes")
	eq(Array(Village.unseen(meta)), ["grounds"], "new: tagged until the player looks")
	# through the screen: after a run the camera shows them, tapping clears NEW
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	GameState.apply_summary({"outcome": "fallen", "glimmers": 10, "floor": 1, "depth": 4})
	var s := _screen()
	check(s.places.has("grounds") and not s.places.has("plot_e1"), "the screen builds the barracks yard on its plot")
	var vis := Rect2(s.cam + Vector2(0, LanternrestScreen.TOP), s.view_size() - Vector2(0, LanternrestScreen.TOP))
	check(vis.encloses(Village.zone("grounds")), "the camera starts with the new yard in view")
	check(vis.encloses(Village.zone("lantern")), "and the lantern")
	_tap_place(s, "grounds")
	var g := s.panel as TrainingGroundsPanel
	check(g != null, "the yard opens the Training Grounds")
	check(Village.unseen(GameState.meta).is_empty(), "looking at it clears NEW")
	GameState.load_all()
	check(Village.unseen(GameState.meta).is_empty(), "and that is saved")
	# shape tiles: learned with a check, learnable with its price, locked with the shape it grows from
	eq(TrainingGroundsPanel.shape_state("kindred"), "learned", "a starting shape is learned")
	eq(TrainingGroundsPanel.status_text("kindred"), "Learned", "learned shapes say so")
	eq(TrainingGroundsPanel.shape_state("keystone"), "learnable", "Keystone grows from a known shape")
	eq(TrainingGroundsPanel.status_text("keystone"), "1 Shard", "a learnable shape shows its Shard price")
	eq(TrainingGroundsPanel.status_text("seawall"), "1 Shard" if GameState.shape_cost("seawall") == 1 else "2 Shards", "four-hero shapes cost more")
	eq(TrainingGroundsPanel.shape_state("crescent"), "locked", "Crescent waits for Keystone")
	eq(TrainingGroundsPanel.status_text("crescent"), "Keystone", "a locked shape names the shape it grows from")
	var tile := g.find_child("Shape_crescent", true, false) as Control
	eq((tile.get_node("Status") as Label).text, "Keystone", "the tile shows it")
	_free(s)
	_done()


func test_camera_starts_on_the_plaza_and_stays_in_the_town() -> void:
	var ws := Village.world_size()
	for res: Vector2i in [WIDE, PHONE]:
		_fresh()
		GameState.set_identity("The Wayfarers", "lantern")
		var s := _screen(res)
		var view := s.view_size()
		var tag := "%dx%d (%d px wide)" % [res.x, res.y, view.x]
		# the opening view: the plaza in the middle, the Vault and the lantern (and their signs)
		# under the top bar and above the hint
		var vis := Rect2(s.cam + Vector2(0, LanternrestScreen.TOP), Vector2(view.x, LanternrestScreen.HINT_Y - LanternrestScreen.TOP))
		for id in ["vault", "lantern"]:
			check(vis.encloses(Village.zone(id)), "%s: the opening view shows all of %s" % [tag, id])
			check(vis.has_point(Village.sign_at(id) - Vector2(0, LanternrestScreen.STEM + LanternrestScreen.SIGN_H)), "%s: and its sign" % [tag])
		check(absf(s.cam.x + view.x / 2.0 - 960.0) <= 1.0, "%s: centred on the plaza" % tag)
		# the mist is in sight from the start (the town is half-erased)
		var f := Village.zone("fog_north")
		check(s.cam.y < f.end.y + 140.0, "%s: the north mist is near the top of the opening view" % tag)
		# clamped in both directions, on whole pixels
		s.set_cam(Vector2(-1000, -1000))
		eq(s.cam, Vector2.ZERO, "%s: no further than the top-left corner" % tag)
		eq(s.world.position, Vector2.ZERO, "%s: the town's corner meets the screen's" % tag)
		s.set_cam(Vector2(1e9, 1e9))
		eq(s.cam, ws - view, "%s: no further than the bottom-right corner" % tag)
		eq(s.world.position, -(ws - view), "%s: the far corner meets the screen's" % tag)
		# a drag pans both ways; a long drag stops at the edge
		s.set_cam(Village.cam_for(Vector2(960, 400), view))
		var c0 := s.cam
		_drag(s, Vector2(300, 200), Vector2(-60, -40))
		eq(s.cam, c0 + Vector2(60, 40), "%s: a drag pans in two dimensions" % tag)
		check(s.did_look, "and counts as looking around")
		_drag(s, Vector2(100, 100), Vector2(2400, 1200), 30)
		eq(s.cam, Vector2.ZERO, "%s: a long drag stops at the corner" % tag)
		check(s.world.position == s.world.position.round(), "%s: the town sits on whole pixels" % tag)
		# the wheel scrolls down (and sideways with shift) and clamps
		for k in 100:
			var wh := InputEventMouseButton.new()
			wh.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wh.pressed = true
			wh.factor = 1.0
			s._gui_input(wh)
		eq(s.cam.y, ws.y - view.y, "%s: the wheel stops at the bottom edge" % tag)
		var sh := InputEventMouseButton.new()
		sh.button_index = MOUSE_BUTTON_WHEEL_DOWN
		sh.pressed = true
		sh.shift_pressed = true
		sh.factor = 1.0
		s._gui_input(sh)
		eq(s.cam.x, LanternrestScreen.WHEEL_STEP, "%s: shift + wheel scrolls sideways" % tag)
		_free(s)
		_done()


func test_edge_cues_never_sit_on_a_place() -> void:
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	GameState.meta["runs"] = 1
	for res: Vector2i in [WIDE, PHONE]:
		var s := _screen(res)
		var view := s.view_size()
		var maxc := Village.clamp_cam(Vector2(INF, INF), view)
		var shown := 0
		for fx in range(0, 9):
			for fy in range(0, 5):
				s.set_cam(Vector2(maxc.x * fx / 8.0, maxc.y * fy / 4.0))
				for c: Dictionary in s.cue_rects():
					shown += 1
					var r: Rect2 = c["rect"]
					check(Rect2(Vector2.ZERO, view).encloses(r), "cue %s on screen" % r)
					check(r.position.y >= LanternrestScreen.TOP, "cue %s under the top bar" % r)
					for id in s.visible_ids:
						check(not r.intersects(s.zone_on_screen(id)), "cam %s: the %s cue %s sits on %s" % [s.cam, c["dir"], r, id])
					for id in s.shown_plates():
						check(not r.intersects(s.plate_rect(id)), "cam %s: a cue covers the %s sign" % [s.cam, id])
		check(shown > 40, "cues show where there is more town (%d)" % shown)
		# at a corner only the two open directions are cued; a cue's tap pages that way
		s.set_cam(Vector2.ZERO)
		var dirs := s.cue_rects().map(func(c: Dictionary) -> Vector2: return c["dir"])
		check(not dirs.has(Vector2.LEFT) and not dirs.has(Vector2.UP), "no cue toward the town's edge")
		for c: Dictionary in s.cue_rects():
			if c["dir"] == Vector2.RIGHT:
				s.tap((c["rect"] as Rect2).get_center())
				s.finish_camera()
				check(s.cam.x > 0.0 and s.panel == null, "the right cue pages right and is not a place")
		_free(s)
	_done()


func test_hint_learns_and_stays_hidden() -> void:
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	var s := _screen()
	eq(s.hint_text(), LanternrestScreen.HINT_FULL, "a new player sees the whole hint")
	_drag(s, Vector2(320, 200), Vector2(30, 0))
	eq(s.hint_text(), LanternrestScreen.HINT_TAP, "after a drag it only says how to visit")
	check(not bool(GameState.meta.get("village_hint_done", false)), "not done yet")
	_tap_place(s, "plot_w1")
	eq(s.hint_text(), "", "after a drag and a tap it is gone")
	GameState.load_all()
	check(bool(GameState.meta.get("village_hint_done", false)), "and that is saved (village_hint_done)")
	_free(s)
	var s2 := _screen()
	eq(s2.hint_text(), "", "it stays gone on the next visit")
	_free(s2)
	# a tap first shortens it the other way; a finished run hides it too
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	var s3 := _screen()
	_tap_place(s3, "vault")
	s3.close_panel()
	eq(s3.hint_text(), LanternrestScreen.HINT_LOOK, "after a tap it only says how to look around")
	_free(s3)
	GameState.apply_summary({"outcome": "fallen", "glimmers": 5, "floor": 1, "depth": 2})
	var s4 := _screen()
	eq(s4.hint_text(), "", "after a run the hint is gone")
	_free(s4)
	_done()


func test_panel_dim_keeps_the_bar_readable() -> void:
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	var s := _screen()
	for id in ["lantern", "vault", "plot_w1", "fog_west"]:
		s.open_place(id)
		check(s.shade_rect().position.y > LanternrestScreen.TOP, "%s: the dim starts below the top bar" % id)
		eq(LanternrestScreen.SHADE, 0.5, "one shared dim of 0.5")
		# z order: dim, then the place lifted above it, then the panel
		check(s._shade.get_index() < s._lift.get_index() and s._lift.get_index() < s.panel.get_index(), "%s: dim < place < panel" % id)
		s.close_panel()
	# the currency on the top bar (never dimmed) against the bar's ink
	var ratio := contrast(Pal.AMBER6, Pal.INK2)
	check(ratio >= 4.5, "the bar's Glimmers and Shards stay at %.1f:1 with a panel open" % ratio)
	_free(s)
	_done()


func test_signboards_meet_the_text_floors() -> void:
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	GameState.meta["runs"] = 1
	var xh := UIText.x_height_1080(UIText.BOLD, UIText.LABEL)
	check(xh >= UIText.MIN_X_HEIGHT_1080, "sign text x-height %.1f px at 1080p >= %d" % [xh, UIText.MIN_X_HEIGHT_1080])
	# sign text over its board (the board is 92% ink over the night town: check against both inks)
	for col: Color in [Pal.AMBER6, Pal.INK9, Pal.CRYSTAL5]:
		for back: Color in [Pal.INK1, Pal.INK2]:
			check(contrast(col, back) >= 4.5, "sign text %s on %s is %.1f:1" % [col, back, contrast(col, back)])
	check(contrast(Pal.CRYSTAL5, Pal.CRYSTAL2) >= 4.5, "the NEW tag reads (%.1f:1)" % contrast(Pal.CRYSTAL5, Pal.CRYSTAL2))
	check(contrast(Pal.INK10, Pal.CRYSTAL2) >= 4.5, "the Glimmer bar's count reads on its fill (%.1f:1)" % contrast(Pal.INK10, Pal.CRYSTAL2))
	check(contrast(Pal.INK9, Pal.INK1) >= 4.5, "the hint reads")
	for res: Vector2i in [WIDE, PHONE]:
		var s := _screen(res)
		s.set_cam(s.start_cam())
		var shown := s.shown_plates()
		check(shown.has("lantern") and shown.has("vault") and shown.has("grounds"), "the main places' signs show without hover")
		for id in shown:
			var r := s.plate_rect(id)
			check(Rect2(Vector2.ZERO, s.view_size()).encloses(r), "%s sign on screen" % id)
			check(r.position.y >= LanternrestScreen.TOP, "%s sign under the top bar" % id)
		_free(s)
	_done()


func test_gear_menu_opens_settings_and_returns_to_title() -> void:
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	var s := _screen()
	var hit := []
	s.to_title.connect(func() -> void: hit.append(1))
	check(s.find_child("TitleButton", true, false) == null, "no Title button on the bar")
	var gear := s.find_child("GearButton", true, false) as Button
	check(gear != null and gear.size.x <= 32, "a small gear instead")
	gear.pressed.emit()
	var menu := s.find_child("GearMenu", true, false)
	check(menu != null, "the gear opens a small menu")
	(menu.find_child("Settings", true, false) as Button).pressed.emit()
	var settings: SettingsScreen = null
	for c in s.get_children():
		if c is SettingsScreen:
			settings = c
	check(settings != null, "Settings opens over the town")
	if settings != null:
		settings.close()
		check(s._settings == null, "and closes back to it")
	gear.pressed.emit()
	(s.find_child("GearMenu", true, false).find_child("ToTitle", true, false) as Button).pressed.emit()
	eq(hit.size(), 1, "Return to title leaves the town")
	_free(s)
	_done()


func test_title_leads_into_lanternrest() -> void:
	_fresh()
	var t := TitleScreen.open(_root())
	check(t.buttons.has("new") and not t.buttons.has("continue"), "a fresh save offers New game")
	var hit := []
	t.lanternrest.connect(func() -> void: hit.append(1))
	(t.buttons["new"] as Button).pressed.emit()
	eq(hit.size(), 1, "New game leads into Lanternrest")
	t.get_parent().remove_child(t)
	t.free()
	GameState.set_identity("The Wayfarers", "lantern")
	var t2 := TitleScreen.open(_root())
	check(t2.buttons.has("continue") and not t2.buttons.has("new"), "with a save the title offers Continue")
	t2.get_parent().remove_child(t2)
	t2.free()
	_done()
