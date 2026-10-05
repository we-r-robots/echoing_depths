class_name HeroAlignGrid
extends Control
## Large 5x5 alignment grid, the centrepiece of the hero detail screen.
## Rows: Mercy (top) -> Cruelty (bottom). Columns: Order (left) -> Freedom (right), matching
## the encounter AlignGrid. Region boundaries are wide grooves, so the four quadrants, the neutral
## cross and the four corners read as separate plates.
## On the grid itself: start ring, memory trail (crystal line + gems), the underlying position
## (amber dashed ghost) when a Relic offsets it, the hero token at the effective position with its
## class name plaque, corner rarity stars (relative to the class start) and steps from here.
## One highlight colour (crystal) marks focus: the hero's region, the tapped cell, the preview.
## Tapping a cell emits cell_tapped([good, law]).

signal cell_tapped(pos: Array)

const C := 46                 # cell size
const GAPS := [2, 6, 6, 2]    # gaps between columns/rows; the 6px ones are region boundaries
const FRAME := 4
const GEM := preload("res://ui/icons/memory_gem_big.png")
const STAR := preload("res://ui/icons/star.png")
const START := preload("res://assets/party/start.png")
const RELIC := preload("res://assets/party/slot_relic.png")
const HI := Pal.CRYSTAL4      # the one highlight colour

var start := [0, 0]
var trail: Array = []
var underlying := [0, 0]
var effective := [0, 0]
var portrait: Texture2D
var hero_color := Pal.AMBER6
var rarity := {}              # corner region -> 1..3
var names := {}               # region -> display name ("???" while hidden)
var new_regions: Array = []   # regions recorded in the codex during this visit (NEW tag)
var ready_glow := false
var focus_region := ""        # outlined region (advancement destination); "" = hero's own
var reach_cell: Variant = null  # corner a held-back hero could reach (hold preview)
var cursor: Variant = null    # tapped cell or null
var reveal := 0.0             # 0..1 flash on the hero cell (advancement)

var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(total(), total())
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


static func total() -> int:
	return FRAME * 2 + 5 * C + 16


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func set_hero(h: Dictionary, tex: Texture2D, color: Color, region_names: Dictionary) -> void:
	start = PartyModel.start_of(h)
	trail = PartyModel.trail(h)
	underlying = PartyModel.underlying(h)
	effective = PartyModel.effective(h)
	portrait = tex
	hero_color = color
	names = region_names
	ready_glow = PartyModel.ready_to_advance(h) and not h.get("held_back", false)
	rarity.clear()
	for r in ["LG*", "CG*", "LE*", "CE*"]:
		rarity[r] = PartyModel.corner_rarity(h, r)
	cursor = null
	focus_region = ""
	reach_cell = null
	queue_redraw()


func _off(i: int) -> int:
	var o := FRAME + i * C
	for k in i:
		o += GAPS[k]
	return o


## Top-left of the cell for grid position [good, law].
func cell_origin(p: Array) -> Vector2:
	return Vector2(_off(2 - int(p[1])), _off(2 - int(p[0])))


func cell_rect(p: Array) -> Rect2:
	return Rect2(cell_origin(p), Vector2(C, C))


func center(p: Array) -> Vector2:
	return cell_origin(p) + Vector2(C / 2, C / 2)


func _gui_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not press:
		return
	var lp: Vector2 = event.position
	for g in range(-2, 3):
		for l in range(-2, 3):
			if cell_rect([g, l]).grow(3).has_point(lp):
				cursor = [g, l]
				cell_tapped.emit([g, l])
				accept_event()
				return


func _draw() -> void:
	var s := total()
	# frame: ink well, rim, and an axis-coloured bar on each side (pole colours)
	draw_rect(Rect2(0, 0, s, s), Pal.INK1)
	PartyDraw.soft_outline(self, Rect2(0, 0, s, s), Pal.INK5)
	draw_rect(Rect2(FRAME, 1, s - FRAME * 2, 2), PartyModel.axis_color("good", 1))
	draw_rect(Rect2(FRAME, s - 3, s - FRAME * 2, 2), PartyModel.axis_color("good", -1))
	draw_rect(Rect2(1, FRAME, 2, s - FRAME * 2), PartyModel.axis_color("law", 1))
	draw_rect(Rect2(s - 3, FRAME, 2, s - FRAME * 2), PartyModel.axis_color("law", -1))
	for i in [1, 3]:
		var gx := _off(i + 1) - 3
		draw_rect(Rect2(gx - 1, FRAME, 2, s - FRAME * 2), Pal.INK2)
		draw_rect(Rect2(FRAME, gx - 1, s - FRAME * 2, 2), Pal.INK2)
	for g in range(-2, 3):
		for l in range(-2, 3):
			_draw_cell([g, l])
	_draw_focus()
	_draw_trail()
	_draw_markers()
	_draw_corner_info()
	_draw_plaques()


func _draw_cell(p: Array) -> void:
	var region := PartyModel.region_of(p)
	var cols: Array = PartyDraw.REGION_COLORS[region]
	var r := cell_rect(p)
	draw_rect(r, cols[0])
	draw_rect(Rect2(r.position, Vector2(C, 1)), cols[1])
	draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(1, C - 1)), cols[1])
	draw_rect(Rect2(r.position + Vector2(1, C - 1), Vector2(C - 1, 1)), cols[2])
	draw_rect(Rect2(r.position + Vector2(C - 1, 1), Vector2(1, C - 2)), cols[2])
	if region.ends_with("*"):
		PartyDraw.outline(self, r.grow(-3), cols[1])


func _draw_focus() -> void:
	var region := focus_region if focus_region != "" else PartyModel.region_of(effective)
	var c := HI
	if focus_region != "":
		c = Pal.CRYSTAL5 if fmod(_t, 1.0) < 0.6 else Pal.CRYSTAL3
	for g in range(-2, 3):
		for l in range(-2, 3):
			if PartyModel.region_of([g, l]) == region:
				_region_edge([g, l], region, c)
	if reach_cell != null:
		PartyDraw.dashed_outline(self, cell_rect(reach_cell).grow(2), Pal.CRYSTAL5, int(_t * 8.0))


## Outer edges of one region cell, bridging gaps to same-region neighbours.
func _region_edge(p: Array, region: String, c: Color) -> void:
	var r := cell_rect(p).grow(2)
	var g := int(p[0])
	var l := int(p[1])
	var up := g < 2 and PartyModel.region_of([g + 1, l]) == region
	var down := g > -2 and PartyModel.region_of([g - 1, l]) == region
	var left := l < 2 and PartyModel.region_of([g, l + 1]) == region
	var right := l > -2 and PartyModel.region_of([g, l - 1]) == region
	if not up:
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c)
	if not down:
		draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), c)
	if not left:
		draw_rect(Rect2(r.position, Vector2(1, r.size.y)), c)
	if not right:
		draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), c)


func _line_points(a: Vector2, b: Vector2) -> Array:
	var pts := []
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in n + 1:
		pts.append(a.lerp(b, float(i) / maxf(n, 1)).round())
	return pts


func _draw_trail() -> void:
	if trail.size() < 2:
		return
	var segs := []
	for i in range(1, trail.size()):
		if trail[i] != trail[i - 1]:
			segs.append(_line_points(center(trail[i - 1]), center(trail[i])))
	for pts: Array in segs:
		for q: Vector2 in pts:
			draw_rect(Rect2(q - Vector2(2, 2), Vector2(5, 5)), Pal.INK1)
	var total_pts := 0
	for pts: Array in segs:
		total_pts += pts.size()
	var glint := int(fmod(_t * 50.0, float(total_pts + 40)))
	var k := 0
	for pts: Array in segs:
		for q: Vector2 in pts:
			var near := absi(k - glint) < 5
			draw_rect(Rect2(q - Vector2(1, 1), Vector2(3, 3)), Pal.CRYSTAL5 if near else Pal.CRYSTAL3)
			k += 1
	for i in range(1, trail.size()):
		var p: Array = trail[i]
		if p == effective:
			continue
		draw_texture(GEM, center(p) - Vector2(6, 7))


func _draw_markers() -> void:
	# start ring: centre of the start cell (lower-left corner when something sits on the centre)
	var busy: bool = start == effective or start in trail.slice(1)
	var so := cell_origin(start) + Vector2(4, C - 11) if busy else center(start) - Vector2(3, 3)
	PartyDraw.tint_tex(self, START, so, Pal.INK10)
	# underlying ghost and the Relic's pull to the effective cell
	if underlying != effective:
		PartyDraw.dashed_outline(self, cell_rect(underlying).grow(-3), Pal.AMBER5, int(_t * 6.0))
		var a := center(underlying)
		var b := center(effective)
		var mid := a.lerp(b, 0.5).round()
		var mr := Rect2(mid - Vector2(7, 7), Vector2(15, 15))
		draw_rect(mr, Pal.INK1)
		PartyDraw.soft_outline(self, mr, Pal.AMBER5)
		draw_texture(RELIC, mid - Vector2(4, 4), Pal.AMBER6)
	# hero token: portrait in a framed well, upper part of the cell (name plaque goes below)
	var er := cell_rect(effective)
	var tok := Rect2(er.position + Vector2((C - 26) / 2, 4), Vector2(26, 26))
	draw_rect(tok.grow(1), Pal.INK1)
	draw_rect(tok, Pal.INK2)
	if portrait:
		draw_texture(portrait, tok.position + Vector2(1, 1))
	PartyDraw.outline(self, tok, hero_color)
	draw_rect(Rect2(tok.position.x, tok.end.y - 2, tok.size.x, 2), hero_color)
	var ring := Pal.INK10
	if ready_glow:
		ring = Pal.CRYSTAL5 if fmod(_t, 0.9) < 0.55 else Pal.CRYSTAL3
	PartyDraw.soft_outline(self, er.grow(1), ring)
	if reveal > 0.0:
		var f := Pal.CRYSTAL5
		f.a = reveal
		draw_rect(er.grow(2), f)


## Corner cells: rarity stars (relative to the class start) and steps from where the hero stands.
func _draw_corner_info() -> void:
	for r in ["LG*", "CG*", "LE*", "CE*"]:
		var cell := PartyModel.region_cell(r)
		if cell == effective:
			continue
		var cr := cell_rect(cell)
		var n: int = rarity.get(r, 1)
		var acc: Color = PartyDraw.REGION_ACCENT[r]
		var sw := n * 8 - 1
		var sx := cr.position.x + (C - sw) / 2
		for k in n:
			PartyDraw.tint_tex(self, STAR, Vector2(sx + k * 8, cr.position.y + 7), acc)
		var d := PartyModel.steps(effective, cell)
		var t := "%d step%s" % [d, "" if d == 1 else "s"]
		var tw := PartyDraw.text_w(t, PartyDraw.BOLD)
		var tr := Rect2(cr.position.x + (C - tw - 6) / 2, cr.position.y + 28, tw + 6, 12)
		draw_rect(tr, Pal.INK1)
		PartyDraw.text(self, tr.position + Vector2(3, 1), t, Pal.INK10, PartyDraw.BOLD, PartyDraw.SANS_SIZE, false)


func _plaque(cx: float, y: float, s: String, fg: Color, edge: Color, tag := "") -> void:
	var w := PartyDraw.text_w(s, PartyDraw.BOLD) + 8
	var tw := 0
	if tag != "":
		tw = PartyDraw.text_w(tag, PartyDraw.BOLD) + 8
	var r := Rect2(roundf(cx - (w + tw) / 2.0), y, w + tw, 13)
	draw_rect(r, Pal.INK1)
	PartyDraw.soft_outline(self, r, edge)
	PartyDraw.text(self, r.position + Vector2(4, 1), s, fg, PartyDraw.BOLD, PartyDraw.SANS_SIZE, false)
	if tag != "":
		var tr := Rect2(r.position.x + w - 1, r.position.y + 2, tw - 2, 9)
		draw_rect(tr, Pal.CRYSTAL4)
		PartyDraw.text(self, tr.position + Vector2(3, -1), tag, Pal.INK1, PartyDraw.BOLD, PartyDraw.SANS_SIZE, false)


func _draw_plaques() -> void:
	var here := PartyModel.region_of(effective)
	var er := cell_rect(effective)
	var nm := String(names.get(here, "???"))
	_plaque(er.position.x + C / 2.0, er.position.y + 32, nm, Pal.INK10 if nm != "???" else Pal.INK8, HI,
		"NEW" if here in new_regions else "")
	if focus_region != "" and focus_region != here:
		var fc := center(PartyModel.region_cell(focus_region))
		var fn := String(names.get(focus_region, "???"))
		_plaque(fc.x, fc.y - 6, fn, Pal.INK10, HI)
	if cursor != null and cursor != effective:
		var cr := cell_rect(cursor)
		_brackets(cr.grow(3), HI)
		var cn := String(names.get(PartyModel.region_of(cursor), "???"))
		var y := cr.position.y + (C - 13) / 2.0
		if PartyModel.region_of(cursor).ends_with("*"):
			y = cr.position.y + 15
		_plaque(cr.position.x + C / 2.0, y, cn, Pal.INK10 if cn != "???" else Pal.INK8, HI)


func _brackets(r: Rect2, c: Color) -> void:
	var L := 6
	for corner in [r.position, Vector2(r.end.x - 1, r.position.y), Vector2(r.position.x, r.end.y - 1), r.end - Vector2(1, 1)]:
		var sx := 1 if corner.x == r.position.x else -1
		var sy := 1 if corner.y == r.position.y else -1
		var hx := corner.x if sx == 1 else corner.x - L + 1
		var vy := corner.y if sy == 1 else corner.y - L + 1
		draw_rect(Rect2(hx, corner.y if sy == 1 else corner.y - 1, L, 2), c)
		draw_rect(Rect2(corner.x if sx == 1 else corner.x - 1, vy, 2, L), c)
