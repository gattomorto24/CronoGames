extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Plaza smoke test: main scene missing")
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	for frame in 12:
		await physics_frame

	var plaza := scene.get_node_or_null("OpenBazaarPlazaPaving")
	var slide := scene.get_node_or_null("NorthSlideAwningBeam")
	var platform := scene.get_node_or_null("WestClimbPlatform")
	if plaza == null or slide == null or platform == null:
		push_error("Plaza smoke test: open parkour props missing")
		quit(1)
		return

	var enemies := get_nodes_in_group("enemy")
	if enemies.size() < 12:
		push_error(
			"Plaza smoke test: expected at least 12 enemies, found %d"
			% enemies.size()
		)
		quit(1)
		return

	var player := get_first_node_in_group("parkour_player") as CharacterBody3D
	if player == null:
		push_error("Plaza smoke test: player missing")
		quit(1)
		return

	var detector := player.get_node_or_null("DetectionController")
	if detector == null:
		push_error("Plaza smoke test: detection controller missing")
		quit(1)
		return

	player.global_position = Vector3(-15.4, 0.12, 11.6)
	player.velocity = Vector3.ZERO
	for frame in 2:
		await physics_frame

	var ledge: Dictionary = detector.call(
		"detect_ledge",
		Vector3(0.0, 0.0, -1.0),
		0.50,
		2.70
	)
	if ledge.is_empty():
		push_error("Plaza smoke test: platform ledge was not detected")
		quit(1)
		return

	quit(0)
