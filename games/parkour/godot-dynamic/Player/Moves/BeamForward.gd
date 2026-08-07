extends Move

@export var beam_speed : float = 1
@export var falling_angular_speed : float = 0.2
@export var correction_angular_speed : float = 0.4
@export var fall_treshold : float = PI / 6

var beam : ProtoBeam
var beam_direction : Vector3
var walk_direction_mod : int = 1

func translate_input_actions(input : InputPackage) -> InputPackage:
	var input_to_moves : Dictionary = {
		"beam_walk" : "beam_walk"
	}
	
	for action in input_to_moves.keys():
		if input.movement_actions.has(action):
			input.actions.append(input_to_moves[action])
	
	return input

func default_lifecycle(input : InputPackage):
	return best_input_that_can_be_paid(input)

func update(input : InputPackage, delta : float):
	var next_animation = choose_animation(input)
	if next_animation != animation:
		animation = next_animation
		animator.update_body_animations()
	
	var vertical_angle = player.basis.y.signed_angle_to(Vector3.UP, player.basis.z)
	if abs(vertical_angle) > fall_treshold:
		player.velocity = player.basis.x * 3 * sign(vertical_angle)
		player.look_at(player.global_position - player.velocity)
		try_force_move("midair") # TODO add a separate animation during glowup phase
		return
		
	var a_d = input.input_direction.x
	if a_d != 0:
		var correction_delta = a_d * correction_angular_speed * delta
		player.global_rotate(player.basis.z, correction_delta)
	else:
		var falling_delta = -sign(vertical_angle) * falling_angular_speed * delta
		player.global_rotate(player.basis.z, falling_delta)
	
	player.velocity = beam_direction * walk_direction_mod * beam_speed
	player.move_and_slide()


func process_input_vector(_input : InputPackage, delta : float):
	var dir = beam_direction
	dir.y = 0
	var face_direction = player.basis.z
	var angle = face_direction.signed_angle_to(dir, Vector3.UP)
	player.rotate_y(clamp(angle, -tracking_angular_speed * delta, tracking_angular_speed * delta))


func choose_animation(input : InputPackage) -> String:
	if input.input_direction.y <= 0: # y axis in 2D is down
		walk_direction_mod = 1
		return "rope_walk_forward"
	else:
		walk_direction_mod = -1
		return "rope_walk_backward"


func on_enter_state():
	beam = area_awareness.current_beam
	animation = choose_animation(area_awareness.last_input_package)
	beam_direction = beam.start.global_position.direction_to(beam.end.global_position)
	var angle = beam_direction.angle_to(player.basis.z)
	if angle >= PI / 2:
		beam_direction *= -1
	player.global_rotate(player.basis.z, randf_range(-0.1,0.1))


func on_exit_state():
	area_awareness.last_beam_fall = Time.get_unix_time_from_system()
	
