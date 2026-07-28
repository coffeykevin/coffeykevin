class_name CityView
extends Node3D
## Renders the CityData occupancy grid as real 3D volumes (one cell = one
## box instance) plus emissive window quads, ground, and non-play depth
## lanes. Carving a crater just rebuilds the MultiMeshes from the grid, so
## the visual is always exactly the collision truth.

const DEPTH := 10.0

var city: CityData
var _cells_mmi: MultiMeshInstance3D
var _win_mmi: MultiMeshInstance3D
var _static_root: Node3D
var _lit_fraction := 0.3
var _win_seed := 0


func build(p_city: CityData, lit_fraction: float, win_seed: int) -> void:
	city = p_city
	_lit_fraction = lit_fraction
	_win_seed = win_seed
	for c in get_children():
		c.queue_free()

	_cells_mmi = MultiMeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CityData.CELL, CityData.CELL, DEPTH)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	box.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	_cells_mmi.multimesh = mm
	add_child(_cells_mmi)

	_win_mmi = MultiMeshInstance3D.new()
	var wbox := BoxMesh.new()
	wbox.size = Vector3(0.55, 0.72, 0.1)
	var wmat := StandardMaterial3D.new()
	wmat.emission_enabled = true
	wmat.emission = Color("ffb35c")
	wmat.emission_energy_multiplier = 2.2
	wmat.albedo_color = Color(0.1, 0.08, 0.05)
	wbox.material = wmat
	var wmm := MultiMesh.new()
	wmm.transform_format = MultiMesh.TRANSFORM_3D
	wmm.mesh = wbox
	_win_mmi.multimesh = wmm
	add_child(_win_mmi)

	refresh()
	_build_static()


## Rebuild instances from the grid (called after every crater).
func refresh() -> void:
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var wins: Array[Transform3D] = []
	var b_of_col := _building_lookup()
	for cy in range(CityData.SKY_CELLS):
		for cx in range(city.width_cells):
			if city.cell(cx, cy) == 0:
				continue
			var base: Color = b_of_col[cx]
			var jitter := 0.92 + 0.08 * float((cx * 7 + cy * 13) % 10) / 10.0
			var ao := clampf(0.5 + float(cy) / 40.0, 0.55, 1.0)
			cols.append(base * jitter * ao)
			xf.append(Transform3D(Basis(), Vector3(
				(cx + 0.5) * CityData.CELL, (cy + 0.5) * CityData.CELL, 0.0)))
			if cx % 3 == 1 and cy % 4 == 2:
				var h := (cx * 131 + cy * 197 + _win_seed) % 100
				if h < int(_lit_fraction * 100.0):
					wins.append(Transform3D(Basis(), Vector3(
						(cx + 0.5) * CityData.CELL,
						(cy + 0.5) * CityData.CELL,
						DEPTH * 0.5 + 0.06)))
	var mm: MultiMesh = _cells_mmi.multimesh
	mm.instance_count = xf.size()
	for i in range(xf.size()):
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var wmm: MultiMesh = _win_mmi.multimesh
	wmm.instance_count = wins.size()
	for i in range(wins.size()):
		wmm.set_instance_transform(i, wins[i])


func _building_lookup() -> Array[Color]:
	var out: Array[Color] = []
	out.resize(city.width_cells)
	for b in city.buildings:
		for cx in range(b["x0"], b["x0"] + b["w"]):
			if cx < city.width_cells:
				out[cx] = b["color"]
	for i in range(out.size()):
		if out[i] == Color():
			out[i] = CityGen.PALETTE[0]
	return out


## Ground plane, background depth lanes, landmark spire, water tower —
## non-play dressing (PRD: depth is presentation; only the throw plane collides).
func _build_static() -> void:
	_static_root = Node3D.new()
	add_child(_static_root)
	var w := city.world_width()

	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(w + 400.0, 2.0, 320.0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("1a1714")
	gmat.roughness = 1.0
	gm.material = gmat
	ground.mesh = gm
	ground.position = Vector3(w * 0.5, -1.0, -40.0)
	_static_root.add_child(ground)

	var lane_rng := Lcg.new(_win_seed * 17 + 3)
	for lane in range(2):
		var z := -26.0 - 22.0 * float(lane)
		var shade := 0.55 - 0.18 * float(lane)
		var x := -30.0
		while x < w + 30.0:
			var bw := 8.0 + lane_rng.randf() * 10.0
			var bh := 10.0 + lane_rng.randf() * (34.0 + 10.0 * float(lane))
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(bw, bh, 12.0)
			var bmat := StandardMaterial3D.new()
			var base: Color = CityGen.PALETTE[lane_rng.randi_range(0, CityGen.PALETTE.size() - 1)]
			bmat.albedo_color = base * shade
			bmat.roughness = 0.95
			bm.material = bmat
			mi.mesh = bm
			mi.position = Vector3(x + bw * 0.5, bh * 0.5, z)
			_static_root.add_child(mi)
			x += bw + 2.0 + lane_rng.randf() * 4.0

	# Landmark spire in the far lane.
	var spire := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(7.0, 58.0, 7.0)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color("8a7358") * 0.5
	sm.material = smat
	spire.mesh = sm
	spire.position = Vector3(w * 0.62, 29.0, -52.0)
	_static_root.add_child(spire)
	var needle := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.12
	nm.bottom_radius = 0.5
	nm.height = 14.0
	nm.material = smat
	needle.mesh = nm
	needle.position = Vector3(w * 0.62, 65.0, -52.0)
	_static_root.add_child(needle)

	# Trestle water tower on a mid background building.
	var tower := Node3D.new()
	tower.position = Vector3(w * 0.34, 0.0, -27.0)
	var t_base_h := 30.0
	var tank := MeshInstance3D.new()
	var tk := CylinderMesh.new()
	tk.top_radius = 3.0
	tk.bottom_radius = 3.2
	tk.height = 4.5
	var tkm := StandardMaterial3D.new()
	tkm.albedo_color = Color("5e432c")
	tkm.roughness = 0.9
	tk.material = tkm
	tank.mesh = tk
	tank.position = Vector3(0, t_base_h + 5.0, 0)
	tower.add_child(tank)
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 3.4
	cm.height = 2.2
	cm.material = tkm
	cap.mesh = cm
	cap.position = Vector3(0, t_base_h + 8.3, 0)
	tower.add_child(cap)
	for i in range(4):
		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.18
		lm.bottom_radius = 0.18
		lm.height = 5.5
		lm.material = tkm
		leg.mesh = lm
		var ang := float(i) * TAU / 4.0 + 0.4
		leg.position = Vector3(cos(ang) * 2.1, t_base_h + 0.4, sin(ang) * 2.1)
		tower.add_child(leg)
	_static_root.add_child(tower)
