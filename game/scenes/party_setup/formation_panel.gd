class_name FormationPanel
extends Control
## The one shape card beside the board: the shape's name and glyph, its status, and a row of
## effect icons (shared EffectIcons / EffectChip; each opens the shared Tip with the full sentence).
## Details shows the same sentences in the same order (bonus, behaviour, cost, class bonds) with the
## same icons, plus the growth path. A locked shape fights as Strays: said once, here.

const W := 208
const H := 318
const TITLE_SIZE := 20      # serif: one step over the effect rows (UIText.HEADING)
## The card's foot: the Details button and the primary Confirm (28 design px tall).
const FOOT := 38
const LOCK := preload("res://assets/party/lock.png")
const DOT := preload("res://assets/party/dot.png")

var cells: Array = []
var names: Array = []           # hero name per cell (for naming roles)
var unlocked: Array = []
var placed := 0
var party_size := 0
var preview := false
var bases: Array = []
var details := false
var _ev := {}
var _effects: Array = []
var _chips: Array[EffectChip] = []
var _lock_tip: Control
var _sig := ""
var _flash := 0.0
var _details_btn: Button
var _was_open := false
## Extra foot height for a second button over Confirm (the camp's review mode adds Back).
var extra_foot := 0
## Why Confirm is disabled (set by FormationSetup), shown on the note line; "" when it isn't.
var confirm_note := "":
	set(v):
		if v != confirm_note:
			confirm_note = v
			queue_redraw()
## The note line over the foot: its own reserved line (critic r6: the hint was drawn over the
## GREW FROM heading). Rows and the growth block end above it.
const NOTE_H := 14
## Height of the growth block (divider, heading, one row of shape chips).
const GROWTH_H := 40
var _show_growth := false


func _ready() -> void:
	size = Vector2(W, H)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_btn = Button.new()
	_details_btn.text = "Details"
	_details_btn.focus_mode = Control.FOCUS_NONE
	_details_btn.position = Vector2(8, H - 32)
	_details_btn.size = Vector2(62, 22)
	_details_btn.pressed.connect(toggle_details)
	add_child(_details_btn)
	_lock_tip = Control.new()
	_lock_tip.mouse_filter = Control.MOUSE_FILTER_STOP
	_lock_tip.visible = false
	add_child(_lock_tip)


## Details (BUILD.md: the one exemption from effects-as-icons): every effect's full sentence with
## its icon, plus the growth path, in the shared tooltip box in the card's own empty lower half (it
## grows up over the card's rows if it must), so it never covers the board's heroes or name plates.
func toggle_details() -> void:
	details = not details
	Tip.close()
	if details:
		Tip.set_zone(free_zone())
		Tip.attach(_details_btn, _details_title(), "", Pal.AMBER5, "zone", {"entries": _details_entries(), "wire": false})
		Tip.show_for(_details_btn)
	_details_btn.text = "Close" if details else "Details"
	queue_redraw()


func _details_title() -> String:
	var shape: Dictionary = _ev.get("shape", {})
	match String(_ev.get("state", "")):
		"unformed", "locked_unformed":
			return "No formation"
		"locked_fallback":
			return "%s, fighting as %s" % [shape.get("name", ""), _ev["effective"].get("name", "")]
	return String(shape.get("name", ""))


func _details_entries() -> Array:
	var out: Array = []
	if _ev.is_empty():
		return out
	var shape: Dictionary = _ev["shape"]
	if bool(_ev["locked"]):
		var as_text := "fighting as %s." % _ev["effective"]["name"] if String(_ev["state"]) == "locked_fallback" else "no formation."
		out.append({"effect": {"icon": preload("res://ui/effect_icons/lock.png"), "sign": 0, "kind": "note"},
			"text": "%s is locked: %s %s" % [shape["name"], as_text, FormationWords.unlock_hint(String(shape["id"]), unlocked)]})
	for e: Dictionary in _effects:
		out.append({"effect": e, "text": String(e["text"])})
	if String(_ev["state"]) in ["strays", "unformed", "locked_unformed"]:
		return out
	var names_of := func(list: Array) -> String:
		var n: PackedStringArray = []
		for sh: Dictionary in list:
			n.append(String(sh["name"]) + ("" if FormationWords.is_unlocked(String(sh["id"]), unlocked) else " (locked)"))
		return ", ".join(n)
	var from := FormationWords.parents(cells)
	if from.is_empty():
		out.append({"effect": {}, "text": "Grows from: nothing. It's a first shape (two heroes)."})
	else:
		out.append({"effect": {}, "text": "Grows from: %s." % names_of.call(from)})
	var into: Array = []
	for e: Dictionary in FormationWords.children(cells):
		into.append(e["shape"])
	if int(shape.get("size", 0)) >= 4:
		out.append({"effect": {}, "text": "Full grown: four is the most."})
	elif into.is_empty():
		out.append({"effect": {}, "text": "With one more hero: no free slot to grow into."})
	else:
		out.append({"effect": {}, "text": "With one more hero: %s." % names_of.call(into)})
	return out


func show_cells(c: Array, unlocked_ids: Array, n_placed: int, n_party: int, is_preview := false,
		base_ids: Array = [], hero_names: Array = []) -> void:
	cells = c.duplicate(true)
	names = hero_names.duplicate()
	bases = base_ids.duplicate()
	unlocked = unlocked_ids
	placed = n_placed
	party_size = n_party
	preview = is_preview
	_ev = FormationWords.evaluate(cells, unlocked)
	var shape: Dictionary = _ev["shape"]
	var eff: Dictionary = _ev["effective"]
	var sid := String(shape.get("id", ""))
	var state := String(_ev["state"])
	var bonds: Array = FormationWords.Formation.compositions(bases)
	# effects that apply: the effective shape's (named by the heroes forming it), plus class bonds
	var sub: Array = _ev["sub_cells"]
	var sub_names: Array = []
	for sc: Array in sub:
		for k in cells.size():
			if int(cells[k][0]) == int(sc[0]) and int(cells[k][1]) == int(sc[1]) and k < names.size():
				sub_names.append(names[k])
	var who := EffectIcons.who_of(String(eff.get("id", "")), sub, sub_names) if sub.size() == sub_names.size() else {}
	_effects = []
	_locked_effects = []
	if state in ["unformed", "locked_unformed"]:
		_effects = [NO_FORMATION] + EffectIcons.formation_effects({}, {}, bonds)
	elif not eff.is_empty():
		_effects = EffectIcons.formation_effects(eff, who, bonds)
	if bool(_ev["locked"]):
		_locked_effects = EffectIcons.formation_effects(shape, EffectIcons.who_of(sid, cells, names), [])
	var sig := "%s|%s|%s|%s|%s" % [sid, state, str(eff.get("id", "")), str(who), str(bases)]
	if sig != _sig:
		if sid != _sig.get_slice("|", 0):
			_flash = 1.0
		_sig = sig
		_rebuild_chips()
	queue_redraw()


const GROUPS := [["note", "NO FORMATION", Pal.INK9], ["stat+", "GAINS", Pal.LIFE4], ["behaviour", "BEHAVIOUR", Pal.CRYSTAL4],
	["cost", "COSTS", Pal.BLOOD4], ["bond", "CLASS BOND", Pal.AMBER5]]
const NO_FORMATION := {"icon": preload("res://ui/effect_icons/cost_capped.png"), "sign": 0, "kind": "note",
	"title": "No bonus, no cost", "name": "No formation",
	"text": "These heroes are partly joined but don't make a shape, so no formation applies: no bonus and no cost. Join everyone into one shape, or spread everyone apart as Strays."}
var _locked_effects: Array = []
const ROW := 26
var _sections: Array = []       # [y, label, color] section headers drawn on the card
var _growth_y := 0


static func _group_of(e: Dictionary) -> String:
	var k := String(e["kind"])
	if k == "stat":
		return "stat+" if int(e["sign"]) > 0 else "cost"
	return k


## Rows in the Sea of Stars shop rhythm: one row per effect, evenly spaced, one body size;
## colour only in the icon and its arrow. Gains and behaviour, a light divider, costs, a light
## divider, class bond and (for a locked shape) one greyed "N locked effects" line.
func _rebuild_chips() -> void:
	for ch in _chips:
		Tip.detach(ch)
		ch.queue_free()
	_chips.clear()
	_sections.clear()
	_lock_tip.visible = false
	_growth_y = 0
	if _ev.is_empty() or (_ev["shape"] as Dictionary).is_empty():
		return
	var blocks := [["note", "stat+", "behaviour"], ["cost"], ["bond"]]
	var groups: Array = []
	var n_rows := 0
	for blk: Array in blocks:
		var items: Array = []
		for e: Dictionary in _effects:
			if blk.has(_group_of(e)):
				items.append(e)
		if blk[0] == "bond" and bool(_ev["locked"]):
			items.append(_locked_row())
		if not items.is_empty():
			groups.append(items)
			n_rows += items.size()
	# rows keep their height; the growth block shows only when it fits whole above the note line
	var bottom := _note_y() - 2
	var rows_end := 66 + n_rows * ROW + maxi(groups.size() - 1, 0) * 7
	var want_growth := String(_ev["state"]) == "active"
	_show_growth = want_growth and rows_end + 4 + GROWTH_H <= bottom
	var y := 66
	var first := true
	for items: Array in groups:
		if not first:
			_sections.append([y + 2, "", Pal.INK4])   # a light divider
			y += 7
		first = false
		for e: Dictionary in items:
			if y + EffectIcons.CHIP > bottom:
				break
			var chip := EffectChip.new()
			add_child(chip)
			chip.position = Vector2(10, y)
			# every row's tooltip opens on the card, directly under (or over) its own row with a
			# caret on the row's icon (never over the board, critic r3; never docked under the
			# list, critic r6); the row it belongs to stays lit
			chip.label_size = UIText.HEADING
			chip.setup(e, "row", W - 40)
			chip.locked = bool(e.get("_locked", false))
			_chips.append(chip)
			y += ROW
	_growth_y = y + 4


## ONE greyed line standing for the locked shape's own effects; its tooltip lists them.
func _locked_row() -> Dictionary:
	var shape: Dictionary = _ev["shape"]
	var n := 0
	var lines: Array = []
	for e: Dictionary in _locked_effects:
		if String(e["kind"]) == "bond":
			continue
		n += 1
		lines.append(String(e["text"]))
	return {"icon": preload("res://ui/effect_icons/lock.png"), "sign": 0, "kind": "note", "_locked": true,
		"title": "%d locked effects" % n, "name": "%s (locked)" % shape["name"],
		"text": "Once unlocked at the Training Grounds: " + " ".join(lines)}


## Demo / tutorial: open the tooltip of effect chip k.
func open_tip(k: int) -> void:
	if k >= 0 and k < _chips.size():
		Tip.show_for(_chips[k])


## The card's empty lower half (global rect): under the rows and the growth block, above the buttons.
func free_zone() -> Rect2:
	return get_global_transform() * _zone_local()


func _note_y() -> int:
	return H - FOOT - extra_foot - NOTE_H


func _zone_local() -> Rect2:
	var top := float(_growth_y)
	if _show_growth and top > 0.0:
		top += float(GROWTH_H)   # the growth block
	var foot := H - FOOT - extra_foot
	top = clampf(top, 66.0, float(foot) - 40.0)
	return Rect2(4, top, W - 8, foot - 4 - top)


## The note line, reserved over the foot: why Confirm is disabled ("Place 1 more hero to confirm"),
## else the quiet hint that effects open their full text. Hidden while a tooltip is open.
func _draw_note() -> void:
	if details or Tip.any_open():
		return
	var y := _note_y()
	if confirm_note != "":
		PartyDraw.text(self, Vector2(8, y), confirm_note, Pal.AMBER6, PartyDraw.BOLD, UIText.BODY, true, W - 16, HORIZONTAL_ALIGNMENT_CENTER)
	elif not (_ev.get("shape", {}) as Dictionary).is_empty():
		PartyDraw.text(self, Vector2(8, y), "Tap an effect for the full text", Pal.INK8, PartyDraw.BOLD, UIText.BODY, false, W - 16, HORIZONTAL_ALIGNMENT_CENTER)


func _process(delta: float) -> void:
	Tip.set_zone(free_zone())
	var open := Tip.any_open()
	if open != _was_open:
		_was_open = open
		queue_redraw()
	if details and not Tip.is_open_for(_details_btn):
		details = false
		_details_btn.text = "Details"
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		queue_redraw()


func _draw() -> void:
	PartyDraw.panel(self, Rect2(0, 0, W, H), 58)
	if _ev.is_empty():
		return
	var shape: Dictionary = _ev["shape"]
	_details_btn.visible = not shape.is_empty()
	if shape.is_empty():
		_draw_empty()
		_draw_note()
		return
	var locked: bool = _ev["locked"]
	var strays := String(_ev["state"]) in ["strays", "unformed"]
	_draw_title(shape, locked, strays)
	for sec: Array in _sections:
		draw_rect(Rect2(10, sec[0], W - 20, 1), Pal.INK3)
	# an open reading pane masks the growth block (critic r4: its chips showed as stubs under it)
	if not _pane_open():
		_draw_growth_block(shape, strays)
	_draw_note()


func _pane_open() -> bool:
	if Tip.is_open_for(_details_btn):
		return true
	for c: Control in _chips:
		if is_instance_valid(c) and Tip.is_open_for(c):
			return true
	return false


## Fills the card's foot: what one more hero would make (or, at four, what it grew from).
func _draw_growth_block(shape: Dictionary, strays: bool) -> void:
	var top := maxi(_growth_y, 0)
	if top <= 0 or not _show_growth or strays:
		return
	# docked under the rows (a divider, then the block), not at the card's foot
	draw_rect(Rect2(10, top - 1, W - 20, 1), Pal.INK3)
	var y := top + 7
	var list: Array = []
	var title := ""
	if int(_ev["effective"].get("size", 0)) >= 4 or placed < 2:
		title = "GREW FROM"
		list = FormationWords.parents(_ev["sub_cells"])
	else:
		title = "WITH ONE MORE HERO"
		for e: Dictionary in FormationWords.children(_ev["sub_cells"] if not (_ev["sub_cells"] as Array).is_empty() else cells):
			list.append(e["shape"])
	PartyDraw.text(self, Vector2(10, y), title, Pal.INK8, PartyDraw.BOLD, UIText.BODY, false)
	y += 12
	if list.is_empty():
		PartyDraw.text(self, Vector2(10, y + 3), "No free slot to grow", Pal.INK8, PartyDraw.BOLD)
		return
	var x := 8
	for sh: Dictionary in list:
		var w := _chip_w(sh)
		if x + w > W - 8:
			break
		_chip(sh, x, y)
		x += w + 4


func _draw_empty() -> void:
	PartyDraw.text(self, Vector2(12, 10), "No shape yet", Pal.INK8, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	PartyDraw.text(self, Vector2(12, 31), "Place heroes side by side", Pal.INK9, PartyDraw.BOLD)
	var y := 72
	for l: String in ["Heroes edge to edge make a shape.", "Each shape grows from a smaller one.", "Apart, they fight as Strays."]:
		draw_texture(DOT, Vector2(12, y + 4), Pal.CRYSTAL3)
		y = _para(l, Vector2(22, y), W - 32, Pal.INK9, PartyDraw.BOLD) + 4


## Title: the whole 2x4 placement as a glyph (the heroes forming the active shape lit), the
## shape's name, a status pill and one plain line saying what fights.
func _draw_title(shape: Dictionary, locked: bool, strays: bool) -> void:
	var state := String(_ev["state"])
	var gw := Rect2(8, 8, 40, 46)
	PartyDraw.inset(self, gw)
	var gp := (gw.position + (gw.size - Vector2(17, 35)) / 2.0).floor()
	FormationWords.draw_glyph(self, gp, cells, 8, Pal.FADE2 if state != "strays" else Pal.INK7, Pal.INK2, 4, false)
	var sub_cells: Array = _ev["sub_cells"]
	if not sub_cells.is_empty():
		FormationWords.draw_glyph(self, gp, sub_cells, 8, Pal.CRYSTAL4, Color(0, 0, 0, 0), 4, false, Pal.CRYSTAL5)
	var ncol := Pal.AMBER6
	match state:
		"strays", "unformed":
			ncol = Pal.INK9
		"locked_fallback", "locked_unformed":
			ncol = Pal.FADE4
	if _flash > 0.5:
		ncol = Pal.AMBER7 if state == "active" else Pal.INK10
	var nm := String(shape["name"])
	if state == "locked_fallback":
		nm = String(_ev["effective"]["name"])   # the shape that fights is the headline
		ncol = Pal.AMBER6 if _flash <= 0.5 else Pal.AMBER7
	elif state == "locked_unformed":
		nm = "No formation"
		ncol = Pal.INK9
	# the panel's title is its largest text (critic r5: it sat a step under the effect rows)
	var tsz := TITLE_SIZE if PartyDraw.text_w(nm, PartyDraw.SERIF, TITLE_SIZE) <= W - 56 - 6 else PartyDraw.SERIF_SIZE
	PartyDraw.text(self, Vector2(56, 5 if tsz == TITLE_SIZE else 8), nm, ncol, PartyDraw.SERIF, tsz)
	var label := "ACTIVE"
	var fg := Pal.CRYSTAL5
	var bg := Pal.CRYSTAL1
	var edge := Pal.CRYSTAL3
	var line := FormationWords.size_word(shape)
	var line_col := Pal.INK9
	match state:
		"strays":
			label = "ACTIVE"
			line = "nobody side by side"
		"unformed":
			label = "NONE"
			fg = Pal.INK9
			bg = Pal.INK2
			edge = Pal.INK5
			line = "not a shape"
		"locked_fallback":
			line = "%s locked" % shape["name"]
			line_col = Pal.FADE4
		"locked_unformed":
			label = "NONE"
			fg = Pal.INK9
			bg = Pal.INK2
			edge = Pal.INK5
			line = "%s locked" % shape["name"]
			line_col = Pal.FADE4
	if preview:
		label = "IF PLACED"
		fg = Pal.AMBER6
		bg = Pal.AMBER1
		edge = Pal.AMBER4
	PartyDraw.pill(self, Vector2(56, 30), label, fg, bg, edge)
	if placed < party_size:
		line = "%d of %d placed" % [placed, party_size]
		line_col = Pal.INK9
	var lx := 56
	if state in ["locked_fallback", "locked_unformed"]:
		draw_texture(LOCK, Vector2(56, 46), Pal.FADE4)
		lx = 64
	PartyDraw.text(self, Vector2(lx, 43), line, line_col, PartyDraw.BOLD)


func _chip_flow(shapes: Array, y: int) -> int:
	var x := 8
	for s: Dictionary in shapes:
		var w := _chip_w(s)
		if x + w > W - 8:
			x = 8
			y += 21
		if y > H - 50:
			break
		_chip(s, x, y)
		x += w + 4
	return y + 23


func _chip_w(s: Dictionary) -> int:
	var ok := FormationWords.is_unlocked(String(s["id"]), unlocked)
	return 4 + 7 + 5 + PartyDraw.text_w(String(s["name"]), PartyDraw.BOLD) + (9 if not ok else 0) + 4


func _chip(s: Dictionary, x: int, y: int) -> void:
	var ok := FormationWords.is_unlocked(String(s["id"]), unlocked)
	var r := Rect2(x, y, _chip_w(s), 19)
	draw_rect(r, Pal.INK2 if ok else Pal.INK1)
	PartyDraw.soft_outline(self, r, Pal.INK5 if ok else Pal.FADE1)
	var sc: Array = s["cells"]
	var hrows := 1
	for c: Array in sc:
		hrows = maxi(hrows, int(c[1]) + 1)
	var gh := hrows * 3 + hrows - 1
	FormationWords.draw_glyph(self, Vector2(x + 4, y + roundi((19 - gh) / 2.0)), sc, 3, Pal.CRYSTAL4 if ok else Pal.FADE2, Pal.INK3, 0, false)
	var tx := x + 16
	if not ok:
		draw_texture(LOCK, Vector2(tx, y + 7), Pal.FADE3)
		tx += 9
	PartyDraw.text(self, Vector2(tx, y + 4), String(s["name"]), Pal.INK10 if ok else Pal.FADE3, PartyDraw.BOLD)


func _para(s: String, pos: Vector2, width: int, color: Color, font: Font = PartyDraw.SANS) -> int:
	var y := int(pos.y)
	var line := ""
	for wd in s.split(" "):
		var trial := wd if line == "" else line + " " + wd
		if PartyDraw.text_w(trial, font) > width and line != "":
			PartyDraw.text(self, Vector2(pos.x, y), line, color, font)
			y += 11
			line = wd
		else:
			line = trial
	if line != "":
		PartyDraw.text(self, Vector2(pos.x, y), line, color, font)
		y += 11
	return y
