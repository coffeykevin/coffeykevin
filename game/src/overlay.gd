class_name AimOverlay
extends Node3D
## The physics overlay (PRD section 7): launch vector + live v-cos/v-sin
## component decomposition + angle arc + short windless ghost arc while
## aiming, and the white dotted trace during flight. Crisp unshaded UI
## floating above the world, never dressed into it.

const YELLOW := Color("ffc93c")
const CYAN := Color("35c4f0")
const WHITE := Color(1, 1, 1, 0.75)
const GHOST := Color(1, 1, 1, 0.35)

var _lines_mi: MeshInstance3D
var _im: ImmediateMesh
var _trace_mmi: MultiMeshInstance3D
var _trace_points: Array[Vector3] = []
var _z := 5.2


func build() -> void:
	_im = ImmediateMesh.new()
	_lines_mi = MeshInstance3D.new()
	_lines_mi.mesh = _im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lines_mi.material_override = mat
	add_child(_lines_mi)

	_trace_mmi = MultiMeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.32
	sph.height = 0.64
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1, 1, 1, 0.92)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sph.material = smat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sph
	mm.instance_count = 0
	_trace_mmi.multimesh = mm
	add_child(_trace_mmi)


func update_aim(origin: Vector3, angle_deg: float, power: float, facing: int,
		accent: Color, gravity: float) -> void:
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	var a := deg_to_rad(angle_deg)
	var dir := Vector3(cos(a) * float(facing), sin(a), 0)
	var len := 2.0 + power * 0.09
	var tip := origin + dir * len

	# Resultant launch vector (player color).
	_seg(origin, tip, accent)
	_arrow_head(tip, dir, accent)
	# Dashed components: v*cos(theta) and v*sin(theta).
	_dashed(origin, origin + Vector3(dir.x, 0, 0).normalized() * (len * cos(a)), WHITE)
	_dashed(origin, origin + Vector3(0, len * sin(a), 0), WHITE)
	# Angle arc (cyan).
	var steps := 14
	var r := 2.6
	for i in range(steps):
		var t0 := a * float(i) / float(steps)
		var t1 := a * float(i + 1) / float(steps)
		_seg(origin + Vector3(cos(t0) * r * facing, sin(t0) * r, 0),
			origin + Vector3(cos(t1) * r * facing, sin(t1) * r, 0), CYAN)
	# Short windless ghost arc — shape only, never the landing point.
	var v := power * Sim.VEL_SCALE
	var vx := cos(a) * v * float(facing)
	var vy := sin(a) * v
	var flight_est := maxf(2.0 * vy / gravity, 0.5)
	var t_end := flight_est * 0.2
	var prev := origin
	for i in range(1, 13):
		var t := t_end * float(i) / 12.0
		var p := origin + Vector3(vx * t, vy * t - 0.5 * gravity * t * t, 0)
		if i % 2 == 0:
			_seg(prev, p, GHOST)
		prev = p
	_im.surface_end()


func clear_aim() -> void:
	_im.clear_surfaces()


func _seg(a: Vector3, b: Vector3, col: Color) -> void:
	_im.surface_set_color(col)
	_im.surface_add_vertex(Vector3(a.x, a.y, _z))
	_im.surface_set_color(col)
	_im.surface_add_vertex(Vector3(b.x, b.y, _z))


func _dashed(a: Vector3, b: Vector3, col: Color) -> void:
	var n := 8
	for i in range(n):
		if i % 2 == 1:
			continue
		var t0 := float(i) / float(n)
		var t1 := float(i + 1) / float(n)
		_seg(a.lerp(b, t0), a.lerp(b, t1), col)


func _arrow_head(tip: Vector3, dir: Vector3, col: Color) -> void:
	var perp := Vector3(-dir.y, dir.x, 0)
	_seg(tip, tip - dir * 0.9 + perp * 0.5, col)
	_seg(tip, tip - dir * 0.9 - perp * 0.5, col)


func trace_clear() -> void:
	_trace_points.clear()
	_trace_mmi.multimesh.instance_count = 0


func trace_add(p: Vector3) -> void:
	_trace_points.append(Vector3(p.x, p.y, _z))
	var mm: MultiMesh = _trace_mmi.multimesh
	mm.instance_count = _trace_points.size()
	for i in range(_trace_points.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), _trace_points[i]))
