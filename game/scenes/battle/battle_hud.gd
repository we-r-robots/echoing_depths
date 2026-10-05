extends Control
## Screen-space battle HUD (Sea of Stars style): party panels with portraits, HP and charge,
## formation badges with their buff and debuff, the fight timer with the sudden-death fuse,
## an action caption bar, the formation intro cards, the ability cut-in, the sudden-death
## banner, the victory/defeat finish, plus touch buttons for speed and skip.

signal speed_pressed
signal skip_pressed

const DIGITS = preload("res://assets/battle/digits.png")
const ICON_ABILITY = preload("res://assets/party/ability.png")
const CHARS := "0123456789+-:x"
const OUTLINE: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
const STAT_NAMES := {"hp_pct": "HP", "atk_pct": "ATK", "def_pct": "DEF", "mag_pct": "MAG", "spd_pct": "SPD",
	"crit_add": "CRIT", "charge_pct": "CHARGE", "heal_pct": "HEAL", "dmg_taken_pct": "DMG TAKEN"}
const PANEL_W := 182
const PANEL_Y := 284
const ROW_H := 14

var b: Node                    # battle controller
var font: Font
var font_bold: Font
var font_serif: Font
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
var _dig := PackedInt32Array()
var _tri := PackedVector2Array()


func setup(controller: Node) -> void:
	b = controller
	font = load("res://assets/fonts/depths_sans.fnt")
	font_bold = load("res://assets/fonts/depths_sans_bold.fnt")
	font_serif = load("res://assets/fonts/depths_serif.fnt")
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dig.resize(8)
	_tri.resize(3)
	row_flash.resize(16)
	speed_btn = _button("x1", Vector2(278, 336), speed_pressed)
	skip_btn = _button("SKIP", Vector2(324, 336), skip_pressed)


func _button(text: String, pos: Vector2, sig: Signal) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.position = pos
	bt.custom_minimum_size = Vector2(42, 20)
	bt.size = Vector2(42, 20)
	bt.focus_mode = Control.FOCUS_NONE
	bt.add_theme_font_size_override("font_size", 11)
	bt.pressed.connect(func() -> void: sig.emit())
	add_child(bt)
	return bt


func tick(vdt: float) -> void:
	t += vdt
	flash_a = maxf(0.0, flash_a - vdt * 5.0)
	fade_in = maxf(0.0, fade_in - vdt * 3.0)
	caption_t += vdt
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


func screen_flash(c: Color, a: float) -> void:
	flash_color = c
	flash_a = maxf(flash_a, a)


func show_caption(uid: int, text: String, target: int, is_ability: bool) -> void:
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
	_draw_sd_banner()
	_draw_end()
	if flash_a > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(flash_color, flash_a))
	_draw_fade()


func _draw_fade() -> void:
	if fade_in > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(Pal.INK1, minf(1.0, fade_in)))


func _draw_vignette() -> void:
	var a := doom * 0.35 + vignette * 0.5
	if a <= 0.01:
		return
	var c := Pal.BLOOD2
	for k in 4:
		var w := 6.0 + k * 6.0
		var ca := Color(c, a * (0.55 - k * 0.12))
		draw_rect(Rect2(0, 0, 640, w), ca)
		draw_rect(Rect2(0, 360 - w, 640, w), ca)
		draw_rect(Rect2(0, 0, w, 360), ca)
		draw_rect(Rect2(640 - w, 0, w, 360), ca)


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
	return Rect2(3 if side == 0 else 640 - 3 - w, 2, w, 26)


## [title, bonus, behaviour, cost] for the banner. A locked shape fights as Strays.
func _badge_parts(side: int) -> Array:
	var form: Dictionary = b.sides[side].get("formation", {})
	var bl: Array = form.get("buffs", [])
	var dl: Array = form.get("debuffs", [])
	var up := _stat_short(bl[0]) if not bl.is_empty() else ""
	if bl.size() > 1:
		up += " " + _stat_short(bl[1])
	var beh := String((form.get("behaviour", {}) as Dictionary).get("name", ""))
	var cost := _stat_short(dl[0]) if not dl.is_empty() else String(form.get("cost", ""))
	var title := String(form.get("name", "")).to_upper()
	if bool(form.get("locked", false)):
		title = String(form.get("shape_name", title)).to_upper()
		beh = "locked: fights as Strays"
		cost = ""
	return [title, up, beh, cost.trim_suffix(".")]


func _stat_short(m: Dictionary) -> String:
	var stat := String(m.get("stat", ""))
	return "%s%+d" % [STAT_NAMES.get(stat, stat.to_upper()), roundi(float(m.get("value", 0.0)) * 100.0)] + "%"


func _w2(t: String) -> float:
	return font_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 2.0


func _w1(t: String) -> float:
	return font_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x


## Two-line banner: NAME + bonus (2x), then behaviour and cost (1x bold). Max half the screen.
## One 2x line: NAME, then a field that rotates every 3 s between the bonus (green ▲), the
## behaviour (side colour ◆) and the cost (red ▼). A pulse shows the field that just fired.
func badge_width(side: int) -> float:
	var p := _badge_parts(side)
	var widest := 0.0
	for k in [1, 2, 3]:
		widest = maxf(widest, _w2(p[k]))
	return minf(314.0, 6.0 + _w2(p[0]) + 8.0 + 13.0 + widest + 6.0)


func _badge_field(side: int) -> int:
	var pulse: float = badge_pulse[side]
	if pulse > 0.0:
		match badge_line[side]:
			0: return 1
			1: return 3
			9: return 2
	var p := _badge_parts(side)
	var k := 1 + int(t / 3.0) % 3
	for i in 3:
		if p[k] != "":
			return k
		k = 1 + k % 3
	return 1


func _draw_badge(side: int, alpha: float) -> void:
	var r := badge_rect(side)
	var sc: Color = b.side_colors[side]
	var pulse: float = badge_pulse[side]
	_panel_bg(r, sc, alpha, pulse)
	var p := _badge_parts(side)
	var x := r.position.x + 6.0
	var y := r.position.y + 3.0
	_text_scaled_left(font_bold, p[0], Vector2(x, y), Color(sc.lerp(Pal.INK10, pulse * 0.7), alpha), 2)
	x += _w2(p[0]) + 8.0
	var f := _badge_field(side)
	var col: Color = [Pal.LIFE4, Pal.LIFE4, sc.lerp(Pal.INK10, 0.45), Pal.BLOOD4][f]
	var room := r.end.x - x - 19.0
	var txt := _fit2(p[f], room)
	if pulse > 0.0:
		draw_rect(Rect2(x - 3, r.position.y + 2, _w2(txt) + 18, 22), Color(col, 0.3 * pulse))
	if f == 1:
		_triangle2(Vector2(x, y + 7), true, Color(col, alpha))
	elif f == 3:
		_triangle2(Vector2(x, y + 7), false, Color(col, alpha))
	else:
		_tri[0] = Vector2(x + 5, y + 2); _tri[1] = Vector2(x + 10, y + 8); _tri[2] = Vector2(x + 5, y + 14)
		draw_colored_polygon(_tri, Color(col, alpha))
		_tri[1] = Vector2(x, y + 8)
		draw_colored_polygon(_tri, Color(col, alpha))
	_text_scaled_left(font_bold, txt, Vector2(x + 13, y), Color(col, alpha), 2)


func _fit2(t: String, w: float) -> String:
	if _w2(t) <= w:
		return t
	while t.length() > 1 and _w2(t + "...") > w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "..."


func _triangle2(p: Vector2, up: bool, c: Color) -> void:
	if up:
		_tri[0] = p + Vector2(0, 8); _tri[1] = p + Vector2(10, 8); _tri[2] = p + Vector2(5, 0)
	else:
		_tri[0] = p; _tri[1] = p + Vector2(10, 0); _tri[2] = p + Vector2(5, 8)
	draw_colored_polygon(_tri, c)


func _text_scaled_left(f: Font, s: String, top_left: Vector2, c: Color, sc: int) -> void:
	var fs := 16 if f == font_serif else 11
	draw_set_transform(top_left + Vector2(0, 8 * sc), 0.0, Vector2(sc, sc))
	var oc := Color(Pal.INK1, c.a)
	for d: Vector2 in OUTLINE:
		draw_string(f, d * (1.0 / sc), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, oc)
	draw_string(f, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_badge_at(side: int, r: Rect2, alpha: float) -> void:
	var sc: Color = b.side_colors[side]
	var pulse: float = badge_pulse[side]
	var sd: Dictionary = b.sides[side]
	var form: Dictionary = sd.get("formation", {})
	_panel_bg(r, sc, alpha, pulse)
	var left := side == 0
	var x_in := r.position.x + 6.0
	var x_right := r.end.x - 6.0
	# side name
	var nm := String(sd.get("name", "")).to_upper()
	_text(font, nm, Vector2(x_in if left else x_right, r.position.y + 10), Color(Pal.INK8, alpha), 0 if left else 2)
	# mini grid
	var gx := x_in if left else x_right - 9.0
	var gy := r.position.y + 14.0
	_mini_grid(side, Vector2(gx, gy), 4, 3, alpha, sc)
	# formation name
	var fname := String(form.get("name", "Loose Ranks"))
	var fx := gx + 13.0 if left else gx - 4.0
	var name_col := sc.lerp(Pal.INK10, pulse * 0.8)
	_text(font_serif, fname, Vector2(fx, r.position.y + 26), Color(name_col, alpha), 0 if left else 2)
	# buff / debuff lines
	var lines: Array = b.form_lines[side]
	for i in lines.size():
		var ln: Array = lines[i]
		var y := r.position.y + 37.0 + i * 9.0
		var good: bool = ln[0]
		var c := Pal.LIFE4 if good else Pal.BLOOD4
		if ln.size() > 2:
			c = Pal.CRYSTAL4
		var hl: bool = badge_line[side] == i and pulse > 0.0
		if hl:
			draw_rect(Rect2(r.position.x + 2, y - 7, r.size.x - 4, 9), Color(c, 0.25 * pulse * alpha))
		var tx := x_in + 8.0 if left else x_right - 8.0
		var ix := x_in + 2.0 if left else x_right - 3.0
		if ln.size() > 2:
			_text(font, "+", Vector2(ix - 2.0, y), Color(c, alpha), 0)
		else:
			_triangle(Vector2(ix, y - 3), good, Color(c, alpha))
		_text(font, ln[1], Vector2(tx, y), Color(c.lerp(Pal.INK10, 0.6 * pulse if hl else 0.0), alpha), 0 if left else 2)


func _panel_bg(r: Rect2, sc: Color, alpha: float, pulse := 0.0) -> void:
	draw_rect(r, Color(Pal.INK1, 0.82 * alpha))
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(Pal.INK2, 0.75 * alpha))
	var bc := Pal.INK5.lerp(sc, 0.3 + 0.7 * pulse)
	draw_rect(r, Color(bc, alpha), false, 1.0)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Color(sc, alpha * (0.7 + 0.3 * pulse)))


func _triangle(p: Vector2, up: bool, c: Color) -> void:
	if up:
		_tri[0] = p + Vector2(0, 4)
		_tri[1] = p + Vector2(5, 4)
		_tri[2] = p + Vector2(2.5, 0)
	else:
		_tri[0] = p
		_tri[1] = p + Vector2(5, 0)
		_tri[2] = p + Vector2(2.5, 4)
	draw_colored_polygon(_tri, c)


func _mini_grid(side: int, p: Vector2, cw: int, ch: int, alpha: float, sc: Color) -> void:
	var occ: Dictionary = b.stage.occupied[side]
	for col in 2:
		for row in 4:
			# left side: back column on the left; right side: back column on the right
			var vx := (1 - col) if side == 0 else col
			var rr := Rect2(p.x + vx * (cw + 1), p.y + row * (ch + 1), cw, ch)
			if occ.has(Vector2i(col, row)):
				var alive: bool = b.stage.alive_cells[side].has(Vector2i(col, row))
				draw_rect(rr, Color(sc if alive else Pal.FADE2, alpha))
			else:
				draw_rect(rr, Color(Pal.INK4, alpha))


# --- timer ------------------------------------------------------------------------------------
func _draw_timer() -> void:
	var st: float = b.sim_t
	var secs := int(st)
	var r := Rect2(222, 334, 52, 24)
	var sd: bool = st >= b.sd_at and b.sd_at > 0.0
	_panel_bg(r, Pal.BLOOD3 if sd else Pal.INK7, 1.0, 0.0)
	@warning_ignore("integer_division")
	var mins := secs / 60
	var s2 := secs % 60
	var row := 4 if sd else 5
	var x := 233.0
	_glyph(mins % 10, row, x, 336)
	_glyph(12, row, x + 7, 336)
	@warning_ignore("integer_division")
	_glyph(s2 / 10, row, x + 14, 336)
	_glyph(s2 % 10, row, x + 22, 336)
	# sudden-death fuse
	var fx := 225.0
	var fw := 46.0
	var frac := clampf(st / maxf(1.0, b.sd_at), 0.0, 1.0)
	draw_rect(Rect2(fx, 352, fw, 2), Pal.INK4)
	draw_rect(Rect2(fx, 352, roundf(fw * frac), 2), Pal.BLOOD3 if frac > 0.75 else Pal.AMBER5)
	if false:
		var on := fmod(t, 0.5) < 0.32
		var lbl := "SUDDEN DEATH  DMG x%.2f" % b.sd_mult
		_text_scaled(font_bold, lbl, Vector2(320, 32), Pal.BLOOD4 if on else Pal.BLOOD3, 2)
	elif frac > 0.0:
		pass


# --- caption bar ------------------------------------------------------------------------------
func _draw_caption() -> void:
	if caption_uid < 0 or end_t >= 0.0 or cutin_t < cutin_hold:
		return
	var a := 1.0
	var u = b.units[caption_uid]
	var sc: Color = b.side_colors[u.side]
	var r := Rect2(188, 292, 264, 28)
	_panel_bg(r, sc, a)
	var tgt := ""
	if caption_target >= 0:
		tgt = b.units[caption_target].label
	var who: String = u.label
	var line: String = who + "  " + caption_text
	if _w2(line) + (_w2(tgt) + 22.0 if tgt != "" else 0.0) > 248.0:
		tgt = ""   # too long: keep the full actor name and action, drop the target
	var k := 1.0
	var w := _w2(line) + (_w2(tgt) + 22.0 if tgt != "" else 0.0)
	if w > 256.0:
		tgt = ""   # one caption size always: drop the target name rather than shrink
		w = _w2(line)
	var ts := 2 if k == 1.0 else 1
	var ty := 296.0 if ts == 2 else 303.0
	var x := roundf(320.0 - w * 0.5)
	_text_scaled_left(font_bold, line, Vector2(x, ty), Color(sc.lerp(Pal.INK10, 0.4), a), ts)
	if tgt != "":
		x += _w2(line) * k + 5.0
		_tri[0] = Vector2(x, 302); _tri[1] = Vector2(x + 6, 306); _tri[2] = Vector2(x, 310)
		draw_colored_polygon(_tri, Color(Pal.INK8, a))
		var tc: Color = b.side_colors[b.units[caption_target].side]
		_text_scaled_left(font_bold, tgt, Vector2(x + 10, ty), Color(tc.lerp(Pal.INK10, 0.4), a), ts)


func _chevron(p: Vector2, c: Color) -> void:
	_tri[0] = p
	_tri[1] = p + Vector2(4, 2.5)
	_tri[2] = p + Vector2(0, 5)
	draw_colored_polygon(_tri, c)


# --- party panels -----------------------------------------------------------------------------
func _draw_panel(side: int) -> void:
	var ids: Array = b.side_units[side]
	var n := ids.size()
	if n == 0:
		return
	var h := 6.0 + n * ROW_H
	var x0 := 4.0 if side == 0 else 640.0 - 4.0 - PANEL_W
	var y0 := 358.0 - h
	var r := Rect2(x0, y0, PANEL_W, h)
	_panel_bg(r, b.side_colors[side], 0.95)
	for i in n:
		_draw_row(side, b.units[ids[i]], Vector2(x0, y0 + 3 + i * ROW_H))


func _draw_row(side: int, u, p: Vector2) -> void:
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
	draw_rect(Rect2(px - 1, p.y, 18, 15), Pal.INK1)
	draw_rect(Rect2(px, p.y + 1, 16, 13), Pal.INK3)
	if tex != null:
		var m := Color(1, 1, 1, 1) if u.alive else Color(0.45, 0.45, 0.55, 1)
		draw_texture_rect(tex, Rect2(px, p.y + 1, 16, 13), false, m)
	draw_rect(Rect2(px - 1, p.y, 18, 15), (sc if acting else Pal.INK5), false, 1.0)
	var tx := px + 21.0 if left else px - 4.0
	var bar_x := tx if left else tx - 112.0
	var name_col := Pal.INK10 if u.alive else Pal.FADE2
	_text(font_bold, u.label, Vector2(tx, p.y + 7), name_col if not acting else sc.lerp(Pal.INK10, 0.5), 0 if left else 2)
	# HP number on the far side of the name
	var num_x := p.x + PANEL_W - 6.0 if left else p.x + 6.0
	if u.alive:
		var hpv := roundi(u.hp_shown)
		var hc := Pal.INK10 if hpv * 4 > u.max_hp else Pal.BLOOD4
		_text(font_bold, str(hpv), Vector2(num_x, p.y + 7), hc, 2 if left else 0)
	else:
		_text(font_bold, "KO", Vector2(num_x, p.y + 7), Pal.BLOOD3, 2 if left else 0)
	var bw := 112.0
	if not u.alive:
		draw_rect(Rect2(bar_x, p.y + 11.0, bw, 1), Pal.INK4)
		return
	# HP bar
	var frac: float = clampf(u.hp_shown / float(u.max_hp), 0.0, 1.0)
	var chip: float = clampf(u.hp_chip / float(u.max_hp), 0.0, 1.0)
	var by := p.y + 9.0
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
func _draw_intro() -> void:
	var it := intro_t
	var fade := 1.0 - clampf((it - (intro_len - 0.35)) / 0.3, 0.0, 1.0)
	for side in 2:
		var a := clampf((it - 0.15 - side * 0.15) / 0.2, 0.0, 1.0) * fade
		if a <= 0.0:
			continue
		var sc: Color = b.side_colors[side]
		var form: Dictionary = b.sides[side].get("formation", {})
		var beh: Dictionary = form.get("behaviour", {})
		var r := Rect2(6 if side == 0 else 334, 6, 300, 108)
		_panel_bg(r, sc, a, 0.5)
		var cx := r.get_center().x
		var p := _badge_parts(side)
		_text_scaled(font_serif, p[0], Vector2(cx, 30), Color(sc.lerp(Pal.INK10, 0.35), a), 2)
		var l1: String = ("+ " + p[1]) if p[1] != "" else ""
		_text(font_bold, l1, Vector2(cx, 74), Color(Pal.LIFE4, a), 1, true)
		var bt := String(beh.get("name", "")) + ": " + String(beh.get("text", ""))
		if bool(form.get("locked", false)):
			bt = "Locked: fights as Strays (no shape behaviour)"
		var lines := _wrap(bt, 286.0)
		for i in lines.size():
			_text(font_bold, lines[i], Vector2(cx, 87 + i * 10), Color(sc.lerp(Pal.INK10, 0.5), a), 1, true)
		if not bool(form.get("locked", false)):
			_text(font_bold, "Cost: " + String(form.get("cost", "")), Vector2(cx, 87 + lines.size() * 10 + 2), Color(Pal.BLOOD4, a), 1, true)


func _wrap(t: String, w: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in t.split(" "):
		var nxt := word if cur == "" else cur + " " + word
		if _w1(nxt) > w and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = nxt
	if cur != "":
		out.append(cur)
	return out


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
	var band := Rect2(194, cy - band_h * 0.5, 252, band_h)
	draw_rect(band, Color(Pal.INK1, 0.92))
	draw_rect(Rect2(194, band.position.y, 252, 1), sc)
	draw_rect(Rect2(194, band.end.y - 1, 252, 1), sc)
	# speed lines
	for k in 9:
		var ly := band.position.y + 4.0 + fmod(k * 7.0, maxf(1.0, band_h - 8.0))
		var lx := 194.0 + fmod(t * 500.0 * -dir + k * 67.0, 212.0)
		draw_rect(Rect2(roundf(lx), roundf(ly), 20 + (k % 3) * 8, 1), Color(sc, 0.35))
	if band_h < 30.0:
		return
	var tx := roundf(320.0 + dir * (1.0 - minf(1.0, cutin_t / 0.16)) * 60.0)
	_text(font_bold, u.label.to_upper() + "  -  ABILITY!", Vector2(tx, cy - 6), Pal.VIOLET4, 1, true)
	_text_scaled(font_serif, cutin_name, Vector2(tx, cy + 13), sc.lerp(Pal.INK10, 0.35), 2)


# --- sudden death ---------------------------------------------------------------------------------
func _draw_sd_banner() -> void:
	pass


## The Fading (sudden death): one line in the game's voice, then a small rising readout.
func _draw_fading() -> void:
	if sd_banner_t < 3.2:
		var a := clampf(sd_banner_t / 0.3, 0.0, 1.0) * (1.0 - clampf((sd_banner_t - 2.8) / 0.4, 0.0, 1.0))
		_text_scaled(font_serif, "The memory of this battle is fading...", Vector2(320, 52), Color(Pal.INK10, a), 2)
	# readout: a fading-eye glyph and the multiplier, under the badges once the line has gone
	if sd_banner_t < 3.2:
		return
	_text_scaled(font_serif, "Fading  x%.2f" % b.sd_mult, Vector2(320, 52), Pal.INK10, 2)


# --- finish -----------------------------------------------------------------------------------------
func _draw_end() -> void:
	if end_t < 0.0:
		return
	var a := clampf(end_t / 0.3, 0.0, 1.0)
	var win: bool = winner == b.player_side
	var col := Pal.AMBER6 if win else (Pal.FADE3 if winner == -1 else Pal.BLOOD4)
	var h := 64.0 * a
	var cy := 150.0
	draw_rect(Rect2(0, cy - h * 0.5, 640, h), Color(Pal.INK1, 0.85))
	draw_rect(Rect2(0, cy - h * 0.5, 640, 1), Color(col, a))
	draw_rect(Rect2(0, cy + h * 0.5 - 1, 640, 1), Color(col, a))
	if h < 60.0:
		return
	# letters drop in one by one
	var word := winner_text
	var sc := 3
	var total_w := font_serif.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * sc
	var x := roundf(320.0 - total_w * 0.5)
	for i in word.length():
		var ch := word.substr(i, 1)
		var lt := clampf((end_t - 0.15 - i * 0.06) / 0.18, 0.0, 1.0)
		if lt <= 0.0:
			x += font_serif.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * sc
			continue
		var dy := roundf((1.0 - (1.0 - pow(1.0 - lt, 2.0))) * -30.0)
		var bounce := roundf(sin(clampf((end_t - 0.33 - i * 0.06) / 0.2, 0.0, 1.0) * PI) * -3.0)
		draw_set_transform(Vector2(x, cy + 8 + dy + bounce), 0.0, Vector2(sc, sc))
		for d: Vector2 in OUTLINE:
			draw_string(font_serif, d * 0.34, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.INK1)
		draw_string(font_serif, Vector2.ZERO, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += font_serif.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * sc
	if end_t > 0.8:
		var sub_a := clampf((end_t - 0.8) / 0.3, 0.0, 1.0)
		_text(font_bold, b.end_subtitle, Vector2(320, cy + 26), Color(Pal.INK10, sub_a), 1, true)


# --- text helpers -------------------------------------------------------------------------------------
## Draws text with an ink outline. align: 0 left, 1 centre, 2 right (pos.x is that edge). Returns end x.
func _text(f: Font, s: String, pos: Vector2, c: Color, align: int, outline := false) -> float:
	var fs := 16 if f == font_serif else 11
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := pos.x
	if align == 1:
		x -= w * 0.5
	elif align == 2:
		x -= w
	var p := Vector2(roundf(x), roundf(pos.y))
	if outline:
		var oc := Color(Pal.INK1, c.a)
		for d: Vector2 in OUTLINE:
			draw_string(f, p + d, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, oc)
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return p.x + w


func _text_scaled(f: Font, s: String, center: Vector2, c: Color, sc: int) -> void:
	var fs := 16 if f == font_serif else 11
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(roundf(center.x - w * sc * 0.5), roundf(center.y))
	draw_set_transform(p, 0.0, Vector2(sc, sc))
	var oc := Color(Pal.INK1, c.a)
	for d: Vector2 in OUTLINE:
		draw_string(f, d * (1.0 / sc) * 1.0, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, oc)
	draw_string(f, Vector2(0, 1.0 / sc) * 2.0, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.INK1, c.a))
	draw_string(f, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _glyph(idx: int, row: int, x: float, y: float) -> void:
	draw_texture_rect_region(DIGITS, Rect2(x, y, 10, 13), Rect2(idx * 10, row * 13, 10, 13))
