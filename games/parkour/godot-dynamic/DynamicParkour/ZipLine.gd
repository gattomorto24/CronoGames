extends Node3D
class_name ParkourZipLine

@export var start_point := Vector3.ZERO
@export var end_point := Vector3(0.0, -2.0, -8.0)
@export var travel_speed := 9.5
@export var capture_radius := 1.35
@export var exit_boost := 4.8
@export var rope_radius := 0.035


func _ready() -> void:
	add_to_group("parkour_zipline")
	_build_rope_visual()


func length() -> float:
	return start_point.distance_to(end_point)


func direction() -> Vector3:
	return start_point.direction_to(end_point)


func point_at(progress: float) -> Vector3:
	return start_point.lerp(end_point, clampf(progress, 0.0, 1.0))


func closest_progress(world_point: Vector3) -> float:
	var segment := end_point - start_point
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return 0.0
	return clampf(
		(world_point - start_point).dot(segment) / length_squared,
		0.0,
		1.0
	)


func distance_to_line(world_point: Vector3) -> float:
	return world_point.distance_to(point_at(closest_progress(world_point)))


func _build_rope_visual() -> void:
	var segment := end_point - start_point
	var rope_length := segment.length()
	if rope_length <= 0.01:
		return

	var rope := MeshInstance3D.new()
	rope.name = "ThickWalkableCable"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = rope_radius
	cylinder.bottom_radius = rope_radius
	cylinder.height = rope_length
	cylinder.radial_segments = 12
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.055, 0.042, 0.030)
	material.roughness = 0.72
	material.metallic = 0.18
	cylinder.material = material
	rope.mesh = cylinder

	var cable_direction := segment / rope_length
	var cable_x := Vector3.UP.cross(cable_direction)
	if cable_x.length_squared() < 0.001:
		cable_x = Vector3.RIGHT
	cable_x = cable_x.normalized()
	var cable_z := cable_x.cross(cable_direction).normalized()
	rope.global_transform = Transform3D(
		Basis(cable_x, cable_direction, cable_z),
		start_point.lerp(end_point, 0.5)
	)
	add_child(rope)

