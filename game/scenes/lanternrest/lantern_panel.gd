class_name LanternPanel
extends VillagePanel
## The Lantern's menu: the village heart. What the village has gathered (runs, victories, the
## deepest floor, the story chapter), the team's identity (the Banner Hall's name and crest, shown
## to rivals on the PvP splash; more crests are remembered with Glimmers) and Glimmers forming
## Shards. Saves at once (GameState).

const EchoPool = preload("res://core/run/echo_pool.gd")
const HALL_W := 280
const CREST_TILE := Vector2(32, 38)

var _sel_crest := ""
var _crest_tiles := {}
var _crest_info: VBoxContainer
var _name_edit: LineEdit
var _shard_btn: Button
var _progress: Label
var _bar: Control


func _init() -> void:
	place_id = "lantern"
	title = "The Lantern"
	width = HALL_W


func _build() -> void:
	_sel_crest = GameState.crest()
	_progress = FlowUI.label("", &"MutedLabel", null, HALL_W)
	_progress.name = "Progress"
	body.add_child(_progress)
	body.add_child(FlowUI.label("TEAM NAME", &"TagLabel"))
	var row := FlowUI.hbox(4)
	_name_edit = LineEdit.new()
	_name_edit.name = "TeamName"
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
	_name_edit.text_submitted.connect(func(_t: String) -> void: save_name())
	_name_edit.focus_exited.connect(save_name)
	row.add_child(_name_edit)
	var rnd := FlowUI.button("Random", 66, 22)
	rnd.pressed.connect(func() -> void:
		_name_edit.text = EchoPool.team_name(randi())
		save_name())
	row.add_child(rnd)
	body.add_child(row)
	body.add_child(FlowUI.label("CREST", &"TagLabel"))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 1)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id: String in Crests.ORDER:
		var t := _crest_tile(id)
		grid.add_child(t)
		_crest_tiles[id] = t
	body.add_child(grid)
	_crest_info = FlowUI.vbox(4)
	body.add_child(_crest_info)
	# Glimmers form Shards
	body.add_child(FlowUI.label("GLIMMERS INTO SHARDS", &"TagLabel"))
	var srow := FlowUI.hbox(6)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(150, 22)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(func() -> void:
		var k := clampf(float(GameState.meta.get("glimmers", 0)) / GameState.GLIMMERS_PER_SHARD, 0.0, 1.0)
		_bar.draw_rect(Rect2(0, 8, 150, 8), Pal.INK1)
		_bar.draw_rect(Rect2(1, 9, roundf(148 * k), 6), Pal.CRYSTAL4)
		_bar.draw_rect(Rect2(1, 9, roundf(148 * k), 1), Pal.CRYSTAL5))
	srow.add_child(_bar)
	_shard_btn = FlowUI.button("Form a Shard", 110, 22)
	_shard_btn.name = "FormShard"
	_shard_btn.pressed.connect(func() -> void:
		if GameState.form_shard():
			changed.emit()
		refresh())
	srow.add_child(_shard_btn)
	body.add_child(srow)
	body.add_child(FlowUI.label("%d Glimmers form one Shard." % GameState.GLIMMERS_PER_SHARD, &"MutedLabel"))
	refresh()


func _crest_tile(id: String) -> Button:
	var b := FlowUI.button("", CREST_TILE.x, CREST_TILE.y)
	b.name = "Crest_" + id
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


func select_crest(id: String) -> void:
	_sel_crest = id
	if GameState.has_crest(id):
		GameState.set_team(_name_edit.text, id)
		changed.emit()
	refresh()


func unlock_crest() -> void:
	if GameState.unlock_crest(_sel_crest):
		GameState.set_team(_name_edit.text, _sel_crest)
		changed.emit()
	refresh()


func save_name() -> void:
	GameState.set_team(_name_edit.text, GameState.crest())
	if _name_edit.text.strip_edges() == "":
		_name_edit.text = GameState.team_name()
	changed.emit()


func close() -> void:
	save_name()
	super.close()


func refresh() -> void:
	var m := GameState.meta
	var parts := ["Runs %d" % int(m["runs"]), "Victories %d" % int(m["victories"])]
	if int(m["best_floor"]) > 0:
		parts.append("Deepest floor %d" % int(m["best_floor"]))
	parts.append("Chapter %d" % int(m["story_chapter"]))
	_progress.text = "   ".join(parts)
	_shard_btn.disabled = not GameState.can_form_shard()
	_bar.queue_redraw()
	for id: String in _crest_tiles:
		(_crest_tiles[id] as Control).queue_redraw()
	for c: Node in _crest_info.get_children():
		c.queue_free()
	var row := FlowUI.hbox(6)
	if GameState.has_crest(_sel_crest):
		row.add_child(FlowUI.label("%s crest. Your Echoes carry it." % Crests.name_of(_sel_crest), &"MutedLabel", null, HALL_W))
	else:
		var can := int(GameState.meta["glimmers"]) >= GameState.CREST_COST
		row.add_child(FlowUI.label("%s crest: %d Glimmers" % [Crests.name_of(_sel_crest), GameState.CREST_COST], &"GoldLabel", Pal.CRYSTAL5 if can else Pal.INK9, HALL_W - 90))
		var b := FlowUI.button("Remember", 84, 22)
		b.name = "Remember"
		b.disabled = not can
		b.pressed.connect(unlock_crest)
		row.add_child(b)
	_crest_info.add_child(row)
