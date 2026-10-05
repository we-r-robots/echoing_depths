class_name AlignPanel
extends Control
## Left panel: the big alignment grid with its four axis ends at the matching edges
## (Mercy top, Cruelty bottom, Order left, Freedom right).

signal cell_tapped(pos: Array)

const W := 346
const H := 312
## Side margins hold Order (left) and Freedom (right) at mid-height, like compass sides (critic r5:
## on the bottom baseline with Cruelty they read as a row of tabs).

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
	# Mercy (top) / Cruelty (bottom): centred, arrow + word
	for pair in [[1, gy - 14, up], [-1, gy + gs + 3, dn]]:
		var word := PartyModel.axis_word("good", pair[0]).to_upper()
		var col := PartyModel.axis_color("good", pair[0])
		var w := PartyDraw.text_w(word, f) + 10
		var x := gx + (gs - w) / 2
		PartyDraw.tint_tex(self, pair[2], Vector2(x, pair[1] + 1), col)
		PartyDraw.text(self, Vector2(x + 10, pair[1]), word, col, f)
	# Order (left) / Freedom (right): beside the grid's left and right edges at mid-height, the
	# arrow over the word pointing out to its side
	var lf: Texture2D = preload("res://ui/icons/arrow_left.png")
	var rt: Texture2D = preload("res://ui/icons/arrow_right.png")
	var cy := gy + gs / 2.0
	for pair in [[1, lf, gx / 2.0], [-1, rt, gx + gs + (W - gx - gs) / 2.0]]:
		var word := PartyModel.axis_word("law", pair[0]).to_upper()
		var col := PartyModel.axis_color("law", pair[0])
		var cx: float = pair[2]
		PartyDraw.tint_tex(self, pair[1], Vector2(roundf(cx - 4.0), roundf(cy - 13.0)), col)
		PartyDraw.text(self, Vector2(roundf(cx - PartyDraw.text_w(word, f) / 2.0), roundf(cy - 1.0)), word, col, f)
