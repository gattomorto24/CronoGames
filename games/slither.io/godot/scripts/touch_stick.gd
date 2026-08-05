class_name CronoTouchStick
extends Control

var left_action := ""
var right_action := ""
var up_action := ""
var down_action := ""
var active_touch := -1
var handle := Vector2.ZERO

func setup(left_value: String, right_value: String, up_value: String, down_value: String) -> void:
	left_action = left_value
	right_action = right_value
	up_action = up_value
	down_action = down_value
	for action in [left_action, right_action, up_action, down_action]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	handle = size * 0.5
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(178, 178)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch < 0:
			active_touch = event.index
			move_handle(event.position)
			accept_event()
		elif not event.pressed and event.index == active_touch:
			release_stick()
			accept_event()
	elif event is InputEventScreenDrag and event.index == active_touch:
		move_handle(event.position)
		accept_event()

func move_handle(point: Vector2) -> void:
	var center := size * 0.5
	var delta := point - center
	var radius := minf(size.x, size.y) * 0.34
	if delta.length() > radius:
		delta = delta.normalized() * radius
	handle = center + delta
	var vector := delta / radius
	set_action(left_action, maxf(0.0, -vector.x))
	set_action(right_action, maxf(0.0, vector.x))
	set_action(up_action, maxf(0.0, -vector.y))
	set_action(down_action, maxf(0.0, vector.y))
	queue_redraw()

func set_action(action: String, strength: float) -> void:
	if strength > 0.08: Input.action_press(action, strength)
	else: Input.action_release(action)

func release_stick() -> void:
	active_touch = -1
	handle = size * 0.5
	for action in [left_action, right_action, up_action, down_action]: Input.action_release(action)
	queue_redraw()

func _exit_tree() -> void: release_stick()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, minf(size.x, size.y) * 0.45, Color(0.04, 0.24, 0.20, 0.32))
	draw_arc(center, minf(size.x, size.y) * 0.45, 0.0, TAU, 40, Color("7cf4bd"), 2.0, true)
	draw_circle(handle, minf(size.x, size.y) * 0.20, Color(0.35, 0.91, 0.68, 0.82))
	draw_arc(handle, minf(size.x, size.y) * 0.20, 0.0, TAU, 28, Color("e5fff2"), 1.5, true)
