class_name Weather
extends Node3D
## The nine-sky weather & lighting system (PRD section 9). Real light only:
## a DirectionalLight3D sun/moon positioned from the round's clock time,
## environment sky + fog per condition, GPU particles for rain/snow, and
## ambient lightning flashes in storms. Presentation-first: nothing here
## touches the simulation.

const CONDITIONS := [
	{"name": "CLEAR DAY", "time": "2:00 PM", "elev": 55.0, "azim": -25.0,
		"energy": 1.3, "sun": Color("fff4e0"), "top": Color("3d7fc4"),
		"horizon": Color("a8cce8"), "fog": 0.0, "precip": "none",
		"lightning": false, "lit": 0.06, "ambient": 1.0},
	{"name": "CLOUDY", "time": "3:15 PM", "elev": 45.0, "azim": -25.0,
		"energy": 0.5, "sun": Color("cfd4d8"), "top": Color("79838c"),
		"horizon": Color("a8aeb4"), "fog": 0.002, "precip": "none",
		"lightning": false, "lit": 0.15, "ambient": 1.1},
	{"name": "RAIN", "time": "4:50 PM", "elev": 30.0, "azim": -25.0,
		"energy": 0.35, "sun": Color("c2c8ce"), "top": Color("525c66"),
		"horizon": Color("7e8890"), "fog": 0.008, "precip": "rain",
		"lightning": false, "lit": 0.3, "ambient": 0.9},
	{"name": "STORM", "time": "5:30 PM", "elev": 20.0, "azim": -25.0,
		"energy": 0.22, "sun": Color("aab4c8"), "top": Color("171c28"),
		"horizon": Color("3a4254"), "fog": 0.01, "precip": "rain",
		"lightning": true, "lit": 0.45, "ambient": 0.7},
	{"name": "SUNSET", "time": "7:45 PM", "elev": 8.0, "azim": -35.0,
		"energy": 1.1, "sun": Color("ffb36b"), "top": Color("5c3a66"),
		"horizon": Color("f2913f"), "fog": 0.002, "precip": "none",
		"lightning": false, "lit": 0.5, "ambient": 0.8},
	{"name": "CLEAR NIGHT", "time": "11:30 PM", "elev": 35.0, "azim": 20.0,
		"energy": 0.25, "sun": Color("bfd4f2"), "top": Color("060b22"),
		"horizon": Color("1a2e5c"), "fog": 0.0, "precip": "none",
		"lightning": false, "lit": 0.85, "ambient": 0.5},
	{"name": "MORNING", "time": "6:30 AM", "elev": 6.0, "azim": 30.0,
		"energy": 1.0, "sun": Color("ffd9a0"), "top": Color("8fa0b8"),
		"horizon": Color("f2d6a4"), "fog": 0.004, "precip": "none",
		"lightning": false, "lit": 0.35, "ambient": 0.9},
	{"name": "FOGGY", "time": "8:10 AM", "elev": 25.0, "azim": -25.0,
		"energy": 0.4, "sun": Color("d8dce0"), "top": Color("aeb4b8"),
		"horizon": Color("c6ccd0"), "fog": 0.014, "precip": "none",
		"lightning": false, "lit": 0.25, "ambient": 1.2},
	{"name": "SNOW", "time": "9:20 AM", "elev": 30.0, "azim": -25.0,
		"energy": 0.6, "sun": Color("e8eef4"), "top": Color("6e7c8c"),
		"horizon": Color("b4c0cb"), "fog": 0.006, "precip": "snow",
		"lightning": false, "lit": 0.3, "ambient": 1.1},
]

var sun: DirectionalLight3D
var world_env: WorldEnvironment
var rain: GPUParticles3D
var snow: GPUParticles3D
var current: Dictionary = CONDITIONS[0]
var _base_energy := 1.0
var _flash := 0.0
var _next_flash := 4.0


func build(center_x: float, span: float) -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)

	rain = _make_precip(center_x, span, true)
	snow = _make_precip(center_x, span, false)
	add_child(rain)
	add_child(snow)


func _make_precip(center_x: float, span: float, is_rain: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(span * 0.7, 2.0, 18.0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 3.0
	if is_rain:
		mat.initial_velocity_min = 26.0
		mat.initial_velocity_max = 34.0
		mat.gravity = Vector3(0, -18, 0)
	else:
		mat.initial_velocity_min = 2.0
		mat.initial_velocity_max = 4.0
		mat.gravity = Vector3(0, -1.5, 0)
	p.process_material = mat
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.7, 0.05) if is_rain else Vector3(0.14, 0.14, 0.14)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(0.75, 0.82, 0.9, 0.5) if is_rain else Color(1, 1, 1, 0.9)
	mesh.material = mm
	p.draw_pass_1 = mesh
	p.amount = 1400 if is_rain else 700
	p.lifetime = 2.2 if is_rain else 14.0
	p.visibility_aabb = AABB(Vector3(-span, -60, -25), Vector3(span * 2.0, 70.0, 50.0))
	p.position = Vector3(center_x, 52.0, 0.0)
	p.emitting = false
	return p


func apply(index: int) -> Dictionary:
	current = CONDITIONS[index]
	var env: Environment = world_env.environment
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
	sky_mat.sky_top_color = current["top"]
	sky_mat.sky_horizon_color = current["horizon"]
	sky_mat.ground_bottom_color = current["top"].darkened(0.6)
	sky_mat.ground_horizon_color = current["horizon"].darkened(0.3)
	env.ambient_light_energy = current["ambient"]
	var fog: float = current["fog"]
	env.fog_enabled = fog > 0.0
	env.fog_density = fog
	env.fog_light_color = current["horizon"]

	sun.rotation_degrees = Vector3(-current["elev"], current["azim"], 0.0)
	sun.light_color = current["sun"]
	sun.light_energy = current["energy"]
	_base_energy = current["energy"]

	rain.emitting = current["precip"] == "rain"
	snow.emitting = current["precip"] == "snow"
	_flash = 0.0
	return current


func _process(delta: float) -> void:
	if not current.get("lightning", false):
		return
	if _flash > 0.0:
		_flash -= delta
		sun.light_energy = _base_energy + maxf(_flash, 0.0) * 14.0
		if _flash <= 0.0:
			sun.light_energy = _base_energy
	else:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 0.16
			_next_flash = 3.0 + randf() * 6.0  # visual only; never gameplay RNG
