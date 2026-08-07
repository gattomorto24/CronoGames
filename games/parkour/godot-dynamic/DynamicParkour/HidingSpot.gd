extends Area3D
class_name HidingSpot

signal concealment_changed(body: Node3D, concealed: bool)

@export var concealment_enabled := true:
	set(value):
		concealment_enabled = value
		if not concealment_enabled:
			_release_all_bodies()

var _concealed_bodies: Dictionary = {}


func _ready() -> void:
	add_to_group(&"HidingSpot")
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	_release_all_bodies()


func contains_player(player: Node3D) -> bool:
	if player == null:
		return false
	return _concealed_bodies.has(player.get_instance_id())


func _on_body_entered(body: Node3D) -> void:
	if (
		not concealment_enabled
		or not body.has_method("enter_hiding_spot")
	):
		return
	var instance_id := body.get_instance_id()
	if _concealed_bodies.has(instance_id):
		return
	_concealed_bodies[instance_id] = weakref(body)
	body.call("enter_hiding_spot", self)
	concealment_changed.emit(body, true)


func _on_body_exited(body: Node3D) -> void:
	var instance_id := body.get_instance_id()
	if not _concealed_bodies.has(instance_id):
		return
	_concealed_bodies.erase(instance_id)
	if body.has_method("exit_hiding_spot"):
		body.call("exit_hiding_spot", self)
	concealment_changed.emit(body, false)


func _release_all_bodies() -> void:
	for body_reference: WeakRef in _concealed_bodies.values():
		var body := body_reference.get_ref() as Node3D
		if (
			body != null
			and is_instance_valid(body)
			and body.has_method("exit_hiding_spot")
		):
			body.call("exit_hiding_spot", self)
	_concealed_bodies.clear()
