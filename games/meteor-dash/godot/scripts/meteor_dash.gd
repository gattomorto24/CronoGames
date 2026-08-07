extends Node2D

var lane := 1
var meteors: Array[Dictionary] = []
var time := -3.0
var distance := 0
var spawn := 0.0
var crashed := false

func _process(delta: float) -> void:
	if not crashed:
		time += delta
		if time >= 0.0:
			spawn -= delta
			if spawn <= 0:
				spawn = randf_range(0.32, 0.65)
				meteors.append({"lane": randi_range(0, 2), "y": -80.0, "speed": randf_range(380, 620)})
			for meteor in meteors:
				meteor.y += meteor.speed * delta
				if meteor.lane == lane and absf(meteor.y - size.y * 0.78) < 46: crashed = true
			meteors = meteors.filter(func(m: Dictionary) -> bool: return m.y < size.y + 100)
			distance += int(160 * delta)
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func _input(event: InputEvent) -> void:
	if event.is_pressed():
		if crashed:
			get_tree().reload_current_scene()
			return
		if event is InputEventKey:
			if event.keycode in [KEY_LEFT, KEY_A]: lane = maxi(0, lane - 1)
			if event.keycode in [KEY_RIGHT, KEY_D]: lane = mini(2, lane + 1)
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			lane = clampi(int(event.position.x / (size.x / 3.0)), 0, 2)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("180914"))
	var road := Rect2(size.x * 0.16, 0, size.x * 0.68, size.y)
	draw_rect(road, Color("2e1727"))
	for i in 2:
		draw_line(Vector2(road.position.x + road.size.x * (i + 1) / 3.0, 0), Vector2(road.position.x + road.size.x * (i + 1) / 3.0, size.y), Color("ffb565"), 3)
	for meteor in meteors:
		var p := Vector2(road.position.x + road.size.x * (meteor.lane + 0.5) / 3.0, meteor.y)
		draw_circle(p, 30, Color("ff654d")); draw_circle(p - Vector2(10, 12), 10, Color("ffe076"))
	var ship := Vector2(road.position.x + road.size.x * (lane + 0.5) / 3.0, size.y * 0.78)
	draw_colored_polygon(PackedVector2Array([ship + Vector2(0, -42), ship + Vector2(-27, 35), ship + Vector2(27, 35)]), Color("73edff"))
	text(Vector2(28, 42), "METEOR DASH", 22, Color("ffe4bd"))
	if time < 0: text(size * 0.5 + Vector2(-45, 4), str(int(ceil(-time))), 80, Color("fff3e1"))
	else: text(Vector2(28, 70), "DISTANZA %dm" % distance, 16, Color("ffbe86"))
	if crashed:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.01, 0.04, 0.72)); text(size * 0.5 + Vector2(-105, 0), "CORSIA PERSA", 28, Color("ffb0b0")); text(size * 0.5 + Vector2(-160, 34), "Tocca per ripartire", 17, Color.WHITE)

func text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
