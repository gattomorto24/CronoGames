extends Node2D

var player := Vector2(640, 500)
var hazards: Array[Dictionary] = []
var elapsed := 0.0
var spawn_clock := 0.0
var score := 0
var alive := true
var touch_target := Vector2.ZERO
var has_touch_target := false

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if alive:
		elapsed += delta
		spawn_clock -= delta
		if spawn_clock <= 0.0:
			spawn_clock = maxf(0.18, 0.75 - elapsed * 0.018)
			hazards.append({"pos": Vector2(randf_range(26, size.x - 26), -30), "speed": randf_range(170, 310) + elapsed * 8})
		var move := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * 430.0
		if has_touch_target:
			move = (touch_target - player).limit_length(430.0)
		player += move * delta
		player = player.clamp(Vector2(25, 25), size - Vector2(25, 25))
		for hazard in hazards:
			hazard.pos.y += hazard.speed * delta
			if player.distance_to(hazard.pos) < 31:
				alive = false
		hazards = hazards.filter(func(h: Dictionary) -> bool: return h.pos.y < size.y + 50)
		score = int(elapsed * 100)
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_target = event.position
		has_touch_target = event.pressed if event is InputEventScreenTouch else true
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		touch_target = event.position
		has_touch_target = true
	if not alive and event.is_pressed():
		get_tree().reload_current_scene()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07091a"))
	for x in range(0, int(size.x), 48): draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.15, 0.2, 0.42, 0.18))
	for y in range(0, int(size.y), 48): draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.15, 0.2, 0.42, 0.18))
	for hazard in hazards:
		draw_circle(hazard.pos, 22, Color("ff3b8d"))
		draw_arc(hazard.pos, 28, 0, TAU, 20, Color("ff8ec2"), 2)
	draw_circle(player, 18, Color("5dffe2"))
	draw_arc(player, 25, 0, TAU, 20, Color("5dffe2"), 2)
	text(Vector2(28, 42), "NEON DODGE  •  RESISTI", 22, Color("b8fff1"))
	text(Vector2(28, 72), "PUNTEGGIO %05d" % score, 16, Color("81a3d1"))
	if not alive:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.08, 0.72))
		text(size * 0.5 + Vector2(-150, -10), "IMPATTO!", 38, Color("ff79b3"))
		text(size * 0.5 + Vector2(-165, 30), "Tocca per ricominciare", 17, Color.WHITE)

func text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
