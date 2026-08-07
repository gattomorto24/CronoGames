extends CanvasLayer
class_name ParkourPauseMenu

signal resumed
signal menu_opened
signal graphics_preset_changed(preset: int, preset_name: String)

@export_enum("Performance", "Bassa", "Media", "Alta", "Ultra")
var default_graphics_preset := ParkourGraphicsPresets.Preset.MEDIUM

@onready var menu_root := %MenuRoot as Control
@onready var main_panel := %MainPanel as VBoxContainer
@onready var manual_panel := %ManualPanel as VBoxContainer
@onready var options_panel := %OptionsPanel as VBoxContainer
@onready var resume_button := %ResumeButton as Button
@onready var manual_button := %ManualButton as Button
@onready var options_button := %OptionsButton as Button
@onready var quit_button := %QuitButton as Button
@onready var manual_back_button := %ManualBackButton as Button
@onready var options_back_button := %OptionsBackButton as Button
@onready var preset_selector := %GraphicsPresetSelector as OptionButton
@onready var preset_detail := %GraphicsPresetDetail as Label

var _is_open := false
var _previous_tree_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _current_preset := ParkourGraphicsPresets.Preset.MEDIUM


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("parkour_pause_menu")
	menu_root.visible = false
	set_process_input(true)
	_connect_buttons()
	_populate_presets()
	_show_main_panel()
	call_deferred("apply_graphics_preset", default_graphics_preset)


func _exit_tree() -> void:
	if _is_open and get_tree() != null:
		get_tree().paused = _previous_tree_paused


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _map_is_open():
		return
	if _is_open and (manual_panel.visible or options_panel.visible):
		_show_main_panel()
	else:
		toggle_pause()
	get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if _is_open:
		resume_game()
	else:
		open_menu()


func open_menu() -> void:
	if _is_open:
		return
	_is_open = true
	_previous_tree_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_root.visible = true
	_show_main_panel()
	resume_button.grab_focus()
	menu_opened.emit()


func resume_game() -> void:
	if not _is_open:
		return
	_is_open = false
	menu_root.visible = false
	get_tree().paused = _previous_tree_paused or _map_is_open()
	if not _map_is_open():
		Input.mouse_mode = _previous_mouse_mode
	resumed.emit()


func is_open() -> bool:
	return _is_open


func apply_graphics_preset(preset: int) -> void:
	_current_preset = clampi(
		preset,
		ParkourGraphicsPresets.Preset.PERFORMANCE,
		ParkourGraphicsPresets.Preset.ULTRA,
	)
	ParkourGraphicsPresets.apply(_current_preset, get_tree(), get_viewport())
	if preset_selector.item_count > _current_preset:
		preset_selector.select(_current_preset)
	preset_detail.text = ParkourGraphicsPresets.detail(_current_preset)
	graphics_preset_changed.emit(
		_current_preset,
		ParkourGraphicsPresets.label(_current_preset),
	)


func get_graphics_preset() -> int:
	return _current_preset


func _connect_buttons() -> void:
	resume_button.pressed.connect(resume_game)
	manual_button.pressed.connect(_show_manual_panel)
	options_button.pressed.connect(_show_options_panel)
	quit_button.pressed.connect(_quit_game)
	manual_back_button.pressed.connect(_show_main_panel)
	options_back_button.pressed.connect(_show_main_panel)
	preset_selector.item_selected.connect(apply_graphics_preset)


func _populate_presets() -> void:
	preset_selector.clear()
	for index in ParkourGraphicsPresets.LABELS.size():
		preset_selector.add_item(ParkourGraphicsPresets.LABELS[index], index)
	preset_selector.select(default_graphics_preset)
	preset_detail.text = ParkourGraphicsPresets.detail(
		default_graphics_preset,
	)


func _show_main_panel() -> void:
	main_panel.visible = true
	manual_panel.visible = false
	options_panel.visible = false
	if _is_open:
		resume_button.grab_focus()


func _show_manual_panel() -> void:
	main_panel.visible = false
	manual_panel.visible = true
	options_panel.visible = false
	manual_back_button.grab_focus()


func _show_options_panel() -> void:
	main_panel.visible = false
	manual_panel.visible = false
	options_panel.visible = true
	preset_selector.grab_focus()


func _quit_game() -> void:
	get_tree().quit()


func _map_is_open() -> bool:
	for candidate: Node in get_tree().get_nodes_in_group(
		"parkour_map_overlay",
	):
		if candidate.has_method("is_open") and bool(candidate.call("is_open")):
			return true
	return false
