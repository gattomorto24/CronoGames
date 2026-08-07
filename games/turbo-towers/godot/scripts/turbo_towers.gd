extends Node2D

var player := Vector2.ZERO
var velocity := Vector2(0, -420)
var platforms: Array[Rect2] = []
var height := 0
var dead := false

func _ready() -> void:
	player = Vector2(size.x * 0.5, size.y - 100)
	for i in 9: platforms.append(Rect2(randf_range(45, size.x - 190), size.y - i * 105, randf_range(100, 185), 18))

func _process(delta: float) -> void:
	if dead: return
	velocity.x = move_toward(velocity.x, Input.get_axis("ui_left", "ui_right") * 310.0, 1200 * delta)
	velocity.y += 1050 * delta; player += velocity * delta
	player.x = wrapf(player.x, 0, size.x)
	if velocity.y > 0:
		for platform in platforms:
			if player.x > platform.position.x and player.x < platform.end.x and player.y + 17 > platform.position.y and player.y - velocity.y * delta + 17 <= platform.position.y:
				velocity.y = -520
		if player.y > size.y + 45: dead = true
	if player.y < size.y * 0.36:
		var shift := size.y * 0.36 - player.y; player.y += shift
		for i in platforms.size(): platforms[i].position.y += shift
		for platform in platforms:
			if platform.position.y > size.y + 30: platform.position = Vector2(randf_range(35, size.x - 190), platform.position.y - 940); height += 1
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag: velocity.x = sign(event.relative.x) * 300
	if dead and event.is_pressed(): get_tree().reload_current_scene()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("08132b"))
	for platform in platforms:
		draw_rect(platform, Color("5ef1d3")); draw_line(platform.position, Vector2(platform.end.x, platform.position.y), Color("d1ffef"), 2)
	draw_circle(player, 18, Color("ffc968")); draw_circle(player + Vector2(0, -4), 9, Color("ffffff"))
	text(Vector2(28, 42), "TURBO TOWERS", 22, Color("ddf8ff")); text(Vector2(28, 70), "PIANI SUPERATI %03d" % height, 16, Color("82b6dd"))
	if dead: draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.12, 0.7)); text(size * 0.5 + Vector2(-100, 0), "CADUTA LIBERA", 27, Color("ffc98d")); text(size * 0.5 + Vector2(-125, 32), "Tocca per risalire", 16, Color.WHITE)

func text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
