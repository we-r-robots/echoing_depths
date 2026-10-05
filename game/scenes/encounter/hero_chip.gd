class_name HeroChip
extends Control
## Compact party-strip entry: framed portrait, name, level + memory pips, mini alignment grid.
## Used by the encounter top bar; any screen that shows the party can reuse it.

const W := 112
const H := 26

var hero: Dictionary
var _portrait: TextureRect
var _name: Label
var _level: Label
var grid: AlignGrid
var _glow := 0.0
var _pips_shown := 0
var _threshold := 3


func setup(h: Dictionary) -> void:
	hero = h
	_threshold = int(EncounterDB.rules().get("advance_threshold", 3))
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := EncounterDB.class_info(h["class"])
	_portrait = TextureRect.new()
	_portrait.texture = load(info["portrait"])
	_portrait.position = Vector2(1, 1)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	_name = Label.new()
	_name.theme_type_variation = &"HeaderLabel"
	_name.text = h["name"]
	_name.position = Vector2(30, 0)
	add_child(_name)
	_level = Label.new()
	_level.theme_type_variation = &"MutedLabel"
	_level.position = Vector2(30, 12)
	add_child(_level)
	grid = AlignGrid.new()
	grid.cell = 4
	grid.gap = 1
	grid.position = Vector2(W - 30, -1)
	grid.dot_color = Pal.c(info["color"])
	grid.from_pos = h["pos"]
	grid.to_pos = h["pos"]
	add_child(grid)
	set_level(int(h["level"]))


func set_level(lv: int) -> void:
	_level.text = "Lv %d" % lv
	_pips_shown = mini(lv, _threshold)
	queue_redraw()


func pulse() -> void:
	_glow = 1.0
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _glow = v; queue_redraw(), 1.0, 0.0, 0.9)


func _draw() -> void:
	var info := EncounterDB.class_info(hero["class"])
	var cc := Pal.c(info["color"])
	# portrait frame: ink1 outline, class colour bottom edge
	draw_rect(Rect2(0, 0, 26, 26), Pal.INK1)
	draw_rect(Rect2(1, 1, 24, 24), Pal.INK3)
	draw_rect(Rect2(1, 24, 24, 1), cc)
	if _glow > 0.0:
		var g := Pal.CRYSTAL5
		g.a = _glow
		draw_rect(Rect2(-1, -1, 28, 28), g, false, 1.0)
	# memory pips toward the advancement threshold
	var x := 30 + 22
	for i in _threshold:
		var r := Rect2(x + i * 5, 15, 4, 4)
		draw_rect(r, Pal.INK1)
		draw_rect(r.grow(-1), Pal.CRYSTAL4 if i < _pips_shown else Pal.INK4)
