extends Control
## Encounter choice screen (640x360). Data-driven from data/encounters/<id>.json.
## Flow: rest (pick a choice) -> resolution (outcome text, memory flies into the hero, level + grid move) -> Continue.
## Standalone demo: loads data/encounters/_demo_party.json, auto-picks a choice at `demo_auto_frame` unless the
## player touches anything first. Continue cycles through the sample encounters with the evolving party.

signal resolved(result: Dictionary)
signal finished(result: Dictionary)

const COL_X := 340
const COL_W := 276      # 24 px clear of the frame's right edge (critic r5: the rows hugged it)
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
## The text column's x: COL_X in the 640x360 frame. On wide screens the painting and the column
## move together as one group, centred in the view (critic r1: anchoring them to opposite edges
## left a band of dead black between the art and its words).
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
		# capture override: --encounter=<encounter_id>[:<choice_id>] (a scene arg, which reaches the
		# game however it is launched), or the env var ENCOUNTER_DEMO with the same value
		var env := OS.get_environment("ENCOUNTER_DEMO")
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--encounter="):
				env = arg.trim_prefix("--encounter=")
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
	var fx := UIText.frame_rect(self).position.x
	col_x = COL_X + roundi(fx)
	var back := ColorRect.new()
	back.color = Pal.INK1
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(back)

	_art = EncounterArt.new()
	_layer.add_child(_art)
	_art.setup(encounter["art"])
	_art.position.x = fx

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
	tl.add_theme_color_override("font_color", UIText.legible(kcol))
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
	_body.text = "[center]" + EncounterDB.markup(UIText.curly(encounter["text"])) + "[/center]"
	# the prose in the bold face: 2-unit stems stay 2 px when a 1080p frame is shown phone-sized
	_body.add_theme_font_override("normal_font", UIText.BOLD)
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
	var font: Font = UIText.BOLD   # the prose face (see _build)
	var lines := UIText.wrap_lines(plain, COL_W - 12, font, UIText.BODY).size()
	return ceili(lines * UIText.line_h(font, UIText.BODY))


## "[solid] now  [ring] after", so the grid markers on every row read without a tutorial.
const AWAKEN_ICON := preload("res://ui/icons/arrow2_up.png")


func _make_legend() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = UIText.BOLD
	var any_awaken := false   # (the rows say "Awakens" themselves)
	var w := 8.0 + UIText.width("now", font, UIText.LABEL) + 6.0 + 10.0 + UIText.width("after", font, UIText.LABEL)
	if any_awaken:
		w += 10.0 + 9.0 + UIText.width("ready to Awaken", font, UIText.LABEL)
	c.custom_minimum_size = Vector2(ceilf(w), 10)
	c.draw.connect(func() -> void:
		var x := 0.0
		c.draw_rect(Rect2(x, 2, 5, 5), Pal.INK9)
		x += 8
		UIText.draw_base(c, Vector2(x, 8), "now", Pal.INK9, font, UIText.LABEL, false)
		x += UIText.width("now", font, UIText.LABEL) + 6
		var r := Rect2(x, 1, 7, 7)
		for e in [Rect2(r.position, Vector2(7, 1)), Rect2(r.position + Vector2(0, 6), Vector2(7, 1)), Rect2(r.position, Vector2(1, 7)), Rect2(r.position + Vector2(6, 0), Vector2(1, 7))]:
			c.draw_rect(e, Pal.INK10)
		x += 10
		UIText.draw_base(c, Vector2(x, 8), "after", Pal.INK9, font, UIText.LABEL, false)
		if any_awaken:
			x += UIText.width("after", font, UIText.LABEL) + 10
			c.draw_texture(AWAKEN_ICON, Vector2(x, 0), Pal.AMBER6)
			x += 9
			UIText.draw_base(c, Vector2(x, 8), "ready to Awaken", Pal.INK9, font, UIText.LABEL, false))
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
	var recruit: Dictionary = btn.choice.get("recruit", {})
	if party.size() >= 4 and party[-1].get("name", "") != recruit.get("name", ""):
		recruit = {}
	var card_h := EncounterResultCard.H
	var cont_h := int(FlowUI.PRIMARY_H)
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
	var card := EncounterResultCard.new()
	_card = card
	card.setup(hero, before, btn.choice, COL_W)
	card.position = Vector2(col_x, card_y)
	_layer.add_child(card)
	_layer.move_child(_fx, -1)
	var reveal: Array[Control] = []
	if rec_h > 0:
		reveal.append(_recruit_panel(recruit, card_y + card_h + 4))
	_continue = FlowUI.primary("Continue", COL_W)
	_continue.position = Vector2(col_x, card_y + card_h + rec_h + 6)
	_continue.size = Vector2(COL_W, cont_h)
	_continue.modulate.a = 0.0
	_continue.disabled = true
	_continue.pressed.connect(_on_continue)
	_layer.add_child(_continue)

	var chip := _chips[btn.hero_index] if btn.hero_index < _chips.size() else null
	var portrait_center := card.portrait_center() - Vector2(0, 6)
	get_tree().create_timer(0.2).timeout.connect(_spawn_flyers.bind(_art.source_point(), portrait_center, chip))
	card.landed.connect(func() -> void:
		_burst(portrait_center)
		if chip:
			chip.set_level(int(hero["level"]))
			chip.pulse())
	card.moving.connect(func() -> void:
		if chip:
			chip.grid.from_pos = before["pos"]
			chip.grid.to_pos = hero["pos"]
			create_tween().tween_property(chip.grid, "progress", 1.0, 0.6))
	card.finished.connect(func() -> void:
		for r in reveal:
			create_tween().tween_property(r, "modulate:a", 1.0, 0.2)
		if chip:
			chip.grid.from_pos = hero["pos"]
			chip.grid.progress = 0.0
		_continue.disabled = false
		create_tween().tween_property(_continue, "modulate:a", 1.0, 0.2))
	card.play()


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
	l.add_theme_color_override("font_color", UIText.legible(col))
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
	l.add_theme_color_override("font_color", UIText.legible(Pal.c(col)))
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
