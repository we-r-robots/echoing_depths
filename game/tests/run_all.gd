extends SceneTree
## Headless test runner: godot --path game --headless -s res://tests/run_all.gd
## Runs every test_* method of every res://tests/test_*.gd file (except test_case.gd).
## Exits 1 on any failed assertion or any engine/script error logged during the run.

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


func _init() -> void:
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var files: Array[String] = []
	var dir := DirAccess.open("res://tests")
	for f in dir.get_files():
		var name := f.trim_suffix(".remap")
		if name.begins_with("test_") and name.ends_with(".gd") and name != "test_case.gd":
			files.append(name)
	files.sort()
	var total := 0
	var failed := 0
	var asserts := 0
	var t0 := Time.get_ticks_msec()
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
	OS.remove_logger(counter)
	print("\n%d tests, %d assertions, %d failed, %d engine errors (%d ms)" % [total, asserts, failed,
		counter.errors.size(), Time.get_ticks_msec() - t0])
	for e in counter.errors:
		print("  error: ", e)
	quit(1 if failed > 0 or not counter.errors.is_empty() else 0)
