extends Node2D

const SnakeScene := preload("res://scripts/snake.gd")
const FoodScene := preload("res://scripts/food.gd")
const OnlineSessionScene := preload("res://scripts/online_session.gd")
const TouchStickScene := preload("res://scripts/touch_stick.gd")
const WORLD_SIZE := Vector2(5200.0, 4000.0)
const SNAKE_COLORS := [Color("78f4ad"), Color("ff7faf"), Color("69b9ff"), Color("ffc963"), Color("c27cff"), Color("ff9666")]
const FOOD_COLORS := [Color("ffe56f"), Color("ff91cc"), Color("70eaff"), Color("9aff82"), Color("b688ff")]

var player: SlitherSnake
var snakes: Array[SlitherSnake] = []
var foods: Array[SlitherFood] = []
var game_active := false
var selected_skin := 0
var menu_layer: CanvasLayer
var hud_layer: CanvasLayer
var nickname_input: LineEdit
var length_label: Label
var score_label: Label
var leaderboard_label: Label
var announce_label: Label
var rng := RandomNumberGenerator.new()
var food_timer := 0.0
var mobile_mode := false
var local_bot_target := 9
var initial_food_count := 180
var food_target := 230
var background_mote_count := 180
var online_session: Node
var online_snakes: Dictionary = {}
var online_leaderboard: Array = []

func _ready() -> void:
	rng.randomize()
	mobile_mode = is_touch_layout()
	if mobile_mode:
		local_bot_target = 5
		initial_food_count = 96
		food_target = 132
		background_mote_count = 86
	queue_redraw()
	build_menu()

func _process(delta: float) -> void:
	if not game_active or player == null or not player.alive:
		return
	player.step_player(delta)
	for snake in snakes.duplicate():
		if not is_instance_valid(snake) or not snake.alive:
			continue
		if snake != player and not snake.network_controlled:
			snake.step_ai(delta, player.global_position)
	collect_food(player)
	for snake in snakes:
		if is_instance_valid(snake) and snake != player and not snake.network_controlled:
			collect_food(snake)
	check_collisions()
	food_timer += delta
	if food_timer >= 0.38 and foods.size() < food_target:
		food_timer = 0.0
		spawn_food(random_world_position(), rng.randi_range(1, 2))
	update_hud()

func random_world_position() -> Vector2:
	return Vector2(rng.randf_range(75.0, WORLD_SIZE.x - 75.0), rng.randf_range(75.0, WORLD_SIZE.y - 75.0))

func build_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 5
	add_child(menu_layer)
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.04, 0.05, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(veil)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_top = -272
	panel.offset_right = 240
	panel.offset_bottom = 272
	panel.add_theme_stylebox_override("panel", panel_style(Color("10222a"), Color("4fd49a"), 21, 1))
	menu_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 27)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var kicker := make_label("CRONOGAMES  •  GODOT WEBGL EDITION", 11, Color("b9ff88"))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kicker)
	var title := make_label("SLITHER.IO", 52, Color("f1fff5"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("123a35"))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	var subtitle := make_label("Cresci, accelera e taglia la strada agli avversari.\nUn’arena neon realizzata in Godot.", 14, Color("b5c9c4"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(make_label("NICKNAME", 10, Color("b9d1c9")))
	nickname_input = LineEdit.new()
	nickname_input.text = account_nickname()
	nickname_input.placeholder_text = "Il tuo nickname"
	nickname_input.max_length = 16
	nickname_input.custom_minimum_size = Vector2(0, 44)
	nickname_input.add_theme_stylebox_override("normal", panel_style(Color("08171c"), Color("3a6661"), 10, 1))
	nickname_input.add_theme_stylebox_override("focus", panel_style(Color("0d2023"), Color("b9ff88"), 10, 2))
	box.add_child(nickname_input)
	box.add_child(make_label("SCEGLI IL COLORE", 10, Color("b9d1c9")))
	var skins := HBoxContainer.new()
	skins.alignment = BoxContainer.ALIGNMENT_CENTER
	skins.add_theme_constant_override("separation", 8)
	for index in 4:
		var skin := Button.new()
		skin.text = ["MINT", "PINK", "SKY", "GOLD"][index]
		skin.custom_minimum_size = Vector2(96, 36)
		skin.add_theme_stylebox_override("normal", panel_style(Color(SNAKE_COLORS[index], 0.2) if index == selected_skin else Color("0b1a20"), SNAKE_COLORS[index] if index == selected_skin else Color("34514f"), 8, 1))
		skin.pressed.connect(select_skin.bind(index, skin, skins))
		skins.add_child(skin)
	box.add_child(skins)
	var start := Button.new()
	start.text = "STRISCIA NELL’ARENA   →"
	start.custom_minimum_size = Vector2(0, 51)
	start.add_theme_font_size_override("font_size", 14)
	start.add_theme_color_override("font_color", Color("0d1c14"))
	start.add_theme_stylebox_override("normal", panel_style(Color("b9ff88"), Color("efffcb"), 11, 1))
	start.pressed.connect(start_game)
	box.add_child(start)
	var hint := make_label("MOUSE / WASD per sterzare · SPAZIO per accelerare", 10, Color("71918a"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

func select_skin(index: int, pressed: Button, container: HBoxContainer) -> void:
	selected_skin = index
	for button in container.get_children():
		var button_index := container.get_children().find(button)
		button.add_theme_stylebox_override("normal", panel_style(Color(SNAKE_COLORS[button_index], 0.2) if button == pressed else Color("0b1a20"), SNAKE_COLORS[button_index] if button == pressed else Color("34514f"), 8, 1))

func start_game() -> void:
	menu_layer.visible = false
	game_active = true
	player = SnakeScene.new()
	player.configure(WORLD_SIZE * 0.5, nickname_input.text if not nickname_input.text.is_empty() else "Pilota", SNAKE_COLORS[selected_skin], true)
	snakes.append(player)
	add_child(player)
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)
	for index in local_bot_target:
		spawn_bot(index)
	for index in initial_food_count:
		spawn_food(random_world_position(), rng.randi_range(1, 3))
	build_hud()
	build_touch_controls()
	online_session = OnlineSessionScene.new()
	add_child(online_session)
	online_session.start_session(self, nickname_input.text, ["mint", "pink", "sky", "gold"][selected_skin])
	announce("Mangia le sfere luminose. Evita il corpo degli altri serpenti.")

func spawn_bot(index: int) -> void:
	var snake := SnakeScene.new()
	var bot_name: String = ["NOVA", "BYTE", "KRAKEN", "PULSE", "ORBIT", "GLITCH", "LUMA", "ZERO", "VOLT"][index % 9]
	snake.target_length = rng.randi_range(24, 46)
	snake.base_speed = rng.randf_range(155.0, 205.0)
	snake.configure(random_world_position(), bot_name, SNAKE_COLORS[(index + 1) % SNAKE_COLORS.size()], false)
	snakes.append(snake)
	add_child(snake)

func spawn_food(food_position: Vector2, value: int) -> void:
	var food := FoodScene.new()
	food.global_position = food_position
	food.configure(FOOD_COLORS[rng.randi_range(0, FOOD_COLORS.size() - 1)], value)
	foods.append(food)
	add_child(food)

func collect_food(snake: SlitherSnake) -> void:
	for food in foods.duplicate():
		if is_instance_valid(food) and snake.global_position.distance_to(food.global_position) < 27.0:
			snake.grow(food.value)
			foods.erase(food)
			food.queue_free()

func check_collisions() -> void:
	for snake in snakes.duplicate():
		if not is_instance_valid(snake) or not snake.alive:
			continue
		for other in snakes:
			if not is_instance_valid(other) or snake == other or not other.alive:
				continue
			if head_hits_body(snake.global_position, other):
				destroy_snake(snake)
				return

func head_hits_body(head: Vector2, body_owner: SlitherSnake) -> bool:
	for index in range(8, body_owner.segments.size(), 3):
		if head.distance_to(body_owner.segments[index]) < 16.0:
			return true
	return false

func destroy_snake(snake: SlitherSnake) -> void:
	if not snake.alive:
		return
	snake.alive = false
	for index in range(0, snake.segments.size(), 2):
		spawn_food(snake.segments[index], 2)
	snakes.erase(snake)
	if snake == player:
		game_active = false
		hud_layer.visible = false
		announce("Sei stato eliminato. Rientro nell’arena…")
		await get_tree().create_timer(1.8).timeout
		get_tree().reload_current_scene()
	else:
		snake.queue_free()
		await get_tree().create_timer(1.2).timeout
		if game_active and snakes.filter(func(candidate: SlitherSnake) -> bool: return is_instance_valid(candidate) and not candidate.network_controlled).size() < local_bot_target + 1:
			spawn_bot(rng.randi_range(0, 99))

func build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 3
	add_child(hud_layer)
	var stats := PanelContainer.new()
	stats.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stats.offset_left = 18
	stats.offset_top = 18
	stats.offset_right = 278
	stats.offset_bottom = 117
	stats.add_theme_stylebox_override("panel", panel_style(Color(0.025, 0.09, 0.1, 0.88), Color("326d65"), 13, 1))
	hud_layer.add_child(stats)
	stats.visible = not mobile_mode
	var labels := VBoxContainer.new()
	labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 13)
	labels.add_theme_constant_override("separation", 6)
	stats.add_child(labels)
	length_label = make_label("LUNGHEZZA  32", 13, Color("e9fff4"))
	score_label = make_label("PUNTEGGIO  0", 12, Color("b9ff88"))
	labels.add_child(length_label)
	labels.add_child(score_label)
	var board := PanelContainer.new()
	board.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	board.offset_left = -210
	board.offset_top = 18
	board.offset_right = -18
	board.offset_bottom = 160
	board.add_theme_stylebox_override("panel", panel_style(Color(0.025, 0.09, 0.1, 0.88), Color("326d65"), 13, 1))
	hud_layer.add_child(board)
	board.visible = not mobile_mode
	leaderboard_label = make_label("CLASSIFICA", 12, Color("e8fff2"))
	leaderboard_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 13)
	board.add_child(leaderboard_label)
	announce_label = make_label("", 12, Color("d7ffac"))
	announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	announce_label.offset_left = -270
	announce_label.offset_top = -62
	announce_label.offset_right = 270
	announce_label.offset_bottom = -32
	announce_label.add_theme_stylebox_override("normal", panel_style(Color(0.03, 0.09, 0.1, 0.84), Color("386a63"), 9, 1))
	hud_layer.add_child(announce_label)
	announce_label.visible = not mobile_mode

func update_hud() -> void:
	if player == null or length_label == null:
		return
	length_label.text = "LUNGHEZZA  %d" % player.segments.size()
	score_label.text = "PUNTEGGIO  %d" % player.score
	var ranking: Array = online_leaderboard.duplicate()
	if ranking.is_empty():
		ranking = snakes.filter(func(snake: SlitherSnake) -> bool: return is_instance_valid(snake)).map(func(snake: SlitherSnake) -> Dictionary: return {"nickname": snake.snake_name, "score": snake.segments.size()})
	ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	var rows := ["CLASSIFICA"]
	for index in min(5, ranking.size()):
		rows.append("%d.  %-12s %3d" % [index + 1, str(ranking[index].get("nickname", "RIVALE")), int(ranking[index].get("score", 0))])
	leaderboard_label.text = "\n".join(rows)

func apply_online_state(state: Dictionary, local_id: String) -> void:
	if str(state.get("game", "")) != "slither":
		return
	online_leaderboard = state.get("leaderboard", [])
	var active := {}
	var rendered := 0
	var remote_limit := 8 if mobile_mode else 20
	var actors: Array = state.get("players", []).duplicate()
	actors.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return not bool(first.get("bot", false)) and bool(second.get("bot", false)))
	for actor in actors:
		var actor_id := str(actor.get("id", ""))
		if actor_id.is_empty() or actor_id == local_id:
			continue
		if rendered >= remote_limit:
			continue
		rendered += 1
		active[actor_id] = true
		var snake: SlitherSnake = online_snakes.get(actor_id)
		if snake == null:
			snake = SnakeScene.new()
			var color_index: int = int(abs(actor_id.hash())) % SNAKE_COLORS.size()
			snake.configure(Vector2(float(actor.get("x", 0.0)), float(actor.get("y", 0.0)) * WORLD_SIZE.y / float(state.get("world", 5200))), str(actor.get("nickname", "Rivale")), SNAKE_COLORS[color_index], false)
			snake.network_controlled = true
			online_snakes[actor_id] = snake
			snakes.append(snake)
			add_child(snake)
		snake.apply_network_state(Vector2(float(actor.get("x", 0.0)), float(actor.get("y", 0.0)) * WORLD_SIZE.y / float(state.get("world", 5200))), float(actor.get("angle", 0.0)), int(actor.get("length", 32)))
	for actor_id in online_snakes.keys():
		if active.has(actor_id):
			continue
		var stale: SlitherSnake = online_snakes[actor_id]
		snakes.erase(stale)
		stale.queue_free()
		online_snakes.erase(actor_id)

func account_nickname() -> String:
	if OS.has_feature("web"):
		var browser_window = JavaScriptBridge.get_interface("window")
		var stored = browser_window.localStorage.getItem("cronogames_account")
		if stored:
			var account = JSON.parse_string(stored)
			if account is Dictionary and account.has("username"):
				return String(account.username)
	return "Pilota"

func build_touch_controls() -> void:
	if not is_touch_layout():
		return
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	add_touch_stick(root, ["cg_slither_left", "cg_slither_right", "cg_slither_up", "cg_slither_down"])
	add_touch_button(root, "BOOST", "cg_slither_boost", Vector2(-116, -94), Vector2(92, 58), Control.PRESET_BOTTOM_RIGHT)

func add_touch_stick(root: Control, actions: Array[String]) -> void:
	var stick = TouchStickScene.new()
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick.position = Vector2(18, -198)
	stick.size = Vector2(178, 178)
	root.add_child(stick)
	stick.setup(actions[0], actions[1], actions[2], actions[3])

func add_touch_button(root: Control, text_value: String, action: String, position_value: Vector2, size_value: Vector2, preset := Control.PRESET_BOTTOM_LEFT) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var button := Button.new()
	button.text = text_value
	button.set_anchors_preset(preset)
	button.position = position_value
	button.size = size_value
	button.add_theme_font_size_override("font_size", 16 if text_value.length() == 1 else 11)
	button.add_theme_stylebox_override("normal", panel_style(Color(0.03, 0.14, 0.14, 0.82), Color("7cf4bd"), 14, 1))
	button.button_down.connect(func() -> void: Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	button.tree_exiting.connect(func() -> void: Input.action_release(action))
	root.add_child(button)

func is_touch_layout() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("window.matchMedia && window.matchMedia('(pointer: coarse)').matches", true))
	return false

func announce(text: String) -> void:
	if announce_label != null:
		announce_label.text = text

func make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("061316"))
	for x in range(0, int(WORLD_SIZE.x) + 1, 120):
		draw_line(Vector2(x, 0), Vector2(x, WORLD_SIZE.y), Color(0.18, 0.56, 0.5, 0.11), 1.0)
	for y in range(0, int(WORLD_SIZE.y) + 1, 120):
		draw_line(Vector2(0, y), Vector2(WORLD_SIZE.x, y), Color(0.18, 0.56, 0.5, 0.11), 1.0)
	for index in background_mote_count:
		var mote := Vector2(float((index * 239) % int(WORLD_SIZE.x)), float((index * 151) % int(WORLD_SIZE.y)))
		draw_circle(mote, 1.0 + float(index % 3) * 0.45, Color(0.55, 1.0, 0.83, 0.13 + float(index % 3) * 0.05))
	draw_rect(Rect2(Vector2(30, 30), WORLD_SIZE - Vector2(60, 60)), Color("3b997b"), false, 3.0)
