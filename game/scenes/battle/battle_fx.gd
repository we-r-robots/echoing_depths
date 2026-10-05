extends Node2D
## Pooled battle effects drawn in world space: sprite effects (sparks, bursts, slashes, heal glows),
## particles, projectiles, floor rings and light pillars. Damage/heal numbers and their tags are
## laid out in world space (so they stay pinned to their target) but drawn on the UI layer at native
## resolution, through the battle's world -> UI transform.
## Everything is pre-allocated in setup(); the per-frame path only mutates pooled slots.

const BURST = preload("res://assets/battle/burst.png")
const SLASH = preload("res://assets/battle/slash.png")
const META_PATH := "res://assets/sprites/sprite_meta.json"

enum Row { PHYS, MAGIC, CRIT, HEAL, DEATH, MUTED }
## Number colours per row (fill), matching the old digit sheet.
const ROW_COL := [Pal.INK10, Pal.VIOLET4, Pal.AMBER6, Pal.LIFE4, Pal.BLOOD4, Pal.FADE4]
## UI sizes (UIText grid): the number, a head word (CRIT! / KO!), a tag or formation cue.
const NUM_SIZE := 25
const NUM_PUNCH := 30
const HEAD_SIZE := UIText.NUMBER
const TAG_SIZE := UIText.LABEL
const ZOOM := 2.0                    # world -> UI design px (the battle camera's zoom)
const MAX_SPR := 24
const MAX_PART := 320
const MAX_PROJ := 10
const MAX_RING := 20
const MAX_PILLAR := 8
const MAX_POP := 40
const MAX_LIGHT := 12
const GLOW = preload("res://assets/battle/glow.png")
const SHARD = preload("res://assets/battle/shard.png")
const LabelLayout = preload("res://scenes/battle/label_layout.gd")

# sprite fx pool
var _sprites: Array[AnimatedSprite2D] = []
var _spr_next := 0
var _frames: SpriteFrames

# particles (struct-of-arrays)
var _px := PackedFloat32Array()
var _py := PackedFloat32Array()
var _vx := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _life := PackedFloat32Array()
var _lmax := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _pcol := PackedColorArray()
var _psize := PackedInt32Array()
var _part_next := 0

# projectiles (sim time)
var _pj_on: Array[bool] = []
var _pj_from := PackedVector2Array()
var _pj_to := PackedVector2Array()
var _pj_t0 := PackedFloat32Array()
var _pj_t1 := PackedFloat32Array()
var _pj_col := PackedColorArray()
var _pj_col2 := PackedColorArray()
var _pj_kind := PackedInt32Array()      # 0 orb, 1 meteor (falls from above), 2 dagger streak
var _pj_arc := PackedFloat32Array()

# rings (visual time)
var _rg_on: Array[bool] = []
var _rg_c := PackedVector2Array()
var _rg_r0 := PackedFloat32Array()
var _rg_r1 := PackedFloat32Array()
var _rg_t := PackedFloat32Array()
var _rg_dur := PackedFloat32Array()
var _rg_col := PackedColorArray()
var _rg_flat := PackedFloat32Array()
var _ring_pts := PackedVector2Array()

# light pillars (visual time)
var _pl_on: Array[bool] = []
var _pl_x := PackedFloat32Array()
var _pl_y := PackedFloat32Array()
var _pl_t := PackedFloat32Array()
var _pl_dur := PackedFloat32Array()
var _pl_w := PackedFloat32Array()
var _pl_col := PackedColorArray()

# popups (visual time)
var _pp_on: Array[bool] = []
var _pp_val := PackedInt32Array()
var _pp_row := PackedInt32Array()
var _pp_x := PackedFloat32Array()
var _pp_y := PackedFloat32Array()
var _pp_t := PackedFloat32Array()
var _pp_scale := PackedInt32Array()
var _pp_plus: Array[bool] = []
var _pp_head: Array[String] = []        # small word above the number ("CRIT", "KO")
var _pp_small: Array[bool] = []         # head drawn in the light font (formation cues)
var _pp_head_col := PackedColorArray()
var _pp_tag: Array[String] = []         # one annotation under the number
var _pp_tag_col := PackedColorArray()
var _pp_ko: Array[bool] = []           # KO! pill beside the number
var _pp_ko_t := PackedFloat32Array()    # when the pill shows (label time)
var _pp_unit := PackedInt32Array()      # the unit the label belongs to
var _pp_box: Array[Rect2] = []          # its laid-out box (world px)

var sim_t := 0.0
var _pop_node: Control              # UI-layer canvas the numbers draw on
var _to_ui: Callable                # world point -> UI design px
# sweeps (visual time): a bright blade line drawn from a to b, e.g. Cleave across a column
var _sw_a := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _sw_b := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _sw_t := PackedFloat32Array([9.0, 9.0, 9.0, 9.0])
var _sw_col := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
var _sw_next := 0
var _pp_link := PackedVector2Array()
var _last_pop := 0
var _sh_pos := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _sh_seg := PackedInt32Array([0, 0, 0, 0])
var _sh_col := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
var _sh_t := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _sh_next := 0
var _shard_t := -1.0
var _shard_from := Vector2.ZERO
var _shard_to := Vector2.ZERO
var _shield_pts := PackedVector2Array()
var _sw_thin: Array[bool] = [false, false, false, false]

# additive light pools (visual time): the "dynamic lighting" of casts, impacts and KOs
var _lights: Array[Sprite2D] = []
var _lt := PackedFloat32Array()
var _ldur := PackedFloat32Array()
var _la := PackedFloat32Array()
var _lcol := PackedColorArray()
var _light_next := 0


func setup(pop_canvas: Control, to_ui: Callable) -> void:
	_to_ui = to_ui
	_build_frames()
	for i in MAX_SPR:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = _frames
		s.visible = false
		s.animation_finished.connect(s.hide)
		add_child(s)
		_sprites.append(s)
	_px.resize(MAX_PART); _py.resize(MAX_PART); _vx.resize(MAX_PART); _vy.resize(MAX_PART)
	_life.resize(MAX_PART); _lmax.resize(MAX_PART); _grav.resize(MAX_PART)
	_pcol.resize(MAX_PART); _psize.resize(MAX_PART)
	_pj_on.resize(MAX_PROJ); _pj_from.resize(MAX_PROJ); _pj_to.resize(MAX_PROJ); _pj_t0.resize(MAX_PROJ)
	_pj_t1.resize(MAX_PROJ); _pj_col.resize(MAX_PROJ); _pj_col2.resize(MAX_PROJ); _pj_kind.resize(MAX_PROJ); _pj_arc.resize(MAX_PROJ)
	_rg_on.resize(MAX_RING); _rg_c.resize(MAX_RING); _rg_r0.resize(MAX_RING); _rg_r1.resize(MAX_RING)
	_rg_t.resize(MAX_RING); _rg_dur.resize(MAX_RING); _rg_col.resize(MAX_RING); _rg_flat.resize(MAX_RING)
	_ring_pts.resize(33)
	_pl_on.resize(MAX_PILLAR); _pl_x.resize(MAX_PILLAR); _pl_y.resize(MAX_PILLAR); _pl_t.resize(MAX_PILLAR)
	_pl_dur.resize(MAX_PILLAR); _pl_w.resize(MAX_PILLAR); _pl_col.resize(MAX_PILLAR)
	_pp_on.resize(MAX_POP); _pp_val.resize(MAX_POP); _pp_row.resize(MAX_POP); _pp_x.resize(MAX_POP)
	_pp_y.resize(MAX_POP); _pp_t.resize(MAX_POP); _pp_scale.resize(MAX_POP); _pp_plus.resize(MAX_POP)
	_pp_small.resize(MAX_POP)
	_pp_head.resize(MAX_POP); _pp_head_col.resize(MAX_POP); _pp_tag.resize(MAX_POP); _pp_tag_col.resize(MAX_POP)
	_pp_link.resize(MAX_POP)
	_pp_ko.resize(MAX_POP); _pp_ko_t.resize(MAX_POP); _pp_unit.resize(MAX_POP); _pp_box.resize(MAX_POP)
	_shield_pts.resize(6)
	_pop_node = pop_canvas
	_pop_node.draw.connect(_draw_pop_layer)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in MAX_LIGHT:
		var l := Sprite2D.new()
		l.texture = GLOW
		l.material = add
		l.visible = false
		l.z_index = -45
		l.z_as_relative = false
		add_child(l)
		_lights.append(l)
	_lt.resize(MAX_LIGHT); _ldur.resize(MAX_LIGHT); _la.resize(MAX_LIGHT); _lcol.resize(MAX_LIGHT)


func _build_frames() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	var src: SpriteFrames = load(String(meta["fx"]["path"]))
	_frames = SpriteFrames.new()
	_frames.remove_animation(&"default")
	for a: StringName in src.get_animation_names():
		_frames.add_animation(a)
		_frames.set_animation_loop(a, false)
		_frames.set_animation_speed(a, src.get_animation_speed(a))
		for i in src.get_frame_count(a):
			_frames.add_frame(a, src.get_frame_texture(a, i))
	_add_strip(&"burst", BURST, 64, 6, 24.0)
	_add_strip(&"slash", SLASH, 48, 5, 26.0)


func _add_strip(anim: StringName, tex: Texture2D, size: int, n: int, fps: float) -> void:
	_frames.add_animation(anim)
	_frames.set_animation_loop(anim, false)
	_frames.set_animation_speed(anim, fps)
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * size, 0, size, tex.get_height())
		_frames.add_frame(anim, at)


# ------------------------------------------------------------------------------------ spawners
func sprite_fx(anim: StringName, pos: Vector2, flip := false, tint := Color.WHITE, speed := 1.0) -> void:
	if not _frames.has_animation(anim):
		return
	var s := _sprites[_spr_next]
	_spr_next = (_spr_next + 1) % MAX_SPR
	s.position = Vector2(roundf(pos.x), roundf(pos.y))
	s.flip_h = flip
	s.modulate = tint
	s.speed_scale = speed
	s.visible = true
	s.play(anim)
	s.frame = 0


func particles(pos: Vector2, n: int, col: Color, speed: float, up: float, life: float, grav: float, size := 1, spread := 1.0) -> void:
	for i in n:
		var k := _part_next
		_part_next = (_part_next + 1) % MAX_PART
		var a := randf() * TAU
		var v := speed * (0.4 + randf() * 0.6)
		_px[k] = pos.x + randf_range(-3, 3) * spread
		_py[k] = pos.y + randf_range(-3, 3) * spread
		_vx[k] = cos(a) * v
		_vy[k] = sin(a) * v * 0.6 - up
		_life[k] = life * (0.6 + randf() * 0.4)
		_lmax[k] = _life[k]
		_grav[k] = grav
		_pcol[k] = col
		_psize[k] = size


func projectile(from: Vector2, to: Vector2, t0: float, t1: float, col: Color, col2: Color, kind := 0, arc := 0.0) -> void:
	for i in MAX_PROJ:
		if not _pj_on[i]:
			_pj_on[i] = true
			_pj_from[i] = from
			_pj_to[i] = to
			_pj_t0[i] = t0
			_pj_t1[i] = t1
			_pj_col[i] = col
			_pj_col2[i] = col2
			_pj_kind[i] = kind
			_pj_arc[i] = arc
			return


func ring(c: Vector2, r0: float, r1: float, dur: float, col: Color, flat := 0.35) -> void:
	r1 = minf(r1, maxf(8.0, minf(c.x - 162.0, 478.0 - c.x)))   # never runs off the view
	for i in MAX_RING:
		if not _rg_on[i]:
			_rg_on[i] = true
			_rg_c[i] = c
			_rg_r0[i] = r0
			_rg_r1[i] = r1
			_rg_t[i] = 0.0
			_rg_dur[i] = dur
			_rg_col[i] = col
			_rg_flat[i] = flat
			return


func pillar(x: float, y: float, w: float, dur: float, col: Color) -> void:
	for i in MAX_PILLAR:
		if not _pl_on[i]:
			_pl_on[i] = true
			_pl_x[i] = x
			_pl_y[i] = y
			_pl_t[i] = 0.0
			_pl_dur[i] = dur
			_pl_w[i] = w
			_pl_col[i] = col
			return


## Label metrics (world units: UI design px / ZOOM). A label is one box: the rise room, the head
## word (CRIT!), the number line (with the KO! pill beside the number) and the tag line.
const NUM_H := 11.0 * NUM_SIZE / 15.0 / ZOOM + 1.5        # cap + outline
const HEAD_H := 11.0 * HEAD_SIZE / 15.0 / ZOOM + 4.0   # + the gap over the number's ring
const TAG_H := 11.0 * TAG_SIZE / 15.0 / ZOOM + 2.5
## How far a number rises after it lands (world px; x6 = screen px at 1080p).
const NUM_RISE := 2.0
## How far a number's box may reach into its own head (world px): the box's bottom holds the rise
## room, so the digits land just over the crown.
const HEAD_DIP := 3.0
## The KO! pill beside a number: gap to the number and padding round the word (UI design px).
const KO_GAP := 3.0
const KO_PAD := 3.0

## The solver's view of the field, set by the controller before each popup (BattleFX labels are
## world-space): every unit {uid, body, bar}, the HUD rects labels keep clear of, and the field.
var units_geo: Array = []
## Tests: every placement with the field it was solved against (tests/test_label_layout.gd).
var recording := false
var record: Array = []
var blocked: Array = []
var field := Rect2(164, 92, 312, 176)


## The label box size for its contents (world px).
static func label_size(value: int, plus: bool, head: String, small: bool, tag: String, ko: bool) -> Vector2:
	var row_w := 0.0
	var h := 0.0
	if value >= 0:
		row_w = (UIText.width(("+" if plus else "") + str(value), UIText.BOLD, NUM_SIZE) + 4.0) / ZOOM
		if ko:
			row_w += (KO_GAP + _ko_w()) / ZOOM
		h += NUM_RISE + NUM_H
	elif ko:
		row_w = _ko_w() / ZOOM
		h += NUM_RISE + HEAD_H
	var hw := 0.0
	if head != "":
		var hs := TAG_SIZE if small else HEAD_SIZE
		hw = (UIText.width(head, UIText.BOLD, hs) + (8.0 if small else 3.0)) / ZOOM
		h += (TAG_H + 1.0) if small else HEAD_H
		if value < 0 and not small:
			h += NUM_RISE
	var tw := (UIText.width(tag, UIText.BOLD, TAG_SIZE) + 3.0) / ZOOM if tag != "" else 0.0
	if tag != "":
		h += TAG_H
	return Vector2(ceilf(maxf(row_w, maxf(hw, tw))), ceilf(h))


static func _ko_w() -> float:
	return UIText.width("KO!", UIText.BOLD, HEAD_SIZE) + KO_PAD * 2.0


## Link the last popup to a point (e.g. the hit that a shared/halved number came from).
func link_last(to: Vector2) -> void:
	_pp_link[_last_pop] = to


## A segmented shield on a unit: one lit segment per supporting ally (Hearthguard).
func shield(pos: Vector2, segments: int, col: Color, dur: float) -> void:
	_sh_pos[_sh_next] = pos
	_sh_seg[_sh_next] = segments
	_sh_col[_sh_next] = col
	_sh_t[_sh_next] = dur
	_sh_next = (_sh_next + 1) % 4


func _geo(uid: int) -> Dictionary:
	for g: Dictionary in units_geo:
		if int(g["uid"]) == uid:
			return g
	return {}


## Lays out label j against everything else on screen this action (LabelLayout.place).
func _place(j: int) -> void:
	var sz := label_size(_pp_val[j], _pp_plus[j], _pp_head[j], _pp_small[j], _pp_tag[j], _pp_ko[j])
	var own := _geo(_pp_unit[j])
	if own.is_empty():
		own = {"uid": _pp_unit[j], "body": Rect2(_pp_x[j] - 11.0, _pp_y[j], 22.0, 40.0), "bar": Rect2()}
	var body: Rect2 = own["body"]
	var bar: Rect2 = own["bar"]
	# a number's box may dip HEAD_DIP into its own head: after the rise its digits sit on the crown
	var pref := Vector2(body.get_center().x, body.position.y + HEAD_DIP)
	if _pp_small[j]:
		# formation cues sit under the unit's plate, numbers over its head
		pref.y = maxf(body.end.y, bar.end.y if bar.has_area() else body.end.y) + 1.0 + sz.y
	var placed: Array = []
	for k in MAX_POP:
		if k != j and _pp_on[k]:
			placed.append(_pp_box[k])
	_pp_box[j] = LabelLayout.place(sz, pref, own, units_geo, placed, blocked, field)
	if recording:
		record.append({"uid": _pp_unit[j], "box": _pp_box[j], "text": _label_text(j), "geo": units_geo.duplicate(),
			"placed": placed, "blocked": blocked.duplicate(), "field": field, "small": _pp_small[j]})
	_pp_x[j] = _pp_box[j].get_center().x
	_pp_y[j] = _pp_box[j].end.y


func last_box() -> Rect2:
	return _pp_box[_last_pop]


## Every live label's box this action (world px), for tests and checks.
func label_boxes() -> Array:
	var out: Array = []
	for j in MAX_POP:
		if _pp_on[j]:
			out.append({"uid": _pp_unit[j], "box": _pp_box[j], "text": _label_text(j)})
	return out


func _label_text(j: int) -> String:
	var s := _pp_head[j]
	if _pp_val[j] >= 0:
		s += (" " if s != "" else "") + str(_pp_val[j])
	if _pp_ko[j]:
		s += " KO!"
	if _pp_tag[j] != "":
		s += " " + _pp_tag[j]
	return s


## A number (value >= 0) or word label on unit `uid`, laid out with the action's other labels.
## `delay` staggers popups that land together; `ko` adds the KO! pill beside the number.
func popup(value: int, row: int, uid: int, scale: int, plus: bool, head: String, head_col: Color, tag: String, tag_col: Color, delay := 0.0, ko := false, small := false) -> int:
	# one number per target per action: a further hit on the same target adds to its number
	if value >= 0:
		for j in MAX_POP:
			if _pp_on[j] and _pp_unit[j] == uid and not _pp_small[j] and _pp_val[j] >= 0 and _pp_row[j] != Row.HEAL and row != Row.HEAL:
				_pp_val[j] += value
				_pp_t[j] = minf(_pp_t[j], 0.0)
				if head != "" and _pp_head[j] == "":
					_pp_head[j] = head
					_pp_head_col[j] = head_col
				if row == Row.CRIT:
					_pp_row[j] = row
				if tag != "" and _pp_tag[j] == "":
					_pp_tag[j] = tag
					_pp_tag_col[j] = tag_col
				if ko and not _pp_ko[j]:
					_pp_ko[j] = true
					_pp_ko_t[j] = maxf(0.0, _pp_t[j]) + 0.3
				_place(j)
				_last_pop = j
				return j
	var best := 0
	var oldest := -1.0
	for i in MAX_POP:
		if not _pp_on[i]:
			best = i
			break
		if _pp_t[i] > oldest:
			oldest = _pp_t[i]
			best = i
	_pp_on[best] = false
	_pp_unit[best] = uid
	_pp_link[best] = Vector2.ZERO
	_pp_small[best] = small
	_pp_val[best] = value
	_pp_row[best] = row
	_pp_t[best] = -delay
	_pp_scale[best] = scale
	_pp_plus[best] = plus
	_pp_head[best] = head
	_pp_head_col[best] = head_col
	_pp_tag[best] = tag
	_pp_tag_col[best] = tag_col
	_pp_ko[best] = ko
	_pp_ko_t[best] = 0.3 if ko and value >= 0 else 0.0
	_place(best)
	_pp_on[best] = true
	_last_pop = best
	return best


## KO on unit `uid`: the pill joins that unit's number this action, or stands alone on its pill.
func ko(uid: int, delay := 0.3) -> void:
	for j in MAX_POP:
		if _pp_on[j] and _pp_unit[j] == uid and _pp_val[j] >= 0 and not _pp_small[j]:
			if not _pp_ko[j]:
				_pp_ko[j] = true
				_pp_ko_t[j] = maxf(0.0, _pp_t[j]) + delay
				_place(j)
			return
	popup(-1, Row.MUTED, uid, 1, false, "", Pal.BLOOD4, "", Color.WHITE, delay, true)


## Light-font cue (formation effects) under unit `uid`'s plate: quieter than numbers and KO.
func cue(text: String, uid: int, col: Color, delay := 0.0) -> void:
	popup(-1, Row.MUTED, uid, 1, false, text, col, "", Color.WHITE, delay, false, true)


## Previous action's numbers blink out quickly so only the current action's stay on screen.
func live_popups() -> int:
	var n := 0
	for i in MAX_POP:
		if _pp_on[i]:
			n += 1
	return n


func sweep(a: Vector2, b: Vector2, col: Color) -> void:
	_sw_a[_sw_next] = a
	_sw_b[_sw_next] = b
	_sw_t[_sw_next] = 0.0
	_sw_col[_sw_next] = col
	_sw_thin[_sw_next] = false
	_sw_next = (_sw_next + 1) % 4


## A thin streak from attacker to target showing the travel.
func trail(a: Vector2, b: Vector2, col: Color) -> void:
	sweep(a, b, col)
	_sw_thin[(_sw_next + 3) % 4] = true


## Victory in the Crystal fight: the Shard breaks free and flies to the centre of the view.
func shard_fly(from: Vector2, to: Vector2) -> void:
	_shard_t = 0.0
	_shard_from = from
	_shard_to = to


func fade_popups() -> void:
	for i in MAX_POP:
		_pp_on[i] = false
	for i in MAX_PILLAR:
		_pl_on[i] = false


func clear_all() -> void:
	for i in MAX_POP:
		_pp_on[i] = false
	for i in MAX_PROJ:
		_pj_on[i] = false
	for i in MAX_PART:
		_life[i] = 0.0
	for s in _sprites:
		s.hide()


## A soft additive light on the floor/units at `pos` (whole-number scale), fading over `dur`.
func light(pos: Vector2, col: Color, scale: int, alpha: float, dur: float) -> void:
	var i := _light_next
	_light_next = (_light_next + 1) % MAX_LIGHT
	var l := _lights[i]
	l.position = Vector2(roundf(pos.x), roundf(pos.y))
	l.scale = Vector2(scale, scale)
	l.visible = true
	_lt[i] = 0.0
	_ldur[i] = dur
	_la[i] = minf(alpha, 0.22)   # additive: keep it a glow, never a white-out of the units under it
	_lcol[i] = col
	l.modulate = Color(col, alpha)


# ------------------------------------------------------------------------------------ per frame
func tick(vdt: float, now_sim: float) -> void:
	sim_t = now_sim
	for k in MAX_PART:
		if _life[k] > 0.0:
			_life[k] -= vdt
			_vy[k] += _grav[k] * vdt
			_px[k] += _vx[k] * vdt
			_py[k] += _vy[k] * vdt
	if _shard_t >= 0.0:
		_shard_t += vdt
	for i in 4:
		_sw_t[i] += vdt
		_sh_t[i] -= vdt
	for i in MAX_RING:
		if _rg_on[i]:
			_rg_t[i] += vdt
			if _rg_t[i] >= _rg_dur[i]:
				_rg_on[i] = false
	for i in MAX_PILLAR:
		if _pl_on[i]:
			_pl_t[i] += vdt
			if _pl_t[i] >= _pl_dur[i]:
				_pl_on[i] = false
	for i in MAX_POP:
		if _pp_on[i]:
			_pp_t[i] += vdt
			if _pp_t[i] > 1.15:
				_pp_on[i] = false
	for i in MAX_PROJ:
		if _pj_on[i] and now_sim >= _pj_t1[i]:
			_pj_on[i] = false
	for i in MAX_LIGHT:
		var l := _lights[i]
		if l.visible:
			_lt[i] += vdt
			var u := _lt[i] / _ldur[i]
			if u >= 1.0:
				l.visible = false
			else:
				var a := _la[i] * (1.0 - u * u)
				# hard steps keep the light banded like the painted art
				l.modulate = Color(_lcol[i], roundf(a * 8.0) / 8.0)
	queue_redraw()
	_pop_node.queue_redraw()


func _draw() -> void:
	# light pillars (behind numbers, above units)
	for i in MAX_PILLAR:
		if not _pl_on[i]:
			continue
		var u := _pl_t[i] / _pl_dur[i]
		var w := roundf(_pl_w[i] * (1.0 - u * u))
		var c := _pl_col[i]
		var top := -20.0
		draw_rect(Rect2(_pl_x[i] - w, top, w * 2.0, _pl_y[i] - top), Color(c, 0.35 * (1.0 - u)))
		draw_rect(Rect2(_pl_x[i] - maxf(1.0, w * 0.4), top, maxf(2.0, w * 0.8), _pl_y[i] - top), Color(Pal.INK10, 0.8 * (1.0 - u)))
	# the freed Shard
	if _shard_t >= 0.0:
		var su := clampf(_shard_t / 1.1, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - su, 3.0)
		var sp := _shard_from.lerp(_shard_to, e) + Vector2(0, -sin(su * PI) * 30.0)
		var sc := 1 + int(e * 2.0)
		var gl := 10.0 + 14.0 * e + 3.0 * sin(_shard_t * 9.0)
		draw_circle(sp, gl, Color(Pal.CRYSTAL4, 0.25))
		draw_circle(sp, gl * 0.6, Color(Pal.CRYSTAL5, 0.35))
		draw_set_transform(Vector2(roundf(sp.x - 7 * sc), roundf(sp.y - 13 * sc)), 0.0, Vector2(sc, sc))
		draw_texture(SHARD, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# hearth shields
	for i in 4:
		if _sh_t[i] > 0.0:
			var p := _sh_pos[i]
			var a := clampf(_sh_t[i] / 0.3, 0.0, 1.0)
			var segs := maxi(1, _sh_seg[i])
			var w := 6.0 * segs + 4.0
			var x0 := roundf(p.x - w * 0.5)
			for k in segs:
				draw_rect(Rect2(x0 + 2 + k * 6, p.y - 9, 5, 14), Color(_sh_col[i], 0.85 * a))
			_shield_pts[0] = Vector2(x0, p.y - 11)
			_shield_pts[1] = Vector2(x0 + w, p.y - 11)
			_shield_pts[2] = Vector2(x0 + w, p.y + 4)
			_shield_pts[3] = Vector2(x0 + w * 0.5, p.y + 9)
			_shield_pts[4] = Vector2(x0, p.y + 4)
			_shield_pts[5] = Vector2(x0, p.y - 11)
			draw_polyline(_shield_pts, Color(Pal.INK10, a), 1.0)
	# sweeps
	for i in 4:
		var st := _sw_t[i]
		if st < 0.45:
			var grow := clampf(st / 0.12, 0.0, 1.0)
			var fade := 1.0 - clampf((st - 0.15) / 0.3, 0.0, 1.0)
			var e := _sw_a[i].lerp(_sw_b[i], grow)
			if _sw_thin[i]:
				draw_line(_sw_a[i], e, Color(_sw_col[i], fade * 0.55), 1.0)
			else:
				draw_line(_sw_a[i] + Vector2(2, 0), e + Vector2(2, 0), Color(_sw_col[i], fade * 0.6), 5.0)
				draw_line(_sw_a[i], e, Color(Pal.INK10, fade), 3.0)
	# rings
	for i in MAX_RING:
		if not _rg_on[i]:
			continue
		var u := _rg_t[i] / _rg_dur[i]
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		var r := _rg_r0[i] + (_rg_r1[i] - _rg_r0[i]) * e
		var c := _rg_col[i]
		c.a = 1.0 - u * u
		for k in 33:
			var a := TAU * k / 32.0
			_ring_pts[k] = Vector2(roundf(_rg_c[i].x + cos(a) * r), roundf(_rg_c[i].y + sin(a) * r * _rg_flat[i]))
		draw_polyline(_ring_pts, c, 1.0)
		if _rg_r1[i] >= 36.0:
			for k in 33:
				_ring_pts[k].y += 1.0
			draw_polyline(_ring_pts, c, 1.0)
		if u < 0.5:
			draw_polyline(_ring_pts, Color(Pal.INK10, (0.5 - u)), 1.0)
	# projectiles
	for i in MAX_PROJ:
		if not _pj_on[i] or sim_t < _pj_t0[i]:
			continue
		var u := clampf((sim_t - _pj_t0[i]) / maxf(0.01, _pj_t1[i] - _pj_t0[i]), 0.0, 1.0)
		var c1 := _pj_col[i]
		var c2 := _pj_col2[i]
		for tr in range(5, -1, -1):
			var uu := maxf(0.0, u - tr * 0.045)
			var p := _proj_pos(i, uu)
			var r := 4.0 - tr * 0.5
			if _pj_kind[i] == 1:
				r = 6.0 - tr * 0.8
			if r <= 0.5:
				continue
			var col := c1 if tr > 0 else c2
			col.a = 1.0 - tr * 0.15
			draw_circle(Vector2(roundf(p.x), roundf(p.y)), roundf(r), col)
		var hp := _proj_pos(i, u)
		draw_circle(Vector2(roundf(hp.x), roundf(hp.y)), 7.0 if _pj_kind[i] != 1 else 12.0, Color(c1, 0.22))
		draw_circle(Vector2(roundf(hp.x), roundf(hp.y)), 1.0 if _pj_kind[i] != 1 else 3.0, Pal.INK10)
	# particles
	for k in MAX_PART:
		if _life[k] > 0.0:
			var c := _pcol[k]
			c.a = clampf(_life[k] / _lmax[k] * 1.6, 0.0, 1.0)
			var s := float(_psize[k])
			draw_rect(Rect2(roundf(_px[k]), roundf(_py[k]), s, s), c)



func _proj_pos(i: int, u: float) -> Vector2:
	var a := _pj_from[i]
	var b := _pj_to[i]
	if _pj_kind[i] == 1:
		var e := u * u
		return Vector2(b.x + (1.0 - e) * 90.0 * (-1.0 if a.x < b.x else 1.0), b.y - (1.0 - e) * 220.0)
	var p := a.lerp(b, u)
	p.y -= _pj_arc[i] * 4.0 * u * (1.0 - u)
	return p


## Numbers, tags and their links draw on the UI layer above the world (native resolution). Layout
## is in world units (pinned to the target), converted per frame through the world -> UI transform.
func _draw_pop_layer() -> void:
	if not _to_ui.is_valid():
		return
	var ci := _pop_node
	# links: a shared/halved number tied to the hit it came from
	for i in MAX_POP:
		if _pp_on[i] and _pp_t[i] >= 0.0 and _pp_link[i] != Vector2.ZERO:
			var a: Vector2 = _to_ui.call(Vector2(_pp_x[i], _pp_y[i] - 6.0))
			var b: Vector2 = _to_ui.call(_pp_link[i])
			var n := int(a.distance_to(b) / 6.0)
			for k in n:
				if k % 2 == 0:
					ci.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), Pal.INK1, 3.0)
					ci.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), Pal.AMBER6, UIText.fpx(UIText.LABEL) * 2.0)
	for i in MAX_POP:
		if _pp_on[i] and _pp_t[i] >= 0.0:
			_draw_popup(ci, i)
	if debug_boxes:
		# --label-boxes (captures): the solver's view, to check placements frame by frame
		for g: Dictionary in units_geo:
			_dbg_rect(ci, g["body"], Color(0.3, 1, 0.3))
			_dbg_rect(ci, g["bar"], Color(1, 1, 0.2))
		for i in MAX_POP:
			if _pp_on[i]:
				_dbg_rect(ci, _pp_box[i], Color.WHITE)


var debug_boxes := OS.get_cmdline_user_args().has("--label-boxes")


func _dbg_rect(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var a: Vector2 = _to_ui.call(r.position)
	var b: Vector2 = _to_ui.call(r.end)
	ci.draw_rect(Rect2(a, b - a), c, false, 1.0)


func _draw_popup(ci: CanvasItem, i: int) -> void:
	var t := _pp_t[i]
	var visible_blink := t < 0.95 or fmod(t, 0.08) < 0.05
	if not visible_blink:
		return
	var box := _pp_box[i]
	var x := box.get_center().x
	var val := _pp_val[i]
	var head := _pp_head[i]
	if _pp_small[i]:
		# world cues (formation behaviours) sit on a dark plate so they read over a busy floor
		var a: Vector2 = _to_ui.call(box.position)
		var b: Vector2 = _to_ui.call(box.end)
		var plate := Rect2(roundf(a.x), roundf(a.y), roundf(b.x - a.x), roundf(b.y - a.y))
		ci.draw_rect(plate, Color(Pal.INK1, 0.82))
		ci.draw_rect(plate, Color(_pp_head_col[i], 0.55), false, 1.0)
		var cy := UIText.centered_y(plate.position.y, plate.size.y, UIText.BOLD, TAG_SIZE)
		UIText.outlined(ci, Vector2(plate.get_center().x, cy), head, _pp_head_col[i], UIText.BOLD, TAG_SIZE, 1)
		return
	# the label rises NUM_RISE after it lands: its content starts at the bottom of its box
	var rise := 1.0 - pow(1.0 - clampf(t / 0.28, 0.0, 1.0), 3.0)
	var y := box.position.y + NUM_RISE * (1.0 - rise)   # world y of the content's top
	if head != "":
		var top: Vector2 = _to_ui.call(Vector2(x, y))
		UIText.outlined(ci, Vector2(top.x, top.y + UIText.cap(UIText.BOLD, HEAD_SIZE) - UIText.ascent(UIText.BOLD, HEAD_SIZE)), head, _pp_head_col[i], UIText.BOLD, HEAD_SIZE, 1)
		y += HEAD_H
	var ko_on := _pp_ko[i] and t >= _pp_ko_t[i]
	if val >= 0:
		# punch: one size up for the first frames
		var sz := NUM_PUNCH if t < 0.06 else NUM_SIZE
		var s := ("+" if _pp_plus[i] else "") + str(val)
		var nw := UIText.width(s, UIText.BOLD, NUM_SIZE) + 4.0
		var row_w := nw + ((KO_GAP + _ko_w()) if _pp_ko[i] else 0.0)
		var c: Vector2 = _to_ui.call(Vector2(x, y + 0.75))
		var x0 := c.x - row_w * 0.5
		var base := c.y + UIText.cap(UIText.BOLD, NUM_SIZE)
		# a two-font-pixel dark ring keeps the digits apart from bright slashes and sparks
		UIText.outlined(ci, Vector2(roundf(x0 + nw * 0.5), base - UIText.ascent(UIText.BOLD, sz)), s, ROW_COL[_pp_row[i]], UIText.BOLD, sz, 1, Pal.INK1, true, 2)
		if ko_on:
			_draw_ko(ci, Vector2(x0 + nw + KO_GAP, base - UIText.cap(UIText.BOLD, NUM_SIZE) * 0.5))
		y += NUM_H
		var tag := _pp_tag[i]
		if tag != "":
			var tp: Vector2 = _to_ui.call(Vector2(x, y + 1.0))
			UIText.outlined(ci, Vector2(tp.x, tp.y + UIText.cap(UIText.BOLD, TAG_SIZE) - UIText.ascent(UIText.BOLD, TAG_SIZE)), tag, _pp_tag_col[i], UIText.BOLD, TAG_SIZE, 1)
	elif ko_on:
		var c2: Vector2 = _to_ui.call(Vector2(x, y + HEAD_H * 0.5))
		_draw_ko(ci, Vector2(c2.x - _ko_w() * 0.5, c2.y))


## The KO! pill: red word on a dark pill with a red rim, left edge at p.x, centred on p.y (UI px).
func _draw_ko(ci: CanvasItem, p: Vector2) -> void:
	var h := UIText.cap(UIText.BOLD, HEAD_SIZE) + KO_PAD * 2.0
	var r := Rect2(roundf(p.x), roundf(p.y - h * 0.5), roundf(_ko_w()), roundf(h))
	ci.draw_rect(r, Color(Pal.INK1, 0.92))
	ci.draw_rect(r, Pal.BLOOD3, false, 1.0)
	var ty := r.position.y + KO_PAD + UIText.cap(UIText.BOLD, HEAD_SIZE) - UIText.ascent(UIText.BOLD, HEAD_SIZE)
	UIText.draw(ci, Vector2(r.position.x + KO_PAD, ty), "KO!", UIText.legible(Pal.BLOOD4), UIText.BOLD, HEAD_SIZE)
