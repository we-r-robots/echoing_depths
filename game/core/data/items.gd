extends RefCounted
## Equipment. Weapons and armor carry flat stat bonuses only.
## Only Relics carry alignment ("alignment": [good_evil, lawful_chaotic] offset).
## Relics bind on equip (enforced by the run layer, not by combat).

const ITEMS := {
	# weapons
	"rusty_blade": {"name": "Rusty Blade", "slot": "weapon", "stats": {"atk": 3}},
	"iron_sword": {"name": "Iron Sword", "slot": "weapon", "stats": {"atk": 6}},
	"twin_daggers": {"name": "Twin Daggers", "slot": "weapon", "stats": {"atk": 4, "spd": 2}},
	"oak_staff": {"name": "Oak Staff", "slot": "weapon", "stats": {"mag": 5}},
	"crystal_wand": {"name": "Crystal Wand", "slot": "weapon", "stats": {"mag": 8, "hp": -10}},
	"lantern_mace": {"name": "Lantern Mace", "slot": "weapon", "stats": {"atk": 4, "mag": 4}},
	# armor
	"padded_vest": {"name": "Padded Vest", "slot": "armor", "stats": {"def": 3, "hp": 10}},
	"chain_mail": {"name": "Chain Mail", "slot": "armor", "stats": {"def": 6, "spd": -1}},
	"silk_robe": {"name": "Silk Robe", "slot": "armor", "stats": {"mag": 3, "hp": 15}},
	"shadow_cloak": {"name": "Shadow Cloak", "slot": "armor", "stats": {"def": 2, "spd": 2}},
	# relics (alignment offset + small stats)
	"dawn_locket": {"name": "Dawn Locket", "slot": "relic", "stats": {"hp": 10}, "alignment": [1, 0]},
	"ashen_idol": {"name": "Ashen Idol", "slot": "relic", "stats": {"atk": 2}, "alignment": [-1, 0]},
	"oath_seal": {"name": "Oath Seal", "slot": "relic", "stats": {"def": 2}, "alignment": [0, 1]},
	"wild_feather": {"name": "Wild Feather", "slot": "relic", "stats": {"spd": 1}, "alignment": [0, -1]},
	"grave_coin": {"name": "Grave Coin", "slot": "relic", "stats": {"mag": 2}, "alignment": [-1, -1]},
}

const SLOTS := ["weapon", "armor", "relic"]
