class_name RoadScreen
extends Control
## The pause between nodes of a run: what the last fight did (won or lost, health, an item, the
## Crystal's fragments), or a hero's advancement decision (Advance / Hold back). The party strip
## along the bottom shows every hero's class, level and memories.
##
##   var s := RoadScreen.open(parent, run.current_node())     # step "outcome" or "decision"
##   s.proceed.connect(func(): ...)            # Continue (outcome)
##   s.decided.connect(func(i): ...)           # 0 Advance / 1 Hold back (decision)
##   s.arrange.connect(func(): ...)            # Formation (review the party's placement)
## The flow frees it. Standalone it shows a demo outcome (--mode=decision for a decision).

signal proceed
signal decided(choice: int)
signal arrange

const SCENE := "res://scenes/flow/road.tscn"
const BACKDROP := preload("res://assets/encounter/hound/bg.png")

var view: Dictionary = {}
var demo := false
var _opened := false
var _box: PanelContainer
var _strip: HBoxContainer
var _buttons: HBoxContainer
var _head: Label


static func open(parent: Node, v: Dictionary) -> RoadScreen:
	var s: RoadScreen = load(SCENE).instantiate()
	s._opened = true
	s.view = v
	parent.add_child(s)
	return s


static func demo_view(mode := "outcome") -> Dictionary:
	var party := [
		{"name": "Brannoc", "class": "fighter", "base": "fighter", "level": 3, "memories": 3, "max_level": 6, "alignment": [0, 1]},
		{"name": "Ilse", "class": "healer", "base": "healer", "level": 2, "memories": 2, "max_level": 6, "alignment": [1, 1]},
		{"name": "Sable", "class": "rogue", "base": "rogue", "level": 2, "memories": 1, "max_level": 6, "alignment": [-1, -1]}]
	var v := {"step": mode, "depth": 9, "floor": 2, "vault": "The Drowned Archive", "health": 8, "max_health": 10, "party": party}
	if mode == "decision":
		v["type"] = "advance"
		v["hero_index"] = 0
		v["hero_name"] = "Brannoc"
	else:
		v["last"] = {"type": "fight", "health": 8, "fight": {"won": true, "kind": "pvp", "opponent": "The Ashen Vow",
			"health": 8, "ended": false}}
	return v


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if view.is_empty():
		demo = true
		var mode := "outcome"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--mode="):
				mode = a.substr(7)
		view = demo_view(mode)
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build() -> void:
	_box = FlowUI.panel()
	var v := FlowUI.vbox(6)
	v.custom_minimum_size.x = 340
	_head = FlowUI.label("", &"HeadingLabel", null, 340, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_head)
	_buttons = FlowUI.hbox(8)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	if String(view.get("step", "")) == "decision":
		_build_decision(v)
	else:
		_build_outcome(v)
	v.add_child(_buttons)
	_box.add_child(FlowUI.margin(v, 12))
	add_child(_box)
	_strip = FlowUI.hbox(8)
	for h: Dictionary in view.get("party", []):
		_strip.add_child(_hero_card(h))
	add_child(_strip)


func _build_outcome(v: VBoxContainer) -> void:
	var last: Dictionary = view.get("last", {})
	var f: Dictionary = last.get("fight", {})
	var won := bool(f.get("won", false))
	var kind := String(f.get("kind", ""))
	_head.text = "Victory" if won else "Defeat"
	_head.add_theme_color_override("font_color", Pal.AMBER6 if won else Pal.BLOOD4)
	var opp := String(f.get("opponent", ""))
	var what := FlowUI.fight_word(kind)
	var line := ("%s: %s" % [what, opp]) if opp != "" else what
	v.add_child(FlowUI.label(line, &"MutedLabel", null, 340, HORIZONTAL_ALIGNMENT_CENTER))
	var lines: Array = []
	if not won:
		var lost := int(f.get("health_lost", 1 if kind != "crystal" else 0))
		if kind == "guardian" or kind == "pvp" or kind == "monster":
			lines.append(["The party limps on: −%d health" % maxi(lost, 1), Pal.BLOOD4])
	if String(f.get("item", "")) != "":
		lines.append(["Found: %s" % RunEncounter.item_name(String(f["item"])), Pal.AMBER6])
	if f.has("fragments"):
		lines.append(["Fragments chipped from the Crystal: %d of 4" % int(f["fragments"]), Pal.CRYSTAL5])
	lines.append(["Health %d of %d" % [int(view.get("health", 0)), int(view.get("max_health", 0))], Pal.INK9])
	for l: Array in lines:
		v.add_child(FlowUI.label(String(l[0]), &"GoldLabel", l[1], 340, HORIZONTAL_ALIGNMENT_CENTER))
	var form := FlowUI.button("Formation", 96, 22)
	form.pressed.connect(func() -> void: arrange.emit())
	_buttons.add_child(form)
	var go := FlowUI.primary("Continue", 112)
	go.pressed.connect(func() -> void: proceed.emit())
	_buttons.add_child(go)


func _build_decision(v: VBoxContainer) -> void:
	var party: Array = view.get("party", [])
	var hi := int(view.get("hero_index", 0))
	var h: Dictionary = party[hi] if hi < party.size() else {}
	var nm := String(view.get("hero_name", h.get("name", "")))
	var base := PartyModel.class_name_of(String(h.get("base", h.get("class", ""))))
	_head.text = "%s can advance" % nm
	v.add_child(FlowUI.para(("%s has gathered %d memories. Advance now to take the class of the region where %s stands on the alignment grid (level resets to 1, with new strengths). Or hold back and keep growing as a %s, up to level %d; you will be asked again after the next memory.") % [
		nm, int(h.get("memories", 3)), nm, base, int(h.get("max_level", 6))], 340, Pal.INK9, HORIZONTAL_ALIGNMENT_CENTER))
	var adv := FlowUI.primary("Advance", 118)
	adv.pressed.connect(func() -> void: decided.emit(0))
	_buttons.add_child(adv)
	var hold := FlowUI.button("Hold back", 110, 24)
	hold.pressed.connect(func() -> void: decided.emit(1))
	_buttons.add_child(hold)


func _hero_card(h: Dictionary) -> Control:
	var p := FlowUI.panel(&"DimPanel")
	var row := FlowUI.hbox(6)
	var base := String(h.get("base", PartyModel.base_class(h)))
	var info := EncounterDB.class_info(base)
	var tex: Texture2D = load(String(info.get("portrait", "res://assets/encounter/portraits/fighter.png")))
	var cc := Pal.c(String(info.get("color", "ink8")))
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(26, 26)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		frame.draw_rect(Rect2(0, 0, 26, 26), Pal.INK1)
		frame.draw_rect(Rect2(1, 1, 24, 24), Pal.INK3)
		frame.draw_texture(tex, Vector2(1, 1))
		frame.draw_rect(Rect2(1, 24, 24, 1), cc))
	row.add_child(frame)
	var col := FlowUI.vbox(0)
	col.add_child(FlowUI.label(String(h.get("name", "")), &"HeaderLabel", cc))
	col.add_child(FlowUI.label(PartyModel.class_name_of(String(h.get("class", ""))), &"MutedLabel"))
	col.add_child(FlowUI.label("Lv %d  ·  %d memor%s" % [int(h.get("level", 1)), int(h.get("memories", 0)), "y" if int(h.get("memories", 0)) == 1 else "ies"], &"MutedLabel"))
	row.add_child(col)
	p.add_child(FlowUI.margin(row, 4))
	return p


func _layout() -> void:
	var fr := UIText.frame_rect(self)
	var cx := fr.position.x + 320.0
	_box.reset_size()
	_box.position = Vector2(roundf(cx - _box.size.x / 2.0), roundf(maxf(40.0, 40 + (230 - _box.size.y) / 2.0)))
	_strip.reset_size()
	_strip.position = Vector2(roundf(cx - _strip.size.x / 2.0), 284)
	queue_redraw()


func _draw() -> void:
	var dim := Pal.INK1
	dim.a = 0.8
	UIFrame.backdrop(self, BACKDROP, dim)
	UIFrame.top_bar(self)
	var l := UIFrame.left(self)
	var r := UIFrame.right(self)
	var title := String(view.get("vault", "The Vault"))
	PartyDraw.text(self, Vector2(l + 10, UIText.centered_y(0, 28, UIText.SERIF, UIText.TITLE)), title, Pal.AMBER6, UIText.SERIF, UIText.TITLE)
	var tx := l + 18 + PartyDraw.text_w(title, UIText.SERIF, UIText.TITLE)
	PartyDraw.text(self, Vector2(tx, UIText.centered_y(0, 28, UIText.BOLD)), "Depth %d  ·  Floor %d" % [int(view.get("depth", 1)), int(view.get("floor", 1))], Pal.INK9, UIText.BOLD)
	FlowUI.draw_health(self, r - 8, 9, int(view.get("health", 0)), int(view.get("max_health", 0)))
