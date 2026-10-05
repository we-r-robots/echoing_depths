class_name LanternrestScreen
extends Control
## Lanternrest, minimal (04-meta-progression.md): what the village holds (Glimmers, Shards), the
## Training Grounds (unlock formation shapes with Shards, following Formations.UNLOCK_TREE) and
## the Banner Hall (the team's name and crest, shown to rivals on the PvP splash; more crests are
## remembered with Glimmers). Glimmers form Shards at the reference rate. Everything saves at once
## (GameState). The village grid, buildings and story NPCs are not built yet.
##
##   var s := LanternrestScreen.open(parent)
##   s.new_run.connect(...); s.to_title.connect(...)     # the flow frees the screen
## Standalone (no open) it shows a demo village and never writes the player's files.

signal new_run
signal to_title

const SCENE := "res://scenes/flow/lanternrest.tscn"
const BACKDROP := preload("res://assets/encounter/campfire/bg.png")
const GLOW := preload("res://assets/encounter/campfire/glow.png")
const GameData = preload("res://core/game_data.gd")
const EchoPool = preload("res://core/run/echo_pool.gd")
## Shape tiles: 3 columns of icon + name (the longest name, "Lumari Chorus", is 66 design px).
const TILE := Vector2(94, 32)
const TILE_COLS := 3
const TILE_PAD := 8          # every name keeps at least this much room to the tile's edges
const TILE_ICON_PX := 4      # shape icon cell size; a 4-tall shape is 19 px, centred in the tile
const TILE_TEXT_X := 20      # names start here, right of the icon column
const GROUNDS_W := 290       # TILE_COLS * TILE.x + 2 * 4
const HALL_W := 266
const CREST_TILE := Vector2(32, 38)

var demo := false
var _opened := false
var _sel_shape := ""
var _sel_crest := ""
var _grounds: PanelContainer
var _hall: PanelContainer
var _shape_tiles := {}
var _crest_tiles := {}
var _detail: VBoxContainer
var _crest_info: VBoxContainer
var _name_edit: LineEdit
var _shard_btn: Button
var _res: Label
var _go: Button
var _title_btn: Button
var _msg := ""


static func open(parent: Node) -> LanternrestScreen:
	var s: LanternrestScreen = load(SCENE).instantiate()
	s._opened = true
	parent.add_child(s)
	return s


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _opened:
		# demo: an in-memory village with a few Shards to spend, nothing written to disk
		demo = true
		GameState.read_only = true
		GameState.meta = GameState.default_meta()
		GameState.settings = GameState.default_settings()
		GameState._loaded = true
		GameState.meta.merge({"glimmers": 87, "shards": 3, "runs": 4, "glimmers_total": 187, "shards_total": 2}, true)
		(GameState.meta["unlocked_formations"] as Array).append("keystone")
		(GameState.meta["crests"] as Array).append("star")
	GameState.ensure()
	_sel_crest = GameState.crest()
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()


func _exit_tree() -> void:
	if demo:
		GameState.read_only = false
		GameState.load_all()   # back to the player's own state


# ------------------------------------------------------------------ build

func _build() -> void:
	_res = FlowUI.label("", &"GoldLabel", null, 220, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_res)
	_grounds = _build_grounds()
	add_child(_grounds)
	_hall = _build_hall()
	add_child(_hall)
	_title_btn = FlowUI.button("Title", 76, 22)
	_title_btn.pressed.connect(func() -> void:
		_save_name()
		to_title.emit())
	add_child(_title_btn)
	_go = FlowUI.primary("New run", 112)
	_go.pressed.connect(func() -> void:
		_save_name()
		new_run.emit())
	add_child(_go)


func _build_grounds() -> PanelContainer:
	var p := FlowUI.panel()
	var v := FlowUI.vbox(5)
	v.custom_minimum_size.x = GROUNDS_W
	v.add_child(FlowUI.label("Training Grounds", &"HeadingLabel"))
	v.add_child(FlowUI.para("A shape's bonus and behaviour work in your runs once it is learned here. New shapes grow from ones you know.", GROUNDS_W, Pal.INK9))
	var grid := GridContainer.new()
	grid.columns = TILE_COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s: Dictionary in GameData.Formations.SHAPES:
		var id := String(s["id"])
		var t := _shape_tile(s)
		grid.add_child(t)
		_shape_tiles[id] = t
	v.add_child(grid)
	_detail = FlowUI.vbox(4)
	v.add_child(_detail)
	p.add_child(FlowUI.margin(v, 8))
	return p


func _shape_tile(s: Dictionary) -> Button:
	var id := String(s["id"])
	var b := FlowUI.button("", TILE.x, TILE.y)
	b.theme_type_variation = &"ChoiceButton"
	b.pressed.connect(select_shape.bind(id))
	var nm := FlowUI.label(String(s["name"]), &"HeaderLabel", null, TILE.x - TILE_TEXT_X - TILE_PAD)
	nm.name = "Name"
	nm.position = Vector2(TILE_TEXT_X, 0)
	nm.size = Vector2(TILE.x - TILE_TEXT_X - TILE_PAD, TILE.y)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(nm)
	b.draw.connect(func() -> void:
		var known := GameState.is_shape_unlocked(id)
		var avail := GameState.shape_available(id)
		var fill := Pal.AMBER5 if known else (Pal.CRYSTAL4 if avail else Pal.INK6)
		FormationWords.draw_shape_glyph(b, shape_icon_pos(s), s, TILE_ICON_PX, fill, Pal.INK3)
		if not known:
			# a corner badge on the tile's top-right edge, clear of the name
			var lock := preload("res://ui/effect_icons/lock.png")
			b.draw_texture(lock, Vector2(TILE.x - 7, -3), Pal.CRYSTAL4 if avail else Pal.INK6)
		if id == _sel_shape:
			b.draw_rect(Rect2(Vector2.ZERO, TILE), Pal.AMBER6, false, 1.0))
	return b


## Top-left of a shape's icon inside its tile: centred vertically, in a fixed icon column.
static func shape_icon_pos(s: Dictionary) -> Vector2:
	var lo := 99
	var hi := 0
	for c: Array in s["cells"]:
		lo = mini(lo, int(c[1]))
		hi = maxi(hi, int(c[1]))
	var rows := maxi(1, hi - lo + 1)
	var gh := rows * TILE_ICON_PX + rows - 1
	return Vector2(5, roundf((TILE.y - gh) / 2.0))


## The rect the shape icon covers inside its tile (frame included), for tests.
static func shape_icon_rect(s: Dictionary) -> Rect2:
	var p := shape_icon_pos(s)
	var lo := 99
	var hi := 0
	for c: Array in s["cells"]:
		lo = mini(lo, int(c[1]))
		hi = maxi(hi, int(c[1]))
	var rows := maxi(1, hi - lo + 1)
	return Rect2(p - Vector2.ONE, Vector2(2 * TILE_ICON_PX + 3, rows * TILE_ICON_PX + rows + 1))


func _build_hall() -> PanelContainer:
	var p := FlowUI.panel()
	var v := FlowUI.vbox(5)
	v.custom_minimum_size.x = HALL_W
	v.add_child(FlowUI.label("Banner Hall", &"HeadingLabel"))
	v.add_child(FlowUI.para("Your team's name and crest, carried by your Echoes and shown to rivals before every Echo fight.", HALL_W, Pal.INK9))
	v.add_child(FlowUI.label("TEAM NAME", &"TagLabel"))
	var row := FlowUI.hbox(4)
	_name_edit = LineEdit.new()
	_name_edit.text = GameState.team_name()
	_name_edit.max_length = GameState.TEAM_MAX
	_name_edit.custom_minimum_size = Vector2(HALL_W - 70, 22)
	_name_edit.add_theme_font_override("font", UIText.BOLD)
	_name_edit.add_theme_font_size_override("font_size", UIText.BODY)
	_name_edit.add_theme_color_override("font_color", Pal.INK10)
	_name_edit.add_theme_color_override("caret_color", Pal.AMBER6)
	_name_edit.add_theme_color_override("selection_color", Pal.INK5)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.INK1
	sb.border_color = Pal.INK5
	sb.set_border_width_all(1)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	var sbf := sb.duplicate() as StyleBoxFlat
	sbf.border_color = Pal.AMBER5
	_name_edit.add_theme_stylebox_override("normal", sb)
	_name_edit.add_theme_stylebox_override("focus", sbf)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _save_name())
	_name_edit.focus_exited.connect(_save_name)
	row.add_child(_name_edit)
	var rnd := FlowUI.button("Random", 66, 22)
	rnd.pressed.connect(func() -> void:
		_name_edit.text = EchoPool.team_name(randi())
		_save_name())
	row.add_child(rnd)
	v.add_child(row)
	v.add_child(FlowUI.label("CREST", &"TagLabel"))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 1)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id: String in Crests.ORDER:
		var t := _crest_tile(id)
		grid.add_child(t)
		_crest_tiles[id] = t
	v.add_child(grid)
	_crest_info = FlowUI.vbox(4)
	v.add_child(_crest_info)
	# Glimmers form Shards
	v.add_child(FlowUI.label("THE LANTERN", &"TagLabel"))
	var srow := FlowUI.hbox(6)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(140, 22)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var k := clampf(float(GameState.meta.get("glimmers", 0)) / GameState.GLIMMERS_PER_SHARD, 0.0, 1.0)
		bar.draw_rect(Rect2(0, 8, 140, 8), Pal.INK1)
		bar.draw_rect(Rect2(1, 9, roundf(138 * k), 6), Pal.CRYSTAL4)
		bar.draw_rect(Rect2(1, 9, roundf(138 * k), 1), Pal.CRYSTAL5))
	srow.add_child(bar)
	_shard_btn = FlowUI.button("Form a Shard", 110, 22)
	_shard_btn.pressed.connect(func() -> void:
		if GameState.form_shard():
			_msg = "The Glimmers gather into a Shard."
		_refresh())
	srow.add_child(_shard_btn)
	v.add_child(srow)
	v.add_child(FlowUI.label("%d Glimmers form one Shard." % GameState.GLIMMERS_PER_SHARD, &"MutedLabel"))
	p.add_child(FlowUI.margin(v, 8))
	return p


func _crest_tile(id: String) -> Button:
	var b := FlowUI.button("", CREST_TILE.x, CREST_TILE.y)
	b.theme_type_variation = &"ChoiceButton"
	b.pressed.connect(select_crest.bind(id))
	b.draw.connect(func() -> void:
		var owned := GameState.has_crest(id)
		Crests.draw(b, Vector2(3, 4), id, 2, not owned)
		if not owned:
			b.draw_texture(preload("res://ui/effect_icons/lock.png"), Vector2(CREST_TILE.x - 11, CREST_TILE.y - 11), Pal.INK8)
		if id == GameState.crest():
			b.draw_rect(Rect2(Vector2.ZERO, CREST_TILE), Pal.AMBER6, false, 1.0)
		elif id == _sel_crest:
			b.draw_rect(Rect2(Vector2.ZERO, CREST_TILE), Pal.CRYSTAL4, false, 1.0))
	return b


# ------------------------------------------------------------------ actions

func select_shape(id: String) -> void:
	_sel_shape = id
	_msg = ""
	_refresh()


func unlock_selected() -> void:
	if GameState.unlock_shape(_sel_shape):
		_msg = "%s is learned. It fights with its bonus from your next run." % FormationWords.shape_by_id(_sel_shape)["name"]
	_refresh()


func select_crest(id: String) -> void:
	_sel_crest = id
	if GameState.has_crest(id):
		GameState.set_team(_name_edit.text, id)
	_refresh()


func unlock_crest() -> void:
	if GameState.unlock_crest(_sel_crest):
		GameState.set_team(_name_edit.text, _sel_crest)
	_refresh()


func _save_name() -> void:
	GameState.set_team(_name_edit.text, GameState.crest())
	if _name_edit.text.strip_edges() == "":
		_name_edit.text = GameState.team_name()
	queue_redraw()


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	var m := GameState.meta
	_res.text = "Glimmers %d   Shards %d" % [int(m["glimmers"]), int(m["shards"])]
	_shard_btn.disabled = not GameState.can_form_shard()
	for id: String in _shape_tiles:
		(_shape_tiles[id] as Control).queue_redraw()
	for id: String in _crest_tiles:
		(_crest_tiles[id] as Control).queue_redraw()
	_refresh_detail()
	_refresh_crest()
	_layout.call_deferred()


func _refresh_detail() -> void:
	for c: Node in _detail.get_children():
		c.queue_free()
	if _sel_shape == "":
		var known := (GameState.meta["unlocked_formations"] as Array).size()
		_detail.add_child(FlowUI.label("%d of %d shapes learned. Tap a shape." % [known, GameData.Formations.SHAPES.size()], &"MutedLabel", null, GROUNDS_W))
		if _msg != "":
			_detail.add_child(FlowUI.label(_msg, &"GoldLabel", Pal.AMBER6, GROUNDS_W))
		return
	var s := FormationWords.shape_by_id(_sel_shape)
	var row := FlowUI.hbox(4)
	row.add_child(FlowUI.label(String(s["name"]), &"GoldLabel"))
	for e: Dictionary in EffectIcons.formation_effects(s):
		var chip := EffectChip.new()
		row.add_child(chip)
		chip.setup(e, "auto")
	_detail.add_child(row)
	var state := ""
	var col := Pal.INK9
	var can := false
	if GameState.is_shape_unlocked(_sel_shape):
		state = "Learned: it fights with its bonus and behaviour."
		col = Pal.AMBER6
	elif GameState.shape_available(_sel_shape):
		var cost := GameState.shape_cost(_sel_shape)
		can = int(GameState.meta["shards"]) >= cost
		state = "Learn for %d Shard%s." % [cost, "" if cost == 1 else "s"] + ("" if can else " Not enough Shards yet.")
		col = Pal.CRYSTAL5
	else:
		var names: Array = []
		for pid: String in GameState.shape_parents(_sel_shape):
			names.append(String(FormationWords.shape_by_id(pid).get("name", pid)))
		state = "Grows from %s: learn that first." % " or ".join(names)
	var row2 := FlowUI.hbox(6)
	row2.add_child(FlowUI.label(state if _msg == "" else _msg, &"GoldLabel", col if _msg == "" else Pal.AMBER6, 220))
	if can:
		var b := FlowUI.button("Learn", 64, 22)
		b.pressed.connect(unlock_selected)
		row2.add_child(b)
	_detail.add_child(row2)


func _refresh_crest() -> void:
	for c: Node in _crest_info.get_children():
		c.queue_free()
	var row := FlowUI.hbox(6)
	if GameState.has_crest(_sel_crest):
		row.add_child(FlowUI.label("%s crest. Your Echoes carry it." % Crests.name_of(_sel_crest), &"MutedLabel", null, HALL_W))
	else:
		var can := int(GameState.meta["glimmers"]) >= GameState.CREST_COST
		row.add_child(FlowUI.label("%s crest: %d Glimmers" % [Crests.name_of(_sel_crest), GameState.CREST_COST], &"GoldLabel", Pal.CRYSTAL5 if can else Pal.INK9, HALL_W - 90))
		var b := FlowUI.button("Remember", 84, 22)
		b.disabled = not can
		b.pressed.connect(unlock_crest)
		row.add_child(b)
	_crest_info.add_child(row)


# ------------------------------------------------------------------ layout / draw

func _layout() -> void:
	var fr := UIText.frame_rect(self)
	var fx := fr.position.x
	_grounds.reset_size()
	_hall.reset_size()
	_grounds.position = Vector2(fx + 8, 36)
	_hall.position = Vector2(fx + 632 - _hall.size.x, 36)
	_res.position = Vector2(roundf(UIFrame.right(self) - 230), 8)
	_title_btn.position = Vector2(roundf(UIFrame.left(self) + 8), 334)
	_go.position = Vector2(roundf(UIFrame.right(self) - 120), 327)
	queue_redraw()


func _draw() -> void:
	var dim := Pal.INK1
	dim.a = 0.72
	UIFrame.backdrop(self, BACKDROP, dim, [GLOW])
	UIFrame.top_bar(self)
	var l := UIFrame.left(self)
	PartyDraw.text(self, Vector2(l + 10, UIText.centered_y(0, 28, UIText.SERIF, UIText.TITLE)), "Lanternrest", Pal.AMBER6, UIText.SERIF, UIText.TITLE)
	var tx := l + 18 + PartyDraw.text_w("Lanternrest", UIText.SERIF, UIText.TITLE)
	Crests.draw(self, Vector2(tx, 7), GameState.crest(), 1)
	PartyDraw.text(self, Vector2(tx + 18, UIText.centered_y(0, 28, UIText.BOLD)), GameState.team_name(), Pal.INK9, UIText.BOLD)
