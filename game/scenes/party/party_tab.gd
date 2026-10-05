class_name PartyTab
extends Button
## One hero in the party row: portrait, name, level and memory pips (the big grid shows the
## selected hero's alignment; a mini grid per tab was one element too many, critic r3).
## The whole tab is the hit target (112x30). Selected tab gets the lit crystal row look.

const W := 100
const H := 30
const PIP_FULL := preload("res://ui/icons/memory_gem.png")
const STAR := preload("res://ui/icons/star.png")

var hero: Dictionary
var info: Dictionary
var is_selected := false:
	set(v): is_selected = v; queue_redraw()
var _por: TextureRect
var _badge: Control
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	text = ""
	focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())


func setup(h: Dictionary) -> void:
	hero = h
	info = EncounterDB.class_info(PartyModel.base_class(h))
	if _por == null:
		_por = TextureRect.new()
		_por.position = Vector2(4, 3)
		_por.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_por)
	_por.texture = load(info["portrait"])
	if _badge == null:
		_badge = Control.new()
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_badge.position = Vector2(1, 0)   # the portrait's far corner, clear of the name
		_badge.size = Vector2(9, 9)
		_badge.draw.connect(_draw_badge)
		add_child(_badge)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if PartyModel.ready_to_advance(hero):
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if is_selected:
		PartyDraw.selected(self, r)
	else:
		draw_rect(r.grow(-1), Pal.INK2)
		PartyDraw.soft_outline(self, r, Pal.INK4)
		draw_rect(Rect2(2, 1, W - 4, 1), Pal.INK3)
	var cc := Pal.c(info["color"])
	# portrait well
	draw_rect(Rect2(3, 2, 26, 26), Pal.INK1)
	draw_rect(Rect2(4, 3, 24, 24), Pal.INK3)
	draw_rect(Rect2(3, 27, 26, 1), cc)
	var name_col := Pal.INK10 if is_selected else Pal.INK9
	PartyDraw.text(self, Vector2(33, 3), String(hero.get("name", "?")), name_col, PartyDraw.BOLD)
	var lv := "Lv %d" % int(hero.get("level", 1))
	PartyDraw.text(self, Vector2(33, 15), lv, Pal.INK9 if is_selected else Pal.INK8, PartyDraw.BOLD)
	var x := 33 + PartyDraw.text_w(lv) + 4
	if PartyModel.tier(hero) == "base":
		var n := PartyModel.memory_count(hero)
		var th := PartyModel.threshold()
		for i in th:
			var p := Rect2(x + i * 5, 18, 4, 4)
			draw_rect(p, Pal.INK1)
			draw_rect(p.grow(-1), Pal.CRYSTAL4 if i < n else Pal.INK4)
		if n > th:
			PartyDraw.text(self, Vector2(x + th * 5 + 1, 15), "+%d" % (n - th), Pal.CRYSTAL4, PartyDraw.BOLD)
	else:
		PartyDraw.tint_tex(self, STAR, Vector2(x, 17), Pal.AMBER5)
	if _badge:
		_badge.queue_redraw()


func _draw_badge() -> void:
	if PartyModel.ready_to_advance(hero) and not hero.get("held_back", false):
		var on := fmod(_t, 0.9) < 0.55
		var b := Rect2(0, 0, 9, 9)
		_badge.draw_rect(b, Pal.INK1)
		_badge.draw_rect(b.grow(-1), Pal.AMBER5 if on else Pal.AMBER4)
		_badge.draw_rect(Rect2(4, 2, 1, 3), Pal.INK1)
		_badge.draw_rect(Rect2(4, 6, 1, 1), Pal.INK1)
