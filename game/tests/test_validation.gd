extends "res://tests/test_case.gd"
## Hostile input for async PvP: Echoes and sim sides must be rejected cleanly
## (an error, never a script error or a silently "fixed" party).

const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
const Echo = preload("res://core/echo.gd")

const HDR := '{"format":"echoing_depths.echo","version":1,"heroes":'
const BAD_ECHOES := [
	'[{"class":"fighter","level":2.7,"slot":[0,0]}]',                       # fractional level
	'[{"class":"fighter","level":1,"slot":[0.5,0]}]',                       # fractional slot
	'[{"class":"fighter","level":1e300,"slot":[0,0]}]',                     # absurd level
	'[{"class":"shard_golem","level":10,"slot":[0,0]}]',                    # monster in a player Echo
	'[{"class":"lantern_saint","level":4,"slot":[0,0]},{"class":"lantern_saint","level":4,"slot":[0,1]}]',  # 2 Legendaries
	'[{"class":"fighter","level":1,"slot":[0,0],"items":{"weapon":"dawn_locket"}}]',  # relic in weapon slot
	'[{"class":"fighter","level":1,"slot":[0,0],"items":{"trinket":"iron_sword"}}]',  # unknown slot
	'[{"class":"fighter","level":1,"slot":[0,0],"items":["iron_sword"]}]',  # items not an object
	'[{"class":5,"level":1,"slot":[0,0]}]',                                 # class not a string
	'[{"class":"fighter","level":1,"slot":["0","1"]}]',                     # slot strings
	'[{"class":"fighter","level":1,"slot":null}]',                          # no slot
	'[{"class":"fighter","level":1,"slot":[0,0],"alignment":[3,0]}]',       # alignment off grid
	'[{"class":"fighter","level":1,"slot":[0,0],"name":7}]',                # name not a string
	'"x"',                                                                  # heroes not an array
	'[]',                                                                   # empty party
	'[{"class":"fighter","level":1,"slot":[0,0]}]',                         # 1 hero (parties start at 2)
	'[{"class":"fighter","level":1,"slot":[0,0]},{"class":"mage","level":1,"slot":[1,0],"name":"AAAAAAAAAAAAAAAAAAAAAAAAA"}]',  # name too long
]
const BAD_TOP := [
	'{"format":["x"],"version":1,"heroes":[]}',
	'{"format":"echoing_depths.echo","version":"1","heroes":[]}',
	'{"format":"echoing_depths.echo","version":1,"data_version":[1],"heroes":%s}',
	'{"format":"echoing_depths.echo","version":1,"data_version":{"a":1},"heroes":%s}',
	'{"format":"echoing_depths.echo","version":1,"data_version":1e300,"heroes":%s}',
	'{"format":"echoing_depths.echo","version":1,"name":["n"],"heroes":%s}',
	'{"format":"echoing_depths.echo","version":1,"name":"%s","heroes":%%s}',
	'{"format":"echoing_depths.echo","version":1,"meta":[1],"heroes":%s}',
	'{"format":"echoing_depths.echo","version":1,"meta":{"x":"%s"},"heroes":%%s}',
]
const GOOD_HEROES := '[{"class":"fighter","level":1,"slot":[0,0]},{"class":"mage","level":1,"slot":[1,0]}]'


func test_hostile_echo_json_rejected() -> void:
	for body: String in BAD_ECHOES:
		var res := Echo.from_json(HDR + body + "}")
		check(res.has("error"), "rejected: %s" % body)
	check(Echo.from_json('{"format":"echoing_depths.echo","version":1.9,"heroes":[]}').has("error"), "fractional version rejected")
	var ok := Echo.from_json(HDR + '[{"class":"fighter","level":2.0,"slot":[0,1]},{"class":"lantern_saint","level":4,"slot":[0,0]}]}')
	check(not ok.has("error"), "whole-number floats (from JSON) and one Legendary are fine: %s" % ok.get("error", ""))


func test_hostile_echo_top_level_rejected() -> void:
	for tpl: String in BAD_TOP:
		var txt := tpl
		if txt.contains('"%s"'):
			txt = txt % ["N".repeat(5000)]
		if txt.contains("%s"):
			txt = txt % [GOOD_HEROES]
		var res := Echo.from_json(txt)
		check(res.has("error") and not res.has("echo"), "rejected: %s" % txt.left(90))
	check(Echo.from_json("A".repeat(70000)).has("error"), "huge input rejected")
	var ok := Echo.from_json('{"format":"echoing_depths.echo","version":1,"data_version":1,"name":"Ok","meta":{"depth":3},"heroes":%s}' % GOOD_HEROES)
	check(not ok.has("error"), "a well-formed Echo is accepted: %s" % ok.get("error", ""))


func test_64_bit_seeds_distinct() -> void:
	var a := CombatSim.simulate(0, PartyGen.demo_party(), PartyGen.demo_rival())
	var b := CombatSim.simulate(0x100000001, PartyGen.demo_party(), PartyGen.demo_rival())
	check(JSON.stringify(a["events"]) != JSON.stringify(b["events"]), "seeds 0 and 0x100000001 play different fights")


func test_sim_rejects_bad_sides() -> void:
	var std := PartyGen.demo_party()
	var eight: Array = []
	for i in 8:
		eight.append(hero("fighter", i >> 2, i % 4, 6))
	var cases := {
		"8-hero player side": party(eight),
		"1-hero player side": party([hero("fighter", 0, 0)]),
		"monster mixed into heroes": party([hero("fighter", 0, 0), hero("hollow_rat", 0, 1)]),
		"items array": party([{"class": "fighter", "level": 1, "slot": [0, 0], "items": ["x"]}]),
		"class int": party([{"class": 5, "level": 1, "slot": [0, 0]}]),
		"level 2.9": party([hero("fighter", 0, 0, 1)]),
		"no heroes key": {},
		"heroes not array": {"heroes": "x"},
		"hero not dict": {"heroes": [3]},
	}
	cases["level 2.9"]["heroes"][0]["level"] = 2.9
	for name: String in cases:
		var r := CombatSim.simulate(1, cases[name], std)
		check(r.has("error") and (r["events"] as Array).is_empty() and int(r["winner"]) == -1, "%s -> error dict" % name)


func test_monster_side_may_fill_grid() -> void:
	var m: Array = []
	for i in 8:
		m.append(hero("hollow_rat", i >> 2, i % 4, 1))
	var r := CombatSim.simulate(1, PartyGen.demo_party(), party(m))
	check(not r.has("error"), "8 monsters on a monster side are allowed")
