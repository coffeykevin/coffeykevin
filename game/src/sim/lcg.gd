class_name Lcg
extends RefCounted
## Deterministic PRNG for the simulation core. Engine-independent so async
## matches and replays stay bit-exact across platforms (PRD section 12).

var state: int


func _init(s: int) -> void:
	state = s & 0x7FFFFFFF
	if state == 0:
		state = 305419896


func next() -> int:
	state = (state * 1103515245 + 12345) & 0x7FFFFFFF
	return state


func randf() -> float:
	return float(next() % 1000000) / 1000000.0


func randi_range(a: int, b: int) -> int:
	if b <= a:
		return a
	return a + next() % (b - a + 1)


## Classic GORILLA.BAS FnRan(x) = INT(x * RND) + 1
func fn_ran(x: int) -> int:
	return int(randf() * float(x)) + 1
