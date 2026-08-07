extends Node
class_name ParkourUI

@export var player_path: NodePath

@onready var game_hud := %GameHUD as ParkourGameHUD
@onready var pause_menu := %PauseMenu as ParkourPauseMenu

var player: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("parkour_ui")
	if player_path != NodePath():
		setup_player(get_node_or_null(player_path) as Node3D)
	elif player != null:
		setup_player(player)
	else:
		call_deferred("_auto_bind_player")


func setup_player(new_player: Node3D) -> void:
	if new_player == null:
		return
	player = new_player
	if is_node_ready():
		game_hud.setup_player(player)


func show_context_prompt(text: String, duration := 0.0) -> void:
	game_hud.show_context_prompt(text, duration)


func clear_context_prompt() -> void:
	game_hud.clear_context_prompt()


func register_map_point(
	point_id: StringName,
	world_position: Vector3,
	point_type: StringName = &"poi",
	display_name := "",
	radius := 0.0,
) -> void:
	game_hud.register_map_point(
		point_id,
		world_position,
		point_type,
		display_name,
		radius,
	)


func _auto_bind_player() -> void:
	setup_player(
		get_tree().get_first_node_in_group("parkour_player") as Node3D,
	)
