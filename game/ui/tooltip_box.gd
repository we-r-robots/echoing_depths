extends Control
## The box behind Tip (ui/tooltip.gd). One instance lives in a CanvasLayer on the root.

const BOLD := preload("res://assets/fonts/depths_sans_bold.fnt")
const MAX_W := 196
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS


func visible_now() -> bool:
	return _shown


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
	var max_w := MAX_W if not use_zone else int(Tip.zone.size.x) - 8
	_lines = _wrap(String(d.get("body", "")), max_w - PAD * 2)
	var w := BOLD.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + PAD * 2
	for l: String in _lines:
		w = maxf(w, BOLD.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + PAD * 2)
	w = ceilf(w)
	var h := PAD + 11 + (3 + _lines.size() * 11 if not _lines.is_empty() else 0) + PAD - 1
	var a := c.get_global_rect()
	var x := clampf(roundf(a.position.x + a.size.x / 2.0 - w / 2.0), 4, 636 - w)
	var y := a.position.y - h - 4
	if place == "zone" and not use_zone:
		place = "left"
	if place == "below" and a.end.y + 4 + h <= 356:
		y = a.end.y + 4
	if y < 4:
		y = a.end.y + 4
	if place == "left" or place == "right":
		y = clampf(roundf(a.position.y + a.size.y / 2.0 - h / 2.0), 4, 356 - h)
		x = a.position.x - w - 6 if place == "left" else a.end.x + 6
		x = clampf(x, 4, 636 - w)
	if use_zone:
		x = roundf(Tip.zone.position.x + (Tip.zone.size.x - w) / 2.0)
		y = Tip.zone.end.y - h
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
	# pointer nub toward the owner when placed beside it
	if owner_control != null and is_instance_valid(owner_control):
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
	var asc := BOLD.get_ascent(11)
	var p := Vector2(r.position.x + PAD, r.position.y + PAD - 1 + asc).round()
	draw_string(BOLD, p + Vector2(1, 1), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.INK1)
	draw_string(BOLD, p, _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _accent)
	p.y += 14
	for l: String in _lines:
		draw_string(BOLD, p + Vector2(1, 1), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.INK1)
		draw_string(BOLD, p, l, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.INK9)
		p.y += 11


static func _wrap(s: String, width: int) -> Array:
	var out: Array = []
	if s == "":
		return out
	var line := ""
	for wd in s.split(" "):
		var trial := wd if line == "" else line + " " + wd
		if BOLD.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > width and line != "":
			out.append(line)
			line = wd
		else:
			line = trial
	if line != "":
		out.append(line)
	return out
