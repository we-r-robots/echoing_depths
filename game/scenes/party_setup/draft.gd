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
	var total := n * cw + (n - 1) * 8
	var x0 := roundi((640 - total) / 2.0)
	for i in n:
		var o: Dictionary = offered[i]
		var c := DraftCard.new()
		add_child(c)
		c.position = Vector2(x0 + i * (cw + 8), 0)
		c.set_base_y(38)
		c.setup({"name": o["name"], "class": o["class"], "alignment": o["alignment"]}, cw, 290, i * 4)
		c.tapped.connect(toggle.bind(i))
		_portraits.append(SpritePortrait.for_class(String(o["class"]), 20))
		_cards.append(c)
	_go = Button.new()
	_go.text = "Set out"
	_go.focus_mode = Control.FOCUS_NONE
	_go.position = Vector2(556, 336)
	_go.size = Vector2(76, 20)
	_go.pressed.connect(commit)
	add_child(_go)
	_refresh()


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


func _draw() -> void:
	draw_texture(BACKDROP, Vector2.ZERO)
	draw_texture(GLOW, Vector2.ZERO)
	var dim := Pal.INK1
	dim.a = 0.72
	draw_rect(Rect2(0, 0, 640, 360), dim)
	# top bar
	draw_rect(Rect2(0, 0, 640, 28), Pal.INK2)
	draw_rect(Rect2(0, 0, 640, 1), Pal.INK3)
	draw_rect(Rect2(0, 28, 640, 1), Pal.INK4)
	draw_rect(Rect2(0, 29, 640, 1), Pal.INK1)
	PartyDraw.text(self, Vector2(10, 5), "Choose two heroes", Pal.AMBER6, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	var tx := 16 + PartyDraw.text_w("Choose two heroes", PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	PartyDraw.text(self, Vector2(tx, 5), "to begin the descent", Pal.INK9, PartyDraw.BOLD)
	var sub := "More can join on the road: four at most."
	PartyDraw.text(self, Vector2(tx, 15), sub, Pal.INK7)
	# pick slots, right
	var px := 632
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
			PartyDraw.text(self, r.position + Vector2(0, 5), str(k + 1), Pal.INK6, PartyDraw.BOLD, 11, false, 22, HORIZONTAL_ALIGNMENT_CENTER)
	PartyDraw.text(self, Vector2(px - 80, 9), "Party %d/%d" % [picks.size(), need], Pal.INK9 if picks.size() < need else Pal.AMBER6,
		PartyDraw.BOLD, 11, true, 78, HORIZONTAL_ALIGNMENT_RIGHT)
	# what "Starts:" on the cards means, said once, as a labelled panel
	var bb := Rect2(8, 334, 540, 22)
	PartyDraw.panel(self, bb, 0, &"DimPanel")
	var pw := PartyDraw.pill(self, Vector2(bb.position.x + 6, bb.position.y + 6), "ALIGNMENT", Pal.AMBER6, Pal.AMBER1, Pal.AMBER4)
	PartyDraw.text(self, Vector2(bb.position.x + 12 + pw, bb.position.y + 6),
		"Each class starts at a fixed place. Your choices shift it and set the advanced class.", Pal.INK9)
