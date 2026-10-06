class_name VillagePlace
extends Node2D
## One tappable place in Lanternrest: a world object at its art's world position, with a tap zone
## (layout data). Its albedo (and the lantern's banner) sit in the world under the night's light;
## its flame and its outline draw above the night (TownLayers.Overlay calls draw_overlay). The
## outline is the standard one hugging its silhouette: `<art>_hi` (2 px, amber) while hovered or
## selected, `<art>_press` (3 px, brighter) while pressed, with its light burning brighter still.
## The mist's places have no art: a district-shaped outline is their highlight.
##
##   var p := VillagePlace.make("vault", "fresh")
##   p.contains(world_point) / p.world_zone() / p.highlight = true / p.pressed = true / p.look()

const BANNER_FRAMES := [0, 1, 0, 2]

var id := ""
var kind := ""
var stage := "fresh"
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
var crest_id := ""
var _tex: Texture2D
var _lit: Texture2D
var _lit_off := Vector2.ZERO
var _hi: Texture2D
var _press: Texture2D
var _hi_off := Vector2.ZERO
var _press_off := Vector2.ZERO
var _flames: Array[Texture2D] = []
var _banner: Array[Texture2D] = []
var _banner_at := Vector2.ZERO
var _t := 0.0
var _frame := -1


static func make(place_id: String, town_stage := "fresh") -> VillagePlace:
	var p := VillagePlace.new()
	p.id = place_id
	p.kind = Village.kind(place_id)
	p.stage = town_stage
	p.name = place_id
	var art := Village.art(place_id)
	var key := art if art != "" else place_id
	if art != "":
		p._tex = Village.texture(art)
		p.position = Village.layer_pos(art)
		var lit := "%s_lit_%s" % [art, town_stage]
		if Village.has_layer(lit):
			p._lit = Village.texture(lit)
			p._lit_off = Village.layer_pos(lit) - p.position
	else:
		p.position = Village.layer_pos(key + "_hi")
	p._hi = Village.texture(key + "_hi")
	p._hi_off = Village.layer_pos(key + "_hi") - p.position
	p._press = Village.texture(key + "_press")
	p._press_off = Village.layer_pos(key + "_press") - p.position
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


func world_zone() -> Rect2:
	return Village.zone(id)


func contains(world_point: Vector2) -> bool:
	return world_zone().has_point(world_point)


func center() -> Vector2:
	return world_zone().get_center()


## How bright its light burns now (1 idle, more while highlighted, most while pressed).
func light_boost() -> float:
	return 1.7 if pressed else (1.35 if highlight else 1.0)


## How it looks now, for tests: the outline drawn ("" / "hover" / "pressed"), its width in px,
## the light boost, and how far the outline sits down (pressed nudges it 1 px: a press).
func look() -> Dictionary:
	if pressed:
		return {"outline": "pressed", "width": 3, "boost": light_boost(), "offset": Vector2(0, 1)}
	if highlight:
		return {"outline": "hover", "width": 2, "boost": light_boost(), "offset": Vector2.ZERO}
	return {"outline": "", "width": 0, "boost": light_boost(), "offset": Vector2.ZERO}


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * 2.5)
	if not _banner.is_empty() and f != _frame:
		_frame = f
		queue_redraw()


func _draw() -> void:
	if _tex != null:
		draw_texture(_tex, Vector2.ZERO)
	_draw_banner(self, Vector2.ZERO, Color.WHITE)


func _draw_banner(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	if _banner.is_empty():
		return
	ci.draw_texture(_banner[BANNER_FRAMES[int(_t * 2.5) % BANNER_FRAMES.size()]], at + _banner_at, tint)
	if kind == "lantern" and crest_id != "":
		Crests.draw(ci, at + _banner_at + Vector2(4, 3), crest_id, 1)


## The flame and the outline (above the night), on any canvas item with the place's top-left at `at`.
func draw_overlay(ci: CanvasItem, at: Vector2, t: float) -> void:
	if not _flames.is_empty():
		ci.draw_texture(_flames[int(t * 7.0) % _flames.size()], at + Village.flame_pos() - position)
	if pressed:
		ci.draw_texture(_press, at + _press_off + Vector2(0, 1))
	elif highlight:
		ci.draw_texture(_hi, at + _hi_off)


## The place as it looks lit (for the lift above the panel dim): its lit pixels, banner, flame and
## outline; the mist's places draw their outline only.
func draw_lifted(ci: CanvasItem, at: Vector2) -> void:
	if _lit != null:
		ci.draw_texture(_lit, at + _lit_off)
	_draw_banner(ci, at, Village.banner_light(stage))
	if not _flames.is_empty():
		ci.draw_texture(_flames[int(_t * 7.0) % _flames.size()], at + Village.flame_pos() - position)
	ci.draw_texture(_hi, at + _hi_off)
