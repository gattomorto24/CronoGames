extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Stealth smoke test: main scene missing")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for frame in 12:
		await physics_frame

	var player := get_first_node_in_group("parkour_player") as Node3D
	var enemy := get_first_node_in_group("enemy") as Node3D
	if player == null or enemy == null:
		push_error("Stealth smoke test: player or enemy missing")
		quit(1)
		return

	player.global_position = Vector3(0.0, 0.08, 0.0)
	player.rotation = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.08, -2.05)
	enemy.rotation = Vector3.ZERO
	enemy.set("has_seen_player", false)
	enemy.set("vision_heat", 0.0)
	if enemy.has_method("_update_status"):
		enemy.call("_update_status")
	for frame in 4:
		await physics_frame

	Input.action_press("assassinate")
	await physics_frame
	Input.action_release("assassinate")
	for frame in 80:
		await physics_frame

	var enemy_alive := true
	if enemy.has_method("is_combat_alive"):
		enemy_alive = bool(enemy.call("is_combat_alive"))
	if enemy_alive:
		push_error("Stealth smoke test: unaware enemy survived assassination")
		quit(1)
		return
	print("Stealth smoke test passed: unaware assassination killed target")
	quit(0)
