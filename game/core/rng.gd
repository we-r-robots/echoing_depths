extends RefCounted
## Deterministic seeded RNG (xoshiro128**), implemented in pure integer math so
## results never depend on the engine's RandomNumberGenerator implementation.
## Never use global randomness (randi(), randf(), randomize()) in game/core.

const M32 := 0xFFFFFFFF

var _s0 := 0
var _s1 := 0
var _s2 := 0
var _s3 := 0


func _init(seed_value: int = 0) -> void:
	reseed(seed_value)


func reseed(seed_value: int) -> void:
	# Seeds below 2^32 keep their historical streams; higher bits are mixed in, so every
	# 64-bit seed gives its own stream (0 and 0x100000001 differ).
	var x := seed_value & M32
	var hi := (seed_value >> 32) & M32
	if hi != 0:
		x = _mix(x ^ _mix(hi + 0x632BE5AB))
	x = _mix(x + 0x9E3779B9)
	_s0 = x
	x = _mix(x + 0x9E3779B9)
	_s1 = x
	x = _mix(x + 0x9E3779B9)
	_s2 = x
	x = _mix(x + 0x9E3779B9)
	_s3 = x
	if (_s0 | _s1 | _s2 | _s3) == 0:
		_s0 = 1


## 32-bit multiply without risking signed 64-bit overflow.
static func mul32(a: int, b: int) -> int:
	a &= M32
	b &= M32
	var lo := a * (b & 0xFFFF)
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & M32


static func _mix(v: int) -> int:
	var z := v & M32
	z = mul32(z ^ (z >> 16), 0x85EBCA6B)
	z = mul32(z ^ (z >> 13), 0xC2B2AE35)
	return (z ^ (z >> 16)) & M32


static func _rotl(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & M32


## Next raw 32-bit unsigned value.
func next_u32() -> int:
	var result := (_rotl((_s1 * 5) & M32, 7) * 9) & M32
	var t := (_s1 << 9) & M32
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = _rotl(_s3, 11)
	return result


## Uniform float in [0, 1).
func next_float() -> float:
	return float(next_u32()) / 4294967296.0


## Uniform int in [lo, hi] inclusive.
func int_range(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + next_u32() % (hi - lo + 1)


## Uniform float in [lo, hi).
func float_range(lo: float, hi: float) -> float:
	return lo + (hi - lo) * next_float()


## Pick an element of a non-empty array.
func pick(arr: Array) -> Variant:
	return arr[int_range(0, arr.size() - 1)]
