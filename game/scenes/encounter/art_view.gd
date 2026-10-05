class_name EncounterArt
extends Control
## Full-bleed encounter illustration with data-driven liveliness:
##   layers: {tex, blend:"add", pulse:[min,max,period]} | {tex, flicker:[min,max]} | {frames:[...], fps}
##   any layer may carry "id" (and "hidden": true); a choice's "art": {hide:[ids], show:[ids]} cross-fades them.
##   motes:  drifting 1px light motes {rect:[x,y,w,h], count, colors:[palette names], speed}
##   drops:  falling 1-2px drops {x, y0, y1, color}
## All positions are in art pixels; `offset` shifts the whole painting (e.g. to clear the top bar).

var art: Dictionary
var _layers: Array = []   # [{node, kind, params}]
var _motes: Array = []    # [{p: Vector2, v: float, c: Color, ph: float}]
var _drops: Array = []
var _t := 0.0
var _offset := Vector2.ZERO
var _mote_rect := Rect2()
var _mote_speed := 4.0
var _flicker_rng := RandomNumberGenerator.new()
var _flick_val := 0.7
var _flick_next := 0.0


func setup(a: Dictionary) -> void:
	art = a
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_flicker_rng.seed = 4242
	var dir: String = a.get("dir", "")
	var off: Array = a.get("offset", [0, 0])
	_offset = Vector2(off[0], off[1])
	var bg := TextureRect.new()
	bg.texture = load(dir + a.get("bg", "bg.png"))
	bg.position = _offset
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for l in a.get("layers", []):
		var node := TextureRect.new()
		node.position = _offset
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if l.has("frames"):
			var texs: Array[Texture2D] = []
			for f in l["frames"]:
				texs.append(load(dir + f))
			node.texture = texs[0]
			_layers.append({"node": node, "kind": "frames", "texs": texs, "fps": float(l.get("fps", 4))})
			_layers[-1]["params"] = []
		else:
			node.texture = load(dir + l["tex"])
			var kind := "static"
			if l.has("pulse"):
				kind = "pulse"
			elif l.has("flicker"):
				kind = "flicker"
			_layers.append({"node": node, "kind": kind, "params": l.get("pulse", l.get("flicker", []))})
		_layers[-1]["id"] = l.get("id", "")
		_layers[-1]["vis"] = 0.0 if l.get("hidden", false) else 1.0
		if l.get("blend", "") == "add":
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			node.material = m
		add_child(node)
	var mo: Dictionary = a.get("motes", {})
	if not mo.is_empty():
		var r: Array = mo["rect"]
		_mote_rect = Rect2(r[0], r[1], r[2], r[3])
		_mote_speed = float(mo.get("speed", 4))
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var cols: Array = mo.get("colors", ["crystal4"])
		for i in int(mo.get("count", 16)):
			_motes.append({
				"p": Vector2(rng.randf_range(_mote_rect.position.x, _mote_rect.end.x), rng.randf_range(_mote_rect.position.y, _mote_rect.end.y)),
				"v": rng.randf_range(0.6, 1.4),
				"c": Pal.c(cols[i % cols.size()]),
				"ph": rng.randf() * TAU,
			})
	for d in a.get("drops", []):
		_drops.append({"x": float(d["x"]), "y0": float(d["y0"]), "y1": float(d["y1"]), "c": Pal.c(d.get("color", "crystal5"))})
	# particles draw above the layers
	var fx := Control.new()
	fx.name = "FX"
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.draw.connect(_draw_fx.bind(fx))
	add_child(fx)


## Cross-fades layers for an outcome: {hide: [ids], show: [ids]}.
func apply_change(change: Dictionary, dur := 0.6) -> void:
	for l in _layers:
		var target := -1.0
		if l["id"] in change.get("hide", []):
			target = 0.0
		elif l["id"] in change.get("show", []):
			target = 1.0
		if target >= 0.0:
			var tw := create_tween()
			tw.tween_method(func(v: float) -> void: l["vis"] = v, float(l["vis"]), target, dur)


## Screen position of the art's memory source (where absorbed memories fly from).
func source_point() -> Vector2:
	var s: Array = art.get("source", [160, 120])
	return Vector2(s[0], s[1]) + _offset


func _process(delta: float) -> void:
	_t += delta
	if _t >= _flick_next:
		_flick_next = _t + _flicker_rng.randf_range(0.06, 0.18)
		_flick_val = _flicker_rng.randf()
	for l in _layers:
		var node: TextureRect = l["node"]
		var a := 1.0
		match l["kind"]:
			"pulse":
				var p: Array = l["params"]
				var k := 0.5 + 0.5 * sin(_t * TAU / float(p[2]))
				# quantise the pulse to a few steps so light breathes in bands, not smears
				k = roundf(k * 4.0) / 4.0
				a = lerpf(p[0], p[1], k)
			"flicker":
				var p: Array = l["params"]
				a = lerpf(p[0], p[1], roundf(_flick_val * 3.0) / 3.0)
			"frames":
				var texs: Array[Texture2D] = l["texs"]
				node.texture = texs[int(_t * float(l["fps"])) % texs.size()]
		node.modulate.a = a * float(l["vis"])
		node.visible = float(l["vis"]) > 0.0
	var fx := get_node_or_null("FX")
	if fx:
		fx.queue_redraw()


func _draw_fx(fx: Control) -> void:
	for m in _motes:
		var h := _mote_rect.size.y
		var y: float = m["p"].y - fmod(_t * _mote_speed * float(m["v"]), h)
		if y < _mote_rect.position.y:
			y += h
		var x: float = m["p"].x + sin(_t * 0.8 + float(m["ph"])) * 3.0
		var tw := 0.5 + 0.5 * sin(_t * 2.2 + float(m["ph"]))
		if tw < 0.15:
			continue
		var c: Color = m["c"]
		var pos := (Vector2(x, y) + _offset).round()
		fx.draw_rect(Rect2(pos, Vector2(1, 1)), c)
		if tw > 0.85:
			fx.draw_rect(Rect2(pos + Vector2(0, 1), Vector2(1, 1)), c)
	for d in _drops:
		var span: float = d["y1"] - d["y0"]
		for k in 3:
			var y: float = d["y0"] + fmod(_t * 55.0 + k * span / 3.0, span)
			var pos := (Vector2(d["x"], y) + _offset).round()
			fx.draw_rect(Rect2(pos, Vector2(2, 3)), d["c"])
