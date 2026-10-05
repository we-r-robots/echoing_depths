class_name BigText
extends RefCounted
## The large reading face for the formation panel: Depths Serif 16, plus the "+" and "%"
## glyphs the font lacks (drawn from ui/effect_icons/serif_*.png in the same stroke weight),
## so numbers like "+30%" read at a glance at 1x.

const FONT := preload("res://assets/fonts/depths_serif.fnt")
const SIZE := 16
const GLYPHS := {
	"+": [preload("res://ui/effect_icons/serif_plus.png"), Vector2(0, 4), 7],
	"%": [preload("res://ui/effect_icons/serif_pct.png"), Vector2(0, 1), 9],
}


static func width(s: String) -> int:
	var w := 0
	for part: String in _split(s):
		if GLYPHS.has(part):
			w += int(GLYPHS[part][2])
		else:
			w += int(FONT.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x)
	return w


static func draw(ci: CanvasItem, pos: Vector2, s: String, color: Color, shadow := true) -> void:
	var x := pos.x
	for part: String in _split(s):
		if GLYPHS.has(part):
			var g: Array = GLYPHS[part]
			var p: Vector2 = Vector2(x, pos.y) + (g[1] as Vector2)
			if shadow:
				ci.draw_texture(g[0], p + Vector2(1, 1), Pal.INK1)
			ci.draw_texture(g[0], p, color)
			x += int(g[2])
		else:
			PartyDraw.text(ci, Vector2(x, pos.y), part, color, FONT, SIZE, shadow)
			x += FONT.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x


## Word wrap by BigText width.
static func wrap(s: String, w: int) -> Array:
	var out: Array = []
	var line := ""
	for wd in s.split(" "):
		var trial := wd if line == "" else line + " " + wd
		if width(trial) > w and line != "":
			out.append(line)
			line = wd
		else:
			line = trial
	if line != "":
		out.append(line)
	return out


static func _split(s: String) -> Array:
	var out: Array = []
	var cur := ""
	for ch in s:
		if GLYPHS.has(ch):
			if cur != "":
				out.append(cur)
				cur = ""
			out.append(ch)
		else:
			cur += ch
	if cur != "":
		out.append(cur)
	return out
