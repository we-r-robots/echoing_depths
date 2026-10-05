class_name AlignPanel
extends Control
## Left panel: the big alignment grid with its four axis ends at the matching edges
## (Mercy top, Cruelty bottom, Order left, Freedom right).

signal cell_tapped(pos: Array)

const W := 300
const H := 294

var grid: HeroAlignGrid
var hero: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	grid = HeroAlignGrid.new()
	grid.position = Vector2((W - HeroAlignGrid.total()) / 2, 19)
	add_child(grid)
	grid.cell_tapped.connect(func(p: Array) -> void: cell_tapped.emit(p))


func set_hero(h: Dictionary, portrait: Texture2D, color: Color, names: Dictionary) -> void:
	hero = h
	grid.set_hero(h, portrait, color, names)
	queue_redraw()


func _draw() -> void:
	PartyDraw.panel(self, Rect2(0, 0, W, H))
	var gs := HeroAlignGrid.total()
	var gx := grid.position.x
	var gy := grid.position.y
	var f := PartyDraw.BOLD
	var up: Texture2D = preload("res://ui/icons/arrow_up.png")
	var dn: Texture2D = preload("res://ui/icons/arrow_down.png")
	var lf: Texture2D = preload("res://ui/icons/arrow_left.png")
	var rt: Texture2D = preload("res://ui/icons/arrow_right.png")
	# Mercy (top) / Cruelty (bottom): centred, arrow + word
	for pair in [[1, gy - 14, up], [-1, gy + gs + 3, dn]]:
		var word := PartyModel.axis_word("good", pair[0]).to_upper()
		var col := PartyModel.axis_color("good", pair[0])
		var w := PartyDraw.text_w(word, f) + 10
		var x := gx + (gs - w) / 2
		PartyDraw.tint_tex(self, pair[2], Vector2(x, pair[1] + 1), col)
		PartyDraw.text(self, Vector2(x + 10, pair[1]), word, col, f)
	# Order (left) / Freedom (right): stacked letters beside the grid, arrow on top
	for pair in [[1, gx - 13, lf], [-1, gx + gs + 4, rt]]:
		var word := PartyModel.axis_word("law", pair[0]).to_upper()
		var col := PartyModel.axis_color("law", pair[0])
		var n := word.length()
		var hgt := 10 + n * 10
		var y := gy + (gs - hgt) / 2
		PartyDraw.tint_tex(self, pair[2], Vector2(pair[1] + 1, y), col)
		for i in n:
			var ch := word.substr(i, 1)
			var cw := PartyDraw.text_w(ch, f)
			PartyDraw.text(self, Vector2(pair[1] + roundi((9 - cw) / 2.0), y + 10 + i * 10), ch, col, f)
