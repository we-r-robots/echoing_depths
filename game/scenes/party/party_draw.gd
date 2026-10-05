class_name PartyDraw
extends RefCounted
## Shared pixel drawing helpers for the party / hero detail screen.
## Every colour comes from Pal (master palette). All coordinates are whole pixels.

const SANS := UIText.SANS
const BOLD := UIText.BOLD
const SERIF := UIText.SERIF
const SANS_SIZE := UIText.BODY
const SERIF_SIZE := UIText.TITLE

## Icons used by path at draw time. Textures must be loaded before _draw (a texture first
## loaded inside _draw renders as a blank quad), so every icon looked up by path lives here.
const ICON_CACHE := {
	"res://ui/icons/arrow_up.png": preload("res://ui/icons/arrow_up.png"),
	"res://ui/icons/arrow_down.png": preload("res://ui/icons/arrow_down.png"),
	"res://ui/icons/arrow_left.png": preload("res://ui/icons/arrow_left.png"),
	"res://ui/icons/arrow_right.png": preload("res://ui/icons/arrow_right.png"),
	"res://ui/icons/arrow_upleft.png": preload("res://ui/icons/arrow_upleft.png"),
	"res://ui/icons/arrow_upright.png": preload("res://ui/icons/arrow_upright.png"),
	"res://ui/icons/arrow_downleft.png": preload("res://ui/icons/arrow_downleft.png"),
	"res://ui/icons/arrow_downright.png": preload("res://ui/icons/arrow_downright.png"),
	"res://ui/icons/arrow2_up.png": preload("res://ui/icons/arrow2_up.png"),
	"res://ui/icons/arrow2_down.png": preload("res://ui/icons/arrow2_down.png"),
	"res://ui/icons/arrow2_left.png": preload("res://ui/icons/arrow2_left.png"),
	"res://ui/icons/arrow2_right.png": preload("res://ui/icons/arrow2_right.png"),
	"res://ui/icons/class_fighter.png": preload("res://ui/icons/class_fighter.png"),
	"res://ui/icons/class_rogue.png": preload("res://ui/icons/class_rogue.png"),
	"res://ui/icons/class_healer.png": preload("res://ui/icons/class_healer.png"),
	"res://ui/icons/class_mage.png": preload("res://ui/icons/class_mage.png"),
}


static func icon(path: String) -> Texture2D:
	if ICON_CACHE.has(path):
		return ICON_CACHE[path]
	return load(path)


## Region palette: [fill, highlight, shadow] per region code.
const REGION_COLORS := {
	"LG": [Pal.AMBER1, Pal.AMBER2, Pal.INK1],
	"CG": [Pal.VIOLET1, Pal.VIOLET2, Pal.INK1],
	"LE": [Pal.CRYSTAL1, Pal.CRYSTAL2, Pal.INK1],
	"CE": [Pal.BLOOD1, Pal.BLOOD2, Pal.INK1],
	"N": [Pal.INK4, Pal.INK5, Pal.INK2],
	"LG*": [Pal.AMBER2, Pal.AMBER3, Pal.AMBER1],
	"CG*": [Pal.VIOLET2, Pal.VIOLET3, Pal.VIOLET1],
	"LE*": [Pal.CRYSTAL2, Pal.CRYSTAL3, Pal.CRYSTAL1],
	"CE*": [Pal.BLOOD2, Pal.BLOOD3, Pal.BLOOD1],
}
## Bright accent per region (legend swatch edge, labels).
const REGION_ACCENT := {
	"LG": Pal.AMBER5, "CG": Pal.VIOLET3, "LE": Pal.CRYSTAL4, "CE": Pal.BLOOD4, "N": Pal.INK8,
	"LG*": Pal.AMBER6, "CG*": Pal.VIOLET4, "LE*": Pal.CRYSTAL5, "CE*": Pal.BLOOD4,
}


static func text(ci: CanvasItem, pos: Vector2, s: String, color: Color, font: Font = SANS,
		size := SANS_SIZE, shadow := true, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	UIText.draw(ci, pos, s, color, font, size, shadow, width, align)


static func text_w(s: String, font: Font = SANS, size := SANS_SIZE) -> int:
	return ceili(UIText.width(s, font, size))


## Small-caps style section header: muted caps, a rule running to `w`, a tiny diamond end.
static func header(ci: CanvasItem, pos: Vector2, w: int, s: String, color := Pal.INK8) -> void:
	text(ci, pos, s.to_upper(), color, BOLD, SANS_SIZE, false)
	var tw := text_w(s.to_upper(), BOLD) + 4
	var y := pos.y + 4
	ci.draw_rect(Rect2(pos.x + tw, y, w - tw - 3, 1), Pal.INK4)
	ci.draw_rect(Rect2(pos.x + w - 2, y - 1, 1, 3), Pal.INK5)
	ci.draw_rect(Rect2(pos.x + w - 3, y, 3, 1), Pal.INK5)


static func outline(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c)
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), c)
	ci.draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(1, r.size.y - 2)), c)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 1), Vector2(1, r.size.y - 2)), c)


## Outline with clipped (1px) corners: reads as a soft pixel frame.
static func soft_outline(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(1, 0), Vector2(r.size.x - 2, 1)), c)
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 1), Vector2(r.size.x - 2, 1)), c)
	ci.draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(1, r.size.y - 2)), c)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 1), Vector2(1, r.size.y - 2)), c)


static func dashed_outline(ci: CanvasItem, r: Rect2, c: Color, phase := 0) -> void:
	var x0 := int(r.position.x)
	var y0 := int(r.position.y)
	var x1 := int(r.end.x) - 1
	var y1 := int(r.end.y) - 1
	for x in range(x0, x1 + 1):
		if (x + phase) % 4 < 2:
			ci.draw_rect(Rect2(x, y0, 1, 1), c)
			ci.draw_rect(Rect2(x1 - (x - x0), y1, 1, 1), c)
	for y in range(y0, y1 + 1):
		if (y + phase) % 4 < 2:
			ci.draw_rect(Rect2(x1, y, 1, 1), c)
			ci.draw_rect(Rect2(x0, y1 - (y - y0), 1, 1), c)


## Recessed value box (the dark wells Sea of Stars-style lists put numbers in).
static func inset(ci: CanvasItem, r: Rect2, fill := Pal.INK1) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Pal.INK4)
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), Pal.INK1)


## Main panel: theme panel stylebox plus a lighter header band of height `band` (0 = none).
static func panel(ci: CanvasItem, r: Rect2, band := 0, kind := &"PanelContainer") -> void:
	var sb: StyleBox = ThemeDB.get_project_theme().get_stylebox(&"panel", kind)
	ci.draw_style_box(sb, r)
	if band > 0:
		var b := Rect2(r.position.x + 3, r.position.y + 3, r.size.x - 6, band)
		ci.draw_rect(b, Pal.INK3)
		ci.draw_rect(Rect2(b.position.x, b.end.y, b.size.x, 1), Pal.INK4)
		ci.draw_rect(Rect2(b.position.x, b.end.y + 1, b.size.x, 1), Pal.INK1)
		# corner knots, re-drawn over the band so the frame ornaments stay visible
		for p in [Vector2(r.position.x + 3, r.position.y + 3), Vector2(r.end.x - 5, r.position.y + 3)]:
			ci.draw_rect(Rect2(p, Vector2(2, 2)), Pal.INK5)


## Highlighted row: stepped crystal gradient, bright rim, lit top edge (the selected-row look).
static func selected(ci: CanvasItem, r: Rect2, accent := Pal.CRYSTAL4) -> void:
	var w := r.size.x - 2
	var bands := [Pal.CRYSTAL2, Pal.CRYSTAL1, Pal.INK3]
	var fracs := [0.0, 0.42, 0.78, 1.0]
	for i in 3:
		var x0 := roundi(w * fracs[i])
		var x1 := roundi(w * fracs[i + 1])
		ci.draw_rect(Rect2(r.position.x + 1 + x0, r.position.y + 1, x1 - x0, r.size.y - 2), bands[i])
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 1, roundi(w * 0.42), 1), Pal.CRYSTAL3)
	soft_outline(ci, r, accent)


## Plain list row: dark plate with a 1px lower rule.
static func row(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Pal.INK2)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Pal.INK3)


static func tint_tex(ci: CanvasItem, tex: Texture2D, pos: Vector2, c: Color, shadow := true) -> void:
	if shadow:
		ci.draw_texture(tex, pos.round() + Vector2(1, 1), Pal.INK1)
	ci.draw_texture(tex, pos.round(), c)


## Pill tag, e.g. "BASE" / "BOUND" / "NEW".
static func pill(ci: CanvasItem, pos: Vector2, s: String, fg: Color, bg: Color, edge: Color) -> int:
	var w := text_w(s, BOLD) + 6
	var r := Rect2(pos, Vector2(w, 11))
	ci.draw_rect(r.grow_individual(0, 0, 0, 0), bg)
	soft_outline(ci, r, edge)
	text(ci, Vector2(pos.x + 3, UIText.centered_y(pos.y, r.size.y, BOLD)), s, fg, BOLD, SANS_SIZE, false)
	return w
