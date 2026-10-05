extends SceneTree
## Live flow check: runs the real main scene (title and every run screen, battles included) and
## presses through it like a player, frame by frame, until a run ends and Lanternrest opens.
## Battles are skipped with the HUD's skip after a moment. Uses a scratch user:// folder.
##   godot --path game --headless -s res://tests/flow_live.gd [-- --seed=N --max_frames=N]
## Prints each screen as it opens; exits 1 on an engine error or if it never reaches Lanternrest.

class ErrorCounter extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
	func _log_message(_m: String, _e: bool) -> void:
		pass

var counter := ErrorCounter.new()
var flow: Flow
var frame := 0
var max_frames := 40000
var seed_value := 5
var _kind := ""
var _at := 0
var _done := false


func _init() -> void:
	OS.add_logger(counter)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		elif a.begins_with("--max_frames="):
			max_frames = int(a.substr(13))
	GameState.use_paths("user://flow_live")
	for f in ["meta.json", "run_save.json", "echo_pool.json", "settings.json"]:
		var p: String = "user://flow_live/" + f
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	GameState.load_all()
	flow = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	flow.screen_opened.connect(func(k: String) -> void:
		_kind = k
		_at = frame
		print("  frame %d: %s" % [frame, k]))
	root.add_child(flow)


func _process(_d: float) -> bool:
	frame += 1
	if frame > max_frames or _done:
		return _finish()
	var wait := frame - _at
	if wait < 20:
		return false
	var s: Node = flow.screen
	match _kind:
		"title":
			if visited_count("title") > 1:
				_done = true
			elif s is TitleScreen:
				(s as TitleScreen).new_run.emit()
		"draft":
			if s is DraftScreen and wait == 20:
				(s as DraftScreen).toggle(0)
				(s as DraftScreen).toggle(1)
				(s as DraftScreen).commit()
		"encounter":
			if s is RunEncounter:
				if wait == 20:
					(s as RunEncounter).choose(0)
				elif wait == 60:
					(s as RunEncounter)._on_continue()
		"decision":
			if s is RoadScreen and wait == 20:
				(s as RoadScreen).decided.emit(0)
		"formation":
			if s is FormationSetup and wait == 20:
				(s as FormationSetup).confirm()
		"splash":
			if s is VersusSplash and wait == 20:
				(s as VersusSplash).finish()
		"battle":
			if wait == 120 and s != null:
				s.call("skip")
		"road":
			if s is RoadScreen and wait == 20:
				(s as RoadScreen).proceed.emit()
		"results":
			if s is ResultsScreen and wait == 20:
				(s as ResultsScreen).proceed.emit()
		"lanternrest":
			if s is LanternrestScreen and wait == 20:
				(s as LanternrestScreen).to_title.emit()
	return false


func visited_count(k: String) -> int:
	return flow.visited.count(k)


func _finish() -> bool:
	var ok := flow.visited.has("lanternrest") and counter.errors.is_empty()
	print("visited %d screens; lanternrest %s; %d engine errors; meta runs %d" % [flow.visited.size(),
		flow.visited.has("lanternrest"), counter.errors.size(), int(GameState.meta.get("runs", 0))])
	for e in counter.errors.slice(0, 20):
		print("  error: ", e)
	OS.remove_logger(counter)
	GameState.use_paths("user://")
	quit(0 if ok else 1)
	return true
