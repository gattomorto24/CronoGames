extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Combat smoke test: main scene missing")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for frame in 12:
		await physics_frame

	var player := get_first_node_in_group("parkour_player") as Node3D
	var enemy := get_first_node_in_group("enemy") as Node3D
	if player == null or enemy == null:
		push_error("Combat smoke test: player or enemy missing")
		quit(1)
		return

	player.global_position = Vector3(0.0, 0.08, 0.0)
	player.rotation = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.08, -2.05)
	enemy.rotation = Vector3(0.0, PI, 0.0)
	if enemy.has_method("_update_status"):
		enemy.call("_update_status")
	for frame in 4:
		await physics_frame

	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	var sword := player.get_node_or_null(
		"VisualPivot/Erika/Skeleton3D/CombatSword"
	)
	var min_blade_distance := INF
	for frame in 80:
		if sword != null and sword.has_method("blade_base"):
			var base: Vector3 = sword.call("blade_base")
			var tip: Vector3 = sword.call("blade_tip", 0.74)
			var target := enemy.global_position + Vector3.UP * 0.98
			min_blade_distance = minf(
				min_blade_distance,
				_distance_to_segment(target, base, tip)
			)
		await physics_frame

	var enemy_alive := true
	if enemy.has_method("is_combat_alive"):
		enemy_alive = bool(enemy.call("is_combat_alive"))
	var enemy_health := 100.0
	var health_node := enemy.get_node_or_null("HealthComponent")
	if health_node != null:
		enemy_health = float(health_node.get("health"))
	var player_swung := (
		player.has_method("has_performed")
		and bool(player.call("has_performed", "combat_attack_inward"))
	)
	if not player_swung:
		push_error("Combat smoke test: player attack did not start")
		quit(1)
		return
	if enemy_alive and enemy_health >= 100.0:
		push_error(
			"Combat smoke test: sword did not register a precise hit, "
			+ "closest distance %.2f" % min_blade_distance
		)
		quit(1)
		return
	print("Combat smoke test passed: enemy health %.1f" % enemy_health)
	quit(0)


func _distance_to_segment(
	point: Vector3,
	start: Vector3,
	end: Vector3
) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var projection := clampf(
		(point - start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	return point.distance_to(start + segment * projection)
