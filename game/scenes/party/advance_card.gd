class_name AdvanceCard
extends Control
## The advancement moment. Replaces the hero card while open, so the grid stays visible beside
## it with the destination region outlined. Two outcomes side by side in plain terms:
##   Advance   -> the class this position produces, stat changes, new ability, level resets to 1.
##   Hold Back -> stays base class, keeps levelling and travelling; nearest corner shown.

signal advance_chosen
signal hold_chosen

const W := 228
const H := 294
const GEM := preload("res://ui/icons/memory_gem.png")
const STAR := preload("res://ui/icons/star.png")
const POINTER := preload("res://assets/party/pointer.png")

var hero: Dictionary = {}
var codex: Array = []
var focus := 0                # 0 advance, 1 hold back (pointer position)
var _t := 0.0
var _btn_adv: Button
var _btn_hold: Button
var _reach: Dictionary = {}


class ActionButton extends Button:
	var accent := Pal.AMBER5
	var lit := false:
		set(v): lit = v; queue_redraw()

	func _init(label: String) -> void:
		text = ""
		tooltip_text = ""
		focus_mode = Control.FOCUS_NONE
		set_meta("label", label)
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var down := is_pressed() or button_pressed
		if lit:
			PartyDraw.selected(self, r, accent)
		else:
			draw_rect(r.grow(-1), Pal.INK2)
			PartyDraw.soft_outline(self, r, Pal.INK5)
			draw_rect(Rect2(2, 1, size.x - 4, 1), Pal.INK3)
		var label := String(get_meta("label"))
		var y := 5 + (1 if down else 0)
		PartyDraw.text(self, Vector2(0, y), label, Pal.INK10 if lit else Pal.INK8, PartyDraw.BOLD,
			PartyDraw.SANS_SIZE, true, size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_adv = ActionButton.new("Advance")
	_btn_adv.position = Vector2(22, H - 30)
	_btn_adv.size = Vector2(92, 20)
	_btn_adv.accent = Pal.AMBER5
	_btn_adv.pressed.connect(func() -> void: advance_chosen.emit())
	add_child(_btn_adv)
	_btn_hold = ActionButton.new("Hold Back")
	_btn_hold.position = Vector2(118, H - 30)
	_btn_hold.size = Vector2(92, 20)
	_btn_hold.accent = Pal.CRYSTAL4
	_btn_hold.pressed.connect(func() -> void: hold_chosen.emit())
	add_child(_btn_hold)
	set_focus(0)


func set_focus(i: int) -> void:
	focus = i
	_btn_adv.lit = i == 0
	_btn_hold.lit = i == 1
	queue_redraw()


func set_hero(h: Dictionary, cdx: Array) -> void:
	hero = h
	codex = cdx
	_reach = hold_reach(h)
	queue_redraw()


## Nearest corner a held-back hero could still reach with the memories left (single steps,
## from the effective position). Returns {} or {region, steps, words, cell}.
static func hold_reach(h: Dictionary) -> Dictionary:
	var left := PartyModel.memories_left(h)
	var eff := PartyModel.effective(h)
	var best := {}
	for r in ["LG*", "CG*", "LE*", "CE*"]:
		var cell := PartyModel.region_cell(r)
		var d := PartyModel.steps(eff, cell)
		if d == 0 or d > left:
			continue
		if best.is_empty() or d < int(best["steps"]):
			var parts := []
			var dg := int(cell[0]) - int(eff[0])
			var dl := int(cell[1]) - int(eff[1])
			if dg != 0:
				parts.append("%s %d" % [PartyModel.axis_word("good", dg), absi(dg)])
			if dl != 0:
				parts.append("%s %d" % [PartyModel.axis_word("law", dl), absi(dl)])
			best = {"region": r, "steps": d, "words": ", ".join(parts), "cell": cell}
	return best


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if hero.is_empty():
		return
	PartyDraw.panel(self, Rect2(0, 0, W, H), 0, &"RarePanel")
	var th := PartyModel.threshold()
	var x := 10
	# heading
	for i in th:
		draw_texture(GEM, Vector2(x + i * 9, 9))
	PartyDraw.text(self, Vector2(x + th * 9 + 3, 8), "%d MEMORIES GATHERED" % PartyModel.memory_count(hero), Pal.CRYSTAL4, PartyDraw.BOLD)
	PartyDraw.text(self, Vector2(x, 20), "%s's Path" % String(hero.get("name", "")), Pal.AMBER6, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	var eff := PartyModel.effective(hero)
	var region := PartyModel.region_of(eff)
	PartyDraw.text(self, Vector2(x, 38), "They stand in %s." % PartyModel.region_words(region).replace("Neutral cross", "the neutral cross"), Pal.INK8, PartyDraw.BOLD)
	_draw_advance(Rect2(6, 52, W - 12, 128))
	_draw_hold(Rect2(6, 184, W - 12, 74))
	# pointer hand beside the focused button
	var b := _btn_adv if focus == 0 else _btn_hold
	var bob := 1 if fmod(_t, 0.6) < 0.3 else 0
	draw_texture(POINTER, b.position + Vector2(-14 + bob, 6))


func _box(r: Rect2, accent: Color, lit: bool) -> void:
	draw_rect(r, Pal.INK2 if not lit else Pal.INK2)
	PartyDraw.soft_outline(self, r, accent if lit else Pal.INK4)
	draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, 12), Pal.INK3)
	draw_rect(Rect2(r.position.x + 1, r.position.y + 13, r.size.x - 2, 1), Pal.INK1)


func _draw_advance(r: Rect2) -> void:
	var lit := focus == 0
	_box(r, Pal.AMBER5, lit)
	var x := r.position.x + 5
	var y := r.position.y
	PartyDraw.text(self, Vector2(x, y + 2), "ADVANCE", Pal.AMBER6 if lit else Pal.AMBER5, PartyDraw.BOLD)
	var lv := "Lv %d \u2192 1" % int(hero.get("level", 1))
	PartyDraw.text(self, Vector2(r.position.x, y + 2), lv, Pal.INK8, PartyDraw.BOLD, PartyDraw.SANS_SIZE, true, r.size.x - 6, HORIZONTAL_ALIGNMENT_RIGHT)
	var adv := PartyModel.advanced_copy(hero)
	var id := String(adv["class"])
	var known := id != "" and id in codex
	var from := PartyModel.class_name_of(String(hero["class"]))
	PartyDraw.text(self, Vector2(x, y + 18), from, Pal.INK8, PartyDraw.BOLD)
	var ax := x + PartyDraw.text_w(from, PartyDraw.BOLD) + 4
	PartyDraw.tint_tex(self, preload("res://ui/icons/arrow_right.png"), Vector2(ax, y + 19), Pal.AMBER5)
	ax += 10
	var to := PartyModel.class_name_of(id) if id != "" else "???"
	PartyDraw.text(self, Vector2(ax, y + 14), to, Pal.AMBER7 if lit else Pal.AMBER6, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	var nx := ax + PartyDraw.text_w(to, PartyDraw.SERIF, PartyDraw.SERIF_SIZE) + 4
	if not known and id != "":
		PartyDraw.pill(self, Vector2(nx, y + 18), "NEW", Pal.INK1, Pal.AMBER5, Pal.AMBER6)
	var lean := PartyModel.lean_of(PartyModel.effective(hero))
	var sub := ("%s  ·  " % lean if lean != "" and PartyModel.region_of(PartyModel.effective(hero)) != "N" else "")
	sub += "joins the codex" if not known else "known path"
	PartyDraw.text(self, Vector2(x, y + 31), sub, Pal.INK8, PartyDraw.BOLD)
	# stats: before > after (change)
	var a := PartyModel.stats(hero)
	var b := PartyModel.stats(adv) if id != "" else a
	var sy := y + 44
	var cx := [x, x + 26, x + 56, x + 70, x + 100]
	var keys := ["hp", "atk", "def", "mag", "spd"]
	for i in keys.size():
		var k: String = keys[i]
		var ry := sy + i * 12
		if i % 2 == 0:
			draw_rect(Rect2(r.position.x + 2, ry, r.size.x - 4, 12), Pal.INK3 if lit else Pal.INK2)
		PartyDraw.tint_tex(self, HeroCard.ICONS[k], Vector2(cx[0], ry + 3), HeroCard.STAT_COLORS[k], false)
		PartyDraw.text(self, Vector2(cx[0] + 10, ry + 1), PartyModel.STAT_LABELS[k], Pal.INK8, PartyDraw.BOLD)
		PartyDraw.text(self, Vector2(cx[1], ry + 1), str(a[k]), Pal.INK8, PartyDraw.BOLD, PartyDraw.SANS_SIZE, true, 26, HORIZONTAL_ALIGNMENT_RIGHT)
		PartyDraw.text(self, Vector2(cx[2], ry + 1), "→", Pal.INK8, PartyDraw.BOLD)
		PartyDraw.text(self, Vector2(cx[3], ry + 1), str(b[k]), Pal.INK10, PartyDraw.BOLD, PartyDraw.SANS_SIZE, true, 26, HORIZONTAL_ALIGNMENT_RIGHT)
		var d := int(b[k]) - int(a[k])
		var dc := Pal.LIFE4 if d > 0 else (Pal.BLOOD4 if d < 0 else Pal.INK6)
		var ds := "(%+d)" % d if d != 0 else "(=)"
		PartyDraw.text(self, Vector2(cx[4], ry + 1), ds, dc)
	# bars to the right: a quick visual of the new stat line vs the old
	var bx := r.position.x + 140
	for i in keys.size():
		var k: String = keys[i]
		var ry := sy + i * 12 + 4
		var mx := 240.0 if k == "hp" else 40.0
		var wa := clampi(roundi(float(a[k]) / mx * 66.0), 1, 66)
		var wb := clampi(roundi(float(b[k]) / mx * 66.0), 1, 66)
		draw_rect(Rect2(bx, ry, 66, 5), Pal.INK1)
		draw_rect(Rect2(bx, ry + 1, wb, 3), HeroCard.STAT_COLORS[k])
		draw_rect(Rect2(bx, ry + 1, mini(wa, wb), 3), HeroCard.STAT_COLORS[k].darkened(0.0) if wb >= wa else Pal.INK5)
		if wb > wa:
			draw_rect(Rect2(bx, ry + 1, wa, 3), Pal.INK6)
			draw_rect(Rect2(bx + wa, ry + 1, wb - wa, 3), HeroCard.STAT_COLORS[k])
	# ability swap
	var ab_y := sy + 63
	var old_ab := String(PartyModel.ability_of(String(hero["class"])).get("name", "—"))
	var new_ab := String(PartyModel.ability_of(id).get("name", "—")) if id != "" else "???"
	PartyDraw.text(self, Vector2(x, ab_y), "Ability", Pal.INK8, PartyDraw.BOLD)
	var ox := x + 38
	PartyDraw.text(self, Vector2(ox, ab_y), old_ab, Pal.INK8, PartyDraw.BOLD)
	ox += PartyDraw.text_w(old_ab) + 4
	PartyDraw.tint_tex(self, preload("res://ui/icons/arrow_right.png"), Vector2(ox, ab_y + 1), Pal.AMBER5)
	PartyDraw.text(self, Vector2(ox + 10, ab_y), new_ab, Pal.AMBER6, PartyDraw.BOLD)


func _draw_hold(r: Rect2) -> void:
	var lit := focus == 1
	_box(r, Pal.CRYSTAL4, lit)
	var x := r.position.x + 5
	var y := r.position.y
	PartyDraw.text(self, Vector2(x, y + 2), "HOLD BACK", Pal.CRYSTAL5 if lit else Pal.CRYSTAL4, PartyDraw.BOLD)
	var lv := "up to Lv %d" % PartyModel.max_level(hero)
	PartyDraw.text(self, Vector2(r.position.x, y + 2), lv, Pal.INK8, PartyDraw.BOLD, PartyDraw.SANS_SIZE, true, r.size.x - 6, HORIZONTAL_ALIGNMENT_RIGHT)
	var cls := PartyModel.class_name_of(String(hero["class"]))
	var ab := String(PartyModel.ability_of(String(hero["class"])).get("name", ""))
	var lines := [
		["+", "Keeps absorbing memories, travels farther", Pal.LIFE4],
		["-", "Fights on as a %s with %s" % [cls, ab], Pal.BLOOD4],
	]
	var ly := y + 16
	for l: Array in lines:
		PartyDraw.text(self, Vector2(x, ly), l[0], l[2], PartyDraw.BOLD)
		PartyDraw.text(self, Vector2(x + 8, ly), l[1], Pal.INK8, PartyDraw.BOLD)
		ly += 11
	# what holding back could reach
	ly += 3
	draw_rect(Rect2(r.position.x + 4, ly, r.size.x - 8, 1), Pal.INK3)
	ly += 3
	if _reach.is_empty():
		PartyDraw.text(self, Vector2(x, ly), "No corner within reach of %d more memories" % PartyModel.memories_left(hero), Pal.INK8, PartyDraw.BOLD)
	else:
		var reg := String(_reach["region"])
		PartyDraw.tint_tex(self, STAR, Vector2(x, ly + 2), PartyDraw.REGION_ACCENT[reg])
		var id := PartyModel.class_for_region(PartyModel.base_class(hero), reg)
		var nm := PartyModel.class_name_of(id) if id != "" and id in codex else "???"
		var t := "Corner %s: %d step away" % [nm, int(_reach["steps"])] if int(_reach["steps"]) == 1 \
			else "Corner %s: %d steps away" % [nm, int(_reach["steps"])]
		PartyDraw.text(self, Vector2(x + 10, ly), t, Pal.CRYSTAL5, PartyDraw.BOLD)
		PartyDraw.text(self, Vector2(x + 10, ly + 11), "needs %s  ·  %d memories left" % [_reach["words"], PartyModel.memories_left(hero)], Pal.INK8, PartyDraw.BOLD)
