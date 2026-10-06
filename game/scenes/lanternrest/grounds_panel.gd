class_name TrainingGroundsPanel
extends VillagePanel
## The Training Grounds' menu (opened from the barracks yard): learn formation shapes with Shards,
## following Formations.UNLOCK_TREE (a shape grows from one you know). Saves at once (GameState).

const GameData = preload("res://core/game_data.gd")
## Shape tiles: 3 columns of icon + name, and under the name the shape's state, every status line
## starting with its icon at the name's left edge (one alignment): a check and "Learned", a Shard
## and its price when it can be learned now, or (dimmed) a lock and the shape it grows from
## (GameState.shape_parents). The icon is the shape on the whole 2 x 4 formation board in 6 px
## cells (round 3: big enough to read). The longest name, "Lumari Chorus", is 66 px.
const TILE := Vector2(98, 37)
const TILE_COLS := 3
const TILE_PAD := 8          # every name keeps at least this much room to the tile's edges
const TILE_ICON_PX := 6      # board cell size: the 4-row board is 27 px, centred in the tile
const BOARD_ROWS := 4
const TILE_TEXT_X := 23      # names and status lines start here, right of the icon column
const STATUS_ICON := 11      # the check / Shard / lock before the status text
const LOCK := preload("res://ui/effect_icons/lock.png")
const GROUNDS_W := 302       # TILE_COLS * TILE.x + 2 * 4
## The intro: one line that fits the panel (no orphaned word).
const INTRO := ["Learn shapes with Shards. Each grows from one you know."]

var _sel_shape := ""
var _shape_tiles := {}
var _detail: VBoxContainer
var _msg := ""


func _init() -> void:
	place_id = "grounds"
	title = "Training Grounds"
	width = GROUNDS_W


func _build() -> void:
	for line: String in INTRO:
		var l := FlowUI.para(line, GROUNDS_W, Pal.INK9)
		l.name = "Intro"
		body.add_child(l)
	var grid := GridContainer.new()
	grid.columns = TILE_COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
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
	nm.position = Vector2(TILE_TEXT_X, 2)
	nm.size = Vector2(TILE.x - TILE_TEXT_X - TILE_PAD, 16)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(nm)
	var st := FlowUI.label("", &"MutedLabel", null, TILE.x - TILE_TEXT_X - TILE_PAD - STATUS_ICON)
	st.name = "Status"
	st.position = Vector2(TILE_TEXT_X + STATUS_ICON, 19)
	st.size = Vector2(TILE.x - TILE_TEXT_X - TILE_PAD - STATUS_ICON, 15)
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(st)
	b.draw.connect(func() -> void:
		var state := shape_state(id)
		var fill := Pal.AMBER5 if state == "learned" else (Pal.CRYSTAL4 if state == "learnable" else Pal.INK6)
		FormationWords.draw_glyph(b, shape_icon_pos(s), s.get("cells", []), TILE_ICON_PX, fill, Pal.INK3, BOARD_ROWS)
		var ic := Vector2(TILE_TEXT_X, 22)
		if state == "learned":
			# a check mark
			for k in 3:
				b.draw_rect(Rect2(ic + Vector2(k, 4 + k), Vector2(1, 1)), Pal.AMBER6)
			for k in 5:
				b.draw_rect(Rect2(ic + Vector2(3 + k, 5 - k), Vector2(1, 1)), Pal.AMBER6)
		elif state == "learnable":
			# a Shard: a small crystal
			b.draw_colored_polygon(PackedVector2Array([ic + Vector2(4, 1), ic + Vector2(8, 5), ic + Vector2(4, 10), ic + Vector2(0, 5)]), Pal.CRYSTAL4)
			b.draw_rect(Rect2(ic + Vector2(3, 3), Vector2(1, 3)), Pal.CRYSTAL5)
		elif state == "locked":
			b.draw_texture(LOCK, ic, Pal.INK8)
			# dimmed: the tile sits back until the shape it grows from is learned
			b.draw_rect(Rect2(Vector2(1, 1), TILE - Vector2(2, 2)), Color(Pal.INK1, 0.35))
		if id == _sel_shape:
			b.draw_rect(Rect2(Vector2.ZERO, TILE), Pal.AMBER6, false, 1.0))
	return b


## "learned", "learnable" (it grows from a known shape) or "locked".
static func shape_state(id: String) -> String:
	if GameState.is_shape_unlocked(id):
		return "learned"
	return "learnable" if GameState.shape_available(id) else "locked"


## The tile's second line: "Learned", the price, or the shape it grows from.
static func status_text(id: String) -> String:
	match shape_state(id):
		"learned":
			return "Learned"
		"learnable":
			var cost := GameState.shape_cost(id)
			return "%d Shard%s" % [cost, "" if cost == 1 else "s"]
	var parents := GameState.shape_parents(id)
	if parents.is_empty():
		return ""
	return String(FormationWords.shape_by_id(parents[0]).get("name", parents[0]))


## Top-left of a shape's board inside its tile: centred vertically, in a fixed icon column.
static func shape_icon_pos(_s: Dictionary) -> Vector2:
	var gh := BOARD_ROWS * TILE_ICON_PX + BOARD_ROWS - 1
	return Vector2(5, floorf((TILE.y - gh) / 2.0))


## The rect the shape's board covers inside its tile (frame included), for tests.
static func shape_icon_rect(s: Dictionary) -> Rect2:
	var p := shape_icon_pos(s)
	return Rect2(p - Vector2.ONE, Vector2(2 * TILE_ICON_PX + 3, BOARD_ROWS * TILE_ICON_PX + BOARD_ROWS + 1))


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
		var t := _shape_tiles[id] as Control
		var st := t.get_node("Status") as Label
		st.text = status_text(id)
		var state := shape_state(id)
		st.add_theme_color_override("font_color", UIText.legible(Pal.AMBER6 if state == "learned" else (Pal.CRYSTAL5 if state == "learnable" else Pal.INK8)))
		(t.get_node("Name") as Label).add_theme_color_override("font_color", UIText.legible(Pal.INK8) if state == "locked" else UIText.legible(Pal.INK10))
		t.queue_redraw()
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
