extends RefCounted
## Layout solver for one action's world labels (hires-ui round 6): damage and heal numbers with
## their head word (CRIT!), tag line and KO! pill, and formation cues. Pure: no nodes, world px.
##
## Numbers and KO! use the column mode (round 16, below `COL_SLACK`): they stack upward over their
## own unit's head and never move sideways. What follows is the free solver: formation cues, and a
## number whose column has no legal box (it never happened in the demo fights; the tests check it).
##
## Every label is anchored to its own unit. It starts at its preferred spot (just above the head
## for numbers, under the HP plate for cues) and may only move:
##   - sideways, keeping its centre inside its own unit's body span (never drifting onto a
##     neighbour's column), and
##   - down over its own body (to just under its own plate) or a little up (RISE_UP),
## and never stacks upward. A candidate box is legal when it (the bar, coordinator 2026-10-05: like
## TFT / Octopath / SAP, a number may overlap a neighbour's sprite; it must never read as the wrong
## unit's hit, merge with another number, or cover HUD text)
##   - overlaps no label already placed this action and no HUD rect (banners, roster, caption,
##     the Crystal's bar), and
##   - stays inside the field, and
##   - is nearer its own unit's body than any other unit's body (centre to box distance), and
##   - is clearly nearer its own unit's head point than any other unit's (HEAD_RATIO): the eye ties a
##     number to the face it sits by, so a number above a front-row head that sits beside the face of
##     the unit one row behind reads as that unit's (critic round 10: Cleave's 103 and 32).
## Bodies are where the units are DRAWN at the moment of placement (the hit frame, knock-back, a
## lunging attacker), plus `also`: where a displaced unit will stand while the label is up (its home).
## The legal box with the least movement wins (moving up costs more than down, sideways a little
## more than down, a little cost for covering a neighbour). When no box is legal the box with the
## least overlap wins: the label still never leaves its own unit's span.

## A unit as the solver sees it: {uid: int, body: Rect2, bar: Rect2, head: Vector2, also: Array}.
## body is the opaque core of the sprite as drawn (columns at least 30% filled, so a thin blade
## sticking out doesn't count), from the top of its head to its feet; bar is its HP plate plus the
## charge diamond; head its face point (default head_of(body)); also other rects it occupies while
## the label is up (a lunging attacker's home slot).
const RISE_UP := 2.0         # how far above its preferred spot (world px)
const BELOW := 14.0          # how far under its own HP plate a label may sit (world px)
const SPAN_SLACK := 3.0      # the core span is the body's thick part: a label centre may reach this
                             # far past it (still over the sprite: hair, sleeves, a held lantern)
const GAP := 1.0             # air between a label and another label (world px)
const W_UP := 3.0            # cost per world px moved up
const W_DOWN := 1.0          # cost per world px moved down
const W_SIDE := 1.5          # cost per world px moved sideways
## Set by place(): true when no legal box existed and the least-bad one was returned.
static var last_fallback := false
## Set by place(): true when a column label found no legal box in its column (the free solver placed it).
static var last_column_miss := false
const W_SPRITE := 0.05       # cost per world px² over a neighbour's sprite or bar (soft)
const HEAD_RATIO := 0.8      # a label's centre is at most this fraction of the distance to any
                             # other unit's head point, measured to its own head point
const KNOCK := 5.0           # neighbours may still be knocked this far sideways (and their hit frame
                             # shift) while the label is up: others' bodies and heads count this
                             # much nearer than they are drawn at placement


## Column mode (round 16, critic round 11 fix 1: "multi-target labels stack upward above their own
## target's head, never sideways"). A number, its CRIT! and its KO! stand in their own unit's
## column: the box's centre stays within COL_SLACK of the head's centre, and when it meets another
## label or a wall it climbs (or, only when nothing is free above, sinks over its own body). It is
## attributed when the eye, travelling straight down from it, meets its own unit first: no other
## unit's body (as drawn, plus where a displaced unit will stand) lies under the box's centre
## between the box's top and its own head (col_misattribution).
const COL_SLACK := 3.0       # a number's centre may sit this far either side of its head's centre
                             # (adjacent rows are 20 px apart and a crit label ~25 px wide: 3 px each
                             # way lets them pass without stacking)
const W_COL_UP := 1.0        # cost per world px climbed
const W_COL_DOWN := 40.0     # cost per world px sunk over its own body (only when nothing is free above)
const COL_DOWN_BASE := 400.0


## Places one label. `size` is the label's box size, `pref` its preferred box bottom-centre,
## `own` its unit, `units` every unit on the field (own included or not), `placed` the boxes
## already placed this action, `blocked` HUD rects, `field` the rect labels must stay inside.
## `column` (numbers and KO!): the column mode above; when it finds no legal box, the free solver.
## Returns the box (world px, whole numbers).
static func place(size: Vector2, pref: Vector2, own: Dictionary, units: Array, placed: Array,
		blocked: Array, field: Rect2, column := false) -> Rect2:
	last_column_miss = false
	if column:
		var rc := _place_column(size, pref, own, units, placed, blocked, field)
		if not last_fallback:
			return rc
		last_column_miss = true
	# a coarse pass (2 px sideways steps); only when it finds no legal box, a fine pass
	var r := _place(size, pref, own, units, placed, blocked, field, 2.0)
	if last_fallback:
		# legality only: the coarse pass's least-bad box stands if the fine one finds nothing
		var r2 := _place(size, pref, own, units, placed, blocked, field, 1.0)
		if not last_fallback:
			return r2
		last_fallback = true
	return r


static func _place(size: Vector2, pref: Vector2, own: Dictionary, units: Array, placed: Array,
		blocked: Array, field: Rect2, step: float) -> Rect2:
	var body: Rect2 = own.get("body", Rect2(pref.x - 11.0, pref.y, 22.0, 40.0))
	var bar: Rect2 = own.get("bar", Rect2())
	var uid := int(own.get("uid", -1))
	var others: Array = []
	for u: Dictionary in units:
		if int(u.get("uid", -2)) != uid:
			others.append(u)
	# the label's centre stays within its own body's span (and the field)
	var x_lo := maxf(body.position.x - SPAN_SLACK, field.position.x + size.x * 0.5)
	var x_hi := minf(body.end.x + SPAN_SLACK, field.end.x - size.x * 0.5)
	if x_lo > x_hi:
		x_lo = clampf(pref.x, field.position.x + size.x * 0.5, field.end.x - size.x * 0.5)
		x_hi = x_lo
	var px := clampf(pref.x, x_lo, x_hi)
	# bottom edge range: a little above the preferred spot, down over its own body to just under
	# its own HP plate (the cost keeps it as near the preferred spot as it can be)
	var under := maxf(body.end.y, bar.end.y if bar.has_area() else body.end.y) + 1.0
	var y_top := minf(pref.y, body.position.y) - RISE_UP
	var y_bot := maxf(pref.y, under + size.y + BELOW)
	var best := Rect2()
	var best_cost := INF
	var fb := Rect2()
	var fb_cost := INF
	var xs := _steps(px, x_lo, x_hi, step)
	var geo := _prep(own, others, 1.0)
	# rows in order of their cost (down is cheaper than up), and in each row the x steps nearest
	# first, so the search stops at the first legal box it can't beat
	var ys: Array[float] = []
	var yy := floorf(y_top)
	while yy <= y_bot + 0.01:
		if step < 1.5 or int(yy - floorf(pref.y)) % 2 == 0:   # the coarse pass takes every other row
			ys.append(yy)
		yy += 1.0
	ys.sort_custom(func(a: float, b: float) -> bool: return _ycost(a - pref.y) < _ycost(b - pref.y))
	for y: float in ys:
		var cy := _ycost(y - pref.y)
		if cy >= best_cost:
			break
		for x: float in xs:
			var cost := cy + absf(x - pref.x) * W_SIDE
			if cost >= best_cost:
				break
			var box := Rect2(roundf(x - size.x * 0.5), y - size.y, size.x, size.y)
			var ov := overlap(box, placed, blocked, field)
			var mis := -1.0   # attribution miss, measured once per candidate and only when needed
			if ov <= 0.0:
				mis = _miss(box.get_center(), geo)
				if mis <= 0.0:
					# legal; covering a neighbour's sprite or bar is allowed but costs a little, so a
					# clear spot near the head wins over an equal one on a neighbour
					cost += sprite_overlap(box, others) * W_SPRITE
					if cost < best_cost:
						best = box
						best_cost = cost
					continue
			if best_cost == INF and step > 1.5:
				if mis < 0.0:
					mis = _miss(box.get_center(), geo)
				var c2 := ov * 100.0 + cost + (0.0 if mis <= 0.0 else 5000.0 + mis * 50.0)
				if c2 < fb_cost:
					fb_cost = c2
					fb = box
	last_fallback = best_cost == INF
	if best_cost < INF:
		return best
	return fb


static func _place_column(size: Vector2, pref: Vector2, own: Dictionary, units: Array, placed: Array,
		blocked: Array, field: Rect2) -> Rect2:
	var body: Rect2 = own.get("body", Rect2(pref.x - 11.0, pref.y, 22.0, 40.0))
	var uid := int(own.get("uid", -1))
	var others: Array = []
	for u: Dictionary in units:
		if int(u.get("uid", -2)) != uid:
			others.append(u)
	var cx := body.get_center().x
	var x_lo := maxf(cx - COL_SLACK, field.position.x + size.x * 0.5)
	var x_hi := minf(cx + COL_SLACK, field.end.x - size.x * 0.5)
	last_fallback = true
	if x_lo > x_hi:
		return Rect2()
	var xs := _steps(clampf(cx, x_lo, x_hi), x_lo, x_hi, 1.0)
	var geo := _prep_col(own, others, 1.0)
	# rows: climbing from the preferred spot (cheap), then sinking over its own body down to its
	# middle (dear: only when nothing is free above)
	var ys: Array[float] = []
	var y := floorf(pref.y)
	var y_top := field.position.y + size.y
	while y >= y_top - 0.01:
		ys.append(y)
		y -= 1.0
	y = floorf(pref.y) + 1.0
	var y_bot := body.end.y
	while y <= y_bot:
		ys.append(y)
		y += 1.0
	var best := Rect2()
	var best_cost := INF
	for yy: float in ys:
		var dy := yy - pref.y
		var cy := (-dy * W_COL_UP) if dy <= 0.0 else (COL_DOWN_BASE + dy * W_COL_DOWN)
		if cy >= best_cost:
			break   # rows come in cost order (every climb costs less than any sink)
		for x: float in xs:
			var cost := cy + absf(x - cx) * W_SIDE
			if cost >= best_cost:
				break
			var box := Rect2(roundf(x - size.x * 0.5), yy - size.y, size.x, size.y)
			if overlap(box, placed, blocked, field) > 0.0:
				continue
			if _col_miss(box, geo) > 0.0:
				continue
			best = box
			best_cost = cost
			break
	last_fallback = best_cost == INF
	return best


## The column geometry flattened once per placement: [own body, PackedFloat32Array of other rects
## (x0, y0, x1, y1 with x grown by the knock slack, then 1 when that unit stands behind this one)].
## A unit stands behind when its feet are further up the floor, or it is a backdrop ("back": the
## Crystal, which every memory in front of it covers).
static func _prep_col(own: Dictionary, others: Array, k: float) -> Array:
	var sl := KNOCK * k
	var ob: Rect2 = own.get("body", Rect2())
	var rr := PackedFloat32Array()
	for u: Dictionary in others:
		var rects: Array = [u.get("body", Rect2())]
		rects.append_array(u.get("also", []))
		var back := bool(u.get("back", false))
		for r: Rect2 in rects:
			if not r.has_area():
				continue
			rr.append(r.position.x - sl)
			rr.append(r.position.y)
			rr.append(r.end.x + sl)
			rr.append(r.end.y)
			rr.append(1.0 if back or r.end.y < ob.end.y - 1.0 else 0.0)
	return [ob, rr]


static func _col_miss(box: Rect2, g: Array) -> float:
	var ob: Rect2 = g[0]
	var c := box.get_center()
	var miss := 0.0
	# over its own head span
	if c.x < ob.position.x:
		miss = ob.position.x - c.x
	elif c.x > ob.end.x:
		miss = c.x - ob.end.x
	# above its own head, or over its own body: never under its feet
	if box.end.y > ob.end.y:
		miss = maxf(miss, box.end.y - ob.end.y)
	# straight down from the label to its own head, no other body
	var y0 := box.position.y
	var y1 := maxf(box.end.y, ob.position.y)
	# a unit standing behind this one is hidden by this one's body: only the part of the label
	# above this unit's head can read as on it
	var y1_behind := minf(y1, ob.position.y)
	var rr: PackedFloat32Array = g[1]
	for i in range(0, rr.size(), 5):
		var yb := y1_behind if rr[i + 4] > 0.5 else y1
		if yb > y0 and c.x > rr[i] and c.x < rr[i + 2] and rr[i + 1] < yb and rr[i + 3] > y0:
			miss = maxf(miss, minf(c.x - rr[i], rr[i + 2] - c.x) + 0.5)
	return miss


## How far (world px) a box misses the column rule: its centre over its own unit's span, the box
## above its own head (or over its own body), and no other unit's body straight under its centre
## between the box and its own head. `k` scales the knock-back slack (1 placing; 0 checking a drawn frame).
static func col_misattribution(box: Rect2, own: Dictionary, others: Array, k := 1.0) -> float:
	return _col_miss(box, _prep_col(own, others, k))


static func _ycost(dy: float) -> float:
	return (dy * W_DOWN) if dy >= 0.0 else (-dy * W_UP)


## Sideways candidates, nearest the preferred x first (then the span's two ends).
static func _steps(px: float, lo: float, hi: float, step := 1.0) -> Array[float]:
	var out: Array[float] = [px]
	var k := 1.0
	while px - k >= lo - 0.01 or px + k <= hi + 0.01:
		if px + k <= hi + 0.01:
			out.append(px + k)
		if px - k >= lo - 0.01:
			out.append(px - k)
		k += step
	for e: float in [hi, lo]:
		if absf(e - px) > 0.01 and not out.has(e):
			out.append(e)
	return out


## Area of a box over other units' bodies and bars (soft: allowed, a little costly).
static func sprite_overlap(box: Rect2, others: Array) -> float:
	var ov := 0.0
	for u: Dictionary in others:
		ov += _area(box, u.get("body", Rect2()))
		ov += _area(box, u.get("bar", Rect2()))
	return ov


## Weighted overlap of a box with placed labels, HUD rects and the outside of the field (0 = legal).
static func overlap(box: Rect2, placed: Array, blocked: Array, field: Rect2) -> float:
	var ov := 0.0
	for r: Rect2 in placed:
		ov += _area(box, r.grow(GAP)) * 3.0
	for r: Rect2 in blocked:
		ov += _area(box, r) * 3.0
	if not field.encloses(box):
		ov += box.get_area() - _area(box, field) + 1.0
	return ov


static func _area(a: Rect2, b: Rect2) -> float:
	if not b.has_area():
		return 0.0
	var i := a.intersection(b)
	return i.get_area() if i.has_area() else 0.0


## Head (face) point of a body rect: centred, a little under its top (hats and hoods sit above the face).
static func head_of(r: Rect2) -> Vector2:
	return Vector2(r.get_center().x, r.position.y + clampf(r.size.y * 0.28, 3.0, 13.0))


static func _head(u: Dictionary) -> Vector2:
	return u["head"] if u.has("head") else head_of(u.get("body", Rect2()))


## The box's centre is nearer its own body than any other unit's body (every rect it occupies), and
## at most HEAD_RATIO of the way to any other unit's head point compared with its own.
static func nearest_is_own(box: Rect2, own: Dictionary, others: Array, k := 1.0) -> bool:
	return misattribution(box, own, others, k) <= 0.0


## How far (world px) the box's centre misses the attribution rule (0 = attributed to its own unit).
## `k` scales the knock-back slack (1 when placing; 0 when checking what is drawn now).
static func misattribution(box: Rect2, own: Dictionary, others: Array, k := 1.0) -> float:
	return _miss(box.get_center(), _prep(own, others, k))


## The attribution geometry flattened once per placement: [own body, own head, slack,
## PackedFloat32Array of other rects (x0, y0, x1, y1, grown by the knock slack), PackedVector2Array
## of their head points]. The solver tests ~2000 candidates against it.
static func _prep(own: Dictionary, others: Array, k: float) -> Array:
	var sl := KNOCK * k
	var rr := PackedFloat32Array()
	var hh := PackedVector2Array()
	for u: Dictionary in others:
		var b0: Rect2 = u.get("body", Rect2())
		var rects: Array = [b0]
		rects.append_array(u.get("also", []))
		for r: Rect2 in rects:
			if not r.has_area():
				continue
			rr.append(r.position.x - sl)
			rr.append(r.position.y - sl * 0.4)
			rr.append(r.end.x + sl)
			rr.append(r.end.y)
			hh.append(_head(u) if r == b0 else head_of(r))
	return [own.get("body", Rect2()), _head(own), sl, rr, hh]


static func _miss(c: Vector2, g: Array) -> float:
	var sl: float = g[2]
	var od := dist(c, g[0]) + sl
	var oh := c.distance_to(g[1]) + sl
	var rr: PackedFloat32Array = g[3]
	var hh: PackedVector2Array = g[4]
	var miss := 0.0
	for i in hh.size():
		var dx := maxf(0.0, maxf(rr[i * 4] - c.x, c.x - rr[i * 4 + 2]))
		var dy := maxf(0.0, maxf(rr[i * 4 + 1] - c.y, c.y - rr[i * 4 + 3]))
		var d := sqrt(dx * dx + dy * dy)
		if d <= od:
			miss = maxf(miss, od - d + 0.5)
		var hd := maxf(0.0, c.distance_to(hh[i]) - sl) * HEAD_RATIO
		if oh > hd:
			miss = maxf(miss, oh - hd)
	return miss


## Distance from a point to a rect (0 inside).
static func dist(p: Vector2, r: Rect2) -> float:
	if not r.has_area():
		return INF
	var dx := maxf(0.0, maxf(r.position.x - p.x, p.x - r.end.x))
	var dy := maxf(0.0, maxf(r.position.y - p.y, p.y - r.end.y))
	return sqrt(dx * dx + dy * dy)
