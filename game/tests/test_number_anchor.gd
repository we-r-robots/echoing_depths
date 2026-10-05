extends "res://tests/test_case.gd"
## Damage numbers sit on their own target (hires-ui critic round 2: numbers floated a grid row high,
## so multi-target hits read on the unit behind). Checks BattleFX.number_anchor on every slot of the
## packed 2x4 grid, in world px (x6 = screen px at 1080p).

const FX = preload("res://scenes/battle/battle_fx.gd")
const Layout = preload("res://scenes/battle/battle_layout.gd")
## Lowest world y the banners keep (camera top 90 + (banner 26 + 2 + 3 margin) / zoom 2).
const BAND := 90.0 + 31.0 / 2.0
const HERO_TOP := [37.0, 43.0]   # shortest and tallest hero idle sprite (rogue .. mage)


func _all_tops(top_h: float) -> Array:
	var out: Array = []
	for side in 2:
		for col in 2:
			for row in 4:
				var feet := Layout.slot_pos(side, col, row)
				out.append([feet - Vector2(0, top_h), side])
	return out


func test_numbers_sit_just_above_their_own_head() -> void:
	for top_h: float in HERO_TOP:
		var tops := _all_tops(top_h)
		for t: Array in tops:
			var top: Vector2 = t[0]
			for crit: bool in [false, true]:
				var p := FX.number_anchor(top, top_h, 1 if t[1] == 1 else -1, BAND, crit)
				# baseline within 2 world px (12 screen px at 1080p) of the head, rise included
				var gap := top.y - (p.y - FX.NUM_RISE)
				check(gap >= -0.5 and gap <= 2.0 + FX.NUM_RISE, "number %.0f world px above head at %s (top_h %.0f, crit %s)" % [gap, top, top_h, crit])
				eq(p.x, top.x, "number centred on its target at %s" % top)
				# the head word never reaches the banners
				check(p.y - FX.NUM_RISE - FX.NUM_H - (FX.HEAD_H if crit else 0.0) >= BAND - 0.5, "number at %s clears the banner band" % top)
				# the nearest head to the number's centre is its own target's
				var c := p - Vector2(0, FX.NUM_RISE + FX.NUM_H * 0.5)
				var own := c.distance_to(top)
				for o: Array in tops:
					var ot: Vector2 = o[0]
					if ot != top:
						check(c.distance_to(ot) > own, "number over %s is nearer its own head than %s's" % [top, ot])


func test_tall_far_row_monster_gets_number_beside_its_head() -> void:
	var top_h := 74.0   # Stone Sentinel
	var feet := Layout.slot_pos(1, 0, 0) + Vector2(10, 10)
	var top := feet - Vector2(0, top_h)
	var p := FX.number_anchor(top, top_h, -1, BAND, true)
	check(p.y - FX.NUM_RISE - FX.NUM_H - FX.HEAD_H >= BAND - 0.5, "tall unit's number clears the band")
	check(absf(p.x - top.x) <= 22.0, "tall unit's number stays within its span (dx %.0f)" % (p.x - top.x))
	check(p.y < feet.y - top_h * 0.5, "tall unit's number sits on its upper half")
