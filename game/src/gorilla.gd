class_name Gorilla
extends Node3D
## Placeholder hero character built from primitives, with procedural
## animation (idle sway, windup-throw, flinch, defeat, chest-beat victory).
## Production replaces this node's visuals with the Meshy Polygonal Gorilla
## pipeline asset (PRD section 12) — the animation contract stays the same.

const FUR := Color("2e2822")
const FUR_DARK := Color("1c1510")

var facing := 1
var accent := Color("ffc93c")

var _root: Node3D
var _arm_pivot: Node3D
var _off_arm: Node3D
var _t := 0.0
var _state := "idle"
var _dance_beats := 0


func build(p_accent: Color, p_facing: int) -> void:
	accent = p_accent
	facing = p_facing
	_root = Node3D.new()
	add_child(_root)
	if facing < 0:
		_root.rotation_degrees.y = 180.0

	var body := _capsule(1.15, 2.6, FUR)
	body.position = Vector3(0, 1.7, 0)
	_root.add_child(body)

	var chest := _sphere(0.95, FUR_DARK)
	chest.position = Vector3(0.25, 2.1, 0)
	_root.add_child(chest)

	var head := _sphere(0.62, FUR)
	head.position = Vector3(0.35, 3.15, 0)
	_root.add_child(head)

	var muzzle := _sphere(0.3, FUR_DARK)
	muzzle.position = Vector3(0.85, 3.0, 0)
	_root.add_child(muzzle)

	var scarf := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.45
	tm.outer_radius = 0.7
	var smat := StandardMaterial3D.new()
	smat.albedo_color = accent
	tm.material = smat
	scarf.mesh = tm
	scarf.position = Vector3(0.2, 2.75, 0)
	scarf.rotation_degrees.x = 80.0
	_root.add_child(scarf)

	_arm_pivot = Node3D.new()
	_arm_pivot.position = Vector3(0.35, 2.75, 0.55)
	_root.add_child(_arm_pivot)
	var arm := _capsule(0.34, 1.9, FUR)
	arm.position = Vector3(0.0, -0.85, 0.0)
	_arm_pivot.add_child(arm)
	var fist := _sphere(0.42, FUR_DARK)
	fist.position = Vector3(0.0, -1.85, 0.0)
	_arm_pivot.add_child(fist)

	_off_arm = Node3D.new()
	_off_arm.position = Vector3(0.35, 2.75, -0.55)
	_root.add_child(_off_arm)
	var arm2 := _capsule(0.34, 1.9, FUR)
	arm2.position = Vector3(0.0, -0.85, 0.0)
	_off_arm.add_child(arm2)

	for side in [-0.45, 0.45]:
		var leg := _capsule(0.42, 1.5, FUR_DARK)
		leg.position = Vector3(-0.1, 0.6, side)
		_root.add_child(leg)


func _capsule(r: float, h: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	m.material = mat
	mi.mesh = m
	return mi


func _sphere(r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	m.material = mat
	mi.mesh = m
	return mi


## World-space release point for the current aim angle.
func hand_pos(angle_deg: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	var local := Vector3(0.35 + cos(a) * 2.0, 2.75 + sin(a) * 2.0, 0.55)
	if facing < 0:
		local.x = -local.x
	return global_position + local


## Arm tracks the ANGLE meter live while aiming (PRD animation set).
func aim_pose(angle_deg: float) -> void:
	if _state != "idle":
		return
	_arm_pivot.rotation_degrees.z = -(180.0 - angle_deg) + 90.0


func throw_anim(angle_deg: float, power: float, on_release: Callable) -> void:
	_state = "throw"
	var windup := clampf(0.35 + power / 240.0, 0.35, 0.8)
	var tw := create_tween()
	tw.tween_property(_arm_pivot, "rotation_degrees:z", 150.0, windup) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_root, "rotation_degrees:x", -8.0, windup)
	tw.tween_property(_arm_pivot, "rotation_degrees:z",
		-(180.0 - angle_deg) + 90.0, 0.13) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_root, "rotation_degrees:x", 10.0, 0.13)
	tw.tween_callback(on_release)
	tw.tween_property(_root, "rotation_degrees:x", 0.0, 0.4)
	tw.tween_callback(func() -> void: _state = "idle")


func flinch() -> void:
	if _state != "idle":
		return
	_state = "flinch"
	var tw := create_tween()
	tw.tween_property(_root, "scale:y", 0.72, 0.12)
	tw.tween_interval(0.35)
	tw.tween_property(_root, "scale:y", 1.0, 0.2)
	tw.tween_callback(func() -> void: _state = "idle")


## The sacred chest-beat, three escalating loops (PRD animation set).
func victory() -> void:
	_state = "victory"
	_dance_beats = 6
	_beat()


func _beat() -> void:
	if _dance_beats <= 0:
		_state = "idle"
		_arm_pivot.rotation_degrees.z = 0.0
		_off_arm.rotation_degrees.z = 0.0
		return
	_dance_beats -= 1
	var up := 150.0 if _dance_beats % 2 == 0 else 120.0
	var tw := create_tween()
	tw.tween_property(_arm_pivot, "rotation_degrees:z", up, 0.16)
	tw.parallel().tween_property(_off_arm, "rotation_degrees:z", -up, 0.16)
	tw.parallel().tween_property(_root, "position:y", 0.7, 0.16)
	tw.tween_property(_arm_pivot, "rotation_degrees:z", 40.0, 0.14)
	tw.parallel().tween_property(_off_arm, "rotation_degrees:z", -40.0, 0.14)
	tw.parallel().tween_property(_root, "position:y", 0.0, 0.14)
	tw.tween_callback(_beat)


func defeat() -> void:
	_state = "defeat"
	var tw := create_tween()
	tw.tween_property(_root, "rotation_degrees:x", 78.0, 0.5) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func reset_pose() -> void:
	_state = "idle"
	_root.rotation_degrees.x = 0.0
	_root.position.y = 0.0
	_root.scale = Vector3.ONE
	_arm_pivot.rotation_degrees.z = 0.0
	_off_arm.rotation_degrees.z = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _state == "idle":
		_root.position.y = sin(_t * 1.7) * 0.06
		_root.rotation_degrees.z = sin(_t * 0.9) * 2.0
