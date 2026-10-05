extends RefCounted
## Turns an event log into human-readable lines (demo CLI, debug overlay, captions).

const COL_NAMES := ["front", "back"]
## Modifiers worth a word in the story. Formation/composition tags are summarised
## once at the top instead of on every hit.
const MOD_TEXT := {"back_row_attacker": "attacker in back row", "back_row_target": "target in back row",
	"back_row_both": "both in back row", "execute": "EXECUTE", "crit": "CRIT",
	"sudden_death": "the Fading"}
const STAT_TEXT := {"hp_pct": "max HP", "atk_pct": "Atk", "def_pct": "Def", "mag_pct": "Mag", "spd_pct": "Spd",
	"crit_add": "crit", "charge_pct": "charge", "heal_pct": "healing"}


static func narrate(events: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	var units := {}
	for ev: Dictionary in events:
		var t := "[%6.2fs] " % float(ev["t"])
		match String(ev["type"]):
			"fight_start":
				for side: Dictionary in ev["sides"]:
					var f: Dictionary = side["formation"]
					lines.append("== %s: formation %s (%s | %s)%s" % [side["name"], f["name"],
						_mods_text(f["buffs"]), _mods_text(f["debuffs"]), _comps_text(side["compositions"])])
					for u: Dictionary in side["units"]:
						units[int(u["uid"])] = u
						lines.append("     %s  %s Lv%d  %s row %d  HP %d  Atk %d Def %d Mag %d Spd %d" % [
							_tag(u), u["class_name"], int(u["level"]), COL_NAMES[int(u["col"])], int(u["row"]) + 1,
							int(u["max_hp"]), int(u["atk"]), int(u["def"]), int(u["mag"]), int(u["spd"])])
				lines.append("== The Fading begins at %.0fs" % float(ev["sudden_death_at"]))
			"action_start":
				var who: Dictionary = units[int(ev["uid"])]
				var what := "uses %s!" % String(ev["name"]).to_upper() if ev["kind"] == "ability" else String(ev["name"]).to_lower() + "s"
				var tgt := ""
				if int(ev["target"]) >= 0:
					tgt = " -> " + _tag(units[int(ev["target"])])
				elif ev["area"] == "all_enemies":
					tgt = " -> all enemies"
				elif ev["area"] == "all_allies":
					tgt = " -> all allies"
				lines.append(t + "%s %s%s" % [_tag(who), what, tgt])
			"damage":
				var dst: Dictionary = units[int(ev["dst"])]
				var extra: Array = []
				var pm: Dictionary = ev["primary"]
				if not pm.is_empty():
					extra.append(_mod_text(pm))
				var verb := "fades for %d" % int(ev["amount"]) if ev["kind"] == "sudden_death" \
					else "takes %d %s" % [int(ev["amount"]), ev["kind"]]
				if ev["kind"] == "sudden_death":
					extra.clear()   # "fades" already says it: the Fading
				lines.append(t + "    %s %s%s  (HP %d/%d)" % [_tag(dst), verb,
					(" [" + ", ".join(extra) + "]") if not extra.is_empty() else "",
					int(ev["hp"]), int(dst["max_hp"])])
			"heal":
				var hd: Dictionary = units[int(ev["dst"])]
				lines.append(t + "    %s heals %d  (HP %d/%d)" % [_tag(hd), int(ev["amount"]), int(ev["hp"]), int(hd["max_hp"])])
			"charge":
				if ev.get("ready", false):
					var q := int(ev.get("queue", 0))
					lines.append(t + "    %s is fully charged: %s" % [_tag(units[int(ev["uid"])]),
						"ability next, jumps the turn queue" if q == 0 else "ability queued (#%d)" % (q + 1)])
			"formation_proc":
				lines.append(t + "    ~ %s %s %+d%% %s (%s)" % [ev["name"], STAT_TEXT[ev["stat"]],
					roundi(float(ev["value"]) * 100.0), "for " + _tag(units[int(ev["uid"])]), ev["trigger"]])
			"formation":
				var fm: Dictionary = ev["formation"]
				lines.append(t + "%s forms %s: %s | %s" % ["AB"[int(ev["side"])], fm["name"], _mods_text(fm["buffs"]), _mods_text(fm["debuffs"])])
			"ko":
				lines.append(t + "    *** %s is knocked out ***" % _tag(units[int(ev["uid"])]))
			"sudden_death":
				lines.append(t + "!! THE FADING deepens (%d): the battle's memory erodes, everyone loses %d%% max HP, damage x%.2f, healing x%.2f" % [
					int(ev["tick"]), roundi(float(ev["hp_pct"]) * 100.0), float(ev["damage_mult"]), float(ev["heal_mult"])])
			"fight_end":
				var w := int(ev["winner"])
				lines.append(t + "== %s (%s)" % ["DRAW" if w < 0 else "Side %s wins" % ["AB"[w]], ev["reason"]])
	return lines


static func _tag(u: Dictionary) -> String:
	return "%s:%s" % ["AB"[int(u["side"])], u.get("label", u["name"])]


## "x0.5 target in back", "+12% Shield (B)", "-9% Wall (A)"
static func _mod_text(m: Dictionary) -> String:
	var mult := float(m["mult"])
	var id := String(m["id"])
	if id == "formation":
		return "%+d%% %s (%s)" % [roundi((mult - 1.0) * 100.0), m["name"], "AB"[int(m["side"])]]
	if id == "crit" or id == "sudden_death":
		return String(MOD_TEXT[id])
	return "x%s %s" % [String.num(mult, 2), MOD_TEXT.get(String(m["id"]), String(m["id"]))]


static func _mods_text(mods: Array) -> String:
	var parts: Array = []
	for m: Dictionary in mods:
		var val := float(m["value"])
		parts.append("%s %s%+d%%" % [m["scope"], String(m["stat"]).trim_suffix("_pct").trim_suffix("_add"), roundi(val * 100.0)])
	return ", ".join(parts)


static func _comps_text(comps: Array) -> String:
	if comps.is_empty():
		return ""
	var names: Array = []
	for c: Dictionary in comps:
		names.append(c["name"])
	return "  +" + ", ".join(names)
