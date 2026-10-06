extends Node2D
## Compact status plate under every living unit: HP bar (with trailing chip damage and heal glow),
## the ATB gauge, and a charge gem that fills toward the ability and blinks when it is ready.

var units: Array = []          # BattleUnit nodes, set by the controller
var sim_t := 0.0
var _t := 0.0
var _gem := PackedVector2Array()
var visible_alpha := 1.0


func _ready() -> void:
	_gem.resize(4)


func tick(vdt: float, now: float) -> void:
	_t += vdt
	sim_t = now
	queue_redraw()


func _draw() -> void:
	if visible_alpha <= 0.0:
		return
	for u in units:
		if u == null or not u.alive:
			continue
		if u.is_crystal:
			_draw_crystal_plate(u)
			continue
		var p: Vector2 = u.plate_pos()
		var x0 := roundf(p.x - 11.0)
		var y0 := roundf(p.y + 3.0)
		var a := visible_alpha
		# frame (a branded unit's frame smoulders, a hexed one's turns violet: heals can't help it)
		draw_rect(Rect2(x0 - 1, y0 - 1, 24, 7), Color(Pal.INK1, 0.92 * a))
		var brand: bool = u.has_status("heal_block")
		if brand or u.has_status("heal_invert"):
			# both are flame-themed (Brand of Flame, Retribution Flame): the brand smoulders amber, the
			# retribution flame burns blood-red
			var on := fmod(_t + u.uid * 0.13, 0.36) < 0.2
			var fc := (Pal.AMBER5 if on else Pal.BLOOD4) if brand else (Pal.BLOOD4 if on else Pal.AMBER6)
			draw_rect(Rect2(x0 - 2, y0 - 2, 26, 9), Color(fc, a), false, 1.0)
		var frac: float = clampf(u.hp_shown / float(u.max_hp), 0.0, 1.0)
		var chip: float = clampf(u.hp_chip / float(u.max_hp), 0.0, 1.0)
		var hc := Pal.LIFE4 if frac > 0.5 else (Pal.AMBER5 if frac > 0.25 else Pal.BLOOD3)
		draw_rect(Rect2(x0, y0, 22, 3), Color(Pal.INK3, a))
		if chip > frac:
			draw_rect(Rect2(x0 + roundf(22.0 * frac), y0, roundf(22.0 * (chip - frac)) + 1.0, 3), Color(Pal.BLOOD4, a))
		if frac > 0.0:
			var w := maxf(1.0, roundf(22.0 * frac))
			draw_rect(Rect2(x0, y0, w, 3), Color(hc.lerp(Pal.INK10, u.heal_glow * 0.8), a))
			draw_rect(Rect2(x0, y0, w, 1), Color(Pal.INK10 if u.heal_glow > 0.2 else hc.lightened(0.35), a))
		# shield: a bright line over the bar, its length the shield's HP against max HP
		var sh: Dictionary = u.status_of("shield")
		if not sh.is_empty():
			var sw := clampf(roundf(22.0 * float(sh["value"]) / float(u.max_hp)), 2.0, 22.0)
			draw_rect(Rect2(x0 - 1, y0 - 3, sw + 2, 3), Color(Pal.INK1, 0.92 * a))
			draw_rect(Rect2(x0, y0 - 2, sw, 1), Color(Pal.CRYSTAL5 if float(sh.get("pop", 0.0)) <= 0.0 else Pal.INK10, a))
		# ATB gauge
		var g: float = u.gauge_at(sim_t)
		var gw := roundf(22.0 * g)
		draw_rect(Rect2(x0, y0 + 4, 22, 1), Color(Pal.INK4, a))
		var gc := Pal.CRYSTAL4 if u.has_status("slow") else Pal.INK9
		if g >= 0.999 or u.acting:
			gc = Pal.AMBER6 if fmod(_t, 0.2) < 0.12 else Pal.INK10
		if gw > 0:
			draw_rect(Rect2(x0, y0 + 4, gw, 1), Color(gc, a))
		# charge gem (diamond, fills bottom-up)
		var cx := x0 + 27.0 if u.side == 0 else x0 - 5.0
		var cy := y0 + 2.0
		var cf: float = clampf(u.charge_shown / float(u.charge_max), 0.0, 1.0)
		if u.summon != "":
			# a summon never charges: its gem is a hollow mark of what called it
			_diamond(cx, cy, 3.0, Color(Pal.INK1, a))
			_diamond(cx, cy, 2.0, Color(Pal.CRYSTAL4 if u.summon == "echo" else Pal.VIOLET3, a))
			_diamond(cx, cy, 1.0, Color(Pal.INK1, a))
			continue
		if u.charge_pulse > 0.0:
			# the charge landed: a bright ring bursts out of the gem and the fill sweeps up in white
			var cp: float = u.charge_pulse / 0.6
			_diamond(cx, cy, 4.0 + roundf((1.0 - cp) * 9.0), Color(Pal.VIOLET4, cp))
			_diamond(cx, cy, 3.0 + roundf((1.0 - cp) * 5.0), Color(Pal.INK10, cp * 0.8))
		_diamond(cx, cy, 3.0, Color(Pal.INK1, a))
		_diamond(cx, cy, 2.0, Color(Pal.VIOLET1, a))
		if u.is_ready:
			var on := fmod(_t, 0.4) < 0.25
			_diamond(cx, cy, 2.0, Color(Pal.VIOLET4 if on else Pal.VIOLET3, a))
			if on:
				draw_rect(Rect2(cx, cy - 1, 1, 1), Color(Pal.INK10, a))
		elif cf > 0.0:
			var fill_h := roundf(5.0 * cf)
			for k in int(fill_h):
				var yy := cy + 2.0 - k
				var half := 2.0 - absf(yy - cy)
				if half >= 0.0:
					draw_rect(Rect2(cx - half, yy, half * 2.0 + 1.0, 1), Color(Pal.VIOLET3.lerp(Pal.INK10, u.charge_pulse / 0.6), a))
		if u.has_status("charge_seal"):
			_seal(cx, cy, a)


## Runebinder's seal on a charge gem: a rune ring round it (four rune ticks turning slowly) and a
## bar across the gem, so the meter reads as locked while the seal lasts.
func _seal(cx: float, cy: float, a: float) -> void:
	_diamond(cx, cy, 5.0, Color(Pal.VIOLET4, a))
	_diamond(cx, cy, 4.0, Color(Pal.INK1, a))
	_diamond(cx, cy, 3.0, Color(Pal.INK1, a))
	_diamond(cx, cy, 2.0, Color(Pal.VIOLET1, a))
	draw_rect(Rect2(cx - 3, cy, 7, 1), Color(Pal.VIOLET4, a))
	var k := int(_t * 4.0) % 4
	for i in 4:
		var ang := (i + k * 0.25) * TAU / 4.0
		var p := Vector2(roundf(cx + 0.5 + cos(ang) * 6.0), roundf(cy + 0.5 + sin(ang) * 6.0))
		draw_rect(Rect2(p.x, p.y, 1, 1), Color(Pal.INK10 if i == 0 else Pal.VIOLET4, a))


func _diamond(cx: float, cy: float, r: float, c: Color) -> void:
	_gem[0] = Vector2(cx + 0.5, cy - r)
	_gem[1] = Vector2(cx + 1.0 + r, cy + 0.5)
	_gem[2] = Vector2(cx + 0.5, cy + 1.0 + r)
	_gem[3] = Vector2(cx - r, cy + 0.5)
	draw_colored_polygon(_gem, c)


const CRACKS := [
	[Vector2(0, -60), Vector2(-4, -50), Vector2(2, -42), Vector2(-3, -34)],
	[Vector2(6, -30), Vector2(10, -40), Vector2(7, -52), Vector2(12, -62)],
	[Vector2(-6, -24), Vector2(-11, -36), Vector2(-8, -46), Vector2(-14, -58), Vector2(-10, -70)],
	[Vector2(1, -16), Vector2(5, -26), Vector2(-2, -38), Vector2(4, -50), Vector2(-1, -66), Vector2(3, -80)],
]


## The Crystal: crack lines per fragment, a wide integrity bar and 4 fragment pips.
func _draw_crystal_plate(u) -> void:
	var p: Vector2 = u.plate_pos()
	for k in mini(u.cracks, 4):
		var pts: Array = CRACKS[k]
		for i in pts.size() - 1:
			draw_line(p + pts[i], p + pts[i + 1], Pal.INK1, 1.0)
			draw_line(p + pts[i] + Vector2(1, 0), p + pts[i + 1] + Vector2(1, 0), Pal.VIOLET4, 1.0)
	# the integrity bar, right of centre so the memory in the front row beside it keeps its own
	# plate clear; the fragment pips live in the Crystal's roster row (battle_hud.gd)
	var w: float = u.CRYSTAL_BAR_W
	var x0 := roundf(p.x + u.CRYSTAL_BAR_DX)
	var y0 := roundf(p.y + 4.0)
	draw_rect(Rect2(x0 - 1, y0 - 1, w + 2, 6), Pal.INK1)
	var frac: float = clampf(u.hp_shown / float(u.max_hp), 0.0, 1.0)
	var chip: float = clampf(u.hp_chip / float(u.max_hp), 0.0, 1.0)
	draw_rect(Rect2(x0, y0, w, 4), Pal.INK3)
	if chip > frac:
		draw_rect(Rect2(x0 + roundf(w * frac), y0, roundf(w * (chip - frac)), 4), Pal.INK10)
	draw_rect(Rect2(x0, y0, roundf(w * frac), 4), Pal.CRYSTAL4)
	draw_rect(Rect2(x0, y0, roundf(w * frac), 1), Pal.CRYSTAL5)
	for k in range(1, 4):
		draw_rect(Rect2(x0 + roundf(w * k / 4.0), y0, 1, 4), Pal.INK1)
