extends "res://tests/test_case.gd"
## What a level gives, shown everywhere a level happens (playtest: "Does each hero level give bonus
## stats? we should make it more clear"): HeroStats.level_gain is the real compute() difference
## (floored, so a fractional growth gives +0 on some levels), the camp's memory line and the
## encounter's choice rows name the gains, the hero card and the advancement card explain levels.

const HeroStats = preload("res://core/hero_stats.gd")
const GameData = preload("res://core/game_data.gd")


## Expected gain from the class data by hand: floor(base + g * n) - floor(base + g * (n - 1)).
func _by_hand(cid: String, lv: int) -> Dictionary:
	var c := GameData.get_class_def(cid)
	var out := {}
	for s: String in GameData.STATS:
		var b := float(c["stats"].get(s, 0))
		var g := float(c["growth"].get(s, 0))
		var d := maxi(1, floori(b + g * lv)) - maxi(1, floori(b + g * (lv - 1)))
		if d != 0:
			out[s] = d
	return out


func test_level_gain_is_the_real_floored_difference() -> void:
	var saw_floored_zero := false
	for cid: String in ["fighter", "rogue", "healer", "mage", "paladin"]:
		var mx := GameData.max_level(cid)
		for lv in range(1, mx):
			var g := HeroStats.level_gain({"class": cid, "level": lv})
			eq(var_to_str(g), var_to_str(_by_hand(cid, lv)), "%s Lv %d → %d gain" % [cid, lv, lv + 1])
			var a := HeroStats.compute({"class": cid, "level": lv})
			var b := HeroStats.compute({"class": cid, "level": lv + 1})
			for s: String in GameData.STATS:
				eq(int(g.get(s, 0)), int(b[s]) - int(a[s]), "%s %s matches compute()" % [cid, s])
				var gr := float(GameData.get_class_def(cid)["growth"].get(s, 0))
				if gr > 0.0 and gr < 1.0 and not g.has(s):
					saw_floored_zero = true
			for s: String in g:
				check(int(g[s]) > 0, "only stats that really change are listed (%s %s)" % [cid, s])
		eq(var_to_str(HeroStats.level_gain({"class": cid, "level": mx})), "{}", "%s at max level: no gain" % cid)
	check(saw_floored_zero, "a fractional growth floors to +0 on some level (and is left out)")


func test_level_gain_counts_items_and_keeps_order() -> void:
	var h := {"class": "fighter", "level": 2, "items": {"weapon": "iron_sword", "armor": "", "relic": ""}}
	var a := HeroStats.compute(h)
	var g := HeroStats.level_gain(h)
	h["level"] = 3
	var b := HeroStats.compute(h)
	for s: String in g:
		eq(int(g[s]), int(b[s]) - int(a[s]), "with items: %s" % s)
	var keys: Array = g.keys()
	var want: Array = GameData.STATS.filter(func(s: String) -> bool: return g.has(s))
	eq(keys, want, "gains in STATS order")


func test_growth_range_whole_numbers() -> void:
	var r := HeroStats.growth_range("fighter")
	var c := GameData.get_class_def("fighter")
	eq(int(r["hp"][0]), int(c["growth"]["hp"]), "whole growth: one value")
	eq(int(r["hp"][1]), int(c["growth"]["hp"]), "whole growth: one value (max)")
	for s: String in GameData.STATS:
		var g := float(c["growth"].get(s, 0))
		check(int(r[s][0]) == floori(g) or int(r[s][0]) == floori(g) - 1, "%s lowest is about floor(growth)" % s)
		check(int(r[s][1]) <= ceili(g), "%s highest is at most ceil(growth)" % s)
	eq(PartyModel.range_words([2, 3]), "+2–3", "a range reads +2–3")
	eq(PartyModel.range_words([16, 16]), "+16", "one value reads +16")
	check(not PartyModel.growth_words("fighter").contains("."), "never a fraction like +0.4")


func test_gain_words() -> void:
	eq(PartyModel.gain_words({"hp": 10, "mag": 2, "def": 1}), "HP +10 · Def +1 · Mag +2", "words in STATS order")
	eq(PartyModel.gain_words({}), "", "nothing at max level")


func test_camp_memory_line_names_the_gains() -> void:
	var h := {"name": "Ilse", "class": "healer", "base": "healer", "tier": "base", "level": 3, "items": {}}
	var line := RunHub.memory_line(h, {"hero_index": 0, "level_before": 2, "level": 3})
	var want := PartyModel.gain_words(HeroStats.gain_between({"class": "healer"}, 2, 3))
	check(want != "", "a healer's level gives something")
	eq(String(line.get_meta("text")), "Ilse absorbed a memory: Lv 2 → 3 · " + want, "the camp line names the gains")
	var green := false
	for l in line.find_children("*", "Label", true, false):
		if (l as Label).text == want:
			green = (l as Label).get_theme_color("font_color") == UIText.legible(Pal.LIFE4)
	check(green, "the gains are green (LIFE4)")
	# Awakened at camp since: the levels were the base class's
	var adv := {"name": "Vael", "class": "paladin", "base": "fighter", "tier": "advanced", "level": 1, "items": {}}
	var l2 := RunHub.memory_line(adv, {"hero_index": 0, "level_before": 2, "level": 3})
	check(String(l2.get_meta("text")).ends_with(PartyModel.gain_words(HeroStats.gain_between({"class": "fighter"}, 2, 3))),
		"after an Awakening the line keeps the base class's gains")
	var capped := RunHub.memory_line(h, {"hero_index": 0, "level_before": 6, "level": 6})
	check(String(capped.get_meta("text")).contains("no level"), "at max level it says it didn't level")
	line.free()
	l2.free()
	capped.free()


func test_encounter_choice_previews_the_gain() -> void:
	var root := Control.new()
	var btn := EncounterChoiceButton.new()
	root.add_child(btn)
	var h := RunEncounter._hero_for_button({"name": "Ilse", "class": "healer", "base": "healer", "tier": "base",
		"level": 3, "memories": 2, "alignment": [0, 0], "items": {}})
	btn.setup({"id": "x", "class": "healer", "label": "Ask", "shift": {"good": 0, "law": 1}}, h, 0, 276)
	var want := HeroStats.level_gain({"class": "healer", "level": 3})
	eq(var_to_str(btn.gain), var_to_str(want), "the row knows what Lv 3 → 4 gives")
	check(btn.level_line != null and btn.level_line.get_child_count() > 2, "line 3 shows the gains")
	var texts: Array = []
	for l in btn.level_line.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	check("Lv 3 → 4" in texts or "Lv 4" in texts, "line 3 names the level step: %s" % [texts])
	for s: String in want:
		check("%+d" % int(want[s]) in texts, "line 3 shows %s %+d" % [s, int(want[s])])
	var tip: Dictionary = btn.grid.get_meta("tip", {})
	check(String(tip.get("body", "")).contains("Lv 3 → 4: " + PartyModel.gain_words(want, ", ")), "the tooltip says it in words")
	# at max level: it won't level
	var mx := RunEncounter._hero_for_button({"name": "Ilse", "class": "healer", "base": "healer", "tier": "base",
		"level": 6, "memories": 5, "alignment": [0, 0], "items": {}})
	var b2 := EncounterChoiceButton.new()
	root.add_child(b2)
	b2.setup({"id": "y", "class": "healer", "label": "Ask", "shift": {"good": 0, "law": 1}}, mx, 0, 276)
	check(b2.at_max and b2.gain.is_empty(), "at max level nothing is gained")
	var t2: Array = []
	for l in b2.level_line.find_children("*", "Label", true, false):
		t2.append((l as Label).text)
	check("Max level: Awaken to grow" in t2, "it says so: %s" % [t2])
	# an Awakened hero's gain uses its real class, not the base class the row's portrait shows
	var ah := RunEncounter._hero_for_button({"name": "Vael", "class": "paladin", "base": "fighter", "tier": "advanced",
		"level": 2, "memories": 2, "alignment": [0, 0], "items": {}})
	var b3 := EncounterChoiceButton.new()
	root.add_child(b3)
	b3.setup({"id": "z", "class": "fighter", "label": "Go", "shift": {"good": 1, "law": 0}}, ah, 0, 276)
	eq(var_to_str(b3.gain), var_to_str(HeroStats.level_gain({"class": "paladin", "level": 2})), "advanced: its own growth")
	root.free()


func test_encounter_result_line_names_the_gains() -> void:
	var h := {"name": "Wren", "class": "mage", "tier": "base", "level": 3, "items": {}}
	var l := RunEncounter.gain_line(h, {"level_before": 2, "level": 3})
	eq(String(l.get_meta("text")), "Level 3 gives Wren: " + PartyModel.gain_words(HeroStats.gain_between({"class": "mage"}, 2, 3)),
		"under the result card: what the level gave")
	l.free()


func test_hero_card_and_advance_card_explain_levels() -> void:
	var root := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var card := HeroCard.new()
	root.add_child(card)
	var h := PartyModel.normalize({"name": "Brannoc", "class": "fighter", "level": 3, "items": {}, "memories": [[0, 1], [1, 0]], "alignment": [1, 1]})
	card.set_hero(h)
	check(card.level_tip != null, "the Lv field has a tooltip")
	var body := String(card.level_tip.get_meta("tip", {}).get("body", ""))
	check(body.begins_with("Each memory raises this hero one level"), "it says what a level is")
	check(body.contains("Awakening starts the new class at Lv 1 with higher base stats"), "and what Awakening does to it")
	check(body.contains("Next level (Lv 4): " + PartyModel.gain_words(PartyModel.level_gain(h), ", ")), "and the next level's gains")
	var adv := AdvanceCard.new()
	root.add_child(adv)
	adv.set_hero(h, [])
	var why := String(adv.level_tip.get_meta("tip", {}).get("body", ""))
	var to := String(PartyModel.advanced_copy(h)["class"])
	check(why.contains("at Lv 1") and why.contains(PartyModel.growth_words(to, ", ")), "the advancement card explains Lv 1 and the growth")
	root.get_parent().remove_child(root)
	root.free()
