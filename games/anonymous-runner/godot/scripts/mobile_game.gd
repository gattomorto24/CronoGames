extends Node3D

const MobilePlayer := preload("res://scripts/mobile_player.gd")
const MobileCamera := preload("res://scripts/mobile_camera.gd")
const MobileInput := preload("res://scripts/mobile_input.gd")
const MobileArena := preload("res://scripts/mobile_online.gd")

var player
var camera_rig
var controls
var checkpoint := Vector3(0.0, 1.2, 13.0)
var crystals: Array[Node3D] = []
var total_crystals := 0
var run_complete := false
var time_label: Label
var score_label: Label
var notice_label: Label
var notice_left := 0.0
var network_label: Label
var online
var remote_runners: Dictionary = {}

func _ready() -> void:
	name = "CronoParkourMobile"
	build_environment()
	build_level()
	player = MobilePlayer.new()
	add_child(player)
	player.set_spawn(checkpoint)
	player.landed.connect(func() -> void: show_notice("Atterraggio pulito"))
	player.jumped.connect(func() -> void: show_notice("Salto"))
	camera_rig = MobileCamera.new()
	add_child(camera_rig)
	camera_rig.snap_to(player)
	controls = MobileInput.new()
	add_child(controls)
	build_hud()
	online = MobileArena.new()
	add_child(online)
	online.start(self, player)
	show_notice("Raccogli i nuclei e raggiungi il portale")

func _physics_process(delta: float) -> void:
	if run_complete:
		return
	player.step(controls.movement(), controls.take_jump(), controls.take_dash(), delta)
	camera_rig.follow(player, delta)
	if player.global_position.y < -12.0:
		player.reset_to_checkpoint()
		show_notice("Checkpoint raggiunto · riparti")
	for crystal in crystals:
		if is_instance_valid(crystal):
			crystal.rotate_y(delta * 2.1)
	update_hud()
	if notice_left > 0.0:
		notice_left -= delta
		if notice_left <= 0.0:
			notice_label.modulate.a = 0.0

func build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("070a1c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7b74be")
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-51.0, -34.0, 0.0)
	key_light.light_color = Color("b8c5ff")
	key_light.light_energy = 1.4
	key_light.shadow_enabled = false
	add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(0.0, 7.0, -45.0)
	fill_light.light_color = Color("7e5bff")
	fill_light.light_energy = 5.0
	fill_light.omni_range = 38.0
	fill_light.shadow_enabled = false
	add_child(fill_light)

func build_level() -> void:
	add_block(Vector3(0.0, -0.5, 8.0), Vector3(20.0, 1.0, 30.0), Color("19265d"))
	add_block(Vector3(0.0, 0.0, -13.0), Vector3(16.0, 1.0, 20.0), Color("25377a"))
	add_block(Vector3(2.0, 1.25, -34.0), Vector3(11.0, 1.0, 15.0), Color("304791"))
	add_block(Vector3(-2.0, 2.5, -55.0), Vector3(14.0, 1.0, 16.0), Color("3f4fa7"))
	add_block(Vector3(0.0, 3.8, -76.0), Vector3(10.0, 1.0, 18.0), Color("4c55b8"))
	add_block(Vector3(0.0, 5.1, -101.0), Vector3(18.0, 1.0, 22.0), Color("33438c"))
	add_border(Vector3(-10.3, 0.7, 8.0), Vector3(0.35, 1.4, 30.0))
	add_border(Vector3(10.3, 0.7, 8.0), Vector3(0.35, 1.4, 30.0))
	for obstacle in [Vector3(-4.0, 1.0, 1.0), Vector3(4.0, 1.0, -6.0), Vector3(0.0, 2.0, -32.0), Vector3(-4.0, 3.2, -51.0), Vector3(3.0, 4.5, -73.0)]:
		add_block(obstacle, Vector3(2.0, 2.0, 2.0), Color("8f5cff"))
	for data in [
		[Vector3(-4.0, 1.8, 4.0), "A"], [Vector3(4.0, 1.8, -3.0), "B"],
		[Vector3(0.0, 2.0, -15.0), "C"], [Vector3(2.0, 3.2, -35.0), "D"],
		[Vector3(-2.0, 4.5, -56.0), "E"], [Vector3(0.0, 5.8, -78.0), "F"]
	]:
		add_checkpoint(data[0], data[1])
	for point in [
		Vector3(-5.0, 1.5, 8.0), Vector3(0.0, 1.5, 2.0), Vector3(5.0, 1.5, -8.0),
		Vector3(-4.0, 2.5, -16.0), Vector3(3.0, 2.8, -31.0), Vector3(0.0, 4.0, -39.0),
		Vector3(-5.0, 3.8, -55.0), Vector3(3.0, 4.8, -73.0), Vector3(0.0, 6.2, -92.0)
	]:
		add_crystal(point)
	add_finish(Vector3(0.0, 6.8, -105.0))

func add_block(position_value: Vector3, dimensions: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = position_value
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = surface_material(color)
	body.add_child(mesh)

func add_border(position_value: Vector3, dimensions: Vector3) -> void:
	add_block(position_value, dimensions, Color("1a2154"))

func add_crystal(position_value: Vector3) -> void:
	var crystal := Area3D.new()
	crystal.position = position_value
	crystal.monitoring = true
	add_child(crystal)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	collision.shape = shape
	crystal.add_child(collision)
	var mesh := MeshInstance3D.new()
	var octahedron := SphereMesh.new()
	octahedron.radius = 0.38
	octahedron.height = 0.84
	octahedron.radial_segments = 6
	octahedron.rings = 2
	mesh.mesh = octahedron
	mesh.material_override = surface_material(Color("87fff1"), Color("3fc7ff"), 2.4)
	crystal.add_child(mesh)
	crystal.body_entered.connect(func(body: Node3D) -> void:
		if body != player:
			return
		player.collected += 1
		crystal.queue_free()
		show_notice("Nucleo raccolto +1")
	)
	crystals.append(crystal)
	total_crystals += 1

func add_checkpoint(position_value: Vector3, label_text: String) -> void:
	var checkpoint_area := Area3D.new()
	checkpoint_area.position = position_value
	add_child(checkpoint_area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 3.0, 1.1)
	collision.shape = shape
	checkpoint_area.add_child(collision)
	var marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.3
	ring.outer_radius = 1.52
	ring.rings = 8
	ring.ring_segments = 12
	marker.mesh = ring
	marker.rotation_degrees.x = 90.0
	marker.material_override = surface_material(Color("ffcc71"), Color("ff8c3a"), 1.1)
	checkpoint_area.add_child(marker)
	var label := Label3D.new()
	label.text = "CP " + label_text
	label.position = Vector3(0.0, 1.7, 0.0)
	label.font_size = 34
	label.outline_size = 8
	label.modulate = Color("fff3d4")
	checkpoint_area.add_child(label)
	checkpoint_area.body_entered.connect(func(body: Node3D) -> void:
		if body == player:
			checkpoint = Vector3(player.global_position.x, position_value.y + 0.8, player.global_position.z)
			player.spawn_point = checkpoint
			show_notice("Checkpoint " + label_text)
	)

func add_finish(position_value: Vector3) -> void:
	var finish := Area3D.new()
	finish.position = position_value
	add_child(finish)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.8
	shape.height = 3.5
	collision.shape = shape
	finish.add_child(collision)
	for height in [0.0, 1.35, 2.7]:
		var ring_mesh := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 2.25
		ring.outer_radius = 2.48
		ring.rings = 8
		ring.ring_segments = 16
		ring_mesh.mesh = ring
		ring_mesh.position.y = height
		ring_mesh.material_override = surface_material(Color("d78aff"), Color("9a4dff"), 2.8)
		finish.add_child(ring_mesh)
	finish.body_entered.connect(func(body: Node3D) -> void:
		if body == player and not run_complete:
			run_complete = true
			show_notice("TRAGUARDO · Run completata!")
			notice_left = 999.0
	)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := Panel.new()
	panel.position = Vector2(20.0, 18.0)
	panel.size = Vector2(266.0, 62.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.13, 0.66)
	style.border_color = Color(0.55, 0.49, 1.0, 0.55)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	time_label = Label.new()
	time_label.position = Vector2(14.0, 9.0)
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", Color("f2f1ff"))
	panel.add_child(time_label)
	score_label = Label.new()
	score_label.position = Vector2(14.0, 32.0)
	score_label.add_theme_font_size_override("font_size", 12)
	score_label.add_theme_color_override("font_color", Color("89ffec"))
	panel.add_child(score_label)
	network_label = Label.new()
	network_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	network_label.position = Vector2(-104.0, 9.0)
	network_label.size = Vector2(92.0, 20.0)
	network_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	network_label.add_theme_font_size_override("font_size", 9)
	network_label.add_theme_color_override("font_color", Color("c7c2ff"))
	panel.add_child(network_label)
	notice_label = Label.new()
	notice_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notice_label.position = Vector2(-180.0, 28.0)
	notice_label.size = Vector2(360.0, 28.0)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 16)
	notice_label.add_theme_color_override("font_color", Color("ffffff"))
	notice_label.add_theme_color_override("font_outline_color", Color("111035"))
	notice_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(notice_label)

func update_hud() -> void:
	var total := maxi(total_crystals, 1)
	time_label.text = "ANONYMOUS RUNNER  %02d:%02d" % [int(player.run_time) / 60, int(player.run_time) % 60]
	score_label.text = "NUCLEI %d / %d" % [player.collected, total]

func mobile_movement() -> Vector2:
	return controls.movement()

func mobile_jump_active() -> bool:
	return controls.active_jump()

func set_network_state(value: String) -> void:
	if network_label != null:
		network_label.text = value

func sync_online_players(state: Dictionary, local_id: String) -> void:
	var active := {}
	var shown := 0
	var actors: Array = state.get("players", []).duplicate()
	actors.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return not bool(first.get("bot", false)) and bool(second.get("bot", false)))
	for actor in actors:
		var actor_id := str(actor.get("id", ""))
		if actor_id.is_empty() or actor_id == local_id or shown >= 8:
			continue
		shown += 1
		active[actor_id] = true
		var remote: Node3D = remote_runners.get(actor_id)
		if remote == null:
			remote = create_remote_runner(str(actor.get("nickname", "Runner")), bool(actor.get("bot", false)))
			remote_runners[actor_id] = remote
			add_child(remote)
		var target := Vector3((float(actor.get("x", 60.0)) - 60.0) * 0.15, 0.7, 13.0 - float(actor.get("y", 60.0)) * 0.9)
		remote.global_position = remote.global_position.lerp(target, 0.22)
	for actor_id in remote_runners.keys():
		if active.has(actor_id):
			continue
		var stale: Node3D = remote_runners[actor_id]
		stale.queue_free()
		remote_runners.erase(actor_id)
	set_network_state("ONLINE · %d" % int(state.get("humans", 1)))

func create_remote_runner(nickname: String, is_bot: bool) -> Node3D:
	var remote := Node3D.new()
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.22
	capsule.radial_segments = 8
	mesh.mesh = capsule
	mesh.material_override = surface_material(Color("73e8ff") if is_bot else Color("ffca72"), Color("3e9dff") if is_bot else Color("ff894c"), 1.2)
	remote.add_child(mesh)
	var label := Label3D.new()
	label.text = nickname
	label.position = Vector3(0.0, 1.15, 0.0)
	label.font_size = 28
	label.outline_size = 6
	remote.add_child(label)
	return remote

func show_notice(message: String) -> void:
	if notice_label == null:
		return
	notice_label.text = message
	notice_label.modulate.a = 1.0
	notice_left = 1.25

func surface_material(color: Color, emission := Color.TRANSPARENT, energy := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.72
	if energy > 0.0:
		result.emission_enabled = true
		result.emission = emission
		result.emission_energy_multiplier = energy
	return result
