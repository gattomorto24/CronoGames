class_name CronoMobileInput
extends CanvasLayer

class VirtualStick:
	extends Control

	var active_touch := -1
	var handle := Vector2.ZERO
	var vector := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(184, 184)
		handle = size * 0.5
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and active_touch < 0:
				active_touch = event.index
				set_handle(event.position)
				accept_event()
			elif not event.pressed and event.index == active_touch:
				release_stick()
				accept_event()
		elif event is InputEventScreenDrag and event.index == active_touch:
			set_handle(event.position)
			accept_event()

	func set_handle(point: Vector2) -> void:
		var center := size * 0.5
		var delta := point - center
		var radius := minf(size.x, size.y) * 0.35
		if delta.length() > radius:
			delta = delta.normalized() * radius
		handle = center + delta
		vector = delta / radius
		queue_redraw()

	func release_stick() -> void:
		active_touch = -1
		vector = Vector2.ZERO
		handle = size * 0.5
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, minf(size.x, size.y) * 0.45, Color(0.05, 0.07, 0.19, 0.38))
		draw_arc(center, minf(size.x, size.y) * 0.45, 0.0, TAU, 40, Color("8a7dff"), 2.0, true)
		draw_circle(handle, minf(size.x, size.y) * 0.2, Color("8c77ff"))
		draw_arc(handle, minf(size.x, size.y) * 0.2, 0.0, TAU, 28, Color("d8d1ff"), 1.5, true)

var stick: VirtualStick
var jump_requested := false
var jump_held := false
var dash_requested := false
var dash_held := false

func _ready() -> void:
	layer = 12
	build_controls()

func movement() -> Vector2:
	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard.y -= 1.0
	var result := stick.vector + keyboard
	return result.limit_length(1.0)

func take_jump() -> bool:
	var value := jump_requested or Input.is_key_pressed(KEY_SPACE)
	jump_requested = false
	return value

func take_dash() -> bool:
	var value := dash_requested or Input.is_key_pressed(KEY_SHIFT)
	dash_requested = false
	return value

func active_dash() -> bool:
	return dash_held or Input.is_key_pressed(KEY_SHIFT)

func active_jump() -> bool:
	return jump_held or Input.is_key_pressed(KEY_SPACE)

func build_controls() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	stick = VirtualStick.new()
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick.position = Vector2(24, -208)
	stick.size = Vector2(184, 184)
	root.add_child(stick)
	add_action_button(root, "SALTA", Vector2(-128, -212), Vector2(102, 76), Color("75f5dc"), request_jump, release_jump)
	add_action_button(root, "SCATTO", Vector2(-128, -124), Vector2(102, 68), Color("b08aff"), request_dash, release_dash)

func add_action_button(root: Control, label: String, offset: Vector2, dimensions: Vector2, color: Color, down: Callable, up: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.flat = false
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = offset
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("f6f4ff"))
	button.add_theme_stylebox_override("normal", button_style(color, 0.74))
	button.add_theme_stylebox_override("pressed", button_style(color.lightened(0.16), 0.96))
	button.button_down.connect(down)
	button.button_up.connect(up)
	button.tree_exiting.connect(up)
	root.add_child(button)

func button_style(color: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.28, alpha)
	style.border_color = color
	style.set_border_width_all(2)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	return style

func request_jump() -> void:
	jump_requested = true
	jump_held = true

func release_jump() -> void:
	jump_held = false

func request_dash() -> void:
	dash_requested = true
	dash_held = true

func release_dash() -> void:
	dash_held = false
