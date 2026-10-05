class_name DraftCard
extends Control
## One offered hero in the starting draft: animated sprite on a lit stage, name, class, the
## class's fixed starting alignment (mini grid + words), base stats, the basic action and the
## ability. The whole card is the tap target (toggle pick).

signal tapped

const STAT_COLORS := HeroCard.STAT_COLORS
const ABILITY := preload("res://assets/party/ability.png")
const TICK := preload("res://assets/party/tick.png")
const GameData = preload("res://core/game_data.gd")

var hero: Dictionary = {}       # {name, class, alignment}
var info: Dictionary = {}
var pick := 0                   # 0 not picked, 1 first pick, 2 second pick
var dimmed := false             # both picks made and this one is not among them
var w := 190
var h := 290
var _sprite: AnimatedSprite2D
var _clip: Control
var _over: Control
var _t := 0.0
var _lift := 0.0
var _flash := 0.0
var _motes: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2(2, 2)
	_clip.add_child(_sprite)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 10:
		_motes.append(Vector3(rng.randi_range(4, 170), rng.randf(), rng.randf_range(0.12, 0.3)))


func setup(hd: Dictionary, width: int, height: int, phase := 0) -> void:
	hero = hd
	w = width
	h = height
	size = Vector2(w, h)
	custom_minimum_size = size
	var base := String(hd["class"])
	info = EncounterDB.class_info(base)
	_clip.position = _stage().position + Vector2(1, 1)
	_clip.size = _stage().size - Vector2(2, 2)
	var frames := HeroCard._frames_for(base)
	if frames:
		_sprite.sprite_frames = frames
		_sprite.play(&"idle")
		_sprite.frame = phase % maxi(1, frames.get_frame_count(&"idle"))
		# feet (origin 32,60 at 1x) on the stage floor, centred
		_sprite.position = Vector2(roundi(_clip.size.x / 2.0) - 64, _clip.size.y - 12 - 120)
	queue_redraw()


func set_pick(p: int, dim: bool) -> void:
	if p != pick and p > 0:
		_flash = 1.0
	pick = p
	dimmed = dim
	var m := Color(0.5, 0.5, 0.6) if dim else Color.WHITE
	_clip.modulate = m
	queue_redraw()


func _stage() -> Rect2:
	return Rect2(6, 6, w - 12, 100)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not (event as InputEventMouseButton).pressed:
		tapped.emit()
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.0)
	var goal := -4.0 if pick > 0 else 0.0
	_lift = lerpf(_lift, goal, 1.0 - exp(-delta * 14.0))
	position.y = roundf(_base_y + _lift)
	_sprite.speed_scale = 0.4 if dimmed else 1.0
	queue_redraw()
	_over.queue_redraw()


var _base_y := 0.0


func set_base_y(y: float) -> void:
	_base_y = y
	position.y = y


func _draw() -> void:
	if hero.is_empty():
		return
	var cc := Pal.c(info["color"])
	var r := Rect2(0, 0, w, h)
	PartyDraw.panel(self, r, 0, &"PanelContainer" if not dimmed else &"DimPanel")
	_draw_stage(cc)
	var x := 8
	# name + class
	PartyDraw.text(self, Vector2(x, 106), String(hero.get("name", "?")), Pal.AMBER6 if not dimmed else Pal.INK8, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	PartyDraw.tint_tex(self, PartyDraw.icon(info["icon"]), Vector2(x, 126), cc)
	var cls := PartyModel.class_name_of(String(hero["class"]))
	PartyDraw.text(self, Vector2(x + 10, 124), cls, cc, PartyDraw.BOLD)
	var cdef := GameData.get_class_def(String(hero["class"]))
	var pref := "Front" if int(cdef.get("preferred_col", 0)) == 0 else "Back"
	var lv := "Lv 1"
	PartyDraw.text(self, Vector2(0, 109), lv, Pal.INK8, PartyDraw.BOLD, 11, true, w - 9, HORIZONTAL_ALIGNMENT_RIGHT)
	PartyDraw.text(self, Vector2(0, 124), "fights " + pref.to_lower(), Pal.AMBER5 if pref == "Front" else Pal.CRYSTAL4, PartyDraw.BOLD, 11, true, w - 9, HORIZONTAL_ALIGNMENT_RIGHT)
	# alignment: the fixed start, in words (no unexplained grid on screen one)
	var a: Array = hero.get("alignment", [0, 0])
	var narrow := w < 170
	PartyDraw.text(self, Vector2(8, 140), "ALIGNMENT", Pal.INK7, PartyDraw.BOLD, 11, false)
	var ey := 151
	if narrow:
		PartyDraw.text(self, Vector2(8, 151), _align_words(a), Pal.INK10, PartyDraw.BOLD)
		ey = 162
	else:
		PartyDraw.text(self, Vector2(14 + PartyDraw.text_w("ALIGNMENT", PartyDraw.BOLD), 140), _align_words(a), Pal.INK10, PartyDraw.BOLD)
	var expl := "Choices shift it; it sets the advanced class." if narrow else "Your choices shift it, and it sets the advanced class."
	var ay := _para(expl, Vector2(8, ey), w - 16, Pal.INK8)
	# stats, labelled
	var st := PartyModel.stats({"class": hero["class"], "level": 1, "items": {}})
	var sy := ay + 3
	var cw := floori((w - 16) / 5.0)
	var sx := 8
	for s: String in ["hp", "atk", "def", "mag", "spd"]:
		var well := Rect2(sx, sy, cw - 2, 24)
		PartyDraw.inset(self, well)
		draw_rect(Rect2(well.position.x + 1, well.position.y, well.size.x - 2, 1), STAT_COLORS[s])
		PartyDraw.text(self, Vector2(sx, sy + 1), PartyModel.STAT_LABELS[s], STAT_COLORS[s], PartyDraw.SANS, 11, true, cw - 2, HORIZONTAL_ALIGNMENT_CENTER)
		PartyDraw.text(self, Vector2(sx, sy + 12), str(st[s]), Pal.INK10, PartyDraw.BOLD, 11, true, cw - 2, HORIZONTAL_ALIGNMENT_CENTER)
		sx += cw
	# basic + ability
	var basic := GameData.get_action(String(cdef.get("basic", "")))
	var ab := PartyModel.ability_of(String(hero["class"]))
	var y := sy + 30
	y = _action(y, "Basic", basic, Pal.INK8, false)
	y = _action(y + 3, "Ability", ab, cc, true)

	if dimmed:
		var d := Pal.INK1
		d.a = 0.45
		draw_rect(r.grow(-2), d)
	if pick > 0:
		PartyDraw.soft_outline(self, r, Pal.AMBER5)
		PartyDraw.soft_outline(self, r.grow(-1), Pal.AMBER3)
		if _flash > 0.0:
			var f := Pal.AMBER7
			f.a = _flash
			PartyDraw.soft_outline(self, r.grow(roundi((1.0 - _flash) * 3.0)), f)


func _action(y: int, label: String, a: Dictionary, color: Color, is_ability: bool) -> int:
	var lab := label.to_upper()
	PartyDraw.text(self, Vector2(8, y), lab, Pal.INK7, PartyDraw.BOLD, 11, false)
	var nx := 12 + PartyDraw.text_w(lab, PartyDraw.BOLD)
	if is_ability:
		PartyDraw.tint_tex(self, ABILITY, Vector2(nx, y + 2), color)
		nx += 10
	var nm := String(a.get("name", "—"))
	PartyDraw.text(self, Vector2(nx, y), nm, Pal.INK10, PartyDraw.BOLD)
	var rx := nx + PartyDraw.text_w(nm, PartyDraw.BOLD) + 4
	var ry := y + 5
	draw_rect(Rect2(rx, ry, w - 8 - rx, 1), Pal.INK4)
	if is_ability and w >= 170:
		var tag := "when charged"
		var tw := PartyDraw.text_w(tag) + 4
		draw_rect(Rect2(w - 9 - tw, y, tw + 1, 11), Pal.INK2 if not dimmed else Pal.INK1)
		PartyDraw.text(self, Vector2(0, y), tag, Pal.INK6, PartyDraw.SANS, 11, true, w - 9, HORIZONTAL_ALIGNMENT_RIGHT)
	y += 12
	if not is_ability:
		if w < 170:
			return y - 1
		return _para(PartyModel.ability_desc(a), Vector2(8, y), w - 16, Pal.INK8 if not dimmed else Pal.INK7)
	return _para(PartyModel.ability_desc(a), Vector2(8, y), w - 16, Pal.INK9 if not dimmed else Pal.INK7,
		PartyDraw.BOLD if w >= 170 else PartyDraw.SANS)


## Pick ribbon across the foot of the stage.
func _draw_over() -> void:
	_over.size = size
	if pick <= 0:
		return
	var b := Rect2(_stage().end.x - 17, _stage().position.y + 3, 14, 14)
	_over.draw_rect(b, Pal.AMBER2)
	PartyDraw.soft_outline(_over, b, Pal.AMBER5)
	PartyDraw.text(_over, b.position + Vector2(0, 1), str(pick), Pal.AMBER7, PartyDraw.BOLD, 11, false, 14, HORIZONTAL_ALIGNMENT_CENTER)
	var st := _stage()
	var fr := Rect2(st.position.x + 1, st.end.y - 16, st.size.x - 2, 14)
	_over.draw_rect(fr, Pal.AMBER1)
	_over.draw_rect(Rect2(fr.position.x, fr.position.y, fr.size.x, 1), Pal.AMBER4)
	var t := "%s pick" % ("First" if pick == 1 else "Second")
	var tw := PartyDraw.text_w(t, PartyDraw.BOLD) + 11
	var tx := fr.position.x + roundi((fr.size.x - tw) / 2.0)
	_over.draw_texture(TICK, Vector2(tx, fr.position.y + 5), Pal.AMBER6)
	PartyDraw.text(_over, Vector2(tx + 11, fr.position.y + 2), t, Pal.AMBER6, PartyDraw.BOLD)


func _draw_stage(cc: Color) -> void:
	var r := _stage()
	draw_rect(r, Pal.INK1)
	var inner := r.grow(-1)
	var bands := [Pal.INK2, Pal.INK2, Pal.INK3, Pal.INK3, Pal.INK4]
	var bh := inner.size.y / bands.size()
	for i in bands.size():
		draw_rect(Rect2(inner.position.x, inner.position.y + roundi(i * bh), inner.size.x, ceili(bh)), bands[i])
	var cx := inner.position.x + roundi(inner.size.x / 2.0)
	# arched alcove behind the hero
	var arch_top := inner.position.y + 8
	for y in range(0, 60):
		var half := 24
		if y < 24:
			half = int(sqrt(maxf(0.0, 576.0 - pow(24.0 - y, 2))))
		draw_rect(Rect2(cx - half, arch_top + y, half * 2, 1), Pal.INK3 if y < 34 else Pal.INK4)
		if half > 0:
			draw_rect(Rect2(cx - half - 1, arch_top + y, 1, 1), Pal.INK5)
			draw_rect(Rect2(cx + half, arch_top + y, 1, 1), Pal.INK5)
	# floor and lit pool in the class colour's warmth
	var fy := inner.end.y - 13
	draw_rect(Rect2(inner.position.x, fy, inner.size.x, inner.end.y - fy), Pal.INK3)
	draw_rect(Rect2(inner.position.x, fy, inner.size.x, 1), Pal.INK5)
	for i in 5:
		var hw := 36 - i * 6
		draw_rect(Rect2(cx - hw, fy + 2 + i, hw * 2, 1), [Pal.INK4, Pal.INK4, Pal.INK5, Pal.INK5, Pal.INK6][i])
	draw_rect(Rect2(cx - 16, fy + 3, 32, 4), Pal.INK2)
	# drifting motes
	if not dimmed:
		for m: Vector3 in _motes:
			if m.x > inner.size.x - 4:
				continue
			var ph := fmod(m.y + _t * m.z, 1.0)
			var y := inner.end.y - 14 - ph * (inner.size.y - 18)
			var x := inner.position.x + m.x + roundf(sin(_t * 1.3 + m.y * 9.0))
			draw_rect(Rect2(Vector2(x, y).round(), Vector2(1, 1)), Pal.AMBER5 if ph < 0.7 else Pal.AMBER3)
	PartyDraw.soft_outline(self, r, Pal.INK5)
	draw_rect(Rect2(r.position.x + 1, r.end.y - 2, r.size.x - 2, 1), cc)
	# class corner tag
	var tg := Rect2(r.position.x + 3, r.position.y + 3, 13, 13)
	draw_rect(tg, Pal.INK1)
	PartyDraw.soft_outline(self, tg, cc)
	draw_texture(PartyDraw.icon(info["icon"]), tg.position + Vector2(3, 3), cc)


static func _align_words(a: Array) -> String:
	var g := int(a[0])
	var l := int(a[1])
	var parts: Array = []
	if l != 0:
		parts.append(("Far " if absi(l) == 2 else "") + PartyModel.axis_word("law", l))
	if g != 0:
		parts.append(("Far " if absi(g) == 2 else "") + PartyModel.axis_word("good", g))
	if parts.is_empty():
		return "Neutral"
	return " · ".join(parts)


func _para(s: String, pos: Vector2, width: int, color: Color, font: Font = PartyDraw.SANS) -> int:
	var words := s.split(" ")
	var line := ""
	var y := int(pos.y)
	for wd in words:
		var trial := wd if line == "" else line + " " + wd
		if PartyDraw.text_w(trial, font) > width and line != "":
			PartyDraw.text(self, Vector2(pos.x, y), line, color, font)
			y += 11
			line = wd
		else:
			line = trial
	if line != "":
		PartyDraw.text(self, Vector2(pos.x, y), line, color, font)
		y += 11
	return y
