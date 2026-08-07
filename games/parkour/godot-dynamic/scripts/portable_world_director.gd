extends Node3D

# Web/phone-safe scene bootstrap for the existing Dynamic Mediterranean project.
# It deliberately reuses the authored district, original DynamicParkourPlayer,
# detection system, animations and zip lines. The native WorldDirector remains
# available for desktop development; this version removes only the platform-
# specific C++ bootstrap so the same game can be exported to WebGL.

const PLAYER_SCENE := preload("res://DynamicParkour/DynamicParkourPlayer.tscn")
const DISTRICT_SCENE := preload("res://assets/models/bazaar_district.glb")
const ZIPLINE_SCENE := preload("res://DynamicParkour/ZipLine.tscn")


func _ready() -> void:
	_create_input_map()
	_create_environment()
	_load_authored_district()
	_create_physics_floor()
	_create_open_plaza_routes()
	_create_player()
	_create_desktop_hint()


func _create_input_map() -> void:
	for binding in [
		[&"forward", KEY_W], [ &"backward", KEY_S], [ &"left", KEY_A], [ &"right", KEY_D],
		[&"go_up", KEY_SPACE], [ &"move_fast", KEY_SHIFT], [ &"drop", KEY_CTRL],
		[&"reset_player", KEY_R], [ &"mouse_mode_switch", KEY_F10], [ &"assassinate", KEY_F],
		[&"block", KEY_E], [ &"sneak", KEY_C],
	]:
		_ensure_key_action(binding[0], binding[1])
	if not InputMap.has_action(&"attack"):
		InputMap.add_action(&"attack", 0.12)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"attack", click)


func _ensure_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.22)
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	InputMap.action_add_event(action_name, key)


func _create_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.055, 0.28, 0.72)
	sky_material.sky_horizon_color = Color(0.54, 0.76, 0.95)
	sky_material.ground_bottom_color = Color(0.27, 0.31, 0.37)
	sky_material.ground_horizon_color = Color(0.57, 0.73, 0.90)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.set_background(Environment.BG_SKY)
	environment.set_sky(sky)
	environment.set_ambient_source(Environment.AMBIENT_SOURCE_SKY)
	environment.set_reflection_source(Environment.REFLECTION_SOURCE_SKY)
	environment.set_tonemapper(Environment.TONE_MAPPER_FILMIC)
	environment.set_ssao_enabled(true)
	environment.set_ssao_radius(2.1)
	environment.set_ssao_intensity(1.7)
	environment.set_glow_enabled(true)
	environment.set_glow_intensity(0.45)
	environment.set("fog_enabled", true)
	environment.set("fog_light_color", Color(0.69, 0.51, 0.35))
	environment.set("fog_density", 0.0035)
	var world_environment := WorldEnvironment.new()
	world_environment.name = "CinematicEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.79, 0.58)
	sun.light_energy = 1.58
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "CoolSkyFill"
	fill.rotation_degrees = Vector3(-68.0, 145.0, 0.0)
	fill.light_color = Color(0.28, 0.47, 0.82)
	fill.light_energy = 0.36
	add_child(fill)


func _load_authored_district() -> void:
	var district := DISTRICT_SCENE.instantiate() as Node3D
	district.name = "AuthoredMediterraneanCity"
	district.position = Vector3(56.0, 0.0, -18.0)
	district.rotation_degrees = Vector3(0.0, -5.0, 0.0)
	_configure_movement_surfaces(district)
	add_child(district)


func _configure_movement_surfaces(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer |= 3
	for child in node.get_children():
		_configure_movement_surfaces(child)


func _create_physics_floor() -> void:
	var floor := StaticBody3D.new()
	floor.name = "StreetFoundation"
	floor.position = Vector3(0.0, -0.22, 0.0)
	floor.collision_layer = 3
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(260.0, 0.35, 220.0)
	collision.shape = shape
	floor.add_child(collision)
	add_child(floor)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh.material = _material(Color(0.20, 0.125, 0.075))
	visual.mesh = mesh
	visual.position = floor.position
	add_child(visual)


func _create_open_plaza_routes() -> void:
	var dark_lava := Color(0.115, 0.100, 0.088)
	var stone := Color(0.66, 0.56, 0.41)
	var limestone := Color(0.78, 0.68, 0.50)
	var terracotta := Color(0.52, 0.22, 0.105)
	var wood := Color(0.23, 0.15, 0.075)
	var plaster := Color(0.72, 0.68, 0.58)
	var route: Array = [
		["OpenBazaarPlazaPaving", Vector3(0, -0.005, 1), Vector3(54, .10, 66), Color(.34, .255, .175)],
		["NorthSlideAwningBeam", Vector3(-10, 1.5, 21), Vector3(6.7, .30, .70), wood],
		["NorthSlideAwningLeftPier", Vector3(-13.25, 1.05, 21), Vector3(.46, 2.1, .76), stone],
		["NorthSlideAwningRightPier", Vector3(-6.75, 1.05, 21), Vector3(.46, 2.1, .76), stone],
		["SouthSlideAwningBeam", Vector3(9.6, 1.48, -3.8), Vector3(6.2, .28, .72), wood],
		["LowMarketCounterNorth", Vector3(4.7, .42, 23), Vector3(3.15, .84, .62), terracotta],
		["LowMarketCounterWest", Vector3(-5.6, .40, 13.3), Vector3(2.65, .80, .62), stone],
		["LowPlanterJumpLine", Vector3(6.1, .47, 9), Vector3(2.2, .94, 1.05), limestone],
		["BrokenCartVault", Vector3(-1.6, .46, -7.2), Vector3(3.25, .92, .66), wood],
		["SidewaysStoneBench", Vector3(-13.8, .38, -10), Vector3(.74, .76, 3.2), plaster],
		["WestClimbPlatform", Vector3(-15.4, 1.28, 7.8), Vector3(4.8, 2.56, 4.7), stone],
		["WestClimbPlatformLipNorth", Vector3(-15.4, 2.70, 10.22), Vector3(5.1, .20, .30), dark_lava],
		["WestClimbLowerCrate", Vector3(-11.1, .78, 5.5), Vector3(2.4, 1.56, 2.05), terracotta],
		["EastFacadeClimbWall", Vector3(15.4, 2.72, 7.2), Vector3(.72, 5.44, 7.4), plaster],
		["EastFacadeLowerHandhold", Vector3(15, 2.16, 7.2), Vector3(.22, .18, 7.25), dark_lava],
		["EastFacadeUpperHandhold", Vector3(15, 3.62, 7.2), Vector3(.22, .18, 7.25), dark_lava],
		["CentralRaisedStepOne", Vector3(-2.5, .56, 7), Vector3(2.7, 1.12, 2.45), terracotta],
		["CentralRaisedStepTwo", Vector3(1.2, .68, 3), Vector3(2.85, 1.36, 2.45), limestone],
		["CentralRaisedStepThree", Vector3(-3.8, .76, -1.3), Vector3(2.85, 1.52, 2.45), stone],
		["SouthwestClimbBlock", Vector3(-15.6, 1.66, -16), Vector3(5.2, 3.32, 4.6), limestone],
		["SoutheastTowerWall", Vector3(13.8, 2.65, -15.4), Vector3(.68, 5.3, 6.7), terracotta],
		["OppositeTowerWall", Vector3(17.25, 2.65, -15.4), Vector3(.68, 5.3, 6.7), plaster],
		["FarSouthLandingPlatform", Vector3(0, 1.18, -23), Vector3(5.8, 2.36, 5.6), stone],
		["FarSouthPlatformNorthLip", Vector3(0, 2.48, -20.08), Vector3(5.95, .20, .30), dark_lava],
	]
	for prop in route:
		_create_prop(prop[0], prop[1], prop[2], prop[3])
	_create_zipline("WestPlatformZipLine", Vector3(-15.4, 4.0, 8.8), Vector3(-3.8, 2.85, -1.3), 9.6)
	_create_zipline("TowerToSouthZipLine", Vector3(15.4, 5.65, -15.4), Vector3(0, 3.15, -23), 10.8)


func _create_prop(prop_name: String, position: Vector3, prop_size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = prop_name
	body.position = position
	body.collision_layer = 3
	body.add_to_group("parkour_module")
	body.set_meta("parkour_surface", true)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = prop_size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = prop_size
	mesh.material = _material(color)
	visual.mesh = mesh
	body.add_child(visual)
	add_child(body)
	return body


func _create_zipline(zipline_name: String, start: Vector3, destination: Vector3, speed: float) -> void:
	var zipline := ZIPLINE_SCENE.instantiate() as Node3D
	zipline.name = zipline_name
	zipline.set("start_point", start)
	zipline.set("end_point", destination)
	zipline.set("travel_speed", speed)
	add_child(zipline)


func _create_player() -> void:
	var player := PLAYER_SCENE.instantiate() as DynamicParkourPlayer
	player.name = "DynamicParkourPlayer"
	player.position = Vector3(0.0, .08, 28.0)
	add_child(player)


func _create_desktop_hint() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	var label := Label.new()
	label.text = "CRONO PARKOUR — WASD muovi · SHIFT corsa · SPAZIO parkour · CTRL scivola · F azione · click attacco"
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, .91, .74))
	layer.add_child(label)
	add_child(layer)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .88
	return material
