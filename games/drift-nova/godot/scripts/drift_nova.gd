extends Node2D

var pos := Vector2.ZERO
var angle := -PI * 0.5
var velocity := 0.0
var laps := 0
var checkpoint := 0
var started := false
var course := PackedVector2Array()

func _ready() -> void:
	build_course(); pos = size * 0.5 + Vector2(0, 175)

func build_course() -> void:
	var c := size * 0.5
	for i in 10:
		var a := TAU * i / 10.0; course.append(c + Vector2(cos(a) * size.x * 0.31, sin(a) * size.y * 0.31))

func _process(delta: float) -> void:
	if started:
		var turn := Input.get_axis("ui_left", "ui_right")
		angle += turn * delta * (1.8 + velocity * 0.003)
		velocity = clampf(velocity + Input.get_axis("ui_down", "ui_up") * delta * 185.0 - 18.0 * delta, 45.0, 330.0)
		pos += Vector2.from_angle(angle) * velocity * delta
		if pos.distance_to(course[checkpoint]) < 58:
			checkpoint = (checkpoint + 1) % course.size()
			if checkpoint == 0: laps += 1
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func _input(event: InputEvent) -> void:
	if event.is_pressed() and not started: started = true
	if event is InputEventScreenDrag:
		if event.position.x < size.x * 0.5: angle -= 0.06
		else: angle += 0.06

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0d0922"))
	if course.size() < 2: return
	draw_polyline(course, Color("734ccf"), 132, true); draw_polyline(course, Color("171339"), 94, true)
	for i in course.size():
		draw_circle(course[i], 10, Color("f6e36b") if i == checkpoint else Color("5b438e"))
	draw_set_transform(pos, angle + PI * 0.5)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(-14, 17), Vector2(14, 17)]), Color("ff6eb8"))
	draw_set_transform(Vector2.ZERO)
	text(Vector2(28, 42), "DRIFT NOVA", 22, Color("f4dcff")); text(Vector2(28, 70), "GIRI %d  •  %03d km/h" % [laps, int(velocity)], 16, Color("d1a7ee"))
	if not started: text(size * 0.5 + Vector2(-150, 10), "TOCCA PER ACCENDERE I MOTORI", 18, Color("ffdbf2"))

func text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
