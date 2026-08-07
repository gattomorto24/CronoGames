extends Node
class_name DynamicParkourAnimationController

const ANIMATION_ROOT := "res://assets/dynamic_parkour/Animations/"
const COMBAT_ANIMATION_FILES := {
	"combat_attack_inward": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_inward_slash.res"
	),
	"combat_attack_outward": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_outward_slash.res"
	),
	"combat_attack_thrust": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_forward_thrust.res"
	),
	"combat_block": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_blocking.res"
	),
	"combat_death": (
		"res://animations/combat_animations_1/"
		+ "combat_animations_1_death.res"
	),
}
const ANIMATION_FILES := {
	"idle": "Idle.fbx",
	"idle_to_sprint": "Idle To Sprint.fbx",
	"walk": "Walk.fbx",
	"jog": "Jog Forward.fbx",
	"run": "Run.fbx",
	"run_to_stop": "Run To Stop.fbx",
	"jump": "Jump.fbx",
	"jump_short": "Jumping Crouch.fbx",
	"jump_medium": "Jump.fbx",
	"jump_long": "Big Jump.fbx",
	"jump_up": "ReachHigh.fbx",
	"jump_downward": "JumpingDown.fbx",
	"jump_standing": "Jumping Crouch.fbx",
	"jump_running": "Jump.fbx",
	"jump_wall_surface": "Braced Jump From Wall.fbx",
	"jump_to_grip": "Idle To Braced Hang.fbx",
	"jump_climb_exit": "Braced Hang Climb.fbx",
	"predicted_jump": "Big Jump.fbx",
	"jump_crouch": "Jumping Crouch.fbx",
	"fall": "Fall Idle.fbx",
	"landing": "Falling To Landing.fbx",
	"land_to_run": "Land To Run Forward.fbx",
	"slide": "Slide.fbx",
	"crouch_to_stand": "Crouched To Standing.fbx",
	"vault": "VaultFence.fbx",
	"step_up": "Step Up.fbx",
	"reach_high": "ReachHigh.fbx",
	"jump_down": "JumpingDown.fbx",
	"hanging_idle": "Hanging Idle.fbx",
	"braced_enter": "Idle To Braced Hang.fbx",
	"braced_idle": "Braced Hanging Idle.fbx",
	"braced_climb": "Braced Hang Climb.fbx",
	"braced_shimmy": "Braced Hang Right Shimmy.fbx",
	"braced_hop_up": "Braced Hang Hop Up.fbx",
	"wall_climb": "Braced Hanging Idle.fbx",
	"braced_hop_down": "Braced Hang Hop Down.fbx",
	"braced_hop_right": "Braced Hang Hop Right.fbx",
	"braced_wall_jump": "Braced Jump From Wall.fbx",
	"braced_to_free": "Braced To Free Hang.fbx",
	"free_enter": "Idle To Freehang.fbx",
	"free_idle": "Freehang Idle.fbx",
	"free_climb": "Freehang Climb.fbx",
	"free_drop": "Freehang Drop.fbx",
	"free_shimmy": "FreeHang Left Shimmy.fbx",
	"drop_to_free": "Drop To Freehang.fbx",
	"free_to_braced": "Free Hang To Braced.fbx",
	"assassination_standard": "VaultFence.fbx",
	"assassination_aerial": "JumpingDown.fbx",
	"assassination_jump": "Big Jump.fbx",
	"assassination_zipline": "Braced Jump From Wall.fbx",
}
const LOOPING_ANIMATIONS := {
	"idle": true,
	"walk": true,
	"jog": true,
	"run": true,
	"fall": true,
	"braced_idle": true,
	"free_idle": true,
	"hanging_idle": true,
	"braced_shimmy": true,
	"free_shimmy": true,
	"wall_climb": true,
}

var animation_player: AnimationPlayer
var current_animation: String = ""


func setup(target_player: AnimationPlayer) -> void:
	animation_player = target_player
	if animation_player.has_animation_library("dynamic"):
		animation_player.remove_animation_library("dynamic")
	var library := AnimationLibrary.new()
	for animation_name in ANIMATION_FILES:
		var source_path: String = (
			ANIMATION_ROOT
			+ ANIMATION_FILES[animation_name]
		)
		var packed := load(source_path) as PackedScene
		if packed == null:
			push_warning("Animazione Dynamic Parkour assente: " + source_path)
			continue
		var source_root := packed.instantiate()
		var source_player := _find_animation_player(source_root)
		if source_player == null:
			source_root.free()
			continue
		var source_animation := source_player.get_animation("mixamo_com")
		if source_animation == null:
			source_root.free()
			continue
		var animation := source_animation.duplicate(true) as Animation
		_remove_horizontal_root_motion(animation)
		if LOOPING_ANIMATIONS.has(animation_name):
			animation.loop_mode = Animation.LOOP_LINEAR
		else:
			animation.loop_mode = Animation.LOOP_NONE
		library.add_animation(animation_name, animation)
		source_root.free()
	for animation_name in COMBAT_ANIMATION_FILES:
		var source_animation := load(
			COMBAT_ANIMATION_FILES[animation_name]
		) as Animation
		if source_animation == null:
			continue
		var animation := source_animation.duplicate(true) as Animation
		_retarget_combat_animation(animation)
		_remove_horizontal_root_motion(animation)
		animation.loop_mode = Animation.LOOP_NONE
		library.add_animation(animation_name, animation)
	animation_player.add_animation_library("dynamic", library)


func play(
	animation_name: String,
	blend: float = 0.16,
	speed: float = 1.0,
	restart: bool = false,
) -> void:
	if animation_player == null:
		return
	var qualified := "dynamic/" + animation_name
	if not animation_player.has_animation(qualified):
		return
	if not restart and current_animation == animation_name:
		animation_player.speed_scale = absf(speed)
		return
	current_animation = animation_name
	animation_player.play(
		qualified,
		blend,
		speed,
		speed < 0.0
	)


func duration(animation_name: String) -> float:
	if animation_player == null:
		return 0.0
	var animation := animation_player.get_animation(
		"dynamic/" + animation_name
	)
	return animation.length if animation != null else 0.0


func vertical_root_offset() -> float:
	if animation_player == null or current_animation.is_empty():
		return 0.0
	var animation := animation_player.get_animation(
		"dynamic/" + current_animation
	)
	if animation == null:
		return 0.0
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		var track_path := String(animation.track_get_path(track_index))
		if not track_path.ends_with(":Hips"):
			continue
		if animation.track_get_key_count(track_index) == 0:
			return 0.0
		var first: Vector3 = animation.track_get_key_value(track_index, 0)
		var sampled: Vector3 = animation.position_track_interpolate(
			track_index,
			animation_player.current_animation_position
		)
		return sampled.y - first.y
	return 0.0


func _remove_horizontal_root_motion(animation: Animation) -> void:
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		var track_path := String(animation.track_get_path(track_index))
		if not track_path.ends_with(":Hips"):
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
			animation.track_set_key_value(track_index, key_index, value)


func _retarget_combat_animation(animation: Animation) -> void:
	for track_index in range(
		animation.get_track_count() - 1,
		-1,
		-1
	):
		if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
			animation.remove_track(track_index)
			continue
		var source_path := String(
			animation.track_get_path(track_index)
		)
		if not source_path.begins_with("%GeneralSkeleton"):
			continue
		var target_path := source_path.replace(
			"%GeneralSkeleton",
			"Skeleton3D"
		)
		animation.track_set_path(
			track_index,
			NodePath(target_path)
		)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
