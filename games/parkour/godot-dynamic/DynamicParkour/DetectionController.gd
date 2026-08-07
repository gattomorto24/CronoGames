extends Node
class_name DynamicParkourDetectionController

const WORLD_MASK := 1
const LEDGE_RAY_ORIGIN_Y := 1.12
const LEDGE_RAY_LENGTH := 1.85
const LEDGE_RAY_COUNT := 15
const LEDGE_RAY_STEP := 0.13
const LEDGE_TOP_INSET := 0.18
const PREDICTED_MAX_HEIGHT := 1.25
const PREDICTED_MAX_DISTANCE := 5.0

var player: CharacterBody3D


func setup(controlled_player: CharacterBody3D) -> void:
	player = controlled_player


func ray(origin: Vector3, target: Vector3, mask: int = WORLD_MASK) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, target, mask)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query)


func is_grounded(distance: float = 0.72) -> bool:
	var origin := player.global_position + Vector3.UP * 0.30
	return not ray(origin, origin + Vector3.DOWN * distance).is_empty()


func ground_below(position: Vector3, distance: float = 4.0) -> Dictionary:
	var origin := position + Vector3.UP * 0.18
	return ray(origin, origin + Vector3.DOWN * distance)


func ground_ahead(direction: Vector3, distance: float = 0.92) -> Dictionary:
	var origin := (
		player.global_position
		+ direction.normalized() * distance
		+ Vector3.UP * 0.32
	)
	return ray(origin, origin + Vector3.DOWN * 0.90)


func has_walkable_support(
	position: Vector3,
	distance: float = 1.15,
) -> bool:
	var support := ground_below(position, distance)
	if support.is_empty():
		return false
	return (support["normal"] as Vector3).dot(Vector3.UP) >= 0.68


func stable_top_stance(
	top_position: Vector3,
	wall_normal: Vector3,
) -> Dictionary:
	var normal := wall_normal.normalized()
	var inward := -normal
	var physical_edge := top_position + normal * 0.18
	var supported_points: Array[Vector3] = []
	for sample_index in range(1, 15):
		var offset := 0.035 + float(sample_index - 1) * 0.075
		var probe := (
			physical_edge
			+ inward * offset
			+ Vector3.UP * 0.62
		)
		var hit := ray(probe, probe + Vector3.DOWN * 1.0)
		if hit.is_empty():
			if not supported_points.is_empty():
				break
			continue
		var hit_position: Vector3 = hit["position"]
		var hit_normal: Vector3 = hit["normal"]
		if (
			hit_normal.dot(Vector3.UP) < 0.72
			or absf(hit_position.y - top_position.y) > 0.16
		):
			if not supported_points.is_empty():
				break
			continue
		supported_points.append(hit_position)

	if supported_points.is_empty():
		return {
			"position": top_position + inward * 0.16 + Vector3.UP * 0.015,
			"width": 0.16,
		}

	var first: Vector3 = supported_points[0]
	var last: Vector3 = supported_points[supported_points.size() - 1]
	var center: Vector3 = first.lerp(last, 0.5)
	center.y = top_position.y + 0.015
	return {
		"position": center,
		"width": first.distance_to(last) + 0.075,
	}


func detect_obstacle(direction: Vector3) -> Dictionary:
	for forward in _assisted_directions(direction):
		var obstacle := _detect_obstacle_along(forward)
		if not obstacle.is_empty():
			return obstacle
	return {}


func _detect_obstacle_along(forward: Vector3) -> Dictionary:
	var knee_origin := player.global_position + Vector3.UP * 0.52
	var wall_hit := ray(
		knee_origin,
		knee_origin + forward * (1.05 + _movement_anticipation())
	)
	if wall_hit.is_empty():
		return {}

	var top_hit := _top_from_wall(wall_hit, 3.15)
	if top_hit.is_empty():
		return {}
	var top_normal: Vector3 = top_hit["normal"]
	if top_normal.dot(Vector3.UP) < 0.72:
		return {}

	var height: float = top_hit["position"].y - player.global_position.y
	return {
		"wall": wall_hit,
		"top": top_hit,
		"height": height,
		"landing": find_landing_beyond(forward, wall_hit),
	}


func detect_ledge(
	direction: Vector3,
	min_height: float = 0.52,
	max_height: float = 2.55,
) -> Dictionary:
	var ledge_range := LEDGE_RAY_LENGTH + _movement_anticipation() * 0.72
	for forward in _ledge_assisted_directions(direction):
		for ray_index in LEDGE_RAY_COUNT:
			var origin := (
				player.global_position
				+ Vector3.UP * (
					LEDGE_RAY_ORIGIN_Y
					+ float(ray_index) * LEDGE_RAY_STEP
				)
				+ forward * 0.08
			)
			var wall_hit := ray(origin, origin + forward * ledge_range)
			if wall_hit.is_empty():
				continue
			var wall_normal: Vector3 = wall_hit["normal"]
			if absf(wall_normal.dot(Vector3.UP)) > 0.22:
				continue

			var top_hit := _top_from_wall(
				wall_hit,
				clampf(max_height + 0.65, 2.0, 4.25)
			)
			if top_hit.is_empty():
				continue
			var height: float = (
				top_hit["position"].y - player.global_position.y
			)
			if height < min_height or height > max_height:
				continue

			var stance := stable_top_stance(top_hit["position"], wall_normal)
			if float(stance["width"]) < 0.10:
				continue

			var foot_origin := (
				player.global_position
				+ Vector3.UP * 0.48
				+ wall_normal * 0.04
			)
			var foot_hit := ray(
				foot_origin,
				foot_origin - wall_normal * 0.82
			)
			var knee_origin := (
				player.global_position
				+ Vector3.UP * 0.86
				+ wall_normal * 0.04
			)
			var knee_hit := ray(
				knee_origin,
				knee_origin - wall_normal * 0.76
			)
			var edge_position: Vector3 = (
				top_hit["position"]
				+ wall_normal.normalized() * LEDGE_TOP_INSET
			)
			return {
				"wall": wall_hit,
				"top": top_hit,
				"height": height,
				"normal": wall_normal.normalized(),
				"edge": edge_position,
				"stance_width": stance["width"],
				"braced": (
					not foot_hit.is_empty()
					or not knee_hit.is_empty()
				),
			}
	return {}


func detect_climb_wall(
	direction: Vector3,
	distance: float = 1.20,
) -> Dictionary:
	distance += _movement_anticipation() * 0.62
	for forward in _assisted_directions(direction):
		var chest_origin := player.global_position + Vector3.UP * 1.08
		var chest_hit := ray(
			chest_origin,
			chest_origin + forward * distance
		)
		if chest_hit.is_empty():
			continue
		var normal: Vector3 = chest_hit["normal"]
		if absf(normal.dot(Vector3.UP)) > 0.20:
			continue
		var hand_origin := player.global_position + Vector3.UP * 1.72
		var hand_hit := ray(
			hand_origin,
			hand_origin + forward * (distance + 0.08)
		)
		if hand_hit.is_empty():
			continue
		var hand_normal: Vector3 = hand_hit["normal"]
		if normal.dot(hand_normal) < 0.84:
			continue
		return chest_hit
	return {}


func wall_hit_at(
	position: Vector3,
	wall_normal: Vector3,
	height: float = 1.08,
	distance: float = 0.74,
) -> Dictionary:
	var normal := wall_normal.normalized()
	var origin := position + Vector3.UP * height + normal * 0.06
	return ray(origin, origin - normal * distance)


func find_logical_grip(
	current_position: Vector3,
	wall_normal: Vector3,
	vertical_delta: float,
	lateral_delta: float,
) -> Dictionary:
	var normal := wall_normal.normalized()
	var tangent := Vector3.UP.cross(normal).normalized()
	var candidate := (
		current_position
		+ Vector3.UP * vertical_delta
		+ tangent * lateral_delta
	)
	var hand_probe := wall_hit_at(candidate, normal, 1.48, 1.04)
	var foot_probe := wall_hit_at(candidate, normal, 0.62, 1.04)
	if hand_probe.is_empty() or foot_probe.is_empty():
		return {}
	var hand_normal := (hand_probe["normal"] as Vector3).normalized()
	var foot_normal := (foot_probe["normal"] as Vector3).normalized()
	if (
		hand_normal.dot(normal) < 0.72
		or foot_normal.dot(normal) < 0.68
	):
		return {}
	return {
		"position": candidate,
		"contact": hand_probe["position"],
		"normal": hand_normal.slerp(foot_normal, 0.35).normalized(),
		"hand": hand_probe,
		"foot": foot_probe,
	}


func detect_slide_context(direction: Vector3) -> Dictionary:
	var forward := direction.normalized()
	var head_origin := player.global_position + Vector3.UP * 1.48
	var head_hit := ray(head_origin, head_origin + forward * 1.55)
	if head_hit.is_empty():
		return {}
	var low_origin := player.global_position + Vector3.UP * 0.62
	var low_hit := ray(low_origin, low_origin + forward * 1.55)
	if not low_hit.is_empty():
		return {}
	return {"overhead": head_hit}


func find_landing_beyond(
	direction: Vector3,
	obstacle_hit: Dictionary,
) -> Dictionary:
	var forward := direction.normalized()
	var obstacle_collider: Object = obstacle_hit.get("collider")
	for sample_index in range(4, 13):
		var distance := float(sample_index) * 0.24
		var origin := (
			player.global_position
			+ forward * distance
			+ Vector3.UP * 3.2
		)
		var landing := ray(origin, origin + Vector3.DOWN * 6.0)
		if landing.is_empty():
			continue
		if landing["normal"].dot(Vector3.UP) < 0.72:
			continue
		if landing.get("collider") == obstacle_collider:
			continue
		return landing
	return {}


func find_predicted_landing(direction: Vector3) -> Dictionary:
	var forward := direction.normalized()
	var current_ground := ground_below(player.global_position, 0.85)
	var at_edge := ground_ahead(forward, 1.05).is_empty()
	if not at_edge:
		return {}

	var current_collider: Object = current_ground.get("collider")
	for sample_index in range(6, 16):
		var distance := 1.45 + float(sample_index) * 0.24
		if distance > PREDICTED_MAX_DISTANCE:
			break
		var origin := (
			player.global_position
			+ forward * distance
			+ Vector3.UP * 3.2
		)
		var landing := ray(origin, origin + Vector3.DOWN * 6.5)
		if landing.is_empty():
			continue
		if landing["normal"].dot(Vector3.UP) < 0.76:
			continue
		if landing.get("collider") == current_collider:
			continue
		var target: Vector3 = landing["position"]
		if target.y - player.global_position.y > PREDICTED_MAX_HEIGHT:
			continue
		if absf(target.y - player.global_position.y) > 2.6:
			continue
		if not trajectory_is_clear(
			player.global_position,
			target,
			PREDICTED_MAX_HEIGHT
		):
			continue
		return landing
	return {}


func trajectory_is_clear(
	start: Vector3,
	end: Vector3,
	height: float,
) -> bool:
	var previous := start + Vector3.UP * 0.7
	for sample_index in range(1, 12):
		var t := float(sample_index) / 12.0
		var point := start.lerp(end, t)
		point.y += 4.0 * height * t * (1.0 - t) + 0.7
		var hit := ray(previous, point)
		if not hit.is_empty():
			return false
		previous = point
	return true


func wall_available_at(
	position: Vector3,
	wall_normal: Vector3,
	height: float,
	distance: float = 0.82,
) -> bool:
	var origin := position + Vector3.UP * height + wall_normal * 0.04
	return not ray(
		origin,
		origin - wall_normal.normalized() * distance
	).is_empty()


func top_surface_near(
	position: Vector3,
	wall_normal: Vector3,
) -> Dictionary:
	var inward := -wall_normal.normalized()
	var origin := position + inward * 0.44 + Vector3.UP * 2.7
	var result := ray(origin, origin + Vector3.DOWN * 3.5)
	if result.is_empty() or result["normal"].dot(Vector3.UP) < 0.72:
		return {}
	return result


func _top_from_wall(wall_hit: Dictionary, extra_height: float) -> Dictionary:
	var wall_position: Vector3 = wall_hit["position"]
	var wall_normal: Vector3 = wall_hit["normal"]
	var inward := -wall_normal.normalized()
	for inset in [0.12, LEDGE_TOP_INSET, 0.30, 0.44]:
		var origin := (
			wall_position
			+ inward * float(inset)
			+ Vector3.UP * extra_height
		)
		var result := ray(
			origin,
			origin + Vector3.DOWN * (extra_height + 0.35)
		)
		if result.is_empty():
			continue
		if result["normal"].dot(Vector3.UP) < 0.72:
			continue
		return result
	return {}


func _assisted_directions(direction: Vector3) -> Array[Vector3]:
	var forward := direction.normalized()
	if forward == Vector3.ZERO:
		return []
	return [
		forward,
		forward.rotated(Vector3.UP, deg_to_rad(-17.0)).normalized(),
		forward.rotated(Vector3.UP, deg_to_rad(17.0)).normalized(),
	]


func _ledge_assisted_directions(direction: Vector3) -> Array[Vector3]:
	var candidates: Array[Vector3] = []
	var forward := direction.normalized()
	if forward != Vector3.ZERO:
		candidates.append(forward)
		for degrees in [-24.0, 24.0, -58.0, 58.0]:
			candidates.append(
				forward.rotated(Vector3.UP, deg_to_rad(float(degrees))).normalized()
			)

	var motion := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if motion.length_squared() > 0.04:
		var moving := motion.normalized()
		candidates.append(moving)
		for degrees in [-34.0, 34.0]:
			candidates.append(
				moving.rotated(Vector3.UP, deg_to_rad(float(degrees))).normalized()
			)

	var directions: Array[Vector3] = []
	for candidate in candidates:
		if candidate.length_squared() < 0.001:
			continue
		var normalized := candidate.normalized()
		var duplicate := false
		for existing in directions:
			if existing.dot(normalized) > 0.985:
				duplicate = true
				break
		if not duplicate:
			directions.append(normalized)
	return directions


func _movement_anticipation() -> float:
	var horizontal_velocity := Vector2(
		player.velocity.x,
		player.velocity.z
	).length()
	return clampf(horizontal_velocity * 0.19, 0.0, 0.82)
