class_name TrainingGroundsPanel
extends VillagePanel
## The Training Grounds' menu (opened from the barracks yard): learn formation shapes with Shards,
## following Formations.UNLOCK_TREE (a shape grows from one you know). Saves at once (GameState).

const GameData = preload("res://core/game_data.gd")
## Shape tiles: 3 columns of icon + name (the longest name, "Lumari Chorus", is 66 design px).
const TILE := Vector2(94, 32)
const TILE_COLS := 3
const TILE_PAD := 8          # every name keeps at least this much room to the tile's edges
const TILE_ICON_PX := 4      # shape icon cell size; a 4-tall shape is 19 px, centred in the tile
const TILE_TEXT_X := 20      # names start here, right of the icon column
const GROUNDS_W := 290       # TILE_COLS * TILE.x + 2 * 4

var _sel_shape := ""
var _shape_tiles := {}
var _detail: VBoxContainer
var _msg := ""


func _init() -> void:
	place_id = "grounds"
	title = "Training Grounds"
	width = GROUNDS_W


func _build() -> void:
	body.add_child(FlowUI.para("A shape's bonus and behaviour work in your runs once it is learned here. New shapes grow from ones you know.", GROUNDS_W, Pal.INK9))
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
	body.add_child(grid)
	_detail = FlowUI.vbox(4)
	body.add_child(_detail)
	refresh()


func _shape_tile(s: Dictionary) -> Button:
	var id := String(s["id"])
	var b := FlowUI.button("", TILE.x, TILE.y)
	b.name = "Shape_" + id
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


func select_shape(id: String) -> void:
	_sel_shape = id
	_msg = ""
	refresh()


func unlock_selected() -> void:
	if GameState.unlock_shape(_sel_shape):
		_msg = "%s is learned. It fights with its bonus from your next run." % FormationWords.shape_by_id(_sel_shape)["name"]
		changed.emit()
	refresh()


func refresh() -> void:
	for id: String in _shape_tiles:
		(_shape_tiles[id] as Control).queue_redraw()
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
	var line := FlowUI.label(state if _msg == "" else _msg, &"GoldLabel", col if _msg == "" else Pal.AMBER6, 220)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row2.add_child(line)
	if can:
		var b := FlowUI.button("Learn", 64, 22)
		b.name = "Learn"
		b.pressed.connect(unlock_selected)
		row2.add_child(b)
	_detail.add_child(row2)
