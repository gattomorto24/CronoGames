class_name SlitherSnake
extends Node2D

var segments: Array[Vector2] = []
var snake_name := "PILOTA"
var tint := Color("76f5b0")
var accent := Color("e9ffc1")
var direction := Vector2.RIGHT
var speed := 215.0
var base_speed := 215.0
var target_length := 32
var alive := true
var is_player := false
var ai_phase := 0.0
var score := 0

func configure(start: Vector2, display_name: String, snake_tint: Color, player_controlled: bool) -> void:
	global_position = start
	snake_name = display_name.to_upper().left(14)
	tint = snake_tint
	accent = tint.lightened(0.45)
	is_player = player_controlled
	direction = Vector2.RIGHT.rotated(randf() * TAU)
	for index in target_length:
		segments.append(global_position - direction * index * 8.0)
	queue_redraw()

func step_player(delta: float) -> void:
	var mouse_direction := global_position.direction_to(get_global_mouse_position())
	if mouse_direction.length() > 0.1:
		direction = direction.slerp(mouse_direction, minf(1.0, delta * 8.5)).normalized()
	var key_direction := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	if key_direction.length() > 0.1:
		direction = direction.slerp(key_direction.normalized(), minf(1.0, delta * 8.5)).normalized()
	var boosting := Input.is_key_pressed(KEY_SPACE) and segments.size() > 20
	speed = base_speed * (1.46 if boosting else 1.0)
	if boosting and randi() % 8 == 0:
		target_length = max(20, target_length - 1)
	move_forward(delta)

func step_ai(delta: float, target: Vector2) -> void:
	ai_phase += delta * 0.8
	var chase_direction := global_position.direction_to(target)
	var desired := chase_direction.rotated(sin(ai_phase + float(get_instance_id()) * 0.01) * 1.15)
	direction = direction.slerp(desired, delta * 1.55).normalized()
	speed = base_speed * 0.82
	move_forward(delta)

func move_forward(delta: float) -> void:
	if not alive:
		return
	global_position += direction * speed * delta
	global_position.x = clampf(global_position.x, 45.0, 5155.0)
	global_position.y = clampf(global_position.y, 45.0, 3955.0)
	segments.push_front(global_position)
	while segments.size() > target_length:
		segments.pop_back()
	queue_redraw()

func grow(amount: int) -> void:
	target_length += amount
	score += amount * 5

func _draw() -> void:
	if segments.size() < 2:
		return
	var points := PackedVector2Array()
	for point in segments:
		points.append(point - global_position)
	draw_polyline(points, Color(tint, 0.2), 28.0, true)
	draw_polyline(points, tint, 19.0, true)
	for index in range(3, segments.size(), 5):
		var local_point := segments[index] - global_position
		draw_circle(local_point, 8.0, tint.darkened(0.13))
		draw_circle(local_point + Vector2(-1.0, -1.0), 4.2, Color(tint, 0.8))
	var head := Vector2.ZERO
	draw_circle(head, 18.0, Color(tint, 0.18))
	draw_circle(head, 14.0, tint)
	var forward := direction * 7.0
	var side := direction.rotated(PI * 0.5) * 6.0
	draw_circle(forward + side, 4.0, Color.WHITE)
	draw_circle(forward - side, 4.0, Color.WHITE)
	draw_circle(forward + side + direction * 1.8, 1.9, Color("172130"))
	draw_circle(forward - side + direction * 1.8, 1.9, Color("172130"))
	draw_circle(-direction * 5.0, 7.0, accent)
	draw_string(ThemeDB.fallback_font, Vector2(-34.0, -31.0), snake_name, HORIZONTAL_ALIGNMENT_CENTER, 68.0, 11, Color("f1fff7"))
