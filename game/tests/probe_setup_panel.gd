extends Node
## Probe (run by tests/run_all.gd over frames, so _draw runs): the formation setup's shape card
## never draws text on text (critic r6: the hint "Tap an effect for the full text" over the GREW FROM
## heading at 2340x1080; the tooltip anchored under the wrong row).
## At 1920x1080 and 2340x1080 it walks every card state: active shapes (every shape that forms),
## Strays, Unformed, the locked fallback and locked-unformed (nothing unlocked), heroes still on the
## bench, a drag preview, every effect row's tooltip open, and Details open. For each it records every
## text drawn on the card (UIText.recording: labels drawn in _draw, chip labels, pills) plus its
## buttons and the tooltip's text, and checks:
##   - no two text boxes overlap (text under the opaque tooltip box is hidden and skipped);
##   - every text stays inside the card (tooltip text inside the tooltip box, the box inside the card);
##   - an effect row's tooltip opens directly under its own row, or directly over it.

const GD = preload("res://core/game_data.gd")

var failures: Array = []
var asserts := 0
var done := false

var _heroes: Array = [
	{"name": "Brannoc", "class": "fighter", "level": 3, "items": {"weapon": "iron_sword", "armor": "", "relic": ""}, "alignment": [0, 1]},
	{"name": "Sable", "class": "rogue", "level": 3, "items": {}, "alignment": [-1, -1]},
	{"name": "Holt", "class": "fighter", "level": 2, "items": {}, "alignment": [0, 1]},
	{"name": "Ilse", "class": "healer", "level": 3, "items": {}, "alignment": [1, 1]},
]
var _info := {"depth": 7, "place": "The Drowned Archive", "health": 4, "max_health": 5, "fight": "pvp",
	"opponent": "Echo of the Ashen Vow"}
var _states_seen := {}
var _tips_checked := 0


func check(cond: bool, msg: String) -> void:
	asserts += 1
	if not cond:
		failures.append(msg)


func _ready() -> void:
	UIText.recording = true
	UIText.recorded.clear()
	get_tree().node_added.connect(_watch)
	_run.call_deferred()


func _exit_tree() -> void:
	UIText.recording = false
	UIText.recorded.clear()
	if get_tree().node_added.is_connected(_watch):
		get_tree().node_added.disconnect(_watch)


## A canvas item's recorded text is replaced each time it redraws.
func _watch(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).draw.is_connected(_forget.bind(n.get_instance_id())):
		(n as CanvasItem).draw.connect(_forget.bind(n.get_instance_id()))


func _forget(id: int) -> void:
	UIText.recorded.erase(id)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _all_unlocked() -> Array:
	var ids: Array = []
	for f: Dictionary in GD.Formations.SHAPES:
		ids.append(String(f["id"]))
	return ids


static func _combos(n: int) -> Array:
	var cells: Array = []
	for c in 2:
		for r in 4:
			cells.append([c, r])
	var out: Array = []
	var pick := func(self_ref: Callable, start: int, cur: Array) -> void:
		if cur.size() == n:
			out.append(cur.duplicate(true))
			return
		for i in range(start, cells.size()):
			cur.append(cells[i])
			self_ref.call(self_ref, i + 1, cur)
			cur.pop_back()
	pick.call(pick, 0, [])
	return out


## The placements to walk: per unlock set and party size, the first placement of every card state,
## and (all unlocked) the first placement of every shape that forms.
func _cases() -> Array:
	var out: Array = []
	for unl: Array in [_all_unlocked(), GD.Formations.DEFAULT_UNLOCKED.duplicate(), []]:
		var keys := {}
		for n in [2, 3, 4]:
			for combo: Array in _combos(n):
				var ev := FormationWords.evaluate(combo, unl)
				var key := "%s|%d|%s" % [ev["state"], n, String((ev["effective"] as Dictionary).get("id", ""))]
				if keys.has(key):
					continue
				keys[key] = true
				out.append({"slots": combo, "unlocked": unl, "n": n, "state": String(ev["state"])})
	# heroes still on the bench: 3 of 4 placed, and 1 of 2
	out.append({"slots": [[0, 0], [0, 1], [1, 1]], "unlocked": _all_unlocked(), "n": 4, "bench": 1, "state": "bench"})
	out.append({"slots": [[0, 1]], "unlocked": _all_unlocked(), "n": 2, "bench": 1, "state": "bench"})
	return out


func _run() -> void:
	var old: Vector2i = get_tree().root.size
	var cases := _cases()
	for res: Vector2i in [Vector2i(1920, 1080), Vector2i(2340, 1080)]:
		get_tree().root.size = res
		await _frames(1)
		for cs: Dictionary in cases:
			await _walk(cs, res)
		await _drag_preview(res)
	get_tree().root.size = old
	for st: String in ["active", "strays", "unformed", "locked_fallback", "locked_unformed", "partial", "parts", "bench", "drag preview", "details"]:
		check(_states_seen.has(st), "the probe walked the %s state" % st)
	check(_tips_checked > 50, "effect-row tooltips were checked (%d)" % _tips_checked)
	done = true


func _open(slots: Array, n: int, unlocked: Array) -> FormationSetup:
	var hs: Array = _heroes.slice(0, n)
	var sl: Array = slots.duplicate(true)
	while sl.size() < n:
		sl.append(null)
	return FormationSetup.open_with(self, hs, sl, unlocked, _info)


func _walk(cs: Dictionary, res: Vector2i) -> void:
	var s := _open(cs["slots"], int(cs["n"]), cs["unlocked"])
	await _frames(3)
	var what := "%dx%d %s %s (%d heroes)" % [res.x, res.y, cs["state"], str(cs["slots"]), cs["n"]]
	_states_seen[String(cs["state"])] = true
	_check(s, what)
	var panel := s.panel
	for k in panel._chips.size():
		panel.open_tip(k)
		await _frames(2)
		_check(s, "%s, row %d tooltip" % [what, k], panel._chips[k])
		_tips_checked += 1
		Tip.close()
	if panel._details_btn.visible:
		panel.toggle_details()
		await _frames(2)
		_states_seen["details"] = true
		_check(s, "%s, Details open" % what)
		panel.toggle_details()
	Tip.close()
	s.queue_free()
	await _frames(1)


func _drag_preview(res: Vector2i) -> void:
	var s := _open([[0, 0], [0, 1], [1, 1]], 4, _all_unlocked())
	await _frames(3)
	var b := s.board
	var from: Vector2 = s._pt(["b"])
	b.pointer_down(from)
	for k in 8:
		b.pointer_move(from.lerp(s._pt(["c", 1, 0]), (k + 1) / 8.0))
		await _frames(1)
	await _frames(2)
	check(s.panel.preview, "%dx%d: dragging a bench hero over a slot previews it" % [res.x, res.y])
	_states_seen["drag preview"] = true
	_check(s, "%dx%d drag preview" % [res.x, res.y])
	b.pointer_up(s._pt(["c", 1, 0]))
	s.queue_free()
	await _frames(1)


## Every text box drawn on the card now (global design px): [rect, text, from].
func _texts(root: Node, out: Array) -> void:
	if root is CanvasItem and (root as CanvasItem).is_visible_in_tree():
		var ci := root as CanvasItem
		for e: Dictionary in UIText.recorded.get(ci.get_instance_id(), []):
			out.append([ci.get_global_transform() * (e["rect"] as Rect2), String(e["text"]), ci.name])
		if root is Button and (root as Button).text != "":
			out.append([(root as Button).get_global_rect(), "[%s]" % (root as Button).text, ci.name])
	for ch in root.get_children():
		_texts(ch, out)


func _check(s: FormationSetup, what: String, row: Control = null) -> void:
	var panel := s.panel
	var card := panel.get_global_rect()
	var items: Array = []
	_texts(panel, items)
	var tip := Tip.box_rect()
	var shown: Array = []
	for it: Array in items:
		if tip.has_area() and (it[0] as Rect2).intersects(tip):
			continue   # under the opaque tooltip box
		shown.append(it)
		check(card.grow(0.5).encloses(it[0]), "%s: \"%s\" %s stays inside the card %s" % [what, it[1], it[0], card])
	if tip.has_area():
		check(card.grow(0.5).encloses(tip), "%s: the tooltip %s stays inside the card %s" % [what, tip, card])
		var tn: Node = Tip._node
		var tips: Array = []
		_texts(tn, tips)
		check(not tips.is_empty(), "%s: the tooltip drew its text" % what)
		for it: Array in tips:
			check(tip.grow(0.5).encloses(it[0]), "%s: tooltip text \"%s\" %s stays inside its box %s" % [what, it[1], it[0], tip])
			shown.append(it)
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			var a: Rect2 = (shown[i][0] as Rect2).grow(-0.25)
			var c: Rect2 = (shown[j][0] as Rect2).grow(-0.25)
			check(not a.intersects(c), "%s: \"%s\" %s overlaps \"%s\" %s" % [what, shown[i][1], shown[i][0], shown[j][1], shown[j][0]])
	if row != null:
		check(tip.has_area(), "%s: the row's tooltip is open" % what)
		var r := row.get_global_rect()
		var below := tip.position.y >= r.end.y and tip.position.y - r.end.y <= 6.0
		var above := tip.end.y <= r.position.y and r.position.y - tip.end.y <= 6.0
		check(below or above, "%s: the tooltip %s opens directly under or over its row %s" % [what, tip, r])
