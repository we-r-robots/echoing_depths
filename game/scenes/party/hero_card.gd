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
const NAME_SIZE := 20      # the hero's name, one size step above the panel's other text
const CLASS_Y := 30
const PIP_Y := 47          # the level line ("Lv 4/6", and an advanced class's stars)
const LV_W := 44           # room for "Lv 4/6" before the stars
const TAKEN_Y := 62        # the memories row: one 16x16 well per memory (its arrow), then the empty ones
const TAKEN_X := 52        # room for "Memories" before the wells
const WELL := 16           # memory wells: 16 design px = 48 screen px at 1080p, arrows drawn x2
const STATS_Y := 116
const EQUIP_Y := 152
const ABILITY_Y := 222
const NOTE_Y := 258        # the screen's one status sentence, inside the card (critic r3)

var hero: Dictionary = {}
var info: Dictionary = {}
var message := "":          # one status sentence about this hero (set by HeroDetail)
	set(v): message = v; queue_redraw()
var _class_tip: Control
var _sprite: AnimatedSprite2D
var _clip: Control
var _advance: Button
var _t := 0.0
var _motes: Array = []
## Tooltip hit areas (at least 16 design px = 48 screen px at 1080p; larger than the drawn glyphs).
const HIT := 16
const PIP_STEP := 16
var _pip_tips: Array[Control] = []
var _taken_tips: Array[Control] = []
var _ability_tip: Control


func _tip_area(r: Rect2) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)
	return c


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
	_advance.theme_type_variation = &"PrimaryButton"   # the card's one main action
	_advance.custom_minimum_size = Vector2(60, 24)
	_advance.size = Vector2(60, 24)
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
	_build_tips()
	var ready := PartyModel.ready_to_advance(h)
	_advance.visible = ready
	_advance.text = "Advance" if not h.get("held_back", false) else "Advance now"
	_advance.size = Vector2(maxi(60, PartyDraw.text_w(_advance.text, PartyDraw.BOLD, UIText.NUMBER) + 28), 24)
	queue_redraw()


## Tooltips for the memory pips, each taken memory arrow and the ability (its full sentence lives
## only here, BUILD.md "effects are icons").
func _build_tips() -> void:
	for c in _pip_tips + _taken_tips:
		Tip.detach(c)
		c.queue_free()
	_pip_tips.clear()
	_taken_tips.clear()
	if _ability_tip != null:
		Tip.detach(_ability_tip)
		_ability_tip.queue_free()
		_ability_tip = null
	if _class_tip != null:
		Tip.detach(_class_tip)
		_class_tip.queue_free()
		_class_tip = null
	var x := 94
	var th := PartyModel.threshold()
	var n := PartyModel.memory_count(hero)
	var base_tier := PartyModel.tier(hero) == "base"
	var body := "%d of %d memories toward advancing. Each encounter choice gives the hero who acts one memory; at %d the hero can Advance to a new class." % [mini(n, th), th, th]
	var mem: Array = hero.get("memories_before", []) + hero.get("memories", [])
	# one well per memory taken (its tooltip names the shift), then the empty wells still to fill
	for i in maxi(mem.size(), th if base_tier else 0):
		var c := _tip_area(Rect2(x + TAKEN_X + i * (WELL + 2), TAKEN_Y, WELL, WELL))
		if i < mem.size():
			var v := Vector2i(int(mem[i][0]), int(mem[i][1]))
			var words: PackedStringArray = []
			for w: Dictionary in EncounterDB.shift_words(v):
				words.append("%s +%d" % [w["word"], w["amount"]])
			Tip.attach(c, "Memory %d" % (i + 1), "Moved the hero %s on the alignment grid.%s" % [
				", ".join(words) if not words.is_empty() else "nowhere", (" " + body) if base_tier else ""], Pal.CRYSTAL4)
		else:
			Tip.attach(c, "Memories", body, Pal.CRYSTAL4)
		_taken_tips.append(c)
	if not base_tier:
		_class_tip = _tip_area(Rect2(x, CLASS_Y - 2, W - x - 6, 16))
		Tip.attach(_class_tip, PartyModel.class_name_of(String(hero["class"])),
			"An advanced class. Its level stars fill as it grows. Legendary gate: sealed (a Legendary class needs a sacrifice).", Pal.AMBER6)
	var a := PartyModel.ability_of(String(hero["class"]))
	var note := "Replaced by the new class's ability on advancing." if PartyModel.tier(hero) == "base" else "This advanced class's ability."
	_ability_tip = _tip_area(Rect2(6, ABILITY_Y - 2, W - 12, 32))
	Tip.attach(_ability_tip, String(a.get("name", "")), PartyModel.ability_desc(a) + " " + note, Pal.c(info["color"]))


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
	_draw_stats(STATS_Y)
	_draw_equipment(EQUIP_Y)
	_draw_ability(ABILITY_Y)
	_draw_note()


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
	PartyDraw.text(self, Vector2(x, 4), String(hero.get("name", "?")), Pal.AMBER6, PartyDraw.SERIF, NAME_SIZE)
	var cls := PartyModel.class_name_of(String(hero["class"]))
	var icon: Texture2D = PartyDraw.icon(info["icon"])
	PartyDraw.tint_tex(self, icon, Vector2(x, CLASS_Y + 2), cc)
	PartyDraw.text(self, Vector2(x + 10, CLASS_Y), cls, cc, PartyDraw.BOLD)
	var tier := PartyModel.tier(hero)
	# level (an advanced class adds its stars); the memories row under it is the trail of arrows
	var lv := int(hero.get("level", 1))
	PartyDraw.text(self, Vector2(x, PIP_Y), "Lv %d/%d" % [lv, PartyModel.max_level(hero)], Pal.INK10, PartyDraw.BOLD)
	if tier != "base":
		var gx := x + LV_W
		for i in PartyModel.max_level(hero):
			var well := Rect2(gx + i * 12, PIP_Y, 11, 11)
			PartyDraw.inset(self, well)
			if i < lv:
				PartyDraw.tint_tex(self, preload("res://ui/icons/star.png"), well.position + Vector2(2, 2), Pal.AMBER6, false)
	_draw_taken(x, TAKEN_Y)
	if tier == "base" and PartyModel.ready_to_advance(hero):
		if hero.get("held_back", false):
			PartyDraw.pill(self, Vector2(_advance.position.x + _advance.size.x + 4, _advance.position.y + 7), "HELD", Pal.CRYSTAL5, Pal.CRYSTAL1, Pal.CRYSTAL3)
		else:
			var on := fmod(_t, 0.9) < 0.55
			PartyDraw.text(self, Vector2(_advance.position.x + _advance.size.x + 4, _advance.position.y + 6), "Ready", Pal.AMBER6 if on else Pal.AMBER5, PartyDraw.BOLD)


## The memories as a labelled trail: one 16x16 well per memory with its direction arrow drawn x2,
## then the wells still empty before the hero can advance (each opens a tooltip).
func _draw_taken(x: int, y: int) -> void:
	var mem: Array = hero.get("memories_before", []) + hero.get("memories", [])
	PartyDraw.text(self, Vector2(x, y + 3), "Memories", Pal.INK9, PartyDraw.BOLD)
	var ax := x + TAKEN_X
	var n := maxi(mem.size(), PartyModel.threshold() if PartyModel.tier(hero) == "base" else 0)
	if n == 0:
		PartyDraw.text(self, Vector2(ax, y + 3), "none yet", Pal.INK8, PartyDraw.BOLD)
		return
	for i in n:
		var well := Rect2(ax, y, WELL, WELL)
		PartyDraw.inset(self, well)
		if i < _taken_tips.size() and Tip.is_open_for(_taken_tips[i]):
			PartyDraw.soft_outline(self, well.grow(1), Pal.CRYSTAL4)
		if i < mem.size():
			var s: Array = mem[i]
			var v := Vector2i(int(s[0]), int(s[1]))
			var col := PartyModel.axis_color("good", v.x) if v.x != 0 else PartyModel.axis_color("law", v.y)
			var tex: Texture2D = PartyDraw.icon(EncounterDB.arrow_icon(v))
			var sz := tex.get_size() * 2.0
			var p := (well.position + (well.size - sz) / 2.0).floor()
			draw_texture_rect(tex, Rect2(p + Vector2(1, 1), sz), false, Pal.INK1)
			draw_texture_rect(tex, Rect2(p, sz), false, col)
		else:
			draw_rect(Rect2(well.position + Vector2(6, 6), Vector2(4, 4)), Pal.INK4)
		ax += WELL + 2


## The status sentence (what the Relic does, how far from advancing, the tapped cell) as the card's
## foot, inside the panel.
func _draw_note() -> void:
	if message == "":
		return
	var r := Rect2(8, NOTE_Y, W - 16, H - NOTE_Y - 8)
	draw_rect(Rect2(8, NOTE_Y - 5, W - 16, 1), Pal.INK3)
	var lines := UIText.wrap_lines(message, int(r.size.x), UIText.BOLD, UIText.BODY)
	var lh := UIText.line_h(UIText.BOLD, UIText.BODY)
	var y := r.position.y + roundf((r.size.y - lines.size() * lh) / 2.0)
	for l: String in lines:
		PartyDraw.text(self, Vector2(r.position.x, y), l, Pal.INK9, PartyDraw.BOLD)
		y += lh


func _draw_stats(y: int) -> void:
	# no section header: the stat icons say what this strip is (fewer, calmer elements)
	var st := PartyModel.stats(hero)
	var x := 8
	var cw := 40
	for s: String in ["hp", "atk", "def", "mag", "spd"]:
		var r := Rect2(x, y, cw, 27)
		PartyDraw.row(self, Rect2(r.position, Vector2(cw, 12)))
		PartyDraw.tint_tex(self, ICONS[s], Vector2(x + 3, y + 2), STAT_COLORS[s])
		PartyDraw.text(self, Vector2(x + 12, y), PartyModel.STAT_LABELS[s], Pal.INK9, PartyDraw.BOLD)
		var well := Rect2(x, y + 13, cw, 13)
		PartyDraw.inset(self, well)
		PartyDraw.text(self, Vector2(x, y + 14), str(st[s]), Pal.INK10, PartyDraw.BOLD, PartyDraw.SANS_SIZE, true, cw - 4, HORIZONTAL_ALIGNMENT_RIGHT)
		x += cw + 3


func _draw_equipment(y: int) -> void:
	var items: Dictionary = hero.get("items", {})
	var ry := y
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
			PartyDraw.text(self, Vector2(28, ry + 3), empty_txt, Pal.INK8, PartyDraw.BOLD)
			if slot == "relic":
				PartyDraw.text(self, Vector2(28, ry + 14), "A Relic binds when equipped", Pal.INK8, PartyDraw.BOLD)
		else:
			var name_col := Pal.AMBER6 if slot == "relic" else Pal.INK10
			PartyDraw.text(self, Vector2(28, ry + 3), String(it.get("name", id)), name_col, PartyDraw.BOLD)
			var sw := PartyModel.item_stat_words(it)
			if slot != "relic":
				PartyDraw.text(self, Vector2(28, ry + 3), sw, Pal.INK8, PartyDraw.BOLD, PartyDraw.SANS_SIZE, true, W - 16 - 24, HORIZONTAL_ALIGNMENT_RIGHT)
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
				PartyDraw.text(self, Vector2(ax + 2, ry + 14), sw, Pal.INK9, PartyDraw.BOLD)
		ry += rh


func _draw_ability(y: int) -> void:
	draw_rect(Rect2(8, y - 5, W - 16, 1), Pal.INK3)
	var a := PartyModel.ability_of(String(hero["class"]))
	if _ability_tip != null and Tip.is_open_for(_ability_tip):
		draw_rect(Rect2(6, y - 2, W - 12, 32), Pal.INK3)
	var well := Rect2(8, y + 2, 15, 15)
	PartyDraw.inset(self, well)
	var cc := Pal.c(info["color"])
	draw_texture(ABILITY, well.position + Vector2(4, 4), cc)
	# BUILD.md "effects are icons" (user ruling 2026-10-05): the name and a label of 20 characters or
	# fewer, set the same way as on the draft card; the full sentence is in the tooltip
	PartyDraw.text(self, Vector2(28, y), String(a.get("name", "—")), Pal.INK10, PartyDraw.BOLD)
	PartyDraw.text(self, Vector2(28, y + 14), PartyModel.ability_short(a), Pal.INK9, PartyDraw.BOLD)
