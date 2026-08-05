extends Node3D

@onready var player = $".."
@onready var player_camera = $PlayerCamera
var mouse_is_captured = true

func _ready():
	capture_mouse()
	top_level = true


func _process(_delta):
	global_position = player.global_position


func _input(event):
	if event is InputEventMouseButton and event.pressed and not is_touch_device():
		capture_mouse()
	if event.is_action_released("mouse_mode_switch"):
		switch_mouse()
	
	if event is InputEventMouseMotion and mouse_is_captured:
		var d_hor = event.relative.x
		rotate_y(- d_hor / 1000)


func switch_mouse():
	if mouse_is_captured:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_is_captured = not mouse_is_captured

func capture_mouse() -> void:
	if is_touch_device():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_is_captured = true

func is_touch_device() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("window.matchMedia && window.matchMedia('(pointer: coarse)').matches", true))
	return false
