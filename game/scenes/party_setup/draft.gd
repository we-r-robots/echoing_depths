class_name DraftScreen
extends Control
## Starting draft: the run offers a pool of base-class heroes and the player picks two.
## Picks are toggles until "Set out" commits them through the run API (run.choose(i) twice).
##
## Open from another screen:
##   var s := DraftScreen.open(self, run)     # run = core/run/run.gd, current_node().step == "draft"
##   s.drafted.connect(func(party): ...)      # party = run.party_view() after both picks
## The screen frees itself after emitting. Run standalone, it plays an unattended demo.

signal drafted(party: Array)

const SCENE := "res://scenes/party_setup/draft.tscn"
const BACKDROP := preload("res://assets/encounter/campfire/bg.png")
const GLOW := preload("res://assets/encounter/campfire/glow.png")
const Run = preload("res://core/run/run.gd")
const EchoPool = preload("res://core/run/echo_pool.gd")

var run: RefCounted = null
var demo := false
var offered: Array = []
var picks: Array = []           # offered indices, in pick order
var need := 2
var vault := ""

var _cards: Array[DraftCard] = []
var _portraits: Array = []
var _go: Button
var _t := 0.0
var _opened := false
var _done := false
var _msg := ""
var _demo_i := 0


static func open(parent: Node, r: RefCounted) -> DraftScreen:
	var s: DraftScreen = load(SCENE).instantiate()
	s._opened = true
	s.run = r
	parent.add_child(s)
	return s


## A run for the standalone demo: seeded, in-memory Echo pool, nothing written to disk.
static func demo_run(seed_value := 7, pool_size := 3) -> RefCounted:
	var pool: RefCounted = EchoPool.new()
	pool.path = "user://_unused_demo_pool.json"
	pool.seed_generated(1)
	var r: RefCounted = Run.new()
	r.call("start_run", seed_value, {"pool": pool, "save_echo": false, "start_pool_size": pool_size})
	return r


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if run == null:
		demo = true
		var n := 3
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--offer="):
				n = int(a.substr(8))
		run = demo_run(7, n)
	var node: Dictionary = run.call("current_node")
	offered = node.get("offered", [])
	need = int(node.get("picks_left", 2))
	vault = String(node.get("vault", ""))
	_build()


func _build() -> void:
	var n := offered.size()
	var cw := 150   # same card for 3 or 4 offered heroes
	for i in n:
		var o: Dictionary = offered[i]
		var c := DraftCard.new()
		add_child(c)
		c.set_base_y(38)
		c.setup({"name": o["name"], "class": o["class"], "alignment": o["alignment"]}, cw, 290, i * 4)
		c.tapped.connect(toggle.bind(i))
		_portraits.append(SpritePortrait.for_class(String(o["class"]), 20))
		_cards.append(c)
	_go = FlowUI.primary("Set out", 104)
	_go.pressed.connect(commit)
	add_child(_go)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()


## Cards centred in the view (3 or 4 offered); the footer runs edge to edge with Set out at the
## right edge.
func _layout() -> void:
	var cw := 150
	var n := _cards.size()
	var total := n * cw + (n - 1) * 8
	var x0 := roundi((get_viewport_rect().size.x - total) / 2.0)
	for i in n:
		_cards[i].position.x = x0 + i * (cw + 8)
	_go.position = Vector2(UIFrame.right(self) - 112, 329)
	queue_redraw()


## Tap a card: pick it (if a pick is left) or unpick it.
func toggle(i: int) -> void:
	if _done or i < 0 or i >= offered.size() or bool(offered[i].get("taken", false)):
		return
	if picks.has(i):
		picks.erase(i)
		_msg = "%s steps back." % offered[i]["name"]
	elif picks.size() < need:
		picks.append(i)
		var cls := PartyModel.class_name_of(String(offered[i]["class"]))
		_msg = "%s the %s joins you." % [offered[i]["name"], cls]
		if picks.size() == need:
			_msg += " Your party is set: tap Set out."
	else:
		_msg = "Two heroes to start. Tap a chosen hero to change your mind."
	_refresh()


func _refresh() -> void:
	for i in _cards.size():
		var k := picks.find(i)
		_cards[i].set_pick(k + 1, picks.size() >= need and k < 0)
	_go.disabled = picks.size() < need or _done
	queue_redraw()


## Commits the picks through the run API, in pick order.
func commit() -> void:
	if picks.size() < need or _done:
		return
	for i: int in picks:
		var res: Dictionary = run.call("choose", int(i))
		if res.has("error"):
			_msg = String(res["error"])
			queue_redraw()
			return
	_done = true
	_go.disabled = true
	var party: Array = run.call("party_view")
	var names: Array = []
	for h: Dictionary in party:
		names.append(h["name"])
	_msg = "%s set out for %s." % [" and ".join(names), vault if vault != "" else "the Vault"]
	drafted.emit(party)
	if not demo:
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	if demo:
		_run_demo()
	queue_redraw()


## Demo: pick the first, then the third, change mind on the first, pick the second, set out.
func _run_demo() -> void:
	var steps := [[1.6, 0], [3.2, 2], [6.0, 0], [7.4, 1], [10.2, -1]]
	if _demo_i >= steps.size():
		return
	var s: Array = steps[_demo_i]
	if _t >= float(s[0]):
		_demo_i += 1
		if int(s[1]) >= 0:
			toggle(int(s[1]))
		else:
			_go.button_pressed = true
			get_tree().create_timer(0.15).timeout.connect(func() -> void:
				_go.button_pressed = false
				commit())


const TITLE_SIZE := 20


func _draw() -> void:
	var dim := Pal.INK1
	dim.a = 0.72
	UIFrame.backdrop(self, BACKDROP, dim, [GLOW])
	var l := UIFrame.left(self)
	var r0 := UIFrame.right(self)
	# top bar
	UIFrame.top_bar(self)
	# the screen's title is clearly a title: serif two steps over the quiet sans subtitle, which
	# shares its baseline (critic r5: "Choose two heroes" was barely larger than the sentence)
	var head_y := UIText.centered_y(0, 28, PartyDraw.SERIF, TITLE_SIZE)
	PartyDraw.text(self, Vector2(l + 10, head_y), "Choose two heroes", Pal.AMBER6, PartyDraw.SERIF, TITLE_SIZE)
	var base := head_y + UIText.ascent(PartyDraw.SERIF, TITLE_SIZE)
	var tx := l + 20 + PartyDraw.text_w("Choose two heroes", PartyDraw.SERIF, TITLE_SIZE)
	PartyDraw.text(self, Vector2(tx, base - UIText.ascent(PartyDraw.BOLD, UIText.BODY)), "More can join on the road, up to four.", Pal.INK8, PartyDraw.BOLD)
	# pick slots, right
	var px := r0 - 8
	for k in range(need - 1, -1, -1):
		var r := Rect2(px - 22, 3, 22, 22)
		px -= 25
		PartyDraw.inset(self, r)
		if k < picks.size():
			if _portraits[picks[k]] != null:
				draw_texture(_portraits[picks[k]], r.position + Vector2(1, 1))
			PartyDraw.soft_outline(self, r, Pal.AMBER5)
		else:
			PartyDraw.dashed_outline(self, r, Pal.INK5)
			PartyDraw.text(self, r.position + Vector2(0, 5), str(k + 1), Pal.INK8, PartyDraw.BOLD, UIText.BODY, false, 22, HORIZONTAL_ALIGNMENT_CENTER)
	PartyDraw.text(self, Vector2(px - 80, 9), "Party %d/%d" % [picks.size(), need], Pal.INK9 if picks.size() < need else Pal.AMBER6,
		PartyDraw.BOLD, UIText.BODY, true, 78, HORIZONTAL_ALIGNMENT_RIGHT)
	# what the alignment line on the cards means, said once, as a labelled panel; once the party
	# sets out, the same strip says so
	# no box (critic r4: the framed strip read as an input field): a hairline above, then the
	# icon and one plain caption line
	var bb := Rect2(l + 8, 332, r0 - l - 128, 22)
	draw_rect(Rect2(bb.position.x, bb.position.y - 1, bb.size.x, 1), Pal.INK3)
	var ty := UIText.centered_y(bb.position.y, bb.size.y)
	if _done:
		PartyDraw.text(self, Vector2(bb.position.x + 8, ty), _msg, Pal.AMBER6, PartyDraw.BOLD)
		return
	# the alignment mark the cards use, then one plain sentence (no caps badge: one type style)
	PartyDraw.tint_tex(self, DraftCard.START, Vector2(bb.position.x + 8, bb.position.y + 8), Pal.AMBER6)
	PartyDraw.text(self, Vector2(bb.position.x + 20, ty),
		"Alignment: each class starts at a fixed place; your choices move it.", Pal.INK9, PartyDraw.BOLD)
