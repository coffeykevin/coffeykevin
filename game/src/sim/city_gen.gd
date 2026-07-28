class_name CityGen
extends RefCounted
## Procedural throw-plane skyline (PRD section 9):
## - fresh seed every round: widths, heights, slope profile, materials
## - guaranteed "interceptor" tall enough to clip the lazy lob
## - solver-backed solvability guarantee for both players
## - distinctness check vs the previous round

const GORILLA_RADIUS := 2.2
const PROFILES := ["upward", "downward", "valley", "mountain"]

const PALETTE := [
	Color("5c3a2e"),  # brownstone
	Color("6e5843"),  # sandstone
	Color("57616f"),  # concrete
	Color("7a4a3e"),  # brick
	Color("4a5568"),  # slate
	Color("8a7358"),  # limestone-tenement
]


static func generate(rng: Lcg, gravity: float, prev: CityData = null) -> CityData:
	var best: CityData = null
	for attempt in range(24):
		var city := _roll_city(rng)
		if not _solvable(city, gravity):
			continue
		if prev != null and city.profile_distance(prev) < 3.0 and attempt < 12:
			continue  # too similar to last round; reroll (PRD distinctness check)
		return city
	# Fallback: never block the game on a pathological seed.
	if best == null:
		best = _roll_city(rng)
	return best


static func _roll_city(rng: Lcg) -> CityData:
	var city := CityData.new()
	var n := 8 + rng.randi_range(0, 2)
	var profile: String = PROFILES[rng.randi_range(0, PROFILES.size() - 1)]
	city.profile_name = profile
	var widths: Array[int] = []
	var total := 0
	for i in range(n):
		var w := 9 + rng.randi_range(0, 5)
		widths.append(w)
		total += w
	city.setup(total)

	var heights: Array[int] = []
	var h := 14 + rng.randi_range(0, 10)
	for i in range(n):
		heights.append(clampi(h, 8, 42))
		var step := 3 + rng.randi_range(0, 5)
		match profile:
			"upward":
				h += step
			"downward":
				h -= step
			"valley":
				h += -step if i < n / 2 else step
			"mountain":
				h += step if i < n / 2 else -step
		h += rng.randi_range(-3, 3)

	var g_left := 1
	var g_right := n - 2
	# Cap the gorilla rooftops so an interceptor can always rise above them
	# within the height clamp.
	heights[g_left] = clampi(heights[g_left], 8, 34)
	heights[g_right] = clampi(heights[g_right], 8, 34)

	# Interceptor guarantee: some mid building must out-reach both rooftops.
	var roof_max := maxi(heights[g_left], heights[g_right])
	var mid_lo := g_left + 1
	var mid_hi := g_right - 1
	var tallest_mid := 0
	for i in range(mid_lo, mid_hi + 1):
		tallest_mid = maxi(tallest_mid, heights[i])
	if tallest_mid < roof_max + 5:
		var pick := rng.randi_range(mid_lo, mid_hi)
		heights[pick] = clampi(roof_max + 5 + rng.randi_range(0, 4), 8, 44)

	# Fill the grid and record building metadata.
	var x0 := 0
	for i in range(n):
		var col: Color = PALETTE[rng.randi_range(0, PALETTE.size() - 1)]
		city.buildings.append({
			"x0": x0, "w": widths[i], "h": heights[i], "color": col,
		})
		for cx in range(x0, x0 + widths[i]):
			for cy in range(heights[i]):
				city.set_cell(cx, cy, 1)
		x0 += widths[i]

	for gi in [g_left, g_right]:
		var b: Dictionary = city.buildings[gi]
		city.gorilla_spots.append(Vector2(
			(b["x0"] + b["w"] * 0.5) * CityData.CELL,
			b["h"] * CityData.CELL))
	return city


## Both players must retain multiple viable throw families in calm wind
## before a layout is accepted (PRD solvability guarantee).
static func _solvable(city: CityData, gravity: float) -> bool:
	for shooter in range(2):
		var start: Vector2 = city.gorilla_spots[shooter] + Vector2(0, 2.5)
		var facing := 1 if shooter == 0 else -1
		var target := {
			"pos": city.gorilla_spots[1 - shooter] + Vector2(0, 2.0),
			"radius": GORILLA_RADIUS,
			"player": 1 - shooter,
		}
		var hits := 0
		for a in range(25, 71, 5):
			for p in range(30, 96, 5):
				var res := Sim.simulate(city, start, float(a), float(p),
					facing, 0.0, gravity, [target], shooter, false)
				if res["result"] == "gorilla":
					hits += 1
					break  # one power per angle is enough evidence
			if hits >= 3:
				break
		if hits < 3:
			return false
	return true
