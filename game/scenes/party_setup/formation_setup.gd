class_name FormationSetup
extends Control
## Formation setup: arrange the party on the side's 2x4 grid before a fight (or any time from the
## run). The shape is detected live and explained in plain words; the opponent's formation is never
## shown (user decision: it stays hidden until the fight starts).
##
## Open from another screen:
##   var s := FormationSetup.open(self, run)                     # run = core/run/run.gd instance
##   var s := FormationSetup.open(self, run, {"mode": "review"}) # from the run menu: adds Back
##   s.confirmed.connect(func(result): ...)  # result = run.set_formation(...) ({"ok", "formation"})
##   s.closed.connect(...)                   # Back pressed (review mode); the screen frees itself
## Without a run (tests, tools): FormationSetup.open_with(self, heroes, slots, unlocked, info)
##   heroes = core-format dicts, slots = per hero [col, row] or null, info = top-bar fields
##   {"depth", "place", "health", "max_health", "fight": "pvp"/"monster"/"heart"/"", "opponent"}.
##   confirmed then carries {"ok": true, "slots": [...], "formation": id}.
## Run standalone (no open), it plays an unattended demo for captures. Demo args: --unlocked=none
## (no shape unlocked: the locked fallback), --demo=strays (a still party of four, nobody side by side).

signal confirmed(result: Dictionary)
signal closed

const SCENE := "res://scenes/party_setup/formation_setup.tscn"
const BACKDROP := preload("res://assets/battle/bg_vault_wide.png")   # 640x360 frame + 120 px wings
const HEART := preload("res://ui/icons/heart.png")
const KIND_ICONS := {
	"pvp": preload("res://ui/icons/kind_pvp.png"), "monster": preload("res://ui/icons/kind_monster.png"),
	"heart": preload("res://ui/icons/kind_monster.png"),
}

var run: RefCounted = null
var mode := "fight"
var info := {}
var demo := false

var board: FormationBoard
var panel: FormationPanel
var _confirm: Button
var _back: Button
var _error := ""
var _t := 0.0
var _opened := false
var _pending: Dictionary = {}
var _done := false

# demo
var _script: Array = []
var _act := -1
var _act_t := 0.0
var _hand_hide_at := -1.0


static func open(parent: Node, r: RefCounted, opts := {}) -> FormationSetup:
	var s: FormationSetup = load(SCENE).instantiate()
	s._opened = true
	s.run = r
	s.mode = String(opts.get("mode", "fight"))
	var node: Dictionary = r.call("current_node")
	var heroes: Array = r.call("party_view")
	var slots: Array = []
	for h: Dictionary in heroes:
		slots.append(h["slot"])
	var unlocked: Array = (r.call("combat_party") as Dictionary).get("unlocked_formations", [])
	var opp: Dictionary = node.get("opponent", {})
	s._pending = {"heroes": heroes, "slots": slots, "unlocked": unlocked, "info": {
		"depth": node.get("depth", 1), "place": node.get("vault", ""), "health": node.get("health", 0),
		"max_health": node.get("max_health", 0), "fight": node.get("type", "") if node.get("step", "") == "fight" else "",
		"opponent": opp.get("name", "")}}
	parent.add_child(s)
	return s


static func open_with(parent: Node, heroes: Array, slots: Array, unlocked: Array, run_info := {}, opts := {}) -> FormationSetup:
	var s: FormationSetup = load(SCENE).instantiate()
	s._opened = true
	s.mode = String(opts.get("mode", "fight"))
	s._pending = {"heroes": heroes, "slots": slots, "unlocked": unlocked, "info": run_info}
	parent.add_child(s)
	return s


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	board = FormationBoard.new()
	add_child(board)
	panel = FormationPanel.new()
	add_child(panel)
	_confirm = FlowUI.primary("Confirm", 112)
	_confirm.position = Vector2(FormationPanel.W - 120, FormationPanel.H - 36)
	_confirm.pressed.connect(confirm)
	panel.add_child(_confirm)
	board.changed.connect(_on_changed)
	board.preview_changed.connect(_refresh)
	board.held_changed.connect(_refresh)
	if not _opened:
		demo = true
		_pending = demo_data()
		_script = demo_script()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--unlocked="):
				# e.g. --unlocked=none: no shape unlocked, to show a locked shape that makes no formation
				var ids := a.substr(11)
				_pending["unlocked"] = [] if ids == "none" else Array(ids.split(","))
			elif a == "--demo=strays":
				# a still party of four with no two heroes side by side (they fight as Strays)
				_pending["heroes"] = (_pending["heroes"] as Array) + [
					{"name": "Holt", "class": "fighter", "level": 2, "items": {}, "alignment": [0, 1]},
					{"name": "Ilse", "class": "healer", "level": 3, "items": {}, "alignment": [1, 1]}]
				_pending["slots"] = [[0, 0], [1, 1], [0, 2], [1, 3]]
				_script = []
	info = _pending.get("info", {})
	if mode == "review":
		_back = Button.new()
		_back.text = "Back"
		_back.focus_mode = Control.FOCUS_NONE
		_back.position = Vector2(FormationPanel.W - 120, FormationPanel.H - 62)
		_back.size = Vector2(112, 22)
		panel.extra_foot = 26
		_back.pressed.connect(_on_back)
		panel.add_child(_back)
	board.setup(_pending["heroes"], _pending["slots"], _pending["unlocked"])
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()


## The board and the card keep their 640x360 frame, centred in the view (the 16:9 safe area of a
## wide phone); the backdrop and the top bar span the whole width, anchored to its safe edges.
func _layout() -> void:
	var fx := UIText.frame_rect(self).position.x
	board.position = Vector2(fx + 8, 34)
	panel.position = Vector2(fx + 424, 34)
	queue_redraw()


func _on_changed() -> void:
	_error = ""
	_refresh()


func _refresh() -> void:
	var pc: Variant = board.preview_cells()
	var cells: Array = pc if pc is Array else board.placed_cells()
	var n_placed := cells.size() if pc is Array else board.placed_cells().size()
	var bases: Array = []
	for h: Dictionary in board.heroes:
		bases.append(PartyModel.base_class(h))
	var pp: Variant = board.preview_placement()
	var names: Array = board.placed_names(pp if pp is Array else board.placement)
	panel.show_cells(cells, board.unlocked, n_placed, board.heroes.size(), pc is Array, bases, names)
	_confirm.disabled = not board.all_placed() or _done
	queue_redraw()


func confirm() -> void:
	if not board.all_placed() or _done:
		return
	var slots: Array = board.placement.duplicate(true)
	var res := {}
	if run != null:
		res = run.call("set_formation", slots)
	else:
		res = {"ok": true, "formation": String(FormationWords.detect(board.placed_cells()).get("id", ""))}
	if res.has("error"):
		_error = String(res["error"])
		board.toast = _error
		board.toast_t = 4.0
		queue_redraw()
		return
	res["slots"] = slots
	var shape := FormationWords.evaluate(board.placed_cells(), board.unlocked)
	var nm := String(shape["effective"].get("name", ""))
	board.toast = "Set: %s" % nm
	board.toast_t = 99.0
	_done = demo
	_confirm.disabled = true
	confirmed.emit(res)
	if not demo:
		queue_free()


func _exit_tree() -> void:
	Tip.set_zone(Rect2())


func _on_back() -> void:
	closed.emit()
	if not demo:
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	if demo:
		_run_demo(delta)
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var view := get_viewport_rect()
	var fr := UIText.frame_rect(self)
	draw_texture(BACKDROP, fr.position + Vector2(-16 - 120, -16))
	var dim := Pal.INK1
	dim.a = 0.78
	draw_rect(view, dim)
	_draw_top_bar()


func _draw_top_bar() -> void:
	var vw := get_viewport_rect().size.x
	var sr := UIText.safe_rect(self)
	var l := sr.position.x
	draw_rect(Rect2(0, 0, vw, 28), Pal.INK2)
	draw_rect(Rect2(0, 28, vw, 1), Pal.INK4)
	draw_rect(Rect2(0, 29, vw, 1), Pal.INK1)
	draw_rect(Rect2(0, 0, vw, 1), Pal.INK3)
	PartyDraw.text(self, Vector2(l + 10, UIText.centered_y(0, 28, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)), "Formation", Pal.AMBER6, PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	var tx := l + 14 + PartyDraw.text_w("Formation", PartyDraw.SERIF, PartyDraw.SERIF_SIZE)
	var where := "Arrange the party" if mode == "review" or String(info.get("fight", "")) == "" else "Before the fight"
	PartyDraw.text(self, Vector2(tx, 5), where, Pal.INK9, PartyDraw.BOLD)
	var place := String(info.get("place", ""))
	var sub := "Depth %d" % int(info.get("depth", 1))
	if place != "":
		sub = place + "  ·  " + sub
	PartyDraw.text(self, Vector2(tx, 15), sub, Pal.INK8, PartyDraw.BOLD)
	# health, far right
	var mh := int(info.get("max_health", 0))
	var r0 := sr.end.x - 8.0
	var right := r0
	if mh > 0:
		var hx := r0 - mh * 9 + 2
		for i in mh:
			var on := i < int(info.get("health", 0))
			PartyDraw.tint_tex(self, HEART, Vector2(hx + i * 9, 5), Pal.BLOOD3 if on else Pal.INK4, on)
		PartyDraw.text(self, Vector2(hx - 20, 15), "Health %d/%d" % [int(info.get("health", 0)), mh], Pal.INK8, PartyDraw.BOLD, UIText.BODY, true, r0 - hx + 20, HORIZONTAL_ALIGNMENT_RIGHT)
		right = hx - 30
		draw_rect(Rect2(right + 8, 5, 1, 19), Pal.INK4)
	# the next fight: who, never their formation
	var fight := String(info.get("fight", ""))
	if fight != "":
		var opp := String(info.get("opponent", ""))
		var title := ("Next: " + opp) if opp != "" else "Next: a fight"
		var w := PartyDraw.text_w(title, PartyDraw.BOLD)
		var x := right - w
		PartyDraw.text(self, Vector2(x, 4), title, Pal.INK10, PartyDraw.BOLD)
		if KIND_ICONS.has(fight):
			PartyDraw.tint_tex(self, KIND_ICONS[fight], Vector2(x - 12, 5), Pal.BLOOD4 if fight != "pvp" else Pal.VIOLET4)
		PartyDraw.text(self, Vector2(right - 220, 15), "Their formation stays hidden until the fight", Pal.INK8, PartyDraw.BOLD, UIText.BODY, true, 220, HORIZONTAL_ALIGNMENT_RIGHT)


# ------------------------------------------------------------------ demo

static func demo_data() -> Dictionary:
	var GD = preload("res://core/game_data.gd")
	return {
		"heroes": [
			{"name": "Brannoc", "class": "fighter", "level": 3, "items": {"weapon": "iron_sword", "armor": "", "relic": ""}, "alignment": [0, 1]},
			{"name": "Sable", "class": "rogue", "level": 3, "items": {}, "alignment": [-1, -1]},
		],
		"slots": [[0, 1], null],
		"unlocked": GD.Formations.DEFAULT_UNLOCKED + ["keystone", "hearth", "keepers_ring"],
		"info": {"depth": 7, "place": "The Drowned Archive", "health": 4, "max_health": 5, "fight": "pvp",
			"opponent": "Echo of the Ashen Vow"},
	}


## Timeline (seconds). Captures at 1/3/5/7/9/11 s: Kindred, Tidebreak (+ growth cells), dragging
## the 4th over the Keeper's Ring slot (live preview), Keeper's Ring, tap-placed into a locked
## Crescent, one hero dragged apart into Strays; then back into Keeper's Ring and Confirm.
## Points are symbolic so they follow the grid as the bench opens and closes:
## ["b"] the first bench slot, ["c", col, row] a hero's body in that slot, ["f", col, row] its floor.
func demo_script() -> Array:
	return [
		{"t": 0.15, "kind": "drag", "keys": [[0.0, ["b"]], [0.55, ["c", 0, 2]]]},
		{"t": 1.5, "kind": "add", "hero": {"name": "Holt", "class": "fighter", "level": 2, "items": {}, "alignment": [0, 1]}},
		{"t": 1.9, "kind": "drag", "keys": [[0.0, ["b"]], [0.6, ["c", 0, 0]]]},
		{"t": 3.3, "kind": "add", "hero": {"name": "Ilse", "class": "healer", "level": 3, "items": {}, "alignment": [1, 1]}},
		{"t": 3.7, "kind": "drag", "keys": [[0.0, ["b"]], [0.55, ["c", 1, 3]], [0.95, ["c", 1, 3]], [1.3, ["c", 1, 1]], [1.9, ["c", 1, 1]]]},
		{"t": 6.6, "kind": "tip", "chip": 2},
		{"t": 7.3, "kind": "untip"},
		{"t": 7.4, "kind": "tap", "at": ["c", 1, 1]},
		{"t": 8.2, "kind": "tap", "at": ["f", 1, 0]},
		{"t": 9.4, "kind": "drag", "keys": [[0.0, ["c", 0, 2]], [0.7, ["c", 1, 3]]]},
		{"t": 11.4, "kind": "details"},
		{"t": 12.1, "kind": "details"},
		{"t": 12.2, "kind": "drag", "keys": [[0.0, ["c", 0, 1]], [0.6, ["c", 0, 2]]]},
		{"t": 13.0, "kind": "drag", "keys": [[0.0, ["c", 1, 0]], [0.5, ["c", 1, 1]]]},
		{"t": 14.6, "kind": "drag", "keys": [[0.0, ["c", 0, 2]], [0.5, ["c", 0, 1]]]},
		{"t": 15.4, "kind": "drag", "keys": [[0.0, ["c", 1, 3]], [0.5, ["c", 0, 2]]]},
		{"t": 16.6, "kind": "confirm"},
	]


func _run_demo(delta: float) -> void:
	if _act >= 0:
		_act_t += delta
		var a: Dictionary = _script[_act]
		if a["kind"] == "drag":
			var keys: Array = []
			for k: Array in a["keys"]:
				keys.append([k[0], _pt(k[1])])
			var p := _key_at(keys, _act_t)
			board.demo_pointer = p
			if _act_t > 0.05:
				board.demo_hand = 2
				board.pointer_move(p)
			if _act_t >= float(keys[-1][0]):
				board.pointer_up(p)
				board.demo_hand = 1
				_hand_hide_at = _t + 0.5
				_act = -1
		elif a["kind"] == "tap":
			if _act_t >= 0.12:
				board.pointer_up(_pt(a["at"]))
				board.demo_hand = 1
				_hand_hide_at = _t + 0.6
				_act = -1
		return
	if _hand_hide_at > 0.0 and _t >= _hand_hide_at:
		board.demo_hand = 0
		_hand_hide_at = -1.0
	for i in _script.size():
		var a: Dictionary = _script[i]
		if a.get("done", false) or _t < float(a["t"]):
			continue
		a["done"] = true
		match String(a["kind"]):
			"add":
				board.add_hero(a["hero"])
			"drag":
				var p: Vector2 = _pt(a["keys"][0][1])
				board.pointer_down(p)
				board.demo_pointer = p
				board.demo_hand = 1
				_act = i
				_act_t = 0.0
			"tap":
				board.pointer_down(_pt(a["at"]))
				board.demo_pointer = _pt(a["at"])
				board.demo_hand = 2
				_act = i
				_act_t = 0.0
			"details":
				panel.toggle_details()
			"tip":
				panel.open_tip(int(a["chip"]))
			"untip":
				Tip.close()
			"confirm":
				_confirm.button_pressed = true
				get_tree().create_timer(0.15).timeout.connect(func() -> void:
					_confirm.button_pressed = false
					confirm())
		break


func _pt(spec: Array) -> Vector2:
	match String(spec[0]):
		"b":
			return board._bench_rect(0).get_center()
		"c":
			return FormationBoard.feet_of([spec[1], spec[2]]) - Vector2(0, 30)
	return FormationBoard.feet_of([spec[1], spec[2]])


static func _key_at(keys: Array, t: float) -> Vector2:
	if t <= float(keys[0][0]):
		return keys[0][1]
	for k in range(1, keys.size()):
		var t0 := float(keys[k - 1][0])
		var t1 := float(keys[k][0])
		if t <= t1:
			var u := (t - t0) / maxf(t1 - t0, 0.001)
			u = u * u * (3.0 - 2.0 * u)
			return (keys[k - 1][1] as Vector2).lerp(keys[k][1], u).round()
	return keys[-1][1]
