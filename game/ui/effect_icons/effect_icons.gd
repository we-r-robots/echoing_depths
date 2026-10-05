class_name EffectIcons
extends RefCounted
## Shared effect icon set + wording (BUILD.md: effects are icons, the full text is a tooltip).
## Icons are white 9x9 masks in this folder (src/make_effect_icons.py), tinted with a palette colour.
##
## An "effect" is a Dictionary:
##   {"icon": Texture2D, "sign": 1 buff / -1 cost / 0 neutral, "kind": "stat"|"behaviour"|"cost"|"bond",
##    "title": a short label, at most 20 chars ("Front Def +10%", "Ilse draws melee"),
##    "name": the tooltip title: the effect's category or lore name ("Def", "Keeper's ring"),
##    "text": the full sentence for the tooltip}
##
##   EffectIcons.formation_effects(shape, who, bonds) -> Array of effects in the order
##       bonus stats, behaviour, cost (stats then the geometric cost), class bonds.
##       shape = a core/data/formations.gd entry; who = role -> [hero names] (who_of) so sentences
##       name the hero ("Ilse can't be targeted ..."); bonds = core Formation.compositions(...) entries.
##   EffectIcons.stat_icon("def_pct") / behaviour_icon("brace") / icon("cost_draws_melee")
##   EffectIcons.draw_effect(canvas_item, pos, effect)   # 18x18 chip, non-interactive (banners)
##   EffectChip.new() + setup(effect)                    # interactive chip with the shared Tip

const Formation = preload("res://core/formation.gd")
const UP := preload("res://ui/effect_icons/up.png")
const DOWN := preload("res://ui/effect_icons/down.png")
const ICONS := {
	"beh_brace": preload("res://ui/effect_icons/beh_brace.png"),
	"beh_covering_fire": preload("res://ui/effect_icons/beh_covering_fire.png"),
	"beh_echo_step": preload("res://ui/effect_icons/beh_echo_step.png"),
	"beh_flank": preload("res://ui/effect_icons/beh_flank.png"),
	"beh_guardian": preload("res://ui/effect_icons/beh_guardian.png"),
	"beh_hearthguard": preload("res://ui/effect_icons/beh_hearthguard.png"),
	"beh_hold_the_door": preload("res://ui/effect_icons/beh_hold_the_door.png"),
	"beh_keepers_ring": preload("res://ui/effect_icons/beh_keepers_ring.png"),
	"beh_opening_volley": preload("res://ui/effect_icons/beh_opening_volley.png"),
	"beh_scattered": preload("res://ui/effect_icons/beh_scattered.png"),
	"beh_shardpoint": preload("res://ui/effect_icons/beh_shardpoint.png"),
	"beh_share_the_blow": preload("res://ui/effect_icons/beh_share_the_blow.png"),
	"beh_shoulder_to_shoulder": preload("res://ui/effect_icons/beh_shoulder_to_shoulder.png"),
	"bond": preload("res://ui/effect_icons/bond.png"),
	"cost_capped": preload("res://ui/effect_icons/cost_capped.png"),
	"cost_draws_melee": preload("res://ui/effect_icons/cost_draws_melee.png"),
	"cost_exposed": preload("res://ui/effect_icons/cost_exposed.png"),
	"cost_no_behaviour": preload("res://ui/effect_icons/cost_no_behaviour.png"),
	"cost_no_front": preload("res://ui/effect_icons/cost_no_front.png"),
	"down": preload("res://ui/effect_icons/down.png"),
	"lock": preload("res://ui/effect_icons/lock.png"),
	"stat_atk": preload("res://ui/effect_icons/stat_atk.png"),
	"stat_charge": preload("res://ui/effect_icons/stat_charge.png"),
	"stat_crit": preload("res://ui/effect_icons/stat_crit.png"),
	"stat_def": preload("res://ui/effect_icons/stat_def.png"),
	"stat_dmg_taken": preload("res://ui/effect_icons/stat_dmg_taken.png"),
	"stat_heal": preload("res://ui/effect_icons/stat_heal.png"),
	"stat_hp": preload("res://ui/effect_icons/stat_hp.png"),
	"stat_mag": preload("res://ui/effect_icons/stat_mag.png"),
	"stat_spd": preload("res://ui/effect_icons/stat_spd.png"),
	"up": preload("res://ui/effect_icons/up.png"),
}
const STAT_ICON := {
	"def_pct": "stat_def", "atk_pct": "stat_atk", "mag_pct": "stat_mag", "spd_pct": "stat_spd",
	"hp_pct": "stat_hp", "heal_pct": "stat_heal", "charge_pct": "stat_charge", "crit_add": "stat_crit",
	"dmg_taken_pct": "stat_dmg_taken",
}
## Geometric cost (what the sim does) per shape id.
const COST_ICON := {
	"kindred": "cost_exposed", "seawall": "cost_exposed", "vigil": "cost_no_front", "choir": "cost_no_front",
	"lumari_chorus": "cost_no_front", "lamplight": "cost_draws_melee", "keystone": "cost_draws_melee",
	"crescent": "cost_draws_melee", "hearth": "cost_draws_melee", "lighthouse": "cost_draws_melee",
	"shardpoint": "cost_draws_melee", "vault_door": "cost_capped", "strays": "cost_no_behaviour",
}
const BUFF := Pal.LIFE4
const COST := Pal.BLOOD4
const BEHAVIOUR := Pal.CRYSTAL4
const BOND := Pal.AMBER5


static func icon(name: String) -> Texture2D:
	return ICONS.get(name, ICONS["stat_def"])


static func stat_icon(stat: String) -> Texture2D:
	return icon(String(STAT_ICON.get(stat, "stat_def")))


static func behaviour_icon(id: String) -> Texture2D:
	return icon("beh_" + id) if ICONS.has("beh_" + id) else icon("beh_shardpoint")


static func color_of(e: Dictionary) -> Color:
	match String(e.get("kind", "")):
		"behaviour":
			return BEHAVIOUR
		"bond":
			return BOND
		"note":
			return Pal.INK9
	return BUFF if int(e.get("sign", 0)) > 0 else COST


## Effects of a formation, in display order (see header).
static func formation_effects(shape: Dictionary, who := {}, bonds: Array = []) -> Array:
	var out: Array = []
	for m: Dictionary in shape.get("bonus", []):
		out.append(_stat_effect(m, who, 1))
	var b: Dictionary = shape.get("behaviour", {})
	if not b.is_empty():
		out.append({"icon": behaviour_icon(String(b.get("id", ""))), "sign": 0, "kind": "behaviour",
			"title": behaviour_title(shape, who), "name": String(b.get("name", "")),
			"text": behaviour_sentence(shape, who)})   # the lore name is the tooltip title ("name")
	for m: Dictionary in shape.get("cost", {}).get("mods", []):
		out.append(_stat_effect(m, who, -1))
	var geo := _geo_cost(shape, who)
	if geo != "":
		out.append({"icon": icon(String(COST_ICON.get(String(shape.get("id", "")), "cost_exposed"))), "sign": -1,
			"kind": "cost", "title": _geo_title(shape, who),
			"name": "Strays" if String(shape.get("id", "")) == "strays" else "%s's weakness" % String(shape.get("name", "Shape")),
			"text": geo})
	for comp: Dictionary in bonds:
		var lines: Array = []
		for m: Dictionary in comp.get("mods", []):
			var sub := "Everyone" if String(m["scope"]) == "all" else _class_plural(comp)
			lines.append(_mod_sentence(sub, true, String(m["stat"]), float(m["value"])))
		out.append({"icon": icon("bond"), "sign": 1, "kind": "bond", "title": String(comp.get("name", "")), "name": "Class bond",
			"text": " ".join(lines)})
	return out


const SCOPE_SHORT := {"all": "All", "front": "Front", "back": "Back", "post": "Post", "tip": "Tip",
	"keeper": "Keeper", "flanker": "Flanker", "gap": "Open end"}


static func _scope_short(scope: String, who: Dictionary) -> String:
	var names: Array = who.get(scope, [])
	if names.size() == 1 and not ["all", "front", "back"].has(scope):
		return String(names[0])
	return String(SCOPE_SHORT.get(scope, scope.capitalize()))


static func _geo_title(shape: Dictionary, who: Dictionary) -> String:
	match String(shape.get("id", "")):
		"kindred":
			return "Nobody behind"
		"seawall":
			return "No back row"
		"vigil", "choir", "lumari_chorus":
			return "No front line"
		"lamplight":
			return "%s takes the hit" % _one(who, "front", "Front")
		"keystone", "crescent":
			return "%s draws melee" % _one(who, "gap", "Open end")
		"hearth", "shardpoint":
			return "%s draws melee" % _one(who, "post" if String(shape["id"]) == "hearth" else "tip", "Front")
		"lighthouse":
			return "%s draws all" % _one(who, "post", "Post")
		"vault_door":
			return "Nothing above +5%"
		"strays":
			return "No shape behaviour"
	return "Cost"


## Plain short label (<= ~20 chars) for a behaviour; the lore name goes in the tooltip.
static func behaviour_title(shape: Dictionary, who := {}) -> String:
	match String(shape.get("behaviour", {}).get("id", "")):
		"shoulder_to_shoulder":
			return "Hit one, both charge"
		"covering_fire":
			return "Partner strikes back"
		"guardian":
			return "Front blocks a spell"
		"brace":
			return "Middle shares hits"
		"opening_volley":
			return "Back row acts first"
		"flank":
			return "Flanker hits harder"
		"hearthguard":
			return "Post toughens"
		"share_the_blow":
			return "Hits spread a row"
		"hold_the_door":
			return "Back steps up"
		"keepers_ring":
			return "%s untargetable" % _one(who, "keeper", "Keeper")
		"shardpoint":
			return "Tip charges up"
		"echo_step":
			return "Splash halved"
		"scattered":
			return "Scattered: no splash"
	return String(shape.get("behaviour", {}).get("name", ""))


static func _class_plural(comp: Dictionary) -> String:
	var w: Dictionary = comp.get("when", {})
	if w.has("base"):
		return String(w["base"]).capitalize() + "s"
	return "Everyone"


static func _stat_effect(m: Dictionary, who: Dictionary, sign: int) -> Dictionary:
	var stat := String(m["stat"])
	var v := float(m["value"])
	var pct := roundi(v * 100.0)
	var noun := String(STAT_NOUN.get(stat, "damage taken"))
	var subj := _subject(String(m["scope"]), who)
	var stat_word := noun.capitalize() if noun.length() > 3 else noun
	if stat == "dmg_taken_pct":
		stat_word = "dmg taken"
	var title := "%s %s %+d%%" % [_scope_short(String(m["scope"]), who), stat_word, pct]
	return {"icon": stat_icon(stat), "sign": sign, "kind": "stat", "title": title, "short": short_stat(stat, v),
		"subject": _scope_short(String(m["scope"]), who), "value": "%+d%%" % pct,
		"name": String(STAT_CATEGORY.get(stat, "Effect")), "text": _mod_sentence(subj[0], subj[1], stat, v)}


const STAT_SHORT := {
	"hp_pct": "HP", "atk_pct": "Atk", "def_pct": "Def", "mag_pct": "Mag", "spd_pct": "Spd", "crit_add": "Crit",
	"charge_pct": "Charge", "heal_pct": "Heal", "dmg_taken_pct": "Dmg taken",
}


## The shortest label for a stat effect, with no subject ("Crit +15%"): the chip row on the
## battle intro cards, where the tooltip names who gets it.
static func short_stat(stat: String, v: float) -> String:
	return "%s %+d%%" % [STAT_SHORT.get(stat, stat.capitalize()), roundi(v * 100.0)]


const STAT_CATEGORY := {
	"def_pct": "Def", "atk_pct": "Atk", "mag_pct": "Mag", "spd_pct": "Spd", "hp_pct": "HP",
	"heal_pct": "Healing", "charge_pct": "Charge", "crit_add": "Critical hits", "dmg_taken_pct": "Damage taken",
}


const SUBJECT := {
	"all": ["Everyone", false], "front": ["Front heroes", true], "back": ["Back heroes", true],
	"post": ["The lone front hero", false], "tip": ["The tip", false], "keeper": ["The ringed hero", false],
	"flanker": ["The flanker", false], "gap": ["The open-end hero", false], "class": ["That class", false],
}
const STAT_NOUN := {
	"hp_pct": "HP", "atk_pct": "Atk", "def_pct": "Def", "mag_pct": "Mag", "spd_pct": "Spd",
	"crit_add": "crit", "charge_pct": "charge", "heal_pct": "healing",
}


static func _subject(scope: String, who: Dictionary) -> Array:
	var subj: Array = SUBJECT.get(scope, [scope.capitalize(), false])
	var names: Array = who.get(scope, [])
	if names.size() == 1 and not ["all", "front", "back"].has(scope):
		return [String(names[0]), false]
	return [String(subj[0]), bool(subj[1])]


## One stat mod as a full sentence: "Front heroes get Def +10%.", "Everyone loses 5% Spd.",
## "Front heroes take 5% more damage."
static func _mod_sentence(subj: String, plural: bool, stat: String, v: float) -> String:
	var pct := absi(roundi(v * 100.0))
	if stat == "dmg_taken_pct":
		return "%s %s %d%% %s damage." % [subj, "take" if plural else "takes", pct, "more" if v > 0 else "less"]
	var noun := String(STAT_NOUN.get(stat, stat))
	if v >= 0.0:
		return "%s %s %s +%d%%." % [subj, "get" if plural else "gets", noun, pct]
	return "%s %s %d%% %s." % [subj, "lose" if plural else "loses", pct, noun]


## Mods merged per scope and value into sentences ("The ringed hero gets healing and charge +40%.").
static func mod_sentences(mods: Array, who := {}) -> Array:
	var groups: Array = []
	for m: Dictionary in mods:
		var found := false
		for g: Array in groups:
			if g[0] == m["scope"] and is_equal_approx(float(g[1]), float(m["value"])) and String(m["stat"]) != "dmg_taken_pct":
				(g[2] as Array).append(String(m["stat"]))
				found = true
		if not found:
			groups.append([String(m["scope"]), float(m["value"]), [String(m["stat"])]])
	var out: Array = []
	for g: Array in groups:
		var subj := _subject(String(g[0]), who)
		var stats: Array = g[2]
		if stats.size() == 1:
			out.append(_mod_sentence(subj[0], subj[1], String(stats[0]), float(g[1])))
			continue
		var nouns: Array = []
		for st: String in stats:
			nouns.append(STAT_NOUN.get(st, st))
		var pct := absi(roundi(float(g[1]) * 100.0))
		var list := _and_list(nouns)
		if float(g[1]) >= 0.0:
			out.append("%s %s %s +%d%%." % [subj[0], "get" if subj[1] else "gets", list, pct])
		else:
			out.append("%s %s %d%% %s." % [subj[0], "lose" if subj[1] else "loses", pct, list])
	return out


static func _and_list(a: Array) -> String:
	if a.size() <= 1:
		return "".join(a)
	return ", ".join(a.slice(0, a.size() - 1)) + " and " + String(a[-1])


static func _one(who: Dictionary, role: String, fallback: String) -> String:
	var n: Array = who.get(role, [])
	return String(n[0]) if n.size() == 1 else fallback


static func _pct(v: Variant) -> int:
	return roundi(float(v) * 100.0)


## The behaviour as one full sentence, naming the hero in the role when known.
static func behaviour_sentence(shape: Dictionary, who := {}) -> String:
	var b: Dictionary = shape.get("behaviour", {})
	match String(b.get("id", "")):
		"shoulder_to_shoulder":
			return "When one is hit in melee, the other gains charge."
		"covering_fire":
			return "When one is hit in melee, the other strikes the attacker."
		"guardian":
			return "%s blocks the first spell or shot aimed at %s." % [_one(who, "front", "The front hero"), _one(who, "back", "the back hero")]
		"brace":
			return "Hits on %s pass %d%% to each neighbour." % [_one(who, "middle", "the middle hero"), _pct(b.get("share", 0.2))]
		"opening_volley":
			var s := "The back row starts with fuller gauges and acts first."
			if b.has("splash"):
				s = "The back row acts first, and magic splash deals +%d%%." % _pct(b["splash"])
			return s
		"flank":
			var s := "%s deals +%d%% to the foe in its row" % [_one(who, "flanker", "The back hero"), _pct(b.get("dmg", 0.2))]
			if float(b.get("crit", 0.0)) > 0.0:
				s += " and crits more"
			return s + "."
		"hearthguard":
			var s := "%s takes %d%% less damage per living back ally" % [_one(who, "post", "The front hero"), _pct(b.get("per_ally", 0.1))]
			if bool(b.get("taunt", false)):
				s += ", and draws the attacks"
			return s + "."
		"share_the_blow":
			return "%d%% of each hit spreads to the hero in the next row." % _pct(b.get("share", 0.3))
		"hold_the_door":
			return "When a front hero falls, the hero behind steps up."
		"keepers_ring":
			return "%s can't be targeted while the front three stand." % _one(who, "keeper", "The ringed hero")
		"shardpoint":
			return "%s gains charge whenever an ally behind acts." % _one(who, "tip", "The tip")
		"echo_step":
			return "Area splash on this party is halved."
		"scattered":
			return "Area splash never spreads between Strays who aren't side by side."
	return String(b.get("text", ""))


## The cost as full sentences: stat mods (exact numbers), then what the geometry does in the sim.
static func cost_sentences(shape: Dictionary, who := {}) -> Array:
	var out: Array = mod_sentences(shape.get("cost", {}).get("mods", []), who)
	var geo := _geo_cost(shape, who)
	if geo != "":
		out.append(geo)
	if out.is_empty():
		out.append(String(shape.get("cost", {}).get("text", "")))
	return out


## The geometric part of a cost, as the sim applies it ("" when the cost is stat mods only).
static func _geo_cost(shape: Dictionary, who := {}) -> String:
	var out: Array = []
	match String(shape.get("id", "")):
		"kindred":
			out.append("Both stand in front and take full physical damage.")
		"vigil", "choir":
			out.append("No front line: melee hits them straight away.")
		"lumari_chorus":
			out.append("No front line, and their physical hits deal half.")
		"lamplight":
			out.append("%s takes the hit it blocks for %s." % [_one(who, "front", "The front hero"), _one(who, "back", "its partner")])
		"keystone", "crescent":
			out.append("%s, at the open end, takes melee meant for the front heroes beside it." % _one(who, "gap", "The open-end front hero"))
		"hearth":
			out.append("%s, the only front hero, takes every melee hit." % _one(who, "post", "The lone front hero"))
		"lighthouse":
			out.append("%s, the post, takes every melee hit and every single-target spell or shot." % _one(who, "post", "The post"))
		"shardpoint":
			out.append("%s, the tip, takes every melee hit." % _one(who, "tip", "The tip"))
		"vault_door":
			out.append("No bonus is bigger than +5%.")
		"seawall":
			out.append("No back row: every hero takes full physical damage.")
		"strays":
			out.append("Strays has its own behaviour, Scattered; shape behaviours don't apply.")
	return "" if out.is_empty() else String(out[0])


## role -> [hero names] for heroes standing on `cells` (cells[k] belongs to names[k]).
static func who_of(shape_id: String, cells: Array, names: Array) -> Dictionary:
	var out := {}
	if shape_id == "" or shape_id == "strays" or cells.size() != names.size():
		return out
	var roles: Array = Formation.roles(shape_id, cells)
	for k in cells.size():
		for r: String in roles[k]:
			if not out.has(r):
				out[r] = []
			(out[r] as Array).append(names[k])
	return out




const CHIP := 20


## Draws one effect as a 20x20 chip at pos: a dark well, the icon tinted (green buff, red cost,
## crystal behaviour, amber bond) and a green up / red down arrow in the corner.
static func draw_effect(ci: CanvasItem, pos: Vector2, e: Dictionary, lit := false, locked := false) -> void:
	var c := color_of(e) if not locked else Pal.FADE4
	var r := Rect2(pos, Vector2(CHIP, CHIP))
	ci.draw_rect(r, Pal.INK1)
	ci.draw_rect(r.grow(-1), Pal.INK2 if not lit else Pal.INK3)
	var edge := Pal.INK4
	match int(e.get("sign", 0)):
		1:
			edge = Pal.LIFE2
		-1:
			edge = Pal.BLOOD2
	if String(e.get("kind", "")) == "behaviour":
		edge = Pal.CRYSTAL2
	elif String(e.get("kind", "")) == "bond":
		edge = Pal.AMBER3
	if locked:
		edge = Pal.FADE2
	if lit:
		edge = c
	ci.draw_rect(Rect2(pos.x + 1, pos.y, CHIP - 2, 1), edge)
	ci.draw_rect(Rect2(pos.x + 1, pos.y + CHIP - 1, CHIP - 2, 1), edge)
	ci.draw_rect(Rect2(pos.x, pos.y + 1, 1, CHIP - 2), edge)
	ci.draw_rect(Rect2(pos.x + CHIP - 1, pos.y + 1, 1, CHIP - 2), edge)
	var tex: Texture2D = e["icon"]
	var ip := pos + Vector2(4, 4)
	ci.draw_texture(tex, ip + Vector2(1, 1), Pal.INK1)
	ci.draw_texture(tex, ip, c)
	match int(e.get("sign", 0)):
		1:
			ci.draw_texture(UP, pos + Vector2(13, 14) + Vector2(1, 1), Pal.INK1)
			ci.draw_texture(UP, pos + Vector2(13, 14), BUFF if not locked else Pal.FADE3)
		-1:
			ci.draw_texture(DOWN, pos + Vector2(13, 14) + Vector2(1, 1), Pal.INK1)
			ci.draw_texture(DOWN, pos + Vector2(13, 14), COST if not locked else Pal.FADE3)
