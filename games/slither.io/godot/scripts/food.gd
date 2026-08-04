class_name SlitherFood
extends Node2D

var tint := Color("ffdf6e")
var value := 1
var phase := 0.0

func configure(food_tint: Color, food_value: int) -> void:
	tint = food_tint
	value = food_value
	phase = randf() * TAU

func _process(delta: float) -> void:
	phase += delta * 3.0
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(phase) * 0.16
	draw_circle(Vector2.ZERO, 11.0 * pulse, Color(tint, 0.11))
	draw_circle(Vector2.ZERO, 6.0 * pulse, Color(tint, 0.35))
	draw_circle(Vector2.ZERO, 3.0 * pulse, tint)
	draw_circle(Vector2(-1, -1), 1.1, Color.WHITE)
