extends RefCounted
## Layout solver for one action's world labels (hires-ui round 6): damage and heal numbers with
## their head word (CRIT!), tag line and KO! pill, and formation cues. Pure: no nodes, world px.
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
##   - is nearer its own unit's body than any other unit's body (centre to box distance).
## The legal box with the least movement wins (moving up costs more than down, sideways a little
## more than down, a little cost for covering a neighbour). When no box is legal the box with the
## least overlap wins: the label still never leaves its own unit's span.

## A unit as the solver sees it: {uid: int, body: Rect2, bar: Rect2}. body is the opaque core of the
## idle sprite (columns at least 30% filled, so a thin blade sticking out doesn't count), from the
## top of its head to its feet; bar is its HP plate plus the charge diamond.
const RISE_UP := 2.0         # how far above its preferred spot (world px)
const BELOW := 14.0          # how far under its own HP plate a label may sit (world px)
const SPAN_SLACK := 3.0      # the core span is the body's thick part: a label centre may reach this
                             # far past it (still over the sprite: hair, sleeves, a held lantern)
const GAP := 1.0             # air between a label and another label (world px)
const W_UP := 3.0            # cost per world px moved up
const W_DOWN := 1.0          # cost per world px moved down
const W_SIDE := 1.5          # cost per world px moved sideways
const W_SPRITE := 0.05       # cost per world px² over a neighbour's sprite or bar (soft)


## Places one label. `size` is the label's box size, `pref` its preferred box bottom-centre,
## `own` its unit, `units` every unit on the field (own included or not), `placed` the boxes
## already placed this action, `blocked` HUD rects, `field` the rect labels must stay inside.
## Returns the box (world px, whole numbers).
static func place(size: Vector2, pref: Vector2, own: Dictionary, units: Array, placed: Array,
		blocked: Array, field: Rect2) -> Rect2:
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
	var xs := _steps(px, x_lo, x_hi)
	var y := floorf(y_top)
	while y <= y_bot + 0.01:
		var dy := y - pref.y
		var cy := (dy * W_DOWN) if dy >= 0.0 else (-dy * W_UP)
		if cy >= best_cost:
			y += 1.0
			continue
		for x: float in xs:
			var cost := cy + absf(x - pref.x) * W_SIDE
			if cost >= best_cost:
				continue
			var box := Rect2(roundf(x - size.x * 0.5), y - size.y, size.x, size.y)
			var ov := overlap(box, placed, blocked, field)
			if ov <= 0.0 and nearest_is_own(box, body, others):
				# legal; covering a neighbour's sprite or bar is allowed but costs a little, so a
				# clear spot near the head wins over an equal one on a neighbour
				cost += sprite_overlap(box, others) * W_SPRITE
				if cost < best_cost:
					best = box
					best_cost = cost
			elif best_cost == INF:
				var c2 := ov * 100.0 + cost + (0.0 if nearest_is_own(box, body, others) else 5000.0)
				if c2 < fb_cost:
					fb_cost = c2
					fb = box
		y += 1.0
	if best_cost < INF:
		return best
	return fb


## Sideways candidates, nearest the preferred x first.
static func _steps(px: float, lo: float, hi: float) -> Array[float]:
	var out: Array[float] = [px]
	var k := 1.0
	while px - k >= lo - 0.01 or px + k <= hi + 0.01:
		if px + k <= hi + 0.01:
			out.append(px + k)
		if px - k >= lo - 0.01:
			out.append(px - k)
		k += 1.0
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


## The box's centre is nearer its own body than any other unit's body.
static func nearest_is_own(box: Rect2, body: Rect2, others: Array) -> bool:
	var c := box.get_center()
	var own := dist(c, body)
	for u: Dictionary in others:
		if dist(c, u.get("body", Rect2())) <= own:
			return false
	return true


## Distance from a point to a rect (0 inside).
static func dist(p: Vector2, r: Rect2) -> float:
	if not r.has_area():
		return INF
	var dx := maxf(0.0, maxf(r.position.x - p.x, p.x - r.end.x))
	var dy := maxf(0.0, maxf(r.position.y - p.y, p.y - r.end.y))
	return sqrt(dx * dx + dy * dy)
