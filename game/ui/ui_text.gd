class_name UIText
extends RefCounted
## The UI text layer: fonts, named sizes and drawing helpers shared by every screen.
##
## Rendering (docs/BUILD.md "Rendering: world and UI layers"): the UI is laid out in a 640x360
## design space, but the window stretches canvas items (not a 640x360 image), so fonts rasterise
## at the screen's native resolution. Fonts are drawn on a 15-units-per-em pixel grid, so a font
## size that is a multiple of 5 puts every font pixel on whole screen pixels at 1080p (x3) and
## 4K (x6): size 10 = 2 screen px per font pixel at 1080p, 15 = 3 px, 20 = 4 px.
##
## Named sizes (mirrored in ui/theme.tres, type "Sizes"; tests/test_ui_text.gd keeps them equal):
##   LABEL / BODY  10  Depths Sans (bold for labels), x-height 16 px at 1080p
##   TITLE         10  Depths Serif, cap 28 px at 1080p
##   NUMBER        15  Depths Sans Bold, cap 33 px at 1080p (numbers that must punch)
##   HEADING       15  big serif titles and banner names
##   DISPLAY       25  the largest moments (VICTORY / DEFEAT, damage numbers)
## Floor: no player-facing text below MIN_X_HEIGHT_1080 px x-height at 1080p. Every draw goes
## through this file, which refuses sizes that are not on the grid or below the floor.

const SANS: FontFile = preload("res://assets/fonts/depths_sans.ttf")
const BOLD: FontFile = preload("res://assets/fonts/depths_sans_bold.ttf")
const SERIF: FontFile = preload("res://assets/fonts/depths_serif.ttf")

const LABEL := 10
const BODY := 10
const TITLE := 10
const NUMBER := 15
const HEADING := 15
const DISPLAY := 25

## Font grid: units per em, and each face's x-height in units (see assets/fonts/src/make_fonts.py).
const EM_UNITS := 15
const X_HEIGHT_UNITS := {"sans": 8, "bold": 8, "serif": 9}
const CAP_UNITS := {"sans": 11, "bold": 11, "serif": 14}
## The legibility floor: x-height in screen pixels on a 1920x1080 screen (docs/BUILD.md).
const MIN_X_HEIGHT_1080 := 14
const SCALE_1080 := 3

const OUTLINE_DIRS: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
	Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]

static var _bad_sizes := {}


## One font pixel at `size`, in design px (2/3 at size 10). Shadows and outlines are one font pixel.
static func fpx(size: int) -> float:
	return float(size) / EM_UNITS


static func face_of(f: Font) -> String:
	if f == SERIF:
		return "serif"
	if f == BOLD:
		return "bold"
	return "sans"


## x-height of `font` at `size`, in screen px at 1080p.
static func x_height_1080(f: Font, size: int) -> float:
	return float(X_HEIGHT_UNITS[face_of(f)]) * fpx(size) * SCALE_1080


## A size is allowed when it lands on whole screen pixels at 1080p and keeps x-height >= the floor.
static func size_ok(f: Font, size: int) -> bool:
	return size % 5 == 0 and x_height_1080(f, size) >= MIN_X_HEIGHT_1080


static func _check(f: Font, size: int) -> void:
	if size_ok(f, size):
		return
	var k := "%s:%d" % [face_of(f), size]
	if not _bad_sizes.has(k):
		_bad_sizes[k] = true
		push_error("UIText: font size %d (%s) is off the pixel grid or below the %d px x-height floor" % [size, face_of(f), MIN_X_HEIGHT_1080])


static func ascent(f: Font = SANS, size := BODY) -> float:
	return float(f.get_ascent(size))


## Cap height in design px (for vertical centring on a plate).
static func cap(f: Font = SANS, size := BODY) -> float:
	return float(CAP_UNITS[face_of(f)]) * fpx(size)


## Top-left y that centres the caps of one line in the band [y, y + h].
static func centered_y(y: float, h: float, f: Font = SANS, size := BODY) -> float:
	var c := cap(f, size)
	return y + (h - c) / 2.0 - (ascent(f, size) - c)


## Line pitch for running text, in design px.
static func line_h(f: Font = SANS, size := BODY) -> float:
	match face_of(f):
		"serif": return 19.0 * fpx(size)
		_: return 16.0 * fpx(size)


static func width(s: String, f: Font = SANS, size := BODY) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Text with its top-left at `pos` (the ascent line), with a one-font-pixel drop shadow.
## width/align as draw_string (align within `w` when w > 0).
## Contrast floor for text (critic round 1: the muted tier at 2.5-3.9:1 faded out at phone size).
## The palette's mid-dark tones are below 4.5:1 on the panel inks, so as a text colour each one
## is lifted to its nearest readable sibling (alpha kept): INK6/INK7 -> INK8 (6.4:1 on INK2,
## 5.7:1 on INK3), FADE2 -> FADE3, AMBER3 -> AMBER4, CRYSTAL3 -> CRYSTAL4, LIFE3 -> LIFE4,
## BLOOD3 -> BLOOD4, VIOLET2 -> VIOLET3, SKIN2 -> SKIN3. Darker tones (INK1-5 ...) are left
## alone: they are only used as dark text on light fills (pills, tags).
const READABLE := {
	"INK6": "INK8", "INK7": "INK8", "FADE2": "FADE3", "AMBER3": "AMBER4", "CRYSTAL3": "CRYSTAL4",
	"LIFE3": "LIFE4", "BLOOD3": "BLOOD4", "VIOLET2": "VIOLET3", "SKIN2": "SKIN3",
}
static var _readable: Dictionary = {}


static func legible(c: Color) -> Color:
	if _readable.is_empty():
		for k: String in READABLE:
			_readable[Pal.c(k.to_lower()).to_html(false)] = Pal.c(String(READABLE[k]).to_lower())
	var key := c.to_html(false)
	if _readable.has(key):
		var r: Color = _readable[key]
		return Color(r, c.a)
	return c


static func draw(ci: CanvasItem, pos: Vector2, s: String, color: Color, f: Font = SANS, size := BODY,
		shadow := true, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_check(f, size)
	color = legible(color)
	var base := Vector2(pos.x, pos.y + ascent(f, size))
	if shadow:
		var d := fpx(size)
		ci.draw_string(f, base + Vector2(d, d), s, align, w, size, Color(Pal.INK1, color.a))
	ci.draw_string(f, base, s, align, w, size, color)


## Same, with `pos` on the baseline.
static func draw_base(ci: CanvasItem, base: Vector2, s: String, color: Color, f: Font = SANS, size := BODY,
		shadow := true, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw(ci, Vector2(base.x, base.y - ascent(f, size)), s, color, f, size, shadow, w, align)


## Text ringed by a one-font-pixel outline (for text over the world: numbers, tags, banners).
## `anchor` 0 left, 1 centre, 2 right of pos.x; pos.y is the top (ascent line).
static func outlined(ci: CanvasItem, pos: Vector2, s: String, color: Color, f: Font = BOLD, size := BODY,
		anchor := 0, outline := Pal.INK1, drop := true, ring := 1) -> float:
	_check(f, size)
	color = legible(color)
	var w := width(s, f, size)
	var x := pos.x - (w * 0.5 if anchor == 1 else (w if anchor == 2 else 0.0))
	var base := Vector2(x, pos.y + ascent(f, size))
	var d := fpx(size)
	var oc := Color(outline, outline.a * color.a)
	if drop:
		for k in [Vector2(d * 2, d * 2), Vector2(d, d * 2), Vector2(d * 2, d)]:
			ci.draw_string(f, base + k, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, oc)
	for r in range(ring, 0, -1):
		for dir: Vector2 in OUTLINE_DIRS:
			ci.draw_string(f, base + dir * d * r, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, oc)
	ci.draw_string(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return x + w


## Typographer's quotes for display (critic r5: "A memory." in straight quotes): pairs of " become
## “ ”, an apostrophe or a closing ' becomes ’, an opening ' becomes ‘. Data stays as written.
static func curly(s: String) -> String:
	var out := ""
	var open := true
	for i in s.length():
		var ch := s[i]
		if ch == "\"":
			out += "“" if open else "”"
			open = not open
		elif ch == "'":
			var prev := s[i - 1] if i > 0 else " "
			out += "‘" if prev in [" ", "\n", "(", "[", "“", "—"] else "’"
		else:
			out += ch
	return out


## Word wrap to `w` design px.
## Words wrapped to `w`. No lone last word: when a paragraph's last line would be one word, the
## line above gives it a word if that still fits (critic r4: a stranded "grid.").
static func wrap_lines(s: String, w: float, f: Font = SANS, size := BODY) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		var lines := PackedStringArray()
		var line := ""
		for wd in para.split(" "):
			var trial := wd if line == "" else line + " " + wd
			if width(trial, f, size) > w and line != "":
				lines.append(line)
				line = wd
			else:
				line = trial
		lines.append(line)
		var n := lines.size()
		if n >= 2 and not lines[n - 1].contains(" ") and lines[n - 2].count(" ") >= 2:
			var cut := lines[n - 2].rfind(" ")
			var moved := lines[n - 2].substr(cut + 1) + " " + lines[n - 1]
			if width(moved, f, size) <= w:
				lines[n - 2] = lines[n - 2].substr(0, cut)
				lines[n - 1] = moved
		out.append_array(lines)
	return out


## Cut to fit `w` with an ellipsis.
static func fit(s: String, w: float, f: Font = SANS, size := BODY) -> String:
	if width(s, f, size) <= w:
		return s
	while s.length() > 1 and width(s + "…", f, size) > w:
		s = s.substr(0, s.length() - 1)
	return s.strip_edges() + "…"


## Paragraph at pos (top-left), wrapped to w; returns the y after the last line.
static func para(ci: CanvasItem, pos: Vector2, s: String, w: float, color: Color, f: Font = SANS, size := BODY,
		shadow := true, pitch := -1.0) -> float:
	var lh := pitch if pitch > 0.0 else line_h(f, size)
	var y := pos.y
	for l in wrap_lines(s, w, f, size):
		draw(ci, Vector2(pos.x, y), l, color, f, size, shadow)
		y += lh
	return y


## The UI's usable rect in design px: the whole view (wider than 640 on wide screens), inset on
## phones by the display's safe area (notch, rounded corners). Edge-anchored UI keeps inside it.
static func safe_rect(ci: CanvasItem) -> Rect2:
	var vr := ci.get_viewport_rect()
	if not OS.has_feature("mobile"):
		return vr
	var sa := Rect2(DisplayServer.get_display_safe_area())
	var ws := Vector2(DisplayServer.window_get_size())
	if ws.x <= 0.0 or sa.size.x <= 0.0:
		return vr
	var k := vr.size.x / ws.x
	var l := maxf(0.0, sa.position.x) * k
	var r := maxf(0.0, ws.x - sa.end.x) * k
	return Rect2(vr.position.x + l, vr.position.y, vr.size.x - l - r, vr.size.y)


## The 640x360 design frame centred in the view (the 16:9 safe area of wide screens).
static func frame_rect(ci: CanvasItem) -> Rect2:
	var vr := ci.get_viewport_rect()
	return Rect2(((vr.size - Vector2(640, 360)) / 2.0).floor(), Vector2(640, 360))


## A 1-font-pixel-thick horizontal rule (thin UI line matched to the text's pixel grid).
static func hline(ci: CanvasItem, x: float, y: float, w: float, color: Color, size := BODY) -> void:
	ci.draw_rect(Rect2(x, y, w, fpx(size)), color)


static func vline(ci: CanvasItem, x: float, y: float, h: float, color: Color, size := BODY) -> void:
	ci.draw_rect(Rect2(x, y, fpx(size), h), color)
