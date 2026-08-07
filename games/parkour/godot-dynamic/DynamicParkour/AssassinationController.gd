extends Node
class_name ParkourAssassinationController

# Adapter for the BackstabComponent/HealthComponent contract used by
# Godot4ThirdPersonCombatPrototype-main. It deliberately keeps combat targets
# decoupled from the movement state machine.
const TARGET_GROUPS := [
	&"assassination_targets",
	&"backstab_targets",
	&"enemies",
	&"enemy",
]
const AIR_MIN_HEIGHT := 3.0
const AIR_MAX_HEIGHT := 9.5
const AIR_MAX_HORIZONTAL_DISTANCE := 2.8
const GROUND_MAX_DISTANCE := 2.65
const BEHIND_FACING_DOT := 0.5


func find_best_target(
	player: CharacterBody3D,
	mode_hint: String,
	allow_legacy_unaware: bool = true,
) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	var aerial_context := mode_hint in [
		"aerial",
		"fall",
		"after_jump",
	]
	var uses_aerial_motion := (
		aerial_context or mode_hint == "zipline"
	)
	var candidates: Array[Node] = []
	for group_name in TARGET_GROUPS:
		for candidate in player.get_tree().get_nodes_in_group(group_name):
			if candidate is Node and not candidates.has(candidate):
				candidates.append(candidate)

	for candidate in candidates:
		if not _is_available(candidate):
			continue
		var target_position := _target_position(candidate)
		var offset := target_position - player.global_position
		var distance := offset.length()
		var unaware := _target_is_unaware(candidate, player)
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		if aerial_context:
			var target_root := _target_root_position(candidate)
			var height_above := (
				player.global_position.y - target_root.y
			)
			if (
				height_above < AIR_MIN_HEIGHT
				or height_above > AIR_MAX_HEIGHT
				or horizontal.length()
				> AIR_MAX_HORIZONTAL_DISTANCE
				or not _is_inside_air_detector(player, candidate)
				or not _has_clear_air_path(
					player,
					candidate,
					target_position,
				)
			):
				continue
		elif mode_hint == "zipline":
			if distance > 5.2:
				continue
		elif (
			distance > GROUND_MAX_DISTANCE
			or not _can_ground_takedown(
				player,
				candidate,
				unaware,
				allow_legacy_unaware,
			)
		):
			continue
		var facing_score := 0.0
		if horizontal.length_squared() > 0.001:
			facing_score = (
				1.0
				- (-player.global_basis.z).dot(horizontal.normalized())
			) * 0.72
		var height_penalty := (
			absf(offset.y) * (0.12 if uses_aerial_motion else 0.55)
		)
		var score := distance + facing_score + height_penalty
		if score < best_score:
			best_score = score
			best = {
				"target": candidate,
				"position": target_position,
				"mode": _resolve_mode(mode_hint, offset),
			}
	return best


func _target_is_unaware(target: Node, player: CharacterBody3D) -> bool:
	if target.has_method("is_player_detected"):
		return not bool(target.call("is_player_detected", player))
	return false


func _can_ground_takedown(
	player: CharacterBody3D,
	target: Node,
	unaware: bool,
	allow_legacy_unaware: bool,
) -> bool:
	# Preserve the prototype's unaware-target contract. This is also the
	# compatibility path used by the existing stealth smoke test.
	if unaware and allow_legacy_unaware:
		return true
	if (
		not _is_behind_target(player, target)
		or not _has_matching_facing(player, target)
	):
		return false
	return _player_is_sneaking(player)


func _player_is_sneaking(player: CharacterBody3D) -> bool:
	var value: Variant = _property(player, &"is_sneaking")
	return bool(value) if value != null else false


func _has_matching_facing(
	player: CharacterBody3D,
	target: Node,
) -> bool:
	if not target is Node3D:
		return true
	var player_back := player.global_basis.z
	var target_back := (target as Node3D).global_basis.z
	player_back.y = 0.0
	target_back.y = 0.0
	if (
		player_back.length_squared() < 0.001
		or target_back.length_squared() < 0.001
	):
		return true
	return (
		player_back.normalized().dot(target_back.normalized())
		> BEHIND_FACING_DOT
	)


func _is_inside_air_detector(
	player: CharacterBody3D,
	target: Node,
) -> bool:
	var detector := player.get_node_or_null(
		"AirAssassinationDetector"
	) as Area3D
	if detector == null:
		return true
	for body in detector.get_overlapping_bodies():
		if body is Node and _belongs_to_target(body as Node, target):
			return true
	for area in detector.get_overlapping_areas():
		if _belongs_to_target(area, target):
			return true
	return false


func _has_clear_air_path(
	player: CharacterBody3D,
	target: Node,
	target_position: Vector3,
) -> bool:
	var world := player.get_world_3d()
	if world == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 0.72,
		target_position,
		9,
		[player.get_rid()],
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Variant = hit.get("collider")
	return (
		collider is Node
		and _belongs_to_target(collider as Node, target)
	)


func _belongs_to_target(node: Node, target: Node) -> bool:
	return (
		node == target
		or target.is_ancestor_of(node)
		or node.is_ancestor_of(target)
	)


func apply_lethal_hit(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("receive_assassination"):
		target.call("receive_assassination")
		return

	var backstab_component := _component(
		target,
		&"backstab_component",
		&"BackstabComponent"
	)
	var health_component := _component(
		target,
		&"health_component",
		&"HealthComponent"
	)
	if health_component == null and backstab_component != null:
		var nested_health: Variant = _property(
			backstab_component,
			&"health_component"
		)
		if nested_health is Node:
			health_component = nested_health as Node

	# This mirrors the prototype's process_hit(): arm maximum damage, then let
	# the existing health component own death, particles and signals.
	if health_component != null:
		if _has_property(health_component, &"deal_max_damage"):
			health_component.set("deal_max_damage", true)
		if health_component.has_method("decrement_health"):
			health_component.call("decrement_health", 1.0)
			return
	if target.has_method("die"):
		target.call("die")


func _resolve_mode(mode_hint: String, offset: Vector3) -> String:
	if mode_hint == "zipline":
		return "zipline_assassination"
	if mode_hint == "after_jump":
		return "jump_assassination"
	if mode_hint in ["aerial", "fall"] or offset.y < -1.15:
		return "aerial_assassination"
	return "standard_assassination"


func _is_available(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method("can_be_assassinated"):
		return bool(target.call("can_be_assassinated"))
	var health_component := _component(
		target,
		&"health_component",
		&"HealthComponent"
	)
	if health_component != null and health_component.has_method("is_alive"):
		return bool(health_component.call("is_alive"))
	if _has_property(target, &"dead"):
		return not bool(target.get("dead"))
	return true


func _is_behind_target(
	player: CharacterBody3D,
	target: Node,
) -> bool:
	if not target is Node3D:
		return true
	var target_3d := target as Node3D
	var to_player := target_3d.global_position.direction_to(
		player.global_position
	)
	var target_forward := -target_3d.global_basis.z
	target_forward.y = 0.0
	to_player.y = 0.0
	if target_forward.length_squared() < 0.001:
		return true
	return target_forward.normalized().dot(to_player.normalized()) < -0.22


func _target_position(target: Node) -> Vector3:
	var attachment: Variant = _property(
		target,
		&"attachment_point"
	)
	if attachment is Node3D:
		return (attachment as Node3D).global_position
	if target is Node3D:
		return (target as Node3D).global_position + Vector3.UP * 0.92
	return Vector3.ZERO


func _target_root_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	return _target_position(target)


func _component(
	target: Node,
	property_name: StringName,
	class_label: StringName,
) -> Node:
	var direct: Variant = _property(target, property_name)
	if direct is Node:
		return direct
	for child in target.get_children():
		if child is Node:
			var child_node := child as Node
			if child_node.get_class() == class_label:
				return child_node
			var script: Variant = child_node.get_script()
			if script != null and String(script.resource_path).contains(
				String(property_name).trim_suffix("_component")
			):
				return child_node
	return null


func _property(object: Object, property_name: StringName) -> Variant:
	if object == null:
		return null
	for descriptor in object.get_property_list():
		if descriptor["name"] == property_name:
			return object.get(property_name)
	return null


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for descriptor in object.get_property_list():
		if descriptor["name"] == property_name:
			return true
	return false
