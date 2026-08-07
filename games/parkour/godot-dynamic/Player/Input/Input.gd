extends Node
class_name InputGatherer

func gather_input() -> InputPackage:
	var new_input = InputPackage.new()
	
	new_input.actions.append("idle")
	
	new_input.input_direction = Input.get_vector("left", "right", "forward", "backward")
	if new_input.input_direction != Vector2.ZERO:
		new_input.movement_actions.append("move")
		if Input.is_action_pressed("move_fast"):
			new_input.movement_actions.append("move_fast")
	
	if Input.is_action_pressed("parry"):
		new_input.actions.append("parry")
	
	if Input.is_action_pressed("roll"):
		new_input.actions.append("roll")
	
	if Input.is_action_pressed("block"):
		new_input.actions.append("block")
	
	if Input.is_action_pressed("go_up"):
		new_input.movement_actions.append("go_up")
	
	if Input.is_action_just_pressed("light_attack"):
		new_input.combat_actions.append("light_attack_pressed")
	
	return new_input
