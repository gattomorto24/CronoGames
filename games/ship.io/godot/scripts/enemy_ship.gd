class_name EnemyShip
extends Node2D

var game: Node
var ship_color := Color("ff607f")
var velocity := Vector2.ZERO
var health := 70.0
var max_health := 70.0
var speed := 150.0
var fire_timer := 0.0
var drift_target := Vector2.ZERO
var pulse := 0.0
var score_value := 50

func configure(game_ref: Node, spawn_position: Vector2, color: Color) -> void:
	game = game_ref
	global_position = spawn_position
	ship_color = color
	drift_target = spawn_position
	pulse = randf() * TAU

func _process(delta: float) -> void:
	var target: PlayerShip = game.player
	if target == null or target.health <= 0.0:
		return
	pulse += delta * 3.0
	var distance := global_position.distance_to(target.global_position)
	var desired := Vector2.ZERO
	if distance > 470.0:
		desired = global_position.direction_to(target.global_position)
	elif distance < 290.0:
		desired = target.global_position.direction_to(global_position)
	else:
		desired = global_position.direction_to(target.global_position).rotated(sin(pulse) * 1.1)
	velocity = velocity.move_toward(desired * speed, speed * 2.6 * delta)
	global_position += velocity * delta
	look_at(target.global_position)
	fire_timer = maxf(0.0, fire_timer - delta)
	if distance < 690.0 and fire_timer <= 0.0:
		fire_timer = randf_range(0.92, 1.36)
		game.spawn_projectile(global_position + Vector2.RIGHT.rotated(rotation) * 26.0, Vector2.RIGHT.rotated(rotation), 13.0, false, Color("ff799c"))
	queue_redraw()

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		game.enemy_destroyed(self)
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 26.0, Color(ship_color, 0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(27, 0), Vector2(-20, -17), Vector2(-7, 0), Vector2(-20, 17)]), ship_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -15), Vector2(-24, -27), Vector2(-18, -5)]), Color("6f315e"))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 15), Vector2(-24, 27), Vector2(-18, 5)]), Color("6f315e"))
	draw_circle(Vector2(5, 0), 3.5, Color("ffdbe8"))
	draw_rect(Rect2(-20, -34, 40, 4), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(-20, -34, 40.0 * maxf(0.0, health) / max_health, 4), Color("ff7e96"))
