class_name Crests
extends RefCounted
## Team crests: a small shield (13x15 px) with a 7x7 symbol, drawn pixel by pixel from the master
## palette (UI chrome, no art files). A team picks one at the Banner Hall in Lanternrest; Echo
## snapshots carry it as meta.crest. Echoes without one (generated rivals, older saves) get a
## crest picked from their team name, so every rival still shows one.
##   Crests.draw(canvas_item, top_left, id, scale)     # scale in whole design px per crest pixel
##   Crests.for_team(crest_id, team_name)              # the crest to show for an Echo

const W := 13
const H := 15
const DEFAULT_CREST := "lantern"
const DEFAULT_UNLOCKED := ["lantern", "crystal", "moon"]

const SHIELD := [
	"#############",
	"#+++++++++++#",
	"#+++++++++++#",
	"#+++++++++++#",
	"#+++++++++++#",
	"#+++++++++++#",
	"#+++++++++++#",
	"#+++++++++++#",
	"#+++++++++++#",
	"#+++++++++++#",
	".#+++++++++#.",
	"..#+++++++#..",
	"...##+++##...",
	".....###.....",
	".............",
]

## id -> name, colours [field, edge, symbol, accent], symbol rows (# symbol, o accent).
const CRESTS := {
	"lantern": {"name": "Lantern", "cols": ["amber1", "amber5", "amber6", "amber7"], "sym": [
		"..###..", ".#...#.", ".#.o.#.", ".#ooo#.", ".#.o.#.", ".#...#.", "..###.."]},
	"crystal": {"name": "Crystal", "cols": ["crystal1", "crystal4", "crystal4", "crystal5"], "sym": [
		"...#...", "..#o#..", ".#ooo#.", "#ooooo#", ".#ooo#.", "..#o#..", "...#..."]},
	"moon": {"name": "Moon", "cols": ["violet1", "violet3", "violet4", "ink10"], "sym": [
		"..###..", ".##....", "##.....", "##.....", "##.....", ".##....", "..###.."]},
	"star": {"name": "Star", "cols": ["ink3", "amber5", "amber6", "amber7"], "sym": [
		"...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "##...##"]},
	"key": {"name": "Key", "cols": ["blood1", "amber4", "amber6", "amber7"], "sym": [
		".###...", "#...#..", ".###...", "..#....", "..###..", "..#....", "..##..."]},
	"flame": {"name": "Flame", "cols": ["blood1", "blood3", "blood4", "amber6"], "sym": [
		"...#...", "..##...", "..###..", ".#####.", ".##o##.", "##ooo##", ".#####."]},
	"wave": {"name": "Wave", "cols": ["crystal1", "crystal3", "crystal4", "crystal5"], "sym": [
		".......", ".##..##", "#..##..", ".......", ".##..##", "#..##..", "......."]},
	"tower": {"name": "Tower", "cols": ["life1", "life3", "life4", "ink10"], "sym": [
		"#.#.#.#", "#######", ".#####.", ".##o##.", ".##o##.", ".#####.", "#######"]},
}
const ORDER := ["lantern", "crystal", "moon", "star", "key", "flame", "wave", "tower"]


static func exists(id: String) -> bool:
	return CRESTS.has(id)


static func name_of(id: String) -> String:
	return String(CRESTS.get(id, CRESTS[DEFAULT_CREST])["name"])


## The crest to show for a team: its own, else one picked from the name (stable per name).
static func for_team(crest_id: String, team: String) -> String:
	if exists(crest_id):
		return crest_id
	return ORDER[absi(team.hash()) % ORDER.size()]


## Accent colour of a crest (for name plates beside it).
static func accent(id: String) -> Color:
	return Pal.c(String(CRESTS.get(id, CRESTS[DEFAULT_CREST])["cols"][2]))


## Draws the crest with its top-left at `pos`, `px` design px per crest pixel. `dim` greys it
## out (a crest not yet unlocked).
static func draw(ci: CanvasItem, pos: Vector2, id: String, px := 2, dim := false) -> void:
	var d: Dictionary = CRESTS.get(id, CRESTS[DEFAULT_CREST])
	var cols: Array = d["cols"]
	var field := Pal.c(cols[0])
	var edge := Pal.c(cols[1])
	var sym := Pal.c(cols[2])
	var acc := Pal.c(cols[3])
	if dim:
		field = Pal.INK2
		edge = Pal.INK5
		sym = Pal.INK6
		acc = Pal.INK6
	pos = pos.round()
	# drop shadow one crest pixel down
	for y in SHIELD.size():
		var row: String = SHIELD[y]
		for x in row.length():
			if row[x] != ".":
				ci.draw_rect(Rect2(pos + Vector2(x * px, (y + 1) * px), Vector2(px, px)), Pal.INK1)
	for y in SHIELD.size():
		var row: String = SHIELD[y]
		for x in row.length():
			var ch := row[x]
			if ch == "#":
				ci.draw_rect(Rect2(pos + Vector2(x, y) * px, Vector2(px, px)), edge)
			elif ch == "+":
				ci.draw_rect(Rect2(pos + Vector2(x, y) * px, Vector2(px, px)), field)
	var sx := 3
	var sy := 3
	var rows: Array = d["sym"]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "#":
				ci.draw_rect(Rect2(pos + Vector2(sx + x, sy + y) * px, Vector2(px, px)), sym)
			elif ch == "o":
				ci.draw_rect(Rect2(pos + Vector2(sx + x, sy + y) * px, Vector2(px, px)), acc)


static func dims(px := 2) -> Vector2:
	return Vector2(W, H) * px
