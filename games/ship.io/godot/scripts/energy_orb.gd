class_name EnergyOrb
extends Node2D

var phase := 0.0
var value := 14

func _ready() -> void:
	phase = randf() * TAU
	queue_redraw()

func _process(delta: float) -> void:
	phase += delta * 2.7
	rotation += delta * 0.75
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(phase) * 0.13
	draw_circle(Vector2.ZERO, 20.0 * pulse, Color(0.57, 0.95, 1.0, 0.055))
	draw_circle(Vector2.ZERO, 12.0 * pulse, Color(0.32, 0.85, 1.0, 0.16))
	draw_circle(Vector2.ZERO, 6.0 * pulse, Color("b9f9ff"))
	draw_circle(Vector2(-2, -2), 2.0, Color.WHITE)
	for offset in [Vector2(13, 0), Vector2(-13, 0), Vector2(0, 13), Vector2(0, -13)]:
		draw_circle(offset, 1.6, Color("77d8ff"))
