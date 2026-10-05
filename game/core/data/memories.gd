extends RefCounted
## Memories released by the Crystal of Remembrance (spec 06-crystal-of-remembrance.md).
## Authored characters and moments, not generic monsters. Horizontal, not vertical: every memory
## is about as strong as the others; each brings a different BEHAVIOUR to answer.
## Chapters follow 01-world-and-lore.md "True History": 1 common folk, 2 the Lumari, 3 the draw
## and the sealing, 4 the Keeper. The run picks the sequence from story progress.
##
## A memory uses the class schema (stats/growth/crit/charge/basic/ability, looked up by
## GameData.get_class_def) plus: chapter, lore (one line, in the game's voice), behaviour {id, ...}.
## Memory behaviours are implemented in combat_sim.gd and cued as formation_proc events with
## source "memory:<id>".

const MEMORIES := {
	"lamplighters_child": {"name": "The Lamplighter's Child", "tier": "memory", "base": "memory", "chapter": 1,
		"lore": "She carried the wick-flame from house to house, and the Crystal kept her still carrying it.",
		"stats": {"hp": 170, "atk": 12, "def": 14, "mag": 26, "spd": 11}, "growth": {"hp": 0, "atk": 0, "def": 0, "mag": 0, "spd": 0},
		"crit": 0.05, "charge_on_act": 30, "charge_on_hit": 1.0, "start_charge": 30,
		"basic": "kindle", "ability": "mend", "preferred_col": 1,
		"behaviour": {"id": "kindle", "name": "Kindle", "text": "Her every action warms the other memories: she heals the most hurt one."}},
	"ferryman": {"name": "The Ferryman Who Waited", "tier": "memory", "base": "memory", "chapter": 1,
		"lore": "He waited at the crossing for passengers the tide had already taken. He is still waiting.",
		"stats": {"hp": 285, "atk": 22, "def": 24, "mag": 8, "spd": 8}, "growth": {"hp": 0, "atk": 0, "def": 0, "mag": 0, "spd": 0},
		"crit": 0.05, "charge_on_act": 25, "charge_on_hit": 1.4, "start_charge": 20,
		"basic": "strike", "ability": "cleave", "preferred_col": 0,
		"behaviour": {"id": "shield_crystal", "name": "Stand in the crossing", "every": 2,
			"text": "While he stands, every second hit aimed at the Crystal lands on him instead."}},
	"miller": {"name": "The Miller's Last Harvest", "tier": "memory", "base": "memory", "chapter": 1,
		"lore": "The last good harvest before the grey came. He remembers every sack, and who never came to collect it.",
		"stats": {"hp": 240, "atk": 24, "def": 18, "mag": 6, "spd": 9}, "growth": {"hp": 0, "atk": 0, "def": 0, "mag": 0, "spd": 0},
		"crit": 0.08, "charge_on_act": 25, "charge_on_hit": 1.2, "start_charge": 25,
		"basic": "slam", "ability": "quake", "preferred_col": 0,
		"behaviour": {"id": "harvest", "name": "Grief of the harvest", "per_fallen": 0.25,
			"text": "He hits 25% harder for each memory that has fallen."}},
	"weaver": {"name": "The Weaver of Names", "tier": "memory", "base": "memory", "chapter": 1,
		"lore": "She wove every child's name into a cloth so the Fading could not take them. It took the cloth.",
		"stats": {"hp": 180, "atk": 8, "def": 12, "mag": 25, "spd": 11}, "growth": {"hp": 0, "atk": 0, "def": 0, "mag": 0, "spd": 0},
		"crit": 0.06, "charge_on_act": 25, "charge_on_hit": 0.8, "start_charge": 25,
		"basic": "flicker", "ability": "unravel", "preferred_col": 1,
		"behaviour": {"id": "mirror", "name": "Woven likeness", "amount": 0.25,
			"text": "She copies the heroes' formation: against a guarding shape she takes 25% less damage, against an attacking shape she deals 25% more."}},
	"lumari_knight": {"name": "A Lumari Knight's Last Stand", "tier": "memory", "base": "memory", "chapter": 2,
		"lore": "She held the Vault door while her people were written into the crystal. She is holding it still.",
		"stats": {"hp": 220, "atk": 25, "def": 20, "mag": 12, "spd": 10}, "growth": {"hp": 0, "atk": 0, "def": 0, "mag": 0, "spd": 0},
		"crit": 0.08, "charge_on_act": 25, "charge_on_hit": 1.0, "start_charge": 25,
		"basic": "strike", "ability": "riposte", "preferred_col": 0,
		"behaviour": {"id": "last_stand", "name": "Last stand",
			"text": "The first blow that would fell her leaves her standing at 1 HP, fully charged."}},
	"the_draw": {"name": "The Draw", "tier": "memory", "base": "memory", "chapter": 3,
		"lore": "The moment the Lumari first pulled memory out of the world and into the crystals. It felt like nothing at all.",
		"stats": {"hp": 190, "atk": 8, "def": 12, "mag": 24, "spd": 12}, "growth": {"hp": 0, "atk": 0, "def": 0, "mag": 0, "spd": 0},
		"crit": 0.05, "charge_on_act": 25, "charge_on_hit": 0.8, "start_charge": 25,
		"basic": "flicker", "ability": "siphon", "preferred_col": 1,
		"behaviour": {"id": "draw_memory", "name": "Draw", "amount": 20,
			"text": "Each of its basic attacks draws 20 charge out of the most charged hero and into itself."}},
	"the_sealing": {"name": "The Sealing", "tier": "memory", "base": "memory", "chapter": 3,
		"lore": "Bodies given up, selves written into stone. The Vault closed over them like water.",
		"stats": {"hp": 195, "atk": 8, "def": 14, "mag": 22, "spd": 10}, "growth": {"hp": 0, "atk": 0, "def": 0, "mag": 0, "spd": 0},
		"crit": 0.05, "charge_on_act": 25, "charge_on_hit": 0.8, "start_charge": 25,
		"basic": "bolt", "ability": "shard_burst", "preferred_col": 1,
		"behaviour": {"id": "hasten_fading", "name": "Close the Vault", "ms": 1000,
			"text": "Each of its turns brings the Fading 1 s closer."}},
	"the_keeper": {"name": "The Keeper", "tier": "memory", "base": "memory", "chapter": 4,
		"lore": "The one who stayed outside with the lantern. The Crystal remembers him younger, before he spent his name on the light.",
		"stats": {"hp": 225, "atk": 14, "def": 18, "mag": 24, "spd": 10}, "growth": {"hp": 0, "atk": 0, "def": 0, "mag": 0, "spd": 0},
		"crit": 0.05, "charge_on_act": 25, "charge_on_hit": 1.0, "start_charge": 25,
		"basic": "smite", "ability": "sanctuary", "preferred_col": 0,
		"behaviour": {"id": "dim_lantern", "name": "Dim the lantern",
			"text": "While he stands, the heroes' formation behaviours go dark (their stat bonuses remain)."}},
}

## Default sequence (chapter 1): one at the start, then one per fragment 1-3.
const DEFAULT_SEQUENCE := ["ferryman", "lamplighters_child", "miller", "weaver"]

## Crystal tuning.
const CRYSTAL := {"integrity": 360, "def": 22, "mag": 22, "fragments": 4}
