class_name TitleScreen
extends Control
## Title: Continue (when there is a save) or New game, both into Lanternrest, where the game
## starts (the Vault entrance there starts each run); Settings, Quit (desktop).
## The footer shows the team's crest and name and what Lanternrest holds so far.
## Signals carry the choice to the flow controller (scenes/flow/flow.gd).

signal lanternrest
signal settings
signal quit

const SCENE := "res://scenes/flow/title.tscn"
const BACKDROP := preload("res://assets/encounter/campfire/bg.png")
const GLOW := preload("res://assets/encounter/campfire/glow.png")

var _opened := false
var _t := 0.0
var _title: Label
var _sub: Label
var _menu: VBoxContainer
var _foot: HBoxContainer
var buttons := {}


static func open(parent: Node) -> TitleScreen:
	var s: TitleScreen = load(SCENE).instantiate()
	s._opened = true
	parent.add_child(s)
	return s


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameState.ensure()
	_title = FlowUI.label("Echoing Depths", &"", Pal.AMBER6, 400, HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_font_override("font", UIText.SERIF)
	_title.add_theme_font_size_override("font_size", UIText.DISPLAY)
	add_child(_title)
	_sub = FlowUI.label("Descend into the Memory Vaults. Bring something back.", &"MutedLabel", null, 400, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_sub)
	_menu = FlowUI.vbox(6)
	add_child(_menu)
	if GameState.has_save():
		_add("continue", "Continue", lanternrest)
	else:
		_add("new", "New game", lanternrest)
	_add("settings", "Settings", settings)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_add("quit", "Quit", quit)
	_foot = FlowUI.hbox(6)
	_foot.add_child(FlowUI.crest(GameState.crest(), 1))
	var m: Dictionary = GameState.meta
	_foot.add_child(FlowUI.label(GameState.team_name(), &"GoldLabel"))
	var line := "Runs %d   Victories %d   Shards %d   Glimmers %d" % [int(m["runs"]), int(m["victories"]),
		int(m["shards"]), int(m["glimmers"])]
	_foot.add_child(FlowUI.label(line, &"MutedLabel"))
	add_child(_foot)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _add(key: String, text: String, sig: Signal) -> void:
	# the first entry (Continue run, else New run) is the screen's one primary action
	var b := FlowUI.primary(text, 150) if buttons.is_empty() else FlowUI.button(text, 140, 24)
	b.pressed.connect(func() -> void: sig.emit())
	_menu.add_child(b)
	buttons[key] = b


func _layout() -> void:
	var fr := UIText.frame_rect(self)
	var cx := fr.position.x + 320.0
	_title.position = Vector2(cx - 200, 70)
	_sub.position = Vector2(cx - 200, 104)
	_menu.reset_size()
	_menu.position = Vector2(cx - 75, 150)
	_foot.reset_size()
	var sr := UIText.safe_rect(self)
	_foot.position = Vector2(roundf(sr.position.x + 10), 334)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var dim := Pal.INK1
	dim.a = 0.55
	UIFrame.backdrop(self, BACKDROP, dim, [GLOW])
	# the menu sits on a dark plate so the backdrop never fights the words
	var fr := UIText.frame_rect(self)
	var cx := fr.position.x + 320.0
	var plate := Pal.INK1
	plate.a = 0.6
	draw_rect(Rect2(cx - 210, 60, 420, 74), plate)
	UIText.hline(self, cx - 120, 126, 240, Pal.AMBER4)
	var bar := Pal.INK1
	bar.a = 0.8
	var vw := get_viewport_rect().size.x
	draw_rect(Rect2(0, 328, vw, 32), bar)
	draw_rect(Rect2(0, 328, vw, 1), Pal.INK4)
