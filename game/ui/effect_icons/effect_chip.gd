class_name EffectChip
extends Control
## One interactive effect: the 20x20 icon chip (EffectIcons.draw_effect), optionally followed by its
## short label in the bold body face, opening the shared Tip with the full sentence on
## hover (PC), tap or press-and-hold (touch). The whole chip + label is the hit target.
##   var chip := EffectChip.new(); parent.add_child(chip)
##   chip.setup(effect)                          # icon only (20x20), tooltip above
##   chip.setup(effect, "left", 170)             # icon + label 170 px wide, tooltip to the left
##   chip.locked = true                          # grey outline + lock: the effect isn't active yet

const LOCK := preload("res://ui/effect_icons/lock.png")
const BOLD := preload("res://assets/fonts/depths_sans_bold.fnt")

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
		# one body size (bold), neutral text: colour lives in the icon and its arrow
		var c := Pal.INK10 if not locked else Pal.FADE4
		var t := String(effect.get("title", ""))
		var base := Vector2(EffectIcons.CHIP + 6, 5 + BOLD.get_ascent(11)).round()
		draw_string(BOLD, base + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.INK1)
		draw_string(BOLD, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)
		if locked and effect.get("icon") != LOCK:
			var x := EffectIcons.CHIP + 10 + BOLD.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_texture(LOCK, Vector2(x, 7) + Vector2(1, 1), Pal.INK1)
			draw_texture(LOCK, Vector2(x, 7), Pal.FADE3)
