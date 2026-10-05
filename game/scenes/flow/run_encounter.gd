class_name RunEncounter
extends Control
## The run's encounter node, driven by the run layer (core/run/run.gd, step "choice"): the
## painting, the title and prose, and the run's own choices in its order (choices bound to heroes
## use the encounter screen's EncounterChoiceButton; a party-wide rest is a plain button). The
## run decides the outcome (memory, shift, luck, recruit, item, lore); this screen shows it and
## waits for Continue. Pool encounters without a painting borrow an authored backdrop of their kind.
##
##   var s := RunEncounter.open(parent, run)
##   s.chosen.connect(func(index, res): ...)   # after run.choose(index)
##   s.finished.connect(func(): ...)           # Continue; the screen frees itself
## Standalone it plays a demo node from a seeded run (picks the first choice after 3 s).

signal chosen(index: int, res: Dictionary)
signal finished

const SCENE := "res://scenes/flow/run_encounter.tscn"
const Catalog = preload("res://core/run/encounter_catalog.gd")
const Run = preload("res://core/run/run.gd")
const RunBot = preload("res://core/run/run_bot.gd")
const Rng = preload("res://core/rng.gd")
const EchoPool = preload("res://core/run/echo_pool.gd")
const COL_W := 276   # the encounter screen's column: 24 px clear of the frame's right edge
const FALLBACK_ART := {"riddle": "colossus", "chance": "odds", "moral": "hollowmere", "monster": "hound",
	"recruitment": "campfire", "legend": "colossus"}
const ITEMS := preload("res://core/data/items.gd")

var run: RefCounted = null
var demo := false
var node: Dictionary = {}
var _opened := false
var _art: EncounterArt
var _col: VBoxContainer
var _body: RichTextLabel
var _choices: VBoxContainer
var _result: VBoxContainer
var _continue: Button
var _bar: PanelContainer
var _chips: Array = []
var _where: Label
var _done := false
var _t := 0.0
var _over: Control


static func open(parent: Node, r: RefCounted) -> RunEncounter:
	var s: RunEncounter = load(SCENE).instantiate()
	s._opened = true
	s.run = r
	parent.add_child(s)
	return s


## A run advanced by the bot to its first encounter node with at least two heroes (demo/captures).
static func demo_run(seed_value := 11, depth := 4) -> RefCounted:
	var pool: RefCounted = EchoPool.new()
	pool.path = "user://_unused_demo_pool.json"
	pool.seed_generated(1)
	var r: RefCounted = Run.new()
	r.call("start_run", seed_value, {"pool": pool, "save_echo": false})
	var rng := Rng.new(seed_value)
	for _i in 300:
		var v: Dictionary = r.call("current_node")
		if String(v["step"]) == "choice" and int(v["depth"]) >= depth:
			break
		RunBot.step(r, rng, "greedy", 0.0)
	return r


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if run == null:
		demo = true
		var depth := 4
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--depth="):
				depth = int(a.substr(8))
		run = demo_run(11, depth)
	node = run.call("current_node")
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _art_for(enc: Dictionary, kind: String) -> Dictionary:
	var art: Dictionary = enc.get("art", {})
	if not art.is_empty() and String(art.get("dir", "")) != "":
		return art
	var dir := String(FALLBACK_ART.get(kind, "colossus"))
	return {"dir": "res://assets/encounter/%s/" % dir, "bg": "bg.png"}


func _build() -> void:
	var kind := String(node.get("kind", "riddle"))
	var enc: Dictionary = Catalog.get_encounter(String(node.get("encounter_id", "")))
	_art = EncounterArt.new()
	add_child(_art)
	_art.setup(_art_for(enc, kind))
	# top bar: the party (chips), where we are, health
	_bar = FlowUI.panel(&"TopBar")
	add_child(_bar)
	# the column's plate and the health hearts, above the painting and the bar
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	_build_chips()
	_where = FlowUI.label("", &"MutedLabel", null, 200)
	add_child(_where)
	# the column: tag, title, prose, choices
	_col = FlowUI.vbox(6)
	_col.custom_minimum_size.x = COL_W
	add_child(_col)
	var info := EncounterDB.kind_info(kind)
	var kc := Pal.c(String(info.get("color", "amber6")))
	var tag := FlowUI.label(String(info.get("label", "Legend's memory" if kind == "legend" else kind)).to_upper(),
		&"TagLabel", kc, COL_W, HORIZONTAL_ALIGNMENT_CENTER)
	_col.add_child(tag)
	var title := FlowUI.label(String(node.get("title", "")), &"HeadingLabel", null, COL_W, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.custom_minimum_size = Vector2(COL_W, 0)
	_body.add_theme_font_override("normal_font", UIText.BOLD)
	_body.text = "[center]" + EncounterDB.markup(UIText.curly(String(node.get("text", "")))) + "[/center]"
	_col.add_child(_body)
	_choices = FlowUI.vbox(5)
	_col.add_child(_choices)
	var party: Array = node.get("party", [])
	for c: Dictionary in node.get("choices", []):
		var i := int(c["index"])
		var hi := int(c.get("hero_index", -1))
		if hi < 0 or c.has("rest"):
			var b := FlowUI.button("%s  (+%d health, no memory)" % [String(c.get("label", "Rest")), int(c.get("rest", 1))], COL_W, 26)
			b.pressed.connect(choose.bind(i))
			_choices.add_child(b)
			continue
		var btn := EncounterChoiceButton.new()
		_choices.add_child(btn)
		btn.setup(_choice_for_button(c), _hero_for_button(party[hi]), hi, COL_W)
		btn.pressed.connect(choose.bind(i))
	_result = FlowUI.vbox(3)
	_result.visible = false
	_col.add_child(_result)
	_continue = FlowUI.primary("Continue", 120)
	_continue.visible = false
	_continue.pressed.connect(_on_continue)
	_col.add_child(_continue)
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _build_chips() -> void:
	for c: Node in _chips:
		c.queue_free()
	_chips.clear()
	for h: Dictionary in (run.call("current_node") as Dictionary).get("party", []):
		var chip := HeroChip.new()
		add_child(chip)
		chip.setup(_hero_for_button(h))
		_chips.append(chip)


## The encounter screen's hero format: base class (portrait, colour), level, grid position.
static func _hero_for_button(h: Dictionary) -> Dictionary:
	var al: Array = h.get("alignment", [0, 0])
	return {"name": h.get("name", ""), "class": String(h.get("base", h.get("class", ""))),
		"level": int(h.get("level", 1)), "pos": Vector2i(int(al[0]), int(al[1]))}


## The run's choice view in the encounter screen's format (shift as {good, law}).
static func _choice_for_button(c: Dictionary) -> Dictionary:
	var s: Array = c.get("shift", [0, 0])
	var out := {"id": c.get("id", ""), "class": c.get("class", ""), "label": c.get("label", ""),
		"shift": {"good": int(s[0]), "law": int(s[1])}}
	if c.has("recruit"):
		out["recruit"] = {"name": "a " + PartyModel.class_name_of(String(c["recruit"]))}
	return out


## Applies choice i through the run and shows what happened.
func choose(i: int) -> void:
	if _done:
		return
	_done = true
	var before_party: Array = node.get("party", [])
	var picked: Dictionary = {}
	for c: Dictionary in node.get("choices", []):
		if int(c["index"]) == i:
			picked = c
	var res: Dictionary = run.call("choose", i)
	_choices.visible = false
	var after: Dictionary = run.call("current_node")
	_body.text = "[center]" + EncounterDB.markup(UIText.curly(String(res.get("text", "")))) + "[/center]"
	# the memory on the encounter screen's designed result card (critic r5: plain centred lines here
	# and a card there were two visual languages for one moment)
	var card: EncounterResultCard = null
	if res.has("memory"):
		var m: Dictionary = res["memory"]
		var hi := int(m["hero_index"])
		var party_after: Array = after.get("party", [])
		if hi < before_party.size() and hi < party_after.size():
			card = EncounterResultCard.new()
			card.setup(_hero_for_button(party_after[hi]), _hero_for_button(before_party[hi]), _choice_for_button(picked), COL_W)
			_result.add_child(card)
	for line: Array in _result_lines(res, after, card != null):
		_result.add_child(FlowUI.label(String(line[0]), &"GoldLabel", line[1], COL_W, HORIZONTAL_ALIGNMENT_CENTER))
	_result.visible = true
	_continue.visible = true
	_build_chips()
	_layout()
	if card != null:
		card.play(0.3)
	chosen.emit(i, res)


## Plain result lines with a colour each.
func _result_lines(res: Dictionary, after: Dictionary, on_card := false) -> Array:
	var out: Array = []
	var party: Array = after.get("party", [])
	if res.has("memory") and on_card and res.get("luck", false):
		out.append(["It turned out differently.", Pal.INK9])
	if res.has("memory") and not on_card:
		var m: Dictionary = res["memory"]
		var h: Dictionary = party[int(m["hero_index"])]
		var lv := "Level %d → %d" % [int(m["level_before"]), int(m["level"])] if int(m["level"]) > int(m["level_before"]) \
			else "Level %d (at its cap)" % int(m["level"])
		out.append(["%s absorbs a memory.  %s" % [h["name"], lv], Pal.CRYSTAL5])
		var sh: Array = m.get("shift", [0, 0])
		var words := EncounterDB.shift_words(Vector2i(int(sh[0]), int(sh[1])))
		var parts: Array = []
		for w: Dictionary in words:
			parts.append("%s +%d" % [w["word"], w["amount"]])
		if not parts.is_empty():
			out.append([("Turned out differently: " if res.get("luck", false) else "") + ", ".join(parts), Pal.INK9])
	if res.has("legendary"):
		out.append(["A legend wakes: %s" % PartyModel.class_name_of(String(res["legendary"])), Pal.AMBER6])
	if res.has("healed"):
		out.append(["The party rests: +%d health" % int(res["healed"]), Pal.LIFE4])
	if res.has("recruited"):
		var r: Dictionary = party[int(res["recruited"])]
		out.append(["%s the %s joins the party" % [r["name"], PartyModel.class_name_of(String(r["class"]))], Pal.LIFE4])
	if String(res.get("item", "")) != "":
		out.append(["Found: %s" % item_name(String(res["item"])), Pal.AMBER6])
	if res.has("lore"):
		out.append(["Found: %s" % String(res["lore"]).replace("_", " ").capitalize(), Pal.VIOLET4])
	match String(after.get("step", "")):
		"fight":
			out.append(["A fight! Arrange your party next.", Pal.BLOOD4])
		"decision":
			out.append(["%s is ready to advance." % String(after.get("hero_name", "")), Pal.AMBER6])
	return out


static func item_name(id: String) -> String:
	var def: Dictionary = ITEMS.ITEMS.get(id, {})
	return String(def.get("name", id.replace("_", " ").capitalize()))


func _on_continue() -> void:
	finished.emit()
	if _opened:
		queue_free()


func _layout() -> void:
	var fr := UIText.frame_rect(self)
	var fx := fr.position.x
	var vw := get_viewport_rect().size.x
	_art.position.x = fx
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(vw, 32)
	var l := roundf(UIFrame.left(self))
	for k in _chips.size():
		(_chips[k] as Control).position = Vector2(l + 4 + k * (HeroChip.W + 4), 2)
	# where we are, top right in the bar, the health under it (the encounter screen's top bar)
	# (the vault's name only when it clears the party chips)
	var right := roundf(UIFrame.right(self)) - 6
	var room := right - (l + 4 + _chips.size() * (HeroChip.W + 4)) - 6
	var full := "%s  ·  Depth %d  ·  Floor %d" % [String(node.get("vault", "")), int(node.get("depth", 1)), int(node.get("floor", 1))]
	var short := "Depth %d  ·  Floor %d" % [int(node.get("depth", 1)), int(node.get("floor", 1))]
	_where.text = full if UIText.width(full, UIText.BOLD, UIText.LABEL) <= room else short
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_where.size.x = maxf(60.0, room)
	_where.position = Vector2(right - _where.size.x, 3)
	_col.reset_size()
	var h := _col.size.y
	_col.position = Vector2(fx + 340, roundf(maxf(54.0, 52 + (304 - h) / 2.0)))
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if demo and not _done and _t > 3.0:
		var cs: Array = node.get("choices", [])
		if not cs.is_empty():
			choose(int(cs[0]["index"]))
	_over.queue_redraw()


func _draw() -> void:
	draw_rect(get_viewport_rect(), Pal.INK1)


func _draw_over() -> void:
	var fx := UIText.frame_rect(self).position.x
	var plate := Pal.INK1
	plate.a = 0.84
	_over.draw_rect(Rect2(fx + 330, 32, 310 + maxf(0.0, get_viewport_rect().size.x - fx - 640), 328), plate)
	_over.draw_rect(Rect2(fx + 330, 32, 1, 328), Pal.INK4)
	var cur: Dictionary = run.call("current_node")
	FlowUI.draw_health(_over, roundf(UIFrame.right(self)) - 6, 17, int(cur.get("health", 0)), int(cur.get("max_health", 0)))
