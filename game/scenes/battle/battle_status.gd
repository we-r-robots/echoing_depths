extends Node2D
## Timed statuses on the battle field (round 17; core README `status` / `status_end`).
##
## Each unit with statuses gets a compact row of status chips by its HP plate, drawn on the UI layer
## at native resolution (the shared 9x9 effect icons from ui/effect_icons, each on an 11 px chip with
## a draining duration line under it). The row sits under the plate; where that is under the HUD (the
## caption, a roster) or a label it moves beside the plate on the outer side, else above the head.
## A row never covers a label or HUD text: it is placed against them, and labels placed later treat
## the rows as walls (battle.gd _layout_ctx). Tap or hover a row: the shared tooltip lists each
## status with its sentence (core/data/statuses.gd).
##
## In the world (this node, between the plates and the effects): the link tether between two linked
## units, stars circling a stunned unit's head, the Runebinder's binding runes, ember and venom motes.
## Hidden units fade to a silhouette, summons keep their tint, the plates carry the shield line, the
## branded frame and the sealed charge gem (battle_unit.gd, battle_plates.gd).

const Statuses = preload("res://core/data/statuses.gd")
const FXS = preload("res://scenes/battle/battle_fx.gd")
const ZOOM := 2.0
const CHIP := 11.0              # UI px: a 9x9 icon in a 1 px frame
const STRIDE := 12.0
const ROW_H := 15.0             # the chip, then its 2 px duration line on a dark strip
const MAX_ICONS := 5
const POP := 0.6                # seconds a new or refreshed chip stays lit
const MIN_HIT := 16.0           # touch target (BUILD.md)
## Icon tint per status (the chip's frame says helpful / harmful).
const TINT := {"stun": Pal.AMBER6, "blind": Pal.INK9, "sap": Pal.BLOOD4, "boon": Pal.LIFE4, "slow": Pal.CRYSTAL4,
	"poison": Pal.LIFE4, "burn": Pal.AMBER5, "regen": Pal.LIFE4, "shield": Pal.CRYSTAL5, "hidden": Pal.INK9,
	"heal_block": Pal.AMBER5, "heal_invert": Pal.VIOLET4, "charge_seal": Pal.VIOLET4, "link": Pal.AMBER6}
const STAT_ICON := {"atk": "stat_atk", "def": "stat_def", "mag": "stat_mag", "spd": "stat_spd"}
const STAT_NAME := {"atk": "Atk", "def": "Def", "mag": "Mag", "spd": "Spd"}
## Rune glyphs (3x5 pixel masks, row-major) for the Runebinder's binding.
const RUNES := [
	[1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1],
	[1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1],
	[0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1],
	[1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1],
]
const BIND_N := 6
const BIND_DUR := 1.1

var units: Array = []
var ui: Control                 # UI-layer canvas the rows draw on
var to_ui: Callable             # world point -> UI design px
var fx: Node2D                  # BattleFX (ambient motes)
var sim_t := 0.0
var _t := 0.0
var shown := true
## Rows placed this frame: uid -> Rect2 (world px), and the candidate spot each uses (sticky).
var rows := {}
var _spot := {}
## Set by the controller every frame (world px): HUD rects and the live labels the rows keep off,
## and the visible field.
var hud_rects: Array = []
var label_rects: Array = []
var field := Rect2(164, 92, 312, 176)
var _tips: Array[Control] = []
var _binds: Array = []          # [uid, visual t]
var _tether_flash := {}         # uid -> visual seconds left (a link share just passed along it)
var _mote_t := 0.0
## Tests: the first visual time each applied status ("uid:id") was drawn in a row, and rows deferred.
var first_drawn := {}
var applied := {}               # "uid:id" -> visual time it was applied
var _pairs := {}                # src uid -> [uid, sim t] of the last link applied (pairs the two ends)


func setup(hud_layer: Node, to_ui_fn: Callable, fx_node: Node2D) -> void:
	to_ui = to_ui_fn
	fx = fx_node
	ui = Control.new()
	ui.name = "StatusRows"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(ui)
	hud_layer.move_child(ui, 0)   # under the numbers and the HUD
	ui.draw.connect(_draw_ui)
	z_index = 45                  # over the plates, under the effects


func clear() -> void:
	rows.clear()
	_spot.clear()
	_binds.clear()
	_tether_flash.clear()
	_pairs.clear()
	first_drawn.clear()
	applied.clear()
	for c in _tips:
		c.visible = false


# ------------------------------------------------------------------------------------------ state
## A `status` event: the status lands on its unit, or stacks onto / refreshes the one it has.
## Returns the entry (with "fresh": true when it is new on the unit).
func apply(ev: Dictionary, now: float) -> Dictionary:
	var uid := int(ev.get("uid", -1))
	if uid < 0 or uid >= units.size() or units[uid] == null:
		return {}
	var u = units[uid]
	var id := String(ev.get("status", ""))
	var stat := String(ev.get("stat", ""))
	var e: Dictionary = u.status_of(id, stat)
	var fresh := e.is_empty()
	if fresh:
		e = {"id": id, "stat": stat, "partner": -1}
		u.statuses.append(e)
	var dur := float(ev.get("duration", 0.0))
	e["value"] = float(ev.get("value", 0.0))
	e["stacks"] = int(ev.get("stacks", 1))
	e["until"] = now + dur
	e["total"] = maxf(0.05, dur)
	e["src"] = int(ev.get("src", -1))
	e["pop"] = POP
	e["fresh"] = fresh
	# a link's two ends are applied together (same source, same moment): pair them. The event has no
	# partner field (reported), so the pairing is read from the order.
	if id == "link":
		var src := int(e["src"])
		var last: Array = _pairs.get(src, [])
		if not last.is_empty() and absf(float(last[1]) - now) < 0.001 and int(last[0]) != uid:
			var other = units[int(last[0])]
			var oe: Dictionary = other.status_of("link")
			if not oe.is_empty():
				oe["partner"] = uid
				e["partner"] = int(last[0])
			_pairs.erase(src)
		else:
			_pairs[src] = [uid, now]
	var key := "%d:%s" % [uid, id]
	if not applied.has(key) or fresh:
		applied[key] = _t
		first_drawn.erase(key)
	return e


## A `status_end` event.
func end(ev: Dictionary) -> void:
	var uid := int(ev.get("uid", -1))
	if uid < 0 or uid >= units.size() or units[uid] == null:
		return
	var u = units[uid]
	var e: Dictionary = u.status_of(String(ev.get("status", "")), String(ev.get("stat", "")))
	if not e.is_empty():
		u.statuses.erase(e)


## A shield took part of a hit: its line shrinks to what is left.
func absorb(ev: Dictionary) -> void:
	var uid := int(ev.get("uid", -1))
	if uid < 0 or uid >= units.size() or units[uid] == null:
		return
	var e: Dictionary = units[uid].status_of("shield")
	if not e.is_empty():
		e["value"] = float(ev.get("shield", 0.0))
		e["pop"] = 0.25


## The Runebinder's binding on a unit (runes ring it, chain together and close in).
func bind(uid: int) -> void:
	_binds.append([uid, 0.0])


## A link share just passed along the tether.
func tether_flash(uid: int) -> void:
	_tether_flash[uid] = 0.35


## Remaining fraction of a status's time (1 = just applied).
func left_frac(e: Dictionary) -> float:
	return clampf((float(e["until"]) - sim_t) / float(e["total"]), 0.0, 1.0)


# ------------------------------------------------------------------------------------------ frame
func tick(vdt: float, now: float) -> void:
	_t += vdt
	sim_t = now
	for u in units:
		if u == null:
			continue
		for e: Dictionary in u.statuses:
			if float(e.get("pop", 0.0)) > 0.0:
				e["pop"] = maxf(0.0, float(e["pop"]) - vdt)
	for k in range(_binds.size() - 1, -1, -1):
		_binds[k][1] = float(_binds[k][1]) + vdt
		if float(_binds[k][1]) > BIND_DUR:
			_binds.remove_at(k)
	for k: int in _tether_flash.keys():
		_tether_flash[k] = float(_tether_flash[k]) - vdt
		if float(_tether_flash[k]) <= 0.0:
			_tether_flash.erase(k)
	_ambient(vdt)
	_layout()
	_place_tips()
	queue_redraw()
	ui.queue_redraw()


## Embers rise off a burning unit, venom beads off a poisoned one (a few motes, never a cloud).
func _ambient(vdt: float) -> void:
	if fx == null or vdt <= 0.0:
		return
	_mote_t += vdt
	if _mote_t < 0.14:
		return
	_mote_t = 0.0
	for u in units:
		if u == null or not u.alive:
			continue
		var br: Rect2 = u.body_rect()
		if u.has_status("burn"):
			fx.particles(Vector2(br.get_center().x + randf_range(-5, 5), br.end.y - 10.0), 1, Pal.AMBER6 if randf() < 0.6 else Pal.BLOOD4, 6.0, 26.0, 0.6, -20.0, 1, 2.0)
		if u.has_status("poison") and randf() < 0.45:
			fx.particles(Vector2(br.get_center().x + randf_range(-6, 6), br.end.y - 16.0), 1, Pal.LIFE4, 4.0, 10.0, 0.7, -6.0, 1, 1.0)


## The statuses a row shows (the newest MAX_ICONS).
static func row_entries(u) -> Array:
	var es: Array = u.statuses
	return es.slice(maxi(0, es.size() - MAX_ICONS))


static func row_size(n: int) -> Vector2:
	return Vector2((n * STRIDE - 1.0) / ZOOM, ROW_H / ZOOM)


## Where a unit's row may stand (world px), in order of preference: under its HP plate (left edge
## on the bar's), beside the plate on the side away from the centre line, above its head.
static func candidates(u, sz: Vector2) -> Array:
	var pr: Rect2 = u.plate_rect()
	var p: Vector2 = u.plate_pos().round()
	var hr: Rect2 = u.home_rect() if not u.acting else u.body_rect()
	var out: Array = []
	out.append(Rect2(roundf(p.x - 12.0), pr.end.y + 1.0, sz.x, sz.y))
	if u.side == 0:
		out.append(Rect2(pr.position.x - 1.0 - sz.x, pr.position.y, sz.x, sz.y))
	else:
		out.append(Rect2(pr.end.x + 1.0, pr.position.y, sz.x, sz.y))
	out.append(Rect2(roundf(hr.get_center().x - sz.x * 0.5), hr.position.y - sz.y - 2.0, sz.x, sz.y))
	return out


func _free(r: Rect2, placed: Array) -> bool:
	if not field.encloses(r):
		return false
	for h: Rect2 in hud_rects:
		if h.intersects(r):
			return false
	for h: Rect2 in label_rects:
		if h.intersects(r):
			return false
	for h: Rect2 in placed:
		if h.grow(0.5).intersects(r):
			return false
	return true


## Why each spot of a unit's row is taken (debug and tests): one string per candidate, "" when free.
func spot_report(uid: int) -> Array:
	var u = units[uid]
	var out: Array = []
	var sz := row_size(maxi(1, row_entries(u).size()))
	for r: Rect2 in candidates(u, sz):
		var why := ""
		if not field.encloses(r):
			why = "outside the field %s" % field
		for h: Rect2 in hud_rects:
			if h.intersects(r):
				why = "hud %s" % h
		for h: Rect2 in label_rects:
			if h.intersects(r):
				why = "label %s" % h
		out.append("%s %s" % [r, why])
	return out


func _layout() -> void:
	rows.clear()
	if not shown:
		return
	var placed: Array = []
	for u in units:
		if u == null or not u.alive or u.statuses.is_empty() or u.is_crystal:
			continue
		var sz := row_size(row_entries(u).size())
		var cands := candidates(u, sz)
		var pick := -1
		var cur := int(_spot.get(u.uid, -1))
		if cur >= 0 and _free(cands[cur], placed):
			pick = cur
		else:
			for k in cands.size():
				if _free(cands[k], placed):
					pick = k
					break
		if pick < 0:
			continue   # nowhere clear this frame (a label covers every spot): it shows once it clears
		_spot[u.uid] = pick
		rows[u.uid] = cands[pick]
		placed.append(cands[pick])
		for e: Dictionary in row_entries(u):
			var key := "%d:%s" % [u.uid, e["id"]]
			if not first_drawn.has(key):
				first_drawn[key] = _t


## A row's rect in UI design px (whole pixels).
func ui_rect(r: Rect2) -> Rect2:
	var a: Vector2 = to_ui.call(r.position)
	return Rect2(roundf(a.x), roundf(a.y), roundf(r.size.x * ZOOM), roundf(r.size.y * ZOOM))


# ------------------------------------------------------------------------------------------ draw
func _draw_ui() -> void:
	var t0 := Time.get_ticks_usec() if FXS.perf_on else 0
	for uid: int in rows:
		var u = units[uid]
		var r := ui_rect(rows[uid])
		var x := r.position.x
		for e: Dictionary in row_entries(u):
			_draw_chip(Vector2(x, r.position.y), e)
			x += STRIDE
	if FXS.perf_on:
		FXS.perf_us += Time.get_ticks_usec() - t0


func _draw_chip(p: Vector2, e: Dictionary) -> void:
	var id: String = e["id"]
	var st: Dictionary = Statuses.STATUSES.get(id, {})
	var good := int(st.get("sign", -1)) > 0
	var tint: Color = TINT.get(id, Pal.INK10)
	var tex: Texture2D = EffectIcons.status_icon(id)
	if id == "sap" or id == "boon":
		tex = EffectIcons.icon(String(STAT_ICON.get(String(e["stat"]), "stat_atk")))
	var pop := float(e.get("pop", 0.0))
	var box := Rect2(p, Vector2(CHIP, CHIP))
	ui.draw_rect(Rect2(p.x, p.y, CHIP, ROW_H), Color(Pal.INK1, 0.92))
	var edge := Pal.LIFE3 if good else Pal.BLOOD3
	if pop > 0.0 and fmod(pop, 0.2) > 0.08:
		edge = Pal.INK10
	ui.draw_rect(box, edge, false, 1.0)
	ui.draw_texture(tex, p + Vector2(1, 1), tint)
	# sap / boon: the stat's icon with its arrow (green up / red down), like every stat chip
	if id == "sap" or id == "boon":
		var ar: Texture2D = EffectIcons.UP if good else EffectIcons.DOWN
		ui.draw_rect(Rect2(p.x + CHIP - 6.0, p.y + CHIP - 5.0, 6, 4), Pal.INK1)
		ui.draw_texture(ar, Vector2(p.x + CHIP - 6.0, p.y + CHIP - 4.5).round(), EffectIcons.BUFF if good else EffectIcons.COST)
	# poison stacks: one pip each along the top
	var n := int(e.get("stacks", 1))
	if n > 1:
		for k in n:
			ui.draw_rect(Rect2(p.x + CHIP - 3.0 - k * 2.0, p.y - 1.0, 1, 2), Pal.INK10)
	# duration: a line under the chip that drains as the status runs out
	var w := roundf((CHIP - 2.0) * left_frac(e))
	ui.draw_rect(Rect2(p.x + 1.0, p.y + CHIP + 1.0, CHIP - 2.0, 2), Pal.INK3)
	if w > 0.0:
		ui.draw_rect(Rect2(p.x + 1.0, p.y + CHIP + 1.0, w, 2), tint)
	if pop > 0.0:
		var g := roundf((1.0 - pop / POP) * 3.0) + 1.0
		ui.draw_rect(box.grow(g), Color(Pal.INK10, pop / POP * 0.7), false, 1.0)


func _draw() -> void:
	var t0 := Time.get_ticks_usec() if FXS.perf_on else 0
	for u in units:
		if u == null or not u.alive:
			continue
		var lk: Dictionary = u.status_of("link")
		var pid := int(lk.get("partner", -1))
		if not lk.is_empty() and pid > u.uid and pid < units.size() and units[pid] != null and units[pid].alive:
			_tether(u, units[pid])
		if u.has_status("stun"):
			_stars(u)
	for bd: Array in _binds:
		var uid := int(bd[0])
		if uid < units.size() and units[uid] != null:
			_runes(units[uid], float(bd[1]))
	if FXS.perf_on:
		FXS.perf_us += Time.get_ticks_usec() - t0


## A thin dotted tether chest to chest, a bright bead running along it; it flares as a share passes.
func _tether(a, b) -> void:
	var p0: Vector2 = a.chest() + Vector2(0, 4)
	var p1: Vector2 = b.chest() + Vector2(0, 4)
	var flare := maxf(float(_tether_flash.get(a.uid, 0.0)), float(_tether_flash.get(b.uid, 0.0))) / 0.35
	var n := maxi(2, int(p0.distance_to(p1) / 2.0))
	var col := Pal.AMBER6.lerp(Pal.INK10, flare)
	for k in n + 1:
		if k % 2 == 1 and flare <= 0.0:
			continue
		var q := p0.lerp(p1, float(k) / n).round()
		draw_rect(Rect2(q, Vector2.ONE), Color(col, 0.85))
	var bead := p0.lerp(p1, fmod(_t * 0.8, 1.0)).round()
	draw_rect(Rect2(bead - Vector2(1, 1), Vector2(3, 3)), Color(Pal.INK1, 0.8))
	draw_rect(Rect2(bead, Vector2.ONE), Pal.INK10)


## Stunned: three small stars circling over the head.
func _stars(u) -> void:
	var c: Vector2 = u.top() + Vector2(0, -3)
	for i in 3:
		var ang := _t * 4.5 + i * TAU / 3.0
		var p := (c + Vector2(cos(ang) * 8.0, sin(ang) * 2.5)).round()
		var front := sin(ang) > 0.0
		var col := Pal.AMBER6 if front else Pal.AMBER4
		draw_rect(Rect2(p.x - 1, p.y, 3, 1), col)
		draw_rect(Rect2(p.x, p.y - 1, 1, 3), col)
		if front:
			draw_rect(Rect2(p, Vector2.ONE), Pal.INK10)


## The Runebinder's binding (user note: "a series of runes connecting and binding the hero/monster"):
## runes appear one by one on a ring round the unit, a chain links each to the last, then the ring
## closes in on the body and fades.
func _runes(u, t: float) -> void:
	var c: Vector2 = u.chest() + Vector2(0, 2)
	var close := clampf((t - 0.45) / 0.35, 0.0, 1.0)
	var rx := lerpf(18.0, 10.0, close * close)
	var ry := lerpf(9.0, 5.0, close * close)
	var fade := 1.0 - clampf((t - 0.85) / (BIND_DUR - 0.85), 0.0, 1.0)
	var pts: Array = []
	for i in BIND_N:
		if t < i * 0.06:
			break
		var ang := -PI * 0.5 + i * TAU / BIND_N + close * 0.6
		pts.append((c + Vector2(cos(ang) * rx, sin(ang) * ry)).round())
	var lc := Color(Pal.VIOLET3, 0.9 * fade)
	for i in range(1, pts.size()):
		draw_line(pts[i - 1], pts[i], lc, 1.0)
	if pts.size() == BIND_N:
		draw_line(pts[BIND_N - 1], pts[0], lc, 1.0)
	for i in pts.size():
		var m: Array = RUNES[i % RUNES.size()]
		var o: Vector2 = pts[i] - Vector2(1, 2)
		draw_rect(Rect2(o - Vector2(1, 1), Vector2(5, 7)), Color(Pal.INK1, 0.85 * fade))
		for k in 15:
			if int(m[k]) == 1:
				draw_rect(Rect2(o + Vector2(k % 3, k / 3), Vector2.ONE), Color(Pal.VIOLET4 if t - i * 0.06 > 0.12 else Pal.INK10, fade))


# ------------------------------------------------------------------------------------------ tips
## One hit area per row (16 px minimum): the shared tooltip lists the unit's statuses.
func _place_tips() -> void:
	while _tips.size() < 12:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.visible = false
		ui.add_child(c)
		_tips.append(c)
	var k := 0
	for uid: int in rows:
		if k >= _tips.size():
			break
		var u = units[uid]
		var r := ui_rect(rows[uid])
		var c := _tips[k]
		var hs := Vector2(maxf(MIN_HIT, r.size.x), maxf(MIN_HIT, r.size.y))
		c.position = r.get_center() - hs * 0.5
		c.size = hs
		var entries: Array = []
		var sig := str(uid)
		for e: Dictionary in u.statuses:
			var line := tip_line(e)
			entries.append({"effect": tip_effect(e), "text": line})
			sig += "|" + line
		if String(c.get_meta("sig", "")) != sig:
			c.set_meta("sig", sig)
			Tip.attach(c, "%s: %s" % [u.label, "1 effect" if entries.size() == 1 else "%d effects" % entries.size()], "", Pal.INK9, "auto", {"entries": entries})
		c.visible = true
		k += 1
	for i in range(k, _tips.size()):
		if _tips[i].visible:
			_tips[i].visible = false


static func tip_effect(e: Dictionary) -> Dictionary:
	var eff := EffectIcons.status_effect(String(e["id"]))
	if e["id"] == "sap" or e["id"] == "boon":
		eff["icon"] = EffectIcons.icon(String(STAT_ICON.get(String(e["stat"]), "stat_atk")))
	return eff


## The tooltip sentence for one status: its data sentence, with the stat and stacks named.
static func tip_line(e: Dictionary) -> String:
	var st: Dictionary = Statuses.STATUSES.get(String(e["id"]), {})
	var s := String(st.get("text", e["id"]))
	match String(e["id"]):
		"sap", "boon":
			s = "%s: %s %+d%%." % [st.get("name", ""), STAT_NAME.get(String(e["stat"]), String(e["stat"])), roundi(float(e["value"]) * 100.0)]
		"poison":
			if int(e.get("stacks", 1)) > 1:
				s += " (%d stacks)" % int(e["stacks"])
		"shield":
			s = "Shielded: %d damage left to absorb. The Fading goes straight through it." % roundi(float(e["value"]))
		"slow":
			s = "Slowed: its turn gauge fills %d%% slower." % roundi(absf(float(e["value"])) * 100.0)
	return s
