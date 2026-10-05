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
	return p
