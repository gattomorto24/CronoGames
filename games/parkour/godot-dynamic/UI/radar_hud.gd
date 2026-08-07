extends Control
class_name ParkourRadarHUD

@export var world_radius := 48.0
@export var rotate_with_player := true
@export var enemy_group: StringName = &"enemy"
@export var target_group: StringName = &"map_target"

var player: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("parkour_player") as Node3D
	queue_redraw()


func setup_player(new_player: Node3D) -> void:
	player = new_player
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(minf(size.x, size.y) * 0.5 - 8.0, 12.0)
	draw_circle(center, radius, Color(0.018, 0.026, 0.036, 0.90))
	draw_circle(center, radius * 0.66, Color(0.11, 0.18, 0.23, 0.22))
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		64,
		Color(0.88, 0.75, 0.48, 0.82),
		2.0,
		true,
	)
	draw_arc(
		center,
		radius * 0.66,
		0.0,
		TAU,
		48,
		Color(0.72, 0.79, 0.79, 0.13),
		1.0,
		true,
	)
	_draw_crosshair(center, radius)
	if player == null or not is_instance_valid(player):
		return
	for enemy_node: Node in get_tree().get_nodes_in_group(enemy_group):
		var enemy := enemy_node as Node3D
		if enemy != null and _is_enemy_alive(enemy):
			_draw_enemy(enemy, center, radius)
	for target_node: Node in get_tree().get_nodes_in_group(target_group):
		var target := target_node as Node3D
		if target != null:
			_draw_target(target, center, radius)
	_draw_player(center)


func _draw_crosshair(center: Vector2, radius: float) -> void:
	var grid_color := Color(0.72, 0.79, 0.79, 0.10)
	draw_line(
		center + Vector2(-radius * 0.84, 0.0),
		center + Vector2(radius * 0.84, 0.0),
		grid_color,
		1.0,
	)
	draw_line(
		center + Vector2(0.0, -radius * 0.84),
		center + Vector2(0.0, radius * 0.84),
		grid_color,
		1.0,
	)
	for angle_index in 8:
		var direction := Vector2.UP.rotated(angle_index * TAU / 8.0)
		draw_line(
			center + direction * (radius - 7.0),
			center + direction * radius,
			Color(0.88, 0.75, 0.48, 0.55),
			1.5,
		)


func _draw_enemy(enemy: Node3D, center: Vector2, radius: float) -> void:
	var relative := _relative_screen_vector(enemy.global_position)
	var normalized_distance := relative.length() / maxf(world_radius, 0.001)
	var clamped_relative := relative
	if normalized_distance > 1.0:
		clamped_relative = relative.normalized() * world_radius
	var point := center + clamped_relative / world_radius * (radius - 11.0)
	var vision := _vision_data(enemy)
	var heat := clampf(float(vision.get("heat", 0.0)), 0.0, 1.0)
	var alert := bool(vision.get("alert", false))
	var color := (
		Color(1.0, 0.20, 0.12, 0.98)
		if alert
		else Color(1.0, lerpf(0.78, 0.35, heat), 0.18, 0.94)
	)
	if normalized_distance > 1.0:
		_draw_edge_marker(point, relative.normalized(), color)
		return
	if alert:
		draw_circle(point, 8.0, Color(color.r, color.g, color.b, 0.16))
	draw_circle(point, 4.2, color)
	draw_arc(point, 6.2, 0.0, TAU, 16, Color.WHITE, 1.0, true)


func _draw_target(target: Node3D, center: Vector2, radius: float) -> void:
	if target == player:
		return
	var relative := _relative_screen_vector(target.global_position)
	if relative.length() > world_radius:
		relative = relative.normalized() * world_radius
	var point := center + relative / world_radius * (radius - 12.0)
	var color := Color(0.28, 0.82, 1.0, 0.96)
	var diamond := PackedVector2Array([
		point + Vector2(0.0, -5.0),
		point + Vector2(5.0, 0.0),
		point + Vector2(0.0, 5.0),
		point + Vector2(-5.0, 0.0),
	])
	draw_colored_polygon(diamond, color)


func _draw_player(center: Vector2) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -9.0),
		center + Vector2(6.0, 7.0),
		center,
		center + Vector2(-6.0, 7.0),
	])
	draw_colored_polygon(points, Color(0.90, 0.79, 0.49, 1.0))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(1.0, 0.96, 0.84, 0.92), 1.2, true)


func _draw_edge_marker(
	point: Vector2,
	direction: Vector2,
	color: Color,
) -> void:
	var tangent := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array([
		point + direction * 5.0,
		point - direction * 4.0 + tangent * 3.5,
		point - direction * 4.0 - tangent * 3.5,
	])
	draw_colored_polygon(points, color)


func _relative_screen_vector(world_position: Vector3) -> Vector2:
	var delta := world_position - player.global_position
	var relative := Vector2(delta.x, delta.z)
	if not rotate_with_player:
		return relative
	var forward := -player.global_basis.z
	var forward_2d := Vector2(forward.x, forward.z)
	if forward_2d.length_squared() <= 0.0001:
		return relative
	var rotation_to_up := -PI * 0.5 - forward_2d.angle()
	return relative.rotated(rotation_to_up)


func _vision_data(enemy: Node3D) -> Dictionary:
	if enemy.has_method("get_vision_data"):
		var result: Variant = enemy.call("get_vision_data")
		if result is Dictionary:
			return result
	return {}


func _is_enemy_alive(enemy: Node3D) -> bool:
	if enemy.has_method("is_combat_alive"):
		return bool(enemy.call("is_combat_alive"))
	return true
