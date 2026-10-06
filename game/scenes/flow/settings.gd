class_name SettingsScreen
extends Control
## Settings. Battle Effects: Low / Medium / High drives the battle scene's spectacle_level
## (0 / 1 / 2; High by default): the focus dim, camera push, effect size, hit-stop and shake on
## ability turns. Saved to user://settings.json (GameState) and applied to every battle the flow
## starts. Standalone (no open) it shows the screen without saving.

signal closed

const SCENE := "res://scenes/flow/settings.tscn"
const BACKDROP := preload("res://assets/battle/bg_vault_wide.png")
const LEVELS := ["Low", "Medium", "High"]
const WORDS := [
	"Calm ability turns: no focus dim, camera push or shake. Easiest on the eyes and on older phones.",
	"Subtle: a light focus dim and camera push, smaller effects.",
	"Full spectacle: focus dim, camera push, big effects, shake and a pause on heavy hits.",
]

var persist := true
var _opened := false
var _level := 2
var _speed := 0
var _buttons: Array[Button] = []
var _speed_buttons: Array[Button] = []
var _desc: Label
var _box: PanelContainer
var _back: Button


static func open(parent: Node) -> SettingsScreen:
	var s: SettingsScreen = load(SCENE).instantiate()
	s._opened = true
	parent.add_child(s)
	return s


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	persist = _opened
	_level = GameState.battle_effects()
	_box = FlowUI.panel()
	var v := FlowUI.vbox(8)
	v.add_child(FlowUI.label("Settings", &"HeadingLabel"))
	v.add_child(FlowUI.label("BATTLE EFFECTS", &"TagLabel"))
	var row := FlowUI.hbox(6)
	var group := ButtonGroup.new()
	for i in LEVELS.size():
		var b := FlowUI.button(LEVELS[i], 84, 24)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == _level
		b.pressed.connect(select.bind(i))
		row.add_child(b)
		_buttons.append(b)
	v.add_child(row)
	_desc = FlowUI.para("", 264)
	_desc.custom_minimum_size.y = 28
	v.add_child(_desc)
	# the speed every fight starts at (also set by the x1 / x2 / x4 button in a fight)
	_speed = GameState.battle_speed()
	v.add_child(FlowUI.label("BATTLE SPEED", &"TagLabel"))
	var srow := FlowUI.hbox(6)
	var sgroup := ButtonGroup.new()
	for i in GameState.BATTLE_SPEEDS.size():
		var sb := FlowUI.button("x%d" % int(GameState.BATTLE_SPEEDS[i]), 84, 24)
		sb.toggle_mode = true
		sb.button_group = sgroup
		sb.button_pressed = i == _speed
		sb.pressed.connect(select_speed.bind(i))
		srow.add_child(sb)
		_speed_buttons.append(sb)
	v.add_child(srow)
	_box.add_child(FlowUI.margin(v, 12))
	add_child(_box)
	_back = FlowUI.button("Back", 76, 22)
	_back.pressed.connect(close)
	add_child(_back)
	_refresh()
	get_viewport().size_changed.connect(_layout)
	_layout()


func select(i: int) -> void:
	_level = clampi(i, 0, 2)
	if persist:
		GameState.set_battle_effects(_level)
	_refresh()


func level() -> int:
	return _level


func select_speed(i: int) -> void:
	_speed = clampi(i, 0, GameState.BATTLE_SPEEDS.size() - 1)
	if persist:
		GameState.set_battle_speed(_speed)
	for k in _speed_buttons.size():
		_speed_buttons[k].set_pressed_no_signal(k == _speed)


func _refresh() -> void:
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == _level)
	_desc.text = WORDS[_level]


func close() -> void:
	closed.emit()
	if _opened:
		queue_free()


func _layout() -> void:
	var fr := UIText.frame_rect(self)
	_box.reset_size()
	_box.position = Vector2(roundf(fr.position.x + 320 - _box.size.x / 2.0), 90)
	_back.position = Vector2(roundf(UIFrame.right(self) - 84), 334)
	queue_redraw()


func _draw() -> void:
	var fr := UIText.frame_rect(self)
	draw_rect(get_viewport_rect(), Pal.INK1)
	draw_texture(BACKDROP, fr.position + Vector2(-16 - 120, -16))
	var dim := Pal.INK1
	dim.a = 0.82
	draw_rect(get_viewport_rect(), dim)
	UIFrame.top_bar(self)
	var l := UIFrame.left(self)
	PartyDraw.text(self, Vector2(l + 10, UIText.centered_y(0, 28, UIText.SERIF, UIText.TITLE)), "Echoing Depths", Pal.AMBER6, UIText.SERIF, UIText.TITLE)
