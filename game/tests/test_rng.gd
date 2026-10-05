extends "res://tests/test_case.gd"

const Rng = preload("res://core/rng.gd")


func test_golden_sequence() -> void:
	# Pinned values: if these change, every stored Echo replay changes. Don't.
	var r := Rng.new(12345)
	var got: Array = []
	for i in 5:
		got.append(r.next_u32())
	eq(got, GOLDEN, "xoshiro128** sequence for seed 12345")


func test_same_seed_same_stream() -> void:
	var a := Rng.new(99)
	var b := Rng.new(99)
	var same := true
	for i in 1000:
		if a.next_u32() != b.next_u32():
			same = false
	check(same, "two RNGs with one seed agree")
	var c := Rng.new(100)
	var d := Rng.new(99)
	check(c.next_u32() != d.next_u32(), "different seeds differ")


func test_ranges() -> void:
	var r := Rng.new(7)
	var ok := true
	var seen := {}
	for i in 5000:
		var f := r.next_float()
		var n := r.int_range(-2, 2)
		if f < 0.0 or f >= 1.0 or n < -2 or n > 2:
			ok = false
		seen[n] = true
	check(ok, "values within range")
	eq(seen.size(), 5, "every int in [-2,2] produced")


func test_big_and_negative_seeds() -> void:
	var a := Rng.new(-1)
	var b := Rng.new(0x7FFFFFFFFFFFFFFF)
	check(a.next_u32() >= 0 and b.next_u32() >= 0, "seeds of any sign/size work")

const GOLDEN := [4164816853, 1512695896, 313911497, 659662091, 1721386193]
