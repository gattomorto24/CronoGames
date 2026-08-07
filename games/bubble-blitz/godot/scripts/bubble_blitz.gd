extends Node2D

var bubbles: Array[Dictionary] = []
var score := 0
var turns := 12
var won := false

func _ready() -> void:
	for i in 42:
		bubbles.append({"pos": Vector2(randf_range(45, size.x - 45), randf_range(95, size.y - 45)), "r": randf_range(15, 27), "color": [Color("7ae9ff"), Color("ff90d0"), Color("fff077")].pick_random()})

func _input(event: InputEvent) -> void:
	if event.is_pressed() and (event is InputEventMouseButton or event is InputEventScreenTouch):
		if won: get_tree().reload_current_scene(); return
		if turns > 0: pop_chain(event.position); turns -= 1

func pop_chain(origin: Vector2) -> void:
	var frontier := [origin]
	while not frontier.is_empty():
		var point: Vector2 = frontier.pop_front()
		for bubble in bubbles.duplicate():
			if point.distance_to(bubble.pos) < bubble.r + 43:
				frontier.append(bubble.pos); bubbles.erase(bubble); score += 10
	if bubbles.size() < 4: won = true
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07152d"))
	for bubble in bubbles:
		draw_circle(bubble.pos, bubble.r, Color(bubble.color, 0.78)); draw_arc(bubble.pos, bubble.r + 3, 0, TAU, 18, Color.WHITE, 1.2)
	text(Vector2(28, 42), "BUBBLE BLITZ", 22, Color("e7f8ff")); text(Vector2(28, 70), "BOLLE %02d  •  MOSSE %02d  •  %04d" % [bubbles.size(), turns, score], 16, Color("8fb7e9"))
	if won: draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.18, 0.75)); text(size * 0.5 + Vector2(-100, 0), "CATENA PERFETTA", 25, Color("e6ffae")); text(size * 0.5 + Vector2(-120, 32), "Tocca per un nuovo schema", 16, Color.WHITE)

func text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
