extends Node2D
## Pooled battle effects drawn in world space: sprite effects (sparks, bursts, slashes, heal glows),
## particles, projectiles, floor rings and pixel-art light beams. Damage/heal numbers and their tags are
## laid out in world space (so they stay pinned to their target) but drawn on the UI layer at native
## resolution, through the battle's world -> UI transform.
## Everything is pre-allocated in setup(); the per-frame path only mutates pooled slots.

const BURST = preload("res://assets/battle/burst.png")
const SLASH = preload("res://assets/battle/slash.png")
const META_PATH := "res://assets/sprites/sprite_meta.json"

enum Row { PHYS, MAGIC, CRIT, HEAL, DEATH, MUTED, SHIELD, TICK, BURN, HEX }
## Number colours per row (fill), matching the old digit sheet. Round 17: SHIELD (a shield's absorb),
## TICK (poison, a link's share), BURN, HEX (a hexed heal); each of those also carries its glyph.
const ROW_COL := [Pal.INK10, Pal.VIOLET4, Pal.AMBER6, Pal.LIFE4, Pal.BLOOD4, Pal.FADE4, Pal.CRYSTAL5, Pal.INK10, Pal.AMBER5, Pal.VIOLET3]
## A status number's glyph before its digits (round 17): the status icon in its colour, so a poison or
## burn tick never reads as a hit or a Fading tick (the Fading keeps its grey mote).
const GLYPH_COL := {"poison": Pal.LIFE4, "burn": Pal.AMBER6, "heal_invert": Pal.AMBER6, "shield": Pal.CRYSTAL5,
	"link": Pal.AMBER6, "cost": Pal.BLOOD4, "tithe": Pal.BLOOD4, "regen": Pal.LIFE4}
const GLYPH_ICON := {"poison": "status_poison", "burn": "status_burn", "heal_invert": "status_heal_invert",
	"shield": "status_shield", "link": "status_link", "cost": "stat_hp", "tithe": "stat_hp", "regen": "status_regen"}
## Status ticks are quieter than blows: one size down.
const TICK_SIZE := 20
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
var _pp_mote: Array[bool] = []         # a glyph before the number (a Fading mote, a status icon)
var _pp_glyph: Array[String] = []      # "mote" or a GLYPH_ICON key
var _pp_nsz := PackedInt32Array()      # the number's font size
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
	_pp_on.resize(MAX_POP); _pp_val.resize(MAX_POP); _pp_row.resize(MAX_POP); _pp_x.resize(MAX_POP)
	_pp_y.resize(MAX_POP); _pp_t.resize(MAX_POP); _pp_scale.resize(MAX_POP); _pp_plus.resize(MAX_POP)
	_pp_small.resize(MAX_POP)
	_pp_head.resize(MAX_POP); _pp_head_col.resize(MAX_POP); _pp_tag.resize(MAX_POP); _pp_tag_col.resize(MAX_POP)
	_pp_link.resize(MAX_POP)
	_pp_mote.resize(MAX_POP)
	_pp_glyph.resize(MAX_POP)
	_pp_nsz.resize(MAX_POP)
	_pp_ko.resize(MAX_POP); _pp_ko_t.resize(MAX_POP); _pp_unit.resize(MAX_POP); _pp_box.resize(MAX_POP)
	_shield_pts.resize(6)
	_make_dither()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the beams' dither tiles
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


## A column of light on a unit's spot (a memory surfacing, the opening volley, a taunt): the
## pixel-art beam (critic r11 fix 3), `w` half its width, a hero's height plus a head above the feet.
func pillar(x: float, y: float, w: float, dur: float, col: Color) -> void:
	beam(x, y, w, y - 44.0, 80.0, dur, col, col.lerp(Pal.INK10, 0.5))


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
## The KO! pill's line under a number (world px): the pill plus a little air.
const KO_H := (11.0 * HEAD_SIZE / 15.0 + KO_PAD * 2.0) / ZOOM + 1.5
## Back-column damage as an icon, not jargon (critic r10 fix 9: "Rear 1/2" on a Backstab read as a
## contradiction): head words that draw the shared rear_half glyph (twice for a quarter: both ranks
## at the back). The full sentence is in the shared tooltip on the icon (tap / hover).
const REAR_HALF := "@rear1"
const REAR_QUARTER := "@rear2"
const REAR_TIP := ["Back rank", "A hero in the back column deals and takes half physical damage."]
const REAR_TIP_QUARTER := ["Back rank, both", "Both are in the back column: half dealt, then half taken, a quarter of the blow."]
const ICON_PX := 9.0
const MAX_TIPS := 6


static func head_icons(head: String) -> int:
	return 1 if head == REAR_HALF else (2 if head == REAR_QUARTER else 0)


## The Fading tick's mote glyph before its number (UI design px).
const MOTE_W := 9.0
const MOTE_GAP := 2.0

## The solver's view of the field, set by the controller before each popup (BattleFX labels are
## world-space): every unit {uid, body, bar}, the HUD rects labels keep clear of, and the field.
var units_geo: Array = []
## HUD rects (world px) effects never draw into: the rosters, caption, banners (set every frame).
var clip_rects: Array = []


func _clipped(p: Vector2) -> bool:
	for r: Rect2 in clip_rects:
		if r.has_point(p):
			return true
	return false


## A polyline drawn only where it is off the HUD.
func _clip_polyline(pts: PackedVector2Array, c: Color) -> void:
	if clip_rects.is_empty():
		draw_polyline(pts, c, 1.0)
		return
	for k in pts.size() - 1:
		if not _clipped(pts[k]) and not _clipped(pts[k + 1]):
			draw_line(pts[k], pts[k + 1], c, 1.0)


## A line drawn only up to where it would enter the HUD.
func _clip_line(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	if not clip_rects.is_empty():
		if _clipped(a):
			return
		var n := 8
		for k in range(1, n + 1):
			if _clipped(a.lerp(b, float(k) / n)):
				b = a.lerp(b, float(k - 1) / n)
				break
	draw_line(a, b, c, w)
## Tests: every placement with the field it was solved against (tests/test_label_layout.gd).
var recording := false
var record: Array = []
var blocked: Array = []
var field := Rect2(164, 92, 312, 176)


## The label box size for its contents (world px).
static func label_size(value: int, plus: bool, head: String, small: bool, tag: String, ko: bool, mote := false, nsz := NUM_SIZE) -> Vector2:
	var row_w := 0.0
	var h := 0.0
	if value >= 0:
		row_w = (UIText.width(("+" if plus else "") + str(value), UIText.BOLD, nsz) + 4.0 + ((MOTE_W + MOTE_GAP) if mote else 0.0)) / ZOOM
		if ko:
			# the KO! pill sits under the number, not beside it: the label stays as narrow as its
			# number and clear of the neighbours' columns (critic r11 fix 1)
			row_w = maxf(row_w, _ko_w() / ZOOM)
			h += KO_H
		h += NUM_RISE + (NUM_H if nsz == NUM_SIZE else 11.0 * nsz / 15.0 / ZOOM + 1.5)
	elif ko:
		row_w = _ko_w() / ZOOM
		h += NUM_RISE + HEAD_H
	var hw := 0.0
	if head != "":
		var hs := TAG_SIZE if small else HEAD_SIZE
		hw = (UIText.width(head, UIText.BOLD, hs) + (8.0 if small else 3.0)) / ZOOM
		if head_icons(head) > 0:
			hw = (head_icons(head) * (ICON_PX + 2.0) + 2.0) / ZOOM
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
	var sz := label_size(_pp_val[j], _pp_plus[j], _pp_head[j], _pp_small[j], _pp_tag[j], _pp_ko[j], _pp_mote[j], _pp_nsz[j])
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
	_pp_box[j] = LabelLayout.place(sz, pref, own, units_geo, placed, blocked, field, not _pp_small[j])
	if recording:
		record.append({"uid": _pp_unit[j], "box": _pp_box[j], "text": _label_text(j), "geo": units_geo.duplicate(),
			"placed": placed, "blocked": blocked.duplicate(), "field": field, "small": _pp_small[j],
			"fallback": LabelLayout.last_fallback or LabelLayout.last_column_miss, "t": sim_t})
	_pp_x[j] = _pp_box[j].get_center().x
	_pp_y[j] = _pp_box[j].end.y


func last_box() -> Rect2:
	return _pp_box[_last_pop]


## Every live label's box (world px): the status rows keep clear of them.
func live_boxes() -> Array:
	var out: Array = []
	for j in MAX_POP:
		if _pp_on[j]:
			out.append(_pp_box[j])
	return out


## Every live label's box this action (world px), for tests and checks.
func label_boxes() -> Array:
	var out: Array = []
	for j in MAX_POP:
		if _pp_on[j]:
			out.append({"uid": _pp_unit[j], "box": _pp_box[j], "text": _label_text(j)})
	return out


func _label_text(j: int) -> String:
	var s := _pp_head[j]
	if head_icons(s) > 0:
		s = "[rear x%s]" % ("1/2" if head_icons(s) == 1 else "1/4")
	if _pp_val[j] >= 0:
		s += (" " if s != "" else "") + str(_pp_val[j])
	if _pp_ko[j]:
		s += " KO!"
	if _pp_tag[j] != "":
		s += " " + _pp_tag[j]
	return s


## A number (value >= 0) or word label on unit `uid`, laid out with the action's other labels.
## `delay` staggers popups that land together; `ko` adds the KO! pill beside the number.
func popup(value: int, row: int, uid: int, scale: int, plus: bool, head: String, head_col: Color, tag: String, tag_col: Color, delay := 0.0, ko := false, small := false, mote := false, glyph := "") -> int:
	if mote and glyph == "":
		glyph = "mote"
	mote = glyph != ""
	# one number per target per action: a further hit on the same target adds to its number (a
	# status number only joins one of its own kind landing at the same moment)
	if value >= 0:
		for j in MAX_POP:
			if _pp_on[j] and _pp_unit[j] == uid and not _pp_small[j] and _pp_val[j] >= 0 and _pp_row[j] != Row.HEAL and row != Row.HEAL \
					and _pp_glyph[j] == glyph and (glyph == "" or glyph == "mote" or _pp_t[j] < 0.25):
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
	_pp_mote[best] = mote
	_pp_glyph[best] = glyph
	_pp_nsz[best] = TICK_SIZE if (glyph != "" and glyph != "mote" and row != Row.SHIELD) else NUM_SIZE
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


## True while an attacker's travel streak is still drawn.
func trail_busy() -> bool:
	for i in 4:
		if _sw_thin[i] and _sw_t[i] < 0.45:
			return true
	return false


## A thin streak from attacker to target showing the travel.
func trail(a: Vector2, b: Vector2, col: Color) -> void:
	sweep(a, b, col)
	_sw_thin[(_sw_next + 3) % 4] = true


## Victory in the Crystal fight: the Shard breaks free and flies to the centre of the view.
func shard_fly(from: Vector2, to: Vector2) -> void:
	_shard_t = 0.0
	_shard_from = from
	_shard_to = to


func fade_popups(beams := true) -> void:
	for i in MAX_POP:
		_pp_on[i] = false
	if beams:
		_beams.clear()


## Pixel-art light beams (critic r11 fix 3: Smite's and Mend's light column read as a flat ~330 px
## debug quad). A beam is as wide as its target's body, banded (a dark rim, the body, a bright core),
## falls from its top to the feet in a few frames, has a soft dithered top, fades by thinning its
## dither (never by alpha), narrows as it goes and leaves a ground ring at the feet. World px, visual time.
const MAX_BEAM := 8
var _beams: Array = []


## `x` the column's centre, `feet` the target's feet, `half_w` half its body width, `head` the top of
## its head (below it the beam thins so the unit shows through), `height` from the feet to the top.
## `delay` (visual s) or `at` (a sim time, e.g. Hexfire's fire reaching each space) holds it back.
func beam(x: float, feet: float, half_w: float, head: float, height: float, dur: float, col: Color, hi: Color, delay := 0.0, at := -1.0) -> void:
	if _beams.size() >= MAX_BEAM:
		_beams.pop_front()
	_beams.append({"x": roundf(x), "y": roundf(feet), "hw": maxf(3.0, roundf(half_w)), "head": roundf(head),
		"h": roundf(height), "t": -delay if at < 0.0 else -1.0, "at": at, "dur": dur, "col": col, "hi": hi})


func _draw_beams() -> void:
	for bm: Dictionary in _beams:
		var u: float = float(bm["t"]) / float(bm["dur"])
		if u >= 1.0 or u < 0.0:
			continue
		var x: float = bm["x"]
		var feet: float = bm["y"]
		var col: Color = bm["col"]
		var hi: Color = bm["hi"]
		var top: float = feet - float(bm["h"])
		for r: Rect2 in clip_rects:   # never inside a banner
			if r.end.y < feet and r.position.x < x + bm["hw"] and r.end.x > x - bm["hw"]:
				top = maxf(top, r.end.y)
		var fall := clampf(float(bm["t"]) / 0.08, 0.0, 1.0)   # the light reaches the feet in ~5 frames
		var bottom := roundf(lerpf(top, feet, fall))
		var hw: float = bm["hw"]
		if u > 0.55:
			hw = maxf(1.0, roundf(hw * (1.0 - (u - 0.55) / 0.45 * 0.6)))
		var fade := 1.0 - u * u
		var soft := maxf(6.0, roundf((feet - top) * 0.4))
		var head: float = bm["head"]
		var rim := Color(col.lerp(Pal.INK1, 0.35), 0.9)
		var core_w := maxf(1.0, roundf(hw * 0.5))
		# rows grouped into runs of one dither level: a few tiled draws per beam, not a draw per pixel
		var run_lvl := -1
		var run_over := false
		var run_y := top
		for yi in range(int(top), int(bottom) + 1):
			var yy := float(yi)
			var lvl := 0
			var over := yy > head
			if yi < int(bottom):
				var d := clampf((yy - top) / soft, 0.0, 1.0) * fade
				if over:
					d = minf(d, 0.3)   # over the unit: a light veil (a quarter of the pixels), the sprite shows through
				lvl = _dither_level(d)
			else:
				lvl = -2   # flush the last run
			if lvl != run_lvl or over != run_over:
				if run_lvl > 0:
					var h := yy - run_y
					_dither_rect(Rect2(x - hw, run_y, 1.0, h), rim, run_lvl)
					_dither_rect(Rect2(x + hw - 1.0, run_y, 1.0, h), rim, run_lvl)
					if hw > 1.0:
						_dither_rect(Rect2(x - hw + 1.0, run_y, hw * 2.0 - 2.0, h), col, run_lvl)
					if not run_over:
						_dither_rect(Rect2(x - core_w, run_y, core_w * 2.0, h), hi, run_lvl)
				run_lvl = lvl
				run_over = over
				run_y = yy
		# the ground ring: a pixel ellipse that opens a little as the beam fades
		if fall >= 1.0:
			var rx := roundf(float(bm["hw"]) + 4.0 + 4.0 * u)
			var ry := 3.0
			var rc := Color(hi, 1.0 - u)
			for k in 33:
				var a := TAU * k / 32.0
				_ring_pts[k] = Vector2(roundf(x + cos(a) * rx), roundf(feet + 1.0 + sin(a) * ry))
			_clip_polyline(_ring_pts, rc)


## Ordered-dither level for a density: 4 solid, 3 a checker (half the pixels), 2 a quarter, 1 an
## eighth, 0 nothing.
static func _dither_level(d: float) -> int:
	if d >= 0.85:
		return 4
	if d >= 0.45:
		return 3
	if d >= 0.2:
		return 2
	if d >= 0.07:
		return 1
	return 0


## Dither tiles (white pixels on clear, tinted when drawn): half, a quarter, an eighth.
var _dither_tex: Array[Texture2D] = []


func _make_dither() -> void:
	for pat: Array in [[2, [Vector2i(0, 0), Vector2i(1, 1)]], [2, [Vector2i(0, 0)]], [4, [Vector2i(0, 0), Vector2i(2, 2)]]]:
		var n: int = pat[0]
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for p: Vector2i in pat[1]:
			img.set_pixelv(p, Color.WHITE)
		_dither_tex.append(ImageTexture.create_from_image(img))


## A block of a beam band at a dither level (whole world pixels). The tile is aligned to the world
## grid, so the bands of one beam share one pattern (the core's pixels replace the body's).
func _dither_rect(r: Rect2, c: Color, lvl: int) -> void:
	if r.size.x < 0.5 or r.size.y < 0.5:
		return
	if lvl >= 4:
		draw_rect(r, c)
		return
	var tex: Texture2D = _dither_tex[3 - lvl]
	var n := float(tex.get_width())
	draw_texture_rect_region(tex, r, Rect2(fposmod(r.position.x, n), fposmod(r.position.y, n), r.size.x, r.size.y), c)


func clear_all() -> void:
	_beams.clear()
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
	for k in range(_beams.size() - 1, -1, -1):
		var at := float(_beams[k]["at"])
		if at >= 0.0:
			if now_sim < at:
				continue
			_beams[k]["at"] = -1.0
			_beams[k]["t"] = 0.0
		_beams[k]["t"] = float(_beams[k]["t"]) + vdt
		if float(_beams[k]["t"]) >= float(_beams[k]["dur"]):
			_beams.remove_at(k)
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
	_place_tips()


## Frame-time probe (battle.gd --perf): usec spent drawing the effects, the numbers and the HUD.
static var perf_on := false
static var perf_us := 0


func _draw() -> void:
	var t0 := Time.get_ticks_usec() if perf_on else 0
	_draw_world()
	if perf_on:
		perf_us += Time.get_ticks_usec() - t0


func _draw_world() -> void:
	_draw_beams()
	# the freed Shard
	if _shard_t >= 0.0:
		var su := clampf(_shard_t / 1.1, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - su, 3.0)
		var sp := _shard_from.lerp(_shard_to, e) + Vector2(0, -sin(su * PI) * 12.0)
		var sc := 1   # at world pixel scale, like every sprite on the field (critic r10 C1)
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
				_clip_line(_sw_a[i], e, Color(_sw_col[i], fade * 0.55), 1.0)
			else:
				_clip_line(_sw_a[i] + Vector2(2, 0), e + Vector2(2, 0), Color(_sw_col[i], fade * 0.6), 5.0)
				_clip_line(_sw_a[i], e, Color(Pal.INK10, fade), 3.0)
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
		_clip_polyline(_ring_pts, c)
		if _rg_r1[i] >= 36.0:
			for k in 33:
				_ring_pts[k].y += 1.0
			_clip_polyline(_ring_pts, c)
		if u < 0.5:
			_clip_polyline(_ring_pts, Color(Pal.INK10, (0.5 - u)))
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
			if not clip_rects.is_empty() and _clipped(Vector2(_px[k], _py[k])):
				continue
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
	var t0 := Time.get_ticks_usec() if perf_on else 0
	_draw_pops()
	if perf_on:
		perf_us += Time.get_ticks_usec() - t0


func _draw_pops() -> void:
	if not _to_ui.is_valid():
		return
	_tip_rects.clear()
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


## Rear icons drawn this frame [UI rect, icons] and the pooled tooltip hit areas over them.
var _tip_rects: Array = []
var _tips: Array[Control] = []


func _place_tips() -> void:
	if _tips.is_empty():
		for i in MAX_TIPS:
			var c := Control.new()
			c.mouse_filter = Control.MOUSE_FILTER_STOP
			c.visible = false
			_pop_node.add_child(c)
			_tips.append(c)
	for i in MAX_TIPS:
		var c := _tips[i]
		if i < _tip_rects.size():
			var r: Rect2 = _tip_rects[i][0]
			# a 16 px minimum hit target (BUILD.md touch rule)
			c.position = r.get_center() - Vector2(maxf(16.0, r.size.x), maxf(16.0, r.size.y)) * 0.5
			c.size = Vector2(maxf(16.0, r.size.x), maxf(16.0, r.size.y))
			var tip: Array = REAR_TIP if int(_tip_rects[i][1]) == 1 else REAR_TIP_QUARTER
			if String((c.get_meta("tip", {}) as Dictionary).get("title", "")) != tip[0]:
				Tip.attach(c, tip[0], tip[1], Pal.INK9)
			c.visible = true
		elif c.visible:
			c.visible = false


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
	if head_icons(head) > 0:
		var top2: Vector2 = _to_ui.call(Vector2(x, y))
		var n := head_icons(head)
		var w := n * (ICON_PX + 2.0) - 2.0
		var ix := roundf(top2.x - w * 0.5)
		var iy := roundf(top2.y + 2.0)
		for k in n:
			var p := Vector2(ix + k * (ICON_PX + 2.0), iy)
			ci.draw_texture(EffectIcons.icon("rear_half"), p + Vector2(1, 1), Pal.INK1)
			ci.draw_texture(EffectIcons.icon("rear_half"), p, Pal.INK9)
		_tip_rects.append([Rect2(ix - 3.0, iy - 3.0, w + 6.0, ICON_PX + 6.0), n])
		y += HEAD_H
	elif head != "":
		var top: Vector2 = _to_ui.call(Vector2(x, y))
		UIText.outlined(ci, Vector2(top.x, top.y + UIText.cap(UIText.BOLD, HEAD_SIZE) - UIText.ascent(UIText.BOLD, HEAD_SIZE)), head, _pp_head_col[i], UIText.BOLD, HEAD_SIZE, 1)
		y += HEAD_H
	var ko_on := _pp_ko[i] and t >= _pp_ko_t[i]
	if val >= 0:
		# punch: one size up for the first frames
		var nsz := _pp_nsz[i]
		var sz := (NUM_PUNCH if nsz == NUM_SIZE else NUM_SIZE) if t < 0.06 else nsz
		var s := ("+" if _pp_plus[i] else "") + str(val)
		var nw := UIText.width(s, UIText.BOLD, nsz) + 4.0
		var mw := (MOTE_W + MOTE_GAP) if _pp_mote[i] else 0.0
		var row_w := mw + nw
		var c: Vector2 = _to_ui.call(Vector2(x, y + 0.75))
		var x0 := c.x - row_w * 0.5
		var base := c.y + UIText.cap(UIText.BOLD, nsz)
		if _pp_mote[i]:
			var gc := Vector2(roundf(x0 + MOTE_W * 0.5), roundf(base - UIText.cap(UIText.BOLD, nsz) * 0.5))
			if _pp_glyph[i] == "mote":
				_draw_mote(ci, gc)
			else:
				var gt := EffectIcons.icon(String(GLYPH_ICON.get(_pp_glyph[i], "status_poison")))
				var gp := gc - Vector2(4, 4)
				ci.draw_rect(Rect2(gp - Vector2(1, 1), Vector2(11, 11)), Color(Pal.INK1, 0.9))
				ci.draw_texture(gt, gp, GLYPH_COL.get(_pp_glyph[i], Pal.INK10))
			x0 += mw
		# a two-font-pixel dark ring keeps the digits apart from bright slashes and sparks
		UIText.outlined(ci, Vector2(roundf(x0 + nw * 0.5), base - UIText.ascent(UIText.BOLD, sz)), s, ROW_COL[_pp_row[i]], UIText.BOLD, sz, 1, Pal.INK1, true, 2)
		y += NUM_H if nsz == NUM_SIZE else 11.0 * nsz / 15.0 / ZOOM + 1.5
		var tag := _pp_tag[i]
		if tag != "":
			var tp: Vector2 = _to_ui.call(Vector2(x, y + 1.0))
			UIText.outlined(ci, Vector2(tp.x, tp.y + UIText.cap(UIText.BOLD, TAG_SIZE) - UIText.ascent(UIText.BOLD, TAG_SIZE)), tag, _pp_tag_col[i], UIText.BOLD, TAG_SIZE, 1)
			y += TAG_H
		if ko_on:
			# under the number, centred on its column
			var kp: Vector2 = _to_ui.call(Vector2(x, y + KO_H * 0.5))
			_draw_ko(ci, Vector2(roundf(kp.x - _ko_w() * 0.5), kp.y))
	elif ko_on:
		var c2: Vector2 = _to_ui.call(Vector2(x, y + HEAD_H * 0.5))
		_draw_ko(ci, Vector2(c2.x - _ko_w() * 0.5, c2.y))


## The Fading's mote: a small grey four-point spark with a dark ring (the drifting motes of the
## arena's greying), marking a number as a Fading tick rather than anyone's blow.
func _draw_mote(ci: CanvasItem, c: Vector2) -> void:
	var r := MOTE_W * 0.5
	var pts := PackedVector2Array([c + Vector2(0, -r - 1), c + Vector2(1.5, -1.5), c + Vector2(r + 1, 0), c + Vector2(1.5, 1.5),
		c + Vector2(0, r + 1), c + Vector2(-1.5, 1.5), c + Vector2(-r - 1, 0), c + Vector2(-1.5, -1.5)])
	ci.draw_colored_polygon(pts, Pal.INK1)
	var pts2 := PackedVector2Array()
	for p in pts:
		pts2.append(c + (p - c) * 0.72)
	ci.draw_colored_polygon(pts2, Pal.FADE4)


## The KO! pill: red word on a dark pill with a red rim, left edge at p.x, centred on p.y (UI px).
func _draw_ko(ci: CanvasItem, p: Vector2) -> void:
	var h := UIText.cap(UIText.BOLD, HEAD_SIZE) + KO_PAD * 2.0
	var r := Rect2(roundf(p.x), roundf(p.y - h * 0.5), roundf(_ko_w()), roundf(h))
	ci.draw_rect(r, Color(Pal.INK1, 0.92))
	ci.draw_rect(r, Pal.BLOOD3, false, 1.0)
	var ty := r.position.y + KO_PAD + UIText.cap(UIText.BOLD, HEAD_SIZE) - UIText.ascent(UIText.BOLD, HEAD_SIZE)
	UIText.draw(ci, Vector2(r.position.x + KO_PAD, ty), "KO!", UIText.legible(Pal.BLOOD4), UIText.BOLD, HEAD_SIZE)
