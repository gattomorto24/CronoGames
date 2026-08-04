extends Move


func default_lifecycle(_input : InputPackage):
	if works_longer_than(DURATION):
		return "midair"
	return "okay"

func update(_input : InputPackage, delta):
	move_player(delta)


func move_player(delta : float):
	player.move_and_slide()
	#var delta_pos = get_root_position_delta(delta)
	#delta_pos.y = 0
	#player.velocity = player.get_quaternion() * delta_pos / delta
	#player.move_and_slide()


func on_enter_state():
	var dir = player.basis.z
	var hor = player.velocity
	hor.y = 0
	player.velocity = dir.bounce(area_awareness.last_wall_jump_normal) * 5
	player.velocity.y = 2
	dir = player.velocity
	dir.y = 0
	player.look_at(player.global_position + dir)


func on_exit_state():
	player.look_at(player.global_position - player.velocity)
