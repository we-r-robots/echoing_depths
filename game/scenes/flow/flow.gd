class_name Flow
extends Control
## The playable flow: title -> Lanternrest (the village hub; the game starts there) -> the Vault
## entrance starts a new run (or continues the saved one) -> draft -> the run's nodes (encounters, advancement
## decisions, formation setup, the PvP splash, battles, floor guardians, the Crystal) -> results
## -> back to Lanternrest. Settings from the title.
##
## The run itself is core's (core/run/run.gd); each screen is its own scene and this controller
## only routes between them, records the player's actions (a run is deterministic from its seed,
## options and actions, so the save is that list: GameState.save_run) and banks the finished run
## into meta (GameState.apply_summary).
##
## Every screen opens through _open(kind, data). With `bot` set, _open opens nothing: the screen
## is queued in `pending` and bot_step() answers it the way the screen would (tests play a whole
## run through this controller without rendering or waiting on battles).

signal screen_opened(kind: String)

const Run = preload("res://core/run/run.gd")
const Rng = preload("res://core/rng.gd")
const BATTLE := preload("res://scenes/battle/battle.tscn")

var run: RefCounted = null
var seed_value := 0
var options: Dictionary = {}
var actions: Array = []
var screen: Node = null
var bot := false
var pending: Dictionary = {}           # bot mode: the screen waiting for an answer
var visited: Array[String] = []        # screen kinds opened, in order
var _banked := false
var _bot_rng: Rng = null
var _overlay: Node = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameState.ensure()
	if not bot:
		show_title()


# ======================================================================= navigation

func show_title() -> void:
	_open("title", {})


func show_settings() -> void:
	_open("settings", {})


func show_lanternrest() -> void:
	_open("lanternrest", {})


## Starts a new run (seed < 0: a fresh random seed). Any saved run is replaced.
func start_new_run(seed_in := -1) -> void:
	seed_value = seed_in if seed_in >= 0 else int(Time.get_unix_time_from_system()) ^ (randi() & 0xffffff)
	options = GameState.run_options()
	run = Run.new()
	run.call("start_run", seed_value, options)
	actions = []
	_banked = false
	_save()
	_next()


## Continues the saved run (replays its actions). Falls back to the title if none.
func continue_run() -> void:
	var d := GameState.load_run()
	if d.is_empty():
		show_title()
		return
	run = d["run"]
	seed_value = int(d["seed"])
	options = d["options"]
	actions = d["actions"]
	_banked = false
	_next()


## Shows whatever the run is waiting for.
func _next() -> void:
	var v: Dictionary = run.call("current_node")
	match String(v["step"]):
		"draft":
			_open("draft", v)
		"choice":
			_open("encounter", v)
		"decision":
			_open("decision", v)
		"fight":
			_open("formation", v)
		"outcome":
			var last: Dictionary = v.get("last", {})
			if String(last.get("type", "")) == "fight":
				_open("road", v)
			else:
				_advance()   # the encounter screen already showed this node's outcome
		"ended":
			_finish_run()


func _advance() -> void:
	_act(["advance"])
	_next()


func _finish_run() -> void:
	var s: Dictionary = run.call("summary")
	var rewards := {}
	if not _banked:
		_banked = true
		rewards = GameState.apply_summary(s)
		GameState.clear_saved_run()
	_open("results", {"summary": s, "rewards": rewards})


# ======================================================================= handlers (screens call these)

func on_title(action: String) -> void:
	match action:
		"lanternrest":
			show_lanternrest()
		"settings":
			show_settings()
		"quit":
			get_tree().quit()


## The draft screen applied its picks (run.choose, in pick order).
func on_drafted(picks: Array) -> void:
	for i in picks:
		_record(["choose", int(i)])
	_next()


## The encounter screen applied choice i (run.choose).
func on_encounter_chosen(i: int) -> void:
	_record(["choose", i])


func on_encounter_done() -> void:
	_next()


func on_decided(i: int) -> void:
	_act(["choose", i])
	_next()


## Formation confirmed before a fight (the setup screen applied run.set_formation): resolve the
## fight now (its result is final, so quitting mid-battle can't undo it), then the splash and the
## battle.
func on_formation(res: Dictionary, review := false) -> void:
	if res.has("slots"):
		_record(["formation", res["slots"]])
	if review:
		return
	var result: Dictionary = _act(["fight"])
	var info: Dictionary = result.get("run", {})
	var kind := String(info.get("kind", ""))
	if kind == "pvp" or kind == "guardian" or kind == "crystal":
		_open("splash", {"result": result, "data": _splash_data(kind, result)})
	else:
		_open("battle", {"result": result})


func on_splash_done(result: Dictionary) -> void:
	_open("battle", {"result": result})


func on_battle_done() -> void:
	var v: Dictionary = run.call("current_node")
	if String(v["step"]) == "outcome":
		_open("road", v)
	else:
		_next()


func on_road(action: String) -> void:
	match action:
		"continue":
			_advance()
		"formation":
			_open_overlay_formation()


func on_results_done() -> void:
	show_lanternrest()


## The village: the Vault entrance starts a run ("new") or continues the saved one ("continue").
func on_lanternrest(action: String) -> void:
	match action:
		"new":
			start_new_run()
		"continue":
			continue_run()
		_:
			show_title()


# ======================================================================= helpers

func _act(a: Array) -> Dictionary:
	var res := GameState.replay(run, a)
	if not res.has("error"):
		_record(a)
	else:
		push_warning("flow: %s -> %s" % [str(a), res["error"]])
	return res


func _record(a: Array) -> void:
	actions.append(a)
	_save()


func _save() -> void:
	if run != null and not bool(run.call("is_over")):
		GameState.save_run(seed_value, options, actions)


## Who meets whom on the splash: the player's team (name, crest, heroes) and the rival Echo, the
## floor guardian or the Crystal.
func _splash_data(kind: String, result: Dictionary) -> Dictionary:
	var you := {"name": GameState.team_name(), "crest": GameState.crest(), "heroes": run.call("party_view")}
	var opp: Dictionary = result.get("opponent", {})
	var meta: Dictionary = opp.get("meta", {})
	var them := {"name": String(meta.get("team_name", opp.get("name", ""))), "crest": String(meta.get("crest", ""))}
	match kind:
		"pvp":
			them["title"] = "Echo recorded on floor %d" % int(meta.get("floor", run.call("current_node")["floor"]))
			them["heroes"] = opp.get("heroes", [])
		"guardian":
			them["name"] = String(opp.get("name", them["name"]))
			them["title"] = String(meta.get("title", "Floor guardian"))
			them["intro"] = String(meta.get("intro", ""))
		"crystal":
			them["name"] = String(opp.get("name", "The Crystal of Remembrance"))
			them["title"] = "The final chamber"
			them["intro"] = String(meta.get("intro", ""))
	return {"mode": kind, "you": you, "them": them}


## Opens a screen (or, in bot mode, queues it for bot_step).
func _open(kind: String, data: Dictionary) -> void:
	visited.append(kind)
	screen_opened.emit(kind)
	if bot:
		pending = {"kind": kind, "data": data}
		return
	_clear()
	match kind:
		"title":
			var s := TitleScreen.open(self)
			s.lanternrest.connect(on_title.bind("lanternrest"))
			s.settings.connect(on_title.bind("settings"))
			s.quit.connect(on_title.bind("quit"))
			screen = s
		"settings":
			var s := SettingsScreen.open(self)
			s.closed.connect(show_title)
			screen = s
		"lanternrest":
			var s := LanternrestScreen.open(self)
			s.new_run.connect(on_lanternrest.bind("new"))
			s.continue_run.connect(on_lanternrest.bind("continue"))
			s.to_title.connect(on_lanternrest.bind("title"))
			screen = s
		"draft":
			var s := DraftScreen.open(self, run)
			s.drafted.connect(func(_party: Array) -> void:
				screen = null
				on_drafted(s.picks.duplicate()))
			screen = s
		"encounter":
			var s := RunEncounter.open(self, run)
			s.chosen.connect(func(i: int, _res: Dictionary) -> void: on_encounter_chosen(i))
			s.finished.connect(func() -> void:
				screen = null
				on_encounter_done())
			screen = s
		"decision":
			var s := RoadScreen.open(self, data)
			s.decided.connect(on_decided)
			screen = s
		"road":
			var s := RoadScreen.open(self, data)
			s.proceed.connect(on_road.bind("continue"))
			s.arrange.connect(on_road.bind("formation"))
			screen = s
		"formation":
			var s := FormationSetup.open(self, run)
			s.confirmed.connect(func(res: Dictionary) -> void:
				screen = null
				on_formation(res))
			screen = s
		"splash":
			var s := VersusSplash.open(self, data["data"])
			s.done.connect(func() -> void:
				screen = null
				on_splash_done(data["result"]))
			screen = s
		"battle":
			var result: Dictionary = data["result"]
			var b: Node = BATTLE.instantiate()
			b.set("autoplay_demo", false)
			b.set("spectacle_level", GameState.battle_effects())
			add_child(b)
			var pvp := String(result.get("run", {}).get("kind", "")) == "pvp"
			b.call("play_result", result, {"echo_side": 1 if pvp else -1})
			b.connect("finished", func(_w: int, _r: Dictionary) -> void:
				b.queue_free()
				screen = null
				on_battle_done())
			screen = b
		"results":
			var s := ResultsScreen.open(self, data["summary"], data["rewards"])
			s.proceed.connect(on_results_done)
			screen = s


## Formation review from the road (no fight follows): on top of the road screen.
func _open_overlay_formation() -> void:
	visited.append("formation_review")
	if bot:
		return
	var s := FormationSetup.open(self, run, {"mode": "review"})
	s.confirmed.connect(func(res: Dictionary) -> void: on_formation(res, true))
	_overlay = s


func _clear() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	Tip.close()


# ======================================================================= bot (tests)

## Answers the pending screen the way a player would. Returns false when there is nothing to do
## (or the bot reached `stop_at`).
func bot_step(stop_at := "") -> bool:
	if pending.is_empty():
		return false
	var p := pending
	var kind := String(p["kind"])
	if kind == stop_at:
		return false
	pending = {}
	if _bot_rng == null:
		_bot_rng = Rng.new(seed_value + 99)
	var d: Dictionary = p["data"]
	match kind:
		"title":
			on_title("lanternrest")
		"settings":
			show_title()
		"draft":
			var picks: Array = []
			for o: Dictionary in d["offered"]:
				if picks.size() < int(d["picks_left"]):
					picks.append(int(o["index"]))
			for i in picks:
				run.call("choose", int(i))
			on_drafted(picks)
		"encounter":
			var cs: Array = d["choices"]
			var pick := int(cs[_bot_rng.int_range(0, cs.size() - 1)]["index"])
			for c: Dictionary in cs:
				if c.has("recruit") or c.has("legend") or (c.has("rest") and int(d["health"]) <= int(d["max_health"]) - 3):
					pick = int(c["index"])
					break
			run.call("choose", pick)
			on_encounter_chosen(pick)
			on_encounter_done()
		"decision":
			on_decided(0)
		"formation":
			var slots: Array = []
			for h: Dictionary in run.call("party_view"):
				slots.append(h["slot"])
			var res: Dictionary = run.call("set_formation", slots)
			res["slots"] = slots
			on_formation(res)
		"splash":
			on_splash_done(d["result"])
		"battle":
			on_battle_done()
		"road":
			on_road("continue")
		"results":
			on_results_done()
		"lanternrest":
			# the first visit descends through the Vault entrance; after a run it goes home
			if GameState.identity_needed():
				GameState.set_identity(GameState.DEFAULT_TEAM, Crests.DEFAULT_CREST)
			on_lanternrest("new" if run == null else "title")
	return true
