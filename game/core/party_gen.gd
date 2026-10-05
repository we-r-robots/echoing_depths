extends RefCounted
## Seeded party generators for demos, tests, benchmarks and PvE encounters.

const Rng = preload("res://core/rng.gd")
const GameData = preload("res://core/game_data.gd")
const Alignment = preload("res://core/alignment.gd")
const Formation = preload("res://core/formation.gd")

const NAMES := ["Brakka", "Ilse", "Moth", "Corin", "Vael", "Tamsin", "Oren", "Sable", "Wren", "Hale",
	"Ysolde", "Pell", "Dagny", "Fenn", "Liora", "Ash"]

## A random but valid player party.
## opts: "size" (2..4, default 4), "advanced_chance" (0..1, default 0.35),
##   "shape" (force a shape id, "strays" or "unformed"), "unlocked" (Array of unlocked shape ids; default all,
##   so generated parties show their shape; pass [] for "nothing unlocked").
## The layout is a random shape of that size (or Strays) at a random height/mirror; classes are
## then picked per slot, leaning melee in front and casters behind (75%), as a player would.
static func random_party(rng: Rng, opts: Dictionary = {}) -> Dictionary:
	var size := int(opts.get("size", 4))
	var adv_chance := float(opts.get("advanced_chance", 0.35))
	var layout := random_layout(rng, size, String(opts.get("shape", "")))
	var picks: Array = []
	var slots: Array = []
	for cell: Array in layout:
		var front := int(cell[0]) == 0
		var lean := rng.next_float() < 0.75
		var pool: Array = ["fighter", "rogue"] if front == lean else ["healer", "mage"]
		picks.append(pool[rng.int_range(0, 1)])
		slots.append(cell)
	var heroes: Array = []
	var used_names := {}
	for i in size:
		var base: String = picks[i]
		var cid := base
		var pos := Alignment.start_for(base)
		if rng.next_float() < adv_chance:
			pos = [rng.int_range(-2, 2), rng.int_range(-2, 2)]
			var adv := Alignment.advanced_class_for(base, pos)
			if adv != "":
				cid = adv
		var items := {"weapon": "", "armor": "", "relic": ""}
		for slot: String in GameData.Items.SLOTS:
			if rng.next_float() < 0.5:
				var choices: Array = []
				for iid: String in GameData.Items.ITEMS:
					if String(GameData.Items.ITEMS[iid]["slot"]) == slot:
						choices.append(iid)
				items[slot] = choices[rng.int_range(0, choices.size() - 1)]
		var hname: String = NAMES[rng.int_range(0, NAMES.size() - 1)]
		while used_names.has(hname):
			hname = NAMES[(NAMES.find(hname) + 1) % NAMES.size()]
		used_names[hname] = true
		heroes.append({"name": hname, "class": cid,
			"level": rng.int_range(1, GameData.max_level(cid) - (2 if cid == base else 0)),
			"items": items, "alignment": pos, "slot": slots[i]})
	var unlocked: Array = opts.get("unlocked", all_shapes())
	return {"name": "Party", "heroes": heroes, "unlocked_formations": unlocked.duplicate()}


static func _as_heroes(cells: Array) -> Array:
	var out: Array = []
	for c: Array in cells:
		out.append({"slot": c})
	return out


## Every shape id (all unlocked).
static func all_shapes() -> Array:
	var out: Array = []
	for sh: Dictionary in GameData.Formations.SHAPES:
		out.append(sh["id"])
	return out


## Slots for a random shape of `size` heroes (or `shape_id` if given), at a random height and
## mirror. "strays" = no two units edge-adjacent; "unformed" = partly joined but no shape.
static func random_layout(rng: Rng, size: int, shape_id: String = "") -> Array:
	var shapes: Array = []
	for sh: Dictionary in GameData.Formations.SHAPES:
		if int(sh["size"]) == size and (shape_id == "" or sh["id"] == shape_id):
			shapes.append(sh)
	var pick := rng.int_range(0, shapes.size()) if shape_id == "" else (0 if not shapes.is_empty() else shapes.size())
	if pick >= shapes.size():   # Strays (or Unformed when asked)
		var want := "unformed" if shape_id == "unformed" else "strays"
		for _attempt in 400:
			var cells: Array = []
			var used := {}
			while cells.size() < size:
				var c := [rng.int_range(0, 1), rng.int_range(0, 3)]
				if not used.has(c[0] * 4 + c[1]):
					used[c[0] * 4 + c[1]] = true
					cells.append(c)
			var st := String(Formation.effective({"heroes": _as_heroes(cells), "unlocked_formations": []})["state"])
			if st == want:
				return cells
		return [[0, 0], [1, 1], [0, 2], [1, 3]].slice(0, size) if want == "strays" else [[0, 0], [0, 1], [1, 3], [0, 3]].slice(0, size)
	var sh: Dictionary = shapes[pick]
	var cells2: Array = (sh["cells"] as Array).duplicate(true)
	if bool(sh["mirror"]) and rng.next_float() < 0.5:
		cells2 = Formation._flip(cells2)
	var h := 0
	for c: Array in cells2:
		h = maxi(h, int(c[1]) + 1)
	var off := rng.int_range(0, 4 - h)
	var out: Array = []
	for c: Array in cells2:
		out.append([int(c[0]), int(c[1]) + off])
	return out


## One canonical 4-hero placement per tetromino, plus a Strays placement (kept for probes/tools).
const LAYOUTS := [
	[[0, 0], [0, 1], [0, 2], [0, 3]],   # seawall
	[[1, 0], [1, 1], [1, 2], [1, 3]],   # lumari_chorus
	[[0, 0], [0, 1], [1, 0], [1, 1]],   # vault_door
	[[0, 0], [0, 1], [0, 2], [1, 0]],   # crescent
	[[0, 0], [1, 0], [1, 1], [1, 2]],   # lighthouse
	[[0, 0], [0, 1], [0, 2], [1, 1]],   # keepers_ring
	[[0, 1], [1, 0], [1, 1], [1, 2]],   # shardpoint
	[[0, 0], [0, 1], [1, 1], [1, 2]],   # echo_step
	[[0, 0], [0, 3], [1, 1], [1, 2]],   # strays
]


## Front slots go to classes that prefer the front (helper for tools that pick classes first).
static func _assign_slots(picks: Array, layout: Array) -> Array:
	var front: Array = []
	var back: Array = []
	for s: Array in layout:
		(front if int(s[0]) == 0 else back).append(s)
	var order: Array = []
	for i in picks.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var pa := int(GameData.get_class_def(picks[a])["preferred_col"])
		var pb := int(GameData.get_class_def(picks[b])["preferred_col"])
		return pa < pb or (pa == pb and a < b))
	var slots: Array = []
	slots.resize(picks.size())
	var all_slots: Array = front + back
	for k in order.size():
		slots[order[k]] = all_slots[k]
	return slots


## Hand-built showcase party used by demos.
static func demo_party() -> Dictionary:
	return {"name": "Lantern Company", "heroes": [
		{"name": "Brakka", "class": "fighter", "level": 3, "items": {"weapon": "iron_sword", "armor": "chain_mail", "relic": ""},
			"alignment": [0, 1], "slot": [0, 1]},
		{"name": "Sable", "class": "rogue", "level": 3, "items": {"weapon": "twin_daggers", "armor": "", "relic": ""},
			"alignment": [-1, -1], "slot": [1, 0]},
		{"name": "Ilse", "class": "healer", "level": 3, "items": {"weapon": "oak_staff", "armor": "silk_robe", "relic": "dawn_locket"},
			"alignment": [1, 1], "slot": [1, 1]},
		{"name": "Vael", "class": "mage", "level": 3, "items": {"weapon": "crystal_wand", "armor": "", "relic": ""},
			"alignment": [1, -1], "slot": [1, 2]}], "unlocked_formations": all_shapes()}


## A rival party (stands in for an Echo in demos).
static func demo_rival() -> Dictionary:
	return {"name": "Echo of the Ashen Pact", "heroes": [
		{"name": "Corin", "class": "fighter", "level": 4, "items": {"weapon": "rusty_blade", "armor": "padded_vest", "relic": ""},
			"alignment": [0, 1], "slot": [0, 0]},
		{"name": "Moth", "class": "rogue", "level": 3, "items": {"weapon": "iron_sword", "armor": "shadow_cloak", "relic": "ashen_idol"},
			"alignment": [-1, -1], "slot": [0, 1]},
		{"name": "Tamsin", "class": "mage", "level": 3, "items": {"weapon": "oak_staff", "armor": "", "relic": ""},
			"alignment": [1, -1], "slot": [0, 2]},
		{"name": "Oren", "class": "healer", "level": 2, "items": {"weapon": "", "armor": "silk_robe", "relic": ""},
			"alignment": [1, 1], "slot": [1, 1]}], "unlocked_formations": all_shapes()}


## A Vault monster group scaled by depth (1..). Deterministic from rng.
## Scaling is deliberately gentle (3-4 monsters, level 3 + (depth-1)/3): encounters stay a real
## fight for a party at the matching stage of a run. Duplicate kinds are lettered ("Hollow Rat B").
static func monster_group(rng: Rng, depth: int) -> Dictionary:
	var ids: Array = GameData.Classes.MONSTER_IDS
	var count := 3 if depth < 6 else 4
	@warning_ignore("integer_division")
	var level := clampi(3 + (depth - 1) / 3, 1, 10)
	var heroes: Array = []
	var used := {}
	for i in count:
		var mid: String = ids[rng.int_range(0, ids.size() - 2)]   # golem reserved for bosses
		var col := int(GameData.get_class_def(mid)["preferred_col"])
		var row := 0
		while used.has(col * 4 + row):
			row += 1
			if row > 3:
				row = 0
				col = 1 - col
		used[col * 4 + row] = true
		heroes.append({"name": GameData.get_class_def(mid)["name"], "class": mid,
			"level": level, "items": {}, "alignment": [0, 0], "slot": [col, row]})
	var kinds := {}
	for h: Dictionary in heroes:
		kinds[h["class"]] = int(kinds.get(h["class"], 0)) + 1
	var seen := {}
	for h: Dictionary in heroes:
		if int(kinds[h["class"]]) > 1:
			var n := int(seen.get(h["class"], 0))
			seen[h["class"]] = n + 1
			h["name"] = "%s %s" % [h["name"], "ABCDEFGH"[n]]
	return {"name": "Vault Monsters", "heroes": heroes}
