class_name RunHub
extends Control
## The camp between nodes of a run (playtest 1, user 2026-10-05: "a general menu between rounds"):
## a lantern-lit camp in the Vault, shown after every node's outcome and before the next node.
## It shows where the run stands (Vault, depth, floor, health), what the last node did, and the
## party; from here the player opens any hero's details, the formation, and Awakenings (a hero
## with enough memories wears a badge and an Awaken button; Awakening or Holding Back happens in
## the hero detail's advancement card). Continue goes on to the next node.
##
##   var s := RunHub.open(parent, run)          # run = core/run/run.gd, any step but draft/ended
##   s.proceed.connect(func(): ...)             # Continue
##   s.arrange.connect(func(): ...)             # Formation (review the party's placement)
##   s.awaken_chosen.connect(func(i): ...)      # Awaken hero i (the flow applies run.awaken(i))
##   s.hold_chosen.connect(func(i): ...)        # Hold Back hero i (run.hold_back(i))
##   s.refresh()                                # after the run changed
## The flow frees it. Standalone it plays a demo camp (`-- --demo=awaken` opens an Awakening).

signal proceed
signal arrange
signal awaken_chosen(index: int)
signal hold_chosen(index: int)

const SCENE := "res://scenes/flow/run_hub.tscn"
const BACKDROP := preload("res://assets/encounter/campfire/bg.png")
const Run = preload("res://core/run/run.gd")
const EchoPool = preload("res://core/run/echo_pool.gd")
const Rng = preload("res://core/rng.gd")
const HeroStats = preload("res://core/hero_stats.gd")
const TITLE := "Lantern Camp"
const CARD_W := 150
const CARD_H := 104
const CARD_GAP := 6
const PANEL_W := 360

var run: RefCounted = null
var view: Dictionary = {}
var demo := false
var detail: HeroDetail = null
var _opened := false
var _box: PanelContainer
var _status: Label
var _cards: Array[HubCard] = []
var _buttons: HBoxContainer
var _continue: Button
var _formation: Button
var _t := 0.0
var _demo_step := 0


static func open(parent: Node, r: RefCounted) -> RunHub:
	var s: RunHub = load(SCENE).instantiate()
	s._opened = true
	s.run = r
	parent.add_child(s)
	return s


## A run played by a simple driver to an outcome where a hero can Awaken (demo / captures): it
## recruits, levels the least-remembered hero and never Awakens on the way.
static func demo_run(seed_value := 21, min_party := 3) -> RefCounted:
	var pool: RefCounted = EchoPool.new()
	pool.seed_generated(1)
	var r: RefCounted = Run.new()
	r.call("start_run", seed_value, {"pool": pool, "save_echo": false, "log": false})
	for _i in 300:
		var v: Dictionary = r.call("current_node")
		match String(v["step"]):
			"draft":
				for o: Dictionary in v["offered"]:
					if not o["taken"]:
						r.call("choose", int(o["index"]))
						break
			"choice":
				var best := 0
				var score := -INF
				for c: Dictionary in v["choices"]:
					var hi := int(c["hero_index"])
					var sc := 50.0 if c.has("recruit") else (-float(v["party"][hi]["memories"]) if hi >= 0 else -9.0)
					if sc > score:
						score = sc
						best = int(c["index"])
				r.call("choose", best)
			"fight":
				r.call("resolve_fight")
			"outcome":
				var ready := false
				for h: Dictionary in v["party"]:
					ready = ready or bool(h.get("awaken_new", false))
				if ready and v["party"].size() >= min_party:
					return r
				r.call("advance")
			_:
				return r
	return r


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if run == null:
		demo = true
		run = demo_run()
	_build()
	get_viewport().size_changed.connect(_layout)
	refresh()


func _build() -> void:
	_box = FlowUI.panel(&"DimPanel")
	add_child(_box)
	_status = FlowUI.label("", &"GoldLabel", null, 620, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_status)
	_buttons = FlowUI.hbox(8)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_buttons)
	_formation = FlowUI.button("Formation", 104, 28)
	_formation.pressed.connect(func() -> void: arrange.emit())
	_buttons.add_child(_formation)
	_continue = FlowUI.primary("Continue", 128)
	_continue.pressed.connect(_on_continue)
	_buttons.add_child(_continue)


## Rebuilds from the run (after an Awakening, a Hold Back or a formation change).
func refresh() -> void:
	view = run.call("current_node")
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(FlowUI.margin(_outcome_box(), 10))
	for c: HubCard in _cards:
		c.queue_free()
	_cards.clear()
	var party: Array = view.get("party", [])
	for i in party.size():
		var card := HubCard.new()
		add_child(card)
		card.setup(party[i], i)
		card.pressed.connect(open_details.bind(i, false))
		card.awaken_pressed.connect(open_details.bind(i, true))
		_cards.append(card)
	if detail != null and is_instance_valid(detail):
		move_child(detail, -1)   # an Awakening refreshes the hub while the details stay open: keep them on top
	var ready: Array = []
	for h: Dictionary in party:
		if bool(h.get("awaken_new", false)):
			ready.append(String(h["name"]))
	if not ready.is_empty():
		_status.text = "%s can Awaken. Awaken into a new class, or Hold Back and keep growing." % _names(ready)
		_status.add_theme_color_override("font_color", UIText.legible(Pal.AMBER6))
	else:
		_status.text = "Tap a hero for details."
		_status.add_theme_color_override("font_color", UIText.legible(Pal.INK9))
	_continue.disabled = String(view.get("step", "")) != "outcome"
	_layout()


static func _names(a: Array) -> String:
	if a.size() == 1:
		return String(a[0])
	return ", ".join(a.slice(0, a.size() - 1)) + " and " + String(a[-1])


## What the last node did: a fight's result, or an encounter's gains (its screen told the story).
func _outcome_box() -> VBoxContainer:
	var v := FlowUI.vbox(3)
	v.custom_minimum_size.x = PANEL_W
	var last: Dictionary = view.get("last", {})
	var party: Array = view.get("party", [])
	var lines: Array = []
	if String(last.get("type", "")) == "fight":
		var f: Dictionary = last.get("fight", {})
		var won := bool(f.get("won", false))
		var kind := String(f.get("kind", ""))
		var head := FlowUI.label("Victory" if won else "Defeat", &"HeadingLabel", Pal.AMBER6 if won else Pal.BLOOD4, PANEL_W, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(head)
		var opp := String(f.get("opponent", ""))
		var what := FlowUI.fight_word(kind)
		lines.append([("%s: %s" % [what, opp]) if opp != "" else what, Pal.INK8])
		if not won and kind in ["guardian", "pvp", "monster"]:
			lines.append(["The party limps on: −%d health" % maxi(int(f.get("health_lost", 1)), 1), Pal.BLOOD4])
		if String(f.get("item", "")) != "":
			lines.append(["Found: %s" % RunEncounter.item_name(String(f["item"])), Pal.AMBER6])
		if f.has("fragments"):
			lines.append(["Fragments chipped from the Crystal: %d of 4" % int(f["fragments"]), Pal.CRYSTAL5])
	else:
		v.add_child(FlowUI.label("The lanterns are lit", &"HeadingLabel", null, PANEL_W, HORIZONTAL_ALIGNMENT_CENTER))
		if last.has("memory"):
			var m: Dictionary = last["memory"]
			var hi := int(m["hero_index"])
			if hi < party.size():
				lines.append([memory_line(party[hi], m), Pal.CRYSTAL5])
		if last.has("recruited") and int(last["recruited"]) < party.size():
			var r: Dictionary = party[int(last["recruited"])]
			lines.append(["%s the %s joined the party" % [r["name"], PartyModel.class_name_of(String(r["class"]))], Pal.LIFE4])
		if last.has("healed"):
			lines.append(["The party rested: +%d health" % int(last["healed"]), Pal.LIFE4])
		if String(last.get("item", "")) != "":
			lines.append(["Found: %s" % RunEncounter.item_name(String(last["item"])), Pal.AMBER6])
		if lines.is_empty():
			lines.append(["The party rests a moment before going deeper.", Pal.INK8])
	lines.append(["Health %d of %d" % [int(view.get("health", 0)), int(view.get("max_health", 0))], Pal.INK9])
	for l: Array in lines:
		if l[0] is Control:
			v.add_child(l[0])
		else:
			v.add_child(FlowUI.label(String(l[0]), &"GoldLabel", l[1], PANEL_W, HORIZONTAL_ALIGNMENT_CENTER))
	return v


## The camp's memory line, naming what the level gave: "Ilse absorbed a memory: Lv 2 → 3 · HP +10 ·
## Mag +2" (gains in green, the real compute() difference), or that a hero at its class's max level
## didn't level. `h` is the party_view hero now, `m` the run's memory result.
static func memory_line(h: Dictionary, m: Dictionary) -> Control:
	var before := int(m["level_before"])
	var after := int(m["level"])
	if after <= before:
		return FlowUI.gain_line("%s absorbed a memory: no level (Lv %d is a %s's max)" % [h["name"], after,
			PartyModel.class_name_of(String(h["class"]))], Pal.CRYSTAL5, {}, PANEL_W)
	return FlowUI.gain_line("%s absorbed a memory: Lv %d → %d" % [h["name"], before, after], Pal.CRYSTAL5,
		HeroStats.gain_between(_class_at_memory(h, after), before, after), PANEL_W)


## The hero as it was when the memory landed: an Awakening since (back to Lv 1 in a new class)
## means the levels were the base class's.
static func _class_at_memory(h: Dictionary, level_after: int) -> Dictionary:
	var o := h.duplicate()
	if int(h.get("level", 1)) != level_after and String(h.get("base", "")) != "":
		o["class"] = String(h["base"])
	return o


## Opens hero i's details (read-only but for Awakening); `awaken` opens the advancement card.
func open_details(i: int, awaken := false) -> void:
	if detail != null and is_instance_valid(detail):
		return
	Tip.close()
	var heroes: Array = []
	var codex: Array = []
	for h: Dictionary in view.get("party", []):
		heroes.append(detail_hero(h))
		if String(h.get("tier", "base")) != "base":
			codex.append(String(h["class"]))
	detail = HeroDetail.open(self, heroes, i, codex, {"depth": int(view.get("depth", 1)), "place": String(view.get("vault", ""))})
	detail.advanced.connect(func(k: int, _h: Dictionary) -> void: awaken_chosen.emit(k))
	detail.held_back.connect(func(k: int) -> void: hold_chosen.emit(k))
	detail.closed.connect(func() -> void:
		detail = null
		refresh())
	if awaken:
		detail.open_advancement()


## A run hero (core/run/run.gd party_view) in the hero detail screen's format.
static func detail_hero(h: Dictionary) -> Dictionary:
	var o := h.duplicate(true)
	o["memories"] = (h.get("trail", []) as Array).duplicate(true)
	o["memories_before"] = (h.get("trail_before", []) as Array).duplicate(true)
	o["held_back"] = bool(h.get("held", false))
	return o


func _on_continue() -> void:
	if _continue.disabled:
		return
	proceed.emit()


func _layout() -> void:
	var fr := UIText.frame_rect(self)
	var cx := fr.position.x + 320.0
	_box.reset_size()
	_box.position = Vector2(roundf(cx - _box.size.x / 2.0), 40)
	var n := _cards.size()
	var total := n * CARD_W + maxi(0, n - 1) * CARD_GAP
	var y := 192.0
	for k in n:
		_cards[k].position = Vector2(roundf(cx - total / 2.0) + k * (CARD_W + CARD_GAP), y)
	_status.size.x = 620
	_status.position = Vector2(roundf(cx - 310), y - 18)
	_buttons.reset_size()
	_buttons.position = Vector2(roundf(cx - _buttons.size.x / 2.0), 314)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if demo:
		_run_demo()


## Unattended demo: the camp; with --demo=awaken the first ready hero's Awakening opens at ~2 s.
func _run_demo() -> void:
	if not ("--demo=awaken" in OS.get_cmdline_user_args()) or _demo_step > 0 or _t < 2.0:
		return
	_demo_step = 1
	var party: Array = view.get("party", [])
	for i in party.size():
		if bool(party[i].get("awaken_new", false)):
			open_details(i, true)
			return


func _draw() -> void:
	var dim := Pal.INK1
	dim.a = 0.72
	UIFrame.backdrop(self, BACKDROP, dim)
	UIFrame.top_bar(self)
	var l := UIFrame.left(self)
	var r := UIFrame.right(self)
	PartyDraw.text(self, Vector2(l + 10, UIText.centered_y(0, 28, UIText.SERIF, UIText.TITLE)), TITLE, Pal.AMBER6, UIText.SERIF, UIText.TITLE)
	var tx := l + 18 + PartyDraw.text_w(TITLE, UIText.SERIF, UIText.TITLE)
	var where := "%s  ·  Depth %d  ·  Floor %d" % [String(view.get("vault", "The Vault")), int(view.get("depth", 1)), int(view.get("floor", 1))]
	var hx := FlowUI.draw_health(self, r - 8, 9, int(view.get("health", 0)), int(view.get("max_health", 0)))
	if tx + UIText.width(where, UIText.BOLD) > hx - 8:
		where = "Depth %d  ·  Floor %d" % [int(view.get("depth", 1)), int(view.get("floor", 1))]
	PartyDraw.text(self, Vector2(tx, UIText.centered_y(0, 28, UIText.BOLD)), where, Pal.INK9, UIText.BOLD)


## One hero at camp: portrait, name, class, level and memories toward Awakening; tap for details.
## A hero who can Awaken wears an amber frame and an Awaken button naming the class they'd become.
class HubCard extends Button:
	signal awaken_pressed

	var hero: Dictionary = {}
	var index := 0
	var _awaken: Button
	var _tex: Texture2D
	var _cc := Pal.INK8
	var _t := 0.0

	func setup(h: Dictionary, i: int) -> void:
		hero = h
		index = i
		theme_type_variation = &"ChoiceButton"
		focus_mode = Control.FOCUS_NONE
		text = ""
		custom_minimum_size = Vector2(RunHub.CARD_W, RunHub.CARD_H)
		size = custom_minimum_size
		var info := EncounterDB.class_info(String(h.get("base", h.get("class", ""))))
		_tex = load(String(info.get("portrait", "res://assets/encounter/portraits/fighter.png")))
		_cc = Pal.c(String(info.get("color", "ink8")))
		if bool(h.get("awaken_ready", false)):
			var to := PartyModel.class_name_of(String(h.get("awaken_class", "")))
			var label := "Awaken: %s" % to
			if UIText.width(label, UIText.BOLD, UIText.NUMBER) > RunHub.CARD_W - 24:
				label = "Awaken"
			_awaken = FlowUI.primary(label, RunHub.CARD_W - 12)
			_awaken.position = Vector2(6, RunHub.CARD_H - 34)
			_awaken.pressed.connect(func() -> void: awaken_pressed.emit())
			add_child(_awaken)
			var why := "%s has %d memories: Awakening turns them into a %s, the class of the region they stand in (level 1, a new ability). Or Hold Back to keep growing as a %s." % [
				h["name"], int(h.get("memories", 0)), to, PartyModel.class_name_of(String(h.get("base", "")))]
			Tip.attach(_awaken, "Awakening", why, Pal.AMBER6)

	func _process(delta: float) -> void:
		if bool(hero.get("awaken_new", false)):
			_t += delta
			queue_redraw()

	func _draw() -> void:
		# portrait at 2x in a class-coloured frame
		draw_rect(Rect2(6, 6, 52, 52), Pal.INK1)
		draw_rect(Rect2(7, 7, 50, 50), Pal.INK3)
		draw_texture_rect(_tex, Rect2(8, 8, 48, 48), false)
		draw_rect(Rect2(7, 55, 50, 2), _cc)
		var x := 64.0
		PartyDraw.text(self, Vector2(x, 6), String(hero.get("name", "")), _cc, UIText.BOLD, UIText.BODY, true, RunHub.CARD_W - x - 6)
		var cls := PartyModel.class_name_of(String(hero.get("class", "")))
		PartyDraw.text(self, Vector2(x, 19), UIText.fit(cls, RunHub.CARD_W - x - 6, UIText.BOLD), Pal.INK9, UIText.BOLD)
		var tier := String(hero.get("tier", "base"))
		PartyDraw.text(self, Vector2(x, 32), "Lv %d" % int(hero.get("level", 1)), Pal.INK10, UIText.BOLD)
		if tier == "base":
			# memory pips toward Awakening
			var thr := PartyModel.threshold()
			var mem := int(hero.get("memories", 0))
			var px := x + 30.0
			for i in thr:
				var r := Rect2(px + i * 9, 35, 7, 7)
				draw_rect(r, Pal.INK1)
				draw_rect(r.grow(-1), Pal.CRYSTAL4 if i < mem else Pal.INK4)
			var note := ""
			if bool(hero.get("awaken_ready", false)):
				note = "Held back" if bool(hero.get("held", false)) and not bool(hero.get("awaken_new", false)) else "Can Awaken"
			else:
				var left := thr - mem
				note = "%d more to Awaken" % left
			PartyDraw.text(self, Vector2(x, 45), note, Pal.AMBER6 if note == "Can Awaken" else Pal.INK8, UIText.BOLD)
		else:
			PartyDraw.text(self, Vector2(x, 45), "Legendary" if tier == "legendary" else "Awakened", Pal.AMBER6, UIText.BOLD)
		if _awaken == null:
			PartyDraw.text(self, Vector2(6, RunHub.CARD_H - 22), "Details", Pal.INK8, UIText.BOLD, UIText.BODY, true, RunHub.CARD_W - 12, HORIZONTAL_ALIGNMENT_CENTER)
		# the badge: an amber frame that breathes while a hero can Awaken (and hasn't answered)
		if bool(hero.get("awaken_new", false)):
			var a := 0.65 + 0.35 * sin(_t * 3.0)
			var c := Pal.AMBER5
			c.a = a
			PartyDraw.outline(self, Rect2(Vector2(1, 1), size - Vector2(2, 2)), c)
			PartyDraw.tint_tex(self, PartyDraw.icon("res://ui/icons/arrow2_up.png"), Vector2(RunHub.CARD_W - 14, 6), Pal.AMBER6)
