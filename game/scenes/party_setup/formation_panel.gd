class_name FormationPanel
extends Control
## The one shape card beside the board: the shape's name and glyph, its status, and a row of
## effect icons (shared EffectIcons / EffectChip; each opens the shared Tip with the full sentence).
## Details shows the same sentences in the same order (bonus, behaviour, cost, class bonds) with the
## same icons, plus the growth path. A locked shape fights as Strays: said once, here.

const W := 208
const H := 318
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


func _ready() -> void:
	size = Vector2(W, H)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_btn = Button.new()
	_details_btn.text = "Details"
	_details_btn.focus_mode = Control.FOCUS_NONE
	_details_btn.position = Vector2(8, H - 28)
	_details_btn.size = Vector2(62, 20)
	_details_btn.pressed.connect(toggle_details)
	add_child(_details_btn)
	_lock_tip = Control.new()
	_lock_tip.mouse_filter = Control.MOUSE_FILTER_STOP
	_lock_tip.visible = false
	add_child(_lock_tip)


func toggle_details() -> void:
	details = not details
	_details_btn.text = "Back" if details else "Details"
	Tip.close()
	_rebuild_chips()
	queue_redraw()


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
	var sid := String(shape.get("id", ""))
	var who := EffectIcons.who_of(sid, cells, names) if sid != "" else {}
	_effects = EffectIcons.formation_effects(shape, who, FormationWords.Formation.compositions(bases)) if not shape.is_empty() else []
	var sig := "%s|%s|%s|%s" % [sid, str(_ev["locked"]), str(who), str(bases)]
	if sig != _sig:
		if sid != _sig.get_slice("|", 0):
			_flash = 1.0
		_sig = sig
		_rebuild_chips()
	queue_redraw()


func _rebuild_chips() -> void:
	for ch in _chips:
		Tip.detach(ch)
		ch.queue_free()
	_chips.clear()
	_lock_tip.visible = false
	if details or _ev.is_empty() or (_ev["shape"] as Dictionary).is_empty():
		return
	var locked: bool = _ev["locked"]
	var y := 66
	if locked:
		y += 26   # the "Fights as Strays" line sits first
	var prev_kind := ""
	for e: Dictionary in _effects:
		var ee := e.duplicate()
		if locked:
			ee["text"] = "Once unlocked: " + String(e["text"])
		var kind := String(e["kind"])
		if prev_kind != "" and kind != prev_kind:
			y += 5   # a small gap between groups: bonus | behaviour | cost | bonds
		if y + EffectIcons.CHIP > H - 36:
			break
		var chip := EffectChip.new()
		add_child(chip)
		chip.position = Vector2(10, y)
		chip.setup(ee, true, W - 40)
		if locked:
			chip.modulate = Color(0.6, 0.6, 0.65)
		_chips.append(chip)
		y += EffectIcons.CHIP + 3
		prev_kind = kind
	if locked:
		_lock_tip.visible = true
		_lock_tip.position = Vector2(8, 64)
		_lock_tip.size = Vector2(W - 16, 20)
		var sid := String(_ev["shape"]["id"])
		Tip.attach(_lock_tip, "Locked", "%s fights as Strays until unlocked. %s" % [_ev["shape"]["name"],
			FormationWords.unlock_hint(sid, unlocked)], Pal.FADE4)


## Demo / tutorial: open the tooltip of effect chip k.
func open_tip(k: int) -> void:
	if k >= 0 and k < _chips.size():
		Tip.show_for(_chips[k])


func _process(delta: float) -> void:
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
		return
	var locked: bool = _ev["locked"]
	var strays := String(shape["id"]) == "strays"
	_draw_title(shape, locked, strays)
	if details:
		_draw_details(shape, locked, strays)
		return
	if locked and _lock_tip.visible:
		var r := Rect2(_lock_tip.position, _lock_tip.size)
		draw_rect(r, Pal.FADE1)
		PartyDraw.soft_outline(self, r, Pal.FADE2)
		draw_texture(LOCK, r.position + Vector2(6, 7), Pal.FADE4)
		PartyDraw.text(self, r.position + Vector2(16, 4), "Locked: fights as Strays", Pal.INK10, PartyDraw.BOLD)
	if not _chips.is_empty():
		var hy := _chips[-1].position.y + EffectIcons.CHIP + 8
		if hy < H - 46:
			PartyDraw.text(self, Vector2(10, hy), "Tap a line to read it in full", Pal.INK6)


func _draw_empty() -> void:
	PartyDraw.text(self, Vector2(12, 10), "No shape yet", Pal.INK8, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	PartyDraw.text(self, Vector2(12, 31), "Place heroes side by side", Pal.INK7, PartyDraw.BOLD)
	var y := 72
	for l: String in ["Heroes edge to edge make a shape.", "Each shape grows from a smaller one.", "Apart, they fight as Strays."]:
		draw_texture(DOT, Vector2(12, y + 4), Pal.CRYSTAL3)
		y = _para(l, Vector2(22, y), W - 32, Pal.INK9, PartyDraw.BOLD) + 4


func _draw_title(shape: Dictionary, locked: bool, strays: bool) -> void:
	var gw := Rect2(8, 8, 40, 46)
	PartyDraw.inset(self, gw)
	var fill := Pal.CRYSTAL4
	if strays or locked:
		fill = Pal.FADE3
	var minr := 99
	var maxr := 0
	for c: Array in cells:
		minr = mini(minr, int(c[1]))
		maxr = maxi(maxr, int(c[1]))
	var hrows := 4 if strays else maxr - minr + 1
	var gs := Vector2(17, hrows * 8 + hrows - 1)
	var gp := (gw.position + (gw.size - gs) / 2.0).floor()
	FormationWords.draw_glyph(self, gp, cells, 8, fill, Pal.INK2, 4 if strays else 0, false,
		Pal.CRYSTAL5 if not strays and not locked else Color(0, 0, 0, 0))
	var ncol := Pal.AMBER6 if not (strays or locked) else Pal.FADE4
	if _flash > 0.5:
		ncol = Pal.AMBER7 if not strays else Pal.INK10
	PartyDraw.text(self, Vector2(56, 10), String(shape["name"]), ncol, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	var label := "ACTIVE"
	var fg := Pal.CRYSTAL5
	var bg := Pal.CRYSTAL1
	var edge := Pal.CRYSTAL3
	if preview:
		label = "IF PLACED"
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
	var pw := PartyDraw.pill(self, Vector2(56, 33), label, fg, bg, edge)
	var sub := "not joined" if strays else FormationWords.size_word(shape)
	if placed < party_size:
		sub = "%d of %d placed" % [placed, party_size]
	PartyDraw.text(self, Vector2(60 + pw, 33), sub, Pal.INK7)


## Same sentences and icons as the chips, in the same order, plus the growth path.
func _draw_details(shape: Dictionary, locked: bool, strays: bool) -> void:
	var y := 66
	if locked:
		draw_texture(LOCK, Vector2(12, y + 2), Pal.FADE4)
		y = _para("Locked: fights as Strays. " + FormationWords.unlock_hint(String(shape["id"]), unlocked),
			Vector2(22, y), W - 30, Pal.FADE4, PartyDraw.BOLD) + 6
	for e: Dictionary in _effects:
		EffectIcons.draw_effect(self, Vector2(8, y), e)
		var ty := _para(String(e["text"]), Vector2(32, y), W - 40, Pal.INK9 if not locked else Pal.FADE4, PartyDraw.BOLD)
		y = maxi(ty, y + EffectIcons.CHIP) + 4
	if strays:
		return
	var from := FormationWords.parents(cells)
	var into := FormationWords.children(cells)
	if y > H - 100:
		return
	y += 2
	PartyDraw.header(self, Vector2(8, y), W - 16, "Grows from", Pal.INK7)
	y += 13
	if from.is_empty():
		PartyDraw.text(self, Vector2(10, y + 3), "The first shapes: two heroes", Pal.INK7)
		y += 21
	else:
		y = _chip_flow(from, y)
	PartyDraw.header(self, Vector2(8, y), W - 16, "With one more hero", Pal.INK7)
	y += 13
	if int(shape["size"]) >= 4:
		PartyDraw.text(self, Vector2(10, y + 3), "Full grown: four is the most", Pal.INK7)
	elif into.is_empty():
		PartyDraw.text(self, Vector2(10, y + 3), "No free slot to grow into", Pal.INK7)
	else:
		var arr: Array = []
		for e: Dictionary in into:
			arr.append(e["shape"])
		_chip_flow(arr, y)


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
