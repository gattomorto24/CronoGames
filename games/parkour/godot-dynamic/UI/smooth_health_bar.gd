extends PanelContainer
class_name ParkourSmoothHealthBar

signal health_displayed(current: float, maximum: float)

@export var smooth_duration := 0.24
@export var damage_lag_delay := 0.16
@export var damage_lag_duration := 0.62
@export var fallback_poll_interval := 0.15

@onready var health_bar := %HealthBar as ProgressBar
@onready var damage_bar := %DamageBar as ProgressBar
@onready var value_label := %HealthValue as Label

var player: Node
var health_source: Node
var _health_tween: Tween
var _damage_tween: Tween
var _poll_elapsed := 0.0
var _last_health := -1.0
var _last_maximum := -1.0
var _connected_signals: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	health_bar.value_changed.connect(_on_bar_value_changed)
	if player != null:
		bind_player(player)


func _process(delta: float) -> void:
	_poll_elapsed -= delta
	if _poll_elapsed > 0.0:
		return
	_poll_elapsed = fallback_poll_interval
	if player != null and (
		health_source == null
		or not is_instance_valid(health_source)
	):
		bind_player(player)
	elif health_source != null:
		_sync_from_source()


func bind_player(new_player: Node) -> void:
	player = new_player
	_disconnect_source()
	health_source = _find_health_source(player)
	if health_source == null:
		return
	for signal_name: StringName in [
		&"health_changed",
		&"took_damage",
		&"health_increased",
		&"zero_health",
	]:
		if health_source.has_signal(signal_name):
			var callback := Callable(self, "_on_health_source_changed")
			if not health_source.is_connected(signal_name, callback):
				health_source.connect(signal_name, callback)
			_connected_signals.append(signal_name)
	_sync_from_source(true)


func set_health(
	current: float,
	maximum: float,
	immediate := false,
) -> void:
	var safe_maximum := maxf(maximum, 1.0)
	var safe_current := clampf(current, 0.0, safe_maximum)
	var previous_target := _last_health
	_last_health = safe_current
	_last_maximum = safe_maximum
	health_bar.max_value = safe_maximum
	damage_bar.max_value = safe_maximum

	if _health_tween != null and _health_tween.is_valid():
		_health_tween.kill()
	if _damage_tween != null and _damage_tween.is_valid():
		_damage_tween.kill()

	if immediate or previous_target < 0.0:
		health_bar.value = safe_current
		damage_bar.value = safe_current
	else:
		_health_tween = create_tween()
		_health_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_health_tween.set_trans(Tween.TRANS_QUART)
		_health_tween.set_ease(Tween.EASE_OUT)
		_health_tween.tween_property(
			health_bar,
			"value",
			safe_current,
			smooth_duration,
		)
		_damage_tween = create_tween()
		_damage_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		if safe_current < damage_bar.value:
			_damage_tween.tween_interval(damage_lag_delay)
			_damage_tween.set_trans(Tween.TRANS_QUAD)
			_damage_tween.set_ease(Tween.EASE_OUT)
			_damage_tween.tween_property(
				damage_bar,
				"value",
				safe_current,
				damage_lag_duration,
			)
		else:
			_damage_tween.tween_property(
				damage_bar,
				"value",
				safe_current,
				smooth_duration,
			)
	_update_value_label(safe_current)
	health_displayed.emit(safe_current, safe_maximum)


func get_displayed_health() -> float:
	return health_bar.value


func _on_health_source_changed(
	_value_a: Variant = null,
	_value_b: Variant = null,
) -> void:
	_sync_from_source()


func _sync_from_source(immediate := false) -> void:
	if health_source == null or not is_instance_valid(health_source):
		return
	var current := _read_numeric_property(health_source, &"health", 0.0)
	var maximum := _read_numeric_property(
		health_source,
		&"max_health",
		maxf(current, 100.0),
	)
	if (
		not immediate
		and is_equal_approx(current, _last_health)
		and is_equal_approx(maximum, _last_maximum)
	):
		return
	set_health(current, maximum, immediate)


func _find_health_source(candidate: Node) -> Node:
	if candidate == null:
		return null
	if _has_property(candidate, &"health") and _has_property(
		candidate,
		&"max_health",
	):
		return candidate
	for path: NodePath in [
		NodePath("CombatHealth"),
		NodePath("HealthComponent"),
		NodePath("Health"),
	]:
		var direct := candidate.get_node_or_null(path)
		if direct != null and _has_property(direct, &"health"):
			return direct
	for child: Node in candidate.find_children(
		"*",
		"HealthComponent",
		true,
		false,
	):
		if _has_property(child, &"health"):
			return child
	for child: Node in candidate.find_children("*", "Node3D", true, false):
		if (
			_has_property(child, &"health")
			and _has_property(child, &"max_health")
		):
			return child
	return null


func _disconnect_source() -> void:
	if health_source == null or not is_instance_valid(health_source):
		_connected_signals.clear()
		return
	var callback := Callable(self, "_on_health_source_changed")
	for signal_name: StringName in _connected_signals:
		if health_source.is_connected(signal_name, callback):
			health_source.disconnect(signal_name, callback)
	_connected_signals.clear()


func _read_numeric_property(
	source: Object,
	property_name: StringName,
	fallback: float,
) -> float:
	if not _has_property(source, property_name):
		return fallback
	var value: Variant = source.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback


func _has_property(source: Object, property_name: StringName) -> bool:
	for property: Dictionary in source.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


func _on_bar_value_changed(value: float) -> void:
	_update_value_label(value)


func _update_value_label(value: float) -> void:
	value_label.text = "%d / %d" % [
		roundi(value),
		roundi(maxf(_last_maximum, 1.0)),
	]
