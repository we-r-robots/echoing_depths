extends RefCounted
## Timed statuses (the shared status system). All numbers are placeholders pending balance.
## Durations are milliseconds of fight time (the same clock as the Fading); ticks and expiries
## land between actions, never inside one (core/README.md "Statuses").
##
## Ruling 2 (user, 2026-10-06): ALL status damage is non-physical. Poison and burn ticks are
## kind "status": the back-column halving never applies to them, in either direction.
##
## Per status:
##   name:   display name ("Stunned").
##   short:  label of 20 characters or fewer (effects-as-icons rule); text: the tooltip sentence.
##   icon:   effect icon id in ui/effect_icons (EffectIcons.status_icon).
##   sign:   1 helpful / -1 harmful (for the ▲ / ▼ marker).
##   stack:  how a second application on the same unit combines (same key):
##           "refresh" = one instance; the duration becomes the longer of the two, the value the
##                       larger (by size).
##           "stack"   = one instance with stacks (up to max_stacks); each application adds its
##                       value and refreshes the duration.
##           "replace" = the new application replaces the old one.
##   keyed:  "stat" = one instance per stat (sap / boon: Atk and Def saps are separate).
##   tick:   ms between ticks (damage or healing over time); 0 = no ticks.
##   kind:   what the sim does with it (see core/README.md):
##           "stun" "blind" "stat" "slow" "dot" "regen" "shield" "hidden" "heal_block"
##           "heal_invert" "charge_seal" "link"
##           and (round-2 classes, 2026-10-06) "disarm" "sabotage" "riposte" "watch" "enshrine"
##           "seal_immune"

const STATUSES := {
	"stun": {"name": "Stunned", "short": "Loses its turns", "icon": "status_stun", "sign": -1,
		"stack": "refresh", "tick": 0, "kind": "stun",
		"text": "Stunned: any turn it would take before this wears off is lost."},
	"blind": {"name": "Blinded", "short": "Attacks may miss", "icon": "status_blind", "sign": -1,
		"stack": "refresh", "tick": 0, "kind": "blind",
		"text": "Blinded: each of its hits on a foe may miss."},
	"sap": {"name": "Sapped", "short": "Stat lowered", "icon": "status_sap", "sign": -1,
		"stack": "refresh", "keyed": "stat", "tick": 0, "kind": "stat",
		"text": "Sapped: one stat is lowered for a while."},
	"boon": {"name": "Blessed", "short": "Stat raised", "icon": "status_boon", "sign": 1,
		"stack": "refresh", "keyed": "stat", "tick": 0, "kind": "stat",
		"text": "Blessed: one stat is raised for a while."},
	"slow": {"name": "Slowed", "short": "Gauge fills slower", "icon": "status_slow", "sign": -1,
		"stack": "refresh", "tick": 0, "kind": "slow",
		"text": "Slowed: its turn gauge fills more slowly."},
	"poison": {"name": "Poisoned", "short": "Damage over time", "icon": "status_poison", "sign": -1,
		"stack": "stack", "max_stacks": 3, "tick": 1000, "kind": "dot",
		"text": "Poisoned: loses HP every second. Stacks up to three times."},
	"burn": {"name": "Burning", "short": "Fire spreads", "icon": "status_burn", "sign": -1,
		"stack": "refresh", "tick": 1000, "kind": "dot",
		"text": "Burning: loses HP every second, and the fire can jump to a foe beside it."},
	"regen": {"name": "Regenerating", "short": "Heals over time", "icon": "status_regen", "sign": 1,
		"stack": "refresh", "tick": 1000, "kind": "regen",
		"text": "Regenerating: recovers HP every second."},
	"shield": {"name": "Shielded", "short": "Absorbs damage", "icon": "status_shield", "sign": 1,
		"stack": "refresh", "tick": 0, "kind": "shield",
		"text": "Shielded: the shield takes damage before HP does. The Fading goes straight through it."},
	"hidden": {"name": "Hidden", "short": "Can't be targeted", "icon": "status_hidden", "sign": 1,
		"stack": "refresh", "tick": 0, "kind": "hidden",
		"text": "Hidden: no single-target attack can pick it; splash and area attacks still reach it."},
	"heal_block": {"name": "Branded", "short": "Can't be healed", "icon": "status_heal_block", "sign": -1,
		"stack": "refresh", "tick": 0, "kind": "heal_block",
		"text": "Branded: no healing reaches it."},
	"heal_invert": {"name": "Retribution flame", "short": "Heals burn it", "icon": "status_heal_invert", "sign": -1,
		"stack": "refresh", "tick": 0, "kind": "heal_invert",
		"text": "Retribution flame: every heal it receives burns it for that much instead."},
	"charge_seal": {"name": "Sealed", "short": "Gains no charge", "icon": "status_charge_seal", "sign": -1,
		"stack": "refresh", "tick": 0, "kind": "charge_seal",
		"text": "Sealed: its ability meter gains no charge."},
	"link": {"name": "Linked", "short": "Shares damage", "icon": "status_link", "sign": 1,
		"stack": "replace", "tick": 0, "kind": "link",
		"text": "Linked: it and its partner split every hit either of them takes."},
	# ---- round-2 classes (docs/design/class-verdicts-round2.md)
	"disarm": {"name": "Disarmed", "short": "No basic attacks", "icon": "status_disarm", "sign": -1,
		"stack": "refresh", "tick": 0, "kind": "disarm",
		"text": "Disarmed: it makes no basic attacks, so it builds no charge from acting. Hits still charge it, and a full bar still fires its ability."},
	"sabotage": {"name": "Sabotaged", "short": "Formation halted", "icon": "status_sabotage", "sign": -1,
		"stack": "refresh", "tick": 0, "kind": "sabotage",
		"text": "Sabotaged: its side's formation behaviour stops while this lasts. The formation's stat bonus stays."},
	"riposte": {"name": "En garde", "short": "Parries next melee", "icon": "status_riposte", "sign": 1,
		"stack": "refresh", "tick": 0, "kind": "riposte",
		"text": "En garde: the next melee hit on it is parried (no damage) and answered with a critical counter. If nobody swings in time, it lunges at the front foe."},
	"watch": {"name": "On watch", "short": "Guards neighbours", "icon": "status_watch", "sign": 1,
		"stack": "refresh", "tick": 0, "kind": "watch",
		"text": "On watch: the next foe to hit an ally beside it is struck and stunned. One catch, then the watch ends."},
	"enshrine": {"name": "Enshrined", "short": "In a reliquary", "icon": "status_enshrine", "sign": -1,
		"stack": "refresh", "tick": 0, "kind": "enshrine",
		"text": "Enshrined: kept in a crystal reliquary. It can't act, nothing can hit or heal it, and its formation loses it. It still counts as standing, and the Fading still reaches it."},
	"seal_immune": {"name": "Crystal-worn", "short": "Can't be resealed", "icon": "status_seal_immune", "sign": 1,
		"stack": "refresh", "tick": 0, "kind": "seal_immune",
		"text": "Crystal-worn: just freed from a crystal seal, it can't be sealed again for a while."},
}

## Global status tuning.
const TUNING := {
	"blind_miss": 0.5,        # chance each hit of a blinded unit on a foe misses
	"skip_ms": 300,           # a stunned unit's lost turn occupies the timeline this long (a beat to show it)
	"stat_floor": 0.2,        # saps never take a stat below 20% of its fight-start value
	"slow_floor": 0.2,        # slows never take the gauge rate below 20%
	"link_share": 0.5,        # share of a linked unit's hit its partner takes
	"seal_immune_ms": 8000,   # Enshriner rule (c), PROVISIONAL: after a seal ends, no reseal for this long
}
