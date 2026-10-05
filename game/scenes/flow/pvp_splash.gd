class_name VersusSplash
extends Control
## The splash before a PvP fight: both teams' crests and names face each other ("VS"), with the
## heroes each side brings. The same card introduces a floor guardian or the Crystal (their name
## and intro instead of a rival team). Tap anywhere (or wait) to begin.
##
##   var s := VersusSplash.open(parent, {"mode": "pvp" | "guardian" | "crystal",
##       "you": {"name", "crest", "heroes": [{name, class, level}]},
##       "them": {"name", "crest", "title", "intro", "heroes": [...]}})
##   s.done.connect(func(): ...)          # the splash frees itself after emitting
## Standalone it shows a demo PvP splash (args: --mode=guardian / --mode=crystal).

signal done

const SCENE := "res://scenes/flow/pvp_splash.tscn"
const BACKDROP := preload("res://assets/battle/bg_vault_wide.png")
const AUTO := {"pvp": 4.0, "guardian": 7.0, "crystal": 8.0}

var data: Dictionary = {}
var demo := false
var _t := 0.0
var _done := false
var _opened := false
var _left: Control
var _right: Control
var _vs: Label
var _hint: Label


static func open(parent: Node, d: Dictionary) -> VersusSplash:
	var s: VersusSplash = load(SCENE).instantiate()
	s._opened = true
	s.data = d
	parent.add_child(s)
	return s


static func demo_data(mode := "pvp") -> Dictionary:
	var you := {"name": "The Lanternrest Company", "crest": "lantern", "heroes": [
		{"name": "Brannoc", "class": "fighter", "level": 4}, {"name": "Ilse", "class": "healer", "level": 3},
		{"name": "Sable", "class": "rogue", "level": 3}]}
	match mode:
		"guardian":
			return {"mode": "guardian", "you": you, "them": {"name": "The Sentinel Warden", "crest": "",
				"title": "Floor guardian", "intro": "Stone that remembers being a door. It has kept this stair for longer than the Vault has had a name, and it does not mean to stop now."}}
		"crystal":
			return {"mode": "crystal", "you": you, "them": {"name": "The Crystal of Remembrance", "crest": "",
				"title": "The final chamber", "intro": "Everything this Vault has taken is held here, humming. Chip a Shard free and the memories inside will rise to stop you."}}
	return {"mode": "pvp", "you": you, "them": {"name": "The Ashen Vow", "crest": "", "title": "Echo, floor 2",
		"heroes": [{"name": "Corvin", "class": "mage", "level": 4}, {"name": "Wren", "class": "rogue", "level": 3},
			{"name": "Hale", "class": "fighter", "level": 3}, {"name": "Mira", "class": "healer", "level": 2}]}}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _opened:
		demo = true
		var mode := "pvp"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--mode="):
				mode = a.substr(7)
		data = demo_data(mode)
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _mode() -> String:
	return String(data.get("mode", "pvp"))


func _build() -> void:
	var you: Dictionary = data.get("you", {})
	var them: Dictionary = data.get("them", {})
	_left = _side(you, "Your party", false)
	add_child(_left)
	var sub := String(them.get("title", ""))
	if sub == "":
		sub = FlowUI.fight_word(_mode())
	_right = _side(them, sub, _mode() != "pvp")
	add_child(_right)
	_vs = FlowUI.label("VS", &"", Pal.AMBER6, 60, HORIZONTAL_ALIGNMENT_CENTER)
	_vs.add_theme_font_override("font", UIText.SERIF)
	_vs.add_theme_font_size_override("font_size", UIText.DISPLAY)
	_vs.modulate.a = 0.0
	add_child(_vs)
	_hint = FlowUI.label("Tap to begin", &"MutedLabel", null, 200, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_hint)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_vs, "modulate:a", 1.0, 0.4).set_delay(0.35)


## One side: crest, name, subtitle, then either its heroes (a party) or its intro (a guardian or
## the Crystal).
func _side(d: Dictionary, sub: String, monster: bool) -> Control:
	var v := FlowUI.vbox(4)
	v.custom_minimum_size.x = 250
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	var crest_id := Crests.for_team(String(d.get("crest", "")), String(d.get("name", "")))
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if monster:
		holder.add_child(_monster_mark())
	else:
		holder.add_child(FlowUI.crest(crest_id, 4))
	v.add_child(holder)
	var nm := FlowUI.label(String(d.get("name", "")), &"HeadingLabel", null, 250, HORIZONTAL_ALIGNMENT_CENTER)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not monster:
		nm.add_theme_color_override("font_color", UIText.legible(Crests.accent(crest_id)))
	v.add_child(nm)
	v.add_child(FlowUI.label(sub, &"MutedLabel", null, 250, HORIZONTAL_ALIGNMENT_CENTER))
	var heroes: Array = d.get("heroes", [])
	if not heroes.is_empty():
		var row := FlowUI.hbox(6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for h: Dictionary in heroes.slice(0, 4):
			row.add_child(_hero(h))
		v.add_child(row)
	var intro := String(d.get("intro", ""))
	if intro != "":
		v.add_child(FlowUI.para(intro, 250, Pal.INK9, HORIZONTAL_ALIGNMENT_CENTER))
	return v


## A guardian or the Crystal has no crest: a plain diamond mark in its colour instead.
func _monster_mark() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(52, 60)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crystal := _mode() == "crystal"
	c.draw.connect(func() -> void:
		var col := Pal.CRYSTAL4 if crystal else Pal.BLOOD3
		var hi := Pal.CRYSTAL5 if crystal else Pal.BLOOD4
		for y in 13:
			var half := 6 - absi(6 - y)
			for x in range(-half, half + 1):
				var p := Vector2(26 + x * 4 - 2, 4 + y * 4)
				c.draw_rect(Rect2(p + Vector2(0, 4), Vector2(4, 4)), Pal.INK1)
				c.draw_rect(Rect2(p, Vector2(4, 4)), hi if x < 0 and absi(x) < half else col))
	return c


func _hero(h: Dictionary) -> Control:
	var v := FlowUI.vbox(1)
	v.custom_minimum_size.x = 56
	var base := PartyModel.base_class(h)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(26, 26)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = load(String(EncounterDB.class_info(base).get("portrait", "res://assets/encounter/portraits/fighter.png")))
	var cc := Pal.c(String(EncounterDB.class_info(base).get("color", "ink8")))
	frame.draw.connect(func() -> void:
		frame.draw_rect(Rect2(0, 0, 26, 26), Pal.INK1)
		frame.draw_rect(Rect2(1, 1, 24, 24), Pal.INK3)
		frame.draw_texture(tex, Vector2(1, 1))
		frame.draw_rect(Rect2(1, 24, 24, 1), cc))
	holder.add_child(frame)
	v.add_child(holder)
	v.add_child(FlowUI.label(String(h.get("name", "")), &"HeaderLabel", null, 56, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(FlowUI.label("Lv %d" % int(h.get("level", 1)), &"MutedLabel", null, 56, HORIZONTAL_ALIGNMENT_CENTER))
	return v


func _layout() -> void:
	var fr := UIText.frame_rect(self)
	var cx := fr.position.x + 320.0
	_left.reset_size()
	_right.reset_size()
	var slide := clampf(1.0 - _t / 0.35, 0.0, 1.0)
	slide = slide * slide
	_left.position = Vector2(roundf(cx - 40 - 250 - slide * 120.0), 84)
	_right.position = Vector2(roundf(cx + 40 + slide * 120.0), 84)
	_vs.position = Vector2(cx - 30, 124)
	_hint.position = Vector2(cx - 100, 334)


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		_layout()
	_hint.modulate.a = 0.55 + 0.45 * absf(sin(_t * 2.0)) if _t > 1.0 else 0.0
	if _t >= float(AUTO.get(_mode(), 4.0)):
		finish()
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if _t < 0.6:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		finish()


func finish() -> void:
	if _done:
		return
	_done = true
	done.emit()
	if not demo:
		queue_free()
	else:
		_t = 0.0
		_done = false


func _draw() -> void:
	var view := get_viewport_rect()
	var fr := UIText.frame_rect(self)
	draw_rect(view, Pal.INK1)
	draw_texture(BACKDROP, fr.position + Vector2(-16 - 120, -16))
	var dim := Pal.INK1
	dim.a = 0.8
	draw_rect(view, dim)
	# a lit band behind the two names, warm on the player's side, cold on the rival's
	var band := Rect2(0, 76, view.size.x, 4)
	draw_rect(band, Pal.INK3)
	var cx := fr.position.x + 320.0
	draw_rect(Rect2(0, 78, cx, 1), Pal.AMBER3)
	draw_rect(Rect2(cx, 78, view.size.x - cx, 1), Pal.BLOOD3 if _mode() != "pvp" else Pal.CRYSTAL3)
	# a vertical rule under the VS
	draw_rect(Rect2(cx, 162, 1, 150), Pal.INK4)
