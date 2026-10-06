class_name LanternrestScreen
extends Control
## Lanternrest, the village hub (04-meta-progression.md; docs/BUILD.md "Lanternrest is a place,
## not a menu", "Lanternrest view: top-down 3/4"). The game starts here: a top-down 3/4 town at
## night, bigger than the screen both ways, that the player pans in two dimensions (drag / swipe
## with fling, mouse wheel, arrow keys, the PC screen's edges, the edge cues) and taps. Each place
## is a world object (VillagePlace) with a tap zone; tapping it slides the camera so the place sits
## a quarter of the way into the view and opens its menu as a panel on the other half, pointing at
## it, over one shared dim:
##   the Lantern          the team's progress, Glimmers into Shards, its name and crest (Banner Hall)
##   the Vault entrance   starts a new run or continues the saved one
##   the Training Grounds a barracks yard on a plot, built after the first run (placeholder rule)
##   empty plots          what could stand there later
##   the mist             the side areas the village has not remembered yet
## The first visit asks for a team name and crest (IdentityPanel). Walking a character comes later;
## the streets are laid out so one could walk them.
##
##   var s := LanternrestScreen.open(parent)
##   s.new_run / s.continue_run / s.to_title      # the flow frees the screen
## Standalone (no open) it shows a demo town and never writes the player's files. Scene args:
##   --state=fresh|built   --cam=west|east|north|south|<x>,<y>   --hover=<place id>
##   --press=<place id>   --panel=<place id>|identity   --saved (a run in progress)   --new
##   --menu (the gear menu open)

signal new_run
signal continue_run
signal to_title

const SCENE := "res://scenes/lanternrest/lanternrest.tscn"
const DRAG_START := 5.0       # design px a press must move before it is a drag, not a tap
const KEY_SPEED := 300.0      # design px per second (arrow keys, edge scrolling)
const EDGE_BAND := 10.0       # the screen's edge strip that scrolls on PC
const WHEEL_STEP := 40.0
const FLING_DECAY := 6.0
const TOP := 28.0             # top bar height
const CAM_TIME := 0.35
const SHADE := 0.5            # the one dim behind every panel (below the top bar)
const PANEL_GAP := 14.0       # between a panel and its place
const STEM := 7.0             # a signboard's stem
const SIGN_H := 16.0
const CUE := Vector2(14, 22)  # an edge cue (left / right; turned for up / down)
const HINT_FULL := "Drag to look around. Tap a place to visit it."
const HINT_TAP := "Tap a place to visit it."
const HINT_LOOK := "Drag to look around."
const HINT_Y := 334.0
const HINT_H := 18.0

var demo := false
var cam := Vector2.ZERO
var world: Node2D
var places := {}              # id -> VillagePlace
var visible_ids: Array[String] = []
var hovered := ""
var selected := ""
var pressed_id := ""
var panel: VillagePanel = null
var panel_side := 1           # the panel's half of the view: 1 right, -1 left
var lights: TownLayers.Lights
var life: TownLayers.Life
var mist: TownLayers.Mist
var did_look := false         # this visit: the player has panned
var did_tap := false          # this visit: the player has opened a place
var _opened := false
var _ui: Control
var _shade: Control
var _lift: Control
var _gear: Button
var _menu: PanelContainer
var _settings: Control
var _base: Sprite2D
var _places_layer: Node2D
var _fog_layer: Node2D
var _panel_place := ""
var _cam_target := Vector2.ZERO
var _press := {}              # {pos, cam, moved, id}
var _vel := Vector2.ZERO
var _last_motion := Vector2.ZERO
var _last_motion_t := 0.0
var _mouse_in := false
var _mouse := Vector2(-1, -1)
var _tween: Tween
var _demo_args := {}


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
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_base = Sprite2D.new()
	_base.name = "Town"
	_base.centered = false
	_base.texture = Village.texture("town")
	world.add_child(_base)
	_places_layer = Node2D.new()
	_places_layer.name = "Places"
	world.add_child(_places_layer)
	lights = TownLayers.Lights.new()
	world.add_child(lights)
	life = TownLayers.Life.new()
	world.add_child(life)
	mist = TownLayers.Mist.new()
	world.add_child(mist)
	_fog_layer = Node2D.new()
	_fog_layer.name = "MistPlaces"
	world.add_child(_fog_layer)
	_ui = Control.new()
	_ui.name = "UI"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_gear = FlowUI.button("", 26, 22)
	_gear.name = "GearButton"
	_gear.icon = Village.texture("gear")
	_gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear.tooltip_text = "Menu"
	_gear.pressed.connect(toggle_menu)
	add_child(_gear)
	rebuild()
	set_cam(start_cam())
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
		p.get_parent().remove_child(p)
		p.queue_free()
	places.clear()
	visible_ids = Village.visible_places(GameState.meta)
	for id in visible_ids:
		var p := VillagePlace.make(id)
		if id == "lantern":
			p.crest_id = GameState.crest()
		(_fog_layer if Village.kind(id) == "fog" else _places_layer).add_child(p)
		places[id] = p
	lights.places = places
	life.places = places
	_refresh_highlights()


func view_size() -> Vector2:
	return get_viewport_rect().size


## Where the camera starts: centred on the plaza (the Vault and the lantern in view), moved just
## enough to show a newly built place too.
func start_cam() -> Vector2:
	var view := view_size()
	var c := Village.cam_for(Village.start_point(), view)
	for id in Village.unseen(GameState.meta):
		var z := Village.zone(id)
		var room := Rect2(c + Vector2(8, TOP + 8), view - Vector2(16, TOP + 8 + 24))
		if z.end.x > room.end.x:
			c.x += z.end.x - room.end.x
		if z.position.x < room.position.x:
			c.x -= room.position.x - z.position.x
		if z.end.y > room.end.y:
			c.y += z.end.y - room.end.y
		if z.position.y < room.position.y:
			c.y -= room.position.y - z.position.y
	return Village.clamp_cam(c, view)


## Top-left of the world on screen (design px): -cam on whole pixels.
func world_origin() -> Vector2:
	return -cam.round()


func set_cam(v: Vector2) -> void:
	var c := Village.clamp_cam(v, view_size())
	if c != cam:
		cam = c
		_apply_cam()


func _apply_cam() -> void:
	world.position = world_origin()
	_ui.queue_redraw()
	if _lift != null:
		_lift.queue_redraw()


func to_world(screen_pos: Vector2) -> Vector2:
	return screen_pos - world_origin()


func to_screen(world_pos: Vector2) -> Vector2:
	return world_pos + world_origin()


## A place's tap zone on screen.
func zone_on_screen(id: String) -> Rect2:
	var z := Village.zone(id)
	return Rect2(to_screen(z.position), z.size)


## The front-most place whose tap zone holds a world point ("" for none).
func place_at(world_pos: Vector2) -> String:
	for i in range(visible_ids.size() - 1, -1, -1):
		var id := visible_ids[i]
		if (places[id] as VillagePlace).contains(world_pos):
			return id
	return ""


## Slides the camera to `target` (clamped).
func glide(target: Vector2) -> void:
	_vel = Vector2.ZERO
	_cam_target = Village.clamp_cam(target, view_size())
	if _tween != null:
		_tween.kill()
	if _cam_target.distance_to(cam) < 1.0:
		set_cam(_cam_target)
		return
	_tween = create_tween()
	_tween.tween_method(set_cam, cam, _cam_target, CAM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Ends a camera slide at once (tests, captures).
func finish_camera() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		set_cam(_cam_target)
	_tween = null


## Brings a place fully into view (keyboard focus), sliding as little as needed.
func focus(id: String) -> void:
	var z := Village.zone(id)
	var view := view_size()
	var c := cam
	var room := Rect2(c + Vector2(12, TOP + 24), view - Vector2(24, TOP + 24 + 12))
	if z.position.x < room.position.x or z.end.x > room.end.x or z.position.y < room.position.y or z.end.y > room.end.y:
		c = Village.cam_for(z.get_center() - Vector2(0, 6), view)
	glide(c)


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if panel != null or _settings != null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and _menu != null:
			close_menu()
			accept_event()
			return
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					var id := place_at(to_world(mb.position))
					_press = {"pos": mb.position, "cam": cam, "moved": false, "id": id}
					_set_pressed(id)
					_vel = Vector2.ZERO
					_last_motion = mb.position
					_last_motion_t = Time.get_ticks_msec() / 1000.0
					if _tween != null:
						_tween.kill()
				elif not _press.is_empty():
					_set_pressed("")
					if not bool(_press["moved"]):
						tap(mb.position)
					_press = {}
				accept_event()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					var d := WHEEL_STEP * maxf(mb.factor, 1.0) * (-1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
					_scroll_by(Vector2(d, 0) if mb.shift_pressed else Vector2(0, d))
				accept_event()
			MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
				if mb.pressed:
					var d := WHEEL_STEP * maxf(mb.factor, 1.0) * (-1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_LEFT else 1.0)
					_scroll_by(Vector2(d, 0))
				accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse = mm.position
		_mouse_in = true
		if not _press.is_empty():
			var start: Vector2 = _press["pos"]
			if not bool(_press["moved"]) and mm.position.distance_to(start) > DRAG_START:
				_press["moved"] = true
				_looked()
				_set_hover("")
				_set_pressed("")
			if bool(_press["moved"]):
				set_cam((_press["cam"] as Vector2) - (mm.position - start))
				var now := Time.get_ticks_msec() / 1000.0
				var dt := maxf(now - _last_motion_t, 0.001)
				_vel = _vel.lerp(-(mm.position - _last_motion) / dt, 0.5)
				_last_motion = mm.position
				_last_motion_t = now
		else:
			_set_hover(place_at(to_world(mm.position)) if mm.position.y > TOP else "")
		accept_event()
	elif event is InputEventPanGesture:
		_scroll_by((event as InputEventPanGesture).delta * 8.0)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or _settings != null:
		return
	if event.is_action("ui_cancel"):
		if _menu != null:
			close_menu()
			get_viewport().set_input_as_handled()
		elif panel != null and panel.closable:
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


## Keyboard: the next place (reading order) becomes the highlighted one, and the camera follows.
func _cycle(dir: int) -> void:
	var ids := visible_ids.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var za := Village.zone(a).get_center()
		var zb := Village.zone(b).get_center()
		return za.y < zb.y if absf(za.y - zb.y) > 40.0 else za.x < zb.x)
	var i := ids.find(hovered)
	i = (i + dir + ids.size()) % ids.size() if i >= 0 else (0 if dir > 0 else ids.size() - 1)
	_set_hover(ids[i])
	focus(ids[i])


func _scroll_by(d: Vector2) -> void:
	_looked()
	if _tween != null:
		_tween.kill()
	set_cam(cam + d)


## A tap at a screen point: an edge cue pages that way, a place opens its menu.
func tap(screen_pos: Vector2) -> void:
	for c: Dictionary in cue_rects():
		if (c["rect"] as Rect2).has_point(screen_pos):
			_page(c["dir"])
			return
	if screen_pos.y <= TOP:
		return
	var id := place_at(to_world(screen_pos))
	if id != "":
		open_place(id)


func _page(dir: Vector2) -> void:
	_looked()
	glide(cam + dir * view_size() * 0.5)


func _set_hover(id: String) -> void:
	if id != hovered:
		hovered = id
		_refresh_highlights()
		_ui.queue_redraw()


func _set_pressed(id: String) -> void:
	if id != pressed_id:
		if places.has(pressed_id):
			(places[pressed_id] as VillagePlace).pressed = false
		pressed_id = id
		if places.has(id):
			(places[id] as VillagePlace).pressed = true


func _refresh_highlights() -> void:
	for id: String in places:
		(places[id] as VillagePlace).highlight = id == hovered or id == selected


func _process(delta: float) -> void:
	var d := Vector2.ZERO
	if panel == null and _settings == null and get_viewport().gui_get_focus_owner() == null:
		d.x = Input.get_axis("ui_left", "ui_right")
		d.y = Input.get_axis("ui_up", "ui_down")
		# PC: resting the pointer on the screen's edge scrolls that way
		if _mouse_in and _press.is_empty() and _menu == null and not OS.has_feature("mobile") and _mouse.x >= 0.0:
			var sr := UIText.safe_rect(self)
			if _mouse.x < sr.position.x + EDGE_BAND:
				d.x = -1.0
			elif _mouse.x > sr.end.x - EDGE_BAND:
				d.x = 1.0
			if _mouse.y > TOP and _mouse.y < TOP + EDGE_BAND:
				d.y = -1.0
			elif _mouse.y > sr.end.y - EDGE_BAND:
				d.y = 1.0
	if d != Vector2.ZERO:
		_looked()
		if _tween != null:
			_tween.kill()
		set_cam(cam + d * KEY_SPEED * delta)
	elif _press.is_empty() and _vel.length() > 5.0:
		set_cam(cam + _vel * delta)
		_vel *= exp(-FLING_DECAY * delta)
	else:
		_vel = Vector2.ZERO


# ------------------------------------------------------------------ the hint

## The first-visit hint, shortened as the player learns (a pan, a visit); gone for good once they
## have done both or finished a run (meta "village_hint_done").
func hint_text() -> String:
	var m := GameState.meta
	if bool(m.get("village_hint_done", false)) or int(m.get("runs", 0)) > 0:
		return ""
	if did_look and did_tap:
		return ""
	if did_look:
		return HINT_TAP
	if did_tap:
		return HINT_LOOK
	return HINT_FULL


func hint_rect() -> Rect2:
	var t := hint_text()
	if t == "":
		return Rect2()
	var w := UIText.width(t, UIText.BOLD)
	return Rect2(roundf((view_size().x - w) / 2.0) - 8.0, HINT_Y, w + 16.0, HINT_H)


func _looked() -> void:
	if not did_look:
		did_look = true
		_hint_learned()


func _hint_learned() -> void:
	if did_look and did_tap and not bool(GameState.meta.get("village_hint_done", false)):
		GameState.meta["village_hint_done"] = true
		GameState.save_meta()
	_ui.queue_redraw()


# ------------------------------------------------------------------ panels

## Opens a place's menu: the camera slides the place to one side, the panel opens on the other.
func open_place(id: String) -> void:
	if not places.has(id):
		return
	close_menu()
	if not did_tap:
		did_tap = true
		_hint_learned()
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
	_show_panel(p, id)


## The first visit: who carries the lantern (a panel pointing at the lantern).
func open_identity() -> void:
	var p := IdentityPanel.new()
	p.chosen.connect(func(_t: String, _c: String) -> void: close_panel())
	_show_panel(p, "lantern")


## Kind of the open panel's place ("" when none), for tests and the flow.
func panel_kind() -> String:
	if panel == null:
		return ""
	if panel is IdentityPanel:
		return "identity"
	return panel.place_id


## The place the open panel points at ("" when none).
func panel_place() -> String:
	return _panel_place if panel != null else ""


func _show_panel(p: VillagePanel, anchor: String) -> void:
	close_panel()
	_panel_place = anchor
	# one shared dim for every panel, below the top bar (the bar's numbers keep full contrast)
	_shade = Control.new()
	_shade.name = "Shade"
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.draw.connect(func() -> void: _shade.draw_rect(shade_rect(), Color(Pal.INK1, SHADE)))
	_shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and panel != null and panel.closable:
			close_panel())
	add_child(_shade)
	# the place itself (and its sign, and a pointer from the panel) above the dim
	_lift = Control.new()
	_lift.name = "Lift"
	_lift.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lift.draw.connect(_draw_lift)
	add_child(_lift)
	panel = p
	p.name = "Panel"
	p.closed.connect(close_panel)
	p.changed.connect(_on_changed)
	add_child(p)
	_place_panel()
	_place_panel.call_deferred()


## The dim behind panels: the whole view below the top bar.
func shade_rect() -> Rect2:
	var vr := get_viewport_rect()
	return Rect2(0, TOP + 2.0, vr.size.x, vr.size.y - TOP - 2.0)


## Where the camera goes and the panel sits for the open panel: the place a quarter of the way in
## from one side, the panel centred in the other half, both clear of each other.
func _place_panel() -> void:
	if panel == null or not is_instance_valid(panel):
		return
	panel.reset_size()
	var view := view_size()
	var sr := UIText.safe_rect(self)
	var z := Village.zone(_panel_place)
	var sz := panel.size
	var mid_y := TOP + (view.y - TOP) / 2.0
	var best := {}
	for side: int in [1, -1]:
		var want_x := view.x * (0.25 if side == 1 else 0.75)
		var c := Village.clamp_cam(Vector2(z.get_center().x - want_x, z.get_center().y - mid_y), view)
		var zs := Rect2(z.position - c.round(), z.size)
		var half_x := view.x * 0.5 + (view.x * 0.5 - sz.x) / 2.0 if side == 1 else (view.x * 0.5 - sz.x) / 2.0
		var px := maxf(half_x, zs.end.x + PANEL_GAP) if side == 1 else minf(half_x, zs.position.x - PANEL_GAP - sz.x)
		px = clampf(px, sr.position.x + 8.0, sr.end.x - 8.0 - sz.x)
		var py := clampf(roundf(mid_y - sz.y / 2.0), TOP + 6.0, view.y - sz.y - 6.0)
		var pr := Rect2(px, py, sz.x, sz.y)
		var cost := c.distance_to(cam) + (0.0 if not pr.intersects(zs) else 1e6)
		if best.is_empty() or cost < float(best["cost"]):
			best = {"cost": cost, "cam": c, "rect": pr, "side": side}
	panel_side = int(best["side"])
	panel.position = (best["rect"] as Rect2).position.round()
	glide(best["cam"])


func close_panel() -> void:
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
		remove_child(panel)
	panel = null
	for n: Control in [_shade, _lift]:
		if n != null and is_instance_valid(n):
			n.queue_free()
			remove_child(n)
	_shade = null
	_lift = null
	_panel_place = ""
	selected = ""
	Tip.close()
	_refresh_highlights()
	_ui.queue_redraw()


func _on_changed() -> void:
	if places.has("lantern"):
		(places["lantern"] as VillagePlace).crest_id = GameState.crest()
		(places["lantern"] as VillagePlace).queue_redraw()
	_ui.queue_redraw()


# ------------------------------------------------------------------ the gear menu

func toggle_menu() -> void:
	if _menu != null:
		close_menu()
		return
	if panel != null and panel.closable:
		close_panel()
	_menu = FlowUI.panel()
	_menu.name = "GearMenu"
	var v := FlowUI.vbox(4)
	var s := FlowUI.button("Settings", 132, 22)
	s.name = "Settings"
	s.pressed.connect(open_settings)
	v.add_child(s)
	var t := FlowUI.button("Return to title", 132, 22)
	t.name = "ToTitle"
	t.pressed.connect(func() -> void:
		close_menu()
		to_title.emit())
	v.add_child(t)
	_menu.add_child(FlowUI.margin(v, 6))
	add_child(_menu)
	_menu.reset_size()
	_menu.position = Vector2(roundf(_gear.position.x + _gear.size.x - _menu.size.x), TOP + 4.0)


func close_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
		remove_child(_menu)
	_menu = null


func open_settings() -> void:
	close_menu()
	var s := SettingsScreen.open(self)
	_settings = s
	s.closed.connect(func() -> void: _settings = null)


# ------------------------------------------------------------------ layout / draw

func _layout() -> void:
	set_cam(cam)
	_apply_cam()
	_gear.position = Vector2(roundf(UIFrame.right(self) - _gear.size.x - 4.0), 3)
	if panel != null:
		_place_panel()
		finish_camera()
	close_menu()


func _draw() -> void:
	draw_rect(get_viewport_rect(), Pal.INK1)


## Edge cues: where more town lies past the view's edges. Each sits mid-edge, slid along the edge
## off any place, signboard or the hint (and left out where there is no clear spot).
func cue_rects() -> Array:
	var out: Array = []
	if panel != null:
		return out
	var view := view_size()
	var sr := UIText.safe_rect(self)
	var maxc := Village.clamp_cam(Vector2(INF, INF), view)
	var avoid: Array[Rect2] = []
	for id in visible_ids:
		avoid.append(zone_on_screen(id).grow(2))
	for id in shown_plates():
		avoid.append(plate_rect(id).grow(2))
	if hint_text() != "":
		avoid.append(hint_rect().grow(2))
	var dirs := []
	if cam.x > 0.5:
		dirs.append(Vector2.LEFT)
	if cam.x < maxc.x - 0.5:
		dirs.append(Vector2.RIGHT)
	if cam.y > 0.5:
		dirs.append(Vector2.UP)
	if cam.y < maxc.y - 0.5:
		dirs.append(Vector2.DOWN)
	for dir: Vector2 in dirs:
		for off: float in [0.0, -36.0, 36.0, -72.0, 72.0, -108.0, 108.0, -144.0, 144.0]:
			var r: Rect2
			if dir.x != 0.0:
				var y := roundf(TOP + (view.y - TOP) / 2.0 - CUE.y / 2.0 + off)
				r = Rect2(sr.position.x + 2.0 if dir.x < 0 else sr.end.x - 2.0 - CUE.x, y, CUE.x, CUE.y)
			else:
				var x := roundf(view.x / 2.0 - CUE.y / 2.0 + off)
				r = Rect2(x, TOP + 4.0 if dir.y < 0 else view.y - 4.0 - CUE.x, CUE.y, CUE.x)
			var clear := true
			for a: Rect2 in avoid:
				if a.intersects(r):
					clear = false
					break
			if clear:
				out.append({"dir": dir, "rect": r})
				break
	return out


## Signboards, edge cues, the top bar and the hint, on the UI layer (native resolution).
func _draw_ui() -> void:
	var ui := _ui
	var sr := UIText.safe_rect(self)
	var unseen := Village.unseen(GameState.meta)
	for id in shown_plates():
		if id != selected:
			_draw_plate(ui, id, unseen.has(id))
	for c: Dictionary in cue_rects():
		_draw_cue(ui, c["rect"], c["dir"])
	# top bar: where you are, whose town, what it holds
	UIFrame.top_bar(ui)
	var l := sr.position.x
	UIText.draw(ui, Vector2(l + 10, UIText.centered_y(0, TOP, UIText.SERIF, UIText.TITLE)), "Lanternrest", Pal.AMBER6, UIText.SERIF, UIText.TITLE)
	var tx := l + 18 + UIText.width("Lanternrest", UIText.SERIF, UIText.TITLE)
	Crests.draw(ui, Vector2(roundf(tx), 7), GameState.crest(), 1)
	UIText.draw(ui, Vector2(roundf(tx + 18), UIText.centered_y(0, TOP, UIText.BOLD)), GameState.team_name(), Pal.INK9, UIText.BOLD)
	var res := currency_text()
	var rw := UIText.width(res, UIText.BOLD)
	UIText.draw(ui, Vector2(roundf(_gear.position.x - 10 - rw), UIText.centered_y(0, TOP, UIText.BOLD)), res, Pal.AMBER6, UIText.BOLD)
	var hint := hint_text()
	if hint != "" and panel == null:
		var hr := hint_rect()
		ui.draw_rect(hr, Color(Pal.INK1, 0.85))
		ui.draw_rect(hr, Pal.INK5, false, 1.0)
		UIText.draw(ui, Vector2(hr.position.x + 8, UIText.centered_y(HINT_Y, HINT_H, UIText.BOLD)), hint, Pal.INK9, UIText.BOLD)


func currency_text() -> String:
	var m := GameState.meta
	return "Glimmers %d   Shards %d" % [int(m["glimmers"]), int(m["shards"])]


func _draw_cue(ci: CanvasItem, r: Rect2, dir: Vector2) -> void:
	ci.draw_rect(r, Color(Pal.INK1, 0.72))
	ci.draw_rect(r, Pal.INK5, false, 1.0)
	var c := r.get_center().round()
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([c + dir * 4.0, c - dir * 3.0 + side * 6.0, c - dir * 3.0 - side * 6.0])
	ci.draw_colored_polygon(pts, Pal.AMBER5)


## The selected place above the dim, its signboard, and a pointer from the panel to it.
func _draw_lift() -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var id := _panel_place
	if places.has(id):
		var p := places[id] as VillagePlace
		p.draw_on(_lift, to_screen(p.position))
		_draw_plate(_lift, id, false)
	var zs := zone_on_screen(id)
	var pr := Rect2(panel.position, panel.size)
	var px := pr.position.x if panel_side == 1 else pr.end.x
	var target := Vector2(zs.end.x + 2.0 if panel_side == 1 else zs.position.x - 2.0, clampf(zs.get_center().y, zs.position.y + 4, zs.end.y - 4))
	var y := clampf(target.y, pr.position.y + 10.0, pr.end.y - 10.0)
	var from := Vector2(px, y)
	_lift.draw_line(from, target, Pal.AMBER5, 1.0)
	var s := float(panel_side)
	var notch := PackedVector2Array([from + Vector2(-s * 5.0, 0), from + Vector2(0, -5), from + Vector2(0, 5)])
	_lift.draw_colored_polygon(notch, Pal.AMBER5)
	_lift.draw_rect(Rect2(target - Vector2(1, 1), Vector2(3, 3)), Pal.AMBER6)


## A signboard's rect on screen (design px): hanging above its place's sign point on a stem, kept
## inside the safe edges and under the top bar.
func plate_rect(id: String, is_new := false) -> Rect2:
	var sr := UIText.safe_rect(self)
	var w := UIText.width(Village.place_name(id), UIText.BOLD)
	var tw := UIText.width("NEW", UIText.BOLD) + 8.0 if is_new else 0.0
	var pw := roundf(w + 14.0 + tw)
	var at := to_screen(Village.sign_at(id))
	var x := clampf(roundf(at.x - pw / 2.0), sr.position.x + 4.0, sr.end.x - 4.0 - pw)
	var y := maxf(roundf(at.y - STEM - SIGN_H), TOP + 4.0)
	return Rect2(x, y, pw, SIGN_H)


## Places whose signboards show now: the main places always, others while hovered or open; a place
## whose sign point is off screen shows none.
func shown_plates() -> Array[String]:
	var out: Array[String] = []
	var view := view_size()
	for id in visible_ids:
		if bool(Village.PLACES[id].get("always_sign", false)) or id == hovered or id == selected:
			var at := to_screen(Village.sign_at(id))
			if at.x < 0.0 or at.x > view.x or at.y < TOP or at.y > view.y:
				continue
			out.append(id)
	return out


func _draw_plate(ci: CanvasItem, id: String, is_new: bool) -> void:
	var label := Village.place_name(id)
	var main := Village.kind(id) in ["lantern", "vault", "building"]
	var lit := id == hovered or id == selected
	var r := plate_rect(id, is_new)
	var edge := Pal.AMBER5 if lit else (Pal.AMBER3 if main else Pal.INK6)
	# the stem down to the place
	var at := to_screen(Village.sign_at(id)).round()
	var sx := clampf(at.x, r.position.x + 3.0, r.end.x - 4.0)
	if at.y > r.end.y:
		ci.draw_rect(Rect2(sx, r.end.y, 1, at.y - r.end.y), edge)
		ci.draw_rect(Rect2(sx - 1, at.y - 1, 3, 2), edge)
	# the board: dark wood in the frame style, a lit top edge and corner nails
	ci.draw_rect(r, Color(Pal.INK1, 0.92))
	ci.draw_rect(r, edge, false, 1.0)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), Color(Pal.INK4, 0.9))
	for cx: float in [r.position.x + 2.0, r.end.x - 3.0]:
		ci.draw_rect(Rect2(cx, r.position.y + 2.0, 1, 1), edge)
	var col := Pal.AMBER6 if main or lit else Pal.INK9
	UIText.draw(ci, Vector2(r.position.x + 7.0, UIText.centered_y(r.position.y, SIGN_H, UIText.BOLD)), label, col, UIText.BOLD)
	if is_new:
		var w := UIText.width(label, UIText.BOLD)
		var tw := UIText.width("NEW", UIText.BOLD) + 8.0
		var tr := Rect2(r.position.x + 7.0 + w + 4.0, r.position.y + 3.0, tw - 2.0, SIGN_H - 6.0)
		ci.draw_rect(tr.grow_individual(0, 1, 0, 1), Pal.CRYSTAL2)
		UIText.draw(ci, Vector2(tr.position.x + 3.0, UIText.centered_y(r.position.y, SIGN_H, UIText.BOLD)), "NEW", Pal.CRYSTAL5, UIText.BOLD, UIText.LABEL, false)


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
	var view := view_size()
	var c := String(_demo_args.get("cam", ""))
	match c:
		"west":
			set_cam(Vector2(0, cam.y))
		"east":
			set_cam(Vector2(INF, cam.y))
		"north":
			set_cam(Vector2(cam.x, 0))
		"south":
			set_cam(Vector2(cam.x, INF))
		"":
			pass
		_:
			var xy := c.split(",")
			if xy.size() == 2:
				set_cam(Village.cam_for(Vector2(float(xy[0]), float(xy[1])), view))
	for k in ["hover", "press"]:
		if _demo_args.has(k) and c == "":
			focus(String(_demo_args[k]))
			finish_camera()
	if _demo_args.has("hover"):
		_set_hover(String(_demo_args["hover"]))
	if _demo_args.has("press"):
		_set_hover(String(_demo_args["press"]))
		_set_pressed(String(_demo_args["press"]))
	if _demo_args.has("menu"):
		toggle_menu()
	if _demo_args.has("panel"):
		if String(_demo_args["panel"]) == "identity":
			open_identity()
		else:
			open_place(String(_demo_args["panel"]))
		finish_camera()
