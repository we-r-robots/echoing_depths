class_name LanternrestScreen
extends Control
## Lanternrest, the village hub (04-meta-progression.md; docs/BUILD.md "Lanternrest is a place,
## not a menu"). The game starts here: a pixel village wider than the screen that the player
## drags / swipes, scrolls (wheel, arrow keys, the screen's edges) and taps. Each place is a world
## object (VillagePlace) with a tap zone; tapping it opens its menu as a panel over the village:
##   the Lantern          the team's name, crest and progress (the Banner Hall menu for now)
##   the Vault entrance   starts a new run or continues the saved one
##   the Training Grounds a barracks yard on a plot, built after the first run (placeholder rule)
##   empty plots          what could stand there later
##   the mist             the side areas the village has not remembered yet
## The first visit asks for a team name and crest (IdentityPanel).
##
##   var s := LanternrestScreen.open(parent)
##   s.new_run / s.continue_run / s.to_title      # the flow frees the screen
## Standalone (no open) it shows a demo village and never writes the player's files. Scene args:
##   --state=fresh|built   --scroll=west|east|<world x>   --hover=<place id>
##   --panel=<place id>|identity   --saved (a run in progress)

signal new_run
signal continue_run
signal to_title

const SCENE := "res://scenes/lanternrest/lanternrest.tscn"
const DRAG_START := 5.0       # design px a press must move before it is a drag, not a tap
const KEY_SPEED := 280.0      # design px per second (arrow keys, edge scrolling)
const EDGE_BAND := 10.0       # the screen's edge strip that scrolls on PC
const WHEEL_STEP := 48.0
const FLING_DECAY := 6.0
const TOP := 28.0             # top bar height
const ARROW := Vector2(18, 40)

var demo := false
var cam := 0.0
var world: Node2D
var places := {}              # id -> VillagePlace
var visible_ids: Array[String] = []
var hovered := ""
var selected := ""
var panel: VillagePanel = null
var hint_shown := true
var _opened := false
var _ui: Control
var _shade: Control
var _title_btn: Button
var _sky: Texture2D
var _ground: Sprite2D
var _press := {}              # {pos, cam, moved}
var _vel := 0.0
var _last_motion := Vector2.ZERO
var _last_motion_t := 0.0
var _mouse_in := false
var _mouse := Vector2(-1, -1)
var _tween: Tween
var _demo_args := {}
var _panel_note := false


static func open(parent: Node) -> LanternrestScreen:
	var s: LanternrestScreen = load(SCENE).instantiate()
	s._opened = true
	parent.add_child(s)
	return s


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if not _opened:
		_demo_setup()
	GameState.ensure()
	_sky = Village.texture("sky")
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_ground = Sprite2D.new()
	_ground.centered = false
	_ground.texture = Village.texture("ground")
	_ground.position = Village.layer_pos("ground")
	world.add_child(_ground)
	_ui = Control.new()
	_ui.name = "UI"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_title_btn = FlowUI.button("Title", 64, 22)
	_title_btn.name = "TitleButton"
	_title_btn.pressed.connect(func() -> void: to_title.emit())
	add_child(_title_btn)
	rebuild()
	cam = _start_cam()
	get_viewport().size_changed.connect(_layout)
	_layout()
	if GameState.identity_needed():
		open_identity()
	elif demo:
		_demo_after()


func _exit_tree() -> void:
	if demo:
		GameState.read_only = false
		GameState.load_all()   # back to the player's own state


# ------------------------------------------------------------------ the world

## (Re)builds the places standing for the current meta (after a run, an unlock).
func rebuild() -> void:
	for p: Node in places.values():
		p.queue_free()
	places.clear()
	visible_ids = Village.visible_places(GameState.meta)
	for id in visible_ids:
		var p := VillagePlace.make(id)
		if id == "lantern":
			p.crest_id = GameState.crest()
		world.add_child(p)
		places[id] = p
	_refresh_highlights()


## Where the camera starts: on the lantern, or between it and a newly built place.
func _start_cam() -> float:
	var vw := view_w()
	var x := (places["lantern"] as VillagePlace).center_x()
	var fresh := Village.unseen(GameState.meta)
	if not fresh.is_empty():
		x = (x + (places[fresh[0]] as VillagePlace).center_x()) / 2.0
	return Village.cam_for(x, vw)


func view_w() -> float:
	return get_viewport_rect().size.x


## Top-left of the world on screen (design px): -cam across, centred when the view is taller or
## (on an ultra-wide screen) wider than the world.
func world_origin() -> Vector2:
	var vr := get_viewport_rect().size
	var ws := Village.world_size()
	var ox := -roundf(cam) if vr.x <= ws.x else floorf((vr.x - ws.x) / 2.0)
	return Vector2(ox, floorf(maxf(0.0, vr.y - ws.y) / 2.0))


func set_cam(x: float) -> void:
	var c := Village.clamp_cam(x, view_w())
	if c != cam:
		cam = c
		_apply_cam()


func _apply_cam() -> void:
	world.position = world_origin()
	queue_redraw()
	_ui.queue_redraw()


func to_world(screen_pos: Vector2) -> Vector2:
	return screen_pos - world_origin()


func to_screen(world_pos: Vector2) -> Vector2:
	return world_pos + world_origin()


## The front-most place whose tap zone holds a world point ("" for none).
func place_at(world_pos: Vector2) -> String:
	for i in range(visible_ids.size() - 1, -1, -1):
		var id := visible_ids[i]
		if (places[id] as VillagePlace).contains(world_pos):
			return id
	return ""


## Slides the camera so a place's zone is on screen (centred when it was off screen).
func focus(id: String, centre := false) -> void:
	var z := (places[id] as VillagePlace).world_zone()
	var vw := view_w()
	var target := cam
	if centre or z.position.x < cam + 8 or z.end.x > cam + vw - 8:
		target = Village.cam_for(z.get_center().x, vw)
	if absf(target - cam) < 1.0:
		return
	_vel = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(set_cam, cam, target, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if panel != null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_press = {"pos": mb.position, "cam": cam, "moved": false}
					_vel = 0.0
					_last_motion = mb.position
					_last_motion_t = Time.get_ticks_msec() / 1000.0
					if _tween != null:
						_tween.kill()
				elif not _press.is_empty():
					if not bool(_press["moved"]):
						tap(mb.position)
					_press = {}
				accept_event()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				if mb.pressed:
					_scroll_by(-WHEEL_STEP * maxf(mb.factor, 1.0))
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				if mb.pressed:
					_scroll_by(WHEEL_STEP * maxf(mb.factor, 1.0))
				accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse = mm.position
		_mouse_in = true
		if not _press.is_empty():
			var start: Vector2 = _press["pos"]
			if not bool(_press["moved"]) and absf(mm.position.x - start.x) > DRAG_START:
				_press["moved"] = true
				hint_shown = false
				_set_hover("")
			if bool(_press["moved"]):
				set_cam(float(_press["cam"]) - (mm.position.x - start.x))
				var now := Time.get_ticks_msec() / 1000.0
				var dt := maxf(now - _last_motion_t, 0.001)
				_vel = lerpf(_vel, -(mm.position.x - _last_motion.x) / dt, 0.5)
				_last_motion = mm.position
				_last_motion_t = now
		else:
			_set_hover(place_at(to_world(mm.position)))
		accept_event()
	elif event is InputEventPanGesture:
		_scroll_by((event as InputEventPanGesture).delta.x * 8.0)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_cancel"):
		if panel != null and panel.closable:
			close_panel()
			get_viewport().set_input_as_handled()
		return
	if panel != null:
		return
	if event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
		_cycle(-1 if event.is_action("ui_focus_prev") else 1)
		get_viewport().set_input_as_handled()
	elif event.is_action("ui_accept") and hovered != "":
		open_place(hovered)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_in = false
		if panel == null and _press.is_empty():
			_set_hover("")


## Keyboard: the next place left to right becomes the highlighted one, and the camera follows.
func _cycle(dir: int) -> void:
	var ids := visible_ids.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return (places[a] as VillagePlace).center_x() < (places[b] as VillagePlace).center_x())
	var i := ids.find(hovered)
	i = (i + dir + ids.size()) % ids.size() if i >= 0 else (0 if dir > 0 else ids.size() - 1)
	_set_hover(ids[i])
	focus(ids[i])


func _scroll_by(dx: float) -> void:
	hint_shown = false
	if _tween != null:
		_tween.kill()
	set_cam(cam + dx)


## A tap at a screen point: the edge arrows scroll, a place opens its menu.
func tap(screen_pos: Vector2) -> void:
	if _arrow_rect(-1).has_point(screen_pos) and cam > 0.0:
		_page(-1)
		return
	if _arrow_rect(1).has_point(screen_pos) and cam < Village.clamp_cam(INF, view_w()):
		_page(1)
		return
	var id := place_at(to_world(screen_pos))
	if id != "":
		open_place(id)


func _page(dir: int) -> void:
	hint_shown = false
	if _tween != null:
		_tween.kill()
	var target := Village.clamp_cam(cam + dir * view_w() * 0.5, view_w())
	_tween = create_tween()
	_tween.tween_method(set_cam, cam, target, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_hover(id: String) -> void:
	if id != hovered:
		hovered = id
		_refresh_highlights()
		_ui.queue_redraw()


func _refresh_highlights() -> void:
	for id: String in places:
		(places[id] as VillagePlace).highlight = id == hovered or id == selected


func _process(delta: float) -> void:
	var dx := 0.0
	if panel == null and get_viewport().gui_get_focus_owner() == null:
		if Input.is_action_pressed("ui_left"):
			dx -= KEY_SPEED * delta
		if Input.is_action_pressed("ui_right"):
			dx += KEY_SPEED * delta
		# PC: resting the pointer on the screen's edge scrolls that way
		if _mouse_in and _press.is_empty() and not OS.has_feature("mobile"):
			var sr := UIText.safe_rect(self)
			if _mouse.x >= 0.0 and _mouse.y > TOP:
				if _mouse.x < sr.position.x + EDGE_BAND:
					dx -= KEY_SPEED * delta
				elif _mouse.x > sr.end.x - EDGE_BAND:
					dx += KEY_SPEED * delta
	if dx != 0.0:
		hint_shown = false
		if _tween != null:
			_tween.kill()
		set_cam(cam + dx)
	elif _press.is_empty() and absf(_vel) > 5.0:
		set_cam(cam + _vel * delta)
		_vel *= exp(-FLING_DECAY * delta)
	else:
		_vel = 0.0
	_ui.queue_redraw()


# ------------------------------------------------------------------ panels

## Opens a place's menu over the village.
func open_place(id: String) -> void:
	if not places.has(id):
		return
	hint_shown = false
	selected = id
	_set_hover(id)
	_refresh_highlights()
	if Village.unseen(GameState.meta).has(id):
		GameState.mark_seen(id)
	var p: VillagePanel
	match Village.kind(id):
		"lantern":
			p = LanternPanel.new()
		"vault":
			var v := VaultPanel.new()
			v.has_saved = _demo_args.has("saved") if demo else GameState.has_saved_run()
			v.descend.connect(func() -> void: new_run.emit())
			v.resume.connect(func() -> void: continue_run.emit())
			p = v
		"building":
			p = TrainingGroundsPanel.new()
		_:
			p = VillagePanel.note(id, Village.place_name(id), String(Village.PLACES[id].get("text", "")))
	_show_panel(p, Village.kind(id) in ["plot", "fog"])
	if Village.kind(id) in ["plot", "fog"]:
		focus(id)


func open_identity() -> void:
	var p := IdentityPanel.new()
	p.chosen.connect(func(_t: String, _c: String) -> void: close_panel())
	_show_panel(p, false)


## Kind of the open panel's place ("" when none), for tests and the flow.
func panel_kind() -> String:
	if panel == null:
		return ""
	if panel is IdentityPanel:
		return "identity"
	return panel.place_id


func _show_panel(p: VillagePanel, note: bool) -> void:
	close_panel()
	_shade = Control.new()
	_shade.name = "Shade"
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := Color(Pal.INK1, 0.0 if note else 0.6)
	_shade.draw.connect(func() -> void: _shade.draw_rect(_shade.get_rect(), dim))
	_shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and panel != null and panel.closable:
			close_panel())
	add_child(_shade)
	panel = p
	p.name = "Panel"
	p.closed.connect(close_panel)
	p.changed.connect(_on_changed)
	add_child(p)
	_panel_note = note
	_place_panel.call_deferred()
	_place_panel()


func _place_panel() -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var note := _panel_note
	panel.reset_size()
	var vr := get_viewport_rect().size
	var sr := UIText.safe_rect(self)
	var sz := panel.size
	var pos: Vector2
	if note and selected != "":
		var z := (places[selected] as VillagePlace).world_zone()
		var top := to_screen(Vector2(z.get_center().x, Village.plate_y(selected)))
		pos = Vector2(top.x - sz.x / 2.0, top.y - sz.y - 22.0)
		if pos.y < TOP + 6.0:
			pos.y = to_screen(z.end).y + 6.0
	else:
		pos = Vector2((vr.x - sz.x) / 2.0, maxf(TOP + 6.0, (vr.y - sz.y) / 2.0 + 6.0))
	pos.x = clampf(pos.x, sr.position.x + 8.0, sr.end.x - 8.0 - sz.x)
	pos.y = clampf(pos.y, TOP + 4.0, vr.y - sz.y - 4.0)
	panel.position = pos.round()


func close_panel() -> void:
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
		remove_child(panel)
	panel = null
	if _shade != null and is_instance_valid(_shade):
		_shade.queue_free()
		remove_child(_shade)
	_shade = null
	selected = ""
	Tip.close()
	_refresh_highlights()
	_ui.queue_redraw()


func _on_changed() -> void:
	if places.has("lantern"):
		(places["lantern"] as VillagePlace).crest_id = GameState.crest()
		(places["lantern"] as VillagePlace).queue_redraw()
	_ui.queue_redraw()


# ------------------------------------------------------------------ layout / draw

func _layout() -> void:
	set_cam(cam)
	_apply_cam()
	_title_btn.position = Vector2(roundf(UIFrame.right(self) - 72), 3)
	if panel != null:
		_place_panel()


func _draw() -> void:
	var vr := get_viewport_rect()
	draw_rect(vr, Pal.INK1)
	# the far sky moves at half the camera's speed (whole px), mirrored past its end on very wide views
	var o := world_origin()
	var sx := -roundf(cam * 0.5) if vr.size.x <= Village.world_size().x else o.x
	var sw := float(_sky.get_width())
	draw_texture(_sky, Vector2(sx, o.y))
	if sx + sw < vr.size.x:
		draw_texture_rect(_sky, Rect2(sx + 2.0 * sw, o.y, -sw, _sky.get_height()), false)


func _arrow_rect(dir: int) -> Rect2:
	var sr := UIText.safe_rect(self)
	var y := 170.0
	return Rect2(sr.position.x + 2.0, y, ARROW.x, ARROW.y) if dir < 0 else Rect2(sr.end.x - 2.0 - ARROW.x, y, ARROW.x, ARROW.y)


## Name plates, the top bar, the edge arrows and the first-visit hint, on the UI layer.
func _draw_ui() -> void:
	var ui := _ui
	var sr := UIText.safe_rect(self)
	var unseen := Village.unseen(GameState.meta)
	for id in shown_plates():
		_draw_plate(ui, id, unseen.has(id))
	# edge arrows: there is more village that way
	var maxc := Village.clamp_cam(INF, view_w())
	for dir in [-1, 1]:
		if (dir < 0 and cam > 0.5) or (dir > 0 and cam < maxc - 0.5):
			var r := _arrow_rect(dir)
			var c := r.get_center()
			var back := Color(Pal.INK1, 0.7)
			ui.draw_rect(r, back)
			var pts := PackedVector2Array([c + Vector2(4 * dir, 0), c + Vector2(-3 * dir, -7), c + Vector2(-3 * dir, 7)])
			ui.draw_colored_polygon(pts, Pal.AMBER5)
	# top bar: where you are, whose village, what it holds
	UIFrame.top_bar(ui)
	var l := sr.position.x
	UIText.draw(ui, Vector2(l + 10, UIText.centered_y(0, TOP, UIText.SERIF, UIText.TITLE)), "Lanternrest", Pal.AMBER6, UIText.SERIF, UIText.TITLE)
	var tx := l + 18 + UIText.width("Lanternrest", UIText.SERIF, UIText.TITLE)
	Crests.draw(ui, Vector2(roundf(tx), 7), GameState.crest(), 1)
	UIText.draw(ui, Vector2(roundf(tx + 18), UIText.centered_y(0, TOP, UIText.BOLD)), GameState.team_name(), Pal.INK9, UIText.BOLD)
	var m := GameState.meta
	var res := "Glimmers %d   Shards %d" % [int(m["glimmers"]), int(m["shards"])]
	var rw := UIText.width(res, UIText.BOLD)
	UIText.draw(ui, Vector2(roundf(_title_btn.position.x - 12 - rw), UIText.centered_y(0, TOP, UIText.BOLD)), res, Pal.AMBER6, UIText.BOLD)
	if hint_shown and panel == null:
		var hint := "Drag to look around. Tap a place to visit it."
		var hw := UIText.width(hint, UIText.BOLD)
		var hx := roundf((get_viewport_rect().size.x - hw) / 2.0)
		ui.draw_rect(Rect2(hx - 8, 335, hw + 16, 18), Color(Pal.INK1, 0.85))
		UIText.draw(ui, Vector2(hx, UIText.centered_y(335, 18, UIText.BOLD)), hint, Pal.INK9, UIText.BOLD)


## The name plate's rect on screen (design px): centred over its place's plate line, kept inside
## the safe edges (clear of the edge arrows) and under the top bar.
func plate_rect(id: String, is_new := false) -> Rect2:
	var sr := UIText.safe_rect(self)
	var z := (places[id] as VillagePlace).world_zone()
	var w := UIText.width(Village.place_name(id), UIText.BOLD)
	var tw := UIText.width("NEW", UIText.BOLD) + 8.0 if is_new else 0.0
	var pw := roundf(w + 12.0 + tw)
	var ph := 16.0
	var bottom := to_screen(Vector2(z.get_center().x, Village.plate_y(id))).y - 3.0
	var x := roundf(to_screen(Vector2(z.get_center().x, 0)).x - pw / 2.0)
	x = clampf(x, sr.position.x + ARROW.x + 6.0, sr.end.x - ARROW.x - 6.0 - pw)
	var y := maxf(roundf(bottom - ph), TOP + 4.0)
	return Rect2(x, y, pw, ph)


## Places whose name plates show now (the main places always; others while hovered or open).
func shown_plates() -> Array[String]:
	var out: Array[String] = []
	var vw := view_w()
	for id in visible_ids:
		if bool(Village.PLACES[id].get("always_plate", false)) or id == hovered or id == selected:
			# a place scrolled off screen shows no plate (it would sit clamped over another place)
			var z := (places[id] as VillagePlace).world_zone()
			var sx := to_screen(z.position).x
			if sx + z.size.x * 0.5 < 0.0 or sx + z.size.x * 0.5 > vw:
				continue
			out.append(id)
	return out


func _draw_plate(ui: Control, id: String, is_new: bool) -> void:
	var label := Village.place_name(id)
	var main := Village.kind(id) in ["lantern", "vault", "building"]
	var lit := id == hovered or id == selected
	var w := UIText.width(label, UIText.BOLD)
	var tag := "NEW"
	var tw := UIText.width(tag, UIText.BOLD) + 8.0 if is_new else 0.0
	var r := plate_rect(id, is_new)
	var x := r.position.x
	var y := r.position.y
	var ph := r.size.y
	ui.draw_rect(r, Color(Pal.INK1, 0.88))
	ui.draw_rect(r, Pal.AMBER5 if lit else Pal.INK5, false, 1.0)
	var col := Pal.AMBER6 if main or lit else Pal.INK9
	UIText.draw(ui, Vector2(x + 6.0, UIText.centered_y(y, ph, UIText.BOLD)), label, col, UIText.BOLD)
	if is_new:
		var tr := Rect2(x + 6.0 + w + 4.0, y + 3.0, tw - 2.0, ph - 6.0)
		ui.draw_rect(tr.grow_individual(0, 1, 0, 1), Pal.CRYSTAL2)
		UIText.draw(ui, Vector2(tr.position.x + 3.0, UIText.centered_y(y, ph, UIText.BOLD)), tag, Pal.CRYSTAL5, UIText.BOLD, UIText.LABEL, false)
	# a short stem from the plate down toward its place
	ui.draw_rect(Rect2(roundf(r.get_center().x), r.end.y, 1, 3), Pal.AMBER5 if lit else Pal.INK5)


# ------------------------------------------------------------------ demo (standalone captures)

func _demo_setup() -> void:
	demo = true
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_demo_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	GameState.read_only = true
	GameState.meta = GameState.default_meta()
	GameState.settings = GameState.default_settings()
	GameState._loaded = true
	if String(_demo_args.get("state", "built")) == "fresh":
		if String(_demo_args.get("panel", "")) != "identity":
			GameState.meta["identity_chosen"] = true
	else:
		GameState.meta.merge({"identity_chosen": true, "glimmers": 87, "shards": 3, "runs": 4,
			"victories": 1, "best_floor": 4, "glimmers_total": 187, "shards_total": 2,
			"team_name": "The Ember Watch", "crest": "star"}, true)
		(GameState.meta["unlocked_formations"] as Array).append("keystone")
		(GameState.meta["crests"] as Array).append("star")
		if not _demo_args.has("new"):
			(GameState.meta["village_seen"] as Array).append("grounds")


func _demo_after() -> void:
	var sc := String(_demo_args.get("scroll", ""))
	if sc == "west":
		set_cam(0.0)
	elif sc == "east":
		set_cam(INF)
	elif sc != "":
		set_cam(Village.cam_for(float(sc), view_w()))
	if _demo_args.has("hover"):
		hint_shown = false
		_set_hover(String(_demo_args["hover"]))
	if _demo_args.has("panel"):
		open_place(String(_demo_args["panel"]))
