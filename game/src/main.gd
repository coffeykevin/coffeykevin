extends Node3D
## Bananarc — vertical slice orchestrator.
## Deterministic classic physics (Sim), per-round procedural obstruction
## skylines (CityGen), nine-sky weather/lighting (Weather), cell-based
## destruction (CityData/CityView), hot-seat + AI, physics overlay and
## debrief (AimOverlay/Hud). PRD: docs/PRD.md.

enum State { TITLE, AIMING, FLYING, PAUSE }

const POINTS_TO_WIN := 3
const GRAVITY := 9.8
const NAMES := ["KILO", "NEWTON"]
const ACCENTS := [Color("ffc93c"), Color("35c4f0")]
const ACCENT_HEX := ["ffc93c", "35c4f0"]
const GORILLA_RADIUS := 2.2

var state: int = State.TITLE
var vs_ai := false
var autotest := false
var match_seed := 0
var round_index := 0
var scores := [0, 0]
var current := 0
var throw_count := 0
var ai_attempts := [0, 0]
var aim := [{"angle": 45.0, "power": 60.0}, {"angle": 45.0, "power": 60.0}]

var city: CityData
var prev_city: CityData
var round_rng: Lcg
var wind := 0.0
var weather_index := 0

var camera: Camera3D
var weather: Weather
var city_view: CityView
var overlay: AimOverlay
var hud: Hud
var gorillas: Array[Gorilla] = []
var banana: MeshInstance3D

var _pts := PackedVector2Array()
var _play_idx := 0.0
var _fly_result: Dictionary = {}
var _windless_impact := Vector2.ZERO
var _throw_start := Vector2.ZERO
var _cam_center := Vector3.ZERO
var _cam_t := 0.0


func _ready() -> void:
	autotest = OS.get_environment("BANANARC_AUTOTEST") == "1"
	camera = Camera3D.new()
	camera.fov = 32.0
	add_child(camera)
	camera.current = true

	weather = Weather.new()
	weather.build(50.0, 70.0)
	add_child(weather)

	city_view = CityView.new()
	add_child(city_view)

	overlay = AimOverlay.new()
	overlay.build()
	add_child(overlay)

	for i in range(2):
		var g := Gorilla.new()
		g.build(ACCENTS[i], 1 if i == 0 else -1)
		add_child(g)
		gorillas.append(g)

	banana = MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.55
	bm.height = 1.1
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("f2be4c")
	bmat.roughness = 0.4
	bm.material = bmat
	banana.mesh = bm
	banana.scale = Vector3(1.5, 0.55, 0.55)
	banana.visible = false
	add_child(banana)

	hud = Hud.new()
	add_child(hud)
	hud.power_changed.connect(_on_power_changed)
	hud.angle_changed.connect(_on_angle_changed)
	hud.mode_picked.connect(_on_mode_picked)
	hud.rematch.connect(_on_rematch)

	if autotest:
		Engine.time_scale = 12.0
		print("[AUTOTEST] starting fixed-seed AI-vs-AI match")
		_on_mode_picked.call_deferred(true)
	else:
		hud.show_title(true)


func _on_mode_picked(p_vs_ai: bool) -> void:
	vs_ai = p_vs_ai
	hud.show_title(false)
	hud.hide_end()
	match_seed = 12345 if autotest else int(Time.get_unix_time_from_system()) % 100000
	round_index = 0
	scores = [0, 0]
	throw_count = 0
	hud.set_scores(0, 0, POINTS_TO_WIN)
	_next_round()


func _on_rematch() -> void:
	_on_mode_picked(vs_ai)


func _next_round() -> void:
	round_index += 1
	round_rng = Lcg.new(match_seed * 31 + round_index * 7919)
	weather_index = round_rng.randi_range(0, Weather.CONDITIONS.size() - 1)
	var cond := weather.apply(weather_index)
	hud.set_weather(cond)

	prev_city = city
	city = CityGen.generate(round_rng, GRAVITY, prev_city)
	city_view.build(city, cond["lit"], match_seed + round_index)
	wind = Sim.roll_wind(round_rng)
	hud.set_wind(wind)

	for i in range(2):
		gorillas[i].reset_pose()
		gorillas[i].position = Vector3(
			city.gorilla_spots[i].x, city.gorilla_spots[i].y, 0.0)
	overlay.trace_clear()
	overlay.clear_aim()
	hud.hide_debrief()

	_fit_camera()
	current = (round_index - 1) % 2
	ai_attempts = [0, 0]
	_begin_turn("ROUND %d — %s THROWS FIRST" % [round_index, NAMES[current]])


func _fit_camera() -> void:
	var w := city.world_width()
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var half_h := deg_to_rad(camera.fov) * 0.5
	var half_w := atan(tan(half_h) * aspect)
	var dist := (w * 0.5 + 10.0) / tan(half_w)
	_cam_center = Vector3(w * 0.5, 22.0, dist)
	camera.position = _cam_center
	camera.look_at(Vector3(w * 0.5, 18.0, 0.0))


func _begin_turn(msg: String) -> void:
	state = State.AIMING
	hud.set_turn(msg, ACCENTS[current])
	hud.set_power(aim[current]["power"])
	hud.set_angle(aim[current]["angle"])
	_refresh_aim_visuals()
	if _is_ai(current):
		_ai_take_turn()


func _is_ai(p: int) -> bool:
	if autotest:
		return true
	return vs_ai and p == 1


func _targets() -> Array:
	var out := []
	for i in range(2):
		out.append({
			"pos": Vector2(gorillas[i].position.x, gorillas[i].position.y + 2.0),
			"radius": GORILLA_RADIUS,
			"player": i,
		})
	return out


func _on_power_changed(v: float) -> void:
	if state != State.AIMING or _is_ai(current):
		return
	aim[current]["power"] = v
	_refresh_aim_visuals()


func _on_angle_changed(v: float) -> void:
	if state != State.AIMING or _is_ai(current):
		return
	aim[current]["angle"] = v
	_refresh_aim_visuals()


func _refresh_aim_visuals() -> void:
	if state != State.AIMING:
		return
	var g := gorillas[current]
	g.aim_pose(aim[current]["angle"])
	overlay.update_aim(g.hand_pos(aim[current]["angle"]),
		aim[current]["angle"], aim[current]["power"], g.facing,
		ACCENTS[current], GRAVITY)


func _ai_take_turn() -> void:
	await get_tree().create_timer(1.1).timeout
	if state != State.AIMING:
		return
	var g := gorillas[current]
	var plan := AiBrain.plan(city,
		Vector2(g.hand_pos(45.0).x, g.hand_pos(45.0).y), g.facing,
		_targets(), current, wind, GRAVITY, round_rng, ai_attempts[current])
	ai_attempts[current] += 1
	aim[current]["angle"] = plan["angle"]
	aim[current]["power"] = plan["power"]
	hud.set_power(plan["power"])
	hud.set_angle(plan["angle"])
	_refresh_aim_visuals()
	await get_tree().create_timer(0.7).timeout
	if state == State.AIMING:
		_throw()


func _unhandled_input(event: InputEvent) -> void:
	if state != State.AIMING or _is_ai(current):
		return
	if event.is_action_pressed("ui_accept"):
		_throw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var origin := camera.project_ray_origin(event.position)
		var dir := camera.project_ray_normal(event.position)
		if absf(dir.z) > 0.0001:
			var t := -origin.z / dir.z
			var hit := origin + dir * t
			if hit.distance_to(gorillas[current].position + Vector3(0, 2, 0)) < 6.0:
				_throw()


func _throw() -> void:
	state = State.FLYING
	throw_count += 1
	hud.hide_debrief()
	overlay.clear_aim()
	overlay.trace_clear()
	var angle: float = aim[current]["angle"]
	var power: float = aim[current]["power"]
	var g := gorillas[current]
	hud.set_turn("%s — %d° AT %d" % [NAMES[current], int(angle), int(power)],
		ACCENTS[current])
	g.throw_anim(angle, power, func() -> void: _launch(angle, power))


func _launch(angle: float, power: float) -> void:
	var g := gorillas[current]
	var hand := g.hand_pos(angle)
	_throw_start = Vector2(hand.x, hand.y)
	var res := Sim.simulate(city, _throw_start, angle, power, g.facing,
		wind, GRAVITY, _targets(), current, true)
	var windless := Sim.simulate(city, _throw_start, angle, power, g.facing,
		0.0, GRAVITY, _targets(), current, false)
	_windless_impact = windless["impact"]
	_fly_result = res
	_pts = res["points"]
	_play_idx = 0.0
	banana.visible = true
	banana.position = hand


func _process(delta: float) -> void:
	_cam_t += delta
	if city != null and state != State.TITLE:
		camera.position = _cam_center + Vector3(
			sin(_cam_t * 0.13) * 0.6, sin(_cam_t * 0.09) * 0.35, 0.0)
	if state != State.FLYING or _pts.is_empty():
		return
	var prev := int(_play_idx)
	_play_idx += delta / Sim.DT
	var idx := mini(int(_play_idx), _pts.size() - 1)
	var p := _pts[idx]
	banana.position = Vector3(p.x, p.y, 0.0)
	banana.rotation_degrees.z -= delta * 700.0 * float(gorillas[current].facing)
	for i in range(prev, idx, 14):
		overlay.trace_add(Vector3(_pts[i].x, _pts[i].y, 0.0))
	if idx >= _pts.size() - 1:
		_resolve()


func _resolve() -> void:
	state = State.PAUSE
	banana.visible = false
	var res := _fly_result
	var impact: Vector2 = res["impact"]
	var d := {
		"who": NAMES[current], "accent": ACCENT_HEX[current], "n": throw_count,
		"angle": int(aim[current]["angle"]), "power": int(aim[current]["power"]),
		"time": res["time"], "apex": res["apex"],
		"dist": absf(impact.x - _throw_start.x),
		"drift": impact.x - _windless_impact.x,
		"note": "",
	}
	match res["result"]:
		"gorilla":
			_explosion(Vector3(impact.x, impact.y, 0.0), 2.2)
			city.carve_world(impact, 5.0)
			city_view.refresh()
			_score_hit(res["player"])
			return
		"building":
			_explosion(Vector3(impact.x, impact.y, 0.0), 1.0)
			city.carve_world(impact, 3.5)
			city_view.refresh()
			d["note"] = "Hit a building — the crater is permanent."
			for i in range(2):
				if Vector2(gorillas[i].position.x, gorillas[i].position.y) \
						.distance_to(impact) < 12.0:
					gorillas[i].flinch()
		"ground":
			d["note"] = "Into the street. Watch the wind line."
		"oob":
			d["note"] = "Gone. The sun said nothing."
	hud.show_debrief(d)
	if autotest:
		print("[AUTOTEST] throw %d by %s: %s at (%.1f, %.1f) drift %.1f" % [
			throw_count, NAMES[current], res["result"], impact.x, impact.y, d["drift"]])
	await get_tree().create_timer(1.3).timeout
	current = 1 - current
	_begin_turn("%s'S THROW" % NAMES[current])


func _score_hit(victim: int) -> void:
	var scorer := 1 - victim
	scores[scorer] += 1
	hud.set_scores(scores[0], scores[1], POINTS_TO_WIN)
	gorillas[victim].defeat()
	gorillas[scorer].victory()
	var self_hit := victim == current
	var msg := "%s TAKES THE ROUND" % NAMES[scorer]
	if self_hit:
		msg = "%s HIT THEMSELF — POINT TO %s" % [NAMES[victim], NAMES[scorer]]
	hud.set_turn(msg, ACCENTS[scorer])
	if autotest:
		print("[AUTOTEST] round %d: %s (score %d-%d)" % [
			round_index, msg, scores[0], scores[1]])
	await get_tree().create_timer(2.6).timeout
	if scores[scorer] >= POINTS_TO_WIN:
		hud.show_end("%s WINS THE MATCH  %d–%d" % [
			NAMES[scorer], scores[0], scores[1]], ACCENTS[scorer])
		state = State.TITLE
		if autotest:
			print("[AUTOTEST] match over: %s wins %d-%d after %d throws — OK" % [
				NAMES[scorer], scores[0], scores[1], throw_count])
			get_tree().quit()
	else:
		_next_round()


func _explosion(at: Vector3, scale_f: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color("ff9e4a")
	light.light_energy = 10.0 * scale_f
	light.omni_range = 22.0 * scale_f
	light.position = at + Vector3(0, 1, 4)
	add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.6)
	tw.tween_callback(light.queue_free)

	var parts := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.6
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 80.0
	mat.initial_velocity_min = 6.0 * scale_f
	mat.initial_velocity_max = 14.0 * scale_f
	mat.gravity = Vector3(0, -14, 0)
	parts.process_material = mat
	var pm := BoxMesh.new()
	pm.size = Vector3(0.3, 0.3, 0.3)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("c66a3a")
	pm.material = pmat
	parts.draw_pass_1 = pm
	parts.amount = 42
	parts.lifetime = 1.1
	parts.one_shot = true
	parts.explosiveness = 1.0
	parts.emitting = true
	parts.position = at
	add_child(parts)
	get_tree().create_timer(2.0).timeout.connect(parts.queue_free)
