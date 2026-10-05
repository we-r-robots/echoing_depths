class_name FormationPanel
extends Control
## Right half of the formation setup screen: what the arrangement on the board IS, live.
## Lore name and size, active / locked / preview status, the bonus, behaviour and cost in plain
## words, the Training Grounds unlock (a locked shape fights as Strays), and the growth path:
## the smaller shape it grows from and what one more hero grows it into.

const W := 324
const H := 296
const BUFF := preload("res://assets/party_setup/buff.png")
const DEBUFF := preload("res://assets/party_setup/debuff.png")
const BEHAV := preload("res://assets/party_setup/behaviour.png")
const GROW := preload("res://assets/party_setup/grow.png")
const LOCK := preload("res://assets/party/lock.png")
const CHEVRON := preload("res://ui/icons/chevron.png")

var cells: Array = []           # placed cells to describe
var unlocked: Array = []
var placed := 0
var party_size := 0
var preview := false            # describing a drag preview, not the current board
var bases: Array = []           # base class of every hero in the party (class bonds)
var details := false            # the Details view: full texts, class bonds, growth path
var placing := false            # a hero is held or dragged: the growth path shows
var _ev := {}
var _shown_id := ""
var _flash := 0.0
var _t := 0.0


var _details_btn: Button


func _ready() -> void:
	size = Vector2(W, H)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_btn = Button.new()
	_details_btn.text = "Details"
	_details_btn.focus_mode = Control.FOCUS_NONE
	_details_btn.position = Vector2(W - 72, 30)
	_details_btn.size = Vector2(62, 18)
	_details_btn.pressed.connect(toggle_details)
	add_child(_details_btn)


## Tap: the glance view <-> full texts, class bonds and the growth path.
func toggle_details() -> void:
	details = not details
	_details_btn.text = "Less" if details else "Details"
	queue_redraw()


func show_cells(c: Array, unlocked_ids: Array, n_placed: int, n_party: int, is_preview := false, base_ids: Array = []) -> void:
	cells = c.duplicate(true)
	bases = base_ids.duplicate()
	unlocked = unlocked_ids
	placed = n_placed
	party_size = n_party
	preview = is_preview
	_ev = FormationWords.evaluate(cells, unlocked)
	var sid := String(_ev["shape"].get("id", ""))
	if sid != _shown_id:
		_flash = 1.0
		_shown_id = sid
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		queue_redraw()
	elif preview or bool(_ev.get("locked", false)):
		queue_redraw()


func _draw() -> void:
	PartyDraw.panel(self, Rect2(0, 0, W, H), 54)
	if _ev.is_empty():
		return
	var shape: Dictionary = _ev["shape"]
	_details_btn.visible = not shape.is_empty()
	if shape.is_empty():
		_draw_empty()
		return
	var sid := String(shape["id"])
	var locked: bool = _ev["locked"]
	var strays := sid == "strays"
	_draw_title(shape, locked, strays)
	if details:
		_draw_details(shape, locked, strays)
	else:
		_draw_main(shape, locked, strays)


## The glance view: one bonus, one cost, the behaviour in one short line. Large type, space.
func _draw_main(shape: Dictionary, locked: bool, strays: bool) -> void:
	var y := 70
	if locked:
		y = _draw_locked_banner(shape, y) + 2
	var dim := locked
	var grow_top := H
	if placing:
		grow_top = _draw_growth(shape, strays) - 6
	y = _big_block(y, "BONUS" + (" IF UNLOCKED" if dim else ""), BUFF, FormationWords.mod_lines(shape.get("bonus", [])),
		Pal.FADE3 if dim else Pal.LIFE4)
	y += 12
	y = _big_block(y, "COST", DEBUFF, FormationWords.cost_lines(shape), Pal.FADE3 if dim else Pal.BLOOD4)
	y += 12
	if y + 34 > grow_top:
		return
	PartyDraw.text(self, Vector2(12, y), "BEHAVIOUR" + (" IF UNLOCKED" if dim else ""), Pal.INK7, PartyDraw.BOLD, 11, false)
	y += 13
	var b: Dictionary = shape.get("behaviour", {})
	PartyDraw.tint_tex(self, BEHAV, Vector2(12, y + 2), Pal.FADE3 if dim else Pal.CRYSTAL4)
	PartyDraw.text(self, Vector2(23, y), String(b.get("name", "")), Pal.FADE4 if dim else Pal.CRYSTAL5, PartyDraw.BOLD)
	y += 12
	_para(FormationWords.behaviour_short(shape), Vector2(23, y), W - 34, Pal.FADE3 if dim else Pal.INK9, PartyDraw.BOLD)


## Label + lines set in the serif (the large face), icon on the first line.
func _big_block(y: int, label: String, icon: Texture2D, lines: Array, color: Color) -> int:
	PartyDraw.text(self, Vector2(12, y), label, Pal.INK7, PartyDraw.BOLD, 11, false)
	y += 13
	var first := true
	for l: String in lines:
		for wl: String in BigText.wrap(l, W - 40):
			if first:
				PartyDraw.tint_tex(self, icon, Vector2(12, y + 6), color)
				first = false
			BigText.draw(self, Vector2(24, y), wl, color)
			y += 16
	return y


## Details: every number and the full texts, class bonds and the growth path.
func _draw_details(shape: Dictionary, locked: bool, strays: bool) -> void:
	var y := 64
	if locked:
		y = _draw_locked_banner(shape, y)
	var dim := locked
	var tag := "  if unlocked" if locked else ""
	# bonus
	PartyDraw.header(self, Vector2(10, y), W - 20, "Bonus" + tag, Pal.INK7)
	y += 13
	for line: String in FormationWords.mod_lines(shape.get("bonus", [])):
		PartyDraw.tint_tex(self, BUFF, Vector2(12, y + 3), Pal.FADE3 if dim else Pal.LIFE4)
		PartyDraw.text(self, Vector2(23, y), line, Pal.FADE3 if dim else Pal.LIFE4, PartyDraw.BOLD)
		y += 12
	y += 4
	# behaviour
	var b: Dictionary = shape.get("behaviour", {})
	PartyDraw.header(self, Vector2(10, y), W - 20, "Behaviour" + tag, Pal.INK7)
	y += 13
	PartyDraw.tint_tex(self, BEHAV, Vector2(12, y + 2), Pal.FADE3 if dim else Pal.CRYSTAL4)
	PartyDraw.text(self, Vector2(23, y), String(b.get("name", "")), Pal.FADE4 if dim else Pal.CRYSTAL5, PartyDraw.BOLD)
	y += 12
	y = _para(String(b.get("text", "")), Vector2(23, y), W - 34, Pal.FADE3 if dim else Pal.INK9, PartyDraw.BOLD)
	y += 4
	# cost
	PartyDraw.header(self, Vector2(10, y), W - 20, "Cost", Pal.INK7)
	y += 13
	PartyDraw.tint_tex(self, DEBUFF, Vector2(12, y + 3), Pal.FADE3 if dim else Pal.BLOOD4)
	y = _para(". ".join(FormationWords.cost_lines(shape)) + ".", Vector2(23, y), W - 34, Pal.FADE3 if dim else Pal.BLOOD4, PartyDraw.BOLD)
	var gy := _draw_growth(shape, strays)
	_draw_bonds(y + 4, gy - 4)


## Class bonds (core compositions): small, always on, independent of the shape.
func _draw_bonds(y: int, limit: int) -> void:
	var comps := FormationWords.Formation.compositions(bases)
	var need := 13 + maxi(1, comps.size()) * 12
	if y + need > limit:
		return
	PartyDraw.header(self, Vector2(10, y), W - 20, "Class bonds", Pal.INK7)
	y += 13
	if comps.is_empty():
		PartyDraw.text(self, Vector2(12, y), "None: two of one class, or four different classes, add one.", Pal.INK6)
		return
	for comp: Dictionary in comps:
		var nm := String(comp["name"])
		PartyDraw.tint_tex(self, BUFF, Vector2(12, y + 3), Pal.AMBER5)
		PartyDraw.text(self, Vector2(23, y), nm, Pal.AMBER6, PartyDraw.BOLD)
		var words: Array = FormationWords.mod_lines(comp["mods"])
		var line := ", ".join(words).replace("Everyone: ", "everyone ")
		if comp["when"].has("base"):
			line = line.replace("Class: ", PartyModel.class_name_of(String(comp["when"]["base"])) + "s: ")
		PartyDraw.text(self, Vector2(27 + PartyDraw.text_w(nm, PartyDraw.BOLD), y), line, Pal.INK8)
		y += 12


func _draw_empty() -> void:
	PartyDraw.text(self, Vector2(12, 8), "No formation yet", Pal.INK8, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	var sub := "Place a hero on the grid" if placed == 0 else "One hero stands alone"
	PartyDraw.text(self, Vector2(12, 26), sub, Pal.INK7)
	var y := 52
	PartyDraw.header(self, Vector2(10, y), W - 20, "How shapes work", Pal.INK7)
	y += 14
	var lines := [
		"Heroes standing edge to edge make a shape.",
		"2 heroes make a domino, 3 a tromino, 4 a tetromino.",
		"Each shape grows from a smaller one plus one hero.",
		"Every shape gives a bonus and a behaviour, and has a cost.",
		"Heroes placed apart fight as Strays.",
	]
	for l: String in lines:
		draw_texture(PLUS_DOT, Vector2(14, y + 4), Pal.CRYSTAL3)
		y = _para(l, Vector2(23, y), W - 34, Pal.INK9)
		y += 3


const PLUS_DOT := preload("res://assets/party/dot.png")


func _draw_title(shape: Dictionary, locked: bool, strays: bool) -> void:
	# glyph well
	var gw := Rect2(8, 7, 40, 46)
	PartyDraw.inset(self, gw)
	var fill := Pal.CRYSTAL4
	if strays:
		fill = Pal.FADE3
	elif locked:
		fill = Pal.FADE3
	var gcells := cells
	# measure, then centre
	var gs := Vector2.ZERO
	var hrows := 1
	var minr := 99
	var maxr := 0
	for c: Array in gcells:
		minr = mini(minr, int(c[1]))
		maxr = maxi(maxr, int(c[1]))
	hrows = maxr - minr + 1
	if strays:
		hrows = 4
	gs = Vector2(17, hrows * 8 + hrows - 1)
	var gp := (gw.position + (gw.size - gs) / 2.0).floor()
	FormationWords.draw_glyph(self, gp, gcells, 8, fill, Pal.INK2, 4 if strays else 0, false,
		Pal.CRYSTAL5 if not strays and not locked else Color(0, 0, 0, 0))
	# name
	var ncol := Pal.AMBER6
	if strays:
		ncol = Pal.FADE4
	elif locked:
		ncol = Pal.FADE4
	if _flash > 0.5:
		ncol = Pal.AMBER7 if not strays else Pal.INK10
	var nm := String(shape["name"])
	PartyDraw.text(self, Vector2(56, 9), nm, ncol, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	var sub := ""
	if strays:
		sub = "Not all joined edge to edge"
	else:
		sub = "%s  ·  %d heroes" % [FormationWords.size_word(shape), int(shape["size"])]
	if placed < party_size and not strays:
		sub += "  ·  %d of %d placed" % [placed, party_size]
	PartyDraw.text(self, Vector2(56, 31), sub, Pal.INK8, PartyDraw.BOLD)
	# status pill, top right
	var label := "ACTIVE"
	var fg := Pal.CRYSTAL5
	var bg := Pal.CRYSTAL1
	var edge := Pal.CRYSTAL3
	if preview:
		label = "IF PLACED HERE"
		fg = Pal.AMBER6
		bg = Pal.AMBER1
		edge = Pal.AMBER4
	elif strays:
		label = "STRAYS"
		fg = Pal.FADE4
		bg = Pal.FADE1
		edge = Pal.FADE2
	elif locked:
		label = "LOCKED"
		fg = Pal.FADE4
		bg = Pal.FADE1
		edge = Pal.FADE3
	var w := PartyDraw.text_w(label, PartyDraw.BOLD) + 6 + (8 if locked and not preview else 0)
	var px := W - 10 - w
	var pr := Rect2(px, 11, w, 11)
	draw_rect(pr, bg)
	PartyDraw.soft_outline(self, pr, edge)
	var tx := px + 3
	if locked and not preview:
		draw_texture(LOCK, Vector2(tx, 13), fg)
		tx += 8
	PartyDraw.text(self, Vector2(tx, 12), label, fg, PartyDraw.BOLD, 11, false)


func _draw_locked_banner(shape: Dictionary, y: int) -> int:
	var hint := FormationWords.unlock_hint(String(shape["id"]), unlocked)
	var lines := _wrap(hint, W - 40, PartyDraw.BOLD).size()
	var r := Rect2(8, y, W - 16, 16 + lines * 11)
	draw_rect(r, Pal.FADE1)
	PartyDraw.soft_outline(self, r, Pal.FADE2)
	draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1), Pal.FADE2)
	draw_texture(LOCK, Vector2(14, y + 5), Pal.FADE4)
	PartyDraw.text(self, Vector2(23, y + 3), "Locked: fights as Strays", Pal.INK10, PartyDraw.BOLD)
	PartyDraw.text(self, Vector2(23 + PartyDraw.text_w("Locked: fights as Strays ", PartyDraw.BOLD), y + 3),
		"(Spd +5%, crit +5%)", Pal.FADE4)
	_para(hint, Vector2(23, y + 14), W - 40, Pal.FADE4, PartyDraw.BOLD)
	return int(r.end.y) + 6


## Growth path as a small tree: the shapes it grows from -> this shape -> what one more hero
## grows it into (only options with a free slot on the board right now).
func _draw_growth(shape: Dictionary, strays: bool) -> int:
	var from := FormationWords.parents(cells)
	var into := FormationWords.children(cells)
	var n := maxi(1, maxi(from.size(), into.size()))
	var rows_h := n * 21 - 2
	var y := H - 10 - rows_h - 26
	if strays:
		y = H - 40
	var top := y
	PartyDraw.header(self, Vector2(10, y), W - 20, "Growth path", Pal.INK7)
	y += 14
	if strays:
		PartyDraw.tint_tex(self, GROW, Vector2(12, y + 2), Pal.INK6)
		_para("Join every hero edge to edge to form a shape. Strays never grow.", Vector2(23, y), W - 34, Pal.INK8)
		return top
	const PX := 10
	const CX := 134
	const KX := 182
	PartyDraw.text(self, Vector2(PX, y), "GROWS FROM", Pal.INK6, PartyDraw.SANS, 11, false)
	PartyDraw.text(self, Vector2(CX - 8, y), "NOW", Pal.INK6, PartyDraw.SANS, 11, false)
	PartyDraw.text(self, Vector2(KX, y), "WITH ONE MORE HERO", Pal.INK6, PartyDraw.SANS, 11, false)
	y += 12
	var cy := y + roundi(rows_h / 2.0)
	# current shape node
	var cur := Rect2(CX - 10, cy - 14, 22, 28)
	draw_rect(cur, Pal.CRYSTAL1)
	PartyDraw.soft_outline(self, cur, Pal.CRYSTAL4)
	var gh := _glyph_h(cells, 4)
	FormationWords.draw_glyph(self, Vector2(cur.position.x + 6, cy - roundi(gh / 2.0)), cells, 4, Pal.CRYSTAL4, Pal.INK2, 0, false, Pal.CRYSTAL5)
	# parents
	if from.is_empty():
		_para("Two heroes side by side: the first shapes", Vector2(PX, cy - 11), 100, Pal.INK7)
	else:
		var py := cy - roundi((from.size() * 21 - 2) / 2.0)
		for s: Dictionary in from:
			var right := _chip(s, PX, py)
			_link(Vector2(right, py + 9), Vector2(cur.position.x - 1, cy))
			py += 21
	# children
	if int(shape["size"]) >= 4:
		_para("Full grown: four heroes is the largest party.", Vector2(KX, cy - 11), W - KX - 10, Pal.INK7)
	elif into.is_empty():
		_para("No free slot to grow into: slide the shape.", Vector2(KX, cy - 11), W - KX - 10, Pal.INK7)
	else:
		var ky := cy - roundi((into.size() * 21 - 2) / 2.0)
		for e: Dictionary in into:
			_chip(e["shape"], KX, ky)
			_link(Vector2(cur.end.x, cy), Vector2(KX - 1, ky + 9))
			ky += 21
	return top


static func _glyph_h(cs: Array, px: int) -> int:
	var lo := 99
	var hi := 0
	for c: Array in cs:
		lo = mini(lo, int(c[1]))
		hi = maxi(hi, int(c[1]))
	var h := hi - lo + 1
	return h * px + h - 1


## Elbow connector between tree nodes.
func _link(a: Vector2, b: Vector2) -> void:
	var mx := roundi((a.x + b.x) / 2.0)
	draw_rect(Rect2(a.x, a.y, mx - a.x, 1), Pal.INK5)
	draw_rect(Rect2(mx, mini(a.y, b.y), 1, absi(int(b.y - a.y)) + 1), Pal.INK5)
	draw_rect(Rect2(mx, b.y, b.x - mx, 1), Pal.INK5)
	draw_rect(Rect2(b.x - 2, b.y - 1, 1, 3), Pal.INK6)


## A small shape chip: glyph + name (+ lock when locked). Returns its right edge.
func _chip(s: Dictionary, x: int, y: int) -> int:
	var ok := FormationWords.is_unlocked(String(s["id"]), unlocked)
	var nm := String(s["name"])
	var w := 4 + 7 + 5 + PartyDraw.text_w(nm, PartyDraw.BOLD) + (9 if not ok else 0) + 4
	var r := Rect2(x, y, w, 19)
	draw_rect(r, Pal.INK2 if ok else Pal.INK1)
	PartyDraw.soft_outline(self, r, Pal.INK5 if ok else Pal.FADE1)
	var sc: Array = s["cells"]
	var gh := _glyph_h(sc, 3)
	FormationWords.draw_glyph(self, Vector2(x + 4, y + roundi((19 - gh) / 2.0)), sc, 3, Pal.CRYSTAL4 if ok else Pal.FADE2, Pal.INK3, 0, false)
	var tx := x + 16
	if not ok:
		draw_texture(LOCK, Vector2(tx, y + 7), Pal.FADE3)
		tx += 9
	PartyDraw.text(self, Vector2(tx, y + 4), nm, Pal.INK10 if ok else Pal.FADE3, PartyDraw.BOLD)
	return x + w


## Word-wrapped paragraph; returns the y below it.
func _para(s: String, pos: Vector2, width: int, color: Color, font: Font = PartyDraw.SANS) -> int:
	var y := int(pos.y)
	for line: String in _wrap(s, width, font):
		PartyDraw.text(self, Vector2(pos.x, y), line, color, font)
		y += 11
	return y


static func _wrap(s: String, width: int, font: Font, fsize := 11) -> Array:
	var out: Array = []
	var line := ""
	for wd in s.split(" "):
		var trial := wd if line == "" else line + " " + wd
		if PartyDraw.text_w(trial, font, fsize) > width and line != "":
			out.append(line)
			line = wd
		else:
			line = trial
	if line != "":
		out.append(line)
	return out
