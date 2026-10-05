class_name EffectChip
extends Control
## One interactive effect: the 20x20 icon chip (EffectIcons.draw_effect), optionally followed by its
## short label in the large reading face (BigText), opening the shared Tip with the full sentence on
## hover (PC), tap or press-and-hold (touch). The whole chip + label is the hit target.
##   var chip := EffectChip.new(); parent.add_child(chip)
##   chip.setup(effect)                          # icon only (20x20), tooltip above
##   chip.setup(effect, "left", 170)             # icon + label 170 px wide, tooltip to the left
##   chip.locked = true                          # grey outline + lock: the effect isn't active yet

const LOCK := preload("res://ui/effect_icons/lock.png")

var effect: Dictionary = {}
var label_w := 0
var locked := false:
	set(v): locked = v; queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resize()


func setup(e: Dictionary, place := "auto", with_label_w := 0) -> void:
	effect = e
	label_w = with_label_w
	_resize()
	Tip.attach(self, String(e.get("name", e.get("title", ""))), String(e.get("text", "")), EffectIcons.color_of(e), place)
	queue_redraw()


func _resize() -> void:
	custom_minimum_size = Vector2(EffectIcons.CHIP + label_w, EffectIcons.CHIP)
	size = custom_minimum_size


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if effect.is_empty():
		return
	var lit := Tip.is_open_for(self)
	if label_w > 0 and lit:
		draw_rect(Rect2(EffectIcons.CHIP - 1, 1, label_w, EffectIcons.CHIP - 2), Pal.INK3)
	EffectIcons.draw_effect(self, Vector2.ZERO, effect, lit, locked)
	if label_w > 0:
		var c := EffectIcons.color_of(effect)
		if locked:
			c = Pal.FADE4
		var t := String(effect.get("title", ""))
		var tw := BigText.width(t)
		if tw <= label_w - 8 - (10 if locked else 0):
			BigText.draw(self, Vector2(EffectIcons.CHIP + 6, 2), t, c)
		else:
			# too long for the large face: the bold face, same line
			tw = PartyDraw.text_w(t, PartyDraw.BOLD)
			PartyDraw.text(self, Vector2(EffectIcons.CHIP + 6, 5), t, c, PartyDraw.BOLD)
		if locked:
			var x := EffectIcons.CHIP + 10 + tw
			draw_texture(LOCK, Vector2(x, 6) + Vector2(1, 1), Pal.INK1)
			draw_texture(LOCK, Vector2(x, 6), Pal.FADE3)
