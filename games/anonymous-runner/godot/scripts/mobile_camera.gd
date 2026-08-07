class_name CronoMobileCamera
extends Node3D

const FOLLOW_DISTANCE := 8.2
const FOLLOW_HEIGHT := 4.2
const LOOK_HEIGHT := 1.2

var target: Node3D
var camera: Camera3D
var focus := Vector3.ZERO

func _ready() -> void:
	name = "MobileCamera"
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 66.0
	camera.near = 0.1
	camera.far = 150.0
	add_child(camera)

func follow(node: Node3D, delta: float) -> void:
	target = node
	if target == null:
		return
	var wanted_focus := target.global_position + Vector3(0.0, LOOK_HEIGHT, 0.0)
	focus = focus.lerp(wanted_focus, minf(1.0, delta * 8.0))
	var wanted_position := focus + Vector3(0.0, FOLLOW_HEIGHT, FOLLOW_DISTANCE)
	global_position = global_position.lerp(wanted_position, minf(1.0, delta * 7.0))
	look_at(focus, Vector3.UP)

func snap_to(node: Node3D) -> void:
	target = node
	focus = target.global_position + Vector3(0.0, LOOK_HEIGHT, 0.0)
	global_position = focus + Vector3(0.0, FOLLOW_HEIGHT, FOLLOW_DISTANCE)
	look_at(focus, Vector3.UP)
