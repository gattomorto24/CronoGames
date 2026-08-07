extends Move


func default_lifecycle(input) -> String:
	#if not area_awareness.is_on_floor():
		#return "midair"
	
	return best_input_that_can_be_paid(input)

func update(_input : InputPackage, delta : float):
	var y_speed = player.velocity.y
	if area_awareness.get_floor_distance() > 0.8:
		y_speed -= gravity * delta
	player.velocity.y = y_speed


func on_enter_state():
	player.velocity = Vector3.ZERO
