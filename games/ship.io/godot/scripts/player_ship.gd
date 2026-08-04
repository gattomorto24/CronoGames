class_name PlayerShip
extends Node2D

signal stats_changed
signal destroyed

var game: Node
var ship_color := Color("a76cff")
var accent_color := Color("f071ff")
var velocity := Vector2.ZERO
var speed := 340.0
var max_health := 100.0
var health := 100.0
var xp := 0.0
var xp_next := 100.0
var level := 1
var score := 0
var fire_interval := 0.28
var fire_timer := 0.0
var invulnerability := 0.0
var thrust_phase := 0.0

func configure(game_ref: Node, selected_skin: String) -> void:
	game = game_ref
	match selected_skin:
		"cyan":
			ship_color = Color("55dcff")
			accent_color = Color("447bff")
		"amber":
			ship_color = Color("ffd166")
			accent_color = Color("ff7657")
		_:
			ship_color = Color("a76cff")
			accent_color = Color("f071ff")

func _process(delta: float) -> void:
	if health <= 0.0:
		return
	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("cg_ship_right")) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("cg_ship_left")),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("cg_ship_down")) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("cg_ship_up"))
	)
	velocity = velocity.move_toward(input_vector.normalized() * speed, speed * 8.0 * delta)
	position += velocity * delta
	position.x = clampf(position.x, 60.0, 4740.0)
	position.y = clampf(position.y, 60.0, 3540.0)
	if Input.is_action_pressed("cg_ship_left") or Input.is_action_pressed("cg_ship_right") or Input.is_action_pressed("cg_ship_up") or Input.is_action_pressed("cg_ship_down"):
		if input_vector.length() > 0.1:
			rotation = input_vector.angle()
	else:
		look_at(get_global_mouse_position())
	fire_timer = maxf(0.0, fire_timer - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	thrust_phase += delta * (8.0 + velocity.length() * 0.025)
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("cg_ship_fire")) and fire_timer <= 0.0:
		fire_timer = fire_interval
		game.spawn_projectile(global_position + Vector2.RIGHT.rotated(rotation) * 30.0, Vector2.RIGHT.rotated(rotation), 20.0 + level * 2.0, true, ship_color)
	queue_redraw()

func collect_orb(value: int) -> void:
	xp += value
	score += value
	while xp >= xp_next:
		xp -= xp_next
		xp_next = floor(xp_next * 1.28)
		level += 1
		max_health += 20.0
		health = max_health
		speed += 24.0
		fire_interval = maxf(0.11, fire_interval - 0.024)
		game.announce_upgrade(level)
	stats_changed.emit()

func take_damage(amount: float) -> void:
	if invulnerability > 0.0 or health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	invulnerability = 0.13
	stats_changed.emit()
	if health <= 0.0:
		destroyed.emit()
	queue_redraw()

func _draw() -> void:
	var flame_scale := 0.8 + sin(thrust_phase) * 0.22 + velocity.length() / speed * 0.32
	draw_circle(Vector2(-22, 0), 20.0 * flame_scale, Color(accent_color, 0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(-29, 0), Vector2(-51, -10 * flame_scale), Vector2(-44, 0), Vector2(-51, 10 * flame_scale)]), Color(accent_color, 0.72))
	draw_colored_polygon(PackedVector2Array([Vector2(34, 0), Vector2(-21, -23), Vector2(-10, 0), Vector2(-21, 23)]), ship_color)
	draw_colored_polygon(PackedVector2Array([Vector2(22, 0), Vector2(-10, -13), Vector2(2, 0), Vector2(-10, 13)]), Color("f4f0ff"))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -15), Vector2(-27, -30), Vector2(-19, -6)]), Color(accent_color, 0.85))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 15), Vector2(-27, 30), Vector2(-19, 6)]), Color(accent_color, 0.85))
	draw_circle(Vector2(5, 0), 4.0, Color.WHITE)
	if invulnerability > 0.0:
		draw_arc(Vector2.ZERO, 39.0, 0.0, TAU, 24, Color("ffe7f6"), 1.5)
