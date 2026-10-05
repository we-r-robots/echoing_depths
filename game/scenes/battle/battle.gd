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
const Demo = preload("res://scenes/battle/battle_demo.gd")
const Unit = preload("res://scenes/battle/battle_unit.gd")
const META_PATH := "res://assets/sprites/sprite_meta.json"

const DEMO_PVP_SEED := 34
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
	"fading_wisp": "wisp", "memory_wraith": "wisp",
	# Crystal memories: placeholder sprites (tinted memory-violet and translucent in battle_unit)
	"ferryman": "fighter", "lamplighters_child": "healer", "miller": "fighter", "weaver": "mage",
	"lumari_knight": "fighter", "the_draw": "wisp", "the_sealing": "wisp", "the_keeper": "healer"}
const CRYSTAL_TEX = preload("res://assets/battle/crystal.png")
const DEMO_CRYSTAL := {
	"ch1": [26, ["ferryman", "lamplighters_child", "miller", "weaver"]],
	"late": [1, ["lumari_knight", "the_draw", "the_sealing", "the_keeper"]],
}
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
## EXPERIMENT (awaiting user approval): ability-turn spectacle. 0 = current look, 1 = subtle, 2 = full.
## Affects ability turns only: focus dim, camera push, VFX size, hit-stop and shake.
## Override from the command line with user arg --spectacle=N.
## Crystal demo sequence: "ch1" (chapter-1 memories) or "late" (chapters 2-4).
@export var demo_sequence := "ch1"
@export_range(0, 2) var spectacle_level := 2

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
var crystal_uid := -1
var fragments := 0
var _seek_to := -1.0
var _tip_demo := -1
var _pending_moves: Array = []
var _move_lit_until := -1.0
var _ko_settle := 0.0
var _cam_push := Vector2.ZERO
var _num_max_dist := 0.0
var _hits_in_action := 0
var _split_tags := 0
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
	if args.has("spectacle"):
		spectacle_level = clampi(int(args["spectacle"]), 0, 2)
	if args.has("tip"):
		_tip_demo = int(args["tip"])
	if args.has("from"):
		_seek_to = float(args["from"])
	if args.has("shape"):
		var sid := String(args["shape"])
		var d: Array = Demo.SHAPE_DEMOS.get(sid, [1, "pvp", 0])
		var fs := int(d[0])
		var mine := Demo.shape_party(sid, int(d[2]))
		_demo_running = true
		if String(d[1]) == "monsters":
			start_fight(mine, PartyGen.monster_group(Rng.new(fs), 3), fs, {}, {})
		else:
			var rival: Dictionary = Echo.from_dict(Echo.make(PartyGen.demo_rival(), {"player": "Ashen Pact"})).get("echo", {})
			start_fight(mine, rival, fs, {}, {"echo_side": 1})
		return
	if String(args.get("fight", demo_fight)) == "crystal":
		var cd: Array = DEMO_CRYSTAL.get(String(args.get("sequence", demo_sequence)), DEMO_CRYSTAL["ch1"])
		_demo_running = true
		play_result(CombatSim.simulate_crystal(int(cd[0]), Demo.demo_party_unlocked(), {"memories": cd[1]}), {})
		return
	if String(args.get("fight", demo_fight)) == "monsters":
		var mon := PartyGen.monster_group(Rng.new(DEMO_MONSTER_SEED), DEMO_MONSTER_DEPTH)
		_demo_running = true
		start_fight(Demo.demo_party_unlocked(), mon, DEMO_MONSTER_SEED, {}, {})
	else:
		var echo: Dictionary = Echo.from_dict(Echo.make(PartyGen.demo_rival(), {"player": "Ashen Pact"})).get("echo", {})
		_demo_running = true
		start_fight(Demo.demo_party_unlocked(), echo, DEMO_PVP_SEED, DEMO_PVP_OPTIONS, {"echo_side": 1})


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


func is_ab_focus(ev: Dictionary) -> bool:
	return String(ev.get("kind", "")) == "ability"


## Jumps playback to sim time t (no effects on the way), e.g. to capture one behaviour.
func _seek(t: float) -> void:
	_instant = true
	while _ev_i < events.size() and float(events[_ev_i]["t"]) < t:
		var ev: Dictionary = events[_ev_i]
		sim_t = float(ev["t"])
		_ev_i += 1
		_dispatch(ev)
	_instant = false
	sim_t = maxf(sim_t, t)
	fx.clear_all()
	for u in units:
		u.plan_move(Unit.Move.STAY, sim_t, sim_t, sim_t, sim_t, u.home)


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
			if _intro_t >= INTRO_LEN and _seek_to > 0.0:
				_seek(_seek_to)
				_seek_to = -1.0
			if _intro_t >= INTRO_LEN and _tip_demo >= 0:
				hud.open_tip_demo(_tip_demo)
				_tip_demo = -1
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
		if frozen and u.uid != _freeze_actor and u.spr.animation != &"hit":
			us = 0.0   # (a hit reaction keeps playing so no unit freezes on its white hit frame)
		u.tick(sim_t, 0.0 if (frozen and u.uid != _freeze_actor) else vdt, us, vdt)
	if not _pending_moves.is_empty() and _focus_end < 0.0 and _freeze <= 0.0 and _vclock > _ko_settle:
		_play_pending_move()
	if _move_lit_until > 0.0 and _vclock > _move_lit_until:
		_move_lit_until = -1.0
		for n in units:
			n.lit = false
	if _focus_end >= 0.0 and sim_t > _focus_end + 0.05:
		_focus_end = -1.0
		fx.fade_popups()   # numbers never outlive their action
		for u in units:
			u.dimmed = false
			u.lit = false
	# dim for ability moments
	var want_dim := 0.0
	if _cur_action.get("kind", "") == "ability" and sim_t < float(_cur_action.get("t", 0.0)) + float(_cur_action.get("duration", 0.0)):
		want_dim = [0.3, 0.32, 0.35][spectacle_level]   # brightness floor: the arena stays lit (>= 65%)
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
			var tg := int(_cur_action.get("target", -1))
			if spectacle_level > 0 and String(_cur_action.get("kind", "")) == "ability" and tg >= 0 and tg < units.size():
				var mid: Vector2 = (a.position + units[tg].position) * 0.5 - Vector2(320, 180)
				var lim := 4.0 * spectacle_level   # bg_vault.png has an 8 world px margin
				target = Vector2(clampf(mid.x * 0.25, -lim, lim), clampf(mid.y * 0.25, -lim, lim))
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
	# Anyone hit or healed during a focused action is part of it (e.g. Mend's ally), so un-dim them.
	if _focus_end >= 0.0 and ev.has("dst"):
		var d := int(ev["dst"])
		if d >= 0 and d < units.size():
			units[d].dimmed = false
			units[d].lit = is_ab_focus(_cur_action)
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
		"formation_move": _on_formation_move(ev)
		"spawn": _on_spawn(ev)
		"crystal_fragment": _on_crystal_fragment(ev)
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
	if stat == "":
		_behaviour_cue(ev, u)
		return
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


## Each formation behaviour reads on the board as its own moment.
func _behaviour_cue(ev: Dictionary, u) -> void:
	if String(ev.get("source", "")).begins_with("memory:"):
		_memory_cue(ev, u)
		return
	var s: int = u.side
	var eff := String(ev.get("effect", ""))
	var r_id := int(ev.get("related", -1))
	var r = units[r_id] if r_id >= 0 and r_id < units.size() else null
	var sc: Color = side_colors[s].lerp(Pal.INK10, 0.25)
	if eff == "keepers_ring":
		var an := String(_cur_action.get("anim", ""))
		if r == null or an.begins_with("melee") or an.begins_with("slam") or int(_cur_action.get("uid", -1)) < 0:
			return   # the ring only matters when it turned a ranged, magic or dash attack
	var name_ := String((sides[s].get("formation", {}).get("behaviour", {}) as Dictionary).get("name", eff.capitalize()))
	if eff == "draws_melee":
		name_ = "Draws the blow"
	elif eff == "taunt":
		name_ = "Lighthouse"
	elif eff == "scattered":
		name_ = "Scattered"
	elif eff == "chorus_splash":
		name_ = "Chorus splash"
	hud.pulse_badge(s, 9)
	stage.glyph_pulse[s] = 1.0
	stage.slot_pulse[Vector3i(s, u.col, u.row)] = 1.4
	u.buff_glow = 0.6
	u.buff_color = sc
	fx.cue(name_, u.position + Vector2(0, 18), sc, 0.0)
	match eff:
		"shoulder_to_shoulder":     # a charge pulse travels from the hit partner and fills this gauge
			if r != null:
				fx.projectile(r.chest(), u.position + Vector2(u.facing * 16, 4), sim_t, sim_t + 0.3, Pal.VIOLET3, Pal.VIOLET4, 0, 10.0)
			u.charge_shown = maxf(0.0, float(u.charge) - float(ev.get("value", 15)))
			u.charge_hold = 0.3
			u.dimmed = false
			u.lit = true
			fx.ring(u.position + Vector2(u.facing * 16, 4), 14, 3, 0.4, Pal.VIOLET4, 1.0)
		"covering_fire":            # retarget line onto the attacker, crosshair on it
			if r != null:
				fx.sweep(u.chest(), r.chest(), Pal.BLOOD4)
				fx.ring(r.chest(), 18, 6, 0.5, Pal.BLOOD4, 1.0)
		"guardian":                 # intercept flash between the two
			if r != null:
				fx.sweep(r.chest(), u.chest(), Pal.INK10)
			fx.ring(u.chest(), 6, 22, 0.45, sc, 1.2)
			fx.light(u.chest(), sc, 1, 0.6, 0.4)
		"brace", "share_the_blow":  # the blow visibly splits to the neighbour(s)
			for n in units:
				if n.alive and n != u and n.side == s and n.col == u.col and absi(n.row - u.row) == 1:
					fx.sweep(u.chest(), n.chest(), Pal.AMBER6)
					fx.ring(n.chest(), 4, 14, 0.4, Pal.AMBER6, 1.0)
			fx.ring(u.chest(), 4, 18, 0.4, Pal.AMBER6, 1.0)
		"opening_volley":           # the back row's gauges surge at fight start
			for n in units:
				if n.alive and n.side == s and n.col == 1:
					fx.pillar(n.position.x, n.position.y, 6.0, 0.8, sc)
					fx.particles(n.position + Vector2(0, 4), 12, sc, 20.0, 60.0, 0.8, -40.0, 1, 6.0)
					n.buff_glow = 0.8
					n.buff_color = sc
		"flank":                    # a strike along the row
			if r != null:
				fx.sweep(u.chest() + Vector2(0, 4), r.chest() + Vector2(0, 4), sc)
				stage.slot_pulse[Vector3i(s, 0, u.row)] = 1.4
		"draws_melee":
			fx.ring(u.chest(), 16, 4, 0.4, Pal.BLOOD4, 1.0)
		"hearthguard":              # a hearth glow on the lone front unit, one shield segment per back ally
			var backs := 0
			for n in units:
				if n.alive and n.side == s and n.col == 1:
					backs += 1
			fx.shield(u.chest() + Vector2(u.facing * 14, 0), backs, Pal.AMBER5, 0.9)
			fx.light(u.position + Vector2(0, -12), Pal.AMBER5, 2, 0.6, 0.8)
			fx.ring(u.position, 4, 22, 0.6, Pal.AMBER5, 0.35)
			fx.particles(u.position, 12, Pal.AMBER6, 14.0, 35.0, 0.8, -20.0, 1, 8.0)
		"taunt":                    # a beam pulls the attack onto the post
			if r != null:
				fx.sweep(r.chest(), u.chest(), Pal.AMBER6)
			fx.pillar(u.position.x, u.position.y, 8.0, 0.5, Pal.AMBER6)
		"chorus_splash":
			if r != null:
				fx.ring(r.chest(), 4, 28, 0.5, Pal.VIOLET4, 0.6)
		"keepers_ring":             # the attack bends off the ring around the keeper onto this unit
			var att = units[int(_cur_action.get("uid", -1))]
			var bend: Vector2 = r.chest() + (att.chest() - r.chest()).normalized() * 22.0
			fx.sweep(att.chest(), bend, Pal.CRYSTAL5)
			fx.sweep(bend, u.chest(), Pal.BLOOD4)
			if r != null:
				fx.ring(r.position + Vector2(0, -2), 26, 14, 0.6, Pal.CRYSTAL5, 0.4)
				fx.ring(r.position + Vector2(0, -2), 14, 20, 0.6, Pal.INK10, 0.4)
				fx.light(r.chest(), Pal.CRYSTAL4, 1, 0.5, 0.6)
				r.buff_glow = 0.6
				r.buff_color = Pal.CRYSTAL5
		"shardpoint":               # a charge spark flies from the ally to the tip and fills its gauge
			if r != null:
				fx.projectile(r.chest(), u.position + Vector2(u.facing * 16, 4), sim_t, sim_t + 0.3, Pal.VIOLET3, Pal.VIOLET4, 0, 12.0)
			u.charge_shown = maxf(0.0, float(u.charge) - float(ev.get("value", 8)))
			u.charge_hold = 0.3
		"echo_step":                # a staggered afterimage
			u.echo_afterimage(0.6)
		"scattered":                # small separate auras: nothing links them
			for n in units:
				if n.alive and n.side == s:
					fx.ring(n.position, 3, 10, 0.5, sc, 0.4)


# ------------------------------------------------------------------------- Crystal of Remembrance
## A memory surfaces: light pours out of the Crystal, the unit forms in its slot, and its name and
## lore line show as a caption. The clock holds while it forms.
func _on_spawn(ev: Dictionary) -> void:
	var u: Dictionary = (ev.get("unit", {}) as Dictionary).duplicate()
	var slot: Array = ev.get("slot", [u.get("col", 0), u.get("row", 0)])
	u["col"] = int(slot[0])
	u["row"] = int(slot[1])
	var node := _make_unit(u)
	var id: int = node.uid
	if units.size() <= id:
		units.resize(id + 1)
	units[id] = node
	side_units[node.side].append(id)
	stage.occupied[node.side][Vector2i(node.col, node.row)] = true
	stage.alive_cells[node.side][Vector2i(node.col, node.row)] = true
	hud.row_flash.resize(maxi(hud.row_flash.size(), units.size()))
	plates.units = units
	if _instant:
		return
	node.form_t = 0.0
	node.modulate.a = 0.0
	var c = units[crystal_uid] if crystal_uid >= 0 else null
	if c != null:
		fx.sweep(c.chest(), node.chest(), Pal.VIOLET4)
		fx.light(c.chest(), Pal.VIOLET3, 3, 0.7, 0.9)
		fx.particles(c.chest(), 30, Pal.VIOLET4, 60.0, 20.0, 0.9, 0.0, 1, 6.0)
	fx.pillar(node.position.x, node.position.y, 12.0, 0.9, Pal.VIOLET3)
	fx.ring(node.position, 4, 30, 0.7, Pal.VIOLET4, 0.35)
	hud.show_lore(node.label, String(ev.get("lore", "")))
	hitstop(1.4 if String(ev.get("reason", "")) == "fragment" else 1.0, node.uid)


## A fragment breaks off: cracks spread, a shard flies off with particles, hit-stop, the pip fills.
func _on_crystal_fragment(ev: Dictionary) -> void:
	fragments = int(ev.get("index", fragments + 1))
	if crystal_uid < 0:
		return
	var c = units[crystal_uid]
	c.cracks = fragments
	if _instant:
		return
	var ch: Vector2 = c.chest()
	hitstop(0.5)
	shake(6.0)
	hud.screen_flash(Pal.INK10, 0.2)
	hud.show_fragment(fragments)
	c.flash(Pal.INK10, 1.0)
	fx.light(ch, Pal.CRYSTAL5, 4, 0.8, 0.8)
	fx.ring(ch, 6, 70, 0.6, Pal.CRYSTAL5, 0.6)
	fx.ring(ch, 4, 46, 0.5, Pal.VIOLET4, 0.6)
	fx.particles(ch, 60, Pal.CRYSTAL5, 140.0, 40.0, 1.0, 160.0, 2, 8.0)
	fx.particles(ch, 30, Pal.VIOLET4, 90.0, 30.0, 0.8, 120.0, 1, 6.0)
	var off := Vector2(30.0 + 10.0 * fragments, -40.0 - 8.0 * fragments)
	fx.projectile(ch + Vector2(-6, -20), ch + off, sim_t, sim_t + 0.45, Pal.CRYSTAL4, Pal.INK10, 0, 40.0)


func _memory_cue(ev: Dictionary, u) -> void:
	var eff := String(ev.get("effect", ""))
	var r_id := int(ev.get("related", -1))
	var r = units[r_id] if r_id >= 0 and r_id < units.size() else null
	var behs := {"shield_crystal": "Stand in the crossing", "kindle": "Kindle", "harvest": "Grief of the harvest",
		"mirror": "Woven likeness", "last_stand": "Last stand", "draw_memory": "Draw",
		"hasten_fading": "Close the Vault", "dim_lantern": "Dim the lantern"}
	var col := Pal.VIOLET4
	fx.cue(String(behs.get(eff, ev.get("name", ""))), u.position + Vector2(0, 18), col, 0.0)
	u.buff_glow = 0.7
	u.buff_color = col
	match eff:
		"shield_crystal":   # the hit aimed at the Crystal is pulled onto the Ferryman
			if r != null:
				fx.sweep(r.chest(), u.chest(), Pal.VIOLET4)
			fx.ring(u.chest(), 6, 22, 0.45, Pal.VIOLET4, 1.2)
		"kindle":           # a heal stream from the child to the most hurt memory
			if r != null:
				fx.trail(u.chest(), r.chest(), Pal.AMBER6)
				fx.projectile(u.chest(), r.chest(), sim_t, sim_t + 0.3, Pal.AMBER5, Pal.AMBER7, 0, 14.0)
		"harvest":
			fx.light(u.chest(), Pal.BLOOD3, 1, 0.6, 0.6)
			fx.ring(u.position, 4, 24, 0.5, Pal.BLOOD4, 0.35)
		"mirror":           # she copies the heroes' shape: their floor glyph flashes, a thread to her
			stage.glyph_pulse[0] = 1.0
			if r != null:
				fx.sweep(r.chest(), u.chest(), Pal.VIOLET3)
		"last_stand":
			fx.light(u.chest(), Pal.INK10, 2, 0.8, 0.6)
			fx.ring(u.chest(), 20, 4, 0.5, Pal.INK10, 1.0)
			hitstop(0.25)
		"draw_memory":      # charge is drawn out of the hero into the Draw
			if r != null:
				fx.projectile(r.chest(), u.chest(), sim_t, sim_t + 0.35, Pal.VIOLET3, Pal.VIOLET4, 0, 16.0)
				r.charge_shown = minf(100.0, r.charge_shown + 20.0)
		"hasten_fading":    # the Vault closes: the arena greys a step toward the Fading
			fade_level = maxf(fade_level, 0.35)
			fx.ring(Vector2(320, 190), 6, 160, 0.7, Pal.FADE3, 0.3)
			hud.vignette = 0.6
		"dim_lantern":      # the heroes' formation behaviours go dark while the Keeper stands
			hud.lantern_dim = u.uid
			fx.light(u.chest(), Pal.FADE3, 2, 0.5, 0.7)
			for n in units:
				if n != null and n.side == 0 and n.alive:
					n.flash(Pal.FADE2, 0.6)


## Vault Door, Hold the door: the back unit steps forward into the fallen front unit's slot.
func _on_formation_move(ev: Dictionary) -> void:
	var uid := int(ev.get("uid", -1))
	if uid < 0 or uid >= units.size():
		return
	var u = units[uid]
	var to: Array = ev.get("to", [0, u.row])
	var s: int = u.side
	stage.alive_cells[s].erase(Vector2i(u.col, u.row))
	u.col = int(to[0])
	u.row = int(to[1])
	stage.alive_cells[s][Vector2i(u.col, u.row)] = true
	var dest := Layout.slot_pos(s, u.col, u.row)
	if _instant:
		u.home = dest
		u.position = dest
		return
	_pending_moves.append([u.uid, dest])


## Hold the door plays once the KO and the action's focus have settled: its own brief focus,
## the clock paused while the unit walks (visual time) into the fallen unit's slot.
func _play_pending_move() -> void:
	var m: Array = _pending_moves.pop_front()
	var u = units[int(m[0])]
	var dest: Vector2 = m[1]
	var s: int = u.side
	var sc: Color = side_colors[s].lerp(Pal.INK10, 0.25)
	for n in units:
		n.dimmed = false
		n.lit = n == u
	u.walk_to(dest, 0.9)
	hitstop(1.2, u.uid)
	u.buff_glow = 1.1
	u.buff_color = side_colors[s].lerp(Pal.INK10, 0.4)
	fx.light(dest + Vector2(0, -12), side_colors[s], 2, 0.6, 1.2)
	fx.cue("Hold the door", dest + Vector2(0, 18), sc, 0.0)
	fx.trail(u.position, dest, sc)
	stage.slot_pulse[Vector3i(s, u.col, u.row)] = 1.8
	hud.pulse_badge(s, 9)
	_move_lit_until = _vclock + 1.3


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
		if int(u.get("span", 1)) == 2:
			stage.occupied[node.side][Vector2i(node.col, node.row + 1)] = true
			stage.alive_cells[node.side][Vector2i(node.col, node.row + 1)] = true
			crystal_uid = node.uid
	plates.units = units
	# same-column neighbours of a large monster step outward so it never hides them
	for big in units:
		if big.height <= 50:
			continue
		for n in units:
			if n != big and n.side == big.side and n.col == big.col and absi(n.row - big.row) == 1:
				n.home.x -= 16.0 * n.facing
				n.position = n.home
	for s: Dictionary in sides:
		var k := int(s["side"])
		var lines: Array = hud._mods_lines(s.get("formation", {}))
		for c: Dictionary in s.get("compositions", []):
			lines.append([true, String(c.get("name", "")), "comp"])
		form_lines[k] = lines
	hud.row_flash.resize(maxi(16, units.size()))
	hud.build_banner()


func _crystal_meta() -> Dictionary:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for an: StringName in [&"idle", &"hit", &"ko", &"attack", &"cast"]:
		frames.add_animation(an)
		frames.set_animation_speed(an, 5.0)
		frames.set_animation_loop(an, an == &"idle")
		for i in (4 if an == &"idle" else 1):
			var at := AtlasTexture.new()
			at.atlas = CRYSTAL_TEX
			at.region = Rect2(i * 56, 0, 56, 96)
			frames.add_frame(an, at)
	var anims := {}
	for an in ["idle", "hit", "ko", "attack", "cast"]:
		anims[an] = {"fps": 5, "frames": 4 if an == "idle" else 1, "events": {}}
	return {"frames": frames, "size": [56, 96], "origin": [28, 93], "anims": anims, "path": ""}


func _make_unit(u: Dictionary) -> Node2D:
	if String(u.get("tier", "")) == "crystal":
		var cm := _crystal_meta()
		var cn := Unit.new()
		units_root.add_child(cn)
		cn.setup(u, cm, SHADOWS["l"], false, side_colors[int(u["side"])], [])
		cn.g_rate = 0.0
		cn.g_base = 0.0
		cn.focus_rim = spectacle_level >= 1
		portraits[cn.uid] = _portrait("crystal", "crystal", true, cm)
		return cn
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
	node.focus_rim = spectacle_level >= 1
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
	var frames: SpriteFrames = m["frames"] if m.has("frames") else load(String(m["path"]))
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
	_split_tags = 0
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
		u.lit = involved and is_ab_focus(ev)
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
				var leave := minf(imp + 0.22, t_end - 0.06)   # linger at the target, home by the next action
				fx.trail(a.chest(), tgt.chest(), a.side_color)
				var hop := anim.begins_with("slam")
				a.plan_move(Unit.Move.HOP if hop else Unit.Move.LUNGE, t0, arrive, leave, t_end + 0.08, dest,
					22.0 if anim == "slam_big" else 14.0, anim != "melee")
			else:
				a.plan_move(Unit.Move.STAY, t0, t0, t0, t_end, a.home)
			a.schedule_anim(&"attack", maxf(t0, imp - a.impact_offset("attack")))
		"shoot":
			a.plan_move(Unit.Move.STAY, t0, t0, t0, t_end, a.home)
			if tgt != null:
				var from: Vector2 = a.chest() + Vector2(a.facing * 12, -2)
				var to: Vector2 = tgt.chest()
				var travel := clampf(from.distance_to(to) / 400.0, 0.18, 0.3)
				var launch := maxf(t0 + 0.05, imp - travel)
				fx.projectile(from, to, launch, imp, cols[0], cols[1], 0, 10.0)
				fx.ring(from, 2, 12, 0.35, cols[1], 1.0)          # cast flare on the caster
				fx.light(from, cols[0], 1, 0.6, 0.4)
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
			fx.sweep(c0 - d * (1.2 + 0.6 * spectacle_level), c0 + d * (1.2 + 0.6 * spectacle_level), cols[0])
			if spectacle_level > 0:
				fx.sweep(c0 - d * 1.6 + Vector2(-6, 0), c0 + d * 1.6 + Vector2(6, 0), Pal.INK10)
				fx.ring(c0, 6, 30 + 16 * spectacle_level, 0.4, cols[0], 1.4)
			for k in 3:
				fx.sprite_fx(&"slash", c0 + d * (k - 1), T.facing > 0, Color.WHITE, 1.0)
		"mend", "sanctuary":
			fx.pillar(T.position.x, T.position.y, 14.0 + 8.0 * spectacle_level, 0.7, Pal.LIFE4)
			fx.ring(T.position, 4, 26, 0.6, Pal.LIFE4, 0.35)
		"quake":
			for k in 4:
				fx.ring(T.position + Vector2(-T.facing * k * 6, 0), 8 + k * 10, (50 + k * 16) * (1.0 + 0.7 * spectacle_level), 0.55 + k * 0.08, Pal.INK10 if k % 2 == 0 else Pal.AMBER6, 0.3)
			fx.particles(T.position, 30, Pal.FADE3, 80.0, 40.0, 0.7, 160.0, 2, 10.0)
			shake(5.0)
		"backstab", "execute":
			fx.ring(T.chest(), 2, 20 + 14 * spectacle_level, 0.3, Pal.VIOLET4, 1.0)
			fx.particles(T.chest(), 16 + 16 * spectacle_level, Pal.VIOLET4, 60.0, 10.0, 0.4, 0.0, 1, 2.0)


## Spectacle level 1/2: an area ability owns the whole target side.
func _big_area(aid: String, side: int, cols: Array) -> void:
	var lv := spectacle_level
	for u in units:
		if u.side != side or not u.alive:
			continue
		if aid == "unravel" or aid == "hexfire":
			for k in 3:   # a spiral: staggered rings winding in
				fx.ring(u.chest() + Vector2(cos(k * 2.1) * 8.0, sin(k * 2.1) * 4.0), 30 + 14 * lv - k * 8, 2, 0.5 + k * 0.1, cols[k % 2], 0.6)
		else:
			fx.ring(u.position, 4, 18, 0.5, cols[0], 0.35)
	fx.light(Vector2(320.0 + (90.0 if side == 1 else -90.0), 190), cols[1], 4, 0.4 * lv, 0.7)


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
			fx.ring(T.position, 4, 22, 0.45, cols[1], 0.3)
		fx.ring(c, 2, 11, 0.3, cols[1].lerp(Color.WHITE, 0.4), 1.0)
		fx.particles(c, 8 + (6 if crit else 0), cols[1], 55.0, 15.0, 0.45, 40.0, 1, 2.0)
	if is_ab and not _action_first_hit:
		_action_first_hit = true
		shake(3.0 * (1.0 + 0.5 * spectacle_level))
		hitstop(0.3 + 0.06 * spectacle_level)
		_cam_push = (T.position - Vector2(320, 180)).normalized() * 3.0
		_ability_shape(aid, T, cols)
		if String(_cur_action.get("area", "single")) == "all_enemies":
			var cx := 320.0 + (60.0 if T.side == 1 else -60.0)
			var g := 1.0 + 0.6 * spectacle_level
			fx.ring(Vector2(cx, 185), 6, 70 * g, 0.55, cols[0], 0.45)
			fx.light(Vector2(cx, 185), cols[0], 2 + spectacle_level, 0.35, 0.6)
			if spectacle_level > 0:
				_big_area(aid, T.side, cols)
			for k in 3 + 3 * spectacle_level:
				fx.particles(Vector2(cx + randf_range(-40, 40), 180 + randf_range(-30, 30)), 14, cols[1], 90.0, 30.0, 0.6, 60.0, 1, 6.0)
	if kind == "magic" and String(_cur_action.get("area", "single")) == "single":
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
	var keep_tag := head == "shared" or head == "halved"
	if not crit and _hits_in_action > 1 and not keep_tag:
		head = ""   # one tag per action (shared/halved numbers always say so)
	var head_col: Color = Pal.AMBER6 if crit else note[1]
	# split hits (Echo step / Share the blow / Brace) are marked from the mods list even when
	# another annotation (e.g. a crit) owns the primary tag
	var split := ""
	for m in ev.get("mods", []):
		if m is Dictionary:
			var mid := String(m.get("id", ""))
			if mid == "echo_step":
				split = "halved"
			elif mid == "share_the_blow" or mid == "brace":
				split = "shared"
	if head == split:
		head = ""
	var was_split := split != ""
	if split != "":
		_split_tags += 1
		if _split_tags > 1:
			split = ""   # one "halved"/"shared" tag per action; the dashed links mark the rest
	fx.next_uid = dst
	fx.popup(amount, row, _num_pos(T, dst), 1, false, head, head_col, split, Pal.CRYSTAL5 if split == "halved" else Pal.AMBER6, delay)
	var pid := String((ev.get("primary", {}) as Dictionary).get("id", "")) if ev.get("primary", null) is Dictionary else ""
	if was_split or pid == "share_the_blow" or pid == "brace" or pid == "echo_step":
		var main := int(_cur_action.get("target", -1))
		if main >= 0 and main < units.size() and main != dst:
			fx.link_last(units[main].head() + Vector2(0, 6))
	if pid == "hearthguard":
		var backs := 0
		for n in units:
			if n.alive and n.side == T.side and n.col == 1:
				backs += 1
		fx.shield(T.chest() + Vector2(T.facing * 14, 0), backs, Pal.AMBER5, 0.7)


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
			return ["", side_colors[fs]]   # stat mods live in the banner (pulsed) and the unit glint
		"brace": return ["shared", Pal.AMBER6]
		"share_the_blow": return ["shared", Pal.AMBER6]
		"flank": return ["Flank x%.1f" % mult, Pal.AMBER6]
		"hearthguard": return ["Hearth -%d%%" % roundi((1.0 - mult) * 100.0), Pal.AMBER6]
		"echo_step": return ["halved", Pal.CRYSTAL5]
		"chorus_splash": return ["Chorus", Pal.VIOLET4]
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
	var p: Vector2 = T.head() + Vector2(0.0, 10.0)   # same-target hits stack (battle_fx)
	if T.is_crystal:
		p = T.position + Vector2(0.0, -50.0)
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
	fx.next_uid = dst
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
	if hud.lantern_dim == u.uid:
		hud.lantern_dim = -1
	_ko_settle = _vclock + 0.6
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
	if reason == "shard" and crystal_uid >= 0:
		var c = units[crystal_uid]
		fx.shard_fly(c.chest() + Vector2(0, -24), Vector2(320, 116))
		fx.light(Vector2(320, 116), Pal.CRYSTAL5, 4, 0.7, 2.5)
		hud.screen_flash(Pal.CRYSTAL5, 0.6)
		shake(4.0)
	end_subtitle = "%s wins  -  %.1f s%s" % [wname, float(ev.get("t", sim_t)), "  -  the Fading" if reason == "fading" else ""]
	if reason == "shard":
		end_subtitle = "A Shard breaks free of the Crystal  -  %.1f s" % float(ev.get("t", sim_t))
	elif crystal_uid >= 0 and w != player_side:
		end_subtitle = "%d of 4 fragments chipped  -  they become Glimmers" % fragments
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
