class_name FormationBoard
extends Control
## Left half of the formation setup screen: the party roster (where unplaced heroes wait) and the
## side's 2-column x 4-row grid, drawn the way the battle faces: BACK column on the left, FRONT on
## the right, the foe beyond it.
##
## Input (touch-first, nothing hover-only):
##   drag a hero (from a cell or the roster) onto a cell: placed there; onto an occupied cell: the
##     two swap; onto the roster: taken off the grid.
##   tap a hero: it lifts (held); then tap a cell to place it, or the roster to take it off.
## While a hero is held or dragged, every free cell names the formation it would make.
## When nothing is held, the free cells next to the shape name what one more hero would grow it into.

signal changed                  # placement changed (a drop or a tap-place)
signal preview_changed          # the drag target changed (preview_cells() differs)
signal held_changed

const ROSTER := Rect2(0, 0, 96, 296)
const GRID := Rect2(100, 0, 196, 296)
const CW := 80
const CH := 62
const COL_GAP := 6
const ROW_GAP := 3
const GX := 115                 # x of the BACK column; FRONT is GX + CW + COL_GAP
const GY := 31
const ENTRY_Y := 22
const ENTRY_H := 67
const DRAG_START := 3.0
const LOCK := preload("res://assets/party/lock.png")
const PLUS := preload("res://assets/party_setup/plus.png")
const FOE := preload("res://assets/party_setup/foe.png")
const HAND_POINT := preload("res://assets/party_setup/hand_point.png")
const HAND_GRAB := preload("res://assets/party_setup/hand_grab.png")
const MAX_PARTY := 4

var heroes: Array = []          # hero dictionaries (core format; "class" may be advanced)
var placement: Array = []       # per hero: [col, row] or null (waiting in the roster)
var unlocked: Array = []
var held := -1                  # tap-selected hero
var demo_hand := 0              # 0 none, 1 pointing, 2 grabbing (demo / tutorial cursor)
var demo_pointer := Vector2.ZERO

var _sprites: Array[AnimatedSprite2D] = []
var _pos: Array = []            # current drawn feet position per hero (eased toward its slot)
var _portraits: Array = []
var _infos: Array = []
var _overlay: Control
var _top: Control
var _press := -1
var _press_at := Vector2.ZERO
var _press_cell: Variant = null
var _press_roster := false
var _dragging := -1
var _drag_at := Vector2.ZERO
var _drag_off := Vector2.ZERO
var _target: Variant = null     # cell under the drag, "roster", or null
var _t := 0.0
var _flash := 0.0               # shape-formed pulse (1 -> 0)
var _flash_cells: Array = []
var _dust: Array = []           # [pos, age]
var _last_shape := ""


func _ready() -> void:
	size = Vector2(296, 296)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = size
	_overlay.z_index = 5
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.size = size
	_top.z_index = 20
	_top.draw.connect(_draw_top)
	add_child(_top)


## heroes: core-format dictionaries; slots: per hero [col, row] or null (waiting).
func setup(hs: Array, slots: Array, unlocked_ids: Array) -> void:
	for s in _sprites:
		s.queue_free()
	_sprites.clear()
	heroes = hs.duplicate(true)
	placement = []
	_pos = []
	_portraits = []
	_infos = []
	unlocked = unlocked_ids.duplicate()
	for i in heroes.size():
		_add_sprite(i, slots[i] if i < slots.size() else null)
	held = -1
	_dragging = -1
	_last_shape = _shape_id()
	queue_redraw()


## Adds a hero to the party (it waits in the roster). Returns its index.
func add_hero(h: Dictionary) -> int:
	if heroes.size() >= MAX_PARTY:
		return -1
	heroes.append(h.duplicate(true))
	_add_sprite(heroes.size() - 1, null)
	changed.emit()
	return heroes.size() - 1


func _add_sprite(i: int, slot: Variant) -> void:
	var base := PartyModel.base_class(heroes[i])
	var info := EncounterDB.class_info(base)
	_infos.append(info)
	_portraits.append(load(String(info["portrait"])))
	placement.append(slot.duplicate() if slot is Array else null)
	var sp := AnimatedSprite2D.new()
	sp.centered = false
	var frames := HeroCard._frames_for(base)
	if frames:
		sp.sprite_frames = frames
		sp.play(&"idle")
		sp.frame = (i * 5) % maxi(1, frames.get_frame_count(&"idle"))
	sp.z_index = 1
	add_child(sp)
	move_child(sp, _overlay.get_index())
	_sprites.append(sp)
	var p := Vector2.ZERO
	if slot is Array:
		p = feet_of(slot)
	else:
		p = _entry_rect(i).position + Vector2(20, 40)
	_pos.append(p)


# ------------------------------------------------------------------ geometry

static func cell_rect(c: Array) -> Rect2:
	var col := int(c[0])
	var row := int(c[1])
	var x := GX + (CW + COL_GAP) * (1 - col)   # front (col 0) on the right
	return Rect2(x, GY + row * (CH + ROW_GAP), CW, CH)


static func feet_of(c: Array) -> Vector2:
	var r := cell_rect(c)
	return Vector2(r.position.x + 40, r.position.y + 50)


func _entry_rect(i: int) -> Rect2:
	return Rect2(4, ENTRY_Y + i * ENTRY_H, 88, ENTRY_H - 4)


func cell_at(p: Vector2) -> Variant:
	for row in 4:
		for col in 2:
			if cell_rect([col, row]).grow(1).has_point(p):
				return [col, row]
	return null


func hero_at_cell(c: Variant) -> int:
	if not (c is Array):
		return -1
	for i in placement.size():
		var s: Variant = placement[i]
		if s is Array and int(s[0]) == int(c[0]) and int(s[1]) == int(c[1]):
			return i
	return -1


func _roster_hero_at(p: Vector2) -> int:
	for i in heroes.size():
		if _entry_rect(i).has_point(p):
			return i
	return -1


# ------------------------------------------------------------------ model

func placed_cells(pl: Array = placement) -> Array:
	var out: Array = []
	for s: Variant in pl:
		if s is Array:
			out.append([int(s[0]), int(s[1])])
	return out


func all_placed() -> bool:
	for s: Variant in placement:
		if not (s is Array):
			return false
	return not placement.is_empty()


func waiting_count() -> int:
	var n := 0
	for s: Variant in placement:
		if not (s is Array):
			n += 1
	return n


## The placement after moving hero i to cell c (null = to the roster); the occupant swaps back.
func moved(i: int, c: Variant) -> Array:
	var pl := placement.duplicate(true)
	var old: Variant = pl[i]
	if c is Array:
		var j := hero_at_cell(c)
		if j == i:
			return pl
		if j >= 0:
			pl[j] = old.duplicate() if old is Array else null
		pl[i] = [int(c[0]), int(c[1])]
	else:
		pl[i] = null
	return pl


func move_hero(i: int, c: Variant) -> void:
	if i < 0 or i >= heroes.size():
		return
	var before := placement.duplicate(true)
	placement = moved(i, c)
	if placement == before:
		return
	if c is Array:
		_dust.append([feet_of(c), 0.0])
	for k in placement.size():
		# the swapped hero walks over from where it stood
		if k != i and placement[k] is Array and before[k] != placement[k] and not (before[k] is Array):
			_pos[k] = _entry_rect(k).position + Vector2(20, 40)
	var sid := _shape_id()
	if sid != _last_shape and sid != "" and sid != "strays":
		_flash = 1.0
		_flash_cells = placed_cells()
	_last_shape = sid
	changed.emit()


func _shape_id() -> String:
	var s := FormationWords.detect(placed_cells())
	return String(s.get("id", ""))


## Cells the info panel should evaluate: the drag preview when hovering a target, else current.
func preview_cells() -> Variant:
	if _dragging >= 0 and _target != null:
		var c: Variant = _target if _target is Array else null
		return placed_cells(moved(_dragging, c))
	return null


func held_or_dragged() -> int:
	return _dragging if _dragging >= 0 else held


func set_held(i: int) -> void:
	held = i
	held_changed.emit()


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			pointer_down(mb.position)
		else:
			pointer_up(mb.position)
		accept_event()
	elif event is InputEventMouseMotion:
		pointer_move((event as InputEventMouseMotion).position)


## Pointer API (also driven by the demo so it exercises the same code path as a finger).
func pointer_down(p: Vector2) -> void:
	_press_at = p
	_press_cell = cell_at(p)
	_press_roster = ROSTER.has_point(p)
	_press = hero_at_cell(_press_cell) if _press_cell != null else _roster_hero_at(p)


func pointer_move(p: Vector2) -> void:
	if _press >= 0 and _dragging < 0 and p.distance_to(_press_at) > DRAG_START:
		_dragging = _press
		var origin: Vector2 = _pos[_dragging] if placement[_dragging] is Array else p + Vector2(0, 14)
		_drag_off = origin - _press_at
		set_held(-1)
	if _dragging >= 0:
		_drag_at = p
		var t: Variant = cell_at(p)
		if t == null and ROSTER.has_point(p):
			t = "roster"
		if t != _target:
			_target = t
			preview_changed.emit()


func pointer_up(p: Vector2) -> void:
	if _dragging >= 0:
		var i := _dragging
		var t: Variant = _target
		_pos[i] = (p + _drag_off).round()
		_dragging = -1
		_target = null
		if t is Array:
			move_hero(i, t)
		elif t == "roster":
			move_hero(i, null)
		preview_changed.emit()
		_press = -1
		return
	# a tap
	var c: Variant = cell_at(p)
	var on_roster := ROSTER.has_point(p)
	if held >= 0:
		if c is Array:
			if hero_at_cell(c) == held:
				set_held(-1)
			else:
				var i := held
				set_held(-1)
				move_hero(i, c)
		elif on_roster:
			var r := _roster_hero_at(p)
			if r >= 0 and r != held:
				set_held(r)
			elif placement[held] is Array:
				var i := held
				set_held(-1)
				move_hero(i, null)
			else:
				set_held(-1)
		else:
			set_held(-1)
	elif _press >= 0:
		set_held(_press)
	_press = -1


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 1.6)
	for d: Array in _dust:
		d[1] = float(d[1]) + delta
	_dust = _dust.filter(func(d: Array) -> bool: return float(d[1]) < 0.35)
	var k := 1.0 - exp(-delta * 18.0)
	for i in heroes.size():
		var sp := _sprites[i]
		var target: Vector2
		var show := true
		if i == _dragging:
			target = _drag_at + _drag_off
			_pos[i] = target
			sp.z_index = 10
		else:
			sp.z_index = 1
			if placement[i] is Array:
				target = feet_of(placement[i])
				_pos[i] = (_pos[i] as Vector2).lerp(target, k)
			else:
				show = false
		var lift := 0.0
		if i == _dragging:
			lift = 4.0
		elif i == held and placement[i] is Array:
			lift = 2.0 + roundf(sin(_t * 6.0))
		sp.visible = show
		# feet origin of the 64x64 frame is (32, 60)
		sp.position = ((_pos[i] as Vector2) - Vector2(32, 60 + lift)).round()
		sp.modulate = Color.WHITE
	queue_redraw()
	_overlay.queue_redraw()
	_top.queue_redraw()


# ------------------------------------------------------------------ drawing

func _eval() -> Dictionary:
	return FormationWords.evaluate(placed_cells(), unlocked)


func _draw() -> void:
	_draw_roster()
	_draw_grid()


func _draw_roster() -> void:
	PartyDraw.panel(self, ROSTER, 0, &"DimPanel")
	PartyDraw.text(self, Vector2(8, 6), "PARTY", Pal.INK7, PartyDraw.BOLD, 11, false)
	var cnt := "%d/%d" % [heroes.size(), MAX_PARTY]
	PartyDraw.text(self, Vector2(0, 6), cnt, Pal.INK7, PartyDraw.BOLD, 11, false, 88, HORIZONTAL_ALIGNMENT_RIGHT)
	var ev := _eval()
	var eff: Dictionary = ev["effective"]
	var cells := placed_cells()
	var roles: Array = []
	if not eff.is_empty() and cells.size() == placed_cells().size():
		roles = _roles_for(String(eff.get("id", "")), cells)
	var hl := held_or_dragged()
	for i in MAX_PARTY:
		var r := _entry_rect(i)
		if i >= heroes.size():
			PartyDraw.dashed_outline(self, r, Pal.INK4)
			PartyDraw.text(self, r.position + Vector2(0, 20), "Open place", Pal.INK6, PartyDraw.SANS, 11, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			PartyDraw.text(self, r.position + Vector2(0, 32), "recruit on the road", Pal.INK5, PartyDraw.SANS, 11, false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var h: Dictionary = heroes[i]
		var info: Dictionary = _infos[i]
		var cc := Pal.c(info["color"])
		var waiting := not (placement[i] is Array)
		if i == hl:
			PartyDraw.selected(self, r)
		elif waiting:
			draw_rect(r, Pal.AMBER1)
			var on := fmod(_t, 1.0) < 0.6
			PartyDraw.soft_outline(self, r, Pal.AMBER4 if on else Pal.AMBER3)
		else:
			PartyDraw.row(self, r)
			PartyDraw.soft_outline(self, r, Pal.INK4)
		var well := Rect2(r.position + Vector2(3, 3), Vector2(26, 26))
		PartyDraw.inset(self, well)
		if i == _dragging:
			draw_rect(well.grow(-1), Pal.INK2)
		else:
			draw_texture(_portraits[i], well.position + Vector2(1, 1))
		draw_rect(Rect2(well.position.x, well.end.y, well.size.x, 1), cc)
		PartyDraw.text(self, r.position + Vector2(33, 3), String(h.get("name", "?")), Pal.INK10, PartyDraw.BOLD)
		var cls := PartyModel.class_name_of(String(h.get("class", "")))
		PartyDraw.tint_tex(self, PartyDraw.icon(info["icon"]), r.position + Vector2(33, 17), cc)
		PartyDraw.text(self, r.position + Vector2(42, 15), cls, cc, PartyDraw.BOLD)
		var y := r.position.y + 33
		if waiting:
			PartyDraw.text(self, Vector2(r.position.x + 4, y), "WAITING", Pal.AMBER6, PartyDraw.BOLD)
			PartyDraw.text(self, Vector2(r.position.x + 4, y + 12), "drag to a slot", Pal.AMBER4)
		else:
			var s: Array = placement[i]
			var where := "FRONT" if int(s[0]) == 0 else "BACK"
			PartyDraw.text(self, Vector2(r.position.x + 4, y), where, Pal.AMBER5 if int(s[0]) == 0 else Pal.CRYSTAL4, PartyDraw.BOLD)
			PartyDraw.text(self, Vector2(r.position.x + 6 + PartyDraw.text_w(where, PartyDraw.BOLD), y), "row %d" % (int(s[1]) + 1), Pal.INK8)
			var role := _role_of(i, roles, cells)
			if role != "":
				PartyDraw.text(self, Vector2(r.position.x + 4, y + 12), String(FormationWords.ROLE_WORDS[role]).left(1).to_upper() + String(FormationWords.ROLE_WORDS[role]).substr(1),
					Pal.CRYSTAL4 if not ev["locked"] else Pal.FADE3)
			elif ev["locked"] or String(eff.get("id", "")) == "strays":
				PartyDraw.text(self, Vector2(r.position.x + 4, y + 12), "Stray", Pal.FADE3)


static func _roles_for(id: String, cells: Array) -> Array:
	if id == "" or id == "strays":
		return []
	return FormationWords.Formation.roles(id, cells)


## The special role (post / tip / keeper / flanker / gap / middle) of hero i, or "".
func _role_of(i: int, roles: Array, cells: Array) -> String:
	if roles.is_empty() or not (placement[i] is Array):
		return ""
	var s: Array = placement[i]
	for k in cells.size():
		if int(cells[k][0]) == int(s[0]) and int(cells[k][1]) == int(s[1]):
			for r: String in roles[k]:
				if FormationWords.ROLE_TAGS.has(r):
					return r
	return ""


func _draw_grid() -> void:
	PartyDraw.panel(self, GRID, 0, &"DimPanel")
	# column headers: BACK (left) | FRONT (right) -> the foe
	var bx := GX
	var fx := GX + CW + COL_GAP
	PartyDraw.text(self, Vector2(bx, 5), "BACK", Pal.CRYSTAL4, PartyDraw.BOLD, 11, true, CW, HORIZONTAL_ALIGNMENT_CENTER)
	PartyDraw.text(self, Vector2(bx, 16), "half physical", Pal.INK7, PartyDraw.SANS, 11, true, CW, HORIZONTAL_ALIGNMENT_CENTER)
	PartyDraw.text(self, Vector2(fx, 5), "FRONT", Pal.AMBER5, PartyDraw.BOLD, 11, true, CW, HORIZONTAL_ALIGNMENT_CENTER)
	PartyDraw.text(self, Vector2(fx, 16), "melee hits first", Pal.INK7, PartyDraw.SANS, 11, true, CW, HORIZONTAL_ALIGNMENT_CENTER)
	# foe-side chevrons down the right edge
	for row in 4:
		var r := cell_rect([0, row])
		var cy := r.position.y + CH / 2 - 3
		var ph := int(_t * 4.0 + row) % 3
		draw_texture(FOE, Vector2(r.end.x + 3, cy), Pal.BLOOD3 if ph == 0 else Pal.BLOOD2)
	var ev := _eval()
	var shape: Dictionary = ev["shape"]
	var sid := String(shape.get("id", ""))
	var locked: bool = ev["locked"]
	var strays := sid == "strays"
	var cells := placed_cells()
	var hl := held_or_dragged()
	var growth := {}
	if hl < 0 and not strays and sid != "":
		if cells.size() < 4:
			for gc: Array in FormationWords.growth_cells(cells):
				var gs := FormationWords.detect(cells + [gc])
				if String(gs.get("id", "strays")) != "strays":
					growth[_key(gc)] = gs
	for row in 4:
		for col in 2:
			var c := [col, row]
			var r := cell_rect(c)
			var occ := hero_at_cell(c)
			if occ == _dragging and occ >= 0:
				occ = -1
			_draw_cell_floor(r, col)
			if occ >= 0:
				var lit := Pal.CRYSTAL3
				if strays or sid == "":
					lit = Pal.FADE2
				elif locked:
					lit = Pal.FADE3
				_draw_occupied(r, lit, strays or sid == "", locked)
			elif growth.has(_key(c)):
				_draw_growth_cell(r, growth[_key(c)])
	_draw_bonds(cells, sid, locked)
	if hl >= 0:
		_draw_drop_labels(hl)
	# shape-formed pulse
	if _flash > 0.0:
		for c: Array in _flash_cells:
			var r := cell_rect(c).grow(roundi((1.0 - _flash) * 3.0))
			var fc := Pal.CRYSTAL5
			fc.a = _flash
			PartyDraw.soft_outline(self, r, fc)
	if _dragging >= 0:
		# the lifted hero's shadow stays on the floor below it
		var p: Vector2 = (_pos[_dragging] as Vector2).round()
		var sh := Pal.INK1
		sh.a = 0.7
		draw_rect(Rect2(p.x - 10, p.y + 2, 20, 3), sh)
	for d: Array in _dust:
		var p: Vector2 = d[0]
		var a := float(d[1]) / 0.35
		var spread := roundi(4 + a * 10)
		for sx in [-1, 1]:
			var dc := Pal.INK8
			dc.a = 1.0 - a
			draw_rect(Rect2(p + Vector2(sx * spread, -1 - roundi(a * 3)), Vector2(2, 1)), dc)
			draw_rect(Rect2(p + Vector2(sx * (spread - 4), 1 - roundi(a * 2)), Vector2(1, 1)), dc)


static func _key(c: Array) -> int:
	return int(c[0]) * 4 + int(c[1])


func _draw_cell_floor(r: Rect2, col: int) -> void:
	draw_rect(r, Pal.INK1)
	var inner := r.grow(-1)
	draw_rect(inner, Pal.INK2)
	# flagstone: a lighter lower floor plate with a lit seam, the column's colour on the sill
	draw_rect(Rect2(inner.position.x, inner.end.y - 16, inner.size.x, 16), Pal.INK3)
	draw_rect(Rect2(inner.position.x, inner.end.y - 16, inner.size.x, 1), Pal.INK4)
	draw_rect(Rect2(inner.position.x, inner.end.y - 1, inner.size.x, 1), Pal.AMBER2 if col == 0 else Pal.CRYSTAL1)
	draw_rect(Rect2(inner.position.x + 1, inner.position.y, inner.size.x - 2, 1), Pal.INK3)


func _draw_occupied(r: Rect2, lit: Color, stray: bool, locked: bool) -> void:
	var cx := r.position.x + 40
	var fy := r.position.y + 50
	if not stray:
		# lantern light pooled under the hero
		var glow := Pal.CRYSTAL1 if not locked else Pal.FADE1
		for i in 4:
			var hw := 30 - i * 6
			draw_rect(Rect2(cx - hw, fy - 3 + i, hw * 2, 1), glow if i < 2 else (Pal.CRYSTAL2 if not locked else Pal.FADE1))
		PartyDraw.soft_outline(self, r, lit)
	else:
		PartyDraw.dashed_outline(self, r, Pal.FADE2, int(_t * 6.0) % 4)
	draw_rect(Rect2(cx - 11, fy - 1, 22, 3), Pal.INK1)
	draw_rect(Rect2(cx - 9, fy + 2, 18, 1), Pal.INK1)


func _draw_growth_cell(r: Rect2, shape: Dictionary) -> void:
	var ok := FormationWords.is_unlocked(String(shape["id"]), unlocked)
	var col := Pal.INK7 if ok else Pal.FADE2
	PartyDraw.dashed_outline(self, r.grow(-2), Pal.INK5)
	var cx := r.position.x + 40
	PartyDraw.tint_tex(self, PLUS, Vector2(cx - 2, r.position.y + 14), Pal.INK6, false)
	PartyDraw.text(self, Vector2(r.position.x, r.position.y + 23), "grows into", Pal.INK6, PartyDraw.SANS, 11, false, CW, HORIZONTAL_ALIGNMENT_CENTER)
	var nm := String(shape["name"])
	PartyDraw.text(self, Vector2(r.position.x, r.position.y + 34), nm, col, PartyDraw.BOLD, 11, true, CW, HORIZONTAL_ALIGNMENT_CENTER)
	if not ok:
		var w := PartyDraw.text_w(nm, PartyDraw.BOLD)
		draw_texture(LOCK, Vector2(cx - w / 2 - 8, r.position.y + 36), Pal.FADE2)


## Crystal links across the gaps between edge-adjacent heroes of the shape.
func _draw_bonds(cells: Array, sid: String, locked: bool) -> void:
	if sid == "" or sid == "strays":
		return
	var dc := cells
	if _dragging >= 0 and placement[_dragging] is Array:
		dc = []
		for i in placement.size():
			if i != _dragging and placement[i] is Array:
				dc.append(placement[i])
	var c1 := Pal.CRYSTAL4 if not locked else Pal.FADE3
	var c2 := Pal.CRYSTAL2 if not locked else Pal.FADE1
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	for a: Array in dc:
		for b: Array in dc:
			if int(a[0]) == int(b[0]) and int(b[1]) == int(a[1]) + 1:
				var ra := cell_rect(a)
				var y := ra.end.y
				var x := ra.position.x + 30
				draw_rect(Rect2(x, y - 2, 20, ROW_GAP + 4), Pal.INK1)
				draw_rect(Rect2(x + 1, y - 1, 18, ROW_GAP + 2), c2)
				draw_rect(Rect2(x + 2, y, 16, ROW_GAP), c1 if pulse > 0.3 or locked else c2)
			elif int(a[1]) == int(b[1]) and int(a[0]) == 1 and int(b[0]) == 0:
				var ra := cell_rect(a)
				var x := ra.end.x
				var y := ra.position.y + 26
				draw_rect(Rect2(x - 2, y, COL_GAP + 4, 12), Pal.INK1)
				draw_rect(Rect2(x - 1, y + 1, COL_GAP + 2, 10), c2)
				draw_rect(Rect2(x, y + 2, COL_GAP, 8), c1 if pulse > 0.3 or locked else c2)


## While a hero is held or dragged, every free cell (and the drag target) names the result.
func _draw_drop_labels(i: int) -> void:
	for row in 4:
		for col in 2:
			var c := [col, row]
			var occ := hero_at_cell(c)
			var is_target: bool = _dragging >= 0 and _target is Array and int(_target[0]) == col and int(_target[1]) == row
			if occ >= 0 and occ != i and not is_target:
				continue
			if occ == i and _dragging < 0:
				continue
			var r := cell_rect(c)
			var res := FormationWords.evaluate(placed_cells(moved(i, c)), unlocked)
			var shape: Dictionary = res["shape"]
			var nm := "—"
			var color := Pal.FADE3
			var lock := false
			if not shape.is_empty():
				nm = String(shape["name"])
				if String(shape["id"]) == "strays":
					color = Pal.FADE3
				elif res["locked"]:
					color = Pal.FADE4
					lock = true
				else:
					color = Pal.CRYSTAL5
			if is_target:
				PartyDraw.soft_outline(self, r.grow(1), Pal.AMBER6)
				PartyDraw.soft_outline(self, r, Pal.AMBER4)
			elif occ < 0:
				PartyDraw.dashed_outline(self, r.grow(-2), Pal.CRYSTAL2 if color == Pal.CRYSTAL5 else Pal.INK5, int(_t * 8.0) % 4)
			if occ < 0 and not is_target:
				var ty := r.position.y + 25
				var w := PartyDraw.text_w(nm, PartyDraw.BOLD) + (8 if lock else 0)
				var plate := Rect2(r.position.x + roundi((CW - w - 8) / 2.0), ty - 1, w + 8, 13)
				draw_rect(plate, Pal.INK1)
				PartyDraw.soft_outline(self, plate, Pal.CRYSTAL3 if color == Pal.CRYSTAL5 else Pal.INK4)
				var tx := plate.position.x + 4
				if lock:
					draw_texture(LOCK, Vector2(tx, ty + 2), Pal.FADE3)
					tx += 8
				PartyDraw.text(self, Vector2(tx, ty), nm, color, PartyDraw.BOLD, 11, false)


## Above the sprites: names under the feet, role tags, stray tags.
func _draw_overlay() -> void:
	var ev := _eval()
	var eff: Dictionary = ev["effective"]
	var shape: Dictionary = ev["shape"]
	var cells := placed_cells()
	var roles: Array = _roles_for(String(shape.get("id", "")), cells)
	var stray := String(eff.get("id", "")) == "strays"
	for i in heroes.size():
		if not (placement[i] is Array) or i == _dragging:
			continue
		var c: Array = placement[i]
		var r := cell_rect(c)
		var nm := String(heroes[i].get("name", "?"))
		PartyDraw.text(_overlay, Vector2(r.position.x, r.position.y + 50), nm, Pal.INK10 if i != held else Pal.AMBER6,
			PartyDraw.BOLD, 11, true, CW, HORIZONTAL_ALIGNMENT_CENTER)
		var tag := ""
		var fg := Pal.CRYSTAL5
		var bg := Pal.CRYSTAL1
		var edge := Pal.CRYSTAL3
		var role := _role_of(i, roles, cells)
		if stray:
			tag = "STRAY"
		elif role != "":
			tag = String(FormationWords.ROLE_TAGS[role])
		if stray:
			fg = Pal.FADE4
			bg = Pal.FADE1
			edge = Pal.FADE2
		if tag != "":
			# a tab straddling the cell's top edge, clear of the hero's head
			PartyDraw.pill(_overlay, Vector2(r.position.x + 3, r.position.y - 4), tag, fg, bg, edge)
	if ev["locked"]:
		# a lock badge on the shape's top-most cell
		var top: Array = cells[0]
		for c: Array in cells:
			if int(c[1]) < int(top[1]) or (int(c[1]) == int(top[1]) and int(c[0]) > int(top[0])):
				top = c
		var r := cell_rect(top)
		var b := Rect2(r.end.x - 14, r.position.y - 4, 11, 11)
		_overlay.draw_rect(b, Pal.INK1)
		PartyDraw.soft_outline(_overlay, b, Pal.FADE2)
		_overlay.draw_texture(LOCK, b.position + Vector2(3, 2), Pal.FADE4)


## Topmost: the dragged hero's drop shadow cue and the demo hand.
func _draw_top() -> void:
	if _dragging >= 0 and _target != null:
		# floating result tag above the lifted hero (follows the finger)
		var c: Variant = _target if _target is Array else null
		var res := FormationWords.evaluate(placed_cells(moved(_dragging, c)), unlocked)
		var shape: Dictionary = res["shape"]
		var nm := "Off the grid" if c == null else ("No shape yet" if shape.is_empty() else String(shape["name"]))
		var good: bool = not shape.is_empty() and String(shape["id"]) != "strays" and not res["locked"]
		var lock: bool = res["locked"]
		var p: Vector2 = (_pos[_dragging] as Vector2).round()
		var w := PartyDraw.text_w(nm, PartyDraw.BOLD) + 8 + (8 if lock else 0)
		var plate := Rect2(clampf(p.x - roundi(w / 2.0), 1, size.x - w - 1), p.y - 64, w, 13)
		_top.draw_rect(plate, Pal.CRYSTAL1 if good else Pal.INK1)
		PartyDraw.soft_outline(_top, plate, Pal.CRYSTAL4 if good else Pal.FADE2)
		_top.draw_rect(Rect2(plate.position.x + roundi(w / 2.0) - 1, plate.end.y, 3, 1), Pal.CRYSTAL4 if good else Pal.FADE2)
		_top.draw_rect(Rect2(plate.position.x + roundi(w / 2.0), plate.end.y + 1, 1, 1), Pal.CRYSTAL4 if good else Pal.FADE2)
		var tx := plate.position.x + 4
		if lock:
			_top.draw_texture(LOCK, Vector2(tx, plate.position.y + 3), Pal.FADE4)
			tx += 8
		PartyDraw.text(_top, Vector2(tx, plate.position.y + 1), nm, Pal.CRYSTAL5 if good else Pal.FADE4, PartyDraw.BOLD, 11, false)
	if demo_hand > 0:
		var tex := HAND_POINT if demo_hand == 1 else HAND_GRAB
		_top.draw_texture(tex, (demo_pointer - Vector2(3, 0)).round())
