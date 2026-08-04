class_name Projectile
extends Node2D

var velocity := Vector2.ZERO
var damage := 20.0
var from_player := true
var lifetime := 1.15
var tint := Color("d7ff57")
var game: Node

func setup(start_position: Vector2, direction: Vector2, bullet_damage: float, player_bullet: bool, bullet_tint: Color, game_ref: Node) -> void:
	global_position = start_position
	velocity = direction.normalized() * 780.0
	damage = bullet_damage
	from_player = player_bullet
	tint = bullet_tint
	game = game_ref

func _process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0 or global_position.x < -80.0 or global_position.y < -80.0 or global_position.x > 4880.0 or global_position.y > 3680.0:
		queue_free()
		return
	if game != null:
		game.resolve_projectile(self)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(tint, 0.09))
	draw_circle(Vector2.ZERO, 6.0, Color(tint, 0.32))
	draw_circle(Vector2.ZERO, 3.2, tint)
	draw_circle(Vector2(-1, -1), 1.2, Color.WHITE)
