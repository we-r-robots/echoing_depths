extends "res://tests/test_case.gd"
## The UI text floor (docs/BUILD.md "Rendering: world and UI layers"): named sizes live in the theme
## and match UIText; every size is on the font pixel grid at 1080p and keeps the x-height at or above
## UIText.MIN_X_HEIGHT_1080; the fonts' real glyph metrics match the table UIText reasons with; and
## no screen draws text except through UIText (so its runtime check sees every size). The scene smoke
## phase of run_all.gd then runs every scene and checks its Labels and Buttons.

const NAMED := {"label": UIText.LABEL, "body": UIText.BODY, "title": UIText.TITLE,
	"number": UIText.NUMBER, "heading": UIText.HEADING, "display": UIText.DISPLAY}


func test_named_sizes_live_in_the_theme() -> void:
	var th: Theme = load("res://ui/theme.tres")
	for k: String in NAMED:
		check(th.has_font_size(k, "Sizes"), "theme has Sizes/%s" % k)
		eq(th.get_font_size(k, "Sizes"), int(NAMED[k]), "theme Sizes/%s matches UIText" % k)


func test_named_sizes_meet_the_floor() -> void:
	for f: Font in [UIText.SANS, UIText.BOLD, UIText.SERIF]:
		for k: String in NAMED:
			var sz: int = NAMED[k]
			check(UIText.size_ok(f, sz), "%s at %s (%d) is on the grid and >= %d px x-height at 1080p (%.1f)" % [
				UIText.face_of(f), k, sz, UIText.MIN_X_HEIGHT_1080, UIText.x_height_1080(f, sz)])
	# the smallest text in the game is 16 px x-height at 1080p, above the 14 px floor
	check(UIText.x_height_1080(UIText.SANS, UIText.BODY) >= 16.0, "body x-height >= 16 px at 1080p")
	check(not UIText.size_ok(UIText.SANS, 5), "size 5 (8 px x-height) is refused")
	check(not UIText.size_ok(UIText.SANS, 12), "size 12 (off the pixel grid) is refused")


## Glyph metrics measured from the font files at 1 px per font pixel (size 15).
func test_font_metrics_match_the_table() -> void:
	var ts := TextServerManager.get_primary_interface()
	for f: FontFile in [UIText.SANS, UIText.BOLD, UIText.SERIF]:
		var face := UIText.face_of(f)
		var rid := f.get_rids()[0]
		var gx := ts.font_get_glyph_index(rid, UIText.EM_UNITS, "x".unicode_at(0), 0)
		var gh := ts.font_get_glyph_index(rid, UIText.EM_UNITS, "H".unicode_at(0), 0)
		# rendered glyph boxes carry 1 px of padding on each side
		var xh := ts.font_get_glyph_size(rid, Vector2i(UIText.EM_UNITS, 0), gx).y - 2.0
		var ch := ts.font_get_glyph_size(rid, Vector2i(UIText.EM_UNITS, 0), gh).y - 2.0
		eq(int(xh), int(UIText.X_HEIGHT_UNITS[face]), "%s x-height in font pixels" % face)
		eq(int(ch), int(UIText.CAP_UNITS[face]), "%s cap height in font pixels" % face)


func test_fonts_cover_the_character_set() -> void:
	var need := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,!?'’:;-–—()/%+&\"“”…·×▲▼▸"
	for f: FontFile in [UIText.SANS, UIText.BOLD]:
		for i in need.length():
			check(f.has_char(need.unicode_at(i)), "%s has '%s'" % [UIText.face_of(f), need[i]])
	for i in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,!?'’:;-()%+…×".length():
		var s := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,!?'’:;-()%+…×"
		check(UIText.SERIF.has_char(s.unicode_at(i)), "serif has '%s'" % s[i])


func test_every_theme_font_size_is_legible() -> void:
	var th: Theme = load("res://ui/theme.tres")
	for type in th.get_font_size_type_list():
		for nm in th.get_font_size_list(type):
			var sz := th.get_font_size(nm, type)
			var f: Font = th.default_font
			for fk in ["font", "normal_font"]:
				if th.has_font(fk, type):
					f = th.get_font(fk, type)
			check(UIText.size_ok(f, sz), "theme %s/%s = %d is legible" % [type, nm, sz])


## Every screen draws text through UIText (the floor check sees every size), never raw.
func test_text_goes_through_ui_text() -> void:
	var raw := RegEx.create_from_string("\\.(draw_string|draw_multiline_string|draw_char|draw_string_outline|draw_multiline_string_outline)\\(")
	var lit := RegEx.create_from_string("add_theme_font_size_override\\([^,]+,\\s*(\\d+)\\)")
	for path in _scripts("res://scenes") + _scripts("res://ui"):
		if path.ends_with("ui/ui_text.gd"):
			continue
		var src := FileAccess.get_file_as_string(path)
		check(raw.search(src) == null, "%s draws text only through UIText" % path)
		check(not src.contains(".fnt\""), "%s uses no bitmap .fnt font" % path)
		for m in lit.search_all(src):
			check(UIText.size_ok(UIText.SANS, int(m.get_string(1))), "%s font size override %s is legible" % [path, m.get_string(1)])


static func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
