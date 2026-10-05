class_name BigText
extends RefCounted
## The large reading face (names on cards): Depths Serif at the title size. The serif now has its
## own "+" and "%" glyphs, so this is a thin wrapper over UIText kept for its callers.

const FONT := UIText.SERIF
const SIZE := UIText.TITLE


static func width(s: String) -> int:
	return ceili(UIText.width(s, FONT, SIZE))


static func draw(ci: CanvasItem, pos: Vector2, s: String, color: Color, shadow := true) -> void:
	UIText.draw(ci, pos, s, color, FONT, SIZE, shadow)

