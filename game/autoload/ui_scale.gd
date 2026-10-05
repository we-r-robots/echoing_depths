extends Node
## Keeps the UI fonts crisp at the window's integer scale (docs/BUILD.md "Rendering").
## The window stretches canvas items by a whole number s (1920x1080 -> 3). A font pixel at size 10
## is 2s/3 screen px: whole at s = 3 and 6, where the fonts render unhinted with positions on
## whole pixels (subpixel AUTO picks whole pixels at these sizes). At s = 2 and 4 a font pixel is
## 1.33 / 2.67 px, so the autohinter snaps stems to whole pixels instead (even 1 px strokes at
## 1280x720) and glyph positions round to whole pixels.

var scale := 0


func _ready() -> void:
	var serif: FontFile = UIText.SERIF
	serif.fallbacks = [UIText.SANS]
	get_tree().root.size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var s := int(round(get_tree().root.get_final_transform().x.x))
	if s == scale:
		return
	scale = s
	var crisp := s % 3 == 0
	for f: FontFile in [UIText.SANS, UIText.BOLD, UIText.SERIF]:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE if crisp else TextServer.HINTING_NORMAL
		f.force_autohinter = not crisp
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO if crisp else TextServer.SUBPIXEL_POSITIONING_DISABLED
