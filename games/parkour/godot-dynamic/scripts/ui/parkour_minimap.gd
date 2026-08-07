extends Control


@export var player_path: NodePath
@export var world_scale := 2.55
@export var view_radius := 44.0

var player: Node3D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	size = Vector2(240.0, 240.0)
	position = Vector2(-264.0, 24.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80


func _process(_delta: float) -> void:
	if player == null and player_path != NodePath():
		player = get_node_or_null(player_path) as Node3D
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var center := size * 0.5
	draw_rect(rect, Color(0.025, 0.022, 0.018, 0.78), true)
	draw_rect(rect, Color(1.0, 0.78, 0.42, 0.82), false, 2.0)
	_draw_grid(center)
	if player == null or not is_instance_valid(player):
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node3D:
			_draw_enemy(enemy as Node3D, center)
	_draw_player(center)


func _draw_grid(center: Vector2) -> void:
	var grid_color := Color(0.95, 0.72, 0.42, 0.14)
	for offset in [-80.0, -40.0, 0.0, 40.0, 80.0]:
		draw_line(
			Vector2(center.x + offset, 12.0),
			Vector2(center.x + offset, size.y - 12.0),
			grid_color,
			1.0
		)
		draw_line(
			Vector2(12.0, center.y + offset),
			Vector2(size.x - 12.0, center.y + offset),
			grid_color,
			1.0
		)


func _draw_enemy(enemy: Node3D, center: Vector2) -> void:
	if enemy.has_method("is_combat_alive"):
		if not bool(enemy.call("is_combat_alive")):
			return
	var enemy_position := _to_map(enemy.global_position, center)
	if not _inside_map(enemy_position):
		return
	var vision := {}
	if enemy.has_method("get_vision_data"):
		vision = enemy.call("get_vision_data")
	var heat := float(vision.get("heat", 0.0))
	var alerted := bool(vision.get("alert", false))
	var color := Color(1.0, 0.22, 0.12, 0.96) if alerted else Color(
		1.0,
		lerpf(0.86, 0.36, heat),
		0.18,
		0.88
	)
	_draw_vision_cone(enemy_position, vision, color)
	draw_circle(enemy_position, 4.0, color)
	draw_circle(enemy_position, 6.5, Color(color.r, color.g, color.b, 0.18))


func _draw_vision_cone(
	origin: Vector2,
	vision: Dictionary,
	color: Color
) -> void:
	if vision.is_empty():
		return
	var range_px := minf(float(vision.get("range", 0.0)), view_radius) * world_scale
	var angle := float(vision.get("angle", deg_to_rad(70.0)))
	var direction_3d: Vector3 = vision.get("direction", Vector3.FORWARD)
	var direction := Vector2(direction_3d.x, -direction_3d.z)
	if direction.length_squared() <= 0.001:
		direction = Vector2.UP
	direction = direction.normalized()
	var base_angle := direction.angle()
	var points := PackedVector2Array()
	points.append(origin)
	var steps := 12
	for index in range(steps + 1):
		var blend := float(index) / float(steps)
		var theta := base_angle - angle * 0.5 + angle * blend
		var point := origin + Vector2(cos(theta), sin(theta)) * range_px
		points.append(_clamp_to_rect(point))
	draw_colored_polygon(
		points,
		Color(color.r, color.g, color.b, 0.16)
	)
	var arc_points := PackedVector2Array()
	for index in range(1, points.size()):
		arc_points.append(points[index])
	draw_polyline(arc_points, Color(color.r, color.g, color.b, 0.45), 1.2)
	draw_line(
		origin,
		origin + direction * range_px,
		Color(color.r, color.g, color.b, 0.55),
		1.0
	)


func _draw_player(center: Vector2) -> void:
	var forward := -player.global_basis.z
	var direction := Vector2(forward.x, -forward.z)
	if direction.length_squared() <= 0.001:
		direction = Vector2.UP
	direction = direction.normalized()
	var right := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array()
	points.append(center + direction * 9.0)
	points.append(center - direction * 6.0 + right * 5.5)
	points.append(center - direction * 6.0 - right * 5.5)
	draw_colored_polygon(points, Color(0.18, 0.78, 1.0, 0.95))
	var outline := PackedVector2Array()
	for point in points:
		outline.append(point)
	outline.append(points[0])
	draw_polyline(outline, Color.WHITE, 1.4)


func _to_map(world_position: Vector3, center: Vector2) -> Vector2:
	var delta := world_position - player.global_position
	delta.x = clampf(delta.x, -view_radius, view_radius)
	delta.z = clampf(delta.z, -view_radius, view_radius)
	return center + Vector2(delta.x, -delta.z) * world_scale


func _inside_map(point: Vector2) -> bool:
	return (
		point.x >= 0.0
		and point.x <= size.x
		and point.y >= 0.0
		and point.y <= size.y
	)


func _clamp_to_rect(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, 2.0, size.x - 2.0),
		clampf(point.y, 2.0, size.y - 2.0)
	)
