class_name IdentityPanel
extends VillagePanel
## First visit to Lanternrest (docs/BUILD.md "Team identity"): the player picks a team name and a
## crest from a handful of generic choices. Full customisation and Titles come later through
## Lanternrest; for now the Lantern's menu can still rename the team.
## The lists are placeholders.

signal chosen(team: String, crest: String)

const NAMES := ["The Lanternrest Company", "The Ember Watch", "The Last Light", "The Wayfarers",
	"The Quiet Vow", "The Long Road"]
const NAME_TILE := Vector2(146, 24)
const CREST_TILE := Vector2(32, 38)
const W := 296

var team := NAMES[0]
var crest := Crests.DEFAULT_CREST
var _name_btns := {}
var _crest_btns := {}


func _init() -> void:
	place_id = "identity"
	title = "Who carries the lantern?"
	width = W
	closable = false


func _build() -> void:
	body.add_child(FlowUI.para("Name your company and choose its crest. Rivals see both before every Echo fight.", W, Pal.INK9))
	body.add_child(FlowUI.label("NAME", &"TagLabel"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n: String in NAMES:
		var b := FlowUI.button(n, NAME_TILE.x, NAME_TILE.y)
		b.name = "Name%d" % _name_btns.size()
		b.theme_type_variation = &"ChoiceButton"
		b.pressed.connect(pick_name.bind(n))
		b.draw.connect(func() -> void:
			if n == team:
				b.draw_rect(Rect2(Vector2.ZERO, b.size), Pal.AMBER6, false, 1.0))
		grid.add_child(b)
		_name_btns[n] = b
	body.add_child(grid)
	body.add_child(FlowUI.label("CREST", &"TagLabel"))
	var row := FlowUI.hbox(4)
	for id: String in Crests.DEFAULT_UNLOCKED:
		var b := FlowUI.button("", CREST_TILE.x, CREST_TILE.y)
		b.name = "Crest_" + id
		b.theme_type_variation = &"ChoiceButton"
		b.pressed.connect(pick_crest.bind(id))
		b.draw.connect(func() -> void:
			Crests.draw(b, Vector2(3, 4), id, 2)
			if id == crest:
				b.draw_rect(Rect2(Vector2.ZERO, CREST_TILE), Pal.AMBER6, false, 1.0))
		row.add_child(b)
		_crest_btns[id] = b
	var note := FlowUI.para("More crests, and Titles for your name, are remembered in Lanternrest later.", W - 3 * 36 - 8, Pal.INK9)
	row.add_child(note)
	body.add_child(row)
	var go := FlowUI.primary("Begin", 120)
	go.name = "Begin"
	go.pressed.connect(confirm)
	var foot := FlowUI.hbox(0)
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(go)
	body.add_child(foot)


func pick_name(n: String) -> void:
	team = n
	for b: Button in _name_btns.values():
		b.queue_redraw()


func pick_crest(id: String) -> void:
	crest = id
	for b: Button in _crest_btns.values():
		b.queue_redraw()


func confirm() -> void:
	GameState.set_identity(team, crest)
	changed.emit()
	chosen.emit(team, crest)
