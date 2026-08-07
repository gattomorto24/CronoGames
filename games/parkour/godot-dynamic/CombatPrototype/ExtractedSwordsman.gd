extends CharacterBody3D
class_name ExtractedCombatEnemy

signal dead
signal call_reinforcements(position: Vector3)

enum CombatState {
	IDLE,
	CHASE,
	ATTACK,
	HIT,
	DEAD,
}

enum AwarenessState {
	PATROL,
	SUSPICIOUS,
	ALERT,
}

const ANIMATION_FILES := {
	"walk_forward": (
		"res://animations/movement_animations_1/"
		+ "movement_animations_1_walk_forwards.res"
	),
	"jog_forward": (
		"res://animations/movement_animations_1/"
		+ "movement_animations_1_jog_forward.res"
	),
	"attack_inward": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_inward_slash.res"
	),
	"attack_outward": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_outward_slash.res"
	),
	"attack_thrust": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_forward_thrust.res"
	),
	"blocking": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_blocking.res"
	),
	"death": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_death.res"
	),
	"death_backstab": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_death_backstab.res"
	),
}

@export var detection_radius := 10.5
@export var disengage_radius := 17.0
@export var attack_radius := 2.15
@export var movement_speed := 2.65
@export var attack_damage := 18.0
@export var vision_range := 8.5
@export var vision_angle_degrees := 74.0
@export var detection_build_seconds := 0.8
@export var alert_memory_seconds := 1.25
@export var suspicious_memory_seconds := 2.5
@export var hearing_radius := 9.0
@export var hearing_speed_threshold := 1.35
@export var sneaking_noise_multiplier := 0.28
@export var hidden_reveal_distance := 1.65
@export var reinforcement_call_seconds := 5.0
@export var patrol_radius := 2.4
@export var patrol_speed := 1.15
@export var skin_index := -1

const SKIN_TONES := [
	Color(0.92, 0.70, 0.54),
	Color(0.78, 0.54, 0.38),
	Color(0.58, 0.36, 0.24),
	Color(0.38, 0.23, 0.16),
	Color(0.96, 0.78, 0.62),
	Color(0.68, 0.43, 0.29),
]
const CLOTH_TONES := [
	Color(0.12, 0.24, 0.44),
	Color(0.45, 0.13, 0.10),
	Color(0.16, 0.33, 0.18),
	Color(0.68, 0.54, 0.32),
	Color(0.26, 0.18, 0.36),
	Color(0.50, 0.46, 0.39),
]
const HAIR_TONES := [
	Color(0.08, 0.055, 0.035),
	Color(0.18, 0.10, 0.04),
	Color(0.36, 0.22, 0.10),
	Color(0.62, 0.48, 0.28),
	Color(0.50, 0.50, 0.46),
]

const ATTACK_ORDER := [
	"attack_inward",
	"attack_outward",
	"attack_thrust",
]
const ATTACK_PROFILES := {
	"attack_inward": {
		"damage_scale": 1.0,
		"speed": 1.20,
		"min_duration": 0.58,
		"max_duration": 1.08,
		"hit_start": 0.31,
		"hit_end": 0.58,
		"turn_end": 0.52,
		"lunge_speed": 1.85,
		"windup_drift": -0.10,
		"recovery_speed": 0.35,
		"acceleration": 16.0,
		"turn_speed": 2.8,
		"reach_padding": 0.46,
		"edge_width": 0.34,
		"max_distance": 2.82,
	},
	"attack_outward": {
		"damage_scale": 1.12,
		"speed": 1.15,
		"min_duration": 0.62,
		"max_duration": 1.14,
		"hit_start": 0.34,
		"hit_end": 0.64,
		"turn_end": 0.46,
		"lunge_speed": 1.70,
		"windup_drift": -0.08,
		"recovery_speed": 0.28,
		"acceleration": 14.0,
		"turn_speed": 2.45,
		"reach_padding": 0.52,
		"edge_width": 0.36,
		"max_distance": 2.92,
	},
	"attack_thrust": {
		"damage_scale": 1.32,
		"speed": 1.28,
		"min_duration": 0.52,
		"max_duration": 0.96,
		"hit_start": 0.25,
		"hit_end": 0.50,
		"turn_end": 0.62,
		"lunge_speed": 2.45,
		"windup_drift": -0.05,
		"recovery_speed": 0.55,
		"acceleration": 22.0,
		"turn_speed": 3.35,
		"reach_padding": 0.70,
		"edge_width": 0.18,
		"max_distance": 3.12,
	},
}

static var _shared_alert_arc_texture: ImageTexture

@onready var animation_player: AnimationPlayer = (
	$Character/AnimationPlayer
)
@onready var health_component: HealthComponent = $HealthComponent
@onready var sword: DamageSource = (
	$Character/Armature_004/GeneralSkeleton/Sword
)
@onready var status_label: Label3D = $Status

var combat_state := CombatState.IDLE
var player: CharacterBody3D
var attack_elapsed := 0.0
var attack_duration := 1.0
var attack_hit_done := false
var attack_index := -1
var attack_name := ""
var attack_profile: Dictionary = {}
var attack_cooldown := 0.0
var hit_recovery := 0.0
var home_position := Vector3.ZERO
var death_by_assassination := false
var awareness_state := AwarenessState.PATROL
var has_seen_player: bool:
	get:
		return awareness_state == AwarenessState.ALERT
	set(value):
		if value:
			awareness_state = AwarenessState.ALERT
			vision_heat = 1.0
			if is_inside_tree():
				call_deferred("_ensure_reinforcement_countdown")
		else:
			awareness_state = AwarenessState.PATROL
			vision_heat = 0.0
			if reinforcement_timer != null:
				reinforcement_timer.stop()
			_set_alert_indicator_visible(false)
var vision_heat := 0.0
var player_visible := false
var last_seen_position := Vector3.ZERO
var patrol_forward := Vector3.FORWARD
var patrol_sign := 1.0
var patrol_wait := 0.0
var investigation_time_left := 0.0
var reinforcement_timer: Timer
var reinforcements_called := false
var alert_indicator_viewport: SubViewport
var alert_indicator_progress: TextureProgressBar
var alert_indicator_sprite: Sprite3D
var _hidden_property_player_id := 0
var _player_has_hidden_property := false
var _player_has_sneaking_property := false


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("assassination_targets")
	home_position = global_position
	last_seen_position = home_position
	patrol_forward = _forward_direction()
	health_component.max_health = 100.0
	health_component.health = health_component.max_health
	health_component.zero_health.connect(_on_zero_health)
	sword.entity = self
	sword.damage_attributes = DamageAttributes.new()
	sword.damage_attributes.health = attack_damage
	sword.can_damage = false
	_install_reinforcement_system()
	_apply_random_human_skin()
	_install_original_animation_library()
	_play_animation("blocking", 0.0, 0.72, true)
	_update_status()


func _physics_process(delta: float) -> void:
	if combat_state == CombatState.DEAD:
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if player == null or not is_instance_valid(player):
		_assign_player(
			get_tree().get_first_node_in_group(
				"parkour_player"
			) as CharacterBody3D
		)
		if player == null:
			return
	_update_vision(delta)
	_update_hearing()
	_update_alert_indicator()

	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.35

	if combat_state == CombatState.ATTACK:
		if player_visible:
			_update_attack(delta)
		else:
			_cancel_attack()
		move_and_slide()
		return
	if combat_state == CombatState.HIT:
		hit_recovery -= delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		if hit_recovery <= 0.0:
			combat_state = CombatState.CHASE
		return

	if awareness_state == AwarenessState.PATROL:
		var home_offset := home_position - global_position
		home_offset.y = 0.0
		if home_offset.length() > patrol_radius + 0.75:
			_update_return_home(delta)
		else:
			_update_patrol(delta)
		move_and_slide()
		return

	if awareness_state == AwarenessState.SUSPICIOUS:
		if player_visible:
			_update_guard(delta)
			_face_direction(_direction_to_player(), delta)
		else:
			_update_investigation(delta)
		move_and_slide()
		return

	if not player_visible:
		var search_offset := last_seen_position - global_position
		search_offset.y = 0.0
		if search_offset.length() > 0.45:
			_update_chase(search_offset, delta)
		else:
			_update_guard(delta)
		move_and_slide()
		return

	var offset := player.global_position - global_position
	var horizontal := Vector3(offset.x, 0.0, offset.z)
	var distance := horizontal.length()
	if (
		distance <= attack_radius
		and attack_cooldown <= 0.0
		and player_visible
		and _has_attack_line(horizontal)
	):
		_begin_attack()
	elif distance <= attack_radius * 1.18:
		_update_guard(delta)
		_face_direction(horizontal.normalized(), delta * 1.45)
	elif distance <= disengage_radius:
		_update_chase(horizontal, delta)
	else:
		_update_guard(delta)
	move_and_slide()


func receive_melee_hit(source: DamageSource) -> void:
	if combat_state == CombatState.DEAD or not source.can_damage:
		return
	if source.entity is Node3D:
		last_seen_position = (source.entity as Node3D).global_position
	_enter_alert()
	health_component.incoming_damage(source)
	sword.set_strike_phase(attack_name, 0.0, false)
	attack_cooldown = 0.42
	if health_component.is_alive():
		combat_state = CombatState.HIT
		hit_recovery = 0.38
		velocity = (
			source.entity.global_position.direction_to(global_position)
			* 2.55
		)
		_play_animation("blocking", 0.06, 1.22, true)
	_update_status()


func receive_assassination() -> void:
	if combat_state == CombatState.DEAD:
		return
	death_by_assassination = true
	health_component.deal_max_damage = true
	health_component.decrement_health(1.0)


func receive_parried() -> void:
	if combat_state == CombatState.DEAD:
		return
	if player != null and is_instance_valid(player):
		last_seen_position = player.global_position
	_enter_alert()
	sword.set_strike_phase(attack_name, 0.0, false)
	combat_state = CombatState.HIT
	hit_recovery = 1.02
	attack_cooldown = 0.72
	velocity = -_forward_direction() * 2.1
	_play_animation("blocking", 0.04, 1.35, true)


func can_be_assassinated() -> bool:
	return (
		combat_state != CombatState.DEAD
		and awareness_state != AwarenessState.ALERT
	)


func is_player_detected(_player: CharacterBody3D = null) -> bool:
	return awareness_state == AwarenessState.ALERT


func get_vision_data() -> Dictionary:
	return {
		"range": vision_range,
		"angle": deg_to_rad(vision_angle_degrees),
		"heat": vision_heat,
		"alert": awareness_state == AwarenessState.ALERT,
		"state": awareness_state,
		"state_name": _awareness_state_name(),
		"reinforcement_time_left": (
			reinforcement_timer.time_left
			if reinforcement_timer != null
			else 0.0
		),
		"origin": global_position,
		"direction": _forward_direction(),
	}


func hear_noise(
	world_position: Vector3,
	intensity := 1.0,
) -> bool:
	if combat_state == CombatState.DEAD:
		return false
	var normalized_intensity := clampf(intensity, 0.05, 1.0)
	var audible_distance := hearing_radius * normalized_intensity
	if global_position.distance_to(world_position) > audible_distance:
		return false
	last_seen_position = world_position
	vision_heat = maxf(
		vision_heat,
		0.20 + normalized_intensity * 0.42
	)
	if awareness_state == AwarenessState.PATROL:
		_set_awareness_state(AwarenessState.SUSPICIOUS)
	else:
		investigation_time_left = suspicious_memory_seconds
	_update_status()
	return true


func _set_awareness_state(next_state: AwarenessState) -> void:
	if awareness_state == next_state:
		return
	awareness_state = next_state
	if awareness_state == AwarenessState.PATROL:
		vision_heat = 0.0
		investigation_time_left = 0.0
	elif awareness_state == AwarenessState.SUSPICIOUS:
		investigation_time_left = suspicious_memory_seconds
	_update_status()


func _enter_alert() -> void:
	if combat_state == CombatState.DEAD:
		return
	vision_heat = 1.0
	_set_awareness_state(AwarenessState.ALERT)
	_ensure_reinforcement_countdown()


func _ensure_reinforcement_countdown() -> void:
	if (
		combat_state == CombatState.DEAD
		or reinforcements_called
		or reinforcement_timer == null
		or not reinforcement_timer.is_stopped()
	):
		return
	reinforcement_timer.start(
		maxf(reinforcement_call_seconds, 0.05)
	)
	_set_alert_indicator_visible(true)
	_update_alert_indicator()


func _install_reinforcement_system() -> void:
	reinforcement_timer = Timer.new()
	reinforcement_timer.name = "ReinforcementCallTimer"
	reinforcement_timer.one_shot = true
	reinforcement_timer.wait_time = maxf(
		reinforcement_call_seconds,
		0.05
	)
	reinforcement_timer.timeout.connect(
		_on_reinforcement_timer_timeout
	)
	add_child(reinforcement_timer)
	_create_alert_indicator()


func _create_alert_indicator() -> void:
	alert_indicator_viewport = SubViewport.new()
	alert_indicator_viewport.name = "AlertIndicatorViewport"
	alert_indicator_viewport.size = Vector2i(128, 96)
	alert_indicator_viewport.transparent_bg = true
	alert_indicator_viewport.disable_3d = true
	alert_indicator_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS
	)
	add_child(alert_indicator_viewport)

	alert_indicator_progress = TextureProgressBar.new()
	alert_indicator_progress.name = "ReinforcementProgress"
	alert_indicator_progress.position = Vector2.ZERO
	alert_indicator_progress.size = Vector2(128.0, 128.0)
	alert_indicator_progress.min_value = 0.0
	alert_indicator_progress.max_value = 100.0
	alert_indicator_progress.value = 100.0
	alert_indicator_progress.fill_mode = (
		TextureProgressBar.FILL_CLOCKWISE
	)
	alert_indicator_progress.radial_initial_angle = 270.0
	alert_indicator_progress.radial_fill_degrees = 180.0
	var arc_texture := _make_semicircle_texture()
	alert_indicator_progress.texture_under = arc_texture
	alert_indicator_progress.texture_progress = arc_texture
	alert_indicator_progress.tint_under = Color(
		0.05,
		0.04,
		0.04,
		0.72
	)
	alert_indicator_progress.tint_progress = Color.WHITE
	alert_indicator_viewport.add_child(alert_indicator_progress)

	alert_indicator_sprite = Sprite3D.new()
	alert_indicator_sprite.name = "ReinforcementIndicator"
	alert_indicator_sprite.position = Vector3(0.0, 2.62, 0.0)
	alert_indicator_sprite.texture = (
		alert_indicator_viewport.get_texture()
	)
	alert_indicator_sprite.pixel_size = 0.006
	alert_indicator_sprite.billboard = (
		BaseMaterial3D.BILLBOARD_ENABLED
	)
	alert_indicator_sprite.no_depth_test = true
	add_child(alert_indicator_sprite)
	_set_alert_indicator_visible(false)


func _make_semicircle_texture() -> ImageTexture:
	if _shared_alert_arc_texture != null:
		return _shared_alert_arc_texture
	var image := Image.create(
		128,
		128,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(64.0, 64.0)
	for y in 128:
		for x in 128:
			if y > 66:
				continue
			var radius := center.distance_to(
				Vector2(float(x), float(y))
			)
			if radius >= 48.0 and radius <= 57.0:
				image.set_pixel(x, y, Color.WHITE)
	_shared_alert_arc_texture = ImageTexture.create_from_image(image)
	return _shared_alert_arc_texture


func _update_alert_indicator() -> void:
	if (
		reinforcement_timer == null
		or alert_indicator_progress == null
	):
		return
	var active := (
		not reinforcement_timer.is_stopped()
		and combat_state != CombatState.DEAD
	)
	_set_alert_indicator_visible(active)
	if not active:
		return
	var duration := maxf(
		reinforcement_timer.wait_time,
		0.05
	)
	var remaining_ratio := clampf(
		reinforcement_timer.time_left / duration,
		0.0,
		1.0
	)
	alert_indicator_progress.value = remaining_ratio * 100.0
	var elapsed_ratio := 1.0 - remaining_ratio
	alert_indicator_progress.tint_progress = Color.WHITE.lerp(
		Color(1.0, 0.08, 0.04, 1.0),
		elapsed_ratio
	)


func _set_alert_indicator_visible(is_visible: bool) -> void:
	if alert_indicator_sprite != null:
		alert_indicator_sprite.visible = is_visible
	if alert_indicator_viewport != null:
		alert_indicator_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS
			if is_visible
			else SubViewport.UPDATE_DISABLED
		)


func _on_reinforcement_timer_timeout() -> void:
	_set_alert_indicator_visible(false)
	if combat_state == CombatState.DEAD or reinforcements_called:
		return
	reinforcements_called = true
	var target_position := last_seen_position
	if player != null and is_instance_valid(player):
		target_position = player.global_position
	call_reinforcements.emit(target_position)


func _update_chase(horizontal: Vector3, delta: float) -> void:
	combat_state = CombatState.CHASE
	var direction := horizontal.normalized()
	_face_direction(direction, delta)
	if not _has_walkable_floor_ahead(direction):
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		_play_animation("blocking", 0.12, 0.82)
		return
	velocity.x = move_toward(
		velocity.x,
		direction.x * movement_speed,
		8.0 * delta
	)
	velocity.z = move_toward(
		velocity.z,
		direction.z * movement_speed,
		8.0 * delta
	)
	_play_animation("jog_forward", 0.16, 1.0)


func _update_patrol(delta: float) -> void:
	if patrol_radius <= 0.05 or patrol_speed <= 0.05:
		_update_guard(delta)
		return
	if patrol_wait > 0.0:
		patrol_wait = maxf(patrol_wait - delta, 0.0)
		_update_guard(delta)
		return
	if is_on_wall():
		_reverse_patrol()
		_update_guard(delta)
		return
	var target := (
		home_position
		+ patrol_forward * patrol_radius * patrol_sign
	)
	var horizontal := target - global_position
	horizontal.y = 0.0
	if horizontal.length() <= 0.30:
		_reverse_patrol()
		_update_guard(delta)
		return
	var direction := horizontal.normalized()
	if not _has_walkable_floor_ahead(direction):
		_reverse_patrol()
		_update_guard(delta)
		return
	combat_state = CombatState.IDLE
	_face_direction(direction, delta * 0.72)
	velocity.x = move_toward(
		velocity.x,
		direction.x * patrol_speed,
		5.0 * delta
	)
	velocity.z = move_toward(
		velocity.z,
		direction.z * patrol_speed,
		5.0 * delta
	)
	_play_animation("walk_forward", 0.18, 0.86)


func _reverse_patrol() -> void:
	patrol_sign *= -1.0
	patrol_wait = 0.48


func _update_guard(delta: float) -> void:
	combat_state = CombatState.IDLE
	velocity.x = move_toward(velocity.x, 0.0, 7.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 7.0 * delta)
	_play_animation("blocking", 0.18, 0.72)


func _update_return_home(delta: float) -> void:
	var horizontal := home_position - global_position
	horizontal.y = 0.0
	if horizontal.length() < 0.35:
		_update_guard(delta)
		return
	_update_chase(horizontal, delta)


func _update_investigation(delta: float) -> void:
	var search_offset := last_seen_position - global_position
	search_offset.y = 0.0
	if search_offset.length() > 0.45:
		_update_chase(search_offset, delta)
		return
	investigation_time_left = maxf(
		investigation_time_left - delta,
		0.0
	)
	_update_guard(delta)
	if investigation_time_left <= 0.0:
		_set_awareness_state(AwarenessState.PATROL)


func _assign_player(candidate: CharacterBody3D) -> void:
	player = candidate
	_hidden_property_player_id = 0
	_player_has_hidden_property = false
	_player_has_sneaking_property = false
	if player == null:
		return
	_hidden_property_player_id = player.get_instance_id()
	for property_data in player.get_property_list():
		var property_name := StringName(property_data.get("name", ""))
		if property_name == &"is_hidden":
			_player_has_hidden_property = true
		elif property_name == &"is_sneaking":
			_player_has_sneaking_property = true


func _is_player_hidden() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if _hidden_property_player_id != player.get_instance_id():
		_assign_player(player)
	return (
		_player_has_hidden_property
		and bool(player.get("is_hidden"))
	)


func _is_player_sneaking() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if _hidden_property_player_id != player.get_instance_id():
		_assign_player(player)
	return (
		_player_has_sneaking_property
		and bool(player.get("is_sneaking"))
	)


func _update_hearing() -> void:
	if (
		player == null
		or not is_instance_valid(player)
		or player_visible
		or awareness_state == AwarenessState.ALERT
	):
		return
	var horizontal_velocity := Vector2(
		player.velocity.x,
		player.velocity.z
	)
	var noise_speed := horizontal_velocity.length()
	if _is_player_sneaking():
		noise_speed *= sneaking_noise_multiplier
	if noise_speed < hearing_speed_threshold:
		return
	var noise_intensity := clampf(
		noise_speed / maxf(movement_speed * 2.4, 0.1),
		0.12,
		1.0
	)
	hear_noise(player.global_position, noise_intensity)


func _update_vision(delta: float) -> void:
	player_visible = false
	if player == null or not is_instance_valid(player):
		vision_heat = maxf(vision_heat - delta * 0.55, 0.0)
		return
	player_visible = (
		_player_inside_vision_cone()
		and _has_line_of_sight()
	)
	if player_visible:
		last_seen_position = player.global_position
		investigation_time_left = suspicious_memory_seconds
		if awareness_state == AwarenessState.PATROL:
			_set_awareness_state(AwarenessState.SUSPICIOUS)
		if awareness_state == AwarenessState.ALERT:
			vision_heat = 1.0
		else:
			vision_heat = minf(
				vision_heat
				+ delta / maxf(detection_build_seconds, 0.05),
				1.0
			)
			if vision_heat >= 0.999:
				_enter_alert()
	else:
		var fade_speed := 1.0
		if awareness_state == AwarenessState.ALERT:
			fade_speed = 1.0 / maxf(alert_memory_seconds, 0.05)
		elif awareness_state == AwarenessState.SUSPICIOUS:
			fade_speed = 0.45
		vision_heat = maxf(vision_heat - delta * fade_speed, 0.0)
		if (
			awareness_state == AwarenessState.ALERT
			and vision_heat <= 0.0
		):
			_set_awareness_state(AwarenessState.SUSPICIOUS)
	_update_status()


func _player_inside_vision_cone() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var to_player := player.global_position - global_position
	var horizontal := Vector3(to_player.x, 0.0, to_player.z)
	var distance := horizontal.length()
	if _is_player_hidden() and distance > hidden_reveal_distance:
		return false
	var active_range := (
		detection_radius
		if awareness_state == AwarenessState.ALERT
		else vision_range
	)
	if distance > active_range or distance < 0.001:
		return false
	var half_angle := deg_to_rad(vision_angle_degrees) * 0.5
	return _forward_direction().dot(horizontal.normalized()) >= cos(half_angle)


func _has_line_of_sight() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var eye := global_position + Vector3.UP * 1.55
	return (
		_ray_reaches_player(
			eye,
			player.global_position + Vector3.UP * 1.34
		)
		or _ray_reaches_player(
			eye,
			player.global_position + Vector3.UP * 0.86
		)
	)


func _ray_reaches_player(eye: Vector3, target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.collision_mask = 1 | player.collision_layer
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider = hit.get("collider")
	if collider == player:
		return true
	return collider is Node and player.is_ancestor_of(collider)


func _begin_attack() -> void:
	if not player_visible:
		return
	combat_state = CombatState.ATTACK
	attack_elapsed = 0.0
	attack_hit_done = false
	attack_index = (attack_index + 1) % ATTACK_ORDER.size()
	var animation_name: String = ATTACK_ORDER[attack_index]
	attack_name = animation_name
	attack_profile = ATTACK_PROFILES[animation_name]
	attack_duration = clampf(
		animation_player.get_animation(
			"prototype/" + animation_name
		).length / float(attack_profile["speed"]),
		float(attack_profile["min_duration"]),
		float(attack_profile["max_duration"])
	)
	sword.instance += 1
	sword.begin_strike(
		animation_name,
		sword.instance,
		attack_damage * float(attack_profile["damage_scale"])
	)
	velocity.x = 0.0
	velocity.z = 0.0
	if player != null and is_instance_valid(player):
		_face_direction(
			_direction_to_player(),
			0.25
		)
	_play_animation(
		animation_name,
		0.08,
		float(attack_profile["speed"]),
		true
	)


func _update_attack(delta: float) -> void:
	if not player_visible:
		_cancel_attack()
		return
	attack_elapsed += delta
	var profile := _active_attack_profile()
	var normalized_time := clampf(
		attack_elapsed / attack_duration,
		0.0,
		1.0
	)
	if player != null and is_instance_valid(player):
		var direction := _direction_to_player()
		if normalized_time <= float(profile["turn_end"]):
			_face_direction(
				direction,
				delta * float(profile["turn_speed"])
			)
		var hit_active := (
			normalized_time >= float(profile["hit_start"])
			and normalized_time <= float(profile["hit_end"])
		)
		sword.set_strike_phase(attack_name, normalized_time, hit_active)
		_apply_attack_velocity(normalized_time, delta, profile, direction)
		if hit_active:
			if (
				not attack_hit_done
				and _sword_reaches_player(profile)
			):
				attack_hit_done = true
				if player.has_method("receive_combat_damage"):
					player.call("receive_combat_damage", sword)
		else:
			sword.set_strike_phase(attack_name, normalized_time, false)
			_apply_attack_velocity(normalized_time, delta, profile, direction)
	if normalized_time >= 1.0:
		sword.set_strike_phase(attack_name, 1.0, false)
		attack_cooldown = 0.38
		combat_state = CombatState.CHASE


func _cancel_attack() -> void:
	sword.set_strike_phase(attack_name, 0.0, false)
	attack_hit_done = false
	attack_cooldown = maxf(attack_cooldown, 0.28)
	combat_state = CombatState.IDLE
	velocity.x = move_toward(velocity.x, 0.0, 0.85)
	velocity.z = move_toward(velocity.z, 0.0, 0.85)
	_play_animation("blocking", 0.08, 0.82, true)


func _active_attack_profile() -> Dictionary:
	if attack_profile.is_empty():
		return ATTACK_PROFILES["attack_inward"]
	return attack_profile


func _apply_attack_velocity(
	t: float,
	delta: float,
	profile: Dictionary,
	direction: Vector3
) -> void:
	var target_speed := 0.0
	var hit_start := float(profile["hit_start"])
	var hit_end := float(profile["hit_end"])
	if t < hit_start:
		target_speed = float(profile["windup_drift"])
	elif t <= hit_end:
		var strike_t := inverse_lerp(hit_start, hit_end, t)
		target_speed = lerpf(
			float(profile["lunge_speed"]) * 0.42,
			float(profile["lunge_speed"]),
			sin(strike_t * PI)
		)
	else:
		target_speed = float(profile["recovery_speed"])
	var desired := direction * target_speed
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


func _sword_reaches_player(profile: Dictionary) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not player_visible or not _has_line_of_sight():
		return false
	if global_position.distance_to(player.global_position) > float(
		profile["max_distance"]
	):
		return false
	return sword.blade_hits_target(
		player,
		float(profile["reach_padding"]),
		float(profile["edge_width"])
	)


func _direction_to_player() -> Vector3:
	if player == null or not is_instance_valid(player):
		return _forward_direction()
	var target_position := player.global_position + Vector3.UP * 0.95
	if player.has_method("get_combat_hurt_position"):
		var hurt_position = player.call("get_combat_hurt_position")
		if hurt_position is Vector3:
			target_position = hurt_position
	var direction := target_position - (global_position + Vector3.UP * 0.95)
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return _forward_direction()
	return direction.normalized()


func _has_attack_line(horizontal: Vector3) -> bool:
	if not player_visible or not _has_line_of_sight():
		return false
	if horizontal.length_squared() <= 0.0001:
		return true
	return _forward_direction().dot(horizontal.normalized()) > 0.16


func _has_walkable_floor_ahead(direction: Vector3) -> bool:
	if direction.length_squared() <= 0.0001 or not is_on_floor():
		return true
	var origin := (
		global_position
		+ direction.normalized() * 0.58
		+ Vector3.UP * 0.42
	)
	var target := origin + Vector3.DOWN * 1.35
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(
		query
	).is_empty()


func get_combat_hurt_position() -> Vector3:
	return global_position + Vector3.UP * 0.98


func get_combat_radius() -> float:
	return 0.48


func is_combat_alive() -> bool:
	return combat_state != CombatState.DEAD and health_component.is_alive()


func _on_zero_health() -> void:
	if combat_state == CombatState.DEAD:
		return
	combat_state = CombatState.DEAD
	if reinforcement_timer != null:
		reinforcement_timer.stop()
	_set_alert_indicator_visible(false)
	sword.set_strike_phase(attack_name, 0.0, false)
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	_play_animation(
		"death_backstab" if death_by_assassination else "death",
		0.08,
		1.0,
		true
	)
	status_label.visible = false
	dead.emit()


func _install_original_animation_library() -> void:
	if animation_player.has_animation_library("prototype"):
		animation_player.remove_animation_library("prototype")
	var library := AnimationLibrary.new()
	for animation_name in ANIMATION_FILES:
		var source := load(ANIMATION_FILES[animation_name]) as Animation
		if source == null:
			continue
		var animation := source.duplicate(true) as Animation
		_remove_legacy_event_tracks(animation)
		_remove_root_motion(animation)
		if animation_name in ["walk_forward", "jog_forward", "blocking"]:
			animation.loop_mode = Animation.LOOP_LINEAR
		else:
			animation.loop_mode = Animation.LOOP_NONE
		library.add_animation(animation_name, animation)
	animation_player.add_animation_library("prototype", library)


func _apply_random_human_skin() -> void:
	var palette_index := skin_index
	if palette_index < 0:
		palette_index = abs(hash(name + str(global_position)))
	var skin: Color = SKIN_TONES[palette_index % SKIN_TONES.size()]
	var cloth: Color = CLOTH_TONES[
		(palette_index * 3 + 1) % CLOTH_TONES.size()
	]
	var accent: Color = CLOTH_TONES[
		(palette_index * 5 + 2) % CLOTH_TONES.size()
	]
	var hair: Color = HAIR_TONES[
		(palette_index * 7 + 3) % HAIR_TONES.size()
	]
	_apply_palette_to_meshes(
		$Character,
		_make_flat_material(skin, 0.72),
		_make_flat_material(cloth, 0.86),
		_make_flat_material(accent.darkened(0.20), 0.90),
		_make_flat_material(hair, 0.82)
	)


func _make_flat_material(
	color: Color,
	roughness: float,
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	return material


func _apply_palette_to_meshes(
	node: Node,
	skin: Material,
	cloth: Material,
	accent: Material,
	hair: Material,
) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var path_label := String(mesh_instance.get_path()).to_lower()
		if path_label.contains("sword"):
			return
		if mesh_instance.mesh == null:
			mesh_instance.material_override = cloth
		else:
			var surface_count := mesh_instance.mesh.get_surface_count()
			for surface_index in surface_count:
				var label := _surface_label(mesh_instance, surface_index)
				mesh_instance.set_surface_override_material(
					surface_index,
					_pick_palette_material(
						label,
						surface_index,
						surface_count,
						skin,
						cloth,
						accent,
						hair
					)
				)
	for child in node.get_children():
		if child is Node:
			_apply_palette_to_meshes(child, skin, cloth, accent, hair)


func _surface_label(
	mesh_instance: MeshInstance3D,
	surface_index: int,
) -> String:
	var label := String(mesh_instance.name).to_lower()
	var material := mesh_instance.get_active_material(surface_index)
	if material != null:
		label += " " + String(material.resource_name).to_lower()
	if mesh_instance.mesh != null:
		label += " " + String(mesh_instance.mesh.resource_name).to_lower()
	return label


func _pick_palette_material(
	label: String,
	surface_index: int,
	surface_count: int,
	skin: Material,
	cloth: Material,
	accent: Material,
	hair: Material,
) -> Material:
	if label.contains("hair"):
		return hair
	if (
		label.contains("skin")
		or label.contains("body")
		or label.contains("head")
		or label.contains("face")
		or label.contains("hand")
		or label.contains("arm")
	):
		return skin
	if (
		label.contains("boot")
		or label.contains("shoe")
		or label.contains("belt")
		or label.contains("leather")
	):
		return accent
	if surface_count <= 1:
		return cloth
	if surface_index == 0:
		return skin
	if surface_index == surface_count - 1:
		return accent
	return cloth


func _remove_legacy_event_tracks(animation: Animation) -> void:
	for track_index in range(
		animation.get_track_count() - 1,
		-1,
		-1
	):
		if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
			animation.remove_track(track_index)


func _remove_root_motion(animation: Animation) -> void:
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		var path := String(animation.track_get_path(track_index))
		if not path.ends_with(":Root") and not path.ends_with(":Hips"):
			continue
		if animation.track_get_key_count(track_index) == 0:
			continue
		var first: Vector3 = animation.track_get_key_value(track_index, 0)
		for key_index in animation.track_get_key_count(track_index):
			var value: Vector3 = animation.track_get_key_value(
				track_index,
				key_index
			)
			value.x = first.x
			value.z = first.z
			animation.track_set_key_value(
				track_index,
				key_index,
				value
			)


func _play_animation(
	animation_name: String,
	blend := 0.14,
	speed := 1.0,
	restart := false,
) -> void:
	var qualified := "prototype/" + animation_name
	if (
		not restart
		and animation_player.current_animation == qualified
	):
		return
	animation_player.play(qualified, blend, speed)


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(
		rotation.y,
		target_yaw,
		clampf(delta * 9.5, 0.0, 1.0)
	)


func _forward_direction() -> Vector3:
	var direction := -global_basis.z
	direction.y = 0.0
	return direction.normalized()


func _update_status() -> void:
	var prefix := _awareness_state_name()
	status_label.text = "%s  %d" % [
		prefix,
		int(health_component.health),
	]
	if awareness_state == AwarenessState.ALERT:
		status_label.modulate = Color(1.0, 0.2, 0.16, 1.0)
	elif awareness_state == AwarenessState.SUSPICIOUS:
		status_label.modulate = Color(1.0, 0.82, 0.28, 1.0)
	else:
		status_label.modulate = Color(0.82, 0.90, 1.0, 1.0)


func _awareness_state_name() -> String:
	match awareness_state:
		AwarenessState.SUSPICIOUS:
			return "SUSPICIOUS"
		AwarenessState.ALERT:
			return "ALERT"
		_:
			return "PATROL"
