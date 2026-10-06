extends Control
## The box behind Tip (ui/tooltip.gd). One instance lives in a CanvasLayer on the root.

const MAX_W := 200
const PAD := 6

var owner_control: Control = null
var _pinned := false
var _hovered := false
var _press_owner: Control = null
var _press_t := 0.0
var _rect := Rect2()
var _title := ""
var _lines: Array = []
var _accent := Pal.CRYSTAL4
var _shown := false
var _entries: Array = []        # [[effect or {}, PackedStringArray lines], ...]
var _in_zone := false           # opened as the reading pane: fills the zone, wired to its row
const ENTRY_INDENT := 26        # icon chip (20) + gap
const ROW_GAP := 5.0            # a "row" tip's gap to its row (room for the caret)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS


func visible_now() -> bool:
	return _shown


## The open box (global rect), or an empty rect.
func box_rect() -> Rect2:
	return _rect if _shown else Rect2()


func hover(c: Control, on: bool) -> void:
	if on:
		_hovered = true
		if not _pinned or owner_control != c:
			open(c, false)
	else:
		_hovered = false
		if owner_control == c and not _pinned:
			shut()


func owner_input(c: Control, e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_press_owner = c
			_press_t = 0.0
		else:
			var held := _press_owner == c and _press_t >= Tip.HOLD_TIME
			_press_owner = null
			if held:
				return   # press-and-hold already opened it; release keeps it open
			if owner_control == c and _shown and _pinned:
				shut()
			else:
				open(c, true)


func open(c: Control, pin: bool) -> void:
	if not is_instance_valid(c) or not c.has_meta("tip"):
		return
	var d: Dictionary = c.get_meta("tip")
	owner_control = c
	_pinned = pin
	_title = String(d.get("title", ""))
	_accent = d.get("accent", Pal.CRYSTAL4)
	var place := String(d.get("place", "auto"))
	var use_zone := place == "zone" and Tip.zone.size.x > 40
	var use_row := place == "row" and Tip.zone.size.x > 40
	var max_w := int(d.get("width", MAX_W)) if not (use_zone or use_row) else int(Tip.zone.size.x) - 8
	_lines = Array(UIText.wrap_lines(String(d.get("body", "")), max_w - PAD * 2, UIText.BOLD, UIText.BODY)) if String(d.get("body", "")) != "" else []
	var w := UIText.width(_title, UIText.BOLD, UIText.LABEL) + PAD * 2
	for l: String in _lines:
		w = maxf(w, UIText.width(l, UIText.BOLD, UIText.BODY) + PAD * 2)
	var lh := UIText.line_h(UIText.BOLD, UIText.BODY)
	var h := ceilf(PAD + lh + (3 + _lines.size() * lh if not _lines.is_empty() else 0.0) + PAD - 2)
	_entries = []
	for en: Dictionary in d.get("entries", []):
		var has_icon := not (en.get("effect", {}) as Dictionary).is_empty()
		var ind := ENTRY_INDENT if has_icon else 0
		var ls := UIText.wrap_lines(String(en.get("text", "")), max_w - PAD * 2 - ind, UIText.BOLD, UIText.BODY)
		for l: String in ls:
			w = maxf(w, UIText.width(l, UIText.BOLD, UIText.BODY) + PAD * 2 + ind)
		_entries.append([en.get("effect", {}), ls])
		h += 6 + maxf(ls.size() * lh, EffectIcons.CHIP if has_icon else 0.0)
	w = ceilf(w)
	h = ceilf(h)
	var a := c.get_global_rect()
	var view := c.get_viewport_rect()   # (this box may not be in the tree yet on its first open)
	var x0 := view.position.x + 4
	var x1 := view.end.x - 4
	var y1 := view.end.y - 4
	var x := clampf(roundf(a.position.x + a.size.x / 2.0 - w / 2.0), x0, x1 - w)
	var y := a.position.y - h - 4
	if (place == "zone" and not use_zone) or (place == "row" and not use_row):
		place = "left"
	if place == "below" and a.end.y + 4 + h <= y1:
		y = a.end.y + 4
	if y < 4:
		y = a.end.y + 4
	if place == "left" or place == "right":
		y = clampf(roundf(a.position.y + a.size.y / 2.0 - h / 2.0), 4, y1 - h)
		x = a.position.x - w - 6 if place == "left" else a.end.x + 6
		x = clampf(x, x0, x1 - w)
	_in_zone = use_zone or use_row
	if use_row:
		# anchored to its own row (critic r6: a pane docked under the list pointed at the last row):
		# the zone's width, directly under the row, or directly over it when there is no room
		# above the zone's foot; the caret points at the row's icon
		x = roundf(Tip.zone.position.x)
		w = roundf(Tip.zone.size.x)
		y = a.end.y + ROW_GAP
		if y + h > Tip.zone.end.y:
			y = maxf(4.0, a.position.y - ROW_GAP - h)
	elif use_zone:
		# a solid pane over the whole free zone (critic r4: a box narrower than the zone let the
		# growth row's bars show round it); taller text grows it upward from the zone's foot
		x = roundf(Tip.zone.position.x)
		w = roundf(Tip.zone.size.x)
		h = maxf(h, roundf(Tip.zone.size.y))
		y = Tip.zone.position.y if h <= Tip.zone.size.y else maxf(4.0, Tip.zone.end.y - h)
	_rect = Rect2(x, y, w, h)
	_shown = true
	queue_redraw()


func shut() -> void:
	_shown = false
	_pinned = false
	owner_control = null
	queue_redraw()


func forget(c: Control) -> void:
	if owner_control == c:
		shut()
	if _press_owner == c:
		_press_owner = null


func _process(delta: float) -> void:
	if _press_owner != null:
		_press_t += delta
		if _press_t >= Tip.HOLD_TIME and not (_shown and owner_control == _press_owner):
			open(_press_owner, true)
	if _shown and (owner_control == null or not is_instance_valid(owner_control) or not owner_control.is_visible_in_tree()):
		shut()


func _input(e: InputEvent) -> void:
	# a tap anywhere else closes a pinned tooltip (never consumes the event)
	if _shown and e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var p := (e as InputEventMouseButton).position
		if owner_control != null and is_instance_valid(owner_control) and owner_control.get_global_rect().has_point(p):
			return
		shut()


func _draw() -> void:
	if not _shown:
		return
	var r := _rect
	draw_rect(r, Pal.INK1)
	draw_rect(r.grow(-1), Pal.INK2)
	draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1), _accent)
	# the reading pane is tied to its row: the row gets an accent frame, and a small caret on the
	# pane's top edge points up toward the row's icon (critic r5: a bracket rule down the card's
	# margin read as a stray line)
	if _in_zone and owner_control != null and is_instance_valid(owner_control):
		var a := owner_control.get_global_rect()
		var cx := roundf(clampf(a.position.x + 10.0, r.position.x + 6.0, r.end.x - 6.0))
		if a.end.y <= r.position.y:
			draw_rect(a.grow(1.0), _accent, false, 1.0)
			for k in 4:
				draw_rect(Rect2(cx - k, r.position.y - 4 + k, k * 2 + 1, 1), _accent)
		elif a.position.y >= r.end.y:
			draw_rect(a.grow(1.0), _accent, false, 1.0)
			for k in 4:
				draw_rect(Rect2(cx - k, r.end.y + 3 - k, k * 2 + 1, 1), _accent)
	# pointer nub toward the owner when placed beside it
	if owner_control != null and is_instance_valid(owner_control) and not _in_zone:
		var a := owner_control.get_global_rect()
		var cy := clampf(roundf(a.get_center().y), r.position.y + 4, r.end.y - 5)
		if a.position.x >= r.end.x:
			draw_rect(Rect2(r.end.x, cy - 2, 1, 5), Pal.INK5)
			draw_rect(Rect2(r.end.x + 1, cy - 1, 1, 3), Pal.INK5)
			draw_rect(Rect2(r.end.x + 2, cy, 1, 1), Pal.INK5)
		elif a.end.x <= r.position.x:
			draw_rect(Rect2(r.position.x - 1, cy - 2, 1, 5), Pal.INK5)
			draw_rect(Rect2(r.position.x - 2, cy - 1, 1, 3), Pal.INK5)
			draw_rect(Rect2(r.position.x - 3, cy, 1, 1), Pal.INK5)
	# soft frame
	draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), Pal.INK5)
	draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), Pal.INK5)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), Pal.INK5)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), Pal.INK5)
	var lh := UIText.line_h(UIText.BOLD, UIText.BODY)
	var p := Vector2(r.position.x + PAD, r.position.y + PAD - 2)
	UIText.draw(self, p, _title, _accent, UIText.BOLD, UIText.LABEL)
	p.y += lh + 3
	for l: String in _lines:
		UIText.draw(self, p, l, Pal.INK10, UIText.BOLD, UIText.BODY)
		p.y += lh
	for en: Array in _entries:
		p.y += 6
		var e: Dictionary = en[0]
		var ls: PackedStringArray = en[1]
		var x := p.x
		var block := ls.size() * lh
		if not e.is_empty():
			EffectIcons.draw_effect(self, Vector2(x, p.y), e)
			x += ENTRY_INDENT
			block = maxf(block, EffectIcons.CHIP)
		# one-line sentences sit centred on their icon; longer ones start at its top
		var ty := p.y + (roundf((EffectIcons.CHIP - lh) / 2.0) if ls.size() == 1 and not e.is_empty() else 0.0)
		for l: String in ls:
			UIText.draw(self, Vector2(x, ty), l, Pal.INK10, UIText.BOLD, UIText.BODY)
			ty += lh
		p.y += block
