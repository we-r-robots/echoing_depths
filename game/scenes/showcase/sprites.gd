extends Node2D
## Sprite gallery (a showcase, not a battle): every character in its own framed
## cell with its name and the animation playing, cycling through idle, attack,
## cast, hit and KO on a staggered schedule, plus a row of the combat FX.
## No input; deterministic timing. Heroes are upright at frames 60 and 240.
## All colours are master-palette entries.

const META_PATH := "res://assets/sprites/sprite_meta.json"

const C_BG := Color8(21, 19, 39)        # ink2
const C_CELL := Color8(31, 29, 58)      # ink3
const C_EDGE := Color8(61, 59, 107)     # ink5
const C_FLOOR := Color8(44, 42, 82)     # ink4
const C_NAME := Color8(251, 210, 122)   # amber6
const C_ANIM := Color8(110, 112, 163)   # ink7
const C_TITLE := Color8(191, 194, 220)  # ink9

const SCHED_ATTACK_FIRST := ["attack", 1.0, "cast", 1.0, "hit", 0.8, "ko", 1.2, "revive", 0.7]
const SCHED_CAST_FIRST := ["cast", 1.0, "attack", 1.0, "hit", 0.8, "ko", 1.2, "revive", 0.7]

# name, label, cell rect (x, y, w, h), schedule, initial idle delay (s)
const CELLS := [
	["fighter", "FIGHTER", Rect2(8, 22, 152, 104), "attack", 0.5],
	["rogue", "ROGUE", Rect2(164, 22, 152, 104), "attack", 0.0],
	["healer", "HEALER", Rect2(320, 22, 152, 104), "cast", 0.6],
	["mage", "MAGE", Rect2(476, 22, 156, 104), "attack", 2.9],
	["wisp", "MNEMOWISP", Rect2(8, 130, 204, 126), "cast", 0.3],
	["shardback", "SHARDBACK", Rect2(216, 130, 204, 126), "attack", 1.6],
	["warden", "FADED WARDEN", Rect2(424, 130, 208, 126), "attack", 0.6],
]
const FX_CELLS := [
	["hit_spark", "HIT SPARK", Rect2(8, 260, 204, 92)],
	["magic_burst", "MAGIC BURST", Rect2(216, 260, 204, 92)],
	["heal_glow", "HEAL GLOW", Rect2(424, 260, 208, 92)],
]

const GLYPHS := {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
	"E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
	"I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
	"Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
	"U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111", "-": "000000111000000", " ": "000000000000000",
}

var _meta: Dictionary = {}
var _fx_frames: SpriteFrames
var _actors: Array = []
var _fx_players: Array = []


func _ready() -> void:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	_fx_frames = load(_meta["fx"]["path"])
	for c in CELLS:
		_actors.append(_spawn(c))
	for f in FX_CELLS:
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = _fx_frames
		spr.position = (f[2] as Rect2).get_center() + Vector2(0, 4)
		add_child(spr)
		spr.play(f[0])
		_fx_players.append({"spr": spr, "kind": f[0], "wait": 0.0})
		spr.animation_finished.connect(_on_fx_loop.bind(_fx_players[-1]))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), C_BG)
	_text("SPRITE GALLERY", Vector2(8, 8), C_TITLE)
	_text("HEROES AND VAULT MONSTERS - EVERY ANIMATION", Vector2(80, 8), C_ANIM)
	for c in CELLS:
		_cell(c[2], c[1])
	for f in FX_CELLS:
		_cell(f[2], f[1])


func _cell(r: Rect2, label: String) -> void:
	draw_rect(r, C_CELL)
	draw_rect(Rect2(r.position.x, r.end.y - 14, r.size.x, 14), C_FLOOR)
	draw_rect(r, C_EDGE, false, -1.0)
	_text(label, r.position + Vector2(4, 4), C_NAME)


func _text(s: String, at: Vector2, col: Color) -> void:
	var x := at.x
	for ch in s.to_upper():
		var g: String = GLYPHS.get(ch, GLYPHS[" "])
		for i in 15:
			if g[i] == "1":
				draw_rect(Rect2(x + i % 3, at.y + i / 3, 1, 1), col)
		x += 4


func _spawn(c: Array) -> Dictionary:
	var name_: String = c[0]
	var m: Dictionary = _meta[name_]
	var r: Rect2 = c[2]
	var root := Node2D.new()
	var w: int = int(m["size"][0])
	var ox: int = int(m["origin"][0])
	# centre the character's body (not its frame) in the cell; feet on the cell floor
	var body_cx := 32 if w <= 64 else 40
	root.position = Vector2(roundi(r.get_center().x - (body_cx - ox) - 8), roundi(r.end.y - 9))
	add_child(root)
	var shadow := Sprite2D.new()
	var size_key := "l" if name_ in ["warden", "shardback"] else ("m" if name_ == "fighter" else "s")
	shadow.texture = load("res://assets/sprites/env/shadow_%s.png" % size_key)
	root.add_child(shadow)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load(m["path"])
	spr.centered = false
	spr.position = Vector2(-ox, -int(m["origin"][1]))
	root.add_child(spr)
	var label := Node2D.new()  # current animation name, bottom-right of the cell
	add_child(label)
	var a := {"name": name_, "root": root, "spr": spr, "meta": m, "rect": r,
		"sched": SCHED_CAST_FIRST if c[3] == "cast" else SCHED_ATTACK_FIRST, "step": 0, "wait": 0.0, "tag": label}
	label.draw.connect(_draw_tag.bind(a))
	spr.frame_changed.connect(_on_frame.bind(a))
	spr.animation_finished.connect(_on_finished.bind(a))
	if float(c[4]) > 0.0:
		spr.play("idle")
		a["step"] = -1
		a["wait"] = float(c[4])
	else:
		_start_step(a)
	return a


func _draw_tag(a: Dictionary) -> void:
	var anim := String((a["spr"] as AnimatedSprite2D).animation).to_upper()
	var r: Rect2 = a["rect"]
	var node: Node2D = a["tag"]
	var w := anim.length() * 4
	var x := r.end.x - w - 4
	for ch in anim:
		var g: String = GLYPHS.get(ch, GLYPHS[" "])
		for i in 15:
			if g[i] == "1":
				node.draw_rect(Rect2(x + i % 3, r.end.y - 10 + i / 3, 1, 1), C_ANIM)
		x += 4


func _start_step(a: Dictionary) -> void:
	var s = a["sched"][a["step"]]
	var spr: AnimatedSprite2D = a["spr"]
	if s is float or s is int:
		if String(spr.animation) != "ko":
			spr.play("idle")
		a["wait"] = float(s)
	elif s == "revive":
		spr.play("idle")
		_next(a)
	else:
		spr.play(s)
		a["wait"] = -1.0
		if s == "hit" or s == "ko":
			_fx("hit_spark", a, Vector2(2, -20))
	(a["tag"] as Node2D).queue_redraw()


func _next(a: Dictionary) -> void:
	a["step"] = (a["step"] + 1) % a["sched"].size()
	_start_step(a)


func _process(delta: float) -> void:
	for a in _actors:
		if a["wait"] > 0.0:
			a["wait"] -= delta
			if a["wait"] <= 0.0:
				_next(a)
	for f in _fx_players:
		if f["wait"] > 0.0:
			f["wait"] -= delta
			if f["wait"] <= 0.0:
				(f["spr"] as AnimatedSprite2D).play(f["kind"])


func _on_fx_loop(f: Dictionary) -> void:
	f["wait"] = 0.6


func _on_finished(a: Dictionary) -> void:
	if a["step"] < 0:
		return
	var s = a["sched"][a["step"]]
	if s is String:
		_next(a)  # after "ko" the next step is a hold: the last KO frame stays up


func _on_frame(a: Dictionary) -> void:
	var spr: AnimatedSprite2D = a["spr"]
	var anim := String(spr.animation)
	var ev: Dictionary = a["meta"]["anims"].get(anim, {}).get("events", {})
	if not ev.has("impact") or spr.frame != int(ev["impact"]):
		return
	var n: String = a["name"]
	if anim == "attack":
		var reach := {"fighter": 32, "rogue": 30, "healer": 30, "mage": 32, "wisp": 30, "shardback": 32, "warden": 42}
		_fx("hit_spark", a, Vector2(reach.get(n, 30), -22))
	elif anim == "cast":
		match n:
			"healer":
				_fx("heal_glow", a, Vector2(0, -16))
			"fighter":
				_fx("hit_spark", a, Vector2(14, -6))
			"rogue":
				_fx("hit_spark", a, Vector2(38, -24))
			_:
				_fx("magic_burst", a, Vector2(34, -26))


func _fx(kind: String, a: Dictionary, local: Vector2) -> void:
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = _fx_frames
	var root: Node2D = a["root"]
	fx.position = (root.position + local).round()
	fx.z_index = 5
	# keep effects inside their cell
	var r: Rect2 = a["rect"]
	fx.position.x = clampf(fx.position.x, r.position.x + 12, r.end.x - 12)
	add_child(fx)
	fx.play(kind)
	fx.animation_finished.connect(fx.queue_free)
