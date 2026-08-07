extends Control
class_name ParkourWorldMapCanvas

@export var world_center := Vector2(0.0, -16.0)
@export var world_extent := Vector2(220.0, 220.0)

var player: Node3D
var runtime_points: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func setup_player(new_player: Node3D) -> void:
	player = new_player
	queue_redraw()


func register_point(
	point_id: StringName,
	world_position: Vector3,
	point_type: StringName,
	display_name: String,
	radius := 0.0,
) -> void:
	runtime_points[point_id] = {
		"position": world_position,
		"type": point_type,
		"label": display_name,
		"radius": maxf(radius, 0.0),
	}
	queue_redraw()


func remove_point(point_id: StringName) -> void:
	runtime_points.erase(point_id)
	queue_redraw()


func clear_runtime_points() -> void:
	runtime_points.clear()
	queue_redraw()


func _draw() -> void:
	var map_rect := Rect2(Vector2(26.0, 20.0), size - Vector2(52.0, 42.0))
	if map_rect.size.x <= 20.0 or map_rect.size.y <= 20.0:
		return
	draw_rect(map_rect, Color(0.022, 0.038, 0.052, 0.96), true)
	draw_rect(map_rect, Color(0.78, 0.69, 0.49, 0.58), false, 2.0)
	_draw_grid(map_rect)
	_draw_discovered_nodes(map_rect)
	for point: Dictionary in runtime_points.values():
		_draw_point_data(point, map_rect)
	if player != null and is_instance_valid(player):
		_draw_player(map_rect)


func _draw_grid(map_rect: Rect2) -> void:
	var grid_color := Color(0.50, 0.66, 0.70, 0.10)
	for index in range(1, 8):
		var blend := float(index) / 8.0
		var x := lerpf(map_rect.position.x, map_rect.end.x, blend)
		var y := lerpf(map_rect.position.y, map_rect.end.y, blend)
		draw_line(
			Vector2(x, map_rect.position.y),
			Vector2(x, map_rect.end.y),
			grid_color,
			1.0,
		)
		draw_line(
			Vector2(map_rect.position.x, y),
			Vector2(map_rect.end.x, y),
			grid_color,
			1.0,
		)
	var center := map_rect.get_center()
	draw_line(
		Vector2(center.x, map_rect.position.y),
		Vector2(center.x, map_rect.end.y),
		Color(0.78, 0.69, 0.49, 0.18),
		1.0,
	)
	draw_line(
		Vector2(map_rect.position.x, center.y),
		Vector2(map_rect.end.x, center.y),
		Color(0.78, 0.69, 0.49, 0.18),
		1.0,
	)


func _draw_discovered_nodes(map_rect: Rect2) -> void:
	var groups := {
		&"map_point_of_interest": &"poi",
		&"point_of_interest": &"poi",
		&"map_target": &"target",
		&"objective": &"target",
		&"hunting_zone": &"hunting_zone",
	}
	var drawn_ids: Dictionary = {}
	for group_name: StringName in groups:
		for candidate: Node in get_tree().get_nodes_in_group(group_name):
			var node := candidate as Node3D
			if node == null or drawn_ids.has(node.get_instance_id()):
				continue
			drawn_ids[node.get_instance_id()] = true
			var label := _node_label(node)
			var radius := float(node.get_meta("map_radius", 0.0))
			_draw_point_data(
				{
					"position": node.global_position,
					"type": groups[group_name],
					"label": label,
					"radius": radius,
				},
				map_rect,
			)


func _draw_point_data(point: Dictionary, map_rect: Rect2) -> void:
	var world_position: Vector3 = point.get("position", Vector3.ZERO)
	var point_type := StringName(point.get("type", &"poi"))
	var label := String(point.get("label", ""))
	var screen_position := _world_to_map(world_position, map_rect)
	var color := Color(0.88, 0.75, 0.48, 0.96)
	if point_type == &"target":
		color = Color(0.28, 0.82, 1.0, 0.98)
	elif point_type == &"hunting_zone":
		color = Color(0.94, 0.33, 0.20, 0.92)
	var zone_radius := float(point.get("radius", 0.0))
	if zone_radius > 0.0:
		var pixel_radius := (
			zone_radius
			/ maxf(world_extent.x, 1.0)
			* map_rect.size.x
		)
		draw_circle(
			screen_position,
			pixel_radius,
			Color(color.r, color.g, color.b, 0.10),
		)
		draw_arc(
			screen_position,
			pixel_radius,
			0.0,
			TAU,
			40,
			Color(color.r, color.g, color.b, 0.48),
			1.5,
			true,
		)
	var marker := PackedVector2Array([
		screen_position + Vector2(0.0, -6.0),
		screen_position + Vector2(6.0, 0.0),
		screen_position + Vector2(0.0, 6.0),
		screen_position + Vector2(-6.0, 0.0),
	])
	draw_colored_polygon(marker, color)
	if not label.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			screen_position + Vector2(10.0, 5.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			13,
			Color(0.92, 0.93, 0.90, 0.90),
		)


func _draw_player(map_rect: Rect2) -> void:
	var point := _world_to_map(player.global_position, map_rect)
	var forward := -player.global_basis.z
	var direction := Vector2(forward.x, forward.z)
	if direction.length_squared() <= 0.001:
		direction = Vector2.UP
	direction = direction.normalized()
	var tangent := Vector2(-direction.y, direction.x)
	var marker := PackedVector2Array([
		point + direction * 9.0,
		point - direction * 6.0 + tangent * 5.0,
		point - direction * 6.0 - tangent * 5.0,
	])
	draw_colored_polygon(marker, Color(0.96, 0.89, 0.68, 1.0))
	var outline := marker.duplicate()
	outline.append(marker[0])
	draw_polyline(outline, Color(0.08, 0.12, 0.15, 0.94), 1.5, true)


func _world_to_map(world_position: Vector3, map_rect: Rect2) -> Vector2:
	var normalized := Vector2(
		(world_position.x - world_center.x) / maxf(world_extent.x, 1.0) + 0.5,
		(world_position.z - world_center.y) / maxf(world_extent.y, 1.0) + 0.5,
	)
	normalized.x = clampf(normalized.x, 0.0, 1.0)
	normalized.y = clampf(normalized.y, 0.0, 1.0)
	return map_rect.position + normalized * map_rect.size


func _node_label(node: Node) -> String:
	if node.has_meta("map_label"):
		return String(node.get_meta("map_label"))
	return node.name.replace("_", " ").capitalize()
