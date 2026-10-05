class_name EncounterChoiceButton
extends Button
## One encounter choice, readable without hover (one focus per row, then one quiet line):
##   line 1  the action (serif, one size up)
##   line 2  Hero  arrow Cruelty +1, Freedom +1 [star] [Awakens] [+ Tamsin joins]
## The level step and the notes (strong shift, edge cap, how to read the grid) are in the tooltip
## on the mini grid.
## Right: the hero's alignment grid, solid cell = now, white ring = after this choice.
## Strong-shift rows use the same plate (so they never look selected) with gold studs and a glint.

const H := 50

var choice: Dictionary
var hero: Dictionary
var hero_index := -1
var strong := false
var awakens := false
var grid: AlignGrid
var _shimmer := -1.0
var _t := 0.0


func setup(c: Dictionary, h: Dictionary, idx: int, width: int) -> void:
	choice = c
	hero = h
	hero_index = idx
	strong = EncounterDB.is_rare(c) and EncounterDB.effective_shift(h["pos"], c) == EncounterDB.shift_of(c)
	var thr := int(EncounterDB.rules().get("advance_threshold", 3))
	var lv := int(h["level"])
	awakens = lv < thr and lv + 1 >= thr
	theme_type_variation = &"ChoiceButton"
	custom_minimum_size = Vector2(width, H)
	size = custom_minimum_size
	focus_mode = Control.FOCUS_ALL
	text = ""
	var info := EncounterDB.class_info(h["class"])
	var cc := Pal.c(info["color"])
	var s := EncounterDB.shift_of(c)

	# portrait with class badge
	var py := int((H - 28) / 2.0)
	var frame := TextureRect.new()
	frame.texture = load("res://ui/portrait_frame.png")
	frame.position = Vector2(6, py)
	_ignore(frame)
	var por := TextureRect.new()
	por.texture = load(info["portrait"])
	por.position = Vector2(8, py + 2)
	_ignore(por)
	_ignore(_rect(Vector2(25, py + 19), Vector2(11, 11), Pal.INK1))
	_ignore(_rect(Vector2(26, py + 20), Vector2(9, 9), Pal.INK2))
	var badge := TextureRect.new()
	badge.texture = load(info["icon"])
	badge.modulate = cc
	badge.position = Vector2(27, py + 21)
	_ignore(badge)

	# line 1, the focus: the action itself, one size step up (serif), in one colour
	var what := Label.new()
	what.text = c.get("label", "")
	# (a label too long for the room beside the grid drops one size step, never clipped;
	# then every row on the screen does, so the rows keep one size)
	var room := width - 42 - (7 * 5 + 4 + 6) - 14
	_what = what
	small = UIText.width(what.text, UIText.SERIF, UIText.HEADING) > room
	what.position.x = 42
	_apply_size()
	_ignore(what)
	_match_rows.call_deferred()

	# line 2, quiet: who grows (class colour) and the one gain that differs between rows, the move
	# on the grid (colour only in its arrow); an Awakening or a recruit adds one amber/green word.
	# The level step, "strong shift", an edge cap and the now/after markers are in the grid's
	# tooltip (critic r3: three lines per row were too dense)
	var eff := EncounterDB.effective_shift(h["pos"], c)
	var l2 := _row(Vector2(42, 29), 3)
	l2.add_child(_label(String(h["name"]), cc, true))
	l2.add_child(_spacer(2))
	var shift_text := "No move"
	if eff != Vector2i.ZERO:
		var words := EncounterDB.shift_words(eff)
		var arrow_col := Pal.c(words[0]["color"]) if words.size() == 1 else Pal.INK10
		l2.add_child(_icon(EncounterDB.arrow_icon(eff), arrow_col, 2))
		var parts: PackedStringArray = []
		for w: Dictionary in words:
			parts.append("%s +%d" % [w["word"], w["amount"]])
		shift_text = ", ".join(parts)
	l2.add_child(_label(shift_text, Pal.INK9 if eff != Vector2i.ZERO else Pal.INK8, true))
	# what fits beside the grid: the strong-shift star and the word "Awakens" go first to the
	# tooltip (the gold studs still mark a strong row; the amber glyph still marks an Awakening)
	var room2 := float(width - 42 - (7 * 5 + 4) - 8 - 6)
	var used := l2.get_combined_minimum_size().x
	var aw := 3.0 + 9.0 + 3.0 + UIText.width("Awakens", UIText.BOLD, UIText.BODY)
	var star_w := 3.0 + 9.0
	var show_star := strong and used + star_w + (aw if awakens else 0.0) <= room2
	if show_star:
		l2.add_child(_icon("res://ui/icons/star.png", Pal.AMBER6, 2))
		used += star_w
	if awakens:
		l2.add_child(_spacer(2))
		l2.add_child(_icon("res://ui/icons/arrow2_up.png", Pal.AMBER6, 2))
		if used + aw <= room2:
			l2.add_child(_label("Awakens", Pal.AMBER6, true))
	if c.has("recruit"):
		l2.add_child(_spacer(4))
		l2.add_child(_label("+ %s joins" % c["recruit"]["name"], Pal.LIFE4, true))

	grid = AlignGrid.new()
	grid.cell = 7
	grid.gap = 1
	grid.dot_color = cc
	grid.from_pos = h["pos"]
	grid.to_pos = EncounterDB.clamp_pos(h["pos"] + s)
	grid.show_target = true
	grid.position = Vector2(width - grid.total_size() - 8, int((H - grid.total_size()) / 2.0))
	add_child(grid)
	grid.mouse_filter = Control.MOUSE_FILTER_STOP
	Tip.attach(grid, String(h["name"]), _detail(c, h, lv, eff, s), cc)


## The row's detail for its tooltip (on the mini grid): the level step, Awakening, the move with
## its strong / capped notes, and how to read the grid.
func _detail(c: Dictionary, h: Dictionary, lv: int, eff: Vector2i, s: Vector2i) -> String:
	var out: PackedStringArray = []
	out.append("Gains a memory: Lv %d to %d." % [lv, lv + 1])
	if awakens:
		out.append("Awakens: ready to advance to a new class.")
	if eff == Vector2i.ZERO:
		out.append("No move: already at the grid's edge.")
	else:
		var parts: PackedStringArray = []
		for w: Dictionary in EncounterDB.shift_words(eff):
			parts.append("%s +%d" % [w["word"], w["amount"]])
		out.append("Moves %s on the alignment grid." % ", ".join(parts))
		if eff != s:
			out.append("Capped at the grid's edge.")
		elif strong:
			out.append("Strong shift: two steps at once.")
	if c.has("recruit"):
		out.append("%s joins the party." % c["recruit"]["name"])
	out.append("Grid: solid cell now, ring after.")
	return " ".join(out)


var small := false   # the action label is one size step down (too long for serif 15)
var _what: Label


func _apply_size() -> void:
	_what.add_theme_font_override("font", UIText.SERIF)
	_what.add_theme_font_size_override("font_size", UIText.TITLE if small else UIText.HEADING)
	_what.position.y = 9 if small else 5


## One size for every row's action: if any sibling row needed the smaller face, all use it.
func _match_rows() -> void:
	var p := get_parent()
	if p == null:
		return
	var any := false
	for c in p.get_children():
		if c is EncounterChoiceButton and (c as EncounterChoiceButton).small:
			any = true
	if any and not small:
		small = true
		_apply_size()


func _row(pos: Vector2, sep: int) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	r.position = pos
	_ignore(r)
	return r


func _rect(pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = sz
	return r


func _ignore(n: Control) -> void:
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(n)


func _label(t: String, col: Color, bold := false) -> Label:
	var l := Label.new()
	if bold:
		l.theme_type_variation = &"GoldLabel"
	l.text = t
	l.add_theme_color_override("font_color", UIText.legible(col))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Small outlined tag: coloured text inside a 1-px border.
func _pill(t: String, col: Color, border: Color) -> Control:
	var l := _label(t, col)
	l.theme_type_variation = &"GoldLabel"
	l.add_theme_color_override("font_color", UIText.legible(col))
	var wrap := MarginContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override("margin_left", 3)
	wrap.add_theme_constant_override("margin_right", 2)
	wrap.add_child(l)
	wrap.draw.connect(func() -> void:
		var r := Rect2(Vector2(0, 1), wrap.size - Vector2(0, 1))
		wrap.draw_rect(r, Pal.INK1)
		wrap.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), border)
		wrap.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), border)
		wrap.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), border)
		wrap.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), border))
	return wrap


func _icon(path: String, col: Color, y_off: int) -> Control:
	var wrap := Control.new()
	var tex: Texture2D = load(path)
	wrap.custom_minimum_size = Vector2(tex.get_width(), 11)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.texture = tex
	r.modulate = col
	r.position = Vector2(0, y_off)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(r)
	return wrap


func _spacer(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _process(delta: float) -> void:
	if not strong:
		return
	_t += delta
	var ph := fmod(_t, 3.2)
	var new_s := ph / 0.7 if ph < 0.7 else -1.0
	if new_s != _shimmer or int(_t / 0.6) % 2 != int((_t - delta) / 0.6) % 2:
		_shimmer = new_s
		queue_redraw()


func _draw() -> void:
	# the selected row (focus or pointer): a lifted fill and a strong crystal border, so it can't
	# be mistaken for the strong-shift studs
	if has_focus() or is_hovered():
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_rect(r, Color(Pal.INK4, 0.55))
		PartyDraw.outline(self, r, Pal.CRYSTAL4)
		PartyDraw.outline(self, r.grow(-1), Color(Pal.CRYSTAL2, 0.8))
	if not strong:
		return
	# gold studs on the chamfered ends mark a strong shift
	var on := fmod(_t, 1.2) < 0.6
	var my := int(size.y / 2.0)
	for x in [2, int(size.x) - 5]:
		draw_rect(Rect2(x + 1, my - 2, 1, 1), Pal.AMBER5)
		draw_rect(Rect2(x, my - 1, 3, 2), Pal.AMBER7 if on else Pal.AMBER5)
		draw_rect(Rect2(x + 1, my + 1, 1, 1), Pal.AMBER5)
	if _shimmer >= 0.0:
		var x0 := int(-10 + _shimmer * (size.x + 20))
		for i in 3:
			for y in [1, int(size.y) - 2]:
				var px := x0 + i
				if px > 7 and px < size.x - 8:
					draw_rect(Rect2(px, y, 1, 1), Pal.AMBER7 if i == 1 else Pal.AMBER5)
