extends Node
class_name FlatWallClimber

@export var wall_clearance: float = 0.31
@export var climb_speed: float = 1.75
@export var lateral_speed: float = 1.15
@export var wall_snap_speed: float = 11.0

var player: CharacterBody3D
var model: PlayerModel
var area_awareness: AreaAwareness
var active: bool = false
var wall_normal: Vector3 = Vector3.ZERO


func setup(
	controlled_player: CharacterBody3D,
	player_model: PlayerModel,
) -> void:
	player = controlled_player
	model = player_model
	area_awareness = player_model.area_awareness


func update_climb(input_package: InputPackage, delta: float) -> bool:
	if active:
		return _continue_climb(input_package, delta)

	if not input_package.movement_actions.has("go_up"):
		return false
	if not input_package.movement_actions.has("move"):
		return false

	# Reachable roof edges keep using the imported pull-up transition.
	# This extension is reserved for tall, uninterrupted wall faces.
	if area_awareness.can_climb_dynamic_ledge():
		return false

	var chest_hit := _wall_probe(1.05, 0.62)
	var head_hit := _wall_probe(2.05, 0.62)
	if chest_hit.is_empty() or head_hit.is_empty():
		return false

	var chest_normal: Vector3 = chest_hit["normal"]
	var head_normal: Vector3 = head_hit["normal"]
	if chest_normal.dot(head_normal) < 0.92:
		return false

	_begin_climb(chest_hit)
	return true


func _begin_climb(wall_hit: Dictionary) -> void:
	active = true
	var sensed_normal: Vector3 = wall_hit["normal"]
	var contact: Vector3 = wall_hit["position"]
	wall_normal = sensed_normal.normalized()
	player.velocity = Vector3.ZERO
	_face_wall()
	_snap_to_wall(wall_hit, 1.0)

	# Ledge grab provides the correct hand-ready base pose. While this helper
	# owns movement, the pull-up clip supplies the natural alternating limbs.
	area_awareness.ledge_climbing_point = (
		contact + Vector3.UP * 0.78
	)
	model.switch_to("ledge_grab")
	_play_climb_cycle()


func _continue_climb(input_package: InputPackage, delta: float) -> bool:
	if not input_package.movement_actions.has("go_up"):
		_drop_from_wall()
		return true

	var chest_hit := _wall_probe(1.05, 0.72)
	if chest_hit.is_empty():
		var last_top := _find_top_surface()
		if not last_top.is_empty():
			_finish_on_ledge(last_top)
		else:
			_drop_from_wall()
		return true

	var sensed_normal: Vector3 = chest_hit["normal"]
	if sensed_normal.dot(wall_normal) < 0.72:
		_drop_from_wall()
		return true
	wall_normal = wall_normal.slerp(sensed_normal.normalized(), clampf(delta * 8.0, 0.0, 1.0))
	_face_wall()
	_snap_to_wall(chest_hit, clampf(delta * wall_snap_speed, 0.0, 1.0))

	var vertical_intent := -input_package.input_direction.y
	if absf(vertical_intent) < 0.08:
		vertical_intent = 0.62

	if vertical_intent > 0.0:
		var top_hit := _find_top_surface()
		if not top_hit.is_empty():
			var top_position: Vector3 = top_hit["position"]
			var top_height: float = top_position.y
			var reach: float = top_height - player.global_position.y
			if reach >= 1.55 and reach <= 2.75:
				_finish_on_ledge(top_hit)
				return true

	var tangent := wall_normal.cross(Vector3.UP).normalized()
	var lateral_intent := input_package.input_direction.x
	var motion := (
		Vector3.UP * vertical_intent * climb_speed
		+ tangent * lateral_intent * lateral_speed
	)
	player.global_position += motion * delta
	player.velocity = Vector3.ZERO

	if not model.animator.legs_animator.is_playing():
		_play_climb_cycle()
	return true


func _wall_probe(height: float, distance: float) -> Dictionary:
	var origin := player.global_position + Vector3.UP * height
	var target := origin + player.basis.z * distance
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query)


func _find_top_surface() -> Dictionary:
	var inward := -wall_normal
	var origin := (
		player.global_position
		+ Vector3.UP * 3.05
		+ inward * 0.48
	)
	var target := origin + Vector3.DOWN * 3.35
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	query.exclude = [player.get_rid()]
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var surface_normal: Vector3 = result["normal"]
	if surface_normal.dot(Vector3.UP) < 0.72:
		return {}
	return result


func _snap_to_wall(wall_hit: Dictionary, weight: float) -> void:
	var contact: Vector3 = wall_hit["position"]
	var anchor := contact + wall_normal * wall_clearance
	anchor.y = player.global_position.y
	player.global_position = player.global_position.lerp(anchor, weight)


func _face_wall() -> void:
	var forward := -wall_normal
	var right := Vector3.UP.cross(forward).normalized()
	player.basis = Basis(right, Vector3.UP, forward).orthonormalized()


func _play_climb_cycle() -> void:
	model.animator.set_speed_scale(1.18)
	model.animator.set_legs_animation("ledge_climb_up")
	model.animator.set_torso_animation("ledge_climb_up")
	model.animator.reset_legs_animation()
	model.animator.reset_torso_animation()


func _finish_on_ledge(top_hit: Dictionary) -> void:
	active = false
	model.animator.set_speed_scale(1.0)
	area_awareness.ledge_climbing_point = top_hit["position"]
	model.switch_to("ledge_climb_up")


func _drop_from_wall() -> void:
	active = false
	model.animator.set_speed_scale(1.0)
	player.velocity = Vector3.DOWN * 0.55
	model.switch_to("midair")
