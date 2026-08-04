extends Move


@export var SPEED = 5.0
@export var TURN_SPEED = 3.2

@export var sprint_stamina_cost = 20 # per sec so multiply by delta

func translate_input_actions(input : InputPackage) -> InputPackage:
	var input_to_moves : Dictionary = {
		"move" : "run",
		"move_fast" : "sprint",
		"go_up" : "jump_sprint",
		"midair" : "midair",
		"beam_walk" : "beam_walk"
	}
	
	for action in input_to_moves.keys():
		if input.movement_actions.has(action):
			input.actions.append(input_to_moves[action])
	
	return input

func default_lifecycle(input : InputPackage):
	#if not player.is_on_floor():
		#return "midair"
	
	return best_input_that_can_be_paid(input)


func update(_input : InputPackage, delta : float):
	player.move_and_slide()
	resources.lose_stamina(sprint_stamina_cost * delta)


func process_input_vector(input : InputPackage, delta : float):
	var y_speed = player.velocity.y
	var input_direction = (player.camera_mount.basis * Vector3(-input.input_direction.x, 0, -input.input_direction.y)).normalized()
	var face_direction = player.basis.z
	var angle = face_direction.signed_angle_to(input_direction, Vector3.UP)
	var new_z = player.basis.z.rotated(Vector3.UP, clamp(angle, -tracking_angular_speed * delta, tracking_angular_speed * delta))
	var new_x = -new_z.cross(Vector3.UP)
	player.basis = Basis(new_x, Vector3.UP, new_z).orthonormalized()
	if abs(angle) >= tracking_angular_speed * delta:
		player.velocity = player.basis.z * TURN_SPEED
	else:
		player.velocity = player.basis.z * SPEED
	if area_awareness.get_floor_distance() > 0.8:
		y_speed -= gravity * delta
	player.velocity.y = y_speed
	animator.set_speed_scale(player.velocity.length() / SPEED)


func on_exit_state():
	animator.set_speed_scale(1)
