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


## The test methods run on the first frame, so tests that play a real scene (test_label_layout)
## find the tree ready.
func _run_tests() -> void:
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
var _tests_done := false
func _process(_delta: float) -> bool:
	if not _tests_done:
		_tests_done = true
		_run_tests()
		return false
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
			else:
				var over := _overflow(c, f, sz)
				if over != "":
					fails.append("%s: %s" % [c.get_path(), over])
	for ch in n.get_children():
		_check_controls(ch, fails)


## Text that doesn't fit its Control (hires-ui round 5): a one-line Label or a Button whose text
## is wider than its box (so it is clipped, cut with an ellipsis or spills out), or text that
## runs off the screen. Returns "" when it fits.
func _overflow(c: Control, f: Font, sz: int) -> String:
	var text := ""
	var room := c.size.x
	var lead := 0.0
	if c is Label:
		var l := c as Label
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.visible_characters >= 0 or l.visible_ratio < 1.0:
			return ""
		text = l.text
		if l.uppercase:
			text = text.to_upper()
		var sb := l.get_theme_stylebox("normal")
		if sb != null:
			room -= sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
			lead = sb.get_margin(SIDE_LEFT)
	elif c is Button:
		var b := c as Button
		if b.icon != null or b.clip_text == false and b.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and b.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return ""
		text = b.text
		var sb := b.get_theme_stylebox("normal")
		if sb != null:
			room -= sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	else:
		return ""
	var w := 0.0
	for line in text.split("\n"):
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
	if w > room + 0.5:
		return "text \"%s\" is %d px wide in a %d px box" % [text.replace("\n", " / "), w, room]
	# on screen: the text's own span (aligned in its box) stays inside the visible design rect
	if c is Label:
		var l := c as Label
		var x0 := lead
		match l.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				x0 = lead + (room - w) / 2.0
			HORIZONTAL_ALIGNMENT_RIGHT:
				x0 = lead + room - w
		var xf := c.get_global_transform_with_canvas()
		var a := xf * Vector2(x0, 0)
		var b2 := xf * Vector2(x0 + w, 0)
		var vis := c.get_viewport().get_visible_rect()
		if a.x < vis.position.x - 0.5 or b2.x > vis.end.x + 0.5:
			return "text \"%s\" runs off the screen (x %d..%d of %d..%d)" % [text, a.x, b2.x, vis.position.x, vis.end.x]
		# inside the button or panel it sits on
		var box: Node = c.get_parent()
		while box != null and not (box is Button or box is Panel or box is PanelContainer):
			box = box.get_parent()
		if box is Control:
			var bx := box as Control
			var bxf := bx.get_global_transform_with_canvas()
			var bl := (bxf * Vector2.ZERO).x
			var br := (bxf * Vector2(bx.size.x, 0)).x
			if a.x < bl - 0.5 or b2.x > br + 0.5:
				return "text \"%s\" spills out of %s (x %d..%d of %d..%d)" % [text, bx.name, a.x, b2.x, bl, br]
	return ""


func _summary() -> void:
	OS.remove_logger(counter)
	print("\n%d tests, %d assertions, %d failed, %d engine errors (%d ms)" % [total, asserts, failed,
		counter.errors.size(), Time.get_ticks_msec() - t0])
	for e in counter.errors:
		print("  error: ", e)
	quit(1 if failed > 0 or not counter.errors.is_empty() else 0)
