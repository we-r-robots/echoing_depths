class_name FormationBoard
extends Control
## The side's 2-column x 4-row grid as the battle shows it (FF1 side view, 2x sprites, rows stepping
## toward the viewer and leaning right, BACK column on the left, FRONT on the right toward the foe),
## plus a slim bench of portraits where unplaced heroes wait (also the drop target to take a hero
## off the grid). Placed heroes appear only on the grid.
##
## Input (touch-first, nothing hover-only):
##   drag a hero (on the grid or the bench) onto a slot: placed there; onto a hero: they swap;
##     onto the bench: taken off the grid.
##   tap a hero: it lifts (held); then tap a slot to place it, or the bench to take it off.
## While a hero is held or dragged, every free slot names the formation it would make. When
## nothing is held, the free slots next to the shape name what one more hero would grow it into.

signal changed                  # placement changed (a drop or a tap-place)
signal preview_changed          # the drag target changed (preview_cells() differs)
signal held_changed

const BENCH_OPEN := 40
const BENCH_SHUT := 12
const RIGHT := 408
const ROW_DY := 44
const SKEW := 40                # x step per row (the battle's lean, at 2x)
const COL_DX := 96              # back column sits this far left of the front
const FRONT_X0 := 214           # feet x of the front column, row 0
const ROW0_Y := 124             # feet y of row 0
const SLOPE := 40.0 / 44.0
const TILE_HW := 40
const TILE_TOP := 13
const TILE_BOT := 15
const SLOT_H := 44
const DRAG_START := 3.0
const MAX_PARTY := 4
const LOCK := preload("res://assets/party/lock.png")
const PLUS := preload("res://assets/party_setup/plus.png")
const HAND_POINT := preload("res://assets/party_setup/hand_point.png")
const HAND_GRAB := preload("res://assets/party_setup/hand_grab.png")

var heroes: Array = []          # hero dictionaries (core format; "class" may be advanced)
var placement: Array = []       # per hero: [col, row] or null (waiting on the bench)
var unlocked: Array = []
var held := -1                  # tap-selected hero
var demo_hand := 0              # 0 none, 1 pointing, 2 grabbing (demo / tutorial cursor)
var demo_pointer := Vector2.ZERO
var toast := ""                 # one short line shown for a moment after a change
var toast_t := 0.0

var _sprites: Array[AnimatedSprite2D] = []
var _pos: Array = []            # drawn feet position per hero (eased toward its slot)
var _portraits: Array = []
var _infos: Array = []
var _overlay: Control
var _top: Control
var _press := -1
var _press_at := Vector2.ZERO
var _dragging := -1
var _drag_at := Vector2.ZERO
var _drag_off := Vector2.ZERO
var _target: Variant = null     # slot under the dragged hero's feet, "bench", or null
var _t := 0.0
var _flash := 0.0
var _flash_cells: Array = []
var _dust: Array = []
var _last_shape := ""
var _bench_w := float(BENCH_OPEN)
var _hover: Variant = null      # slot under a hovering mouse (PC), for the result plate
## Horizontal shift of the grid so it stays centred as the bench opens and closes.
static var ox := 0.0


func _ready() -> void:
	size = Vector2(408, 318)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = size
	_overlay.z_index = 8
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


## Adds a hero to the party (it waits on the bench). Returns its index.
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
	var por: Texture2D = SpritePortrait.for_class(base, 24)
	_portraits.append(por if por != null else load(String(info["portrait"])))
	placement.append(slot.duplicate() if slot is Array else null)
	var sp := AnimatedSprite2D.new()
	sp.centered = false
	sp.scale = Vector2(2, 2)
	var frames := HeroCard._frames_for(base)
	if frames:
		sp.sprite_frames = frames
		sp.play(&"idle")
		sp.frame = (i * 5) % maxi(1, frames.get_frame_count(&"idle"))
	add_child(sp)
	_sprites.append(sp)
	_pos.append(feet_of(slot) if slot is Array else _bench_rect(_bench_index(i)).get_center())


# ------------------------------------------------------------------ geometry

## Feet of slot [col, row] (board-local): the battle's side-0 layout at 2x.
static func feet_of(c: Array) -> Vector2:
	var col := int(c[0])
	var row := int(c[1])
	return Vector2(roundf(FRONT_X0 - COL_DX * col + SKEW * row + ox), ROW0_Y + ROW_DY * row)


func bench_rect() -> Rect2:
	return Rect2(0, 0, roundf(_bench_w), 318)


func field_rect() -> Rect2:
	var bw := roundf(_bench_w)
	return Rect2(bw + 4, 0, RIGHT - bw - 4, 318)


func _bench_wanted() -> bool:
	if waiting_count() > 0:
		return true
	if _dragging >= 0 and placement[_dragging] is Array:
		return true
	return held >= 0 and placement[held] is Array


## Is p inside slot c's floor tile (a parallelogram leaning with the rows)?
static func in_tile(c: Array, p: Vector2, grow := 0) -> bool:
	var f := feet_of(c)
	var dy := p.y - f.y
	if dy < -TILE_TOP - grow or dy > TILE_BOT + grow:
		return false
	var dx := p.x - (f.x + dy * SLOPE)
	return absf(dx) <= TILE_HW + grow


func cell_at(p: Vector2) -> Variant:
	for row in 4:
		for col in 2:
			if in_tile([col, row], p, 2):
				return [col, row]
	return null


## Hero whose body or tile is under p (front-most rows first, as drawn).
func hero_at_point(p: Vector2) -> int:
	for row in range(3, -1, -1):
		for col in 2:
			var i := hero_at_cell([col, row])
			if i < 0:
				continue
			var f := feet_of([col, row])
			if Rect2(f.x - 18, f.y - 82, 36, 84).has_point(p) or in_tile([col, row], p):
				return i
	return -1


func hero_at_cell(c: Variant) -> int:
	if not (c is Array):
		return -1
	for i in placement.size():
		var s: Variant = placement[i]
		if s is Array and int(s[0]) == int(c[0]) and int(s[1]) == int(c[1]):
			return i
	return -1


func _bench_rect(k: int) -> Rect2:
	return Rect2(5, 22 + k * 40, 30, 30)


## Position of hero i on the bench (waiting heroes only, in party order); -1 if placed.
func _bench_index(i: int) -> int:
	if i < placement.size() and placement[i] is Array:
		return -1
	var k := 0
	for j in mini(i, placement.size()):
		if not (placement[j] is Array):
			k += 1
	return k


func _bench_hero_at(p: Vector2) -> int:
	for i in heroes.size():
		var k := _bench_index(i)
		if k >= 0 and _bench_rect(k).grow(3).has_point(p):
			return i
	return -1


# ------------------------------------------------------------------ model

func placed_cells(pl: Array = placement) -> Array:
	var out: Array = []
	for s: Variant in pl:
		if s is Array:
			out.append([int(s[0]), int(s[1])])
	return out


## [cells, names] of placed heroes (same order), for role naming.
func placed_names(pl: Array = placement) -> Array:
	var names: Array = []
	for i in pl.size():
		if pl[i] is Array:
			names.append(String(heroes[i].get("name", "")))
	return names


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


## The placement after moving hero i to cell c (null = to the bench); the occupant swaps back.
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
	var bench_before := []
	for k in heroes.size():
		bench_before.append(_bench_index(k))
	placement = moved(i, c)
	if placement == before:
		return
	if c is Array:
		_dust.append([feet_of(c), 0.0])
	for k in placement.size():
		if k != i and placement[k] is Array and not (before[k] is Array):
			_pos[k] = _bench_rect(maxi(0, int(bench_before[k]))).get_center()
	var ev := FormationWords.evaluate(placed_cells(), unlocked)
	var sid := String(ev["shape"].get("id", ""))
	if sid != _last_shape and sid != "" and sid != "strays":
		_flash = 1.0
		_flash_cells = placed_cells()
	toast = _toast_for(ev)
	toast_t = 2.2
	_last_shape = sid
	changed.emit()


static func _toast_for(ev: Dictionary) -> String:
	var shape: Dictionary = ev["shape"]
	if shape.is_empty():
		return ""
	if String(shape["id"]) == "strays":
		return "Strays"
	if ev["locked"]:
		return ""   # the persistent unlock line below says it
	return "%s formed" % shape["name"]


func _shape_id() -> String:
	return String(FormationWords.detect(placed_cells()).get("id", ""))


## Placement the card should describe: the drag preview over a target, else null (current).
func preview_placement() -> Variant:
	if _dragging >= 0 and _target != null:
		return moved(_dragging, _target if _target is Array else null)
	return null


func preview_cells() -> Variant:
	var pl: Variant = preview_placement()
	return placed_cells(pl) if pl is Array else null


func held_or_dragged() -> int:
	return _dragging if _dragging >= 0 else held


func is_dragging() -> bool:
	return _dragging >= 0


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


## Pointer API (the demo drives the same path as a finger).
func pointer_down(p: Vector2) -> void:
	_press_at = p
	_press = hero_at_point(p)
	if _press < 0:
		_press = _bench_hero_at(p)


func pointer_move(p: Vector2) -> void:
	if _press < 0 and _dragging < 0:
		var hv: Variant = cell_at(p)
		if hv != _hover:
			_hover = hv
	if _press >= 0 and _dragging < 0 and p.distance_to(_press_at) > DRAG_START:
		_dragging = _press
		var origin: Vector2 = _pos[_dragging] if placement[_dragging] is Array else p + Vector2(0, 30)
		_drag_off = origin - _press_at
		_pos[_dragging] = origin
		set_held(-1)
	if _dragging >= 0:
		_drag_at = p
		var feet := p + _drag_off
		var t: Variant = cell_at(feet)
		if t == null:
			t = cell_at(p)
		if t == null and bench_rect().grow(4).has_point(p):
			t = "bench"
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
		elif t == "bench":
			move_hero(i, null)
		preview_changed.emit()
		_press = -1
		return
	var c: Variant = cell_at(p)
	var on_bench := bench_rect().has_point(p)
	if held >= 0:
		var hit := hero_at_point(p)
		if hit == held:
			set_held(-1)
		elif hit >= 0 and placement[hit] is Array:
			var i := held
			set_held(-1)
			move_hero(i, placement[hit])
		elif c is Array:
			var i := held
			set_held(-1)
			move_hero(i, c)
		elif on_bench:
			var r := _bench_hero_at(p)
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
	toast_t -= delta
	var goal := float(BENCH_OPEN if _bench_wanted() else BENCH_SHUT)
	_bench_w = move_toward(_bench_w, goal, delta * 220.0)
	ox = roundf((_bench_w - BENCH_OPEN) / 2.0)
	_flash = maxf(0.0, _flash - delta * 1.6)
	for d: Array in _dust:
		d[1] = float(d[1]) + delta
	_dust = _dust.filter(func(d: Array) -> bool: return float(d[1]) < 0.35)
	var k := 1.0 - exp(-delta * 18.0)
	for i in heroes.size():
		var sp := _sprites[i]
		var show := true
		var row := 0
		if i == _dragging:
			_pos[i] = _drag_at + _drag_off
			sp.z_index = 10
		elif placement[i] is Array:
			row = int(placement[i][1])
			_pos[i] = (_pos[i] as Vector2).lerp(feet_of(placement[i]), k)
			sp.z_index = 1 + row
		else:
			show = false
		var lift := 0.0
		if i == _dragging:
			lift = 6.0
		elif i == held and placement[i] is Array:
			lift = 3.0 + roundf(sin(_t * 6.0))
		sp.visible = show
		# feet origin of the 64x64 frame is (32, 60); drawn at 2x
		sp.position = ((_pos[i] as Vector2) - Vector2(64, 120 + lift)).round()
		sp.speed_scale = 1.0
	queue_redraw()
	_overlay.queue_redraw()
	_top.queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	_draw_bench()
	_draw_field()


func _draw_bench() -> void:
	var br := bench_rect()
	var dragging_to_bench: bool = _dragging >= 0 and _target is String and _target == "bench"
	PartyDraw.panel(self, br, 0, &"DimPanel")
	if br.size.x < BENCH_OPEN - 2:
		# collapsed: a thin strip; it opens when a hero needs the bench
		for k in 4:
			draw_rect(Rect2(br.size.x / 2.0 - 1, 40 + k * 70, 2, 30), Pal.INK3)
		return
	if dragging_to_bench or (_dragging >= 0 and placement[_dragging] is Array) or (held >= 0 and placement[held] is Array):
		PartyDraw.soft_outline(self, br.grow(-2), Pal.AMBER5 if dragging_to_bench else Pal.AMBER3)
	PartyDraw.text(self, Vector2(0, 6), "BENCH", Pal.INK9, PartyDraw.SANS, 11, false, BENCH_OPEN, HORIZONTAL_ALIGNMENT_CENTER)
	var shown := 0
	for i in heroes.size():
		var k := _bench_index(i)
		if k < 0:
			continue
		shown += 1
		var r := _bench_rect(k)
		var info: Dictionary = _infos[i]
		if i == held:
			PartyDraw.selected(self, r.grow(2))
		PartyDraw.inset(self, r)
		var on := fmod(_t, 1.0) < 0.6
		PartyDraw.soft_outline(self, r.grow(1), Pal.AMBER5 if on else Pal.AMBER3)
		var m := Color.WHITE if i != _dragging else Color(0.55, 0.55, 0.65)
		draw_texture(_portraits[i], r.position + Vector2(3, 3), m)
		draw_rect(Rect2(r.position.x + 1, r.end.y - 2, r.size.x - 2, 1), Pal.c(info["color"]))
	if dragging_to_bench or (_dragging >= 0 and placement[_dragging] is Array):
		PartyDraw.dashed_outline(self, _bench_rect(shown), Pal.AMBER4, int(_t * 8.0) % 4)


func _fill_tile(c: Array, fill: Color, edge: Color, lit := Color(0, 0, 0, 0)) -> void:
	var f := feet_of(c)
	for dy in range(-TILE_TOP, TILE_BOT + 1):
		var x0 := roundi(f.x + dy * SLOPE) - TILE_HW
		var y := int(f.y) + dy
		if dy == -TILE_TOP or dy == TILE_BOT:
			draw_rect(Rect2(x0 + 1, y, TILE_HW * 2 - 1, 1), edge)
		else:
			var col := fill
			if dy > TILE_BOT - 3:
				col = lit if lit.a > 0.0 else fill
			draw_rect(Rect2(x0, y, TILE_HW * 2 + 1, 1), col)
			draw_rect(Rect2(x0, y, 1, 1), edge)
			draw_rect(Rect2(x0 + TILE_HW * 2, y, 1, 1), edge)


func _dashed_tile(c: Array, col: Color, phase := 0) -> void:
	var f := feet_of(c)
	for dy in range(-TILE_TOP, TILE_BOT + 1):
		var x0 := roundi(f.x + dy * SLOPE) - TILE_HW
		var y := int(f.y) + dy
		if dy == -TILE_TOP or dy == TILE_BOT:
			for x in range(1, TILE_HW * 2, 1):
				if (x + phase) % 4 < 2:
					draw_rect(Rect2(x0 + x, y, 1, 1), col)
		elif (dy + phase) % 4 < 2:
			draw_rect(Rect2(x0, y, 1, 1), col)
			draw_rect(Rect2(x0 + TILE_HW * 2, y, 1, 1), col)


func _outline_tile(c: Array, col: Color, grow := 0) -> void:
	var f := feet_of(c)
	for dy in range(-TILE_TOP - grow, TILE_BOT + grow + 1):
		var x0 := roundi(f.x + dy * SLOPE) - TILE_HW - grow
		var y := int(f.y) + dy
		if dy == -TILE_TOP - grow or dy == TILE_BOT + grow:
			draw_rect(Rect2(x0 + 1, y, (TILE_HW + grow) * 2 - 1, 1), col)
		else:
			draw_rect(Rect2(x0, y, 1, 1), col)
			draw_rect(Rect2(x0 + (TILE_HW + grow) * 2, y, 1, 1), col)


func _draw_field() -> void:
	var field := field_rect()
	PartyDraw.panel(self, field, 0, &"DimPanel")
	# column headings over the top row
	var bx := feet_of([1, 0]).x - 50
	var fx := feet_of([0, 0]).x - 50
	PartyDraw.text(self, Vector2(bx, 5), "BACK", Pal.CRYSTAL4, PartyDraw.BOLD, 11, true, 100, HORIZONTAL_ALIGNMENT_CENTER)
	PartyDraw.text(self, Vector2(bx, 16), "deals and takes", Pal.INK9, PartyDraw.SANS, 11, true, 100, HORIZONTAL_ALIGNMENT_CENTER)
	PartyDraw.text(self, Vector2(bx, 26), "half physical", Pal.INK9, PartyDraw.SANS, 11, true, 100, HORIZONTAL_ALIGNMENT_CENTER)
	PartyDraw.text(self, Vector2(fx, 5), "FRONT", Pal.AMBER5, PartyDraw.BOLD, 11, true, 100, HORIZONTAL_ALIGNMENT_CENTER)
	PartyDraw.text(self, Vector2(fx, 16), "melee hits", Pal.INK9, PartyDraw.SANS, 11, true, 100, HORIZONTAL_ALIGNMENT_CENTER)
	PartyDraw.text(self, Vector2(fx, 26), "here first", Pal.INK9, PartyDraw.SANS, 11, true, 100, HORIZONTAL_ALIGNMENT_CENTER)
	var ev := FormationWords.evaluate(placed_cells(), unlocked)
	var shape: Dictionary = ev["shape"]
	var sid := String(shape.get("id", ""))
	var locked: bool = ev["locked"]
	var cells := placed_cells()
	var hl := held_or_dragged()
	var growth := {}
	if hl < 0 and sid != "" and sid != "strays" and cells.size() < 4:
		for gc: Array in FormationWords.growth_cells(cells):
			var gs := FormationWords.detect(cells + [gc])
			if String(gs.get("id", "strays")) != "strays":
				growth[_key(gc)] = gs
	var in_shape := sid != "" and sid != "strays"
	# floor tiles, back to front
	for row in 4:
		for col in [1, 0]:
			var c := [col, row]
			var occ := hero_at_cell(c)
			if occ == _dragging and occ >= 0:
				occ = -1
			var sill := Pal.AMBER2 if col == 0 else Pal.CRYSTAL1
			if occ >= 0 and in_shape and not locked:
				_fill_tile(c, Pal.CRYSTAL1, Pal.CRYSTAL3, Pal.CRYSTAL2)
			elif occ >= 0:
				_fill_tile(c, Pal.INK3, Pal.INK5, Pal.INK4)
			else:
				_fill_tile(c, Pal.INK2, Pal.INK4, sill)
	_draw_bonds(sid, locked)
	# empty-slot labels: growth (nothing held) or the drop result (held / dragged)
	for row in 4:
		for col in 2:
			var c := [col, row]
			var occ := hero_at_cell(c)
			if hl >= 0:
				_drop_label(c, hl, occ)
			elif occ < 0 and growth.has(_key(c)):
				_growth_label(c, growth[_key(c)])
	if _flash > 0.0:
		for c: Array in _flash_cells:
			var fc := Pal.CRYSTAL5
			fc.a = _flash
			_outline_tile(c, fc, roundi((1.0 - _flash) * 3.0))
	if _dragging >= 0:
		var p: Vector2 = (_pos[_dragging] as Vector2).round()
		var sh := Pal.INK1
		sh.a = 0.7
		draw_rect(Rect2(p.x - 16, p.y + 1, 32, 4), sh)
	for d: Array in _dust:
		var p: Vector2 = d[0]
		var a := float(d[1]) / 0.35
		var spread := roundi(8 + a * 14)
		for sx in [-1, 1]:
			var dc := Pal.INK8
			dc.a = 1.0 - a
			draw_rect(Rect2(p + Vector2(sx * spread, -1 - roundi(a * 4)), Vector2(2, 2)), dc)
	# a short line for a moment after a change
	if toast_t > 0.0 and toast != "" and hl < 0 and not locked:
		var col := Pal.AMBER6 if toast.ends_with("formed") else Pal.FADE4
		PartyDraw.text(self, Vector2(field.position.x, field.end.y - 18), toast, col, PartyDraw.BOLD, 11, true, field.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	elif locked and hl < 0:
		var msg := "%s is locked: unlock it at the Training Grounds" % shape["name"]
		var mw := PartyDraw.text_w(msg, PartyDraw.BOLD) + 12
		var mx := field.position.x + roundi((field.size.x - mw) / 2.0)
		draw_texture(LOCK, Vector2(mx, field.end.y - 16), Pal.FADE4)
		PartyDraw.text(self, Vector2(mx + 10, field.end.y - 18), msg, Pal.FADE4, PartyDraw.BOLD)


static func _key(c: Array) -> int:
	return int(c[0]) * 4 + int(c[1])


func _label_plate(c: Array, nm: String, color: Color, edge: Color, lock: bool, y_off := 0) -> void:
	var f := feet_of(c)
	var w := PartyDraw.text_w(nm, PartyDraw.BOLD) + 8 + (8 if lock else 0)
	var plate := Rect2(roundi(f.x - 4 - w / 2.0), f.y - 6 + y_off, w, 13)
	draw_rect(plate, Pal.INK1)
	PartyDraw.soft_outline(self, plate, edge)
	var tx := plate.position.x + 4
	if lock:
		draw_texture(LOCK, Vector2(tx, plate.position.y + 3), Pal.FADE3)
		tx += 8
	PartyDraw.text(self, Vector2(tx, plate.position.y + 1), nm, color, PartyDraw.BOLD, 11, false)


## A free slot next to the shape: a quiet dashed outline and a "+" (its name is on the card).
func _growth_label(c: Array, _shape: Dictionary) -> void:
	_dashed_tile(c, Pal.INK5)
	var f := feet_of(c)
	draw_texture(PLUS, Vector2(f.x - 2, f.y - 3), Pal.INK6)


## While a hero is held or dragged: every free slot is outlined in the colour of its result
## (crystal = an active shape, grey = Strays or locked). Only the slot under the drag target or
## the hovering mouse gets a name plate.
func _drop_label(c: Array, i: int, occ: int) -> void:
	var is_target: bool = _dragging >= 0 and _target is Array and int(_target[0]) == int(c[0]) and int(_target[1]) == int(c[1])
	if is_target:
		_outline_tile(c, Pal.AMBER6, 1)
		_outline_tile(c, Pal.AMBER4, 0)
		return
	if occ >= 0:
		return
	var res := FormationWords.evaluate(placed_cells(moved(i, c)), unlocked)
	var shape: Dictionary = res["shape"]
	var good: bool = not shape.is_empty() and String(shape["id"]) != "strays" and not res["locked"]
	_dashed_tile(c, Pal.CRYSTAL3 if good else Pal.INK5, int(_t * 8.0) % 4)
	var hovered: bool = _dragging < 0 and _hover is Array and int(_hover[0]) == int(c[0]) and int(_hover[1]) == int(c[1])
	if hovered and not shape.is_empty():
		_label_plate(c, String(shape["name"]), Pal.CRYSTAL5 if good else Pal.FADE4,
			Pal.CRYSTAL3 if good else Pal.INK4, bool(res["locked"]))


## Crystal links across the floor gaps between edge-adjacent heroes of the shape (none for
## Strays). Drawn on the floor in the gap between two tiles, never under a hero's feet.
func _draw_bonds(sid: String, locked: bool) -> void:
	if sid == "" or sid == "strays":
		return
	var dc: Array = []
	for i in placement.size():
		if i != _dragging and placement[i] is Array:
			dc.append(placement[i])
	var c1 := Pal.CRYSTAL4 if not locked else Pal.FADE3
	var c2 := Pal.CRYSTAL2 if not locked else Pal.FADE1
	var lit := int(_t * 2.0) % 2 == 0
	for a: Array in dc:
		for b: Array in dc:
			if int(a[0]) == int(b[0]) and int(b[1]) == int(a[1]) + 1:
				# same column, next row: a short leaning bar from a's front edge to b's back edge
				var fa := feet_of(a)
				var y0 := int(fa.y) + TILE_BOT + 1
				var y1 := int(feet_of(b).y) - TILE_TOP - 1
				for y in range(y0, y1 + 1):
					var x := roundi(fa.x + (y - fa.y) * SLOPE)
					draw_rect(Rect2(x - 4, y, 9, 1), c2)
					draw_rect(Rect2(x - 2, y, 5, 1), c1 if lit or locked else Pal.CRYSTAL5)
			elif int(a[1]) == int(b[1]) and int(a[0]) == 1 and int(b[0]) == 0:
				# same row, back to front: a short bar across the gap between the two tiles
				var fb := feet_of(a)
				var x0 := int(fb.x) + TILE_HW + 1
				var x1 := int(feet_of(b).x) - TILE_HW - 1
				draw_rect(Rect2(x0, fb.y - 2, x1 - x0 + 1, 5), c2)
				draw_rect(Rect2(x0, fb.y - 1, x1 - x0 + 1, 3), c1 if lit or locked else Pal.CRYSTAL5)


## Above the sprites: name plates under the feet; role tags (hidden while dragging a preview).
func _draw_overlay() -> void:
	var ev := FormationWords.evaluate(placed_cells(), unlocked)
	var shape: Dictionary = ev["shape"]
	var sid := String(shape.get("id", ""))
	var cells := placed_cells()
	var roles: Array = []
	if sid != "" and sid != "strays" and not ev["locked"] and _dragging < 0:
		roles = FormationWords.Formation.roles(sid, cells)
	for i in heroes.size():
		if not (placement[i] is Array) or i == _dragging:
			continue
		var c: Array = placement[i]
		var f := (_pos[i] as Vector2).round()
		var nm := String(heroes[i].get("name", "?"))
		var w := PartyDraw.text_w(nm, PartyDraw.BOLD) + 6
		var plate := Rect2(roundi(f.x - 8 - w / 2.0), f.y + 3, w, 12)
		_overlay.draw_rect(plate, Pal.INK1)
		_overlay.draw_rect(Rect2(plate.position.x, plate.end.y - 1, plate.size.x, 1), Pal.c(_infos[i]["color"]))
		PartyDraw.text(_overlay, plate.position + Vector2(3, 0), nm, Pal.INK10 if i != held else Pal.AMBER6, PartyDraw.BOLD, 11, false)
		if roles.is_empty():
			continue
		for k in cells.size():
			if int(cells[k][0]) == int(c[0]) and int(cells[k][1]) == int(c[1]):
				for r: String in roles[k]:
					if FormationWords.ROLE_TAGS.has(r):
						var tag := String(FormationWords.ROLE_TAGS[r])
						var tw := PartyDraw.text_w(tag, PartyDraw.BOLD) + 6
						PartyDraw.pill(_overlay, Vector2(roundi(f.x - tw / 2.0), f.y - 96), tag, Pal.CRYSTAL5, Pal.CRYSTAL1, Pal.CRYSTAL3)
						break


## Topmost: the floating result tag over the dragged hero, and the demo hand.
func _draw_top() -> void:
	if _dragging >= 0 and _target != null:
		var pl: Array = moved(_dragging, _target if _target is Array else null)
		var res := FormationWords.evaluate(placed_cells(pl), unlocked)
		var shape: Dictionary = res["shape"]
		var nm := "Back to the bench" if not (_target is Array) else ("No shape" if shape.is_empty() else String(shape["name"]))
		var good: bool = not shape.is_empty() and String(shape["id"]) != "strays" and not res["locked"] and _target is Array
		var lock: bool = res["locked"]
		var p: Vector2 = (_pos[_dragging] as Vector2).round()
		var w := PartyDraw.text_w(nm, PartyDraw.BOLD) + 8 + (8 if lock else 0)
		var plate := Rect2(clampf(p.x - roundi(w / 2.0), 1, size.x - w - 1), p.y - 106, w, 13)
		var ec := Pal.CRYSTAL4 if good else Pal.FADE2
		_top.draw_rect(plate, Pal.CRYSTAL1 if good else Pal.INK1)
		PartyDraw.soft_outline(_top, plate, ec)
		var cx := plate.position.x + roundi(w / 2.0)
		_top.draw_rect(Rect2(cx - 1, plate.end.y, 3, 1), ec)
		_top.draw_rect(Rect2(cx, plate.end.y + 1, 1, 1), ec)
		var tx := plate.position.x + 4
		if lock:
			_top.draw_texture(LOCK, Vector2(tx, plate.position.y + 3), Pal.FADE4)
			tx += 8
		PartyDraw.text(_top, Vector2(tx, plate.position.y + 1), nm, Pal.CRYSTAL5 if good else Pal.FADE4, PartyDraw.BOLD, 11, false)
	if demo_hand > 0:
		var tex := HAND_POINT if demo_hand == 1 else HAND_GRAB
		_top.draw_texture(tex, (demo_pointer - Vector2(3, 0)).round())
