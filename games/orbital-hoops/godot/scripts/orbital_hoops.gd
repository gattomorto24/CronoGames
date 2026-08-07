extends Node2D

var ball := Vector2.ZERO
var velocity := Vector2.ZERO
var target := Vector2.ZERO
var shots := 0
var score := 0
var waiting := true

func _ready() -> void:
	reset_ball()

func reset_ball() -> void:
	ball = Vector2(130, size.y * 0.5)
	velocity = Vector2.ZERO
	target = Vector2(size.x * randf_range(0.55, 0.86), size.y * randf_range(0.23, 0.77))
	waiting = true

func _process(delta: float) -> void:
	if not waiting:
		var gravity := (size * 0.5 - ball).normalized() * 90.0
		velocity += gravity * delta
		ball += velocity * delta
		if ball.distance_to(target) < 33:
			score += 1; reset_ball()
		elif ball.x > size.x + 70 or ball.y < -70 or ball.y > size.y + 70:
			reset_ball()
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func _input(event: InputEvent) -> void:
	if event.is_pressed() and (event is InputEventMouseButton or event is InputEventScreenTouch):
		if waiting:
			velocity = (event.position - ball).normalized() * minf(700.0, ball.distance_to(event.position) * 2.3 + 160.0)
			waiting = false; shots += 1

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("06102a"))
	var center := size * 0.5
	for radius in [90, 170, 255]: draw_arc(center, radius, 0, TAU, 70, Color(0.24, 0.42, 0.82, 0.24), 1.5)
	draw_arc(target, 29, 0, TAU, 32, Color("d9ff85"), 7)
	draw_arc(target, 39, 0, TAU, 32, Color("74e7ff"), 2)
	draw_circle(ball, 14, Color("ffcf7a")); draw_arc(ball, 22, 0, TAU, 20, Color("fff1be"), 2)
	text(Vector2(28, 42), "ORBITAL HOOPS", 22, Color("dcecff")); text(Vector2(28, 70), "ANELLI %d   LANCI %d" % [score, shots], 16, Color("91b8f5"))
	if waiting: text(Vector2(92, size.y - 38), "Tocca lontano dalla sfera per lanciarla nell'anello", 17, Color("d5e5ff"))

func text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
