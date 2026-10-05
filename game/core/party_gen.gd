extends RefCounted
## Seeded party generators for demos, tests, benchmarks and PvE encounters.

const Rng = preload("res://core/rng.gd")
const GameData = preload("res://core/game_data.gd")
const Alignment = preload("res://core/alignment.gd")

const NAMES := ["Brakka", "Ilse", "Moth", "Corin", "Vael", "Tamsin", "Oren", "Sable", "Wren", "Hale",
	"Ysolde", "Pell", "Dagny", "Fenn", "Liora", "Ash"]

## 4-hero slot layouts (each is a known formation shape or a loose layout).
const LAYOUTS := [
	[[0, 0], [0, 1], [1, 0], [1, 1]],   # square
	[[0, 1], [1, 0], [1, 1], [1, 2]],   # shield
	[[0, 0], [0, 1], [0, 2], [1, 1]],   # anvil
	[[0, 1], [0, 2], [0, 3], [1, 1]],   # vanguard
	[[0, 1], [1, 1], [1, 2], [1, 3]],   # watchtower
	[[0, 1], [0, 2], [1, 2], [1, 3]],   # staggered
	[[0, 0], [0, 1], [0, 2], [0, 3]],   # wall
	[[1, 0], [1, 1], [1, 2], [1, 3]],   # rearguard
	[[0, 0], [0, 3], [1, 1], [1, 2]],   # loose
]


## A random but valid player party.
## opts: "size" (default 4), "advanced_chance" (0..1, default 0.35)
static func random_party(rng: Rng, opts: Dictionary = {}) -> Dictionary:
	var size := int(opts.get("size", 4))
	var adv_chance := float(opts.get("advanced_chance", 0.35))
	var bases: Array = GameData.Classes.BASE_CLASS_IDS
	var picks: Array = []
	for i in size:
		picks.append(bases[rng.int_range(0, bases.size() - 1)])
	# plausible formation: enough front slots for the melee classes, melee in front first
	var layout: Array = _pick_layout(rng, picks) if size == 4 else _line_layout(size)
	var slots := _assign_slots(picks, layout)
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
	return {"name": "Party", "heroes": heroes}


static func _pick_layout(rng: Rng, picks: Array) -> Array:
	var melee := 0
	for cid: String in picks:
		if int(GameData.get_class_def(cid)["preferred_col"]) == 0:
			melee += 1
	var fits: Array = []
	for lay: Array in LAYOUTS:
		var front := 0
		for s: Array in lay:
			if int(s[0]) == 0:
				front += 1
		if front >= maxi(1, melee):
			fits.append(lay)
	return fits[rng.int_range(0, fits.size() - 1)]


static func _line_layout(size: int) -> Array:
	var out: Array = []
	for i in size:
		out.append([i % 2, i >> 1])
	return out


## Front slots go to classes that prefer the front.
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
			"alignment": [1, -1], "slot": [1, 2]}]}


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
			"alignment": [1, 1], "slot": [1, 1]}]}


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
