extends Control
const GameData = preload("res://core/game_data.gd")
## Screen-space battle HUD (Sea of Stars style) on the UI layer, at native resolution: party panels
## with portraits, HP and charge, formation banners with their effect chips, the fight timer with
## the Fading fuse, an action caption bar, the formation intro cards, the ability cut-in, the Fading
## line, the victory/defeat finish, plus touch buttons for speed and skip.
## Layout is in UI design px (640x360 frame); on wide screens the side panels and banners anchor to
## the safe area's edges and the centre pieces stay on the view's centre line.

signal speed_pressed
signal skip_pressed

const ICON_ABILITY = preload("res://assets/party/ability.png")
const STAT_NAMES := {"hp_pct": "HP", "atk_pct": "ATK", "def_pct": "DEF", "mag_pct": "MAG", "spd_pct": "SPD",
	"crit_add": "CRIT", "charge_pct": "CHARGE", "heal_pct": "HEAL", "dmg_taken_pct": "DMG TAKEN"}
const PANEL_W := 182
## Short cost labels for the banner (the full sentence is in the chips' tooltips).
const COST_SHORT := {"kindred": "Back unguarded", "vigil": "No front line", "lamplight": "Front takes extra hit",
	"tidebreak": "Spd -5%", "choir": "No front line", "keystone": "Gap draws melee", "hearth": "One wall",
	"seawall": "Spd -3%, no back row", "lumari_chorus": "No front line", "vault_door": "No standout",
	"crescent": "Open end draws melee", "lighthouse": "Post falls fast", "keepers_ring": "Front +5% dmg taken",
	"shardpoint": "Tip draws melee", "echo_step": "Def -5%", "strays": "No shape behaviour"}
const ROW_H := 20          # roster row: name and HP one size up (15) when they fit, then the bars
const BANNER_H := 26
const CHIP_GAP := 3

const SANS := UIText.SANS
const BOLD := UIText.BOLD
const SERIF := UIText.SERIF

var b: Node                    # battle controller
var speed_btn: Button
var skip_btn: Button

# visual state (seconds, visual time)
var t := 0.0
var flash_color := Color.WHITE
var flash_a := 0.0
var fade_in := 1.0
var caption_uid := -1
var caption_target := -1
var caption_text := ""
var caption_t := 9.0
var caption_ability := false
var caption_area := "single"
var cutin_uid := -1
var cutin_name := ""
var cutin_t := 9.0
var cutin_hold := 0.9
var intro_t := -1.0
var intro_len := 2.6
var sd_banner_t := 9.0
var end_t := -1.0
var winner := -2
var winner_text := ""
var badge_pulse: Array[float] = [0.0, 0.0]
var badge_line: Array[int] = [-1, -1]
var row_flash := PackedFloat32Array()
var doom := 0.0
var vignette := 0.0
var fading_tick := 0
var lore_t := 9.0
var lore_name := ""
var lore_text := ""
var frag_t := 9.0
var frag_n := 0
var lantern_dim := -1     # uid of the Keeper while he dims the heroes' behaviours
var _tri := PackedVector2Array()
# layout of the current frame (design px): view width, safe left / right edges, centre line
var _vw := 640.0
var _l := 0.0
var _r := 640.0
var _c := 320.0
var _cap_w := 264.0       # caption / cut-in width: the room between the party panels


func setup(controller: Node) -> void:
	b = controller
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tri.resize(3)
	row_flash.resize(16)
	speed_btn = _button("x1", speed_pressed)
	skip_btn = _button("SKIP", skip_pressed)
	_layout()


func _button(text: String, sig: Signal) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.custom_minimum_size = Vector2(42, 20)
	bt.size = Vector2(42, 20)
	bt.focus_mode = Control.FOCUS_NONE
	bt.pressed.connect(func() -> void: sig.emit())
	add_child(bt)
	return bt


## Edges and centre of the view (wide screens: panels to the safe edges, centre pieces centred).
func _layout() -> void:
	var vr := get_viewport_rect()
	var sr := UIText.safe_rect(self)
	_vw = vr.size.x
	_l = sr.position.x
	_r = sr.end.x
	_c = roundf(vr.size.x / 2.0)
	_cap_w = clampf((_r - _l) - 2.0 * (PANEL_W + 10.0), 260.0, 330.0)
	if speed_btn != null:
		speed_btn.position = Vector2(_c - 42, 336)
		skip_btn.position = Vector2(_c + 4, 336)


func tick(vdt: float) -> void:
	t += vdt
	_layout()
	var show_chips: bool = (intro_t < 0.0 or intro_t > intro_len - 0.35) and end_t < 0.0
	for side in 2:
		for c: Array in _chips[side]:
			(c[0] as Control).visible = show_chips
	if not _chips[0].is_empty() or not _chips[1].is_empty():
		_place_chips()
	_place_intro()
	if _pulse_layer != null:
		_pulse_layer.queue_redraw()
	flash_a = maxf(0.0, flash_a - vdt * 5.0)
	fade_in = maxf(0.0, fade_in - vdt * 3.0)
	caption_t += vdt
	lore_t += vdt
	frag_t += vdt
	cutin_t += vdt
	sd_banner_t += vdt
	if end_t >= 0.0:
		end_t += vdt
	if intro_t >= 0.0:
		intro_t += vdt
	for k in 2:
		badge_pulse[k] = maxf(0.0, badge_pulse[k] - vdt * 0.9)
	for i in row_flash.size():
		row_flash[i] = maxf(0.0, row_flash[i] - vdt * 3.0)
	vignette = maxf(0.0, vignette - vdt * 1.5)
	queue_redraw()


func show_lore(name: String, text: String) -> void:
	lore_name = name
	lore_text = text
	lore_t = 0.0


## The fragment banner has its own slot at the top centre, between the two formation badges
## (critic r4: in the caption slot it hid the next action's caption while that action's numbers
## showed). It shows as the fragment breaks and never touches the action caption.
const FRAG_SHOW := 2.4


func show_fragment(n: int) -> void:
	frag_n = n
	frag_t = 0.0


## The fragment banner's rect (UI design px): centred in the gap between the badges, the text at
## the heading size when it fits there, else the label size.
func fragment_rect() -> Rect2:
	var sz := fragment_size()
	var w := UIText.width(_frag_text(), BOLD, sz) + 20.0
	return Rect2(roundf(_c - w / 2.0), 2, roundf(w), BANNER_H)


func fragment_size() -> int:
	var room := badge_rect(1).position.x - badge_rect(0).end.x - 12.0
	return UIText.HEADING if UIText.width(_frag_text(), BOLD, UIText.HEADING) + 20.0 <= room else UIText.LABEL


func _frag_text() -> String:
	return "FRAGMENT %d OF 4" % maxi(frag_n, 1)


func screen_flash(c: Color, a: float) -> void:
	flash_color = c
	flash_a = maxf(flash_a, a)


func show_caption(uid: int, text: String, target: int, is_ability: bool, area := "single") -> void:
	caption_area = area
	caption_uid = uid
	caption_text = text
	caption_target = target
	caption_t = 0.0
	caption_ability = is_ability


func show_cutin(uid: int, ability: String, hold: float) -> void:
	cutin_uid = uid
	cutin_name = ability
	cutin_t = 0.0
	cutin_hold = hold


func pulse_badge(side: int, line: int) -> void:
	badge_pulse[side] = 1.0
	badge_line[side] = line


# ------------------------------------------------------------------------------------- drawing
func _draw() -> void:
	if b == null or b.units.is_empty():
		_draw_fade()
		return
	_draw_vignette()
	var intro_done := intro_t < 0.0 or intro_t > intro_len - 0.35
	var sd_on: bool = b.sd_at > 0.0 and b.sim_t >= b.sd_at
	if intro_done:
		for side in 2:
			_draw_badge(side, 1.0)
	if sd_on and end_t < 0.0:
		_draw_fading()
	_draw_timer()
	_draw_caption()
	for side in 2:
		_draw_panel(side)
	if intro_t >= 0.0 and intro_t <= intro_len + 0.4:
		_draw_intro()
	_draw_cutin()
	_draw_lore()
	_draw_fragment()
	_draw_end()
	if flash_a > 0.0:
		draw_rect(Rect2(0, 0, _vw, 360), Color(flash_color, flash_a))
	_draw_fade()


func _draw_fade() -> void:
	if fade_in > 0.0:
		draw_rect(Rect2(0, 0, maxf(_vw, 640.0), 360), Color(Pal.INK1, minf(1.0, fade_in)))


func _draw_vignette() -> void:
	var a := doom * 0.35 + vignette * 0.5
	if a <= 0.01:
		return
	var c := Pal.BLOOD2
	for k in 4:
		var w := 6.0 + k * 6.0
		var ca := Color(c, a * (0.55 - k * 0.12))
		draw_rect(Rect2(0, 0, _vw, w), ca)
		draw_rect(Rect2(0, 360 - w, _vw, w), ca)
		draw_rect(Rect2(0, 0, w, 360), ca)
		draw_rect(Rect2(_vw - w, 0, w, 360), ca)


# --- formation badges -------------------------------------------------------------------------
func _mods_lines(form: Dictionary) -> Array:
	var out := []
	var bl: PackedStringArray = []
	for m: Dictionary in form.get("buffs", []):
		bl.append(_mod_text(m))
	var dl: PackedStringArray = []
	for m: Dictionary in form.get("debuffs", []):
		dl.append(_mod_text(m))
	if not bl.is_empty():
		out.append([true, _join_mods(bl)])
	if not dl.is_empty():
		out.append([false, _join_mods(dl)])
	return out


## "DEF +30% front" + "DEF +10% back" -> "DEF +30% front, +10% back"
func _join_mods(parts: PackedStringArray) -> String:
	var s := parts[0]
	var stat := parts[0].get_slice(" ", 0)
	for i in range(1, parts.size()):
		var p := parts[i]
		if p.get_slice(" ", 0) == stat:
			s += ", " + p.substr(stat.length() + 1)
		else:
			s += ", " + p
	return s


func _mod_text(m: Dictionary) -> String:
	var stat := String(m.get("stat", ""))
	var v := float(m.get("value", 0.0))
	var s := "%s %+d%%" % [STAT_NAMES.get(stat, stat.to_upper()), roundi(v * 100.0)]
	var scope := String(m.get("scope", "all"))
	if scope == "front":
		s += " front"
	elif scope == "back":
		s += " back"
	return s


func badge_rect(side: int) -> Rect2:
	var w := badge_width(side)
	return Rect2(_l + 3 if side == 0 else _r - 3 - w, 2, w, BANNER_H)


## [title, bonus, behaviour, cost] for the banner. A locked shape fights as Strays.
func _badge_parts(side: int) -> Array:
	var form: Dictionary = b.sides[side].get("formation", {})
	var bl: Array = form.get("buffs", [])
	var dl: Array = form.get("debuffs", [])
	var up := _stat_short(bl[0]) if not bl.is_empty() else ""
	if bl.size() > 1:
		up += " " + _stat_short(bl[1])
	var beh := String((form.get("behaviour", {}) as Dictionary).get("name", ""))
	var cost := String(COST_SHORT.get(String(form.get("shape", form.get("id", ""))), ""))
	if cost == "":
		cost = _stat_short(dl[0]) if not dl.is_empty() else String(form.get("cost", ""))
	var title := String(form.get("name", ""))
	if bool(form.get("locked", false)):
		title = String(form.get("shape_name", title))
		beh = "locked: fights as Strays"
		cost = ""
	return [title, up, beh, cost.trim_suffix(".")]


func _stat_short(m: Dictionary) -> String:
	var stat := String(m.get("stat", ""))
	return "%s %+d" % [STAT_NAMES.get(stat, stat.to_upper()), roundi(float(m.get("value", 0.0)) * 100.0)] + "%"


## Banner title width (the formation name in the serif).
## Banner titles one size step up from body text (critic r2: the phone frame needs a punchier top tier).
const BANNER_TITLE := UIText.HEADING


func _wt(s: String) -> float:
	return UIText.width(s, SERIF, BANNER_TITLE)


## Banner (BUILD.md: effects are icons): the shape name, then a row of shared effect chips
## (EffectChip: hover / tap / press-and-hold opens the full sentence in the shared Tip).
## When a behaviour or effect fires, its chip pulses.
var _chips: Array = [[], []]        # side -> [[EffectChip, effect], ...]
var _pulse_layer: Control


## Capture aid (--tip=N): open the tooltip of side 0's N-th banner chip.
func open_tip_demo(k: int) -> void:
	if k < (_chips[0] as Array).size():
		Tip.show_for(_chips[0][k][0])


func build_banner() -> void:
	_layout()
	for side in 2:
		for c: Array in _chips[side]:
			(c[0] as Control).queue_free()
		_chips[side] = []
	for side in 2:
		var effs := _banner_effects(side)
		# each banner keeps to its half of the 16:9 frame, clear of the centre line
		var room := minf(_c - _l, 320.0) - 3.0 - 8.0 - _wt(_badge_parts(side)[0]) - 10.0 - 6.0
		var fit := int((room + CHIP_GAP) / (EffectIcons.CHIP + CHIP_GAP))
		var shown := effs.size() if effs.size() <= fit else maxi(0, fit - 1)
		for k in shown:
			var chip := EffectChip.new()
			add_child(chip)
			chip.setup(effs[k], "below")
			_chips[side].append([chip, effs[k]])
		if shown < effs.size():
			var more := MoreChip.new()
			var rest: PackedStringArray = []
			for k in range(shown, effs.size()):
				rest.append("%s: %s" % [effs[k]["title"], effs[k]["text"]])
			more.n = effs.size() - shown
			add_child(more)
			Tip.attach(more, "%d more" % more.n, "\n".join(rest), Pal.INK9, "below")
			_chips[side].append([more, {"kind": "more", "sign": 0}])
	if _pulse_layer == null:
		_pulse_layer = Control.new()
		_pulse_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pulse_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pulse_layer.draw.connect(_draw_chip_pulses)
		add_child(_pulse_layer)
	move_child(_pulse_layer, -1)
	_build_intro()
	move_child(speed_btn, -1)
	move_child(skip_btn, -1)
	_place_chips()


func _banner_effects(side: int) -> Array:
	var form: Dictionary = b.sides[side].get("formation", {})
	var sid := String(form.get("shape", form.get("id", "strays")))
	var shape: Dictionary = GameData.Formations.STRAYS
	for s: Dictionary in GameData.Formations.SHAPES:
		if s["id"] == sid:
			shape = s
	if sid == "crystal_chamber":
		return []
	var locked := bool(form.get("locked", false))
	var cells: Array = []
	var names: Array = []
	for uid: int in b.side_units[side]:
		cells.append([b.units[uid].col, b.units[uid].row])
		names.append(b.units[uid].label)
	var who: Dictionary = {} if locked else EffectIcons.who_of(sid, cells, names)
	var out: Array = []
	if locked:
		out.append({"icon": EffectIcons.icon("lock"), "sign": 0, "kind": "cost",
			"title": "%s, locked" % String(form.get("shape_name", shape.get("name", ""))),
			"text": "%s is not unlocked at the Training Grounds yet, so this party fights as Strays." % String(form.get("shape_name", ""))})
		shape = GameData.Formations.STRAYS
	out.append_array(EffectIcons.formation_effects(shape, who, b.sides[side].get("compositions", [])))
	return out


func badge_width(side: int) -> float:
	var p := _badge_parts(side)
	var n: int = (_chips[side] as Array).size()
	if n > 0 and not (_chips[side][0][0] as Control).visible:
		n = 0
	var chips := n * (EffectIcons.CHIP + CHIP_GAP) - CHIP_GAP if n > 0 else 0
	return ceilf(8.0 + _wt(p[0]) + (10.0 + chips if n > 0 else 0.0) + 6.0)


func _place_chips() -> void:
	for side in 2:
		var r := badge_rect(side)
		var x := r.position.x + 8.0 + _wt(_badge_parts(side)[0]) + 10.0
		for c: Array in _chips[side]:
			(c[0] as Control).position = Vector2(roundf(x), r.position.y + 3)
			x += EffectIcons.CHIP + CHIP_GAP


## Which chips a banner pulse refers to (line 0 bonus, 1 cost, 9 behaviour, other = class bond).
func _chip_hit(side: int, k: int) -> bool:
	var e: Dictionary = _chips[side][k][1]
	var kind := String(e.get("kind", ""))
	match badge_line[side]:
		9: return kind == "behaviour"
		0: return kind == "stat" and int(e.get("sign", 0)) > 0
		1: return int(e.get("sign", 0)) < 0
		-1: return false
	return kind == "bond"


func _draw_chip_pulses() -> void:
	if lantern_dim >= 0:
		for k in (_chips[0] as Array).size():
			var e: Dictionary = _chips[0][k][1]
			var ch: Control = _chips[0][k][0]
			if String(e.get("kind", "")) == "behaviour" and ch.visible:
				var rr := Rect2(ch.position, Vector2(EffectIcons.CHIP, EffectIcons.CHIP))
				_pulse_layer.draw_rect(rr, Color(Pal.INK1, 0.7))
				_pulse_layer.draw_line(rr.position + Vector2(2, 2), rr.end - Vector2(2, 2), Pal.FADE3, 1.0)
	for side in 2:
		var pulse: float = badge_pulse[side]
		if pulse <= 0.0:
			continue
		for k in (_chips[side] as Array).size():
			if not _chip_hit(side, k):
				continue
			var ch: Control = _chips[side][k][0]
			if not ch.visible:
				continue
			var col := EffectIcons.color_of(_chips[side][k][1])
			var g := roundf((1.0 - pulse) * 4.0)
			var rr := Rect2(ch.position, Vector2(EffectIcons.CHIP, EffectIcons.CHIP)).grow(1.0 + g)
			_pulse_layer.draw_rect(rr, Color(col, pulse), false, 1.0)
			_pulse_layer.draw_rect(Rect2(ch.position, Vector2(EffectIcons.CHIP, EffectIcons.CHIP)).grow(-1), Color(col, 0.45 * pulse))


func _draw_badge(side: int, alpha: float) -> void:
	var r := badge_rect(side)
	var sc: Color = b.side_colors[side]
	var pulse: float = badge_pulse[side]
	_panel_bg(r, sc, alpha, pulse)
	var p := _badge_parts(side)
	UIText.draw(self, Vector2(r.position.x + 8.0, UIText.centered_y(r.position.y, r.size.y, SERIF, BANNER_TITLE)),
		p[0], Color(sc.lerp(Pal.INK10, 0.15 + pulse * 0.6), alpha), SERIF, BANNER_TITLE)


func _panel_bg(r: Rect2, sc: Color, alpha: float, pulse := 0.0) -> void:
	draw_rect(r, Color(Pal.INK1, 0.82 * alpha))
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(Pal.INK2, 0.75 * alpha))
	var bc := Pal.INK5.lerp(sc, 0.3 + 0.7 * pulse)
	draw_rect(r, Color(bc, alpha), false, 1.0)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Color(sc, alpha * (0.7 + 0.3 * pulse)))


# --- timer ------------------------------------------------------------------------------------
func _draw_timer() -> void:
	var st: float = b.sim_t
	var secs := int(st)
	var r := Rect2(_c - 98, 334, 52, 24)
	var sd: bool = st >= b.sd_at and b.sd_at > 0.0
	_panel_bg(r, Pal.BLOOD3 if sd else Pal.INK7, 1.0, 0.0)
	@warning_ignore("integer_division")
	var txt := "%d:%02d" % [secs / 60, secs % 60]
	UIText.outlined(self, Vector2(r.get_center().x, UIText.centered_y(r.position.y, 20, BOLD, UIText.NUMBER)), txt,
		Pal.BLOOD4 if sd else Pal.INK10, BOLD, UIText.NUMBER, 1, Pal.INK1, false)
	# the Fading fuse
	var fx := r.position.x + 3.0
	var fw := r.size.x - 6.0
	var frac := clampf(st / maxf(1.0, b.sd_at), 0.0, 1.0)
	draw_rect(Rect2(fx, 352, fw, 2), Pal.INK4)
	draw_rect(Rect2(fx, 352, roundf(fw * frac), 2), Pal.BLOOD3 if frac > 0.75 else Pal.AMBER5)


# --- caption bar ------------------------------------------------------------------------------
func _draw_caption() -> void:
	if caption_uid < 0 or end_t >= 0.0 or cutin_t < cutin_hold:
		return
	var u = b.units[caption_uid]
	var sc: Color = b.side_colors[u.side]
	var r := Rect2(_c - _cap_w / 2.0, 292, _cap_w, 28)
	var sz := UIText.NUMBER
	var who: String = u.label
	var what := caption_text
	# every caption says whom it is aimed at: a name, or "all foes" / "all allies" / "self"
	var tgt := ""
	var tc: Color = b.side_colors[1 - u.side]
	match caption_area:
		"all_enemies":
			tgt = "all foes"
		"all_allies":
			tgt = "all allies"
			tc = sc
	if tgt == "" and caption_target >= 0:
		if caption_target == caption_uid:
			tgt = "self"
			tc = sc
		else:
			tgt = b.units[caption_target].label
			tc = b.side_colors[b.units[caption_target].side]
	var gap := UIText.width(" ", BOLD, sz)
	var arrow_w := 14.0
	var room := r.size.x - 16.0
	var w_who := UIText.width(who, BOLD, sz)
	var w_what := UIText.width(what, BOLD, sz)
	var w_tgt := UIText.width(tgt, BOLD, sz) if tgt != "" else 0.0
	var line1 := w_who + gap * 2.0 + w_what
	var total := line1 + (arrow_w + w_tgt if tgt != "" else 0.0)
	var who_col: Color = sc.lerp(Pal.INK10, 0.35)
	var tgt_col: Color = tc.lerp(Pal.INK10, 0.35)
	if total <= room:
		_panel_bg(r, sc, 1.0)
		var y := UIText.centered_y(r.position.y, r.size.y, BOLD, sz)
		var x := roundf(_c - total / 2.0)
		x = UIText.outlined(self, Vector2(x, y), who, who_col, BOLD, sz, 0, Pal.INK1, false) + gap * 2.0
		x = UIText.outlined(self, Vector2(x, y), what, Pal.INK10, BOLD, sz, 0, Pal.INK1, false)
		if tgt != "":
			_caption_target(x, r.get_center().y, y, tgt, tgt_col, arrow_w, sz)
		return
	# Too long for one line (long memory names in the Crystal fight): two lines, the panel grows
	# upward and, if it must, wider into the gap between the party panels. Names are never cut.
	var lh := UIText.line_h(BOLD, sz)
	var w_need := maxf(line1, arrow_w + w_tgt) + 16.0
	var w_max := (_r - _l) - 2.0 * (PANEL_W + 4.0)
	var w := clampf(w_need, r.size.x, w_max)
	var r2 := Rect2(roundf(_c - w / 2.0), r.end.y - (lh * 2.0 + 10.0), roundf(w), lh * 2.0 + 10.0)
	_panel_bg(r2, sc, 1.0)
	var y1 := UIText.centered_y(r2.position.y + 4.0, lh, BOLD, sz)
	var x1 := roundf(_c - line1 / 2.0)
	x1 = UIText.outlined(self, Vector2(x1, y1), who, who_col, BOLD, sz, 0, Pal.INK1, false) + gap * 2.0
	UIText.outlined(self, Vector2(x1, y1), what, Pal.INK10, BOLD, sz, 0, Pal.INK1, false)
	if tgt != "":
		var y2 := y1 + lh
		var x2 := roundf(_c - (arrow_w + w_tgt) / 2.0)
		_caption_target(x2, y2 + UIText.cap(BOLD, sz) * 0.5 + (UIText.ascent(BOLD, sz) - UIText.cap(BOLD, sz)), y2, tgt, tgt_col, arrow_w, sz)


func _caption_target(x: float, cy: float, y: float, tgt: String, col: Color, arrow_w: float, sz: int) -> void:
	_tri[0] = Vector2(x + 4, cy - 4); _tri[1] = Vector2(x + 10, cy); _tri[2] = Vector2(x + 4, cy + 4)
	draw_colored_polygon(_tri, Pal.INK8)
	UIText.outlined(self, Vector2(x + arrow_w, y), tgt, col, BOLD, sz, 0, Pal.INK1, false)


# --- party panels -----------------------------------------------------------------------------
func _draw_panel(side: int) -> void:
	var ids: Array = b.side_units[side]
	var n := ids.size()
	if n == 0:
		return
	var h := 6.0 + n * ROW_H
	var x0 := _l + 4.0 if side == 0 else _r - 4.0 - PANEL_W
	var y0 := 358.0 - h
	var r := Rect2(x0, y0, PANEL_W, h)
	_panel_bg(r, b.side_colors[side], 0.95)
	# names one size up (critic r3: the roster read thinner than the old 640x360 frame at phone
	# size) when every name on this side fits; else the whole side stays at the label size
	var sz := UIText.NUMBER
	for i in n:
		if UIText.width(b.units[ids[i]].label, BOLD, sz) > _name_room(sz):
			sz = UIText.LABEL
	for i in n:
		_draw_row(side, b.units[ids[i]], Vector2(x0, y0 + 3 + i * ROW_H), sz)


## Room for a roster name: the row minus the portrait and a 3-digit HP number.
func _name_room(sz: int) -> float:
	return PANEL_W - 4.0 - 17.0 - 4.0 - 6.0 - UIText.width("000", BOLD, sz) - 10.0


func _draw_row(side: int, u, p: Vector2, sz := UIText.LABEL) -> void:
	var left := side == 0
	var sc: Color = b.side_colors[side]
	var acting: bool = u.acting
	var rf: float = row_flash[u.uid] if u.uid < row_flash.size() else 0.0
	if acting:
		draw_rect(Rect2(p.x + 2, p.y, PANEL_W - 4, ROW_H - 1), Color(sc, 0.22))
		draw_rect(Rect2(p.x + 2, p.y, PANEL_W - 4, ROW_H - 1), Color(sc, 0.8), false, 1.0)
	if rf > 0.0:
		draw_rect(Rect2(p.x + 2, p.y, PANEL_W - 4, ROW_H - 1), Color(Pal.BLOOD3, rf * 0.35))
	var px := p.x + 4.0 if left else p.x + PANEL_W - 4.0 - 17.0
	var tex: Texture2D = b.portraits.get(u.uid)
	var py := p.y + 3.0
	draw_rect(Rect2(px - 1, py - 1, 18, 15), Pal.INK1)
	draw_rect(Rect2(px, py, 16, 13), Pal.INK3)
	if tex != null:
		var m := Color(1, 1, 1, 1) if u.alive else Color(0.45, 0.45, 0.55, 1)
		draw_texture_rect(tex, Rect2(px, py, 16, 13), false, m)
	draw_rect(Rect2(px - 1, py - 1, 18, 15), (sc if acting else Pal.INK5), false, 1.0)
	var tx := px + 21.0 if left else px - 4.0
	var bw := 112.0
	var bar_x := tx if left else tx - bw
	var name_col := Pal.INK10 if u.alive else Pal.FADE2
	var ny := UIText.centered_y(p.y, 12.0, BOLD, sz)
	# HP number on the far side of the name
	var num_x := p.x + PANEL_W - 6.0 if left else p.x + 6.0
	var hs := ""
	var hc := Pal.INK10
	if u.alive:
		var hpv := roundi(u.hp_shown)
		hs = str(hpv)
		hc = Pal.INK10 if hpv * 4 > u.max_hp else Pal.BLOOD4
	else:
		hs = "KO"
		hc = Pal.BLOOD3
	var hw := UIText.width(hs, BOLD, sz)
	UIText.draw(self, Vector2(num_x - hw if left else num_x, ny), hs, hc, BOLD, sz)
	var room := absf(num_x - tx) - UIText.width("000", BOLD, sz) - 6.0   # clear of a 3-digit HP number
	var nm := UIText.fit(u.label, room, BOLD, sz)
	UIText.draw(self, Vector2(tx if left else tx - UIText.width(nm, BOLD, sz), ny), nm,
		name_col if not acting else sc.lerp(Pal.INK10, 0.5), BOLD, sz)
	if not u.alive:
		draw_rect(Rect2(bar_x, p.y + 15.0, bw, 1), Pal.INK4)
		return
	# HP bar
	var frac: float = clampf(u.hp_shown / float(u.max_hp), 0.0, 1.0)
	var chip: float = clampf(u.hp_chip / float(u.max_hp), 0.0, 1.0)
	var by := p.y + 15.0
	draw_rect(Rect2(bar_x - 1, by - 1, bw + 2, 5), Pal.INK1)
	draw_rect(Rect2(bar_x, by, bw, 3), Pal.INK3)
	var hcol := Pal.LIFE4 if frac > 0.5 else (Pal.AMBER5 if frac > 0.25 else Pal.BLOOD3)
	if chip > frac:
		draw_rect(Rect2(bar_x + roundf(bw * frac), by, roundf(bw * (chip - frac)), 3), Pal.BLOOD4)
	if frac > 0.0:
		draw_rect(Rect2(bar_x, by, roundf(bw * frac), 3), hcol.lerp(Pal.INK10, u.heal_glow * 0.7))
		draw_rect(Rect2(bar_x, by, roundf(bw * frac), 1), hcol.lightened(0.3))
	# charge meter
	var cy := by + 3.0
	var cf: float = clampf(u.charge_shown / float(u.charge_max), 0.0, 1.0)
	draw_rect(Rect2(bar_x, cy, bw, 1), Pal.INK4)
	if u.alive:
		var ccol := Pal.VIOLET4
		if u.is_ready:
			ccol = Pal.VIOLET4 if fmod(t, 0.3) < 0.18 else Pal.INK10
		draw_rect(Rect2(bar_x, cy, roundf(bw * cf), 1), ccol)
	# ready icon
	if u.is_ready and u.alive:
		var ix := bar_x + bw + 3.0 if left else bar_x - 10.0
		draw_texture(ICON_ABILITY, Vector2(ix, by - 1))


# --- intro cards --------------------------------------------------------------------------------
## One card per side (BUILD.md: effects are icons): the shape's name, one row of shared stat chips
## (green ▲ gains, red ▼ costs, short labels) and the behaviour glyph with its short label
## (20 characters or fewer). Every chip opens the shared Tip with the full sentence.
const INTRO_W := 296.0
const INTRO_GAP := 10.0
var _intro: Array = [null, null]          # side -> Control holding the card's EffectChips
var _intro_rows: Array = [[], []]         # side -> [[[effect, label_w], ...], ...] per row


## Effects for the intro card: rows [stat chips], [behaviour]. Class bonds stay on the banner.
func _intro_effects(side: int) -> Array:
	var stats: Array = []
	var beh: Array = []
	for e: Dictionary in _banner_effects(side):
		var k := String(e.get("kind", ""))
		if k == "bond":
			continue
		var c := e.duplicate()
		if k == "stat":
			# whose stat it is stays on the chip ("Ilse Heal +40%"; critic r3: two bare "+40%")
			var subj := String(e.get("subject", ""))
			c["title"] = (subj + " " if subj != "" else "") + String(e.get("short", e.get("title", "")))
		if k == "behaviour":
			beh.append(c)
		else:
			stats.append(c)
	if stats.is_empty() and beh.is_empty():
		# a shape the icon set doesn't cover (the Crystal): its behaviour as one glyph
		var form: Dictionary = b.sides[side].get("formation", {})
		var bd: Dictionary = form.get("behaviour", {})
		if not bd.is_empty():
			beh.append({"icon": EffectIcons.behaviour_icon(String(bd.get("id", ""))), "sign": 0, "kind": "behaviour",
				"title": "Never acts" if String(form.get("id", form.get("shape", ""))) == "crystal_chamber" else UIText.fit(String(bd.get("name", "")), 110.0, BOLD, UIText.LABEL),
				"name": String(bd.get("name", "")), "text": String(bd.get("text", ""))})
	return [stats, beh]


func _build_intro() -> void:
	for side in 2:
		if _intro[side] != null:
			(_intro[side] as Control).queue_free()
		var box := Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		_intro[side] = box
		var rows: Array = []
		var tw := INTRO_W - 24.0
		for list: Array in _intro_effects(side):
			if list.is_empty():
				continue
			var row: Array = []
			for e: Dictionary in list:
				row.append([e, _chip_label_w(String(e["title"]))])
			# one row: if the labels don't fit, stat chips keep their subject and value ("Ilse +40%";
			# the icon names the stat), then labels drop from the end (the tooltip still says it all)
			if _row_w(row) > tw:
				for item: Array in row:
					var e: Dictionary = item[0]
					if String(e.get("kind", "")) == "stat" and e.has("value"):
						var subj := String(e.get("subject", ""))
						e["title"] = (subj + " " if subj != "" else "") + String(e["value"])
						item[1] = _chip_label_w(String(e["title"]))
			var k := row.size() - 1
			while _row_w(row) > tw and k >= 0:
				row[k][1] = 0
				k -= 1
			rows.append(row)
		_intro_rows[side] = rows
		for row: Array in rows:
			for it: Array in row:
				var chip := EffectChip.new()
				box.add_child(chip)
				chip.setup(it[0], "below", int(it[1]))
				it.append(chip)
		box.visible = false


func _chip_label_w(t: String) -> float:
	return ceilf(6.0 + UIText.width(t, BOLD, UIText.LABEL) + 2.0)


func _row_w(row: Array) -> float:
	var w := 0.0
	for it: Array in row:
		w += EffectIcons.CHIP + float(it[1])
	return w + INTRO_GAP * maxf(0.0, row.size() - 1)


func _intro_rect(side: int) -> Rect2:
	var h := 8.0 + UIText.ascent(SERIF, UIText.HEADING) + 8.0
	h += (_intro_rows[side] as Array).size() * (EffectIcons.CHIP + 5.0) + 3.0
	var cw := INTRO_W
	return Rect2(_l + 6.0 if side == 0 else _r - 6.0 - cw, 6, cw, ceilf(h))


## Places and fades the card's chips (called every tick while the intro shows).
func _place_intro() -> void:
	var on := intro_t >= 0.0 and intro_t <= intro_len + 0.4
	var fade := 1.0 - clampf((intro_t - (intro_len - 0.35)) / 0.3, 0.0, 1.0)
	for side in 2:
		var box: Control = _intro[side]
		if box == null:
			continue
		var a := clampf((intro_t - 0.15 - side * 0.15) / 0.2, 0.0, 1.0) * fade
		box.visible = on and a > 0.0
		if not box.visible:
			continue
		box.modulate = Color(1, 1, 1, a)
		var r := _intro_rect(side)
		var y := r.position.y + 8.0 + UIText.ascent(SERIF, UIText.HEADING) + 8.0
		for row: Array in _intro_rows[side]:
			var x := roundf(r.get_center().x - _row_w(row) / 2.0)
			for it: Array in row:
				(it[2] as Control).position = Vector2(x, y)
				x += EffectIcons.CHIP + float(it[1]) + INTRO_GAP
			y += EffectIcons.CHIP + 5.0


func _draw_intro() -> void:
	var it := intro_t
	var fade := 1.0 - clampf((it - (intro_len - 0.35)) / 0.3, 0.0, 1.0)
	for side in 2:
		var a := clampf((it - 0.15 - side * 0.15) / 0.2, 0.0, 1.0) * fade
		if a <= 0.0:
			continue
		var sc: Color = b.side_colors[side]
		var r := _intro_rect(side)
		_panel_bg(r, sc, a, 0.5)
		UIText.outlined(self, Vector2(r.get_center().x, r.position.y + 8.0), _badge_parts(side)[0],
			Color(sc.lerp(Pal.INK10, 0.35), a), SERIF, UIText.HEADING, 1, Pal.INK1, false)


# --- Crystal: memory lore caption and fragment banner -----------------------------------------------
## Bottom of the memory lore caption in UI design px while it shows (numbers keep below it), else -1.
func lore_bottom() -> float:
	if lore_t > 3.6 or lore_name == "":
		return -1.0
	var lines := UIText.wrap_lines(lore_text, 456.0, BOLD, UIText.BODY)
	return 40.0 + ceilf(10.0 + UIText.ascent(SERIF, UIText.TITLE) + 6.0 + lines.size() * UIText.line_h(BOLD, UIText.BODY) + 6.0)


func _draw_lore() -> void:
	if lore_t > 3.6 or lore_name == "":
		return
	var a := clampf(lore_t / 0.25, 0.0, 1.0) * (1.0 - clampf((lore_t - 3.2) / 0.4, 0.0, 1.0))
	var lines := UIText.wrap_lines(lore_text, 456.0, BOLD, UIText.BODY)
	var lh := UIText.line_h(BOLD, UIText.BODY)
	var h := ceilf(10.0 + UIText.ascent(SERIF, UIText.TITLE) + 6.0 + lines.size() * lh + 6.0)
	var r := Rect2(_c - 240, 40, 480, h)
	draw_rect(r, Color(Pal.INK1, 0.85 * a))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Color(Pal.VIOLET3, a))
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color(Pal.VIOLET3, a))
	var y := r.position.y + 6.0
	UIText.outlined(self, Vector2(_c, y), lore_name, Color(Pal.VIOLET4, a), SERIF, UIText.TITLE, 1, Pal.INK1, false)
	y += UIText.ascent(SERIF, UIText.TITLE) + 6.0
	for i in lines.size():
		UIText.outlined(self, Vector2(_c, y), lines[i], Color(Pal.INK9, a), BOLD, UIText.BODY, 1, Pal.INK1, false)
		y += lh


func _draw_fragment() -> void:
	if frag_t > FRAG_SHOW or frag_n <= 0 or end_t >= 0.0:
		return
	var a := clampf(frag_t / 0.1, 0.0, 1.0) * (1.0 - clampf((frag_t - (FRAG_SHOW - 0.4)) / 0.4, 0.0, 1.0))
	var sz := fragment_size()
	var r := fragment_rect()
	draw_rect(r, Color(Pal.INK1, 0.95 * a))
	draw_rect(r, Color(Pal.CRYSTAL5, a), false, 1.0)
	if frag_t < 0.35:   # a second ring as the shard breaks off (the text's ground stays dark)
		draw_rect(r.grow(2.0), Color(Pal.CRYSTAL5, a), false, 1.0)
	UIText.outlined(self, Vector2(_c, UIText.centered_y(r.position.y, r.size.y, BOLD, sz)), _frag_text(),
		Color(Pal.CRYSTAL5, a), BOLD, sz, 1, Pal.INK1, false)


# --- ability cut-in -------------------------------------------------------------------------------
func _draw_cutin() -> void:
	if cutin_uid < 0:
		return
	var total := cutin_hold + 0.25
	if cutin_t > total:
		return
	var u = b.units[cutin_uid]
	var sc: Color = b.side_colors[u.side]
	var dir := -1.0 if u.side == 0 else 1.0
	var inn := clampf(cutin_t / 0.12, 0.0, 1.0)
	if cutin_t > cutin_hold:
		return   # the action caption takes the slot back at once
	var band_h := roundf(40.0 * inn)
	if band_h < 1.0:
		return
	var cy := 309.0
	var bw := _cap_w
	var bx := _c - bw / 2.0
	var band := Rect2(bx, cy - band_h * 0.5, bw, band_h)
	draw_rect(band, Color(Pal.INK1, 0.92))
	draw_rect(Rect2(bx, band.position.y, bw, 1), sc)
	draw_rect(Rect2(bx, band.end.y - 1, bw, 1), sc)
	# speed lines
	for k in 9:
		var ly := band.position.y + 4.0 + fmod(k * 7.0, maxf(1.0, band_h - 8.0))
		var lx := bx + fmod(t * 500.0 * -dir + k * 67.0, bw - 40.0)
		draw_rect(Rect2(roundf(lx), roundf(ly), 20 + (k % 3) * 8, 1), Color(sc, 0.35))
	if band_h < 30.0:
		return
	var tx := roundf(_c + dir * (1.0 - minf(1.0, cutin_t / 0.16)) * 60.0)
	UIText.outlined(self, Vector2(tx, cy - 14.0), u.label.to_upper() + "  ·  ABILITY", Pal.VIOLET4, BOLD, UIText.LABEL, 1, Pal.INK1, false)
	UIText.outlined(self, Vector2(tx, cy - 2.0), cutin_name, sc.lerp(Pal.INK10, 0.35), SERIF, UIText.HEADING, 1, Pal.INK1, false)


## The Fading (sudden death): one line in the game's voice, then a small rising readout.
func _draw_fading() -> void:
	var y := 40.0
	if sd_banner_t < 3.2:
		var a := clampf(sd_banner_t / 0.3, 0.0, 1.0) * (1.0 - clampf((sd_banner_t - 2.8) / 0.4, 0.0, 1.0))
		UIText.outlined(self, Vector2(_c, y), "The memory of this battle is fading…", Color(Pal.INK10, a), SERIF, UIText.HEADING, 1)
		return
	# readout under the banners once the line has gone
	UIText.outlined(self, Vector2(_c, y), "Fading  ×%.2f" % b.sd_mult, Pal.FADE4, BOLD, UIText.NUMBER, 1)


# --- finish -----------------------------------------------------------------------------------------
func _draw_end() -> void:
	if end_t < 0.0:
		return
	var a := clampf(end_t / 0.3, 0.0, 1.0)
	var win: bool = winner == b.player_side
	var col := Pal.AMBER6 if win else (Pal.FADE3 if winner == -1 else Pal.BLOOD4)
	var h := 72.0 * a
	var cy := 150.0
	draw_rect(Rect2(0, cy - h * 0.5, _vw, h), Color(Pal.INK1, 0.95))
	draw_rect(Rect2(0, cy - h * 0.5, _vw, 1), Color(col, a))
	draw_rect(Rect2(0, cy + h * 0.5 - 1, _vw, 1), Color(col, a))
	if h < 68.0:
		return
	# letters drop in one by one
	var word := winner_text
	var sz := UIText.DISPLAY
	var total_w := UIText.width(word, SERIF, sz)
	var x := roundf(_c - total_w * 0.5)
	var top := cy - 25.0
	for i in word.length():
		var ch := word.substr(i, 1)
		var cw := UIText.width(ch, SERIF, sz)
		var lt := clampf((end_t - 0.15 - i * 0.06) / 0.18, 0.0, 1.0)
		if lt > 0.0:
			var dy := roundf((1.0 - (1.0 - pow(1.0 - lt, 2.0))) * -30.0)
			var bounce := roundf(sin(clampf((end_t - 0.33 - i * 0.06) / 0.2, 0.0, 1.0) * PI) * -3.0)
			UIText.outlined(self, Vector2(x, top + dy + bounce), ch, col, SERIF, sz, 0)
		x += cw
	if end_t > 0.8:
		var sub_a := clampf((end_t - 0.8) / 0.3, 0.0, 1.0)
		UIText.outlined(self, Vector2(_c, cy + 14.0), b.end_subtitle, Color(Pal.INK10, sub_a), BOLD, UIText.LABEL, 1, Pal.INK1, false)


## "+N" chip for banner effects beyond the room (opens the rest in the shared tooltip).
class MoreChip extends Control:
	var n := 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(EffectIcons.CHIP, EffectIcons.CHIP)
		size = custom_minimum_size
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Pal.INK1)
		draw_rect(r.grow(-1), Pal.INK3)
		draw_rect(r, Pal.INK6, false, 1.0)
		UIText.outlined(self, Vector2(size.x / 2.0, UIText.centered_y(0, size.y, UIText.BOLD, UIText.LABEL)), "+%d" % n,
			Pal.INK10, UIText.BOLD, UIText.LABEL, 1, Pal.INK1, false)
