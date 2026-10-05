class_name HeroCard
extends Control
## Left panel of the hero detail screen: stage with the animated sprite, identity, level and
## memory pips, stats strip, equipment (only the Relic shows alignment, marked bound), ability.

signal advance_pressed

const W := 228
const H := 294
const GEM := preload("res://ui/icons/memory_gem.png")
const ICONS := {
	"hp": preload("res://assets/party/stat_hp.png"), "atk": preload("res://assets/party/stat_atk.png"),
	"def": preload("res://assets/party/stat_def.png"), "mag": preload("res://assets/party/stat_mag.png"),
	"spd": preload("res://assets/party/stat_spd.png"),
}
const STAT_COLORS := {"hp": Pal.BLOOD4, "atk": Pal.AMBER5, "def": Pal.INK9, "mag": Pal.VIOLET3, "spd": Pal.LIFE4}
const SLOT_ICONS := {
	"weapon": preload("res://assets/party/slot_weapon.png"), "armor": preload("res://assets/party/slot_armor.png"),
	"relic": preload("res://assets/party/slot_relic.png"),
}
const LOCK := preload("res://assets/party/lock.png")
const ABILITY := preload("res://assets/party/ability.png")
const STAGE := Rect2(8, 8, 80, 100)

var hero: Dictionary = {}
var info: Dictionary = {}
var _sprite: AnimatedSprite2D
var _clip: Control
var _advance: Button
var _t := 0.0
var _motes: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	clip_contents = false
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.position = STAGE.position + Vector2(1, 1)
	_clip.size = STAGE.size - Vector2(2, 3)
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2(2, 2)
	_clip.add_child(_sprite)
	_advance = Button.new()
	_advance.text = "Advance"
	_advance.position = Vector2(94, 84)
	_advance.custom_minimum_size = Vector2(60, 18)
	_advance.size = Vector2(60, 18)
	_advance.focus_mode = Control.FOCUS_NONE
	_advance.pressed.connect(func() -> void: advance_pressed.emit())
	add_child(_advance)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		_motes.append(Vector3(rng.randi_range(4, int(STAGE.size.x) - 5), rng.randf(), rng.randf_range(0.12, 0.3)))


func set_hero(h: Dictionary) -> void:
	hero = h
	info = EncounterDB.class_info(PartyModel.base_class(h))
	var frames := _frames_for(PartyModel.base_class(h))
	if frames:
		_sprite.sprite_frames = frames
		_sprite.play(&"idle")
		_sprite.visible = true
		# feet (origin 32,60 at 1x) on the stage floor
		_sprite.position = Vector2(roundi(STAGE.size.x / 2) - 1 - 64, STAGE.size.y - 1 - 9 - 120)
	else:
		_sprite.visible = false
	var ready := PartyModel.ready_to_advance(h)
	_advance.visible = ready
	_advance.text = "Advance" if not h.get("held_back", false) else "Advance now"
	_advance.size = Vector2(maxi(60, PartyDraw.text_w(_advance.text, PartyDraw.BOLD) + 22), 18)
	queue_redraw()


static func _frames_for(base: String) -> SpriteFrames:
	var meta: Variant = EncounterDB.load_json("res://assets/sprites/sprite_meta.json")
	if meta is Dictionary and (meta as Dictionary).has(base):
		var p := String(meta[base].get("path", ""))
		if p != "" and ResourceLoader.exists(p):
			return load(p)
	return null


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if hero.is_empty():
		return
	PartyDraw.panel(self, Rect2(0, 0, W, H))
	_draw_stage()
	_draw_identity()
	_draw_stats(114)
	_draw_equipment(158)
	_draw_ability(238)


func _draw_stage() -> void:
	var r := STAGE
	var cc := Pal.c(info["color"])
	draw_rect(r, Pal.INK1)
	var inner := r.grow(-1)
	# backdrop: stepped night bands, lighter toward the floor where the lantern light pools
	var bands := [Pal.INK2, Pal.INK2, Pal.INK3, Pal.INK3, Pal.INK4]
	var bh := inner.size.y / bands.size()
	for i in bands.size():
		draw_rect(Rect2(inner.position.x, inner.position.y + roundi(i * bh), inner.size.x, ceili(bh)), bands[i])
	# arched window motif behind the hero
	var cx := inner.position.x + inner.size.x / 2
	var arch_top := inner.position.y + 10
	for y in range(0, 54):
		var half := 20
		if y < 20:
			half = int(sqrt(maxf(0.0, 400.0 - pow(20.0 - y, 2))))
		draw_rect(Rect2(cx - half, arch_top + y, half * 2, 1), Pal.INK3 if y < 30 else Pal.INK4)
		if half > 0:
			draw_rect(Rect2(cx - half - 1, arch_top + y, 1, 1), Pal.INK5)
			draw_rect(Rect2(cx + half, arch_top + y, 1, 1), Pal.INK5)
	# floor: a lit ellipse in the class colour's shadow tone, then the contact shadow
	var fy := inner.end.y - 13
	draw_rect(Rect2(inner.position.x, fy, inner.size.x, inner.end.y - fy), Pal.INK3)
	draw_rect(Rect2(inner.position.x, fy, inner.size.x, 1), Pal.INK5)
	for i in 5:
		var hw := 30 - i * 5
		draw_rect(Rect2(cx - hw, fy + 2 + i, hw * 2, 1), [Pal.INK4, Pal.INK4, Pal.INK5, Pal.INK5, Pal.INK6][i])
	draw_rect(Rect2(cx - 16, fy + 3, 32, 4), Pal.INK2)
	draw_rect(Rect2(cx - 13, fy + 2, 26, 1), Pal.INK2)
	draw_rect(Rect2(cx - 13, fy + 7, 26, 1), Pal.INK2)
	# drifting memory motes (crystal), lively but quiet
	for m: Vector3 in _motes:
		var ph := fmod(m.y + _t * m.z, 1.0)
		var y := inner.end.y - 14 - ph * (inner.size.y - 18)
		var x := inner.position.x + m.x + roundf(sin(_t * 1.3 + m.y * 9.0) * 1.0)
		var c := Pal.CRYSTAL4 if ph < 0.7 else Pal.CRYSTAL2
		draw_rect(Rect2(Vector2(x, y).round(), Vector2(1, 1)), c)
	# frame: class colour sill, soft rim
	PartyDraw.soft_outline(self, r, Pal.INK5)
	draw_rect(Rect2(r.position.x + 1, r.end.y - 2, r.size.x - 2, 1), cc)
	# tier corner tag
	var tier := PartyModel.tier(hero)
	if tier != "base":
		draw_rect(Rect2(r.position.x + 3, r.position.y + 3, 7, 7), Pal.INK1)
		PartyDraw.tint_tex(self, preload("res://ui/icons/star.png"), r.position + Vector2(3, 3), Pal.AMBER6, false)


func _draw_identity() -> void:
	var x := 94
	var cc := Pal.c(info["color"])
	PartyDraw.text(self, Vector2(x, 6), String(hero.get("name", "?")), Pal.AMBER6, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	var cls := PartyModel.class_name_of(String(hero["class"]))
	var icon: Texture2D = PartyDraw.icon(info["icon"])
	PartyDraw.tint_tex(self, icon, Vector2(x, 27), cc)
	PartyDraw.text(self, Vector2(x + 10, 25), cls, Pal.INK10, PartyDraw.BOLD)
	var tier := PartyModel.tier(hero)
	var tx := x + 14 + PartyDraw.text_w(cls, PartyDraw.BOLD)
	var tl: String = String(PartyModel.TIER_LABELS.get(tier, tier)).to_upper()
	if tier == "base":
		PartyDraw.pill(self, Vector2(tx, 25), tl, Pal.INK8, Pal.INK2, Pal.INK5)
	else:
		PartyDraw.pill(self, Vector2(tx, 25), tl, Pal.AMBER6, Pal.AMBER1, Pal.AMBER4)
	# level
	var lv := int(hero.get("level", 1))
	PartyDraw.text(self, Vector2(x, 40), "Lv", Pal.INK7, PartyDraw.BOLD)
	PartyDraw.text(self, Vector2(x + 15, 40), str(lv), Pal.INK10, PartyDraw.BOLD)
	PartyDraw.text(self, Vector2(x + 18 + PartyDraw.text_w(str(lv), PartyDraw.BOLD), 40), "/ %d" % PartyModel.max_level(hero), Pal.INK6)
	_draw_taken(x, 70)
	# memories toward the advancement threshold (or levels toward Legendary)
	var th := PartyModel.threshold()
	var n := PartyModel.memory_count(hero)
	if tier == "base":
		PartyDraw.text(self, Vector2(x + 52, 40), "MEMORIES", Pal.INK7)
		var gx := x
		var gy := 54
		for i in th:
			var well := Rect2(gx + i * 12, gy, 11, 12)
			PartyDraw.inset(self, well)
			if i < n:
				draw_texture(GEM, well.position + Vector2(2, 2))
			else:
				draw_rect(Rect2(well.position + Vector2(4, 4), Vector2(3, 4)), Pal.INK3)
		var ex := gx + th * 12 + 2
		if n > th:
			draw_rect(Rect2(ex, gy + 1, 1, 10), Pal.INK5)
			for i in n - th:
				var well := Rect2(ex + 3 + i * 12, gy, 11, 12)
				PartyDraw.inset(self, well)
				draw_texture(GEM, well.position + Vector2(2, 2))
			ex += 3 + (n - th) * 12
		var cnt := "%d/%d" % [mini(n, th), th]
		PartyDraw.text(self, Vector2(ex + 3, gy + 1), cnt, Pal.CRYSTAL4 if n >= th else Pal.INK8, PartyDraw.BOLD)
		if PartyModel.ready_to_advance(hero):
			if hero.get("held_back", false):
				PartyDraw.pill(self, Vector2(_advance.position.x + _advance.size.x + 4, 88), "HELD", Pal.CRYSTAL5, Pal.CRYSTAL1, Pal.CRYSTAL3)
			else:
				var on := fmod(_t, 0.9) < 0.55
				PartyDraw.text(self, Vector2(_advance.position.x + _advance.size.x + 4, 87), "Ready", Pal.AMBER6 if on else Pal.AMBER5, PartyDraw.BOLD)
		else:
			var left := th - n
			PartyDraw.text(self, Vector2(x, 86), "%d more to advance" % left, Pal.INK7)
	else:
		PartyDraw.text(self, Vector2(x + 52, 40), "LEGENDARY", Pal.INK7)
		var gy := 54
		var mx := PartyModel.max_level(hero)
		for i in mx:
			var well := Rect2(x + i * 12, gy, 11, 12)
			PartyDraw.inset(self, well)
			if i < lv:
				PartyDraw.tint_tex(self, preload("res://ui/icons/star.png"), well.position + Vector2(2, 3), Pal.AMBER6, false)
		PartyDraw.text(self, Vector2(x, 86), "Legendary gate: sealed", Pal.INK7)


## The memories taken so far as direction arrows, in the order absorbed.
func _draw_taken(x: int, y: int) -> void:
	var mem: Array = hero.get("memories_before", []) + hero.get("memories", [])
	PartyDraw.text(self, Vector2(x, y), "Taken", Pal.INK7)
	var ax := x + 30
	if mem.is_empty():
		PartyDraw.text(self, Vector2(ax, y), "none yet", Pal.INK6)
		return
	for s: Array in mem:
		var v := Vector2i(int(s[0]), int(s[1]))
		var col := PartyModel.axis_color("good", v.x) if v.x != 0 else PartyModel.axis_color("law", v.y)
		var well := Rect2(ax, y, 11, 11)
		PartyDraw.inset(self, well)
		draw_texture(PartyDraw.icon(EncounterDB.arrow_icon(v)), well.position + Vector2(2, 2), col)
		ax += 12


func _draw_stats(y: int) -> void:
	PartyDraw.header(self, Vector2(8, y), W - 16, "Stats")
	var st := PartyModel.stats(hero)
	var x := 8
	var cw := 40
	for s: String in ["hp", "atk", "def", "mag", "spd"]:
		var r := Rect2(x, y + 12, cw, 27)
		PartyDraw.row(self, Rect2(r.position, Vector2(cw, 12)))
		PartyDraw.tint_tex(self, ICONS[s], Vector2(x + 3, y + 14), STAT_COLORS[s])
		PartyDraw.text(self, Vector2(x + 12, y + 12), PartyModel.STAT_LABELS[s], Pal.INK8)
		var well := Rect2(x, y + 25, cw, 13)
		PartyDraw.inset(self, well)
		PartyDraw.text(self, Vector2(x, y + 26), str(st[s]), Pal.INK10, PartyDraw.BOLD, PartyDraw.SANS_SIZE, true, cw - 4, HORIZONTAL_ALIGNMENT_RIGHT)
		x += cw + 3


func _draw_equipment(y: int) -> void:
	PartyDraw.header(self, Vector2(8, y), W - 16, "Equipment")
	var items: Dictionary = hero.get("items", {})
	var ry := y + 12
	for slot: String in ["weapon", "armor", "relic"]:
		var id := String(items.get(slot, ""))
		var it := PartyModel.item(id) if id != "" else {}
		var rh := 28 if slot == "relic" else 18
		var r := Rect2(8, ry, W - 16, rh - 1)
		if slot == "relic":
			draw_rect(r, Pal.AMBER1 if id != "" else Pal.INK2)
			PartyDraw.soft_outline(self, r, Pal.AMBER3 if id != "" else Pal.INK4)
		else:
			PartyDraw.row(self, r)
		var well := Rect2(10, ry + 2, 13, 13)
		PartyDraw.inset(self, well)
		var ic: Color = Pal.AMBER6 if slot == "relic" and id != "" else (Pal.INK9 if id != "" else Pal.INK5)
		draw_texture(SLOT_ICONS[slot], well.position + Vector2(2, 2), ic)
		if id == "":
			var empty_txt := "No Relic" if slot == "relic" else "Empty"
			PartyDraw.text(self, Vector2(28, ry + 3), empty_txt, Pal.INK6)
			if slot == "relic":
				PartyDraw.text(self, Vector2(28, ry + 14), "A Relic binds when equipped", Pal.INK6)
		else:
			var name_col := Pal.AMBER6 if slot == "relic" else Pal.INK10
			PartyDraw.text(self, Vector2(28, ry + 3), String(it.get("name", id)), name_col, PartyDraw.BOLD)
			var sw := PartyModel.item_stat_words(it)
			if slot != "relic":
				PartyDraw.text(self, Vector2(28, ry + 3), sw, Pal.INK8, PartyDraw.SANS, PartyDraw.SANS_SIZE, true, W - 16 - 24, HORIZONTAL_ALIGNMENT_RIGHT)
			else:
				# BOUND tag with a lock
				var bw := PartyDraw.text_w("BOUND", PartyDraw.BOLD) + 14
				var bx := W - 8 - 3 - bw
				var br := Rect2(bx, ry + 3, bw, 11)
				draw_rect(br, Pal.INK1)
				PartyDraw.soft_outline(self, br, Pal.AMBER4)
				draw_texture(LOCK, Vector2(bx + 3, ry + 5), Pal.AMBER5)
				PartyDraw.text(self, Vector2(bx + 10, ry + 4), "BOUND", Pal.AMBER5, PartyDraw.BOLD, PartyDraw.SANS_SIZE, false)
				# alignment offset: the only equipment with one
				var off: Array = it.get("alignment", [0, 0])
				var ax := 28
				for pair in [["good", int(off[0])], ["law", int(off[1])]]:
					if pair[1] == 0:
						continue
					var v: int = pair[1]
					var shift := Vector2i(v, 0) if pair[0] == "good" else Vector2i(0, v)
					var arrow: Texture2D = PartyDraw.icon(EncounterDB.arrow_icon(shift))
					var col := PartyModel.axis_color(pair[0], v)
					PartyDraw.tint_tex(self, arrow, Vector2(ax, ry + 16), col)
					var word := "%+d %s" % [absi(v), PartyModel.axis_word(pair[0], v)]
					PartyDraw.text(self, Vector2(ax + 9, ry + 14), word, col, PartyDraw.BOLD)
					ax += 13 + PartyDraw.text_w(word, PartyDraw.BOLD)
				PartyDraw.text(self, Vector2(ax, ry + 14), "offset  " + sw, Pal.AMBER4)
		ry += rh


func _draw_ability(y: int) -> void:
	PartyDraw.header(self, Vector2(8, y), W - 16, "Ability")
	var a := PartyModel.ability_of(String(hero["class"]))
	var well := Rect2(8, y + 13, 15, 15)
	PartyDraw.inset(self, well)
	var cc := Pal.c(info["color"])
	draw_texture(ABILITY, well.position + Vector2(4, 4), cc)
	PartyDraw.text(self, Vector2(28, y + 12), String(a.get("name", "—")), Pal.INK10, PartyDraw.BOLD)
	var tag := "replaced on advancing" if PartyModel.tier(hero) == "base" else "advanced ability"
	PartyDraw.text(self, Vector2(28, y + 12), tag, Pal.INK6, PartyDraw.SANS, PartyDraw.SANS_SIZE, true, W - 16 - 20, HORIZONTAL_ALIGNMENT_RIGHT)
	var desc := PartyModel.ability_desc(a)
	var lines := UIText.wrap_lines(desc, W - 36, UIText.SANS, UIText.BODY)
	var ly := y + 24.0
	for i in mini(3, lines.size()):
		UIText.draw(self, Vector2(28, ly), lines[i], Pal.INK8, UIText.SANS, UIText.BODY)
		ly += UIText.line_h(UIText.SANS, UIText.BODY)
