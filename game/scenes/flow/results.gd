class_name ResultsScreen
extends Control
## The end of a run: how it ended, how far it got, the party as it finished, and what it brings
## home to Lanternrest (Glimmers with their sources, Shards, lore, the Remembrance on a victory).
## The flow banks the rewards (GameState.apply_summary) before opening this screen.
##
##   var s := ResultsScreen.open(parent, run.summary(), rewards)
##   s.proceed.connect(func(): ...)      # "To Lanternrest"
## Standalone it shows a demo (--outcome=victory for a won run).

signal proceed

const SCENE := "res://scenes/flow/results.tscn"
const BACKDROP := preload("res://assets/encounter/odds/bg.png")

var summary: Dictionary = {}
var rewards: Dictionary = {}
var _opened := false
var _head: Label
var _sub: Label
var _left: PanelContainer
var _right: PanelContainer
var _go: Button


static func open(parent: Node, s: Dictionary, r: Dictionary) -> ResultsScreen:
	var scr: ResultsScreen = load(SCENE).instantiate()
	scr._opened = true
	scr.summary = s
	scr.rewards = r
	parent.add_child(scr)
	return scr


static func demo_summary(outcome := "fallen") -> Dictionary:
	var s := {"outcome": outcome, "vault": "The Drowned Archive", "team_name": "The Lanternrest Company",
		"depth": 21, "floor": 4, "pvp_wins": 4, "pvp_losses": 2, "guardian_wins": 2, "guardian_losses": 1,
		"monster_wins": 3, "monster_losses": 1, "memories": 11, "glimmers": 41, "shards": 0, "fragments": 0,
		"crystal_reached": false, "lore_items": ["faded_songbook"], "new_floors": [3, 4],
		"glimmer_breakdown": {"depth": 21, "pvp": 16, "milestones": 8, "fragments": 0},
		"heroes": [{"name": "Brannoc", "class": "lightsworn", "base": "fighter", "level": 2, "memories": 4},
			{"name": "Ilse", "class": "healer", "base": "healer", "level": 5, "memories": 4},
			{"name": "Sable", "class": "rogue", "base": "rogue", "level": 3, "memories": 3}]}
	if outcome == "victory":
		s.merge({"depth": 30, "floor": 5, "shards": 1, "crystal_reached": true, "fragments": 4, "glimmers": 58,
			"glimmer_breakdown": {"depth": 30, "pvp": 20, "milestones": 8, "fragments": 0},
			"remembrance": {"name": "The Harbor at Dawn", "lore": "A whole town waking at once, before anyone knew the word Fading."}}, true)
	return s


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if summary.is_empty():
		var outcome := "fallen"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--outcome="):
				outcome = a.substr(10)
		summary = demo_summary(outcome)
		rewards = {"glimmers": summary["glimmers"], "shards": summary["shards"], "new_lore": summary["lore_items"],
			"story_chapter_before": 1, "story_chapter": 2 if outcome == "victory" else 1, "glimmers_now": 87, "shards_now": 3}
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _won() -> bool:
	return String(summary.get("outcome", "")) == "victory"


func _build() -> void:
	_head = FlowUI.label("Victory" if _won() else "Fallen", &"", Pal.AMBER6 if _won() else Pal.FADE4, 400, HORIZONTAL_ALIGNMENT_CENTER)
	_head.add_theme_font_override("font", UIText.SERIF)
	_head.add_theme_font_size_override("font_size", UIText.DISPLAY)
	add_child(_head)
	var how := "A Shard breaks free of the Crystal." if _won() else \
		("The party fell at the Crystal." if bool(summary.get("crystal_reached", false)) else "The party fell on floor %d." % int(summary.get("floor", 1)))
	_sub = FlowUI.label("%s  ·  %s" % [String(summary.get("vault", "")), how], &"MutedLabel", null, 520, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_sub)
	_left = _run_panel()
	add_child(_left)
	_right = _reward_panel()
	add_child(_right)
	_go = FlowUI.primary("To Lanternrest", 150)
	_go.pressed.connect(func() -> void: proceed.emit())
	add_child(_go)


func _run_panel() -> PanelContainer:
	var p := FlowUI.panel()
	var v := FlowUI.vbox(3)
	v.custom_minimum_size.x = 250
	v.add_child(FlowUI.label("THE RUN", &"TagLabel"))
	v.add_child(FlowUI.label(String(summary.get("team_name", "")), &"GoldLabel"))
	var rows := [
		["Reached", "depth %d, floor %d" % [int(summary.get("depth", 0)), int(summary.get("floor", 0))]],
		["Echo fights", "%d won, %d lost" % [int(summary.get("pvp_wins", 0)), int(summary.get("pvp_losses", 0))]],
		["Guardians", "%d won, %d lost" % [int(summary.get("guardian_wins", 0)), int(summary.get("guardian_losses", 0))]],
		["Memories", str(int(summary.get("memories", 0)))],
	]
	if bool(summary.get("crystal_reached", false)):
		rows.append(["Crystal", "%d of 4 fragments" % int(summary.get("fragments", 0))])
	for r: Array in rows:
		v.add_child(_row(String(r[0]), String(r[1]), Pal.INK10))
	v.add_child(FlowUI.label("THE PARTY", &"TagLabel"))
	for h: Dictionary in summary.get("heroes", []):
		v.add_child(_row(String(h.get("name", "")), "%s, Lv %d" % [PartyModel.class_name_of(String(h.get("class", ""))), int(h.get("level", 1))], Pal.INK10))
	p.add_child(FlowUI.margin(v, 10))
	return p


func _reward_panel() -> PanelContainer:
	var p := FlowUI.panel(&"RarePanel" if _won() else &"PanelContainer")
	var v := FlowUI.vbox(3)
	v.custom_minimum_size.x = 250
	v.add_child(FlowUI.label("BROUGHT HOME", &"TagLabel"))
	v.add_child(_row("Glimmers", "+%d" % int(rewards.get("glimmers", 0)), Pal.CRYSTAL5))
	var b: Dictionary = summary.get("glimmer_breakdown", {})
	var src := {"depth": "  depth reached", "pvp": "  Echoes beaten", "milestones": "  new floors", "fragments": "  Crystal fragments"}
	for k: String in src:
		if int(b.get(k, 0)) > 0:
			v.add_child(_row(String(src[k]), "+%d" % int(b[k]), Pal.INK9))
	v.add_child(_row("Shards", "+%d" % int(rewards.get("shards", 0)), Pal.AMBER6))
	for l: String in rewards.get("new_lore", []):
		v.add_child(_row("Lore found", l.replace("_", " ").capitalize(), Pal.VIOLET4))
	if summary.has("remembrance"):
		var rm: Dictionary = summary["remembrance"]
		v.add_child(_row("Remembrance", String(rm.get("name", "")), Pal.AMBER6))
		v.add_child(FlowUI.para(String(rm.get("lore", "")), 250, Pal.INK9))
	if int(rewards.get("story_chapter", 1)) > int(rewards.get("story_chapter_before", 1)):
		v.add_child(_row("Story", "chapter %d opens" % int(rewards["story_chapter"]), Pal.AMBER6))
	v.add_child(FlowUI.label("Lanternrest now holds %d Glimmers and %d Shard%s." % [int(rewards.get("glimmers_now", 0)), int(rewards.get("shards_now", 0)), "" if int(rewards.get("shards_now", 0)) == 1 else "s"], &"MutedLabel", null, 250))
	p.add_child(FlowUI.margin(v, 10))
	return p


func _row(k: String, val: String, col: Color) -> HBoxContainer:
	var h := FlowUI.hbox(4)
	var a := FlowUI.label(k, &"MutedLabel")
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(FlowUI.label(val, &"GoldLabel", col))
	return h


func _layout() -> void:
	var fr := UIText.frame_rect(self)
	var cx := fr.position.x + 320.0
	_head.position = Vector2(cx - 200, 36)
	_sub.position = Vector2(cx - 260, 70)
	_left.reset_size()
	_right.reset_size()
	_left.position = Vector2(cx - 8 - _left.size.x, 92)
	_right.position = Vector2(cx + 8, 92)
	_go.position = Vector2(roundf(UIFrame.right(self) - 158), 326)
	queue_redraw()


func _draw() -> void:
	# dimmed far enough that the vault's statue and plaque don't read as UI behind the panels
	var dim := Pal.INK1
	dim.a = 0.93
	UIFrame.backdrop(self, BACKDROP, dim)
