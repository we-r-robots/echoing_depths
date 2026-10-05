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
		if not u.alive:
			continue
		var p: Vector2 = u.position
		var x0 := roundf(p.x - 11.0)
		var y0 := roundf(p.y + 3.0)
		var a := visible_alpha
		# frame
		draw_rect(Rect2(x0 - 1, y0 - 1, 24, 7), Color(Pal.INK1, 0.92 * a))
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
		# ATB gauge
		var g: float = u.gauge_at(sim_t)
		var gw := roundf(22.0 * g)
		draw_rect(Rect2(x0, y0 + 4, 22, 1), Color(Pal.INK4, a))
		var gc := Pal.INK9
		if g >= 0.999 or u.acting:
			gc = Pal.AMBER6 if fmod(_t, 0.2) < 0.12 else Pal.INK10
		if gw > 0:
			draw_rect(Rect2(x0, y0 + 4, gw, 1), Color(gc, a))
		# charge gem (diamond, fills bottom-up)
		var cx := x0 + 27.0 if u.side == 0 else x0 - 5.0
		var cy := y0 + 2.0
		var cf: float = clampf(u.charge_shown / float(u.charge_max), 0.0, 1.0)
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


func _diamond(cx: float, cy: float, r: float, c: Color) -> void:
	_gem[0] = Vector2(cx + 0.5, cy - r)
	_gem[1] = Vector2(cx + 1.0 + r, cy + 0.5)
	_gem[2] = Vector2(cx + 0.5, cy + 1.0 + r)
	_gem[3] = Vector2(cx - r, cy + 0.5)
	draw_colored_polygon(_gem, c)
