class_name DamageSource
extends BoneAttachment3D


signal parried


@export var entity: CharacterBody3D
@export var debug: bool = false
@export var grip_bone_name: StringName = &"RightHand"
@export var grip_lock_enabled := true

@export var can_damage: bool = false
@export var damage_attributes: DamageAttributes = \
	preload("res://resources/DefaultDamageAttributes.tres")

# Used to make sure an entity is only hit
# once in a single instance. For example
# this may come in and out of a hitbox
# multiple times but it should only count
# as one hit if its the same instance.
var instance: int = 0
var strike_name := ""
var strike_phase := 0.0

@onready var blade_base_marker := $BladeBase as Marker3D
@onready var blade_tip_marker := $BladeTip as Marker3D
@onready var area := $Area as Area3D
@onready var collider := $Area/Collider as CollisionShape3D


func _ready() -> void:
	_bind_to_parent_hand()
	if area != null:
		area.monitoring = false
		area.monitorable = true
	if collider != null:
		collider.disabled = false


func _process(_delta: float) -> void:
	if grip_lock_enabled:
		_bind_to_parent_hand()
	if debug:
		print("%s %.2f active=%s" % [strike_name, strike_phase, can_damage])


func begin_strike(
	_name: String,
	_instance: int,
	_damage: float
) -> void:
	strike_name = _name
	instance = _instance
	strike_phase = 0.0
	can_damage = false
	if damage_attributes == null:
		damage_attributes = DamageAttributes.new()
	damage_attributes.health = _damage


func set_strike_phase(
	_name: String,
	phase: float,
	active: bool
) -> void:
	strike_name = _name
	strike_phase = clampf(phase, 0.0, 1.0)
	can_damage = active


func blade_base() -> Vector3:
	if blade_base_marker != null:
		return blade_base_marker.global_position
	if collider != null:
		var blade_axis := collider.global_basis.y.normalized()
		return collider.global_position - blade_axis * 0.55
	return global_position


func blade_tip(extra_reach := 0.0) -> Vector3:
	var base := blade_base()
	var tip := (
		blade_tip_marker.global_position
		if blade_tip_marker != null
		else global_position + global_basis.y.normalized() * 1.05
	)
	var axis := tip - base
	if axis.length_squared() > 0.0001:
		tip += axis.normalized() * extra_reach
	return tip


func blade_hits_target(
	target: Node3D,
	extra_reach := 0.0,
	edge_width := 0.22
) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var base := blade_base()
	var tip := blade_tip(extra_reach)
	var radius := 0.45
	if target.has_method("get_combat_radius"):
		radius = float(target.call("get_combat_radius"))
	var center := _target_combat_center(target)
	var samples := [
		center + Vector3.UP * 0.45,
		center,
		center + Vector3.DOWN * 0.42,
	]
	for sample in samples:
		if _distance_to_segment(sample, base, tip) <= radius + edge_width:
			return true
	return false


## this damage source got parried by an entity
func get_parried() -> void:
	parried.emit()


## Logic when this damage source successfully hits an entity
## Returns whether its going to free itsself
func hit_considered() -> bool:
	# meant to be overridden
	return false


func _bind_to_parent_hand() -> void:
	var skeleton := get_parent() as Skeleton3D
	if skeleton == null:
		return
	var wanted_bone := skeleton.find_bone(grip_bone_name)
	if wanted_bone < 0:
		return
	if bone_name != grip_bone_name:
		bone_name = grip_bone_name
	if bone_idx != wanted_bone:
		bone_idx = wanted_bone


func _target_combat_center(target: Node3D) -> Vector3:
	if target.has_method("get_combat_hurt_position"):
		var hurt_position = target.call("get_combat_hurt_position")
		if hurt_position is Vector3:
			return hurt_position
	return target.global_position + Vector3.UP * 0.95


func _distance_to_segment(
	point: Vector3,
	start: Vector3,
	end: Vector3
) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var projection := clampf(
		(point - start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	return point.distance_to(start + segment * projection)
