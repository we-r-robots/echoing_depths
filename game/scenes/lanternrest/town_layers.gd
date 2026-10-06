class_name TownLayers
extends RefCounted
## The layers of Lanternrest's town over its albedo, drawn in world px on whole pixels (docs/BUILD.md:
## no sub-pixel motion; no shaders, only CanvasItem blends). Back to front:
##   TownLayers.Life      grass tufts swaying, chimney smoke rising (lit by the night like the town)
##   TownLayers.Night     the stage's light map multiplied over everything below (BLEND_MODE_MUL):
##                        light TINTS the authored colours; smooth, no bands, no dither
##   TownLayers.Mist      the mist's translucent body and its drifting banks (smooth alpha, filtered)
##   TownLayers.Lights    additive bloom: the lantern flickers and its pool breathes, the Vault's cold
##                        shaft pulses, lamps waver; a place's light burns brighter while hovered or
##                        pressed (VillagePlace.light_boost()); also the faint ink lift (no pure black)
##   TownLayers.Overlay   what is not lit by the night: the lantern's flame, motes rising from the
##                        Vault, and the hover / pressed outline of each place


## Light entries for this meta: on when their stage is reached and their place stands.
static func _lit(meta: Dictionary) -> Array:
	var out: Array = []
	for l: Dictionary in Village.lights():
		if Village.entry_on(l, meta):
			out.append(l)
	return out


class Night:
	extends Sprite2D

	func _init() -> void:
		name = "Night"
		centered = false
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		material = m

	func set_stage(st: String) -> void:
		texture = Village.texture("light_" + st)


## Additive glows. `places` is the screen's id -> VillagePlace map.
class Lights:
	extends Node2D
	var places: Dictionary = {}
	var _items: Array = []      # [{light, tex, off, kind, level, next}]
	var _pool: Texture2D
	var _lamp_pool: Texture2D
	var _t := 0.0
	var _rng := RandomNumberGenerator.new()

	func _init() -> void:
		name = "Lights"
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_rng.seed = 7
		_pool = Village.texture("glow_pool")
		_lamp_pool = Village.texture("glow_lamp_pool")

	func setup(meta: Dictionary) -> void:
		_items.clear()
		for l: Dictionary in TownLayers._lit(meta):
			var g := String(l["glow"])
			_items.append({"light": l, "tex": Village.texture(g), "off": Village.layer_pos(g),
				"kind": String(l["id"]).get_slice("_", 0), "level": 1.0, "next": 0.0})
		queue_redraw()

	## How strongly a light burns now (0..~1.6), for tests and captures (0 when it is out).
	func level(id: String) -> float:
		for it: Dictionary in _items:
			if String(it["light"]["id"]) == id:
				return float(it["level"]) * _boost(it)
		return 0.0

	func ids() -> Array:
		return _items.map(func(it: Dictionary) -> String: return String(it["light"]["id"]))

	func _boost(it: Dictionary) -> float:
		var pid := String(it["light"].get("place", ""))
		if pid != "" and places.has(pid):
			return (places[pid] as VillagePlace).light_boost()
		return 1.0

	func _process(delta: float) -> void:
		_t += delta
		for it: Dictionary in _items:
			match String(it["kind"]):
				"lantern":
					if _t >= float(it["next"]):
						it["next"] = _t + _rng.randf_range(0.07, 0.2)
						it["level"] = [1.0, 0.92, 0.85, 1.0, 0.96][_rng.randi() % 5]
				"vault":
					it["level"] = 0.78 + (0.5 + 0.5 * sin(_t * 1.1)) * 0.3
				"lamp", "grounds":
					if _t >= float(it["next"]):
						it["next"] = _t + _rng.randf_range(0.15, 0.6)
						it["level"] = [1.0, 0.95, 1.0, 0.9][_rng.randi() % 4]
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Village.world_size()), Village.lift_color())
		for it: Dictionary in _items:
			var l: Dictionary = it["light"]
			var a := clampf(float(it["level"]) * _boost(it), 0.0, 2.0)
			var k := String(it["kind"])
			if k == "lantern":
				draw_texture(_pool, Vector2(float(l["x"]), float(l["y"]) - 6.0) - Village.layer_pos("glow_pool"), Color(1, 1, 1, a))
			elif k == "lamp" or k == "grounds":
				draw_texture(_lamp_pool, Vector2(float(l["x"]), float(l["y"])) - Village.layer_pos("glow_lamp_pool"), Color(1, 1, 1, a))
			var at := Vector2(float(l["gx"]), float(l["gy"])) - (it["off"] as Vector2)
			draw_texture(it["tex"], at, Color(1, 1, 1, a))


## Chimney smoke and swaying grass (below the night, so they are lit like the town).
class Life:
	extends Node2D
	const PUFFS := 8
	const RISE := 3.6
	var meta: Dictionary = {}
	var _grass: Array[Texture2D] = []
	var _smoke: Array = []
	var _t := 0.0
	var _frame := -1
	var _cols: Array[Color] = [Color(Pal.FADE3, 0.75), Color(Pal.FADE2, 0.55), Color(Pal.FADE2, 0.32)]

	func _init() -> void:
		name = "Life"
		for i in 2:
			_grass.append(Village.texture("grass_%d" % i))

	func setup(m: Dictionary) -> void:
		meta = m
		_smoke = Village.smoke().filter(func(s: Dictionary) -> bool: return Village.entry_on(s, m))
		queue_redraw()

	func smoke_count() -> int:
		return _smoke.size()

	func _process(delta: float) -> void:
		_t += delta
		var f := int(_t * 10.0)
		if f != _frame:
			_frame = f
			queue_redraw()

	func _draw() -> void:
		var tufts := Village.grass()
		for i in tufts.size():
			var g: Array = tufts[i]
			var lean := int(_t * 1.3 + float(i) * 0.37) % 3 == 0
			draw_texture(_grass[1 if lean else 0], Vector2(float(g[0]), float(g[1])))
		for s: Dictionary in _smoke:
			var o := Vector2(float(s["x"]), float(s["y"]))
			for k in PUFFS:
				var age := fposmod(_t / RISE + float(k) / PUFFS + o.x * 0.013, 1.0)
				var x := roundf(sin(age * 5.0 + float(k)) * 1.5 + age * 9.0)
				var y := -roundf(age * 30.0)
				var sz := 3.0 if age < 0.3 else (4.0 if age < 0.65 else 5.0)
				var c: Color = _cols[mini(int(age * 3.0), 2)]
				draw_rect(Rect2(o + Vector2(x - 1, y), Vector2(sz, sz - 1)), c)
				draw_rect(Rect2(o + Vector2(x, y - 1), Vector2(sz - 2, 1)), c)


## The mist: its translucent body over the edges (half resolution, drawn x2 filtered) and banks
## drifting slowly on whole pixels.
class Mist:
	extends Node2D
	var _body: Texture2D
	var _wisp: Texture2D
	var _t := 0.0
	var _off := Vector2.ZERO

	func _init() -> void:
		name = "Mist"
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_wisp = Village.texture("mist_wisp")

	func set_stage(st: String) -> void:
		_body = Village.texture("mist_body_" + st)
		queue_redraw()

	func drift() -> Vector2:
		return Vector2(roundf(sin(_t * 0.055) * 16.0), roundf(sin(_t * 0.09 + 1.0) * 3.0))

	func _process(delta: float) -> void:
		_t += delta
		var o := drift()
		if o != _off:
			_off = o
			queue_redraw()

	func _draw() -> void:
		var ws := Village.world_size()
		draw_texture_rect(_body, Rect2(Vector2.ZERO, ws), false)
		draw_texture_rect(_wisp, Rect2(_off, Vector2(_wisp.get_size()) * 2.0), false)


## Above the night and the mist: the lantern's flame, motes rising from the Vault, each place's
## outline while hovered or pressed.
class Overlay:
	extends Node2D
	var places: Dictionary = {}
	var _t := 0.0
	var _frame := -1

	func _init() -> void:
		name = "Overlay"

	func _process(delta: float) -> void:
		_t += delta
		var f := int(_t * 12.0)
		if f != _frame:
			_frame = f
			queue_redraw()

	func _draw() -> void:
		for id: String in places:
			var p := places[id] as VillagePlace
			p.draw_overlay(self, p.position, _t)
		if places.has("vault"):
			# motes of cold light drifting up out of the stairwell
			var z := Village.zone("vault")
			var o := Vector2(z.get_center().x, z.end.y - 22.0)
			for k in 7:
				var age := fposmod(_t * 0.35 + float(k) / 7.0, 1.0)
				var x := roundf(o.x + sin(age * 6.0 + float(k) * 1.7) * 3.0 + float(k % 3 - 1) * 6.0)
				var y := roundf(o.y - age * 44.0)
				draw_rect(Rect2(x, y, 1, 1), Color(Pal.CRYSTAL5, 1.0 - age))
