class_name TownLayers
extends RefCounted
## The moving layers of Lanternrest's town, drawn in world px on whole pixels (docs/BUILD.md: no
## sub-pixel motion, no filtering; no shaders, only additive / alpha canvas blends):
##   TownLayers.Lights   additive light: the lantern flickers, the Vault's cold light pulses slowly,
##                       street lamps waver; a place's light burns brighter while it is hovered or
##                       pressed (its VillagePlace.light_boost())
##   TownLayers.Life     chimney smoke rising, grass tufts swaying
##   TownLayers.Mist     the mist's body over the edges and its wisps drifting (half resolution x2)


## Additive glows from Village.lights(). `places` is the screen's id -> VillagePlace map: a light
## that belongs to a place shows only while that place stands.
class Lights:
	extends Node2D
	var places: Dictionary = {}
	var _items: Array = []      # [{light, tex, off, kind, level, next, phase}]
	var _t := 0.0
	var _rng := RandomNumberGenerator.new()

	func _init() -> void:
		name = "Lights"
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
		_rng.seed = 7
		for l: Dictionary in Village.lights():
			var g := String(l["glow"])
			_items.append({"light": l, "tex": Village.texture(g), "off": Village.layer_pos(g),
				"kind": String(l["id"]).get_slice("_", 0), "level": 1.0, "next": 0.0,
				"phase": _rng.randf() * TAU})

	## How strongly each light burns now (0..~1.6), for tests and captures.
	func level(id: String) -> float:
		for it: Dictionary in _items:
			if String(it["light"]["id"]) == id:
				return float(it["level"]) * _boost(it)
		return 0.0

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
					# a living flame: the light steps between a few levels at uneven moments
					if _t >= float(it["next"]):
						it["next"] = _t + _rng.randf_range(0.07, 0.2)
						it["level"] = [1.0, 0.93, 0.86, 1.0, 0.96][_rng.randi() % 5]
				"vault":
					# the deep breathes: a slow pulse, in steps of 6%
					it["level"] = 0.76 + roundf((0.5 + 0.5 * sin(_t * 1.1)) * 4.0) * 0.06
				"lamp", "grounds":
					if _t >= float(it["next"]):
						it["next"] = _t + _rng.randf_range(0.15, 0.6)
						it["level"] = [1.0, 0.95, 1.0, 0.9][_rng.randi() % 4]
		queue_redraw()

	func _draw() -> void:
		for it: Dictionary in _items:
			var l: Dictionary = it["light"]
			var pid := String(l.get("place", ""))
			if pid != "" and not places.has(pid):
				continue
			var at := Vector2(float(l["gx"]), float(l["gy"])) - (it["off"] as Vector2)
			draw_texture(it["tex"], at, Color(1, 1, 1, clampf(float(it["level"]) * _boost(it), 0.0, 2.0)))


## Chimney smoke and swaying grass.
class Life:
	extends Node2D
	const PUFFS := 8
	const RISE := 3.6          # seconds a puff takes to fade
	var places: Dictionary = {}
	var _grass: Array[Texture2D] = []
	var _t := 0.0
	var _frame := -1
	var _cols: Array[Color] = [Color(Pal.FADE3, 0.75), Color(Pal.FADE2, 0.55), Color(Pal.FADE2, 0.32)]

	func _init() -> void:
		name = "Life"
		for i in 2:
			_grass.append(Village.texture("grass_%d" % i))

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
			# each tuft leans in the wind a moment at a time, out of step with its neighbours
			var lean := int(_t * 1.3 + float(i) * 0.37) % 3 == 0
			draw_texture(_grass[1 if lean else 0], Vector2(float(g[0]), float(g[1])))
		for s: Dictionary in Village.smoke():
			var pid := String(s.get("place", ""))
			if pid != "" and not places.has(pid):
				continue
			var o := Vector2(float(s["x"]), float(s["y"]))
			for k in PUFFS:
				var age := fposmod(_t / RISE + float(k) / PUFFS + o.x * 0.013, 1.0)
				var x := roundf(sin(age * 5.0 + float(k)) * 1.5 + age * 9.0)
				var y := -roundf(age * 30.0)
				var sz := 3.0 if age < 0.3 else (4.0 if age < 0.65 else 5.0)
				var c: Color = _cols[mini(int(age * 3.0), 2)]
				draw_rect(Rect2(o + Vector2(x - 1, y), Vector2(sz, sz - 1)), c)
				draw_rect(Rect2(o + Vector2(x, y - 1), Vector2(sz - 2, 1)), c)


## The mist: its body over the edges (static) and wisps drifting slowly on whole pixels.
class Mist:
	extends Node2D
	var _body: Texture2D
	var _wisp: Texture2D
	var _t := 0.0
	var _off := Vector2.ZERO

	func _init() -> void:
		name = "Mist"
		_body = Village.texture("mist_body")
		_wisp = Village.texture("mist_wisp")

	## The wisps' drift now (world px, whole).
	func drift() -> Vector2:
		return Vector2(roundf(sin(_t * 0.055) * 16.0), roundf(sin(_t * 0.09 + 1.0) * 3.0))

	func _process(delta: float) -> void:
		_t += delta
		var o := drift()
		if o != _off:
			_off = o
			queue_redraw()

	func _draw() -> void:
		draw_texture(_body, Vector2.ZERO)
		draw_texture_rect(_wisp, Rect2(_off, Vector2(_wisp.get_size()) * 2.0), false)
