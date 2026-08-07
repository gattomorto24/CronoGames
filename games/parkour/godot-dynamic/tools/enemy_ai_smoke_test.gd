extends SceneTree


class StealthTestPlayer:
	extends CharacterBody3D

	var is_hidden := false
	var is_sneaking := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_world := Node3D.new()
	root.add_child(test_world)
	_add_ground(test_world)

	var player := StealthTestPlayer.new()
	player.name = "TestPlayer"
	player.add_to_group("parkour_player")
	var player_shape := CollisionShape3D.new()
	var player_capsule := CapsuleShape3D.new()
	player_capsule.radius = 0.30
	player_capsule.height = 1.78
	player_shape.position = Vector3.UP * 0.89
	player_shape.shape = player_capsule
	player.add_child(player_shape)
	test_world.add_child(player)
	player.global_position = Vector3(0.0, 0.05, 14.0)

	var packed_enemy := load(
		"res://CombatPrototype/ExtractedSwordsman.tscn"
	) as PackedScene
	if packed_enemy == null:
		_fail("enemy scene missing")
		return
	var enemy := packed_enemy.instantiate() as CharacterBody3D
	if enemy == null:
		_fail("enemy scene could not be instantiated")
		return
	enemy.set("patrol_radius", 2.4)
	enemy.set("patrol_speed", 1.2)
	enemy.set("reinforcement_call_seconds", 0.35)
	var reinforcement_calls: Array[Vector3] = []
	enemy.connect(
		&"call_reinforcements",
		func(position: Vector3) -> void:
			reinforcement_calls.append(position)
	)
	test_world.add_child(enemy)
	enemy.global_position = Vector3(0.0, 0.05, 0.0)
	enemy.rotation = Vector3.ZERO
	enemy.set("home_position", enemy.global_position)
	enemy.set("patrol_forward", Vector3(0.0, 0.0, -1.0))

	for frame in 12:
		await physics_frame
	var patrol_start := enemy.global_position
	for frame in 80:
		await physics_frame
	if enemy.global_position.distance_to(patrol_start) < 0.55:
		_fail("unaware enemy did not patrol")
		return

	_reset_enemy(enemy, Vector3.ZERO)
	enemy.set("patrol_radius", 0.0)
	player.global_position = Vector3(0.0, 0.05, -6.0)
	var chase_start_distance := enemy.global_position.distance_to(
		player.global_position
	)
	for frame in 12:
		await physics_frame
	if int(enemy.get("awareness_state")) != 1:
		_fail("visible player did not trigger suspicious state")
		return
	var showed_reinforcement_indicator := false
	for frame in 93:
		await physics_frame
		if bool(enemy.get("has_seen_player")):
			var indicator := enemy.get_node_or_null(
				"ReinforcementIndicator"
			) as Sprite3D
			if indicator != null and indicator.visible:
				showed_reinforcement_indicator = true
	var chase_end_distance := enemy.global_position.distance_to(
		player.global_position
	)
	if not bool(enemy.get("has_seen_player")):
		_fail("enemy did not detect a visible player")
		return
	if chase_end_distance >= chase_start_distance - 0.65:
		_fail("enemy detected the player but did not chase")
		return
	if not showed_reinforcement_indicator:
		_fail("alert did not show reinforcement countdown")
		return
	if reinforcement_calls.size() != 1:
		_fail("alert did not emit one reinforcement call")
		return

	var attack_position := enemy.global_position
	var enemy_forward := -enemy.global_basis.z
	enemy_forward.y = 0.0
	player.global_position = (
		attack_position
		+ enemy_forward.normalized() * 1.75
	)
	var began_attack := false
	for frame in 80:
		await physics_frame
		if int(enemy.get("combat_state")) == 2:
			began_attack = true
			break
	if not began_attack:
		_fail("enemy did not attack a visible nearby player")
		return
	var attack_elapsed_before := float(enemy.get("attack_elapsed"))
	for frame in 8:
		await physics_frame
	if float(enemy.get("attack_elapsed")) <= attack_elapsed_before + 0.05:
		_fail("enemy attack animation did not advance")
		return

	var wall_position := (
		enemy.global_position
		+ (
			player.global_position - enemy.global_position
		) * 0.5
	)
	var sight_blocker := _add_sight_blocker(
		test_world,
		wall_position
	)
	for frame in 3:
		await physics_frame
	var sword := enemy.get_node_or_null(
		"Character/Armature_004/GeneralSkeleton/Sword"
	)
	if int(enemy.get("combat_state")) == 2:
		_fail("enemy kept attacking after losing line of sight")
		return
	if sword != null and bool(sword.get("can_damage")):
		_fail("enemy weapon stayed active without line of sight")
		return

	_reset_enemy(enemy, Vector3.ZERO)
	player.global_position = Vector3(0.0, 0.05, -1.8)
	sight_blocker.global_position = Vector3(0.0, 1.25, -0.9)
	for frame in 90:
		await physics_frame
	if bool(enemy.get("has_seen_player")):
		_fail("enemy detected the player through a wall")
		return
	if int(enemy.get("combat_state")) == 2:
		_fail("enemy attacked the player through a wall")
		return

	sight_blocker.global_position = Vector3(20.0, 1.25, 20.0)
	_reset_enemy(enemy, Vector3.ZERO)
	player.is_hidden = true
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.05, -4.0)
	for frame in 90:
		await physics_frame
	if int(enemy.get("awareness_state")) != 0:
		_fail("enemy saw a hidden player outside close range")
		return

	player.global_position = Vector3(0.0, 0.05, -1.25)
	for frame in 70:
		await physics_frame
	if not bool(enemy.get("has_seen_player")):
		_fail("enemy ignored a hidden player at very close range")
		return

	_reset_enemy(enemy, Vector3.ZERO)
	player.is_hidden = false
	player.is_sneaking = false
	player.global_position = Vector3(0.0, 0.05, 4.0)
	player.velocity = Vector3(6.0, 0.0, 0.0)
	for frame in 4:
		await physics_frame
	player.velocity = Vector3.ZERO
	if int(enemy.get("awareness_state")) != 1:
		_fail("enemy did not hear a nearby running player")
		return

	var doomed_enemy := packed_enemy.instantiate() as CharacterBody3D
	var cancelled_calls: Array[Vector3] = []
	doomed_enemy.set("reinforcement_call_seconds", 0.2)
	doomed_enemy.set("patrol_radius", 0.0)
	doomed_enemy.connect(
		&"call_reinforcements",
		func(position: Vector3) -> void:
			cancelled_calls.append(position)
	)
	test_world.add_child(doomed_enemy)
	doomed_enemy.global_position = Vector3(10.0, 0.05, 10.0)
	doomed_enemy.set("has_seen_player", true)
	await physics_frame
	doomed_enemy.call("receive_assassination")
	for frame in 20:
		await physics_frame
	if not cancelled_calls.is_empty():
		_fail("dead enemy completed a reinforcement call")
		return

	print(
		(
			"Enemy AI smoke test passed: patrol, suspicion, alert, "
			+ "hearing, hiding, reinforcements and vision-gated attack"
		)
	)
	quit(0)


func _reset_enemy(enemy: CharacterBody3D, position: Vector3) -> void:
	enemy.global_position = position + Vector3.UP * 0.05
	enemy.rotation = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy.set("home_position", enemy.global_position)
	enemy.set("last_seen_position", enemy.global_position)
	enemy.set("has_seen_player", false)
	enemy.set("player_visible", false)
	enemy.set("vision_heat", 0.0)
	enemy.set("awareness_state", 0)
	enemy.set("investigation_time_left", 0.0)
	enemy.set("combat_state", 0)
	enemy.set("attack_cooldown", 0.0)


func _add_ground(parent: Node3D) -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	shape_node.position = Vector3(0.0, -0.1, 0.0)
	shape_node.shape = shape
	ground.add_child(shape_node)
	parent.add_child(ground)


func _add_sight_blocker(
	parent: Node3D,
	position: Vector3,
) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.2, 2.5, 0.24)
	shape_node.shape = shape
	wall.add_child(shape_node)
	parent.add_child(wall)
	wall.global_position = position
	wall.global_position.y = 1.25
	return wall


func _fail(message: String) -> void:
	push_error("Enemy AI smoke test: " + message)
	quit(1)
