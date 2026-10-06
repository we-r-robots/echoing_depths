extends "res://tests/test_case.gd"
## Lanternrest, the village hub (scenes/lanternrest/): a fresh save shows only the starting places,
## every place opens its own menu from a real tap, the Vault entrance starts a run, the Training
## Grounds stand after the unlock rule, the first visit asks for the team's identity, and the
## camera stays inside the world. Uses a scratch user:// folder, never the player's files.

const DIR := "user://test_lanternrest"
const STARTING := ["plot_w1", "plot_w2", "plot_e1", "plot_e2", "plot_e3", "vault", "lantern", "fog_west", "fog_east"]


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
	GameState.use_paths("user://")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


var _old_size := Vector2i.ZERO


## Opens the screen as the flow does (not the demo), at the 1080p design size.
func _screen() -> LanternrestScreen:
	if _old_size == Vector2i.ZERO:
		_old_size = _root().size
	_root().size = Vector2i(1920, 1080)
	return LanternrestScreen.open(_root())


func _free(s: Node) -> void:
	s.get_parent().remove_child(s)
	s.free()
	Tip.close()
	if _old_size != Vector2i.ZERO:
		_root().size = _old_size


## A real tap (press and release, no movement) on a place: the camera first brings it on screen.
func _tap_place(s: LanternrestScreen, id: String) -> void:
	var p: VillagePlace = s.places[id]
	s.set_cam(Village.cam_for(p.center_x(), s.view_w()))
	var at := s.to_screen(p.world_zone().get_center())
	_click(s, at)


func _click(s: LanternrestScreen, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	s._gui_input(down)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	s._gui_input(up)


func test_fresh_village_has_only_the_starting_places() -> void:
	var meta := GameState.default_meta()
	var ids := Village.visible_places(meta)
	eq(Array(ids), STARTING, "a fresh save: the lantern, the Vault entrance, five empty plots and the mist on both sides")
	check(not ids.has("grounds"), "no Training Grounds yet")
	var kinds := {}
	for id in ids:
		kinds[Village.kind(id)] = int(kinds.get(Village.kind(id), 0)) + 1
	eq(kinds, {"plot": 5, "vault": 1, "lantern": 1, "fog": 2}, "place kinds on a fresh save")
	# every place has art, a highlight and a tap zone at least 16 px each way inside the world
	var ws := Village.world_size()
	for id: String in Village.PLACES:
		var art := String(Village.PLACES[id]["art"])
		check(Village.texture(art) != null and Village.texture(art + "_hi") != null, "%s has its art and highlight" % id)
		var z := Village.zone(id)
		check(z.size.x >= 16 and z.size.y >= 16, "%s tap zone %s is at least 16x16" % [id, z])
		check(Rect2(Vector2.ZERO, ws).encloses(z), "%s tap zone lies inside the world" % id)
	# the screen on a fresh save builds exactly those places, then asks who carries the lantern
	_fresh()
	var s := _screen()
	eq(Array(s.visible_ids), STARTING, "the screen builds the starting places")
	eq(s.places.size(), STARTING.size(), "one world object per place")
	for id: String in s.places:
		check(s.places[id] is VillagePlace and (s.places[id] as Node).get_parent() == s.world, "%s is a positioned world object" % id)
	eq(s.panel_kind(), "identity", "the first visit asks for the team's name and crest")
	_free(s)
	_done()


func test_first_visit_picks_a_team_identity() -> void:
	_fresh()
	check(GameState.identity_needed(), "a fresh save needs a team identity")
	var s := _screen()
	var p := s.panel as IdentityPanel
	check(p != null, "the identity panel is open")
	check(not p.closable, "it can't be dismissed without choosing")
	_click(s, s.to_screen((s.places["vault"] as VillagePlace).world_zone().get_center()))
	eq(s.panel_kind(), "identity", "the village waits behind it (a tap on a place does nothing)")
	eq(IdentityPanel.NAMES.size() >= 4, true, "a handful of generic names")
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
	eq(s2.panel_kind(), "", "the next visit opens straight onto the village")
	_free(s2)
	_done()


func test_every_place_opens_its_panel_from_a_tap() -> void:
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	GameState.meta["runs"] = 1
	var s := _screen()
	for id in s.visible_ids:
		_tap_place(s, id)
		check(s.panel != null, "tapping %s opens a panel" % id)
		if s.panel == null:
			continue
		eq(s.panel.place_id, id, "the panel belongs to %s" % id)
		match Village.kind(id):
			"lantern":
				check(s.panel is LanternPanel, "the Lantern opens the team identity menu")
			"vault":
				check(s.panel is VaultPanel, "the Vault entrance opens the descent menu")
			"building":
				check(s.panel is TrainingGroundsPanel, "the Training Grounds open the shapes menu")
			_:
				check(not (s.panel is LanternPanel or s.panel is VaultPanel or s.panel is TrainingGroundsPanel),
					"%s opens a note" % id)
		check((s.places[id] as VillagePlace).highlight, "%s is highlighted while its panel is open" % id)
		s.close_panel()
		check(s.panel == null, "Close closes it")
		check(not (s.places[id] as VillagePlace).highlight or s.hovered == id, "the highlight goes with the panel")
	# a tap on empty ground opens nothing; a drag never taps
	s.set_cam(Village.cam_for(640, s.view_w()))
	_click(s, Vector2(s.view_w() / 2.0 - 100, 345))
	eq(s.panel_kind(), "", "a tap on the road opens nothing")
	var at := s.to_screen((s.places["lantern"] as VillagePlace).world_zone().get_center())
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	s._gui_input(down)
	var mv := InputEventMouseMotion.new()
	mv.position = at + Vector2(40, 0)
	s._gui_input(mv)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	up.position = mv.position
	s._gui_input(up)
	eq(s.panel_kind(), "", "dragging across the lantern does not open it")
	# a tap outside a panel closes it
	_tap_place(s, "lantern")
	var out := InputEventMouseButton.new()
	out.button_index = MOUSE_BUTTON_LEFT
	out.pressed = true
	out.position = Vector2(4, 350)
	s._shade.gui_input.emit(out)
	eq(s.panel_kind(), "", "a tap outside the panel closes it")
	_free(s)
	_done()


func test_lantern_menu_keeps_the_banner_hall_working() -> void:
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	GameState.meta["glimmers"] = GameState.GLIMMERS_PER_SHARD + GameState.CREST_COST
	var s := _screen()
	s.open_place("lantern")
	var p := s.panel as LanternPanel
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
	var z := (s.places["grounds"] as VillagePlace).world_zone()
	check(z.position.x < s.cam + s.view_w() and z.end.x > s.cam, "the camera starts with the new building in view")
	_tap_place(s, "grounds")
	check(s.panel is TrainingGroundsPanel, "the yard opens the Training Grounds")
	check(Village.unseen(GameState.meta).is_empty(), "looking at it clears NEW")
	GameState.load_all()
	check(Village.unseen(GameState.meta).is_empty(), "and that is saved")
	_free(s)
	_done()


func test_scrolling_stays_inside_the_world() -> void:
	var W := Village.world_size().x
	eq(Village.clamp_cam(-300, 640), 0.0, "no further left than the world's edge")
	eq(Village.clamp_cam(99999, 640), W - 640, "no further right (16:9)")
	eq(Village.clamp_cam(99999, 780), W - 780, "no further right (19.5:9)")
	check(W > 780, "the village is wider than a 19.5:9 phone screen")
	eq(Village.cam_for(0, 640), 0.0, "centring on the west edge clamps")
	_fresh()
	GameState.set_identity("The Wayfarers", "lantern")
	var s := _screen()
	var vw := s.view_w()
	s.set_cam(-1000)
	eq(s.cam, 0.0, "set_cam clamps at the west edge")
	eq(s.world.position.x, 0.0, "the world sits at the screen's left")
	s.set_cam(1e9)
	eq(s.cam, W - vw, "set_cam clamps at the east edge")
	eq(s.world.position.x, -(W - vw), "the world's east edge meets the screen's")
	# a drag far to the right pulls the camera to the west edge and stops there
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(100, 200)
	s._gui_input(down)
	for k in range(1, 30):
		var mv := InputEventMouseMotion.new()
		mv.position = Vector2(100 + k * 80, 200)
		s._gui_input(mv)
	eq(s.cam, 0.0, "a long drag stops at the west edge")
	check(float(int(s.world.position.x)) == s.world.position.x, "the world sits on whole pixels")
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	s._gui_input(up)
	# the wheel scrolls and clamps too
	for k in 100:
		var wh := InputEventMouseButton.new()
		wh.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wh.pressed = true
		wh.factor = 1.0
		s._gui_input(wh)
	eq(s.cam, W - vw, "the wheel stops at the east edge")
	# the edge arrow pages back west
	s.tap(s._arrow_rect(-1).get_center())
	check(s.panel == null, "the arrow is not a place")
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
