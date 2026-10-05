extends Node2D
## Battle scene: plays back a CombatSim event log in real time (1 sim second = 1 real second at x1),
## driven only by the events: their times, impact times and anim hints. Nothing is re-simulated.
##
## API (from another scene):
##   var battle = preload("res://scenes/battle/battle.tscn").instantiate()
##   battle.autoplay_demo = false
##   add_child(battle)
##   battle.start_fight(party_a, party_b, seed, sim_options, display)   # simulates, then plays
##   # or: battle.play_result(CombatSim.simulate(...), display)
##   battle.finished.connect(func(winner: int, result: Dictionary): ...)
## display (all optional): {"player_side": 0, "echo_side": 1 (draw that side as an Echo), "speed": 1.0}
## Controls: set_speed(x), skip(). No input is needed to watch.
##
## Demo (no API call within the first frame): fixed-seed PvP (hero party vs an Echo party).
## User arg --fight=monsters plays the hero party against Vault monsters instead.

signal finished(winner: int, result: Dictionary)

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Rng = preload("res://core/rng.gd")
const Echo = preload("res://core/echo.gd")
const Layout = preload("res://scenes/battle/battle_layout.gd")
const Unit = preload("res://scenes/battle/battle_unit.gd")
const META_PATH := "res://assets/sprites/sprite_meta.json"

const DEMO_PVP_SEED := 33
const DEMO_MONSTER_SEED := 31
const DEMO_MONSTER_DEPTH := 3
## The demo shortens sudden death (36 s in Tuning) so the escalation shows inside a 40 s capture.
const DEMO_PVP_OPTIONS := {"tuning": {"sudden_death_start_ms": 18000, "sudden_death_hp_pct_per_tick": 0.03, "sudden_death_dmg_mult_per_tick": 0.12}}

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const INTRO_LEN := 2.6
const ABILITY_FREEZE := 0.3
const SHADOWS := {"s": preload("res://assets/sprites/env/shadow_s.png"),
	"m": preload("res://assets/sprites/env/shadow_m.png"), "l": preload("res://assets/sprites/env/shadow_l.png")}
## Sprite used for each class family (advanced classes use their base class).
const SPRITE_FOR := {"fighter": "fighter", "rogue": "rogue", "healer": "healer", "mage": "mage",
	"hollow_rat": "shardback", "stone_sentinel": "warden", "shard_golem": "warden",
	"fading_wisp": "wisp", "memory_wraith": "wisp"}
## Monster recolours (palette swaps) so kinds that share a sprite stay distinct.
const SWAPS := {
	"memory_wraith": [["crystal3", "violet2"], ["crystal4", "violet3"], ["crystal5", "violet4"], ["crystal2", "violet1"]],
	"shard_golem": [["violet2", "crystal2"], ["violet3", "crystal3"], ["violet4", "crystal4"], ["violet1", "crystal1"]],
}
## Effect colours per action [main, highlight].
const FX_COL := {
	"bolt": ["violet3", "violet4"], "flicker": ["crystal3", "crystal5"], "smite": ["amber5", "amber7"],
	"firestorm": ["amber4", "amber6"], "unravel": ["fade3", "crystal5"], "hexfire": ["violet2", "blood4"],
	"shard_burst": ["crystal4", "crystal5"], "meteor": ["amber4", "amber7"], "grave_drain": ["violet2", "violet4"],
	"siphon": ["violet2", "violet4"], "mend": ["life4", "amber7"], "sanctuary": ["life4", "amber7"],
	"aegis_strike": ["amber6", "ink10"], "lantern_oath": ["amber6", "amber7"], "quake": ["fade3", "ink9"],
	"claw": ["blood4", "ink10"], "gnaw": ["blood4", "ink10"], "backstab": ["violet4", "ink10"], "execute": ["blood4", "ink10"],
}

enum State { IDLE, INTRO, PLAY, END }

@export var autoplay_demo := true
## Demo fight when nothing calls the API: "pvp" (hero party vs an Echo) or "monsters". --fight=... overrides.
@export var demo_fight := "pvp"

var units: Array = []                  # BattleUnit by uid
var side_units: Array = [[], []]       # uids per side in slot order
var sides: Array = []                  # fight_start side entries
var side_colors: Array[Color] = [Pal.AMBER5, Pal.CRYSTAL4]
var form_lines: Array = [[], []]
var portraits := {}
var player_side := 0
var echo_side := -1
var result: Dictionary = {}
var events: Array = []
var sim_t := 0.0
var sd_at := 36.0
var sd_mult := 1.0
var end_subtitle := ""
var stage: Node2D
var hud: Control

var _state := State.IDLE
var _ev_i := 0
var _speed_i := 0
var _freeze := 0.0
var _freeze_actor := -1
var _shake := 0.0
var _shake_t := 0.0
var _cam_off := Vector2.ZERO
var _intro_t := 0.0
var _end_t := 0.0
var _emitted := false
var _meta: Dictionary
var _fill := 0.0007
var _cur_action: Dictionary = {}
var _action_first_hit := false
var _stack := {}                      # uid -> [last popup time, stack index]
var _instant := false
var _rng := RandomNumberGenerator.new()
var _dim_a := 0.0
var _started := false
var _vclock := 0.0
var _display := {}
var _started_by_api := false
var _demo_running := false
var _focus_end := -1.0
var _cam_push := Vector2.ZERO
var _num_max_dist := 0.0
var _hits_in_action := 0
var _stale_seen := 0
# frame-time probe (user arg --perf): wall-clock usec per frame, reported at the end of the fight
var _perf := false
var _perf_last := 0
var _perf_buf := PackedInt32Array()
var _perf_n := 0
var _perf_proc := PackedInt32Array()

@onready var cam: Camera2D = $Camera
@onready var units_root: Node2D = $Units
@onready var fx: Node2D = $FX
@onready var plates: Node2D = $Plates
@onready var dim: ColorRect = $Dim
@onready var fade_rect: ColorRect = $FadeLayer/Fade
var fade_level := 0.0
var _fade_target := 0.0


func _ready() -> void:
	_rng.seed = 1234
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	stage = $Stage
	stage.setup()
	fx.setup()
	hud = $HUD/Hud
	hud.setup(self)
	hud.speed_pressed.connect(_cycle_speed)
	hud.skip_pressed.connect(skip)
	_perf = OS.get_cmdline_user_args().has("--perf")
	if _perf:
		_perf_buf.resize(20000)
		_perf_proc.resize(20000)
	if autoplay_demo:
		_start_demo.call_deferred()



func _start_demo() -> void:
	if _started:
		return
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if String(args.get("fight", demo_fight)) == "monsters":
		var mon := PartyGen.monster_group(Rng.new(DEMO_MONSTER_SEED), DEMO_MONSTER_DEPTH)
		_demo_running = true
		start_fight(PartyGen.demo_party(), mon, DEMO_MONSTER_SEED, {}, {})
	else:
		var echo: Dictionary = Echo.from_dict(Echo.make(PartyGen.demo_rival(), {"player": "Ashen Pact"})).get("echo", {})
		_demo_running = true
		start_fight(PartyGen.demo_party(), echo, DEMO_PVP_SEED, DEMO_PVP_OPTIONS, {"echo_side": 1})


## Simulates the fight with the core sim and plays it back.
func start_fight(party_a: Dictionary, party_b: Dictionary, fight_seed: int, sim_options: Dictionary = {}, display: Dictionary = {}) -> void:
	play_result(CombatSim.simulate(fight_seed, party_a, party_b, sim_options), display)


## Plays back an existing CombatSim result (e.g. a stored Echo replay).
func play_result(res: Dictionary, display: Dictionary = {}) -> void:
	_started = true
	_display = display
	result = res
	events = res.get("events", [])
	if events.is_empty() or res.has("error"):
		push_warning("battle: nothing to play (%s)" % str(res.get("error", "no events")))
		return
	player_side = int(display.get("player_side", 0))
	echo_side = int(display.get("echo_side", -1))
	var sp := float(display.get("speed", 1.0))
	_speed_i = maxi(0, SPEEDS.find(sp))
	_clear()
	_ev_i = 0
	sim_t = 0.0
	# fight_start is always first: build the field from it, then play the intro
	_dispatch(events[0])
	_ev_i = 1
	_state = State.INTRO
	_intro_t = 0.0
	hud.intro_t = 0.0
	hud.intro_len = INTRO_LEN
	hud.fade_in = 1.0
	hud.speed_btn.text = "x%d" % int(SPEEDS[_speed_i])


func set_speed(x: float) -> void:
	_speed_i = maxi(0, SPEEDS.find(x))
	hud.speed_btn.text = "x%d" % int(SPEEDS[_speed_i])


func _cycle_speed() -> void:
	_speed_i = (_speed_i + 1) % SPEEDS.size()
	hud.speed_btn.text = "x%d" % int(SPEEDS[_speed_i])


## Jumps to the end: applies every remaining event without effects, then shows the finish.
func skip() -> void:
	if _state != State.INTRO and _state != State.PLAY:
		return
	_instant = true
	_state = State.PLAY
	hud.intro_t = -1.0
	stage.glyph_reveal = 1.0
	while _ev_i < events.size():
		var ev: Dictionary = events[_ev_i]
		sim_t = float(ev.get("t", sim_t))
		_ev_i += 1
		_dispatch(ev)
	_instant = false
	fx.clear_all()
	_freeze = 0.0
	for u in units:
		u.plan_move(Unit.Move.STAY, sim_t, sim_t, sim_t, sim_t, u.home)


func _clear() -> void:
	for u in units:
		u.queue_free()
	units.clear()
	side_units = [[], []]
	portraits.clear()
	_stack.clear()
	fx.clear_all()
	_emitted = false
	hud.end_t = -1.0
	hud.winner = -2
	stage.doom = 0.0
	hud.doom = 0.0
	_fade_target = 0.0
	fade_level = 0.0
	hud.fading_tick = 0


# ---------------------------------------------------------------------------------------- frame
func _process(delta: float) -> void:
	_vclock += delta
	if _perf and _state == State.PLAY:
		_edge_probe()
	if _perf:
		var now := Time.get_ticks_usec()
		if _perf_last > 0 and _perf_n < _perf_buf.size():
			_perf_buf[_perf_n] = now - _perf_last
			_perf_proc[_perf_n] = int(Performance.get_monitor(Performance.TIME_PROCESS) * 1000000.0)
			_perf_n += 1
		_perf_last = now
	if _state == State.IDLE:
		hud.tick(delta)
		return
	var speed: float = SPEEDS[_speed_i]
	var vdt := delta * speed
	var frozen := _freeze > 0.0
	if frozen:
		_freeze -= vdt
	match _state:
		State.INTRO:
			_intro_t += vdt
			hud.intro_t = _intro_t
			stage.glyph_reveal = clampf((_intro_t - 0.4) / 0.9, 0.0, 1.0)
			stage.labels_alpha = 1.0
			if _intro_t >= INTRO_LEN:
				_state = State.PLAY
				hud.intro_t = -1.0
				hud.screen_flash(Pal.INK10, 0.35)
				fx.ring(Vector2(320, 206), 10, 150, 0.5, Pal.CRYSTAL4, 0.25)
		State.PLAY:
			stage.labels_alpha = 0.0
			if not frozen:
				sim_t += vdt
				while _ev_i < events.size() and float(events[_ev_i]["t"]) <= sim_t:
					var ev: Dictionary = events[_ev_i]
					_ev_i += 1
					_dispatch(ev)
					if _state != State.PLAY:
						break
		State.END:
			_end_t += delta
			if _end_t > 3.5 and _emitted and _demo_running:
				_end_t = 0.0
				play_result(result, _display)   # demo: loop the fight
			elif _end_t > 3.0 and not _emitted:
				_emitted = true
				if _perf:
					_report_perf()
				finished.emit(int(result.get("winner", -1)), result)
	# units
	for u in units:
		var us := speed
		if frozen and u.uid != _freeze_actor:
			us = 0.0
		u.tick(sim_t, 0.0 if (frozen and u.uid != _freeze_actor) else vdt, us)
	if _focus_end >= 0.0 and sim_t > _focus_end + 0.05:
		_focus_end = -1.0
		for u in units:
			u.dimmed = false
	# dim for ability moments
	var want_dim := 0.0
	if _cur_action.get("kind", "") == "ability" and sim_t < float(_cur_action.get("t", 0.0)) + float(_cur_action.get("duration", 0.0)):
		want_dim = 0.5
	_dim_a = move_toward(_dim_a, want_dim, vdt * 4.0)
	dim.color = Color(Pal.INK1, _dim_a)
	dim.visible = _dim_a > 0.01
	fade_level = move_toward(fade_level, _fade_target, (vdt * 0.8) if _fade_target > fade_level else (delta * 0.65))
	fade_rect.visible = fade_level > 0.005
	if fade_rect.visible:
		(fade_rect.material as ShaderMaterial).set_shader_parameter("level", fade_level)
	stage.tick(vdt)
	fx.tick(delta * speed, sim_t)
	plates.tick(vdt, sim_t)
	hud.tick(vdt)
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	var target := Vector2.ZERO
	if _cur_action.has("uid") and _state == State.PLAY:
		var a = units[int(_cur_action["uid"])]
		if a.acting:
			target = Vector2(clampf((a.position.x - 320.0) * 0.05, -3, 3), clampf((a.position.y - 200.0) * 0.05, -3, 3))
	_cam_push = _cam_push.move_toward(Vector2.ZERO, delta * 8.0)
	target += _cam_push
	_cam_off = _cam_off.lerp(target, clampf(delta * 4.0, 0.0, 1.0))
	var sh := Vector2.ZERO
	if _shake > 0.0:
		_shake_t += delta
		_shake = maxf(0.0, _shake - delta * 14.0)
		sh = Vector2(roundf(sin(_shake_t * 71.0) * _shake), roundf(cos(_shake_t * 53.0) * _shake * 0.6))
	cam.offset = Vector2(roundf(_cam_off.x), roundf(_cam_off.y)) + sh
	stage.bg_layer.offset = -cam.offset * Layout.ZOOM


var _edge_hits := 0
var _edge_min := 999.0
## Screen-space distance of every unit's opaque sprite pixels (alive or KO) and its HP plate from the edges.
func _edge_probe() -> void:
	var xf := get_viewport().get_canvas_transform()
	for u in units:
		var tex: Texture2D = u.spr.sprite_frames.get_frame_texture(u.spr.animation, u.spr.frame)
		if tex == null:
			continue
		var img: Image = _img_cache.get(tex)
		if img == null:
			img = tex.get_image()
			_img_cache[tex] = img
		var used := img.get_used_rect()
		var x0: float = u.spr.global_position.x + (img.get_width() - used.end.x if u.spr.flip_h else used.position.x)
		var x1: float = x0 + used.size.x
		x0 = minf(x0, u.position.x - 12.0)
		x1 = maxf(x1, u.position.x + 14.0)
		var s0 := (xf * Vector2(x0, 0)).x
		var s1 := (xf * Vector2(x1, 0)).x
		var m := minf(s0, 640.0 - s1)
		_edge_min = minf(_edge_min, m)
		if m < 8.0:
			_edge_hits += 1
			if _edge_hits % 25 == 1:
				print("EDGEHIT ", u.label, " s0=", s0, " s1=", s1, " anim=", u.spr.animation, " alive=", u.alive)
var _img_cache := {}


func _report_perf() -> void:
	print("EDGE unit_frames_within_8px=%d  min_edge_gap_screen_px=%.0f" % [_edge_hits, _edge_min])
	var a := _perf_buf.slice(30, _perf_n)
	var p := _perf_proc.slice(30, _perf_n)
	a.sort()
	p.sort()
	var tot := 0
	for v in a:
		tot += v
	print("CHECK popups_alive_at_next_action(before clear)=%d  max_number_centre_to_head_screen_px=%.1f  alive_after_clear=%d" % [_stale_seen, _num_max_dist, fx.live_popups()])
	print("PERF frames=%d wall_avg=%.2fms wall_p99=%.2fms wall_max=%.2fms process_avg=%.3fms process_p99=%.3fms nodes=%d" % [
		a.size(), tot / 1000.0 / maxi(1, a.size()), a[int(a.size() * 0.99)] / 1000.0, a[a.size() - 1] / 1000.0,
		float(p[int(p.size() * 0.5)]) / 1000.0, float(p[int(p.size() * 0.99)]) / 1000.0, get_tree().get_node_count()])
	get_tree().quit()


func shake(amount: float) -> void:
	if _instant:
		return
	_shake = maxf(_shake, amount)


func hitstop(t: float, actor := -1) -> void:
	if _instant:
		return
	if t > _freeze:
		_freeze = t
		_freeze_actor = actor


# ------------------------------------------------------------------------------------- dispatch
func _dispatch(ev: Dictionary) -> void:
	match String(ev.get("type", "")):
		"fight_start": _on_fight_start(ev)
		"formation": pass   # same data as fight_start; shown by the intro cards
		"action_start": _on_action_start(ev)
		"ability": _on_ability(ev)
		"damage": _on_damage(ev)
		"heal": _on_heal(ev)
		"charge": _on_charge(ev)
		"ko": _on_ko(ev)
		"sudden_death": _on_sudden_death(ev)
		"fight_end": _on_fight_end(ev)
		"formation_proc": _on_formation_proc(ev)
		_: _on_other(ev)    # unknown / future event types are ignored safely


func _on_other(ev: Dictionary) -> void:
	# Formation procs for effects that don't show on hits (future core event): pulse that side's badge.
	var ty := String(ev.get("type", ""))
	if ty.begins_with("formation") and ev.has("side") and not _instant:
		var s := int(ev["side"])
		if s >= 0 and s < 2:
			hud.pulse_badge(s, -1)
			stage.glyph_pulse[s] = 1.0


## A formation/composition effect applying right now (core event): cue on the unit, highlight the
## matching buff/debuff line on that side's badge and pulse the floor glyph.
func _on_formation_proc(ev: Dictionary) -> void:
	var s := int(ev.get("side", -1))
	if s < 0 or s > 1 or _instant:
		return
	var good := String(ev.get("sign", "buff")) == "buff"
	var src := String(ev.get("source", ""))
	var line := -1
	var lines: Array = form_lines[s]
	for i in lines.size():
		var ln: Array = lines[i]
		if src.begins_with("comp:"):
			if ln.size() > 2:
				line = i
		elif ln.size() <= 2 and bool(ln[0]) == good:
			line = i
	hud.pulse_badge(s, line)
	stage.glyph_pulse[s] = 1.0
	var uid := int(ev.get("uid", -1))
	if uid < 0 or uid >= units.size():
		return
	var u = units[uid]
	var stat := String(ev.get("stat", ""))
	var v := float(ev.get("value", 0.0))
	var txt := "%s %s %+d%%" % [String(ev.get("name", "")).to_upper(), hud.STAT_NAMES.get(stat, stat.to_upper()), roundi(v * 100.0)]
	var col: Color = (side_colors[s] if good else Pal.BLOOD4).lerp(Pal.INK10, 0.2)
	if String(_cur_action.get("kind", "")) != "ability":
		pass
	stage.slot_pulse[Vector3i(s, u.col, u.row)] = 1.6
	u.buff_glow = 0.7
	u.buff_color = col
	for cell: Vector2i in stage.alive_cells[s]:
		var k := Vector3i(s, cell.x, cell.y)
		stage.slot_pulse[k] = maxf(float(stage.slot_pulse.get(k, 0.0)), 0.35)
	fx.ring(u.position, 6, 26, 0.5, col, 0.4)
	fx.light(u.position, col, 1, 0.45, 0.6)


func _on_fight_start(ev: Dictionary) -> void:
	sides = ev.get("sides", [])
	sd_at = float(ev.get("sudden_death_at", 36.0))
	_fill = float(ev.get("gauge_fill_per_spd", 0.0007))
	var monsters := [false, false]
	for s: Dictionary in sides:
		var allm := true
		for u: Dictionary in s.get("units", []):
			if String(u.get("tier", "")) != "monster":
				allm = false
		monsters[int(s["side"])] = allm
	for k in 2:
		side_colors[k] = Pal.AMBER5 if k == player_side else (Pal.BLOOD4 if monsters[k] else Pal.CRYSTAL4)
	stage.side_colors = side_colors
	stage.occupied = [{}, {}]
	stage.alive_cells = [{}, {}]
	var all_units: Array = []
	for s: Dictionary in sides:
		for u: Dictionary in s.get("units", []):
			all_units.append(u)
	all_units.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return int(a["uid"]) < int(c["uid"]))
	units.resize(all_units.size())
	for u: Dictionary in all_units:
		var node := _make_unit(u)
		units[node.uid] = node
		side_units[node.side].append(node.uid)
		stage.occupied[node.side][Vector2i(node.col, node.row)] = true
		stage.alive_cells[node.side][Vector2i(node.col, node.row)] = true
	plates.units = units
	# same-column neighbours of a large monster step outward so it never hides them
	for big in units:
		if big.height <= 50:
			continue
		for n in units:
			if n != big and n.side == big.side and n.col == big.col and absi(n.row - big.row) == 1:
				n.home.x -= 28.0 * n.facing
				n.position = n.home
	for s: Dictionary in sides:
		var k := int(s["side"])
		var lines: Array = hud._mods_lines(s.get("formation", {}))
		for c: Dictionary in s.get("compositions", []):
			lines.append([true, String(c.get("name", "")), "comp"])
		form_lines[k] = lines
	hud.row_flash.resize(maxi(16, units.size()))


func _make_unit(u: Dictionary) -> Node2D:
	var cls := String(u.get("class", ""))
	var base := String(u.get("base_class", cls))
	var key: String = SPRITE_FOR.get(cls, SPRITE_FOR.get(base, "fighter"))
	if not _meta.has(key):
		key = "fighter"
	var m: Dictionary = _meta[key]
	var sh := "s"
	if int(m["size"][0]) > 64:
		sh = "l"
	elif key == "shardback" or base == "fighter":
		sh = "m"
	var swaps := []
	for pair: Array in SWAPS.get(cls, []):
		swaps.append([Pal.c(pair[0]), Pal.c(pair[1])])
	var node := Unit.new()
	units_root.add_child(node)
	node.setup(u, m, SHADOWS[sh], int(u["side"]) == echo_side, side_colors[int(u["side"])], swaps)
	node.g_rate = float(u.get("spd", 10)) * _fill
	node.g_base = float(u.get("gauge", 0.0))
	node.t_base = 0.0
	portraits[node.uid] = _portrait(key, base, String(u.get("tier", "")) == "monster", m)
	return node


## Panel portrait: a 16x15 crop around the head of the unit's own idle sprite (found from its pixels,
## so it follows sprite redraws). Cached per sprite.
var _portrait_cache := {}
func _portrait(key: String, _base: String, _monster: bool, m: Dictionary) -> Texture2D:
	if _portrait_cache.has(key):
		return _portrait_cache[key]
	var frames: SpriteFrames = load(String(m["path"]))
	var ft := frames.get_frame_texture(&"idle", 0)
	var at := AtlasTexture.new()
	if ft is AtlasTexture:
		var src: AtlasTexture = ft
		at.atlas = src.atlas
		var img := src.atlas.get_image()
		var reg := Rect2i(src.region)
		var top := -1
		var x_sum := 0.0
		var x_n := 0
		var right := reg.position.x
		for y in range(reg.position.y, reg.end.y):
			for x in range(reg.position.x, reg.end.x):
				if img.get_pixel(x, y).a > 0.5:
					if top < 0:
						top = y
					right = maxi(right, x)
					if top >= 0 and y < top + 10:
						x_sum += x
						x_n += 1
		var cx := x_sum / maxf(1.0, x_n)
		var cy := float(top + 1)
		var offs := {"warden": Vector2(0, 8), "shardback": Vector2(0, 0)}
		if key == "shardback":
			cx = right - 9
			cy = top + 8
		cy += (offs.get(key, Vector2.ZERO) as Vector2).y
		at.region = Rect2(roundf(cx - 8), roundf(cy), 16, 13)
	else:
		at.atlas = ft
		at.region = Rect2(Vector2.ZERO, Vector2(16, 15))
	_portrait_cache[key] = at
	return at


# --- actions ----------------------------------------------------------------------------------
func _on_action_start(ev: Dictionary) -> void:
	_cur_action = ev
	_hits_in_action = 0
	_stale_seen += fx.live_popups()
	fx.fade_popups()
	_action_first_hit = false
	var t0 := float(ev["t"])
	var dur := float(ev.get("duration", 0.5))
	var imp := float(ev.get("impact", t0 + dur * 0.5))
	var t_end := t0 + dur
	# ATB: gauges snapshot, frozen during the action, then rising again
	var g: Array = ev.get("gauges", [])
	for i in mini(g.size(), units.size()):
		units[i].g_base = float(g[i])
		units[i].t_base = t_end
	var a = units[int(ev["uid"])]
	a.g_base = 0.0
	_focus_end = t_end
	var area := String(ev.get("area", "single"))
	var tside := int(ev.get("target_side", -1))
	for u in units:
		var involved: bool = u == a or u.uid == int(ev.get("target", -1)) or (area != "single" and u.side == tside)
		u.dimmed = not involved
	if _instant:
		return
	var anim := String(ev.get("anim", "melee"))
	var tid := int(ev.get("target", -1))
	var tgt = units[tid] if tid >= 0 and tid < units.size() else null
	var is_ab := String(ev.get("kind", "basic")) == "ability"
	var aid := String(ev.get("action", ""))
	var cols := _fx_cols(aid)
	hud.show_caption(a.uid, String(ev.get("name", aid)), tid if String(ev.get("area", "single")) != "all_allies" else -1, is_ab)
	match anim:
		"melee", "melee_big", "dash", "slam", "slam_big":
			if tgt != null:
				var reach := 48.0 if a.height > 50 or tgt.height > 50 else 30.0
				var dest := Layout.strike_pos(tgt.home, a.side, reach)
				if anim == "dash":
					dest = Layout.strike_pos(tgt.home, 1 - a.side, reach)   # blink in behind the target
					a.flip_at_dest = true
				var arrive := maxf(t0 + 0.09, imp - 0.025)
				var leave := imp + 0.28                       # linger at the target, return overlaps the gap
				fx.trail(a.chest(), tgt.chest(), a.side_color)
				var hop := anim.begins_with("slam")
				a.plan_move(Unit.Move.HOP if hop else Unit.Move.LUNGE, t0, arrive, leave, leave + 0.2, dest,
					22.0 if anim == "slam_big" else 14.0, anim != "melee")
			else:
				a.plan_move(Unit.Move.STAY, t0, t0, t0, t_end, a.home)
			a.schedule_anim(&"attack", maxf(t0, imp - a.impact_offset("attack")))
		"shoot":
			a.plan_move(Unit.Move.STAY, t0, t0, t0, t_end, a.home)
			if tgt != null:
				var from: Vector2 = a.chest() + Vector2(a.facing * 12, -2)
				var to: Vector2 = tgt.chest()
				var travel := clampf(from.distance_to(to) / 520.0, 0.12, 0.24)
				var launch := maxf(t0 + 0.05, imp - travel)
				fx.projectile(from, to, launch, imp, cols[0], cols[1], 0, 10.0)
				a.schedule_anim(&"attack", maxf(t0, launch - a.impact_offset("attack")))
			else:
				a.schedule_anim(&"attack", t0)
		_:  # cast, cast_big, heal, heal_big
			a.plan_move(Unit.Move.STAY, t0, t0, t0, t_end, a.home)
			var anim_name := &"cast" if a.has_anim("cast") else &"attack"
			a.schedule_anim(anim_name, maxf(t0, imp - a.impact_offset(String(anim_name))))
			fx.ring(a.position, 6, 18, 0.5, cols[0], 0.3)
			fx.light(a.chest(), cols[0], 1, 0.45, maxf(0.3, imp - t0 + 0.2))
			if tgt != null and tgt != a and anim.begins_with("heal"):
				fx.trail(a.chest(), tgt.chest(), Pal.LIFE4)
			if tgt != null and String(ev.get("area", "single")) == "single" and not anim.begins_with("heal"):
				var from2: Vector2 = a.chest() + Vector2(a.facing * 10, -6)
				var kind := 1 if aid == "meteor" else 0
				fx.projectile(from2, tgt.chest(), maxf(t0 + 0.08, imp - 0.2), imp, cols[0], cols[1], kind, 24.0)
	if is_ab:
		fx.particles(a.chest(), 14, cols[1], 30.0, 10.0, 0.5, -20.0, 1, 3.0)
		fx.light(a.position + Vector2(0, -10), cols[0], 2, 0.4, dur + 0.4)


func _on_ability(ev: Dictionary) -> void:
	if _instant:
		return
	var a = units[int(ev["uid"])]
	var cols := _fx_cols(String(ev.get("action", "")))
	hud.show_cutin(a.uid, String(ev.get("name", "")), ABILITY_FREEZE + 0.5)
	hitstop(ABILITY_FREEZE, a.uid)
	a.flash(a.side_color, 1.0)
	a.set_ready(false)
	fx.ring(a.position, 4, 34, 0.55, Pal.VIOLET4, 0.32)
	fx.ring(a.position, 2, 22, 0.45, cols[1], 0.32)
	fx.light(a.chest(), Pal.VIOLET3, 2, 0.6, ABILITY_FREEZE + 0.3)
	fx.particles(a.chest(), 22, Pal.VIOLET4, 70.0, 20.0, 0.6, 40.0, 1, 2.0)
	shake(1.5)


## Ability-specific shape on the board at the first impact.
func _ability_shape(aid: String, T, cols: Array) -> void:
	match aid:
		"cleave", "aegis_strike", "lantern_oath", "rampage", "riposte":
			# a blade sweep through the target's column, crossing the rows above and below it
			var c0: Vector2 = T.chest()
			var d := Vector2(Layout.SKEW, 22.0)
			fx.sweep(c0 - d * 1.2, c0 + d * 1.2, cols[0])
			for k in 3:
				fx.sprite_fx(&"slash", c0 + d * (k - 1), T.facing > 0, Color.WHITE, 1.0)
		"mend", "sanctuary":
			fx.pillar(T.position.x, T.position.y, 14.0, 0.7, Pal.LIFE4)
			fx.ring(T.position, 4, 26, 0.6, Pal.LIFE4, 0.35)
		"quake":
			for k in 4:
				fx.ring(T.position + Vector2(-T.facing * k * 6, 0), 8 + k * 10, 50 + k * 16, 0.55 + k * 0.08, Pal.INK10 if k % 2 == 0 else Pal.AMBER6, 0.3)
			fx.particles(T.position, 30, Pal.FADE3, 80.0, 40.0, 0.7, 160.0, 2, 10.0)
			shake(5.0)
		"backstab", "execute":
			fx.ring(T.chest(), 2, 20, 0.3, Pal.VIOLET4, 1.0)
			fx.particles(T.chest(), 16, Pal.VIOLET4, 60.0, 10.0, 0.4, 0.0, 1, 2.0)


func _fx_cols(aid: String) -> Array:
	var c: Array = FX_COL.get(aid, ["amber6", "ink10"])
	return [Pal.c(c[0]), Pal.c(c[1])]


# --- effects ------------------------------------------------------------------------------------
func _on_damage(ev: Dictionary) -> void:
	var dst := int(ev.get("dst", -1))
	if dst < 0 or dst >= units.size():
		return
	var T = units[dst]
	T.set_hp(int(ev.get("hp", T.hp)))
	if _instant:
		return
	var src := int(ev.get("src", -1))
	var S = units[src] if src >= 0 and src < units.size() else null
	var kind := String(ev.get("kind", "physical"))
	var crit := bool(ev.get("crit", false))
	var amount := int(ev.get("amount", 0))
	var aid := String(ev.get("action", ""))
	var cols := _fx_cols(aid)
	var is_ab := String(_cur_action.get("kind", "")) == "ability" and int(_cur_action.get("uid", -1)) == src
	var anim := String(_cur_action.get("anim", "melee"))
	var dir := -float(T.facing)
	var amp := 3.0 + (2.0 if crit or is_ab else 0.0)
	var delay := _stagger(dst) + 0.08 * _hits_in_action
	if kind != "sudden_death":
		T.hit(dir, amp)
		hud.row_flash[dst] = 1.0
	var c: Vector2 = T.chest()
	c.x -= 4.0 * float(T.facing)   # on the far side of the target, away from the attacker
	# impact art
	if kind == "sudden_death":
		fx.particles(c, 8, Pal.BLOOD3, 30.0, 10.0, 0.5, 60.0, 1, 2.0)
		T.flash(Pal.BLOOD3, 0.9)
	elif kind == "physical":
		var flip: bool = S != null and S.facing < 0
		if is_ab:
			fx.sprite_fx(&"slash", c + Vector2(-T.facing * 6, 0), flip, Color.WHITE, 1.0)
		fx.sprite_fx(&"hit_spark", c, false, Color.WHITE, 1.0)
		fx.particles(c, 6 + (6 if crit else 0), Pal.AMBER6, 70.0, 10.0, 0.35, 120.0, 1, 1.0)
		if anim.begins_with("slam"):
			fx.ring(T.position, 4, 30, 0.4, Pal.INK9, 0.3)
			shake(2.5)
	else:
		if aid == "smite":
			fx.pillar(c.x, T.position.y, 7.0, 0.35, cols[0])
		if anim == "cast_big" and String(_cur_action.get("area", "single")) == "all_enemies":
			fx.pillar(c.x, T.position.y, 10.0, 0.45, cols[0])
			fx.ring(T.position, 4, 22, 0.45, cols[1], 0.3)
		fx.ring(c, 2, 11, 0.3, cols[1].lerp(Color.WHITE, 0.4), 1.0)
		fx.particles(c, 8 + (6 if crit else 0), cols[1], 55.0, 15.0, 0.45, 40.0, 1, 2.0)
	if is_ab and not _action_first_hit:
		_action_first_hit = true
		hud.screen_flash(cols[0], 0.18)
		shake(3.0)
		hitstop(0.3)
		_cam_push = (T.position - Vector2(320, 180)).normalized() * 3.0
		_ability_shape(aid, T, cols)
		if String(_cur_action.get("area", "single")) == "all_enemies":
			var cx := 320.0 + (60.0 if T.side == 1 else -60.0)
			fx.ring(Vector2(cx, 180), 6, 90, 0.55, cols[0], 0.45)
			fx.ring(Vector2(cx, 180), 4, 60, 0.45, cols[1], 0.45)
			fx.light(Vector2(cx, 175), cols[0], 3, 0.55, 0.6)
			for k in 3:
				fx.particles(Vector2(cx + randf_range(-40, 40), 180 + randf_range(-30, 30)), 14, cols[1], 90.0, 30.0, 0.6, 60.0, 1, 6.0)
	if kind == "magic":
		fx.light(c, cols[0], 1, 0.5, 0.45)
	elif kind == "physical":
		fx.light(c, Pal.AMBER5, 1, 0.35 if not crit else 0.6, 0.3)
	if crit:
		fx.ring(c, 3, 16, 0.3, Pal.AMBER6, 1.0)
		hitstop(0.07)
		shake(3.0)
	# number + one primary annotation
	var row: int = fx.Row.PHYS
	if kind == "magic":
		row = fx.Row.MAGIC
	elif kind == "sudden_death":
		row = fx.Row.DEATH
	if crit:
		row = fx.Row.CRIT
	var note := _annotation(ev)
	var head := "CRIT!" if crit else String(note[0])
	_hits_in_action += 1
	if not crit and _hits_in_action > 1:
		head = ""   # one tag per action: on the first number only
	var head_col: Color = Pal.AMBER6 if crit else note[1]
	fx.popup(amount, row, _num_pos(T, dst), 1, false, head, head_col, "", Color.WHITE, delay)


## Picks the one annotation shown under a damage number. Priority: execute > formation > back row
## > sudden-death escalation. Formation procs also pulse that side's badge and floor glyph.
func _annotation(ev: Dictionary) -> Array:
	var prim: Variant = ev.get("primary", null)
	if prim is Dictionary:
		for m in ev.get("mods", []):
			if m is Dictionary and String(m.get("id", "")) == "formation":
				var fs0 := int(m.get("side", 0))
				hud.pulse_badge(fs0, _formation_line(fs0, m))
				stage.glyph_pulse[clampi(fs0, 0, 1)] = 1.0
				_formation_glint(ev, m)
		return _primary_note(prim)
	var execute := false
	var form: Dictionary = {}
	var back_t := false
	var back_a := false
	var sdm := 1.0
	for m in ev.get("mods", []):
		if m is String:
			if m == "sudden_death":
				pass
			continue
		if not (m is Dictionary):
			continue
		match String(m.get("id", "")):
			"execute": execute = true
			"formation": form = m
			"back_row_target": back_t = true
			"back_row_attacker": back_a = true
			"sudden_death": sdm = float(m.get("mult", 1.0))
	if not form.is_empty():
		var fs := int(form.get("side", 0))
		var line := _formation_line(fs, form)
		hud.pulse_badge(fs, line)
		stage.glyph_pulse[fs] = 1.0
	if execute:
		return ["EXECUTE x2", Pal.BLOOD4]
	if not form.is_empty():
		var pct := roundi((float(form.get("mult", 1.0)) - 1.0) * 100.0)
		var fs2 := int(form.get("side", 0))
		var nm := String(form.get("name", "Formation")).to_upper()
		return ["%s %+d%%" % [nm, pct], side_colors[clampi(fs2, 0, 1)].lerp(Pal.INK10, 0.25)]
	if back_t and back_a:
		return ["Rear 1/4", Pal.INK9]
	if back_t:
		return ["Rear 1/2", Pal.INK9]
	if back_a:
		return ["Rear 1/2", Pal.INK9]
	if sdm > 1.0:
		return ["fading x%.2f" % sdm, Pal.FADE4]
	return ["", Color.WHITE]


func _primary_note(p: Dictionary) -> Array:
	var mult := float(p.get("mult", 1.0))
	match String(p.get("id", "")):
		"crit": return ["", Color.WHITE]          # the CRIT! head word already says it
		"execute": return ["EXECUTE x%.1f" % mult, Pal.BLOOD4]
		"pierce": return ["pierce", Pal.VIOLET4]
		"back_row": return ["Rear 1/4" if mult < 0.3 else "Rear 1/2", Pal.INK9]
		"back_row_both": return ["Rear 1/4", Pal.INK9]
		"back_row_target": return ["Rear 1/2", Pal.INK9]
		"back_row_attacker": return ["Rear 1/2", Pal.INK9]
		"formation":
			var fs := clampi(int(p.get("side", 0)), 0, 1)
			var nm := String(p.get("name", "Formation")).to_upper()
			return ["%s %+d%%" % [nm, roundi((mult - 1.0) * 100.0)], side_colors[fs].lerp(Pal.INK10, 0.25)]
		"sudden_death":
			return ["fading x%.2f" % mult, Pal.FADE4] if mult > 1.0 else ["", Color.WHITE]
	return ["", Color.WHITE]


## A formation modifier shaped this hit: glint on the unit it belongs to (shield = defence, blade = attack).
func _formation_glint(ev: Dictionary, m: Dictionary) -> void:
	if _instant:
		return
	var fs := clampi(int(m.get("side", 0)), 0, 1)
	var uid := int(ev.get("dst", -1))
	var src := int(ev.get("src", -1))
	if src >= 0 and src < units.size() and units[src].side == fs:
		uid = src
	if uid < 0 or uid >= units.size():
		return
	var u = units[uid]
	var col: Color = side_colors[fs].lerp(Pal.INK10, 0.3)
	u.buff_glow = 0.6
	u.buff_color = col
	stage.slot_pulse[Vector3i(u.side, u.col, u.row)] = 1.4
	var defend: bool = uid == int(ev.get("dst", -1))
	if defend:
		fx.ring(u.chest(), 10, 16, 0.45, col, 1.25)      # shield glint
	else:
		fx.sweep(u.chest() + Vector2(-8, 10), u.chest() + Vector2(8, -14), col)   # blade glint


## Index of the formation line (buff/debuff) most likely responsible, for highlighting on the badge.
func _formation_line(side: int, form: Dictionary) -> int:
	var src := String(form.get("source", ""))
	if src.begins_with("comp:"):
		var lines: Array = form_lines[side]
		for i in lines.size():
			if (lines[i] as Array).size() > 2:
				return i
		return -1
	var mult := float(form.get("mult", 1.0))
	var fs: Dictionary = sides[side].get("formation", {})
	var nb: int = (fs.get("buffs", []) as Array).size()
	var stat_hint := "atk_pct" if mult > 1.0 else "def_pct"
	# a buff of the side's own formation that matches the direction of the effect
	var lines2: Array = form_lines[side]
	for i in lines2.size():
		var ln: Array = lines2[i]
		if ln.size() > 2:
			continue
		var good: bool = ln[0]
		if (mult > 1.0) == good or (mult < 1.0) == good:
			return i
	return 0 if nb > 0 else -1


## Number anchor: just above the target's head; a second/third hit on the same target in one
## action sits beside the first. Tall units near the top band get it beside the head instead.
func _num_pos(T, uid: int) -> Vector2:
	var k := int((_stack.get(uid, [0.0, 0]) as Array)[1])
	var p: Vector2 = T.head() + Vector2([0.0, 16.0, -16.0][k], 10.0)
	if p.y < 140.0:
		p = Vector2(T.head().x - 12.0 * T.facing, 140.0)   # tall unit: on its face, below the top band
	# measured in SCREEN pixels through the live canvas transform (camera zoom + offset):
	# centre of the drawn number vs the target's on-screen head top
	var drawn := Vector2(clampf(p.x, 186.0, 454.0), maxf(p.y, 140.0)) + Vector2(0, -8.0)
	var xf := get_viewport().get_canvas_transform()
	_num_max_dist = maxf(_num_max_dist, (xf * drawn).distance_to(xf * T.head()))
	return p


func _stagger(uid: int) -> float:
	var now := _vclock
	var st: Array = _stack.get(uid, [-10.0, 0])
	if now - float(st[0]) < 0.45:
		st[1] = (int(st[1]) + 1) % 3
	else:
		st[1] = 0
	st[0] = now
	_stack[uid] = st
	return 0.06 * int(st[1])


func _on_heal(ev: Dictionary) -> void:
	var dst := int(ev.get("dst", -1))
	if dst < 0 or dst >= units.size():
		return
	var T = units[dst]
	T.set_hp(int(ev.get("hp", T.hp)))
	if _instant:
		return
	var src := int(ev.get("src", -1))
	var drain := src == dst
	fx.sprite_fx(&"heal_glow", T.position + Vector2(0, -20), false, Color.WHITE, 1.0)
	fx.light(T.chest(), Pal.LIFE4, 1, 0.5, 0.6)
	fx.particles(T.chest(), 10, Pal.LIFE4, 18.0, 30.0, 0.8, -10.0, 1, 4.0)
	if not drain:
		fx.pillar(T.position.x, T.position.y, 6.0, 0.4, Pal.LIFE4)
	T.flash(Pal.LIFE4, 0.6)
	var delay := _stagger(dst)
	var pos: Vector2 = _num_pos(T, dst)
	fx.popup(int(ev.get("amount", 0)), fx.Row.HEAL, pos, 1, true, "DRAIN" if drain else "", Pal.VIOLET4, "", Color.WHITE, delay)


func _on_charge(ev: Dictionary) -> void:
	var uid := int(ev.get("uid", -1))
	if uid < 0 or uid >= units.size():
		return
	var u = units[uid]
	u.charge = int(ev.get("charge", u.charge))
	var r := bool(ev.get("ready", false))
	if r and not u.is_ready and u.alive:
		u.g_base = 1.0
		u.t_base = float(ev["t"])
		u.set_ready(true)
		if not _instant:
			fx.particles(u.chest(), 6, Pal.VIOLET4, 30.0, 20.0, 0.5, -10.0, 1, 3.0)
	elif not r:
		u.set_ready(false)


func _on_ko(ev: Dictionary) -> void:
	var uid := int(ev.get("uid", -1))
	if uid < 0 or uid >= units.size():
		return
	var u = units[uid]
	u.knock_out()
	stage.alive_cells[u.side].erase(Vector2i(u.col, u.row))
	if _instant:
		return
	hitstop(0.12)
	shake(3.5)
	fx.particles(u.chest(), 26, Pal.INK10, 80.0, 20.0, 0.7, 80.0, 1, 3.0)
	fx.particles(u.chest(), 16, u.side_color, 50.0, 30.0, 0.9, 20.0, 2, 3.0)
	fx.ring(u.chest(), 3, 18, 0.4, Pal.INK10, 1.0)
	fx.light(u.chest(), Pal.INK10, 2, 0.5, 0.5)
	fx.word("KO!", u.chest() + Vector2(0, 6), Pal.BLOOD4, 0.3)


func _on_sudden_death(ev: Dictionary) -> void:
	var tick := int(ev.get("tick", 1))
	fx.fade_popups()
	sd_mult = float(ev.get("damage_mult", 1.0))
	var t0 := float(ev["t"])
	var dur := float(ev.get("duration", 0.7))
	for u in units:
		u.g_base = u.gauge_at(t0)
		u.t_base = t0 + dur
	_cur_action = {}
	_fade_target = minf(1.0, 0.3 + tick * 0.12)
	hud.fading_tick = tick
	if _instant:
		fade_level = _fade_target
		return
	if tick == 1:
		hud.sd_banner_t = 0.0
		hitstop(0.35)
	shake(1.5 + tick * 0.5)
	for u in units:
		if u.alive:
			fx.particles(u.chest(), 12, Pal.FADE3, 14.0, 28.0, 1.3, -22.0, 1, 6.0)
			fx.particles(u.chest(), 6, Pal.FADE4, 10.0, 20.0, 1.0, -18.0, 2, 5.0)


func _on_fight_end(ev: Dictionary) -> void:
	fx.clear_all()
	_state = State.END
	_end_t = 0.0
	var w := int(ev.get("winner", -1))
	hud.winner = w
	hud.end_t = 0.0
	if w == player_side:
		hud.winner_text = "VICTORY"
	elif w == -1:
		hud.winner_text = "DRAW"
	else:
		hud.winner_text = "DEFEAT"
	var wname := String(sides[w]["name"]) if w >= 0 else "Neither side"
	var reason := String(ev.get("reason", "wipe"))
	end_subtitle = "%s wins  -  %.1f s%s" % [wname, float(ev.get("t", sim_t)), "  -  sudden death" if reason == "sudden_death" else ""]
	if w >= 0:
		for u in units:
			if u.side == w and u.alive:
				u.victory_hop = true
				fx.light(u.position + Vector2(0, -12), u.side_color, 2, 0.55, 3.0)
				fx.pillar(u.position.x, u.position.y, 8.0, 0.8, u.side_color)
				fx.particles(u.chest(), 24, Pal.AMBER6, 40.0, 50.0, 1.4, -15.0, 1, 5.0)
		stage.victory_light = 1.0
	_cur_action = {}
	hud.screen_flash(Pal.INK10 if w == player_side else Pal.BLOOD2, 0.4)
	_fade_target = 0.0 if w == player_side else _fade_target
