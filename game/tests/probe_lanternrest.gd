extends Node
## Probe (run by tests/run_all.gd over frames, so containers lay out and _draw runs): Lanternrest
## at 1920x1080 and 2340x1080 (19.5:9). With the camera at the west edge, the lantern and the east
## edge, every name plate stays on screen, under the top bar and clear of the other plates; every
## panel (the Lantern, the Vault entrance with and without a saved run, the Training Grounds with a
## shape picked, an empty plot, the mist, the first-visit identity) lies on screen under the top
## bar, and each of its one-line texts fits its box and stays inside the panel.

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
		for c in [0.0, 640.0, 1e9]:
			s.set_cam(Village.cam_for(c, s.view_w()) if c < 1e8 else 1e9)
			for id in s.visible_ids:
				s.hovered = id
				_check_plates(s, "%s cam %d hover %s" % [tag, s.cam, id])
		s.hovered = ""
		for which in ["lantern", "vault", "vault_saved", "grounds", "plot_w2", "fog_east", "identity"]:
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
			_check_panel(s, "%s %s" % [tag, which])
			s.close_panel()
		remove_child(s)
		s.free()
	root.size = old
	done = true


func _check_plates(s: LanternrestScreen, at: String) -> void:
	var vr := s.get_viewport_rect()
	var rects := {}
	for id in s.shown_plates():
		var r := s.plate_rect(id)
		# only plates whose place is on screen matter
		var z := (s.places[id] as VillagePlace).world_zone()
		var sx := s.to_screen(z.position).x
		if sx + z.size.x < 0 or sx > vr.size.x:
			continue
		rects[id] = r
		check(vr.encloses(r), "%s: %s plate %s on screen" % [at, id, r])
		check(r.position.y >= LanternrestScreen.TOP, "%s: %s plate under the top bar" % [at, id])
	var ids := rects.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			check(not (rects[ids[i]] as Rect2).intersects(rects[ids[j]]), "%s: plates %s and %s overlap" % [at, ids[i], ids[j]])


func _check_panel(s: LanternrestScreen, at: String) -> void:
	check(s.panel != null, "%s: a panel is open" % at)
	if s.panel == null:
		return
	var vr := s.get_viewport_rect()
	var pr := s.panel.get_global_rect()
	check(vr.encloses(pr), "%s: panel %s on screen" % [at, pr])
	check(pr.position.y >= LanternrestScreen.TOP, "%s: panel under the top bar" % at)
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
