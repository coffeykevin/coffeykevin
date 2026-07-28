class_name Sim
extends RefCounted
## The deterministic trajectory integrator — the exact GORILLA.BAS model
## (PRD section 2), evaluated in closed form per fixed timestep:
##   x(t) = x0 + v*cos(a)*t + 0.5*(W/5)*t^2      (wind drift is quadratic)
##   y(t) = y0 + v*sin(a)*t - 0.5*g*t^2
## Power 0-100 maps linearly onto the classic velocity range (PRD 6.1).

const DT := 1.0 / 120.0
const VEL_SCALE := 0.5
const WIND_ACCEL := 0.1      # world-units/s^2 per wind unit (wind in [-10,10])
const MAX_T := 30.0
const SELF_IGNORE_T := 0.6   # thrower can't hit itself during the windup arc
const OTHER_IGNORE_T := 0.05

## targets: [{ "pos": Vector2, "radius": float, "player": int }]
## Returns { "result": "gorilla"|"building"|"ground"|"oob",
##           "impact": Vector2, "player": int, "time": float,
##           "apex": float, "points": PackedVector2Array }
static func simulate(city: CityData, start: Vector2, angle_deg: float,
		power: float, facing: int, wind: float, gravity: float,
		targets: Array, shooter: int, record := true) -> Dictionary:
	var v := power * VEL_SCALE
	var a := deg_to_rad(clampf(angle_deg, 0.0, 90.0))
	var vx := cos(a) * v * float(facing)
	var vy := sin(a) * v
	var ax := wind * WIND_ACCEL
	var pts := PackedVector2Array()
	var apex := start.y
	var t := 0.0
	var p := start
	while t < MAX_T:
		t += DT
		p = Vector2(
			start.x + vx * t + 0.5 * ax * t * t,
			start.y + vy * t - 0.5 * gravity * t * t)
		if record:
			pts.append(p)
		if p.y > apex:
			apex = p.y
		for tg in targets:
			var ignore := SELF_IGNORE_T if tg["player"] == shooter else OTHER_IGNORE_T
			if t > ignore and p.distance_to(tg["pos"]) <= tg["radius"]:
				return _done("gorilla", p, tg["player"], t, apex, pts)
		if city.solid_at_world(p):
			return _done("building", p, -1, t, apex, pts)
		if p.y <= 0.0:
			return _done("ground", p, -1, t, apex, pts)
		if p.x < -30.0 or p.x > city.world_width() + 30.0:
			return _done("oob", p, -1, t, apex, pts)
	return _done("oob", p, -1, t, apex, pts)


static func _done(kind: String, impact: Vector2, player: int, t: float,
		apex: float, pts: PackedVector2Array) -> Dictionary:
	return {
		"result": kind, "impact": impact, "player": player,
		"time": t, "apex": apex, "points": pts,
	}


## Classic wind roll: W = rand(10) - 5, with gust amplification chance.
static func roll_wind(rng: Lcg) -> float:
	var w := rng.randf() * 10.0 - 5.0
	if rng.randf() > 0.5:
		w += signf(w) * rng.randf() * 5.0
	return clampf(w, -10.0, 10.0)


static func wind_mph(w: float) -> int:
	return int(round(absf(w) * 2.3))
