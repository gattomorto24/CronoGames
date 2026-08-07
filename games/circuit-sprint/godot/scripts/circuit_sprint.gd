extends Node2D

var lane := 1
var gates: Array[Dictionary] = []
var clock := 30.0
var spawn := 0.0
var score := 0
var done := false

func _process(delta: float) -> void:
	if done: return
	clock -= delta; spawn -= delta
	if spawn <= 0:
		spawn = 0.55; gates.append({"lane": randi_range(0, 2), "y": -45.0, "good": randf() > 0.38})
	for gate in gates:
		gate.y += 335 * delta
		if gate.y > size.y * 0.74 and gate.y - 335 * delta <= size.y * 0.74:
			if gate.lane == lane and gate.good: score += 1
			elif gate.lane == lane: clock -= 3
	gates = gates.filter(func(g: Dictionary) -> bool: return g.y < size.y + 60)
	if clock <= 0: done = true
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func _input(event: InputEvent) -> void:
	if event.is_pressed():
		if done: get_tree().reload_current_scene(); return
		if event is InputEventKey:
			if event.keycode in [KEY_LEFT, KEY_A]: lane = maxi(0, lane - 1)
			if event.keycode in [KEY_RIGHT, KEY_D]: lane = mini(2, lane + 1)
		if event is InputEventScreenTouch or event is InputEventMouseButton: lane = clampi(int(event.position.x / (size.x / 3.0)), 0, 2)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("071018"))
	for x in 4: draw_line(Vector2(x * size.x / 3.0, 80), Vector2(x * size.x / 3.0, size.y), Color("1d5267"), 2)
	for gate in gates:
		var p := Vector2((gate.lane + 0.5) * size.x / 3.0, gate.y)
		draw_rect(Rect2(p - Vector2(60, 17), Vector2(120, 34)), Color("82f6c1") if gate.good else Color("ff5b7a"))
	var runner := Vector2((lane + 0.5) * size.x / 3.0, size.y * 0.74)
	draw_circle(runner, 21, Color("83cfff")); draw_line(runner - Vector2(25, 0), runner + Vector2(25, 0), Color("effcff"), 3)
	text(Vector2(28, 42), "CIRCUIT SPRINT", 22, Color("d8f8ff")); text(Vector2(28, 70), "NODI %d  •  TEMPO %.1fs" % [score, maxf(0, clock)], 16, Color("79b3c8"))
	if done: draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0.05, 0.08, 0.72)); text(size * 0.5 + Vector2(-115, 0), "CIRCUITO CHIUSO", 26, Color("bce8ff")); text(size * 0.5 + Vector2(-130, 32), "Tocca per una nuova corsa", 16, Color.WHITE)

func text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
