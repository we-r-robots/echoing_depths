extends "res://tests/test_case.gd"
## BUILD.md "effects are icons" (user ruling 2026-10-05): hero detail shows each ability as its icon,
## name and a label of 20 characters or fewer; the full sentence is only in the tooltip.

const Actions = preload("res://core/data/abilities.gd")


func test_every_ability_has_a_short_label() -> void:
	for id: String in Actions.ACTIONS:
		var a: Dictionary = Actions.ACTIONS[id]
		var s := PartyModel.ability_short(a)
		check(s != "", "%s has a short label" % id)
		check(s.length() <= 20, "%s short label '%s' is 20 characters or fewer" % [id, s])
		check(not s.ends_with("…"), "%s short label '%s' is not cut" % [id, s])
