class_name DraftCard
extends Control
## One offered hero in the starting draft. The hero first (3x sprite on a lit stage, name, class),
## then the fixed starting alignment in one line, labelled base stats, and one line each for the
## basic action and the ability (tap either for the full text in the shared Tip). The rest of the
## card is the tap target (toggle pick).

signal tapped

const STAT_COLORS := HeroCard.STAT_COLORS
const ABILITY := preload("res://assets/party/ability.png")
const TICK := preload("res://assets/party/tick.png")
const START := preload("res://assets/party/start.png")
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
var _rows: Array = []

const NAME_Y := 150
const NAME_SIZE := 20               # serif, one size step above the card's other text
const CLASS_Y := 179
const STATS_Y := 197
## Tooltip rows: [basic, ability] (the ability reads first, the basic attack is one quiet line).
const ROW_RECT := [Rect2(4, 268, 0, 16), Rect2(4, 228, 0, 36)]
var _class_tip: Control
var _tag_tip: Control
## One short plain line per base action, and the full plain sentence for its tooltip.
const ACTION_SHORT := {
	"strike": "Hits the front foe", "stab": "A quick hit, front foe", "smite": "Holy hit, front foe",
	"bolt": "Shoots the back row", "cleave": "Front foe and its sides", "backstab": "Huge hit on the weakest",
	"mend": "Heals the weakest ally", "firestorm": "Burns every foe",
}
const ACTION_FULL := {
	"strike": "Hits the foe in front for 100% physical damage.",
	"stab": "A quick hit on the foe in front for 90% physical damage.",
	"smite": "A holy hit on the foe in front for 70% magic damage.",
	"bolt": "Shoots the back row first for 80% magic damage.",
	"cleave": "Hits the foe in front for 190% physical damage and the foes beside it for 80%.",
	"backstab": "Dashes to the weakest foe and hits it for 320% physical damage.",
	"mend": "Heals the weakest ally (220% power), then hits the foe in front for 90% magic damage.",
	"firestorm": "Burns the back row first for 160% magic damage and every other foe for 70%.",
}


static func action_short(id: String) -> String:
	return String(ACTION_SHORT.get(id, PartyModel.ability_desc(GameData.get_action(id)).trim_suffix(".")))


static func action_full(id: String) -> String:
	return String(ACTION_FULL.get(id, PartyModel.ability_desc(GameData.get_action(id))))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2(3, 3)
	_clip.add_child(_sprite)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 10:
		_motes.append(Vector3(rng.randi_range(4, 132), rng.randf(), rng.randf_range(0.12, 0.3)))


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
		# feet (origin 32,60 at 1x) on the stage floor, centred, at 3x
		_sprite.position = Vector2(roundi(_clip.size.x / 2.0) - 96, _clip.size.y - 8 - 180)
	var cdef := GameData.get_class_def(base)
	# the class line and the class glyph on the stage: where the class fights and its starting
	# alignment (hit areas at least 16 design px = 48 screen px at 1080p)
	var pref := "the front row" if int(cdef.get("preferred_col", 0)) == 0 else "the back row"
	var ctext := "Fights best from %s. Starts at %s on the alignment grid; your choices move it." % [
		pref, _align_words(hd.get("alignment", [0, 0]))]
	var ccol := Pal.c(info["color"])
	_class_tip = Control.new()
	_class_tip.position = Vector2(4, CLASS_Y - 2)
	_class_tip.size = Vector2(w - 8, 16)
	add_child(_class_tip)
	Tip.attach(_class_tip, PartyModel.class_name_of(base), ctext, ccol)
	_tag_tip = Control.new()
	_tag_tip.position = Vector2(_stage().position.x + 1, _stage().position.y + 1)
	_tag_tip.size = Vector2(18, 18)
	add_child(_tag_tip)
	Tip.attach(_tag_tip, PartyModel.class_name_of(base), ctext, ccol)
	for k in 2:
		var aid := String(cdef.get("basic" if k == 0 else "ability", ""))
		var row := Control.new()
		var rr: Rect2 = ROW_RECT[k]
		row.position = rr.position
		row.size = Vector2(w - 8, rr.size.y)
		add_child(row)
		_rows.append(row)
		Tip.attach(row, String(GameData.get_action(aid).get("name", aid)), action_full(aid), Pal.c(info["color"]) if k == 1 else Pal.INK9)
	queue_redraw()


func set_pick(p: int, dim: bool) -> void:
	if p != pick and p > 0:
		_flash = 1.0
	pick = p
	dimmed = dim
	var m := Color(0.62, 0.62, 0.72) if dim else Color.WHITE   # only the portrait dims; the text stays readable
	_clip.modulate = m
	queue_redraw()


func _stage() -> Rect2:
	return Rect2(6, 6, w - 12, 140)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not (event as InputEventMouseButton).pressed:
		tapped.emit()
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.0)
	var goal := 0.0   # picked cards stay aligned with the rest; the outline and ribbon mark the pick
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
	PartyDraw.panel(self, r, 0, &"PanelContainer")
	_draw_stage(cc)
	var cls := PartyModel.class_name_of(String(hero["class"]))
	var cdef := GameData.get_class_def(String(hero["class"]))
	# one focus: the hero's name, one size step above everything else on the card
	PartyDraw.text(self, Vector2(8, NAME_Y), String(hero.get("name", "?")), Pal.AMBER6 if not dimmed else Pal.INK9, PartyDraw.SERIF, NAME_SIZE)
	# class (its colour) and starting alignment (neutral) on one quiet line; where the class fights
	# and what the alignment means live in this line's tooltip
	var ly := CLASS_Y
	if _class_tip != null and Tip.is_open_for(_class_tip):
		draw_rect(Rect2(4, ly - 2, w - 8, 15), Pal.INK3)
	PartyDraw.tint_tex(self, PartyDraw.icon(info["icon"]), Vector2(8, ly + 2), cc)
	PartyDraw.text(self, Vector2(18, ly), cls, cc, PartyDraw.BOLD)
	var a: Array = hero.get("alignment", [0, 0])
	var aw := _align_words(a)
	var ax := w - 8 - PartyDraw.text_w(aw, PartyDraw.BOLD)
	PartyDraw.tint_tex(self, START, Vector2(ax - 11, ly + 2), Pal.INK8)
	PartyDraw.text(self, Vector2(ax, ly), aw, Pal.INK9, PartyDraw.BOLD)
	# stats: muted labels, bright values
	var st := PartyModel.stats({"class": hero["class"], "level": 1, "items": {}})
	var sy := STATS_Y
	var cw := floori((w - 16) / 5.0)
	var sx := 8
	for sname: String in ["hp", "atk", "def", "mag", "spd"]:
		var well := Rect2(sx, sy, cw - 2, 25)
		PartyDraw.inset(self, well)
		draw_rect(Rect2(well.position.x + 1, well.position.y, well.size.x - 2, 1), STAT_COLORS[sname])
		PartyDraw.text(self, Vector2(sx, sy + 2), PartyModel.STAT_LABELS[sname], Pal.INK9, PartyDraw.BOLD, UIText.BODY, false, cw - 2, HORIZONTAL_ALIGNMENT_CENTER)
		PartyDraw.text(self, Vector2(sx, sy + 13), str(st[sname]), Pal.INK10, PartyDraw.BOLD, UIText.BODY, true, cw - 2, HORIZONTAL_ALIGNMENT_CENTER)
		sx += cw
	# the ability (its name and one short line), then the basic attack as one quiet line; the full
	# sentences are in each row's tooltip
	for k in 2:
		var aid := String(cdef.get("basic" if k == 0 else "ability", ""))
		var act := GameData.get_action(aid)
		var rr: Rect2 = ROW_RECT[k]
		rr.size.x = w - 8
		var lit := k < _rows.size() and Tip.is_open_for(_rows[k])
		if lit:
			draw_rect(rr, Pal.INK3)
		var y := rr.position.y + 2
		if k == 1:
			# the same icon + name + short label as hero detail (PartyModel.ability_short), in the
			# card's one body face: only the hero's name is serif
			PartyDraw.tint_tex(self, ABILITY, Vector2(8, y + 3), cc)
			PartyDraw.text(self, Vector2(18, y), String(act.get("name", aid)), Pal.INK10, PartyDraw.BOLD)
			PartyDraw.text(self, Vector2(18, y + 14), PartyModel.ability_short(act), Pal.INK9, PartyDraw.BOLD)
		else:
			draw_rect(Rect2(8, rr.position.y - 3, w - 16, 1), Pal.INK3)
			PartyDraw.text(self, Vector2(8, y), "Basic: %s" % String(act.get("name", aid)), Pal.INK9, PartyDraw.BOLD)
	if pick > 0:
		PartyDraw.soft_outline(self, r, Pal.AMBER5)
		PartyDraw.soft_outline(self, r.grow(-1), Pal.AMBER3)
		if _flash > 0.0:
			var f := Pal.AMBER7
			f.a = _flash
			PartyDraw.soft_outline(self, r.grow(roundi((1.0 - _flash) * 3.0)), f)


## Pick ribbon across the foot of the stage.
func _draw_over() -> void:
	_over.size = size
	if pick <= 0:
		return
	var b := Rect2(_stage().end.x - 17, _stage().position.y + 3, 14, 14)
	_over.draw_rect(b, Pal.AMBER2)
	PartyDraw.soft_outline(_over, b, Pal.AMBER5)
	PartyDraw.text(_over, b.position + Vector2(0, 1), str(pick), Pal.AMBER7, PartyDraw.BOLD, UIText.BODY, false, 14, HORIZONTAL_ALIGNMENT_CENTER)
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
