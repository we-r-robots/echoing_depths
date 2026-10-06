extends RefCounted
## Actions: basic attacks and charged abilities share one schema.
##
## name:      display name.
## kind:      "basic" or "ability" (informational; the sim decides by charge).
## target:    primary target selector (see README "Targeting").
## duration:  seconds the action occupies the timeline.
## impact:    seconds after action start when effects land (wind-up for animation).
## area:      optional; overrides the action_start "area" (e.g. a primary hit + splash on everyone).
## anim:      hint for the battle scene ("melee", "shoot", "cast", "heal", "slam"...).
## effects:   applied in order. Each effect:
##   op:     "damage" | "heal" | "charge"
##   to:     "primary" | "primary_adjacent" | "primary_column" | "primary_column_rest" |
##           "other_enemies" (all enemies except the primary) | "melee_enemy" (whoever melee
##           targeting would hit, e.g. a healer's smite rider) | "all_enemies" |
##           "front_enemies" | "front_random" | "self" | "all_allies" | "lowest_hp_ally" | "random_enemy"
##   kind:   "physical" | "magic"            (damage)
##   power:  multiplier                       (damage / heal; heal scales with Mag)
##   hits:   repeat count, each hit re-picks if the target is down (default 1)
##   bonus_below_hp: [fraction, mult] -> extra multiplier when target HP% is below
##   drain:  fraction of damage dealt healed to the source
##   amount: charge added (op "charge")
##
## Advanced-class ops (2026-10-06; core/README.md "Advanced class abilities"):
##   op "status":       {status (data/statuses.gd id), to, dur_ms, + per status: value / stat / power /
##                       amount / spread_ms / then (an action id that follows when it expires)}
##   op "steal_charge": {to, amount}: takes up to amount charge from the target and gains it
##   op "swap":         {to}: pulls the foe behind the target (same row, back column) forward
##   op "gauge":        {to, amount}: fills the target's ATB gauge (1.0 = full: it acts next)
##   op "hp_cost":      {to, pct}: the target pays pct of its max HP (never below 1 HP)
##   op "tithe":        {pct, give}: the healthiest ally pays pct max HP, the weakest gets give x that
##   op "link":         {dur_ms}: links the healthiest and the weakest ally (shared damage)
##   op "summon":       {hp_frac}: an echo of the caster in the empty front slot nearest its row
##   op "raise":        {frac, spd_frac}: the most recently fallen unit (either side) returns as a husk
##   op "revive":       {hp_frac}: the first fallen ally stands again (once per fight per caster)
##   op "boon_random":  {to, table: [status or charge entries]}: one random gift
##   heal "overheal_shield": true -> healing past full HP becomes a shield (shield_ms)
##   damage to "column_sweep" (stagger_ms): hits the target's column bottom-up, a space at a time
## New "to"/target selectors: adjacent_allies (effect "adjacency": "edge" | "all"), column_allies,
##   other_allies, primary_neighbours, most_charged_enemy, highest_hp_enemy, random_ally,
##   column_bottom.
## requires / fallback: an ability that needs something to work on ("adjacent_ally", "empty_front",
##   "fallen", "fallen_ally", "two_allies", "tithe", "wounded_other") plays its fallback action
##   instead when there is nothing (the charge is still spent). always: true = never skipped as
##   "nobody to heal".
## short: authored label (20 characters or fewer, effects-as-icons rule); text: the tooltip
##   sentence; icon: an effect icon id (ui/effect_icons) for the UI; provisional: why it may change.

const ACTIONS := {
	# ---------------- basic attacks ----------------
	"strike": {"name": "Strike", "kind": "basic", "target": "melee", "duration": 0.49, "impact": 0.23, "anim": "melee",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.0, "to": "primary"}]},
	"stab": {"name": "Stab", "kind": "basic", "target": "melee", "duration": 0.45, "impact": 0.21, "anim": "melee",
		"effects": [{"op": "damage", "kind": "physical", "power": 0.9, "to": "primary"}]},
	"smite": {"name": "Smite", "kind": "basic", "target": "melee", "duration": 0.49, "impact": 0.26, "anim": "cast",
		"effects": [{"op": "damage", "kind": "magic", "power": 0.7, "to": "primary"}]},
	"bolt": {"name": "Bolt", "kind": "basic", "target": "back_first", "duration": 0.52, "impact": 0.29, "anim": "shoot",
		"effects": [{"op": "damage", "kind": "magic", "power": 0.8, "to": "primary"}]},
	"claw": {"name": "Claw", "kind": "basic", "target": "melee", "duration": 0.45, "impact": 0.23, "anim": "melee",
		"effects": [{"op": "damage", "kind": "physical", "power": 0.85, "to": "primary"}]},
	"slam": {"name": "Slam", "kind": "basic", "target": "melee", "duration": 0.55, "impact": 0.29, "anim": "slam",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.0, "to": "primary"}]},
	"flicker": {"name": "Flicker", "kind": "basic", "target": "lowest_hp_enemy", "duration": 0.49, "impact": 0.26, "anim": "shoot",
		"effects": [{"op": "damage", "kind": "magic", "power": 0.7, "to": "primary"}]},

	"kindle": {"name": "Kindle", "kind": "basic", "target": "melee", "duration": 0.55, "impact": 0.3, "anim": "cast",
		"effects": [{"op": "damage", "kind": "magic", "power": 0.7, "to": "primary"}, {"op": "heal", "power": 0.9, "to": "lowest_hp_ally"}]},

	# ---------------- base class abilities ----------------
	"cleave": {"name": "Cleave", "kind": "ability", "target": "melee", "duration": 0.72, "impact": 0.36, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.9, "to": "primary"}, {"op": "damage", "kind": "physical", "power": 0.8, "to": "primary_adjacent"}]},
	"backstab": {"name": "Backstab", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.65, "impact": 0.33, "anim": "dash",
		"effects": [{"op": "damage", "kind": "physical", "power": 3.2, "to": "primary"}]},
	"mend": {"name": "Mend", "kind": "ability", "target": "lowest_hp_ally", "duration": 0.65, "impact": 0.36, "anim": "heal",
		"effects": [{"op": "heal", "power": 2.2, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.9, "to": "melee_enemy"}]},
	"firestorm": {"name": "Firestorm", "kind": "ability", "target": "back_first", "area": "all_enemies", "duration": 0.85, "impact": 0.45, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.6, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.7, "to": "other_enemies"}]},

	# ---------------- advanced (illustrative) ----------------
	"aegis_strike": {"name": "Aegis Strike", "kind": "ability", "target": "melee", "duration": 0.78, "impact": 0.39, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.7, "to": "primary"}, {"op": "heal", "power": 1.4, "to": "lowest_hp_ally"}]},
	"rampage": {"name": "Rampage", "kind": "ability", "target": "melee", "duration": 0.85, "impact": 0.29, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 0.9, "to": "front_random", "hits": 3}]},
	"riposte": {"name": "Riposte", "kind": "ability", "target": "melee", "duration": 0.65, "impact": 0.33, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.9, "to": "primary"}, {"op": "charge", "amount": 40, "to": "self"}]},
	"execute": {"name": "Execute", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.72, "impact": 0.39, "anim": "dash",
		"effects": [{"op": "damage", "kind": "physical", "power": 2.6, "to": "primary", "bonus_below_hp": [0.4, 1.5]}]},
	"sanctuary": {"name": "Sanctuary", "kind": "ability", "target": "all_allies", "duration": 0.78, "impact": 0.42, "anim": "heal_big",
		"effects": [{"op": "heal", "power": 1.2, "to": "all_allies"}, {"op": "damage", "kind": "magic", "power": 0.9, "to": "melee_enemy"}]},
	"meteor": {"name": "Meteor", "kind": "ability", "target": "back_first", "duration": 0.91, "impact": 0.52, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 2.2, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.7, "to": "primary_adjacent"}]},
	# Warlock, user tweak (round-1 verdicts): a column of Hexfire from the bottom of the foes' back
	# column, hitting each space one at a time up the column.
	"hexfire": {"name": "Hexfire", "kind": "ability", "target": "column_bottom", "area": "column", "duration": 0.85, "impact": 0.42, "anim": "cast_big",
		"short": "Fire up a column", "icon": "status_burn",
		"text": "Hexfire climbs the foes' back column from the bottom, hitting each space in turn (the front column if the back is empty).",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.5, "to": "column_sweep", "stagger_ms": 110}]},
	# ---------------- approved advanced classes (class-verdicts-round1.md) ----------------
	# Fighter
	"shackle": {"name": "Shackle", "kind": "ability", "target": "melee", "duration": 0.78, "impact": 0.39, "anim": "melee_big",
		"short": "Drags back foe fwd", "icon": "status_stun",
		"text": "Hits the front foe in its row, then drags the foe behind it forward and shoves the struck foe back.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.7, "to": "primary"}, {"op": "swap", "to": "primary"}]},
	"drive_on": {"name": "Drive On", "kind": "ability", "target": "self", "duration": 0.72, "impact": 0.36, "anim": "cast",
		"short": "Allies act now", "icon": "stat_spd", "requires": "adjacent_ally", "fallback": "marshal_strike",
		"text": "Each ally beside it acts at once, and each pays a little HP for it. With no ally beside it, it strikes the front foe instead.",
		# "adjacency": "edge" (the four sides) as written; "all" makes it each adjacent (the user's musing)
		"effects": [{"op": "gauge", "to": "adjacent_allies", "adjacency": "edge", "amount": 1.0},
			{"op": "hp_cost", "to": "adjacent_allies", "adjacency": "edge", "pct": 0.06}]},
	"marshal_strike": {"name": "Marshal's Blow", "kind": "ability", "target": "melee", "duration": 0.72, "impact": 0.36, "anim": "melee_big",
		"short": "Hits front foe", "text": "Nobody stands beside it to drive on, so it strikes the front foe hard.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.8, "to": "primary"}]},
	"call_echo": {"name": "Call Echo", "kind": "ability", "target": "self", "duration": 0.78, "impact": 0.42, "anim": "cast_big",
		"short": "Summons its echo", "icon": "status_hidden", "requires": "empty_front", "fallback": "echo_strike",
		"text": "An echo of it steps into an empty front slot and fights with its basic attack until struck down. It doesn't count toward shapes.",
		"effects": [{"op": "summon", "to": "self", "hp_frac": 0.4}]},
	"echo_strike": {"name": "Echo Strike", "kind": "ability", "target": "melee", "duration": 0.72, "impact": 0.36, "anim": "melee_big",
		"short": "Hits front foe", "text": "No front slot is free for an echo, so it strikes the front foe hard.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.9, "to": "primary"}]},
	# Rogue
	"pilfer": {"name": "Pilfer", "kind": "ability", "target": "most_charged_enemy", "duration": 0.65, "impact": 0.33, "anim": "dash",
		"short": "Steals charge", "icon": "stat_charge",
		"text": "Hits the most charged foe and steals some of its charge.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.8, "to": "primary"}, {"op": "steal_charge", "to": "primary", "amount": 30}]},
	"vanishing_cut": {"name": "Vanishing Cut", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.65, "impact": 0.33, "anim": "dash",
		"short": "Strike, then vanish", "icon": "status_hidden",
		"text": "Hits the weakest foe, then is hidden for a moment: no single-target attack can pick it.",
		"effects": [{"op": "damage", "kind": "physical", "power": 2.4, "to": "primary"},
			{"op": "status", "status": "hidden", "to": "self", "dur_ms": 2000}]},
	"slow_venom": {"name": "Slow Venom", "kind": "ability", "target": "highest_hp_enemy", "duration": 0.65, "impact": 0.33, "anim": "cast",
		"short": "Poisons healthiest", "icon": "status_poison",
		"text": "Poisons the healthiest foe for heavy damage over several seconds. Stacks up to three times.",
		"effects": [{"op": "status", "status": "poison", "to": "primary", "dur_ms": 6000, "power": 0.55}]},
	"unseen_arrest": {"name": "Unseen Arrest", "kind": "ability", "target": "self", "duration": 0.55, "impact": 0.25, "anim": "cast",
		"short": "Unseen arrest", "icon": "status_stun",
		"text": "Slips out of sight for a moment, then stuns the most charged foe and blinds the foes beside it.",
		"effects": [{"op": "status", "status": "hidden", "to": "self", "dur_ms": 1500, "then": "unseen_arrest_strike"}]},
	"unseen_arrest_strike": {"name": "Unseen Arrest", "kind": "ability", "target": "most_charged_enemy", "duration": 0.72, "impact": 0.36, "anim": "dash",
		"short": "Stuns, blinds beside", "icon": "status_stun",
		"text": "Out of nowhere: stuns the most charged foe and blinds the foes beside it.",
		"effects": [{"op": "status", "status": "stun", "to": "primary", "dur_ms": 2500},
			{"op": "status", "status": "blind", "to": "primary_neighbours", "dur_ms": 4000}]},
	# Healer
	"bind_lives": {"name": "Bind Lives", "kind": "ability", "target": "lowest_hp_ally", "duration": 0.72, "impact": 0.39, "anim": "cast",
		"short": "Binds two lives", "icon": "status_link", "requires": "two_allies", "fallback": "mender_smite",
		"text": "Links the healthiest and the weakest ally: for a few seconds they split all damage either takes.",
		"effects": [{"op": "link", "to": "primary", "dur_ms": 5000}]},
	"mender_smite": {"name": "Smite", "kind": "ability", "target": "melee", "duration": 0.65, "impact": 0.36, "anim": "cast",
		"short": "Hits front foe", "text": "With no two allies to bind, it smites the front foe.",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.4, "to": "primary"}]},
	"lumen_ward": {"name": "Lumen Ward", "kind": "ability", "target": "all_allies", "duration": 0.78, "impact": 0.42, "anim": "heal_big", "always": true,
		"short": "Heals all + shields", "icon": "status_shield",
		"text": "A small heal on every ally; healing past full HP becomes a shield of that size.",
		"effects": [{"op": "heal", "power": 0.8, "to": "all_allies", "overheal_shield": true, "shield_ms": 6000}]},
	"rekindle": {"name": "Rekindle", "kind": "ability", "target": "lowest_hp_ally", "duration": 0.85, "impact": 0.45, "anim": "heal_big",
		"short": "Relights a fallen", "icon": "stat_heal", "requires": "fallen_ally", "fallback": "rekindle_mend",
		"text": "Brings the first fallen ally back at low HP, once per fight; otherwise heals the weakest ally.",
		"effects": [{"op": "revive", "to": "primary", "hp_frac": 0.3}]},
	"rekindle_mend": {"name": "Kindle Mend", "kind": "ability", "target": "lowest_hp_ally", "duration": 0.65, "impact": 0.36, "anim": "heal",
		"short": "Heal ally + hit foe", "text": "Nobody to relight: heals the weakest ally and smites the front foe.",
		"effects": [{"op": "heal", "power": 2.2, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.9, "to": "melee_enemy"}]},
	"tithe": {"name": "Tithe", "kind": "ability", "target": "lowest_hp_ally", "duration": 0.72, "impact": 0.39, "anim": "cast",
		"short": "Tithes the strong", "icon": "stat_hp", "requires": "tithe", "fallback": "mender_smite",
		"text": "Takes HP from the healthiest ally and gives more of it back to the weakest.",
		"effects": [{"op": "tithe", "to": "primary", "pct": 0.12, "give": 1.6}]},
	"burn_to_mend": {"name": "Burn to Mend", "kind": "ability", "target": "all_allies", "duration": 0.78, "impact": 0.42, "anim": "heal_big",
		"short": "Burns HP to heal all", "icon": "stat_heal", "requires": "wounded_other", "fallback": "mender_smite",
		"text": "Spends a share of its own HP to heal every other ally by more.",
		"effects": [{"op": "hp_cost", "to": "self", "pct": 0.12}, {"op": "heal", "power": 1.4, "to": "other_allies"}]},
	# Confessor: mechanic as written; flavour, name and short text are flame-themed (user note)
	"brand_of_flame": {"name": "Brand of Flame", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.72, "impact": 0.39, "anim": "cast_big",
		"short": "Brand: no healing", "icon": "status_heal_block",
		"text": "Sears the weakest foe with a brand of flame: it can't be healed for a few seconds.",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.6, "to": "primary"},
			{"op": "status", "status": "heal_block", "to": "primary", "dur_ms": 5000}]},
	"raise_husk": {"name": "Raise Husk", "kind": "ability", "target": "self", "duration": 0.85, "impact": 0.45, "anim": "cast_big",
		"short": "Raises a husk", "icon": "status_hidden", "requires": "fallen", "fallback": "grave_bolt",
		"text": "Raises the most recently fallen unit, from either side, as a husk in an empty front slot: much weaker than it was. It doesn't count toward shapes.",
		"effects": [{"op": "raise", "to": "self", "frac": 0.5, "spd_frac": 0.75}]},
	"grave_bolt": {"name": "Grave Bolt", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.72, "impact": 0.39, "anim": "cast_big",
		"short": "Hits weakest foe", "provisional": "Gravecaller's no-one-has-fallen behaviour: the user will decide (round-1 ruling 7).",
		"text": "Nobody has fallen yet, so it strikes the weakest foe with grave cold. (Provisional.)",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.8, "to": "primary"}]},
	# Mage
	"chain_storm": {"name": "Chain Storm", "kind": "ability", "target": "random_enemy", "duration": 0.85, "impact": 0.36, "anim": "cast_big",
		"short": "Random foes x3", "text": "Strikes random foes three times (separate hits, so Strays and Echo Step don't stop it).",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.0, "to": "random_enemy", "hits": 3}]},
	"draw_star": {"name": "Draw a Star", "kind": "ability", "target": "random_ally", "duration": 0.72, "impact": 0.39, "anim": "cast",
		"short": "Random ally buff", "icon": "stat_mag",
		"text": "Gives a random ally one random gift: Atk, Mag or Spd up, a shield, or a burst of charge.",
		"effects": [{"op": "boon_random", "to": "primary", "table": [
			{"op": "status", "status": "boon", "stat": "atk", "value": 0.3, "dur_ms": 6000},
			{"op": "status", "status": "boon", "stat": "mag", "value": 0.3, "dur_ms": 6000},
			{"op": "status", "status": "boon", "stat": "spd", "value": 0.3, "dur_ms": 6000},
			{"op": "status", "status": "shield", "power": 2.0, "dur_ms": 6000},
			{"op": "charge", "amount": 40}]}]},
	"column_ward": {"name": "Column Ward", "kind": "ability", "target": "self", "duration": 0.72, "impact": 0.39, "anim": "cast",
		"short": "Shields its column", "icon": "status_shield",
		"text": "Gives every ally in its column a shield for a few seconds.",
		"effects": [{"op": "status", "status": "shield", "to": "column_allies", "power": 1.8, "dur_ms": 6000}]},
	"rune_seal": {"name": "Rune Seal", "kind": "ability", "target": "most_charged_enemy", "duration": 0.78, "impact": 0.42, "anim": "cast_big",
		"short": "Seals foe's charge", "icon": "status_charge_seal",
		"text": "Runes bind the most charged foe: it is hit and gains no charge for a few seconds.",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.5, "to": "primary"},
			{"op": "status", "status": "charge_seal", "to": "primary", "dur_ms": 4000}]},
	"slow_field": {"name": "Slow the Field", "kind": "ability", "target": "all_enemies", "duration": 0.78, "impact": 0.42, "anim": "cast_big",
		"short": "Slows every foe", "icon": "status_slow",
		"text": "Slows every foe's turn gauge for a few seconds.",
		"effects": [{"op": "status", "status": "slow", "to": "all_enemies", "value": 0.4, "dur_ms": 5000}]},
	"wildfire": {"name": "Wildfire", "kind": "ability", "target": "random_enemy", "duration": 0.78, "impact": 0.42, "anim": "cast_big",
		"short": "Fire that spreads", "icon": "status_burn",
		"text": "Sets a random foe burning; every few seconds the fire jumps to a foe beside it.",
		"effects": [{"op": "damage", "kind": "magic", "power": 0.8, "to": "primary"},
			{"op": "status", "status": "burn", "to": "primary", "dur_ms": 6000, "power": 0.35, "spread_ms": 2000}]},
	"lantern_oath": {"name": "Lantern Oath", "kind": "ability", "target": "melee", "duration": 0.91, "impact": 0.45, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 2.0, "to": "primary"}, {"op": "damage", "kind": "physical", "power": 0.9, "to": "primary_adjacent"}, {"op": "heal", "power": 1.4, "to": "lowest_hp_ally"}]},

	# ---------------- monster abilities ----------------
	"gnaw": {"name": "Gnaw", "kind": "ability", "target": "melee", "duration": 0.65, "impact": 0.23, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 0.95, "to": "primary", "hits": 2}]},
	"unravel": {"name": "Unravel", "kind": "ability", "target": "back_first", "area": "all_enemies", "duration": 0.78, "impact": 0.42, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.4, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.6, "to": "other_enemies"}]},
	"quake": {"name": "Quake", "kind": "ability", "target": "melee", "duration": 0.85, "impact": 0.45, "anim": "slam_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.6, "to": "primary"}, {"op": "damage", "kind": "physical", "power": 0.8, "to": "primary_column_rest"}]},
	"siphon": {"name": "Siphon", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.72, "impact": 0.39, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.7, "to": "primary", "drain": 0.5}]},
	"shard_burst": {"name": "Shard Burst", "kind": "ability", "target": "back_first", "area": "all_enemies", "duration": 0.91, "impact": 0.52, "anim": "cast_big",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.5, "to": "primary"}, {"op": "damage", "kind": "magic", "power": 0.7, "to": "other_enemies"}]},
}
