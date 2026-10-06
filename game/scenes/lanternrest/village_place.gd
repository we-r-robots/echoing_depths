class_name VillagePlace
extends Node2D
## One tappable place in Lanternrest: a positioned world object (pixel art at its world position),
## with a tap zone and a highlight. The screen hit-tests zones in world px and opens the place's
## panel; a walking avatar could later walk up to `zone` and interact the same way.
##
##   var p := VillagePlace.make("vault")      # position = the art's world position
##   p.contains(world_point) / p.world_zone() / p.highlight = true

var id := ""
var kind := ""
var highlight := false:
	set(v):
		if v != highlight:
			highlight = v
			queue_redraw()
var _tex: Texture2D
var _hi: Texture2D
var _hi_off := Vector2.ZERO
var _glow: Sprite2D
var _glow_base := 0.0
var _flames: Array[Texture2D] = []
var _flame_off := Vector2.ZERO
var _t := 0.0
var _flick := 1.0
var _flick_next := 0.0
var _rng := RandomNumberGenerator.new()
var crest_id := ""            # the lantern draws the team's crest on its banner


static func make(place_id: String) -> VillagePlace:
	var p := VillagePlace.new()
	p.id = place_id
	p.kind = Village.kind(place_id)
	p.name = place_id
	var art := String(Village.PLACES[place_id]["art"])
	p._tex = Village.texture(art)
	p.position = Village.layer_pos(art)
	p._hi = Village.texture(art + "_hi")
	p._hi_off = Village.layer_pos(art + "_hi") - p.position
	var glow := String(Village.PLACES[place_id].get("glow", ""))
	if glow != "":
		var g := Sprite2D.new()
		g.texture = Village.texture(glow)
		g.centered = false
		g.position = Village.layer_pos(glow) - p.position
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = m
		p._glow_base = {"lantern": 0.3, "vault": 0.55, "building": 0.5}.get(p.kind, 0.5)
		g.modulate.a = p._glow_base
		p._glow = g
		p.add_child(g)
	if p.kind == "lantern":
		for i in 4:
			p._flames.append(Village.texture("flame_%d" % i))
		p._flame_off = Village.layer_pos("flame") - p.position
	p._rng.seed = hash(place_id)
	return p


## The tap zone in world px.
func world_zone() -> Rect2:
	return Village.zone(id)


func contains(world_point: Vector2) -> bool:
	return world_zone().has_point(world_point)


## World x of the zone's centre (the camera centres here when the place is focused).
func center_x() -> float:
	return world_zone().get_center().x


func _process(delta: float) -> void:
	_t += delta
	if _glow != null:
		if _t >= _flick_next:
			_flick_next = _t + _rng.randf_range(0.08, 0.22)
			# light breathes in a few steps, never smears (as the encounter glow layers do)
			_flick = 1.0 - roundf(_rng.randf() * 3.0) / 3.0 * 0.18
		_glow.modulate.a = _glow_base * _flick * (1.25 if highlight else 1.0)
	if not _flames.is_empty():
		queue_redraw()


func _draw() -> void:
	draw_texture(_tex, Vector2.ZERO)
	if not _flames.is_empty():
		draw_texture(_flames[int(_t * 7.0) % _flames.size()], _flame_off)
	if kind == "lantern" and crest_id != "":
		Crests.draw(self, Village.banner_pos() - position, crest_id, 1)
	if highlight:
		draw_texture(_hi, _hi_off)
