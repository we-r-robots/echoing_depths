extends "res://tests/test_case.gd"
## The playable flow (scenes/flow/): a bot plays whole runs through the flow controller, from the
## title through every run screen to results and Lanternrest; meta progress, settings and the run
## save land in user:// files (a test folder, never the player's).

const DIR := "user://test_flow"


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


## Plays from the title to the next title. Returns the flow.
func _play(seed_value: int) -> Flow:
	var flow: Flow = Flow.new()
	flow.bot = true
	flow.show_title()
	flow.pending = {}
	flow.start_new_run(seed_value)
	var n := 0
	while flow.bot_step("title") and n < 2000:
		n += 1
	return flow


func test_bot_plays_title_to_lanternrest_and_meta_is_saved() -> void:
	_fresh()
	var flow: Flow = Flow.new()
	flow.bot = true
	flow.show_title()
	check(flow.bot_step(), "title answered (New run)")
	var n := 0
	while flow.bot_step("title") and n < 2000:
		n += 1
	var seen := flow.visited
	for k in ["title", "draft", "encounter", "formation", "battle", "splash", "road", "results", "lanternrest"]:
		check(seen.has(k), "the flow opened the %s screen" % k)
	eq(String(flow.pending.get("kind", "")), "title", "after Lanternrest the flow is back at the title")
	check(bool(flow.run.call("is_over")), "the run ended")
	var s: Dictionary = flow.run.call("summary")
	# meta on disk
	var meta := GameState._read(GameState.meta_path)
	eq(int(meta.get("runs", 0)), 1, "one run banked in meta.json")
	eq(int(meta.get("glimmers_total", -1)), int(s["glimmers"]), "the run's Glimmers banked")
	eq(int(meta.get("shards_total", -1)), int(s["shards"]), "the run's Shards banked")
	eq(int(meta.get("best_floor", 0)), int(s["floor"]), "deepest floor recorded")
	eq(String(meta.get("last_run", {}).get("outcome", "")), String(s["outcome"]), "last run outcome recorded")
	check(int(s["glimmers"]) > 0, "a run always brings Glimmers home")
	check(not GameState.has_saved_run(), "the finished run's save is cleared")
	# the run's Echo carries the team's name and crest
	var pool := GameState._read(GameState.pool_path)
	var mine: Array = (pool.get("echoes", []) as Array).filter(func(e: Dictionary) -> bool:
		return not bool(e.get("meta", {}).get("generated", true)))
	check(not mine.is_empty(), "the run recorded its Echo in the pool")
	if not mine.is_empty():
		eq(String(mine[0]["meta"]["team_name"]), GameState.DEFAULT_TEAM, "the Echo carries the team name")
		eq(String(mine[0]["meta"]["crest"]), Crests.DEFAULT_CREST, "the Echo carries the crest")
	# the bank happens once even if results are shown again
	flow._finish_run()
	eq(int(GameState._read(GameState.meta_path).get("runs", 0)), 1, "results never bank a run twice")
	flow.free()
	_done()


func test_lanternrest_unlocks_shapes_and_crests() -> void:
	_fresh()
	var m := GameState.meta
	check(not GameState.is_shape_unlocked("keystone"), "Keystone starts locked")
	check(GameState.shape_available("keystone"), "Keystone grows from Kindred, which is known")
	check(not GameState.shape_available("crescent"), "Crescent needs Keystone first")
	check(not GameState.unlock_shape("keystone"), "no Shards: nothing learned")
	m["glimmers"] = GameState.GLIMMERS_PER_SHARD + GameState.CREST_COST
	check(GameState.form_shard(), "Glimmers form a Shard")
	eq(int(m["shards"]), 1, "one Shard")
	check(GameState.unlock_shape("keystone"), "Keystone learned for 1 Shard")
	check(GameState.shape_available("crescent"), "Crescent now available")
	check(not GameState.unlock_crest("lantern"), "an owned crest can't be bought again")
	check(GameState.unlock_crest("star"), "Star crest remembered for Glimmers")
	GameState.set_team("  The Night Lamps  ", "star")
	GameState.load_all()   # from disk
	check(GameState.is_shape_unlocked("keystone"), "unlock saved")
	check(GameState.has_crest("star"), "crest saved")
	eq(GameState.crest(), "star", "chosen crest saved")
	eq(GameState.team_name(), "The Night Lamps", "team name saved, trimmed")
	var o := GameState.run_options()
	check((o["unlocked_formations"] as Array).has("keystone"), "the next run fights with Keystone unlocked")
	eq(String(o["crest"]), "star", "the next run's Echo carries the crest")
	eq(String(o["party_name"]), "The Night Lamps", "the next run carries the team name")
	GameState.set_team("", "nope")
	eq(GameState.team_name(), GameState.DEFAULT_TEAM, "an empty name falls back to the default")
	eq(GameState.crest(), "star", "an unknown crest is ignored")
	_done()


func test_settings_battle_effects_saved() -> void:
	_fresh()
	eq(GameState.battle_effects(), 2, "Battle Effects default High (2)")
	GameState.set_battle_effects(0)
	GameState.load_all()
	eq(GameState.battle_effects(), 0, "Low saved to settings.json")
	GameState.set_battle_effects(7)
	eq(GameState.battle_effects(), 2, "clamped to High")
	_done()


func test_saved_run_continues_where_it_stopped() -> void:
	_fresh()
	var flow: Flow = Flow.new()
	flow.bot = true
	flow.start_new_run(4242)
	for i in 40:
		flow.bot_step("results")
	var before: Dictionary = flow.run.call("current_node")
	check(GameState.has_saved_run(), "a run in progress is saved")
	var flow2: Flow = Flow.new()
	flow2.bot = true
	flow2.continue_run()
	var after: Dictionary = flow2.run.call("current_node")
	eq(after["step"], before["step"], "continued at the same step")
	eq(after["depth"], before["depth"], "continued at the same depth")
	eq(after["health"], before["health"], "same health")
	eq(var_to_str(after["party"]), var_to_str(before["party"]), "same party")
	flow.free()
	flow2.free()
	_done()


func test_second_run_uses_lanternrest_unlocks() -> void:
	_fresh()
	GameState.meta["shards"] = 2
	check(GameState.unlock_shape("keystone"), "learned Keystone")
	var flow := _play(77)
	var meta := GameState._read(GameState.meta_path)
	eq(int(meta.get("runs", 0)), 1, "run banked")
	check((flow.options["unlocked_formations"] as Array).has("keystone"), "the run started with Keystone unlocked")
	flow.free()
	_done()


func test_crests_draw_for_any_team() -> void:
	for id: String in Crests.ORDER:
		check(Crests.exists(id), "%s exists" % id)
		eq((Crests.CRESTS[id]["sym"] as Array).size(), 7, "%s symbol is 7 rows" % id)
	check(Crests.exists(Crests.for_team("", "The Ashen Vow")), "a crestless Echo still gets a crest")
	eq(Crests.for_team("", "The Ashen Vow"), Crests.for_team("", "The Ashen Vow"), "stable per name")
	eq(Crests.for_team("moon", "x"), "moon", "an Echo's own crest wins")


## Lanternrest's Training Grounds tiles (hires-ui round 5): every shape name fits its tile with
## at least TILE_PAD design px to the tile's edges, and every shape icon sits inside its tile
## (centred vertically, clear of the name and the edges).
func test_lanternrest_tile_labels_and_icons_fit() -> void:
	var GameData = preload("res://core/game_data.gd")
	var T := LanternrestScreen.TILE
	var text_w := T.x - LanternrestScreen.TILE_TEXT_X - LanternrestScreen.TILE_PAD
	check(LanternrestScreen.TILE_COLS * T.x + (LanternrestScreen.TILE_COLS - 1) * 4 <= LanternrestScreen.GROUNDS_W,
		"the tile grid fits the Training Grounds width")
	for s: Dictionary in GameData.Formations.SHAPES:
		var nm := String(s["name"])
		var w := UIText.BOLD.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, UIText.LABEL).x
		check(w <= text_w, "'%s' (%d px) fits its tile's %d px with %d px padding" % [nm, w, text_w, LanternrestScreen.TILE_PAD])
		var r := LanternrestScreen.shape_icon_rect(s)
		check(r.position.x >= 4 and r.position.y >= 4 and r.end.y <= T.y - 4,
			"%s icon %s sits inside its %s tile with 4 px to spare" % [nm, r, T])
		check(r.end.x + 4 <= LanternrestScreen.TILE_TEXT_X, "%s icon clears the name" % nm)
		check(absf(r.position.y - (T.y - r.end.y)) <= 1.0, "%s icon is centred vertically" % nm)
