extends CanvasLayer
class_name ParkourGameHUD

signal player_bound(player: Node3D)
signal contextual_prompt_changed(prompt: String)

@export var player_path: NodePath
@export var auto_find_player := true
@export var suppress_legacy_interface := true

@onready var health_widget := %HealthWidget as ParkourSmoothHealthBar
@onready var radar := %Radar as ParkourRadarHUD
@onready var map_overlay := %ExtendedMap as ParkourMapOverlay
@onready var prompt_panel := %ContextPromptPanel as PanelContainer
@onready var prompt_label := %ContextPrompt as Label

var player: Node3D
var _resolve_elapsed := 0.0
var _legacy_suppress_elapsed := 0.0
var _current_prompt := ""
var _manual_prompt := ""
var _manual_prompt_until_msec := -1
var _prompt_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("parkour_game_hud")
	prompt_panel.visible = false
	if player_path != NodePath():
		setup_player(get_node_or_null(player_path) as Node3D)
	elif player != null:
		setup_player(player)
	else:
		call_deferred("_resolve_player")
	if suppress_legacy_interface:
		call_deferred("_suppress_legacy_ui")


func _process(delta: float) -> void:
	if (
		auto_find_player
		and (player == null or not is_instance_valid(player))
	):
		_resolve_elapsed -= delta
		if _resolve_elapsed <= 0.0:
			_resolve_elapsed = 0.25
			_resolve_player()
	_update_context_prompt()
	if suppress_legacy_interface:
		_legacy_suppress_elapsed -= delta
		if _legacy_suppress_elapsed <= 0.0:
			_legacy_suppress_elapsed = 0.75
			_suppress_legacy_ui()


func setup_player(new_player: Node3D) -> void:
	if new_player == null:
		return
	if player != null and is_instance_valid(player):
		var callback := Callable(self, "_on_assassination_prompt_changed")
		if player.has_signal("assassination_opportunity_changed") and (
			player.is_connected(
				&"assassination_opportunity_changed",
				callback,
			)
		):
			player.disconnect(&"assassination_opportunity_changed", callback)
	player = new_player
	if not is_node_ready():
		return
	health_widget.bind_player(player)
	radar.setup_player(player)
	map_overlay.setup_player(player)
	if player.has_signal("assassination_opportunity_changed"):
		var callback := Callable(self, "_on_assassination_prompt_changed")
		if not player.is_connected(
			&"assassination_opportunity_changed",
			callback,
		):
			player.connect(&"assassination_opportunity_changed", callback)
	_update_context_prompt(true)
	player_bound.emit(player)


func show_context_prompt(text: String, duration := 0.0) -> void:
	_manual_prompt = text
	_manual_prompt_until_msec = (
		Time.get_ticks_msec() + roundi(duration * 1000.0)
		if duration > 0.0
		else -1
	)
	_update_context_prompt(true)


func clear_context_prompt() -> void:
	_manual_prompt = ""
	_manual_prompt_until_msec = -1
	_update_context_prompt(true)


func register_map_point(
	point_id: StringName,
	world_position: Vector3,
	point_type: StringName = &"poi",
	display_name := "",
	radius := 0.0,
) -> void:
	map_overlay.register_point(
		point_id,
		world_position,
		point_type,
		display_name,
		radius,
	)


func remove_map_point(point_id: StringName) -> void:
	map_overlay.remove_point(point_id)


func open_map() -> void:
	map_overlay.open_map()


func close_map() -> void:
	map_overlay.close_map()


func _resolve_player() -> void:
	if player != null and is_instance_valid(player):
		return
	if player_path != NodePath():
		var from_path := get_node_or_null(player_path) as Node3D
		if from_path != null:
			setup_player(from_path)
			return
	if auto_find_player:
		setup_player(
			get_tree().get_first_node_in_group("parkour_player") as Node3D,
		)


func _update_context_prompt(force := false) -> void:
	if (
		not _manual_prompt.is_empty()
		and _manual_prompt_until_msec >= 0
		and Time.get_ticks_msec() >= _manual_prompt_until_msec
	):
		_manual_prompt = ""
		_manual_prompt_until_msec = -1
	var next_prompt := _manual_prompt
	if next_prompt.is_empty():
		next_prompt = _read_player_prompt()
	if not force and next_prompt == _current_prompt:
		return
	_current_prompt = next_prompt
	contextual_prompt_changed.emit(_current_prompt)
	_animate_prompt(_current_prompt)


func _read_player_prompt() -> String:
	if player == null or not is_instance_valid(player):
		return ""
	if player.has_method("get_contextual_prompt"):
		return String(player.call("get_contextual_prompt"))
	if _has_property(player, &"contextual_prompt"):
		return String(player.get(&"contextual_prompt"))
	return ""


func _on_assassination_prompt_changed(
	available: bool,
	prompt_text: String,
	_target: Node,
) -> void:
	if _manual_prompt.is_empty():
		_animate_prompt(prompt_text if available else "")
		_current_prompt = prompt_text if available else ""


func _animate_prompt(text: String) -> void:
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if text.is_empty():
		if not prompt_panel.visible:
			return
		_prompt_tween = create_tween()
		_prompt_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_prompt_tween.tween_property(
			prompt_panel,
			"modulate:a",
			0.0,
			0.14,
		)
		_prompt_tween.tween_callback(
			func() -> void:
				prompt_panel.visible = false
		)
		return
	prompt_label.text = text
	prompt_panel.visible = true
	prompt_panel.modulate.a = 0.0
	_prompt_tween = create_tween()
	_prompt_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_prompt_tween.set_trans(Tween.TRANS_QUART)
	_prompt_tween.set_ease(Tween.EASE_OUT)
	_prompt_tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.18)


func _suppress_legacy_ui() -> void:
	var root := get_tree().root
	var legacy_interface := root.get_node_or_null("CronoParkourBazaar/Interface")
	if legacy_interface == null:
		legacy_interface = root.get_node_or_null("Interface")
	if legacy_interface is CanvasItem:
		(legacy_interface as CanvasItem).visible = false
	var legacy_radar := root.get_node_or_null("StealthHUD")
	if legacy_radar is CanvasLayer and legacy_radar != self:
		(legacy_radar as CanvasLayer).visible = false


func _has_property(source: Object, property_name: StringName) -> bool:
	for property: Dictionary in source.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
