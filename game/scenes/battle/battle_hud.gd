extends Control
const GameData = preload("res://core/game_data.gd")
const FXS = preload("res://scenes/battle/battle_fx.gd")
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
var caption_extra := 0          # further units the action hits besides its target ("▸ Moth + 2")
## The other kind of target an action touches (critic r11 fix 2): "· heals self", "· strikes Corin".
var caption_tail_verb := ""
var caption_tail := -1
var caption_tail_extra := 0
## What the action did beyond hits and heals, after the target (round 17): "sealed", "2 blinded".
var caption_note := ""
## A target the caption names that has no unit yet (a summon being called): its label.
var caption_lead_label := ""
var cutin_uid := -1
var cutin_name := ""
var cutin_t := 9.0
var cutin_hold := 0.9
var cutin_icon := ""      # the ability's effect icon (abilities.gd "icon"), beside its name
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
var _vh := 360.0
## The HUD lives in two bands and never covers the board (user playtest 2026-10-06: the rosters and
## the caption hid the bottom-row heroes): the top band holds the formation badges, each team's tab
## (name and how many stand) and the Fading readout; the bottom band the clock, the caption (or the
## ability cut-in, a memory's lore, the Fading's line) and x1 / SKIP. The board sits between them at
## every window shape (the battle view is centred, and its rows fit 640x360 between the bands).
const TOP_H := 42.0
const BOT_H := 32.0
const TAB_H := 12.0
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
	_vh = vr.size.y
	_l = sr.position.x
	_r = sr.end.x
	_c = roundf(vr.size.x / 2.0)
	_cap_w = clampf((_r - _l) - 2.0 * 112.0, 240.0, 420.0)
	if speed_btn != null:
		var by := roundf(_vh - BOT_H * 0.5 - 10.0)
		speed_btn.position = Vector2(roundf(_c + _cap_w / 2.0 + 6.0), by)
		skip_btn.position = Vector2(roundf(_c + _cap_w / 2.0 + 52.0), by)
		# x1 / SKIP mean nothing once the fight is over (critic r10 fix 4)
		speed_btn.visible = end_t < 0.0 and not b_ended()
		skip_btn.visible = speed_btn.visible


## The board's vertical room (UI px): between the top band and the bottom band.
func band_top() -> float:
	return TOP_H


func band_bottom() -> float:
	return _vh - BOT_H


func top_band() -> Rect2:
	return Rect2(0, 0, _vw, TOP_H)


func bottom_band() -> Rect2:
	return Rect2(0, _vh - BOT_H, _vw, BOT_H)


## A team's tab under its formation badge: "The Lanternrest Company · 4" (heroes standing).
func team_tab_text(side: int) -> String:
	var n := 0
	for id: int in b.side_units[side]:
		var u = b.units[id]
		if u.alive and u.summon == "" and not u.is_crystal:
			n += 1
	return "%s · %d" % [team_name(side), n]


func team_tab_rect(side: int) -> Rect2:
	var w := UIText.width(team_tab_text(side), BOLD, UIText.LABEL) + 12.0
	var br := badge_rect(side)
	return Rect2(br.position.x if side == 0 else br.end.x - w, br.end.y + 1.0, w, TAB_H)


func b_ended() -> bool:
	return b != null and int(b._state) == 3


## The team's name as the fight knows it (sides[].name), shown on its roster tab and in the result.
func team_name(side: int) -> String:
	if b == null or side < 0 or side >= b.sides.size():
		return ""
	return String(b.sides[side].get("name", ""))


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


## True while only Fading ticks have happened since the caption's action: the caption dims so the
## ticks don't read as that action hitting both sides (critic r10 fix 8).
var caption_stale := false


func show_caption(uid: int, text: String, target: int, is_ability: bool, area := "single", extra := 0,
		tail_verb := "", tail := -1, tail_extra := 0, note := "", lead_label := "") -> void:
	caption_stale = false
	caption_note = note
	caption_lead_label = lead_label
	caption_extra = extra
	caption_tail_verb = tail_verb
	caption_tail = tail
	caption_tail_extra = tail_extra
	caption_area = area
	caption_uid = uid
	caption_text = text
	caption_target = target
	caption_t = 0.0
	caption_ability = is_ability


func show_cutin(uid: int, ability: String, hold: float, icon := "") -> void:
	cutin_icon = icon
	cutin_uid = uid
	cutin_name = ability
	cutin_t = 0.0
	cutin_hold = hold


func pulse_badge(side: int, line: int) -> void:
	badge_pulse[side] = 1.0
	badge_line[side] = line


# ------------------------------------------------------------------------------------- drawing
func _draw() -> void:
	var t0 := Time.get_ticks_usec() if FXS.perf_on else 0
	_draw_hud()
	if FXS.perf_on:
		FXS.perf_us += Time.get_ticks_usec() - t0


func _draw_hud() -> void:
	if b == null or b.units.is_empty():
		_draw_fade()
		return
	_draw_vignette()
	var intro_done := intro_t < 0.0 or intro_t > intro_len - 0.35
	var sd_on: bool = b.sd_at > 0.0 and b.sim_t >= b.sd_at
	if intro_done:
		for side in 2:
			_draw_badge(side, 1.0)
			if end_t < 0.0:
				_draw_team_tab(side)
	if sd_on and end_t < 0.0:
		_draw_fading()
	_draw_timer()
	_draw_caption()
	if intro_t >= 0.0 and intro_t <= intro_len + 0.4:
		_draw_intro()
	_draw_cutin()
	_draw_lore()
	_draw_fragment()
	_draw_end()
	if flash_a > 0.0:
		draw_rect(Rect2(0, 0, _vw, _vh), Color(flash_color, flash_a))
	_draw_fade()


func _draw_fade() -> void:
	if fade_in > 0.0:
		draw_rect(Rect2(0, 0, maxf(_vw, 640.0), maxf(_vh, 360.0)), Color(Pal.INK1, minf(1.0, fade_in)))


func _draw_vignette() -> void:
	var a := doom * 0.35 + vignette * 0.5
	if a <= 0.01:
		return
	var c := Pal.BLOOD2
	for k in 4:
		var w := 6.0 + k * 6.0
		var ca := Color(c, a * (0.55 - k * 0.12))
		draw_rect(Rect2(0, 0, _vw, w), ca)
		draw_rect(Rect2(0, _vh - w, _vw, w), ca)
		draw_rect(Rect2(0, 0, w, _vh), ca)
		draw_rect(Rect2(_vw - w, 0, w, _vh), ca)


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


## The team's tab: its name and how many heroes stand, in its side colour (the rosters are gone:
## every unit carries its HP bar, and a tap on a unit opens its card).
func _draw_team_tab(side: int) -> void:
	var r := team_tab_rect(side)
	var sc: Color = b.side_colors[side]
	draw_rect(r, Color(Pal.INK1, 0.88))
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), sc)
	UIText.outlined(self, Vector2(r.get_center().x, UIText.centered_y(r.position.y, r.size.y - 1.0, BOLD, UIText.LABEL)),
		team_tab_text(side), UIText.legible(sc.lerp(Pal.INK10, 0.2)), BOLD, UIText.LABEL, 1, Pal.INK1, false)


func _panel_bg(r: Rect2, sc: Color, alpha: float, pulse := 0.0) -> void:
	draw_rect(r, Color(Pal.INK1, 0.82 * alpha))
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(Pal.INK2, 0.75 * alpha))
	var bc := Pal.INK5.lerp(sc, 0.3 + 0.7 * pulse)
	draw_rect(r, Color(bc, alpha), false, 1.0)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Color(sc, alpha * (0.7 + 0.3 * pulse)))


# --- timer ------------------------------------------------------------------------------------
func _draw_timer() -> void:
	if end_t >= 0.0:
		return   # the result line gives the fight's time (critic r11 fix 5: the clock repeated it)
	var st: float = b.sim_t if b.end_clock < 0.0 else minf(b.sim_t, b.end_clock)
	var secs := int(st)
	var r := Rect2(roundf(_c - _cap_w / 2.0 - 58.0), roundf(_vh - BOT_H * 0.5 - 13.0), 52, 26)
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
	draw_rect(Rect2(fx, r.end.y - 6.0, fw, 2), Pal.INK4)
	draw_rect(Rect2(fx, r.end.y - 6.0, roundf(fw * frac), 2), Pal.BLOOD3 if frac > 0.75 else Pal.AMBER5)


# --- caption bar ------------------------------------------------------------------------------
## The caption's layout (pure: the draw and the label solver's walls both use it, so a test that
## never draws still sees the caption as drawn). {} when no caption shows; else its "rect" (UI px),
## "two" (two lines), its strings, widths and colours.
var _cap_key := ""
var _cap_memo: Dictionary = {}


func caption_layout() -> Dictionary:
	# memoized on everything it reads (the solver, the clip rects and the draw all ask each frame)
	var key := "%d|%s|%d|%d|%s|%d|%d|%s|%s|%s|%s|%s|%s|%.0f|%.0f" % [caption_uid, caption_text, caption_target, caption_extra,
		caption_tail_verb, caption_tail, caption_tail_extra, caption_note, caption_lead_label, caption_area,
		end_t >= 0.0, cutin_t < cutin_hold, lore_bottom() > 0.0 or (b != null and fading_line_on() and b.sim_t >= b.sd_at), _vw, _vh]
	if key != _cap_key:
		_cap_key = key
		_cap_memo = _caption_layout()
	return _cap_memo


func _caption_layout() -> Dictionary:
	if b == null or caption_uid < 0 or caption_uid >= b.units.size() or end_t >= 0.0 or cutin_t < cutin_hold \
			or lore_bottom() > 0.0 or (fading_line_on() and b.sim_t >= b.sd_at):
		return {}   # the slot is the lore's or the Fading line's while they show
	var u = b.units[caption_uid]
	var sc: Color = b.side_colors[u.side]
	var r := Rect2(_c - _cap_w / 2.0, roundf(_vh - BOT_H * 0.5 - 13.0), _cap_w, 26)
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
	if tgt == "" and caption_lead_label != "":
		tgt = caption_lead_label
		tc = sc
	elif caption_area == "column" and caption_target >= 0 and caption_target < b.units.size():
		tgt = "%s column" % ("front" if b.units[caption_target].col == 0 else "back")
	if tgt == "" and caption_target >= 0:
		if caption_target == caption_uid:
			tgt = "self"
			tc = sc
		else:
			tgt = b.units[caption_target].label
			tc = b.side_colors[b.units[caption_target].side]
			if caption_extra > 0:
				tgt += " + %d" % caption_extra
	# the other kind of target, as a clause after the lead (critic r11 fix 2)
	var tail := ""
	var tail_col := Pal.INK10
	if tgt != "" and caption_tail_verb != "" and caption_tail >= 0 and caption_tail < b.units.size():
		var tu = b.units[caption_tail]
		tail = "· %s %s" % [caption_tail_verb, "self" if caption_tail == caption_uid else tu.label]
		if caption_tail_extra > 0:
			tail += " + %d" % caption_tail_extra
		tail_col = (b.side_colors[tu.side] as Color).lerp(Pal.INK10, 0.35)
	if tgt != "" and caption_note != "":
		tail = (tail + " · " if tail != "" else "· ") + caption_note
	var L := {"who": who, "what": what, "tgt": tgt, "tail": tail, "tail_col": tail_col, "sc": sc,
		"who_col": sc.lerp(Pal.INK10, 0.35), "tgt_col": tc.lerp(Pal.INK10, 0.35), "arrow_w": 14.0}
	_caption_widths(L, sz)
	var total: float = L["line1"] + (L["arrow_w"] + L["w_tgt"] + L["w_tail"] if tgt != "" else 0.0)
	if total <= r.size.x - 16.0:
		L["rect"] = r
		L["two"] = false
		L["total"] = total
		return L
	# Too long for one line (long memory names in the Crystal fight, a clause for a second kind of
	# target): two lines in the bottom band, between the clock and x1 / SKIP. Names are never cut.
	var w_max := _cap_w
	_caption_widths(L, UIText.LABEL)   # two lines fit the band at the label size; never cut
	var lh := UIText.line_h(BOLD, L["sz"])
	var w_need: float = maxf(L["line1"], L["arrow_w"] + L["w_tgt"] + L["w_tail"]) + 16.0
	var w := clampf(w_need, r.size.x, w_max)
	L["rect"] = Rect2(roundf(_c - w / 2.0), roundf(_vh - BOT_H * 0.5 - (lh * 2.0 + 6.0) * 0.5), roundf(w), ceilf(lh * 2.0 + 6.0))
	L["two"] = true
	L["lh"] = lh
	return L


func _caption_widths(L: Dictionary, sz: int) -> void:
	L["sz"] = sz
	L["gap"] = UIText.width(" ", BOLD, sz)
	L["w_tgt"] = UIText.width(L["tgt"], BOLD, sz) if L["tgt"] != "" else 0.0
	L["w_tail"] = (L["gap"] + UIText.width(L["tail"], BOLD, sz)) if L["tail"] != "" else 0.0
	L["line1"] = UIText.width(L["who"], BOLD, sz) + L["gap"] * 2.0 + UIText.width(L["what"], BOLD, sz)


func _draw_caption() -> void:
	var L := caption_layout()
	caption_drawn = L.get("rect", Rect2())
	if L.is_empty():
		return
	var sz: int = L["sz"]
	var gap: float = L["gap"]
	var tgt: String = L["tgt"]
	var tail: String = L["tail"]
	var r: Rect2 = L["rect"]
	_panel_bg(r, L["sc"], 1.0)
	if not bool(L["two"]):
		var y := UIText.centered_y(r.position.y, r.size.y, BOLD, sz)
		var x := roundf(_c - float(L["total"]) / 2.0)
		x = UIText.outlined(self, Vector2(x, y), L["who"], L["who_col"], BOLD, sz, 0, Pal.INK1, false) + gap * 2.0
		x = UIText.outlined(self, Vector2(x, y), L["what"], Pal.INK10, BOLD, sz, 0, Pal.INK1, false)
		if tgt != "":
			x = _caption_target(x, r.get_center().y, y, tgt, L["tgt_col"], L["arrow_w"], sz)
			if tail != "":
				UIText.outlined(self, Vector2(x + gap, y), tail, L["tail_col"], BOLD, sz, 0, Pal.INK1, false)
		_dim_stale(r)
		return
	var lh: float = L["lh"]
	var y1 := UIText.centered_y(r.position.y + 3.0, lh, BOLD, sz)
	var x1 := roundf(_c - float(L["line1"]) / 2.0)
	x1 = UIText.outlined(self, Vector2(x1, y1), L["who"], L["who_col"], BOLD, sz, 0, Pal.INK1, false) + gap * 2.0
	UIText.outlined(self, Vector2(x1, y1), L["what"], Pal.INK10, BOLD, sz, 0, Pal.INK1, false)
	if tgt != "":
		var y2 := y1 + lh
		var x2 := roundf(_c - (float(L["arrow_w"]) + float(L["w_tgt"]) + float(L["w_tail"])) / 2.0)
		x2 = _caption_target(x2, y2 + UIText.cap(BOLD, sz) * 0.5 + (UIText.ascent(BOLD, sz) - UIText.cap(BOLD, sz)), y2, tgt, L["tgt_col"], L["arrow_w"], sz)
		if tail != "":
			UIText.outlined(self, Vector2(x2 + gap, y2), tail, L["tail_col"], BOLD, sz, 0, Pal.INK1, false)
	_dim_stale(r)


func _dim_stale(r: Rect2) -> void:
	if caption_stale:
		draw_rect(r.grow(-1.0), Color(Pal.INK1, 0.6))


func _caption_target(x: float, cy: float, y: float, tgt: String, col: Color, arrow_w: float, sz: int) -> float:
	_tri[0] = Vector2(x + 4, cy - 4); _tri[1] = Vector2(x + 10, cy); _tri[2] = Vector2(x + 4, cy + 4)
	draw_colored_polygon(_tri, Pal.INK8)
	return UIText.outlined(self, Vector2(x + arrow_w, y), tgt, col, BOLD, sz, 0, Pal.INK1, false)


# --- party panels -----------------------------------------------------------------------------
## A roster panel with its team-name tab (UI px; pure layout, as drawn), or an empty rect.
func panel_rect(side: int) -> Rect2:
	if true:
		return Rect2()   # no roster panels since round 17 (the bands hold the HUD)
	if b == null or b.side_units[side].is_empty():
		return Rect2()
	var h := 6.0 + roster_rows(side).size() * ROW_H
	var x0 := _l + 4.0 if side == 0 else _r - 4.0 - PANEL_W
	var r := Rect2(x0, 358.0 - h, PANEL_W, h)
	var tn := team_name(side)
	if tn != "":
		var tw := minf(PANEL_W, UIText.width(tn, BOLD, UIText.LABEL) + 12.0)
		r = r.merge(Rect2(x0 if side == 0 else x0 + PANEL_W - tw, r.position.y - 13.0, tw, 14.0))
	return r


func _draw_panel(side: int) -> void:
	var ids: Array = b.side_units[side]
	var n := ids.size()
	if n == 0:
		return
	var rows := roster_rows(side)
	var h := 6.0 + rows.size() * ROW_H
	var x0 := _l + 4.0 if side == 0 else _r - 4.0 - PANEL_W
	var y0 := 358.0 - h
	var r := Rect2(x0, y0, PANEL_W, h)
	panel_drawn[side] = r
	_panel_bg(r, b.side_colors[side], 0.95)
	# the team's name on a tab over its roster: the same name the result card says won
	var tn := team_name(side)
	if tn != "":
		var tw := minf(PANEL_W, UIText.width(tn, BOLD, UIText.LABEL) + 12.0)
		var tab := Rect2(x0 if side == 0 else x0 + PANEL_W - tw, y0 - 13.0, tw, 14.0)
		draw_rect(tab, Color(Pal.INK1, 0.9))
		draw_rect(Rect2(tab.position.x, tab.position.y, tab.size.x, 1), b.side_colors[side])
		UIText.outlined(self, Vector2(tab.get_center().x, UIText.centered_y(tab.position.y + 1.0, tab.size.y - 1.0, BOLD, UIText.LABEL)),
			UIText.fit(tn, tw - 8.0, BOLD, UIText.LABEL), UIText.legible(b.side_colors[side].lerp(Pal.INK10, 0.2)), BOLD, UIText.LABEL, 1, Pal.INK1, false)
		panel_drawn[side] = r.merge(tab)
	# names one size up (critic r3: the roster read thinner than the old 640x360 frame at phone
	# size) when every name on this side fits; else the whole side stays at the label size
	var sz := UIText.NUMBER
	for row: Variant in rows:
		if row is String:
			continue
		if UIText.width(b.units[int(row)].label, BOLD, sz) > _name_room(sz):
			sz = UIText.LABEL
	for i in rows.size():
		var p := Vector2(x0, y0 + 3 + i * ROW_H)
		if rows[i] is String:
			_draw_summary_row(side, String(rows[i]), p)
		else:
			_draw_row(side, b.units[int(rows[i])], p, sz)


func _pip(cx: float, cy: float, lit: bool) -> void:
	for r: float in [4.0, 3.0]:
		_tri.resize(4)
		_tri[0] = Vector2(cx + 0.5, cy - r)
		_tri[1] = Vector2(cx + 1.0 + r, cy + 0.5)
		_tri[2] = Vector2(cx + 0.5, cy + 1.0 + r)
		_tri[3] = Vector2(cx - r, cy + 0.5)
		draw_colored_polygon(_tri, Pal.INK1 if r > 3.5 else (Pal.VIOLET4 if lit else Pal.INK4))
	_tri.resize(3)


## A roster never grows past MAX_ROWS (critic r5: the Fading's fifth memory grew the enemy panel
## up over the Crystal's bar and pips). Past that, the fallen fold into one summary row ("3 memories
## faded"), and if the living alone still overflow, the last row says how many more there are.
## Returns unit uids (int) and summary rows (String), top to bottom.
const MAX_ROWS := 4


func roster_rows(side: int) -> Array:
	# summons (an echo, a husk) keep their HP on their plate, not a roster row: the roster stays the
	# party (round 17: an echo pushed a hero off into "+2 more")
	var ids: Array = []
	for id: int in b.side_units[side]:
		if b.units[id].summon == "":
			ids.append(id)
	if ids.size() <= MAX_ROWS:
		return ids.duplicate()
	var living: Array = []
	var fallen := 0
	var memories := true
	for id: int in ids:
		var u = b.units[id]
		if u.alive:
			living.append(id)
		else:
			fallen += 1
			memories = memories and u.is_memory
	var rows: Array = living.duplicate()
	var more := 0
	var room := MAX_ROWS - (1 if fallen > 0 else 0)
	if rows.size() > room:
		room = MAX_ROWS - 1
		more = rows.size() - room
		rows = rows.slice(0, room)
	var parts: PackedStringArray = []
	if more > 0:
		parts.append("+%d more" % more)
	if fallen > 0:
		parts.append(("%d %s faded" % [fallen, "memory" if fallen == 1 else "memories"]) if memories else ("%d fallen" % fallen))
	if not parts.is_empty():
		rows.append("  ·  ".join(parts))
	return rows


func _draw_summary_row(side: int, text: String, p: Vector2) -> void:
	var left := side == 0
	var sz := UIText.LABEL
	var y := UIText.centered_y(p.y, ROW_H - 2.0, BOLD, sz)
	var w := UIText.width(text, BOLD, sz)
	var x := p.x + 25.0 if left else p.x + PANEL_W - 25.0 - w
	UIText.draw(self, Vector2(x, y), text, Pal.FADE4, BOLD, sz)
	draw_rect(Rect2(p.x + 6, p.y, PANEL_W - 12, 1), Pal.INK4)


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
	# the Crystal's 4 fragment pips, on its bar's line beside the bar (critic r5: in the world they
	# ran into heroes' bars and hid under the grown roster)
	if u.is_crystal:
		for k in 4:
			var px2 := (bar_x - 39.0 + k * 9.0) if not left else (bar_x + bw + 7.0 + k * 9.0)
			_pip(px2, by, k < u.cracks)
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
		var fx: Array = _intro_effects(side)
		var stats: Array = fx[0]
		var beh: Array = fx[1]
		# every chip keeps a label, one label style per row (critic r6: "Oren +40%" twice, two bare
		# chips): "Oren Heal +40%", else "Heal +40%"; when even that row is too wide, the costs move
		# down beside the behaviour glyph (gains on top). Labels are never dropped.
		var stat_row := _label_row(stats, tw)
		if stat_row.is_empty() and not stats.is_empty():
			var gains: Array = []
			var costs: Array = []
			for e: Dictionary in stats:
				(gains if int(e.get("sign", 1)) >= 0 else costs).append(e)
			var g_row := _label_row(gains, tw)
			var low := _label_row(costs + beh, tw)
			if not g_row.is_empty() and not low.is_empty():
				rows = [g_row, low]
			else:
				rows = [_label_row(stats, tw, true), _label_row(beh, tw, true)]
		else:
			rows = [stat_row, _label_row(beh, tw, true)]
		var kept: Array = []
		for row: Array in rows:
			if not row.is_empty():
				kept.append(row)
		rows = kept
		_intro_rows[side] = rows
		for row: Array in rows:
			for it: Array in row:
				var chip := EffectChip.new()
				box.add_child(chip)
				chip.setup(it[0], "below", int(it[1]))
				it.append(chip)
		box.visible = false


## One chip row with every label at the longest style that fits `tw` ("Oren Heal +40%", then
## "Heal +40%"), or [] when none does (with `force`, the shortest style regardless).
func _label_row(list: Array, tw: float, force := false) -> Array:
	if list.is_empty():
		return []
	for style in 2:
		var row: Array = []
		for e0: Dictionary in list:
			var e := e0.duplicate()
			if String(e.get("kind", "")) == "stat" and style == 1:
				e["title"] = String(e.get("short", e["title"]))
			row.append([e, _chip_label_w(String(e["title"]))])
		if _row_w(row) <= tw or (force and style == 1):
			return row
	return []


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
## The HUD rects world labels keep clear of (UI design px): the formation badges, the fragment
## banner, the lore caption, the Fading line, the caption slot (as drawn, or its one-line rect), the
## roster panels and the timer row. BattleFX's label solver treats them as walls.
func blocked_rects() -> Array:
	var out: Array = [badge_rect(0), badge_rect(1), top_band(), bottom_band()]
	# the caption and rosters as laid out now (pure layout: also right before their first draw)
	var cr: Rect2 = caption_layout().get("rect", Rect2())
	if cr.has_area():
		out.append(cr)
	for side in 2:
		var pr := panel_rect(side)
		if pr.has_area():
			out.append(pr)
	# banners carry a margin (critic r6: a "20" touched the lore banner's bottom rule)
	if frag_t <= FRAG_SHOW and frag_n > 0:
		out.append(fragment_rect().grow(BANNER_MARGIN))
	if b != null and b.crystal_uid >= 0:
		# a Crystal fight: a memory may surface over the top of the field at any break, and a number
		# placed before it surfaces lives on under it, so the tallest lore banner is always reserved
		out.append(lore_reserve())
	else:
		var lb := lore_bottom()
		if lb > 0.0:
			out.append(lore_rect().grow(BANNER_MARGIN))
	if b != null and b.sd_at > 0.0 and b.sim_t >= b.sd_at - 0.5:
		out.append(Rect2(_c - 160, 38, 320, 24).grow(BANNER_MARGIN))
	return out


## Clear space kept round every banner (UI design px), so no number touches its rule.
const BANNER_MARGIN := 4.0
## The lore banner is one line (critic r10 C3: two lines covered the back-row heads and left a
## widow): as wide as the view allows, and a line that still doesn't fit ends in an ellipsis.
const LORE_MAX_LINES := 1


func _lore_w() -> float:
	return minf(_vw - 24.0, 624.0)


func _lore_lines() -> PackedStringArray:
	var w := _lore_w() - 16.0
	if UIText.width(lore_text, BOLD, UIText.BODY) <= w:
		return PackedStringArray([lore_text])
	return PackedStringArray([UIText.fit(lore_text, w, BOLD, UIText.BODY)])


## The lore banner as drawn right now (UI design px), or an empty rect.
func lore_rect() -> Rect2:
	var lb := lore_bottom()
	return Rect2(_c - _lore_w() / 2.0, _vh - BOT_H + 2.0, _lore_w(), BOT_H - 4.0) if lb > 0.0 else Rect2()


## The tallest lore banner plus the margin: reserved for the whole of a Crystal fight.
func lore_reserve() -> Rect2:
	var n := LORE_MAX_LINES
	var h := ceilf(10.0 + UIText.ascent(SERIF, UIText.TITLE) + 6.0 + n * UIText.line_h(BOLD, UIText.BODY) + 6.0)
	# + the camera's travel: a world label placed now moves with the camera push and shake (up to
	# ~5 world px = 10 UI px) while the banner stays put
	return bottom_band()   # (round 17) the lore takes the caption's slot in the bottom band


const RESERVE_SLACK := 10.0
## The lore banner keeps a wider clear band under it (critic r11 fix 7: a "20" on the Crystal's top
## read as touching its bottom rule).
const LORE_MARGIN := 10.0


var caption_drawn := Rect2()
var panel_drawn: Array[Rect2] = [Rect2(), Rect2()]


func lore_bottom() -> float:
	if lore_t > 3.6 or lore_name == "":
		return -1.0
	var lines := _lore_lines()
	return 40.0 + ceilf(10.0 + UIText.ascent(SERIF, UIText.TITLE) + 6.0 + lines.size() * UIText.line_h(BOLD, UIText.BODY) + 6.0)


func _draw_lore() -> void:
	if lore_t > 3.6 or lore_name == "":
		return
	var a := clampf(lore_t / 0.25, 0.0, 1.0) * (1.0 - clampf((lore_t - 3.2) / 0.4, 0.0, 1.0))
	var lines := _lore_lines()
	var lh := UIText.line_h(BOLD, UIText.BODY)
	var h := ceilf(10.0 + UIText.ascent(SERIF, UIText.TITLE) + 6.0 + lines.size() * lh + 6.0)
	var r := lore_rect()
	draw_rect(r, Color(Pal.INK1, 0.92 * a))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Color(Pal.VIOLET3, a))
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color(Pal.VIOLET3, a))
	var y := r.position.y + 2.0
	UIText.outlined(self, Vector2(_c, y), lore_name, Color(Pal.VIOLET4, a), SERIF, UIText.TITLE, 1, Pal.INK1, false)
	y += UIText.ascent(SERIF, UIText.TITLE) + 1.0
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
	var band_h := roundf((BOT_H - 4.0) * inn)
	if band_h < 1.0:
		return
	var cy := roundf(_vh - BOT_H * 0.5)
	var bw := _cap_w
	var bx := _c - bw / 2.0
	var band := Rect2(bx, cy - band_h * 0.5, bw, band_h)
	draw_rect(band, Color(Pal.INK1, 0.92))
	draw_rect(Rect2(bx, band.position.y, bw, 1), sc)
	draw_rect(Rect2(bx, band.end.y - 1, bw, 1), sc)
	# speed lines
	for k in 9:
		var ly := band.position.y + 4.0 + fmod(k * 7.0, maxf(1.0, band_h - 8.0))
		# fposmod: a plain fmod went negative for the left team's cut-in and drew the lines across
		# the roster (critic r10: Unravel's red streaks through "Sable 116")
		var lx := bx + 4.0 + fposmod(t * 500.0 * -dir + k * 67.0, bw - 48.0)
		draw_rect(Rect2(roundf(lx), roundf(ly), 20 + (k % 3) * 8, 1), Color(sc, 0.35))
	if band_h < 24.0:
		return
	var tx := roundf(_c + dir * (1.0 - minf(1.0, cutin_t / 0.16)) * 60.0)
	# the hero's class names who is acting (an advanced class is the ability's identity, round 17)
	var who: String = u.class_name_.to_upper() if (u.class_name_ != "" and not u.is_monster and not u.is_memory and u.summon == "") else "ABILITY"
	UIText.outlined(self, Vector2(tx, cy - 13.0), u.label.to_upper() + "  ·  " + who, Pal.VIOLET4, BOLD, UIText.LABEL, 1, Pal.INK1, false)
	UIText.outlined(self, Vector2(tx, cy - 4.0), cutin_name, sc.lerp(Pal.INK10, 0.35), SERIF, UIText.HEADING, 1, Pal.INK1, false)
	if cutin_icon != "":
		# its effect icon on a chip before the name (effects as icons)
		var nw := UIText.width(cutin_name, SERIF, UIText.HEADING)
		var ip := Vector2(roundf(tx - nw * 0.5 - 16.0), roundf(cy - 4.0 + UIText.ascent(SERIF, UIText.HEADING) - UIText.cap(SERIF, UIText.HEADING) * 0.5 - 5.5))
		draw_rect(Rect2(ip, Vector2(11, 11)), Pal.INK1)
		draw_rect(Rect2(ip, Vector2(11, 11)), Pal.VIOLET3, false, 1.0)
		draw_texture(EffectIcons.icon(cutin_icon), ip + Vector2(1, 1), Pal.VIOLET4)


## The Fading (sudden death): one line in the game's voice, then a small rising readout.
func _draw_fading() -> void:
	var y := TOP_H - 13.0
	if fading_line_on():
		# in the caption's slot (bottom band), so the line never lies over the back row's heads
		var a := clampf(sd_banner_t / 0.3, 0.0, 1.0) * (1.0 - clampf((sd_banner_t - 2.8) / 0.4, 0.0, 1.0))
		var lw := UIText.width("The memory of this battle is fading…", SERIF, UIText.HEADING) + 20.0
		var lr := Rect2(roundf(_c - lw / 2.0), _vh - BOT_H + 3.0, roundf(lw), BOT_H - 6.0)
		draw_rect(lr, Color(Pal.INK1, 0.9 * a))
		draw_rect(Rect2(lr.position.x, lr.position.y, lr.size.x, 1), Color(Pal.FADE3, a))
		UIText.outlined(self, Vector2(_c, UIText.centered_y(lr.position.y, lr.size.y, SERIF, UIText.HEADING)), "The memory of this battle is fading…", Color(Pal.INK10, a), SERIF, UIText.HEADING, 1)
		return
	# readout under the banners once the line has gone
	var ro := fading_readout()
	if ro != "":
		UIText.outlined(self, Vector2(_c, y), ro, Pal.FADE4, BOLD, UIText.NUMBER, 1)


## The Fading's line ("The memory of this battle is fading…") is up.
func fading_line_on() -> bool:
	return fading_tick >= 1 and sd_banner_t < 3.2


## The Fading readout under the banners, or "": it follows the line and starts at the first real
## step (critic r11 fix 6: it showed "×1.00" before the line).
func fading_readout() -> String:
	if fading_tick < 1 or b.sd_mult <= 1.0 or fading_line_on() or end_t >= 0.0:
		return ""
	return "Fading  ×%.2f" % b.sd_mult


# --- finish -----------------------------------------------------------------------------------------
func _draw_end() -> void:
	if end_t < 0.0:
		return
	var win: bool = winner == b.player_side
	var col := Pal.AMBER6 if win else (Pal.FADE3 if winner == -1 else Pal.BLOOD4)
	# the band sits in the top band of the screen, over the formation badges, so the survivors
	# below it stay visible and unclipped while they celebrate (critic r10 fix 4). It is whole with
	# its text from its first frame (critic r11 fix 5: two empty black frames opened it).
	var h := 64.0
	var cy := 36.0
	draw_rect(Rect2(0, cy - h * 0.5, _vw, h), Color(Pal.INK1, 0.95))
	draw_rect(Rect2(0, cy - h * 0.5, _vw, 1), col)
	draw_rect(Rect2(0, cy + h * 0.5 - 1, _vw, 1), col)
	# the word settles in as one piece (critic r5: letters dropping one by one left a frame reading
	# "VICTᴼ", a raised letter that looked like a glyph bug)
	var word := winner_text
	var sz := UIText.DISPLAY
	var lt := clampf(end_t / 0.2, 0.0, 1.0)
	var dy := roundf((1.0 - lt) * (1.0 - lt) * -6.0)
	UIText.outlined(self, Vector2(_c, cy - 25.0 + dy), word, col, SERIF, sz, 1)
	var sub: String = b.end_subtitle
	var tn := team_name(winner) if winner >= 0 else ""
	var sy := cy + 13.0
	if tn != "" and sub.begins_with(tn):
		# the winning team's name in its side colour, as on its roster tab
		var rest := sub.substr(tn.length())
		var w1 := UIText.width(tn, BOLD, UIText.LABEL)
		var x := roundf(_c - (w1 + UIText.width(rest, BOLD, UIText.LABEL)) / 2.0)
		x = UIText.outlined(self, Vector2(x, sy), tn, Color(UIText.legible(b.side_colors[winner].lerp(Pal.INK10, 0.2))), BOLD, UIText.LABEL, 0, Pal.INK1, false)
		UIText.outlined(self, Vector2(x, sy), rest, Color(Pal.INK10), BOLD, UIText.LABEL, 0, Pal.INK1, false)
	else:
		UIText.outlined(self, Vector2(_c, sy), sub, Color(Pal.INK10), BOLD, UIText.LABEL, 1, Pal.INK1, false)


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
