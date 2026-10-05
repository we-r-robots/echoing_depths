class_name EncounterResultCard
extends Control
## The designed result of an encounter choice: the hero's portrait in a class-coloured frame, the
## memory absorbed, the level ticking up (pips), the shift in words and the hero's move on the
## alignment grid with its four pole words. Shared by the encounter screen and the run's encounter
## node (critic r5: the flow showed plain centred text instead of this card).
##
##   var card := EncounterResultCard.new()
##   parent.add_child(card)
##   card.setup(hero_after, hero_before, choice, width)   # heroes in the encounter screen's format
##   card.landed.connect(...)      # the level ticks up (pulse a chip, burst sparks)
##   card.finished.connect(...)    # the grid move and the reveals are done
##   card.play()                   # fades in, then animates

signal landed
signal moving
signal finished

const H := 112

var hero: Dictionary
var before: Dictionary
var strong := false
var capped := false
var _lv_old: Label
var _lv_arrow: Label
var _lv_new: Label
var _pips: Control
var _frame: ColorRect
var _adv: Label
var _grid: AlignGrid
var _reveal: Array[Control] = []
var _thr := 3


func setup(h: Dictionary, b: Dictionary, choice: Dictionary, width: int) -> void:
	hero = h
	before = b
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(width, H)
	custom_minimum_size = size
	var info := EncounterDB.class_info(h["class"])
	var cc := Pal.c(info["color"])
	var shift: Vector2i = h["pos"] - b["pos"]
	capped = shift != EncounterDB.shift_of(choice)
	strong = EncounterDB.is_rare(choice) and not capped
	_thr = int(EncounterDB.rules().get("advance_threshold", 3))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"RarePanel" if strong else &"PanelContainer"
	panel.size = size
	_add(panel)

	# left: portrait at 2x in a class-coloured frame
	_rect(Rect2(10, 10, 54, 54), Pal.INK1)
	_frame = _rect(Rect2(11, 11, 52, 52), cc)
	_rect(Rect2(12, 12, 50, 50), Pal.INK3)
	var por := TextureRect.new()
	por.texture = load(info["portrait"])
	por.scale = Vector2(2, 2)
	por.position = Vector2(13, 13)
	_add(por)
	var nm := _text(h["name"], Vector2(4, 68), cc, &"HeaderLabel")
	nm.size = Vector2(66, 11)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cl := _text(info.get("name", ""), Vector2(4, 79), Pal.INK8, &"HeaderLabel")
	cl.size = Vector2(66, 11)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# middle column (x 74..166): memory, level, shift
	var mx := 74
	var gem := TextureRect.new()
	gem.texture = load("res://ui/icons/memory_gem_big.png")
	gem.position = Vector2(mx, 9)
	_add(gem)
	_text("Memory", Vector2(mx + 17, 8), Pal.CRYSTAL4, &"TagLabel")
	_text("absorbed", Vector2(mx + 17, 18), Pal.INK8, &"HeaderLabel")
	_text("LEVEL", Vector2(mx, 37), Pal.INK8, &"HeaderLabel")
	_lv_old = _text(str(int(b["level"])), Vector2(mx + 30, 34), Pal.INK10, &"TitleLabel")
	# one arrow for every level and stat change in the game: "2 → 3" (critic r1 found three)
	_lv_arrow = _text("→", Vector2(mx + 40, 36), Pal.INK8, &"HeaderLabel")
	_lv_arrow.visible = false
	_lv_new = _text(str(int(h["level"])), Vector2(mx + 49, 34), Pal.CRYSTAL5, &"TitleLabel")
	_lv_new.visible = false
	_pips = Control.new()
	_pips.position = Vector2(mx, 53)
	_pips.set_meta("filled", mini(int(b["level"]), _thr))
	_pips.set_meta("glow", 0.0)
	var thr := _thr
	var pips := _pips
	_pips.draw.connect(func() -> void:
		var f: int = pips.get_meta("filled")
		var glow: float = pips.get_meta("glow")
		for i in thr:
			var r := Rect2(i * 9, 0, 8, 6)
			pips.draw_rect(r, Pal.INK1)
			var on := i < f
			var col := Pal.CRYSTAL4 if on else Pal.INK4
			if on and i == f - 1 and glow > 0.0:
				col = Pal.INK10
			pips.draw_rect(r.grow(-1), col)
			if on:
				pips.draw_rect(Rect2(i * 9 + 2, 1, 2, 1), Pal.CRYSTAL5))
	_add(_pips)
	var left := _thr - int(h["level"])
	_adv = _text(("%d more to Awaken" % left) if left > 0 else "Ready to Awaken", Vector2(mx, 61),
		Pal.AMBER6 if left <= 0 else Pal.INK7)
	_adv.modulate.a = 0.0
	# shift: one word per line so nothing runs into the grid labels
	var words := EncounterDB.shift_words(shift)
	var acol := Pal.c(words[0]["color"]) if words.size() == 1 else Pal.INK10
	var sy := 76
	if words.is_empty():
		var nm0 := _text("No move", Vector2(mx, sy), Pal.INK8)
		nm0.modulate.a = 0.0
		_reveal.append(nm0)
		sy += 11
	for i in words.size():
		var w: Dictionary = words[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row.position = Vector2(mx, sy)
		if i == 0:
			row.add_child(_icon_box(EncounterDB.arrow_icon(shift), acol))
		else:
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(7, 1)
			row.add_child(sp)
		var l := Label.new()
		l.text = "%s +%d" % [w["word"], w["amount"]]
		l.add_theme_color_override("font_color", UIText.legible(Pal.c(w["color"])))
		row.add_child(l)
		row.modulate.a = 0.0
		_add(row)
		_reveal.append(row)
		sy += 11
	var note_txt := ""
	var note_col := Pal.INK7
	if strong:
		note_txt = "Strong shift"
		note_col = Pal.AMBER6
	elif capped:
		note_txt = "Capped at edge"
		note_col = Pal.INK8
	if note_txt != "":
		var note := _text(note_txt, Vector2(mx, sy), note_col)
		note.modulate.a = 0.0
		_reveal.append(note)

	# right: the big grid with the four pole words, each clear of the border
	_grid = AlignGrid.new()
	_grid.cell = 7
	_grid.gap = 1
	_grid.dot_color = cc
	_grid.target_color = Pal.INK10
	_grid.from_pos = b["pos"]
	_grid.to_pos = h["pos"]
	_grid.show_target = true
	var gs := _grid.total_size()
	var gx := width - gs - 48
	var gy := int((H - gs) / 2.0) + 1
	_grid.position = Vector2(gx, gy)
	_add(_grid)
	var axes: Dictionary = EncounterDB.rules()["axes"]
	_axis_label(axes["good"]["pos"], axes["good"]["pos_color"], Vector2(gx - 10, gy - 13), gs + 20, HORIZONTAL_ALIGNMENT_CENTER)
	_axis_label(axes["good"]["neg"], axes["good"]["neg_color"], Vector2(gx - 10, gy + gs + 2), gs + 20, HORIZONTAL_ALIGNMENT_CENTER)
	_axis_label(axes["law"]["pos"], axes["law"]["pos_color"], Vector2(gx - 34, gy + int(gs / 2.0) - 6), 30, HORIZONTAL_ALIGNMENT_RIGHT)
	_axis_label(axes["law"]["neg"], axes["law"]["neg_color"], Vector2(gx + gs + 4, gy + int(gs / 2.0) - 6), 42, HORIZONTAL_ALIGNMENT_LEFT)


## The portrait's centre, in the card's parent's space (where the memory lands).
func portrait_center() -> Vector2:
	return position + Vector2(37, 37)


## Fades the card in and plays the memory landing, the level tick and the grid move.
## `delay` waits before the level ticks (the encounter screen's memory flight).
func play(delay := 0.7) -> void:
	modulate.a = 0.0
	var cc := _frame.color
	var tw := create_tween()
	var y0 := position.y
	position.y = y0 + 6
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(self, "position:y", y0, 0.2)
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		_lv_old.add_theme_color_override("font_color", UIText.legible(Pal.INK6))
		_lv_arrow.visible = true
		_lv_new.visible = true
		_lv_new.add_theme_color_override("font_color", UIText.legible(Pal.INK10))
		_pips.set_meta("filled", mini(int(hero["level"]), _thr))
		_pips.set_meta("glow", 1.0)
		_pips.queue_redraw()
		_frame.color = Pal.CRYSTAL5
		landed.emit())
	tw.tween_interval(0.14)
	tw.tween_callback(func() -> void:
		_frame.color = cc
		_lv_new.add_theme_color_override("font_color", UIText.legible(Pal.CRYSTAL5))
		_pips.set_meta("glow", 0.0)
		_pips.queue_redraw())
	tw.tween_property(_adv, "modulate:a", 1.0, 0.15)
	tw.tween_callback(func() -> void: moving.emit())
	tw.tween_property(_grid, "progress", 1.0, 0.8 if strong else 0.6)
	tw.tween_callback(func() -> void:
		_grid.show_target = false
		_grid.flash = 1.0)
	tw.tween_property(_grid, "flash", 0.0, 0.3)
	for r in _reveal:
		tw.parallel().tween_property(r, "modulate:a", 1.0, 0.2)
	tw.tween_callback(func() -> void: finished.emit())


func _rect(r: Rect2, col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.position = r.position
	c.size = r.size
	_add(c)
	return c


func _text(t: String, pos: Vector2, col: Color, variation: StringName = &"") -> Label:
	var l := Label.new()
	if variation != &"":
		l.theme_type_variation = variation
	l.text = t
	l.position = pos
	l.add_theme_color_override("font_color", UIText.legible(col))
	_add(l)
	return l


func _add(n: Control) -> void:
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(n)


func _icon_box(path: String, col: Color) -> Control:
	var wrap := Control.new()
	var tex: Texture2D = load(path)
	wrap.custom_minimum_size = Vector2(tex.get_width(), 11)
	var r := TextureRect.new()
	r.texture = tex
	r.modulate = col
	r.position = Vector2(0, 2)
	wrap.add_child(r)
	return wrap


func _axis_label(t: String, col: String, pos: Vector2, w: int, align: HorizontalAlignment) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UIText.legible(Pal.c(col)))
	l.position = pos
	l.size = Vector2(w, 11)
	l.horizontal_alignment = align
	_add(l)
