extends Node2D

const PlayerShipScene := preload("res://scripts/player_ship.gd")
const EnemyShipScene := preload("res://scripts/enemy_ship.gd")
const EnergyOrbScene := preload("res://scripts/energy_orb.gd")
const ProjectileScene := preload("res://scripts/projectile.gd")
const RemoteShipScene := preload("res://scripts/remote_ship.gd")
const OnlineSessionScene := preload("res://scripts/online_session.gd")

const WORLD_SIZE := Vector2(4800.0, 3600.0)
const ENEMY_COLORS := [Color("ff6687"), Color("ff9f68"), Color("d76aff"), Color("5ab6ff")]

var player: PlayerShip
var enemies: Array[EnemyShip] = []
var orbs: Array[EnergyOrb] = []
var selected_skin := "violet"
var game_active := false
var menu_layer: CanvasLayer
var hud_layer: CanvasLayer
var nickname_input: LineEdit
var health_label: Label
var xp_label: Label
var level_label: Label
var score_label: Label
var leaderboard_label: Label
var announcement_label: Label
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var spawn_timer := 0.0
var online_session: Node
var remote_ships: Dictionary = {}
var online_leaderboard: Array = []

func _ready() -> void:
	rng.randomize()
	queue_redraw()
	build_menu()

func _process(delta: float) -> void:
	if not game_active:
		return
	elapsed += delta
	spawn_timer += delta
	if spawn_timer > 1.4 and orbs.size() < 100:
		spawn_timer = 0.0
		spawn_orb(random_world_position())
	for orb in orbs.duplicate():
		if is_instance_valid(orb) and player != null and player.global_position.distance_to(orb.global_position) < 43.0:
			player.collect_orb(orb.value)
			orbs.erase(orb)
			orb.queue_free()
	update_hud()

func random_world_position() -> Vector2:
	return Vector2(rng.randf_range(100.0, WORLD_SIZE.x - 100.0), rng.randf_range(100.0, WORLD_SIZE.y - 100.0))

func build_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 5
	add_child(menu_layer)
	var veil := ColorRect.new()
	veil.color = Color(0.018, 0.02, 0.055, 0.74)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(veil)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -238.0
	panel.offset_top = -290.0
	panel.offset_right = 238.0
	panel.offset_bottom = 290.0
	panel.add_theme_stylebox_override("panel", panel_style(Color("12152a"), Color("8069dd"), 20, 1))
	menu_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 26)
	panel.add_child(box)
	var kicker := make_label("CRONOGAMES  •  GODOT WEBGL EDITION", 11, Color("d8ff57"))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kicker)
	var title := make_label("SHIP.IO", 58, Color("f7f5ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("3d1c69"))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	var subtitle := make_label("Un’arena spaziale costruita in Godot.\nRaccogli energia. Scala la classifica. Sopravvivi.", 14, Color("b8b5cb"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(spacer(7))
	box.add_child(make_label("NICKNAME", 10, Color("bcb7d3")))
	nickname_input = LineEdit.new()
	nickname_input.placeholder_text = "Inserisci il tuo nickname"
	nickname_input.text = account_nickname()
	nickname_input.max_length = 16
	nickname_input.custom_minimum_size = Vector2(0, 44)
	nickname_input.add_theme_stylebox_override("normal", panel_style(Color("090a17"), Color("4d4774"), 10, 1))
	nickname_input.add_theme_stylebox_override("focus", panel_style(Color("0c0d20"), Color("d8ff57"), 10, 2))
	box.add_child(nickname_input)
	box.add_child(make_label("SCEGLI LA TUA NAVE", 10, Color("bcb7d3")))
	var skins := HBoxContainer.new()
	skins.alignment = BoxContainer.ALIGNMENT_CENTER
	skins.add_theme_constant_override("separation", 9)
	for skin_name in ["violet", "cyan", "amber"]:
		var skin_button := Button.new()
		skin_button.text = {"violet": "NOVA", "cyan": "ION", "amber": "SOLAR"}[skin_name]
		skin_button.custom_minimum_size = Vector2(125, 38)
		skin_button.tooltip_text = "Seleziona skin " + skin_name
		skin_button.pressed.connect(select_skin.bind(skin_name, skin_button, skins))
		skin_button.add_theme_stylebox_override("normal", panel_style(Color("201b36") if skin_name == selected_skin else Color("0e1020"), Color("a76cff") if skin_name == selected_skin else Color("383452"), 9, 1))
		skins.add_child(skin_button)
	box.add_child(skins)
	box.add_child(spacer(3))
	var start_button := Button.new()
	start_button.text = "ENTRA NELL’ARENA   →"
	start_button.custom_minimum_size = Vector2(0, 51)
	start_button.add_theme_font_size_override("font_size", 14)
	start_button.add_theme_color_override("font_color", Color("111408"))
	start_button.add_theme_stylebox_override("normal", panel_style(Color("d8ff57"), Color("f4ffbd"), 11, 1))
	start_button.pressed.connect(start_game)
	box.add_child(start_button)
	var shop_button := Button.new()
	shop_button.text = "SHIPYARD  ✦  SKIN E RICOMPENSE"
	shop_button.flat = true
	shop_button.add_theme_color_override("font_color", Color("cbbcff"))
	shop_button.pressed.connect(show_shop)
	box.add_child(shop_button)
	var build_note := make_label("WebGL · Godot 4 · Modalità arena locale", 10, Color("7e7a97"))
	build_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(build_note)

func select_skin(skin_name: String, pressed_button: Button, container: HBoxContainer) -> void:
	selected_skin = skin_name
	for button in container.get_children():
		button.add_theme_stylebox_override("normal", panel_style(Color("201b36") if button == pressed_button else Color("0e1020"), Color("a76cff") if button == pressed_button else Color("383452"), 9, 1))

func show_shop() -> void:
	var shop := PanelContainer.new()
	shop.set_anchors_preset(Control.PRESET_CENTER)
	shop.offset_left = -245
	shop.offset_top = -175
	shop.offset_right = 245
	shop.offset_bottom = 175
	shop.add_theme_stylebox_override("panel", panel_style(Color("15152a"), Color("d5b357"), 18, 1))
	menu_layer.add_child(shop)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 23)
	content.add_theme_constant_override("separation", 13)
	shop.add_child(content)
	var shop_title := make_label("SHIPYARD", 32, Color("fff4c8"))
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(shop_title)
	var shop_text := make_label("Qui arriveranno skin premium e premi pubblicitari.\nQuesta build mantiene i pulsanti come placeholder, senza pagamenti reali.", 13, Color("bbb7c9"))
	shop_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(shop_text)
	for option in ["SOLAR  ·  € 0,99", "MINT RUSH  ·  GUARDA UNO SPOT"]:
		var option_button := Button.new()
		option_button.text = option
		option_button.custom_minimum_size = Vector2(0, 41)
		option_button.add_theme_stylebox_override("normal", panel_style(Color("242139"), Color("63567d"), 9, 1))
		option_button.pressed.connect(func() -> void: announce("Placeholder shop: integrazione pagamento/advertising da definire."))
		content.add_child(option_button)
	var close := Button.new()
	close.text = "CHIUDI"
	close.flat = true
	close.pressed.connect(shop.queue_free)
	content.add_child(close)

func start_game() -> void:
	menu_layer.visible = false
	game_active = true
	player = PlayerShipScene.new()
	player.configure(self, selected_skin)
	player.global_position = WORLD_SIZE * 0.5
	player.stats_changed.connect(update_hud)
	player.destroyed.connect(player_destroyed)
	add_child(player)
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)
	for index in 12:
		spawn_enemy(index)
	for index in 90:
		spawn_orb(random_world_position())
	build_hud()
	build_touch_controls()
	online_session = OnlineSessionScene.new()
	add_child(online_session)
	online_session.start_session(self, nickname_input.text, selected_skin)
	announce("Raccogli energia. Tieni premuto il mouse per fare fuoco.")

func spawn_enemy(index: int) -> void:
	var enemy := EnemyShipScene.new()
	var angle := float(index) / 12.0 * TAU
	var distance := rng.randf_range(560.0, 1100.0)
	var position_on_ring := WORLD_SIZE * 0.5 + Vector2(cos(angle), sin(angle)) * distance
	position_on_ring.x = clampf(position_on_ring.x, 90.0, WORLD_SIZE.x - 90.0)
	position_on_ring.y = clampf(position_on_ring.y, 90.0, WORLD_SIZE.y - 90.0)
	enemy.configure(self, position_on_ring, ENEMY_COLORS[index % ENEMY_COLORS.size()])
	enemies.append(enemy)
	add_child(enemy)

func spawn_orb(orb_position: Vector2) -> void:
	var orb := EnergyOrbScene.new()
	orb.global_position = orb_position
	orbs.append(orb)
	add_child(orb)

func spawn_projectile(start_position: Vector2, direction: Vector2, damage: float, from_player: bool, color: Color) -> void:
	var projectile := ProjectileScene.new()
	projectile.setup(start_position, direction, damage, from_player, color, self)
	add_child(projectile)

func resolve_projectile(projectile: Projectile) -> void:
	if not is_instance_valid(projectile):
		return
	if projectile.from_player:
		for enemy in enemies.duplicate():
			if is_instance_valid(enemy) and projectile.global_position.distance_to(enemy.global_position) < 30.0:
				enemy.take_damage(projectile.damage)
				projectile.queue_free()
				return
	elif player != null and projectile.global_position.distance_to(player.global_position) < 29.0:
		player.take_damage(projectile.damage)
		projectile.queue_free()

func enemy_destroyed(enemy: EnemyShip) -> void:
	enemies.erase(enemy)
	player.score += enemy.score_value
	player.collect_orb(36)
	announce("Nave rivale eliminata  +%d" % enemy.score_value)
	await get_tree().create_timer(1.1).timeout
	if game_active:
		spawn_enemy(rng.randi_range(0, 99))

func announce_upgrade(new_level: int) -> void:
	announce("LIVELLO %d  ·  Scudo, velocità e fuoco migliorati" % new_level)

func player_destroyed() -> void:
	game_active = false
	if hud_layer != null:
		hud_layer.visible = false
	announce("Nave distrutta. Rientra nell’arena quando vuoi.")
	await get_tree().create_timer(1.6).timeout
	get_tree().reload_current_scene()

func build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 3
	add_child(hud_layer)
	var stats_panel := PanelContainer.new()
	stats_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stats_panel.offset_left = 18
	stats_panel.offset_top = 18
	stats_panel.offset_right = 300
	stats_panel.offset_bottom = 148
	stats_panel.add_theme_stylebox_override("panel", panel_style(Color(0.045, 0.05, 0.11, 0.88), Color("403d64"), 13, 1))
	hud_layer.add_child(stats_panel)
	var stats := VBoxContainer.new()
	stats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 13)
	stats.add_theme_constant_override("separation", 6)
	stats_panel.add_child(stats)
	level_label = make_label("LV 1  ·  PILOTA", 14, Color("eae5ff"))
	health_label = make_label("SCUDO  100 / 100", 12, Color("ffb0c0"))
	xp_label = make_label("ENERGIA  0 / 100", 12, Color("8fcfff"))
	score_label = make_label("PUNTEGGIO  0", 12, Color("d8ff57"))
	stats.add_child(level_label)
	stats.add_child(health_label)
	stats.add_child(xp_label)
	stats.add_child(score_label)
	var leaderboard_panel := PanelContainer.new()
	leaderboard_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	leaderboard_panel.offset_left = -215
	leaderboard_panel.offset_top = 18
	leaderboard_panel.offset_right = -18
	leaderboard_panel.offset_bottom = 160
	leaderboard_panel.add_theme_stylebox_override("panel", panel_style(Color(0.045, 0.05, 0.11, 0.88), Color("403d64"), 13, 1))
	hud_layer.add_child(leaderboard_panel)
	leaderboard_label = make_label("CLASSIFICA\n\n1.  PILOTA        0", 12, Color("ece9f7"))
	leaderboard_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 13)
	leaderboard_panel.add_child(leaderboard_label)
	announcement_label = make_label("", 13, Color("eaffad"))
	announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	announcement_label.offset_left = -270
	announcement_label.offset_top = -70
	announcement_label.offset_right = 270
	announcement_label.offset_bottom = -36
	announcement_label.add_theme_stylebox_override("normal", panel_style(Color(0.06, 0.06, 0.14, 0.86), Color("585279"), 9, 1))
	hud_layer.add_child(announcement_label)
	var controls := make_label("WASD / FRECCE · MOUSE PER MIRA E FUOCO · TOUCH SU MOBILE", 10, Color("aaa7c0"))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls.offset_left = -210
	controls.offset_top = -27
	controls.offset_right = 210
	controls.offset_bottom = -8
	hud_layer.add_child(controls)

func update_hud() -> void:
	if player == null or not is_instance_valid(player) or health_label == null:
		return
	level_label.text = "LV %d  ·  %s" % [player.level, nickname_input.text.to_upper()]
	health_label.text = "SCUDO  %d / %d" % [ceil(player.health), ceil(player.max_health)]
	xp_label.text = "ENERGIA  %d / %d" % [floor(player.xp), floor(player.xp_next)]
	score_label.text = "PUNTEGGIO  %d" % player.score
	var rivals: Array = online_leaderboard.duplicate()
	if rivals.is_empty():
		rivals = enemies.filter(func(enemy: EnemyShip) -> bool: return is_instance_valid(enemy)).map(func(enemy: EnemyShip) -> Dictionary: return {"nickname": "RIVALE", "score": enemy.score_value + int(enemy.health)})
		rivals.append({"nickname": nickname_input.text.to_upper(), "score": player.score})
	rivals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	var rows := ["CLASSIFICA"]
	for index in min(5, rivals.size()):
		rows.append("%d.  %-12s %4d" % [index + 1, str(rivals[index].get("nickname", "RIVALE")), int(rivals[index].get("score", 0))])
	leaderboard_label.text = "\n".join(rows)

func apply_online_state(state: Dictionary, local_id: String) -> void:
	if str(state.get("game", "")) != "ship":
		return
	online_leaderboard = state.get("leaderboard", [])
	var active := {}
	for actor in state.get("players", []):
		var actor_id := str(actor.get("id", ""))
		if actor_id.is_empty() or actor_id == local_id:
			continue
		active[actor_id] = true
		var remote: Node2D = remote_ships.get(actor_id)
		if remote == null:
			remote = RemoteShipScene.new()
			remote.configure(str(actor.get("nickname", "Rivale")), str(actor.get("skin", "violet")), bool(actor.get("bot", false)))
			remote_ships[actor_id] = remote
			add_child(remote)
		var position_scale := Vector2(WORLD_SIZE.x / float(state.get("world", 2600)), WORLD_SIZE.y / float(state.get("world", 2600)))
		remote.apply_network_state(Vector2(float(actor.get("x", 0.0)), float(actor.get("y", 0.0))) * position_scale, float(actor.get("angle", 0.0)))
	for actor_id in remote_ships.keys():
		if active.has(actor_id):
			continue
		var stale: Node2D = remote_ships[actor_id]
		stale.queue_free()
		remote_ships.erase(actor_id)

func announce(text: String) -> void:
	if announcement_label != null:
		announcement_label.text = text

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
	add_touch_button(root, "←", "cg_ship_left", Vector2(24, -90), Vector2(58, 58))
	add_touch_button(root, "↑", "cg_ship_up", Vector2(88, -154), Vector2(58, 58))
	add_touch_button(root, "→", "cg_ship_right", Vector2(152, -90), Vector2(58, 58))
	add_touch_button(root, "↓", "cg_ship_down", Vector2(88, -90), Vector2(58, 58))
	add_touch_button(root, "FUOCO", "cg_ship_fire", Vector2(-116, -94), Vector2(92, 58), Control.PRESET_BOTTOM_RIGHT)

func add_touch_button(root: Control, text_value: String, action: String, position_value: Vector2, size_value: Vector2, preset := Control.PRESET_BOTTOM_LEFT) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var button := Button.new()
	button.text = text_value
	button.set_anchors_preset(preset)
	button.position = position_value
	button.size = size_value
	button.add_theme_font_size_override("font_size", 16 if text_value.length() == 1 else 11)
	button.add_theme_stylebox_override("normal", panel_style(Color(0.07, 0.06, 0.16, 0.82), Color("b68cff"), 14, 1))
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

func make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func spacer(height: float) -> Control:
	var control := Control.new()
	control.custom_minimum_size = Vector2(0, height)
	return control

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
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("070813"))
	for x in range(0, int(WORLD_SIZE.x) + 1, 120):
		draw_line(Vector2(x, 0), Vector2(x, WORLD_SIZE.y), Color(0.27, 0.24, 0.55, 0.13), 1.0)
	for y in range(0, int(WORLD_SIZE.y) + 1, 120):
		draw_line(Vector2(0, y), Vector2(WORLD_SIZE.x, y), Color(0.27, 0.24, 0.55, 0.13), 1.0)
	for index in 170:
		var star_position := Vector2(float((index * 197) % int(WORLD_SIZE.x)), float((index * 313) % int(WORLD_SIZE.y)))
		var size := 1.0 + float(index % 3) * 0.6
		draw_circle(star_position, size, Color(0.72, 0.73, 1.0, 0.25 + float(index % 4) * 0.1))
	var border_color := Color("6e5cca")
	draw_rect(Rect2(Vector2(32, 32), WORLD_SIZE - Vector2(64, 64)), border_color, false, 3.0)
