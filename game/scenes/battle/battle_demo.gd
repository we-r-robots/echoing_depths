extends RefCounted
## Demo fight setups for the battle scene (capture and showcase only; real fights come from the run).
## shape_party() rearranges a party into a named formation so every shape's behaviour can be shown.

const PartyGen = preload("res://core/party_gen.gd")
const GameData = preload("res://core/game_data.gd")

## Per shape: [fight seed, opponent ("pvp" or "monsters"), row offset]. Picked by search so the
## shape's behaviour fires within the first ~2 s of the fight (see captures/battle-scene/r11/shapes/).
const SHAPE_DEMOS := {
	"kindred": [30, "pvp", 0], "vigil": [17, "pvp", 1], "lamplight": [7, "monsters", 0],
	"tidebreak": [41, "monsters", 0], "choir": [1, "pvp", 0], "keystone": [1, "monsters", 0],
	"hearth": [21, "pvp", 0], "seawall": [58, "monsters", 0], "lumari_chorus": [76, "pvp", 0],
	"vault_door": [20, "pvp", 0], "crescent": [30, "monsters", 0], "lighthouse": [58, "monsters", 0],
	"keepers_ring": [58, "monsters", 0], "shardpoint": [30, "pvp", 0], "echo_step": [7, "pvp", 1],
	"strays": [7, "pvp", 0],
}

const MELEE := ["fighter", "rogue"]


static func all_shape_ids() -> Array:
	var out: Array = []
	for s: Dictionary in GameData.Formations.SHAPES:
		out.append(s["id"])
	return out


## The demo party placed in `shape_id` (all shapes unlocked). Front cells get the melee heroes.
## "strays" scatters the party so no two heroes touch.
static func shape_party(shape_id: String, row_off := 0) -> Dictionary:
	var base: Dictionary = PartyGen.demo_party()
	var cells: Array = []
	if shape_id == "strays":
		cells = [[0, 0], [1, 1], [0, 2], [1, 3]]
	else:
		for s: Dictionary in GameData.Formations.SHAPES:
			if s["id"] == shape_id:
				cells = (s["cells"] as Array).duplicate(true)
	if cells.is_empty():
		return base
	var max_row := 0
	for c: Array in cells:
		max_row = maxi(max_row, int(c[1]))
	row_off = clampi(row_off, 0, 3 - max_row)
	var front: Array = []
	var back: Array = []
	for c: Array in cells:
		var cc := [int(c[0]), int(c[1]) + row_off]
		(front if cc[0] == 0 else back).append(cc)
	var melee: Array = []
	var casters: Array = []
	for h: Dictionary in base["heroes"]:
		(melee if MELEE.has(String(h["class"])) else casters).append(h)
	var heroes: Array = []
	for c: Array in front:
		var h: Dictionary = (melee.pop_front() if not melee.is_empty() else casters.pop_front())
		h["slot"] = c
		heroes.append(h)
	for c: Array in back:
		var h2: Dictionary = (casters.pop_front() if not casters.is_empty() else melee.pop_front())
		h2["slot"] = c
		heroes.append(h2)
	return {"name": base["name"], "heroes": heroes, "unlocked_formations": all_shape_ids()}


## The standard demo party with every shape unlocked (so its Shardpoint is live, not Strays).
static func demo_party_unlocked() -> Dictionary:
	var p: Dictionary = PartyGen.demo_party()
	p["unlocked_formations"] = all_shape_ids()
	p["name"] = "The Lanternrest Company"   # the game's default team name (GameState.DEFAULT_TEAM)
	return p


## Round 17: class showcase fights, the approved advanced classes and every timed status, so captures
## cover them. Per sequence: [fight seed, side-0 heroes, side-1 heroes (drawn as an Echo),
## start_statuses (core option: tools only)]. Heroes are [name, class, col, row], all level 4. Seeds
## picked by search so each sequence shows its classes' abilities (and their fallbacks) in ~25-40 s:
##   a  Shackler, Echoblade, Rekindler, Archmage vs Iron Marshal, Unseen Warden, Runebinder, Gravecaller
##      (the swap, summon echo, revive, gauge, stun + skip, blind + miss, seal; runs into the Fading;
##      no one falls before the Gravecaller acts, so it casts its provisional Grave Bolt)
##   b  Fadewalker, Nightshade, Lumenward, Wildfire vs Paladin, Berserker, Threadmender, Confessor
##      (hidden, poison, overheal shield + absorb, burn + spread, link, Brand of Flame + blocked heal)
##   c  Cutpurse, Lampwright, Tithekeeper, Warlock vs Chronist, Wickburner, Starcaller, Gravecaller
##      (Hexfire's column, a husk raised, pilfer, tithe, column ward, slow, boon, burn to mend) plus a
##      hex, a regen and a sap at t = 0
const CLASS_DEMOS := {
	"a": [418, [["Brakka", "shackler", 0, 1], ["Sable", "echoblade", 0, 2], ["Ilse", "rekindler", 1, 1], ["Vael", "archmage", 1, 2]],
		[["Corin", "iron_marshal", 0, 1], ["Moth", "unseen_warden", 0, 2], ["Tamsin", "runebinder", 1, 1], ["Oren", "gravecaller", 1, 2]], []],
	"b": [201, [["Sable", "fadewalker", 0, 1], ["Brakka", "nightshade", 0, 2], ["Ilse", "lumenward", 1, 1], ["Vael", "wildfire", 1, 2]],
		[["Corin", "paladin", 0, 1], ["Moth", "berserker", 0, 2], ["Oren", "threadmender", 1, 1], ["Tamsin", "confessor", 1, 2]], []],
	"c": [559, [["Brakka", "cutpurse", 0, 1], ["Sable", "lampwright", 1, 0], ["Ilse", "tithekeeper", 1, 1], ["Vael", "warlock", 1, 2]],
		[["Corin", "chronist", 1, 1], ["Moth", "wickburner", 1, 2], ["Tamsin", "starcaller", 0, 1], ["Oren", "gravecaller", 1, 0]],
		[{"side": 1, "slot": [0, 1], "status": "heal_invert", "dur_ms": 16000, "src_side": 0, "src_slot": [1, 1]},
			{"side": 0, "slot": [1, 1], "status": "regen", "power": 0.5, "dur_ms": 12000, "src_side": 0, "src_slot": [1, 1]},
			{"side": 1, "slot": [1, 1], "status": "sap", "stat": "def", "value": -0.3, "dur_ms": 12000, "src_side": 0, "src_slot": [1, 2]}]],
}


static func _class_hero(h: Array) -> Dictionary:
	return {"name": h[0], "class": h[1], "level": 4, "items": {}, "alignment": [0, 0], "slot": [h[2], h[3]]}


## [party_a, party_b, seed, sim options] for a class showcase sequence ("a", "b", "c").
static func class_fight(seq: String) -> Array:
	var d: Array = CLASS_DEMOS.get(seq, CLASS_DEMOS["a"])
	var a: Array = []
	var b: Array = []
	for h: Array in d[1]:
		a.append(_class_hero(h))
	for h: Array in d[2]:
		b.append(_class_hero(h))
	var opts := {}
	if not (d[3] as Array).is_empty():
		opts["start_statuses"] = (d[3] as Array).duplicate(true)
	return [{"name": "The Lanternrest Company", "heroes": a, "unlocked_formations": all_shape_ids()},
		{"name": "Echo of the Ashen Pact", "heroes": b, "unlocked_formations": all_shape_ids()}, int(d[0]), opts]
