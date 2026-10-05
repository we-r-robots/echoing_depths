class_name AlignGrid
extends Control
## Pixel-drawn 5x5 alignment grid. Rows: Mercy (top) -> Cruelty (bottom); columns: Order (left) -> Freedom (right).
## Shows a hero's position, an optional target cell and animates the move with `progress` (0..1).
## The neutral cross is drawn lighter than the four quadrants so the advanced-class regions read at a glance.

@export var cell := 3:
	set(v): cell = v; _resize()
@export var gap := 1:
	set(v): gap = v; _resize()
var from_pos := Vector2i.ZERO:
	set(v): from_pos = v; queue_redraw()
var to_pos := Vector2i.ZERO:
	set(v): to_pos = v; queue_redraw()
var progress := 0.0:
	set(v): progress = v; queue_redraw()
var show_target := false:
	set(v): show_target = v; queue_redraw()
var dot_color := Pal.AMBER6:
	set(v): dot_color = v; queue_redraw()
var target_color := Pal.INK10
var blink := true
var flash := 0.0:
	set(v): flash = v; queue_redraw()

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func _resize() -> void:
	var s := total_size()
	custom_minimum_size = Vector2(s, s)
	size = custom_minimum_size
	queue_redraw()


func total_size() -> int:
	return 5 * cell + 4 * gap + 4


func _process(delta: float) -> void:
	if show_target and blink:
		_t += delta
		queue_redraw()


## Cell origin (top-left, local px) for an alignment position (good, law).
func cell_origin(p: Vector2i) -> Vector2:
	var col := 2 - p.y
	var row := 2 - p.x
	return Vector2(2 + col * (cell + gap), 2 + row * (cell + gap))


func _draw() -> void:
	var s := total_size()
	var rules := EncounterDB.rules()
	var axes: Dictionary = rules["axes"]
	draw_rect(Rect2(0, 0, s, s), Pal.INK1)
	# axis bars: the colour of each pole on its side
	draw_rect(Rect2(2, 0, s - 4, 1), Pal.c(axes["good"]["pos_color"]))
	draw_rect(Rect2(2, s - 1, s - 4, 1), Pal.c(axes["good"]["neg_color"]))
	draw_rect(Rect2(0, 2, 1, s - 4), Pal.c(axes["law"]["pos_color"]))
	draw_rect(Rect2(s - 1, 2, 1, s - 4), Pal.c(axes["law"]["neg_color"]))
	for g in range(-2, 3):
		for l in range(-2, 3):
			var o := cell_origin(Vector2i(g, l))
			var cross := g == 0 or l == 0
			var c := Pal.INK4 if cross else Pal.INK3
			if cell >= 6 and absi(g) == 2 and absi(l) == 2:
				c = Pal.INK5  # corner classes
			draw_rect(Rect2(o, Vector2(cell, cell)), c)
	var moving := to_pos != from_pos
	if moving and progress > 0.0:
		# where the hero stood: a hollow mark in their colour
		_outline(Rect2(cell_origin(from_pos), Vector2(cell, cell)), dot_color)
	if show_target and moving:
		# where the choice leads: a white ring around the target cell (blinks), never a fill
		var on := fmod(_t, 0.8) < 0.55 or not blink
		var to := cell_origin(to_pos)
		_outline(Rect2(to - Vector2(1, 1), Vector2(cell + 2, cell + 2)), target_color if on else Pal.INK7)
	var a := cell_origin(from_pos)
	var b := cell_origin(to_pos)
	var e := progress * progress * (3.0 - 2.0 * progress)
	var p := a.lerp(b, e).round()
	if cell >= 6 and moving and progress > 0.0:
		# trail of light behind the moving mark
		var steps := int(maxf(absf(p.x - a.x), absf(p.y - a.y)))
		for i in steps:
			var q := a.lerp(p, float(i) / maxf(steps, 1)).round()
			draw_rect(Rect2(q + Vector2(cell / 2.0 - 1, cell / 2.0 - 1).floor(), Vector2(2, 2)), Pal.INK7)
	if cell >= 6:
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(cell + 2, cell + 2)), Pal.INK1)
		draw_rect(Rect2(p, Vector2(cell, cell)), dot_color)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(2, 1)), Pal.INK10)
	else:
		draw_rect(Rect2(p, Vector2(cell, cell)), dot_color)
	if flash > 0.0:
		var f := Pal.INK10
		f.a = flash
		_outline(Rect2(p - Vector2(2, 2), Vector2(cell + 4, cell + 4)), f)


func _outline(r: Rect2, c: Color) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), c)
	draw_rect(Rect2(r.position, Vector2(1, r.size.y)), c)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), c)
