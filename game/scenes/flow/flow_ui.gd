class_name FlowUI
extends RefCounted
## Small builders shared by the flow screens (title, road, splash, results, Lanternrest,
## settings). Everything uses the shared theme (ui/theme.tres) variations and named sizes, so
## these screens match the draft, setup and encounter screens.

const HEART := preload("res://ui/icons/heart.png")


static func label(text: String, variation: StringName = &"", color = null, w := 0.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if color is Color:
		l.add_theme_color_override("font_color", UIText.legible(color))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = align
	if w > 0.0:
		l.custom_minimum_size.x = w
		l.size.x = w
	return l


## A wrapped paragraph in the bold face (secondary text on dark panels stays 2 px at phone size).
static func para(text: String, w: float, color := Pal.INK9, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, &"", color, w, align)
	l.add_theme_font_override("font", UIText.BOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, w := 96.0, h := 22.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	b.size = b.custom_minimum_size
	return b


static func panel(variation: StringName = &"PanelContainer") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != &"PanelContainer":
		p.theme_type_variation = variation
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func vbox(sep := 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func hbox(sep := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func margin(child: Control, m := 8) -> MarginContainer:
	var c := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		c.add_theme_constant_override("margin_" + side, m)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(child)
	return c


## A drawn crest as a Control (so containers can lay it out).
static func crest(id: String, px := 2, dim := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Crests.dims(px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: Crests.draw(c, Vector2.ZERO, id, px, dim))
	return c


## Health as hearts (lit / dark), right-aligned at `right`, top `y`. Returns the left x.
static func draw_health(ci: CanvasItem, right: float, y: float, health: int, max_health: int) -> float:
	var hx := right - max_health * 9 + 2
	for i in max_health:
		var on := i < health
		PartyDraw.tint_tex(ci, HEART, Vector2(hx + i * 9, y), Pal.BLOOD3 if on else Pal.INK4, on)
	return hx


## Words for a fight kind.
static func fight_word(kind: String) -> String:
	match kind:
		"pvp":
			return "Echo"
		"guardian":
			return "Floor guardian"
		"crystal":
			return "The final chamber"
		"monster":
			return "Monsters"
	return "Fight"


## The class's display name (advanced and Legendary classes included).
static func class_name_of(id: String) -> String:
	var GameData = preload("res://core/game_data.gd")
	return String(GameData.get_class_def(id).get("name", id.capitalize()))
