extends Move


var height : float

func update(_input : InputPackage, delta : float):
	rotate_player(delta)
	move_player(delta)

func rotate_player(delta : float):
	var vertical_axis : Vector3 = player.global_position
	vertical_axis.y = area_awareness.ledge_climbing_point.y
	var climb_direction : Vector3 = vertical_axis.direction_to(area_awareness.ledge_climbing_point)
	var face_direction = player.basis.z
	var angle = face_direction.signed_angle_to(climb_direction, Vector3.UP)
	if abs(angle) > 0.001 and get_progress() < 0.9667:
		player.rotate_y(angle / 8)

func move_player(delta : float):
	var delta_pos = get_root_position_delta(delta)
	var velocity = player.get_quaternion() * delta_pos
	
	if get_progress() <= 0.3:
		velocity.y += ((height - 1.915) / 0.3) * delta
	
	player.global_position += velocity
	if get_progress() >= 3.1:
		player.global_position += player.basis.z * 0.004


func on_enter_state():
	height = area_awareness.ledge_climbing_point.y - (player.global_position.y)
	print(height)


func on_exit_state():
	var height = area_awareness.get_floor_distance() - area_awareness.on_floor_height + 0.2
	if height < 0:
		player.global_position.y -= height
