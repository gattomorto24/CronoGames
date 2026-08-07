extends Control
class_name ParkourMapOverlay

signal map_opened
signal map_closed

@onready var map_canvas := %WorldMapCanvas as ParkourWorldMapCanvas

var player: Node3D
var _is_open := false
var _previous_tree_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("parkour_map_overlay")
	visible = false
	set_process_input(true)
	_ensure_map_action()
	if player != null:
		map_canvas.setup_player(player)


func _exit_tree() -> void:
	if _is_open and get_tree() != null:
		get_tree().paused = _previous_tree_paused


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("map"):
		if not _is_open and _pause_menu_is_open():
			return
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if _is_open and event.is_action_pressed("ui_cancel"):
		close_map()
		get_viewport().set_input_as_handled()


func setup_player(new_player: Node3D) -> void:
	player = new_player
	if is_node_ready():
		map_canvas.setup_player(player)


func toggle_map() -> void:
	if _is_open:
		close_map()
	else:
		open_map()


func open_map() -> void:
	if _is_open:
		return
	_is_open = true
	_previous_tree_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	map_opened.emit()


func close_map() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	get_tree().paused = _previous_tree_paused or _pause_menu_is_open()
	if not _pause_menu_is_open():
		Input.mouse_mode = _previous_mouse_mode
	map_closed.emit()


func is_open() -> bool:
	return _is_open


func register_point(
	point_id: StringName,
	world_position: Vector3,
	point_type: StringName = &"poi",
	display_name := "",
	radius := 0.0,
) -> void:
	map_canvas.register_point(
		point_id,
		world_position,
		point_type,
		display_name,
		radius,
	)


func remove_point(point_id: StringName) -> void:
	map_canvas.remove_point(point_id)


func clear_runtime_points() -> void:
	map_canvas.clear_runtime_points()


func _pause_menu_is_open() -> bool:
	for candidate: Node in get_tree().get_nodes_in_group(
		"parkour_pause_menu",
	):
		if candidate.has_method("is_open") and bool(candidate.call("is_open")):
			return true
	return false


func _ensure_map_action() -> void:
	if InputMap.has_action(&"map"):
		return
	InputMap.add_action(&"map", 0.2)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_M
	InputMap.action_add_event(&"map", key)
