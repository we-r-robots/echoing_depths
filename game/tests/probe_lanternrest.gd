extends Node
## Probe (run by tests/run_all.gd over frames, so containers lay out and _draw runs): the Lanternrest
## town at 1920x1080 and 2340x1080 (19.5:9). With the camera at the opening view, each corner and
## each edge, and every place hovered in turn, every signboard stays on screen, under the top bar
## and clear of the other signs; edge cues stay off places. Every panel (the Lantern, the Vault
## entrance with and without a saved run, the Training Grounds with a shape picked, empty plots, the
## mist on each side, the first-visit identity) lies on screen under the top bar, beside its place
## and never over it, and each of its one-line texts fits its box and stays inside the panel.

var failures: Array = []
var asserts := 0
var done := false


func check(cond: bool, msg: String) -> void:
	asserts += 1
	if not cond:
		failures.append(msg)


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var root := get_tree().root
	var old := root.size
	for res in [Vector2i(1920, 1080), Vector2i(2340, 1080)]:
		root.size = res
		await _frames(2)
		var s: LanternrestScreen = load(LanternrestScreen.SCENE).instantiate()
		add_child(s)
		await _frames(2)
		var tag := "%dx%d" % [res.x, res.y]
		var view := s.view_size()
		var maxc := Village.clamp_cam(Vector2(INF, INF), view)
		var cams := [s.start_cam(), Vector2.ZERO, maxc, Vector2(maxc.x, 0), Vector2(0, maxc.y),
			Vector2(maxc.x / 2, 0), Vector2(maxc.x / 2, maxc.y), Vector2(0, maxc.y / 2), Vector2(maxc.x, maxc.y / 2)]
		for c: Vector2 in cams:
			s.set_cam(c)
			s.hovered = ""
			_check_plates(s, "%s cam %s" % [tag, s.cam])
			for id in s.visible_ids:
				s.hovered = id
				_check_plates(s, "%s cam %s hover %s" % [tag, s.cam, id])
		s.hovered = ""
		for which in ["lantern", "vault", "vault_saved", "grounds", "plot_w1", "plot_w2", "plot_e2", "plot_s1",
				"fog_east", "fog_west", "fog_north", "fog_south", "identity"]:
			var id: String = which.trim_suffix("_saved")
			s._demo_args.erase("saved")
			if which == "vault_saved":
				s._demo_args["saved"] = "true"
			if id == "identity":
				s.open_identity()
			else:
				s.open_place(id)
			if s.panel is TrainingGroundsPanel:
				(s.panel as TrainingGroundsPanel).select_shape("seawall")
			if s.panel is VaultPanel and which == "vault_saved":
				(s.panel as VaultPanel).new_descent()
			await _frames(3)
			s._place_panel()
			s.finish_camera()
			await _frames(1)
			_check_panel(s, "%s %s" % [tag, which], "lantern" if id == "identity" else id)
			s.close_panel()
		remove_child(s)
		s.free()
	root.size = old
	done = true


func _check_plates(s: LanternrestScreen, at: String) -> void:
	var vr := s.get_viewport_rect()
	var rects := {}
	var unseen := Village.unseen(GameState.meta)
	for id in s.shown_plates():
		var r := s.plate_rect(id, unseen.has(id))
		rects[id] = r
		check(vr.encloses(r), "%s: %s sign %s on screen" % [at, id, r])
		check(r.position.y >= LanternrestScreen.TOP, "%s: %s sign under the top bar" % [at, id])
	var ids := rects.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			check(not (rects[ids[i]] as Rect2).intersects(rects[ids[j]]), "%s: signs %s and %s overlap" % [at, ids[i], ids[j]])
	for c: Dictionary in s.cue_rects():
		for id in s.visible_ids:
			check(not (c["rect"] as Rect2).intersects(s.zone_on_screen(id)), "%s: a cue sits on %s" % [at, id])


func _check_panel(s: LanternrestScreen, at: String, place: String) -> void:
	check(s.panel != null, "%s: a panel is open" % at)
	if s.panel == null:
		return
	var vr := s.get_viewport_rect()
	var pr := s.panel.get_global_rect()
	check(vr.encloses(pr), "%s: panel %s on screen" % [at, pr])
	check(pr.position.y >= LanternrestScreen.TOP, "%s: panel under the top bar" % at)
	var zs := s.zone_on_screen(place)
	check(not pr.intersects(zs), "%s: panel %s covers its place %s" % [at, pr, zs])
	check(Rect2(Vector2(0, LanternrestScreen.TOP), vr.size).intersects(zs), "%s: its place stays in view" % at)
	_check_texts(s.panel, pr, at)


func _check_texts(n: Node, pr: Rect2, at: String) -> void:
	if n is Control and not (n as Control).is_visible_in_tree():
		return
	if n is Label or n is Button:
		var c := n as Control
		var text: String = (c as Label).text if c is Label else (c as Button).text
		if text != "":
			var gr := c.get_global_rect()
			check(pr.grow(0.5).encloses(gr), "%s: \"%s\" %s inside the panel %s" % [at, text, gr, pr])
			var wraps := c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
			if not wraps:
				var f := c.get_theme_font("font")
				var sz := c.get_theme_font_size("font_size")
				var room := c.size.x
				var sb := c.get_theme_stylebox("normal")
				if sb != null:
					room -= sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
				var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
				check(w <= room + 0.5, "%s: \"%s\" (%d px) fits its %d px box" % [at, text, w, room])
	for ch in n.get_children():
		_check_texts(ch, pr, at)
