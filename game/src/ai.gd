class_name AiBrain
extends RefCounted
## AI opponent (PRD 6.3). Plans with the same deterministic integrator the
## player plays against, then blurs the solution by a per-attempt error —
## so it converges like a human instead of sniping like a computer.

## Silverback tier: converges over 2-4 throws.
const ERR_BY_ATTEMPT := [
	{"angle": 9.0, "power": 14.0},
	{"angle": 5.0, "power": 8.0},
	{"angle": 2.0, "power": 3.5},
	{"angle": 0.8, "power": 1.5},
]


static func plan(city: CityData, shooter_pos: Vector2, facing: int,
		targets: Array, shooter: int, wind: float, gravity: float,
		rng: Lcg, attempt: int) -> Dictionary:
	var candidates: Array[Vector2] = []
	var best := Vector2(45, 60)
	var best_miss := 1e9
	var target_pos: Vector2 = Vector2.ZERO
	for tg in targets:
		if tg["player"] != shooter:
			target_pos = tg["pos"]
	for a in range(22, 73, 2):
		for p in range(28, 101, 3):
			var res := Sim.simulate(city, shooter_pos, float(a), float(p),
				facing, wind, gravity, targets, shooter, false)
			if res["result"] == "gorilla" and res["player"] != shooter:
				candidates.append(Vector2(a, p))
			else:
				var miss: float = res["impact"].distance_to(target_pos)
				if miss < best_miss:
					best_miss = miss
					best = Vector2(a, p)
	var pick := best
	if not candidates.is_empty():
		pick = candidates[rng.randi_range(0, candidates.size() - 1)]
	var err: Dictionary = ERR_BY_ATTEMPT[clampi(attempt, 0, ERR_BY_ATTEMPT.size() - 1)]
	var angle := clampf(pick.x + (rng.randf() * 2.0 - 1.0) * err["angle"], 5.0, 88.0)
	var power := clampf(pick.y + (rng.randf() * 2.0 - 1.0) * err["power"], 10.0, 100.0)
	return {"angle": angle, "power": power}
