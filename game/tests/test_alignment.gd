extends "res://tests/test_case.gd"

const Alignment = preload("res://core/alignment.gd")


func test_relic_offset_clamps() -> void:
	eq(Alignment.effective([2, 0], [1, 0]), [2, 0], "offset past the edge clamps to +2")
	eq(Alignment.effective([-2, -1], [-1, -1]), [-2, -2], "clamps both axes")
	eq(Alignment.effective([0, 1], [1, -1]), [1, 0], "plain offset")


func test_relic_buffer_example_from_spec() -> void:
	# Hero at Good +2 with a +1 Good relic absorbs a -1 memory: underlying +1, effective stays +2.
	var under := Alignment.apply_shift([2, 0], [-1, 0])
	eq(under, [1, 0], "underlying moves")
	eq(Alignment.effective(under, [1, 0]), [2, 0], "effective stays at the edge")


func test_underlying_stays_on_grid() -> void:
	eq(Alignment.apply_shift([2, -2], [2, -2]), [2, -2], "underlying clamps")


func test_relic_from_hero_items() -> void:
	var h := {"class": "healer", "alignment": [1, 1], "items": {"relic": "grave_coin", "weapon": "oak_staff"}}
	eq(Alignment.relic_offset(h), [-1, -1], "relic offset read from item data")
	eq(Alignment.effective_for_hero(h), [0, 0], "effective position for hero")
	eq(Alignment.relic_offset({"items": {"weapon": "iron_sword"}}), [0, 0], "weapons carry no alignment")


func test_regions() -> void:
	eq(Alignment.region_of([0, 2]), "N", "neutral cross")
	eq(Alignment.region_of([1, 1]), "LG", "lawful good")
	eq(Alignment.region_of([1, -2]), "CG", "chaotic good")
	eq(Alignment.region_of([-1, 1]), "LE", "lawful evil")
	eq(Alignment.region_of([-2, -2]), "CE*", "chaotic evil corner")
	eq(Alignment.region_of([2, 2]), "LG*", "lawful good corner")


func test_advanced_class_lookup() -> void:
	eq(Alignment.start_for("healer"), [1, 1], "healer fixed start")
	eq(Alignment.advanced_class_for("healer", [1, 1]), "cleric", "healer LG -> cleric")
	eq(Alignment.advanced_class_for("healer", [-2, -2]), "gravecaller", "far corner -> gravecaller (Necromancer dropped)")
	eq(Alignment.advanced_class_for("healer", [-1, -1]), "bloodletter", "healer CE -> bloodletter (round 2)")
	eq(Alignment.advanced_class_for("rogue", [2, -2]), "informant", "rogue CG* -> informant (round 3)")
	eq(Alignment.advanced_class_for("fighter", [2, 2]), "aegisbearer", "fighter LG* -> aegisbearer (round 3)")
	eq(Alignment.legendary_class_for("lightsworn"), "lantern_saint", "legendary lookup")
