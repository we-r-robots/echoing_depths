extends SceneTree
## Headless test runner: godot --path game --headless -s res://tests/run_all.gd
## Runs every test_* method of every res://tests/test_*.gd file (except test_case.gd), then the
## scene smoke phase: every .tscn under res://scenes/ is instantiated, added to the tree and run
## for SCENE_FRAMES frames (its demo mode plays, so its _draw paths run), then its Controls are
## checked against the UI text floor (UIText.size_ok). A scene that fails to load, logs a script or
## engine error, or shows text below the floor fails.
## Exits 1 on any failed assertion or any engine/script error logged during the run.

const SCENE_FRAMES := 45

class ErrorCounter extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var counter := ErrorCounter.new()
var total := 0
var failed := 0
var asserts := 0
var t0 := 0
var _scenes: Array[String] = []
var _scene_i := -1
var _scene_node: Node = null
var _scene_frames := 0
var _scene_errs := 0


func _init() -> void:
	OS.add_logger(counter)
	var files: Array[String] = []
	var dir := DirAccess.open("res://tests")
	for f in dir.get_files():
		var name := f.trim_suffix(".remap")
		if name.begins_with("test_") and name.ends_with(".gd") and name != "test_case.gd":
			files.append(name)
	files.sort()
	t0 = Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("  FAIL  %s: could not load" % f)
			continue
		var methods: Array[String] = []
		for m: Dictionary in script.get_script_method_list():
			var mn := String(m["name"])
			if mn.begins_with("test_") and not methods.has(mn):
				methods.append(mn)
		for mn in methods:
			var obj: RefCounted = script.new()
			obj.set("current", "%s::%s" % [f.trim_suffix(".gd"), mn])
			var errs_before := counter.errors.size()
			obj.call(mn)
			total += 1
			var fails: Array = obj.get("failures")
			asserts += int(obj.get("asserts"))
			if counter.errors.size() > errs_before:
				fails.append("%s: engine/script error during test" % obj.get("current"))
			if int(obj.get("asserts")) == 0:
				fails.append("%s: made no assertions" % obj.get("current"))
			if fails.is_empty():
				print("  ok    ", obj.get("current"))
			else:
				failed += 1
				for msg: String in fails:
					print("  FAIL  ", msg)
	_scenes = _find_scenes("res://scenes")
	_scenes.sort()


static func _find_scenes(path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(path)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_find_scenes(path.path_join(sub)))
	for f in d.get_files():
		if f.ends_with(".tscn") or f.ends_with(".tscn.remap"):
			out.append(path.path_join(f.trim_suffix(".remap")))
	return out


## Scene smoke phase, one scene at a time across frames.
func _process(_delta: float) -> bool:
	if _scene_node != null:
		_scene_frames += 1
		if _scene_frames < SCENE_FRAMES:
			return false
		_finish_scene()
		return false
	_scene_i += 1
	if _scene_i >= _scenes.size():
		_summary()
		return true
	var path := _scenes[_scene_i]
	_scene_errs = counter.errors.size()
	var ps: PackedScene = load(path)
	var inst: Node = ps.instantiate() if ps != null else null
	if inst == null:
		total += 1
		failed += 1
		print("  FAIL  scene::%s: could not load or instantiate" % path)
		return false
	_scene_node = inst
	_scene_frames = 0
	root.add_child(inst)
	return false


func _finish_scene() -> void:
	var path := _scenes[_scene_i]
	var fails: Array[String] = []
	asserts += 1
	_check_controls(_scene_node, fails)
	_scene_node.queue_free()
	_scene_node = null
	Tip.close()
	if counter.errors.size() > _scene_errs:
		fails.append("engine/script error while running")
	total += 1
	if fails.is_empty():
		print("  ok    scene::", path)
	else:
		failed += 1
		for m in fails:
			print("  FAIL  scene::%s: %s" % [path, m])


## Every visible text Control uses a UI font at a size on the grid and above the floor.
func _check_controls(n: Node, fails: Array[String]) -> void:
	if n is Label or n is Button or n is RichTextLabel or n is LineEdit:
		var c := n as Control
		var has_text: bool = (c is Label and (c as Label).text != "") or (c is Button and (c as Button).text != "") \
			or (c is RichTextLabel and (c as RichTextLabel).text != "") or c is LineEdit
		if has_text and c.is_visible_in_tree():
			var key := "normal_font" if c is RichTextLabel else "font"
			var skey := "normal_font_size" if c is RichTextLabel else "font_size"
			var f := c.get_theme_font(key)
			var sz := c.get_theme_font_size(skey)
			if c is Label and (c as Label).label_settings != null:
				var ls := (c as Label).label_settings
				if ls.font != null:
					f = ls.font
				sz = ls.font_size
			asserts += 1
			if not (f == UIText.SANS or f == UIText.BOLD or f == UIText.SERIF):
				fails.append("%s uses a font outside the UI set" % c.get_path())
			elif not UIText.size_ok(f, sz):
				fails.append("%s: font size %d is off the grid or below the x-height floor" % [c.get_path(), sz])
	for ch in n.get_children():
		_check_controls(ch, fails)


func _summary() -> void:
	OS.remove_logger(counter)
	print("\n%d tests, %d assertions, %d failed, %d engine errors (%d ms)" % [total, asserts, failed,
		counter.errors.size(), Time.get_ticks_msec() - t0])
	for e in counter.errors:
		print("  error: ", e)
	quit(1 if failed > 0 or not counter.errors.is_empty() else 0)
