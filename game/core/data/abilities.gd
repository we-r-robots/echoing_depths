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
##   delay_ms: lands this many ms after the action's impact (still inside the action), so an
##           action's numbers don't all land at one instant (Whirlwind's allies, Bloodletting's heals)
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
##   status shield "scale": "def" -> the shield is sized from the caster's Def instead of its Mag
## Round-2 ops (2026-10-06; core/README.md "Advanced class abilities"):
##   op "sabotage":     {dur_ms}: every foe gets "sabotage": their side's formation behaviour stops
##   op "drain_heal":   {pct}: pct of the damage this action dealt so far, shared out among all allies
##   op "raise" "nameless": {name, basic, stats}: with nobody fallen, a nameless husk rises instead
## Reactions (not cast directly; their effects are data): riposte_counter (Duelist's parry answer),
##   watch_strike (Nightwatch's catch).
##   damage to "column_sweep" (stagger_ms): hits the target's column bottom-up, a space at a time
## New "to"/target selectors: adjacent_allies (effect "adjacency": "edge" | "all"), column_allies,
##   other_allies, primary_neighbours, most_charged_enemy, highest_hp_enemy, random_ally,
##   column_bottom; round 2: primary_behind (the foe in the back column of the primary's row),
##   strongest_front_enemy / strongest_sealable_enemy (highest of Atk or Mag; ties -> more HP, then
##   lower uid; the sealable one skips units already sealed or crystal-worn).
## requires / fallback: an ability that needs something to work on ("adjacent_ally", "empty_front",
##   "fallen", "fallen_ally", "two_allies", "tithe", "wounded_other", "sealable") plays its fallback action
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
	# Lightsworn (round 2: replaces Paladin and keeps its ability name, Aegis Strike): hit, then shield
	"aegis_strike": {"name": "Aegis Strike", "kind": "ability", "target": "melee", "duration": 0.78, "impact": 0.39, "anim": "melee_big",
		"short": "Hit + shield weakest", "icon": "status_shield",
		"text": "Hits the front foe and gives the lowest-HP ally a shield (sized by its Def) for a few seconds.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.7, "to": "primary"},
			{"op": "status", "status": "shield", "to": "lowest_hp_ally", "power": 1.6, "scale": "def", "dur_ms": 6000}]},
	"rampage": {"name": "Rampage", "kind": "ability", "target": "melee", "duration": 0.85, "impact": 0.29, "anim": "melee_big",
		"effects": [{"op": "damage", "kind": "physical", "power": 0.9, "to": "front_random", "hits": 3}]},
	# Duelist (round-2 rework): a parry stance; the counter and the lunge are data below
	"riposte": {"name": "Riposte", "kind": "ability", "target": "self", "duration": 0.55, "impact": 0.25, "anim": "cast",
		"short": "Parry, then counter", "icon": "status_riposte",
		"text": "Takes guard: the next melee hit on it is parried (no damage) and answered with a critical counter. If nobody swings within a few seconds, it lunges at the front foe instead.",
		"effects": [{"op": "status", "status": "riposte", "to": "self", "dur_ms": 3500, "then": "riposte_lunge",
			"counter": "riposte_counter"}]},
	"riposte_counter": {"name": "Riposte", "kind": "ability", "target": "melee", "duration": 0.45, "impact": 0.2, "anim": "melee_big",
		"short": "Critical counter", "text": "Parried: it answers the attacker with a critical counter.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.9, "to": "primary", "crit": true}]},
	"riposte_lunge": {"name": "Lunge", "kind": "ability", "target": "melee", "duration": 0.65, "impact": 0.33, "anim": "dash",
		"short": "Lunges at front foe", "text": "Nobody swung at it in time, so it lunges at the front foe.",
		"effects": [{"op": "damage", "kind": "physical", "power": 2.0, "to": "primary"}]},
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
		"short": "Chains drag foe fwd", "icon": "status_stun",
		"text": "Its chains lash the front foe in its row, then drag the foe behind it forward and fling the struck foe back.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.7, "to": "primary"}, {"op": "swap", "to": "primary"}]},
	"drive_on": {"name": "Drive On", "kind": "ability", "target": "self", "duration": 0.72, "impact": 0.36, "anim": "cast",
		"short": "Allies act now", "icon": "stat_spd", "requires": "adjacent_ally", "fallback": "marshal_strike",
		"text": "Each ally around it (diagonals too) acts at once, and each pays a little HP for it. With no ally around it, it strikes the front foe instead.",
		# round-2 decision q-6: "adjacent", diagonals included ("all" = the 8 cells around it)
		"effects": [{"op": "gauge", "to": "adjacent_allies", "adjacency": "all", "amount": 1.0},
			{"op": "hp_cost", "to": "adjacent_allies", "adjacency": "all", "pct": 0.06}]},
	"marshal_strike": {"name": "Marshal's Blow", "kind": "ability", "target": "melee", "duration": 0.72, "impact": 0.36, "anim": "melee_big",
		"short": "Hits front foe", "text": "Nobody stands around it to drive on, so it strikes the front foe hard.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.8, "to": "primary"}]},
	"call_echo": {"name": "Call Echo", "kind": "ability", "target": "self", "duration": 0.78, "impact": 0.42, "anim": "cast_big",
		"short": "Summons its echo", "icon": "status_hidden", "requires": "empty_front", "fallback": "echo_strike",
		"text": "An echo of it steps into an empty front slot and fights with its basic attack until struck down. It doesn't count toward shapes.",
		"effects": [{"op": "summon", "to": "self", "hp_frac": 0.4}]},
	"echo_strike": {"name": "Echo Strike", "kind": "ability", "target": "melee", "duration": 0.72, "impact": 0.36, "anim": "melee_big",
		"short": "Hits front foe", "text": "No front slot is free for an echo, so it strikes the front foe hard.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.9, "to": "primary"}]},
	# ---------------- approved advanced classes, round 2 (class-verdicts-round2.md) ----------------
	# Fighter
	"long_reach": {"name": "Long Reach", "kind": "ability", "target": "melee", "duration": 0.78, "impact": 0.39, "anim": "melee_big",
		"short": "Hits front + behind", "icon": "stat_atk",
		"text": "Its polearm hits the front foe and the foe behind it in the same row (a back-column foe takes half, like any physical hit).",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.8, "to": "primary"},
			{"op": "damage", "kind": "physical", "power": 1.4, "to": "primary_behind"}]},
	"break_blade": {"name": "Break Blade", "kind": "ability", "target": "strongest_front_enemy", "duration": 0.78, "impact": 0.39, "anim": "melee_big",
		"short": "Disarms strongest", "icon": "status_disarm",
		"text": "Strikes the weapon from the strongest front foe (highest Atk or Mag): for a few seconds it makes no basic attacks.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.4, "to": "primary"},
			{"op": "status", "status": "disarm", "to": "primary", "dur_ms": 6000}]},
	"whirlwind": {"name": "Whirlwind", "kind": "ability", "target": "melee", "duration": 0.85, "impact": 0.42, "anim": "melee_big",
		"short": "Spins: foes + allies", "icon": "stat_atk",
		"text": "A whirlwind: hits every foe in the front column and every ally around it (diagonals too), hard. With nobody beside it, only foes are hurt.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.5, "to": "front_enemies"},
			{"op": "damage", "kind": "physical", "power": 1.5, "to": "adjacent_allies", "adjacency": "all", "delay_ms": 150}]},
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
	"cut_the_ropes": {"name": "Cut the Ropes", "kind": "ability", "target": "melee", "duration": 0.78, "impact": 0.39, "anim": "melee_big",
		"short": "Halts foe formation", "icon": "status_sabotage",
		"text": "Hits the front foe and cuts the ropes that hold the foes' ranks: their formation behaviour stops for a few seconds (its stat bonus stays).",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.6, "to": "primary"},
			{"op": "sabotage", "to": "self", "dur_ms": 4000}]},
	"keep_watch": {"name": "Keep Watch", "kind": "ability", "target": "self", "duration": 0.55, "impact": 0.25, "anim": "cast",
		"short": "Guards allies beside", "icon": "status_watch", "requires": "adjacent_ally", "fallback": "nightwatch_blow",
		"text": "Keeps watch: the next foe to hit an ally beside it is struck and stunned. With no ally beside it, it strikes the front foe instead.",
		"effects": [{"op": "status", "status": "watch", "to": "self", "dur_ms": 6000, "adjacency": "edge",
			"strike": "watch_strike"}]},
	"watch_strike": {"name": "Caught", "kind": "ability", "target": "melee", "duration": 0.45, "impact": 0.2, "anim": "dash",
		"short": "Strikes and stuns", "text": "Caught in the act: the Nightwatch strikes the foe that hit its neighbour and stuns it.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.3, "to": "primary"},
			{"op": "status", "status": "stun", "to": "primary", "dur_ms": 2000}]},
	"nightwatch_blow": {"name": "Night Blow", "kind": "ability", "target": "melee", "duration": 0.65, "impact": 0.33, "anim": "melee_big",
		"short": "Hits front foe", "text": "Nobody stands beside it to watch over, so it strikes the front foe hard.",
		"effects": [{"op": "damage", "kind": "physical", "power": 1.8, "to": "primary"}]},
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
	# Gravecaller (round-2 q-3): the fallen rise as now; with nobody fallen, a nameless husk of the
	# Vault's long-dead rises instead, weaker than any raised hero (fixed stats, below a raised
	# level-1 Mage, the weakest raised hero: HP 40, budget ~28).
	"raise_husk": {"name": "Raise Husk", "kind": "ability", "target": "self", "duration": 0.85, "impact": 0.45, "anim": "cast_big",
		"short": "Raises a husk", "icon": "status_hidden", "requires": "empty_front", "fallback": "grave_bolt",
		"text": "Raises the most recently fallen unit, from either side, as a husk in an empty front slot: much weaker than it was. With nobody fallen, a nameless husk of the Vault's long-dead rises instead. Husks don't count toward shapes.",
		"effects": [{"op": "raise", "to": "self", "frac": 0.5, "spd_frac": 0.75,
			"nameless": {"name": "Nameless Husk", "basic": "claw",
				"stats": {"hp": 30, "atk": 8, "def": 4, "mag": 2, "spd": 6}}}]},
	"grave_bolt": {"name": "Grave Bolt", "kind": "ability", "target": "lowest_hp_enemy", "duration": 0.72, "impact": 0.39, "anim": "cast_big",
		"short": "Hits weakest foe", "provisional": "Gravecaller with its front column full (no slot for a husk): the user hasn't ruled on this case (round 2).",
		"text": "Its front column is full, so no husk can rise: it strikes the weakest foe with grave cold instead. (Provisional.)",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.8, "to": "primary"}]},
	"bloodletting": {"name": "Bloodletting", "kind": "ability", "target": "all_enemies", "duration": 0.85, "impact": 0.45, "anim": "cast_big",
		"short": "Drain all, heal all", "icon": "stat_heal",
		"text": "Draws a little blood from every foe, then heals all allies from it: part of the damage dealt, shared out among them.",
		# drain starts conservative (user: "might be too strong"): 40% of the damage, split among allies
		"effects": [{"op": "damage", "kind": "magic", "power": 0.5, "to": "all_enemies"},
			{"op": "drain_heal", "to": "all_allies", "pct": 0.4, "delay_ms": 150}]},
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
	# Enshriner (round 2; the name will change, so it is data only). Rules (a)-(d) are PROVISIONAL.
	"enshrine": {"name": "Enshrine", "kind": "ability", "target": "strongest_sealable_enemy", "duration": 0.85, "impact": 0.45, "anim": "cast_big",
		"short": "Seals foe in crystal", "icon": "status_enshrine", "requires": "sealable", "fallback": "shrine_shard",
		"provisional": "Enshriner rules (a)-(d) await the user (round-2 q-9).",
		"text": "Seals the strongest foe (highest Atk or Mag) in crystal for a few seconds: it can't act, nothing can hit it, and its formation loses it. It still counts as standing.",
		"effects": [{"op": "status", "status": "enshrine", "to": "primary", "dur_ms": 3500}]},
	"shrine_shard": {"name": "Shrine Shard", "kind": "ability", "target": "back_first", "duration": 0.72, "impact": 0.39, "anim": "cast_big",
		"short": "Hits a foe", "text": "Nobody can be sealed right now, so it strikes with a crystal shard instead.",
		"effects": [{"op": "damage", "kind": "magic", "power": 1.8, "to": "primary"}]},
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
