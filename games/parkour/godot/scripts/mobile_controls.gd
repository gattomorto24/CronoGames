extends CanvasLayer

var pressed_actions: Dictionary = {}

func _ready() -> void:
	if not is_touch_layout():
		return
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	add_button(root, "←", "left", Vector2(26, -92), Vector2(62, 62))
	add_button(root, "↑", "forward", Vector2(94, -160), Vector2(62, 62))
	add_button(root, "→", "right", Vector2(162, -92), Vector2(62, 62))
	add_button(root, "↓", "backward", Vector2(94, -92), Vector2(62, 62))
	add_button(root, "SALTA", "go_up", Vector2(-116, -108), Vector2(92, 54), Control.PRESET_BOTTOM_RIGHT)
	add_button(root, "CORRI", "move_fast", Vector2(-116, -48), Vector2(92, 42), Control.PRESET_BOTTOM_RIGHT)

func add_button(root: Control, label: String, action: String, offset: Vector2, size: Vector2, preset := Control.PRESET_BOTTOM_LEFT) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = size
	button.set_anchors_preset(preset)
	button.position = offset
	button.size = size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 16 if label.length() == 1 else 11)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.17, 0.8)
	style.border_color = Color("74f1d0")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	button.add_theme_stylebox_override("normal", style)
	button.button_down.connect(press_action.bind(action))
	button.button_up.connect(release_action.bind(action))
	button.tree_exiting.connect(release_action.bind(action))
	root.add_child(button)

func press_action(action: String) -> void:
	pressed_actions[action] = true
	Input.action_press(action)

func release_action(action: String) -> void:
	pressed_actions.erase(action)
	Input.action_release(action)

func _exit_tree() -> void:
	for action in pressed_actions.keys():
		Input.action_release(action)

func is_touch_layout() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("window.matchMedia && window.matchMedia('(pointer: coarse)').matches", true))
	return false
