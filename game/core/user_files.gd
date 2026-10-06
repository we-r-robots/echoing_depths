extends RefCounted
## The player's files and the guard that keeps everything else away from them.
##
## The real game keeps four files in user://: echo_pool.json, meta.json, run_save.json and
## settings.json. Only the real game may write them. Tests (`-s` scripts), captures and demos
## (`-- --scene=` / `--shots=`), simulations and tools get a sandbox folder instead
## (user://sandbox/), and any attempt to write a player file from them is refused with an error
## (which also fails tests/run_all.gd's "0 engine errors").
##   UserFiles.path("meta.json")   # user://meta.json in the game, user://sandbox/meta.json elsewhere
##   UserFiles.may_write(p)        # false for a player file outside the real game
## ED_SANDBOX=1 in the environment forces the sandbox (runner scripts that start the main scene).

const PLAYER_DIR := "user://"
const SANDBOX_DIR := "user://sandbox/"
const PLAYER_FILES := ["echo_pool.json", "meta.json", "run_save.json", "settings.json"]

static var _real := -1   # -1 unknown, 0 sandboxed, 1 the real game


## True only for the game itself: no `-s` script, no capture/demo scene, no ED_SANDBOX.
static func is_real_game() -> bool:
	if _real < 0:
		_real = 1
		var args := OS.get_cmdline_args()
		if args.has("-s") or args.has("--script") or OS.get_environment("ED_SANDBOX") != "":
			_real = 0
		for a in args:
			if a.ends_with(".gd") and not a.begins_with("--"):
				_real = 0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shots") or a.begins_with("--scene"):
				_real = 0
	return _real == 1


## Folder for the player's files in this process.
static func dir() -> String:
	return PLAYER_DIR if is_real_game() else SANDBOX_DIR


static func path(file_name: String) -> String:
	return dir().path_join(file_name)


## True when `p` names one of the real player files (user://<file>).
static func is_player_file(p: String) -> bool:
	var s := p.simplify_path()
	for f: String in PLAYER_FILES:
		if s == PLAYER_DIR + f or s == "user:///" + f \
				or s == ProjectSettings.globalize_path(PLAYER_DIR + f).simplify_path():
			return true
	return false


## Guard for every write: the player's files only from the real game. Logs an error on refusal.
static func may_write(p: String) -> bool:
	if is_player_file(p) and not is_real_game():
		push_error("refused to write the player's file %s outside the real game (use a test path)" % p)
		return false
	return true
