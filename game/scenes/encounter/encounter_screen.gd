extends Control
## Encounter choice screen (640x360). Data-driven from data/encounters/<id>.json.
## Flow: rest (pick a choice) -> resolution (outcome text, memory flies into the hero, level + grid move) -> Continue.
## Standalone demo: loads data/encounters/_demo_party.json, auto-picks a choice at `demo_auto_frame` unless the
## player touches anything first. Continue cycles through the sample encounters with the evolving party.

signal resolved(result: Dictionary)
signal finished(result: Dictionary)

const COL_X := 340
const COL_W := 292
const BOTTOM := 350

@export var encounter_id := ""
@export var demo := true

var party: Array = []
var encounter: Dictionary
var meta: Dictionary = {}
var _art: EncounterArt
var _chips: Array[HeroChip] = []
var _choice_box: VBoxContainer
var _buttons: Array[EncounterChoiceButton] = []
var _body: RichTextLabel
var _title: Label
var _tag: HBoxContainer
var _divider: TextureRect
var _fx: Control
var _flyers: Array = []
var _card: Control
var _continue: Button
var _result: Dictionary = {}
var _auto_choice := ""
var _auto_frame := -1
var _frames := 0
var _playlist: Array = []
var _layer: Control
var _legend: Control
var _body_top := 92
var _clock := 0.0
## The text column's x: COL_X in the 640x360 frame; on wide screens it anchors to the right edge
## (the painting stays at the left edge and every encounter painting ends in plain ink on the right).
var col_x := COL_X


func _ready() -> void:
	theme = preload("res://ui/theme.tres")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if demo:
		meta = EncounterDB.load_json(EncounterDB.DIR + "_demo_party.json")
		for h in meta["heroes"]:
			party.append({"name": h["name"], "class": h["class"], "level": int(h["level"]), "pos": Vector2i(h["pos"][0], h["pos"][1])})
		_playlist = meta.get("playlist", [])
		encounter_id = meta.get("encounter", "weeping_colossus")
		_auto_choice = meta.get("demo_auto_choice", "")
		_auto_frame = int(meta.get("demo_auto_frame", 240))
		# capture override: ENCOUNTER_DEMO=<encounter_id>[:<choice_id>]
		var env := OS.get_environment("ENCOUNTER_DEMO")
		if env != "":
			var parts := env.split(":")
			encounter_id = parts[0]
			if parts.size() > 1:
				_auto_choice = parts[1]
	show_encounter(encounter_id)


## Public entry for the run flow: set party/meta then call show_encounter(id).
func show_encounter(id: String) -> void:
	encounter = EncounterDB.get_encounter(id)
	encounter_id = id
	_result = {}
	if _layer:
		_layer.queue_free()
	_chips.clear()
	_buttons.clear()
	_flyers.clear()
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_build()
	_intro()


# ------------------------------------------------------------------------------------------ build

func _build() -> void:
	col_x = COL_X + roundi(UIFrame.right(self) - 640.0)
	var back := ColorRect.new()
	back.color = Pal.INK1
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(back)

	_art = EncounterArt.new()
	_layer.add_child(_art)
	_art.setup(encounter["art"])

	_build_top_bar()

	var kind := EncounterDB.kind_info(encounter["kind"])
	var kcol := Pal.c(kind.get("color", "crystal4"))
	_tag = HBoxContainer.new()
	_tag.add_theme_constant_override("separation", 4)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line_l := _hline(18, Pal.INK4)
	var icon := TextureRect.new()
	icon.texture = load(kind.get("icon", "res://ui/icons/kind_riddle.png"))
	icon.modulate = kcol
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tl := Label.new()
	tl.theme_type_variation = &"TagLabel"
	tl.text = String(kind.get("label", encounter["kind"])).to_upper()
	tl.add_theme_color_override("font_color", kcol)
	var line_r := _hline(18, Pal.INK4)
	for n in [line_l, icon, tl, line_r]:
		_tag.add_child(n)
	_layer.add_child(_tag)
	_tag.reset_size()
	_tag.position = Vector2(col_x + int((COL_W - _tag.size.x) / 2.0), 44)

	_title = Label.new()
	_title.theme_type_variation = &"HeadingLabel"
	_title.text = encounter["title"]
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(col_x, 58)
	_title.size = Vector2(COL_W, 20)
	_layer.add_child(_title)

	_divider = TextureRect.new()
	_divider.texture = load("res://ui/divider.png")
	_divider.position = Vector2(col_x + int((COL_W - 96) / 2.0), 78)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_divider)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.position = Vector2(col_x + 6, 92)
	_body.size = Vector2(COL_W - 12, 120)
	_body.text = "[center]" + EncounterDB.markup(encounter["text"]) + "[/center]"
	_layer.add_child(_body)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 5)
	_layer.add_child(_choice_box)
	var bound := EncounterDB.bind_choices(encounter, party)
	for b in bound:
		var btn := EncounterChoiceButton.new()
		_choice_box.add_child(btn)
		btn.setup(b["choice"], party[b["hero_index"]], b["hero_index"], COL_W)
		btn.pressed.connect(_on_choice.bind(btn))
		_buttons.append(btn)
	var h := bound.size() * EncounterChoiceButton.H + maxi(bound.size() - 1, 0) * 5
	_choice_box.size = Vector2(COL_W, h)
	if _buttons.size() > 0:
		_buttons[0].focus_neighbor_top = _buttons[-1].get_path()
	_legend = _make_legend()
	_layer.add_child(_legend)
	_layout()

	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_layer.add_child(_fx)


## Vertically centres the column: tag, title, divider, prose, legend, choices (no dead band).
func _layout() -> void:
	var body_h := _text_height(_body.text)
	var ch_h := int(_choice_box.size.y)
	var total := 54 + body_h + 12 + 12 + ch_h
	var top := 38 + maxi(0, int((BOTTOM - 38 - total) / 2.0))
	_tag.position.y = top
	_title.position.y = top + 13
	_divider.position.y = top + 38
	_body_top = top + 52
	_body.position.y = _body_top
	var cy := mini(_body_top + body_h + 24, BOTTOM - ch_h)
	_legend.position = Vector2(col_x + COL_W - _legend.custom_minimum_size.x - 4, cy - 11)
	_choice_box.position = Vector2(col_x, cy)


func _text_height(bb: String) -> int:
	var plain := RegEx.create_from_string("\\[[^\\]]*\\]").sub(bb, "", true)
	var font := get_theme_font("normal_font", "RichTextLabel")
	var lines := UIText.wrap_lines(plain, COL_W - 12, font, UIText.BODY).size()
	return ceili(lines * UIText.line_h(font, UIText.BODY))


## "Alignment: [solid] now  [ring] after", so the grid markers on every row read without a tutorial.
func _make_legend() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(118, 10)
	var font: Font = UIText.BOLD
	c.draw.connect(func() -> void:
		var x := 0.0
		UIText.draw_base(c, Vector2(x, 8), "Grid:", Pal.INK8, font, UIText.LABEL, false)
		x += UIText.width("Grid:", font, UIText.LABEL) + 5
		c.draw_rect(Rect2(x, 2, 5, 5), Pal.INK9)
		x += 8
		UIText.draw_base(c, Vector2(x, 8), "now", Pal.INK10, font, UIText.LABEL, false)
		x += UIText.width("now", font, UIText.LABEL) + 6
		var r := Rect2(x, 1, 7, 7)
		for e in [Rect2(r.position, Vector2(7, 1)), Rect2(r.position + Vector2(0, 6), Vector2(7, 1)), Rect2(r.position, Vector2(1, 7)), Rect2(r.position + Vector2(6, 0), Vector2(1, 7))]:
			c.draw_rect(e, Pal.INK10)
		x += 10
		UIText.draw_base(c, Vector2(x, 8), "after this choice", Pal.INK10, font, UIText.LABEL, false))
	c.custom_minimum_size.x = 30 + 8 + 22 + 10 + 96
	return c


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"TopBar"
	bar.position = Vector2.ZERO
	bar.size = Vector2(get_viewport_rect().size.x, 32)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bar)
	var l0 := roundi(UIFrame.left(self))
	var r0 := roundi(UIFrame.right(self))
	var x := l0 + 4
	for h in party:
		var chip := HeroChip.new()
		chip.position = Vector2(x, 2)
		_layer.add_child(chip)
		chip.setup(h)
		_chips.append(chip)
		x += HeroChip.W + 4
	# right side: where we are + party lanterns (health)
	var loc := Label.new()
	loc.theme_type_variation = &"MutedLabel"
	loc.text = "Depth %d" % int(meta.get("depth", 1))
	loc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	loc.position = Vector2(r0 - 280, 3)
	loc.size = Vector2(274, 11)
	_layer.add_child(loc)
	var lan: Array = meta.get("lanterns", [3, 4])
	var lx := r0 - 6 - int(lan[1]) * 9
	for i in int(lan[1]):
		var lt := _lantern_icon(i < int(lan[0]))
		lt.position = Vector2(lx + i * 9, 15)
		_layer.add_child(lt)


func _lantern_icon(lit: bool) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(7, 10)
	c.draw.connect(func() -> void:
		var rows := [".###.", "#...#", "#.o.#", "#ooo#", "#.o.#", "#...#", ".###.", "..#.."]
		for y in rows.size():
			for x in 5:
				var ch: String = rows[y][x]
				if ch == "#":
					c.draw_rect(Rect2(x + 1, y + 1, 1, 1), Pal.AMBER3 if lit else Pal.FADE1)
				elif ch == "o":
					c.draw_rect(Rect2(x + 1, y + 1, 1, 1), Pal.AMBER6 if lit else Pal.INK3)
		c.draw_rect(Rect2(3, 0, 1, 1), Pal.AMBER3 if lit else Pal.FADE1)
	)
	return c


func _hline(w: int, col: Color) -> Control:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(w, 1)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ------------------------------------------------------------------------------------------ intro

func _intro() -> void:
	_layer.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_layer, "modulate:a", 1.0, 0.35)
	for i in _buttons.size():
		var b := _buttons[i]
		b.modulate.a = 0.0
		var t2 := create_tween()
		t2.tween_interval(0.2 + i * 0.08)
		t2.tween_property(b, "modulate:a", 1.0, 0.2)
	if _buttons.size() > 0 and not demo:
		_buttons[0].grab_focus.call_deferred()


# ------------------------------------------------------------------------------------------ demo + input

func _process(delta: float) -> void:
	_frames += 1
	_clock += delta
	if _auto_frame > 0 and _frames >= _auto_frame and _result.is_empty():
		_auto_frame = -1
		for b in _buttons:
			if b.choice.get("id", "") == _auto_choice:
				b.button_pressed = true
				_on_choice(b)
				return
		if _buttons.size() > 0:
			_on_choice(_buttons[0])
	if not _flyers.is_empty():
		_fx.queue_redraw()


func _input(event: InputEvent) -> void:
	# any real input cancels the unattended demo pick
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey:
		_auto_frame = -1


# ------------------------------------------------------------------------------------------ resolution

func _on_choice(btn: EncounterChoiceButton) -> void:
	if not _result.is_empty():
		return
	var hero: Dictionary = party[btn.hero_index]
	var before := EncounterDB.apply_choice(hero, btn.choice)
	var outcome := EncounterDB.pick_outcome(btn.choice)
	var recruit: Dictionary = btn.choice.get("recruit", {})
	_result = {"encounter": encounter_id, "choice": btn.choice.get("id", ""), "hero_index": btn.hero_index,
		"before": before, "after": {"level": hero["level"], "pos": hero["pos"]}, "recruit": recruit}
	resolved.emit(_result)
	for b in _buttons:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	_legend.visible = false
	# the chosen plate lights up, the rest fall away
	btn.add_theme_stylebox_override("disabled", btn.get_theme_stylebox("pressed"))
	var tw := create_tween().set_parallel(true)
	for b in _buttons:
		if b != btn:
			tw.tween_property(b, "modulate:a", 0.0, 0.18)
	tw.chain().tween_interval(0.15)
	tw.chain().tween_property(btn, "modulate:a", 0.0, 0.18)
	# the illustration answers the choice
	if btn.choice.has("art"):
		var ta := create_tween()
		ta.tween_interval(0.25)
		ta.tween_callback(_art.apply_change.bind(btn.choice["art"], 0.7))
	# narrative swaps to the outcome
	var bb := "[center]" + EncounterDB.markup(outcome) + "[/center]"
	var body_h := _text_height(bb)
	var tt := create_tween()
	tt.tween_property(_body, "modulate:a", 0.0, 0.15)
	tt.tween_callback(func() -> void:
		_body.text = bb
		_body.visible_ratio = 0.0)
	tt.tween_property(_body, "modulate:a", 1.0, 0.01)
	tt.tween_property(_body, "visible_ratio", 1.0, 0.7)
	var tc := create_tween()
	tc.tween_interval(0.42)
	tc.tween_callback(_show_card.bind(btn, hero, before, body_h))
	if not recruit.is_empty() and party.size() < 4:
		tc.tween_interval(1.0)
		tc.tween_callback(_add_recruit.bind(recruit))


## A recruited hero joins the party at once: a new chip slides into the top bar.
func _add_recruit(r: Dictionary) -> void:
	var info := EncounterDB.class_info(r["class"])
	var h := {"name": r["name"], "class": r["class"], "level": 1, "pos": EncounterDB.class_start(r["class"])}
	party.append(h)
	var chip := HeroChip.new()
	chip.position = Vector2(roundi(UIFrame.left(self)) + 4 + _chips.size() * (HeroChip.W + 4), 2)
	chip.modulate.a = 0.0
	_layer.add_child(chip)
	chip.setup(h)
	_chips.append(chip)
	var tw := create_tween()
	tw.tween_property(chip, "modulate:a", 1.0, 0.25)
	tw.tween_callback(chip.pulse)


func _show_card(btn: EncounterChoiceButton, hero: Dictionary, before: Dictionary, body_h: int) -> void:
	_choice_box.visible = false
	var info := EncounterDB.class_info(hero["class"])
	var cc := Pal.c(info["color"])
	var shift: Vector2i = hero["pos"] - before["pos"]
	var capped: bool = shift != EncounterDB.shift_of(btn.choice)
	var strong := EncounterDB.is_rare(btn.choice) and not capped
	var thr := int(EncounterDB.rules().get("advance_threshold", 3))
	var recruit: Dictionary = btn.choice.get("recruit", {})
	if party.size() >= 4 and party[-1].get("name", "") != recruit.get("name", ""):
		recruit = {}
	var card_h := 112
	var cont_h := 22
	var rec_h := 40 if not recruit.is_empty() else 0
	# re-centre the whole column around the result so nothing floats over empty space
	var total := 52 + body_h + 10 + card_h + rec_h + 6 + cont_h
	var top := 38 + maxi(0, int((BOTTOM - 38 - total) / 2.0))
	var shift_y := top - _tag.position.y
	var tl := create_tween().set_parallel(true)
	for n in [_tag, _title, _divider, _body]:
		tl.tween_property(n, "position:y", n.position.y + shift_y, 0.3)
	_body_top += shift_y
	var card_y := _body_top + body_h + 10
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = Vector2(col_x, card_y + 6)
	_card.size = Vector2(COL_W, card_h)
	_card.modulate.a = 0.0
	_layer.add_child(_card)
	_layer.move_child(_fx, -1)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"RarePanel" if strong else &"PanelContainer"
	panel.size = _card.size
	_add(_card, panel)

	# left: portrait at 2x in a class-coloured frame
	_rect(_card, Rect2(10, 10, 54, 54), Pal.INK1)
	var frame2 := _rect(_card, Rect2(11, 11, 52, 52), cc)
	_rect(_card, Rect2(12, 12, 50, 50), Pal.INK3)
	var por := TextureRect.new()
	por.texture = load(info["portrait"])
	por.scale = Vector2(2, 2)
	por.position = Vector2(13, 13)
	_add(_card, por)
	var nm := _text(_card, hero["name"], Vector2(4, 68), cc, &"HeaderLabel")
	nm.size = Vector2(66, 11)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cl := _text(_card, info.get("name", ""), Vector2(4, 79), Pal.INK7)
	cl.size = Vector2(66, 11)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# middle column (x 74..166): memory, level, shift
	var mx := 74
	var gem := TextureRect.new()
	gem.texture = load("res://ui/icons/memory_gem_big.png")
	gem.position = Vector2(mx, 9)
	_add(_card, gem)
	_text(_card, "Memory", Vector2(mx + 17, 8), Pal.CRYSTAL4, &"TagLabel")
	_text(_card, "absorbed", Vector2(mx + 17, 18), Pal.INK7)
	_text(_card, "LEVEL", Vector2(mx, 37), Pal.INK7)
	var lv_old := _text(_card, str(int(before["level"])), Vector2(mx + 30, 34), Pal.INK10, &"TitleLabel")
	var lv_arrow := TextureRect.new()
	lv_arrow.texture = load("res://ui/icons/chevron.png")
	lv_arrow.modulate = Pal.INK6
	lv_arrow.position = Vector2(mx + 42, 39)
	lv_arrow.visible = false
	_add(_card, lv_arrow)
	var lv_new := _text(_card, str(int(hero["level"])), Vector2(mx + 49, 34), Pal.CRYSTAL5, &"TitleLabel")
	lv_new.visible = false
	var pips := Control.new()
	pips.position = Vector2(mx, 53)
	pips.set_meta("filled", mini(int(before["level"]), thr))
	pips.set_meta("glow", 0.0)
	pips.draw.connect(func() -> void:
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
	_add(_card, pips)
	var left := thr - int(hero["level"])
	var adv := _text(_card, ("%d more to Awaken" % left) if left > 0 else "Ready to Awaken", Vector2(mx, 61),
		Pal.AMBER6 if left <= 0 else Pal.INK7)
	adv.modulate.a = 0.0
	# shift: one word per line so nothing runs into the grid labels
	var words := EncounterDB.shift_words(shift)
	var acol := Pal.c(words[0]["color"]) if words.size() == 1 else Pal.INK10
	var reveal: Array[Control] = []
	var sy := 76
	if words.is_empty():
		var nm0 := _text(_card, "No move", Vector2(mx, sy), Pal.INK8)
		nm0.modulate.a = 0.0
		reveal.append(nm0)
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
		l.add_theme_color_override("font_color", Pal.c(w["color"]))
		row.add_child(l)
		row.modulate.a = 0.0
		_add(_card, row)
		reveal.append(row)
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
		var note := _text(_card, note_txt, Vector2(mx + (10 if strong else 0), sy), note_col)
		note.modulate.a = 0.0
		reveal.append(note)
		if strong:
			var star := TextureRect.new()
			star.texture = load("res://ui/icons/star.png")
			star.modulate = Pal.AMBER6
			star.position = Vector2(-10, 2)
			note.add_child(star)

	# right: the big grid with the four pole words, each clear of the border
	var grid := AlignGrid.new()
	grid.cell = 7
	grid.gap = 1
	grid.dot_color = cc
	grid.target_color = Pal.INK10
	grid.from_pos = before["pos"]
	grid.to_pos = hero["pos"]
	grid.show_target = true
	var gs := grid.total_size()
	var gx := COL_W - gs - 48
	var gy := int((card_h - gs) / 2.0) + 1
	grid.position = Vector2(gx, gy)
	_add(_card, grid)
	var axes: Dictionary = EncounterDB.rules()["axes"]
	_axis_label(_card, axes["good"]["pos"], axes["good"]["pos_color"], Vector2(gx - 10, gy - 13), gs + 20, HORIZONTAL_ALIGNMENT_CENTER)
	_axis_label(_card, axes["good"]["neg"], axes["good"]["neg_color"], Vector2(gx - 10, gy + gs + 2), gs + 20, HORIZONTAL_ALIGNMENT_CENTER)
	_axis_label(_card, axes["law"]["pos"], axes["law"]["pos_color"], Vector2(gx - 34, gy + int(gs / 2.0) - 6), 30, HORIZONTAL_ALIGNMENT_RIGHT)
	_axis_label(_card, axes["law"]["neg"], axes["law"]["neg_color"], Vector2(gx + gs + 4, gy + int(gs / 2.0) - 6), 42, HORIZONTAL_ALIGNMENT_LEFT)

	if rec_h > 0:
		reveal.append(_recruit_panel(recruit, card_y + card_h + 4))
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.position = Vector2(col_x, card_y + card_h + rec_h + 6)
	_continue.size = Vector2(COL_W, cont_h)
	_continue.modulate.a = 0.0
	_continue.disabled = true
	_continue.pressed.connect(_on_continue)
	_layer.add_child(_continue)

	var chip := _chips[btn.hero_index] if btn.hero_index < _chips.size() else null
	var portrait_center := _card.position + Vector2(37, 37 - 6)
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_card, "position:y", _card.position.y - 6, 0.2)
	tw.tween_callback(_spawn_flyers.bind(_art.source_point(), portrait_center, chip))
	tw.tween_interval(0.7)
	tw.tween_callback(func() -> void:
		lv_old.add_theme_color_override("font_color", Pal.INK6)
		lv_arrow.visible = true
		lv_new.visible = true
		lv_new.add_theme_color_override("font_color", Pal.INK10)
		pips.set_meta("filled", mini(int(hero["level"]), thr))
		pips.set_meta("glow", 1.0)
		pips.queue_redraw()
		frame2.color = Pal.CRYSTAL5
		_burst(portrait_center)
		if chip:
			chip.set_level(int(hero["level"]))
			chip.pulse())
	tw.tween_interval(0.14)
	tw.tween_callback(func() -> void:
		frame2.color = cc
		lv_new.add_theme_color_override("font_color", Pal.CRYSTAL5)
		pips.set_meta("glow", 0.0)
		pips.queue_redraw())
	tw.tween_property(adv, "modulate:a", 1.0, 0.15)
	tw.tween_property(grid, "progress", 1.0, 0.8 if strong else 0.6)
	if chip:
		chip.grid.from_pos = before["pos"]
		chip.grid.to_pos = hero["pos"]
		tw.parallel().tween_property(chip.grid, "progress", 1.0, 0.6)
	tw.tween_callback(func() -> void:
		grid.show_target = false
		grid.flash = 1.0)
	tw.tween_property(grid, "flash", 0.0, 0.3)
	for r in reveal:
		tw.parallel().tween_property(r, "modulate:a", 1.0, 0.2)
	tw.tween_callback(func() -> void:
		if chip:
			chip.grid.from_pos = hero["pos"]
			chip.grid.progress = 0.0
		_continue.disabled = false)
	tw.tween_property(_continue, "modulate:a", 1.0, 0.2)


## The recruit's moment: their portrait, name and starting place on the grid, under the memory card.
func _recruit_panel(r: Dictionary, y: int) -> Control:
	var info := EncounterDB.class_info(r["class"])
	var cc := Pal.c(info["color"])
	var p := Control.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = Vector2(col_x, y)
	p.size = Vector2(COL_W, 36)
	p.modulate.a = 0.0
	_layer.add_child(p)
	var bgp := PanelContainer.new()
	bgp.size = p.size
	_add(p, bgp)
	_rect(p, Rect2(6, 4, 28, 28), Pal.INK1)
	_rect(p, Rect2(7, 5, 26, 26), Pal.LIFE3)
	_rect(p, Rect2(8, 6, 24, 24), Pal.INK3)
	var por := TextureRect.new()
	por.texture = load(info["portrait"])
	por.position = Vector2(8, 6)
	_add(p, por)
	_text(p, "%s joins the party" % r["name"], Vector2(42, 6), Pal.LIFE4, &"GoldLabel")
	_text(p, "%s  ·  Lv 1  ·  starts here:" % info.get("name", ""), Vector2(42, 18), Pal.INK8)
	var g := AlignGrid.new()
	g.cell = 5
	g.gap = 1
	g.dot_color = cc
	g.from_pos = EncounterDB.class_start(r["class"])
	g.to_pos = g.from_pos
	g.position = Vector2(COL_W - g.total_size() - 8, 2)
	_add(p, g)
	return p


func _rect(parent: Control, r: Rect2, col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.position = r.position
	c.size = r.size
	_add(parent, c)
	return c


func _text(parent: Control, t: String, pos: Vector2, col: Color, variation: StringName = &"") -> Label:
	var l := Label.new()
	if variation != &"":
		l.theme_type_variation = variation
	l.text = t
	l.position = pos
	l.add_theme_color_override("font_color", col)
	_add(parent, l)
	return l


## A ring of sparks when the memory lands.
func _burst(at: Vector2) -> void:
	for i in 12:
		var ang := TAU * i / 12.0
		var d := Vector2(cos(ang), sin(ang))
		_flyers.append({"a": at + d * 4.0, "m": at + d * 14.0, "b": at + d * 22.0, "t0": _clock, "dur": 0.35,
			"c": Pal.CRYSTAL5 if i % 2 == 0 else Pal.INK10})


func _add(parent: Control, n: Control) -> void:
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)


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


func _axis_label(parent: Control, t: String, col: String, pos: Vector2, w: int, align: HorizontalAlignment) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Pal.c(col))
	l.position = pos
	l.size = Vector2(w, 11)
	l.horizontal_alignment = align
	_add(parent, l)


func _spawn_flyers(from: Vector2, to: Vector2, chip: HeroChip) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var now := _clock
	for i in 14:
		var dest := to
		if chip and i % 3 == 0:
			dest = chip.position + Vector2(13, 13)
		var mid := from.lerp(dest, 0.5) + Vector2(rng.randf_range(-60, 60), rng.randf_range(-70, -10))
		_flyers.append({"a": from + Vector2(rng.randf_range(-6, 6), rng.randf_range(-4, 4)), "m": mid, "b": dest,
			"t0": now + i * 0.03, "dur": rng.randf_range(0.5, 0.7),
			"c": [Pal.CRYSTAL5, Pal.CRYSTAL4, Pal.INK10][i % 3]})


func _draw_fx() -> void:
	var now := _clock
	var alive := []
	for f in _flyers:
		var k: float = (now - float(f["t0"])) / float(f["dur"])
		if k > 1.0:
			continue
		alive.append(f)
		if k < 0.0:
			continue
		var e := k * k * (3.0 - 2.0 * k)
		for tail in 4:
			var kk := maxf(e - tail * 0.05, 0.0)
			var p: Vector2 = (f["a"] as Vector2).lerp(f["m"], kk).lerp((f["m"] as Vector2).lerp(f["b"], kk), kk)
			var c: Color = f["c"] if tail == 0 else (Pal.CRYSTAL3 if tail < 3 else Pal.CRYSTAL2)
			var s := 2 if tail == 0 else 1
			_fx.draw_rect(Rect2(p.round(), Vector2(s, s)), c)
	_flyers = alive


func _on_continue() -> void:
	finished.emit(_result)
	if not demo or _playlist.is_empty():
		return
	var i := _playlist.find(encounter_id)
	show_encounter(_playlist[(i + 1) % _playlist.size()])
