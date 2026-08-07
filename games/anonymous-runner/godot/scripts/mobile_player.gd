class_name CronoMobileRunner
extends CharacterBody3D

signal landed
signal jumped

const GRAVITY := 25.0
const WALK_SPEED := 8.2
const DASH_SPEED := 13.8
const ACCELERATION := 28.0
const JUMP_SPEED := 9.2
const COYOTE_TIME := 0.12

var spawn_point := Vector3.ZERO
var coyote_left := 0.0
var dash_left := 0.0
var collected := 0
var run_time := 0.0
var previous_floor := false

func _ready() -> void:
	name = "MobileRunner"
	build_body()

func set_spawn(point: Vector3) -> void:
	spawn_point = point
	global_position = point
	velocity = Vector3.ZERO

func reset_to_checkpoint() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	dash_left = 0.0

func step(input_vector: Vector2, jump_requested: bool, dash_requested: bool, delta: float) -> void:
	run_time += delta
	var on_floor := is_on_floor()
	if on_floor:
		coyote_left = COYOTE_TIME
	elif coyote_left > 0.0:
		coyote_left -= delta
		velocity.y -= GRAVITY * delta
	else:
		velocity.y -= GRAVITY * delta
	if jump_requested and (on_floor or coyote_left > 0.0):
		velocity.y = JUMP_SPEED
		coyote_left = 0.0
		jumped.emit()
	if dash_requested and dash_left <= 0.0:
		dash_left = 0.34
	if dash_left > 0.0:
		dash_left -= delta
	var direction := Vector3(input_vector.x, 0.0, -input_vector.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var target_speed := DASH_SPEED if dash_left > 0.0 else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction.x * target_speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * target_speed, ACCELERATION * delta)
	if direction.length_squared() > 0.03:
		var facing := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, facing, minf(1.0, delta * 14.0))
	move_and_slide()
	if on_floor and not previous_floor:
		landed.emit()
	previous_floor = on_floor

func build_body() -> void:
	var collision := CollisionShape3D.new()
	var collision_shape := CapsuleShape3D.new()
	collision_shape.radius = 0.34
	collision_shape.height = 1.42
	collision.shape = collision_shape
	collision.position.y = 0.71
	add_child(collision)
	var model := Node3D.new()
	model.name = "LowPolyRunner"
	add_child(model)
	var suit := MeshInstance3D.new()
	var suit_mesh := CapsuleMesh.new()
	suit_mesh.radius = 0.34
	suit_mesh.height = 1.32
	suit_mesh.radial_segments = 8
	suit_mesh.rings = 3
	suit.mesh = suit_mesh
	suit.position.y = 0.72
	suit.material_override = material(Color("6d5dff"), Color("261d66"))
	model.add_child(suit)
	var visor := MeshInstance3D.new()
	var visor_mesh := SphereMesh.new()
	visor_mesh.radius = 0.23
	visor_mesh.height = 0.22
	visor_mesh.radial_segments = 8
	visor_mesh.rings = 4
	visor.mesh = visor_mesh
	visor.position = Vector3(0.0, 1.08, -0.23)
	visor.material_override = material(Color("70f4e5"), Color("1e8fbb"), 1.6)
	model.add_child(visor)
	for side in [-1.0, 1.0]:
		var boot := MeshInstance3D.new()
		var boot_mesh := BoxMesh.new()
		boot_mesh.size = Vector3(0.2, 0.12, 0.38)
		boot.mesh = boot_mesh
		boot.position = Vector3(0.17 * side, 0.12, 0.08)
		boot.material_override = material(Color("202440"))
		model.add_child(boot)

func material(color: Color, emission_color := Color.TRANSPARENT, energy := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.62
	if energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = energy
	return result
