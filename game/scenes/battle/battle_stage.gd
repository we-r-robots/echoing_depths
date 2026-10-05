extends Node2D
## The Vault environment behind the fight: painted chamber, animated brazier flames and light,
## drifting motes in the light shaft, the 2x4 slot markers on each side (with FRONT / BACK 1/2
## floor labels) and the formation glyph that links the occupied slots into the formation's shape.

const Layout = preload("res://scenes/battle/battle_layout.gd")
const BG = preload("res://assets/battle/bg_vault_wide.png")   # bg_vault.png + 120 px wings each side
const BG_WING := 120
const FLAME = preload("res://assets/battle/flame.png")
const GLOW = preload("res://assets/battle/glow.png")
const BRAZIERS: Array[Vector2] = [Vector2(26, 168), Vector2(614, 168)]   # screen px (bg layer)
const N_MOTES := 36
const NB: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]

var bg: Sprite2D
var bg_layer: CanvasLayer
var bg_root: Node2D                 # the 640x360 frame of the painted chamber, centred in the view
var slot_pulse := {}                # Vector3i(side, col, row) -> 0..1 formation-proc tint
var _flames: Array[AnimatedSprite2D] = []
var _glows: Array[Sprite2D] = []
var _t := 0.0
var _mx := PackedFloat32Array()
var _my := PackedFloat32Array()
var _mp := PackedFloat32Array()
var _ell := PackedVector2Array()
var _quad := PackedVector2Array()
var _quad4 := PackedVector2Array()
var _quad_in := PackedVector2Array()

# set by the battle controller
var occupied := [{}, {}]            # side -> {Vector2i(col,row): true}
var alive_cells := [{}, {}]
var side_colors: Array[Color] = [Pal.AMBER5, Pal.CRYSTAL4]
var glyph_reveal := 0.0             # 0..1 drawn during the intro
var glyph_pulse: Array[float] = [0.0, 0.0]
var labels_alpha := 1.0
var doom := 0.0                     # sudden-death red shift 0..1
var victory_light := 0.0


func setup() -> void:
	# the painted chamber is screen-space art at 1x; the field above it is world-space at 2x zoom
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	bg_root = Node2D.new()
	bg_layer.add_child(bg_root)
	bg = Sprite2D.new()
	bg.texture = BG
	bg.centered = false
	bg.position = Vector2(-Layout.BG_MARGIN - BG_WING, -Layout.BG_MARGIN)
	bg_root.add_child(bg)
	var frames := SpriteFrames.new()
	frames.add_animation(&"burn")
	frames.set_animation_speed(&"burn", 10.0)
	for i in 6:
		var at := AtlasTexture.new()
		at.atlas = FLAME
		at.region = Rect2(i * 16, 0, 16, 28)
		frames.add_frame(&"burn", at)
	for i in BRAZIERS.size():
		var g := Sprite2D.new()
		g.texture = GLOW
		g.position = BRAZIERS[i] + Vector2(0, -8)
		g.modulate = Color(Pal.AMBER5, 0.5)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = m
		bg_root.add_child(g)
		_glows.append(g)
		var f := AnimatedSprite2D.new()
		f.sprite_frames = frames
		f.centered = false
		f.position = BRAZIERS[i] + Vector2(-8, -30)
		f.play(&"burn")
		f.frame = i * 3
		bg_root.add_child(f)
		_flames.append(f)
	_mx.resize(N_MOTES)
	_my.resize(N_MOTES)
	_mp.resize(N_MOTES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in N_MOTES:
		_mx[i] = rng.randf_range(170, 470)
		_my[i] = rng.randf_range(100, 240)
		_mp[i] = rng.randf() * TAU
	_ell.resize(17)
	_quad.resize(5)
	_quad4.resize(4)
	_quad_in.resize(5)


## Centre the chamber's 640x360 frame in a view of `view_size` (wider on wide screens: the wings
## show more wall and floor), shifted by the camera shake `shake`.
func place_bg(view_size: Vector2, shake: Vector2) -> void:
	bg_root.position = ((view_size - Vector2(640, 360)) / 2.0).round() + shake


func tick(vdt: float) -> void:
	_t += vdt
	for i in _glows.size():
		var fl := 0.5 + 0.08 * sin(_t * 9.0 + i * 2.0) + 0.05 * sin(_t * 23.0 + i)
		var c := Pal.AMBER5.lerp(Pal.BLOOD3, doom)
		_glows[i].modulate = Color(c, fl)
		_flames[i].modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.55), doom)
	for k in 2:
		glyph_pulse[k] = maxf(0.0, glyph_pulse[k] - vdt * 1.4)
	for key: Vector3i in slot_pulse:
		slot_pulse[key] = maxf(0.0, float(slot_pulse[key]) - vdt * 1.2)
	for i in N_MOTES:
		_my[i] -= vdt * (3.0 + (i % 4))
		_mx[i] += sin(_t * 0.7 + _mp[i]) * vdt * 3.0
		if _my[i] < 96:
			_my[i] = 240
	bg.modulate = Color.WHITE.lerp(Color(1.0, 0.72, 0.78), doom * 0.8)
	queue_redraw()


func _draw() -> void:
	# light-shaft motes
	for i in N_MOTES:
		var a := 0.35 + 0.35 * sin(_t * 2.0 + _mp[i])
		var c := Pal.CRYSTAL5.lerp(Pal.BLOOD4, doom)
		draw_rect(Rect2(roundf(_mx[i]), roundf(_my[i]), 1, 1), Color(c, a * 0.6))
	# slot markers and glyphs, per side
	for side in 2:
		var sc: Color = side_colors[side]
		var pulse: float = glyph_pulse[side]
		for col in 2:
			for row in 4:
				var p := Layout.slot_pos(side, col, row)
				var cell := Vector2i(col, row)
				var occ: bool = occupied[side].has(cell)
				var alive: bool = alive_cells[side].has(cell)
				var c := Color(Pal.INK6, 0.55)
				if occ:
					c = Color(sc, (0.45 + 0.55 * pulse) * glyph_reveal) if alive else Color(Pal.FADE1, 0.7)
				_tile(p, row, c, col == 1, occ and alive)
				var sp: float = minf(1.0, slot_pulse.get(Vector3i(side, col, row), 0.0))
				if sp > 0.0:
					_quad_fill()
					draw_colored_polygon(_quad4, Color(sc, 0.85 * sp))
					draw_polyline(_quad, Color(Pal.INK10, sp), 1.0)
		# formation glyph: link orthogonally adjacent occupied cells
		if glyph_reveal > 0.0:
			var gc := Color(sc, (0.55 + 0.45 * pulse) * glyph_reveal)
			var width := 1.0
			for cell: Vector2i in occupied[side]:
				for nb: Vector2i in NB:
					var o: Vector2i = cell + nb
					if occupied[side].has(o):
						var a := Layout.slot_pos(side, cell.x, cell.y)
						var b := Layout.slot_pos(side, o.x, o.y)
						var mid := a.lerp(b, clampf(glyph_reveal * 1.4, 0.0, 1.0))
						draw_line(a, mid, gc, width)
				if pulse > 0.05:
					var pp := Layout.slot_pos(side, cell.x, cell.y)
					_ellipse(pp, 15.0 + 6.0 * (1.0 - pulse), 4.0 + 2.0 * (1.0 - pulse), Color(Pal.INK10, pulse * 0.7))


## A slot tile on the floor: a trapezoid that follows the floor perspective.
func _tile(p: Vector2, _row: int, c: Color, back: bool, lit: bool) -> void:
	var hw := 17.0
	var hd := 7.0
	var sk := Layout.SLOPE * hd
	_quad[0] = Vector2(roundf(p.x - hw - sk), p.y - hd)
	_quad[1] = Vector2(roundf(p.x + hw - sk), p.y - hd)
	_quad[2] = Vector2(roundf(p.x + hw + sk), p.y + hd)
	_quad[3] = Vector2(roundf(p.x - hw + sk), p.y + hd)
	_quad[4] = _quad[0]
	if lit:
		draw_colored_polygon(_quad_fill(), Color(c, c.a * 0.18))
	else:
		draw_colored_polygon(_quad_fill(), Color(Pal.INK1, 0.25))
	draw_polyline(_quad, c, 1.0)
	if back:
		# back column: an inner ring marks the half-damage rank
		for i in 5:
			_quad_in[i] = _quad[i].lerp(p, 0.45).round()
		draw_polyline(_quad_in, Color(c, c.a * 0.7), 1.0)


func _quad_fill() -> PackedVector2Array:
	for i in 4:
		_quad4[i] = _quad[i]
	return _quad4


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	for k in 17:
		var a := TAU * k / 16.0
		_ell[k] = Vector2(roundf(c.x + cos(a) * rx), roundf(c.y + sin(a) * ry))
	draw_polyline(_ell, col, 1.0)
