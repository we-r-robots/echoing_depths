extends Node2D
## One combatant on the battle grid. Motion is evaluated from the playback clock (sim time), so the
## lunge lands exactly on the event's impact time at any playback speed. Visual-only timers
## (flash, knockback, glow) run on the scene's visual delta.

const Layout = preload("res://scenes/battle/battle_layout.gd")
const SHADER = preload("res://scenes/battle/unit.gdshader")

enum Move { NONE, LUNGE, HOP, STAY }

# --- identity (from the fight_start unit snapshot) ---
var uid := -1
var side := 0
var col := 0
var row := 0
var label := ""
var class_name_ := ""
var base_class := ""
var level := 1
var is_monster := false
var is_echo := false
var ability_name := ""
var facing := 1            # +1 faces right (side 0), -1 faces left (side 1)
var home := Vector2.ZERO
var side_color := Color.WHITE

# --- live state, driven by events ---
var max_hp := 1
var hp := 1
var hp_shown := 1.0        # eased HP for bars
var hp_chip := 1.0         # trailing "lost" segment
var chip_wait := 0.0
var heal_glow := 0.0
var charge := 0
var charge_max := 100
var charge_shown := 0.0
var is_ready := false
var alive := true
var spd := 10
var g_base := 0.0          # ATB gauge model: gauge(t) = g_base + rate * max(0, t - t_base)
var t_base := 0.0
var g_rate := 0.0
var acting := false
var ko_t := -1.0

# --- motion plan (sim time) ---
var _move := Move.NONE
var _t0 := 0.0
var _t_arrive := 0.0
var _t_leave := 0.0
var _t_end := 0.0
var _dest := Vector2.ZERO
var _hop_h := 0.0
var _ghosts_on := false
var _pending_anim := &""
var _pending_at := 0.0

# --- visual timers (visual time) ---
var _flash := 0.0
var _flash_color := Color.WHITE
var _knock_t := 9.0
var _knock_dir := 0.0
var _knock_amp := 0.0
var _glow_t := 0.0
var _bob_t := 0.0
var victory_hop := false
var focus_rim := false
var dimmed := false
var lit := false          # part of the focused action: drawn above the dim, with a rim light
var charge_hold := 0.0
var charge_pulse := 0.0
var _echo_t := 0.0
var flip_at_dest := false
var buff_glow := 0.0
var buff_color := Color.WHITE
var _dim := 0.0

var spr: AnimatedSprite2D
var shadow: Sprite2D
var mat: ShaderMaterial
var meta: Dictionary
var _ghosts: Array[AnimatedSprite2D] = []
var _ghost_mat: ShaderMaterial
var _hist_pos: PackedVector2Array
var _hist_frame: PackedInt32Array
var _hist_anim: Array[StringName] = []
var _hist_i := 0
var _impact_frame := {}
var _anim_fps := {}
var _sprite_w := 64
var _sprite_h := 64
var _ox := 32
var _oy := 60
var height := 40           # visible sprite height (for popups and plates)


func setup(u: Dictionary, sprite_meta: Dictionary, shadow_tex: Texture2D, echo: bool, col_side: Color, swaps: Array) -> void:
	uid = int(u["uid"])
	side = int(u["side"])
	col = int(u["col"])
	row = int(u["row"])
	label = String(u.get("label", u.get("name", "?")))
	class_name_ = String(u.get("class_name", ""))
	base_class = String(u.get("base_class", u.get("class", "")))
	level = int(u.get("level", 1))
	is_monster = String(u.get("tier", "")) == "monster"
	is_echo = echo
	ability_name = String((u.get("ability", {}) as Dictionary).get("name", ""))
	max_hp = maxi(1, int(u["max_hp"]))
	hp = int(u["hp"])
	hp_shown = hp
	hp_chip = hp
	charge = int(u.get("charge", 0))
	charge_max = maxi(1, int(u.get("charge_max", 100)))
	charge_shown = charge
	spd = int(u.get("spd", 10))
	g_base = float(u.get("gauge", 0.0))
	facing = 1 if side == 0 else -1
	side_color = col_side
	home = Layout.slot_pos(side, col, row)
	if int(sprite_meta["size"][1]) > 64:
		home.x += 10.0 * facing          # large monsters: a wider slot, nudged toward the gutter
		if row == 0:
			home.y += 10.0               # far row: forward enough to clear the top band
	position = home
	meta = sprite_meta
	_sprite_w = int(meta["size"][0])
	_sprite_h = int(meta["size"][1])
	_ox = int(meta["origin"][0])
	_oy = int(meta["origin"][1])
	for a: String in (meta["anims"] as Dictionary):
		var ad: Dictionary = meta["anims"][a]
		_anim_fps[a] = float(ad.get("fps", 10))
		_impact_frame[a] = int((ad.get("events", {}) as Dictionary).get("impact", 0))
	height = 40 if _sprite_h <= 64 else _sprite_h - 6

	shadow = Sprite2D.new()
	shadow.texture = shadow_tex
	shadow.position = Vector2(0, 0)
	add_child(shadow)

	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = SHADER
	_ghost_mat.set_shader_parameter("flash", 1.0)
	_ghost_mat.set_shader_parameter("flash_color", col_side)
	var frames: SpriteFrames = load(String(meta["path"]))
	for i in 3:
		var g := AnimatedSprite2D.new()
		g.sprite_frames = frames
		g.centered = false
		g.material = _ghost_mat
		g.visible = false
		g.modulate = Color(1, 1, 1, 0.55 - i * 0.15)
		g.flip_h = facing < 0
		g.top_level = true
		g.z_index = -1
		g.z_as_relative = true
		add_child(g)
		_ghosts.append(g)
	_hist_pos.resize(12)
	_hist_frame.resize(12)
	_hist_anim.resize(12)
	for i in 12:
		_hist_anim[i] = &"idle"

	spr = AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.centered = false
	spr.flip_h = facing < 0
	spr.position = _sprite_offset()
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	if echo:
		mat.set_shader_parameter("outline_color", Color(Pal.CRYSTAL3, 0.75))
	if not swaps.is_empty():
		var from := PackedColorArray()
		var to := PackedColorArray()
		for pair: Array in swaps:
			from.append(pair[0])
			to.append(pair[1])
		from.resize(5)
		to.resize(5)
		mat.set_shader_parameter("swap_n", swaps.size())
		mat.set_shader_parameter("swap_from", from)
		mat.set_shader_parameter("swap_to", to)
	spr.material = mat
	add_child(spr)
	spr.animation_finished.connect(_on_anim_finished)
	spr.play(&"idle")
	spr.frame = (uid * 2) % maxi(1, spr.sprite_frames.get_frame_count(&"idle"))
	_bob_t = uid * 0.37


func _sprite_offset() -> Vector2:
	return Vector2(-_ox if facing > 0 else -(_sprite_w - _ox), -_oy)


## Offset (seconds) from an animation's start to its impact frame, read from sprite_meta.json.
func impact_offset(anim: String) -> float:
	if not _anim_fps.has(anim):
		return 0.0
	return float(_impact_frame[anim]) / maxf(1.0, float(_anim_fps[anim]))


func has_anim(anim: String) -> bool:
	return _anim_fps.has(anim)


## Plans a move to `dest` that arrives at `t_arrive`, holds, then returns home by `t_end`.
func plan_move(kind: int, t0: float, t_arrive: float, t_leave: float, t_end: float, dest: Vector2, hop_h: float = 0.0, ghosts: bool = false) -> void:
	_move = kind
	_t0 = t0
	_t_arrive = t_arrive
	_t_leave = t_leave
	_t_end = t_end
	_dest = dest
	_hop_h = hop_h
	_ghosts_on = ghosts
	acting = true
	z_index = 30


## Starts `anim` when the playback clock reaches `at` (so its impact frame lines up with the event).
func schedule_anim(anim: StringName, at: float) -> void:
	_pending_anim = anim
	_pending_at = at


func play_now(anim: StringName) -> void:
	if not alive and anim != &"ko":
		return
	if spr.sprite_frames.has_animation(anim):
		spr.play(anim)
		spr.frame = 0


func gauge_at(t: float) -> float:
	if not alive:
		return 0.0
	return clampf(g_base + g_rate * maxf(0.0, t - t_base), 0.0, 1.0)


func hit(dir: float, amp: float) -> void:
	_knock_dir = dir
	_knock_amp = amp
	_knock_t = 0.0
	flash(Color.WHITE, 1.0)
	if alive and _move == Move.NONE and spr.animation != &"attack" and spr.animation != &"cast":
		play_now(&"hit")


func flash(c: Color, amount: float) -> void:
	_flash = amount
	_flash_color = c


func set_hp(v: int) -> void:
	if v < hp:
		chip_wait = 0.35
		hp_chip = maxf(hp_chip, hp_shown)
	elif v > hp:
		heal_glow = 1.0
	hp = clampi(v, 0, max_hp)


func set_ready(r: bool) -> void:
	is_ready = r


func knock_out() -> void:
	alive = false
	is_ready = false
	ko_t = 0.0
	play_now(&"ko")
	flash(Color.WHITE, 1.0)


## Called every frame by the battle controller.
func tick(sim_t: float, vdt: float, speed: float) -> void:
	spr.speed_scale = speed
	if _pending_anim != &"" and sim_t >= _pending_at:
		play_now(_pending_anim)
		_pending_anim = &""
	var p := home
	var hop := 0.0
	match _move:
		Move.LUNGE, Move.HOP:
			if sim_t < _t0 + 0.05:
				p = home - Vector2(facing * 3.0 * clampf((sim_t - _t0) / 0.05, 0.0, 1.0), 0)
			elif sim_t < _t_arrive:
				var u := clampf((sim_t - _t0 - 0.05) / maxf(0.01, _t_arrive - _t0 - 0.05), 0.0, 1.0)
				var e := 1.0 - (1.0 - u) * (1.0 - u)
				p = (home - Vector2(facing * 3.0, 0)).lerp(_dest, e)
				if _move == Move.HOP:
					hop = _hop_h * 4.0 * u * (1.0 - u)
			elif sim_t < _t_leave:
				p = _dest
				if flip_at_dest:
					spr.flip_h = facing > 0
			elif sim_t < _t_end:
				spr.flip_h = facing < 0
				var u2 := clampf((sim_t - _t_leave) / maxf(0.01, _t_end - _t_leave), 0.0, 1.0)
				var e2 := u2 * u2 * (3.0 - 2.0 * u2)
				p = _dest.lerp(home, e2)
				if _move == Move.HOP:
					hop = _hop_h * 0.5 * 4.0 * u2 * (1.0 - u2)
			else:
				_end_move()
		Move.STAY:
			if sim_t >= _t_end:
				_end_move()
	if _walk_t >= 0.0:
		_walk_t += vdt
		var wu := clampf(_walk_t / _walk_dur, 0.0, 1.0)
		p = _walk_from.lerp(_walk_to, wu * wu * (3.0 - 2.0 * wu))
		hop = absf(sin(wu * PI * 3.0)) * 3.0
		_ghosts_on = true
		if wu >= 1.0:
			_walk_t = -1.0
			_ghosts_on = false
	# knockback (visual time)
	if _knock_t < 0.24:
		_knock_t += vdt
		var k := 1.0 - clampf(_knock_t / 0.24, 0.0, 1.0)
		p.x += _knock_dir * _knock_amp * k * k
	# victory hops
	if victory_hop and alive:
		_bob_t += vdt
		hop = maxf(hop, absf(sin(_bob_t * 7.0)) * 6.0)
	position = Vector2(roundf(p.x), roundf(p.y))
	spr.position = _sprite_offset() - Vector2(0, roundf(hop))
	shadow.scale = Vector2.ONE
	# ghosts / afterimages for dashes
	_record_history()
	for i in _ghosts.size():
		var g := _ghosts[i]
		g.visible = (_ghosts_on and (_move != Move.NONE or _walk_t >= 0.0) and alive) or (_echo_t > 0.0 and alive)
		if _echo_t > 0.0 and alive and not (_ghosts_on and (_move != Move.NONE or _walk_t >= 0.0)):
			g.global_position = position + _sprite_offset() + Vector2(-facing * 6.0 * (i + 1), -2.0 * (i + 1))
			g.animation = spr.animation
			g.frame = spr.frame
		elif g.visible:
			var hi := (_hist_i - 1 - (i + 1) * 3 + 120) % 12
			g.global_position = _hist_pos[hi] + _sprite_offset()
			if g.animation != _hist_anim[hi]:
				g.animation = _hist_anim[hi]
			g.frame = _hist_frame[hi]
	if _echo_t > 0.0:
		_echo_t -= vdt
	# flash / tint / ready outline
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - vdt * 7.0)
	mat.set_shader_parameter("flash", 1.0 if _flash > 0.6 else (_flash * 0.9))
	mat.set_shader_parameter("flash_color", _flash_color if _flash <= 0.6 else Color.WHITE)
	if buff_glow > 0.0 and alive:
		buff_glow -= vdt
		var sh := fmod(buff_glow, 0.16) < 0.1
		mat.set_shader_parameter("outline_color", Color(buff_color if sh else Pal.INK10, 1.0))
		if _flash <= 0.0:
			mat.set_shader_parameter("flash", 0.25)
			mat.set_shader_parameter("flash_color", buff_color)
	elif is_ready and alive:
		_glow_t += vdt
		var on := fmod(_glow_t, 0.5) < 0.3
		mat.set_shader_parameter("outline_color", Color(Pal.VIOLET4 if on else Pal.VIOLET3, 1.0))
	elif is_echo and alive:
		mat.set_shader_parameter("outline_color", Color(Pal.CRYSTAL3, 0.55))
	elif lit and alive and focus_rim:
		mat.set_shader_parameter("outline_color", Color(side_color.lerp(Pal.INK10, 0.55), 1.0))   # focus rim light
	elif height > 50 and alive:
		mat.set_shader_parameter("outline_color", Color(Pal.INK7, 0.9))   # rim light: dark giants read against the wall
	else:
		mat.set_shader_parameter("outline_color", Color(0, 0, 0, 0))
	if ko_t >= 0.0:
		ko_t += vdt
		var g2 := clampf((ko_t - 0.35) / 0.5, 0.0, 1.0)
		mat.set_shader_parameter("gray", g2)
		modulate.a = 1.0 - 0.45 * g2
		shadow.visible = ko_t < 0.6
	# focus: units not in the current action recede
	_dim = move_toward(_dim, 1.0 if (dimmed and alive) else 0.0, vdt * 6.0)
	var dv := 1.0 - 0.42 * _dim
	spr.self_modulate = Color(dv, dv, dv + 0.08 * _dim, 1.0)
	# bars
	var hs_target := float(hp)
	hp_shown = move_toward(hp_shown, hs_target, maxf(1.0, absf(hs_target - hp_shown)) * vdt * 14.0)
	if chip_wait > 0.0:
		chip_wait -= vdt
	else:
		hp_chip = move_toward(hp_chip, hp_shown, max_hp * vdt * 0.9)
	if hp_chip < hp_shown:
		hp_chip = hp_shown
	heal_glow = maxf(0.0, heal_glow - vdt * 2.0)
	if charge_hold > 0.0:
		charge_hold -= vdt
		if charge_hold <= 0.0:
			charge_pulse = 0.6
	else:
		charge_shown = move_toward(charge_shown, float(charge), vdt * (60.0 if charge_pulse > 0.0 else 160.0))
	charge_pulse = maxf(0.0, charge_pulse - vdt)
	if not acting:
		z_index = 25 if lit else 0


## Walk to a new home slot (Vault Door's Hold the door).
func step_to(dest: Vector2, t0: float, dur: float) -> void:
	_relocate = true
	plan_move(Move.LUNGE, t0, t0 + dur, t0 + dur, t0 + dur, dest, 0.0, true)


## Echo Step: a staggered afterimage for a moment.
func echo_afterimage(dur: float) -> void:
	_echo_t = dur


var _relocate := false
var _walk_from := Vector2.ZERO
var _walk_to := Vector2.ZERO
var _walk_t := -1.0
var _walk_dur := 1.0


## Walk to a new slot in visual time (works while the battle clock is paused).
func walk_to(dest: Vector2, dur: float) -> void:
	_walk_from = position
	_walk_to = dest
	_walk_dur = dur
	_walk_t = 0.0
	home = dest


func _end_move() -> void:
	if _relocate:
		_relocate = false
		home = _dest
	_move = Move.NONE
	flip_at_dest = false
	spr.flip_h = facing < 0
	_ghosts_on = false
	acting = false
	z_index = 0


func _record_history() -> void:
	_hist_pos[_hist_i] = position
	_hist_frame[_hist_i] = spr.frame
	_hist_anim[_hist_i] = spr.animation
	_hist_i = (_hist_i + 1) % 12


func _on_anim_finished() -> void:
	if not alive:
		return
	if spr.animation != &"idle":
		spr.play(&"idle")


## World position of the chest (for hit sparks and projectiles).
func chest() -> Vector2:
	return position + Vector2(0, -roundf(height * 0.5))


func head() -> Vector2:
	return position + Vector2(0, -height)
