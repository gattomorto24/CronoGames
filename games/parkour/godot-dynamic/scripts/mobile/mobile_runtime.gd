extends CanvasLayer

# MobileRuntime is an adapter for the *existing* DynamicParkourPlayer.  It does
# not own a second physics controller or a reduced level: it maps touch input
# directly into the established parkour state machine.

var _player: DynamicParkourPlayer
var _touch_enabled := false
var _mobile_ui: Control


func _ready() -> void:
	_touch_enabled = _is_touch_runtime()
	if not _touch_enabled:
		visible = false
		return
	layer = 100
	_configure_mobile_performance()
	call_deferred("_connect_to_player")
	call_deferred("_hide_desktop_interface")
	_build_mobile_ui()


func _is_touch_runtime() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		var user_agent := String(JavaScriptBridge.eval("navigator.userAgent || ''", true)).to_lower()
		return "android" in user_agent or "iphone" in user_agent or "ipad" in user_agent or "ipod" in user_agent
	return false


func _connect_to_player() -> void:
	_player = get_tree().get_first_node_in_group("parkour_player") as DynamicParkourPlayer
	if _player == null:
		await get_tree().process_frame
		_connect_to_player()
		return
	_player.set_mobile_input_enabled(true)


func _hide_desktop_interface() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		var interface_layer := scene.get_node_or_null("Interface") as CanvasLayer
		if interface_layer != null:
			interface_layer.visible = false
	var stealth_hud := get_tree().root.get_node_or_null("StealthHUD") as CanvasLayer
	if stealth_hud != null:
		stealth_hud.visible = false


func _configure_mobile_performance() -> void:
	# Render less detail on a physically smaller display while preserving the
	# authored level, parkour probes, character and animation state machine.
	get_viewport().scaling_3d_scale = 0.68
	var scene := get_tree().current_scene
	if scene == null:
		return
	var environment_node := scene.get_node_or_null("CinematicEnvironment") as WorldEnvironment
	if environment_node != null and environment_node.environment != null:
		var environment := environment_node.environment
		environment.set("ssao_enabled", false)
		environment.set("ssil_enabled", false)
		environment.set("glow_enabled", false)
		environment.set("fog_enabled", false)
	for light in scene.find_children("*", "DirectionalLight3D", true, false):
		(light as DirectionalLight3D).shadow_enabled = false


func _build_mobile_ui() -> void:
	_mobile_ui = Control.new()
	_mobile_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mobile_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_mobile_ui)

	# The look surface is deliberately added first. The stick and buttons added
	# below sit above it and therefore own their touches.
	var look_pad := TouchLookPad.new()
	look_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	look_pad.anchor_left = 0.47
	look_pad.offset_left = 0
	look_pad.look_dragged.connect(_on_camera_dragged)
	_mobile_ui.add_child(look_pad)

	var stick := TouchStick.new()
	stick.custom_minimum_size = Vector2(176, 176)
	stick.position = Vector2(28, 0)
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick.position.y = -204
	stick.size = Vector2(176, 176)
	stick.direction_changed.connect(_on_stick_changed)
	_mobile_ui.add_child(stick)

	var jump := _make_button("SALTA", Vector2(-130, -222), Vector2(102, 72))
	_bind_held_action(jump, &"go_up")
	var sprint := _make_button("SCATTA", Vector2(-242, -138), Vector2(100, 62))
	_bind_held_action(sprint, &"move_fast")
	var action := _make_button("AZIONE", Vector2(-135, -140), Vector2(104, 62))
	_bind_held_action(action, &"assassinate")
	var attack := _make_button("ATTACCA", Vector2(-246, -62), Vector2(104, 54))
	attack.button_down.connect(_on_attack_pressed)
	var slide := _make_button("SCIVOLA", Vector2(-135, -68), Vector2(104, 54))
	slide.button_down.connect(_pulse_drop)


func _make_button(label_text: String, offset: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = label_text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = offset
	button.size = size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.96, 0.92, 0.76, 1.0))
	button.add_theme_stylebox_override("normal", _style_box(Color(0.035, 0.06, 0.10, 0.78), Color(0.90, 0.63, 0.19, 0.72)))
	button.add_theme_stylebox_override("pressed", _style_box(Color(0.90, 0.63, 0.19, 0.88), Color(1.0, 0.88, 0.61, 0.95)))
	_mobile_ui.add_child(button)
	return button


func _style_box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style


func _bind_held_action(button: Button, action_name: StringName) -> void:
	button.button_down.connect(func() -> void: Input.action_press(action_name))
	button.button_up.connect(func() -> void: Input.action_release(action_name))


func _on_stick_changed(direction: Vector2) -> void:
	if _player != null:
		_player.set_mobile_move_input(direction)


func _on_camera_dragged(relative: Vector2) -> void:
	if _player != null:
		_player.add_mobile_camera_look(relative)


func _on_attack_pressed() -> void:
	if _player != null:
		_player.request_mobile_attack()


func _pulse_drop() -> void:
	Input.action_press(&"drop")
	await get_tree().create_timer(0.08).timeout
	Input.action_release(&"drop")


class TouchStick extends Control:
	signal direction_changed(direction: Vector2)

	var _active_touch := -1
	var _direction := Vector2.ZERO
	var _center := Vector2.ZERO
	var _radius := 62.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_center = size * 0.5
		_radius = minf(size.x, size.y) * 0.36
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_center = size * 0.5
			_radius = minf(size.x, size.y) * 0.36
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and _active_touch == -1:
				_active_touch = event.index
				_update_direction(event.position)
				accept_event()
			elif not event.pressed and event.index == _active_touch:
				_active_touch = -1
				_direction = Vector2.ZERO
				direction_changed.emit(_direction)
				queue_redraw()
				accept_event()
		elif event is InputEventScreenDrag and event.index == _active_touch:
			_update_direction(event.position)
			accept_event()
		elif event is InputEventMouseButton:
			if event.pressed:
				_active_touch = 0
				_update_direction(event.position)
			elif _active_touch == 0:
				_active_touch = -1
				_direction = Vector2.ZERO
				direction_changed.emit(_direction)
				queue_redraw()
		elif event is InputEventMouseMotion and _active_touch == 0:
			_update_direction(event.position)

	func _update_direction(point: Vector2) -> void:
		_direction = ((point - _center) / _radius).limit_length(1.0)
		direction_changed.emit(_direction)
		queue_redraw()

	func _draw() -> void:
		draw_circle(_center, _radius, Color(0.02, 0.05, 0.08, 0.50))
		draw_arc(_center, _radius, 0.0, TAU, 48, Color(0.90, 0.63, 0.19, 0.65), 2.0)
		draw_circle(_center + _direction * (_radius * 0.52), _radius * 0.37, Color(0.90, 0.63, 0.19, 0.65))


class TouchLookPad extends Control:
	signal look_dragged(relative: Vector2)

	var _active_touches: Dictionary = {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed:
				_active_touches[event.index] = event.position
			else:
				_active_touches.erase(event.index)
		elif event is InputEventScreenDrag and _active_touches.has(event.index):
			look_dragged.emit(event.relative)
			_active_touches[event.index] = event.position
