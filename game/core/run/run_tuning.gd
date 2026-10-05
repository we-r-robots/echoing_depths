extends RefCounted
## Run-layer tuning. Every number is a placeholder pending balance (spec 03 / 04).
## Sized by the Memory Supply table in 03-runs-and-combat.md: core uses the "3 + 3" scheme
## (advance at 3 memories, base max level 6 for Holding Back, advanced max level 4 = 3 more
## memories before the Legendary gate). A run has 16 non-PvP encounters, inside the
## 12 ("all 4 Advanced") .. 24 ("full party maxed") window.

const RUN := {
	# --- run arc (hidden map; never player-facing) ---
	# One string per Vault floor, one letter per node: E encounter, P PvP, G floor guardian
	# (tougher than the floor's PvP), H the Vault Heart (the last guardian).
	"floors": ["EEEPEG", "EPEPEG", "EPEPEG", "EPEPEG", "EPEPEH"],
	"phase_by_floor": ["gathering", "gathering", "advancement", "advancement", "legend"],
	"layer_width_min": 2,        # parallel encounter nodes per map layer
	"layer_width_max": 3,
	# --- encounter kind weights per phase (recruitment prominent while Gathering) ---
	"kind_weights": {
		"gathering": {"recruitment": 4, "riddle": 2, "chance": 2, "moral": 2, "monster": 2},
		"advancement": {"recruitment": 1, "riddle": 2, "chance": 2, "moral": 2, "monster": 3},
		"legend": {"recruitment": 0, "riddle": 2, "chance": 2, "moral": 2, "monster": 3},
	},
	# --- party ---
	"start_pool_size": 3,        # heroes offered at run start (Tavern widens this; distinct base classes)
	"start_picks": 2,
	"max_party": 4,
	"advance_threshold": 3,      # memories at base tier before Advance / Hold Back is offered
	# --- health ("lanterns") ---
	"max_health": 10,
	"pvp_loss_health": 1,
	"monster_loss_health": 1,
	"rest_heal": 1,              # a rest choice (some encounters): +1 health, no memory at that node
	# --- fights ---
	"monster_level_base": 1,     # monster level = base + layer / monster_level_per_layers
	"monster_level_per_layers": 4,
	"monster_count_min": 2,      # monster count = party size, clamped to [min, max]
	"monster_count_max": 4,
	# floor guardians and the Vault Heart (name, intro, monsters, level, loss_health): guardians.json
	"item_drop_chance": 0.5,     # chance a won monster fight drops an item
	# PvP matching by floor: an opponent is an Echo recorded on the same floor (nearest if thin)
	"echo_recent_per_floor": 20, # pick among the most recent real Echoes of that floor
	"echo_min_real": 4,          # below this many real Echoes on a floor, generated ones join in
	"echo_pool_max": 600,        # oldest player Echoes dropped past this (generated seeds kept)
	"echo_seed_per_floor": 6,    # generated Echoes per floor in a fresh pool
	# --- rewards (Glimmers: 04-meta-progression) ---
	"glimmers_per_layer": 1,     # depth reached
	"glimmers_per_pvp_win": 4,
	"glimmers_per_new_floor": 4, # depth milestone: first time reaching a floor (one-time)
	"glimmers_per_shard": 100,   # meta reference: Glimmers that form a Shard
	"victory_shards": 1,         # a victory = a full Shard, worth several losing runs
	"lore_chance": 0.25,         # riddle / moral nodes carrying a lore item
}

const LORE_ITEMS := ["cracked_lumari_tablet", "keepers_wick", "faded_songbook", "vault_census_page",
	"crystal_seed", "ribbon_of_names", "first_fading_ledger", "lamplighters_note"]

const VAULT_HEART_MEMORIES := ["heart_of_the_drowned_archive", "heart_of_the_first_draw",
	"heart_of_the_sealing", "heart_of_the_lantern"]

const VAULTS := ["The Drowned Archive", "The Hollow Choir", "The Glass Ossuary", "The Sunken Lantern"]

const HERO_NAMES := ["Brakka", "Ilse", "Moth", "Corin", "Vael", "Tamsin", "Oren", "Sable", "Wren",
	"Hale", "Ysolde", "Pell", "Dagny", "Fenn", "Liora", "Ash", "Brannoc", "Vesper", "Isolde", "Quill"]

## Team names ("The <epithet> <company>"): a run's party name unless the player picks one, and the
## names of generated Echoes. 24 x 24 = 576 combinations, all <= 32 characters.
const TEAM_EPITHETS := ["Ashen", "Gray", "Lantern", "Hollow", "Quiet", "Last", "Drowned", "Unlit",
	"Crystal", "Faded", "Sleepless", "Oathbound", "Wandering", "Forgotten", "Ember", "Silent",
	"Mended", "Lumari", "Nameless", "Waning", "Dawnless", "Glass", "Hearth", "Kindled"]
const TEAM_COMPANIES := ["Pact", "Choir", "Watch", "Oath", "Company", "Wardens", "Lanterns", "Vigil",
	"Remnant", "Covenant", "Pilgrims", "Bell", "Circle", "Banner", "Wake", "Sworn", "Kin",
	"Procession", "Candles", "Hounds", "Tide", "Keepers", "Ledger", "Chorus"]

## Strength score used to match Echoes: base level, advanced 5 + level, legendary 9 + level.
const TIER_POWER := {"base": 0, "advanced": 5, "legendary": 9}

## Legendary gate (05-formations.md; logic in core/run/legend_gate.gd, swappable): eligible from
## advanced level 3; each later encounter node rolls a rising chance to become that hero's
## legend's memory; at most once per run. The 1-per-party Legendary cap stays (core).
const LEGEND_GATE := {
	"min_advanced_level": 3,
	"base_chance": 0.08,
	"step": 0.08,                # added after each eligible node where it does not appear
	"cap": 0.60,
}
