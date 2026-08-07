extends Node
class_name StealthWorldDirector

signal reinforcements_called(origin: Vector3, spawned_count: int)

const ENEMY_SCENE := preload(
	"res://CombatPrototype/ExtractedSwordsman.tscn"
)
const HIDING_SPOT_SCENE_PATH := (
	"res://DynamicParkour/HidingSpot.tscn"
)
const HIDING_SPOT_POSITIONS := [
	Vector3(-8.4, 0.0, 17.2),
	Vector3(6.8, 0.0, 13.6),
	Vector3(-15.0, 0.0, 5.4),
	Vector3(14.6, 0.0, -3.8),
	Vector3(-6.8, 0.0, -14.8),
	Vector3(-55.0, 0.0, 55.2),
	Vector3(70.0, 0.0, 31.0),
	Vector3(1.2, 0.0, -79.0),
	Vector3(-72.0, 0.0, -38.0),
	Vector3(47.0, 0.0, 75.0),
]

@export var reinforcement_wave_size := 3
@export var maximum_reinforcements := 9
@export var reinforcement_cooldown := 10.0
@export var minimum_spawn_radius := 11.0
@export var maximum_spawn_radius := 17.0

var player: CharacterBody3D
var reinforcement_cooldown_left := 0.0
var wave_index := 0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_bootstrap_world")


func _process(delta: float) -> void:
	reinforcement_cooldown_left = maxf(
		reinforcement_cooldown_left - delta,
		0.0
	)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(
			"parkour_player"
		) as CharacterBody3D


func _bootstrap_world() -> void:
	player = get_tree().get_first_node_in_group(
		"parkour_player"
	) as CharacterBody3D
	for enemy in get_tree().get_nodes_in_group("enemy"):
		_connect_enemy(enemy)
	_install_hiding_spots()
	_install_runtime_occlusion()
	_configure_visibility_ranges()


func _on_node_added(node: Node) -> void:
	if node.is_in_group("enemy"):
		call_deferred("_connect_enemy", node)


func _connect_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	if not enemy.has_signal("call_reinforcements"):
		return
	var callback := Callable(self, "_on_call_reinforcements")
	if not enemy.is_connected("call_reinforcements", callback):
		enemy.connect("call_reinforcements", callback)


func _on_call_reinforcements(origin := Vector3.ZERO) -> void:
	if reinforcement_cooldown_left > 0.0:
		return
	if player == null or not is_instance_valid(player):
		return
	reinforcement_cooldown_left = reinforcement_cooldown
	call_deferred("_spawn_reinforcement_wave", origin)


func _spawn_reinforcement_wave(_origin: Vector3) -> void:
	if player == null or not is_instance_valid(player):
		return
	var alive_reinforcements := 0
	for enemy in get_tree().get_nodes_in_group("reinforcement"):
		if (
			enemy.has_method("is_combat_alive")
			and bool(enemy.call("is_combat_alive"))
		):
			alive_reinforcements += 1
	var available := maxi(
		maximum_reinforcements - alive_reinforcements,
		0
	)
	var spawn_count := mini(reinforcement_wave_size, available)
	if spawn_count <= 0:
		return

	var spawned := 0
	var world_parent := get_parent() as Node3D
	if world_parent == null:
		return
	for index in spawn_count:
		var angle := (
			float(wave_index) * 1.71
			+ TAU * float(index) / float(maxi(spawn_count, 1))
		)
		var radius := lerpf(
			minimum_spawn_radius,
			maximum_spawn_radius,
			0.35 + 0.55 * absf(sin(angle * 1.37))
		)
		var position := _find_ground_position(
			player.global_position
			+ Vector3(cos(angle), 0.0, sin(angle)) * radius
		)
		var enemy := ENEMY_SCENE.instantiate() as CharacterBody3D
		if enemy == null:
			continue
		enemy.name = "Reinforcement_%d_%d" % [wave_index, index]
		enemy.add_to_group("reinforcement")
		enemy.global_position = position
		var to_player := player.global_position - position
		enemy.rotation.y = atan2(-to_player.x, -to_player.z)
		enemy.set("skin_index", 40 + wave_index * 3 + index)
		enemy.set("vision_heat", 1.0)
		enemy.set("has_seen_player", true)
		enemy.set("last_seen_position", player.global_position)
		world_parent.add_child(enemy)
		spawned += 1
	wave_index += 1
	if spawned > 0:
		reinforcements_called.emit(player.global_position, spawned)


func _find_ground_position(candidate: Vector3) -> Vector3:
	var origin := candidate + Vector3.UP * 18.0
	var target := candidate + Vector3.DOWN * 12.0
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collision_mask = 1
	var result := get_viewport().world_3d.direct_space_state.intersect_ray(
		query
	)
	if result.is_empty():
		candidate.y = player.global_position.y
		return candidate
	return Vector3(
		candidate.x,
		(result["position"] as Vector3).y + 0.08,
		candidate.z
	)


func _install_hiding_spots() -> void:
	if ResourceLoader.exists(HIDING_SPOT_SCENE_PATH) == false:
		return
	var hiding_scene := load(HIDING_SPOT_SCENE_PATH) as PackedScene
	if hiding_scene == null:
		return
	var world_parent := get_parent() as Node3D
	if world_parent == null:
		return
	for index in HIDING_SPOT_POSITIONS.size():
		var hiding_spot := hiding_scene.instantiate() as Node3D
		if hiding_spot == null:
			continue
		hiding_spot.name = "HidingSpot_%02d" % index
		hiding_spot.global_position = HIDING_SPOT_POSITIONS[index]
		hiding_spot.rotation.y = float(index) * 0.71
		world_parent.add_child(hiding_spot)


func _install_runtime_occlusion() -> void:
	for module in get_tree().get_nodes_in_group("parkour_module"):
		if not module is StaticBody3D:
			continue
		var body := module as StaticBody3D
		if body.has_node("RuntimeOccluder"):
			continue
		for child in body.get_children():
			if not child is CollisionShape3D:
				continue
			var collision := child as CollisionShape3D
			if not collision.shape is BoxShape3D:
				continue
			var box_shape := collision.shape as BoxShape3D
			var size := box_shape.size
			if size.y < 1.6 or maxf(size.x, size.z) < 2.0:
				continue
			var occluder := OccluderInstance3D.new()
			occluder.name = "RuntimeOccluder"
			occluder.transform = collision.transform
			var box_occluder := BoxOccluder3D.new()
			box_occluder.size = size
			occluder.occluder = box_occluder
			body.add_child(occluder)
			break


func _configure_visibility_ranges() -> void:
	for module in get_tree().get_nodes_in_group("parkour_module"):
		if not module is Node3D:
			continue
		for child in module.get_children():
			if not child is GeometryInstance3D:
				continue
			var geometry := child as GeometryInstance3D
			var bounds := geometry.get_aabb().size
			var longest_side := maxf(
				bounds.x,
				maxf(bounds.y, bounds.z)
			)
			if longest_side <= 0.01 or longest_side > 40.0:
				continue
			geometry.visibility_range_end = (
				155.0 if longest_side < 4.0 else 230.0
			)
			geometry.visibility_range_end_margin = 18.0
			geometry.visibility_range_fade_mode = (
				GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			)
