class_name EffectChip
extends Control
## One interactive effect: the 20x20 icon chip (EffectIcons.draw_effect), optionally followed by its
## short label, opening the shared Tip with the effect's full sentence on hover (PC), tap or
## press-and-hold (touch). The whole chip + label is the hit target.
##   var chip := EffectChip.new(); parent.add_child(chip)
##   chip.setup(effect)                       # icon only (20x20)
##   chip.setup(effect, true, 180)            # tooltip below; icon + label, 180 px wide

const BOLD := preload("res://assets/fonts/depths_sans_bold.fnt")

var effect: Dictionary = {}
var label_w := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resize()


func setup(e: Dictionary, tip_below := false, with_label_w := 0) -> void:
	effect = e
	label_w = with_label_w
	_resize()
	Tip.attach(self, String(e.get("title", "")), String(e.get("text", "")), EffectIcons.color_of(e), tip_below)
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
		draw_rect(Rect2(EffectIcons.CHIP - 1, 2, label_w, EffectIcons.CHIP - 4), Pal.INK3)
	EffectIcons.draw_effect(self, Vector2.ZERO, effect, lit)
	if label_w > 0:
		var c := EffectIcons.color_of(effect)
		var base := Vector2(EffectIcons.CHIP + 6, 5 + BOLD.get_ascent(11)).round()
		var t := String(effect.get("title", ""))
		draw_string(BOLD, base + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.INK1)
		draw_string(BOLD, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c if int(effect.get("sign", 0)) != 0 or String(effect.get("kind", "")) == "behaviour" else Pal.INK10)
