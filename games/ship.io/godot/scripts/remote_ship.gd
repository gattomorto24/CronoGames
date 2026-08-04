extends Node2D

var display_name := "RIVALE"
var ship_color := Color("71dfff")
var bot := false

func configure(name_text: String, skin: String, is_bot: bool) -> void:
	display_name = name_text.to_upper().left(14)
	bot = is_bot
	match skin:
		"cyan": ship_color = Color("55dcff")
		"amber", "gold": ship_color = Color("ffd166")
		"pink": ship_color = Color("ff7faf")
		"mint": ship_color = Color("78f4ad")
		_: ship_color = Color("a76cff") if not bot else Color("6ef1dc")
	queue_redraw()

func apply_network_state(target_position: Vector2, target_angle: float) -> void:
	global_position = global_position.lerp(target_position, 0.24)
	rotation = lerp_angle(rotation, target_angle, 0.28)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 30.0, Color(ship_color, 0.09))
	draw_colored_polygon(PackedVector2Array([Vector2(28, 0), Vector2(-18, -18), Vector2(-7, 0), Vector2(-18, 18)]), ship_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -14), Vector2(-25, -26), Vector2(-18, -3)]), Color(ship_color, 0.7))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 14), Vector2(-25, 26), Vector2(-18, 3)]), Color(ship_color, 0.7))
	draw_circle(Vector2(4, 0), 3.0, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(-42, -37), display_name + (" · BOT" if bot else ""), HORIZONTAL_ALIGNMENT_CENTER, 84, 11, Color("e9f7ff"))
