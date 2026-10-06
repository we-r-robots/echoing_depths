extends RefCounted
## Turns an event log into human-readable lines (demo CLI, debug overlay, captions).

const GameData = preload("res://core/game_data.gd")

const COL_NAMES := ["front", "back"]
## Modifiers worth a word in the story. Formation/composition tags are summarised
## once at the top instead of on every hit.
const MOD_TEXT := {"back_row_attacker": "attacker in back row", "back_row_target": "target in back row",
	"back_row_both": "both in back row", "execute": "EXECUTE", "crit": "CRIT",
	"sudden_death": "the Fading", "brace": "braced", "share_the_blow": "shared blow", "flank": "flank",
	"hearthguard": "hearthguard", "echo_step": "echo step", "chorus_splash": "chorus splash", "harvest": "grief", "mirror": "woven",
	"poison": "poison", "burn": "burn", "heal_invert": "hexed heal", "cost": "cost", "tithe": "tithe", "link": "linked"}
const BEH_TEXT := {"shoulder_to_shoulder": "shoulder to shoulder, gains charge", "covering_fire": "covering fire, targets the attacker",
	"guardian": "guardian intercepts the hit", "brace": "braces, neighbours share the blow", "opening_volley": "opening volley, acts early",
	"flank": "flanks the enemy in its row", "hearthguard": "hearthguard, takes less damage", "share_the_blow": "shares the blow down the wall",
	"chorus_splash": "chorus, splash +10%", "keepers_ring": "keeper's ring, can't be targeted", "shardpoint": "shardpoint, the tip gains charge",
	"echo_step": "echo step, splash halved", "scattered": "scattered, splash can't spread", "draws_melee": "draws the melee",
	"taunt": "the lit post taunts melee", "kindle": "kindles another memory", "shield_crystal": "stands in the crossing, takes the Crystal's blow",
	"harvest": "grieves the fallen, hits harder", "mirror": "weaves the heroes' formation into herself",
	"last_stand": "will not fall yet", "draw_memory": "draws charge out of a hero", "hasten_fading": "closes the Vault, the Fading draws nearer",
	"dim_lantern": "dims the lantern, the heroes' formation goes dark"}
const STAT_TEXT := {"hp_pct": "max HP", "atk_pct": "Atk", "def_pct": "Def", "mag_pct": "Mag", "spd_pct": "Spd",
	"crit_add": "crit", "charge_pct": "charge", "heal_pct": "healing", "dmg_taken_pct": "damage taken"}


static func narrate(events: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	var units := {}
	var cur_action := "the attack"
	for ev: Dictionary in events:
		var t := "[%6.2fs] " % float(ev["t"])
		match String(ev["type"]):
			"fight_start":
				for side: Dictionary in ev["sides"]:
					var f: Dictionary = side["formation"]
					lines.append("== %s: %s%s%s" % [side["name"], f["name"],
						" (%s is locked: fights as Strays)" % f["shape_name"] if f["locked"] else "",
						_comps_text(side["compositions"])])
					for u: Dictionary in side["units"]:
						units[int(u["uid"])] = u
						lines.append("     %s  %s Lv%d  %s row %d  HP %d  Atk %d Def %d Mag %d Spd %d" % [
							_tag(u), u["class_name"], int(u["level"]), COL_NAMES[int(u["col"])], int(u["row"]) + 1,
							int(u["max_hp"]), int(u["atk"]), int(u["def"]), int(u["mag"]), int(u["spd"])])
				lines.append("== The Fading begins at %.0fs" % float(ev["sudden_death_at"]))
			"action_start":
				cur_action = "%s's %s" % [_tag(units[int(ev["uid"])]), ev["name"]]
				var who: Dictionary = units[int(ev["uid"])]
				var what := "uses %s!" % String(ev["name"]).to_upper() if ev["kind"] == "ability" else String(ev["name"]).to_lower() + "s"
				var tgt := ""
				if int(ev["target"]) >= 0:
					tgt = " -> " + _tag(units[int(ev["target"])])
				elif ev["area"] == "all_enemies":
					tgt = " -> all enemies"
				elif ev["area"] == "all_allies":
					tgt = " -> all allies"
				if ev["area"] == "column":
					tgt += " (up the column)"
				lines.append(t + "%s %s%s" % [_tag(who), what, tgt])
			"damage":
				var dst: Dictionary = units[int(ev["dst"])]
				var extra: Array = []
				var pm: Dictionary = ev["primary"]
				if not pm.is_empty():
					extra.append(_mod_text(pm))
				var verb := "fades for %d" % int(ev["amount"]) if ev["kind"] == "sudden_death" \
					else "takes %d %s" % [int(ev["amount"]), ev["kind"] if ev["kind"] != "status" else String(pm.get("id", "status")).replace("_", " ")]
				if ev["kind"] == "sudden_death" or ev["kind"] == "status":
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
				var who := _tag(units[int(ev["uid"])])
				if String(ev["stat"]) != "":
					lines.append(t + "    ~ %s %s %+d%% for %s (%s)" % [ev["name"], STAT_TEXT[ev["stat"]],
						roundi(float(ev["value"]) * 100.0), who, ev["trigger"]])
				else:
					var rel := int(ev["related"])
					var what: String = BEH_TEXT.get(ev["effect"], ev["effect"])
					if ev["effect"] == "taunt" or ev["effect"] == "draws_melee":
						what = "%s draws %s" % ["the lit post" if ev["effect"] == "taunt" else "it", cur_action]
					lines.append(t + "    ~ %s: %s: %s%s" % [ev["name"], what, who,
						(" (vs %s)" % _tag(units[rel])) if rel >= 0 else ""])
			"spawn":
				var su: Dictionary = ev["unit"]
				units[int(ev["uid"])] = su
				if String(ev.get("summon", "")) != "":
					lines.append(t + "    + %s %s %s (%s row %d)" % [_tag(units[int(ev["summoner"])]),
						"raises" if ev["summon"] == "husk" else "calls", _tag(su), COL_NAMES[int(ev["slot"][0])], int(ev["slot"][1]) + 1])
				else:
					lines.append(t + "** The Crystal releases a memory: %s (%s row %d). \"%s\"" % [_tag(su),
						COL_NAMES[int(ev["slot"][0])], int(ev["slot"][1]) + 1, ev["lore"]])
			"status":
				var sn: String = GameData.Statuses.STATUSES[ev["status"]]["name"]
				var extra2 := ""
				if String(ev["stat"]) != "":
					extra2 = " (%s %+d%%)" % [String(ev["stat"]).capitalize(), roundi(float(ev["value"]) * 100.0)]
				elif int(ev["stacks"]) > 1:
					extra2 = " x%d" % int(ev["stacks"])
				lines.append(t + "    + %s is %s%s for %.1fs" % [_tag(units[int(ev["uid"])]), sn.to_lower(), extra2, float(ev["duration"])])
			"status_end":
				lines.append(t + "    - %s is no longer %s (%s)" % [_tag(units[int(ev["uid"])]),
					String(GameData.Statuses.STATUSES[ev["status"]]["name"]).to_lower(), ev["reason"]])
			"miss":
				lines.append(t + "    %s" % ("%s misses %s (blinded)" % [_tag(units[int(ev["src"])]), _tag(units[int(ev["dst"])])]
					if ev["reason"] == "blind" else "%s can't be healed (branded)" % _tag(units[int(ev["dst"])])))
			"skip":
				lines.append(t + "%s is stunned and loses its turn" % _tag(units[int(ev["uid"])]))
			"absorb":
				lines.append(t + "    %s's shield absorbs %d (%d left)" % [_tag(units[int(ev["uid"])]), int(ev["amount"]), int(ev["shield"])])
			"move":
				lines.append(t + "    ~ %s is %s to the %s row" % [_tag(units[int(ev["uid"])]), ev["effect"], COL_NAMES[int(ev["to"][0])]])
			"gauge":
				lines.append(t + "    ~ %s is driven on: acts next" % _tag(units[int(ev["uid"])]))
			"revive":
				lines.append(t + "    + %s rekindles %s (HP %d)" % [_tag(units[int(ev["src"])]), _tag(units[int(ev["uid"])]), int(ev["hp"])])
			"crystal_fragment":
				lines.append(t + "** The Crystal cracks: fragment %d of 4 (integrity %d/%d)" % [int(ev["index"]),
					int(ev["integrity"]), int(ev["max_integrity"])])
			"formation_move":
				lines.append(t + "    ~ Hold the door: %s steps forward from the back row into row %d" % [
					_tag(units[int(ev["uid"])]), int(ev["to"][1]) + 1])
			"formation":
				var fm: Dictionary = ev["formation"]
				lines.append(t + "%s forms %s: %s | %s: %s | cost: %s%s" % ["AB"[int(ev["side"])], fm["name"],
					_mods_text(fm["buffs"]), fm["behaviour"]["name"], fm["behaviour"]["text"], fm["cost"],
					(" " + _mods_text(fm["debuffs"])) if not (fm["debuffs"] as Array).is_empty() else ""])
			"ko":
				lines.append(t + "    *** %s is knocked out ***" % _tag(units[int(ev["uid"])]))
			"sudden_death":
				lines.append(t + "!! THE FADING deepens (%d): the battle's memory erodes, everyone loses %d%% max HP, damage x%.2f, healing x%.2f" % [
					int(ev["tick"]), roundi(float(ev["hp_pct"]) * 100.0), float(ev["damage_mult"]), float(ev["heal_mult"])])
			"fight_end":
				var w := int(ev["winner"])
				if ev["reason"] == "shard":
					lines.append(t + "== The fourth fragment frees a whole Shard. Victory.")
				else:
					lines.append(t + "== %s (%s)%s" % ["DRAW" if w < 0 else "Side %s wins" % ["AB"[w]], ev["reason"],
						"  fragments chipped: %d" % int(ev.get("fragments", 0)) if int(ev.get("fragments", 0)) > 0 else ""])
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
