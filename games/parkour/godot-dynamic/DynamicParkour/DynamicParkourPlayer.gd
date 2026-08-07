extends CharacterBody3D
class_name DynamicParkourPlayer

signal action_changed(action_name: String)
signal stealth_changed(hidden: bool, sneaking: bool)
signal assassination_opportunity_changed(
	available: bool,
	prompt_text: String,
	target: Node,
)

enum State {
	LOCOMOTION,
	AIRBORNE,
	LANDING,
	SLIDE,
	VAULT,
	REACH,
	PREDICTED_JUMP,
	LEDGE_ENTRY,
	WALL_CLIMB,
	WALL_HOP,
	HANG_BRACED,
	HANG_FREE,
	LEDGE_HOP,
	CLIMB_UP,
	ZIPLINE,
	COMBAT_ATTACK,
	COMBAT_BLOCK,
	COMBAT_HIT,
	ASSASSINATION,
}

# Original Dynamic Parkour System tuning.
const WALK_SPEED := 3.0
const RUN_SPEED := 4.5
const SNEAK_SPEED := 2.15
const GROUND_ACCELERATION := 18.0
const AIR_CONTROL := 4.0
const GRAVITY := 22.0
const NORMAL_JUMP_SPEED := 6.15
const PREDICTED_HEIGHT := 1.25
const PREDICTED_DURATION := 0.70
const SLIDE_DISTANCE := 4.0
const SLIDE_DURATION := 1.05
const NORMAL_CAPSULE_HEIGHT := 1.75
const NORMAL_COLLIDER_Y := 0.875
const SLIDE_CAPSULE_HEIGHT := 0.82
const SLIDE_COLLIDER_Y := 0.41
const WALL_CLEARANCE := 0.31
const WALL_HOP_UP_DISTANCE := 0.68
const WALL_HOP_DOWN_DISTANCE := 0.48
const WALL_HOP_SIDE_DISTANCE := 0.46
const WALL_HOP_SETTLE_TIME := 0.10
const WALL_JUMP_HORIZONTAL_SPEED := 5.6
const WALL_JUMP_VERTICAL_SPEED := 4.4
const DIRECTIONAL_JUMP_SPEED := 4.35
const DIRECTIONAL_RUN_JUMP_SPEED := 5.25
const ZIPLINE_HAND_OFFSET := Vector3(0.0, -1.35, 0.0)
const COMBAT_ATTACK_ORDER := [
	"combat_attack_inward",
	"combat_attack_outward",
	"combat_attack_thrust",
]
const COMBAT_ATTACK_PROFILES := {
	"combat_attack_inward": {
		"damage": 28.0,
		"speed": 1.28,
		"min_duration": 0.54,
		"max_duration": 0.98,
		"hit_start": 0.30,
		"hit_end": 0.57,
		"combo_start": 0.66,
		"turn_end": 0.52,
		"lunge_speed": 2.25,
		"windup_drift": -0.22,
		"recovery_speed": 0.45,
		"acceleration": 20.0,
		"turn_speed": 4.2,
		"reach_padding": 0.52,
		"edge_width": 0.36,
		"max_distance": 3.05,
		"minimum_alignment": -0.18,
	},
	"combat_attack_outward": {
		"damage": 31.0,
		"speed": 1.22,
		"min_duration": 0.58,
		"max_duration": 1.06,
		"hit_start": 0.32,
		"hit_end": 0.62,
		"combo_start": 0.70,
		"turn_end": 0.48,
		"lunge_speed": 2.05,
		"windup_drift": -0.16,
		"recovery_speed": 0.35,
		"acceleration": 18.0,
		"turn_speed": 3.7,
		"reach_padding": 0.58,
		"edge_width": 0.38,
		"max_distance": 3.15,
		"minimum_alignment": -0.14,
	},
	"combat_attack_thrust": {
		"damage": 38.0,
		"speed": 1.34,
		"min_duration": 0.48,
		"max_duration": 0.88,
		"hit_start": 0.24,
		"hit_end": 0.48,
		"combo_start": 0.62,
		"turn_end": 0.64,
		"lunge_speed": 3.15,
		"windup_drift": -0.10,
		"recovery_speed": 0.75,
		"acceleration": 28.0,
		"turn_speed": 5.4,
		"reach_padding": 0.74,
		"edge_width": 0.18,
		"max_distance": 3.35,
		"minimum_alignment": 0.02,
	},
}

@onready var detector := $DetectionController as DynamicParkourDetectionController
@onready var animation_system := $AnimationController as DynamicParkourAnimationController
@onready var animation_player := $VisualPivot/Erika/AnimationPlayer as AnimationPlayer
@onready var visual_pivot := $VisualPivot as Node3D
@onready var collider := $Collider as CollisionShape3D
@onready var camera_rig := $CameraRig as Node3D
@onready var assassination_system: Node = $AssassinationController
@onready var air_assassination_detector := (
	$AirAssassinationDetector as Area3D
)
@onready var combat_weapon: DamageSource = (
	$VisualPivot/Erika/Skeleton3D/CombatSword
)
@onready var combat_health: HealthComponent = $CombatHealth

var current_action: String = "initializing"
var last_completed_action: String = ""
var action_history: PackedStringArray = []
var is_dynamic_parkour: bool = true
var is_hidden: bool = false
var is_sneaking: bool = false
var assassination_prompt_visible: bool = false
var assassination_prompt_text: String = ""
var assassination_prompt_target: Node
var assassination_prompt_mode: String = ""

var state: State = State.LOCOMOTION
var spawn_position := Vector3.ZERO
var action_start := Vector3.ZERO
var action_target := Vector3.ZERO
var action_direction := Vector3.FORWARD
var action_elapsed := 0.0
var action_duration := 1.0
var action_arc_height := 0.0
var ledge_top := Vector3.ZERO
var wall_normal := Vector3.ZERO
var hang_is_braced := true
var landing_elapsed := 0.0
var camera_yaw := 0.0
var camera_pitch := deg_to_rad(-13.0)
var mouse_captured := true
# Mobile input is intentionally kept separate from Godot's desktop InputMap.
# The touch layer feeds an analogue movement vector and camera deltas directly
# into the existing state machine, so parkour, ledges and combat still use the
# same controller rather than a second, simplified player.
var mobile_input_active := false
var mobile_move_input := Vector2.ZERO
var wall_climb_elapsed := 0.0
var wall_jump_capture_elapsed := 0.0
var wall_jump_capture_active := false
var intent_direction := Vector3.FORWARD
var edge_guard_active := false
var climbed_support_width := 1.0
var current_jump_variant := "jump_standing"
var jump_origin_action := ""
var wall_hop_cooldown := 0.0
var wall_hop_animation := "braced_hop_up"
var active_zipline: Node3D
var zipline_progress := 0.0
var zipline_speed := 0.0
var zipline_exit_window := 0.0
var assassination_target: Node
var assassination_mode := ""
var assassination_hit_applied := false
var combat_target: Node3D
var combat_attack_index := -1
var combat_attack_name := ""
var combat_attack_profile: Dictionary = {}
var combat_queued_attack := false
var combat_attack_requested := false
var combat_hit_done := false
var combat_invulnerable := false
var combat_hit_elapsed := 0.0
var combat_defeated := false
var combat_parry_window := 0.0
var _active_hiding_spots: Dictionary = {}
var _assassination_collision_suspended := false
var _opportunity_refresh_elapsed := 0.0


func _ready() -> void:
	add_to_group("parkour_player")
	_ensure_runtime_actions()
	spawn_position = global_position
	detector.setup(self)
	animation_system.setup(animation_player)
	camera_rig.top_level = true
	camera_rig.global_position = global_position + Vector3.UP * 1.42
	combat_weapon.entity = self
	combat_weapon.damage_attributes = DamageAttributes.new()
	combat_weapon.damage_attributes.health = 34.0
	combat_weapon.can_damage = false
	combat_health.zero_health.connect(_on_combat_health_depleted)
	_install_stealth_hud()
	if not mobile_input_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_state(State.LOCOMOTION, "idle", "idle")


func _unhandled_input(event: InputEvent) -> void:
	if mobile_input_active:
		return
	if event.is_action_released("mouse_mode_switch"):
		mouse_captured = not mouse_captured
		Input.mouse_mode = (
			Input.MOUSE_MODE_CAPTURED
			if mouse_captured
			else Input.MOUSE_MODE_VISIBLE
		)
	if event is InputEventMouseMotion and mouse_captured:
		camera_yaw -= event.relative.x * 0.0025
		camera_pitch = clampf(
			camera_pitch - event.relative.y * 0.0021,
			deg_to_rad(-52.0),
			deg_to_rad(24.0)
		)
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		combat_attack_requested = true


func _process(delta: float) -> void:
	var camera_target := global_position + Vector3.UP * 1.42
	camera_rig.global_position = camera_rig.global_position.lerp(
		camera_target,
		clampf(delta * 14.0, 0.0, 1.0)
	)
	camera_rig.global_rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	var visual_y_target := 0.0
	if _uses_procedural_vertical_motion():
		visual_y_target = -animation_system.vertical_root_offset()
	visual_pivot.position.y = lerpf(
		visual_pivot.position.y,
		visual_y_target,
		clampf(delta * 24.0, 0.0, 1.0)
	)
	var wall_sway := 0.0
	var wall_roll := 0.0
	if state in [State.WALL_CLIMB, State.WALL_HOP]:
		wall_sway = sin(wall_climb_elapsed * 7.4) * 0.022
		wall_roll = sin(wall_climb_elapsed * 7.4) * deg_to_rad(1.6)
	visual_pivot.position.x = lerpf(
		visual_pivot.position.x,
		wall_sway,
		clampf(delta * 12.0, 0.0, 1.0)
	)
	visual_pivot.rotation.z = lerpf(
		visual_pivot.rotation.z,
		wall_roll,
		clampf(delta * 10.0, 0.0, 1.0)
	)


func _physics_process(delta: float) -> void:
	_update_stealth_state()
	_opportunity_refresh_elapsed += delta
	if _opportunity_refresh_elapsed >= 0.08:
		_opportunity_refresh_elapsed = 0.0
		_refresh_assassination_opportunity()
	if Input.is_action_just_pressed("reset_player"):
		_reset_player()
	zipline_exit_window = maxf(zipline_exit_window - delta, 0.0)
	combat_parry_window = maxf(combat_parry_window - delta, 0.0)
	var attack_pressed := (
		combat_attack_requested
		or Input.is_action_just_pressed("attack")
	)
	var assassination_pressed := Input.is_action_just_pressed("assassinate")
	combat_attack_requested = false
	if attack_pressed and state == State.COMBAT_ATTACK:
		combat_queued_attack = true
	if (
		Input.is_action_just_pressed("block")
		and state == State.COMBAT_ATTACK
		and action_duration > 0.0
		and action_elapsed / action_duration >= 0.62
	):
		_begin_combat_block()
		return
	if (
		Input.is_action_just_pressed("block")
		and state in [State.LOCOMOTION, State.LANDING]
	):
		_begin_combat_block()
		return
	if (
		assassination_pressed
		and state not in [
			State.ASSASSINATION,
			State.COMBAT_ATTACK,
			State.COMBAT_BLOCK,
			State.COMBAT_HIT,
		]
	):
		if _try_begin_assassination():
			return
	if (
		attack_pressed
		and state not in [
			State.ASSASSINATION,
			State.COMBAT_ATTACK,
			State.COMBAT_BLOCK,
			State.COMBAT_HIT,
		]
	):
		if _try_begin_melee_attack():
			return

	match state:
		State.LOCOMOTION:
			_update_locomotion(delta)
		State.AIRBORNE:
			_update_airborne(delta)
		State.LANDING:
			_update_landing(delta)
		State.SLIDE:
			_update_slide(delta)
		State.VAULT, State.REACH, State.PREDICTED_JUMP:
			_update_arc_action(delta)
		State.LEDGE_ENTRY:
			_update_ledge_entry(delta)
		State.WALL_CLIMB:
			_update_wall_climb(delta)
		State.WALL_HOP:
			_update_wall_hop(delta)
		State.HANG_BRACED, State.HANG_FREE:
			_update_hang(delta)
		State.LEDGE_HOP:
			_update_ledge_hop(delta)
		State.CLIMB_UP:
			_update_climb_up(delta)
		State.ZIPLINE:
			_update_zipline(delta)
		State.COMBAT_ATTACK:
			_update_melee_attack(delta)
		State.COMBAT_BLOCK:
			_update_combat_block(delta)
		State.COMBAT_HIT:
			_update_combat_hit(delta)
		State.ASSASSINATION:
			_update_assassination(delta)


func has_performed(action_name: String) -> bool:
	return action_history.has(action_name)


func _install_stealth_hud() -> void:
	var root := get_tree().root
	if root.has_node("StealthHUD"):
		return
	var layer := CanvasLayer.new()
	layer.name = "StealthHUD"
	layer.layer = 32
	var minimap := preload("res://scripts/ui/parkour_minimap.gd").new()
	minimap.name = "StealthMinimap"
	minimap.player_path = get_path()
	layer.add_child(minimap)
	root.add_child.call_deferred(layer)


func _ensure_runtime_actions() -> void:
	for action_name in [&"attack", &"assassinate"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.22)
	_ensure_key_action(&"assassinate", KEY_F)
	_ensure_key_action(&"sneak", KEY_C)


func _ensure_key_action(
	action_name: StringName,
	physical_keycode: Key,
) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.22)
	for event in InputMap.action_get_events(action_name):
		if (
			event is InputEventKey
			and (event as InputEventKey).physical_keycode
			== physical_keycode
		):
			return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, key_event)


func enter_hiding_spot(hiding_spot: Area3D) -> void:
	if hiding_spot == null or not is_instance_valid(hiding_spot):
		return
	_active_hiding_spots[hiding_spot.get_instance_id()] = weakref(
		hiding_spot
	)
	_update_stealth_state()


func exit_hiding_spot(hiding_spot: Area3D) -> void:
	if hiding_spot == null:
		return
	_active_hiding_spots.erase(hiding_spot.get_instance_id())
	_update_stealth_state()


func get_active_hiding_spots() -> Array[Area3D]:
	_prune_hiding_spots()
	var spots: Array[Area3D] = []
	for spot_reference: WeakRef in _active_hiding_spots.values():
		var spot := spot_reference.get_ref() as Area3D
		if spot != null:
			spots.append(spot)
	return spots


func get_assassination_opportunity() -> Dictionary:
	if state in [
		State.ASSASSINATION,
		State.COMBAT_ATTACK,
		State.COMBAT_BLOCK,
		State.COMBAT_HIT,
	]:
		return {}
	return assassination_system.call(
		"find_best_target",
		self,
		_assassination_mode_hint(),
		false,
	)


func get_contextual_prompt() -> String:
	return (
		"Premi [F] per Assassinare"
		if assassination_prompt_visible
		else ""
	)


func get_contextual_assassination_data() -> Dictionary:
	if not assassination_prompt_visible:
		return {}
	return {
		"available": true,
		"prompt": get_contextual_prompt(),
		"target": assassination_prompt_target,
		"mode": assassination_prompt_mode,
	}


func _update_stealth_state() -> void:
	_prune_hiding_spots()
	var hidden_now := not _active_hiding_spots.is_empty()
	var sneaking_now := (
		hidden_now
		or Input.is_action_pressed("sneak")
	)
	if hidden_now == is_hidden and sneaking_now == is_sneaking:
		return
	is_hidden = hidden_now
	is_sneaking = sneaking_now
	stealth_changed.emit(is_hidden, is_sneaking)


func _prune_hiding_spots() -> void:
	var expired_ids: Array[int] = []
	for instance_id: int in _active_hiding_spots:
		var spot_reference := _active_hiding_spots[instance_id] as WeakRef
		if (
			spot_reference == null
			or spot_reference.get_ref() == null
		):
			expired_ids.append(instance_id)
	for instance_id in expired_ids:
		_active_hiding_spots.erase(instance_id)


func _refresh_assassination_opportunity() -> void:
	var opportunity := get_assassination_opportunity()
	var target: Node
	var prompt := ""
	var contextual_mode := ""
	if not opportunity.is_empty():
		target = opportunity.get("target") as Node
		var mode := String(opportunity.get("mode", ""))
		contextual_mode = mode
		prompt = (
			"Premi [F] per Assassinare (aereo)"
			if mode in [
				"aerial_assassination",
				"jump_assassination",
				"zipline_assassination",
			]
			else "Premi [F] per Assassinare"
		)
	var available := target != null
	if (
		available == assassination_prompt_visible
		and prompt == assassination_prompt_text
		and target == assassination_prompt_target
		and contextual_mode == assassination_prompt_mode
	):
		return
	assassination_prompt_visible = available
	assassination_prompt_text = prompt
	assassination_prompt_target = target
	assassination_prompt_mode = contextual_mode
	assassination_opportunity_changed.emit(available, prompt, target)


func set_mobile_input_enabled(enabled: bool) -> void:
	mobile_input_active = enabled
	mobile_move_input = Vector2.ZERO
	if enabled:
		mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_mobile_move_input(input_vector: Vector2) -> void:
	# A small dead zone keeps the runner still when a thumb is released.
	mobile_move_input = input_vector.limit_length(1.0)
	if mobile_move_input.length() < 0.08:
		mobile_move_input = Vector2.ZERO


func add_mobile_camera_look(look_delta: Vector2) -> void:
	if not mobile_input_active:
		return
	camera_yaw -= look_delta.x * 0.0042
	camera_pitch = clampf(
		camera_pitch - look_delta.y * 0.0034,
		deg_to_rad(-52.0),
		deg_to_rad(24.0)
	)


func request_mobile_attack() -> void:
	combat_attack_requested = true


func get_bone_world_position(bone_name: StringName) -> Vector3:
	var skeleton := $VisualPivot/Erika/Skeleton3D as Skeleton3D
	var bone_index := skeleton.find_bone(bone_name)
	if bone_index < 0:
		return global_position
	return skeleton.to_global(
		skeleton.get_bone_global_pose(bone_index).origin
	)


func _update_locomotion(delta: float) -> void:
	var input_vector := _movement_input()
	var movement_direction := _camera_relative_direction(input_vector)
	var wants_run := (
		Input.is_action_pressed("move_fast")
		and not is_sneaking
		and input_vector.length() > 0.5
	)
	var speed := (
		SNEAK_SPEED
		if is_sneaking
		else RUN_SPEED if wants_run else WALK_SPEED
	)

	if movement_direction != Vector3.ZERO:
		_face_direction(movement_direction, delta)
		velocity.x = move_toward(
			velocity.x,
			movement_direction.x * speed,
			GROUND_ACCELERATION * delta
		)
		velocity.z = move_toward(
			velocity.z,
			movement_direction.z * speed,
			GROUND_ACCELERATION * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			GROUND_ACCELERATION * 1.35 * delta
		)
		velocity.z = move_toward(
			velocity.z,
			0.0,
			GROUND_ACCELERATION * 1.35 * delta
		)

	var support_is_close := detector.has_walkable_support(
		global_position,
		0.34
	)
	if not is_on_floor() and not support_is_close:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.35

	var intended_direction := (
		movement_direction
		if movement_direction != Vector3.ZERO
		else _forward()
	)

	if (
		Input.is_action_just_pressed("drop")
		and Vector2(velocity.x, velocity.z).length() > 2.2
	):
		_begin_slide(intended_direction)
		return

	if Input.is_action_just_pressed("go_up"):
		intent_direction = intended_direction.normalized()
		if _try_capture_zipline():
			return
		if _try_contextual_parkour(intended_direction):
			return
		_begin_directional_jump(intended_direction, wants_run)
		move_and_slide()
		return

	var edge_blocked := _apply_edge_guard(movement_direction, delta)
	if not edge_blocked:
		var locomotion_animation := "idle"
		if movement_direction != Vector3.ZERO:
			locomotion_animation = "run" if wants_run else "walk"
		_set_locomotion_animation(locomotion_animation)

	move_and_slide()
	if not is_on_floor() and velocity.y < -0.7:
		_set_state(State.AIRBORNE, "fall", "fall")


func _try_contextual_parkour(direction: Vector3) -> bool:
	# Preserve the exact original priority: obstacle, deep vault, reach,
	# climbable ledge, predicted landing, then the regular jump fallback.
	var obstacle := detector.detect_obstacle(direction)
	if not obstacle.is_empty():
		var obstacle_height: float = obstacle["height"]
		if obstacle_height <= 1.05:
			_begin_vault(direction, obstacle)
			return true
		if obstacle_height <= 2.02:
			_begin_reach(direction, obstacle)
			return true

	var ledge := detector.detect_ledge(direction)
	if not ledge.is_empty():
		_begin_ledge_entry(ledge)
		return true

	var climb_wall := detector.detect_climb_wall(direction)
	if not climb_wall.is_empty():
		_begin_wall_climb(climb_wall)
		return true

	var predicted := detector.find_predicted_landing(direction)
	if not predicted.is_empty():
		_begin_predicted_jump(direction, predicted)
		return true
	return false


func _begin_directional_jump(direction: Vector3, running: bool) -> void:
	var jump_direction := direction.normalized()
	if jump_direction == Vector3.ZERO:
		jump_direction = _forward()
	var current_horizontal_speed := Vector2(
		velocity.x,
		velocity.z
	).length()
	var estimated_distance := maxf(
		1.0,
		current_horizontal_speed * 0.62
	)
	var ground_ahead := detector.ground_below(
		global_position + jump_direction * estimated_distance,
		3.4
	)
	var height_delta := 0.0
	if not ground_ahead.is_empty():
		height_delta = (
			(ground_ahead["position"] as Vector3).y
			- global_position.y
		)
	var profile := _select_jump_profile(
		estimated_distance,
		height_delta,
		current_horizontal_speed,
		_forward().dot(jump_direction),
		"running" if running else "free"
	)
	var directed_speed: float = profile["horizontal_speed"]
	directed_speed = maxf(directed_speed, current_horizontal_speed)
	velocity.x = jump_direction.x * directed_speed
	velocity.z = jump_direction.z * directed_speed
	velocity.y = profile["vertical_speed"]
	action_direction = jump_direction
	intent_direction = jump_direction
	_face_direction_immediate(jump_direction)
	current_jump_variant = profile["animation"]
	jump_origin_action = profile["action"]
	_set_state(
		State.AIRBORNE,
		profile["action"],
		profile["animation"],
		float(profile["speed"]),
		true,
		float(profile["blend"])
	)


func _select_jump_profile(
	distance: float,
	height_delta: float,
	horizontal_speed: float,
	direction_alignment: float,
	context: String,
) -> Dictionary:
	var profile := {
		"action": "jump_medium",
		"animation": "jump_medium",
		"horizontal_speed": DIRECTIONAL_JUMP_SPEED,
		"vertical_speed": NORMAL_JUMP_SPEED,
		"duration": 0.66,
		"arc": 1.0,
		"speed": 1.0,
		"blend": 0.07,
	}
	if context == "wall":
		profile.merge({
			"action": "jump_between_walls",
			"animation": "jump_wall_surface",
			"horizontal_speed": WALL_JUMP_HORIZONTAL_SPEED,
			"vertical_speed": WALL_JUMP_VERTICAL_SPEED,
			"duration": 0.52,
			"arc": 0.58,
			"speed": 1.06,
		}, true)
	elif context == "grip":
		profile.merge({
			"action": "jump_to_upper_grip",
			"animation": "jump_to_grip",
			"horizontal_speed": 3.8,
			"vertical_speed": 6.4,
			"duration": 0.56,
			"arc": 0.72,
			"speed": 1.08,
		}, true)
	elif context == "climb_exit":
		profile.merge({
			"action": "jump_climb_exit",
			"animation": "jump_climb_exit",
			"horizontal_speed": 2.8,
			"vertical_speed": 4.8,
			"duration": 0.72,
			"arc": 0.34,
		}, true)
	elif height_delta > 0.62:
		profile.merge({
			"action": "jump_up",
			"animation": "jump_up",
			"horizontal_speed": 3.7,
			"vertical_speed": 6.85,
			"duration": 0.70,
			"arc": maxf(0.85, height_delta * 0.72),
			"speed": 1.05,
		}, true)
	elif height_delta < -0.78:
		profile.merge({
			"action": "jump_down",
			"animation": "jump_downward",
			"horizontal_speed": 4.65,
			"vertical_speed": 4.55,
			"duration": 0.68,
			"arc": 0.72,
			"speed": 1.03,
		}, true)
	elif horizontal_speed < 0.72 and distance < 1.7:
		profile.merge({
			"action": "jump_from_standstill",
			"animation": "jump_standing",
			"horizontal_speed": 2.25,
			"vertical_speed": 5.72,
			"duration": 0.58,
			"arc": 0.74,
			"speed": 1.06,
		}, true)
	elif distance < 1.72:
		profile.merge({
			"action": "jump_short",
			"animation": "jump_short",
			"horizontal_speed": 3.35,
			"vertical_speed": 5.5,
			"duration": 0.54,
			"arc": 0.68,
			"speed": 1.08,
		}, true)
	elif distance > 3.35 or horizontal_speed > 4.25:
		profile.merge({
			"action": (
				"jump_running"
				if context == "running" and distance < 3.8
				else "jump_long"
			),
			"animation": (
				"jump_running"
				if context == "running" and distance < 3.8
				else "jump_long"
			),
			"horizontal_speed": DIRECTIONAL_RUN_JUMP_SPEED,
			"vertical_speed": 6.35,
			"duration": 0.74,
			"arc": 1.22,
			"speed": 1.0,
		}, true)
	elif context == "running":
		profile.merge({
			"action": "jump_running",
			"animation": "jump_running",
			"horizontal_speed": DIRECTIONAL_RUN_JUMP_SPEED,
			"vertical_speed": 6.18,
			"duration": 0.64,
			"arc": 1.0,
			"speed": 1.06,
		}, true)
	if direction_alignment < 0.15:
		profile["horizontal_speed"] = (
			float(profile["horizontal_speed"]) * 0.88
		)
		profile["speed"] = float(profile["speed"]) * 1.05
	return profile


func _update_airborne(delta: float) -> void:
	var input_vector := _movement_input()
	var movement_direction := _camera_relative_direction(input_vector)
	if movement_direction != Vector3.ZERO:
		intent_direction = movement_direction
	if movement_direction != Vector3.ZERO and not wall_jump_capture_active:
		_face_direction(movement_direction, delta * 0.55)
		velocity.x = move_toward(
			velocity.x,
			movement_direction.x * RUN_SPEED,
			AIR_CONTROL * delta
		)
		velocity.z = move_toward(
			velocity.z,
			movement_direction.z * RUN_SPEED,
			AIR_CONTROL * delta
		)

	velocity.y -= GRAVITY * delta
	if Input.is_action_pressed("go_up") and _try_capture_zipline():
		return
	if wall_jump_capture_active:
		wall_jump_capture_elapsed += delta
		if wall_jump_capture_elapsed >= 0.10:
			var travel_direction := Vector3(velocity.x, 0.0, velocity.z)
			if travel_direction.length_squared() < 0.04:
				travel_direction = wall_normal
			travel_direction = travel_direction.normalized()
			var opposite_ledge := detector.detect_ledge(
				travel_direction,
				0.34,
				2.65
			)
			if not opposite_ledge.is_empty():
				_begin_ledge_entry(opposite_ledge)
				return
			var opposite_wall := detector.detect_climb_wall(
				travel_direction,
				0.82
			)
			if not opposite_wall.is_empty():
				_begin_wall_climb(opposite_wall)
				return
		if wall_jump_capture_elapsed > 1.05:
			wall_jump_capture_active = false

	if Input.is_action_pressed("go_up") and velocity.y <= 1.8:
		var airborne_intent := intent_direction
		if airborne_intent == Vector3.ZERO:
			airborne_intent = Vector3(velocity.x, 0.0, velocity.z)
		if airborne_intent == Vector3.ZERO:
			airborne_intent = _forward()
		airborne_intent = airborne_intent.normalized()
		var ledge := detector.detect_ledge(
			airborne_intent,
			0.34,
			2.80
		)
		if not ledge.is_empty():
			_begin_ledge_entry(ledge)
			return
		var climb_wall := detector.detect_climb_wall(
			airborne_intent,
			0.78
		)
		if not climb_wall.is_empty():
			_begin_wall_climb(climb_wall)
			return

	move_and_slide()
	if is_on_floor():
		velocity.y = -0.35
		landing_elapsed = 0.0
		var landing_speed := Vector2(velocity.x, velocity.z).length()
		_set_state(
			State.LANDING,
			"landing",
			"land_to_run" if landing_speed > 2.1 else "landing",
			clampf(0.96 + landing_speed * 0.025, 0.96, 1.10),
			true
		)
	elif current_action != "fall" and velocity.y < -0.4:
		_record_action("fall")
		animation_system.play("fall")


func _update_landing(delta: float) -> void:
	landing_elapsed += delta
	var movement_direction := _camera_relative_direction(_movement_input())
	var has_runout := movement_direction != Vector3.ZERO
	var target_speed := RUN_SPEED if Input.is_action_pressed("move_fast") else WALK_SPEED
	var target_velocity := movement_direction * target_speed
	velocity.x = move_toward(
		velocity.x,
		target_velocity.x if has_runout else 0.0,
		(7.0 if has_runout else 4.2) * delta
	)
	velocity.z = move_toward(
		velocity.z,
		target_velocity.z if has_runout else 0.0,
		(7.0 if has_runout else 4.2) * delta
	)
	velocity.y = -0.35
	move_and_slide()
	if landing_elapsed >= (0.13 if has_runout else 0.24):
		_complete_action("landing")
		_set_state(
			State.LOCOMOTION,
			"run" if has_runout else "idle",
			"run" if has_runout else "idle",
			1.0,
			true
		)


func _begin_slide(direction: Vector3) -> void:
	action_direction = direction.normalized()
	action_start = global_position
	action_target = action_start + action_direction * SLIDE_DISTANCE
	action_elapsed = 0.0
	action_duration = SLIDE_DURATION
	action_arc_height = 0.0
	_face_direction_immediate(action_direction)
	_set_collider_sliding(true)
	velocity = Vector3.ZERO
	_set_state(State.SLIDE, "slide", "slide", 1.18, true)


func _update_slide(delta: float) -> void:
	action_elapsed += delta
	var t := clampf(action_elapsed / action_duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 2.35)
	global_position = action_start.lerp(action_target, eased)
	velocity = Vector3.ZERO
	if t >= 1.0:
		_set_collider_sliding(false)
		_complete_action("slide")
		_set_state(
			State.LOCOMOTION,
			"crouch_to_stand",
			"crouch_to_stand",
			1.0,
			true
		)


func _begin_vault(direction: Vector3, obstacle: Dictionary) -> void:
	var landing: Dictionary = obstacle["landing"]
	var target := global_position + direction.normalized() * 2.05
	if not landing.is_empty():
		target = landing["position"] + Vector3.UP * 0.04
	var distance := global_position.distance_to(target)
	var deep_vault := distance > 2.25
	var profile := _select_jump_profile(
		distance,
		target.y - global_position.y,
		Vector2(velocity.x, velocity.z).length(),
		_forward().dot(direction.normalized()),
		"running"
	)
	current_jump_variant = (
		profile["animation"] if deep_vault else "jump_short"
	)
	_begin_arc_action(
		State.VAULT,
		"deep_vault" if deep_vault else "vault",
		profile["animation"] if deep_vault else "vault",
		target,
		0.85 if deep_vault else 0.76,
		1.08 if deep_vault else 0.72,
		0.07
	)


func _begin_reach(direction: Vector3, obstacle: Dictionary) -> void:
	var top: Dictionary = obstacle["top"]
	var target: Vector3 = top["position"]
	target += direction.normalized() * 0.48
	target.y += 0.04
	var height: float = obstacle["height"]
	var profile := _select_jump_profile(
		global_position.distance_to(target),
		target.y - global_position.y,
		Vector2(velocity.x, velocity.z).length(),
		_forward().dot(direction.normalized()),
		"grip" if height > 1.15 else "free"
	)
	current_jump_variant = profile["animation"]
	_begin_arc_action(
		State.REACH,
		"reach_high" if height > 1.15 else "step_up",
		profile["animation"] if height > 1.15 else "step_up",
		target,
		0.92 if height > 1.15 else 0.66,
		0.42 if height > 1.15 else 0.24,
		0.06
	)


func _begin_predicted_jump(
	direction: Vector3,
	landing: Dictionary,
) -> void:
	var target: Vector3 = landing["position"] + Vector3.UP * 0.045
	var distance := global_position.distance_to(target)
	var profile := _select_jump_profile(
		distance,
		target.y - global_position.y,
		Vector2(velocity.x, velocity.z).length(),
		_forward().dot(direction.normalized()),
		"running"
	)
	current_jump_variant = profile["animation"]
	jump_origin_action = profile["action"]
	_begin_arc_action(
		State.PREDICTED_JUMP,
		profile["action"],
		profile["animation"],
		target,
		clampf(
			float(profile["duration"]) + distance * 0.035,
			0.56,
			0.84
		),
		maxf(float(profile["arc"]), PREDICTED_HEIGHT),
		float(profile["blend"])
	)
	action_direction = direction.normalized()


func _begin_arc_action(
	next_state: State,
	action_name: String,
	animation_name: String,
	target: Vector3,
	duration: float,
	arc_height: float,
	blend_time: float = 0.08,
) -> void:
	state = next_state
	action_start = global_position
	action_target = target
	action_direction = (target - action_start)
	action_direction.y = 0.0
	if action_direction != Vector3.ZERO:
		action_direction = action_direction.normalized()
		_face_direction_immediate(action_direction)
	action_elapsed = 0.0
	action_duration = maxf(duration, 0.1)
	action_arc_height = arc_height
	velocity = Vector3.ZERO
	_record_action(action_name)
	animation_system.play(animation_name, blend_time, 1.0, true)


func _update_arc_action(delta: float) -> void:
	action_elapsed += delta
	var t := clampf(action_elapsed / action_duration, 0.0, 1.0)
	var position := action_start.lerp(action_target, t)
	position.y += 4.0 * action_arc_height * t * (1.0 - t)
	global_position = position
	velocity = Vector3.ZERO
	if t >= 1.0:
		_complete_action(current_action)
		landing_elapsed = 0.0
		var carries_momentum := _movement_input() != Vector2.ZERO
		velocity = (
			action_direction * (RUN_SPEED if carries_momentum else 1.4)
			+ Vector3.DOWN * 0.35
		)
		_set_state(
			State.LANDING,
			"landing",
			"land_to_run" if carries_momentum else "landing",
			1.05,
			true
		)


func _begin_ledge_entry(ledge: Dictionary) -> void:
	wall_jump_capture_active = false
	wall_normal = (ledge["normal"] as Vector3).normalized()
	ledge_top = ledge["top"]["position"]
	hang_is_braced = ledge["braced"]
	var edge_position: Vector3 = ledge.get(
		"edge",
		ledge_top + wall_normal * 0.18
	)
	var target: Vector3 = edge_position + wall_normal * (
		0.31 if hang_is_braced else 0.20
	)
	target.y = ledge_top.y - (1.62 if hang_is_braced else 1.80)
	action_start = global_position
	action_target = target
	action_elapsed = 0.0
	action_duration = 0.56
	velocity = Vector3.ZERO
	_face_direction_immediate(-wall_normal)
	current_jump_variant = "jump_to_grip"
	jump_origin_action = "jump_to_upper_grip"
	_set_state(
		State.LEDGE_ENTRY,
		"jump_to_upper_grip",
		"jump_to_grip" if hang_is_braced else "free_enter",
		1.06,
		true
	)


func _update_ledge_entry(delta: float) -> void:
	action_elapsed += delta
	var t := clampf(action_elapsed / action_duration, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	global_position = action_start.lerp(action_target, eased)
	velocity = Vector3.ZERO
	if t >= 1.0:
		_complete_action(current_action)
		if hang_is_braced:
			_set_state(
				State.HANG_BRACED,
				"braced_hang",
				"braced_idle",
				1.0,
				true
			)
		else:
			_set_state(
				State.HANG_FREE,
				"free_hang",
				"free_idle",
				1.0,
				true
			)


func _begin_wall_climb(wall_hit: Dictionary) -> void:
	wall_jump_capture_active = false
	wall_normal = (wall_hit["normal"] as Vector3).normalized()
	var contact: Vector3 = wall_hit["position"]
	var anchor := contact + wall_normal * WALL_CLEARANCE
	anchor.y = global_position.y
	global_position = global_position.move_toward(anchor, 0.56)
	velocity = Vector3.ZERO
	wall_climb_elapsed = 0.0
	wall_hop_cooldown = WALL_HOP_SETTLE_TIME
	_face_direction_immediate(-wall_normal)
	_set_state(
		State.WALL_CLIMB,
		"wall_grip",
		"jump_to_grip",
		1.08,
		true
	)


func _update_wall_climb(delta: float) -> void:
	wall_climb_elapsed += delta
	wall_hop_cooldown = maxf(wall_hop_cooldown - delta, 0.0)
	velocity = Vector3.ZERO
	if Input.is_action_just_pressed("drop"):
		_drop_from_ledge()
		return

	var input_vector := _movement_input()
	if (
		Input.is_action_just_pressed("go_up")
		and input_vector.y > 0.45
		and wall_climb_elapsed > 0.16
	):
		_jump_from_wall()
		return

	var wall_hit := detector.wall_hit_at(
		global_position,
		wall_normal,
		1.08,
		0.92
	)
	if wall_hit.is_empty():
		wall_hit = detector.detect_climb_wall(-wall_normal, 1.02)
	if wall_hit.is_empty():
		var last_ledge := detector.detect_ledge(
			-wall_normal,
			0.24,
			2.25
		)
		if not last_ledge.is_empty():
			_begin_ledge_entry(last_ledge)
		else:
			_drop_from_ledge()
		return

	var sensed_normal: Vector3 = wall_hit["normal"]
	wall_normal = wall_normal.slerp(
		sensed_normal.normalized(),
		clampf(delta * 10.0, 0.0, 1.0)
	).normalized()
	_face_direction_immediate(-wall_normal)

	var contact: Vector3 = wall_hit["position"]
	var wall_clearance := _wall_climb_clearance(contact)
	var wall_anchor := contact + wall_normal * wall_clearance
	global_position.x = lerpf(
		global_position.x,
		wall_anchor.x,
		clampf(delta * 15.0, 0.0, 1.0)
	)
	global_position.z = lerpf(
		global_position.z,
		wall_anchor.z,
		clampf(delta * 15.0, 0.0, 1.0)
	)
	if wall_climb_elapsed < 0.16:
		return

	var ledge := detector.detect_ledge(-wall_normal, 0.34, 2.25)
	if (
		not ledge.is_empty()
		and (
			Input.is_action_pressed("go_up")
			or input_vector.y < -0.12
		)
	):
		_begin_ledge_entry(ledge)
		return

	if wall_hop_cooldown <= 0.0:
		var requests_hop := (
			Input.is_action_pressed("go_up")
			or absf(input_vector.x) > 0.42
			or input_vector.y > 0.52
		)
		if requests_hop:
			_begin_wall_hop(input_vector)
			return
	animation_system.play("wall_climb", 0.12)


func _begin_wall_hop(input_vector: Vector2) -> void:
	var vertical_delta := WALL_HOP_UP_DISTANCE
	if input_vector.y > 0.42:
		vertical_delta = -WALL_HOP_DOWN_DISTANCE
	var lateral_delta := input_vector.x * WALL_HOP_SIDE_DISTANCE
	if absf(input_vector.x) > 0.28 and absf(input_vector.y) < 0.28:
		vertical_delta = 0.12

	var next_grip := detector.find_logical_grip(
		global_position,
		wall_normal,
		vertical_delta,
		lateral_delta
	)
	if next_grip.is_empty():
		if vertical_delta > 0.0:
			var top_ledge := detector.detect_ledge(
				-wall_normal,
				0.24,
				2.45
			)
			if not top_ledge.is_empty():
				_begin_ledge_entry(top_ledge)
		else:
			animation_system.play("wall_climb", 0.08)
		return

	var next_normal := (next_grip["normal"] as Vector3).normalized()
	if next_normal.dot(wall_normal) < 0.72:
		return
	wall_normal = next_normal
	var contact: Vector3 = next_grip["contact"]
	var candidate: Vector3 = next_grip["position"]
	action_start = global_position
	action_target = contact + wall_normal * WALL_CLEARANCE
	action_target.y = candidate.y
	action_elapsed = 0.0
	action_duration = (
		0.43
		if absf(lateral_delta) > 0.08
		else 0.49
	)
	action_arc_height = 0.07
	state = State.WALL_HOP
	current_jump_variant = (
		"jump_up" if vertical_delta > 0.18 else "jump_downward"
	)
	if vertical_delta < -0.08:
		wall_hop_animation = "braced_hop_down"
	elif absf(lateral_delta) > 0.08:
		wall_hop_animation = "braced_hop_right"
	else:
		wall_hop_animation = "braced_hop_up"
	var action_name := "wall_hop_up"
	if vertical_delta < -0.08:
		action_name = "wall_hop_down"
	elif absf(lateral_delta) > 0.08:
		action_name = "wall_hop_diagonal"
	_record_action(action_name)
	animation_system.play(
		wall_hop_animation,
		0.055,
		1.10 if lateral_delta >= 0.0 else -1.10,
		true
	)


func _update_wall_hop(delta: float) -> void:
	action_elapsed += delta
	var t := clampf(action_elapsed / action_duration, 0.0, 1.0)
	if t < 0.17:
		var load_t := t / 0.17
		global_position = (
			action_start
			+ Vector3.DOWN * sin(load_t * PI) * 0.055
			- wall_normal * sin(load_t * PI) * 0.018
		)
	elif t < 0.86:
		var flight_t := (t - 0.17) / 0.69
		var eased := flight_t * flight_t * (3.0 - 2.0 * flight_t)
		global_position = action_start.lerp(action_target, eased)
		global_position += (
			wall_normal * sin(flight_t * PI) * 0.065
			+ Vector3.UP * sin(flight_t * PI) * action_arc_height
		)
	else:
		var catch_t := (t - 0.86) / 0.14
		global_position = action_target + (
			wall_normal * sin(catch_t * PI) * 0.022
			+ Vector3.DOWN * sin(catch_t * PI) * 0.028
		)
	velocity = Vector3.ZERO
	_face_direction_immediate(-wall_normal)
	if t >= 1.0:
		global_position = action_target
		_complete_action(current_action)
		state = State.WALL_CLIMB
		wall_climb_elapsed = 0.0
		wall_hop_cooldown = WALL_HOP_SETTLE_TIME
		_record_action("wall_grip")
		animation_system.play("wall_climb", 0.07, 1.0, true)


func _wall_climb_clearance(contact: Vector3) -> float:
	if wall_climb_elapsed < 0.12:
		return WALL_CLEARANCE
	var left_hand := get_bone_world_position(&"LeftHand")
	var right_hand := get_bone_world_position(&"RightHand")
	var hand_midpoint := (left_hand + right_hand) * 0.5
	var hand_depth := (hand_midpoint - contact).dot(wall_normal)
	var player_depth := (global_position - contact).dot(wall_normal)
	# Keep a small palm/knuckle clearance because the animated pose advances
	# between the physics alignment pass and the rendered frame.
	var required_shift := 0.07 - hand_depth
	return clampf(
		player_depth + required_shift,
		WALL_CLEARANCE,
		0.68
	)


func _update_hang(delta: float) -> void:
	velocity = Vector3.ZERO
	if Input.is_action_just_pressed("drop"):
		_drop_from_ledge()
		return

	var input_vector := _movement_input()
	if Input.is_action_just_pressed("go_up"):
		if input_vector.y > 0.45:
			_jump_from_wall()
			return
		if absf(input_vector.x) > 0.45:
			_begin_ledge_hop(signf(input_vector.x))
			return
		_begin_climb_up()
		return

	var lateral := input_vector.x
	if absf(lateral) > 0.08:
		var tangent := Vector3.UP.cross(wall_normal).normalized()
		var candidate := global_position + tangent * lateral * 1.08 * delta
		if detector.wall_available_at(candidate, wall_normal, 1.55):
			global_position = candidate
			var top := detector.top_surface_near(
				global_position,
				wall_normal
			)
			if not top.is_empty():
				ledge_top = top["position"]
			animation_system.play(
				"braced_shimmy" if hang_is_braced else "free_shimmy",
				0.12,
				1.0 if lateral > 0.0 else -1.0
			)
			_record_action(
				"braced_shimmy" if hang_is_braced else "free_shimmy"
			)
	else:
		var idle_name := "braced_idle" if hang_is_braced else "free_idle"
		animation_system.play(idle_name)

	var now_braced := detector.wall_available_at(
		global_position,
		wall_normal,
		0.50
	)
	if now_braced != hang_is_braced:
		hang_is_braced = now_braced
		if hang_is_braced:
			state = State.HANG_BRACED
			_record_action("free_to_braced")
			animation_system.play("free_to_braced", 0.10, 1.0, true)
		else:
			state = State.HANG_FREE
			_record_action("braced_to_free")
			animation_system.play("braced_to_free", 0.10, 1.0, true)

	_align_hands_to_ledge()


func _align_hands_to_ledge() -> void:
	var left_hand := get_bone_world_position(&"LeftHand")
	var right_hand := get_bone_world_position(&"RightHand")
	var hand_midpoint := (left_hand + right_hand) * 0.5

	# The top ray lands 18 cm inside the surface. Match the palms to the
	# physical outer edge, just as Unity's MatchTarget/IK pass does.
	var hand_target := ledge_top + wall_normal * 0.18
	hand_target.y -= 0.015
	var vertical_error := hand_target.y - hand_midpoint.y
	var wall_depth_error := (hand_target - hand_midpoint).dot(wall_normal)
	global_position += (
		Vector3.UP * clampf(vertical_error, -0.075, 0.075)
		+ wall_normal * clampf(wall_depth_error, -0.04, 0.04)
	)


func _begin_ledge_hop(direction_sign: float) -> void:
	var tangent := Vector3.UP.cross(wall_normal).normalized()
	var candidate := global_position + tangent * direction_sign * 0.68
	if not detector.wall_available_at(candidate, wall_normal, 1.55):
		return
	action_start = global_position
	action_target = candidate
	action_elapsed = 0.0
	action_duration = 0.56
	action_arc_height = 0.13
	state = State.LEDGE_HOP
	_record_action("ledge_hop")
	animation_system.play(
		"braced_hop_right" if hang_is_braced else "free_shimmy",
		0.08,
		1.0 if direction_sign > 0.0 else -1.0,
		true
	)


func _update_ledge_hop(delta: float) -> void:
	action_elapsed += delta
	var t := clampf(action_elapsed / action_duration, 0.0, 1.0)
	global_position = action_start.lerp(action_target, t)
	global_position.y += 4.0 * action_arc_height * t * (1.0 - t)
	if t >= 1.0:
		_complete_action("ledge_hop")
		state = State.HANG_BRACED if hang_is_braced else State.HANG_FREE
		animation_system.play(
			"braced_idle" if hang_is_braced else "free_idle",
			0.12,
			1.0,
			true
		)


func _begin_climb_up() -> void:
	action_start = global_position
	var stable_stance := detector.stable_top_stance(
		ledge_top,
		wall_normal
	)
	action_target = stable_stance["position"]
	climbed_support_width = stable_stance["width"]
	action_elapsed = 0.0
	var profile := _select_jump_profile(
		action_start.distance_to(action_target),
		action_target.y - action_start.y,
		0.0,
		1.0,
		"climb_exit"
	)
	current_jump_variant = profile["animation"]
	action_duration = clampf(
		animation_system.duration(profile["animation"]),
		0.86,
		1.35
	)
	state = State.CLIMB_UP
	_record_action(profile["action"])
	animation_system.play(
		profile["animation"],
		0.07,
		1.0,
		true
	)


func _update_climb_up(delta: float) -> void:
	action_elapsed += delta
	var t := clampf(action_elapsed / action_duration, 0.0, 1.0)
	var high_anchor := Vector3(
		action_start.x,
		action_target.y,
		action_start.z
	)
	if t < 0.62:
		var vertical_t := t / 0.62
		vertical_t = vertical_t * vertical_t * (3.0 - 2.0 * vertical_t)
		global_position = action_start.lerp(high_anchor, vertical_t)
	else:
		var mantle_t := (t - 0.62) / 0.38
		mantle_t = mantle_t * mantle_t * (3.0 - 2.0 * mantle_t)
		global_position = high_anchor.lerp(action_target, mantle_t)
	velocity = Vector3.ZERO
	if t >= 1.0:
		global_position = action_target
		edge_guard_active = climbed_support_width < 0.72
		_complete_action(current_action)
		_set_state(State.LOCOMOTION, "idle", "idle")


func _jump_from_wall() -> void:
	var profile := _select_jump_profile(
		2.6,
		0.65,
		0.0,
		-1.0,
		"wall"
	)
	state = State.AIRBORNE
	global_position += wall_normal * 0.08
	velocity = (
		wall_normal * float(profile["horizontal_speed"])
		+ Vector3.UP * float(profile["vertical_speed"])
	)
	wall_jump_capture_elapsed = 0.0
	wall_jump_capture_active = true
	current_jump_variant = profile["animation"]
	jump_origin_action = profile["action"]
	_record_action(profile["action"])
	animation_system.play(
		profile["animation"],
		0.055,
		profile["speed"],
		true
	)


func _drop_from_ledge() -> void:
	state = State.AIRBORNE
	wall_jump_capture_active = false
	global_position += wall_normal * 0.10
	velocity = wall_normal * 0.85 + Vector3.DOWN * 0.65
	_record_action("ledge_drop")
	animation_system.play(
		"free_drop" if not hang_is_braced else "jump_down",
		0.10,
		1.0,
		true
	)


func _try_capture_zipline() -> bool:
	if state in [
		State.SLIDE,
		State.WALL_CLIMB,
		State.WALL_HOP,
		State.HANG_BRACED,
		State.HANG_FREE,
		State.CLIMB_UP,
		State.ASSASSINATION,
	]:
		return false
	var hand_position := global_position + Vector3.UP * 1.48
	var best_line: Node3D
	var best_progress := 0.0
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("parkour_zipline"):
		if (
			not node is Node3D
			or not node.has_method("closest_progress")
			or not node.has_method("point_at")
		):
			continue
		var zipline: Node3D = node as Node3D
		var progress: float = float(
			zipline.call("closest_progress", hand_position)
		)
		if progress >= 0.97:
			continue
		var line_point: Vector3 = zipline.call("point_at", progress)
		var distance: float = hand_position.distance_to(
			line_point
		)
		var capture_radius: float = float(
			zipline.get("capture_radius")
		)
		if (
			distance <= capture_radius
			and distance < best_distance
		):
			best_line = zipline
			best_progress = progress
			best_distance = distance
	if best_line == null:
		return false

	active_zipline = best_line
	zipline_progress = best_progress
	var configured_speed: float = float(
		active_zipline.get("travel_speed")
	)
	zipline_speed = maxf(
		Vector2(velocity.x, velocity.z).length(),
		configured_speed * 0.72
	)
	state = State.ZIPLINE
	velocity = Vector3.ZERO
	var attachment_point: Vector3 = active_zipline.call(
		"point_at",
		zipline_progress
	)
	var travel_direction: Vector3 = active_zipline.call("direction")
	global_position = (
		attachment_point
		+ ZIPLINE_HAND_OFFSET
	)
	_face_direction_immediate(travel_direction)
	_record_action("zipline_attach")
	animation_system.play("hanging_idle", 0.065, 1.08, true)
	return true


func _update_zipline(delta: float) -> void:
	if active_zipline == null or not is_instance_valid(active_zipline):
		_exit_zipline(false)
		return
	if (
		Input.is_action_just_pressed("go_up")
		or Input.is_action_just_pressed("drop")
	):
		_exit_zipline(true)
		return

	var line_direction: Vector3 = active_zipline.call("direction")
	var gravity_acceleration := maxf(
		0.0,
		-Vector3.UP.dot(line_direction) * GRAVITY * 0.58
	)
	var configured_speed: float = float(
		active_zipline.get("travel_speed")
	)
	zipline_speed = move_toward(
		zipline_speed,
		configured_speed + gravity_acceleration,
		delta * 4.8
	)
	var line_length: float = float(active_zipline.call("length"))
	zipline_progress += (
		zipline_speed
		/ maxf(line_length, 0.1)
		* delta
	)
	var sway: Vector3 = (
		Vector3.UP.cross(line_direction).normalized()
		* sin(Time.get_ticks_msec() * 0.012)
		* 0.018
	)
	var line_point: Vector3 = active_zipline.call(
		"point_at",
		zipline_progress
	)
	global_position = (
		line_point
		+ ZIPLINE_HAND_OFFSET
		+ sway
	)
	_face_direction_immediate(line_direction)
	velocity = Vector3.ZERO
	animation_system.play("hanging_idle", 0.10, 1.06)
	if zipline_progress >= 0.985:
		_exit_zipline(false)


func _exit_zipline(jumped: bool) -> void:
	var line_direction := _forward()
	var release_speed := RUN_SPEED
	if active_zipline != null and is_instance_valid(active_zipline):
		line_direction = active_zipline.call("direction")
		release_speed = maxf(
			zipline_speed,
			float(active_zipline.get("exit_boost"))
		)
	active_zipline = null
	state = State.AIRBORNE
	velocity = (
		line_direction * release_speed
		+ Vector3.UP * (4.15 if jumped else 1.25)
	)
	intent_direction = line_direction
	zipline_exit_window = 1.15
	current_jump_variant = (
		"jump_running" if jumped else "jump_downward"
	)
	jump_origin_action = "zipline_exit_jump"
	_record_action("zipline_exit_jump" if jumped else "zipline_release")
	animation_system.play(
		current_jump_variant,
		0.055,
		1.08,
		true
	)


func _try_begin_melee_attack() -> bool:
	if state not in [
		State.LOCOMOTION,
		State.LANDING,
		State.AIRBORNE,
	]:
		return false
	_begin_melee_attack()
	return true


func _begin_melee_attack() -> void:
	combat_target = _find_melee_target()
	combat_attack_index = (
		(combat_attack_index + 1)
		% COMBAT_ATTACK_ORDER.size()
	)
	var animation_name: String = COMBAT_ATTACK_ORDER[combat_attack_index]
	combat_attack_name = animation_name
	combat_attack_profile = COMBAT_ATTACK_PROFILES[animation_name]
	action_elapsed = 0.0
	action_duration = clampf(
		animation_system.duration(animation_name)
		/ float(combat_attack_profile["speed"]),
		float(combat_attack_profile["min_duration"]),
		float(combat_attack_profile["max_duration"])
	)
	combat_hit_done = false
	combat_queued_attack = false
	combat_weapon.instance += 1
	combat_weapon.begin_strike(
		animation_name,
		combat_weapon.instance,
		float(combat_attack_profile["damage"])
	)
	state = State.COMBAT_ATTACK
	velocity.x *= 0.35
	velocity.z *= 0.35
	if combat_target != null:
		action_direction = _direction_to_combat_target(combat_target)
		if action_direction.length_squared() > 0.001:
			action_direction = action_direction.normalized()
			_face_direction_immediate(action_direction)
	else:
		action_direction = _combat_intent_direction()
	_record_action(animation_name)
	animation_system.play(
		animation_name,
		0.055,
		float(combat_attack_profile["speed"]),
		true
	)


func _update_melee_attack(delta: float) -> void:
	action_elapsed += delta
	var t := clampf(action_elapsed / action_duration, 0.0, 1.0)
	var profile := _active_combat_profile()
	if combat_target != null and is_instance_valid(combat_target):
		var target_direction := _direction_to_combat_target(combat_target)
		if target_direction.length_squared() > 0.001:
			action_direction = target_direction.normalized()
			if t <= float(profile["turn_end"]):
				_face_direction(
					action_direction,
					delta * float(profile["turn_speed"])
				)

	var hit_active := (
		t >= float(profile["hit_start"])
		and t <= float(profile["hit_end"])
	)
	combat_weapon.set_strike_phase(
		combat_attack_name,
		t,
		hit_active
	)
	_apply_combat_attack_velocity(t, delta, profile)
	if hit_active:
		if (
			not combat_hit_done
			and combat_target != null
			and is_instance_valid(combat_target)
			and _combat_weapon_hits_target(combat_target, profile)
		):
			combat_hit_done = true
			if combat_target.has_method("receive_melee_hit"):
				combat_target.call(
					"receive_melee_hit",
					combat_weapon
				)
	else:
		combat_weapon.can_damage = false

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.35
	move_and_slide()
	if (
		combat_queued_attack
		and t >= float(profile["combo_start"])
		and not combat_defeated
	):
		_complete_action(current_action)
		_begin_melee_attack()
		return
	if t >= 1.0:
		combat_weapon.can_damage = false
		combat_weapon.set_strike_phase(combat_attack_name, 1.0, false)
		combat_target = null
		combat_queued_attack = false
		_complete_action(current_action)
		_set_state(State.LOCOMOTION, "idle", "idle", 1.0, true)


func _find_melee_target() -> Node3D:
	var best_target: Node3D
	var best_score := INF
	var forward_direction := _forward()
	for candidate in get_tree().get_nodes_in_group("enemy"):
		if not candidate is Node3D:
			continue
		var enemy := candidate as Node3D
		if enemy.has_method("is_combat_alive"):
			if not bool(enemy.call("is_combat_alive")):
				continue
		var target_position := _target_combat_position(enemy)
		var offset := target_position - (
			global_position + Vector3.UP * 0.95
		)
		var distance := offset.length()
		if distance > 3.65:
			continue
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		if horizontal.length_squared() < 0.001:
			continue
		var alignment := forward_direction.dot(
			horizontal.normalized()
		)
		if alignment < -0.18:
			continue
		var score := distance * 0.70 + (1.0 - alignment) * 1.05
		if score < best_score:
			best_score = score
			best_target = enemy
	return best_target


func _active_combat_profile() -> Dictionary:
	if combat_attack_profile.is_empty():
		return COMBAT_ATTACK_PROFILES["combat_attack_inward"]
	return combat_attack_profile


func _combat_intent_direction() -> Vector3:
	var movement_direction := _camera_relative_direction(_movement_input())
	if movement_direction != Vector3.ZERO:
		return movement_direction.normalized()
	return _forward()


func _apply_combat_attack_velocity(
	t: float,
	delta: float,
	profile: Dictionary
) -> void:
	var target_speed := 0.0
	var hit_start := float(profile["hit_start"])
	var hit_end := float(profile["hit_end"])
	if t < hit_start:
		target_speed = float(profile["windup_drift"])
	elif t <= hit_end:
		var strike_t := inverse_lerp(hit_start, hit_end, t)
		target_speed = lerpf(
			float(profile["lunge_speed"]) * 0.45,
			float(profile["lunge_speed"]),
			sin(strike_t * PI)
		)
	else:
		target_speed = float(profile["recovery_speed"])
	var desired := action_direction * target_speed
	velocity.x = move_toward(
		velocity.x,
		desired.x,
		float(profile["acceleration"]) * delta
	)
	velocity.z = move_toward(
		velocity.z,
		desired.z,
		float(profile["acceleration"]) * delta
	)


func _combat_weapon_hits_target(
	target: Node3D,
	profile: Dictionary
) -> bool:
	var direction := _direction_to_combat_target(target)
	if direction.length_squared() > 0.001:
		var alignment := action_direction.dot(direction.normalized())
		if alignment < float(profile["minimum_alignment"]):
			return false
	if global_position.distance_to(target.global_position) > float(
		profile["max_distance"]
	):
		return false
	if combat_weapon.blade_hits_target(
		target,
		float(profile["reach_padding"]),
		float(profile["edge_width"])
	):
		return true
	var target_radius := 0.46
	if target.has_method("get_combat_radius"):
		target_radius = float(target.call("get_combat_radius"))
	return (
		global_position + Vector3.UP * 0.95
	).distance_to(_target_combat_position(target)) <= 2.20 + target_radius


func _target_combat_position(target: Node3D) -> Vector3:
	if target.has_method("get_combat_hurt_position"):
		var hurt_position = target.call("get_combat_hurt_position")
		if hurt_position is Vector3:
			return hurt_position
	return target.global_position + Vector3.UP * 0.95


func _direction_to_combat_target(target: Node3D) -> Vector3:
	var direction := _target_combat_position(target) - (
		global_position + Vector3.UP * 0.95
	)
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return _forward()
	return direction.normalized()


func get_combat_hurt_position() -> Vector3:
	return global_position + Vector3.UP * 0.98


func get_combat_radius() -> float:
	return 0.46


func is_combat_alive() -> bool:
	return not combat_defeated and combat_health.is_alive()


func _begin_combat_block() -> void:
	state = State.COMBAT_BLOCK
	combat_parry_window = 0.20
	combat_queued_attack = false
	combat_weapon.set_strike_phase(combat_attack_name, 0.0, false)
	velocity.x *= 0.25
	velocity.z *= 0.25
	_record_action("combat_block")
	animation_system.play("combat_block", 0.055, 1.0, true)


func _update_combat_block(delta: float) -> void:
	var guard_target := combat_target
	if guard_target == null or not is_instance_valid(guard_target):
		guard_target = _find_melee_target()
	if guard_target != null:
		_face_direction(
			_direction_to_combat_target(guard_target),
			delta * 3.6
		)
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	velocity.y = -0.35 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if not Input.is_action_pressed("block"):
		_set_state(State.LOCOMOTION, "idle", "idle", 1.0, true)


func receive_combat_damage(source: DamageSource) -> void:
	if combat_invulnerable or combat_defeated:
		return
	if source == null or source.entity == null:
		return
	if state == State.COMBAT_BLOCK:
		var incoming_direction := source.entity.global_position.direction_to(
			global_position
		)
		incoming_direction.y = 0.0
		if incoming_direction.length_squared() <= 0.0001:
			incoming_direction = _forward()
		var faces_attack := _forward().dot(
			-incoming_direction.normalized()
		) > 0.18
		if faces_attack and combat_parry_window > 0.0:
			combat_parry_window = 0.0
			combat_queued_attack = false
			source.get_parried()
			_record_action("combat_parry")
			animation_system.play("combat_block", 0.03, 1.35, true)
			if source.entity.has_method("receive_parried"):
				source.entity.call("receive_parried")
			return
		if faces_attack:
			combat_health.decrement_health(
				source.damage_attributes.health * 0.18
			)
			_record_action("combat_blocked_hit")
			return
	combat_health.incoming_damage(source)
	combat_queued_attack = false
	combat_weapon.set_strike_phase(combat_attack_name, 0.0, false)
	if combat_health.is_alive():
		combat_invulnerable = true
		combat_hit_elapsed = 0.0
		combat_defeated = false
		state = State.COMBAT_HIT
		var knockback := source.entity.global_position.direction_to(
			global_position
		)
		velocity = knockback * 2.6
		velocity.y = 1.15
		_record_action("combat_hit")
		animation_system.play("combat_block", 0.05, 1.20, true)


func _on_combat_health_depleted() -> void:
	combat_queued_attack = false
	combat_weapon.set_strike_phase(combat_attack_name, 0.0, false)
	combat_invulnerable = true
	combat_defeated = true
	combat_hit_elapsed = 0.0
	state = State.COMBAT_HIT
	velocity = Vector3.ZERO
	_record_action("combat_defeated")
	animation_system.play("combat_death", 0.08, 1.0, true)


func _update_combat_hit(delta: float) -> void:
	combat_hit_elapsed += delta
	velocity.x = move_toward(velocity.x, 0.0, 7.5 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 7.5 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.35
	move_and_slide()
	if combat_defeated:
		if combat_hit_elapsed >= 1.75:
			combat_health.health = combat_health.max_health
			combat_defeated = false
			combat_invulnerable = false
			_reset_player()
		return
	if combat_hit_elapsed >= 0.34:
		combat_invulnerable = false
		_set_state(State.LOCOMOTION, "idle", "idle", 1.0, true)


func _try_begin_assassination() -> bool:
	var candidate: Dictionary = assassination_system.call(
		"find_best_target",
		self,
		_assassination_mode_hint(),
	)
	if candidate.is_empty():
		return false

	assassination_target = candidate["target"]
	assassination_mode = candidate["mode"]
	assassination_hit_applied = false
	action_start = global_position
	var target_center: Vector3 = candidate["position"]
	var approach := Vector3(
		target_center.x - global_position.x,
		0.0,
		target_center.z - global_position.z
	)
	if approach.length_squared() < 0.001:
		approach = _forward()
	approach = approach.normalized()
	action_target = target_center - Vector3.UP * 0.92 - approach * 0.54
	action_target.y = maxf(action_target.y, -0.05)
	action_direction = approach
	action_elapsed = 0.0
	action_duration = (
		0.88
		if assassination_mode != "standard_assassination"
		else 0.98
	)
	action_arc_height = (
		0.52
		if assassination_mode != "standard_assassination"
		else 0.08
	)
	active_zipline = null
	state = State.ASSASSINATION
	velocity = Vector3.ZERO
	_set_assassination_physics_suspended(true)
	_set_assassination_opportunity_empty()
	_face_direction_immediate(approach)
	_record_action(assassination_mode)
	var assassination_animation := "combat_attack_thrust"
	if assassination_mode == "aerial_assassination":
		assassination_animation = "assassination_aerial"
	elif assassination_mode == "jump_assassination":
		assassination_animation = "assassination_jump"
	elif assassination_mode == "zipline_assassination":
		assassination_animation = "assassination_zipline"
	animation_system.play(
		assassination_animation,
		0.055,
		0.92 if assassination_mode == "standard_assassination" else 1.08,
		true
	)
	return true


func _update_assassination(delta: float) -> void:
	if (
		assassination_target == null
		or not is_instance_valid(assassination_target)
	):
		_finish_assassination()
		return
	action_elapsed += delta
	var t := clampf(action_elapsed / action_duration, 0.0, 1.0)
	var transfer := t * t * (3.0 - 2.0 * t)
	global_position = action_start.lerp(action_target, transfer)
	global_position.y += (
		4.0 * action_arc_height * t * (1.0 - t)
	)
	if t < 0.18 and assassination_mode == "standard_assassination":
		global_position -= (
			action_direction * sin(t / 0.18 * PI) * 0.045
		)
	var lethal_time := (
		0.48
		if assassination_mode == "standard_assassination"
		else 0.58
	)
	if not assassination_hit_applied and t >= lethal_time:
		assassination_hit_applied = true
		assassination_system.call(
			"apply_lethal_hit",
			assassination_target
		)
	if t >= 1.0:
		_finish_assassination()


func _finish_assassination() -> void:
	if (
		not assassination_hit_applied
		and assassination_target != null
		and is_instance_valid(assassination_target)
	):
		assassination_system.call(
			"apply_lethal_hit",
			assassination_target
		)
	assassination_hit_applied = true
	assassination_target = null
	_set_assassination_physics_suspended(false)
	zipline_exit_window = 0.0
	velocity = action_direction * 2.1 + Vector3.DOWN * 0.35
	landing_elapsed = 0.0
	_complete_action(assassination_mode)
	_set_state(
		State.LANDING,
		"landing",
		"land_to_run" if _movement_input() != Vector2.ZERO else "landing",
		1.08,
		true
	)


func _assassination_mode_hint() -> String:
	if state == State.ZIPLINE or zipline_exit_window > 0.0:
		return "zipline"
	if state == State.AIRBORNE:
		return (
			"fall"
			if current_action == "fall" and velocity.y < -0.2
			else "after_jump"
		)
	return "standard"


func _set_assassination_physics_suspended(suspended: bool) -> void:
	if _assassination_collision_suspended == suspended:
		return
	_assassination_collision_suspended = suspended
	collider.set_deferred(&"disabled", suspended)


func _set_assassination_opportunity_empty() -> void:
	if (
		not assassination_prompt_visible
		and assassination_prompt_text.is_empty()
		and assassination_prompt_target == null
		and assassination_prompt_mode.is_empty()
	):
		return
	assassination_prompt_visible = false
	assassination_prompt_text = ""
	assassination_prompt_target = null
	assassination_prompt_mode = ""
	assassination_opportunity_changed.emit(false, "", null)


func _set_locomotion_animation(animation_name: String) -> void:
	if current_action == animation_name:
		return
	_record_action(animation_name)
	animation_system.play(animation_name)


func _apply_edge_guard(
	movement_direction: Vector3,
	delta: float,
) -> bool:
	var guard_direction := movement_direction
	if guard_direction == Vector3.ZERO:
		guard_direction = Vector3(velocity.x, 0.0, velocity.z)
	if guard_direction.length_squared() < 0.01:
		return false
	guard_direction = guard_direction.normalized()
	if not detector.has_walkable_support(global_position, 0.82):
		edge_guard_active = false
		return false

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var probe_distance := (
		0.34
		+ minf(horizontal_speed * delta * 1.35, 0.24)
	)
	var full_step := global_position + guard_direction * probe_distance
	if detector.has_walkable_support(full_step):
		edge_guard_active = false
		return false

	var safe_x := false
	var safe_z := false
	if absf(guard_direction.x) > 0.05:
		safe_x = detector.has_walkable_support(
			global_position
			+ Vector3(guard_direction.x, 0.0, 0.0).normalized()
			* probe_distance
		)
	if absf(guard_direction.z) > 0.05:
		safe_z = detector.has_walkable_support(
			global_position
			+ Vector3(0.0, 0.0, guard_direction.z).normalized()
			* probe_distance
		)

	if not safe_x:
		velocity.x = 0.0
	if not safe_z:
		velocity.z = 0.0
	edge_guard_active = true
	_record_action("edge_balance")
	animation_system.play("idle", 0.12)
	return true


func _set_state(
	next_state: State,
	action_name: String,
	animation_name: String,
	speed: float = 1.0,
	restart: bool = false,
	blend_time: float = 0.10,
) -> void:
	state = next_state
	_record_action(action_name)
	animation_system.play(
		animation_name,
		blend_time,
		speed,
		restart
	)


func _record_action(action_name: String) -> void:
	if current_action == action_name:
		return
	current_action = action_name
	action_history.append(action_name)
	if action_history.size() > 64:
		action_history.remove_at(0)
	action_changed.emit(action_name)
	print("Dynamic Parkour -> ", action_name)


func _complete_action(action_name: String) -> void:
	last_completed_action = action_name


func _movement_input() -> Vector2:
	if mobile_input_active:
		return mobile_move_input
	return Input.get_vector("left", "right", "forward", "backward")


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector == Vector2.ZERO:
		return Vector3.ZERO
	var camera_forward := -camera_rig.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera_rig.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	return (
		camera_right * input_vector.x
		+ camera_forward * -input_vector.y
	).normalized()


func _forward() -> Vector3:
	var direction := -global_basis.z
	direction.y = 0.0
	return direction.normalized()


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction == Vector3.ZERO:
		return
	var target_yaw := _yaw_for_direction(direction)
	rotation.y = lerp_angle(
		rotation.y,
		target_yaw,
		clampf(delta * 12.0, 0.0, 1.0)
	)


func _face_direction_immediate(direction: Vector3) -> void:
	if direction != Vector3.ZERO:
		rotation.y = _yaw_for_direction(direction)


func _yaw_for_direction(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func _set_collider_sliding(sliding: bool) -> void:
	var capsule := collider.shape as CapsuleShape3D
	if capsule == null:
		return
	if sliding:
		capsule.height = SLIDE_CAPSULE_HEIGHT
		collider.position.y = SLIDE_COLLIDER_Y
	else:
		capsule.height = NORMAL_CAPSULE_HEIGHT
		collider.position.y = NORMAL_COLLIDER_Y


func _uses_procedural_vertical_motion() -> bool:
	return state in [
		State.AIRBORNE,
		State.LANDING,
		State.VAULT,
		State.REACH,
		State.PREDICTED_JUMP,
		State.LEDGE_ENTRY,
		State.WALL_CLIMB,
		State.WALL_HOP,
		State.LEDGE_HOP,
		State.CLIMB_UP,
		State.ZIPLINE,
		State.COMBAT_ATTACK,
		State.COMBAT_BLOCK,
		State.COMBAT_HIT,
		State.ASSASSINATION,
	]


func _reset_player() -> void:
	global_position = spawn_position
	rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	wall_jump_capture_active = false
	wall_jump_capture_elapsed = 0.0
	wall_climb_elapsed = 0.0
	wall_hop_cooldown = 0.0
	edge_guard_active = false
	climbed_support_width = 1.0
	current_jump_variant = "jump_standing"
	jump_origin_action = ""
	active_zipline = null
	zipline_progress = 0.0
	zipline_speed = 0.0
	zipline_exit_window = 0.0
	assassination_target = null
	assassination_mode = ""
	assassination_hit_applied = false
	_set_assassination_physics_suspended(false)
	_active_hiding_spots.clear()
	is_hidden = false
	is_sneaking = false
	_set_assassination_opportunity_empty()
	combat_target = null
	combat_hit_done = false
	combat_attack_name = ""
	combat_attack_profile = {}
	combat_queued_attack = false
	combat_invulnerable = false
	combat_defeated = false
	combat_hit_elapsed = 0.0
	combat_parry_window = 0.0
	combat_weapon.set_strike_phase(combat_attack_name, 0.0, false)
	combat_health.health = combat_health.max_health
	visual_pivot.position.y = 0.0
	visual_pivot.position.x = 0.0
	visual_pivot.rotation.z = 0.0
	intent_direction = Vector3.FORWARD
	_set_collider_sliding(false)
	_set_state(State.LOCOMOTION, "idle", "idle", 1.0, true)
