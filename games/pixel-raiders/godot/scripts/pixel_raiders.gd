extends Node2D

var player := Vector2.ZERO
var aim := Vector2.ZERO
var bullets: Array[Dictionary] = []
var raiders: Array[Dictionary] = []
var cooldown := 0.0
var wave := 1
var score := 0
var game_over := false

func _ready() -> void:
	player = size * 0.5; aim = player + Vector2.RIGHT
	spawn_wave()

func spawn_wave() -> void:
	for i in wave * 3:
		var p := Vector2(randf_range(30, size.x - 30), randf_range(30, size.y - 30))
		if p.distance_to(player) < 180: p += Vector2(220, 120)
		raiders.append({"pos": p.clamp(Vector2(20, 20), size - Vector2(20, 20)), "hp": 1 + wave / 3})

func _process(delta: float) -> void:
	if game_over: return
	var movement := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * 270.0
	player = (player + movement * delta).clamp(Vector2(18, 18), size - Vector2(18, 18))
	cooldown -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): fire()
	for bullet in bullets: bullet.pos += bullet.dir * 700 * delta
	for raider in raiders:
		var d: Vector2 = player - raider.pos; raider.pos += d.normalized() * (55 + wave * 4) * delta
		if d.length() < 24: game_over = true
	for bullet in bullets.duplicate():
		for raider in raiders.duplicate():
			if bullet.pos.distance_to(raider.pos) < 19:
				raider.hp -= 1; bullets.erase(bullet)
				if raider.hp <= 0: raiders.erase(raider); score += 10
	bullets = bullets.filter(func(b: Dictionary) -> bool: return Rect2(Vector2.ZERO, size).grow(50).has_point(b.pos))
	if raiders.is_empty(): wave += 1; spawn_wave()
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func fire() -> void:
	if cooldown > 0: return
	cooldown = 0.16
	bullets.append({"pos": player, "dir": (aim - player).normalized()})

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag: aim = event.position
	if event is InputEventScreenTouch and event.pressed: aim = event.position; fire()
	if game_over and event.is_pressed(): get_tree().reload_current_scene()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b0820"))
	for raider in raiders:
		draw_rect(Rect2(raider.pos - Vector2(13, 13), Vector2(26, 26)), Color("ff5f89")); draw_rect(Rect2(raider.pos - Vector2(7, 7), Vector2(14, 14)), Color("401832"))
	for bullet in bullets: draw_circle(bullet.pos, 5, Color("f9ff79"))
	draw_circle(player, 17, Color("71f6ff")); draw_line(player, player + (aim - player).normalized() * 31, Color("d4ffff"), 5)
	text(Vector2(28, 42), "PIXEL RAIDERS  •  ONDATA %d" % wave, 22, Color("dfdcff")); text(Vector2(28, 70), "ROTTAMI %04d" % score, 16, Color("aaa7dc"))
	if game_over: draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.01, 0.08, 0.72)); text(size * 0.5 + Vector2(-90, 0), "BASE PERSA", 28, Color("ffb1cc")); text(size * 0.5 + Vector2(-145, 32), "Tocca per una nuova incursione", 16, Color.WHITE)

func text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
