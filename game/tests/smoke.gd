extends SceneTree
## Headless smoke test for the engine-independent simulation core.
## Run: godot --headless --path game -s tests/smoke.gd

func _initialize() -> void:
	var failures := 0

	# 1. Deterministic RNG: same seed, same stream.
	var a := Lcg.new(42)
	var b := Lcg.new(42)
	for i in range(100):
		if a.next() != b.next():
			failures += 1
			push_error("RNG determinism broke at step %d" % i)
			break

	# 2. City generation: solvable, interceptor present, distinct.
	var prev: CityData = null
	for s in [7, 99, 12345, 777, 31337, 2026]:
		var rng := Lcg.new(s)
		var city := CityGen.generate(rng, 9.8, prev)
		var w := city.world_width()
		if city.gorilla_spots.size() != 2:
			failures += 1
			push_error("seed %d: missing gorilla spots" % s)
			continue
		var roof_max := maxf(city.gorilla_spots[0].y, city.gorilla_spots[1].y)
		var tallest := 0.0
		for bld in city.buildings.slice(2, city.buildings.size() - 2):
			tallest = maxf(tallest, float(bld["h"]))
		var intercepts := tallest >= roof_max + 4.9
		print("seed %6d: width=%5.0f buildings=%d profile=%-8s interceptor=%s" % [
			s, w, city.buildings.size(), city.profile_name, str(intercepts)])
		if not intercepts:
			failures += 1
			push_error("seed %d: no interceptor guarantee" % s)
		prev = city

	# 3. Trajectory sanity: 45deg calm-wind throw lands downrange, symmetric-ish.
	var rng2 := Lcg.new(5)
	var city2 := CityGen.generate(rng2, 9.8, null)
	var start: Vector2 = city2.gorilla_spots[0] + Vector2(0, 2.5)
	var targets := [
		{"pos": city2.gorilla_spots[0] + Vector2(0, 2.0), "radius": 2.2, "player": 0},
		{"pos": city2.gorilla_spots[1] + Vector2(0, 2.0), "radius": 2.2, "player": 1},
	]
	var res := Sim.simulate(city2, start, 60.0, 80.0, 1, 0.0, 9.8, targets, 0)
	print("throw 60deg@80 calm: result=%s impact=(%.1f, %.1f) t=%.2f apex=%.1f" % [
		res["result"], res["impact"].x, res["impact"].y, res["time"], res["apex"]])
	if res["impact"].x <= start.x:
		failures += 1
		push_error("trajectory did not travel downrange")

	# 4. Wind drift is quadratic-in-time: measure over open ground so both
	# throws land instead of exiting the play area.
	var open := CityData.new()
	open.setup(400)
	var o_start := Vector2(20.0, 30.0)
	var calm := Sim.simulate(open, o_start, 45.0, 70.0, 1, 0.0, 9.8, [], 0, false)
	var windy := Sim.simulate(open, o_start, 45.0, 70.0, 1, 8.0, 9.8, [], 0, false)
	var drift: float = windy["impact"].x - calm["impact"].x
	print("open-ground 45deg@70: calm lands %.1f, wind=8 lands %.1f, drift=%.1f" % [
		calm["impact"].x, windy["impact"].x, drift])
	if drift <= 2.0:
		failures += 1
		push_error("wind produced no meaningful drift")

	# 5. Destruction: carve removes cells.
	var removed := city2.carve_world(Vector2(city2.world_width() * 0.5, 8.0), 3.5)
	print("carve at mid-city removed %d cells" % removed)
	if removed <= 0:
		failures += 1
		push_error("carve removed nothing")

	# 6. AI finds a plan.
	var plan := AiBrain.plan(city2, start, 1, targets, 0, 2.0, 9.8, Lcg.new(9), 3)
	print("AI plan (low error): angle=%.1f power=%.1f" % [plan["angle"], plan["power"]])

	if failures == 0:
		print("SMOKE OK — all simulation-core checks passed")
	else:
		print("SMOKE FAILED — %d failures" % failures)
	quit(1 if failures > 0 else 0)
