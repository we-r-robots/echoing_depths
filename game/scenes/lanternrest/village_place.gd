class_name VillagePlace
extends Node2D
## One tappable place in Lanternrest: a world object at its art's world position, with a tap zone
## (layout data) and a highlight that hugs its silhouette (the generated `<art>_hi` sprite: the place
## a light step brighter inside a 1 px amber outline). The screen hit-tests zones in world px and
## opens the place's panel; a walking avatar could later walk up to `zone` and interact the same way.
## Its light (Village.lights() with this place) brightens while it is highlighted or pressed; the
## lantern's flame and the banners move here.
##
##   var p := VillagePlace.make("vault")      # position = the art's world position
##   p.contains(world_point) / p.world_zone() / p.highlight = true / p.pressed = true

const BANNER_FRAMES := [0, 1, 0, 2]

var id := ""
var kind := ""
var highlight := false:
	set(v):
		if v != highlight:
			highlight = v
			queue_redraw()
var pressed := false:
	set(v):
		if v != pressed:
			pressed = v
			queue_redraw()
var crest_id := ""            # the lantern's banner carries the team's crest
var _tex: Texture2D
var _hi: Texture2D
var _hi_off := Vector2.ZERO
var _flames: Array[Texture2D] = []
var _banner: Array[Texture2D] = []
var _banner_at := Vector2.ZERO
var _t := 0.0
var _frame := -1


static func make(place_id: String) -> VillagePlace:
	var p := VillagePlace.new()
	p.id = place_id
	p.kind = Village.kind(place_id)
	p.name = place_id
	var art := Village.art(place_id)
	if art != "":
		p._tex = Village.texture(art)
		p.position = Village.layer_pos(art)
		p._hi = Village.texture(art + "_hi")
		p._hi_off = Village.layer_pos(art + "_hi") - p.position
	else:
		p._hi = Village.texture(place_id + "_hi")
		p.position = Village.layer_pos(place_id + "_hi")
	if p.kind == "lantern":
		for i in 4:
			p._flames.append(Village.texture("flame_%d" % i))
		p._banner_at = Village.banner_pos() - p.position
	elif Village.banners().has(place_id):
		p._banner_at = Village._v(Village.banners()[place_id]) - p.position
	if p.kind == "lantern" or Village.banners().has(place_id):
		for i in 3:
			p._banner.append(Village.texture("banner_%d" % i))
	return p


## The tap zone in world px.
func world_zone() -> Rect2:
	return Village.zone(id)


func contains(world_point: Vector2) -> bool:
	return world_zone().has_point(world_point)


func center() -> Vector2:
	return world_zone().get_center()


## How bright its light burns now (1 idle, more while highlighted or pressed).
func light_boost() -> float:
	return 1.6 if pressed else (1.35 if highlight else 1.0)


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * 7.0) * 1000 + int(_t * 2.5)
	if (not _flames.is_empty() or not _banner.is_empty()) and f != _frame:
		_frame = f
		queue_redraw()


func _draw() -> void:
	draw_on(self, Vector2.ZERO)


## Draws the place (art, moving parts, highlight) on any canvas item with its top-left at `at`
## (the screen's lift redraws the selected place above the panel shade this way).
func draw_on(ci: CanvasItem, at: Vector2) -> void:
	if _tex != null:
		ci.draw_texture(_tex, at)
	if not _banner.is_empty():
		ci.draw_texture(_banner[BANNER_FRAMES[int(_t * 2.5) % BANNER_FRAMES.size()]], at + _banner_at)
		if kind == "lantern" and crest_id != "":
			Crests.draw(ci, at + _banner_at + Vector2(2, 3), crest_id, 1)
	if not _flames.is_empty():
		ci.draw_texture(_flames[int(_t * 7.0) % _flames.size()], at + Village.flame_pos() - position)
	if highlight or pressed or kind == "fog" and ci != self:
		ci.draw_texture(_hi, at + _hi_off)
