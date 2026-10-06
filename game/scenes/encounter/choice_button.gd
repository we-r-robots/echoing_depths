class_name EncounterChoiceButton
extends Button
## One encounter choice, readable without hover (one focus per row, then one quiet line):
##   line 1  the action (serif, one size up)
##   line 2  Hero  arrow Cruelty +1, Freedom +1 [star] [Awakens] [+ Tamsin joins]
## The level step and the notes (strong shift, edge cap, how to read the grid) are in the tooltip
## on the mini grid.
## Right: the hero's alignment grid, solid cell = now, white ring = after this choice.
## Strong-shift rows use the same plate (so they never look selected) with gold studs and a glint.

const H := 56
## The mini grid: 9 design px cells (critic r5: 7 px cells couldn't be read at phone size).
const CELL := 9
const GRID_W := 5 * CELL + 4 + 4
## Three lines in the row: the action (serif; one step down when long), who and the move, and what
## the memory's level gives (13 px pitch for the two quiet lines, as the advancement card's lists).
const LINE1_Y := 4
const LINE1_SMALL_Y := 8
const LINE2_Y := 26
const LINE3_Y := 39
const STAT_ICONS := {
	"hp": preload("res://assets/party/stat_hp.png"), "atk": preload("res://assets/party/stat_atk.png"),
	"def": preload("res://assets/party/stat_def.png"), "mag": preload("res://assets/party/stat_mag.png"),
	"spd": preload("res://assets/party/stat_spd.png"),
}
const STAT_COLORS := {"hp": Pal.BLOOD4, "atk": Pal.AMBER5, "def": Pal.INK9, "mag": Pal.VIOLET3, "spd": Pal.LIFE4}

var choice: Dictionary
var hero: Dictionary
var hero_index := -1
var strong := false
var awakens := false
var awaken_tag: Control = null   # the "Can Awaken" mark (with its tooltip), when this choice Awakens
var level_line: HBoxContainer = null   # line 3: the level step and its stat gains
var gain: Dictionary = {}              # what the level gives ({stat: +n}); {} at the class's max level
var at_max := false
var grid: AlignGrid
var _shimmer := -1.0
var _t := 0.0


func setup(c: Dictionary, h: Dictionary, idx: int, width: int) -> void:
	choice = c
	hero = h
	hero_index = idx
	strong = EncounterDB.is_rare(c) and EncounterDB.effective_shift(h["pos"], c) == EncounterDB.shift_of(c)
	var lv := int(h["level"])
	awakens = EncounterDB.awakens_after(h)
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
	what.text = UIText.curly(String(c.get("label", "")))
	# (a label too long for the room beside the grid drops one size step, never clipped;
	# then every row on the screen does, so the rows keep one size)
	var room := width - 42 - (GRID_W + 2) - 14
	_what = what
	# serif at the title size, a step under the screen's own title (critic r4: the choices read
	# louder than the encounter's name)
	small = true
	what.position.x = 42
	_apply_size()
	_ignore(what)
	_match_rows.call_deferred()

	# line 2, quiet: who grows (class colour) and the one gain that differs between rows, the move
	# on the grid (colour only in its arrow); an Awakening or a recruit adds one amber/green word.
	# The level step, "strong shift", an edge cap and the now/after markers are in the grid's
	# tooltip (critic r3: three lines per row were too dense)
	var eff := EncounterDB.effective_shift(h["pos"], c)
	var l2 := _row(Vector2(42, LINE2_Y), 3)
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
	# an Awakening always sits in ONE place on every row (critic r6: it moved between lines): line 1,
	# right-aligned against the mini grid, glyph + words; the longest that fits ("Can Awaken",
	# "Awakens", the glyph alone). It explains itself (playtest 1): tap or hover for "<Hero> can
	# Awaken after this".
	if awakens:
		var right := float(grid_x_of(width)) - 4.0
		var title_end := 42.0 + UIText.width(what.text, UIText.SERIF, UIText.TITLE) + 4.0
		var word := ""
		for w: String in ["Can Awaken", "Awakens"]:
			if word == "" and right - (9.0 + 3.0 + UIText.width(w, UIText.BOLD, UIText.BODY)) >= title_end:
				word = w
		var tw := (9.0 + 3.0 + UIText.width(word, UIText.BOLD, UIText.BODY)) if word != "" else 9.0
		var tag := _row(Vector2(roundf(right - tw), LINE1_SMALL_Y + roundf(UIText.ascent(UIText.SERIF, UIText.TITLE) - UIText.ascent(UIText.BOLD, UIText.BODY))), 3)
		tag.add_child(_icon("res://ui/icons/arrow2_up.png", Pal.AMBER6, 2))
		if word != "":
			tag.add_child(_label(word, Pal.AMBER6, true))
		awaken_tag = tag
		# the tag's own tooltip (a 16 px hit area at least; touch reaches it with a tap)
		tag.mouse_filter = Control.MOUSE_FILTER_STOP
		tag.custom_minimum_size = Vector2(maxf(tw, 16.0), 16.0)
		Tip.attach(tag, "Awakening", awaken_hint(String(h["name"])), Pal.AMBER6)
	if c.has("recruit"):
		l2.add_child(_spacer(4))
		l2.add_child(_label("+ %s joins" % c["recruit"]["name"], Pal.LIFE4, true))
	# line 3 (playtest: "Does each hero level give bonus stats? we should make it more clear"): what
	# the memory's level gives this hero, stat icons with green gains; the words are in the tooltip
	level_line = _level_row(h, lv, float(grid_x_of(width)) - 4.0 - 42.0)
	level_line.position = Vector2(42, LINE3_Y)

	grid = AlignGrid.new()
	grid.cell = CELL
	grid.gap = 1
	grid.dot_color = cc
	grid.from_pos = h["pos"]
	grid.to_pos = EncounterDB.clamp_pos(h["pos"] + s)
	grid.show_target = true
	grid.position = Vector2(grid_x_of(width), int((H - grid.total_size()) / 2.0))
	add_child(grid)
	grid.mouse_filter = Control.MOUSE_FILTER_STOP
	Tip.attach(grid, String(h["name"]), _detail(c, h, lv, eff, s), cc)


## The row's detail for its tooltip (on the mini grid): the level step, Awakening, the move with
## its strong / capped notes, and how to read the grid.
func _detail(c: Dictionary, h: Dictionary, lv: int, eff: Vector2i, s: Vector2i) -> String:
	var out: PackedStringArray = []
	out.append(level_words(lv))
	if awakens:
		out.append(awaken_hint(String(h["name"])))
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


## The level step in words (the grid's tooltip): "Gains a memory: Lv 3 → 4: HP +10, Mag +2." or
## "Gains a memory, but Lv 6 is the max level for its class: Awaken to grow."
func level_words(lv: int) -> String:
	if at_max:
		return "Gains a memory, but Lv %d is the max level for its class%s." % [lv, ": Awaken to grow" if String(hero.get("tier", "base")) == "base" else ""]
	var g := PartyModel.gain_words(gain, ", ")
	return "Gains a memory: Lv %d → %d%s." % [lv, lv + 1, (": " + g) if g != "" else ""]


## What the hero's level gives, for line 3: the hero's real class (h["stat_class"], else h["class"]),
## level and items; the run's hero format brings "gain" / "at_max" precomputed.
static func gain_of(h: Dictionary) -> Dictionary:
	if h.has("gain"):
		return {"gain": h["gain"], "at_max": bool(h.get("at_max", false))}
	var sh := {"class": String(h.get("stat_class", h.get("class", ""))), "level": int(h.get("level", 1)),
		"items": h.get("items", {})}
	var at := int(sh["level"]) >= PartyModel.max_level(sh)
	return {"gain": {} if at else PartyModel.level_gain(sh), "at_max": at}


## Line 3: a green up-arrow, "Lv 3 → 4" and one stat icon + green "+n" per stat that grows; at the
## class's max level "Max level: Awaken to grow". Drops the "Lv 3 →" (then the arrow) to fit `room`.
func _level_row(h: Dictionary, lv: int, room: float) -> HBoxContainer:
	var gi := gain_of(h)
	gain = gi["gain"]
	at_max = bool(gi["at_max"])
	var r := _row(Vector2.ZERO, 3)
	if at_max:
		var t := "Max level: Awaken to grow" if String(h.get("tier", "base")) == "base" else "Max level for its class"
		r.add_child(_label(t, Pal.INK8, true))
		return r
	var stats_w := 0.0
	for s: String in gain:
		stats_w += 7 + 1 + UIText.width("%+d" % int(gain[s]), UIText.BOLD, UIText.BODY) + 5
	var lead := "Lv %d → %d" % [lv, lv + 1]
	if 7 + 3 + UIText.width(lead, UIText.BOLD, UIText.BODY) + 3 + stats_w > room:
		lead = "Lv %d" % (lv + 1)
	r.add_child(_icon("res://ui/icons/arrow2_up.png", Pal.LIFE4, 2))
	r.add_child(_label(lead, Pal.INK9, true))
	for s: String in gain:
		r.add_child(_spacer(2))
		r.add_child(_icon(STAT_ICONS[s].resource_path, STAT_COLORS[s], 2))
		r.add_child(_label("%+d" % int(gain[s]), Pal.LIFE4, true))
	return r


## What the "Can Awaken" mark means (its tooltip and the grid's).
static func awaken_hint(hero_name: String) -> String:
	return "%s can Awaken after this. At camp, Awaken into the class of the region %s stands in, or keep growing." % [hero_name, hero_name]


## The mini grid's left edge in a row `width` wide.
static func grid_x_of(width: int) -> int:
	return width - GRID_W - 8


var small := false   # the action label is one size step down (too long for serif 15)
var _what: Label


func _apply_size() -> void:
	_what.add_theme_font_override("font", UIText.SERIF)
	_what.add_theme_font_size_override("font_size", UIText.TITLE if small else UIText.HEADING)
	_what.position.y = LINE1_SMALL_Y if small else LINE1_Y


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
	# a strong shift: a glint runs along the plate's edges (critic r5: the gold studs read as stray ◆)
	if _shimmer >= 0.0:
		var x0 := int(-10 + _shimmer * (size.x + 20))
		for i in 3:
			for y in [1, int(size.y) - 2]:
				var px := x0 + i
				if px > 7 and px < size.x - 8:
					draw_rect(Rect2(px, y, 1, 1), Pal.AMBER7 if i == 1 else Pal.AMBER5)
