class_name HeroDetail
extends Control
## Hero detail / alignment screen, opened mid-run to understand one hero and the party's growth.
##
## Open from another screen:
##   var screen := HeroDetail.open(self, party, 0, codex, {"depth": 4, "place": "The Drowned Archive"})
##   screen.advanced.connect(func(i, hero): ...)   # hero = the new dictionary (class, level 1)
##   screen.held_back.connect(func(i): ...)
##   screen.codex_recorded.connect(func(class_id): ...)
##   screen.closed.connect(...)                     # the screen frees itself after emitting
## party: 1-4 hero dictionaries in the core format (core/README.md) plus optional
##   "memories" ([[d_good, d_law], ...] in order absorbed, draws the trail) and "held_back".
## codex: advanced class ids the player has already reached (others show "???").
## Run standalone (no open()), it plays an unattended demo for captures.

signal advanced(index: int, hero: Dictionary)
signal held_back(index: int)
signal codex_recorded(class_id: String)
signal closed

const SCENE := "res://scenes/party/hero_detail.tscn"
const BACKDROP := preload("res://assets/encounter/colossus/bg.png")

var party: Array = []
var codex: Array = []
var run_info := {"depth": 4, "place": "The Drowned Archive"}
var index := 0
var demo := false

var _tabs: Array[PartyTab] = []
var _card: HeroCard
var _adv: AdvanceCard
var _align: AlignPanel
var _close: Button
var _message := ""
var _message_override := ""
var _t := 0.0
var _demo_step := 0
var _opened_by_api := false


static func open(parent: Node, heroes: Array, start_index := 0, codex_ids: Array = [], run := {}) -> HeroDetail:
	var s: HeroDetail = load(SCENE).instantiate()
	s._opened_by_api = true
	s.party = []
	for h: Dictionary in heroes.slice(0, 4):
		s.party.append(PartyModel.normalize(h))
	s.codex = codex_ids.duplicate()
	if not run.is_empty():
		s.run_info = run
	s.index = clampi(start_index, 0, maxi(s.party.size() - 1, 0))
	parent.add_child(s)
	return s


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _opened_by_api and party.is_empty():
		demo = true
		var d := demo_data()
		party = []
		for h: Dictionary in d["party"]:
			party.append(PartyModel.normalize(h))
		codex = d["codex"]
	_build()
	select(index)


func _build() -> void:
	for i in party.size():
		var tab := PartyTab.new()
		tab.position = Vector2(8 + i * (PartyTab.W + 4), 4)
		tab.pressed.connect(select.bind(i))
		add_child(tab)
		_tabs.append(tab)
	_card = HeroCard.new()
	_card.position = Vector2(8, 38)
	add_child(_card)
	_card.advance_pressed.connect(open_advancement)
	_adv = AdvanceCard.new()
	_adv.position = Vector2(8, 38)
	_adv.visible = false
	add_child(_adv)
	_adv.advance_chosen.connect(_on_advance)
	_adv.hold_chosen.connect(_on_hold)
	_align = AlignPanel.new()
	_align.position = Vector2(242, 38)
	add_child(_align)
	_align.cell_tapped.connect(_on_cell)
	_close = Button.new()
	_close.text = "Close"
	_close.focus_mode = Control.FOCUS_NONE
	_close.position = Vector2(582, 337)
	_close.size = Vector2(46, 18)
	_close.pressed.connect(close)
	add_child(_close)


## Shows hero i (party row tap).
func select(i: int) -> void:
	if party.is_empty():
		return
	index = clampi(i, 0, party.size() - 1)
	if _adv.visible:
		_close_advancement(false)
	for k in _tabs.size():
		_tabs[k].setup(party[k])
		_tabs[k].is_selected = k == index
	var h: Dictionary = party[index]
	_card.set_hero(h)
	var info := EncounterDB.class_info(PartyModel.base_class(h))
	_align.set_hero(h, load(info["portrait"]), Pal.c(info["color"]), _region_names(h))
	_message_override = ""
	_message = _describe(h)
	queue_redraw()


## Region -> the class name shown on the grid ("???" while that class is not in the codex),
## built the way the advancement card names corners.
func _region_names(h: Dictionary) -> Dictionary:
	var out := {}
	var base := PartyModel.base_class(h)
	for reg: String in PartyModel.REGION_ORDER:
		var id := PartyModel.class_for_region(base, reg)
		out[reg] = PartyModel.class_name_of(id) if id != "" and id in codex else "???"
	return out


func current() -> Dictionary:
	return party[index] if not party.is_empty() else {}


func open_advancement() -> void:
	var h := current()
	if not PartyModel.ready_to_advance(h):
		return
	_adv.set_hero(h, codex)
	_adv.set_focus(0)
	_adv.visible = true
	_adv.position.x = -230
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _adv.position.x = roundf(v), -230.0, 8.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_card.visible = false
	var target := PartyModel.region_of(PartyModel.effective(h))
	_align.grid.focus_region = target
	var reach := AdvanceCard.hold_reach(h)
	_align.grid.reach_cell = reach["cell"] if not reach.is_empty() else null
	_message_override = "Advance sets the class from where %s stands now. Holding back keeps the path open." % h["name"]
	queue_redraw()


func _close_advancement(_animate := true) -> void:
	_adv.visible = false
	_card.visible = true
	_align.grid.focus_region = ""
	_align.grid.reach_cell = null


func _on_advance() -> void:
	var h := current()
	var id := PartyModel.advance_target(h)
	if id == "":
		return
	var is_new := not (id in codex)
	var nh := PartyModel.advanced_copy(h)
	party[index] = nh
	if is_new:
		codex.append(id)
		codex_recorded.emit(id)
	_close_advancement()
	select(index)
	_align.grid.new_regions = [PartyModel.region_of(PartyModel.effective(nh))] if is_new else []
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _align.grid.reveal = v, 1.0, 0.0, 0.6)
	_message_override = "%s advanced to %s.%s" % [nh["name"], PartyModel.class_name_of(id),
		" A new path is recorded in the codex." if is_new else ""]
	advanced.emit(index, nh)


func _on_hold() -> void:
	var h := current()
	h["held_back"] = true
	_close_advancement()
	select(index)
	_message_override = "%s holds back: still a %s, still travelling the grid." % [h["name"], PartyModel.class_name_of(String(h["class"]))]
	held_back.emit(index)


func close() -> void:
	closed.emit()
	if not demo:
		queue_free()


func _on_cell(p: Array) -> void:
	var h := current()
	var region := PartyModel.region_of(p)
	var base := PartyModel.base_class(h)
	var id := PartyModel.class_for_region(base, region)
	var nm := PartyModel.class_name_of(id) if id != "" and id in codex else "???"
	var d := PartyModel.steps(PartyModel.start_of(h), p)
	var words := PartyModel.region_words(region)
	if region.ends_with("*"):
		words = "Corner of " + words
	var lean := PartyModel.lean_of(p)
	_message_override = "%s: %s%s. %d step%s from the %s start." % [words, nm,
		(" (%s)" % lean) if lean != "" and region != "N" else "", d, "" if d == 1 else "s", PartyModel.class_name_of(base)]
	queue_redraw()


func _describe(h: Dictionary) -> String:
	var name := String(h["name"])
	if PartyModel.tier(h) != "base":
		return "%s walks the path of the %s. Legendary needs a sacrifice." % [name, PartyModel.class_name_of(String(h["class"]))]
	if PartyModel.ready_to_advance(h):
		if h.get("held_back", false):
			return "%s is held back, still travelling. They can advance at any rest." % name
		return "%s has gathered %d memories. Advance now, or hold back to travel farther." % [name, PartyModel.memory_count(h)]
	var off := PartyModel.relic_offset(h)
	var left := PartyModel.threshold() - PartyModel.memory_count(h)
	if off != [0, 0]:
		var relic := PartyModel.item(String(h["items"].get("relic", "")))
		var id := PartyModel.advance_target(h)
		var ground := PartyModel.class_name_of(id) if id != "" and id in codex else "unknown"
		return "%s's %s is bound and holds them %s off their memories' path, on %s ground." % [name, relic.get("name", "Relic"),
			"a step" if absi(int(off[0])) + absi(int(off[1])) == 1 else "two steps", ground]
	return "%s needs %d more memor%s to set their path." % [name, left, "y" if left == 1 else "ies"]


func _process(delta: float) -> void:
	_t += delta
	if demo:
		_run_demo()
	queue_redraw()


## Unattended demo: ~60 Ilse at rest, ~240 Brannoc (at threshold), ~420 advancement prompt,
## ~600 after Advancing (Paladin recorded in the codex).
func _run_demo() -> void:
	var f := roundi(_t * 60.0)
	match _demo_step:
		0:
			if f >= 140:
				_on_cell([1, 1])
				_demo_step = 1
		1:
			if f >= 180:
				select(1)
				_demo_step = 2
		2:
			if f >= 300:
				open_advancement()
				_demo_step = 3
		3:
			if f >= 440 and _demo_hold():
				_adv.set_focus(1)
			if f >= 490:
				_demo_button().button_pressed = true
				_demo_step = 4
		4:
			if f >= 500:
				_demo_button().button_pressed = false
				if _demo_hold():
					_on_hold()
				else:
					_on_advance()
				_demo_step = 5


## `-- --demo=hold` makes the demo choose Hold Back instead of Advance.
func _demo_hold() -> bool:
	return "--demo=hold" in OS.get_cmdline_user_args()


func _demo_button() -> Button:
	return _adv._btn_hold if _demo_hold() else _adv._btn_adv


func _draw() -> void:
	# the run behind the menu, dimmed
	draw_texture(BACKDROP, Vector2.ZERO)
	var dim := Pal.INK1
	dim.a = 0.82
	draw_rect(Rect2(0, 0, 640, 360), dim)
	# run box (top right)
	var rb := Rect2(474, 4, 158, 30)
	PartyDraw.panel(self, rb, 0, &"DimPanel")
	PartyDraw.text(self, Vector2(rb.position.x + 8, 7), String(run_info.get("place", "")), Pal.INK8)
	PartyDraw.text(self, Vector2(rb.position.x + 8, 18), "Depth %d" % int(run_info.get("depth", 1)), Pal.AMBER6, PartyDraw.BOLD)
	var ready := 0
	for h: Dictionary in party:
		if PartyModel.ready_to_advance(h) and not h.get("held_back", false):
			ready += 1
	if ready > 0:
		var t := "%d ready" % ready
		PartyDraw.text(self, Vector2(rb.position.x, 18), t, Pal.AMBER5, PartyDraw.SANS, PartyDraw.SANS_SIZE, true, rb.size.x - 8, HORIZONTAL_ALIGNMENT_RIGHT)
	# description bar (bottom)
	var bb := Rect2(8, 336, 570, 20)
	draw_rect(bb.grow(-1), Pal.INK2)
	PartyDraw.soft_outline(self, bb, Pal.INK5)
	draw_rect(Rect2(bb.position.x + 2, bb.position.y + 1, bb.size.x - 4, 1), Pal.INK3)
	var msg := _message_override if _message_override != "" else _message
	PartyDraw.text(self, Vector2(bb.position.x + 8, bb.position.y + 5), msg, Pal.INK9)


## Sample party mid-run: Ilse wears a bound Relic (effective != underlying), Brannoc sits at the
## advancement threshold, Vesper and Kett are on their way.
static func demo_data() -> Dictionary:
	return {
		"party": [
			{"name": "Ilse", "class": "healer", "level": 3,
				"items": {"weapon": "lantern_mace", "armor": "silk_robe", "relic": "dawn_locket"},
				"memories": [[-1, 0], [0, 1]], "alignment": [0, 2]},
			{"name": "Brannoc", "class": "fighter", "level": 4,
				"items": {"weapon": "iron_sword", "armor": "chain_mail", "relic": ""},
				"memories": [[0, -1], [1, 1], [0, 1]], "alignment": [1, 2]},
			{"name": "Vesper", "class": "mage", "level": 3,
				"items": {"weapon": "crystal_wand", "armor": "silk_robe", "relic": ""},
				"memories": [[0, -1], [-1, 0]], "alignment": [0, -2]},
			{"name": "Kett", "class": "rogue", "level": 2,
				"items": {"weapon": "twin_daggers", "armor": "shadow_cloak", "relic": "wild_feather"},
				"memories": [[1, 0]], "alignment": [0, -1]},
		],
		"codex": ["cleric", "archmage", "berserker", "duelist"],
	}
