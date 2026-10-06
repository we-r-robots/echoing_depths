extends Node
## Unattended capture harness used by tools/capture.sh and critic agents. Saves the full window at
## the capture resolution (UI at native resolution, world at 640x360 x3).
## Args after `--`:
##   --scene=res://path.tscn   scene to load instead of main
##   --shots=out_dir           directory to write PNG screenshots
##   --at=60,120,240           frame numbers to capture at (physics-independent, uses process frames)
##   --seed=N                  global RNG seed for deterministic runs
##   --quit                    quit after the last capture

var _shots_dir := ""
var _at: Array[int] = []
var _frame := 0
var _quit := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if args.has("seed"):
		seed(int(args["seed"]))
	if args.has("shots"):
		# a real pointer over the capture window must not steer the unattended demo (critic r6:
		# the 1080 and phone shots of one named state showed different states)
		get_tree().root.disable_input = true
		_shots_dir = args["shots"]
		DirAccess.make_dir_recursive_absolute(_shots_dir)
	if args.has("at"):
		for s in String(args["at"]).split(","):
			_at.append(int(s))
	_quit = args.has("quit")
	if args.has("scene"):
		get_tree().change_scene_to_file.call_deferred(args["scene"])

func _process(_delta: float) -> void:
	if _at.is_empty():
		return
	_frame += 1
	if _frame in _at:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/f%05d.png" % [_shots_dir, _frame])
		if _frame >= _at.max() and _quit:
			get_tree().quit()
